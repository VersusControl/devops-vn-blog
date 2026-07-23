---
layout: post
title: "Multi-Cluster Deployments"
series: "ArgoCD"
series_url: /argocd-series/
part: 10
date: 2024-12-26
author: Quan Huynh
tags: [kubernetes, argocd, gitops]
image: /assets/images/posts/argocd-10-multi-cluster/cover.svg
---

Until now every Application has deployed to the same cluster ArgoCD runs in
(`https://kubernetes.default.svc`). In the real world you often have several clusters —
dev, staging, prod, or one per region — and you want to manage them all from a single
ArgoCD. This is the **hub-and-spoke** model: one ArgoCD (the hub) deploys to many
workload clusters (the spokes).

## Registering an external cluster

ArgoCD needs credentials to talk to each external cluster. The quickest way is the CLI.
With your `kubeconfig` context pointing at the target cluster, run:

```bash
# List the contexts ArgoCD can see
argocd cluster list

# Add a cluster by kubeconfig context name
argocd cluster add prod-cluster --name prod
```

Under the hood this creates a ServiceAccount in the target cluster, grabs its token, and
stores the connection details as a Secret in the `argocd` namespace of the hub.

## Registering a cluster declaratively

Doing it by hand is fine for a demo, but GitOps means we prefer declarative config. A
cluster is just a Secret with the label `argocd.argoproj.io/secret-type: cluster`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: prod-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: prod
  server: https://prod.example.com:6443
  config: |
    {
      "bearerToken": "<token>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64-ca>"
      }
    }
```

Commit this (with the token itself sealed — see the Secret Management post!) and ArgoCD
picks up the new cluster. From now on, `prod` is a valid deployment target.

## Targeting a cluster from an Application

Once a cluster is registered, point an Application's `destination.server` (or
`destination.name`) at it instead of the in-cluster address:

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
    name: prod            # the cluster we registered
    namespace: book-info
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

That single line — `name: prod` — is all it takes to deploy to a different cluster.

## Deploying to every cluster with the Cluster generator

Managing one Application per cluster by hand brings us back to the copy-paste problem from
the previous post. The **Cluster generator** in ApplicationSet solves it: it produces one
Application per registered cluster automatically.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: book-info-all-clusters
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - clusters: {}          # every registered cluster
  template:
    metadata:
      name: 'book-info-{% raw %}{{ .name }}{% endraw %}'
    spec:
      project: default
      source:
        repoURL: 'https://github.com/hoalongnatsu/argocd-series'
        targetRevision: HEAD
        path: '06-kustomize/book-info/overlays/prod'
      destination:
        server: '{% raw %}{{ .server }}{% endraw %}'
        namespace: book-info
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

The empty `clusters: {}` selector matches all clusters, including the local one. To target
a subset, add a label selector that matches labels on the cluster Secrets:

```yaml
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: production
```

Now every production cluster receives the Book Info app, and adding a new prod cluster
(with the right label) automatically gets it deployed — no changes to the ApplicationSet.

## Per-cluster values

Different clusters often need different settings (region, replica count, ingress host).
You can attach arbitrary values to a cluster Secret and read them in the template:

```yaml
# on the cluster Secret
metadata:
  labels:
    argocd.argoproj.io/secret-type: cluster
    environment: production
  annotations:
    values.region: us-west-2
```

```yaml
# in the ApplicationSet template, via goTemplate
      source:
        kustomize:
          namePrefix: '{% raw %}{{ index .metadata.annotations "values.region" }}{% endraw %}-'
```

## Architecture tips

- Keep the **hub** cluster small and dedicated to ArgoCD; don't run workloads on it.
- Use **network policies / private endpoints** so only the hub can reach spoke API
  servers.
- Give the hub's ServiceAccount on each spoke the **least privilege** it needs.
- Combine with **Projects** (from the Core Concepts post) to restrict which clusters and
  namespaces each team can deploy to.

Full manifests are in
[argocd-series/10-multi-cluster](https://github.com/hoalongnatsu/argocd-series/tree/main/10-multi-cluster).

With one ArgoCD managing many clusters, the last thing we need is proper access control
for the humans logging in. In the final post we'll set up **SSO with Keycloak**.
