# Internship plan — Scaling osmocom + TTCN-3 with Kubernetes namespaces

## Problem statement

The current test pipeline brings up a full osmocom GSM network (BSC, BTS, MSC, HLR,
MGW, STP, SGSN/GGSN as applicable) plus a mobile station simulator inside containers,
runs a TTCN-3 suite from an integrated pod, then tears the whole stack down. Bring-up
and tear-down dominate per-test cost, so the full suite takes much longer than the
sum of the actual test logic.

We have a single host with ~128 cores and a lot of RAM. Each network instance only
uses a small fraction of those resources, so we can run many independent instances in
parallel — one per Kubernetes namespace — and shard the test suite across them. The
internship is to build that and prove the speed-up with numbers.

## Success criteria

1. A reproducible single-server Kubernetes deployment of the osmocom + TTCN-3 stack,
   parameterized so any number of independent instances can run in parallel namespaces.
2. A launcher that shards the TTCN-3 suite across N namespaces and aggregates results.
3. A measurement harness producing a speed-up curve: wall-clock suite time vs. N for
   N ∈ {1, 2, 4, 8, 16, 32, ...} up to the point where it stops scaling.
4. A written report explaining where the curve flattens and why (CPU, memory, kernel
   limits, container runtime, network, disk).
5. Everything committed to this repo with enough docs that a new engineer can
   reproduce the numbers.

## Stretch goals (only if 1–5 are done early)

- Auto-sharding based on historical test runtimes (longest-processing-time bin packing).
- Lightweight observability (Prometheus + Grafana) showing per-namespace resource use.
- A simple GitHub Actions / CI job that runs a small N=4 smoke run on a self-hosted runner.

## Out of scope

- Multi-node Kubernetes cluster, cloud deployment, GPU work, modifying osmocom source,
  modifying TTCN-3 test logic, building a UI.

## Weekly plan (8 weeks)

Each week ends with a Friday demo + a commit to `results/weekNN/` with whatever was
produced. Tasks are tracked in `tracking.csv`.

### Week 1 — Understand the baseline

Goal: be able to explain the existing setup end-to-end and have one credible baseline
number on the target server.

- W1.1 Read up on the osmocom GSM stack (BSC, BTS, MSC, HLR, MGW, STP) and TTCN-3 —
  one-page writeup of what each component does and which ones talk to which.
- W1.2 Get access to the target server; install required tooling; clone the existing
  `docker compose` setup into `compose/` as a frozen reference.
- W1.3 Run the existing suite end-to-end on the target server with no changes. Capture
  per-phase wall-clock: image pull, container start, network registration, test
  execution, teardown.
- W1.4 Pick 1 short test case and 1 long one; instrument them with timestamps to
  understand fixed cost vs. per-test cost.
- **Deliverable:** `docs/baseline.md` with a stack diagram, the timing breakdown, and
  the raw logs under `results/week01/`.
- **Acceptance:** Baseline run is reproducible from a clean clone in one command.

### Week 2 — First Kubernetes lift-and-shift

Goal: run **one** namespace of the stack on k3s and pass the same TTCN-3 suite.

- W2.1 Install k3s on the target server; verify `kubectl` works; understand namespace,
  Deployment, Service, ConfigMap, Job, PVC.
- W2.2 Convert each docker-compose service to k8s manifests. `kompose convert` is a
  fine starting point but the output **will** need hand-editing — fix service names,
  inter-service DNS, config mounts, and any host networking assumptions.
- W2.3 Run the TTCN-3 suite as a `Job` in the same namespace. Confirm the same test
  outcomes as the docker-compose baseline.
- **Deliverable:** `k8s/base/` manifests + `scripts/run-one.sh`.
- **Acceptance:** `scripts/run-one.sh <namespace>` brings up the stack, runs the
  suite, writes results to `results/`, and tears down.

### Week 3 — Parameterize for N namespaces

Goal: stamp out N identical, isolated stacks from one template.

- W3.1 Wrap `k8s/base/` in a Helm chart (preferred) or kustomize overlay. Namespace,
  release name, and any host-port-ish things must be parameterized.
- W3.2 Verify two namespaces can run simultaneously without cross-talk (check DNS,
  service IPs, log streams, any shared state).
- W3.3 Write `scripts/run-n.sh N` that creates namespaces `gsm-{1..N}`, deploys the
  chart into each, runs the suite, collects results, tears down.
- **Deliverable:** `k8s/chart/` + `scripts/run-n.sh`.
- **Acceptance:** `scripts/run-n.sh 4` runs 4 stacks in parallel and produces 4
  result bundles with no collisions.

### Week 4 — Measurement harness + mid-point review

Goal: turn this into a science experiment, not a demo.

- W4.1 Implement the measurement plan from `docs/metrics.md`: per-namespace start
  time, ready time, suite start, suite end, teardown end; node-level CPU / mem /
  load samples; container restarts.
- W4.2 Add a test-sharding strategy. Start dumb (round-robin by index); record per-
  test durations so week 7 can do something smarter.
- W4.3 Run the matrix N ∈ {1, 2, 4, 8} three times each. Plot wall-clock vs. N.
- W4.4 **Mid-point review meeting** — present numbers, raise blockers, agree scope
  for the second half.
- **Deliverable:** `results/week04/` with raw CSVs + plots + `docs/midpoint.md`.
- **Acceptance:** Plots are reproducible from raw data via a committed script.

### Week 5 — Scale out and find the wall

Goal: push N until the speed-up flattens, and characterize why.

- W5.1 Extend the matrix: N ∈ {16, 32, 64, …} until throughput plateaus or things
  start failing.
- W5.2 For each failure mode, capture the symptom and the suspected cause: OOM
  kills, scheduler pending, image pull throttling, conntrack table full, inotify
  watch exhaustion, ARP cache, ephemeral port exhaustion, container runtime
  errors, etcd / k3s API throttling.
- W5.3 Pick the **top 2** bottlenecks based on impact and write them up.
- **Deliverable:** `docs/bottlenecks.md` listing each bottleneck, evidence, and the
  proposed fix.
- **Acceptance:** Each claimed bottleneck has a reproducible failure case.

### Week 6 — Tuning

Goal: fix the top 2 bottlenecks from week 5 and re-measure.

- W6.1 Apply pod-level fixes: right-sized `requests`/`limits`, readiness/liveness
  probes that don't restart healthy pods, anti-affinity if needed.
- W6.2 Apply node-level fixes only as needed and only with justification: kernel
  sysctls (e.g. `net.netfilter.nf_conntrack_max`, `fs.inotify.max_user_*`,
  `net.ipv4.ip_local_port_range`), ulimits, image pre-pull, container runtime
  config. **Document every change.**
- W6.3 Re-run the matrix and produce before/after plots.
- **Deliverable:** `results/week06/` + a short `docs/tuning.md` log of changes.
- **Acceptance:** Speed-up at high N is measurably better than week 5, or there's a
  written reason why the remaining ceiling is fundamental.

### Week 7 — Robustness + sharding intelligence

Goal: make repeated runs trustworthy, and use historical timings for smarter sharding.

- W7.1 Failure handling: a single namespace failing should not abort the whole run.
  Retry policy + per-namespace timeout + clean teardown on failure.
- W7.2 Smarter sharding: use the per-test durations recorded in week 4 to do
  longest-processing-time-first bin packing into N shards. Compare wall-clock vs.
  round-robin.
- W7.3 Light observability: a single Prometheus + Grafana on the cluster showing
  per-namespace CPU / mem and a run-overview dashboard. Screenshot in the report.
- **Deliverable:** updated scripts + `results/week07/`.
- **Acceptance:** Smart sharding beats round-robin on the same matrix, or there's
  data showing it doesn't matter at the chosen N.

### Week 8 — Report, demo, handoff

Goal: leave behind something the team can actually use.

- W8.1 Final report `docs/final-report.md`: problem, approach, speed-up curve,
  bottlenecks, fixes, residual issues, recommendations.
- W8.2 Runbook `docs/runbook.md`: how to install k3s on a fresh server, deploy the
  chart, run the suite at N namespaces, read the results, tear down.
- W8.3 Demo: live run at the best-known N on the target server; show the dashboard
  and the time-to-completion vs. baseline.
- W8.4 Handoff PR review; tag a release.
- **Deliverable:** final report, runbook, tagged release.
- **Acceptance:** Another engineer can reproduce the headline number using only the
  runbook.

## Logistics

- **Branching:** feature branches off `main`, PR per logical change, no force-pushes
  to `main`.
- **Commits:** small and self-describing. Numbers and plots committed under
  `results/` so history shows progress.
- **Daily check-in:** one line in the tracker `Notes` column. No status meeting.
- **Weekly demo:** Friday, 30 min, on the target server.
- **Mentor:** Makarand. Escalate any blocker that costs more than half a day.

## Risk register

| Risk | Mitigation |
| --- | --- |
| docker-compose setup doesn't translate cleanly (host networking, privileged caps) | Budget extra time in week 2; fall back to a thinner subset of services and grow it |
| Single-server k8s hits unexpected kernel limits | Week 5 is explicitly about finding these; week 6 about fixing them |
| TTCN-3 suite has hidden shared state (ports, files) | Surface in week 3 isolation test; if real, parameterize or stub |
| Intern blocked on server access | Get access on day 1; have laptop fallback for k3s/kind work |
