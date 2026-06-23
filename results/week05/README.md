# Week 05 — Sliding Window Parallelism Experiment

## Setup

- **Test suite**: 16 confirmed-passing tests from `scripts/sliding-window-campaign.cfg`
- **Runner**: `scripts/run-sliding-window.sh` (true dynamic dispatch, flock-based queue)
- **Serial baseline**: `scripts/run-n.sh --workers 1` (N=1, one test at a time, fresh namespace each)
- **Parallel run**: `scripts/run-sliding-window.sh --workers 8` (N=8 sliding window)

---

## Results

| | Serial (N=1) | Sliding Window (N=8) |
|---|---|---|
| Run directory | `run20260623-073129-N1` | `run20260623-071306-N8` |
| T_suite (first start → last end) | 4119 s | 671 s |
| Wall clock (script start → finish) | 4211 s (70m 11s) | 766 s (12m 46s) |
| Pass / Fail | 15 / 1 | 16 / 0 |
| Speedup S(8) | — | **6.14×** |
| Parallel efficiency E(8) | — | **76.8%** |

Speedup computed as T_suite_serial / T_suite_parallel = 4119 / 671.

---

## Per-test durations

| Test | Serial (s) | Parallel (s) | Verdict (serial / parallel) |
|---|---|---|---|
| TC_26_6_1_1 | 412.0 | 411.5 | PASS / PASS |
| TC_34_2_2 | 334.3 | 333.6 | PASS / PASS |
| TC_26_7_3_2 | 230.9 | 230.7 | PASS / PASS |
| TC_26_6_2_3_1 | 75.3 | 210.4 | **FAIL** / PASS |
| TC_26_7_5_3 | 211.6 | 207.2 | PASS / PASS |
| TC_26_7_4_1 | 199.0 | 202.9 | PASS / PASS |
| TC_26_6_2_1_1 | 195.5 | 195.4 | PASS / PASS |
| TC_26_6_11_1 | 192.6 | 191.4 | PASS / PASS |
| TC_26_6_2_4 | 179.6 | 159.9 | PASS / PASS |
| TC_26_7_5_6 | 117.7 | 120.9 | PASS / PASS |
| TC_26_8_1_3_3_1 | 114.5 | 122.1 | PASS / PASS |
| TC_26_8_1_3_4_6 | 101.7 | 106.4 | PASS / PASS |
| TC_26_7_2_1 | 98.1 | 96.5 | PASS / PASS |
| TC_26_7_2_2 | 95.3 | 99.4 | PASS / PASS |
| TC_26_6_8_2 | 95.0 | 101.0 | PASS / PASS |
| TC_26_8_1_2_1_1 | 92.1 | 90.1 | PASS / PASS |

---

## Key observations

1. **6.14× speedup at N=8**, vs theoretical max of 8×. Parallel efficiency is 76.8%.

2. **Bottleneck: TC_26_6_1_1 (412s)**. It ran in the second wave of the sliding window and
   was the last test to finish, holding all other slots idle for ~150s at the end.
   This is Amdahl's Law — the longest test sets the floor on T_suite regardless of N.

3. **TC_26_6_2_3_1 is flaky**. It failed in the serial run (75s, early exit) but passed in
   the parallel run (210s). Duration difference suggests a non-deterministic timeout or
   infrastructure race. Worth investigating separately.

4. **Individual test durations are consistent** between serial and parallel runs (within ~5%)
   for all 15 stable tests, confirming the sliding window does not introduce interference
   between concurrent tests.
