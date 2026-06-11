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
