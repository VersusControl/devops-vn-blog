# Chapter 14: The Kubernetes Gateway API with Istio

Article: https://devopsvn.tech/kubernetes-service-mesh-14-gateway-api/

Starting state: Book Store at http://bookstore.local:8080 (`./scripts/bootstrap.sh 14`), and the
chapter 4 certificates in `certs/` (`./scripts/make-certs.sh`).

| File | Purpose |
| --- | --- |
| `gateway.yaml` | Gateway API `Gateway` (class `istio`) + ConfigMap that makes its Service a NodePort 30090 (localhost:9080). |
| `httproute.yaml` | Chapter 3's routes as an `HTTPRoute`. |
| `gateway-https.yaml` | Adds an HTTPS listener; the Secret lives in `bookstore`. |
| `reviews-versions.yaml` | `reviews-v1` and `reviews-v3` Services (the Gateway API has no subsets). |
| `httproute-reviews-canary.yaml` | 90/10 canary as an `HTTPRoute` attached to the `reviews` Service (GAMMA). |
| `gateway-partners.yaml` | Adds an `api` listener that accepts routes from namespace `partners`. |
| `partners-route.yaml` | Namespace `partners` and its `HTTPRoute` to `productpage` in `bookstore`. |
| `referencegrant.yaml` | Lets HTTPRoutes in `partners` reference Services in `bookstore`. |
| `destinationrule-productpage.yaml` | Shows a DestinationRule still applies to the Gateway API gateway. |

```sh
export PATH="$PWD/bin:$PATH"
kubectl apply --server-side \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml

kubectl apply -f 14-gateway-api/gateway.yaml
kubectl apply -f 14-gateway-api/httproute.yaml
./scripts/count-versions.sh http://bookstore.local:9080 20

kubectl apply -f 14-gateway-api/reviews-versions.yaml -f 14-gateway-api/httproute-reviews-canary.yaml
./scripts/count-versions.sh http://bookstore.local:9080 100

kubectl apply -f 14-gateway-api/gateway-partners.yaml -f 14-gateway-api/partners-route.yaml
kubectl -n partners get httproute bookstore-api -o yaml    # status: RefNotPermitted
kubectl apply -f 14-gateway-api/referencegrant.yaml
```

Reset:

```sh
kubectl delete -f 14-gateway-api/httproute-reviews-canary.yaml -f 14-gateway-api/reviews-versions.yaml \
  -f 14-gateway-api/httproute.yaml -f 14-gateway-api/gateway-https.yaml \
  -f 14-gateway-api/destinationrule-productpage.yaml
kubectl delete -f 14-gateway-api/partners-route.yaml -f 14-gateway-api/referencegrant.yaml --ignore-not-found
kubectl -n bookstore delete configmap bookstore-gw-options
kubectl -n bookstore delete secret bookstore-local-tls
```

Chapter 15 starts on a new cluster: `./scripts/bootstrap.sh 15`.
