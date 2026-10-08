#!/bin/sh
# Container entrypoint for the FRR routers.
#
# Why this exists:
#  1. Docker does not guarantee interface names (eth0, eth1, ...) for a given
#     network, so frr.conf refers to interfaces by their IP address,
#     written as @IF[10.10.12.2]. This script swaps in the real name at start-up.
#  2. The config directory is mounted read-only at /config and copied to
#     /etc/frr, so FRR never writes back into the repository.
set -e

mkdir -p /etc/frr
cp /config/daemons /config/vtysh.conf /config/frr.conf /etc/frr/

# ip -o -4 addr show -> "21: eth0    inet 10.10.12.2/24 brd ..."
ip -o -4 addr show | while read -r _ ifname _ cidr _; do
  addr="${cidr%%/*}"
  ifname="${ifname%%@*}"
  sed -i "s|@IF\[$addr\]|$ifname|g" /etc/frr/frr.conf
done

if grep -q '@IF\[' /etc/frr/frr.conf; then
  echo "frr-entrypoint: unresolved interface placeholder in frr.conf:" >&2
  grep '@IF\[' /etc/frr/frr.conf >&2
  exit 1
fi

chown -R frr:frr /etc/frr 2>/dev/null || true
chmod 640 /etc/frr/frr.conf 2>/dev/null || true

exec /sbin/tini -- /usr/lib/frr/docker-start
