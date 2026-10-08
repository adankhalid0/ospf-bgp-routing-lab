#!/usr/bin/env bash
# Simulates the failure of edge router r1 and verifies that traffic moves to r3.
# Run from the repository root:  bash scripts/failover.sh
set -u
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

echo "== Before failure =="
trace_ab
check "baseline: path goes via r1" path_has 10.10.12.2

echo
echo ">> Stopping r1 (simulated edge router failure)"
docker compose stop r1 >/dev/null

echo "Waiting for BGP/OSPF to reconverge (up to 120 s)..."
retry 120 bash -c "docker compose exec -T host-a traceroute -n -w 1 -q 1 10.10.200.10 | grep -q 10.10.23.3"

echo
echo "== During failure =="
trace_ab
check "traffic still reaches host-b"        ping_ab
check "path moved to r3 (backup)"           path_has 10.10.23.3

echo
echo ">> Starting r1 again"
docker compose start r1 >/dev/null

echo "Waiting for r1 to take over again (local-pref 200, up to 150 s)..."
retry 150 bash -c "docker compose exec -T host-a traceroute -n -w 1 -q 1 10.10.200.10 | grep -q 10.10.12.2"

echo
echo "== After recovery =="
trace_ab
check "path returned to r1 (primary)" path_has 10.10.12.2

summary
