# Serial vs Parallel — Week 02

Comparison of running 5 tests serially (fresh namespace per test, sequential)
vs in parallel (5 simultaneous namespaces, one test each).

## Results

| Test | Serial time | Parallel time | Serial verdict | Parallel verdict |
|---|---|---|---|---|
| TC_26_8_1_3_2_1 | 233.3s | 204.5s | FAIL | FAIL |
| TC_26_7_3_1 | 193.8s | 188.1s | FAIL | FAIL |
| TC_26_7_4_4 | 184.3s | 171.3s | FAIL | **PASS** |
| TC_26_8_1_2_3_1 | 103.1s | 134.4s | INCONCLUSIVE | INCONCLUSIVE |
| TC_26_7_5_3 | 104.1s | 137.1s | INCONCLUSIVE | INCONCLUSIVE |
| **Total / Wall-clock** | **818.6s** | **204.5s** | | |
| **Speedup** | — | **4.0×** | | |

## Notes

- Parallel wall-clock is bounded by the slowest namespace (TC_26_8_1_3_2_1 at 204.5s).
- TC_26_7_4_4 passed in parallel but failed serially — sensitive to node load after
  a prior heavy teardown.
- FAIL/INCONCLUSIVE verdicts are pre-existing k8s issues unrelated to the timing
  comparison; see `docs/open-issues.md`.
