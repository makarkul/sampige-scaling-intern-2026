#!/usr/bin/env python3
"""Turn a run directory's events.csv into summary.json.

Usage:
    scripts/summarize.py results/runs/<run-dir>
"""
import csv
import json
import sys
from pathlib import Path

PHASES = ["t0", "t_apply", "t_ready", "t_attached",
          "t_test0", "t_testN", "t_teardown"]


def load_events(events_csv: Path) -> dict[str, dict[str, float]]:
    per_ns: dict[str, dict[str, float]] = {}
    with events_csv.open() as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            per_ns.setdefault(row["namespace"], {})[row["phase"]] = float(row["unix_ts"])
    return per_ns


def derive(per_ns: dict[str, dict[str, float]]) -> dict:
    namespaces = []
    for ns, ts in per_ns.items():
        def d(a: str, b: str) -> float | None:
            if a in ts and b in ts:
                return round(ts[b] - ts[a], 3)
            return None

        namespaces.append({
            "namespace": ns,
            "bringup_s":  d("t0", "t_attached"),
            "testing_s":  d("t_test0", "t_testN"),
            "teardown_s": d("t_testN", "t_teardown"),
            "total_s":    d("t0", "t_teardown"),
        })

    if not namespaces:
        return {"namespaces": [], "T_suite_s": None}

    t0_min = min((ts["t0"] for ts in per_ns.values() if "t0" in ts), default=None)
    end_max = max((ts.get("t_teardown", ts.get("t_testN", 0)) for ts in per_ns.values()),
                  default=None)
    t_suite = round(end_max - t0_min, 3) if t0_min and end_max else None

    return {
        "namespaces": namespaces,
        "T_suite_s": t_suite,
        "N": len(namespaces),
    }


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    run_dir = Path(sys.argv[1])
    events = run_dir / "events.csv"
    if not events.exists():
        print(f"no events.csv in {run_dir}", file=sys.stderr)
        return 1
    summary = derive(load_events(events))
    (run_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
