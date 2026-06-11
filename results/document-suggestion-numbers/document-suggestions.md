# Sizing: how many cores per test instance?

Measured from `suggestion-1-run` (N=1, single namespace `gsm-cal`).  
Host: **cn083** — Intel Xeon Platinum 8268 @ 2.90 GHz, 48 vCPUs, 187.6 GiB RAM, k3s v1.35.4.

## suggestion-1-run results

| Field | Value |
|-------|-------|
| Timestamp | 2026-06-11 07:26:10 UTC |
| Test case | TC_26_8_1_3_4_7 |
| Verdict | **PASS** |
| Bringup | 37.6 s |
| Testing | 124.0 s |
| Teardown | 46.0 s |
| Total | 207.6 s |
| Pod restarts | 0 |
| OOM kills | 0 |

## Per-pod resource usage

| Pod | Phase | Avg CPU (m) | Peak CPU (m) | Avg RAM (MiB) | Peak RAM (MiB) |
|-----|-------|-------------|--------------|---------------|----------------|
| msc-test-stub | bringup | 8.0 | 8.0 | 16.0 | 16.0 |
| msc-test-stub | testing | 1.5 | 8.0 | 16.0 | 16.0 |
| osmo-bsc | bringup | 6.0 | 7.0 | 5.0 | 5.0 |
| osmo-bsc | testing | 1.1 | 2.0 | 5.0 | 5.0 |
| osmo-bts-virtual | bringup | 11.2 | 16.0 | 5.0 | 5.0 |
| osmo-bts-virtual | testing | 16.3 | 18.0 | 5.0 | 5.0 |
| osmo-hlr | bringup | 3.0 | 3.0 | 2.0 | 2.0 |
| osmo-hlr | testing | 1.1 | 3.0 | 2.0 | 2.0 |
| osmo-mgw | bringup | 1.0 | 1.0 | 2.0 | 2.0 |
| osmo-mgw | testing | 1.0 | 1.0 | 2.0 | 2.0 |
| osmo-mobile | bringup | 14.2 | 17.0 | 33.0 | 33.0 |
| osmo-mobile | testing | 3.1 | 4.0 | 33.0 | 33.0 |
| osmo-stp | bringup | 1.0 | 1.0 | 2.0 | 2.0 |
| osmo-stp | testing | 1.0 | 1.0 | 2.0 | 2.0 |
| ttcn3 | bringup | — | — | 6.2 | 7.0 |
| ttcn3 | testing | 1.0 | 1.0 | 6.2 | 7.0 |
| virtphy | bringup | 6.2 | 7.0 | 1.0 | 1.0 |
| virtphy | testing | 6.2 | 7.0 | 1.0 | 1.0 |

> **Note on ttcn3 bringup:** the pod is not launched until after `t_ready`, so it has no bringup CPU samples — this is expected, not a data gap.

Phase boundaries (from `events.csv`):
- **Bringup**: `t0` → `t_ready` (~37.6 s)
- **Testing**: `t_test0` → `t_testN` (~124 s)

## Recommended Kubernetes requests / limits

Sizing rules: CPU request = 1.5× max-phase avg; CPU limit = 2.5× max-phase peak; RAM request = limit = next power-of-2 above 1.25× peak.

| Pod | CPU Request | CPU Limit | RAM Request = Limit |
|-----|-------------|-----------|---------------------|
| msc-test-stub | 12m | 20m | 32Mi |
| osmo-bsc | 9m | 18m | 8Mi |
| osmo-bts-virtual | 25m | 45m | 8Mi |
| osmo-hlr | 5m | 8m | 4Mi |
| osmo-mgw | 2m | 5m | 4Mi |
| osmo-mobile | 22m | 43m | 64Mi |
| osmo-stp | 2m | 5m | 4Mi |
| ttcn3 | 2m | 5m | 16Mi |
| virtphy | 10m | 18m | 2Mi |
| **Total / instance** | **89m** | **167m** | **142Mi** |

## N_max estimate

With 20% of host resources reserved for k3s and system overhead:

| Constraint | Usable capacity | Per-instance demand | N_max |
|------------|-----------------|---------------------|-------|
| CPU (limits) | 38,400m (80% × 48 cores) | 167m | **229** |
| RAM (limits) | 153,674 MiB (80% × 187.6 GiB) | 142Mi | 1,082 |

CPU is the binding constraint. RAM headroom is not exhausted until well past N=1,000.

## Summary

The Osmocom GSM stack is decisively I/O-bound rather than CPU-bound: at peak the entire nine-pod suite for one concurrent test instance consumes only ~60 millicores during bringup and ~45 millicores during steady-state test execution, while RAM never exceeds ~73 MiB per instance. The two heaviest consumers are `osmo-bts-virtual` (the only pod with sustained CPU load at ~16 m average during testing) and `osmo-mobile` (bursts to 17 m at startup, then drops to ~3 m); all other pods stay at single-digit millicores throughout. Recommended Kubernetes CPU requests/limits are 89 m / 167 m per instance and RAM request = limit = 142 Mi, sized to absorb 2.5× burst headroom without over-provisioning. On the 48-core / 187.6 GiB host (cn083), reserving 20% for k3s and system overhead leaves ~38,400 m usable CPU, which accommodates roughly **N_max ≈ 229 concurrent instances** before hitting CPU limits — RAM would not become a binding constraint until well past 1,000 instances (~31 GiB at N=229), so CPU scheduling is the only practical ceiling at this scale.

## Batching when resources bound N

| Constraint | N_max |
|------------|-------|
| CPU (binding) | **229** |
| RAM | 1,082 |
| Conntrack | ~1,500+ |
| Inotify | not a concern |

CPU is the only real ceiling. At N=229 conntrack is projected at ~15% of system maximum (237,000 of 1,572,864). RAM headroom extends to ~1,082 instances. Batching in waves of 229 is therefore CPU-driven, not memory or kernel driven.

> **Caveat:** `inotify max_user_instances=128` is worth rechecking at N=50+ as each process using inotify consumes one instance.

## Optimal execution order with known durations

LPT implementation is deferred to Week 7 — per-test duration data is being accumulated from ongoing runs and will be used to build the lookup table once the full suite has sufficient samples.

## Limiting CPU/RAM per namespace (Question 4)

No `ResourceQuota` or `LimitRange` currently exists in `refs/osmocom-demo/k8s/chart/templates/`.

Plan: add two new files to the Helm chart:
- `resource-quota.yaml` — caps the whole namespace at CPU request=89m, limit=167m, RAM request=limit=142Mi (values from run-cal2 calibration)
- `limit-range.yaml` — sets conservative per-pod defaults (CPU request=10m, limit=20m, RAM request=limit=16Mi) for any pod that doesn't specify its own limits

Implementation deferred to a later week — not a blocker for current parallel runs.

## Multi-node scheduling and placement (Question 5)

Currently running on a single node (cn083) — default scheduler is sufficient for now.

Three tweaks to implement when cluster grows beyond one node:
- **Pod affinity:** keep all pods of one test instance on the same node — avoids cross-node signalling latency inside the GSM stack
- **Topology spread constraints:** spread different test instances evenly across nodes so no single machine gets overloaded
- **Taints and node affinity:** reserve certain nodes exclusively for test traffic so other workloads don't interfere

Do not implement until the default scheduler measurably misplaces work.

## Calibration run for CI/CD scheduling (Question 6)

Data collection is already in place: `test-durations.csv` (per-TC timings) and `pod-resources.csv` (per-pod resource usage) are written after every run.

Next step: wire this data into the pipeline automatically so it:
- Uses per-test durations from `test-durations.csv` for LPT sharding
- Uses `pod-resources.csv` to confirm N_max before each run
- Updates a rolling median after each run so the schedule stays accurate as the suite evolves

This is the natural bridge from Week 4 duration recording to a production-ready pipeline. Implementation planned for Week 7+.
