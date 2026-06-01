# Week 02 — reflection

## 1. What I did

- Installed k3s on cn083; verified single-node cluster with `kubectl get nodes`.
- Converted all docker-compose services to k8s manifests using kompose + hand
  edits; all pods reach Ready in the `gsm-baseline` namespace.
- Wrapped the test run in `scripts/run-one.sh` — brings up a namespace, runs
  the TTCN-3 suite as a k8s Job, tears down on exit.
- Diagnosed and fixed ISSUE-001: `MM_EVENT_CELL_SELECTED` was firing before
  osmo-mobile's VTY listener was bound, causing TC_26_2_3 to fail with
  "Connection refused". Fix: added `wait_mobile_vty` to probe port 4247 before
  test launch.
- Ran serial vs parallel comparison across 5 tests: 818 s serial → 204 s
  parallel → 4× speedup.

## 2. Key findings

- The k8s bring-up path (40.6 s) is faster than docker-compose (51.8 s) at N=1,
  but test execution is slower (72 s vs 53 s) due to pod-to-pod networking
  latency through kube-proxy.
- Running N namespaces in parallel scales almost linearly — 4× with N=5 tests.
  Gap from theoretical 5× is because wall-clock is bounded by the slowest
  namespace.
- Several "known to pass" tests fail on k8s even in isolation — likely tuned
  for docker-compose timing. Separate investigation needed.

## 3. Surprises

## 4. Carry-overs into week 3

- Wrap `k8s/base/` in a Helm chart or kustomize overlay so namespaces can be
  parameterised without sed substitution.
- Verify two namespaces run simultaneously without cross-talk.
- Write `scripts/run-n.sh` to spin up N namespaces and aggregate results.
