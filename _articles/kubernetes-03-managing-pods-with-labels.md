---
layout: post
title: "Managing Pods with Labels"
series: "Kubernetes Basics"
series_url: /kubernetes-basics-series/
part: 3
date: 2023-09-19
author: Quan Huynh
tags: [kubernetes, devops]
image: /assets/images/posts/kubernetes-03-managing-pods-with-labels/cover.svg
---

In the previous post we learned what a Pod is. In this post we'll learn how to
manage Pods using the *labels* property.

## Organizing Pods

Labels are how we can separate different Pods depending on the project or
environment. For example, suppose our company has 3 environments — testing, staging,
and production. If we run Pods without labeling them, it's very hard to know which
Pod belongs to which environment.

Imagine our company has many applications deployed with many Pods, like below:

![Many Pods](/assets/images/posts/kubernetes-03-managing-pods-with-labels/many-pods.png)

How do we know what a Pod is running and what it's used for? The simplest way is to
name the Pods, as shown above — Order Service Pod for Order, or Product Pod for
Product. But we can't group Pods by function and application. For example, if we
need to list all Pods for one application, how do we do it? With just a name, we
can't.

Pods provide the `labels` property for this. After we assign labels to Pods, we can
group them like below:

![Grouped Pods](/assets/images/posts/kubernetes-03-managing-pods-with-labels/grouped-pods.png)

To define labels for a Pod, use the `metadata.labels` property and name them as
`<key>: <value>` pairs with the values you want. For example, create a file
`hello-kube.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-kube-ios
  labels:
    app: ui
spec:
  containers:
    - image: 080196/hello-kube
      name: hello-kube
      ports:
        - containerPort: 3000
          protocol: TCP

---
apiVersion: v1
kind: Pod
metadata:
  name: hello-kube-pc
  labels:
    app: ui
spec:
  containers:
    - image: 080196/hello-kube
      name: hello-kube
      ports:
        - containerPort: 3000
          protocol: TCP

---
apiVersion: v1
kind: Pod
metadata:
  name: hello-kube-os
  labels:
    app: system
spec:
  containers:
    - image: 080196/hello-kube
      name: hello-kube
      ports:
        - containerPort: 3000
          protocol: TCP
```

Run apply:

```bash
kubectl apply -f hello-kube.yaml
```

Check that the Pods are running:

```bash
kubectl get pod
```

```
NAME             READY   STATUS    RESTARTS   AGE
hello-kube-ios   1/1     Running   0          89s
hello-kube-pc    1/1     Running   0          90s
hello-kube-os    1/1     Running   0          90s
```

Above, we defined two Pods with `labels: app: ui` and one Pod with
`labels: app: system`. To select Pods by labels, use `get` with `-l`. For example,
list the Pods deployed for UI:

```bash
kubectl get pod -l app=ui
```

```
NAME             READY   STATUS    RESTARTS   AGE
hello-kube-ios   1/1     Running   0          2m24s
hello-kube-pc    1/1     Running   0          2m23s
```

List the Pods deployed for System:

```bash
kubectl get pod -l app=system
```

```
NAME            READY   STATUS    RESTARTS   AGE
hello-kube-os   1/1     Running   0          3m13s
```

Labels are a great way to organize and manage Pods across different environments and
projects. Remember to delete the Pods when you're done:

```bash
kubectl delete -f hello-kube.yaml
```

## Partitioning Resources with Namespaces

In Kubernetes, we use namespaces to manage and partition resources between
environments.

For example, if our application needs three environments — testing, staging, and
production — we need to create three corresponding namespaces. You can simply think
of it as `Environment ~= Namespace`.

By default, when you create a Kubernetes cluster it has a few default namespaces. To
list all namespaces:

```bash
kubectl get ns
```

```
NAME                STATUS   AGE
default             Active   588d
kube-public         Active   588d
kube-system         Active   588d
```

All the Pods we created in previous posts are in the namespace named `default`.

When we use `kubectl get pod` to list Pods, kubectl automatically assumes we're
working with `default`. To specify a namespace, add `--namespace` when running the
command. For example, list Pods in `kube-system`:

```bash
kubectl get pod --namespace kube-system
```

Next, let's try creating a new namespace and creating a Pod in it. Create a
namespace named `testing`:

```bash
kubectl create ns testing
```

> A standard way to organize namespaces is to name them `<project_name>-<environment>`.
> For example: scaleup-testing, scaleup-staging, scaleup-production.

Create a file named `hello-namespace.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-kube-testing
  namespace: testing # namespace name
spec:
  containers:
    - image: 080196/hello-kube
      name: hello-kube
      ports:
        - containerPort: 3000
          protocol: TCP
```

Create the Pod:

```bash
kubectl apply -f hello-namespace.yaml
```

After creating the Pod, if we list Pods without specifying the namespace, we won't
see the newly created Pod.

```bash
kubectl get pod
```

```
No resources found in default namespace.
```

To list the Pod we just created, add `-n` when running the command:

```bash
kubectl get pod -n testing
```

```
NAME                 READY   STATUS    RESTARTS   AGE
hello-kube-testing   1/1     Running   0          3m13s
```

So we've successfully created a namespace and a Pod. Remember to delete the Pod:

```bash
kubectl delete pod hello-kube-testing -n testing
```

You can delete a namespace with `delete`, but note that when you delete a namespace,
all the resources in it are deleted too.

```bash
kubectl delete ns testing
```

## Conclusion

Use labels to organize and manage Pods. Use namespaces to manage resources between
environments in Kubernetes.
