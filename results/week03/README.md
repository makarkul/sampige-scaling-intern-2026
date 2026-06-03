# Week 03 — Parameterize for N namespaces

## Runs

| Directory | Description | Outcome |
|---|---|---|
| `run20260603-064707-N2/` | W3.2 isolation run — N=2 parallel, both TC_26_2_3 | PASS |
| `run20260603-080529-N4/` | W3.3 acceptance run — N=4 parallel, all TC_26_2_3 | PASS |

## run20260603-080529-N4

Four namespaces (`gsm-1` through `gsm-4`) ran TC_26_2_3 simultaneously to
satisfy the W3.3 acceptance criterion: 4 stacks in parallel, 4 result bundles,
no collisions.

| Namespace | bringup_s | testing_s | teardown_s | Verdict |
|---|---|---|---|---|
| gsm-1 | 39.4 | 62.0 | 70.8 | PASS |
| gsm-2 | 39.4 | 62.0 | 63.5 | PASS |
| gsm-3 | 39.4 | 62.0 | 66.5 | PASS |
| gsm-4 | 39.4 | 62.0 | 64.6 | PASS |

**Wall-clock:** 172s — identical to a single-namespace run, confirming no
resource contention between the 4 parallel stacks. Bringup times are within
0.01s of each other across all namespaces.

## run20260603-064707-N2

Two namespaces (`gsm-1`, `gsm-2`) ran TC_26_2_3 simultaneously to verify
no cross-talk between parallel stacks.

| Namespace | bringup_s | testing_s | teardown_s | Verdict |
|---|---|---|---|---|
| gsm-1 | 39.6 | 11.4 | 52.0 | PASS |
| gsm-2 | 39.6 | 52.9 | 50.7 | PASS |

**Wall-clock:** 143.3 s — bounded by the slower namespace (gsm-2).

**Isolation confirmed:**
- DNS: each namespace resolved its own service IPs (gsm-1 and gsm-2 got distinct IPs for msc, mobile, bsc)
- L1CTL socket: `/tmp/osmocom-l2-gsm-1` and `/tmp/osmocom-l2-gsm-2` were separate host directories
- No OOM kills, no test interference
