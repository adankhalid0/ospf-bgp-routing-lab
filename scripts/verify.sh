#!/usr/bin/env bash
# Verifies that OSPF and BGP converged and that host-a can reach host-b.
# Run from the repository root:  bash scripts/verify.sh
set -u
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

echo "Waiting for the control plane to converge (up to 120 s)..."
retry 120 ping_ab || echo "(host-a still cannot reach host-b, checks below will show why)"

echo
echo "== OSPF adjacencies (area 0) =="
check_retry "r1 has 2 OSPF neighbors in state Full" ospf_full r1 2
check_retry "r2 has 2 OSPF neighbors in state Full" ospf_full r2 2
check_retry "r3 has 2 OSPF neighbors in state Full" ospf_full r3 2

echo
echo "== BGP sessions =="
check_retry "r1: iBGP to r2, r3 and eBGP to r4 are Established" bgp_estab r1 3
check_retry "r2: iBGP to r1 and r3 are Established"             bgp_estab r2 2
check_retry "r3: iBGP to r1, r2 and eBGP to r4 are Established" bgp_estab r3 3
check_retry "r4: eBGP to r1 and r3 are Established"             bgp_estab r4 2

echo
echo "== Routing =="
check_retry "r2 learned 10.10.200.0/24 via BGP"  bash -c "docker compose exec -T r2 vtysh -c 'show ip bgp 10.10.200.0/24' | grep -q 'localpref 200'"
check_retry "r4 learned 10.10.100.0/24 via BGP"  bash -c "docker compose exec -T r4 vtysh -c 'show ip bgp' | grep -q '10.10.100.0/24'"

echo
echo "== Data plane =="
check_retry "host-a can ping host-b"                 ping_ab
check_retry "traffic from host-a to host-b goes via r1 (primary)" path_has 10.10.12.2

summary
