#!/usr/bin/env bash
# Shared helpers for the lab scripts.

PASS=0
FAIL=0

vt() { docker compose exec -T "$1" vtysh -c "$2"; }

# retry <timeout-seconds> <command...>: run until it succeeds or time runs out
retry() {
  local timeout="$1"; shift
  local waited=0
  until "$@" >/dev/null 2>&1; do
    sleep 3
    waited=$((waited + 3))
    if [ "$waited" -ge "$timeout" ]; then return 1; fi
  done
  return 0
}

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $name"; PASS=$((PASS + 1))
  else
    echo "FAIL  $name"; FAIL=$((FAIL + 1))
  fi
}

# check_retry <name> <command...>: like check, but waits up to 90 s for the
# condition to become true. BGP and OSPF settle at different times, so a single
# immediate check can fail even though the lab is healthy a few seconds later.
check_retry() {
  local name="$1"; shift
  if retry 90 "$@"; then
    echo "PASS  $name"; PASS=$((PASS + 1))
  else
    echo "FAIL  $name"; FAIL=$((FAIL + 1))
  fi
}

ospf_full()   { [ "$(vt "$1" 'show ip ospf neighbor' | grep -c Full)" -ge "$2" ]; }
bgp_estab()   { [ "$(vt "$1" 'show ip bgp neighbors' | grep -c 'BGP state = Established')" -ge "$2" ]; }
ping_ab()     { docker compose exec -T host-a ping -c 2 -W 2 10.10.200.10; }
trace_ab()    { docker compose exec -T host-a traceroute -n -w 1 -q 1 10.10.200.10; }
path_has()    { trace_ab 2>&1 | grep -q "$1"; }

summary() {
  echo
  echo "Result: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
}
