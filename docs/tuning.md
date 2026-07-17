# Node-Level Tuning — W6.2

**Question:** do any of the kernel-level limits called out in the internship plan
(`net.netfilter.nf_conntrack_max`, `fs.inotify.max_user_*`, `net.ipv4.ip_local_port_range`,
`ulimit -n`) need to be raised to support parallel test execution, or is the node's default
configuration already enough?

**Method:** rather than raising limits speculatively, the actual per-run consumption of each
limit was pulled from `host-samples.csv` on the highest-concurrency runs already captured
(week 5's N=11 sliding-window campaign) and compared against the sysctl/ulimit ceilings
recorded in `docs/baseline.md`.

## Measured headroom at N=11

Source: `results/week05/run20260623-105203-N11/host-samples.csv` (max value observed across
the run).

| Limit | Ceiling (cn083 default) | Observed peak at N=11 | Headroom used |
|---|---|---|---|
| `net.netfilter.nf_conntrack_max` | 1,572,864 | 5,346 (`conntrack_count`) | 0.3% |
| `ulimit -n` (open files) | 1,048,576 | 206,688 (`fd_used`) | ~20% |
| `net.ipv4.ip_local_port_range` | 28,231 ports | 1,024 (`tcp_tw`, TIME_WAIT sockets) | ~3.6% |
| `fs.inotify.max_user_watches` | 65,536 | 18 (`inotify_watches`) | <0.1% |

## Conclusion

None of the four kernel limits called out in the internship plan are anywhere close to
saturation at N=11 — the closest, open file descriptors, is still sitting under 20% of the
ulimit. **No sysctl or ulimit change was applied**, because none was justified by the data:
raising an already-generously-headroomed limit would add configuration drift without fixing
anything.

This matches the conclusion reached independently in `docs/find-max-parallel-namespaces.md`
and `docs/final-report.md` (Section 8): on this class of hardware, the binding constraints
are the Kubernetes 110-pods-per-node default and available RAM, not any of the kernel-level
counters this task was scoped to check. The internship plan's own acceptance criteria for
this task allows for exactly this outcome — apply node-level fixes "only as needed and only
with justification" — and the justification here is that the measured data shows no need.

## If a future server *does* show pressure on one of these

The method to re-check is the same one used here: pull `conntrack_count`, `fd_used`,
`tcp_tw`, and `inotify_watches` from `host-samples.csv` on the highest-N run available for
that server, and compare against its `docs/baseline.md`-style host capacity numbers. If any
of them crosses roughly 70–80% of its ceiling, that is the point to raise the corresponding
sysctl/ulimit — not before.
