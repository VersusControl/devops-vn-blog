# Chapter 10: Control Traffic Leaving the Mesh: ServiceEntry and the Egress Gateway

Article: https://devopsvn.tech/kubernetes-service-mesh-10-serviceentry-and-egress-gateway/

Starting state: Istio (with the egress gateway) and Book Store in the mesh
(`./scripts/bootstrap.sh 10`).

The "external" partner is a Docker container on the `kind` network, outside the cluster:

```sh
docker run -d --name partner-catalog --network kind \
  --network-alias catalog.partner.example \
  --restart unless-stopped docker.io/mccutchen/go-httpbin:v2.15.0
```

| File | Purpose |
| --- | --- |
| `tester.yaml` | A curl client Pod in `bookstore` (with a sidecar). |
| `sidecar-registry-only.yaml` | `REGISTRY_ONLY` for the `bookstore` namespace. |
| `serviceentry-partner-catalog.yaml` | Registers `catalog.partner.example:8080` (HTTP). |
| `egress-gateway.yaml` | Gateway + two-hop VirtualService through the egress gateway (port 80). |
| `egress-gateway-mtls.yaml` | Same, with `ISTIO_MUTUAL` between the sidecar and the egress gateway (port 443). |

```sh
export PATH="$PWD/bin:$PATH"
kubectl apply -f 10-egress/tester.yaml
kubectl -n bookstore exec deploy/tester -c tester -- curl -s http://catalog.partner.example:8080/get

kubectl apply -f 10-egress/sidecar-registry-only.yaml          # blocked
kubectl apply -f 10-egress/serviceentry-partner-catalog.yaml   # allowed
kubectl apply -f 10-egress/egress-gateway.yaml                 # through the egress gateway
kubectl apply -f 10-egress/egress-gateway-mtls.yaml            # with mesh mTLS to the gateway
kubectl -n istio-system logs deploy/istio-egressgateway --tail=1
```

Reset before chapter 11:

```sh
kubectl delete -f 10-egress/egress-gateway-mtls.yaml -f 10-egress/serviceentry-partner-catalog.yaml \
  -f 10-egress/sidecar-registry-only.yaml -f 10-egress/tester.yaml
docker rm -f partner-catalog
```
