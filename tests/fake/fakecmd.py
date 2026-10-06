#!/usr/bin/env python3
"""Stand-in for the external tools the scripts call, used by tests/run-scripts.sh.

Invoked as `fakecmd.py <tool> <args...>` through thin wrappers named after each tool. It
behaves like the real tool closely enough to exercise every script's control flow, and it
fails the way the real tool fails where the scripts depend on that:

  - `oc apply` parses every document it receives (a broken heredoc fails here as on a
    cluster) and stores it; `oc get` / `oc wait` answer only for stored objects.
  - `oc wait vmi/<name>` fails with NotFound, because right after `oc apply` of a
    VirtualMachine its VMI does not exist yet (the DataVolume is still importing).
  - `openshift-install agent create image` consumes its two input files, as the real one does.

Fault injection through the environment: FAKE_NODE_NOTREADY=1, FAKE_VIP_TAKEN=1.
State lives in $FAKE_STATE (JSON); fixtures in $FAKE_DIR.
"""
import base64
import json
import os
import pathlib
import re
import sys

import yaml

TOOL, ARGS = sys.argv[1], sys.argv[2:]
ENV = os.environ
STATE = pathlib.Path(ENV["FAKE_STATE"])
FAKE_DIR = pathlib.Path(ENV["FAKE_DIR"])
LOG = pathlib.Path(ENV.get("FAKE_LOG", "/dev/null"))
NODES = [ENV.get(f"MW0{i}_HOSTNAME", f"mw0{i}") for i in (1, 2, 3)]

KINDS = {  # resource names as typed on the command line -> kind
    "nncp": "NodeNetworkConfigurationPolicy", "vm": "VirtualMachine", "vmi": "VirtualMachineInstance",
    "mcp": "MachineConfigPool", "catalogsource": "CatalogSource", "subscription": "Subscription",
    "csv": "ClusterServiceVersion", "hyperconverged": "HyperConverged", "storageclass": "StorageClass",
    "datavolume": "DataVolume", "hostpathprovisioner": "HostPathProvisioner", "lvmcluster": "LVMCluster",
    "storageprofile": "StorageProfile", "tridentbackendconfig": "TridentBackendConfig", "tbc": "TridentBackendConfig",
    "tridentorchestrator": "TridentOrchestrator", "operatorhub": "OperatorHub", "namespace": "Namespace",
    "configs.samples.operator.openshift.io": "Config",
}


def log(msg):
    with LOG.open("a") as f:
        f.write(f"{TOOL} {msg}\n")


def die(msg, code=1):
    print(f"fake {TOOL}: {msg}", file=sys.stderr)
    sys.exit(code)


def load():
    return json.loads(STATE.read_text()) if STATE.exists() else {"objects": {}, "registry_installed": False}


def save(state):
    STATE.write_text(json.dumps(state, indent=1))


def opt(name, default=None):
    for i, a in enumerate(ARGS):
        if a == name and i + 1 < len(ARGS):
            return ARGS[i + 1]
        if a.startswith(name + "="):
            return a.split("=", 1)[1]
    return default


def key(kind, name, ns=None):
    return f"{kind}/{ns or '-'}/{name}"


def find(state, kind, name, ns=None):
    if kind == "MachineConfigPool" and name in ("master", "worker"):
        return {"kind": kind, "metadata": {"name": name}}  # exists on every cluster
    if kind == "ClusterServiceVersion":  # OLM creates the CSV once a Subscription resolves
        sub = name.rsplit(".v", 1)[0]
        return find(state, "Subscription", sub, ns)
    for k, obj in state["objects"].items():
        if k.split("/")[0] == kind and k.split("/")[2] == name and (ns is None or k.split("/")[1] in (ns, "-")):
            return obj
    return None


# --------------------------------------------------------------------------- oc
def oc_apply(state):
    src = opt("-f")
    texts = []
    if src == "-":
        texts.append(sys.stdin.read())
    elif src and pathlib.Path(src).is_dir():
        texts += [p.read_text() for p in sorted(pathlib.Path(src).iterdir()) if p.suffix in (".yaml", ".yml", ".json")]
    elif src:
        texts.append(pathlib.Path(src).read_text())
    else:
        die("apply needs -f")
    n = 0
    for text in texts:
        try:
            docs = list(yaml.safe_load_all(text))
        except yaml.YAMLError as exc:
            die(f"error parsing input: {exc}")
        for doc in docs:
            if not doc:
                continue
            for field in ("apiVersion", "kind", "metadata"):
                if field not in doc:
                    die(f"error validating data: {field} not set")
            ns = doc["metadata"].get("namespace") or opt("-n")
            state["objects"][key(doc["kind"], doc["metadata"]["name"], ns)] = doc
            print(f"{doc['kind'].lower()}/{doc['metadata']['name']} configured")
            n += 1
    if n == 0:
        die("no objects passed to apply")
    save(state)


def jsonpath(state, kind, names, ns, path):
    if kind == "Node":
        if ".items[*].metadata.name" in path:
            return " ".join(NODES)
        if "devices.kubevirt.io/kvm" in path or "devices\\.kubevirt\\.io/kvm" in path:
            return "\n".join(f"{n} 1k" for n in NODES)
    if kind == "CatalogSource":
        if ".items[*].metadata.name" in path:
            return " ".join(k.split("/")[2] for k in state["objects"] if k.startswith("CatalogSource/"))
        return "READY" if find(state, kind, names[0], ns) else ""
    if kind == "StorageClass" and "is-default-class" in path:
        out = [o["metadata"]["name"] for k, o in state["objects"].items() if k.startswith("StorageClass/")
               and (o["metadata"].get("annotations") or {}).get("storageclass.kubernetes.io/is-default-class") == "true"]
        return "\n".join(out)
    if kind == "VirtualMachineInstance" and "nodeName" in path:
        return " ".join(NODES[i % 3] for i, _ in enumerate(names))
    obj = find(state, kind, names[0], ns) if names else None
    if obj is None:
        return None
    if "installedCSV" in path:
        return f"{names[0]}.v0.0.1"
    if "configuration.name" in path or ".spec.configuration.source" in path:
        pass
    elif "lastObservedState" in path or ".status.phase" in path or ".status.state" in path:
        return {"DataVolume": "Succeeded", "TridentBackendConfig": "Bound", "LVMCluster": "Ready"}.get(kind, "Succeeded")
    elif "conditions" in path:
        return "True"
    if "disableAllDefaultSources" in path:
        return str(obj.get("spec", {}).get("disableAllDefaultSources", "")).lower()
    if ".spec.configuration.source" in path:
        return " ".join(k.split("/")[2] for k in state["objects"] if k.startswith("MachineConfig/"))
    if "configuration.name" in path:
        return "rendered-master-0123"  # spec and status agree once the rollout is done
    return ""


def oc_get(state):
    target = ARGS[1]
    ns = opt("-n")
    out = opt("-o", "")
    resources = target.split(",")
    names = [a for a in ARGS[2:] if not a.startswith("-") and a not in (ns, out) and "=" not in a]
    if len(resources) > 1 or out in ("wide", "yaml") or out == "" and "--no-headers" not in ARGS and target not in ("nodes", "co"):
        print(f"(fake listing of {target})")
        return
    if target in ("nodes", "node"):
        kind = "Node"
        if "--no-headers" in ARGS:
            for i, n in enumerate(NODES):
                status = "NotReady" if ENV.get("FAKE_NODE_NOTREADY") and i == 1 else "Ready"
                print(f"{n}   {status}   control-plane,master,worker   1d   v1.35.0")
            return
    elif target == "co":
        for c in ("authentication", "etcd", "kube-apiserver", "machine-config"):
            print(f"{c}   4.22.3   True   False   False   1d")
        return
    else:
        kind = KINDS.get(target.split("/")[0])
        if kind is None:
            die(f"unhandled get {target}", 3)
        if "/" in target:
            names = [target.split("/", 1)[1]]
    if out == "name":
        print("\n".join(f"{target}/{k.split('/')[2]}" for k in state["objects"] if k.startswith(kind + "/")))
        return
    if out.startswith("jsonpath="):
        value = jsonpath(state, kind, names, ns, out[len("jsonpath="):])
        if value is None:
            die(f'Error from server (NotFound): {target} "{names[0] if names else ""}" not found')
        print(value)
        return
    if kind != "Node" and names and not find(state, kind, names[0], ns):
        die(f'Error from server (NotFound): {target} "{names[0]}" not found')
    print(f"(fake {target} {' '.join(names)})")


def oc_wait(state):
    target = ARGS[1]
    res, _, name = target.partition("/")
    kind = KINDS.get(res)
    if kind == "VirtualMachineInstance":
        die(f'Error from server (NotFound): virtualmachineinstances.kubevirt.io "{name}" not found')
    if kind == "MachineConfigPool":
        return
    if kind is None or not find(state, kind, name, opt("-n")):
        die(f'Error from server (NotFound): {target} not found')


def oc_debug():
    cmd = " ".join(ARGS)
    if "/proc/net/bonding/bond0" in cmd:
        print("Ethernet Channel Bonding Driver: v6\n\nBonding Mode: IEEE 802.3ad Dynamic link aggregation\nMII Status: up")
        for i in range(4):
            print(f"\nSlave Interface: port{i}\nMII Status: up\nSpeed: 10000 Mbps")
    elif "/dev/kvm" in cmd:
        return
    else:
        print("(fake debug output)")


def oc_mirror():
    if "--help" in ARGS:
        return
    for flag in ("-c", "--authfile"):
        if not opt(flag) or not pathlib.Path(opt(flag)).is_file():
            die(f"{flag} file missing: {opt(flag)}")
    dests = [a for a in ARGS if a.startswith(("file://", "docker://"))]
    if opt("--from"):  # disk to mirror
        src = pathlib.Path(opt("--from")[len("file://"):])
        if not list(src.glob("mirror_*.tar")):
            die(f"no archive in {src}")
        reg = [d for d in dests if d.startswith("docker://")][0][len("docker://"):]
        auths = json.loads(pathlib.Path(opt("--authfile")).read_text())["auths"]
        if reg not in auths:
            die(f"unauthorized: no credentials for {reg} in --authfile")
        cr = src / "working-dir/cluster-resources"
        cr.mkdir(parents=True, exist_ok=True)
        (cr / "idms-oc-mirror.yaml").write_text(
            "apiVersion: config.openshift.io/v1\nkind: ImageDigestMirrorSet\nmetadata:\n  name: idms-release-0\n"
            "spec:\n  imageDigestMirrors:\n"
            f"    - mirrors: [{reg}/openshift/release]\n      source: quay.io/openshift-release-dev/ocp-v4.0-art-dev\n"
            f"    - mirrors: [{reg}/openshift/release-images]\n      source: quay.io/openshift-release-dev/ocp-release\n")
        isc = yaml.safe_load(pathlib.Path(opt("-c")).read_text())
        for entry in isc["mirror"]["operators"]:
            index = entry["catalog"].split("/")[-1].split(":")[0]
            name = f"cs-{index}-v4-22"
            (cr / f"{name}.yaml").write_text(
                f"apiVersion: operators.coreos.com/v1alpha1\nkind: CatalogSource\nmetadata:\n  name: {name}\n"
                f"  namespace: openshift-marketplace\nspec:\n  image: {reg}/redhat/{index}:v4.22\n  sourceType: grpc\n")
    else:  # mirror to disk
        dest = pathlib.Path([d for d in dests if d.startswith("file://")][0][len("file://"):])
        dest.mkdir(parents=True, exist_ok=True)
        (dest / "mirror_000001.tar").write_bytes(b"fake archive\n")


def oc():
    state = load()
    verb = ARGS[0] if ARGS else ""
    if verb == "mirror":
        oc_mirror()
    elif verb == "apply":
        oc_apply(state)
    elif verb == "get":
        oc_get(state)
    elif verb == "wait":
        oc_wait(state)
    elif verb == "debug":
        oc_debug()
    elif verb == "create" and "--dry-run=client" in ARGS:
        kind, name = ARGS[1], ARGS[2]
        ns = opt("-n")
        meta = {"name": name, **({"namespace": ns} if ns else {})}
        print(yaml.safe_dump({"apiVersion": "v1", "kind": "Namespace" if kind == "namespace" else "ConfigMap", "metadata": meta}))
    elif verb == "annotate":
        sc = find(state, "StorageClass", ARGS[2])
        if sc is None:
            die(f'storageclasses "{ARGS[2]}" not found')
        k, v = ARGS[3].split("=", 1)
        sc["metadata"].setdefault("annotations", {})[k] = v
        save(state)
    elif verb == "patch":
        kind = KINDS.get(ARGS[1].lower(), ARGS[1])
        obj = find(state, kind, ARGS[2]) or {"apiVersion": "v1", "kind": kind, "metadata": {"name": ARGS[2]}}
        obj.setdefault("spec", {}).update(json.loads(opt("-p")).get("spec", {}))
        state["objects"][key(kind, ARGS[2])] = obj
        save(state)
    elif verb in ("delete", "describe", "rollout", "whoami", "version", "cluster-info", "adm"):
        print(f"(fake {verb})")
    else:
        die(f"unhandled verb: {' '.join(ARGS)}", 3)


# --------------------------------------------------------------------------- others
def openshift_install():
    if ARGS[:1] == ["version"]:
        print(f"openshift-install {ENV['OCP_VERSION']}\nrelease image quay.io/openshift-release-dev/ocp-release@sha256:{'0' * 64}")
        return
    d = pathlib.Path(opt("--dir"))
    if ARGS[:3] == ["agent", "create", "image"]:
        for f in ("install-config.yaml", "agent-config.yaml"):
            yaml.safe_load((d / f).read_text())
            (d / f).unlink()  # consumed, like the real installer
        (d / "agent.x86_64.iso").write_bytes(b"fake iso\n")
    elif ARGS[:2] == ["agent", "wait-for"]:
        if ARGS[2] == "install-complete":
            (d / "auth").mkdir(exist_ok=True)
            (d / "auth/kubeconfig").write_text("apiVersion: v1\nkind: Config\n")
    else:
        die(f"unhandled: {' '.join(ARGS)}", 3)


def curl():
    url = [a for a in ARGS if re.match(r"^https?://", a)][0]
    out = opt("-o")
    if "-w" in ARGS:  # status-code probes
        if url.endswith("/v2/") and ENV.get("FAKE_NO_REGISTRY"):
            print("000", end="")
            sys.exit(7)  # connection refused
        code = "401" if url.endswith("/v2/") else "200" if url.endswith("repomd.xml") else "000"
        print(code, end="")
        return
    if "quay.io" in url:
        die("Could not resolve host: quay.io", 6)
    name = url.rsplit("/", 1)[1]
    src = FAKE_DIR / "downloads" / name
    if out and out != "/dev/null":
        if not src.exists():
            die(f"The requested URL returned error: 404 ({name})", 22)
        pathlib.Path(out).write_bytes(src.read_bytes())


def podman():
    state = load()
    if ARGS[:1] == ["ps"]:
        print("quay-app" if state.get("registry_installed") else "")
    elif ARGS[:1] == ["login"]:
        authfile, user, reg = opt("--authfile"), opt("--username"), ARGS[-1]
        password = sys.stdin.read().rstrip("\n")
        if not password:
            die("password required")
        data = json.loads(pathlib.Path(authfile).read_text())
        data.setdefault("auths", {})[reg] = {"auth": base64.b64encode(f"{user}:{password}".encode()).decode()}
        pathlib.Path(authfile).write_text(json.dumps(data))
        print("Login Succeeded!")
    else:
        print(f"(fake podman {' '.join(ARGS)})")


def mirror_registry():
    if ARGS[:1] != ["install"]:
        die("unhandled", 3)
    root = pathlib.Path(opt("--quayRoot"))
    (root / "quay-rootCA").mkdir(parents=True, exist_ok=True)
    (root / "quay-rootCA/rootCA.pem").write_text((FAKE_DIR / "rootCA.pem").read_text())
    state = load()
    state["registry_installed"] = True
    save(state)


def dig():
    server = next((a[1:] for a in ARGS if a.startswith("@")), None)
    if "-x" in ARGS:
        ip = opt("-x")
        for i in (1, 2, 3):
            if ENV.get(f"MW0{i}_IP") == ip:
                print(f"{ENV[f'MW0{i}_HOSTNAME']}.{ENV['BASE_DOMAIN']}.")
        return
    name = [a for a in ARGS if not a.startswith(("@", "+", "-"))][-1]
    cluster = f"{ENV['CLUSTER_NAME']}.{ENV['BASE_DOMAIN']}"
    answer = {f"api.{cluster}": ENV["API_VIP"], f"api-int.{cluster}": ENV["API_VIP"],
              ENV["MIRROR_REGISTRY_HOSTNAME"]: ENV["MIRROR_REGISTRY_IP"]}.get(name)
    if answer is None and name.endswith(f".apps.{cluster}"):
        answer = ENV["INGRESS_VIP"]
    if server and answer:
        print(answer)


def main():
    log(" ".join(ARGS))
    if TOOL in ("oc", "kubectl"):
        oc()
    elif TOOL == "oc-mirror":
        ARGS.insert(0, "mirror")
        oc_mirror()
    elif TOOL == "openshift-install":
        openshift_install()
    elif TOOL == "curl":
        curl()
    elif TOOL == "skopeo":
        print("sha256:" + "ab" * 32)
    elif TOOL == "podman":
        podman()
    elif TOOL == "mirror-registry":
        mirror_registry()
    elif TOOL == "dig":
        dig()
    elif TOOL == "chronyd":
        print("2026-10-06T00:00:00Z System clock wrong by -0.000213 seconds (ignored)", file=sys.stderr)
    elif TOOL == "ping":
        sys.exit(0 if ENV.get("FAKE_VIP_TAKEN") else 1)
    elif TOOL == "rpm":
        for pkg in [a for a in ARGS if not a.startswith("-")]:
            print(f"{pkg}-1.0-1.el9.x86_64")
    elif TOOL == "mountpoint":
        sys.exit(0 if load().get("mounted") else 1)
    elif TOOL == "mount":
        state = load()
        state["mounted"] = True
        save(state)
    elif TOOL == "systemctl" and ARGS[:1] == ["is-enabled"]:
        print("enabled")
    elif TOOL in ("systemctl", "firewall-cmd", "update-ca-trust", "dnf", "nmstatectl", "mkksiso", "dnsmasq"):
        pass
    else:
        die(f"no fake for {TOOL}", 3)


main()
