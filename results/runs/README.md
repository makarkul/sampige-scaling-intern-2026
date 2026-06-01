# results/runs/

Raw output from individual `scripts/run-one.sh` and `scripts/run-n.sh` invocations.

## Naming convention

| Pattern | Meaning |
|---|---|
| `YYYYMMDDTHHMMSSZ-N<N>/` | k8s run with N parallel namespaces |
| `YYYYMMDDTHHMMSSZ-<label>/` | labelled one-off or verification run |

## Contents of each run directory

```
<run>/
├── meta.json          # N, host facts, image tags, suite revision
├── events.csv         # per-namespace phase timestamps (t0, t_ready, t_attached, ...)
├── host-samples.csv   # 1 Hz host metrics (CPU, mem, net) collected during run
├── summary.json       # derived per-namespace timings + overall T_suite
├── ns-1/  ns-2/  ...  # per-namespace events.csv + ttcn3 reports
└── ns-1.log  ...      # stdout from run-one.sh per namespace
```

## Notes

- Directories here are not guaranteed to be committed — scratch runs may be local only.
- Committed runs are the ones referenced from `results/week*/README.md`.
