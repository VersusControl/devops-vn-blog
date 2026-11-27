#!/usr/bin/env bash
# Remove everything this example created. Deleting the ServiceAccount also
# revokes every token issued for it, within seconds (the API server caches token checks briefly).
set -euo pipefail
cd "$(dirname "$0")/.."
kubectl delete -f manifests/02-dev-viewer.yaml --ignore-not-found
kubectl delete -f manifests/01-namespaces-and-apps.yaml --ignore-not-found
rm -f dev-viewer.kubeconfig
