# Baseline — docker-compose setup (pre-k8s)

Measured on **cn083**, 2026-05-22 (day 1 / week 0).
Raw evidence: `week00/notes/`.

This is the reference point for all parallelism speed-up measurements.
The setup being timed is `refs/osmocom-demo/virtual-um-demo.sh` — the
existing docker-compose stack, run with no modifications.

## Host

| Field | Value |
|---|---|
| Hostname | cn083 |
| CPU | Intel Xeon Platinum 8268 @ 2.90 GHz, 48 cores |
| RAM | 187.6 GB (196,702,648 KB) |
| Disk (`/`) | 439 GB total, 34 GB free (92% used) |
| Kernel | 6.8.0-101-generic |
| `ulimit -n` (open files) | 1,048,576 |
| `nf_conntrack_max` | 1,572,864 |
| `inotify.max_user_watches` | 65,536 |
| `inotify.max_user_instances` | 128 |
| `ip_local_port_range` | 32768 – 60999 (28,231 ports) |

## Stack

Eight docker-compose containers per test run. The network is brought up
fresh for every test case (confirmed from `docker ps` timestamps during
the smoke campaign — `week00/notes/D-campaign-smoke.md`).

```
                        ┌──────────────┐
                        │  ttcn3-pod   │  ← drives the test
                        └──────┬───────┘
                               │ (TCP/JSON + VTY + GSMTAP)
                        ┌──────▼───────┐     ┌──────────┐
                        │   osmo-msc   │◄────►│ osmo-hlr │
                        └──────┬───────┘     └──────────┘
                               │ SS7/SCCP (M3UA)
                        ┌──────▼───────┐
                        │   osmo-stp   │  ← SS7 signaling transfer point
                        └──────┬───────┘
                               │ SS7/SCCP (M3UA)
                        ┌──────▼───────┐     ┌──────────┐
                        │   osmo-bsc   │◄────►│ osmo-mgw │
                        └──────┬───────┘     └──────────┘
                               │ Abis/OML (TCP)
                        ┌──────▼──────────┐
                        │ osmo-bts-virtual│
                        └──────┬──────────┘
                               │ L1CTL (Unix socket)
                        ┌──────▼───────┐
                        │ osmo-virtphy │
                        └──────┬───────┘
                               │ L1CTL (Unix socket)
                        ┌──────▼──────────┐
                        │ osmo-mobile-ms1 │  ← simulated mobile station
                        └─────────────────┘
```

Peak container count during a single test run: **9** (8 stack containers +
the TTCN-3 runner). Source: `week00/notes/F-baseline-hints.md`.

Approximate RAM per stack instance: **56 MiB**. Source: `docker stats
--no-stream` snapshot in `week00/notes/F-baseline-hints.md`.

## Per-phase timing

Phases measured using `date +%s.%N` before/after each step.

| Phase | Duration |
|---|---|
| Stack bring-up (`start` → all containers Up + MS "normal service") | **51.76 s** |
| Subscriber attach (register IMSI → "normal service" in mobile log) | 5.64 s |
| Stack teardown (`stop` → no `osmo-*` containers remaining) | **44.26 s** |
| **Fixed overhead per test run (bring-up + teardown)** | **~96 s** |

Source: `week00/notes/B-virtual-um.md`.

## Test execution times

### Short test — TC_26_2_3 (PASS)

| Phase | Duration |
|---|---|
| TTCN-3 execution (test start → final verdict) | 53 s |
| Total wall-clock including bring-up and teardown | ~149 s |
| Overhead fraction | ~64% |

Source: `week00/notes/C-single-test.md`. Verdict log confirms `pass`.

### Smoke campaign — TC_26_7_4_5_1 / _2 / _3

| Test | Result | Wall-clock |
|---|---|---|
| TC_26_7_4_5_1 | ran | ~6–7 min |
| TC_26_7_4_5_2 | FAIL | > 25 min |
| TC_26_7_4_5_3 | not reached | — |

Total observed: 30+ minutes before campaign was abandoned.

Key observation: the network is brought up fresh for each test case in
the campaign (not shared). This means fixed overhead (~96 s) is paid once
per test case, not once per campaign run.

Source: `week00/notes/D-campaign-smoke.md`.

## Key findings

1. **Fixed overhead is ~96 s per test run** (52 s bring-up + 44 s teardown),
   regardless of what the test actually does.

2. **For short tests, overhead exceeds test time.** TC_26_2_3 runs for 53 s
   but costs 96 s just to bring up and tear down the stack — overhead is
   64% of total wall-clock.

3. **The network is not reused across tests in a campaign.** Each test pays
   the full bring-up and teardown cost. This is the primary inefficiency the
   k8s parallelism work is targeting.

4. **Long tests in the smoke campaign time out.** TC_26_7_4_5_2 ran for over
   25 minutes before failing, suggesting it hits a GSM protocol timer rather
   than completing normally. Understanding which tests are genuinely long vs.
   broken is important for sharding strategy (Week 4/7).

5. **Image pull is a one-time cost.** Images were already present on the
   host; pull time was not measured and is not part of the per-run overhead.

## Reproducibility

From a clean clone on the target server, with images already built:

```
scripts/run-baseline.sh
```

This brings up the docker-compose stack, runs TC_26_2_3, tears down, and
writes `events.csv` and `summary.json` to `results/week01/`.

If images are not yet built (first time only):

```
cd refs/osmocom-demo && ./build-images.sh && cd ../..
scripts/run-baseline.sh
```
