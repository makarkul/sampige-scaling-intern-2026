# run-n-fresh-ns — N=2 parallel runs with fresh namespace per test

## Goal

Verify that `run-n.sh` with `--workers 2` and a fresh namespace per test produces
the same verdicts as the serial baseline, with reduced wall time.

## Bug found: msc-stub boot LU buffer replay (TC_26_7_2_1)

### Symptom

TC_26_7_2_1 failed reproducibly in every N=2 parallel run before the fix,
while passing in the serial run and the N=8 parallel run.
Failure reason: `MS used wrong CKSN` (expected CKSN=4, got CKSN=7).

### Root cause

When osmo-mobile camps on the cell it immediately sends a Location Update
(the "boot LU", BSC_SLR=0x000001) before any TTCN-3 client connects.
The msc-stub buffers this event and replays it to the first client that connects.

In the N=2 parallel run the cluster was already warm, so the TTCN-3 job pod
started faster — it connected before the boot LU's channel had been released
by the BSC.  The stub replayed two buffered events (EVENT_LU_REQUEST +
EVENT_CLEAR_REQUEST for bsc_slr=1) to the test.

The test handled bsc_slr=1 as the "real" LU (sent LU_ACCEPT), which shifted
every subsequent bsc_slr up by one.  When step 2 sent a paging, the already-
queued bsc_slr=2 retry LU was sitting in the port queue; the test consumed it
as the "paging response".  The test then sent AUTH on that connection but never
sent LU_ACCEPT, so the MS's LU never completed and CKSN=4 was never persisted.
At step 7 the MS sent a new LU instead of a paging response → FAIL.

In the serial run (and the N=8 run) the TTCN-3 job happened to connect after
the boot LU channel had already timed out and a k8s probe had cleared the
buffer via ECONNRESET — an accidental race that only reliably went the right
way when startup was slower.

### Fix

`wait_boot_lu_clear()` added to `scripts/run-one.sh`, called after
`wait_mobile_vty`.  It:

1. Polls the msc-stub log for `CLEAR REQUEST for BSC_SLR=0x000001` — meaning
   the boot LU's channel has been released by the BSC (T3210 timeout).
2. Connects to the stub's control port (127.0.0.1:5000) from inside its own
   pod with `SO_LINGER=0` (RST on close), causing the server to receive
   ECONNRESET and clear its buffered event queue.

The CLEAR REQUEST is in the log before the function is called (~28s from
namespace start vs ~55s for prior readiness checks), so overhead is ~2s.

Commit: `c979959`

## Run directories

| Run | Description | Verdict |
|-----|-------------|---------|
| `run20260615-061423-N2` | First fresh-ns N=2 run (before fix, `\|\| true` applied) | 7/8 PASS — TC_26_7_2_1 FAIL |
| `run20260615-065312-N2` | Second fresh-ns N=2 run (before fix, retry) | 7/8 PASS — TC_26_7_2_1 FAIL |
| `run20260615-072231-N2` | Third fresh-ns N=2 run (**after fix**) | **8/8 PASS** |

## Results (fixed run: run20260615-072231-N2)

| Test | Worker | Duration (s) | Verdict |
|------|--------|-------------|---------|
| TC_26_6_1_1 | gsm-1 | 413.6 | PASS |
| TC_26_6_8_2 | gsm-1 | 95.2 | PASS |
| TC_26_7_4_1 | gsm-1 | 199.3 | PASS |
| TC_26_8_1_3_3_1 | gsm-1 | 114.9 | PASS |
| TC_26_6_2_1_1 | gsm-2 | 202.1 | PASS |
| TC_26_7_2_1 | gsm-2 | 98.5 | PASS |
| TC_26_8_1_2_1_1 | gsm-2 | 92.6 | PASS |
| TC_34_2_2 | gsm-2 | 332.9 | PASS |

**Wall time: 1101s (18.4 min)**
(bottlenecked by worker ns-1: TC_26_6_1_1 413s + bringup/teardown overhead × 4 tests)

Serial baseline wall time for the same 8 tests: ~2221s (~37 min)

**Speedup: ~2.0×** with N=2 workers (expected; bottleneck is the slow TC_26_6_1_1 in worker 1)
