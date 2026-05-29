# Open issues

---

## ISSUE-001 — MSC stub closes TCP connection mid-test → LU wait timeout

**Status:** Resolved (2026-05-29)  
**Affects:** TC_26_2_3  
**Evidence:** `results/week02/run20260528-115031-N1/events.csv` — `t_attached` fired only 0.2 s after `t_ready`

### Root cause

`wait_attached` returned as soon as `MM_EVENT_CELL_SELECTED` appeared in
osmo-mobile logs, which can happen before the VTY listener on port 4247 is
bound. TC_26_2_3 then issued a VTY power-cycle immediately and got
`Connection refused`; the MSC stub dropped the connection during that
window, causing the 90 s LU wait to timeout.

### Fix

Added `wait_mobile_vty` in `scripts/run-one.sh` (after `wait_attached`)
that polls `nc -z 127.0.0.1 4247` inside the osmo-mobile pod until VTY
is accepting connections before any test is launched.

**Verified:** TC_26_2_3 PASS on k8s via `scripts/run-one.sh` (2026-05-29,
namespace `gsm-fix-verify`). Result matches docker-compose baseline.
