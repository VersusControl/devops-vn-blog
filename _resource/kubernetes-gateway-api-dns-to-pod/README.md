# From DNS to Pod with the Kubernetes Gateway API

Example manifests for the article
[Kubernetes Gateway API: How a Request Travels from DNS to Pod](https://devopsvn.tech/kubernetes-gateway-api-dns-to-pod/).

| File | Purpose |
| --- | --- |
| `00-namespace.yaml` | Creates the `shop` namespace. |
| `01-backends.yaml` | Two Deployments and Services: `payment-service` and `auth-service`. |
| `02-gateway.yaml` | A Gateway with one HTTP listener for `*.example.com`. |
| `03-httproute.yaml` | Routes `api.example.com/payment` and `/auth` to the two Services. |

Tested with Kind, Gateway API v1.6.1 CRDs, and NGINX Gateway Fabric 2.7.2.

## Run on Kind

```sh
kind create cluster --name gateway-demo

kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" \
  | kubectl apply -f -

# Kind has no cloud load balancer, so expose the data plane as NodePort.
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --version 2.7.2 --create-namespace -n nginx-gateway \
  --set nginx.service.type=NodePort --wait

kubectl apply -f 00-namespace.yaml -f 01-backends.yaml -f 02-gateway.yaml -f 03-httproute.yaml
kubectl -n shop wait --for=condition=Programmed gateway/shop-gateway --timeout=180s
kubectl -n shop rollout status deploy/shop-gateway-nginx
```

In a second terminal:

```sh
kubectl -n shop port-forward svc/shop-gateway-nginx 8080:80
```

Then test:

```sh
curl -H 'Host: api.example.com' http://127.0.0.1:8080/payment   # payment-service
curl -H 'Host: api.example.com' http://127.0.0.1:8080/auth      # auth-service
```

## Clean up

```sh
kind delete cluster --name gateway-demo
```
