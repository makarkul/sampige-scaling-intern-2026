# results/

Numbers and plots committed alongside the code that produced them.

## Layout

```
results/
├── runs/                                 # raw output from scripts/run-n.sh
│   └── 20260613T101500Z-N4/
│       ├── meta.json                     # N, host facts, image tags, suite rev
│       ├── events.csv                    # all per-namespace phase timestamps
│       ├── host-samples.csv              # 1 Hz host metrics
│       ├── summary.json                  # derived per-ns + T_suite
│       ├── ns-1/  ns-2/  ns-3/  ns-4/    # per-namespace events + ttcn3 reports
│       └── ns-1.log  ns-2.log  ...       # stdout from run-one.sh per namespace
├── week01-example/                       # reference of what a weekly bundle looks like
│   ├── meta.json
│   ├── events.csv
│   ├── host-samples.csv
│   ├── summary.json
│   └── README.md
└── plots/                                # output of scripts/plot.py (regenerable)
    ├── 01-tsuite-vs-n.png
    ├── 02-speedup.png
    ├── 03-phase-stacked.png
    └── 04-cpu-timeline-*.png
```

## Rules

- Commit `meta.json`, `events.csv`, `host-samples.csv`, `summary.json`, and the
  ttcn3 report bundles. These are small and they're the evidence.
- Do **not** commit container logs in full — they're large and noisy. Keep them
  under `runs/.../ns-*/logs/` only if they're needed to explain a failure.
- Plots live under `results/plots/`. They are regenerable from raw CSVs and
  should be regenerated, not hand-edited, before each weekly demo.
- At the end of each week, also drop a one-page `results/weekNN/README.md`
  that points at the run directories used in that week's report.
