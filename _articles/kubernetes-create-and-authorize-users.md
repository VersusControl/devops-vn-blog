---
layout: post
title: "Creating and Authorizing Users on Kubernetes"
date: 2023-06-05
author: Quan Huynh
tags: [kubernetes, rbac, security]
image: /assets/images/posts/kubernetes-create-and-authorize-users/cover.png
---

A guide to creating and authorizing users with kubectl.

## The Problem

Imagine the following situation. Your company has a Kubernetes cluster with two
environments, `pro` and `dev` — `pro` for the real production environment and `dev`
for product development. Until now you've worked alone and have full permissions to
manage the cluster; every time a developer wants to do anything, even view logs,
they have to go through you. Your boss finds this a bit inconvenient and asks you to
find a way for developers to list applications and view logs themselves in the `dev`
environment.

## The Solution

We use Role-Based Access Control (RBAC) to solve this. The steps are as follows.

Create a `pod-logs-sa.yaml` file for the Service Account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-logs
  namespace: dev
secrets:
  - name: pod-logs

---
apiVersion: v1
kind: Secret
metadata:
  name: pod-logs
  namespace: dev
  annotations:
    kubernetes.io/service-account.name: pod-logs
type: kubernetes.io/service-account-token
```

```bash
kubectl apply -f pod-logs-sa.yaml
```

Create a `pod-logs-role.yaml` file:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-logs
  namespace: dev
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
```

```bash
kubectl apply -f pod-logs-role.yaml
```

Create the RoleBinding:

```bash
kubectl -n dev create rolebinding pod-logs --serviceaccount=dev:pod-logs --role=pod-logs
```

Next, we'll create a user and let them log in with a token taken from the `pod-logs`
Service Account. Get the token:

```bash
kubectl -n dev describe secrets "$(kubectl -n dev describe serviceaccount pod-logs | grep -i Tokens | awk '{print $2}')" | grep token: | awk '{print $2}'
```

**Note: run kubectl with the correct namespace.** In this example it's `-n dev`.

Assign that value to the `TOKEN` variable:

```bash
TOKEN=$(kubectl -n dev describe secrets "$(kubectl -n dev describe serviceaccount pod-logs | grep -i Tokens | awk '{print $2}')" | grep token: | awk '{print $2}')
```

Create a user with any name:

```bash
kubectl config set-credentials devopsvn --token=$TOKEN
```

```
User "devopsvn" set.
```

Switch the current cluster context to the `devopsvn` user:

```bash
kubectl config set-context $(kubectl config current-context) --user=devopsvn
```

At this point you've created the user successfully. Run the following commands to
check permissions:

```bash
$ kubectl auth can-i get pods --namespace=dev
yes

$ kubectl auth can-i get pods --namespace=pro
no
```

Next, open the `~/.kube/config` file and remove the other users and unnecessary
information, keeping only the `devopsvn` user. For example:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ...
    server: ...
  name: devopsvn-cluster
contexts:
- context:
    cluster: devopsvn-cluster
    user: devopsvn
  name: devopsvn-cluster
kind: Config
preferences: {}
users:
- name: devopsvn
  user:
    token: ...
```

Then send this file to your developers.

## Conclusion

There are many solutions to the problem posed in this post, but the other solutions
are somewhat convoluted and complex. This is a manual approach, but it's the
simplest and easiest to do, and it's suitable for beginners. You can also look into a
more complex solution using ArgoCD.
