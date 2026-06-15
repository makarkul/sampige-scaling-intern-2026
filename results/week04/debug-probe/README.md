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

## Summary

| Metric | Value |
|--------|-------|
| Serial wall time | ~2221s |
| Parallel wall time | 521s |
| Speedup | **4.3×** |
| Serial verdicts | 8/8 PASS |
| Parallel verdicts | 8/8 PASS |
| Verdict mismatches | **0** |

All 8 verdicts matched between serial and parallel.  No parallelism regressions
detected.  The radio isolation fix from week04 (per-namespace GSMTAP multicast
groups) and this session's msc_stub_host fix together make the infra ready to
scale to the full 119-test campaign.

## Run directories

| Run | Directory |
|-----|-----------|
| Serial (per-test) | `results/week04/debug-probe/TC_<name>/` |
| Parallel N=8 | `results/week04/run20260615-053525-N8/` |
