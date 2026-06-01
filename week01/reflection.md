# Week 01 — reflection

## 1. What I did

- Read through the osmocom GSM stack architecture and TTCN-3 test framework;
  documented the MS → BTS → BSC → MSC → HLR call flow in `docs/baseline.md`.
- Verified server access on cn083, confirmed Docker and git setup.
- Ran the full docker-compose stack end-to-end using `virtual-um-demo.sh`;
  captured per-phase wall-clock timings.
- Instrumented TC_26_2_3 (short) and the smoke campaign (long) with timestamps;
  results committed under `results/week01/`.
- Got `scripts/run-baseline.sh` running end-to-end: TC_26_2_3 passes
  (verdict: pass, 100%) with total wall-clock ~284 s.

## 2. Key findings

- Bring-up (51.8 s) and teardown (44.3 s) dominate total runtime — the actual
  test logic (53.3 s for TC_26_2_3) is comparable in size to the overhead.
- The smoke campaign tests are much longer (~900 s each); infrastructure
  amortization matters more at that scale.
- `scripts/run-baseline.sh` makes the baseline reproducible from a clean clone.

## 3. Surprises

## 4. Carry-overs into week 2

- Begin k8s lift: convert docker-compose services to k8s manifests.
- Get TC_26_2_3 passing on k8s as proof of parity with the docker-compose baseline.
