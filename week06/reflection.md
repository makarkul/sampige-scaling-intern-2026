# Week 06 — reflection

## 1. What I did

- Re-ran the confirmed 16-test sliding-window suite (`sliding-window-campaign.cfg`)
  at N=11 against the stack after the handover/second-BTS merge landed
  (`results/week06/run20260626-113024-N11`, revision `a5b7937`) — regressed hard:
  7/11 INCONCLUSIVE, 4/11 PASS, versus 16/16 PASS at the same N in week05. A
  same-day retry (`run20260626-113057-N11`) also came back degraded (2
  INCONCLUSIVE / 3 PASS out of only 5 tests captured) (W6.1).
- Traced the regression to two independent root causes introduced by the new
  second-BTS/handover support (`osmocom-demo` commits `9e298a7` add bsc-test-stub
  + n56 BTS for Category B handover tests, `81737ac` DNAT initContainer for
  hardcoded VTY IPs, `85fe616` pin osmo-mobile to ARFCN 51): (a) every namespace
  was still injecting GSMTAP paging into the same multicast group, so only one
  namespace's radio traffic landed correctly once N>1; (b) BSC_STUB-mode tests
  could be routed to the real `osmo-bsc` instead of the stub depending on which
  script (`run-one.sh` vs `run-ttcn3-tests.sh`) built the deploy, because the two
  scripts kept separate, drifting `BSC_STUB_TESTS` lists (W6.2).
- Reported both root causes to Vishal's team; the fixes landed in
  `osmocom-demo` as commit `b1c2a86` (per-namespace GSMTAP multicast group
  derivation + `BSC_STUB_TESTS` list sync, plus `docs/K8S_SCALING_RUNBOOK.md`)
  and commit `6ec6d35` (swapped `msc-test-stub`'s `tcpSocket:5000` liveness
  probe — which was itself opening spurious connections the stub tried to
  replay buffered events to, sometimes SIGKILLing it mid-test — for an
  `exec: pgrep -f msc-test-stub` check) (W6.2).
- Validated the BSC-stub paging trio (`TC_26_6_2_1_1/_2/_3`) end to end:
  `vishal-sir-success-run` (N=3, revision `c9e0c03`) came back 3/3 PASS, but the
  same 3 tests at the same N one day later (`run20260701-103609-N3`) came back
  1 FAIL / 2 PASS on identical code — confirmed the failure was parallelism-
  induced rather than a test defect by re-running `TC_26_6_2_1_1` solo
  (`run20260701-104516-N1`, PASS, committed as `ff27321`) (W6.3).
- Started running a wider batch of new tests beyond the original 16-test set:
  5 separate N=8 discovery runs on 2026-07-02 (`run20260702-071554` through
  `-095213`, revision `8987268`) against ~30 previously-unrun test IDs
  (`TC_26_3_2`, `TC_26_6_12_3`, `TC_26_7_4_2_4_5`, `TC_26_8_1_2_4_13`,
  `TC_26_7_5_6`, `TC_26_8_1_3_4_6`, `TC_26_6_8_5`, `TC_26_8_1_2_3_1`, `TC_26_8_3`,
  `TC_26_8_1_2_6_6`, and others) (W6.4).

## 2. Key findings

- **Cross-namespace GSMTAP multicast collision only showed up above N=8.** The
  original 16-test suite had run clean at N=11 in week05 (before the handover-
  support merge); after that merge reintroduced a shared multicast group, the
  same suite dropped to 7/11 INCONCLUSIVE at N=11 — scaling up didn't just
  strain resources this time, it reopened a correctness bug that had been
  invisible at lower N.
- **The BSC-stub routing bug (drifting `BSC_STUB_TESTS` lists) explains the
  day-to-day flake in the paging trio**, not flakiness in the tests themselves —
  the same 3 tests flipped between a clean PASS and a partial FAIL purely based
  on which harness path built the deploy for that run.
- **The liveness probe on `msc-test-stub` was hurting the very process it
  monitored** — the third infra-level bug this project has found hiding in a
  health probe, after week03/04's DNS-race init-container fix and week04's
  liveness-probe-kills-stub fix.
- **Two tests show a hang pattern rather than a fast failure**:
  `TC_26_7_4_2_4_5` FAILed at 873.5 s and again at 751.1 s (vs. a 100–240 s norm
  for the rest of the batch); `TC_26_7_4_2_2_1` FAILed at 939.2 s in a later
  batch. Neither looks like a scheduling artifact — both ran 4–8× longer than
  every passing test around them before failing.
- **`TC_26_3_2` is flaky in the wider test batch** — PASSed (238.1 s) in one N=8
  batch and FAILed (148.6 s) in another otherwise-identical batch on the same
  revision (`8987268`).

## 3. Surprises

- Scaling up (N=11) surfaced a correctness bug, not just a resource ceiling —
  the opposite failure mode from week05, where N=11 was purely about the
  CPU/pod budget, not shared state.
- The regression was introduced by unrelated feature work landing in the shared
  `osmocom-demo` submodule (handover/second-BTS support), not by anything in
  the scaling harness itself — a reminder that the harness's isolation
  guarantees need re-verifying every time the underlying stack changes, not
  just when the harness changes.
- The original week06 plan (tracking.csv: pod/node-level tuning — requests,
  limits, probes, affinity, sysctls) was almost entirely displaced by this
  bug-hunt. The one piece of "tuning" that did happen (Fix C, the liveness-probe
  swap) came from Vishal's team responding to a failure I reported, not from a
  planned tuning pass on my side.

## 4. Carry-overs into week 07

- Re-run the original 16-test suite at N=11 with Fix A/B/C in place to confirm
  the regression is actually closed — no post-fix N=11 run was captured before
  week06 ended.
- Investigate the `TC_26_7_4_2_4_5` / `TC_26_7_4_2_2_1` hang pattern (750–940 s
  before FAIL) — likely a stack-level timeout bug, not a harness issue.
- Resolve the `TC_26_3_2` flake.
- Continue assembling a validated "set 2" 16-test campaign from the
  new-test runs.
