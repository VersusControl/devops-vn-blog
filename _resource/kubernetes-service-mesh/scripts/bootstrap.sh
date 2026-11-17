#!/usr/bin/env bash
# Build a fresh cluster in the starting state of a chapter.
#
#   ./scripts/bootstrap.sh 01
#   ./scripts/bootstrap.sh 05
#
# This deletes the cluster named "mesh" if it exists. Use it when a cluster is in
# an unknown state, or to start a chapter without doing the earlier ones.
set -euo pipefail
cd "$(dirname "$0")/.."

chapter="${1:-}"
if [[ ! "$chapter" =~ ^[0-9]{2}$ ]] || (( 10#$chapter < 1 || 10#$chapter > 15 )); then
  echo "usage: $0 <chapter number from 01 to 15, for example 03>" >&2
  exit 2
fi
n=$((10#$chapter))

./scripts/preflight.sh

if kind get clusters 2>/dev/null | grep -qx mesh; then
  echo "Deleting the existing cluster 'mesh'"
  kind delete cluster --name mesh
fi
kind create cluster --config cluster/kind-config.yaml

step() { printf '\n==> %s\n' "$*"; }

# Chapter 1 starts with an empty cluster. The chapter deploys Book Store itself.

if (( n == 15 )); then
  # Chapter 15 installs Istio with Helm from the release archives: download 1.32.0 (and its
  # istioctl). The chapter downloads 1.31.4 itself.
  step "Downloading Istio"
  ./cluster/install-istio.sh download
fi

if (( n == 2 || n == 15 )); then
  # Chapter 2 starts with Book Store running without Istio (the end of chapter 1).
  # Chapter 15 starts the same way, on a new cluster, and installs Istio with Helm.
  step "Deploying Book Store without Istio"
  kubectl apply -k app
  ./scripts/wait-for-app.sh
fi

if (( n >= 3 && n <= 14 )); then
  # End of chapter 2: Istio installed, Book Store in the mesh, Prometheus and Kiali.
  step "Installing Istio"
  ./cluster/install-istio.sh
  step "Deploying Book Store into the mesh"
  kubectl apply -f app/namespace.yaml
  kubectl label namespace bookstore istio-injection=enabled --overwrite
  kubectl apply -k app
  ./scripts/wait-for-app.sh
  step "Installing Prometheus and Kiali"
  ./cluster/addons.sh
fi

if (( n >= 4 && n <= 14 )); then
  # End of chapter 3: Book Store reachable at http://bookstore.local:8080.
  step "Exposing Book Store through the ingress gateway"
  kubectl apply -f 03-gateway-virtualservice/gateway.yaml
  kubectl apply -f 03-gateway-virtualservice/virtualservice.yaml
fi

if (( n >= 7 && n <= 14 )); then
  # End of chapter 6: the reviews subsets v1, v2, v3 exist (no VirtualService for reviews).
  step "Defining the reviews subsets"
  kubectl apply -f 06-traffic-shifting/destinationrule-reviews.yaml
fi

if (( n >= 12 && n <= 14 )); then
  # End of chapter 11: STRICT mutual TLS for the bookstore namespace.
  step "Requiring mutual TLS in bookstore"
  kubectl apply -f 11-mtls/peerauthentication-strict.yaml
fi

echo
echo "Cluster ready for chapter $chapter."
if (( n >= 3 )); then
  echo "Put this series' istioctl first on your PATH:  export PATH=\"\$PWD/bin:\$PATH\""
fi
