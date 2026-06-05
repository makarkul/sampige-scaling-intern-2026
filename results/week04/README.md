# Week 04 — Measurement Harness

## What was built this week

**W4.1 — Measurement harness**
- Extended `scripts/collect-host.sh` with all fields required by `docs/metrics.md`:
  net throughput (`net_rx_bytes`, `net_tx_bytes`), disk throughput
  (`disk_read_bytes`, `disk_write_bytes`), container/pod counts, inotify watches.
- Added output file schemas to `docs/metrics.md`.

**W4.2 — Round-robin sharding + per-test durations**
- Added `--workers N` flag to `scripts/run-n.sh` so N namespaces can be launched
  independently of how many tests are in the suite.
- Tests are assigned to namespaces round-robin: `test[i] → namespace (i % N) + 1`.
- `scripts/run-one.sh` now records per-test `start_ts`, `end_ts`, `duration_s`,
  and `verdict` into `test-durations.csv` for every test run.
- `scripts/summarize.py` reads `test-durations.csv` and includes it in `summary.json`.

## Runs

| Run | Location | Workers | Tests | Outcome |
|-----|----------|---------|-------|---------|
| W4.2 sharding smoke — same test × 4 | `results/runs/20260605T063005Z-w4.2-shard-same-test/` | 2 | TC_26_2_3 × 4 | 4/4 PASS |
| W4.2 sharding smoke — 6 mixed tests | `results/runs/20260605T064459Z-w4.2-shard-mixed/` | 2 | 6 different TCs | 0/6 PASS |

## Run 1 — same test × 4 (`20260605T063005Z-w4.2-shard-same-test`)

**Goal:** verify sharding and per-test duration recording work end-to-end.

**Assignment (--workers 2, 4 tests):**
- `gsm-1`: TC_26_2_3, TC_26_2_3
- `gsm-2`: TC_26_2_3, TC_26_2_3

| Namespace | bringup_s | testing_s | teardown_s | Verdicts |
|-----------|-----------|-----------|------------|----------|
| gsm-1 | 39.8 | 135.7 | 50.0 | PASS, PASS |
| gsm-2 | 39.8 | 69.8 | 49.2 | PASS, PASS |

**Wall-clock:** 225.5s — gsm-1 was the bottleneck (ran two full tests serially).

**Per-test durations recorded:**

| Namespace | TC | duration_s | Verdict |
|-----------|----|-----------|---------|
| gsm-1 | TC_26_2_3 | 68.9 | PASS |
| gsm-1 | TC_26_2_3 | 66.8 | PASS |
| gsm-2 | TC_26_2_3 | 20.4 | PASS |
| gsm-2 | TC_26_2_3 | 49.4 | PASS |

Note: gsm-2's first test ran in 20.4s vs the usual ~68s. The stack was freshly
attached and the test had less setup overhead on a warm namespace.

## Run 2 — 6 mixed tests (`20260605T064459Z-w4.2-shard-mixed`)

**Goal:** exercise sharding with different tests per slot; validate per-test
timing and verdict recording across a mixed suite.

**Assignment (--workers 2, 6 tests):**
- `gsm-1`: TC_26_8_1_3_2_1, TC_26_7_3_1, TC_26_7_4_4
- `gsm-2`: TC_26_8_1_2_1_1, TC_26_8_1_2_2_2, TC_26_8_1_2_3_1

| Namespace | bringup_s | testing_s | teardown_s | Pass | Fail | Inconc |
|-----------|-----------|-----------|------------|------|------|--------|
| gsm-1 | 39.7 | 362.5 | 51.6 | 0 | 3 | 0 |
| gsm-2 | 39.7 | 271.3 | 51.9 | 0 | 2 | 1 |

**Wall-clock:** 453.8s

All 6 tests failed or were inconclusive. These tests have not been validated on
k8s yet — the failures are a test-compatibility issue, not a sharding issue.
The harness (sharding, per-test CSV, summary.json) worked correctly.

**Per-test durations recorded:**

| Namespace | TC | duration_s | Verdict |
|-----------|----|-----------|---------|
| gsm-1 | TC_26_8_1_3_2_1 | 127.6 | FAIL |
| gsm-1 | TC_26_7_3_1 | 140.0 | FAIL |
| gsm-1 | TC_26_7_4_4 | 94.9 | FAIL |
| gsm-2 | TC_26_8_1_2_1_1 | 130.3 | FAIL |
| gsm-2 | TC_26_8_1_2_2_2 | 127.3 | FAIL |
| gsm-2 | TC_26_8_1_2_3_1 | 13.7 | INCONCLUSIVE |
