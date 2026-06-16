# cores-sweep: minimum safe CPU limit per namespace

## Goal

Find the minimum Kubernetes CPU limit per namespace that still allows all 8
GSM TTCN-3 test cases to pass when running 8 namespaces in parallel on a
single k3s node.

## Setup

- 8 test cases, each run in its own namespace with a fresh 8-pod stack
  (osmo-bsc, osmo-bts-virtual, osmo-hlr, osmo-mgw, osmo-mobile, osmo-stp,
  msc-test-stub, virtphy) plus the ttcn3 job pod = 9 containers/namespace.
- CPU constraint is applied via a Kubernetes **ResourceQuota** and **LimitRange**
  injected by the Helm chart (`refs/osmocom-demo/k8s/chart/templates/resource-limits.yaml`).
  The per-container default is `floor(cpuLimit_millis / 10)` to leave headroom
  for init containers while keeping the namespace total within the quota.
- Serial baseline (1 namespace, 8 tests sequentially): **T_baseline = 2227 s**.
- Unconstrained parallel N=8: **T_suite ≈ 427 s** (~5.2× speedup).

## How to reproduce

```bash
# Example: 250m limit, 8 tests in parallel
WEEK=04/cores-sweep \
  scripts/run-n.sh --workers 8 --cpu-limit 250m \
    TC_26_6_1_1 TC_26_6_2_1_1 TC_26_6_8_2 TC_26_7_2_1 \
    TC_26_7_4_1 TC_26_8_1_2_1_1 TC_26_8_1_3_3_1 TC_34_2_2
```

## Helm chart changes

`refs/osmocom-demo/k8s/chart/values.yaml` — added:
```yaml
cpuLimit: ""   # empty = no quota; set to e.g. "250m" for constrained runs
```

`refs/osmocom-demo/k8s/chart/templates/resource-limits.yaml` — new file:
creates a LimitRange (default `floor(limit/10)` per container) and a
ResourceQuota (hard limit on `limits.cpu` and `requests.cpu`) when
`cpuLimit` is non-empty.

`scripts/run-n.sh` — added `--cpu-limit` flag that exports `CPU_LIMIT`.

`scripts/run-one.sh` — passes `${CPU_LIMIT:+--set "cpuLimit=${CPU_LIMIT}"}`
to `helm upgrade --install`.

## Results

`CPU_LIMIT` is not recorded in `meta.json`; the run-to-limit mapping is:

| Run directory           | CPU limit / ns | T_suite (s) | Pass |
|-------------------------|---------------|-------------|------|
| run20260616-070953-N8   | unconstrained | 427.3       | 8/8  |
| run20260616-084713-N8   | 150 m         | 438.8       | 7/8  |
| run20260616-085833-N8   | 89 m          | 1827        | 0/8  |
| run20260616-094547-N8   | 300 m         | 545.7       | 8/8  |
| run20260616-095818-N8   | 200 m         | 561.7       | 7/8  |
| run20260616-101707-N8   | **250 m ★**   | **420.6**   | **8/8** |
| run20260616-102707-N8   | 225 m         | 423.9       | 6/8  |

Failing tests across partial-pass runs: TC_26_6_2_1_1 (requires LU restart
within 120 s) and TC_26_7_4_1 (MM timers). Both are sensitive to CFS
throttling delays on osmo-mobile and osmo-bsc.

## ASCII graph

```
T_suite (s)
 1900 |
 1800 | [89m: 0/8 FAIL]
 1700 |  ###
 1600 |  ###
 1500 |  ###
 1400 |  ###
 1300 |  ###
 1200 |  ###
 1100 |  ###
 1000 |  ###
  900 |  ###
  800 |  ###
  700 |  ###
  600 |  ###                    [200m: 7/8] [300m: 8/8]
  500 |  ###              [150m: 7/8] ...  ...
  400 |  ###                          [225m: 6/8] [250m: 8/8]★  [none: 8/8]
  300 |
  200 |
  100 |
    0 +---+----+-----+-----+-----+-----+-----+------>
       89m  none  150m  200m  225m  250m  300m   CPU limit/ns
              ^                           ^
              |                           |
         unconstrained               elbow point
           baseline
```

## Conclusion

**250 m per namespace = 25 m per container** is the minimum safe limit for
8-way parallel GSM testing on this node. At 225 m (≈22 m/container) CFS
throttling starts causing intermittent LU-timer failures.

The elbow sits between 225 m and 250 m — a 25 m gap. Recommend using
**300 m** in practice to keep a one-step safety margin above the elbow.
