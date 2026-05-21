# sampige-scaling-intern-2026

Scaling the osmocom GSM + TTCN-3 test pipeline by running independent test instances
in parallel Kubernetes namespaces on a single high-core-count server. The goal of the
internship is to demonstrate a measurable reduction in end-to-end test execution time
versus the current single-instance `docker compose` setup.

## Internship at a glance

- **Duration:** 8 weeks (2 months)
- **Intern profile:** 3rd-year CS student, comfortable with Linux, containers, and Python/Bash
- **Target host:** single server, ~128 cores, large memory
- **Cluster:** lightweight Kubernetes on that single server (k3s recommended; kind/minikube acceptable)
- **Primary success metric:** wall-clock time to execute the full TTCN-3 suite
  - Baseline = current `docker compose` run on the same host
  - Goal = run N suites/shards concurrently in N namespaces and show the speed-up curve

## Documents

- [`docs/internship-plan.md`](docs/internship-plan.md) — week-by-week plan, deliverables, acceptance criteria
- [`docs/onboarding.md`](docs/onboarding.md) — week-1 reading list and environment setup
- [`docs/metrics.md`](docs/metrics.md) — what to measure, how to measure it, how to report
- [`tracking.csv`](tracking.csv) — weekly task tracker (import into Google Sheets / Excel)

## Repo layout (to be populated by the intern)

```
.
├── README.md
├── docs/                  # plan, onboarding, metrics, final report
├── tracking.csv           # weekly task tracker
├── compose/               # snapshot of the existing docker-compose setup (reference)
├── k8s/                   # manifests / helm chart for the per-namespace stack
├── scripts/               # launcher, sharding, measurement scripts
└── results/               # raw timing data + plots, committed per milestone
```

## Operating cadence

- Daily: short standup note in the tracker (`Notes` column)
- Weekly: Friday demo + commit of results to `results/weekNN/`
- Mid-point review at end of week 4; final demo end of week 8
