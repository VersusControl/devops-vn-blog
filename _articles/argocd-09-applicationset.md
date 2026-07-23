---
layout: post
title: "ApplicationSet"
series: "ArgoCD"
series_url: /argocd-series/
part: 9
date: 2024-12-18
author: Quan Huynh
tags: [kubernetes, argocd, gitops]
image: /assets/images/posts/argocd-09-applicationset/cover.svg
---

As your platform grows you'll find yourself creating a lot of very similar Applications —
one per environment, one per team, one per cluster. Copy-pasting Application YAML quickly
becomes error-prone. **ApplicationSet** is the ArgoCD controller that generates
Applications automatically from a template and a set of parameters.

## The idea: generator + template

An `ApplicationSet` has two parts:

- **generators** — produce a list of parameter sets (for example, one entry per
  environment or per cluster).
- **template** — an Application blueprint with `{% raw %}{{ }}{% endraw %}` placeholders that the generator fills
  in.

The controller renders one Application per generated parameter set and keeps them in
sync. Delete an entry and the corresponding Application is removed; add one and a new
Application appears.

## List generator

The simplest generator is a hard-coded list. Here we create one Book Info Application per
environment:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: book-info
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - list:
        elements:
          - env: dev
            namespace: book-info-dev
          - env: prod
            namespace: book-info-prod
  template:
    metadata:
      name: 'book-info-{% raw %}{{ .env }}{% endraw %}'
    spec:
      project: default
      source:
        repoURL: 'https://github.com/hoalongnatsu/argocd-series'
        targetRevision: HEAD
        path: '06-kustomize/book-info/overlays/{% raw %}{{ .env }}{% endraw %}'
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: '{% raw %}{{ .namespace }}{% endraw %}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

Apply it and ArgoCD creates `book-info-dev` and `book-info-prod` for you — from a single
resource.

```bash
kubectl apply -f book-info-appset.yaml
```

## Git directory generator

Even better, we can let the **repository layout** drive the Applications. The Git generator
scans a repo and produces one parameter set per matching directory. Add a new folder to
Git and a new Application appears automatically — no edits to the ApplicationSet.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: 'https://github.com/hoalongnatsu/argocd-series'
        revision: HEAD
        directories:
          - path: 'apps/*'
  template:
    metadata:
      name: '{% raw %}{{ .path.basename }}{% endraw %}'
    spec:
      project: default
      source:
        repoURL: 'https://github.com/hoalongnatsu/argocd-series'
        targetRevision: HEAD
        path: '{% raw %}{{ .path.path }}{% endraw %}'
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: '{% raw %}{{ .path.basename }}{% endraw %}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

With a repo like:

```
apps/
├── productpage/
├── reviews/
└── ratings/
```

you get three Applications named `productpage`, `reviews`, and `ratings`. This "app of
apps, generated" pattern is one of the most popular uses of ApplicationSet.

## Other generators

ApplicationSet ships with several generators you can mix and match:

- **List** — an explicit list of parameters (shown above).
- **Cluster** — one Application per cluster registered in ArgoCD (we'll use this in the
  next post for multi-cluster).
- **Git (directories / files)** — driven by folders or config files in a repo.
- **SCM Provider** — one Application per repository in a GitHub/GitLab org.
- **Pull Request** — one Application per open PR, ideal for preview environments.
- **Matrix** — the cross-product of two generators (e.g. every app × every cluster).
- **Merge** — combine generators, letting later ones override earlier values.

## Matrix: apps across environments

Say you want every app deployed to every environment. A `matrix` generator combines a Git
directory generator (the apps) with a list generator (the environments):

```yaml
  generators:
    - matrix:
        generators:
          - git:
              repoURL: 'https://github.com/hoalongnatsu/argocd-series'
              revision: HEAD
              directories:
                - path: 'apps/*'
          - list:
              elements:
                - env: dev
                - env: prod
```

The template then has access to both `{% raw %}{{ .path.basename }}{% endraw %}` and `{% raw %}{{ .env }}{% endraw %}`, producing an
Application for each app/environment pair.

## A safety note

Because an ApplicationSet can create and delete many Applications at once, enable it
carefully. During rollout you can set:

```yaml
spec:
  syncPolicy:
    applicationsSync: create-update   # don't let it delete Applications yet
```

Once you trust it, switch to the default so removed entries are pruned.

The examples live in
[argocd-series/09-applicationset](https://github.com/hoalongnatsu/argocd-series/tree/main/09-applicationset).

ApplicationSet turns dozens of near-identical Applications into a single declarative
resource. In the next post we'll use its **Cluster generator** to deploy across many
clusters — welcome to **Multi-Cluster Deployments**.
