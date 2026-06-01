# Week 02 — K8s Lift

This folder holds the week-2 journal: lifting the GSM stack onto k3s and
confirming TTCN-3 parity with the docker-compose baseline.

## Contents

- [`reflection.md`](reflection.md) — end-of-week reflection.
- `notes/` — raw notes and evidence collected during the week.

## Work done this week (W2.1–W2.3)

| Task | Deliverable | Status |
|---|---|---|
| W2.1 — Install k3s; verify kubectl | Single-node k3s on cn083 | Completed |
| W2.2 — Convert compose → k8s manifests | `k8s/base/` | Completed |
| W2.3 — Run TTCN-3 suite as a k8s Job | `scripts/run-one.sh` | Completed |
| W2.R — Friday demo | Demo + mentor sign-off | Planned |

## Key results

- TC_26_2_3 PASS on k8s after fixing ISSUE-001 (`wait_mobile_vty`).
- Serial (5 tests, fresh ns each) vs parallel (5 simultaneous ns): **4× speedup**
  (818 s → 204 s).
- Run data: `results/week02/`
