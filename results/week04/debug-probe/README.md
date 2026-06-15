# debug-probe — Serial vs Parallel baseline (2026-06-15)

## Goal

Establish a serial ground truth for 8 representative tests, then run the same
8 tests in parallel and verify that verdicts are identical.  The serial run
gives us the "correct" answer for each test in isolation; the parallel run
tells us whether running concurrently on the same cluster introduces any
interference or flips any verdict.

## Test selection

8 tests were chosen to span 6 different functional areas of the GSM test suite,
none of which were pre-flagged as FAIL or INCONCLUSIVE in the static baseline:

| Test | Area |
|------|------|
| TC_26_6_1_1 | Immediate Assignment |
| TC_26_6_2_1_1 | Paging |
| TC_26_6_8_2 | Ciphering |
| TC_26_7_2_1 | Authentication |
| TC_26_7_4_1 | Location Updating |
| TC_26_8_1_2_1_1 | Outgoing call setup |
| TC_26_8_1_3_3_1 | Incoming call |
| TC_34_2_2 | GPRS |

## Serial run

Each test ran in its own fresh namespace (brought up, tested, torn down) before
the next test started.  This matches what GitLab CI does — clean state per test,
no shared resources.

| Test | Serial duration (s) | Verdict |
|------|-------------------|---------|
| TC_26_6_1_1 | 505 (414s test + 91s overhead) | PASS |
| TC_26_6_2_1_1 | 288 | PASS |
| TC_26_6_8_2 | 191 | PASS (after fix — see below) |
| TC_26_7_2_1 | 188 | PASS |
| TC_26_7_4_1 | 238 | PASS |
| TC_26_8_1_2_1_1 | 180 | PASS |
| TC_26_8_1_3_3_1 | 207 | PASS |
| TC_34_2_2 | 424 | PASS |

**Total serial wall time: ~2221s (~37 min)**
(TC_26_6_1_1 ran separately before the timed loop; remaining 7 took 1716s)

## Bug found and fixed: TC_26_6_8_2 (msc_host parameter name mismatch)

TC_26_6_8_2 initially **FAILED** with `timeout waiting for initial LU REQUEST`.

**Root cause:** The test's config file used the parameter names `msc_host` and
`msc_port` to tell the TTCN-3 port where to find the MSC stub.  But the C++
port implementation (`MSC_Port.cc`) only recognises `msc_stub_host` and
`msc_stub_port`.  The mismatch caused the port to silently ignore the injected
k8s IP and fall back to the hardcoded docker-compose address `172.20.0.12`,
which does not exist in k8s.  The connection failed before the test could even
start.

**How it was found:** The MTC log showed two back-to-back warnings:
```
MSC_Port: Unknown parameter 'msc_host'   ← value ignored, fell back to default
MSC_Port: Failed to connect to MSC stub  ← tried 172.20.0.12, which doesn't exist
```

**Fix:** The test job init container already runs a `sed` pass over each config
file to replace docker IPs with real k8s IPs.  Two extra substitution rules were
added to `k8s/base/ttcn3-job.yaml` to also rename the parameter keys at runtime:

```
.msc_host :=  →  .msc_stub_host :=
.msc_port :=  →  .msc_stub_port :=
```

The 7 affected `.cfg` files are left untouched — the fix happens entirely in the
infra layer.  The pattern is precise enough that it cannot accidentally match
configs that already use the correct `msc_stub_host` name.

**7 affected tests:** TC_26_6_8_2, TC_26_6_1_4, TC_26_6_13_9, TC_26_6_13_10,
TC_26_6_2_1_3, TC_26_6_2_3_1, TC_26_6_2_4.

**Verified:** TC_26_6_8_2 goes from FAIL to PASS after the fix.

Commit: `525e6a4` (in refs/osmocom-demo), `72a9e21` (submodule pointer).

## Parallel run (N=8)

The same 8 tests were launched simultaneously — each in its own fresh namespace
(gsm-1 through gsm-8) — all starting at the same time.

| Test | Namespace | Bringup (s) | Test (s) | Teardown (s) | Total (s) | Verdict |
|------|-----------|-------------|----------|--------------|-----------|---------|
| TC_26_6_1_1 | gsm-1 | 51.1 | 415.0 | 54.9 | 521.0 | PASS |
| TC_26_6_2_1_1 | gsm-2 | 41.0 | 193.8 | 53.7 | 288.6 | PASS |
| TC_26_6_8_2 | gsm-3 | 40.4 | 95.3 | 52.9 | 188.6 | PASS |
| TC_26_7_2_1 | gsm-4 | 40.4 | 101.7 | 53.4 | 195.5 | PASS |
| TC_26_7_4_1 | gsm-5 | 50.7 | 203.1 | 53.8 | 307.6 | PASS |
| TC_26_8_1_2_1_1 | gsm-6 | 36.0 | 92.0 | 54.0 | 182.1 | PASS |
| TC_26_8_1_3_3_1 | gsm-7 | 50.6 | 114.9 | 52.6 | 218.1 | PASS |
| TC_34_2_2 | gsm-8 | 36.2 | 333.4 | 54.4 | 424.0 | PASS |

**Total parallel wall time: 521s (~8.7 min)**
(bottlenecked by the slowest test, TC_26_6_1_1)

## Bug found and fixed: TC_26_7_2_1 (msc-stub boot LU buffer replay)

TC_26_7_2_1 **FAILED** reproducibly in every N=2 parallel run with
`MS used wrong CKSN` (expected CKSN=4, got CKSN=7), while passing in the
serial run and the N=8 parallel run.

**Root cause:** When osmo-mobile camps on the cell it immediately sends a
Location Update (the "boot LU", BSC_SLR=0x000001) before any TTCN-3 client
connects.  The msc-stub buffers this event and replays it to the first client
that connects.

In the N=2 parallel run the cluster was already warm (the previous test's
namespace had just torn down), so the TTCN-3 job pod started faster and
connected before the boot LU's channel had been released by the BSC.  The
stub replayed EVENT_LU_REQUEST + EVENT_CLEAR_REQUEST for bsc_slr=1 to the
test, shifting every subsequent bsc_slr up by one.

The test handled bsc_slr=1 as the "real" LU (sent LU_ACCEPT), then at step 2
consumed the already-queued bsc_slr=2 retry LU as the "paging response".  It
sent AUTH on that connection but never sent LU_ACCEPT, so the MS's LU never
completed and CKSN=4 was never persisted.  At step 7 the MS sent a new LU
instead of a paging response → FAIL.

In the serial run the TTCN-3 job connected after the boot LU channel had
already timed out and a k8s probe had cleared the buffer via ECONNRESET — an
accidental race that happened to go the right way only when startup was slower.

**How it was found:** Comparing the serial and parallel MTC logs showed the
serial test received `EVENT_PAGING_RESPONSE` at step 2 while the parallel test
received `EVENT_LU_REQUEST`.  Tracing back: the serial run's first event was
`bsc_slr=2, old_lac=0` (boot LU already gone), the parallel run's first event
was `bsc_slr=1, old_lac=65534` (boot LU still buffered).  The msc-stub log
confirmed the buffer-replay mechanism.

**Fix:** `wait_boot_lu_clear()` added to `scripts/run-one.sh`, called after
`wait_mobile_vty`.  It waits for `CLEAR REQUEST for BSC_SLR=0x000001` in the
msc-stub log (boot LU timed out at BSC), then connects to the stub's control
port with `SO_LINGER=0` (RST on close) so the server receives ECONNRESET and
clears its buffered event queue before the TTCN-3 job starts.

The CLEAR REQUEST is already in the log before the function is called (~28s
from namespace start vs ~55s for prior readiness checks), so overhead is ~2s.

**Verified:** 2 consecutive N=2 runs before fix → TC_26_7_2_1 FAIL each time.
After fix → 8/8 PASS.

Commit: `c979959`.

## N=2 parallel run (after fix)

Workers: 2.  Each worker runs its assigned tests serially, each in a fresh
namespace.  Results in `run-n-fresh-ns/run20260615-072231-N2/`.

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

**Wall time: 1101s (~18.4 min)**

## Summary

| Metric | Value |
|--------|-------|
| Serial wall time | ~2221s (~37 min) |
| N=8 parallel wall time | 521s (~8.7 min) |
| N=2 parallel wall time (after fix) | 1101s (~18.4 min) |
| N=8 speedup | **4.3×** |
| N=2 speedup | **2.0×** |
| Serial verdicts | 8/8 PASS |
| N=8 parallel verdicts | 8/8 PASS |
| N=2 parallel verdicts (after fix) | 8/8 PASS |
| Verdict mismatches | **0** |

All 8 verdicts matched across serial, N=8, and N=2 (post-fix) runs.  Two
infrastructure bugs were found and fixed during this session:
1. `msc_host` parameter name mismatch (TC_26_6_8_2 and 6 others)
2. msc-stub boot LU buffer replay (TC_26_7_2_1 in parallel runs)

Both fixes are in the infra layer and do not touch test source files.

## Run directories

| Run | Directory |
|-----|-----------|
| Serial (per-test) | `results/week04/debug-probe/serial-baseline/TC_<name>/` |
| Parallel N=8 | `results/week04/run20260615-053525-N8/` |
| N=2 shared-ns (pre-fix reference) | `results/week04/debug-probe/run-n-shared-ns/` |
| N=2 fresh-ns runs | `results/week04/debug-probe/run-n-fresh-ns/` |
