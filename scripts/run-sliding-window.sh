#!/usr/bin/env bash
# Sliding-window test runner — true dynamic dispatch from a campaign file.
#
# Maintains a pool of N concurrent test slots.  As each test finishes, its slot
# immediately claims the next test from a shared queue, so up to N tests are
# always running until the campaign is exhausted.  This is the key difference
# from run-n.sh, which pre-assigns tests to workers round-robin before any test
# starts.
#
# Usage:
#   WEEK=05 scripts/run-sliding-window.sh \
#       --workers N --campaign FILE [--keep] [--baseline SECONDS]
#
# --workers N       pool size — max concurrent tests (default: 8)
# --campaign FILE   INI-format campaign file (e.g. scripts/sliding-window-campaign.cfg)
# --keep            keep namespaces after each test (passed to run-one.sh)
# --baseline S      serial wall-time in seconds; enables S(N) and E(N) in summary
#
# Namespace naming
#   Each test runs in a k8s namespace of the form:  <tc-slug>-<slot>
#   e.g. TC_26_6_1_1 in slot 3  →  tc-26-6-1-1-3
#
#   run-one.sh derives GSMTAP multicast groups from the trailing integer of the
#   namespace name.  Concurrent slots always have distinct slot numbers, so they
#   always get distinct GSMTAP groups and their virtual radio stacks cannot
#   interfere.  Tests within the same slot run serially, so reusing the group
#   between their successive runs is safe.
#
# Output: results/weekNN/run<YYYYMMDD>-<HHMMSS>-N<N>/
#   meta.json
#   events.csv           (aggregated from all per-test events)
#   host-samples.csv     (run-level host metrics)
#   pods.csv             (aggregated pod health)
#   test-durations.csv   (per-test start/end/duration/verdict)
#   summary.json         (produced by scripts/summarize.py)
#   ns-<slot>/           (one directory per worker slot)
#     <TC_name>/         (per-test outputs written by run-one.sh)

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────

KEEP=""
BASELINE=""
WORKERS=8
CAMPAIGN=""

while (($#)); do
  case "$1" in
    --keep)      KEEP="--keep";  shift ;;
    --baseline)  BASELINE="$2";  shift 2 ;;
    --workers)   WORKERS="$2";   shift 2 ;;
    --campaign)  CAMPAIGN="$2";  shift 2 ;;
    -*)  echo "unknown flag: $1" >&2; exit 2 ;;
    *)   echo "unexpected argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$CAMPAIGN" ]; then
  echo "usage: run-sliding-window.sh --campaign FILE [--workers N] [--keep] [--baseline SECONDS]" >&2
  exit 2
fi

if [ ! -f "$CAMPAIGN" ]; then
  echo "campaign file not found: $CAMPAIGN" >&2
  exit 2
fi

# ── Campaign file parsing ─────────────────────────────────────────────────────
# Reads every line matching "TC_name = ..." from the INI file.
# Ignores [section] headers, blank lines, and # comments.

TESTS=()
while IFS= read -r line; do
  line="${line%%#*}"   # strip inline comments
  [[ "$line" =~ ^[[:space:]]*(TC_[A-Za-z0-9_]+)[[:space:]]*= ]] || continue
  TESTS+=("${BASH_REMATCH[1]}")
done < "$CAMPAIGN"

if [ ${#TESTS[@]} -eq 0 ]; then
  echo "no tests found in campaign file: $CAMPAIGN" >&2
  exit 2
fi

N=${WORKERS}

# ── Paths ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEMO_REPO="${REPO_ROOT}/refs/osmocom-demo"
BASE="${DEMO_REPO}/k8s/base"

# ── Output directory ──────────────────────────────────────────────────────────

WEEK=${WEEK:-$(date -u +%V)}
TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="${REPO_ROOT}/results/week${WEEK}/run${TS}-N${N}"
mkdir -p "${OUT_DIR}"

# ── meta.json ─────────────────────────────────────────────────────────────────

SUITE_REV=$(git -C "${DEMO_REPO}" rev-parse --short HEAD 2>/dev/null || echo unknown)
IMAGE_TAGS=$(grep -h 'image:' "${BASE}"/*.yaml 2>/dev/null \
  | sed 's/.*image:[[:space:]]*//' | sort -u | paste -sd ',' - || true)
IMAGE_TAGS="${IMAGE_TAGS:-unknown}"
IMAGE_TAGS="${IMAGE_TAGS//$'\n'/,}"

cat > "${OUT_DIR}/meta.json" <<EOF
{
  "N": ${N},
  "timestamp_utc": "${TS}",
  "host": "$(hostname)",
  "kernel": "$(uname -r)",
  "cpus": $(nproc),
  "mem_kb": $(awk '/MemTotal/ {print $2}' /proc/meminfo),
  "k3s_version": "$(k3s --version 2>/dev/null | head -1 || echo unknown)",
  "image_tags": "${IMAGE_TAGS}",
  "suite_revision": "${SUITE_REV}"
}
EOF

# ── Host metric collection ────────────────────────────────────────────────────

"${SCRIPT_DIR}/collect-host.sh" "${OUT_DIR}/host-samples.csv" &
HOST_PID=$!
trap 'kill ${HOST_PID} 2>/dev/null || true' EXIT

# ── Queue setup ───────────────────────────────────────────────────────────────
# One TC name per line.  Workers atomically pop from the front using flock(1).

QUEUE_FILE="${OUT_DIR}/.queue"
QUEUE_LOCK="${OUT_DIR}/.queue.lock"
printf '%s\n' "${TESTS[@]}" > "${QUEUE_FILE}"
: > "${QUEUE_LOCK}"

# ── claim_next ────────────────────────────────────────────────────────────────
# Atomically reads and removes the first line from QUEUE_FILE.
# Prints the TC name, or prints nothing when the queue is exhausted.
#
# This is the mutex (binary semaphore) at the heart of the sliding window:
#   flock -x           →  P() / lock   — blocks until no other worker holds it
#   read + delete      →  critical section, executes exclusively
#   subshell exit      →  V() / unlock — fd 9 closes, kernel releases the lock
#
# Two workers calling claim_next simultaneously will serialize: the second
# blocks on flock until the first has finished its read-and-delete and exited
# the subshell.  No two workers ever claim the same test.

claim_next() {
  (
    flock -x 9
    local tc
    tc=$(head -n1 "${QUEUE_FILE}" 2>/dev/null || true)
    if [ -n "$tc" ]; then
      tail -n +2 "${QUEUE_FILE}" > "${QUEUE_FILE}.tmp" \
        && mv "${QUEUE_FILE}.tmp" "${QUEUE_FILE}" \
        || true
    fi
    printf '%s' "$tc"
  ) 9>"${QUEUE_LOCK}"
}

# ── Worker ────────────────────────────────────────────────────────────────────
# Each worker loops: claim next test → run it via run-one.sh → repeat.
# The loop exits when claim_next returns empty, meaning the queue is exhausted.
#
# The slot number is fixed for the worker's lifetime and serves two purposes:
#   1. Output path  →  ns-<slot>/<TC_name>/  (same layout as run-n.sh)
#   2. Namespace suffix  →  <tc-slug>-<slot>
#      run-one.sh extracts the trailing integer from the namespace name to
#      assign a unique GSMTAP multicast group per slot.  Since concurrent slots
#      always have distinct numbers, their virtual radio stacks never interfere.

worker() {
  local slot=$1
  trap - EXIT   # workers must not inherit the parent's HOST_PID cleanup trap

  while true; do
    local tc
    tc=$(claim_next)
    [ -z "$tc" ] && break   # queue exhausted — this slot is done

    # Derive k8s namespace: lowercase TC name, underscores → hyphens, append slot.
    # grep -oE '[0-9]+$' on the result always yields the slot number.
    local ns
    ns="$(echo "${tc}" | tr '[:upper:]_' '[:lower:]-')-${slot}"

    local ns_dir="${OUT_DIR}/ns-${slot}"
    local tc_dir="${ns_dir}/${tc}"
    mkdir -p "${tc_dir}"

    # run-one.sh owns the full Helm lifecycle for this test:
    #   helm install → wait_deployments → wait_attached → wait_boot_lu_clear
    #   → run TTCN-3 job → collect verdict → helm uninstall → kubectl delete ns
    RUN_ONE_OUT="${tc_dir}" "${DEMO_REPO}/scripts/run-one.sh" "${ns}" "${tc}" \
      >> "${ns_dir}/run-one-outer.log" 2>&1 || true
    # When run-one.sh returns, loop back and claim the next test immediately.
  done
}

# ── Launch worker pool ────────────────────────────────────────────────────────
# All N workers start simultaneously.  Each races to claim the first test from
# the queue.  Subsequent claims happen as each test finishes, maintaining up to
# N concurrent tests for the duration of the campaign.

pids=()
for i in $(seq 1 "${N}"); do
  worker "$i" &
  pids+=($!)
done

fail=0
for pid in "${pids[@]}"; do
  wait "${pid}" || fail=$((fail + 1))
done

# ── Aggregate events.csv ──────────────────────────────────────────────────────

{
  echo "namespace,phase,unix_ts"
  for i in $(seq 1 "${N}"); do
    for f in "${OUT_DIR}/ns-${i}"/*/events.csv; do
      [ -f "$f" ] && tail -n +2 "$f" || true
    done
  done
} > "${OUT_DIR}/events.csv"

# ── Aggregate pods.csv ────────────────────────────────────────────────────────

{
  echo "namespace,pod,container,restarts,oom_killed,exit_code"
  for i in $(seq 1 "${N}"); do
    for f in "${OUT_DIR}/ns-${i}"/*/pods.csv; do
      [ -f "$f" ] && tail -n +2 "$f" || true
    done
  done
} > "${OUT_DIR}/pods.csv"

# ── Aggregate test-durations.csv ──────────────────────────────────────────────

{
  echo "namespace,tc_name,start_ts,end_ts,duration_s,verdict"
  for i in $(seq 1 "${N}"); do
    for f in "${OUT_DIR}/ns-${i}"/*/test-durations.csv; do
      [ -f "$f" ] && tail -n +2 "$f" || true
    done
  done
} > "${OUT_DIR}/test-durations.csv"

# ── Stop host collection ──────────────────────────────────────────────────────

kill "${HOST_PID}" 2>/dev/null || true
wait "${HOST_PID}" 2>/dev/null || true

# ── Summarize ─────────────────────────────────────────────────────────────────

baseline_arg=""
[ -n "${BASELINE}" ] && baseline_arg="--baseline ${BASELINE}"
python3 "${SCRIPT_DIR}/summarize.py" "${OUT_DIR}" ${baseline_arg}

echo "done: ${OUT_DIR}  (failures=${fail})"
exit "${fail}"
