# Kubernetes Basics Chapter 7 Resource

The resources have separate purposes: `configmap.yaml` holds ordinary settings,
`secret.template.yaml` documents the required secret key without a real value, and
`persistent-volume-claim.yaml` requests task-data storage.

```sh
kubectl apply -f configmap.yaml
kubectl apply -f persistent-volume-claim.yaml
kubectl get pvc task-api-data -n tasks
```

Create the real Secret from an environment variable with `kubectl create secret generic`; do not
apply the template with a credential.