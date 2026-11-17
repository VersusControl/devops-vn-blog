#!/usr/bin/env bash
# Install Istio's observability add-ons from the downloaded release (same version as istioctl).
#
#   ./cluster/addons.sh                     # prometheus and kiali (chapter 2)
#   ./cluster/addons.sh grafana jaeger      # more add-ons (chapter 13)
#
# These are Istio's sample add-on manifests: fine for learning, not tuned for production.
set -euo pipefail
cd "$(dirname "$0")/.."

ISTIO_VERSION="${ISTIO_VERSION:-1.32.0}"
dir=".istio/istio-$ISTIO_VERSION/samples/addons"
if [[ ! -d "$dir" ]]; then
  echo "Istio $ISTIO_VERSION is not downloaded yet. Run ./cluster/install-istio.sh first." >&2
  exit 1
fi

addons=("$@")
(( ${#addons[@]} )) || addons=(prometheus kiali)

for addon in "${addons[@]}"; do
  kubectl apply -f "$dir/$addon.yaml"
done
for addon in "${addons[@]}"; do
  kubectl -n istio-system rollout status "deploy/$addon" --timeout=300s
done
