#!/usr/bin/env python3
"""Turn a run directory into summary.json.

Usage:
    scripts/summarize.py <run-dir> [--baseline SECONDS]

--baseline  T_suite(1) in seconds; enables S(N) and E(N) computation.
"""
import argparse
import csv
import json
import sys
from pathlib import Path

PHASES = ["t0", "t_apply", "t_ready", "t_attached",
          "t_test0", "t_testN", "t_teardown"]


def load_events(events_csv: Path) -> dict[str, dict[str, float]]:
    per_ns: dict[str, dict[str, float]] = {}
    with events_csv.open() as fh:
        for row in csv.DictReader(fh):
            per_ns.setdefault(row["namespace"], {})[row["phase"]] = float(row["unix_ts"])
    return per_ns


def _ns_name_from_dir(ns_dir: Path) -> str:
    meta = ns_dir / "meta.json"
    if meta.exists():
        return json.loads(meta.read_text()).get("namespace", ns_dir.name)
    ev = ns_dir / "events.csv"
    if ev.exists():
        with ev.open() as fh:
            row = next(csv.DictReader(fh), None)
            if row:
                return row["namespace"]
    return ns_dir.name


def load_verdicts(run_dir: Path) -> dict[str, dict[str, str]]:
    """Return {namespace: {tc_name: verdict}}."""
    result: dict[str, dict[str, str]] = {}
    ns_dirs = sorted(run_dir.glob("ns-*/"))
    if ns_dirs:
        for ns_dir in ns_dirs:
            ns_name = _ns_name_from_dir(ns_dir)
            result[ns_name] = {
                vf.parent.name: vf.read_text().strip()
                for vf in sorted(ns_dir.glob("*/verdict.txt"))
            }
    else:
        meta = run_dir / "meta.json"
        if meta.exists():
            ns_name = json.loads(meta.read_text()).get("namespace", "unknown")
        else:
            ev = run_dir / "events.csv"
            ns_name = "unknown"
            if ev.exists():
                with ev.open() as fh:
                    row = next(csv.DictReader(fh), None)
                    if row:
                        ns_name = row["namespace"]
        result[ns_name] = {
            vf.parent.name: vf.read_text().strip()
            for vf in sorted(run_dir.glob("*/verdict.txt"))
        }
    return result


def load_pods(pods_csv: Path) -> dict | None:
    if not pods_csv.exists():
        return None
    total_restarts = 0
    oom_kills = 0
    with pods_csv.open() as fh:
        for row in csv.DictReader(fh):
            total_restarts += int(row.get("restarts") or 0)
            if row.get("oom_killed") == "true":
                oom_kills += 1
    return {"total_restarts": total_restarts, "oom_kills": oom_kills}


def derive(per_ns: dict[str, dict[str, float]]) -> dict:
    namespaces = []
    for ns, ts in per_ns.items():
        def d(a: str, b: str, _ts: dict = ts) -> float | None:
            if a in _ts and b in _ts:
                return round(_ts[b] - _ts[a], 3)
            return None

        namespaces.append({
            "namespace":  ns,
            "bringup_s":  d("t0", "t_attached"),
            "testing_s":  d("t_test0", "t_testN"),
            "teardown_s": d("t_testN", "t_teardown"),
            "total_s":    d("t0", "t_teardown"),
        })

    if not namespaces:
        return {"namespaces": [], "T_suite_s": None, "N": 0}

    t0_min = min((ts["t0"] for ts in per_ns.values() if "t0" in ts), default=None)
    end_max = max(
        (ts.get("t_teardown", ts.get("t_testN", 0)) for ts in per_ns.values()),
        default=None,
    )
    t_suite = round(end_max - t0_min, 3) if t0_min and end_max else None

    return {
        "namespaces": namespaces,
        "T_suite_s": t_suite,
        "N": len(namespaces),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir")
    parser.add_argument("--baseline", type=float, default=None,
                        metavar="SECONDS",
                        help="T_suite(1) for S(N)/E(N) computation")
    args = parser.parse_args()

    run_dir = Path(args.run_dir)
    events = run_dir / "events.csv"
    if not events.exists():
        print(f"no events.csv in {run_dir}", file=sys.stderr)
        return 1

    summary = derive(load_events(events))

    # Verdicts — merge into per-namespace entries and roll up totals
    verdicts = load_verdicts(run_dir)
    for ns_entry in summary["namespaces"]:
        ns_v = verdicts.get(ns_entry["namespace"], {})
        ns_entry["verdicts"] = ns_v
        ns_entry["pass"]        = sum(1 for v in ns_v.values() if v == "PASS")
        ns_entry["fail"]        = sum(1 for v in ns_v.values() if v == "FAIL")
        ns_entry["inconclusive"] = sum(1 for v in ns_v.values() if v not in ("PASS", "FAIL"))

    all_v = [v for ns_v in verdicts.values() for v in ns_v.values()]
    summary["pass"]        = sum(1 for v in all_v if v == "PASS")
    summary["fail"]        = sum(1 for v in all_v if v == "FAIL")
    summary["inconclusive"] = sum(1 for v in all_v if v not in ("PASS", "FAIL"))

    # Pod health
    pods = load_pods(run_dir / "pods.csv")
    if pods is not None:
        summary["pods"] = pods

    # Speed-up and efficiency (only when baseline is known)
    t_suite = summary.get("T_suite_s")
    n = summary.get("N")
    if args.baseline and t_suite:
        s = round(args.baseline / t_suite, 3)
        summary["T_baseline_s"] = args.baseline
        summary["S"] = s
        summary["E"] = round(s / n, 3) if n else None
    else:
        summary["S"] = None
        summary["E"] = None

    out = run_dir / "summary.json"
    out.write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
