# Week 01 — Baseline

This folder holds the week-1 journal: baseline measurement of the existing
docker-compose GSM stack and TTCN-3 suite.

## Contents

- [`reflection.md`](reflection.md) — end-of-week reflection covering what was
  done, what was surprising, and what carries into week 2.
- `notes/` — raw notes and evidence collected during the week.

## Work done this week (W1.1–W1.R)

| Task | Deliverable | Status |
|---|---|---|
| W1.1 — Read osmocom stack + TTCN-3 | `docs/baseline.md` | Completed |
| W1.2 — Server access + compose snapshot | `compose/` | Completed |
| W1.3 — Run suite end-to-end; capture wall-clock | `results/week01/` | Completed |
| W1.4 — Instrument one short + one long test | `results/week01/` | Completed |
| W1.R — Friday demo + baseline.md sign-off | `docs/baseline.md` | Completed |

## Key numbers

| Phase | Time |
|---|---|
| docker-compose bring-up | 51.8 s |
| TC_26_2_3 (single test) | 53.3 s |
| Teardown | 44.3 s |
| **Total** | **149.4 s** |
