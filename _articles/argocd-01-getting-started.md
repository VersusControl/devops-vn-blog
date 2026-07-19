---
layout: post
title: "Getting Started"
series: "ArgoCD"
series_url: /argocd-series/
part: 1
date: 2024-10-14
author: Quan Huynh
tags: [kubernetes, argocd, gitops]
image: /assets/images/posts/argocd-01-getting-started/cover.svg
---

## What Is Argo CD?

Argo CD is an open-source tool designed to support the **GitOps** workflow for
deploying applications on **Kubernetes**. Argo CD is applied in the CD (Continuous
Delivery) step of the CI/CD flow — this is the step where we deploy the application
to the server environment.

Argo CD uses Git repositories as the primary source of truth to determine the
desired application state, which is why it's called a GitOps tool. In this series we
use Argo CD to deploy the **Microservice Book Info** application below.

![Book Info microservices](/assets/images/posts/argocd-01-getting-started/bookinfo.png)

In this first post, we'll learn how to install Argo CD and use the simplest way to
deploy the Book Info application.

## Installing Argo CD

Create a namespace for argocd and install it:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Check that the installation succeeded:

```bash
kubectl get pods -n argocd
```

```
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          3m39s
argocd-applicationset-controller-744b76d7fd-xgk2d   1/1     Running   0          3m39s
argocd-dex-server-5bf5dbc64d-w8vdx                  1/1     Running   0          3m39s
argocd-notifications-controller-84f5bf6896-5mdbg    1/1     Running   0          3m39s
argocd-redis-74b8999f94-zmm5b                       1/1     Running   0          3m39s
argocd-repo-server-57f4899557-vxcrf                 1/1     Running   0          3m39s
argocd-server-7bc7b97977-nclk6                      1/1     Running   0          3m39s
```

**Install the Argo CD CLI** to interact with Argo CD. On Mac, Linux, or WSL, run:

```bash
brew install argocd
```

For Windows, see the [CLI installation documentation](https://argo-cd.readthedocs.io/en/stable/cli_installation/).
Access the Argo CD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Because we're running on localhost, the website reports "unsafe"; click "proceed to
localhost (unsafe)":

![Unsafe warning](/assets/images/posts/argocd-01-getting-started/unsafe-warning.png)

The login UI:

![Login UI](/assets/images/posts/argocd-01-getting-started/login.png)

The default Argo CD account is `admin`. To get the password, run:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

The UI after logging into Argo CD:

![Argo CD dashboard](/assets/images/posts/argocd-01-getting-started/dashboard.png)

## Deploying the Book Info Application

Book Info consists of the following services:

- Products Service
- Details Service
- Reviews Service
- Ratings Service

To deploy an application on Argo CD, we need to create an Application (explained in
detail in the next post). Click the **+ New App** button in the UI.

![New App](/assets/images/posts/argocd-01-getting-started/new-app.png)

Enter `bookinfo` as the application name, choose `default` for the project, and set
the sync policy to Automatic. Leave the SYNC OPTIONS at their defaults for now.

![App general settings](/assets/images/posts/argocd-01-getting-started/app-general.png)

The **Repository URL** field is where we connect to Git, which holds the Kubernetes
resource files we want to deploy. Use my repo
[istio-microservice-book-info](https://github.com/hoalongnatsu/istio-microservice-book-info).
It's a public repo that anyone can access; in the next post I'll show how to connect
to a private repo. For the Path, enter `.` for the root directory:

![Repository URL and path](/assets/images/posts/argocd-01-getting-started/repo-path.png)

For **Destination**, enter `https://kubernetes.default.svc` and choose the namespace
to deploy to — mine is `default`.

![Destination](/assets/images/posts/argocd-01-getting-started/destination.png)

Click the **Create** button.

![Create](/assets/images/posts/argocd-01-getting-started/create.png)

Wait for Argo CD to deploy the application.

![Deploying](/assets/images/posts/argocd-01-getting-started/deploying.png)

Once the status changes to synced, the bookinfo application has been deployed to the
Kubernetes environment successfully. Click on the app.

![Synced](/assets/images/posts/argocd-01-getting-started/synced.png)

The services we defined in YAML files and stored in Git have been deployed to
Kubernetes by Argo CD. To check, open the Products page:

```bash
kubectl port-forward svc/products 9080:9080
```

![Products page](/assets/images/posts/argocd-01-getting-started/products.png)

In this post, we successfully deployed the Book Info microservice application the
simple way. In the next post, we'll go deeper into Argo CD concepts and apply them
to deploy applications more professionally and effectively.
