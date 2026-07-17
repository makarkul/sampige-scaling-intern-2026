# Runbook — Install, Deploy, Run, Read, Tear Down

This is the operational guide for reproducing the headline speed-up numbers in
`docs/final-report.md` on a fresh single-node server. It assumes a bare Linux
box with no Kubernetes installed yet.

## 1. Install k3s on a fresh server

```bash
curl -sfL https://get.k3s.io | sh -
sudo k3s kubectl get nodes           # confirm the node is Ready
```

Point `kubectl` at the k3s config so plain `kubectl`/`helm` work without `sudo k3s`:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u)":"$(id -g)" ~/.kube/config
kubectl get nodes
```

Confirm `helm` and `kompose` are installed (`helm version`, `kompose version`) — both
are used by the chart / conversion workflow, not by the launcher scripts directly.

## 2. Clone the repo and build images

```bash
git clone <this-repo-url> && cd sampige-scaling-intern-2026
git submodule update --init --recursive     # pulls refs/osmocom-demo

cd refs/osmocom-demo
./build-images.sh                            # one-time; builds all stack images
cd ../..
```

Confirm the images landed where k3s's containerd can see them (k3s uses its own
containerd, not the host Docker daemon) — `k3s ctr images ls` should list the
`osmo-*` and `msc-test-stub` images built above.

## 3. Deploy the chart — one namespace, sanity check

Before running anything in parallel, confirm a single namespace works:

```bash
scripts/run-one.sh gsm-1 TC_26_2_3
```

This brings up the full 8-pod GSM stack + a TTCN-3 job pod in namespace `gsm-1`
via the Helm chart (`refs/osmocom-demo/k8s/chart/`), runs `TC_26_2_3`, and tears
the namespace down on exit. Check the result:

```bash
cat results/week*/run*-N1/summary.json   # pass/fail + timing for the run just made
```

If this doesn't pass, stop here — nothing downstream will work until a single
namespace is healthy. See `docs/open-issues.md` and `docs/final-report.md`
Section 12 for the bugs already found and fixed in this area.

## 4. Run N namespaces in parallel

Two launchers exist, for two different scheduling strategies (see
`docs/final-report.md` Section 11 for why the sliding-window one is preferred):

**Static round-robin** (`scripts/run-n.sh`) — pre-assigns tests to N workers up front:

```bash
scripts/run-n.sh --workers 8 --baseline <serial_seconds> \
  TC_26_2_3 TC_26_6_1_1 TC_26_6_2_1_1 TC_26_6_8_2 TC_26_7_2_1 TC_26_7_4_1 TC_26_8_1_2_1_1 TC_34_2_2
```

**Sliding-window dispatch** (`scripts/run-sliding-window.sh`) — keeps N slots
continuously busy, pulling the next test from a shared, `flock`-protected queue
the moment a slot frees up:

```bash
scripts/run-sliding-window.sh --workers 11 \
  --campaign scripts/sliding-window-campaign.cfg \
  --baseline <serial_seconds>
```

Optional flags on either launcher:
- `--cpu-limit 300m` — apply a per-namespace `ResourceQuota`/`LimitRange` (see
  `docs/final-report.md` Section 13 for how to pick this value for a given N).
- `--keep` — leave namespaces up after their test finishes (debugging only；
  don't use this for a real timing run, it will distort teardown costs).

## 5. Pick N for a new server

Don't guess N. Use the capacity-planning method in
`docs/find-max-parallel-namespaces.md`:

1. Get hardware specs (`lscpu`, `free -h`, `/proc/meminfo`).
2. Run one namespace, measure its footprint (`kubectl top pods -n <ns>`).
3. Compute the three ceilings — RAM, CPU, and the Kubernetes 110-pods-per-node
   limit — and take the minimum.
4. Apply a conservative margin (that document recommends ~70–85% of the
   theoretical max) rather than running at the exact ceiling.
5. Validate with a full campaign at the chosen N: no OOMKills, no pod
   evictions, pass rate matches the known-good baseline, and `S(N)` is close
   to linear (a big drop-off means the real ceiling was overshot regardless of
   what the formula said).

## 6. Read the results

Every run (`run-one.sh`, `run-n.sh`, `run-sliding-window.sh`) writes to
`results/week<NN>/run<YYYYMMDD-HHMMSS>-N<N>/`:

| File | What's in it |
|---|---|
| `meta.json` | N, image tags, k3s version, kernel, host facts |
| `events.csv` | per-namespace phase timestamps (`t0`, `t_apply`, `t_ready`, `t_attached`, `t_test0`, `t_testN`, `t_teardown`) |
| `host-samples.csv` | 1 Hz CPU/mem/conntrack/fd/pod-count samples for the run |
| `test-durations.csv` | per-test start/end/duration/verdict |
| `pods.csv` | pod restarts, OOM kills, exit codes |
| `summary.json` | derived `T_suite`, `S(N)`, `E(N)`, per-namespace pass/fail counts |

Full field definitions are in `docs/metrics.md`. Regenerate the four required
plots (`T_suite` vs N, `S(N)` vs N, phase-stacked bar, CPU timeline) from any
set of `summary.json` files with:

```bash
python3 scripts/plot.py results/week*/run*/summary.json
```

Never hand-edit a plot — if the presentation needs to change, change
`plot.py` so the plots stay reproducible from raw data.

## 7. Tear down

Normal runs tear themselves down automatically on exit (each launcher's
cleanup trap deletes its namespace(s) even on failure). If a run was aborted
mid-way (Ctrl-C, crash) and left namespaces behind:

```bash
kubectl get ns | grep '^gsm-'                 # find leftover namespaces
kubectl delete ns gsm-1 gsm-2 ...              # or: kubectl get ns -o name | grep gsm- | xargs kubectl delete
```

Stale namespaces left running measurably slow down the next parallel run (see
`week03/reflection.md`) — always confirm the cluster is clean
(`kubectl get ns`, `kubectl get pods -A`) before starting a new timing run.

## 8. Known gotchas (read before your first real run)

- **CPU limit is not one fixed number.** It depends on N — see
  `docs/final-report.md` Section 13. 250m/namespace was safe at N=8 but not at
  N=16.
- **N is capped at 11 on the reference 48-core / 110-pod server**, not by RAM
  or CPU but by Kubernetes' default pod-count limit. Re-derive this for any
  new server with `docs/find-max-parallel-namespaces.md`.
- **One test (`TC_26_6_1_1`, ~412s) dominates the tail** of any suite it's
  included in — expect the wall-clock floor to sit near its runtime regardless
  of N.
- **Health probes have caused real bugs here twice** — if a test starts
  failing right after scaling up, check the liveness/readiness probes on the
  affected pod before assuming the test itself regressed.
- **Two scripts can silently drift.** `scripts/run-sliding-window.sh` once
  called a stale copy of `run-one.sh` instead of the current one in
  `refs/osmocom-demo/scripts/`, producing an entire batch of false failures
  (week07). If a batch fails identically across every test, confirm which
  script path actually executed before concluding the tests themselves are
  broken.
