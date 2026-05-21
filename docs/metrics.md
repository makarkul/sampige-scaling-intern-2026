# Metrics — what to measure and how to report it

The internship lives or dies on the speed-up curve. This document fixes the
definitions so the numbers from week 4 onward are comparable.

## Headline number

**`T_suite(N)`** — wall-clock seconds from the launcher invocation to "all N
namespaces have reported pass/fail and been torn down", measured on the target
server, with the agreed test suite, three runs, median reported.

Speed-up `S(N) = T_suite(1) / T_suite(N)`.

Efficiency `E(N) = S(N) / N` — tells us how close we are to linear.

The baseline `T_baseline` is the existing `docker compose` run on the same host
under the same conditions.

## Per-phase timestamps (every run)

For each namespace `i`:

- `t0`         launcher started for namespace `i`
- `t_apply`    `kubectl apply` returned
- `t_ready`    all stack pods report Ready (readiness probe)
- `t_attached` MS has registered with the network (first successful attach)
- `t_test0`    first test case started
- `t_testN`    last test case finished
- `t_teardown` namespace fully deleted

From these, derive per namespace:
- `bringup    = t_attached - t0`
- `testing    = t_testN - t_test0`
- `teardown   = t_teardown - t_testN`
- `total      = t_teardown - t0`

These four numbers are the unit of analysis. They tell us whether the win is
from amortizing bring-up, from parallel test execution, or both.

## Host-level samples (every run)

Sample at 1 Hz for the duration of the run:

- per-CPU utilization (`mpstat -P ALL 1` or node_exporter)
- total memory used / free
- load average
- network bytes in/out on the bridge
- disk IOPS and bytes
- container count, pod count
- key kernel counters that bite at scale:
  - `net.netfilter.nf_conntrack_count` vs. `_max`
  - open file descriptors (`/proc/sys/fs/file-nr`)
  - inotify watches in use
  - TCP sockets in TIME_WAIT

Dump to a CSV per run. Plot CPU / mem / conntrack overlaid on the run timeline.

## File layout per run

```
results/weekNN/runYYYYMMDD-HHMMSS-N{N}/
  meta.json            # N, image tags, k3s version, kernel, host facts
  events.csv           # one row per (namespace, phase) timestamp
  host-samples.csv     # 1 Hz host metrics
  pods.csv             # pod restarts, OOMs, exit codes
  ttcn3/
    namespace-1/...    # raw test reports
    ...
  summary.json         # derived: T_suite, S, E, per-namespace bringup/testing/teardown
```

`meta.json` and `summary.json` are mandatory — they let later analysis scripts
work without parsing logs.

## Plots that must exist by end of week 4

1. `T_suite` vs. `N` (log-log)
2. Speed-up `S(N)` vs. `N` with the `y = N` ideal line
3. Stacked bar of `bringup` / `testing` / `teardown` averaged across namespaces,
   one bar per `N`
4. CPU utilization timeline for the best run at `N=1` and the best run at the
   largest scaling `N`

All four are regenerated from raw CSVs by a committed script
(`scripts/plot.py`). No hand-edited plots.

## Reporting rules

- Always state `N`, the host (cores / RAM / kernel), the k3s version, the image
  tags, and the suite revision.
- Median of three runs for headline numbers; show min/max in tables.
- A failed run (any namespace failure) is reported separately and **not** averaged
  into the headline.
- If a tuning change is applied, the before/after must be on the same hardware,
  same suite revision, same `N`.
