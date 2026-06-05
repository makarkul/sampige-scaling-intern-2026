#!/usr/bin/env python3
"""Regenerate the four required plots from one or more run directories.

Usage:
    scripts/plot.py results/runs/* --out results/plots/

Reads summary.json from each run and produces:
    01-tsuite-vs-n.png          T_suite vs N (log-log)
    02-speedup.png               S(N) vs N with y=N ideal line
    03-phase-stacked.png         bringup / testing / teardown averaged per N
    04-cpu-timeline.png          CPU% timeline for best N=1 and best N=max run

Requires: matplotlib
"""
import argparse
import csv
import json
import sys
from pathlib import Path
from statistics import median

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def load_runs(paths: list[Path]) -> list[dict]:
    runs = []
    for p in paths:
        s = p / "summary.json"
        if not s.exists():
            continue
        data = json.loads(s.read_text())
        data["_dir"] = p
        runs.append(data)
    return runs


def median_by_n(runs: list[dict]) -> dict[int, dict]:
    by_n: dict[int, list[dict]] = {}
    for r in runs:
        if r.get("N") and r.get("T_suite_s"):
            by_n.setdefault(r["N"], []).append(r)
    out = {}
    for n, group in by_n.items():
        t_suites = [g["T_suite_s"] for g in group]
        bringups = [ns["bringup_s"] for g in group for ns in g["namespaces"] if ns["bringup_s"]]
        testings = [ns["testing_s"] for g in group for ns in g["namespaces"] if ns["testing_s"]]
        teardowns = [ns["teardown_s"] for g in group for ns in g["namespaces"] if ns["teardown_s"]]
        out[n] = {
            "T_suite": median(t_suites),
            "bringup": median(bringups) if bringups else 0,
            "testing": median(testings) if testings else 0,
            "teardown": median(teardowns) if teardowns else 0,
            "runs": len(group),
        }
    return out


def best_runs_per_n(runs: list[dict], by_n: dict[int, dict]) -> dict[int, dict]:
    """Return {N: run} — the run whose T_suite is closest to the median for that N."""
    best = {}
    for n, stats in by_n.items():
        target = stats["T_suite"]
        group = [r for r in runs if r.get("N") == n and r.get("T_suite_s")]
        if group:
            best[n] = min(group, key=lambda r: abs(r["T_suite_s"] - target))
    return best


def plot_tsuite(by_n: dict[int, dict], out: Path) -> None:
    ns = sorted(by_n)
    ys = [by_n[n]["T_suite"] for n in ns]
    plt.figure()
    plt.loglog(ns, ys, marker="o")
    plt.xlabel("N (parallel namespaces)")
    plt.ylabel("T_suite (s)")
    plt.title("Suite wall-clock vs. N")
    plt.grid(True, which="both", ls=":")
    plt.savefig(out / "01-tsuite-vs-n.png", dpi=150, bbox_inches="tight")
    plt.close()


def plot_speedup(by_n: dict[int, dict], out: Path) -> None:
    if 1 not in by_n:
        return
    base = by_n[1]["T_suite"]
    ns = sorted(by_n)
    s = [base / by_n[n]["T_suite"] for n in ns]
    plt.figure()
    plt.plot(ns, s, marker="o", label="measured")
    plt.plot(ns, ns, ls="--", label="ideal y=N")
    plt.xlabel("N")
    plt.ylabel("speed-up")
    plt.title("Speed-up vs. N")
    plt.legend()
    plt.grid(True, ls=":")
    plt.savefig(out / "02-speedup.png", dpi=150, bbox_inches="tight")
    plt.close()


def plot_phase_stack(by_n: dict[int, dict], out: Path) -> None:
    ns = sorted(by_n)
    bringup = [by_n[n]["bringup"] for n in ns]
    testing = [by_n[n]["testing"] for n in ns]
    teardown = [by_n[n]["teardown"] for n in ns]
    plt.figure()
    plt.bar(ns, bringup, label="bringup")
    plt.bar(ns, testing, bottom=bringup, label="testing")
    bottom = [b + t for b, t in zip(bringup, testing)]
    plt.bar(ns, teardown, bottom=bottom, label="teardown")
    plt.xlabel("N")
    plt.ylabel("seconds (per namespace, median)")
    plt.title("Per-namespace phase breakdown")
    plt.legend()
    plt.savefig(out / "03-phase-stacked.png", dpi=150, bbox_inches="tight")
    plt.close()


def plot_cpu_timeline(best: dict[int, dict], by_n: dict[int, dict], out: Path) -> None:
    """Plot CPU% vs time for the N=1 representative run and the largest-N run."""
    ns = sorted(best)
    if len(ns) < 2:
        return
    n_small, n_large = ns[0], ns[-1]

    fig, axes = plt.subplots(2, 1, figsize=(10, 6), sharey=True)
    for ax, n in zip(axes, [n_small, n_large]):
        run = best[n]
        csv_path = run["_dir"] / "host-samples.csv"
        if not csv_path.exists():
            ax.text(0.5, 0.5, f"N={n}: no host-samples.csv",
                    ha="center", va="center", transform=ax.transAxes)
            ax.set_title(f"N={n}")
            continue

        times: list[float] = []
        cpus: list[float] = []
        with csv_path.open() as fh:
            for row in csv.DictReader(fh):
                try:
                    times.append(float(row["unix_ts"]))
                    cpus.append(float(row["cpu_pct"]))
                except (KeyError, ValueError):
                    pass

        if not times:
            ax.text(0.5, 0.5, f"N={n}: no samples",
                    ha="center", va="center", transform=ax.transAxes)
            ax.set_title(f"N={n}")
            continue

        t0 = times[0]
        ax.plot([t - t0 for t in times], cpus, lw=1)
        ax.set_title(f"N={n}  (T_suite={by_n[n]['T_suite']:.1f}s)")
        ax.set_ylabel("CPU %")
        ax.set_ylim(0, 100)
        ax.grid(True, ls=":")

    axes[-1].set_xlabel("seconds into run")
    plt.suptitle("CPU utilization — representative runs")
    plt.tight_layout()
    plt.savefig(out / "04-cpu-timeline.png", dpi=150, bbox_inches="tight")
    plt.close()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("runs", nargs="+", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    runs = load_runs(args.runs)
    if not runs:
        print("no summary.json files found", file=sys.stderr)
        return 1
    by_n = median_by_n(runs)
    best = best_runs_per_n(runs, by_n)
    plot_tsuite(by_n, args.out)
    plot_speedup(by_n, args.out)
    plot_phase_stack(by_n, args.out)
    plot_cpu_timeline(best, by_n, args.out)
    print(f"wrote plots to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
