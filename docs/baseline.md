# Baseline — osmocom + TTCN-3 on k8s (single namespace)

Measured on **cn083**, calendar week 22 (2026-05-26/27).
Raw data: `results/week01/` (symlink → `results/week22/`; runs are named by calendar week).

## Host

| Field | Value |
|---|---|
| Hostname | cn083 |
| CPU | Intel Xeon Platinum 8268 @ 2.90 GHz, 48 cores |
| RAM | 187.6 GB (196,702,648 KB) |
| Disk (`/`) | 439 GB total, 34 GB free (92% used) |
| Kernel | 6.8.0-101-generic |
| k3s | v1.35.4+k3s1 |
| Suite revision | 1bd74dc |
| `ulimit -n` (open files) | 1,048,576 |
| `nf_conntrack_max` | 1,572,864 |
| `inotify.max_user_watches` | 65,536 |
| `inotify.max_user_instances` | 128 |
| `ip_local_port_range` | 32768 – 60999 (28,231 ports) |

## Stack

Eight containers run in a single Kubernetes namespace per test instance.

```
                        ┌──────────────┐
                        │  ttcn3-pod   │  ← drives the test
                        └──────┬───────┘
                               │ (TTCN-3 test ports / IP)
                        ┌──────▼───────┐     ┌──────────┐
                        │ msc-test-stub│◄────►│ osmo-hlr │
                        └──────┬───────┘     └──────────┘
                               │ SS7/SCCP (M3UA)
                        ┌──────▼───────┐
                        │  osmo-stp    │  ← SS7 signaling transfer point
                        └──────┬───────┘
                               │ SS7/SCCP (M3UA)
                        ┌──────▼───────┐
                        │  osmo-bsc    │  ← base station controller
                        └──────┬───────┘
                               │ Abis/OML (TCP)
                        ┌──────▼──────────┐
                        │ osmo-bts-virtual│  ← virtual BTS
                        └──────┬──────────┘
                               │ L1CTL (Unix socket)
                        ┌──────▼───────┐
                        │ osmo-virtphy │  ← virtual radio PHY
                        └──────┬───────┘
                               │ L1CTL (Unix socket)
                        ┌──────▼───────┐
                        │ osmo-mobile  │  ← simulated mobile station (UE)
                        └──────────────┘
```

### Component roles

| Image | Role |
|---|---|
| `osmo-bsc` | Base Station Controller — manages radio resources, routes traffic between BTS and MSC via SS7 |
| `osmo-bts-virtual` | Virtual BTS — implements the Abis interface upward and L1CTL downward; no real radio hardware needed |
| `osmo-virtphy` | Virtual PHY — simulates the GSM radio layer; both BTS and the mobile station connect to it via L1CTL sockets |
| `osmo-stp` | Signaling Transfer Point — routes SS7/SCCP messages between BSC and MSC |
| `msc-test-stub` | Stub MSC — controlled by the TTCN-3 pod; sends/receives protocol messages on behalf of a real MSC |
| `osmo-hlr` | Home Location Register — subscriber database; answers GSUP queries from the MSC stub |
| `osmo-mobile` | Simulated mobile station — drives the air-side traffic through virtphy |
| `ttcn3-compiler` | TTCN-3 test pod — compiles and runs the test suite; result verdicts are written to the filesystem |

## Per-phase timing

Phases are recorded in `events.csv` for each run. Definitions:

| Phase label | Meaning |
|---|---|
| `t0` | `kubectl apply` issued |
| `t_apply` | `kubectl apply` returns |
| `t_ready` | all pods `Ready` (k8s readiness gates pass) |
| `t_attached` | L1CTL socket between virtphy and BTS confirmed open |
| `t_test0` | first TTCN-3 verdict line appears |
| `t_testN` | last TTCN-3 verdict line appears |
| `t_teardown` | `kubectl delete namespace` returns |

### Timing summary across measured runs

All values in seconds.

| Run | TCs | bringup | testing | teardown | T\_suite |
|---|---|---|---|---|---|
| 20260527-040108 | 3 (TC_26_7_4_5_1/2/3) | 50.1 | 1995.5 | 46.2 | 2045.6 |
| 20260527-053848 | 2 (TC_26_7_4_5_1/3) | 39.4 | 1097.7 | 50.3 | 1137.1 |
| 20260527-075711 | 5 (mixed) | 36.6 | 262.8 | 53.0 | 299.4 |
| 20260527-074811 | 5 (mixed, short) | 35.0 | 58.0 | 52.9 | 93.0 |
| 20260527-052358 | 1 (TC_26_6_4_1) | 44.7 | 26.6 | 44.8 | 71.3 |
| 20260527-052648 | 1 (TC_26_6_8_5) | 39.7 | 10.7 | — | 50.4 |
| 20260527-052857 | 1 (TC_26_6_13_9) | 41.3 | 13.6 | — | 54.9 |
| 20260527-053109 | 1 (TC_26_8_1_3_4_2) | 44.1 | 27.0 | — | 71.1 |

`bringup` = `t_ready − t0`. `testing` = `t_testN − t_test0`. `teardown` = `t_teardown − t_testN`.

### Bringup breakdown (run 20260527-040108)

| Sub-phase | Duration |
|---|---|
| `kubectl apply` call | 2.4 s |
| Pod startup (apply → ready) | 47.5 s |
| L1CTL socket attach (ready → attached) | 0.2 s |
| **Total bringup** | **50.1 s** |

Pod startup is almost all of bringup. The 2.4 s apply time and 0.2 s socket attach are negligible.

## Short test vs. long test

Individual test probe runs (single TC, namespace `gsm-probe`):

| Test case | testing (s) | bringup (s) | bringup / testing |
|---|---|---|---|
| TC_26_6_8_5 | 10.7 | 39.7 | **3.7×** — bringup dominates |
| TC_26_6_13_9 | 13.6 | 41.3 | **3.0×** |
| TC_26_6_4_1 | 26.6 | 44.7 | 1.7× |
| TC_26_8_1_3_4_2 | 27.0 | 44.1 | 1.6× |
| TC_26_7_4_5_1 (in 2-TC run) | ~549 (est.) | 39.4 | 0.07× — test dominates |

The TC_26_7_4_5_x family runs for many minutes and eventually FAILs (likely hitting a timeout in the test logic). These are the long test cases. The TC_26_6_x and short TC_26_8_x cases complete in under 30 s each.

## Key findings

1. **Fixed overhead per run is ~90 s** (≈ 40 s bringup + ≈ 50 s teardown), regardless of how many test cases are packed into the run. This overhead is what parallelism amortizes.

2. **For short tests, fixed overhead exceeds test time.** TC_26_6_8_5 takes 10.7 s but costs 39.7 s just to bring up the stack — a 3.7× overhead ratio. Packing more short tests per namespace and running namespaces in parallel are both important.

3. **Bringup time is stable at 35–50 s** across all runs. The variance is pod scheduling jitter, not image pulls (images are pre-loaded in the local registry at `localhost:5000`).

4. **The two phases to amortize are pod startup (~40 s) and teardown (~50 s).** These together account for ~90 s of wall-clock time that is paid once per namespace, not once per test case.

5. **Image pull is not a measured phase.** All images are pre-loaded into the node-local registry at `localhost:5000`, so there is no pull latency at run time. Pull cost is a one-time setup step and is not included in any timing above.

## Reproducibility

A single-namespace run from a clean checkout:

```
scripts/run-one.sh gsm-baseline results/week22
```

This brings up the stack, runs the suite, writes `events.csv`, `summary.json`, `pods.csv`, and per-TC logs to the target directory, then tears down. Confirmed reproducible across the runs above.
