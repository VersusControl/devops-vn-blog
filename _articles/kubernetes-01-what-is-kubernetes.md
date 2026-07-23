---
layout: post
title: "What Is Kubernetes?"
series: "Kubernetes Basics"
series_url: /kubernetes-basics-series/
part: 1
date: 2023-08-28
author: Quan Huynh
tags: [kubernetes, devops]
image: /assets/images/posts/kubernetes-01-what-is-kubernetes/cover.svg
---

Welcome to Kubernetes Basics. In this series we'll cover the fundamental Kubernetes
resources such as Pod, ReplicaSet, Deployment, and StatefulSet; how to expose
traffic to clients with a Service; how to store data with a PersistentVolumeClaim;
and how to pass application configuration into a container with ConfigMap and
Secret. After finishing the series, you'll have a solid grasp of how to use each of
the fundamental Kubernetes resources. This series is meant to help you on your path
to becoming a Kubernetes developer. It's based on the book *Kubernetes In Action*.

## What Is Kubernetes?

Kubernetes (or k8s) is an open-source platform for managing containers. With
Kubernetes, developing, deploying, and scaling applications becomes very easy.

You can use Kubernetes on many different platforms — physical servers,
on-premises, or the cloud. Kubernetes is used by many large companies around the
world, including Google, Facebook, and Amazon, and it has a very large community.

## What Problems Does Kubernetes Solve?

To understand what problems k8s solves, let's first look at some common ways of
deploying applications.

### Running the Application Directly on a Server

![Running directly on a server](/assets/images/posts/kubernetes-01-what-is-kubernetes/run-on-server.png)

Here we run the application on a physical server. The weakness of this approach is
that there's no way to define resource boundaries between applications, which causes
resource-allocation problems.

For example, when several applications run on the same physical server, if one uses
more resources and keeps increasing its usage (because we have no limits), the
others will have fewer resources to use and will run slowly. To solve this, virtual
machines were created.

### Splitting the Server into Multiple Virtual Machines

![Virtual machines](/assets/images/posts/kubernetes-01-what-is-kubernetes/virtual-machines.png)

This is the solution to the above problem, called virtualization. Virtualization
technology lets us run multiple virtual machines (VMs) on the same physical server,
where each VM has its own operating system (OS), *file system*, and CPU.

Our applications run inside these VMs. Each VM is defined with resource limits, so
there's no problem of one application consuming resources beyond the VM's limit and
affecting applications in other VMs.

The weakness of this approach is that because a VM is virtualized by copying both
the OS and the hardware, a physical server can only create a small number of VMs —
4 or 5 on a normal server.

### Running the Application with Containers

![Containers](/assets/images/posts/kubernetes-01-what-is-kubernetes/containers.png)

Containers are also a way to virtualize applications, like VMs. A container also has
its own OS and file system, but unlike a VM, a container only copies the OS, not the
hardware. So we can run many applications on the same physical server, each with its
own environment.

With containers, developing and running our applications across different operating
systems is very easy. The weakness of containers is that they can only run
applications that can run on Linux. For example, if an application can only run on
Windows and not Linux, a container can't run it.

## So What Does Kubernetes Solve?

Running applications with containers solves many problems. But imagine the number of
containers scaling up to more than 1000 — how would we know what a container is
running and which project it belongs to? And if we want to improve an application's
performance by automatically scaling it up by 2 or 3 more containers, how would we
do that? And what if the physical server running that container fails and can't keep
running? **Kubernetes solves these problems.**

With k8s, we can group and manage containers by application and project. K8s
provides features that make it easy to scale applications, and features that keep
our system's availability as high as possible — when a physical server fails, it can
move the container to another physical server and keep it running, without affecting
the user's experience.

## Installing Kubernetes

Follow the guide below to install k8s for a local dev/test environment. Install k8s
with [Minikube](https://minikube.sigs.k8s.io/docs/start/).

## Conclusion

Using Kubernetes makes it easy to run and manage applications. The major cloud
platforms also offer very easy-to-use Kubernetes services — AWS provides EKS, Azure
provides AKS, and Google Cloud provides GKE. In the next post, we'll talk about the
most fundamental component for deploying an application on Kubernetes: the Pod.
