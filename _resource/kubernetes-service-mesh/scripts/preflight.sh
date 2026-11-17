#!/usr/bin/env bash
# Check this machine before you start the series.
# Run from _resource/kubernetes-service-mesh:  ./scripts/preflight.sh
set -uo pipefail

fail=0
ok()   { printf '  ok    %s\n' "$*"; }
warn() { printf '  warn  %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; fail=1; }

echo "Tools"
for tool in docker kind kubectl curl; do
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool found"; else bad "$tool not found"; fi
done

if command -v kind >/dev/null 2>&1; then
  v="$(kind version 2>/dev/null | awk '{print $2}')"
  case "$v" in
    v0.3[3-9]*|v[1-9]*) ok "kind $v" ;;
    *) warn "kind $v: the series is tested with v0.33.0" ;;
  esac
fi

echo "Docker"
if ! docker info >/dev/null 2>&1; then
  bad "Docker is not running"
else
  mem_bytes="$(docker info --format '{{.MemTotal}}')"
  mem_gb=$((mem_bytes / 1024 / 1024 / 1024))
  if   (( mem_gb >= 7 )); then ok "Docker memory ${mem_gb} GB"
  elif (( mem_gb >= 5 )); then warn "Docker memory ${mem_gb} GB: enough for most chapters, 8 GB recommended"
  else bad "Docker memory ${mem_gb} GB: give Docker at least 6 GB (8 GB recommended)"
  fi
  cpus="$(docker info --format '{{.NCPU}}')"
  if (( cpus >= 4 )); then ok "Docker CPUs $cpus"; else warn "Docker CPUs $cpus: 4 or more recommended"; fi
fi

echo "Ports (the Kind cluster publishes these on 127.0.0.1)"
for port in 8080 8443 9080; do
  if kind get clusters 2>/dev/null | grep -qx mesh; then
    ok "port $port (cluster 'mesh' already exists)"
  elif (echo >"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1; then
    bad "port $port is in use. Stop that program or change hostPort in cluster/kind-config.yaml"
  else
    ok "port $port free"
  fi
done

echo
if (( fail )); then echo "Fix the FAIL lines above, then run this script again."; exit 1; fi
echo "Ready."
