#!/usr/bin/env bash
# Build a separate kubeconfig for the dev-viewer ServiceAccount.
# Your own kubeconfig is not changed. Run it with your admin context active.
#
#   scripts/make-kubeconfig.sh [duration]     # default 8h
set -euo pipefail
DURATION="${1:-8h}"
OUT="dev-viewer.kubeconfig"

# Server address and CA of the cluster you are connected to now.
SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
CA_DATA="$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"

# A short-lived token for the ServiceAccount. Nothing is stored in the cluster.
TOKEN="$(kubectl -n dev create token dev-viewer --duration="$DURATION")"

# Write everything into the new file only.
export KUBECONFIG="$OUT"
kubectl config set-cluster shared-cluster --server="$SERVER" >/dev/null
kubectl config set "clusters.shared-cluster.certificate-authority-data" "$CA_DATA" >/dev/null
kubectl config set-credentials dev-viewer --token="$TOKEN" >/dev/null
kubectl config set-context dev-viewer --cluster=shared-cluster --user=dev-viewer --namespace=dev >/dev/null
kubectl config use-context dev-viewer >/dev/null
chmod 600 "$OUT"
echo "Wrote $OUT (token valid for $DURATION)"
