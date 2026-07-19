---
layout: post
title: "Ensuring Pod Count with Replication Controllers"
series: "Kubernetes Basics"
series_url: /kubernetes-basics-series/
part: 4
date: 2023-10-09
author: Quan Huynh
tags: [kubernetes, devops]
image: /assets/images/posts/kubernetes-04-replication-controllers/cover.png
---

In the previous post we learned how to use a Pod to run an application. But in
practice we don't create Pods directly — we do it through other resources such as
Replication Controllers or ReplicaSets. In this post we'll learn about Replication
Controllers and why we use them instead of creating Pods directly.

## What Are ReplicationControllers?

ReplicationControllers (RC) were replaced by ReplicaSets in Kubernetes 1.9. However,
to understand how ReplicaSets work, we need to understand ReplicationControllers.

ReplicationControllers (RCs) are an important part of Kubernetes. They're used to
create and manage Pods, ensuring that a certain number of Pods are always running.

The main characteristics of ReplicationControllers:

- **Desired Replica Count**: the number of Pods we want to maintain; the RC ensures
  the current number of Pods always equals the desired number
- **Pod Template**
- **Selector**: the RC uses a selector to determine which Pods it manages
- **Self-healing**: the RC automatically replaces failed or terminated Pods to
  ensure the desired Pod count is always maintained

![RC characteristics](/assets/images/posts/kubernetes-04-replication-controllers/rc-characteristics.png)

## Why Don't We Run Pods Directly?

A Pod plays the role of monitoring a container and automatically restarting the
container when it dies.

![A Pod monitors its container](/assets/images/posts/kubernetes-04-replication-controllers/pod-monitors-container.png)

So what happens when the Worker Node the Pod is running on dies? The Pod in that
Worker Node dies too.

![The Node dies](/assets/images/posts/kubernetes-04-replication-controllers/node-dies.png)

If we run Kubernetes with more than 1 Worker Node, the RC helps us solve this
problem, because the RC always ensures that the number of Pods it creates equals the
number we want.

So when we create an RC with `replicas = 1`, the RC always ensures there is 1 Pod
running. When a Worker Node dies and the Pod managed by the RC was in that Worker
Node, the RC detects that its Pod count is 0 and recreates 1 Pod on another Worker
Node to ensure the Pod count is 1.

![The RC recreates the Pod](/assets/images/posts/kubernetes-04-replication-controllers/rc-recreates-pod.png)

An illustration of how the RC works:

![How the RC works](/assets/images/posts/kubernetes-04-replication-controllers/rc-how-it-works.png)

So instead of running Pods directly, we should use higher-level resources to manage
and create Pods.

Besides ensuring the Pod count always equals `replicas`, running multiple Pods also
helps improve an application's performance somewhat.

For example, for a simple web application, instead of deploying 1 Pod to run it, we
can run 3 Pods — now user requests are sent to all 3 Pods, making processing faster.

![Multiple Pods improve performance](/assets/images/posts/kubernetes-04-replication-controllers/multiple-pods-performance.png)

## Hands-On

Next, let's practice creating Pods with an RC. Create a file named `hello-rc.yaml`:

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: hello-rc
spec:
  replicas: 2 # number of the pod
  selector: # The pod selector determining what pods the RC is operating on
    app: hello-kube # label value
  template: # pod template
    metadata:
      labels:
        app: hello-kube # label value
    spec:
      containers:
      - image: 080196/hello-kube # image used to run container
        name: hello-kube # name of the container
        ports:
          - containerPort: 3000 # port of the container
```

The RC configuration structure has 3 main parts:

- **selector**: specifies which Pods the RC monitors
- **replicas**: the number of Pods to create
- **template**: the Pod's configuration

![RC structure](/assets/images/posts/kubernetes-04-replication-controllers/rc-structure.png)

Create the RC:

```bash
kubectl apply -f hello-rc.yaml
```

Check whether the RC ran successfully:

```bash
kubectl get rc
```

If the number in the `READY` column equals the `DESIRED` number, the RC ran
successfully. Check that the number of Pods created by the RC matches the number
specified in `replicas`:

```bash
kubectl get pod
```

If you see two Pods, it's correct. The names of Pods created by an RC follow the
format `<replicationcontroller-name>-<random>`. Let's delete one Pod to see whether
the RC recreates another one, as the theory says.

```bash
kubectl delete pod hello-rc-c6l8k
```

Open another terminal window and run:

```bash
kubectl get pod
```

You'll see the number of Pods is still 2. The RC's process of detecting and
recreating the Pod:

![RC detects and recreates the Pod](/assets/images/posts/kubernetes-04-replication-controllers/rc-detect-recreate.png)

## Changing the Pod Template

You can change the Pod template and update the RC, but it won't apply to the current
Pods. To update the Pod template, you have two options:

- Delete the Pods so the RC creates new Pods with the new template
- Delete the RC and recreate it

![Changing the template](/assets/images/posts/kubernetes-04-replication-controllers/change-template.png)

To delete the RC, run:

```bash
kubectl delete rc hello-rc
```

When you delete an RC, the Pods it manages are deleted too.

## Conclusion

As you can see, the ReplicationController is a very useful resource for deploying
Pods. However, in newer versions the RC has been replaced by ReplicaSets. We'll
learn about ReplicaSets in the next post.
