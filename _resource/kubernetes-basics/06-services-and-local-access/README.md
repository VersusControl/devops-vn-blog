# Kubernetes Basics Chapter 6 Resource

Apply the Chapter 5 Deployment, then create the internal Service:

```sh
kubectl apply -f ../05-deployments-and-rollouts/deployment.yaml
kubectl apply -f service.yaml
kubectl port-forward -n tasks service/task-api 8080:80
```

In another terminal, run `curl --fail http://localhost:8080/`. The manifest only defines the
ClusterIP Service; port-forward is a temporary client command and leaves no resource behind.