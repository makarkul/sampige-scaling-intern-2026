#!/usr/bin/env bash
# Run the docker-compose baseline: bring up the GSM stack, run TC_26_2_3,
# tear down. Prints per-phase wall-clock matching docs/baseline.md.
#
# Usage: scripts/run-baseline.sh [OUTPUT_DIR]
#   OUTPUT_DIR defaults to results/week01
#
# Prerequisites: images must be built (refs/osmocom-demo/build-images.sh).
# No k8s required.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_DIR="$REPO_ROOT/refs/osmocom-demo"
OUT_DIR="${1:-$REPO_ROOT/results/week01}"
TC="TC_26_2_3"

if [[ ! -f "$DEMO_DIR/run-ttcn3-tests.sh" ]]; then
    echo "ERROR: refs/osmocom-demo not found. Run: git submodule update --init --recursive" >&2
    exit 1
fi

if ! docker image inspect osmocom-demo/osmo-bsc:latest &>/dev/null; then
    echo "ERROR: Docker images not built. Run: cd refs/osmocom-demo && ./build-images.sh" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
LOGFILE="$OUT_DIR/run-baseline.log"

echo "[baseline] TC        : $TC"
echo "[baseline] Output    : $OUT_DIR"
echo "[baseline] Log       : $LOGFILE"

T0=$(date +%s.%N)
T0_UTC=$(date -u +%Y%m%d-%H%M%S)

echo "[baseline] Start     : $T0_UTC"

# --- bring-up ---
T_BRINGUP_START=$(date +%s.%N)
(cd "$DEMO_DIR" && ./virtual-um-demo.sh start) 2>&1 | tee -a "$LOGFILE"
T_BRINGUP_END=$(date +%s.%N)
BRINGUP_S=$(echo "$T_BRINGUP_END - $T_BRINGUP_START" | bc)

# --- test execution ---
T_TEST_START=$(date +%s.%N)
(cd "$DEMO_DIR" && ./run-ttcn3-tests.sh "$TC") 2>&1 | tee -a "$LOGFILE"
VERDICT=$?
T_TEST_END=$(date +%s.%N)
TESTING_S=$(echo "$T_TEST_END - $T_TEST_START" | bc)

# --- teardown ---
T_TEARDOWN_START=$(date +%s.%N)
(cd "$DEMO_DIR" && ./virtual-um-demo.sh stop) 2>&1 | tee -a "$LOGFILE"
T_TEARDOWN_END=$(date +%s.%N)
TEARDOWN_S=$(echo "$T_TEARDOWN_END - $T_TEARDOWN_START" | bc)

TOTAL_S=$(echo "$T_TEARDOWN_END - $T0" | bc)

# --- write events.csv ---
cat > "$OUT_DIR/events.csv" <<EOF
run,phase,unix_ts,note
docker-compose,t0,$T0,virtual-um-demo.sh start issued
docker-compose,t_ready,$T_BRINGUP_END,all osmo-* containers Up
docker-compose,t_test0,$T_TEST_START,$TC started
docker-compose,t_testN,$T_TEST_END,$TC finished
docker-compose,t_teardown_end,$T_TEARDOWN_END,virtual-um-demo.sh stop complete
EOF

# --- write summary.json ---
cat > "$OUT_DIR/summary.json" <<EOF
{
  "setup": "docker-compose",
  "timestamp_utc": "$T0_UTC",
  "tc": "$TC",
  "bringup_s": $BRINGUP_S,
  "testing_s": $TESTING_S,
  "teardown_s": $TEARDOWN_S,
  "total_s": $TOTAL_S,
  "exit_code": $VERDICT
}
EOF

echo ""
echo "====================================="
echo " Baseline run complete"
echo "====================================="
printf "  Bring-up  : %.2f s\n" "$BRINGUP_S"
printf "  Testing   : %.2f s\n" "$TESTING_S"
printf "  Teardown  : %.2f s\n" "$TEARDOWN_S"
printf "  Total     : %.2f s\n" "$TOTAL_S"
echo "====================================="
echo "  Results   : $OUT_DIR"
