# TTCN-3 quickstart — running tests in `refs/osmocom-demo/`

Short reference for the day-1 punch list. Authoritative source is
`refs/osmocom-demo/CLAUDE.md` and the runner itself.

All commands below are run from `refs/osmocom-demo/`.

## Environment check (run this first, always)

```bash
./run-ttcn3-tests.sh status
```

Prints repo branch + commit, submodule revisions, built Docker image
versions, and any running test containers. If image versions are missing,
build them once: `./build-images.sh`.

## List what's available

```bash
./run-ttcn3-tests.sh list           # all TC_*.ttcn3 test cases (54 today)
./run-ttcn3-tests.sh campaign       # named campaigns from ttcn3/config/campaigns.cfg
```

## Run a single test

```bash
./run-ttcn3-tests.sh TC_26_2_3       # one test
./run-ttcn3-tests.sh TC_26_2_3 TC_26_2_4   # two tests, sequentially
```

Each test brings the network stack up, runs the test, tears it down.

## Run a campaign

A campaign is a named group of tests in `ttcn3/config/campaigns.cfg` —
they share one network bring-up (key fact for this internship).

```bash
./run-ttcn3-tests.sh campaign smoke           # 3 tests, fastest
./run-ttcn3-tests.sh campaign paging          # ~10 tests
./run-ttcn3-tests.sh campaign immediate_assignment
```

Other defined campaigns today: `c-test`, `location_update`, `authentication`,
`ciphering`, `channel_release`, `classmark`. Read `campaigns.cfg` for the
exact list.

## Run everything

```bash
./run-ttcn3-tests.sh all              # all 54 tests — slow, useful as baseline
```

## Where logs go

Per test:

```
ttcn3/logs/<TC>-<timestamp>/
  MTC.log                    main test controller log (verdict lives here)
  mc_output.log              main controller output
  test_output.log            consolidated test stdout
  <TC>-*-hc.log              host controller logs
  <TC>-*-mtc.log             MTC component logs
  container-logs/            stdout/stderr of every osmo-* container
```

## Reading logs — sequence that usually works

```bash
# 1) verdict
grep -E "VERDICTOP|TESTCASE|STATISTICS" ttcn3/logs/<TC>-*/MTC.log

# 2) failure reason
grep -E "USER|FAIL" ttcn3/logs/<TC>-*/MTC.log | grep -v "Warning: Stopping"

# 3) MSC stub I/O (TTCN-3 ↔ stub commands)
cat ttcn3/logs/<TC>-*/container-logs/*msc-stub.log

# 4) Mobile MM state
grep -E "new state|LOCATION UPDATING|no IMSI|shutdown" \
     ttcn3/logs/<TC>-*/container-logs/*mobile.log
```

## Network conflict warning

The runner uses `compose/ttcn3.yml`, which collides with
`compose/virtual-um.yml`. **Stop the Virtual Um demo before running tests**:

```bash
./virtual-um-demo.sh stop
```

The runner will auto-stop it in non-interactive mode, but it's cleaner to
do it yourself.

## Don'ts

These are from `refs/osmocom-demo/CLAUDE.md` and will burn a day if you
ignore them:

- Don't `rm -rf ttcn3/` or `rm -f *.ttcn3` — those are hand-written sources,
  not build outputs. Cleanup is `cd ttcn3 && make clean`.
- Don't run `git clean -fdx` in `refs/osmocom-demo/` — same reason.
- Don't edit anything inside `refs/osmocom-demo/` as part of week 0 work.
  This is a frozen reference snapshot for the baseline.

## What "good" looks like by EOD

You can, from memory:

- start the virtual-Um demo, register a subscriber, see "normal service",
  stop it cleanly;
- run one TTCN-3 test, find its verdict and timing in `ttcn3/logs/`;
- run the `smoke` campaign and explain how it differs from running the same
  three tests individually.
