# Appendix B — Network boot

> **Grade:** out of scope for v2.0 (ADR-04).

**Network boot** is the category; PXE (DHCP + TFTP, often chained to iPXE) is one mechanism and
UEFI HTTP Boot is another. These labs boot nodes from the Agent ISO through XCC virtual media and
helper hosts from a `mkksiso`-built DVD, because network boot presupposes DHCP plus TFTP or HTTP
services that a greenfield dark site does not have, and building them first is a second project.

If a site **already** runs network boot, the installer-supported route is
`openshift-install agent create pxe-files`, not a hand-maintained pxelinux or TFTP menu (verify on 4.22:
[Agent-based Installer documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/installing_an_on-premise_cluster_with_the_agent-based_installer/)).
