#!/usr/bin/env bash
# Sample host-level metrics at 1 Hz until killed.
#
# Usage:
#   scripts/collect-host.sh <output.csv>
#
# Columns: unix_ts, cpu_pct, mem_used_kb, load1, conntrack_count,
#          conntrack_max, fd_used, tcp_tw, net_rx_bytes, net_tx_bytes,
#          disk_read_bytes, disk_write_bytes, container_count, pod_count,
#          inotify_watches

set -euo pipefail

OUT="${1:?usage: collect-host.sh <out.csv>}"

# k3s CNI bridge interface
BRIDGE="${COLLECT_BRIDGE:-cni0}"

echo "unix_ts,cpu_pct,mem_used_kb,load1,conntrack_count,conntrack_max,fd_used,tcp_tw,net_rx_bytes,net_tx_bytes,disk_read_bytes,disk_write_bytes,container_count,pod_count,inotify_watches" > "${OUT}"

# Prime CPU sample
prev_cpu=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)

# Prime network sample — rx_bytes and tx_bytes for the bridge
read_net() {
  awk -v iface="${BRIDGE}:" '$1==iface {print $2, $10}' /proc/net/dev 2>/dev/null || echo "0 0"
}
prev_net=$(read_net)

# Prime disk sample — sectors read/written across whole disks only (no partitions)
# Sectors are 512 bytes each; multiply to get bytes.
read_disk() {
  awk '$3 ~ /^(sd[a-z]|vd[a-z]|nvme[0-9]+n[0-9]+|xvd[a-z])$/ {r+=$6*512; w+=$10*512} END {print r+0, w+0}' \
    /proc/diskstats 2>/dev/null || echo "0 0"
}
prev_disk=$(read_disk)

while true; do
  # CPU utilization (delta ticks since last sample)
  read -r total_now idle_now <<< "$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)"
  read -r total_prev idle_prev <<< "${prev_cpu}"
  dt=$((total_now - total_prev))
  di=$((idle_now - idle_prev))
  cpu_pct=$(awk -v dt="${dt}" -v di="${di}" 'BEGIN { if (dt==0) print 0; else printf "%.2f", 100.0*(dt-di)/dt }')
  prev_cpu="${total_now} ${idle_now}"

  # Memory, load
  mem_used=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print t-a}' /proc/meminfo)
  load1=$(awk '{print $1}' /proc/loadavg)

  # Conntrack, file descriptors, TCP TIME_WAIT
  ct_count=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 0)
  ct_max=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo 0)
  fd_used=$(awk '{print $1}' /proc/sys/fs/file-nr 2>/dev/null || echo 0)
  tcp_tw=$(ss -tan state time-wait 2>/dev/null | wc -l)

  # Network throughput on bridge (bytes since last sample)
  curr_net=$(read_net)
  read -r rx_now tx_now <<< "${curr_net}"
  read -r rx_prev tx_prev <<< "${prev_net}"
  net_rx=$(( rx_now - rx_prev ))
  net_tx=$(( tx_now - tx_prev ))
  prev_net="${curr_net}"

  # Disk throughput across all physical disks (bytes since last sample)
  curr_disk=$(read_disk)
  read -r dr_now dw_now <<< "${curr_disk}"
  read -r dr_prev dw_prev <<< "${prev_disk}"
  disk_r=$(( dr_now - dr_prev ))
  disk_w=$(( dw_now - dw_prev ))
  prev_disk="${curr_disk}"

  # Container and pod counts via crictl
  # Use || : (not || echo 0) to avoid double output when crictl exits non-zero
  container_count=$(crictl ps -q 2>/dev/null | wc -l || :)
  pod_count=$(crictl pods -q 2>/dev/null | wc -l || :)

  # Inotify watches in use — use find+xargs to avoid ARG_MAX with large /proc
  inotify_watches=$(
    find /proc -maxdepth 3 -type f -path '*/fdinfo/*' -print0 2>/dev/null \
      | xargs -0 grep -h '^inotify' 2>/dev/null \
      | wc -l || :
  )
  inotify_watches=${inotify_watches:-0}

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$(date -u +%s)" "${cpu_pct}" "${mem_used}" "${load1}" \
    "${ct_count}" "${ct_max}" "${fd_used}" "${tcp_tw}" \
    "${net_rx}" "${net_tx}" "${disk_r}" "${disk_w}" \
    "${container_count}" "${pod_count}" "${inotify_watches}" >> "${OUT}"

  sleep 1
done
