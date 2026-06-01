# results/plots/

Generated plots from `scripts/plot.py`. All files here are regenerable — do not edit by hand.

## Plots

| File | Description |
|---|---|
| `01-tsuite-vs-n.png` | Total suite wall-clock vs N (parallelism level) |
| `02-speedup.png` | Observed speedup vs ideal N× |
| `03-phase-stacked.png` | Stacked bar: bringup / testing / teardown per N |
| `04-cpu-timeline-*.png` | Host CPU utilisation over time, one file per run |

## Regenerate

```bash
python3 scripts/plot.py results/runs/
```
