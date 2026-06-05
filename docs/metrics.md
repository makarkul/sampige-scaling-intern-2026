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

## Output file schemas

### events.csv

| Column      | Type   | Description                                                                         |
|-------------|--------|-------------------------------------------------------------------------------------|
| `namespace` | string | k8s namespace name (e.g. `gsm-1`)                                                  |
| `phase`     | string | One of: `t0`, `t_apply`, `t_ready`, `t_attached`, `t_test0`, `t_testN`, `t_teardown` |
| `unix_ts`   | float  | Unix timestamp (seconds since epoch, nanosecond resolution)                         |

### host-samples.csv

| Column              | Type  | Unit    | Source                                                                        |
|---------------------|-------|---------|-------------------------------------------------------------------------------|
| `unix_ts`           | int   | seconds | `date -u +%s`                                                                 |
| `cpu_pct`           | float | %       | Delta of busy/total ticks from `/proc/stat`                                   |
| `mem_used_kb`       | int   | KB      | `MemTotal - MemAvailable` from `/proc/meminfo`                                |
| `load1`             | float | —       | 1-minute load average from `/proc/loadavg`                                    |
| `conntrack_count`   | int   | count   | `/proc/sys/net/netfilter/nf_conntrack_count`                                  |
| `conntrack_max`     | int   | count   | `/proc/sys/net/netfilter/nf_conntrack_max`                                    |
| `fd_used`           | int   | count   | Allocated file descriptors from `/proc/sys/fs/file-nr`                        |
| `tcp_tw`            | int   | count   | TCP sockets in TIME_WAIT via `ss -tan`                                        |
| `net_rx_bytes`      | int   | bytes/s | Delta rx bytes on `cni0` from `/proc/net/dev`                                 |
| `net_tx_bytes`      | int   | bytes/s | Delta tx bytes on `cni0` from `/proc/net/dev`                                 |
| `disk_read_bytes`   | int   | bytes/s | Delta sectors read × 512 across all physical disks from `/proc/diskstats`    |
| `disk_write_bytes`  | int   | bytes/s | Delta sectors written × 512 across all physical disks from `/proc/diskstats` |
| `container_count`   | int   | count   | Running containers via `crictl ps -q`                                         |
| `pod_count`         | int   | count   | Running pods via `crictl pods -q`                                             |
| `inotify_watches`   | int   | count   | Active inotify watches across all processes via `/proc/*/fdinfo`              |

### pods.csv

| Column       | Type   | Description                                               |
|--------------|--------|-----------------------------------------------------------|
| `namespace`  | string | k8s namespace name                                        |
| `pod`        | string | Pod name                                                  |
| `container`  | string | Container name within the pod                             |
| `restarts`   | int    | Cumulative restart count (`restartCount`)                 |
| `oom_killed` | bool   | `true` if last termination reason was OOMKilled           |
| `exit_code`  | int    | Exit code of last termination (empty if none)             |

### summary.json

| Field                        | Type        | Description                                              |
|------------------------------|-------------|----------------------------------------------------------|
| `N`                          | int         | Number of parallel namespaces                            |
| `T_suite_s`                  | float       | Wall-clock seconds: `max(t_teardown) - min(t0)`         |
| `T_baseline_s`               | float\|null | `--baseline` value passed to `summarize.py`              |
| `S`                          | float\|null | Speedup: `T_baseline_s / T_suite_s`                      |
| `E`                          | float\|null | Efficiency: `S / N`                                      |
| `pass`                       | int         | Total PASS verdicts across all namespaces                |
| `fail`                       | int         | Total FAIL verdicts across all namespaces                |
| `inconclusive`               | int         | Total INCONCLUSIVE verdicts                              |
| `pods.total_restarts`        | int         | Sum of all pod restart counts                            |
| `pods.oom_kills`             | int         | Count of OOMKilled container terminations                |
| `namespaces[i].namespace`    | string      | Namespace name                                           |
| `namespaces[i].bringup_s`    | float       | `t_attached - t0`                                        |
| `namespaces[i].testing_s`    | float       | `t_testN - t_test0`                                      |
| `namespaces[i].teardown_s`   | float       | `t_teardown - t_testN`                                   |
| `namespaces[i].total_s`      | float       | `t_teardown - t0`                                        |
| `namespaces[i].verdicts`     | object      | Map of `{tc_name: verdict}` for this namespace           |
| `namespaces[i].pass`         | int         | PASS count for this namespace                            |
| `namespaces[i].fail`         | int         | FAIL count for this namespace                            |
| `namespaces[i].inconclusive` | int         | INCONCLUSIVE count for this namespace                    |
