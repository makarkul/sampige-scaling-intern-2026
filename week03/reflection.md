# Week 03 — reflection

## 1. What I did

- Wrapped `refs/osmocom-demo/k8s/base/` in a Helm chart (`k8s/chart/`) with
  namespace, L1CTL socket path, test name, and host paths as template values —
  replacing the sed substitutions previously done in `scripts/run-one.sh`.
- Verified `helm install` brings up all 8 pods in a fresh namespace and
  `helm uninstall` tears everything down cleanly. TC_26_2_3 passed in 57s via
  the chart (W3.1).
- Ran N=2 parallel isolation test: two namespaces running TC_26_2_3
  simultaneously, both PASS, no cross-talk. Confirmed DNS scoping (distinct
  service IPs per namespace) and separate L1CTL socket dirs on the host (W3.2).
- Ran N=4 parallel acceptance run: four namespaces running TC_26_2_3
  simultaneously, all PASS, wall-clock 172s — identical to a single-namespace
  run, confirming no resource contention at N=4 (W3.3).

## 2. Key findings

- Helm makes namespace parameterization clean: `helm install gsm-1 k8s/chart/
  --namespace gsm-1 --set l1ctlSocketDir=/tmp/osmocom-l2-gsm-1` is all it
  takes to stamp out a fully isolated stack.
- At N=4, bringup times were within 0.01s of each other across all namespaces —
  the cluster is not resource-constrained at this scale.
- TC_26_7_4_5_1 and TC_26_7_4_5_3 are flaky when run in parallel with other
  stacks — they hung or failed in multiple attempts while TC_26_2_3 was
  consistently stable. Needs investigation before using these in the W4 matrix.
- Stale namespaces left running on the cluster significantly degrade parallel
  run performance — the first N=4 attempt ran for 16+ minutes due to three
  idle namespaces consuming resources.

## 3. Surprises

- [TODO: fill in]

## 4. Carry-overs into week 4

- Investigate TC_26_7_4_5_1 and TC_26_7_4_5_3 flakiness in parallel runs
  before including them in the W4 measurement matrix.
- Implement the W4.1 measurement plan: per-namespace start/ready/suite/teardown
  timestamps + node-level CPU/mem samples.
- Run the matrix N ∈ {1, 2, 4, 8} three times each and plot wall-clock vs. N.
- Add round-robin test sharding strategy for W4.2.
