#!/usr/bin/env bash
# Launch N namespaces in parallel, run the suite in each, aggregate results.
#
# Usage:
#   scripts/run-n.sh <N> [--prefix gsm] [--keep]
#
# Writes to: results/runs/<timestamp>-N<N>/
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

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="results/runs/${TS}-N${N}"
mkdir -p "${OUT_DIR}"

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
  "image_tags": "TODO: capture from chart values",
  "suite_revision": "TODO: capture from suite repo"
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
  ( scripts/run-one.sh "${ns}" ${KEEP} > "${OUT_DIR}/ns-${i}.log" 2>&1
    mkdir -p "${OUT_DIR}/ns-${i}"
    # The most recent run dir for this namespace:
    latest="$(ls -1dt results/runs/*-"${ns}" 2>/dev/null | head -1 || true)"
    if [[ -n "${latest}" && -d "${latest}" ]]; then
      mv "${latest}"/* "${OUT_DIR}/ns-${i}/" 2>/dev/null || true
      rmdir "${latest}" 2>/dev/null || true
    fi
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

# Stop host collection
kill "${HOST_PID}" 2>/dev/null || true
wait "${HOST_PID}" 2>/dev/null || true

# Summarize
python3 scripts/summarize.py "${OUT_DIR}"

echo "done: ${OUT_DIR}  (failures=${fail})"
exit "${fail}"
