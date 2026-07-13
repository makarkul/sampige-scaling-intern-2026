# Week 07 — reflection

## 1. What I did

- Ran a local N=10 sliding-window batch on a further set of newly-discovered
  test IDs (`results/week07/run20260707-105201-N10`) — all 10/10 tests came
  back INCONCLUSIVE, every one with `no TITAN report dir found under
  .../ttcn3/logs/gsm-N/` (W7.1).
- Diagnosed the INCONCLUSIVE batch: `scripts/run-sliding-window.sh`'s
  `worker()` was calling the stale top-level `scripts/run-one.sh` (last
  touched before any of week06's isolation fixes landed) instead of
  `refs/osmocom-demo/scripts/run-one.sh`. Every test in the run executed
  against a harness copy that predated the per-namespace GSMTAP fix and the
  `BSC_STUB_TESTS` sync — diffing the two confirmed the stale copy was missing
  both (W7.1).
- Fixed the one-line bug (`${SCRIPT_DIR}/run-one.sh` →
  `${DEMO_REPO}/scripts/run-one.sh`) — not yet re-validated with a rerun
  (W7.1).
- Assembled `scripts/sliding-window-campaign-2.cfg`: a second, non-overlapping
  16-test set, continuing the new-test work started in week06 (W7.2).

## 2. Key findings

- **The N=10 batch's 10/10 INCONCLUSIVE was entirely a harness bug, not a
  test-content problem** — every test in the batch ran against an out-of-date
  `run-one.sh` that predated week06's isolation fixes.
- **"All tests failed identically" is a harness signal, not a test-content
  signal** — worth checking the script path being resolved before concluding a
  wider test batch itself is bad.
- The new-test work is currently blocked on validating the path fix:
  campaign-2 (16 tests) is drafted but has not yet been run against a
  corrected harness.

## 3. Surprises

- The exact class of bug diagnosed in week06 — a stale/incorrect path silently
  serving an out-of-date script — reappeared independently in the scaling
  harness itself, one script over. Worth treating "wrong path resolved" as a
  standing risk whenever a script is referenced from more than one location.
- A single untracked one-line path bug was enough to zero out an entire
  10-test batch — no partial credit, no partial signal from any of the 10
  tests.

## 4. Carry-overs into week 08

- Re-run the N=10 (or larger) sliding-window batch after the path fix to get a
  real verdict set for the newly-discovered tests — the current week07 result
  bundle carries no information about the tests themselves.
- Run the `sliding-window-campaign-2.cfg` set once the path fix is validated.
- Commit the outstanding week06/07 work: bump `refs/osmocom-demo`, commit the
  `run-sliding-window.sh` path fix, `sliding-window-campaign-2.cfg`, and the
  `results/week06`/`results/week07` run bundles.
- Reconcile `tracking.csv`: week06/07 rows still describe a Tune/Robustness
  plan (pod tuning, LPT sharding, Prometheus/Grafana) that wasn't executed as
  written; actual work was isolation-bug diagnosis and running new tests.
