# 07 — Boot Cluster Nodes from the ISO (BMC)

## Goal

Boot every OpenShift node from the Agent discovery ISO using BMC virtual media — **not PXE**.

## WHERE

- Bastion: holds `install-config/agent.x86_64.iso`  
- Each node BMC web UI (Lenovo XCC, Dell iDRAC, HPE iLO, etc.)

## WHY this lab exists

The ISO contains the discovery agent. When a node boots from it, it registers with the Assisted Service (rendezvous node) using the MAC/IP map from `agent-config.yaml`. That is how bare metal becomes an OpenShift node without DHCP.

## DO — copy ISO if needed

If BMC cannot read a file from the bastion network share, copy ISO to your admin laptop and upload via BMC virtual media.

## DO — on each node BMC

1. Open BMC in a browser (`https://<BMC-IP>`)  
2. Open **Remote Console** / **Virtual Media**  
3. Map `agent.x86_64.iso` as a virtual CD/DVD  
4. Set one-time boot to CD/virtual CD  
5. Reboot the node  
6. Repeat for **all** control-plane and worker nodes  

### Order tip

Boot control-plane nodes first (especially the rendezvous IP node), then workers. All can be up before install finishes.

## WHY not PXE here

PXE would need DHCP options pointing at a TFTP/HTTP server you do not have in a greenfield dark site. BMC virtual CD only needs:

- BMC network reachability from your admin browser  
- The ISO file  

## VERIFY

On bastion, while nodes are booting:

```bash
export PATH="${MIRROR_DIR}/clients:${PATH}"
openshift-install agent wait-for bootstrap-complete --dir=install-config/ --log-level=info
# This can take a while; first success means rendezvous/bootstrap path is alive
```

If nothing happens for a long time, re-check MACs and that nodes actually booted the virtual CD (not local disk).

## FAILS IF

| Problem | Symptom |
|---|---|
| Node boots old local OS | Forgot one-time CD boot |
| Wrong MAC in agent-config | BMC boots ISO; installer ignores host |
| Firewall blocks node↔node / node↔registry | Bootstrap never completes |

## Next

→ [08 — Finish install and mirror integration](08-install-and-mirror-integration.md)
