# Week 02 — K8s Lift

Results from the k8s lift phase (W2.1–W2.3).

## Runs

| Directory | Description | Outcome |
|---|---|---|
| `../runs/run20260528-115031-N1/` | TC_26_2_3 on k8s before fix — ISSUE-001 evidence | FAIL |
| `../runs/run20260529-060205-N1/` | TC_26_2_3 post-fix verification (`gsm-fix-verify`) | PASS |
| `../runs/serial-vs-parallel/` | 5-test serial (818 s) vs parallel (204 s) comparison | 4× speedup |

## ISSUE-001

Root cause: `MM_EVENT_CELL_SELECTED` fires before osmo-mobile's VTY port 4247
is bound. Fix: added `wait_mobile_vty` in `scripts/run-one.sh` to probe port
4247 before any test launches. See `docs/open-issues.md` for full details.

## Serial vs Parallel

5 tests run sequentially (fresh namespace each) vs simultaneously (one namespace
per test). Results in `serial-vs-parallel/` — see its README for the full table.
