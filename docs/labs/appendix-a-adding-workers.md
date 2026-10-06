# Appendix A — Adding workers later

> **Grade:** outside the v2.0 path. The tutorial builds a compact cluster with
> `compute.replicas: 0`; this page is the only place dedicated workers appear.

The Agent installer waits for `controlPlane.replicas + compute.replicas` hosts, so worker hosts must
**never** be listed in the initial `install-config.yaml` of a three-server rack: with two phantom
workers it waits for five hosts that do not exist (FR-A2).

Once the compact cluster is healthy, add a dedicated worker (for example `wk01`) as a day-2
operation:

1. Cable and prepare the server as in [Lab 05](05-compute-resources.md) (RAID1, SVM, four bond members).
2. Add its A and PTR records to the bastion (`scripts/02-bootstrap-dns-ntp.sh`) and to the DNS VM zone template.
3. Generate a node ISO from the running cluster with `oc adm node-image create` and boot it through XCC
   virtual media (verify on 4.22:
   [Adding worker nodes to an on-premise cluster](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/nodes/)).
4. Approve the node's CSRs (`oc get csr`, `oc adm certificate approve …`).

The field register has no worker keys in v2.0; a future schema version would add `WKnn_*` fields
with the same rules as group C.
