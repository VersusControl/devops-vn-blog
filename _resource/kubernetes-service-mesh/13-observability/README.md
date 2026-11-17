# Chapter 13: See the Mesh: Metrics, Tracing, and Kiali

Article: https://devopsvn.tech/kubernetes-service-mesh-13-metrics-tracing-kiali/

Starting state: Book Store in the mesh with Prometheus and Kiali (`./scripts/bootstrap.sh 13`).

| File | Purpose |
| --- | --- |
| `istio-tracing.yaml` | IstioOperator overlay: registers Jaeger (`zipkin` Service) as extension provider `jaeger`. |
| `telemetry-tracing.yaml` | Telemetry API: tracing on for the whole mesh, 100% sampling (lab only). |
| `promql.sh` | Runs one PromQL query against `localhost:9090` and prints one line per series. |
| `show-trace.py` | Prints the largest recent trace for a service as a tree (Jaeger API on `localhost:16686`). |
| `list-traces.py` | Lists recent traces that include a service, with span counts. |
| `storefront.yaml` | A small Python service that calls productpage; `FORWARD_TRACE_HEADERS` controls header propagation. |
| `tester.yaml` | curl client in `bookstore`. |

```sh
export PATH="$PWD/bin:$PATH"
./cluster/addons.sh grafana jaeger

kubectl -n istio-system port-forward svc/prometheus 9090:9090      # terminal 2
./13-observability/promql.sh 'sum by (destination_version) (rate(istio_requests_total{reporter="destination", destination_service_name="reviews"}[2m]))'

istioctl install -f cluster/istio-install.yaml -f 13-observability/istio-tracing.yaml -y
kubectl apply -f 13-observability/telemetry-tracing.yaml
kubectl -n istio-system port-forward svc/tracing 16686:80          # terminal 3
python3 13-observability/show-trace.py istio-ingressgateway.istio-system

kubectl apply -f 13-observability/storefront.yaml -f 13-observability/tester.yaml
kubectl -n bookstore exec deploy/tester -c tester -- curl -s http://storefront:8080/
python3 13-observability/list-traces.py storefront.bookstore       # two traces per request
kubectl -n bookstore set env deploy/storefront-v1 FORWARD_TRACE_HEADERS=true
python3 13-observability/list-traces.py storefront.bookstore       # one trace per request
```

Reset before chapter 14:

```sh
kubectl delete -f 13-observability/storefront.yaml -f 13-observability/tester.yaml
```
