---
layout: post
title: "SSO with Keycloak"
series: "ArgoCD"
series_url: /argocd-series/
part: 11
date: 2025-01-06
author: Quan Huynh
tags: [kubernetes, argocd, gitops, security]
image: /assets/images/posts/argocd-11-sso-keycloak/cover.svg
---

Throughout this series we've logged into ArgoCD with the built-in `admin` account. That's
fine for a demo, but on a real team you want everyone to sign in with their company
identity and get permissions based on their group — no shared passwords. In this final
post we'll wire ArgoCD up to **Keycloak** using OpenID Connect (OIDC) for single sign-on.

## How ArgoCD does SSO

ArgoCD authenticates users in one of two ways:

- **Local users** — accounts defined in `argocd-cm` (like `admin`).
- **SSO via OIDC** — delegate login to an identity provider. ArgoCD can talk OIDC
  directly, or go through its bundled **Dex** connector for providers that need it.

Keycloak is a first-class OIDC provider, so we'll use ArgoCD's **direct OIDC** integration
— no Dex required. The flow is: ArgoCD redirects the user to Keycloak, Keycloak
authenticates them and returns an ID token containing their **groups**, and ArgoCD maps
those groups to roles via RBAC.

## Configure Keycloak

In your Keycloak realm (say `devops`), create a new **OIDC client** for ArgoCD:

1. **Client ID**: `argocd`
2. **Client authentication**: On (confidential client — we'll use a secret).
3. **Valid redirect URIs**: `https://argocd.example.com/auth/callback`
4. **Web origins**: `https://argocd.example.com`

Then copy the client secret from the **Credentials** tab.

The important part is exposing the user's **groups** in the token. Add a **Group
Membership** mapper to the client:

- **Mapper type**: Group Membership
- **Token Claim Name**: `groups`
- **Full group path**: Off (so you get `argocd-admins`, not `/argocd-admins`)
- Enable **Add to ID token** and **Add to userinfo**.

Finally create a couple of groups in Keycloak — for example `argocd-admins` and
`argocd-developers` — and assign your users to them.

## Point ArgoCD at Keycloak

ArgoCD reads its OIDC config from the `argocd-cm` ConfigMap. Add an `oidc.config` block
with your Keycloak realm URL and client:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  oidc.config: |
    name: Keycloak
    issuer: https://keycloak.example.com/realms/devops
    clientID: argocd
    clientSecret: $oidc.keycloak.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
      - groups
```

Notice `clientSecret: $oidc.keycloak.clientSecret`. The `$` tells ArgoCD to read the value
from a key in the `argocd-secret` Secret rather than storing it in the ConfigMap. Add it
there (sealed, of course):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
type: Opaque
stringData:
  oidc.keycloak.clientSecret: <client-secret-from-keycloak>
```

## Map groups to roles with RBAC

Authentication tells ArgoCD *who* you are; **RBAC** decides *what* you can do. Configure
group-to-role mappings in `argocd-rbac-cm`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Keycloak group  ->  ArgoCD role
    g, argocd-admins, role:admin

    # A custom, scoped role for developers
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    g, argocd-developers, role:developer
  scopes: '[groups]'
```

Here:

- Members of `argocd-admins` get the built-in `role:admin`.
- We define a custom `role:developer` that may view and sync Applications but not delete
  them or change settings, and bind the `argocd-developers` group to it.
- Everyone else falls back to `policy.default` (`role:readonly`).
- `scopes: '[groups]'` tells the RBAC engine to read the `groups` claim from the token.

## Apply and test

Apply the ConfigMaps and Secret, then restart the API server so it picks up the OIDC
config:

```bash
kubectl apply -f argocd-cm.yaml -f argocd-rbac-cm.yaml -f argocd-secret.yaml
kubectl -n argocd rollout restart deploy/argocd-server
```

Open the ArgoCD UI and you'll now see a **"LOG IN VIA KEYCLOAK"** button next to the
regular login form. Sign in with a Keycloak user, and ArgoCD applies the role that matches
their group. A member of `argocd-developers` will be able to sync apps but will find the
delete and settings actions disabled.

## Hardening tips

- Once SSO works, **disable the local admin account** by setting `admin.enabled: "false"`
  in `argocd-cm`, so there's no shared password to leak.
- Prefer **groups over individual users** in `policy.csv` — access is then managed entirely
  in Keycloak.
- Keep the client secret in a **SealedSecret** or External Secret, never in plain Git.
- Use **AppProjects** to further limit which repos, clusters, and namespaces each role can
  touch.

The manifests are in
[argocd-series/11-sso-keycloak](https://github.com/hoalongnatsu/argocd-series/tree/main/11-sso-keycloak).

## Wrapping up the series

That completes our ArgoCD journey — from a first `Application`, through core concepts,
private repos, architecture, Helm and Kustomize, resource hooks, secret management,
ApplicationSet, multi-cluster deployments, and finally single sign-on. You now have the
building blocks to run GitOps continuous delivery for real teams and real clusters. Happy
shipping!
