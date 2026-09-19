# Kubernetes Basics Chapter 4 Resource

Apply the Namespace before the Pod because `pod.yaml` explicitly targets `tasks`.

```sh
kubectl apply -f namespace.yaml
kubectl apply -f pod.yaml
kubectl get pods -n tasks -o wide
kubectl describe pod pod-inspector -n tasks
```

`namespace.yaml` creates the logical scope. `pod.yaml` creates one inspectable nginx Pod; it has
no controller, Service, or persistence.

Delete both resources after the experiment:

```sh
kubectl delete -f pod.yaml
kubectl delete -f namespace.yaml
```