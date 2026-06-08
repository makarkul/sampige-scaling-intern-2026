# Serial vs Parallel — single namespace serial (2026-05-27)

Comparison of running 5 tests sequentially in **one shared namespace** vs
running them in **5 simultaneous namespaces** (one test each).

This is the correct serial baseline for evaluating parallelism benefit: bringup
and teardown are paid once in the serial case, amortised across all 5 tests.

## Setup

- **Host**: cn083, 48 CPUs, 187 GB RAM, k3s single-node
- **Tests**: TC_26_8_1_3_2_1, TC_26_8_1_2_1_1, TC_26_7_3_1, TC_26_8_1_2_2_2, TC_26_7_4_4
- **Suite revision**: 20260527

## Results

| Mode | bringup | testing | teardown | Wall-clock | Verdicts |
|------|---------|---------|----------|-----------|---------|
| Serial (1 namespace, 5 tests sequential) | 36.6 s (once) | 262.8 s | ~52 s | **352 s** | 2 FAIL, 3 INCONCLUSIVE |
| Parallel (5 namespaces, 1 test each) | ~48 s × 5 | — | — | **247 s** | 5 FAIL, 0 INCONCLUSIVE |

**Speedup: 352 / 247 = 1.42×**

## Breakdown

### Serial run

One namespace (`gsm-baseline`) brought up once, all 5 tests queued and run
sequentially within it.

- bringup paid once: 36.6 s
- 5 tests sequential: 262.8 s total testing time
- teardown once: ~52 s
- Wall-clock: **5m52s = 352 s**

Verdicts: 2 FAIL (TC_26_8_1_3_2_1, TC_26_8_1_2_1_1), 3 INCONCLUSIVE
(TC_26_7_3_1, TC_26_8_1_2_2_2, TC_26_7_4_4)

Data: `serial/` (namespace `gsm-baseline`, timestamp 20260527-075711)

### Parallel run

Five namespaces (`gsm-p1` through `gsm-p5`) launched simultaneously, each
running one test. Each paid its own bringup (~48 s).

| Namespace | Test | bringup_s | testing_s | Verdict |
|-----------|------|-----------|-----------|---------|
| gsm-p1 | TC_26_8_1_3_2_1 | 47.4 | 145.1 | FAIL |
| gsm-p2 | TC_26_8_1_2_1_1 | 48.4 | 134.9 | FAIL |
| gsm-p3 | TC_26_7_3_1 | 47.4 | 102.6 | FAIL |
| gsm-p4 | TC_26_8_1_2_2_2 | 48.4 | 131.8 | FAIL |
| gsm-p5 | TC_26_7_4_4 | 48.4 | 75.6 | FAIL |

Wall-clock bounded by slowest namespace (gsm-p1 at 192.5 s + teardown):
**4m7s = 247 s**

Verdicts: 5 FAIL, 0 INCONCLUSIVE

Data: `parallel/par-1/` through `parallel/par-5/`

## Key observations

**Modest speedup (1.42×).** Unlike the fresh-namespace-serial case (where the
serial side pays bringup + teardown N times giving an inflated 4× apparent
speedup), here the serial run amortises its fixed overhead once. The 1.42×
speedup comes purely from running the tests concurrently, partially offset by
each parallel namespace paying its own bringup (~48 s × 5 = 240 s total vs
36.6 s once serially).

**Parallel fixed the INCONCLUSIVE verdicts.** In the serial run, 3 tests
were INCONCLUSIVE — they timed out rather than producing a definitive FAIL.
This is consistent with the MSC stub accumulating state from earlier tests in
the sequence and becoming unresponsive to later ones. In the parallel run,
each namespace starts with a fresh, unstressed MSC stub, so all 5 tests run
to completion and produce a clean FAIL verdict. Parallelism improved verdict
reliability, not just throughput.

**bringup cost is the main overhead in parallel mode.** At N=5, each
namespace pays ~48 s bringup — the parallel run spends ~240 s aggregate on
bringup vs 36.6 s in the serial run. This is the Amdahl serial fraction in
concrete terms: bringup is a per-namespace fixed cost that cannot be
parallelised away.
