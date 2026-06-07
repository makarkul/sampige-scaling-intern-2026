# Week 04 — reflection

## 1. What I did

- Extended `scripts/collect-host.sh` with four missing metric groups required by
  `docs/metrics.md`: network throughput (rx/tx bytes on cni0), disk throughput
  (read/write bytes across physical disks), container/pod counts via `crictl`,
  and inotify watch counts via `/proc/*/fdinfo` (W4.1).
- Added output file schemas for all four CSV/JSON files to `docs/metrics.md` (W4.1).
- Added `--workers N` round-robin sharding to `scripts/run-n.sh` so the number
  of parallel namespaces is independent of the number of tests; `test[i]` maps to
  `namespace (i % N) + 1` (W4.2).
- Added per-test timing to `scripts/run-one.sh`: each test records `start_ts`,
  `end_ts`, `duration_s`, and `verdict` into `test-durations.csv` (W4.2).
- Updated `scripts/summarize.py` to read `test-durations.csv` and embed it in
  `summary.json`; changed verdicts from a dict to a list to handle duplicate test
  names in the same namespace (W4.2).
- Wrote `scripts/run-matrix.sh` to automate the full N × reps matrix: runs N=1
  first to establish the median baseline, then passes `--baseline` to all
  subsequent runs so `summarize.py` writes S(N) and E(N) (W4.3).
- Completed `scripts/plot.py` with all four required plots: T_suite vs N (log-log),
  S(N) vs N with ideal line, stacked phase breakdown, and CPU timeline for the
  representative N=1 and N=max runs (W4.3).
- Ran the N ∈ {1, 2, 4} × 3 pilot matrix: 9 runs, 72 tests, 72/72 PASS.
- Ran the full N ∈ {1, 2, 4, 8} × 3 matrix: 12 runs, 96 tests, 96/96 PASS.
  Results in `results/week04/matrix-run-1-2-4-8/`.

## 2. Key findings

- **Strong scaling through N=8.** Full matrix results (baseline 1268 s):
  S(2) = 2.55×, S(4) = 4.07×, S(8) = 7.53×. Efficiency E(4) = 1.02 (ideal);
  E(8) = 0.94 — still 94% efficient at 8 parallel namespaces.
- **Super-linear speedup at N=2 is real and explainable.** With N=1 and 8
  sequential tests, the MSC stub pod restarts 7–8 times per run; tests 7 and 8 take
  ~230 s and ~375 s respectively (3–5× longer than normal). With N=2, each
  namespace runs only 4 tests and the MSC stub never reaches the crash threshold —
  all per-test durations stay in the normal 52–155 s range. The parallelism removed
  a serial bottleneck that wasn't visible until we ran the full 8-test suite.
- **At N=8 the bringup/teardown overhead becomes the limiting factor.** Each
  namespace runs only 1 test (~55 s), but bringup is ~43 s and teardown ~65 s —
  overhead is now larger than the test itself. This is the Amdahl serial fraction
  in action: the fixed per-namespace cost sets a ceiling on S(N) around N=8–10.
- **Bringup cost (~40 s) is fully amortised at N=4.** At N=4 the testing phase
  dominates (~208 s) and bringup is 16% of total per-namespace time. At N=8 it
  flips — bringup+teardown is ~108 s vs ~55 s of actual testing.
- **Variance across reps is low.** Spread between min and max T_suite across 3 reps
  was under 4% for N=1/4/8; N=2 had one fast outlier (435 s) but median held.
- **Pod restarts scale with N** (8 at N=1, ~9 at N=2, 12 at N=4, 16–18 at N=8)
  but do not affect verdict correctness — all 96 tests pass.

## 3. Surprises

- The MSC stub crash pattern is deterministic: exactly 7 restarts in every N=1
  rep, always hitting at tests 7 and 8. The crash is triggered by the accumulated
  state of 6 completed test sessions, not by time or load. This was invisible in
  earlier runs that only used 2–4 copies of the same test.
- S(2) > 2 at first looked like a measurement bug. It is not — it is a real
  consequence of reduced per-namespace load improving individual test duration, not
  just parallelism. The speedup has two components: parallel execution (gives up to
  N×) and removal of MSC stub instability (adds extra margin on top).
- In early sharding smoke runs, the second namespace completed its tests noticeably
  faster than expected. The likely reason is that by the time the second namespace's
  jobs ran, the stack was already warm and the mobile station was already camped on
  the cell, reducing the per-test setup work compared to a cold start.

## 4. Carry-overs into week 5

- Investigate the MSC stub crash: what state accumulates across sequential test
  runs that causes it to restart? Could be a file descriptor leak, a socket that
  isn't cleaned up between jobs, or a memory limit.
- Reduce the fixed bringup/teardown cost (~108 s at N=8) to push S(8) closer to
  ideal. The serial fraction is now the main bottleneck, not parallelism.
- Add Amdahl's Law fit to `plot.py` — overlay `S(N) = 1 / (f + (1-f)/N)` on the
  speedup plot to extract the serial fraction `f` from the measured data.
- Begin W5 work: profiling where the fixed overhead comes from (namespace creation,
  pod scheduling, MS attach time) and identifying which parts can be reduced.
