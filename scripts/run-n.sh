#!/usr/bin/env bash
# Launch N namespaces in parallel, run the suite in each, aggregate results.
#
# Usage:
#   scripts/run-n.sh <N> [--prefix gsm] [--keep]
#
# Writes to: results/weekNN/run<YYYYMMDD>-<HHMMSS>-N<N>/
#   meta.json
#   events.csv          (concatenated from per-namespace events)
#   host-samples.csv    (collected by scripts/collect-host.sh in background)
#   summary.json        (produced by scripts/summarize.py)
#   ns-<i>/             (per-namespace outputs)

set -euo pipefail

N="${1:?usage: run-n.sh <N> [--prefix gsm] [--keep]}"
PREFIX="gsm"
KEEP=""

shift
while (($#)); do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --keep)   KEEP="--keep"; shift ;;
    *)        echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

DEMO_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/refs/osmocom-demo"
BASE="${DEMO_REPO}/k8s/base"

WEEK=${WEEK:-$(date -u +%V)}
TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="results/week${WEEK}/run${TS}-N${N}"
mkdir -p "${OUT_DIR}"

SUITE_REV=$(git -C "${DEMO_REPO}" rev-parse --short HEAD 2>/dev/null || echo unknown)
IMAGE_TAGS=$(grep -h 'image:' "${BASE}"/*.yaml 2>/dev/null \
  | sed 's/.*image:[[:space:]]*//' | sort -u | paste -sd ',' - || echo unknown)

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

# Launch N namespaces in parallel
pids=()
for i in $(seq 1 "${N}"); do
  ns="${PREFIX}-${i}"
  ns_dir="${OUT_DIR}/ns-${i}"
  mkdir -p "${ns_dir}"
  ( RUN_ONE_OUT="${ns_dir}" scripts/run-one.sh "${ns}" > "${ns_dir}/run-one-outer.log" 2>&1
  ) &
  pids+=($!)
done

fail=0
for pid in "${pids[@]}"; do
  wait "${pid}" || fail=$((fail+1))
done

# Aggregate events
{
  echo "namespace,phase,unix_ts"
  for i in $(seq 1 "${N}"); do
    tail -n +2 "${OUT_DIR}/ns-${i}/events.csv" 2>/dev/null || true
  done
} > "${OUT_DIR}/events.csv"

# Aggregate pods
{
  echo "namespace,pod,container,restarts,oom_killed,exit_code"
  for i in $(seq 1 "${N}"); do
    tail -n +2 "${OUT_DIR}/ns-${i}/pods.csv" 2>/dev/null || true
  done
} > "${OUT_DIR}/pods.csv"

# Stop host collection
kill "${HOST_PID}" 2>/dev/null || true
wait "${HOST_PID}" 2>/dev/null || true

# Summarize
python3 scripts/summarize.py "${OUT_DIR}"

echo "done: ${OUT_DIR}  (failures=${fail})"
exit "${fail}"
