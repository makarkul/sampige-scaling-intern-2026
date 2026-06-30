# Week 05 — reflection

## 1. What I did

- Ran the CPU limit sweep (`cores-proof-sweep`) on TC_26_6_1_1 solo (N=1) across
  11 CPU allocations from 50m to 300m plus unconstrained, to find the minimum safe
  per-container CPU limit (W5.1).
- Built and validated `scripts/run-sliding-window.sh`: a true dynamic dispatcher
  using flock-based queue files so tests are dispatched to the next free namespace
  as soon as one finishes, rather than batched in fixed rounds (W5.2).
- Assembled `scripts/sliding-window-campaign.cfg` with 16 confirmed-passing tests,
  ran the full N=1 serial baseline and parallel runs at N=8, N=11, N=12, and N=16
  (N=16 aborted — exceeded pod limit mid-run) (W5.2).
- Applied `LimitRange` + `ResourceQuota` CPU isolation via the Helm chart
  (`cpuLimit=370m`), validated with an N=11 run, and fixed a divisor bug in the
  Helm template (10 → 9 pods per namespace, commit `107696b`) (W5.3).
- Generated CPU and memory vs. concurrency plots from `pod-resources.csv` using
  `scripts/sliding-window-cpu-memory-plot-generator.py` and embedded them in
  the week05 README (W5.3).
- Ran the 58-test expanded BSC stub campaign (`vishal-bug` run, N=8, revision
  `8b5af85`) to expose failures in the larger test suite; provided the failure
  log set to Vishal's team as a bug baseline (W5.4).
- Coordinated with Vishal on the BSC stub 3-fix branch
  (`feature/k3s-execution-scaling-vishalm`): ran `vishal-bug-fix-3/4/5` at N=8
  across successive image revisions to quantify improvement per fix (phys-info
  timing, CM_SERVICE_ACCEPT handling, dynamic TS reconfigure) (W5.4).
- Ran the June 30 stability check: re-ran the original 16-test campaign at N=11
  with the 3-fix image (revision `c9e0c03`) and confirmed 16/16 PASS (W5.5).
- Started the extended campaign with 16 new tests at N=11 and N=8 (June 30
  afternoon runs), with 10/16 passing on first attempt (W5.5).

## 2. Key findings

- **5.50× speedup at N=8, 5.76× at N=11 on the 16-test suite.** Efficiency drops
  from 68.7% to 52.4% from N=8 to N=11 because TC_26_6_1_1 (~412 s) dominates
  the tail — adding 3 more workers saves only ~35 s of wall-clock time. Amdahl's
  law is the binding constraint, not worker count.
- **N=11 is the confirmed safe maximum** on a 110-pod node. Each namespace peaks
  at 9 pods (8 stack + 1 TTCN-3 job pod); 5 system pods are always present.
  floor((110 − 5) / 9) = 11. N=12 briefly required 113 pods, stalled with 3
  Pending TTCN-3 pods, and caused TC_26_7_2_1 to fail (ran 160 s vs. 96–97 s at
  N=8/N=11) — consistent with scheduling stall, not a test bug.
- **CPU floor for TC_26_6_1_1 is between 50m and 75m.** At 50m the test fails;
  at 75m it passes but runs ~37 s slower than unconstrained (449 s vs. 413 s).
  At 150m runtime matches the unconstrained baseline — this is the practical
  saturation point. The chosen `cpuLimit=370m` (41m per container × 9 pods) is
  well above the per-test floor and adds less than 6% overhead at N=11.
- **CPU isolation overhead is ~43 s (~6%) at N=11.** T_suite went from 730.6 s
  (no limit) to 773.9 s (cpuLimit=370m), 16/16 PASS both ways. No throttle events
  were observed in `pod-resources.csv`. The overhead is within run-to-run variance.
- **BSC stub 3-fix raised pass rate from 2/10 to 4/10** on the 10-test BSC stub
  subset. The three fixes were phys-info timing, CM_SERVICE_ACCEPT handling, and
  dynamic timeslot reconfiguration. The remaining 6 failures are still being
  investigated by Vishal's team.
- **Extended campaign failures are N-independent.** The same 3 tests (TC_26_6_1_2,
  TC_26_6_3_1, TC_26_7_4_2_1) fail and the same 3 are inconclusive at both N=8
  and N=11. This rules out parallelism as the cause — the failures are in the
  tests or the stack, not the runner.

## 3. Surprises

- **TC_26_6_2_3_1 is reliably flaky in the other direction.** It failed in both
  N=1 serial runs (75 s, LU timeout) but passed in all 3 parallel runs (210–223 s).
  A fresh per-test namespace means the mobile is quicker to register for the first
  test in a namespace than for later ones in the serial queue. The timeout behavior
  is sensitive to whether the MS is pre-camped.
- **Memory scales linearly at ~65.7 MiB/namespace**, confirmed across N=1, 8, and
  11. With 11 namespaces active simultaneously the stack uses ~723 MiB application
  RSS — well within the 188 GiB node, so memory is not a constraint anywhere near
  current scales.
- **N=16 aborted silently.** The run directory has only 13 verdicts (2 PASS) and
  no top-level events.csv — the sliding window dispatcher hit the pod cap and some
  namespaces never started. The failure mode was invisible until manually inspected;
  added a pre-flight pod-headroom check to the TODO list.

## 4. Carry-overs into week 6

- Continue the extended campaign: figure out why TC_26_6_1_2, TC_26_6_3_1, and
  TC_26_7_4_2_1 fail consistently, and whether they are fixable or permanently
  excluded from the scaling suite.
- Add pre-flight pod-headroom validation to `run-sliding-window.sh` so that
  requesting N > floor((110 − 5) / 9) = 11 prints a clear error rather than
  silently dropping tests.
- Coordinate with Vishal on the remaining 6 BSC stub failures; run another
  N=8 sweep once the next image revision lands.
- Add Amdahl's Law curve fit to `plot.py` — overlay
  `S(N) = 1 / (f + (1-f)/N)` on the speedup plot and extract the serial fraction
  `f` from the measured data (carried from week 4).
- Investigate TC_26_6_1_1 bottleneck: 412 s is almost entirely in the TTCN-3
  test body. Profile which part of the Location Update / Call sequence is slow.
