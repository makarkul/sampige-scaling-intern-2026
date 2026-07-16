# Parallel Namespace Scaling — Capacity Planning Method

**Context:** Kubernetes-based parallel test execution platform for the Osmocom GSM stack.
Each parallel worker is a namespace running a full GSM stack (multiple pods) plus a TTCN-3
test job. This document captures the method used to calculate how many namespaces can run
in parallel on a given server, why memory (not CPU) is usually the binding constraint, and
how to reproduce this calculation on any new server.

---

## 1. The problem

Running N namespaces in parallel means N × (stack pods) all competing for the same node's
CPU, RAM, and the Kubernetes hard pod-count limit. Running too many causes overcommitted
pods and throttling and running too few wastes available hardware. The goal is a
repeatable formula for picking N on any server.

There are **three independent ceilings**. The real answer is whichever one is *smallest*:

1. **RAM ceiling** — total memory available vs. memory per namespace
2. **CPU ceiling** — total CPU available vs. CPU per namespace
3. **Pod-count ceiling** — Kubernetes' default 110-pods-per-node limit

---

## 2. Core formula

```
W_ram = floor( (RAM_available − RAM_reserve) / RAM_per_stack )
W_cpu = floor( (CPU_cores − CPU_reserve) / CPU_per_stack )
W_pod = floor( (110 − system_pods) / pods_per_namespace )

max_parallel_namespaces = max( 1, min(W_ram, W_cpu, W_pod) )
```

- `RAM_reserve` / `CPU_reserve` account for the OS, k3s/k8s control plane, containerd,
  local image registry, and image cache.
- `pods_per_namespace` = every pod a single namespace spins up (stack pods + the TTCN-3
  job pod itself).
- `system_pods` = pods already running outside test namespaces (kube-system, registry, etc.).

In this project, **RAM turned out to be the binding constraint on every server tested** —
CPU had headroom to spare. This is expected: the GSM stack processes are protocol-timer /
I/O-bound rather than CPU-hot, so they idle on CPU while still holding memory.

---

## 3. Grounded constants (flat-reserve method)

These were the constants measured directly from this project and used for quick estimates
on lab hardware:

| Constant | Value | Why |
|---|---|---|
| `RAM_per_stack` | 4 GB | measured working set of one namespace (10 pods + TITAN job) |
| `RAM_reserve` | 4 GB | OS + k3s control plane + containerd + local registry + image cache |
| `CPU_per_stack` | 1.5 vCPU | stacks are protocol-timer / I/O-bound, not CPU-hot |
| `CPU_reserve` | 2 cores | headroom for k3s/system |
| `pods_per_namespace` | 9 | 8 stack pods + 1 TTCN-3 job pod |
| `system_pods` | 5 | always-present cluster pods (kube-system, registry, etc.) |

### Worked examples

| Runner | Specs | W_ram | W_cpu | min(W_ram, W_cpu) | What actually happened |
|---|---|---|---|---|---|
| Laptop | 12 CPU, 19 GB RAM | (19−4)/4 = **3** | (12−2)/1.5 = **6** | 3 | Ran **N=6** in practice — above the RAM-bound estimate, but held steady with no observed issues. |
| CI/CD server | ~16 CPU, ~48 GB RAM | (48−4)/4 = **11** | (16−2)/1.5 = **9** | 9 | No pod-count limit was set on this server. Ran **N=6** conservatively (~48% RAM used), well under both the RAM and CPU ceilings, prioritizing reproducibility over squeezing out the last few workers. |

**Takeaway:** the formula gives a theoretical ceiling, not a target to hit exactly. On the
laptop, the CPU-bound number (6) turned out to be usable in practice despite RAM being the
tighter constraint on paper; on the CI/CD server, N was kept well under both ceilings for
stability and reproducible test results.

---

## 4. Pod-count ceiling (Kubernetes default limit)

Kubernetes defaults to a **110 pods per node** limit regardless of how much CPU/RAM is free.
On the CDAC server this was the first ceiling hit:

```
Safe max N = floor( (110 − system_pods) / pods_per_namespace )
           = floor( (110 − 5) / 9 )
           = 11
```

This is why the CDAC server was tested with **N = 11**.

---

## 5. Precise CPU-bound method (millicore measurement)

The flat `CPU_per_stack = 1.5 vCPU` constant is a coarse estimate. For a more precise,
server-specific number, measure actual per-pod CPU usage under load and derive a millicore
budget:

```
cpu_per_namespace                 = max_cpu_per_pod × pods_per_namespace
cpu_per_namespace_with_headroom   = cpu_per_namespace × 1.2
effective_cpu_per_pod             = cpu_per_namespace_with_headroom / pods_per_namespace
total_cluster_cpu_millicores      = CPU_cores × 1000
max_pods_cpu_bound                = floor(total_cluster_cpu_millicores / effective_cpu_per_pod)
W_cpu_precise                     = floor(max_pods_cpu_bound / pods_per_namespace)
```

**CDAC server example (48 cores):**
- `max_cpu_per_pod` = 34m (observed)
- `cpu_per_namespace` = 34m × 9 = 306m → +20% headroom = **370m**
- `effective_cpu_per_pod` = 370/9 ≈ **41m**
- `total_cluster_cpu` = 48,000m
- `max_pods_cpu_bound` = 48,000 / 41 ≈ **1,170 pods**
- `W_cpu_precise` = 1,170 / 9 ≈ **130 namespaces (theoretical, CPU-only)**


---

## 6. Precise RAM-bound method (percentage safe-ceiling)

Rather than a flat `RAM_reserve` in GB (which doesn't scale well across very different
server sizes), the more robust method uses a **percentage-based safe ceiling** plus the
*actual* baseline memory already in use (not just an assumed reserve):

```
1. safe_ceiling   = 0.85 × total_RAM_GB          (85% of total RAM — leave 15% headroom for OS/kernel/cache spikes)
2. baseline       = MemTotal − MemAvailable       (from /proc/meminfo, measured at start of run)
3. headroom       = safe_ceiling − baseline
4. W_ram_precise  = floor(headroom / avg_RAM_per_namespace)
```

**CDAC server example (187.6 GB total RAM):**
- `safe_ceiling` = 0.85 × 187.6 = **159.5 GB**
- `baseline` (already in use, unstable/shared environment) ≈ **101 GB**
- `headroom` = 159.5 − 101 = **58.5 GB**
- `avg_RAM_per_namespace` = **1.82 GB** (measured)
- `W_ram_precise` = floor(58.5 / 1.82) = **32 namespaces**

**Result: on the CDAC server, RAM was the binding constraint (32) — far below the
CPU-bound theoretical ceiling (130).** This matches the general finding across every
server in this project: size for RAM first, then sanity-check against CPU and pod count.

---

## 7. Server hardware reference (CDAC server, `lscpu`)

For reproducibility, the CDAC test server used for the above calculation:

```
Architecture:        x86_64
CPU(s):               48 (2 sockets × 24 cores, 1 thread/core, SMT disabled)
Model:                Intel(R) Xeon(R) Platinum 8268 CPU @ 2.90GHz
CPU max/min MHz:      3900.0 / 1200.0
NUMA node(s):         2 (node0: CPU 0-23, node1: CPU 24-47)
L1d/L1i:              1.5 MiB (48 instances)
L2:                   48 MiB (48 instances)
L3:                   71.5 MiB (2 instances)
Virtualization:       VT-x (bare-metal Xeon, not a virtualized/QEMU guest)
```
---

## 8. General Steps — applying this to *any* new server

1. **Get hardware specifications**
   ```
   lscpu                      # CPU cores
   free -h                    # total RAM
   cat /proc/meminfo          # MemTotal, MemAvailable (baseline usage)
   ```

2. **Measure per-namespace footprint** (run one namespace in isolation under real load):
   ```
   kubectl top pods -n <test-namespace>
   ```
   Record: `pods_per_namespace`, `max_cpu_per_pod`, `avg_RAM_per_namespace` (sum of all pod
   memory in one namespace).

3. **Compute all three ceilings:**
   - `W_ram` — use Section 6 (percentage safe-ceiling method) for the most robust result on
     unfamiliar hardware; use Section 3's flat-GB method only as a fast rough estimate.
   - `W_cpu` — use Section 5 (millicore method) for precision; use Section 3's flat-vCPU constant as a
     fast rough estimate.
   - `W_pod` — use Section 4, adjusting `system_pods` for whatever's already running on that cluster.

4. **Take the minimum** of the three — that's the *safe theoretical maximum*.

5. **Apply a conservative margin.** In this project the theoretical maximum was never run
   at 100% — always leave headroom for reproducibility, log-collection overhead, and
   variance in individual test runtimes:
   ```
   recommended_N = min(theoretical_max, floor(theoretical_max × 0.7–0.85))
   ```
   (e.g. CI/CD server theoretical = 9 → ran at 6; laptop theoretical = 3–6 → ran at 6.)

6. **Validate empirically.** Run a full test campaign at the chosen N and confirm:
   - No pod evictions / OOMKills
   - Pass/fail rates match expected baseline (no silent failures introduced by resource
     starvation)
   - Measured speedup `S(N)` is close to linear up to that N (a big drop-off signals you've
     exceeded the real ceiling regardless of what the formula said)

---

## 9. Summary — key numbers from this project

| Server | Total CPU | Total RAM | W_ram | W_cpu | W_pod | Binding factor | N actually used |
|---|---|---|---|---|---|---|---|
| Laptop | 12 cores | 19 GB | 3 | 6 | — | RAM | 6 |
| CI/CD server | 16 cores | 48 GB | 11 | 9 | — (no limit set) | CPU | 6 |
| CDAC server | 48 cores | 187.6 GB | **32** | 130 | 11 | **RAM** (pod-count limited the actual test run; 32 is the RAM ceiling for future runs without that limit) | 11 |

**Bottom line:** memory is almost always the binding constraint for this workload, because
the GSM stack pods are I/O/timer-bound rather than CPU-hot — they sit on memory without
burning CPU. CPU headroom is usually generous; the Kubernetes 110-pods-per-node default is
the one ceiling that can bite unexpectedly on smaller test batches even when both RAM and
CPU have room to spare.
