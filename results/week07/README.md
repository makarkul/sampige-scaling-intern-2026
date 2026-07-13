# Week 07 — Sliding-Window Harness Regression (Stale `run-one.sh`)

Narrative and carry-overs: see [`week07/reflection.md`](../../week07/reflection.md).

## Run: N=10 new-test batch (2026-07-07)

`run20260707-105201-N10` — a further batch of newly-discovered test IDs,
continuing week06's work of running new tests.

| | Value |
|---|---|
| N | 10 |
| suite_revision | `5c0508f` |
| Tests captured | 10 |
| PASS | 0 |
| FAIL | 0 |
| INCONCLUSIVE | 10 |

| Test | Duration | Verdict |
|---|---|---|
| TC_26_7_4_3_4 | 45.3s | INCONCLUSIVE |
| TC_26_8_1_3_3_6 | 107.1s | INCONCLUSIVE |
| TC_26_8_1_2_4_7 | 81.1s | INCONCLUSIVE |
| TC_26_7_4_6 | 164.4s | INCONCLUSIVE |
| TC_26_8_1_4_5_6 | 65.8s | INCONCLUSIVE |
| TC_26_8_1_3_3_5 | 50.1s | INCONCLUSIVE |
| TC_26_8_1_3_4_5 | 100.7s | INCONCLUSIVE |
| TC_26_8_1_3_3_3 | 39.3s | INCONCLUSIVE |
| TC_26_8_1_3_3_2 | 583.3s | INCONCLUSIVE |
| TC_26_8_1_3_5_3 | 566.3s | INCONCLUSIVE |

Every namespace's TTCN-3 job logged the same error:
`no TITAN report dir found under .../refs/osmocom-demo/ttcn3/logs/gsm-N/`.

## Root cause

`scripts/run-sliding-window.sh`'s `worker()` function invoked the stale
top-level `scripts/run-one.sh` (last touched before any of week06's isolation
fixes landed) instead of `refs/osmocom-demo/scripts/run-one.sh`. Every test in
this batch ran against a harness copy that predated the per-namespace GSMTAP
fix and the `BSC_STUB_TESTS` sync — diffing the two scripts confirmed the
stale copy was missing both. This is a harness bug, not a defect in any of
the 10 tests themselves.

## Fix

One-line change in `worker()`:

```diff
- RUN_ONE_OUT="${tc_dir}" "${SCRIPT_DIR}/run-one.sh" "${ns}" "${tc}" \
+ RUN_ONE_OUT="${tc_dir}" "${DEMO_REPO}/scripts/run-one.sh" "${ns}" "${tc}" \
```

Not yet re-validated with a rerun — no corrected result bundle exists yet for
this batch of tests.

## Key observation

**"All tests failed identically" was a pure harness signal, not a
test-content signal.** Before concluding a new batch of tests itself is bad,
check which script path actually ran.
