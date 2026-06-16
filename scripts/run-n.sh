#!/usr/bin/env bash
# Launch N workers in parallel, sharding tests round-robin across them.
# Each worker runs its assigned tests serially, spinning up a fresh namespace
# per test (bring up → run → tear down → next test).  This gives clean state
# per test (same as a serial run) while still reducing wall time by N×.
#
# Usage:
#   scripts/run-n.sh [--prefix gsm] [--keep] [--baseline SECONDS] --workers N TC1 [TC2 ...]
#
# --workers N   number of parallel workers (defaults to number of tests)
#
# Writes to: results/weekNN/run<YYYYMMDD>-<HHMMSS>-N<N>/
#   meta.json
#   events.csv           (concatenated from per-test events)
#   host-samples.csv     (collected by scripts/collect-host.sh in background)
#   test-durations.csv   (per-test start/end/duration/verdict)
#   summary.json         (produced by scripts/summarize.py)
#   ns-<i>/              (per-worker outputs)
#     <TC_name>/         (per-test outputs from run-one.sh)

set -euo pipefail

PREFIX="gsm"
KEEP=""
BASELINE=""
WORKERS=""
TESTS=()

while (($#)); do
  case "$1" in
    --prefix)   PREFIX="$2"; shift 2 ;;
    --keep)     KEEP="--keep"; shift ;;
    --baseline) BASELINE="$2"; shift 2 ;;
    --workers)  WORKERS="$2"; shift 2 ;;
    -*)         echo "unknown flag: $1" >&2; exit 2 ;;
    *)          TESTS+=("$1"); shift ;;
  esac
done

if [ ${#TESTS[@]} -eq 0 ]; then
  echo "usage: run-n.sh [--prefix gsm] [--keep] [--baseline SECONDS] [--workers N] TC1 [TC2 ...]" >&2
  exit 2
fi

N=${WORKERS:-${#TESTS[@]}}

DEMO_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/refs/osmocom-demo"
BASE="${DEMO_REPO}/k8s/base"

WEEK=${WEEK:-02}
TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="results/week${WEEK}/run${TS}-N${N}"
mkdir -p "${OUT_DIR}"

SUITE_REV=$(git -C "${DEMO_REPO}" rev-parse --short HEAD 2>/dev/null || echo unknown)
IMAGE_TAGS=$(grep -h 'image:' "${BASE}"/*.yaml 2>/dev/null \
  | sed 's/.*image:[[:space:]]*//' | sort -u | paste -sd ',' - || true)
IMAGE_TAGS="${IMAGE_TAGS:-unknown}"
IMAGE_TAGS="${IMAGE_TAGS//$'\n'/,}"

# Capture host facts up front
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

# Start host metric collection in background
scripts/collect-host.sh "${OUT_DIR}/host-samples.csv" &
HOST_PID=$!
trap 'kill ${HOST_PID} 2>/dev/null || true' EXIT

# Build per-worker buckets via round-robin.
# Each test slot gets a globally unique namespace: gsm-1, gsm-2, ..., gsm-T
# so that events.csv has distinct namespace keys and logs are easy to trace.
for i in $(seq 1 "$N"); do
  declare -a "bucket_${i}=()"
done
for idx in "${!TESTS[@]}"; do
  slot=$(( (idx % N) + 1 ))
  declare -n _b="bucket_${slot}"
  # Store "namespace:TC" so each test carries its unique namespace name
  _b+=("${PREFIX}-$(( idx + 1 )):${TESTS[$idx]}")
  unset -n _b
done

# Launch workers in parallel — skip any bucket that ended up empty
# (happens when --workers N > number of tests)
pids=()
active=0
for i in $(seq 1 "${N}"); do
  declare -n _b="bucket_${i}"
  if [ ${#_b[@]} -eq 0 ]; then
    unset -n _b
    continue
  fi
  active=$((active + 1))
  ns_dir="${OUT_DIR}/ns-${i}"
  mkdir -p "${ns_dir}"
  _bucket=("${_b[@]}")
  (
    for entry in "${_bucket[@]}"; do
      ns="${entry%%:*}"
      TC="${entry#*:}"
      tc_dir="${ns_dir}/${TC}"
      mkdir -p "${tc_dir}"
      RUN_ONE_OUT="${tc_dir}" scripts/run-one.sh "${ns}" "${TC}" \
        >> "${ns_dir}/run-one-outer.log" 2>&1 || true
    done
  ) &
  pids+=($!)
  unset -n _b
done

fail=0
for pid in "${pids[@]}"; do
  wait "${pid}" || fail=$((fail+1))
done

# Aggregate events (one subdir per test under each ns-i/)
{
  echo "namespace,phase,unix_ts"
  for i in $(seq 1 "${N}"); do
    for f in "${OUT_DIR}/ns-${i}"/*/events.csv; do
      [ -f "$f" ] && tail -n +2 "$f" || true
    done
  done
} > "${OUT_DIR}/events.csv"

# Aggregate pods
{
  echo "namespace,pod,container,restarts,oom_killed,exit_code"
  for i in $(seq 1 "${N}"); do
    for f in "${OUT_DIR}/ns-${i}"/*/pods.csv; do
      [ -f "$f" ] && tail -n +2 "$f" || true
    done
  done
} > "${OUT_DIR}/pods.csv"

# Aggregate per-test durations
{
  echo "namespace,tc_name,start_ts,end_ts,duration_s,verdict"
  for i in $(seq 1 "${N}"); do
    for f in "${OUT_DIR}/ns-${i}"/*/test-durations.csv; do
      [ -f "$f" ] && tail -n +2 "$f" || true
    done
  done
} > "${OUT_DIR}/test-durations.csv"

# Stop host collection
kill "${HOST_PID}" 2>/dev/null || true
wait "${HOST_PID}" 2>/dev/null || true

# Summarize
baseline_arg=""
[ -n "${BASELINE}" ] && baseline_arg="--baseline ${BASELINE}"
python3 scripts/summarize.py "${OUT_DIR}" ${baseline_arg}

echo "done: ${OUT_DIR}  (failures=${fail})"
exit "${fail}"
