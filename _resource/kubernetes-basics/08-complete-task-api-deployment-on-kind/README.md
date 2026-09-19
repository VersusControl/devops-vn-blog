# Kubernetes Basics Chapter 8 Resource

This is the complete local Task API manifest set. Replace the image placeholder in
`deployment.yaml`, create `task-api-secret`, and create `ghcr-pull-secret` before applying a
private GHCR image.

```sh
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f persistent-volume-claim.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl rollout status deployment/task-api -n tasks
kubectl port-forward -n tasks service/task-api 8080:80
```

The Secret template is documentation only. Do not apply it with a real credential.