#!/usr/bin/env bash
# Run the N ∈ {1,2,4,8} × 3 measurement matrix with a fixed test suite.
#
# Usage:
#   WEEK=04 scripts/run-matrix.sh [TC1 TC2 ...]
#
# With no arguments the default suite is 8 × TC_26_2_3.
# N=1 runs first (3 reps) to establish the baseline T_suite(1); subsequent
# N=2/4/8 runs receive --baseline so summarize.py writes S(N) and E(N).
#
# Outputs:
#   results/week${WEEK}/matrix-<TS>.log     — full run log
#   results/week${WEEK}/plots-<TS>/         — 4 required PNG plots

set -euo pipefail

WEEK=${WEEK:-04}
REPS=3

if [ $# -eq 0 ]; then
  SUITE=(TC_26_2_3 TC_26_2_3 TC_26_2_3 TC_26_2_3 TC_26_2_3 TC_26_2_3 TC_26_2_3 TC_26_2_3)
else
  SUITE=("$@")
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="results/week${WEEK}/matrix-${TS}.log"
PLOTS="results/week${WEEK}/plots-${TS}"
mkdir -p "results/week${WEEK}" "${PLOTS}"

log() { echo "[matrix] $*" | tee -a "${LOG}"; }

ALL_DIRS=()
N1_DIRS=()
LAST_RUN_DIR=""

# Run run-n.sh once and capture the output directory in LAST_RUN_DIR.
# run-n.sh exits with the count of namespace failures — tolerate that here.
run_once() {
  local workers="$1"
  local baseline_arg="${2:-}"    # e.g. "--baseline 500.1"
  local tmp
  tmp=$(mktemp)
  # shellcheck disable=SC2086
  WEEK="${WEEK}" scripts/run-n.sh --workers "${workers}" ${baseline_arg} "${SUITE[@]}" \
    2>&1 | tee "${tmp}" | tee -a "${LOG}" || true
  LAST_RUN_DIR=$(grep "^done:" "${tmp}" | awk '{print $2}')
  rm -f "${tmp}"
}

# ── Phase 1: N=1 × REPS — establish baseline ──────────────────────────────────

log "===== Phase 1: N=1 baseline (${REPS} reps) ====="
for rep in $(seq 1 "${REPS}"); do
  log "  rep ${rep}/${REPS} ..."
  run_once 1
  if [ -n "${LAST_RUN_DIR}" ]; then
    N1_DIRS+=("${LAST_RUN_DIR}")
    ALL_DIRS+=("${LAST_RUN_DIR}")
    log "  -> ${LAST_RUN_DIR}"
  else
    log "  WARNING: could not determine run directory for rep ${rep}"
  fi
done

if [ ${#N1_DIRS[@]} -eq 0 ]; then
  log "ERROR: all N=1 runs failed to produce output — cannot establish baseline"
  exit 1
fi

# Compute median T_suite(1) from the completed N=1 runs
BASELINE=$(python3 - "${N1_DIRS[@]}" <<'EOF'
import json, sys
vals = []
for d in sys.argv[1:]:
    try:
        data = json.loads(open(d + "/summary.json").read())
        t = data.get("T_suite_s")
        if t:
            vals.append(t)
    except Exception:
        pass
if not vals:
    print(0)
else:
    vals.sort()
    n = len(vals)
    print(vals[n // 2] if n % 2 == 1 else (vals[n // 2 - 1] + vals[n // 2]) / 2)
EOF
)
log "  T_suite(1) baseline = ${BASELINE}s"

# Regenerate N=1 summaries with the baseline so S/E appear in summary.json
for d in "${N1_DIRS[@]}"; do
  python3 scripts/summarize.py "${d}" --baseline "${BASELINE}" > /dev/null || true
done

# ── Phases 2-4: N=2,4,8 × REPS ───────────────────────────────────────────────

for N in 2 4 8; do
  log "===== N=${N} (${REPS} reps, baseline=${BASELINE}s) ====="
  for rep in $(seq 1 "${REPS}"); do
    log "  rep ${rep}/${REPS} ..."
    run_once "${N}" "--baseline ${BASELINE}"
    if [ -n "${LAST_RUN_DIR}" ]; then
      ALL_DIRS+=("${LAST_RUN_DIR}")
      log "  -> ${LAST_RUN_DIR}"
    else
      log "  WARNING: could not determine run directory for N=${N} rep ${rep}"
    fi
  done
done

# ── Generate plots ─────────────────────────────────────────────────────────────

log "===== Generating plots ====="
if [ ${#ALL_DIRS[@]} -gt 0 ]; then
  python3 scripts/plot.py "${ALL_DIRS[@]}" --out "${PLOTS}"
  log "  -> ${PLOTS}"
else
  log "  WARNING: no run directories collected; skipping plots"
fi

log "===== Matrix complete ====="
log "  Total runs : ${#ALL_DIRS[@]}"
log "  Log        : ${LOG}"
log "  Plots      : ${PLOTS}"
