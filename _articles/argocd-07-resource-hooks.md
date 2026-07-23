---
layout: post
title: "Resource Hooks"
series: "ArgoCD"
series_url: /argocd-series/
part: 7
date: 2024-12-02
author: Quan Huynh
tags: [kubernetes, argocd, gitops]
image: /assets/images/posts/argocd-07-resource-hooks/cover.svg
---

So far every sync has simply applied our manifests and waited for them to become
healthy. But real deployments often need extra steps at specific moments — running a
database migration *before* the new version rolls out, or a smoke test *after*. ArgoCD
gives us **Resource Hooks** to run these tasks at the right point in a sync.

## Sync phases

When ArgoCD syncs an Application, it moves through a series of phases. A hook is just a
normal Kubernetes resource (usually a `Job` or `Pod`) annotated to run in one of them:

- **PreSync** — runs *before* the main manifests are applied. Perfect for schema
  migrations or seeding data.
- **Sync** — runs *together with* the main wave of resources.
- **PostSync** — runs *after* all resources are applied and report healthy. Great for
  smoke tests, cache warming, or notifications.
- **SyncFail** — runs only when the sync fails. Use it for cleanup or alerting.

We select a phase with the `argocd.argoproj.io/hook` annotation.

## A PreSync migration hook

Here's a classic example: run a database migration as a `Job` before the application
is updated.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: myorg/book-info-migrations:1.4.0
          command: ["/bin/sh", "-c", "migrate up"]
  backoffLimit: 1
```

Because it's a `PreSync` hook, ArgoCD creates this Job and waits for it to complete
successfully **before** applying the rest of the manifests. If the migration fails, the
sync stops and your new version is never rolled out against an out-of-date schema.

## Cleaning up hooks: delete policies

Hook resources would pile up if we never removed them, so ArgoCD provides the
`argocd.argoproj.io/hook-delete-policy` annotation:

- **HookSucceeded** — delete the hook once it completes successfully.
- **HookFailed** — delete the hook if it fails (keep the logs of successful ones).
- **BeforeHookCreation** — delete the previous hook instance right before creating a new
  one on the next sync. This is the most common choice for Jobs, because Job specs are
  immutable and re-applying a Job with the same name would otherwise error.

A robust migration hook usually combines two:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
```

## A PostSync smoke test

After the new version is live, run a quick health check:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: curl
          image: curlimages/curl:8.9.1
          command:
            - sh
            - -c
            - "curl -sf http://productpage:9080/health || exit 1"
  backoffLimit: 0
```

If the smoke test Job fails, ArgoCD marks the sync operation as failed, which you can
wire up to notifications or a rollback.

## Ordering resources with sync waves

Hooks control *when* a task runs relative to the phases. To order the *regular*
resources within a phase, use **sync waves** with the
`argocd.argoproj.io/sync-wave` annotation. Lower numbers are applied first; ArgoCD
waits for each wave to become healthy before starting the next.

```yaml
# Applied first
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
# Applied after wave 0 is healthy
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

A typical layout:

- wave `-1`: a `PreSync` migration hook
- wave `0`: the `Deployment` and `Service`
- wave `1`: an `Ingress` that should only appear once the app is up

Sync waves also apply to hooks, so you can, for example, run several PreSync hooks in a
deterministic order.

## Health and the sync order, together

Putting it all together, a sync of the Book Info app might look like this:

1. **PreSync** — run `db-migrate`; wait for success.
2. **Sync** — apply the Deployment (wave 0), then the Ingress (wave 1), waiting for each
   wave to be healthy.
3. **PostSync** — run `smoke-test`; if it fails, the operation is marked failed.

You can find the manifests in
[argocd-series/07-hooks](https://github.com/hoalongnatsu/argocd-series/tree/main/07-hooks).

Resource hooks turn ArgoCD from a "kubectl apply on a loop" into a proper deployment
pipeline that understands the order your application needs.

In the next post, we'll tackle one of the trickiest parts of GitOps: **Secret Management
with GitOps** — how to keep secrets in Git without leaking them.
