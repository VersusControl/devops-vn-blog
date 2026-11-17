# Chapter 5: Debug the Istio Gateway: From YAML to Envoy Config

Article: https://devopsvn.tech/kubernetes-service-mesh-05-debug-the-gateway/

Starting state: chapter 3's HTTP gateway (`./scripts/bootstrap.sh 05`).

| File | Purpose |
| --- | --- |
| `virtualservice-maintenance.yaml` | Failure 4: a second VirtualService for the same host. |
| `telemetry-gateway-errors.yaml` | Telemetry API: the ingress gateway logs only failed requests. |

```sh
export PATH="$PWD/bin:$PATH"

# The four layers
istioctl proxy-config listener -n istio-system deploy/istio-ingressgateway --port 8080
istioctl proxy-config route    -n istio-system deploy/istio-ingressgateway --name http.8080
istioctl proxy-config cluster  -n istio-system deploy/istio-ingressgateway --fqdn productpage.bookstore.svc.cluster.local
istioctl proxy-config endpoint -n istio-system deploy/istio-ingressgateway --cluster "outbound|9080||productpage.bookstore.svc.cluster.local"

# Failure 1: UH (no endpoints)
kubectl -n bookstore scale deploy/productpage-v1 --replicas=0
kubectl -n bookstore scale deploy/productpage-v1 --replicas=1

# Failure 2: NC (destination host typo)
kubectl -n bookstore patch virtualservice bookstore --type=json \
  -p='[{"op":"replace","path":"/spec/http/1/route/0/destination/host","value":"productpages"}]'
kubectl apply -f 03-gateway-virtualservice/virtualservice.yaml

# Failure 3: URX,UF in the sidecar (wrong targetPort)
kubectl -n bookstore patch svc productpage --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":9090}]'
kubectl -n bookstore patch svc productpage --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":9080}]'

# Failure 4: two VirtualServices for one host
kubectl apply -f 05-debug-gateway/virtualservice-maintenance.yaml
kubectl delete -f 05-debug-gateway/virtualservice-maintenance.yaml

# Error-only gateway logs
kubectl apply -f 05-debug-gateway/telemetry-gateway-errors.yaml
kubectl delete -f 05-debug-gateway/telemetry-gateway-errors.yaml
```
