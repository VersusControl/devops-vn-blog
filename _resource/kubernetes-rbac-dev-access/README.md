# Kubernetes RBAC in Practice: read-only access to one namespace

Example code for the article
[Kubernetes RBAC in Practice](https://devopsvn.tech/kubernetes-create-and-authorize-users/).

It gives developers read access to Pods and their logs in the `dev` namespace, and nothing in
`pro`, through a ServiceAccount, a Role, a RoleBinding, and a separate kubeconfig file with a
short-lived token. Tested on Kind (Kubernetes 1.37).

| Path | Purpose |
| --- | --- |
| `manifests/01-namespaces-and-apps.yaml` | The `dev` and `pro` namespaces, each with a small `orders` app that writes a log line every 5 seconds. |
| `manifests/02-dev-viewer.yaml` | The `dev-viewer` ServiceAccount, the `pod-reader` Role (`pods`, `pods/log`: get, list, watch), and the RoleBinding, all in `dev`. |
| `scripts/make-kubeconfig.sh` | Writes `dev-viewer.kubeconfig` with a token from `kubectl create token` (default 8 hours). Your own kubeconfig is not changed. |
| `scripts/cleanup.sh` | Deletes everything, including the kubeconfig file. |

## Run it

```sh
kubectl apply -f manifests/01-namespaces-and-apps.yaml
kubectl apply -f manifests/02-dev-viewer.yaml

# check the permissions before handing anything over
kubectl auth can-i get pods -n dev --as=system:serviceaccount:dev:dev-viewer      # yes
kubectl auth can-i get pods -n pro --as=system:serviceaccount:dev:dev-viewer      # no

scripts/make-kubeconfig.sh 8h
KUBECONFIG=dev-viewer.kubeconfig kubectl get pods
KUBECONFIG=dev-viewer.kubeconfig kubectl logs -l app=orders --tail=5

scripts/cleanup.sh
```

`dev-viewer.kubeconfig` contains a token. Send it privately, and don't commit it.
