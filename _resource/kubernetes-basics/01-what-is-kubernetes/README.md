# Kubernetes Basics Chapter 1 Resource

`hello-web-deployment.yaml` contains one Kubernetes Deployment. Its single purpose is to
declare that a cluster should keep two `nginx:1.27-alpine` web-server Pods running.

After creating a Kubernetes cluster, apply it with:

```sh
kubectl apply -f hello-web-deployment.yaml
kubectl rollout status deployment/hello-web
kubectl get deployment hello-web
kubectl get pods -l app=hello-web
```

`kubectl rollout status` waits for the Deployment to finish starting its Pods. It should report
that the rollout completed; `kubectl get deployment hello-web` should then report `2/2` ready
replicas. This resource does not expose the Pods outside the cluster; a Service is intentionally
out of scope for this first example.

Remove the example when finished:

```sh
kubectl delete -f hello-web-deployment.yaml
```