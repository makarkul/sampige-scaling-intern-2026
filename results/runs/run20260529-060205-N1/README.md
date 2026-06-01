# gsm-fix-verify — ISSUE-001 fix verification

**Date:** 2026-05-29  
**Namespace:** gsm-fix-verify  
**Script:** `scripts/run-one.sh`

## Purpose

Verification run confirming the ISSUE-001 fix works. Ran TC_26_2_3 through
the main repo's instrumented `run-one.sh` after adding `wait_mobile_vty`
to probe VTY port 4247 before test launch.

## Result

| Test | Verdict |
|---|---|
| TC_26_2_3 | **PASS** |

## Fix summary

`MM_EVENT_CELL_SELECTED` was firing only 0.2s after deployments became ready —
before osmo-mobile's VTY listener was bound. Added `wait_mobile_vty 60` after
`wait_attached` to poll port 4247 directly, ensuring VTY is accepting before
any test runs.

See `docs/open-issues.md` for full root cause and fix details.
