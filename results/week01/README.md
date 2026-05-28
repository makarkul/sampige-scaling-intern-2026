# results/week01 — docker-compose baseline

**Date:** 2026-05-22 (day 1)
**Setup:** `refs/osmocom-demo/virtual-um-demo.sh` (docker-compose, no k8s)
**Host:** cn083

This is the W1 baseline: the existing setup run with no modifications.
All numbers here are the reference point for parallelism speed-up measurements.

## Files

- `meta.json` — host facts, image versions, peak container count
- `events.csv` — per-phase unix timestamps reconstructed from measured durations
  and the TTCN-3 log timestamp for TC_26_2_3
- `summary.json` — timing breakdown and verdict for TC_26_2_3

## Raw evidence

The primary source is `week00/notes/`:

| File | What it contains |
|---|---|
| `B-virtual-um.md` | bring-up (51.76 s) and teardown (44.26 s) durations |
| `C-single-test.md` | TC_26_2_3 TTCN-3 log with exact start/end timestamps |
| `D-campaign-smoke.md` | smoke campaign observations (TC_26_7_4_5_x) |
| `F-baseline-hints.md` | peak container count (9), RAM (~56 MiB) |

## Timing summary

| Phase | Duration |
|---|---|
| Bring-up (start → normal service) | 51.76 s |
| TC_26_2_3 execution | 53.35 s |
| Teardown | 44.26 s |
| **Total** | **149.36 s** |

Fixed overhead (bring-up + teardown) = **96 s** = 64% of total wall-clock
for a short test.
