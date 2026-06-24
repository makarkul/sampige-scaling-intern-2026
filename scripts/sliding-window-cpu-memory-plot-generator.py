#!/usr/bin/env python3
"""Generate CPU and memory vs concurrent namespaces plots from pod-resources.csv.

Usage:
    scripts/sliding-window-cpu-memory-plot-generator.py

Reads pod-resources.csv from the three week05 runs (N=1, N=8, N=11) and writes:
    results/week05/cpu-vs-namespaces.png
    results/week05/memory-vs-namespaces.png
"""

import csv
from collections import defaultdict
from pathlib import Path
import statistics

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np

REPO_ROOT = Path(__file__).resolve().parent.parent

RUNS = {
    "N=1":  (REPO_ROOT / "results/week05/run20260623-073129-N1/pod-resources.csv",  "gsm-"),
    "N=8":  (REPO_ROOT / "results/week05/run20260623-071306-N8/pod-resources.csv",  "tc-"),
    "N=11": (REPO_ROOT / "results/week05/run20260623-105203-N11/pod-resources.csv", "tc-"),
}

OUT_DIR = REPO_ROOT / "results/week05"


def load_run(path: Path, prefix: str) -> dict[int, tuple[float, float]]:
    """Return {concurrent_ns_count: (median_cpu_m, median_mem_mib)}."""
    rows = [r for r in csv.DictReader(path.open()) if r["namespace"].startswith(prefix)]

    ts_ns  = defaultdict(set)
    ts_cpu = defaultdict(float)
    ts_mem = defaultdict(float)
    for r in rows:
        ts = r["unix_ts"]
        ts_ns[ts].add(r["namespace"])
        if r["cpu_m"]:   ts_cpu[ts] += float(r["cpu_m"])
        if r["mem_mib"]: ts_mem[ts] += float(r["mem_mib"])

    group_cpu = defaultdict(list)
    group_mem = defaultdict(list)
    for ts, nss in ts_ns.items():
        n = len(nss)
        group_cpu[n].append(ts_cpu[ts])
        group_mem[n].append(ts_mem[ts])

    return {
        n: (statistics.median(group_cpu[n]), statistics.median(group_mem[n]))
        for n in sorted(group_cpu)
    }


def linear_fit(xs, ys):
    """Return (slope, intercept) for a least-squares fit."""
    coeffs = np.polyfit(xs, ys, 1)
    return coeffs[0], coeffs[1]


def make_plot(metric: str, ylabel: str, unit: str,
              data_per_run: dict[str, dict[int, tuple]],
              out_path: Path) -> None:
    idx = 0 if metric == "cpu" else 1

    fig, ax = plt.subplots(figsize=(9, 5))
    fig.patch.set_facecolor("#0f1117")
    ax.set_facecolor("#161b22")

    colors = {"N=1": "#58a6ff", "N=8": "#3fb950", "N=11": "#f78166"}
    markers = {"N=1": "o", "N=8": "s", "N=11": "^"}
    # plot N=1 last so its single point renders on top of the others
    plot_order = ["N=8", "N=11", "N=1"]

    all_xs, all_ys = [], []

    for label in plot_order:
        run_data = data_per_run[label]
        xs = sorted(run_data.keys())
        ys = [run_data[x][idx] for x in xs]
        all_xs.extend(xs)
        all_ys.extend(ys)

        is_n1 = label == "N=1"
        ax.plot(xs, ys,
                color=colors[label], marker=markers[label],
                linewidth=1.5, markersize=10 if is_n1 else 6,
                markeredgewidth=1.5 if is_n1 else 0,
                markeredgecolor="#e6edf3" if is_n1 else colors[label],
                label=label, alpha=0.9, zorder=5 if is_n1 else 3)

    # linear fit across all data
    slope, intercept = linear_fit(all_xs, all_ys)
    fit_xs = np.linspace(1, 16, 200)
    fit_ys = slope * fit_xs + intercept
    ax.plot(fit_xs, fit_ys,
            color="#8b949e", linewidth=1, linestyle="--",
            label=f"linear fit  ({slope:+.1f}{unit}/ns)", alpha=0.7)

    # extrapolated markers at N=13 and N=16
    for n_proj in [13, 16]:
        y_proj = slope * n_proj + intercept
        ax.axvline(n_proj, color="#8b949e", linewidth=0.6, linestyle=":", alpha=0.5)
        ax.annotate(f"N={n_proj}\n~{y_proj:.0f}{unit}",
                    xy=(n_proj, y_proj),
                    xytext=(n_proj + 0.3, y_proj * 1.05),
                    color="#8b949e", fontsize=8,
                    arrowprops=dict(arrowstyle="->", color="#8b949e", lw=0.8))

    ax.set_xlabel("Concurrent namespaces", color="#c9d1d9", fontsize=11)
    ax.set_ylabel(ylabel, color="#c9d1d9", fontsize=11)
    ax.set_title(f"{ylabel} vs concurrent namespaces  (pod-resources.csv)",
                 color="#e6edf3", fontsize=13, pad=12)

    ax.tick_params(colors="#8b949e")
    ax.xaxis.set_major_locator(ticker.MaxNLocator(integer=True))
    for spine in ax.spines.values():
        spine.set_edgecolor("#30363d")

    ax.grid(True, color="#21262d", linewidth=0.7, linestyle="-")
    ax.set_xlim(0, 17)

    legend = ax.legend(facecolor="#161b22", edgecolor="#30363d",
                       labelcolor="#c9d1d9", fontsize=9)

    fig.tight_layout()
    fig.savefig(out_path, dpi=150, bbox_inches="tight",
                facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"saved: {out_path}")


def main() -> None:
    data_per_run = {label: load_run(path, prefix) for label, (path, prefix) in RUNS.items()}

    make_plot(
        metric="cpu", ylabel="Total CPU (millicores)", unit="m",
        data_per_run=data_per_run,
        out_path=OUT_DIR / "cpu-vs-namespaces.png",
    )
    make_plot(
        metric="memory", ylabel="Total memory (MiB)", unit=" MiB",
        data_per_run=data_per_run,
        out_path=OUT_DIR / "memory-vs-namespaces.png",
    )


if __name__ == "__main__":
    main()
