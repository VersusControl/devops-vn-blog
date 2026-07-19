---
layout: post
title: "Working with Helm"
series: "ArgoCD"
series_url: /argocd-series/
part: 5
date: 2024-11-16
author: Quan Huynh
tags: [kubernetes, argocd, gitops, helm]
image: /assets/images/posts/argocd-05-with-helm/cover.png
---

For easier management and deployment, we usually don't write Kubernetes resource
files directly — instead we package them and use Helm to manage them. For example,
to deploy Redis in master-slave mode by writing plain YAML for each resource:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: default
spec:
  serviceName: "redis"
  replicas: 3  # One master and two replicas
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:latest
          command: ["redis-server"]
          args: ["/etc/redis/redis.conf"]
          ports:
            - containerPort: 6379
          volumeMounts:
            - name: redis-data
              mountPath: /data
            - name: redis-config
              mountPath: /etc/redis
      initContainers:
        - name: init-redis-config
          image: busybox
          command: ['sh', '-c', 'if [ "$(hostname)" == "redis-0" ]; then cp /etc/redis/master.conf /etc/redis/redis.conf; else cp /etc/redis/slave.conf /etc/redis/redis.conf; fi']
          volumeMounts:
            - name: redis-config
              mountPath: /etc/redis
  volumeClaimTemplates:
    - metadata:
        name: redis-data
      spec:
        accessModes: [ "ReadWriteOnce" ]
        resources:
          requests:
            storage: 1Gi

---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: default
spec:
  clusterIP: None  # Headless service for StatefulSet
  ports:
    - port: 6379
      targetPort: 6379
      protocol: TCP
  selector:
    app: redis

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-configs
data:
  master.conf: |
    bind 0.0.0.0
    protected-mode yes
    port 6379
    dir /data

  slave.conf: |
    bind 0.0.0.0
    protected-mode yes
    port 6379
    dir /data
    replicaof redis-0.default.svc.cluster.local 6379 # Point to the master instance
```

Instead of copying all the resources into another file and modifying the parameters
each time we deploy, we can apply more effective configuration management methods —
namely, using Helm.

## Helm

We can package all the resources into a single package and use Helm to manage them.
For popular technologies like Redis, Postgres, ClickHouse, and so on, the community
provides a lot of support, and we can use those instead of writing our own, except in
special cases. Here's an example of deploying Redis with Helm:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install my-redis bitnami/redis \
  --set password=secretpassword \
  --set replication.enabled=true \
  --set replication.slaveCount=1
```

Each time we need to deploy a new cluster, we just run the command above. However,
deploying Redis manually through the Helm CLI can make it hard to manage changes.
ArgoCD supports deploying Helm through the use of an Application.

## ArgoCD with Helm

To deploy Redis with Helm and ArgoCD, we declare a `redis-helm.yaml` file:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis-helm-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://charts.bitnami.com/bitnami'
    chart: redis
    targetRevision: 17.11.3  # Use the desired version of the chart
    helm:
      releaseName: redis
      parameters:
        - name: password
          value: "your-redis-password"  # Set your Redis password here
        - name: replication.enabled
          value: "true"
        - name: replication.slaveCount
          value: "2"  # Number of replicas you want to create
  destination:
    server: 'https://kubernetes.default.svc'
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Compared to an Application for plain resource files, the part that changes is the
`source:` section:

- **repoURL**: the Helm chart repository URL
- **chart**: the chart to deploy
- **targetRevision**: the version
- **helm.parameters**: the parameters we need to pass in

Run apply:

```bash
kubectl apply -f redis-helm.yaml
```

In the UI you'll see the Application for Redis being created:

![Redis creating](/assets/images/posts/argocd-05-with-helm/redis-creating.png)

Wait for Redis to be created successfully:

![Redis created](/assets/images/posts/argocd-05-with-helm/redis-created.png)

## GitOps

Above is how we use an Application to deploy Redis with Helm. However, to manage all
changes through Git and properly follow the GitOps standard, we need to do the same
steps as when deploying the Book Info application. Specifically, we create a Git
repository with the two files below, then create an Argo Application for that repo.

```
├── Chart.yaml
└── values.yaml
```

Contents of `Chart.yaml`:

```yaml
apiVersion: v2
name: redis
description: A Helm chart for redis

type: application
version: 17.11.3

dependencies:
  - name: redis
    version: 17.11.3
    repository: https://charts.bitnami.com/bitnami
```

Contents of `values.yaml`:

```yaml
redis:
  password: your-redis-password
  replication:
    enabled: true
    slaveCount: 2
```

See [argocd-series/05-gitops/gitops](https://github.com/hoalongnatsu/argocd-series/tree/main/05-gitops/gitops).
Create an `app.yaml` file to declare the Argo Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/hoalongnatsu/argocd-series'
    targetRevision: HEAD
    path: '05-gitops/gitops'
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Run apply:

```bash
kubectl apply -f app.yaml
```

Wait for Redis to be created successfully:

![Redis GitOps](/assets/images/posts/argocd-05-with-helm/redis-gitops.png)

Any change to Redis now requires editing the `values.yaml` file and merging it into
Git. Using Helm makes it easy to deploy applications, and combined with ArgoCD to
manage Helm chart changes through Git ⇒ managing and deploying applications becomes
more professional.

In the next post, we'll learn how to use ArgoCD with Kustomize.
