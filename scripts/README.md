# scripts/

Starter helpers. The intern is expected to extend these — they're skeletons,
not finished code.

| script | week | purpose |
| --- | --- | --- |
| `run-one.sh` | W2.3 | Bring up one namespace, run the suite, tear down. Records per-phase timestamps to `events.csv`. |
| `run-n.sh`   | W3.3 | Launch N namespaces in parallel, aggregate events, write `meta.json`, kick off `summarize.py`. |
| `collect-host.sh` | W4.1 | 1 Hz host metrics (CPU, mem, conntrack, fd, TIME_WAIT). Backgrounded by `run-n.sh`. |
| `summarize.py` | W4.1 | `events.csv` → `summary.json` (per-namespace bringup/testing/teardown, T_suite). |
| `plot.py` | W4.3 | One or more `summary.json` files → the four required plots in `docs/metrics.md`. |

## Conventions

- All scripts write to `results/runs/<UTC-timestamp>-<tag>/`.
- Phase names in `events.csv` must match the ones in `docs/metrics.md` so plots
  don't break silently.
- Don't `chmod -R` random things; mark the four shell scripts executable and
  leave Python ones to `python3 path/to/x.py`.
- No hand-edited plots. If you tweak presentation, do it in `plot.py`.

## TODOs for the intern

- `run-one.sh`: replace the placeholder readiness check with a real
  "MS attached" probe (poll BSC/MSC logs, or a CLI from the stack).
- `run-n.sh`: parameterize image tags and suite revision in `meta.json`.
- `summarize.py`: extend with pod restart / OOM counts once `pods.csv` exists.
- `plot.py`: add the CPU-timeline plot (`04-cpu-timeline-*.png`) from
  `host-samples.csv` once you have a real run.
