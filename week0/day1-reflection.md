# Day 1 — reflection

Fill in by end of day. Bullets are fine. Keep it short — this is what
Makarand reviews on Friday, not a writeup.

Reference the evidence files under `week0/notes/` rather than pasting logs
inline.

---

## 1. What the stack looks like to me now

In your own words, what does the existing demo actually do when you run
`./virtual-um-demo.sh start`? Aim for a diagram or a 5–10 line description.

- Components that come up:
  - <list the `osmo-*` containers you saw>
- The MS attaches to the network via:
  - <one sentence: virtual Um → BTS → BSC → MSC → HLR>
- The TTCN-3 suite plugs in where:
  - <where does the test runner connect — what ports, what containers?>

## 2. What I ran today

- Section B (virtual-um demo end-to-end): <worked / partial / blocked>
  - Bring-up time observed: <seconds>
  - Teardown time observed: <seconds>
- Section C (single TC_26_2_3): <verdict> — wall-clock <seconds>
- Section D (campaign `smoke`): <verdict> — wall-clock <seconds> for
  <N> tests

Evidence: `week0/notes/`.

## 3. The two phases that look most expensive

The internship is about amortizing the parts of a test run that don't depend
on test logic. Based on what you saw today, which phases look like they
dominate wall-clock?

- <phase 1, e.g. "container start + image pull + network registration">
- <phase 2, e.g. "BSC/MSC bring-up before first attach">

You don't need to be right — you need to have a guess we can check in week 1.

## 4. Surprises and stuck points

Anything that was different from what you expected, or that you had to work
around. One bullet per surprise; link the relevant log path.

- <surprise / sticking point> → <how you handled it / what you'd ask>

## 5. Questions for Makarand

The cheapest time to ask these is now.

- <q1>
- <q2>
- <q3>

## 6. Plan for tomorrow (day 2)

Two or three concrete things you intend to do. This becomes input to
`tracking.csv` and `docs/baseline.md`.

- <plan item 1>
- <plan item 2>
- <plan item 3>
