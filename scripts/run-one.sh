#!/usr/bin/env bash
# Bring up one namespace of the osmocom + TTCN-3 stack, run the suite, tear down.
#
# Usage:
#   scripts/run-one.sh <namespace> [--keep]
#
# Writes results to: results/runs/<timestamp>-<namespace>/
#
# Intern TODO:
#   - Point CHART_PATH at the Helm chart from week 3 (or kustomize overlay)
#   - Fill in the TTCN-3 job manifest / values that actually run the suite
#   - Replace the readiness probe loop with whatever signals "MS attached"

set -euo pipefail

NS="${1:?usage: run-one.sh <namespace> [--keep]}"
KEEP="${2:-}"

CHART_PATH="${CHART_PATH:-k8s/chart}"
SUITE_TIMEOUT="${SUITE_TIMEOUT:-3600}"   # seconds
READY_TIMEOUT="${READY_TIMEOUT:-300}"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-${NS}"
OUT_DIR="results/runs/${RUN_ID}"
mkdir -p "${OUT_DIR}"

event() {
  # event <phase>
  printf '%s,%s,%s\n' "${NS}" "$1" "$(date -u +%s.%N)" >> "${OUT_DIR}/events.csv"
}

cleanup() {
  if [[ "${KEEP}" != "--keep" ]]; then
    event teardown_start
    kubectl delete ns "${NS}" --wait=true --timeout=300s >/dev/null 2>&1 || true
    event teardown_end
  fi
}
trap cleanup EXIT

echo "namespace,phase,unix_ts" > "${OUT_DIR}/events.csv"

event t0
kubectl create ns "${NS}" >/dev/null
event ns_created

helm install "${NS}" "${CHART_PATH}" \
  --namespace "${NS}" \
  --set namespace="${NS}" \
  --wait --timeout "${READY_TIMEOUT}s"
event t_ready

# TODO: replace with a real attach check (poll BSC/MSC logs or MS state)
kubectl -n "${NS}" wait --for=condition=Ready pod -l role=ms --timeout="${READY_TIMEOUT}s"
event t_attached

# Run the TTCN-3 job in the same namespace
kubectl -n "${NS}" apply -f k8s/jobs/ttcn3-suite.yaml
event t_test0
kubectl -n "${NS}" wait --for=condition=complete job/ttcn3-suite --timeout="${SUITE_TIMEOUT}s"
event t_testN

# Pull reports
mkdir -p "${OUT_DIR}/ttcn3"
kubectl -n "${NS}" cp "$(kubectl -n "${NS}" get pod -l job-name=ttcn3-suite -o name | head -1 | cut -d/ -f2)":/reports "${OUT_DIR}/ttcn3" || true

echo "done: ${OUT_DIR}"
