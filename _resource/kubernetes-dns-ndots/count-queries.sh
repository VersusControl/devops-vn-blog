#!/usr/bin/env bash
# Resolve a name once from a Pod and print the DNS queries CoreDNS received for it.
#   ./count-queries.sh app-default api.github.com
set -euo pipefail
POD="$1"; NAME="$2"
sleep 9   # let earlier queries fall out of the 8-second log window
kubectl exec "$POD" -- getent ahosts "$NAME" >/dev/null
sleep 2
kubectl -n kube-system logs -l k8s-app=kube-dns --since=8s --prefix=false \
  | grep -E '"(A|AAAA) IN' \
  | sed -E 's/.*"(A|AAAA) IN ([^ ]+) .*" (NOERROR|NXDOMAIN) .*/\1 \2 \3/'
