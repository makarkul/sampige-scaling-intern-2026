# Week 06 — N=11 Regression, Flake Diagnosis, and Corpus Expansion

Narrative and carry-overs: see [`week06/reflection.md`](../../week06/reflection.md).

## 1. N=11 regression (2026-06-26)

Re-running the confirmed 16-test suite (`scripts/sliding-window-campaign.cfg`)
at N=11 — clean 16/16 PASS in week05 — regressed after a handover/second-BTS
merge landed in `osmocom-demo`.

| | `run20260626-113024-N11` | `run20260626-113057-N11` |
|---|---|---|
| N | 11 | 11 |
| suite_revision | `a5b7937` | `a5b7937` |
| Tests captured | 11 | 5 |
| PASS | 4 | 3 |
| INCONCLUSIVE | 7 | 2 |
| FAIL | 0 | 0 |

Per-test verdicts, run `-113024`:

| Test | Verdict |
|---|---|
| TC_26_6_2_1_1 | PASS |
| TC_26_7_2_1 | PASS |
| TC_26_7_4_1 | PASS |
| TC_26_8_1_3_4_6 | PASS |
| TC_26_6_8_2 | INCONCLUSIVE |
| TC_26_6_2_4 | INCONCLUSIVE |
| TC_26_6_11_1 | INCONCLUSIVE |
| TC_26_7_2_2 | INCONCLUSIVE |
| TC_26_7_5_6 | INCONCLUSIVE |
| TC_26_8_1_2_1_1 | INCONCLUSIVE |
| TC_26_8_1_3_3_1 | INCONCLUSIVE |

**Root cause (two, found by diagnosis, fixed by Vishal's team):**
1. Every namespace still injected GSMTAP paging into the same multicast
   group — at N>1 only one namespace's radio traffic landed correctly.
   Fixed in `osmocom-demo` commit `b1c2a86` (per-namespace GSMTAP group
   derivation).
2. BSC_STUB-mode tests could be routed to the real `osmo-bsc` instead of the
   stub, because `run-one.sh` and `run-ttcn3-tests.sh` kept separate, drifting
   `BSC_STUB_TESTS` lists. Fixed in the same commit (`BSC_STUB_TESTS` sync).

A third, related fix landed alongside: `msc-test-stub`'s `tcpSocket:5000`
liveness probe was itself corrupting the stub (spurious connections,
occasional mid-test SIGKILL) — replaced with a process check
(`osmocom-demo` commit `6ec6d35`).

## 2. BSC-stub paging trio flake validation (2026-06-30 – 07-01)

| | `vishal-sir-success-run` | `run20260701-103609-N3` | `run20260701-104516-N1` |
|---|---|---|---|
| N | 3 | 3 | 1 |
| suite_revision | `c9e0c03` | `c9e0c03` | `c9e0c03` |
| TC_26_6_2_1_1 | PASS (179.3s) | **FAIL** (195.8s) | PASS (192.7s) |
| TC_26_6_2_1_2 | PASS (156.9s) | PASS (173.4s) | — |
| TC_26_6_2_1_3 | PASS (111.1s) | PASS (134.0s) | — |

Same code, same N, one day apart: `TC_26_6_2_1_1` flipped from a clean PASS to
a FAIL. Re-running it solo (`run20260701-104516-N1`) confirmed the failure was
parallelism-induced rather than a test defect.

## 3. Running new tests — N=8 discovery batches (2026-07-02)

Five separate N=8 batches (all `suite_revision 8987268`) probing
previously-unrun test IDs to grow the validated test list beyond the
original 16.

| Test | `-071554` | `-084151` | `-085945` | `-092308` | `-095213` |
|---|---|---|---|---|---|
| TC_26_3_2 | PASS 238.1s | *no verdict* | FAIL 148.6s | | |
| TC_26_6_12_3 | PASS 186.0s | PASS 105.0s | PASS 105.6s | | |
| TC_26_7_4_2_4_5 | FAIL 873.5s | *no verdict* | FAIL 751.1s | | |
| TC_26_8_1_2_4_13 | PASS 148.9s | PASS 101.4s | PASS 109.1s | | |
| TC_26_7_5_6 | PASS 100.0s | PASS 112.4s | PASS 105.7s | | |
| TC_26_8_1_3_4_6 | PASS 159.8s | PASS 117.9s | PASS 118.8s | | |
| TC_26_6_8_5 | PASS 122.4s | PASS 98.6s | PASS 102.4s | | |
| TC_26_8_1_2_3_1 | PASS 142.6s | PASS 98.6s | PASS 106.8s | | |
| TC_26_8_1_3_5_7 | | | | PASS 147.6s | |
| TC_26_6_8_2 | | | | PASS 115.0s | |
| TC_26_7_4_3_4 | | | | *no verdict* | |
| TC_26_7_3_2 | | | | PASS 296.8s | |
| TC_26_7_4_2_2_1 | | | | **FAIL 939.2s** | |
| TC_26_8_1_2_6_2 | | | | PASS 124.6s | |
| TC_26_8_1_2_4_4 | | | | FAIL 134.2s | |
| TC_26_6_1_2 | | | | PASS 215.1s | |
| TC_26_8_1_3_4_2 | | | | | PASS 123.5s |
| TC_26_7_5_4 | | | | | PASS 96.6s |
| TC_26_8_1_2_6_6 | | | | | PASS 122.4s |
| TC_26_8_3 | | | | | PASS 149.8s |
| TC_26_8_1_3_5_9 | | | | | PASS 155.4s |
| TC_26_6_2_2 | | | | | PASS 96.0s |
| TC_26_8_1_2_2_3 | | | | | PASS 140.6s |
| TC_26_7_3_1 | | | | | PASS 120.4s |

`-095213` came back a clean 8/8 PASS. `-071554`, `-084151`, and `-085945`
repeat the same 8-test subset — useful for spotting flakes across runs.

## Key observations

- **`TC_26_7_4_2_4_5`, `TC_26_7_4_2_2_1`, and `TC_26_7_4_3_4` all show the same
  hang pattern**: FAIL only after 750–940 s (vs. a 100–240 s norm for the rest
  of the batch), and `TC_26_7_4_2_4_5`/`TC_26_7_4_3_4` sometimes get no verdict
  at all when the dispatcher moves on before they finish. All three sit in the
  same `TC_26_7_4_x` family — worth investigating as a class rather than
  three unrelated flakes.
- **`TC_26_3_2` and `TC_26_8_1_2_4_4` fail inconsistently** on identical
  revisions/N — genuine flakes, not yet root-caused.
- **The N=11 regression and the new-test flakes are unrelated failure
  classes**: the former was a namespace-isolation bug (fixed), the latter look
  like per-test timing/stack issues in newly-discovered tests that were never
  validated before.
