# Week 02 — K8s Lift

Results from the k8s lift phase (W2.1–W2.3).

## Runs

| Directory | Description | Outcome |
|---|---|---|
| `../runs/run20260528-115031-N1/` | TC_26_2_3 on k8s before fix — ISSUE-001 evidence | FAIL |
| `../runs/run20260529-060205-N1/` | TC_26_2_3 post-fix verification (`gsm-fix-verify`) | PASS |
| `../runs/serial-vs-parallel/` | 5-test serial (818 s) vs parallel (204 s) comparison | 4× speedup |

## ISSUE-001

Root cause: `MM_EVENT_CELL_SELECTED` fires before osmo-mobile's VTY port 4247
is bound. Fix: added `wait_mobile_vty` in `scripts/run-one.sh` to probe port
4247 before any test launches. See `docs/open-issues.md` for full details.

## Serial vs Parallel — fresh namespace per test

5 tests run sequentially (fresh namespace each) vs simultaneously (one namespace
per test). Results in `serial-vs-parallel/` — see its README for the full table.

## Serial vs Parallel — single shared namespace (2026-05-27)

Fairer serial baseline: all 5 tests queued in **one namespace** (bringup paid
once) vs 5 simultaneous namespaces. Results in
[`serial-parallel-single-namespace/README.md`](serial-parallel-single-namespace/README.md).

| Mode | Wall-clock | Verdicts |
|------|-----------|---------|
| Serial (1 namespace, 5 tests) | 352 s | 2 FAIL, 3 INCONCLUSIVE |
| Parallel (5 namespaces, 1 test each) | 247 s | 5 FAIL, 0 INCONCLUSIVE |
| **Speedup** | **1.42×** | |

Notable: parallel mode eliminated all INCONCLUSIVE verdicts — each namespace
starts with a fresh MSC stub, preventing state accumulation that caused timeouts
in the serial run.

## Week 02 Day 2 — Sharding + Parallel Run (2026-06-02)

Full findings, timestamps, and speedup numbers are in
[`serial-parallel-using-run-n/README.md`](serial-parallel-using-run-n/README.md).



### What changed

`scripts/run-n.sh` was rewritten to shard tests across namespaces (1 test per
namespace) instead of replicating the full suite in every namespace. The new
interface is:

```
scripts/run-n.sh [--prefix gsm] [--keep] [--baseline SECONDS] TC1 [TC2 ...]
```

N is derived from the number of test names given. `--baseline` passes a serial
reference time through to `summarize.py` to compute S(N) and E(N).

### Bug found and fixed — virtphy socket collision

All namespaces were mounting the same hostPath (`/tmp/osmocom-l2`) for the
L1CTL Unix socket shared between `virtphy` and `osmo-mobile`. In parallel,
each namespace's `cleanup` init container would delete the socket created by
another namespace, leaving virtphy stuck at 0/1 Ready.

Fix: `scripts/run-one.sh`'s `apply()` function now rewrites the hostPath to
`/tmp/osmocom-l2-<namespace>` at apply time, giving each namespace its own
isolated directory on the node.

### Results

| Run | Tests | Total time | S(N) | E(N) |
|---|---|---|---|---|
| Serial (N=1×3, sequential) | TC_26_7_4_5_1/2/3 | 746s (12m26s) | — | — |
| Parallel (N=3, sharded) | TC_26_7_4_5_1/2/3 | 262s (4m22s) | 2.84× | 0.947 |

Serial run directories: `run20260602-114415-N1` (TC1), `run20260602-114824-N1`
(TC2), `run20260602-115231-N1` (TC3). Parallel: `run20260602-113320-N3`.

Efficiency of 0.947 (just under 1) reflects the per-namespace bringup and
teardown overhead (~100s each) that parallel runs cannot amortise across tests.
Near-linear scaling at N=3 is the expected result.
