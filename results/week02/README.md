# Week 02 — K8s Lift

Results from the k8s lift phase (W2.1–W2.3).

| Run | Description | Outcome |
|---|---|---|
| `run20260528-115031-N1/` | TC_26_2_3 on k8s before fix — ISSUE-001 evidence | FAIL |

ISSUE-001 (MSC stub drops connection mid-test) was root-caused and fixed in `scripts/run-one.sh`.
Verification run (TC_26_2_3 PASS) is under `results/runs/20260529T060205Z-N1/`.
