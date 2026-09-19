---
layout: post
title: "Configure Applications with ConfigMaps, Secrets, and Storage"
series: "Kubernetes Basics"
series_url: /kubernetes-basics-series/
part: 7
date: 2026-09-12
author: Quan Huynh
subtitle: "Keep Task API configuration, credentials, and task data outside the container image and give each a separate lifecycle."
tags: [kubernetes, configmaps, secrets, persistent-volumes, storage]
image: /assets/images/posts/kubernetes-basics-07-configmaps-secrets-and-storage/cover.svg
---

An image should contain application code and runtime dependencies, not the message for one
environment, an API token, or the data created by users. Baking those values into an image
requires a rebuild for a configuration change and can leak a credential through image history.
Writing task data only to a container filesystem loses it when Kubernetes replaces the Pod.

This chapter gives each concern its own Kubernetes resource: a ConfigMap for non-sensitive
settings, a Secret template for credentials, and a PersistentVolumeClaim (PVC) for task data.
By the end, you will know what each resource stores, what it does not secure, and how Chapter 8
mounts or injects it into the Task API.

> **Code for this chapter.** The focused manifests and README are in
> [_resource/kubernetes-basics/07-configmaps-secrets-and-storage](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/kubernetes-basics/07-configmaps-secrets-and-storage).

![ConfigMap and Secret inputs with a persistent volume claim mounted outside the Task API container filesystem](/assets/images/posts/kubernetes-basics-07-configmaps-secrets-and-storage/configuration-storage-boundaries.svg)

## Put Plain Configuration in a ConfigMap

The Task API reads `APP_MESSAGE` and `PORT` from its environment. Neither is a credential, so a
ConfigMap is appropriate:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: task-api-config
  namespace: tasks
data:
  APP_MESSAGE: Tasks are ready from Kubernetes.
  PORT: "3000"
```

`data` values are strings. The quotes around `3000` make that fact clear; environment variables
are strings even when the application later parses a number. Apply and inspect the ConfigMap:

```sh
kubectl apply -f configmap.yaml
kubectl get configmap task-api-config -n tasks -o yaml
```

ConfigMaps are not encrypted secret stores. Anyone with permission to read this ConfigMap can
read its values. A ConfigMap consumed as an environment variable does not update an already
running process when it changes. A Deployment rollout creates Pods with the new environment.
Mounted ConfigMap files can update eventually, but the application must reload them.

## Treat a Secret as Sensitive Input

The Task API can require `API_TOKEN` for `POST /tasks`. The resource folder contains
`secret.template.yaml`, not a usable secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: task-api-secret
  namespace: tasks
type: Opaque
stringData:
  API_TOKEN: CHANGE_ME
```

`stringData` lets a human provide plain text; the API server converts it to the base64-encoded
`data` field when it stores the Secret. Base64 is encoding, not encryption. Access control, API
server encryption at rest when configured, audit logging, and an external secret manager are
separate controls.

Do not apply the template with a real token committed to Git. For a local experiment, create the
Secret from an environment variable instead:

```sh
kubectl create secret generic task-api-secret \
  --namespace tasks \
  --from-literal=API_TOKEN="$TASK_API_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Set `TASK_API_TOKEN` in the current shell from a secret manager or interactive prompt. The
command sends generated YAML directly to the API and does not create a file. In production, use
an external-secrets controller, encrypted GitOps secret system, or CI secret store according to
the organization's policy.

## Request Durable Data With a PVC

The API saves tasks under `/var/lib/task-api/tasks.json`. A PVC requests storage that survives
replacement Pods:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task-api-data
  namespace: tasks
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

The claim asks for one gibibyte with `ReadWriteOnce` access. That mode generally means the volume
can be mounted read-write by one node at a time; it does not mean one Pod in every storage
implementation. A *StorageClass* chooses how Kubernetes provisions a backing PersistentVolume.
Kind commonly has local storage suitable for experiments, but deleting the Kind cluster is not a
backup strategy. The claim does not name a StorageClass, so Kubernetes uses the cluster's default
class when one exists.

```sh
kubectl apply -f persistent-volume-claim.yaml
kubectl get pvc task-api-data -n tasks
kubectl get storageclass
```

The PVC should become `Bound`. If it remains `Pending`, inspect `kubectl describe pvc
task-api-data -n tasks`. A cluster without a default StorageClass cannot dynamically satisfy a
claim until you specify an available class or an administrator supplies a matching volume.

## Mounting Changes the Deployment Boundary

Chapter 8 mounts the claim at `/var/lib/task-api`. The mount makes data available, but it does
not make the application safe for every replica pattern. This API uses a JSON file without
concurrent-write coordination. One replica is appropriate for the tutorial. Two replicas with
independent disks split task state, while two writers sharing storage can corrupt it.

For a production API, use a database designed for concurrent access and operate it with backup,
availability, and migration plans. A PVC provides durable block or filesystem storage, not an
application data model.

## Summary

- ConfigMaps hold non-sensitive configuration and need a rollout when environment values change.
- Secrets are access-controlled objects, but base64 encoding alone does not protect credentials.
- Keep only a placeholder Secret template in source; create real values from a trusted source.
- A PVC requests durable storage, while a StorageClass determines how backing storage is supplied.
- Persistent storage does not make a file-based application safe for concurrent replicas.

The final chapter combines these resources with the Task API image, health probes, a Service,
and Kind-specific private registry access.