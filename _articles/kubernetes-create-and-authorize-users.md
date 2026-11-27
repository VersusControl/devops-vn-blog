---
layout: post
title: "Kubernetes RBAC in Practice: Give Developers Read-Only Access to One Namespace"
subtitle: "Use a ServiceAccount, a Role, and a RoleBinding so developers can read Pods and logs in one namespace, and change nothing."
date: 2026-11-28
author: Quan Huynh
tags: [kubernetes, rbac, security, kubectl]
image: /assets/images/posts/kubernetes-create-and-authorize-users/cover.svg
---

Your company runs one Kubernetes cluster with two namespaces: `dev` for development and `pro` for
production. You hold the only admin access, so every time a developer wants to see why their
Pod crashed, they message you, and you copy the logs into the chat. You become the bottleneck,
and your manager asks for a fix: developers should read Pods and logs in `dev` themselves, and
they must not be able to change anything, or see anything in `pro`.

Kubernetes has a built-in feature for this called *RBAC* (Role-Based Access Control). You write
down what an identity (a person or a program) may do. The *API server*, the cluster component
that every `kubectl` command talks to, checks each request against those rules.

By the end of this post you will be able to:

- explain the three RBAC objects you need, and how they connect;
- give a team read-only access to Pods and logs in one namespace;
- check those permissions before you hand anything over;
- build a separate connection file (a kubeconfig) for the developers, without touching your own;
- know what to change before you use this in production.

> **Code for this post:** [_resource/kubernetes-rbac-dev-access](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/kubernetes-rbac-dev-access).
> I ran every command on a Kind cluster with Kubernetes 1.37. The outputs below come from that
> run.

## How RBAC Decides

Every request to the API server, including every `kubectl` command, comes from an identity.
For each request, RBAC asks one question: may this identity do this action on this resource, in
this namespace? If no rule says yes, the answer is no.

You write the "yes" with three objects:

| Object | Question it answers | Example in this post |
| --- | --- | --- |
| *ServiceAccount* | Who? An identity that can log in to the cluster | `dev-viewer` in `dev` |
| *Role* | What? A list of allowed actions on resources, in one namespace | `pod-reader`: get, list, and watch Pods and Pod logs |
| *RoleBinding* | Who gets what? It connects a Role to an identity, in one namespace | `dev-viewer-pod-reader` |

A Role contains *rules*. Each rule names resources (`pods`, `pods/log`) and *verbs*, the
actions allowed on them (`get`, `list`, `watch`, `create`, `delete`, and so on).

The namespace is the safety boundary. A Role and a RoleBinding live in one namespace and only
grant access there. The Role and RoleBinding in this post live in `dev`, so they give nothing in
`pro`. (The cluster-wide versions are called *ClusterRole* and *ClusterRoleBinding*. You only
meet one ClusterRole, near the end.)

![The RoleBinding dev-viewer-pod-reader in the dev namespace points to the ServiceAccount dev-viewer (who, through subjects) and the Role pod-reader (what, through roleRef: get, list, and watch on pods and pods/log). The pro namespace has no Role or RoleBinding, so it has no access.](/assets/images/posts/kubernetes-create-and-authorize-users/rbac-model.svg)

### Where are the users?

Kubernetes has no "user" object. People log in through something outside the cluster: client
certificates, an identity provider such as Okta or Google through *OIDC* (OpenID Connect, a
standard login protocol), or your cloud provider's IAM on EKS, GKE, or AKS.

A ServiceAccount is the one identity Kubernetes manages itself. It's meant for applications, but
its tokens work for people too. That makes it the simplest way to give a small team access while
you learn RBAC. The production section at the end covers what to use instead.

## Step 1: Create the Namespaces and an App

First, create something to look at: the two namespaces, and a small `orders` app in each one
that writes a log line every 5 seconds. Run this step, and every step except Step 5, with your
admin access.

```sh
git clone https://github.com/VersusControl/devops-vn-blog.git
cd devops-vn-blog/_resource/kubernetes-rbac-dev-access
kubectl apply -f manifests/01-namespaces-and-apps.yaml
```

```text
namespace/dev created
namespace/pro created
deployment.apps/orders created
deployment.apps/orders created
```

## Step 2: Define the Access

Now that there are Pods to read, define who may read them. The file
`manifests/02-dev-viewer.yaml` holds all three RBAC objects:

```yaml
# Who: a ServiceAccount the developers will use.
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev-viewer
  namespace: dev
---
# What: read Pods and their logs. Nothing else, and only in this namespace.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev
rules:
- apiGroups: [""]               # "" is the core API group, where Pods live
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
---
# Glue: give pod-reader to dev-viewer, inside dev only.
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-viewer-pod-reader
  namespace: dev
subjects:
- kind: ServiceAccount
  name: dev-viewer
  namespace: dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

Three details in the rule matter:

- `pods/log` is separate from `pods`. A *subresource* is a part of a resource that has its own
  permission, and logs are a subresource of a Pod. So the right to read a Pod doesn't include
  the right to read its logs. The
  [Break It](#break-it-two-permissions-people-forget) section shows what happens when you
  forget it.
- `get`, `list`, and `watch` cover `kubectl get pods`, `kubectl logs`, and `kubectl get pods -w`.
  (`kubectl describe pod` also reads Events, which this Role doesn't include, so the Events
  part of its output may be missing. The built-in `view` role at the end of this post covers it.)
- The verbs that change things are missing on purpose: no `create`, `update`, `patch`, or
  `delete`.

Apply the file:

```sh
kubectl apply -f manifests/02-dev-viewer.yaml
```

```text
serviceaccount/dev-viewer created
role.rbac.authorization.k8s.io/pod-reader created
rolebinding.rbac.authorization.k8s.io/dev-viewer-pod-reader created
```

## Step 3: Check the Access Before You Hand It Over

The objects exist, but nobody uses them yet. Before you create a token, test the permissions.
`kubectl auth can-i` asks the API server whether a request would be allowed. The `--as` flag
makes the request on behalf of another identity, which is called *impersonation*. When a
ServiceAccount calls the API, its username has the form
`system:serviceaccount:<namespace>:<name>`:

```sh
SA=system:serviceaccount:dev:dev-viewer
kubectl auth can-i get pods -n dev --as=$SA
kubectl auth can-i get pods --subresource=log -n dev --as=$SA
kubectl auth can-i delete pods -n dev --as=$SA
kubectl auth can-i get pods -n pro --as=$SA
kubectl auth can-i get secrets -n dev --as=$SA
```

```text
yes
yes
no
no
no
```

The five answers match the request from the manager: the developers can read Pods and logs in
`dev`, but can't delete Pods, can't see `pro`, and can't read Secrets.

To see every permission at once, run `kubectl auth can-i --list -n dev --as=$SA`. The output also
lists a few permissions that every identity gets by default, such as API discovery. The two
lines that come from `pod-reader` are:

```text
pods/log    []    []    [get list watch]
pods        []    []    [get list watch]
```

Run this check every time you change a Role. If you find a mistake after the access is out,
someone may already have used it.

## Step 4: Build a Kubeconfig File for the Developers

The permissions are correct, so the developers now need a way to connect. They need two things:
the cluster's address with its CA certificate (so `kubectl` can trust the server), and a token
for `dev-viewer`. A *kubeconfig* file holds both. `kubectl` reads it to know where to connect and
how to log in. Inside a kubeconfig, a *context* names one cluster, one user, and a default
namespace, and `kubectl` uses the current context.

Build the developers' kubeconfig as a separate file. If you add their user to your own
kubeconfig, it's easy to overwrite your admin context by accident. The script writes a new file:

```sh
scripts/make-kubeconfig.sh 8h
```

```text
Wrote dev-viewer.kubeconfig (token valid for 8h)
```

The core of the script has three parts. This excerpt is abbreviated: before these lines, the
script reads `$SERVER` and `$CA_DATA` from your current context. Run the script rather than
pasting these lines, because `export KUBECONFIG` would switch your own shell to the new file.

```sh
# 1. A short-lived token for the ServiceAccount
TOKEN="$(kubectl -n dev create token dev-viewer --duration=8h)"

# 2. Everything below writes to the new file only
export KUBECONFIG=dev-viewer.kubeconfig

# 3. Cluster address and CA (copied from your current context), user, and context
kubectl config set-cluster shared-cluster --server="$SERVER"
kubectl config set clusters.shared-cluster.certificate-authority-data "$CA_DATA"
kubectl config set-credentials dev-viewer --token="$TOKEN"
kubectl config set-context dev-viewer --cluster=shared-cluster --user=dev-viewer --namespace=dev
kubectl config use-context dev-viewer
```

`kubectl create token` asks the API server for a token with an expiry time, here 8 hours. The
token is not stored in the cluster. When it expires, the developer asks you for a new file. The
context also sets `--namespace=dev`, so developers don't have to type `-n dev` every time.

> **Note:** Older guides create a Secret of type `kubernetes.io/service-account-token` to get a
> token. That token never expires, and it sits in the cluster as a Secret. Use it only when you
> really need a long-lived token, and rotate it yourself.

How long can a token live? It depends on the cluster. Kind accepted `--duration=999h` in my test,
but the API server can cap it with the `--service-account-max-token-expiration` flag. Keep it as
short as your team can work with. One working day is a good starting point.

## Step 5: Use It as a Developer

The file contains a token, so send `dev-viewer.kubeconfig` to the developer over a private
channel. They point `kubectl` at it with the `KUBECONFIG` variable. You can run the same commands
yourself to test it:

```sh
export KUBECONFIG=dev-viewer.kubeconfig
kubectl get pods
kubectl logs -l app=orders --tail=2
```

```text
NAME                      READY   STATUS    RESTARTS   AGE
orders-77cbdbf696-hsrsc   1/1     Running   0          9s
processed order 15258
processed order 22861
```

The developer can now read Pods and logs without asking you. The API server refuses anything
outside the Role. Each error names the identity, the verb, the resource, and the namespace:

```sh
kubectl delete pod orders-77cbdbf696-hsrsc
kubectl -n pro get pods
```

```text
Error from server (Forbidden): pods "orders-77cbdbf696-hsrsc" is forbidden: User "system:serviceaccount:dev:dev-viewer" cannot delete resource "pods" in API group "" in the namespace "dev"
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:dev:dev-viewer" cannot list resource "pods" in API group "" in the namespace "pro"
```

Your own kubeconfig is unchanged. If you tested in your own shell, run `unset KUBECONFIG` to go
back to your admin context. The rest of the post needs admin access.

## Break It: Two Permissions People Forget

After you hand out read access, two complaints come up often: "I can see Pods but not logs" and
"logs work, but not the way I usually run them." Both come from a missing permission.

Run the checks below with your admin access. If you're in a new terminal, set the identity again
first: `SA=system:serviceaccount:dev:dev-viewer`.

**1. A Role without `pods/log`.** If the rule lists only `pods`, `kubectl get pods` works but
`kubectl logs` fails:

```text
Error from server (Forbidden): pods "orders-77cbdbf696-hsrsc" is forbidden: User "system:serviceaccount:dev:dev-viewer" cannot get resource "pods/log" in API group "" in the namespace "dev"
```

The error names the missing piece, `pods/log`. To fix it, work from your admin context:

1. Confirm the problem with `kubectl auth can-i get pods --subresource=log -n dev --as=$SA`. It
   answers `no`.
2. Add `pods/log` to the rule and apply the file again.

The developer doesn't need a new token. RBAC checks every request against the current rules, so
the next `kubectl logs` works.

**2. `kubectl logs deploy/orders`.** This form is convenient, but `kubectl` first reads the
Deployment to find its Pods. Deployments belong to the `apps` API group, not the core group
(`""`) that the Role covers, so the Role doesn't allow reading them:

```text
Error from server (Forbidden): deployments.apps "orders" is forbidden: User "system:serviceaccount:dev:dev-viewer" cannot get resource "deployments" in API group "apps" in the namespace "dev"
```

You can fix this in two ways. Tell developers to select Pods by label
(`kubectl logs -l app=orders`), or add a second rule for `deployments` in the `apps` API group
with `get` and `list`. Either works. In general, a `kubectl` shortcut can make several API calls,
and each call needs its own permission.

## Take the Access Back

Sooner or later, someone leaves the team or a file leaks. You can end access in two ways:

- Wait. The token from `kubectl create token` stops working when it expires.
- Delete the ServiceAccount with `kubectl -n dev delete serviceaccount dev-viewer`. Every token
  issued for it stops working. In my test the API server rejected the old token about 10 seconds
  later, because it caches token checks for a short time.

## Before You Use This in Production

The ServiceAccount approach works for learning RBAC and for a small team. In production it has
two weak points:

- Everyone looks like the same person. The *audit log* (the API server's record of who did
  what) shows `system:serviceaccount:dev:dev-viewer`, not the developer who ran the command. If
  three people share the file, you can't tell them apart.
- The token is a file. Someone can copy it, forward it, or commit it to a repository by mistake.

In production, people log in as themselves, through your identity provider or your cloud's IAM,
and the RoleBinding names a group instead of a ServiceAccount. You also don't have to write the
Role yourself. Kubernetes ships a built-in ClusterRole called `view`. A RoleBinding can point to
a ClusterRole, and then it grants those rules only in the RoleBinding's namespace:

```sh
kubectl -n dev create rolebinding dev-team-view --clusterrole=view --group=dev-team
```

I checked this with impersonation (`--as=jane@example.com --as-group=dev-team`): members of
`dev-team` can read Pods and logs in `dev`, can't read Secrets, can't delete, and get nothing in
`pro`. Someone outside the group gets nothing. `view` also covers Deployments, Services, and most
other read-only resources, so the `kubectl logs deploy/...` problem goes away.

How the group gets its members depends on the platform: OIDC groups from your identity
provider, access entries on EKS, Google groups on GKE, or Microsoft Entra ID groups on AKS. The
RBAC part doesn't change between platforms. Roles and RoleBindings work the same way; only the
subject in the RoleBinding changes, from a ServiceAccount to a group.

## Clean Up

```sh
scripts/cleanup.sh
```

It deletes the RoleBinding, Role, ServiceAccount, both namespaces with their apps, and the
kubeconfig file.

## Summary

- RBAC needs three objects: a ServiceAccount (who), a Role (what), and a RoleBinding (who gets
  what). A Role and RoleBinding in one namespace grant access only in that namespace.
- Logs are a separate permission: list `pods/log` next to `pods`.
- Check access with `kubectl auth can-i --as=...` before you hand anything over.
- Give people a separate kubeconfig with a short-lived token from `kubectl create token`, not a
  never-expiring Secret, and never edit your own admin context for them.
- In production, let people log in as themselves and bind a group to the built-in `view`
  ClusterRole.

Next step: run `kubectl auth can-i --list -n <namespace> --as=<identity>` for one identity in your
own cluster, and check that its permissions match what you think they are.

## Resources

- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), Kubernetes documentation
- [Managing Service Accounts](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/), including bound tokens
- [`kubectl create token`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_token/)
- [User-facing roles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles): `view`, `edit`, `admin`, and `cluster-admin`
