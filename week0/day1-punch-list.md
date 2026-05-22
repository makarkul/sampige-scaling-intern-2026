# Day 1 — punch list

Work through these in order. Each item ends with **evidence to capture** —
a log path, a timing, or a screenshot. References are to the existing demo at
`refs/osmocom-demo/`.

Run everything from `refs/osmocom-demo/` unless noted otherwise.

---

## A. Access and environment

- [ ] You can `git pull` and `git submodule update --init --recursive`
      cleanly in `refs/osmocom-demo/` (auth to gitlab.vayavyalabs.com works).
- [ ] `docker info` returns without error; you can `docker ps`.
- [ ] `./run-ttcn3-tests.sh status` runs and reports submodule + image
      versions. If images aren't built yet, note that and continue.
- [ ] If images aren't built: `./build-images.sh` and capture the wall-clock
      time. (One-time cost, but useful to know.)
- **Evidence:** paste the output of `./run-ttcn3-tests.sh status` into
  `week0/notes/A-status.txt`.

## B. Run the virtual-Um demo end-to-end

The goal here is to drive the GSM stack the way today's docker-compose flow
does — one shell, one network, one MS attaching to one BSC.

- [ ] `./virtual-um-demo.sh start` — wait for it to settle (~15 s single MS).
- [ ] `./virtual-um-demo.sh status` — confirm all `osmo-*` containers are
      Up, and that MS1 VTY is reachable on port 4247.
- [ ] `./virtual-um-demo.sh subscriber` registers the test IMSI in HLR.
- [ ] Open the BSC VTY: `telnet localhost 4242` → `enable` → `show subscribers
      all`. Confirm MS1 appears as `imsi_attached=1` (or the equivalent
      "normal service" state in `docker logs osmo-mobile-ms1`).
- [ ] `./virtual-um-demo.sh stop` — clean teardown, no stray containers
      (`docker ps -a | grep osmo-`).
- **Timings to capture** (`date +%s.%N` before/after, or just a stopwatch):
  - `t_start_to_ready` = `start` invocation → `status` shows all Up
  - `t_attach`         = subscriber registered → "normal service" in mobile log
  - `t_teardown`       = `stop` invocation → no `osmo-` containers left
- **Evidence:** `week0/notes/B-virtual-um.md` with the three timings and one
  line per step ("worked / didn't work / had to do X").

## C. Run a single TTCN-3 test

This is the actual unit of work the internship will be scaling. One test =
one network bring-up + one suite run + one teardown today.

- [ ] Make sure no Virtual-Um demo is running (B's last step). The runner
      will auto-stop it, but cleaner to start from zero.
- [ ] Pick the short test from the suite: `./run-ttcn3-tests.sh TC_26_2_3`.
- [ ] While it runs: in another shell, `docker ps` — note how many containers
      come up for one test. This is the baseline for "one stack".
- [ ] When it finishes, find the results dir: `ls -t ttcn3/logs/ | head -5`.
      The latest `TC_26_2_3-<timestamp>/` is yours.
- **Evidence:**
  - Verdict line: `grep -E "VERDICTOP|TESTCASE|STATISTICS"
    ttcn3/logs/TC_26_2_3-*/MTC.log`
  - Wall-clock for this single test (from runner output or `ls -la`).
  - Path to the log directory.
- **Reflection prompt:** how much of the wall-clock looks like bring-up vs.
  actual test execution? Don't measure precisely — eyeball from
  `container-logs/` timestamps.

## D. Run a TTCN-3 campaign

A "campaign" is just a named group of tests run sequentially against one
network bring-up. This is what we'll be parallelizing.

- [ ] `./run-ttcn3-tests.sh campaign` — list available campaigns. Note that
      `smoke`, `paging`, `immediate_assignment`, `location_update`, etc.
      are defined in `ttcn3/config/campaigns.cfg`.
- [ ] Read `ttcn3/config/campaigns.cfg`. Pick the **smallest** campaign
      (smoke has 3 tests). Note which tests it includes.
- [ ] `./run-ttcn3-tests.sh campaign smoke`.
- [ ] Note the wall-clock for the full campaign and for each test inside it.
- **Evidence:** `week0/notes/D-campaign-smoke.md` with:
  - Total wall-clock for the campaign.
  - Per-test wall-clock (from the per-test log directories under
    `ttcn3/logs/`).
  - One sentence on whether the network is brought up once or per-test —
    look at `docker ps` timestamps or container `Created` time.

## E. Reading logs (do this **while** running C and D, not after)

This is the muscle memory you need for the rest of the internship.

- [ ] Find the verdict — `grep -E "VERDICTOP|TESTCASE|STATISTICS"
      ttcn3/logs/<TC>-*/MTC.log`.
- [ ] Find a failure reason — `grep -E "USER|FAIL"
      ttcn3/logs/<TC>-*/MTC.log | grep -v "Warning: Stopping"`.
- [ ] Look at mobile state — `grep -E "new state|LOCATION UPDATING|no IMSI|
      shutdown" ttcn3/logs/<TC>-*/container-logs/*mobile.log`.
- [ ] Look at MSC stub I/O — `cat ttcn3/logs/<TC>-*/container-logs/*msc-stub.log`.
- **Evidence:** one paragraph in `week0/notes/E-log-tour.md` explaining where
  you'd start if a test failed unexpectedly tomorrow.

## F. Capture rough numbers for the week-1 baseline

Not a real measurement yet — those land in `results/week01/`. Just numbers
good enough to predict whether the parallelism strategy will pay off.

- [ ] One short test (TC_26_2_3): total wall-clock.
- [ ] One full campaign (smoke): total wall-clock + count of tests.
- [ ] Container count during a single test (peak `docker ps | wc -l`).
- [ ] Approx. RAM used during a single test (`docker stats --no-stream` once).
- **Evidence:** `week0/notes/F-baseline-hints.md` — one table.

## G. EOD checklist

- [ ] `week0/notes/` has files for A, B, D, E, F.
- [ ] `day1-reflection.md` filled in (next file).
- [ ] No stray containers (`docker ps | grep osmo-` is empty).
- [ ] Push a branch with everything you've added under `week0/`.
- [ ] Drop a one-line update in `tracking.csv` `Notes` column.

---

## Escalation

- If anything in **section A** doesn't work, ping Makarand immediately —
  don't sit on access issues.
- If a test fails unexpectedly in **C** or **D**: capture the log directory
  path, move on, and note it for the reflection. Don't debug osmocom on day 1.
- If you can't tell whether a step "worked": write down what you saw and
  ask in the reflection. That's a useful question, not a knowledge gap.
