# Serial vs Parallel — sharded run-n.sh (2026-06-02)

Comparison of running TC_26_7_4_5_1/2/3 serially (1 namespace, 1 test at a
time) vs in parallel (1 namespace per test, all concurrent) using the new
sharded `run-n.sh`.

## Setup

- **Host**: cn083, 48 CPUs, 192 GB RAM, k3s v1.35.4
- **Suite revision**: 1bd74dc
- **Tests**: TC_26_7_4_5_1, TC_26_7_4_5_2, TC_26_7_4_5_3

## Serial runs (N=1 × 3, sequential)

Each test ran in its own fresh namespace, torn down before the next started.

| Run directory | Test | T_suite_s |
|---|---|---|
| `run20260602-114415-N1` | TC_26_7_4_5_1 | 199.531s |
| `run20260602-114824-N1` | TC_26_7_4_5_2 | 197.895s |
| `run20260602-115231-N1` | TC_26_7_4_5_3 | 199.191s |
| **Total wall-clock** | | **746s (12m26s)** |

## Parallel run (N=3, sharded)

All three namespaces launched simultaneously, each running one test.

| Run directory | T_suite_s |
|---|---|
| `run20260602-113320-N3` | **262.672s (4m22s)** |

| Namespace | Test | bringup_s | testing_s | teardown_s | total_s |
|---|---|---|---|---|---|
| gsm-1 | TC_26_7_4_5_1 | 39.9 | 159.6 | 59.8 | 259.3 |
| gsm-2 | TC_26_7_4_5_2 | 39.9 | 162.9 | 59.9 | 262.7 |
| gsm-3 | TC_26_7_4_5_3 | 39.9 | 159.6 | 58.9 | 258.4 |

## Speedup

| Metric | Value |
|---|---|
| T_baseline (serial) | 746s |
| T_suite (parallel) | 262s |
| **S(3)** | **2.84×** |
| **E(3)** | **0.947** |

Efficiency of 0.947 (just under 1) is expected: each namespace pays its own
bringup (~40s) and teardown (~60s) that can't be amortised across tests.

## Bug found and fixed — virtphy hostPath collision

All namespaces were mounting the same hostPath (`/tmp/osmocom-l2`) for the
L1CTL Unix socket shared between `virtphy` and `osmo-mobile`. In parallel,
each namespace's `cleanup` init container deleted the socket created by
another namespace, leaving virtphy stuck at 0/1 Ready indefinitely.

**Fix** (`scripts/run-one.sh`): added a sed substitution in `apply()` to
rewrite the hostPath to `/tmp/osmocom-l2-<namespace>` at apply time, giving
each namespace its own isolated directory on the node.
