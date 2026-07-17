# Week 08 — reflection

## 1. What I did

- Wrote `docs/final-report.md`: problem statement, week-by-week summary, Docker/Kubernetes
  core concepts, a dedicated section on how the Docker-to-Kubernetes port made the
  parallelism possible (with 3 Mermaid diagrams — Docker run lifecycle, Kubernetes run
  lifecycle, and a Docker-vs-Kubernetes comparison), why Kubernetes suits this workload at
  scale, the role Helm charts played in going from "one namespace by hand" to "N namespaces
  on demand", the full N=1..11 speed-up numbers, the sliding-window scheduler and its
  `flock`-based mutex (and why it beats static/LPT sharding), the six parallelism bugs found
  across the project, and the CPU-limit math (250m/namespace at N=8, 500m at N=16) (W8.1).
- Wrote `docs/find-max-parallel-namespaces.md`: a capacity-planning method for picking N on
  any server — RAM ceiling, CPU ceiling, and the Kubernetes 110-pod-per-node ceiling — with
  worked examples from the laptop, the CI/CD server, and the CDAC server (48 cores, 187.6 GB
  RAM), and a general recipe for applying it to new hardware (W8.1).
- Wrote `docs/tuning.md`, closing out W6.2: pulled `conntrack_count`, `fd_used`, `tcp_tw`,
  and `inotify_watches` from the N=11 sliding-window run's `host-samples.csv` and compared
  each against cn083's sysctl/ulimit ceilings from `docs/baseline.md`. All four sit well
  under their limits, so no sysctl/ulimit change was justified — confirms the real ceiling
  at this scale is the Kubernetes 110-pod default and RAM, not kernel-level counters.
- Wrote `docs/runbook.md`: install k3s on a fresh server, build images, sanity-check one
  namespace, run N namespaces in parallel (round-robin vs. sliding-window), pick N using the
  capacity-planning doc, read the `results/weekNN/` output, tear down, and a known-gotchas
  section pulling together the CPU-limit/N relationship, the 110-pod ceiling, the
  `TC_26_6_1_1` tail, the recurring health-probe bugs, and the stale-script risk (W8.2).
- Cleaned up a misfiled run bundle: `results/week27/run20260629-073944-N1` (a 2026-06-29,
  i.e. week06-dated, run) had landed under a mislabeled `week27` directory; moved it to
  `results/week06/`.
- Updated `tracking.csv` to reflect what actually happened across weeks 6–8, including the
  node-level tuning writeup above.

## 2. Key findings

- **Node-level tuning came back "nothing to change," and that's a legitimate answer.**
  Every kernel limit called out in the internship plan had wide headroom at N=11 (heaviest
  was open file descriptors at ~20% of the ulimit); raising an already-headroomed limit
  would just be configuration drift with nothing to fix. The task's own acceptance
  criteria — apply node-level fixes "only as needed and only with justification" — allows
  for exactly this outcome.
- **Writing the final report surfaced one real gap**: `docs/final-report.md` originally cited
  the wrong section number in two places (a leftover from before extra sections were
  inserted) — cross-references have to be re-checked by hand whenever sections are
  renumbered; nothing here auto-updates.
- **The capacity-planning method generalizes past this one server.** Applying the same
  RAM/CPU/pod-count formula to the laptop and the CI/CD server (in addition to the CDAC
  server used throughout the rest of the project) confirmed the same pattern holds
  everywhere tested: RAM is the practical binding constraint because the GSM stack pods are
  protocol-timer/I/O-bound, not CPU-hot, so they hold memory without burning CPU.
- **The 110-pods-per-node default can bite before RAM, CPU, or any kernel counter does** on
  smaller or leaner servers — worth checking first, since it's the cheapest of the ceilings
  to compute.

## 3. Surprises

- How much of the "why" behind earlier weeks' numbers (the CPU-limit elbow, the mutex
  mechanism, the 110-pod ceiling) had never been written down in one place until the final
  report forced it.
