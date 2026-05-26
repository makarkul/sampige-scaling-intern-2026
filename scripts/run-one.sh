#!/usr/bin/env bash
# Instrumented wrapper for the osmocom-demo run.
# Owns events.csv (metrics contract); kubectl work mirrors refs/osmocom-demo.

set -euo pipefail

META_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_REPO="${META_ROOT}/refs/osmocom-demo"

# ── Arguments ──────────────────────────────────────────────────────────────────

NS="${1:?Usage: run-one.sh <namespace> [TC_NAME ...]}"
shift
TESTS=("$@")

if [ ${#TESTS[@]} -eq 0 ]; then
  TESTS=(TC_26_7_4_5_1 TC_26_7_4_5_2 TC_26_7_4_5_3)
fi

# ── Paths ──────────────────────────────────────────────────────────────────────

BASE="${DEMO_REPO}/k8s/base"
TTCN3_DIR="${DEMO_REPO}/ttcn3"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
RUN_DIR="${META_ROOT}/results/runs/${TIMESTAMP}-${NS}"

mkdir -p "${RUN_DIR}"

# ── Metrics contract ───────────────────────────────────────────────────────────

echo "namespace,phase,unix_ts" > "${RUN_DIR}/events.csv"

event() {
  printf '%s,%s,%s\n' "${NS}" "$1" "$(date -u +%s.%N)" >> "${RUN_DIR}/events.csv"
}

# ── Logging ────────────────────────────────────────────────────────────────────

log()  { echo "[run-one] $*"; }
info() { echo "[run-one] INFO  $*"; }
ok()   { echo "[run-one] PASS  $*"; }
fail() { echo "[run-one] FAIL  $*"; }

exec > >(tee "${RUN_DIR}/run-one.log") 2>&1

log "Namespace : $NS"
log "Tests     : ${TESTS[*]}"
log "Results   : $RUN_DIR"

# Always delete the namespace on exit, even if the script fails mid-run.
cleanup() {
  # Delete the L1CTL socket from inside virtphy (runs as root) before the
  # namespace goes away — host path is root-owned so rm from userspace fails.
  kubectl exec -n "$NS" deployment/virtphy -- rm -f /tmp/osmocom_l2 2>/dev/null || true
  info "Teardown: deleting namespace $NS..."
  kubectl delete namespace "$NS" --wait=true --timeout=300s 2>/dev/null || true
  event t_teardown
}
trap cleanup EXIT

# ── Helpers ────────────────────────────────────────────────────────────────────

apply() {
  local f="$1"
  sed -e "s/namespace: osmocom/namespace: $NS/g" \
      -e "s/name: osmocom$/name: $NS/"           \
      "$f" | kubectl apply -f -
}

apply_dir() {
  for f in "$1"/*.yaml; do
    [[ "$f" == *ttcn3-job* ]] && continue
    apply "$f"
  done
}

wait_deployments() {
  local timeout=${1:-180}
  info "Waiting up to ${timeout}s for Deployments to be Ready..."
  local deadline=$(( $(date +%s) + timeout ))
  while true; do
    local not_ready
    not_ready=$(kubectl get deployments -n "$NS" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"/"}{.status.readyReplicas}{"/"}{.spec.replicas}{"\n"}{end}' 2>/dev/null \
      | awk -F/ '$2 != $3 {print $0}')
    if [ -z "$not_ready" ]; then
      info "All Deployments ready."
      return 0
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      fail "Timeout waiting for Deployments: $not_ready"
      return 1
    fi
    echo "  Not ready: $not_ready"
    sleep 5
  done
}

wait_attached() {
  # Probe for MM_EVENT_CELL_SELECTED rather than "normal service": the msc-stub
  # holds the LU open until TTCN-3 explicitly accepts it, so normal service never
  # fires pre-test. Cell-selected means the radio layer is up and the stack is
  # ready for the test to run.
  local timeout=${1:-300}
  info "Waiting up to ${timeout}s for MS to camp on cell (MM_EVENT_CELL_SELECTED)..."
  local deadline=$(( $(date +%s) + timeout ))
  while true; do
    if kubectl logs -n "$NS" deployment/osmo-mobile 2>/dev/null | grep -q "MM_EVENT_CELL_SELECTED"; then
      info "MS camped on cell."
      return 0
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      fail "Timeout waiting for MS to camp in namespace $NS"
      return 1
    fi
    sleep 5
  done
}

run_test() {
  local TEST_NAME="$1"
  local JOB_NAME
  JOB_NAME="ttcn3-$(echo "$TEST_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
  local TEST_DIR="${RUN_DIR}/${TEST_NAME}"
  mkdir -p "$TEST_DIR"

  info "Running $TEST_NAME as Job $JOB_NAME..."

  kubectl delete job "$JOB_NAME" -n "$NS" --ignore-not-found=true >/dev/null

  sed -e "s/__JOB_NAME__/$JOB_NAME/g"    \
      -e "s/__TEST_NAME__/$TEST_NAME/g"  \
      -e "s/__NAMESPACE__/$NS/g"         \
      "$BASE/ttcn3-job.yaml"             \
    | kubectl apply -f - >/dev/null

  local done=0
  local deadline=$(( $(date +%s) + 2000 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    local succeeded failed
    succeeded=$(kubectl get job "$JOB_NAME" -n "$NS" \
      -o jsonpath='{.status.succeeded}' 2>/dev/null || echo 0)
    failed=$(kubectl get job "$JOB_NAME" -n "$NS" \
      -o jsonpath='{.status.failed}' 2>/dev/null || echo 0)
    if [ "${succeeded:-0}" = "1" ] || [ "${failed:-0}" -ge 1 ]; then
      done=1
      break
    fi
    sleep 3
  done

  local pod
  pod=$(kubectl get pods -n "$NS" -l "job-name=$JOB_NAME" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -n "$pod" ]; then
    kubectl logs -n "$NS" "$pod" > "$TEST_DIR/ttcn3-pod.log" 2>&1 || true
  fi

  if [ "$done" -eq 0 ]; then
    fail "$TEST_NAME: Job timed out"
    echo "INCONCLUSIVE (timeout)" > "$TEST_DIR/verdict.txt"
    return 2
  fi

  local TITAN_DIR
  TITAN_DIR=$(ls -td "$TTCN3_DIR/logs/$TEST_NAME"-* 2>/dev/null | head -1)
  if [ -n "$TITAN_DIR" ] && [ -d "$TITAN_DIR" ]; then
    cp -r "$TITAN_DIR/." "$TEST_DIR/titan-logs/"  2>/dev/null || \
      cp -rp "$TITAN_DIR" "$TEST_DIR/titan-logs"  2>/dev/null || true
    if grep -qi 'verdict: pass' "$TITAN_DIR"/*.log 2>/dev/null; then
      ok "$TEST_NAME: PASS"
      echo "PASS" > "$TEST_DIR/verdict.txt"
      return 0
    elif grep -qi 'verdict: fail' "$TITAN_DIR"/*.log 2>/dev/null; then
      fail "$TEST_NAME: FAIL"
      echo "FAIL" > "$TEST_DIR/verdict.txt"
      return 1
    fi
  fi

  if grep -qi 'verdict: pass' "$TEST_DIR/ttcn3-pod.log" 2>/dev/null; then
    ok "$TEST_NAME: PASS"
    echo "PASS" > "$TEST_DIR/verdict.txt"
    return 0
  elif grep -qi 'verdict: fail' "$TEST_DIR/ttcn3-pod.log" 2>/dev/null; then
    fail "$TEST_NAME: FAIL"
    echo "FAIL" > "$TEST_DIR/verdict.txt"
    return 1
  fi

  fail "$TEST_NAME: INCONCLUSIVE"
  echo "INCONCLUSIVE" > "$TEST_DIR/verdict.txt"
  return 2
}

# ── t0: launcher started ───────────────────────────────────────────────────────

event t0

# ── Images ─────────────────────────────────────────────────────────────────────

if ! curl -sf http://localhost:5000/v2/osmocom-demo/osmo-stp/tags/list 2>/dev/null | grep -q "0.1.5"; then
  info "Images not found in local registry — importing from Docker..."
  bash "${DEMO_REPO}/k8s/import-images.sh"
else
  info "Images already in local registry."
fi

# ── Namespace + Apply → t_apply ────────────────────────────────────────────────

info "Creating namespace $NS..."
kubectl get namespace "$NS" >/dev/null 2>&1 \
  || kubectl create namespace "$NS"

info "Applying manifests from $BASE/ ..."
apply_dir "$BASE"
event t_apply

# ── Wait for Deployments → t_ready ────────────────────────────────────────────

wait_deployments 240
event t_ready

# ── Wait for MS attach → t_attached ───────────────────────────────────────────

wait_attached 300
event t_attached

# ── Run tests → t_test0 … t_testN ─────────────────────────────────────────────

PASS=0; FAIL=0; INCONC=0
declare -A VERDICTS

event t_test0
for TC in "${TESTS[@]}"; do
  run_test "$TC" && VERDICTS[$TC]="PASS" || {
    ec=$?
    if [ $ec -eq 1 ]; then VERDICTS[$TC]="FAIL"
    else VERDICTS[$TC]="INCONCLUSIVE"
    fi
  }
  case "${VERDICTS[$TC]}" in
    PASS) PASS=$((PASS+1)) ;;
    FAIL) FAIL=$((FAIL+1)) ;;
    *)    INCONC=$((INCONC+1)) ;;
  esac
done
event t_testN

# ── Summary ────────────────────────────────────────────────────────────────────

{
  echo "====================================================="
  echo " TTCN-3 k8s Run Summary"
  echo " Namespace : $NS"
  echo " Timestamp : $TIMESTAMP"
  echo "====================================================="
  for TC in "${!VERDICTS[@]}"; do
    printf "  %-40s %s\n" "$TC" "${VERDICTS[$TC]}"
  done | sort
  echo "-----------------------------------------------------"
  echo "  PASS: $PASS   FAIL: $FAIL   INCONCLUSIVE: $INCONC"
  echo "====================================================="
} | tee "${RUN_DIR}/summary.txt"

info "Done. Results: $RUN_DIR"

[ "$FAIL" -eq 0 ]
