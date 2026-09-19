# Kubernetes Basics Task API

This directory contains the dependency-free Node.js API and Kubernetes resources used by
the Kubernetes Basics series. The Kubernetes resources intentionally contain two safe
placeholders:

- `YOUR_GITHUB_OWNER` in `04-deployment.yaml` must be replaced with the GitHub user or
  organization that owns the GHCR image.
- `02-secret.example.yaml` is an example only. Copy it outside version control or create
  the Secret with `kubectl create secret`; never commit a real token.

## Validate locally

```sh
cd task-api
npm test
node --check src/server.js
docker build -t task-api:local .
kubectl kustomize ../kubernetes
```

The image is designed for Node.js 20. Create the local Kind cluster with:

```sh
kind create cluster --name kubernetes-basics --config kind-config.yaml
```

Apply the namespace, ConfigMap, PVC, deployment, and Service after creating the Secret:

```sh
kubectl apply -f kubernetes/02-secret.example.yaml
kubectl apply -k kubernetes/
```