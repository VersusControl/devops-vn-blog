# Kubernetes Basics Chapter 5 Resource

`deployment.yaml` creates two `task-api` placeholder Pods. `deployment-image-update.yaml`
changes only the image to a nonexistent tag so that a rollout failure can be inspected and
rolled back.

```sh
kubectl apply -f ../04-pods-and-namespaces/namespace.yaml
kubectl apply -f deployment.yaml
kubectl rollout status deployment/task-api -n tasks
kubectl apply -f deployment-image-update.yaml
kubectl rollout undo deployment/task-api -n tasks
```