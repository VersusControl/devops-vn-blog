#!/usr/bin/env bash
# Install a pinned Argo CD version into the argocd namespace and wait for it.
set -euo pipefail
VERSION="${1:-v3.6.3}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${VERSION}/manifests/install.yaml"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
