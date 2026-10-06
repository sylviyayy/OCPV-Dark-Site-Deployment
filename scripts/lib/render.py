#!/usr/bin/env python3
"""Validate the .env field register and render every site file from it.

PRD v2.0: FR-A1 (renderer), FR-A3 (validation), FR-D1..FR-D8 (install inputs),
FR-E4 (kickstarts), FR-B6 (ImageSet), FR-H4 (VM manifests).

Values come from the process environment: scripts/lib/common.sh:load_env sources .env
with `set -a`, so every key is exported. Secrets never arrive on argv (NFR-4).
PyYAML (python3-pyyaml, on the RHEL 9 DVD) is imported only by subcommands that emit
or read YAML, so `validate` also runs on a host without it.

Subcommands
  validate [--probe]             enforce the field-register Rule column (one message per key)
  install-config OUT             render install-config.yaml   (FR-D1, D2, D3, A2)
  agent-config OUT               render agent-config.yaml     (FR-D4, D5, D6, D8)
  imageset OUT [--profile P]     render the oc-mirror ImageSetConfiguration (FR-B6)
  text TEMPLATE OUT              substitute ${KEY} tokens in a text template
  catalog-source                 print the mirrored redhat-operator-index CatalogSource name (FR-G1)
  value KEY                      print one .env or derived value
"""
import argparse
import base64
import ipaddress
import json
import os
import pathlib
import re
import subprocess
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
TOKEN = re.compile(r"\$\{([A-Z][A-Z0-9_]*)\}")
NODES = ("CP01", "CP02", "CP03")

# Field register, in the order of docs/labs/03-checklist.md and .env.example (PRD §1).
REGISTER = [
    ("A1", "CLUSTER_NAME"), ("A2", "BASE_DOMAIN"), ("A3", "OCP_VERSION"), ("A4", "OCP_CHANNEL"),
    ("B1", "MACHINE_NETWORK_CIDR"), ("B2", "NETWORK_GATEWAY"),
    ("B3", "CLUSTER_NETWORK_CIDR"), ("B3", "SERVICE_NETWORK_CIDR"),
    ("B4", "MTU"), ("B5", "API_VIP"), ("B6", "INGRESS_VIP"),
    *[("C1", f"{n}_HOSTNAME") for n in NODES],
    *[("C2", f"{n}_IP") for n in NODES],
    *[("C3", f"{n}_NICS") for n in NODES],
    *[("C4", f"{n}_ROOT_DEVICE") for n in NODES],
    *[("C5", f"{n}_BMC_IP") for n in NODES],
    ("C6", "RENDEZVOUS_IP"),
    ("D1", "BASTION_HOSTNAME"), ("D1", "BASTION_IP"), ("D2", "BASTION_IFNAME"),
    ("D3", "MIRROR_REGISTRY_HOSTNAME"), ("D4", "MIRROR_REGISTRY_PORT"),
    ("D5", "MIRROR_REGISTRY_IP"), ("D6", "MIRROR_REGISTRY_USER"),
    ("E1", "TIME_SOURCE"), ("E2", "DNS_VM_IPS"), ("E3", "NTP_VM_IP"),
    ("E4", "VM_NETWORK_MODEL"), ("E5", "STORAGE_BACKEND"),
    ("F1", "PULL_SECRET_FILE"), ("F2", "SSH_PUBLIC_KEY_FILE"), ("F3", "MIRROR_DIR"), ("F4", "INSTALL_DIR"),
]
# Derived keys live in .env.example's "do not edit" block; validation proves they still
# equal their formula, so a hand edit (for example MIRROR_REGISTRY=<ip>:443) is caught.
DERIVED = {
    "MIRROR_REGISTRY": lambda e: f"{e['MIRROR_REGISTRY_HOSTNAME']}:{e['MIRROR_REGISTRY_PORT']}",
    "MIRROR_ARCHIVE_DIR": lambda e: f"{e['MIRROR_DIR']}/archive",
    "IMAGESET_CONFIG": lambda e: f"{e['MIRROR_DIR']}/imageset-config.yaml",
    "AUTH_FILE": lambda e: f"{e['MIRROR_DIR']}/auth.json",
    "REGISTRY_CA_FILE": lambda e: f"{e['MIRROR_DIR']}/registry-ca.crt",
    "CLUSTER_RESOURCES_DIR": lambda e: f"{e['MIRROR_DIR']}/archive/working-dir/cluster-resources",
}
FIELD_ID = {key: fid for fid, key in REGISTER}

RFC1123_LABEL = re.compile(r"^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$")
DNS_NAME = re.compile(r"^(?=.{1,253}$)([a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?)(\.[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?)+$")
IFNAME = re.compile(r"^[A-Za-z0-9_.-]{1,15}$")
MAC = re.compile(r"^[0-9a-f]{2}(:[0-9a-f]{2}){5}$")
OVN_INTERNAL = [ipaddress.ip_network("100.64.0.0/16"), ipaddress.ip_network("100.88.0.0/16")]
PLACEHOLDERS = [
    (re.compile(r"\$\{[A-Z][A-Z0-9_]*\}"), "unrendered ${KEY} token"),
    (re.compile(r"<[A-Z][A-Z0-9_]{2,}>"), "<UPPER_CASE> placeholder"),
    (re.compile(r"00:50:56", re.I), "VMware OUI sample MAC (00:50:56)"),
    (re.compile(r"\bens192\b"), "vSphere sample NIC name (ens192)"),
]


class Fail(Exception):
    """A rendering precondition is not met; message is printed and the exit code is 1."""


# --------------------------------------------------------------------------- helpers
def env_get(env, key):
    value = env.get(key, "")
    if value == "":
        raise Fail(f"{key} is empty or missing in .env")
    return value


def machine_net(env):
    return ipaddress.ip_network(env_get(env, "MACHINE_NETWORK_CIDR"), strict=True)


def parse_nics(raw):
    """'ens1f0=aa:bb:cc:00:01:01,ens1f1=...' -> [('ens1f0', 'aa:bb:cc:00:01:01'), ...]"""
    pairs = []
    for item in [p.strip() for p in raw.split(",") if p.strip()]:
        if "=" not in item:
            raise ValueError(f"'{item}' is not <ifname>=<MAC>")
        name, mac = (s.strip() for s in item.split("=", 1))
        pairs.append((name, mac.lower()))
    return pairs


def dns_vm_ips(env):
    ips = [p.strip() for p in env_get(env, "DNS_VM_IPS").split(",") if p.strip()]
    if len(ips) != 2:
        raise Fail("DNS_VM_IPS must hold exactly two comma-separated IPs")
    return ips


def time_upstream(env):
    """The clock every node and VM follows: TIME_SOURCE, or the bastion's orphan clock."""
    src = env_get(env, "TIME_SOURCE")
    return env_get(env, "BASTION_IP") if src == "orphan" else src


def vm_mac(ip):
    """Deterministic, locally administered unicast MAC from an IPv4 address (02:00:a:b:c:d)."""
    octets = ipaddress.ip_address(ip).packed
    return "02:00:" + ":".join(f"{o:02x}" for o in octets)


def reverse_zone(env):
    net = machine_net(env)
    whole = (net.prefixlen // 8) * 8
    if whole < 8:
        raise Fail("MACHINE_NETWORK_CIDR prefix must be /8 or longer for the reverse zone")
    octets = str(net.network_address).split(".")[: whole // 8]
    return ".".join(reversed(octets)) + ".in-addr.arpa", whole // 8


def ptr_owner(env, ip):
    _, zone_octets = reverse_zone(env)
    octets = ip.split(".")[zone_octets:]
    return ".".join(reversed(octets))


def outside_repo(path):
    p = pathlib.Path(path).expanduser().resolve()
    return p != REPO_ROOT and REPO_ROOT not in p.parents


def read_file(path, what):
    p = pathlib.Path(path)
    if not p.is_file():
        raise Fail(f"{what} not found: {p}")
    return p.read_text()


def assert_clean(text, label):
    for pattern, what in PLACEHOLDERS:
        m = pattern.search(text)
        if m:
            raise Fail(f"{label}: {what} left in output: '{m.group(0)}'")


def write_out(path, text, mode=0o644):
    out = pathlib.Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text)
    out.chmod(mode)


# --------------------------------------------------------------------------- YAML
def yaml_module():
    try:
        import yaml  # noqa: PLC0415 — deferred so `validate` needs no PyYAML
    except ImportError as exc:
        raise Fail("python3-pyyaml is required (dnf install python3-pyyaml; it is on the RHEL 9 DVD)") from exc
    return yaml


def yaml_load(path):
    yaml = yaml_module()
    return yaml.safe_load(read_file(path, "YAML file"))


def yaml_dump(data):
    """Deterministic dump (NFR-2): key order kept, sequences indented, multi-line strings
    as literal blocks so every PEM line is indented (FR-D3)."""
    yaml = yaml_module()

    class Dumper(yaml.SafeDumper):
        def increase_indent(self, flow=False, indentless=False):
            return super().increase_indent(flow, False)

    def represent_str(dumper, value):
        if "\n" in value:
            return dumper.represent_scalar("tag:yaml.org,2002:str", value, style="|")
        return dumper.represent_scalar("tag:yaml.org,2002:str", value)

    Dumper.add_representer(str, represent_str)
    return yaml.dump(data, Dumper=Dumper, sort_keys=False, default_flow_style=False, width=4096)


# --------------------------------------------------------------------------- validate
class Report:
    def __init__(self):
        self.errors = {}
        self.warnings = []

    def fail(self, key, message):
        self.errors.setdefault(key, message)  # one message per offending key (FR-A3)

    def warn(self, key, message):
        self.warnings.append((key, message))


def _ip(r, env, key, net=None):
    raw = env.get(key, "")
    try:
        ip = ipaddress.IPv4Address(raw)
    except ValueError:
        r.fail(key, f"'{raw}' is not an IPv4 address")
        return None
    if net is not None and ip not in net:
        r.fail(key, f"{ip} is outside MACHINE_NETWORK_CIDR {net}")
        return None
    return ip


def validate(env, probe=False):
    r = Report()
    for _, key in REGISTER:
        if env.get(key, "") == "":
            r.fail(key, "missing or empty")
    if env.get("ENV_SCHEMA_VERSION") != "2":
        r.fail("ENV_SCHEMA_VERSION", "must be 2 (this is a v1 .env: re-create it from .env.example)")

    # A — cluster identity
    if env.get("CLUSTER_NAME") and not RFC1123_LABEL.match(env["CLUSTER_NAME"]):
        r.fail("CLUSTER_NAME", "must be a lowercase RFC 1123 label (a-z, 0-9, '-'; max 63)")
    dom = env.get("BASE_DOMAIN", "")
    if dom:
        if not DNS_NAME.match(dom):
            r.fail("BASE_DOMAIN", f"'{dom}' is not a lowercase DNS name with at least two labels")
        elif dom == "local" or dom.endswith(".local"):
            r.fail("BASE_DOMAIN", ".local is reserved for multicast DNS (RFC 6762); use a site-owned domain or <name>.internal")
        elif re.search(r"(^|\.)example\.(com|net|org)$", dom):
            r.fail("BASE_DOMAIN", "example.com/.net/.org are documentation domains (RFC 2606), not site-owned; use your domain or <name>.internal")
    ver = re.fullmatch(r"4\.(\d+)\.(\d+)", env.get("OCP_VERSION", ""))
    if env.get("OCP_VERSION") and not ver:
        r.fail("OCP_VERSION", f"'{env['OCP_VERSION']}' is not an exact z-stream such as 4.22.3")
    chan = re.fullmatch(r"(stable|fast|eus|candidate)-4\.(\d+)", env.get("OCP_CHANNEL", ""))
    if env.get("OCP_CHANNEL") and not chan:
        r.fail("OCP_CHANNEL", "must look like stable-4.22")
    elif ver and chan and ver.group(1) != chan.group(2):
        r.fail("OCP_CHANNEL", f"minor {chan.group(2)} differs from OCP_VERSION minor {ver.group(1)}")

    # B — networks
    net = None
    try:
        net = ipaddress.IPv4Network(env.get("MACHINE_NETWORK_CIDR", ""), strict=True)
    except ValueError as exc:
        r.fail("MACHINE_NETWORK_CIDR", f"not an IPv4 network with host bits zero ({exc})")
    _ip(r, env, "NETWORK_GATEWAY", net)
    overlay = {}
    for key in ("CLUSTER_NETWORK_CIDR", "SERVICE_NETWORK_CIDR"):
        try:
            overlay[key] = ipaddress.IPv4Network(env.get(key, ""), strict=True)
        except ValueError as exc:
            r.fail(key, f"not an IPv4 network with host bits zero ({exc})")
            continue
        clash = [str(n) for n in ([net] if net else []) + OVN_INTERNAL if overlay[key].overlaps(n)]
        if clash:
            r.fail(key, f"overlaps {', '.join(clash)} (machine network or OVN-K internal ranges)")
    if len(overlay) == 2 and overlay["CLUSTER_NETWORK_CIDR"].overlaps(overlay["SERVICE_NETWORK_CIDR"]):
        r.fail("SERVICE_NETWORK_CIDR", "overlaps CLUSTER_NETWORK_CIDR")
    mtu = env.get("MTU", "")
    if mtu and not (mtu.isdigit() and 1280 <= int(mtu) <= 9216):
        r.fail("MTU", "must be an integer between 1280 and 9216 that equals the switch MTU end to end")
    api = _ip(r, env, "API_VIP", net)
    ingress = _ip(r, env, "INGRESS_VIP", net)
    if api and ingress and api == ingress:
        r.fail("INGRESS_VIP", "must differ from API_VIP")

    # C — control-plane nodes
    names, macs, cp_ips = {}, {}, []
    for n in NODES:
        host = env.get(f"{n}_HOSTNAME", "")
        if host:
            if "." in host or not RFC1123_LABEL.match(host):
                r.fail(f"{n}_HOSTNAME", "must be a short lowercase name (no dots), e.g. cp01")
            elif host in names:
                r.fail(f"{n}_HOSTNAME", f"duplicates {names[host]}")
            names[host] = f"{n}_HOSTNAME"
        ip = _ip(r, env, f"{n}_IP", net)
        if ip:
            cp_ips.append(str(ip))
        key = f"{n}_NICS"
        try:
            pairs = parse_nics(env.get(key, ""))
        except ValueError as exc:
            r.fail(key, str(exc))
            pairs = []
        if env.get(key) and len(pairs) != 4:
            r.fail(key, f"must list exactly the 4 bond members, found {len(pairs)}")
        for ifname, mac in pairs:
            if not IFNAME.match(ifname):
                r.fail(key, f"'{ifname}' is not a valid interface name")
            elif not MAC.match(mac):
                r.fail(key, f"'{mac}' is not a MAC address (aa:bb:cc:dd:ee:ff)")
            elif mac == "00:00:00:00:00:00":
                r.fail(key, "still holds the sample MAC 00:00:00:00:00:00; read real MACs from XCC (Lab 03/05)")
            elif mac.startswith("00:50:56"):
                r.fail(key, f"{mac} has the VMware OUI 00:50:56; these are bare-metal NICs")
            elif int(mac.split(":")[0], 16) & 1:
                r.fail(key, f"{mac} is a multicast address")
            elif mac in macs:
                r.fail(key, f"MAC {mac} duplicates one in {macs[mac]}")
            else:
                macs[mac] = key
        if len({p[0] for p in pairs}) != len(pairs):
            r.fail(key, "interface names must be unique within a node")
        dev = env.get(f"{n}_ROOT_DEVICE", "")
        if dev:
            if not re.match(r"^/dev/disk/by-(path|id)/[^\s…]+$", dev) or "..." in dev:
                r.fail(f"{n}_ROOT_DEVICE", "must be a complete /dev/disk/by-path/... (or by-id) path to the RAID1 virtual disk, never /dev/sdX")
        _ip(r, env, f"{n}_BMC_IP")
    rv = env.get("RENDEZVOUS_IP", "")
    if rv and cp_ips and rv not in cp_ips:
        r.fail("RENDEZVOUS_IP", f"{rv} must equal one of CP01_IP..CP03_IP ({', '.join(cp_ips)})")

    # D — bastion and registry
    bh = env.get("BASTION_HOSTNAME", "")
    if bh and ("." in bh or not RFC1123_LABEL.match(bh)):
        r.fail("BASTION_HOSTNAME", "must be a short lowercase name (no dots), e.g. bastion")
    _ip(r, env, "BASTION_IP", net)
    if env.get("BASTION_IFNAME") and not IFNAME.match(env["BASTION_IFNAME"]):
        r.fail("BASTION_IFNAME", "is not a valid interface name (read it with `ip -br link` on the bastion)")
    reg = env.get("MIRROR_REGISTRY_HOSTNAME", "")
    if reg:
        if not DNS_NAME.match(reg):
            r.fail("MIRROR_REGISTRY_HOSTNAME", "must be a lowercase FQDN")
        elif dom and not reg.endswith("." + dom):
            r.fail("MIRROR_REGISTRY_HOSTNAME", f"must sit under BASE_DOMAIN ({dom}) so the bastion and DNS VMs serve it")
    port = env.get("MIRROR_REGISTRY_PORT", "")
    if port:
        if not (port.isdigit() and 1 <= int(port) <= 65535):
            r.fail("MIRROR_REGISTRY_PORT", "must be a TCP port number")
        elif port not in ("8443", "443"):
            r.warn("MIRROR_REGISTRY_PORT", "is neither 8443 (tool default) nor 443 (site policy); confirm the firewall plan")
    _ip(r, env, "MIRROR_REGISTRY_IP", net)
    user = env.get("MIRROR_REGISTRY_USER", "")
    if user and not re.match(r"^[a-z_][a-z0-9_-]{0,31}$", user):
        r.fail("MIRROR_REGISTRY_USER", "must be a lowercase user name")

    # E — site services
    ts = env.get("TIME_SOURCE", "")
    if ts == "orphan":
        r.warn("TIME_SOURCE", "orphan: the cluster agrees with itself, not with UTC; this run is lab-grade (Lab 07)")
    elif ts:
        _ip(r, env, "TIME_SOURCE")
    raw_dns = [p.strip() for p in env.get("DNS_VM_IPS", "").split(",") if p.strip()]
    if env.get("DNS_VM_IPS") and len(raw_dns) != 2:
        r.fail("DNS_VM_IPS", "must hold exactly two comma-separated IPs (two DNS VMs, ADR-07)")
    for ip in raw_dns:
        try:
            if net and ipaddress.IPv4Address(ip) not in net:
                r.fail("DNS_VM_IPS", f"{ip} is outside MACHINE_NETWORK_CIDR")
        except ValueError:
            r.fail("DNS_VM_IPS", f"'{ip}' is not an IPv4 address")
    _ip(r, env, "NTP_VM_IP", net)
    if env.get("VM_NETWORK_MODEL") and env["VM_NETWORK_MODEL"] not in ("localnet", "linux-bridge"):
        r.fail("VM_NETWORK_MODEL", "must be localnet or linux-bridge (ADR-06)")
    if env.get("STORAGE_BACKEND") and env["STORAGE_BACKEND"] not in ("hpp", "lvms"):
        r.fail("STORAGE_BACKEND", "must be hpp or lvms (ADR-05)")

    # F — files and directories
    ps = env.get("PULL_SECRET_FILE", "")
    if ps:
        p = pathlib.Path(ps).expanduser()
        if not outside_repo(p):
            r.fail("PULL_SECRET_FILE", "must live outside the git working tree (it is a secret)")
        elif not p.is_file():
            r.fail("PULL_SECRET_FILE", f"{p} does not exist (download it from console.redhat.com, Lab 01)")
        else:
            try:
                auths = json.loads(p.read_text()).get("auths")
                if not isinstance(auths, dict) or not auths:
                    r.fail("PULL_SECRET_FILE", "is JSON but has no 'auths' object")
            except (ValueError, AttributeError):
                r.fail("PULL_SECRET_FILE", "is not valid JSON")
    sk = env.get("SSH_PUBLIC_KEY_FILE", "")
    if sk:
        p = pathlib.Path(sk).expanduser()
        if not p.is_file():
            r.fail("SSH_PUBLIC_KEY_FILE", f"{p} does not exist (ssh-keygen -t ed25519)")
        elif not re.match(r"^(ssh-(ed25519|rsa)|ecdsa-sha2-|sk-)\S* \S+", p.read_text().strip()):
            r.fail("SSH_PUBLIC_KEY_FILE", "does not look like an OpenSSH public key")
    md = env.get("MIRROR_DIR", "")
    if md:
        p = pathlib.Path(md)
        if not p.is_absolute():
            r.fail("MIRROR_DIR", "must be an absolute path")
        elif p.exists() and not os.access(p, os.W_OK):
            r.fail("MIRROR_DIR", f"{p} is not writable by {os.environ.get('USER', 'this user')}: sudo chown -R \"$USER:$USER\" {p}")
    idir = env.get("INSTALL_DIR", "")
    if idir:
        if not pathlib.Path(idir).is_absolute():
            r.fail("INSTALL_DIR", "must be an absolute path")
        elif not outside_repo(idir):
            r.fail("INSTALL_DIR", "must be outside the git working tree (the installer writes kubeconfig and the pull secret there, ADR-08)")

    # Derived block must still equal its formula.
    if all(env.get(k) for k in ("MIRROR_REGISTRY_HOSTNAME", "MIRROR_REGISTRY_PORT", "MIRROR_DIR")):
        for key, formula in DERIVED.items():
            expect = formula(env)
            if env.get(key) != expect:
                r.fail(key, f"is derived and must equal {expect} (do not edit the derived block)")

    # Every address is used once (the registry may share the bastion host).
    seen = {}
    addr_keys = ["NETWORK_GATEWAY", "API_VIP", "INGRESS_VIP", *[f"{n}_IP" for n in NODES],
                 "BASTION_IP", "MIRROR_REGISTRY_IP", "NTP_VM_IP"]
    pairs = [(k, env.get(k, "")) for k in addr_keys] + [("DNS_VM_IPS", ip) for ip in raw_dns]
    for key, ip in pairs:
        if not ip:
            continue
        if ip in seen and not {key, seen[ip]} == {"BASTION_IP", "MIRROR_REGISTRY_IP"}:
            r.fail(key, f"{ip} is already used by {seen[ip]}")
        seen.setdefault(ip, key)

    if probe and not r.errors:
        for key in ("API_VIP", "INGRESS_VIP"):
            res = subprocess.run(["ping", "-c1", "-W1", env[key]], stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL, check=False)
            if res.returncode == 0:
                r.fail(key, f"{env[key]} answers ping before install; another host owns it")
    return r


def cmd_validate(env, args):
    r = validate(env, probe=args.probe)
    order = ["ENV_SCHEMA_VERSION"] + [k for _, k in REGISTER] + list(DERIVED)
    for key, msg in r.warnings:
        print(f"[WARN] {FIELD_ID.get(key, '--')} {key}: {msg}", file=sys.stderr)
    for key in sorted(r.errors, key=lambda k: order.index(k) if k in order else len(order)):
        print(f"[FAIL] {FIELD_ID.get(key, '--')} {key}: {r.errors[key]}", file=sys.stderr)
    if r.errors:
        print(f"validate-env: {len(r.errors)} key(s) violate the field register "
              "(docs/labs/03-checklist.md)", file=sys.stderr)
        return 1
    print("validate-env: PASS — .env satisfies every field-register rule", file=sys.stderr)
    return 0


# --------------------------------------------------------------------------- derived values
def derived_value(env, key):
    """Values computed from .env keys; each exists so no template hard-codes a site fact."""
    if key in env and env[key] != "":
        return env[key]
    if key in DERIVED:
        return DERIVED[key](env)
    simple = {
        "OCP_MINOR": lambda: ".".join(env_get(env, "OCP_VERSION").split(".")[:2]),
        "MACHINE_NETWORK_PREFIX": lambda: str(machine_net(env).prefixlen),
        "MACHINE_NETWORK_NETMASK": lambda: str(machine_net(env).netmask),
        "TIME_UPSTREAM": lambda: time_upstream(env),
        "DNS_VM1_IP": lambda: dns_vm_ips(env)[0],
        "DNS_VM2_IP": lambda: dns_vm_ips(env)[1],
        "VM_MAC": lambda: vm_mac(env_get(env, "VM_IP")),
        "REVERSE_ZONE": lambda: reverse_zone(env)[0],
        "REGISTRY_RELNAME": lambda: env_get(env, "MIRROR_REGISTRY_HOSTNAME")[: -len("." + env_get(env, "BASE_DOMAIN"))],
        "SSH_PUBLIC_KEY": lambda: read_file(pathlib.Path(env_get(env, "SSH_PUBLIC_KEY_FILE")).expanduser(), "SSH public key").strip(),
        "VM_STORAGE_CLASS": lambda: {"hpp": "hostpath-csi", "lvms": "lvms-vg1"}[env_get(env, "STORAGE_BACKEND")],
        "RHEL_GUEST_IMAGE_URL": lambda: guest_image_url(env),
        # Both DNS VMs are independent primaries loading identical files (no zone transfer),
        # so the serial is never compared; a constant keeps renders byte-identical (NFR-2).
        "ZONE_SERIAL": lambda: "1",
        "NODE_CHRONY_CONF_B64": lambda: base64.b64encode(render_text(
            env, REPO_ROOT / "manifests/production/ntp-vm/node-chrony.conf.template").encode()).decode(),
    }
    ptr = re.fullmatch(r"(BASTION|REGISTRY|CP0[123]|DNS_VM[12]|NTP_VM|API_VIP)_PTR", key)
    if ptr:
        src = {"REGISTRY": "MIRROR_REGISTRY_IP", "API_VIP": "API_VIP"}.get(ptr.group(1), f"{ptr.group(1)}_IP")
        ip = derived_value(env, src) if src.startswith("DNS_VM") else env_get(env, src)
        return ptr_owner(env, ip)
    if key in simple:
        return simple[key]()
    raise Fail(f"template token ${{{key}}} is neither a .env key nor a derived value")


def guest_image_url(env):
    """docker:// URL of the pinned RHEL guest image inside the mirror registry (FR-H7).
    The digest's single source is the ImageSet that produced the archive (FR-B6)."""
    data = yaml_load(env_get(env, "IMAGESET_CONFIG"))
    for item in (data.get("mirror", {}).get("additionalImages") or []):
        name = item.get("name", "")
        m = re.fullmatch(r"registry\.redhat\.io/(rhel9/rhel-guest-image@sha256:[0-9a-f]{64})", name)
        if m:
            return f"docker://{derived_value(env, 'MIRROR_REGISTRY')}/{m.group(1)}"
    raise Fail(f"no digest-pinned rhel9/rhel-guest-image in {env['IMAGESET_CONFIG']} (re-run Lab 06 step 6.1)")


# --------------------------------------------------------------------------- text templates
def render_text(env, template):
    """Replace ${KEY} with .env or derived values. A multi-line value must stand alone on
    its line and is re-indented to that column, so block scalars stay valid (FR-D3 class)."""
    text = pathlib.Path(template).read_text()
    out_lines = []
    for line in text.splitlines(keepends=True):
        def sub(match):
            value = derived_value(env, match.group(1))
            if "\n" in value:
                indent = line[: len(line) - len(line.lstrip())]
                if line.strip() != match.group(0):
                    raise Fail(f"{template}: multi-line ${{{match.group(1)}}} must be alone on its line")
                return value.rstrip("\n").replace("\n", "\n" + indent)
            return value
        out_lines.append(TOKEN.sub(sub, line))
    return "".join(out_lines)


def cmd_text(env, args):
    text = render_text(env, args.template)
    assert_clean(text, args.out)
    if args.out.endswith((".yaml", ".yml")):
        list(yaml_module().safe_load_all(text))  # raises on a parse error
    write_out(args.out, text, 0o600)
    return 0


# --------------------------------------------------------------------------- install-config
def idms_sources(env):
    """imageDigestSources copied from oc-mirror's idms-oc-mirror.yaml, never hard-coded (FR-D1)."""
    path = pathlib.Path(derived_value(env, "CLUSTER_RESOURCES_DIR")) / "idms-oc-mirror.yaml"
    yaml = yaml_module()
    sources = []
    for doc in yaml.safe_load_all(read_file(path, "oc-mirror IDMS (run Lab 06 step 6.8 first)")):
        if doc and doc.get("kind") == "ImageDigestMirrorSet":
            for item in doc.get("spec", {}).get("imageDigestMirrors", []):
                sources.append({"mirrors": list(item["mirrors"]), "source": item["source"]})
    needed = {"quay.io/openshift-release-dev/ocp-release", "quay.io/openshift-release-dev/ocp-v4.0-art-dev"}
    missing = needed - {s["source"] for s in sources}
    if missing:
        raise Fail(f"{path} does not map {', '.join(sorted(missing))}; the release was not mirrored")
    return sources


def cmd_install_config(env, args):
    ic = yaml_load(REPO_ROOT / "install-config/install-config.yaml.template")
    auth = json.loads(read_file(derived_value(env, "AUTH_FILE"), "merged auth file (Lab 06 step 6.8)"))
    registry = derived_value(env, "MIRROR_REGISTRY")
    if registry not in auth.get("auths", {}):
        raise Fail(f"AUTH_FILE has no auths entry for {registry}; run ./scripts/04-mirror-ocp-images.sh load (FR-D2)")
    pem = read_file(derived_value(env, "REGISTRY_CA_FILE"), "registry CA (Lab 06 step 6.6)").replace("\r", "")
    if "-----BEGIN CERTIFICATE-----" not in pem:
        raise Fail("REGISTRY_CA_FILE holds no PEM certificate")

    ic["baseDomain"] = env_get(env, "BASE_DOMAIN")
    ic["metadata"]["name"] = env_get(env, "CLUSTER_NAME")
    ic["networking"]["clusterNetwork"][0]["cidr"] = env_get(env, "CLUSTER_NETWORK_CIDR")
    ic["networking"]["serviceNetwork"] = [env_get(env, "SERVICE_NETWORK_CIDR")]
    ic["networking"]["machineNetwork"][0]["cidr"] = env_get(env, "MACHINE_NETWORK_CIDR")
    ic["platform"]["baremetal"]["apiVIPs"] = [env_get(env, "API_VIP")]
    ic["platform"]["baremetal"]["ingressVIPs"] = [env_get(env, "INGRESS_VIP")]
    ic["pullSecret"] = json.dumps(auth, separators=(",", ":"))
    ic["sshKey"] = derived_value(env, "SSH_PUBLIC_KEY")
    ic["additionalTrustBundle"] = pem.strip() + "\n"
    ic["imageDigestSources"] = idms_sources(env)
    if ic["compute"][0]["replicas"] != 0 or ic["controlPlane"]["replicas"] != 3:
        raise Fail("install-config skeleton must keep compute replicas 0 and controlPlane replicas 3 (FR-A2)")

    text = yaml_dump(ic)
    assert_clean(text, args.out)
    yaml_module().safe_load(text)
    write_out(args.out, text, 0o600)
    return 0


# --------------------------------------------------------------------------- agent-config
def node_host(env, n):
    nics = parse_nics(env_get(env, f"{n}_NICS"))
    ports = [name for name, _ in nics]
    mtu = int(env_get(env, "MTU"))
    bond = {
        "name": "bond0",
        "type": "bond",
        "state": "up",
        "mtu": mtu,
        "link-aggregation": {"mode": "802.3ad", "options": {"miimon": "100"}, "port": ports},
        "ipv4": {"enabled": True, "dhcp": False,
                 "address": [{"ip": env_get(env, f"{n}_IP"), "prefix-length": machine_net(env).prefixlen}]},
        "ipv6": {"enabled": False},
    }
    members = [{"name": p, "type": "ethernet", "state": "up", "mtu": mtu,
                "ipv4": {"enabled": False}, "ipv6": {"enabled": False}} for p in ports]
    return {
        "hostname": env_get(env, f"{n}_HOSTNAME"),
        "role": "master",
        "rootDeviceHints": {"deviceName": env_get(env, f"{n}_ROOT_DEVICE")},
        "interfaces": [{"name": name, "macAddress": mac} for name, mac in nics],
        "networkConfig": {
            "interfaces": [bond, *members],
            "dns-resolver": {"config": {"search": [env_get(env, "BASE_DOMAIN")],
                                        "server": [env_get(env, "BASTION_IP")]}},
            "routes": {"config": [{"destination": "0.0.0.0/0",
                                   "next-hop-address": env_get(env, "NETWORK_GATEWAY"),
                                   "next-hop-interface": "bond0"}]},
        },
    }


def cmd_agent_config(env, args):
    ac = yaml_load(REPO_ROOT / "install-config/agent-config.yaml.template")
    ac["metadata"]["name"] = env_get(env, "CLUSTER_NAME")
    ac["rendezvousIP"] = env_get(env, "RENDEZVOUS_IP")
    ac["additionalNTPSources"] = [time_upstream(env)]
    ac["hosts"] = [node_host(env, n) for n in NODES]

    text = yaml_dump(ac)
    assert_clean(text, args.out)
    rendered = {h["macAddress"] for host in yaml_module().safe_load(text)["hosts"] for h in host["interfaces"]}
    wanted = {mac for n in NODES for _, mac in parse_nics(env[f"{n}_NICS"])}
    if rendered != wanted or len(rendered) != 12:
        raise Fail("rendered MAC set differs from .env (AT-01)")
    write_out(args.out, text, 0o600)
    return 0


# --------------------------------------------------------------------------- ImageSet
def cmd_imageset(env, args):
    isc = yaml_load(REPO_ROOT / "mirror/imageset-config.yaml.template")
    profiles = yaml_load(REPO_ROOT / "mirror/imageset-profiles.yaml")
    digest = env.get("RHEL_GUEST_IMAGE_DIGEST", "")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise Fail("RHEL_GUEST_IMAGE_DIGEST must be set to sha256:<64 hex> (scripts/01 resolves it)")
    minor = derived_value(env, "OCP_MINOR")
    channel = isc["mirror"]["platform"]["channels"][0]
    channel.update({"name": env_get(env, "OCP_CHANNEL"),
                    "minVersion": env_get(env, "OCP_VERSION"), "maxVersion": env_get(env, "OCP_VERSION")})

    selected = ["default"] + (["lvms"] if env_get(env, "STORAGE_BACKEND") == "lvms" else [])
    if args.profile != "default":
        selected.append(args.profile)
    packages = []
    for name in selected:
        if name not in profiles:
            raise Fail(f"unknown ImageSet profile '{name}' (see mirror/imageset-profiles.yaml)")
        for pkg in profiles[name]["operators"]:
            packages.append({"name": pkg["name"],
                             "channels": [{"name": pkg["channel"].replace("${OCP_MINOR}", minor)}]})
    isc["mirror"]["operators"][0]["catalog"] = f"registry.redhat.io/redhat/redhat-operator-index:v{minor}"
    isc["mirror"]["operators"][0]["packages"] = packages
    isc["mirror"]["additionalImages"] = [{"name": f"registry.redhat.io/rhel9/rhel-guest-image@{digest}"}]

    text = yaml_dump(isc)
    assert_clean(text, args.out)
    if ":latest" in text:
        raise Fail("ImageSet must not reference :latest (NFR-8)")
    write_out(args.out, text, 0o644)
    return 0


# --------------------------------------------------------------------------- lookups
def cmd_catalog_source(env, _args):
    """metadata.name of the CatalogSource oc-mirror generated for redhat-operator-index (FR-G1)."""
    yaml = yaml_module()
    found = []
    for path in sorted(pathlib.Path(derived_value(env, "CLUSTER_RESOURCES_DIR")).glob("cs-*.yaml")):
        for doc in yaml.safe_load_all(path.read_text()):
            if doc and doc.get("kind") == "CatalogSource" and "redhat-operator-index" in doc["spec"].get("image", ""):
                found.append(doc["metadata"]["name"])
    if len(found) != 1:
        raise Fail(f"expected one redhat-operator-index CatalogSource in cluster-resources, found {found or 'none'}")
    print(found[0])
    return 0


def cmd_value(env, args):
    print(derived_value(env, args.key))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    v = sub.add_parser("validate")
    v.add_argument("--probe", action="store_true", help="also ping the VIPs (they must not answer before install)")
    for name in ("install-config", "agent-config"):
        sub.add_parser(name).add_argument("out")
    i = sub.add_parser("imageset")
    i.add_argument("out")
    i.add_argument("--profile", default="default")
    t = sub.add_parser("text")
    t.add_argument("template")
    t.add_argument("out")
    sub.add_parser("catalog-source")
    sub.add_parser("value").add_argument("key")
    args = parser.parse_args()

    handlers = {"validate": cmd_validate, "install-config": cmd_install_config, "agent-config": cmd_agent_config,
                "imageset": cmd_imageset, "text": cmd_text, "catalog-source": cmd_catalog_source, "value": cmd_value}
    try:
        return handlers[args.cmd](dict(os.environ), args)
    except Fail as exc:
        print(f"[ERROR] render.py {args.cmd}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
