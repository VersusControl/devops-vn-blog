---
layout: post
title: "ReplicaSets and DaemonSets"
series: "Kubernetes Basics"
series_url: /kubernetes-basics-series/
part: 5
date: 2023-10-23
author: Quan Huynh
tags: [kubernetes, devops]
image: /assets/images/posts/kubernetes-05-replicasets-and-daemonsets/cover.png
---

In the previous post we learned how to use Replication Controllers. In this post
we'll learn about the enhanced version of Replication Controllers — ReplicaSets — and
how to use DaemonSets.

## Comparing ReplicaSets and Replication Controllers

Replication Controllers (RC) were replaced by ReplicaSets (RS) in Kubernetes `1.9`.

RS and RC are two resources that work similarly. But RS is more flexible in its
*label selector*. With RC, it can only select Pods whose labels exactly match its
own. RS, on the other hand, allows some expressions in the label selector.

For example, RC can't select Pods with `env=production` and `env=testing` at the
same time, whereas RS can, by specifying a label selector with a value like
`env=***`. In addition, RS supports operators with the `matchExpressions` property:

```yaml
selector:
  matchExpressions:
    - key: app
      operator: In
      values:
        - kubia
```

There are four basic operators: In, NotIn, Exists, DoesNotExist. They let an RS
select many different Pods.

## Using ReplicaSets

We'll use ReplicaSets (RS) to deploy Pods instead of RC. The RS configuration is the
same as RC, only the `selector` property differs. Create a file named `hello-rs.yaml`:

```yaml
apiVersion: apps/v1 # change API version
kind: ReplicaSet # change resource name
metadata:
  name: hello-rs
spec:
  replicas: 2
  selector:
    matchLabels: # change here
      app: hello-kube
  template:
    metadata:
      labels:
        app: hello-kube
    spec:
      containers:
      - image: 080196/hello-kube
        name: hello-kube
        ports:
          - containerPort: 3000
```

Run `apply`:

```bash
kubectl apply -f hello-rs.yaml
```

Check whether the RS was created successfully:

```bash
kubectl get rs
```

```
NAME       DESIRED   CURRENT    READY   AGE
hello-rs   2         2          2       3s
```

Check that the number of Pods created by the RS equals the `replicas` field:

```bash
kubectl get pod
```

```
NAME             READY   STATUS    RESTARTS   AGE
hello-rs-gmxfp   1/1     Running   0          21s
hello-rs-xhtkg   1/1     Running   0          21s
```

If 2 Pods are created, we ran the RS successfully. As you can see, the RS works like
the RC, only the `selector` configuration differs. This might be a question you get
in an interview if you meet someone who likes to ask about theory.

To delete the RS, run `delete`:

```bash
kubectl delete rs hello-rs
```

## DaemonSets

Unlike RS — where Pods managed by an RS can be deployed on any Node, and a single
Node can run multiple Pods — DaemonSets are used when we want to deploy exactly one
Pod per Node. The number of Pods corresponds to the number of selected Nodes, and it
has no `replicas` property.

![DaemonSet](/assets/images/posts/kubernetes-05-replicasets-and-daemonsets/daemonset.png)

One use of DaemonSets is log collection and system monitoring. When we need to
collect logs from a Node, we only need one Pod per Node — because if more than one
Pod collects logs from the same Node, logs would be duplicated in storage.

Another example: we need to monitor all Nodes that use SSD disks. We'll label the
Nodes like this:

```bash
kubectl label nodes <your-node-name> disk=ssd
```

Then specify it in the DaemonSet's `nodeSelector` property:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ssd-monitor
spec:
  selector:
    matchLabels:
      app: ssd-monitor
  template:
    metadata:
      labels:
        app: ssd-monitor
    spec:
      nodeSelector: # config here
        disk: ssd
      containers:
        - name: main
          image: luksa/ssd-monitor
```

When you create the DaemonSet, it only deploys Pods to Nodes labeled `disk=ssd`.

![DaemonSet with nodeSelector](/assets/images/posts/kubernetes-05-replicasets-and-daemonsets/daemonset-nodeselector.png)

Learn more about DaemonSets [here](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/).

## Conclusion

We've now learned about ReplicaSets and DaemonSets. RS is the enhanced version of RC
and is used in practice. Use DaemonSet when you want to deploy one Pod per Node.
