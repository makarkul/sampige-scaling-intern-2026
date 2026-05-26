#!/usr/bin/env bash
# Thin wrapper: real run-one.sh lives in refs/osmocom-demo/.
# This wrapper is where metrics-contract instrumentation will be added
# so the source repo doesn't need to know about our measurement schema.

set -euo pipefail

META_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec "${META_ROOT}/refs/osmocom-demo/scripts/run-one.sh" "$@"
