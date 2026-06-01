# Week 2 review notes

Audit of the intern's work as of `d421276` (2026-05-29). Posted as a PR so the
follow-ups have a single thread to discuss; nothing here is blocking.

## Metrics contract — green

All 7 phases from `docs/metrics.md` are emitted in order:

| phase | source |
|---|---|
| `t0` | `scripts/run-one.sh:283` — launcher start |
| `t_apply` | `scripts/run-one.sh:302` — after `apply_dir` |
| `t_ready` | `scripts/run-one.sh:307` — after `wait_deployments` |
| `t_attached` | `scripts/run-one.sh:313` — after `wait_attached` + `wait_mobile_vty` |
| `t_test0` | `scripts/run-one.sh:320` |
| `t_testN` | `scripts/run-one.sh:334` |
| `t_teardown` | `scripts/run-one.sh:109` — fires from the cleanup trap even on failure |

Other earlier TODOs that are now in place:

- `wait_attached` uses a real probe (`MM_EVENT_CELL_SELECTED`); `wait_mobile_vty`
  added to close ISSUE-001 by waiting for port 4247.
- `meta.json` populated with real `image_tags` (grep'd from `${BASE}/*.yaml`) and
  `suite_revision` (submodule git rev). No placeholders.
- `pods.csv` collected on teardown (`restarts`, `oom_killed`, `exit_code`) and
  aggregated across namespaces in `run-n.sh`.
- `summarize.py` rolls up verdicts per namespace and overall, includes pod
  restart / OOM counts, and computes `S(N)` / `E(N)` when given `--baseline`.

## Follow-ups (please address before W2.R demo)

### 1. Commit the post-fix `gsm-fix-verify` run bundle

`docs/open-issues.md` records the ISSUE-001 fix as verified in namespace
`gsm-fix-verify` on 2026-05-29, but the only `results/week02/` bundle still
checked in is the pre-fix FAIL (`run20260528-115031-N1/`). Please commit the
post-fix PASS run so `results/week02/` matches the green W2.3 status in the
tracker.

### 2. W2.R still marked Planned

`tracking.csv` shows W1.R/W2.1/W2.2/W2.3 Completed, but W2.R (Friday demo) is
still Planned. Update once the demo happens.

### 3. No top-level `week01/` journal

`week00/` exists with the day-1 punch list, reflection, and `notes/`. By the
same convention there should be a `week01/` with the week-1 journal entries —
the work clearly happened (it shows up in commits and in `results/week01/` +
`docs/baseline.md`) but the daily notes are missing. Either add a brief
`week01/` (reflection + notes from the week) to keep the cadence, or
explicitly drop the convention going forward. Don't leave it as an
accidental gap.

## Minor gaps (not blocking, can ride into W4)

- `host-samples.csv` is only collected by `run-n.sh`. Single-namespace baselines
  collected host samples separately; consider folding `collect-host.sh` into
  `run-one.sh` so the N=1 path produces the same evidence bundle as N>1.
- `scripts/plot.py` is still the skeleton I committed in week 0. The four plots
  required by `docs/metrics.md` will land naturally with W4.1/W4.3 once there is
  multi-N data — flagging here so it doesn't surprise anyone at the mid-point
  review.

## Not flagged here

Anything related to W3 (Helm/kustomize parameterization) — that's next week's
scope. No comments on it yet.
