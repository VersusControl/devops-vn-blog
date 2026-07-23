---
layout: post
title: "Working with Kustomize"
series: "ArgoCD"
series_url: /argocd-series/
part: 6
date: 2024-11-24
author: Quan Huynh
tags: [kubernetes, argocd, gitops, kustomize]
image: /assets/images/posts/argocd-06-kustomize/cover.svg
---

In the previous post we used Helm to package and manage our resources. Helm is great
when you need templating and a rich release lifecycle, but it isn't the only option.
For many teams a lighter, template-free approach is enough — and that's exactly what
**Kustomize** gives us. In this post we'll learn how to structure our manifests with
Kustomize and deploy them with ArgoCD.

## What is Kustomize?

Kustomize is a configuration management tool that lets us customize raw, template-free
YAML files for multiple purposes, leaving the original files untouched. Instead of
parameterizing everything with `{% raw %}{{ }}{% endraw %}` like Helm, Kustomize takes a set of **base**
manifests and applies **overlays** (patches) on top of them.

The key idea is **base + overlays**:

- **base** — the common resources shared by every environment.
- **overlays** — per-environment folders (dev, staging, prod) that patch the base.

The best part: Kustomize is built into `kubectl`, so there's nothing extra to install.

```bash
kubectl kustomize ./overlays/prod        # render the manifests
kubectl apply -k ./overlays/prod          # render + apply
```

## Structuring the Book Info app with Kustomize

Let's restructure the Book Info application from the earlier posts into a base and two
overlays — `dev` and `prod`.

```
book-info/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        ├── kustomization.yaml
        └── replicas-patch.yaml
```

The `base/kustomization.yaml` simply lists the resources that make up the app:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app: productpage
```

A trimmed `base/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productpage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productpage
  template:
    metadata:
      labels:
        app: productpage
    spec:
      containers:
        - name: productpage
          image: docker.io/istio/examples-bookinfo-productpage-v1:1.20.1
          ports:
            - containerPort: 9080
```

## Overlays

The `dev` overlay only needs to point at the base and tweak a couple of small things —
here we add a `dev-` name prefix and a namespace:

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: book-info-dev
namePrefix: dev-

resources:
  - ../../base
```

The `prod` overlay reuses the same base but bumps the replica count with a strategic
merge patch:

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: book-info-prod
namePrefix: prod-

resources:
  - ../../base

patches:
  - path: replicas-patch.yaml
```

```yaml
# overlays/prod/replicas-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productpage
spec:
  replicas: 3
```

Notice how the base is never modified — each environment layers its own changes on top.
Preview the rendered prod manifest to confirm the replica count is `3`:

```bash
kubectl kustomize ./overlays/prod
```

## Common Kustomize transformers

Beyond patches, Kustomize ships a set of handy transformers you'll use every day:

- **namePrefix / nameSuffix** — prefix or suffix every resource name.
- **namespace** — place all resources into a namespace.
- **commonLabels / commonAnnotations** — add labels/annotations to everything.
- **images** — override an image name or tag without editing the deployment.
- **configMapGenerator / secretGenerator** — generate ConfigMaps and Secrets from files
  or literals, with an automatic content hash suffix that triggers rolling updates.

For example, pinning the image tag per environment is as simple as:

```yaml
# overlays/prod/kustomization.yaml
images:
  - name: docker.io/istio/examples-bookinfo-productpage-v1
    newTag: 1.20.1
```

And generating a ConfigMap from literals:

```yaml
configMapGenerator:
  - name: productpage-config
    literals:
      - LOG_LEVEL=info
      - FEATURE_REVIEWS=true
```

## Deploying an overlay with ArgoCD

ArgoCD has first-class support for Kustomize. When ArgoCD finds a `kustomization.yaml`
in the `path` you point it to, it renders it automatically — no extra configuration
needed. We just point each Application at the overlay folder we want.

An Application for the `prod` overlay:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: book-info-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/hoalongnatsu/argocd-series'
    targetRevision: HEAD
    path: '06-kustomize/book-info/overlays/prod'
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: book-info-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Run apply:

```bash
kubectl apply -f app-prod.yaml
```

Create a second Application pointing at `overlays/dev` and you now have two environments
deployed from a single base, each managed through Git.

If you need to override a Kustomize parameter directly from the Application (handy for
CI-driven image bumps), use the `kustomize` block in the `source`:

```yaml
  source:
    repoURL: 'https://github.com/hoalongnatsu/argocd-series'
    targetRevision: HEAD
    path: '06-kustomize/book-info/overlays/prod'
    kustomize:
      images:
        - docker.io/istio/examples-bookinfo-productpage-v1:1.20.2
```

See [argocd-series/06-kustomize](https://github.com/hoalongnatsu/argocd-series/tree/main/06-kustomize)
for the full example.

## Helm or Kustomize?

Both are excellent, and ArgoCD supports each equally well:

- Reach for **Helm** when you need templating, conditionals, and a package you can
  version and share (third-party charts like Redis, Postgres, etc.).
- Reach for **Kustomize** when you want plain, reviewable YAML with small, declarative
  per-environment differences and zero templating language to learn.

Many teams even combine them — rendering a Helm chart and then applying Kustomize
patches on top.

In the next post, we'll learn about **Resource Hooks** — how to run tasks like database
migrations at the right moment during a sync.
