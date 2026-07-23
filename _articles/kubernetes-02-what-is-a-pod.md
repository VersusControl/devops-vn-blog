---
layout: post
title: "What Is a Pod?"
series: "Kubernetes Basics"
series_url: /kubernetes-basics-series/
part: 2
date: 2023-09-01
author: Quan Huynh
tags: [kubernetes, devops]
image: /assets/images/posts/kubernetes-02-what-is-a-pod/cover.svg
---

In the previous post we learned what Kubernetes is. In this post we'll talk about
the most fundamental component for deploying an application on k8s: the Pod.

## What Is a Pod?

A Pod is the most fundamental component for deploying and running an application on
Kubernetes. A Pod is used to group and run one or more containers together on the
same server. The containers in a Pod share resources with each other.

![A Pod shares resources](/assets/images/posts/kubernetes-02-what-is-a-pod/pod-shares-resources.png)

**So why use a Pod to run containers instead of running containers directly?**

Kubernetes uses the Pod as an enhanced version of a container. A Pod provides many
more features to manage and run a container, helping the container work better than
running it directly with Docker. Some notable features:

- Grouping a container's resources
- Checking whether a container is running, and restarting it if not
- Checking and making sure the application inside the container is running before
  sending requests to it
- Providing *lifecycle* hooks so you can add actions to the Pod when it starts

![Pod features](/assets/images/posts/kubernetes-02-what-is-a-pod/pod-features.png)

## Running Your First Application with a Pod

Let's practice deploying our first application with a Pod. Create a file named
`index.js` with the following content:

```javascript
const http = require("http");

const server = http.createServer((req, res) => {
  res.end("Hello kube\n")
});

server.listen(3000, () => {
  console.log("Server listen on port 3000")
})
```

Create a `Dockerfile`:

```docker
FROM node:14-alpine
WORKDIR /app
COPY index.js .
ENTRYPOINT [ "node", "index" ]
```

Build the container image:

```bash
docker build . -t 080196/hello-kube
```

Test the container you just built:

```bash
docker run -d --name hello-kube -p 3000:3000 080196/hello-kube
```

Send a request to the container:

```bash
curl localhost:3000
```

```
Hello kube
```

If it prints `Hello kube`, the application inside the container is running. Remember
to remove the container:

```bash
docker rm -f hello-kube
```

Next, we use a Pod to run the container. You can use my image `080196/hello-kube` or
create your own image.

Create a file named `hello-kube.yaml`:

```yaml
apiVersion: v1 # Descriptor conforms to version v1 of the Kubernetes API
kind: Pod # Select the Pod resource
metadata:
  name: hello-kube # The name of the pod
spec:
  containers:
    - image: 080196/hello-kube # Image to create the container
      name: hello-kube # The name of the container
      ports:
        - containerPort: 3000 # The port the app is listening on
          protocol: TCP
```

> Usually we don't run a Pod directly, but use other k8s resources to run Pods.
> We'll cover that in later posts.

Use the `kubectl` CLI to create the Pod:

```bash
kubectl apply -f hello-kube.yaml
```

To check whether the Pod is running, use `get pod`:

```bash
kubectl get pod
```

```
NAME         READY   STATUS    RESTARTS   AGE
hello-kube   1/1     Running   0          21s
```

If the `status` column shows Running, the Pod started successfully; a `status` of
ContainerCreating means the Pod is still being created.

Next, we check whether the application inside the Pod is running. To do that, we
need to open the Pod's port so it can receive requests from outside — because by
default, when a Pod is created it doesn't open any port to receive traffic.

![A Pod doesn't open a port by default](/assets/images/posts/kubernetes-02-what-is-a-pod/pod-no-port.png)

There are 2 ways to expose a Pod's port: using a Service resource (covered in later
posts) or using `kubectl port-forward`. In this post we use `port-forward`:

```bash
kubectl port-forward pod/hello-kube 3000:3000
```

```
Forwarding from 127.0.0.1:3000 -> 3000
Forwarding from [::1]:3000 -> 3000
```

![Port forwarding to the Pod](/assets/images/posts/kubernetes-02-what-is-a-pod/port-forward.png)

Send a request to the Pod:

```bash
curl localhost:3000
```

```
Hello kube
```

If it prints `Hello kube`, the Pod is running correctly. To delete the Pod, run
`delete`:

```bash
kubectl delete pod hello-kube
```

```
pod "hello-kube" deleted
```

## Conclusion

We've now successfully deployed our first application with a Pod. The Pod is the
simplest component and the core Kubernetes component for running containers.
