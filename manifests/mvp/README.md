# MVP manifests — reference only
# MVP DNS/NTP is deployed via scripts/02-bootstrap-dns-ntp.sh on the bastion host
# using dnsmasq and chronyd directly (not Kubernetes manifests).
#
# This directory is reserved for optional containerized MVP services
# if you prefer running dnsmasq in a pod before OCP is installed.
#
# For the standard workflow, use:
#   sudo ./scripts/02-bootstrap-dns-ntp.sh
#
# See docs/05-mvp-network-services.md for details.
