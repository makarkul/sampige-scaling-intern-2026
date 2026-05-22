# Week 0 — Day 1 / pre-baseline

This folder holds the intern's **day-1 work product**: a punch list to walk
through end-to-end with the existing osmocom + TTCN-3 demo, and a reflection
template to fill in by end of day.

The goal of day 1 is **not** to start writing Kubernetes manifests. It is to
build a mental model of the stack you are about to scale, by running the
existing demo and the TTCN-3 suite the way they run today.

## Contents

- [`day1-punch-list.md`](day1-punch-list.md) — checklist to work through, in
  order. Each item produces evidence (a log path, a timing, a screenshot) you
  reference in the reflection.
- [`day1-reflection.md`](day1-reflection.md) — fill this in by EOD. Five short
  sections; bullet points are fine. This is what gets reviewed on Friday.
- [`ttcn3-quickstart.md`](ttcn3-quickstart.md) — one-page reference for the
  TTCN-3 runner (single test vs. campaign, where logs land, how to read them).

## Why this exists

The internship plan (`docs/internship-plan.md`) puts the baseline measurement
in week 1. Before that, you need to be able to drive the existing demo without
help. Day 1 is that warm-up.

## Where to write outputs

- Logs and timings collected today: keep under `week0/notes/` (create the
  directory; not tracked yet).
- Anything that turns into a baseline number: it moves into `results/week01/`
  next week, **not** here.

## What's already done for you

- `refs/osmocom-demo/` is the existing demo, cloned with all submodules
  initialized at known-good commits.
- Makarand has already validated that `refs/osmocom-demo/virtual-um-demo.sh
  start` runs end-to-end on the target server.
- `refs/osmocom-demo/CLAUDE.md` is a working session log with the gotchas
  Makarand hit getting RF + voice + LAU + TTCN-3 working. Skim it; you do not
  need to absorb the DSP detail.
