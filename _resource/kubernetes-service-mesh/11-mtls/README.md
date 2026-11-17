# Chapter 11: Mutual TLS Between Services with Istio

Article: https://devopsvn.tech/kubernetes-service-mesh-11-mutual-tls/

Starting state: Book Store in the mesh (`./scripts/bootstrap.sh 11`).

| File | Purpose |
| --- | --- |
| `httpbin.yaml` | Echo service in `bookstore`; shows the `X-Forwarded-Client-Cert` header its sidecar adds. |
| `tester.yaml` | curl client in `bookstore` (with a sidecar). |
| `outside-client.yaml` | Namespace `reports` (no injection) with Pod `report-job` (no sidecar). |
| `peerauthentication-strict.yaml` | `STRICT` mTLS for the `bookstore` namespace. Kept for chapter 12. |
| `peerauthentication-ratings-permissive.yaml` | Temporary workload-level exception for `ratings`. |

```sh
export PATH="$PWD/bin:$PATH"
kubectl apply -f 11-mtls/httpbin.yaml -f 11-mtls/tester.yaml -f 11-mtls/outside-client.yaml

kubectl -n bookstore exec deploy/tester -c tester -- curl -s http://httpbin:8000/headers
istioctl proxy-config secret deploy/productpage-v1 -n bookstore

# Which workloads still receive plain text? (port-forward Prometheus first)
kubectl -n istio-system port-forward svc/prometheus 9090:9090
curl -s http://localhost:9090/api/v1/query --data-urlencode \
  'query=sum by (destination_workload) (istio_requests_total{reporter="destination", destination_workload_namespace="bookstore", connection_security_policy="none"})'

kubectl apply -f 11-mtls/peerauthentication-strict.yaml
kubectl -n reports exec report-job -- curl -s http://ratings.bookstore:9080/ratings/0   # reset

# Fix: give the client a sidecar
kubectl label namespace reports istio-injection=enabled
kubectl -n reports delete pod report-job && kubectl apply -f 11-mtls/outside-client.yaml
```

Reset before chapter 12 (keep STRICT):

```sh
kubectl delete -f 11-mtls/httpbin.yaml -f 11-mtls/tester.yaml
kubectl delete namespace reports
```
