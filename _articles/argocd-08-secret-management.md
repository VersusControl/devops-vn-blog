---
layout: post
title: "Secret Management with GitOps"
series: "ArgoCD"
series_url: /argocd-series/
part: 8
date: 2024-12-10
author: Quan Huynh
tags: [kubernetes, argocd, gitops, security]
image: /assets/images/posts/argocd-08-secret-management/cover.svg
---

GitOps says *everything* lives in Git — but a Kubernetes `Secret` is only base64
encoded, not encrypted. Committing one straight to a repository would expose your
passwords to anyone who can read it. So how do we manage secrets while still keeping Git
as the single source of truth? In this post we'll look at the common patterns and set up
one of them end to end.

## The problem

A plain Secret looks like this:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  password: c2VjcmV0cGFzc3dvcmQ=   # base64, NOT encryption
```

`echo c2VjcmV0cGFzc3dvcmQ= | base64 -d` reveals `secretpassword` instantly. We need the
value in Git to be genuinely encrypted, and only decryptable inside the cluster.

## The common approaches

There are four popular ways to do GitOps-friendly secrets:

1. **Sealed Secrets** (Bitnami) — encrypt a Secret into a `SealedSecret` custom resource
   that only the in-cluster controller can decrypt. The encrypted form is safe to commit.
2. **External Secrets Operator (ESO)** — keep the actual secret in a manager like AWS
   Secrets Manager, GCP Secret Manager, or Vault, and commit only a reference
   (`ExternalSecret`) that syncs the value into a real Secret.
3. **SOPS + KSOPS** — encrypt values with Mozilla SOPS (backed by KMS/age/PGP) and let a
   Kustomize plugin decrypt them during the ArgoCD render.
4. **HashiCorp Vault** — inject secrets at runtime with the Vault Agent or the Vault
   Secrets Operator.

We'll set up **Sealed Secrets** because it's the simplest to reason about and fits the
GitOps flow perfectly. Then we'll show what **ESO** looks like for teams already using a
cloud secret manager.

## Sealed Secrets

The model is a public/private key pair. The controller running in the cluster holds the
private key; you encrypt with the public key. Because only the controller can decrypt, a
`SealedSecret` is safe to store in a public repo.

Install the controller (itself managed by ArgoCD, of course):

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system
```

Install the `kubeseal` CLI locally, then encrypt a normal Secret into a SealedSecret:

```bash
# Create a Secret locally (do NOT commit this file)
kubectl create secret generic db-credentials \
  --from-literal=password=secretpassword \
  --dry-run=client -o yaml > secret.yaml

# Encrypt it using the controller's public key
kubeseal --controller-name sealed-secrets \
  --controller-namespace kube-system \
  --format yaml < secret.yaml > sealed-secret.yaml
```

The resulting `sealed-secret.yaml` contains ciphertext instead of the password:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-credentials
  namespace: default
spec:
  encryptedData:
    password: AgBy3i4OJSWK+PiTySYZZA9rO... # encrypted, safe to commit
  template:
    metadata:
      name: db-credentials
    type: Opaque
```

**This** is what you commit. When ArgoCD applies the `SealedSecret`, the controller
notices it, decrypts it, and creates a matching real `Secret` in the cluster. Your app
consumes the Secret exactly as before — it never knows the difference.

## External Secrets Operator

If your organization already stores secrets in AWS Secrets Manager, Vault, or similar,
ESO is a great fit. You commit a reference, not the value.

Install ESO and define a `SecretStore` that knows how to talk to your provider:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

Then commit an `ExternalSecret` that maps a remote secret into a Kubernetes Secret:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: prod/book-info/db
        property: password
```

ESO periodically pulls the value from AWS Secrets Manager and keeps the in-cluster Secret
in sync. Rotating the secret in AWS automatically flows into the cluster — no Git commit
required.

## Which one should I use?

- **Sealed Secrets** — simplest, self-contained, no external dependency. Great for small
  teams and homelabs. The trade-off: rotating a secret means re-sealing and committing.
- **External Secrets Operator** — best when you already have a central secret manager and
  want rotation handled outside Git. The trade-off: an extra operator and cloud
  dependency.
- **SOPS/KSOPS** — keeps the encrypted value *in* Git (like Sealed Secrets) but with
  KMS-backed keys and Kustomize integration.

Whatever you choose, the golden rule holds: **plaintext secrets never touch Git.** Only
encrypted blobs or references do.

The example manifests are in
[argocd-series/08-secrets](https://github.com/hoalongnatsu/argocd-series/tree/main/08-secrets).

In the next post, we'll stop managing Applications one by one and generate them in bulk
with **ApplicationSet**.
