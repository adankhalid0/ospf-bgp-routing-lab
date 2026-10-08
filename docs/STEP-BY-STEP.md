# Step-by-step: run the lab and verify it

These steps work in **Git Bash on Windows** (with Docker Desktop), WSL, Linux
and macOS. Take a screenshot at each step marked with a camera if you want to
document your own run.

## 1. Check Docker

```bash
docker --version
docker compose version
```

Docker Desktop must be running (whale icon in the system tray) before you
continue.

## 2. Get the code

```bash
git clone https://github.com/adankhalid0/ospf-bgp-routing-lab.git
cd ospf-bgp-routing-lab
```

## 3. Validate the compose file

```bash
docker compose config -q && echo "compose file is valid"
```

## 4. Start the lab

```bash
docker compose up -d
docker compose ps
```

You should see six containers running: `r1`, `r2`, `r3`, `r4`, `host-a` and
`host-b`. (Screenshot: `docker compose ps`.)

Wait one to two minutes for OSPF and BGP to converge.

## 5. Check OSPF

```bash
docker compose exec r2 vtysh -c "show ip ospf neighbor"
```

Expected: two neighbors (r1 and r3) in state `Full`. (Screenshot.)

```bash
docker compose exec r2 vtysh -c "show ip route ospf"
```

Expected: the loopbacks of r1 and r3 and the links between the routers are
learned through OSPF (`O>*`).

## 6. Check BGP

```bash
docker compose exec r1 vtysh -c "show ip bgp summary"
```

Expected: three neighbors for r1 (r2 and r3 are iBGP, r4 is eBGP), each with a
number in the `State/PfxRcd` column instead of `Active` or `Idle`.
(Screenshot.)

```bash
docker compose exec r2 vtysh -c "show ip bgp 10.10.200.0/24"
```

Expected: the route to LAN B is known through both edge routers. The path via
r1 (`1.1.1.1`) is marked `best` because of `localpref 200`. (Screenshot.)

## 7. Test the data plane

```bash
docker compose exec host-a ping -c 3 10.10.200.10
docker compose exec host-a traceroute -n 10.10.200.10
```

Expected path through the primary exit:

```
10.10.100.2   (r2)
10.10.12.2    (r1)
10.10.14.3    (r4)
10.10.200.10  (host-b)
```

(Screenshot.)

## 8. Run the automated checks

```bash
bash scripts/verify.sh
```

All lines should read `PASS`. (Screenshot.)

## 9. Failover

```bash
bash scripts/failover.sh
```

The script stops r1, waits for reconvergence, shows the new path, then starts
r1 again and checks that traffic moves back. During the failure the traceroute
should go through `10.10.23.3` (r3) and `10.10.34.3` (r4). (Screenshot of the
traceroute before, during and after.)

To do the same by hand:

```bash
docker compose stop r1
docker compose exec host-a traceroute -n 10.10.200.10
docker compose exec r2 vtysh -c "show ip bgp 10.10.200.0/24"
docker compose start r1
```

## 10. Clean up

```bash
docker compose down -v
```

## Troubleshooting

| Symptom | Likely cause and fix |
|---------|----------------------|
| `Cannot connect to the Docker daemon` | Start Docker Desktop and wait until it says it is running |
| `Pool overlaps with other one on this address space` | Another Docker network uses one of the 10.10.x.0/24 subnets. Remove it with `docker network ls` and `docker network rm`, or change the subnets in `docker-compose.yml` and the matching `configs/` |
| OSPF neighbors stay in `Init` or `ExStart` | Give it a minute. If it persists, run `docker compose restart` and wait again |
| BGP neighbors stay `Active` | Check that the OSPF routes to the loopbacks exist (`show ip route`), because the iBGP sessions use loopback addresses |
| Config file errors or `permission denied` in the router logs | Make sure the files in `configs/` have LF line endings (the repository includes `.gitattributes` for this) and are readable. Check with `docker compose logs r1` |
| `traceroute: not found` in `host-a` | Re-run with `docker compose up -d --force-recreate host-a` or use `ping` instead |
| Scripts fail with `\r: command not found` | The scripts have Windows line endings. Run `git config core.autocrlf false`, re-clone, and try again |
