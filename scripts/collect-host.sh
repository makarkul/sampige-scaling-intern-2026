#!/usr/bin/env bash
# Sample host-level metrics at 1 Hz until killed.
#
# Usage:
#   scripts/collect-host.sh <output.csv>
#
# Columns: unix_ts, cpu_pct, mem_used_kb, load1, conntrack_count,
#          conntrack_max, fd_used, tcp_tw

set -euo pipefail

OUT="${1:?usage: collect-host.sh <out.csv>}"

cpus=$(nproc)
echo "unix_ts,cpu_pct,mem_used_kb,load1,conntrack_count,conntrack_max,fd_used,tcp_tw" > "${OUT}"

# Prime CPU sample
prev=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)

while true; do
  read -r total_now idle_now <<< "$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)"
  read -r total_prev idle_prev <<< "${prev}"
  dt=$((total_now - total_prev))
  di=$((idle_now - idle_prev))
  cpu_pct=$(awk -v dt="${dt}" -v di="${di}" 'BEGIN { if (dt==0) print 0; else printf "%.2f", 100.0*(dt-di)/dt }')
  prev="${total_now} ${idle_now}"

  mem_used=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print t-a}' /proc/meminfo)
  load1=$(awk '{print $1}' /proc/loadavg)
  ct_count=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 0)
  ct_max=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo 0)
  fd_used=$(awk '{print $1}' /proc/sys/fs/file-nr 2>/dev/null || echo 0)
  tcp_tw=$(ss -tan state time-wait 2>/dev/null | wc -l)

  printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$(date -u +%s)" "${cpu_pct}" "${mem_used}" "${load1}" \
    "${ct_count}" "${ct_max}" "${fd_used}" "${tcp_tw}" >> "${OUT}"

  sleep 1
done
