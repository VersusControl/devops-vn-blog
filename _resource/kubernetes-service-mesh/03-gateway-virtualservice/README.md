# Chapter 3: Expose an App with an Istio Gateway and a VirtualService

Article: https://devopsvn.tech/kubernetes-service-mesh-03-gateway-and-virtualservice/

Starting state: Istio installed, Book Store in the mesh (`./scripts/bootstrap.sh 03`).

| File | Purpose |
| --- | --- |
| `gateway.yaml` | Opens port 80 of the ingress gateway for `bookstore.local`. |
| `virtualservice.yaml` | Redirects `/` and routes Book Store's paths to `productpage`. |

```sh
export PATH="$PWD/bin:$PATH"

curl -v http://localhost:8080/productpage           # Empty reply: no listener yet
kubectl apply -f 03-gateway-virtualservice/gateway.yaml
curl -si --resolve bookstore.local:8080:127.0.0.1 http://bookstore.local:8080/productpage   # 404: no route yet
kubectl apply -f 03-gateway-virtualservice/virtualservice.yaml
curl -s --resolve bookstore.local:8080:127.0.0.1 http://bookstore.local:8080/productpage | grep -o "<title>.*</title>"
./scripts/count-versions.sh http://bookstore.local:8080 20

istioctl proxy-config listener -n istio-system deploy/istio-ingressgateway
istioctl proxy-config route -n istio-system deploy/istio-ingressgateway
kubectl -n istio-system logs deploy/istio-ingressgateway --tail=3
```

Break it:

```sh
# Wrong gateway name -> 404 NR
kubectl -n bookstore patch virtualservice bookstore --type=json \
  -p='[{"op":"replace","path":"/spec/gateways/0","value":"bookstore-gw"}]'
istioctl analyze -n bookstore
kubectl apply -f 03-gateway-virtualservice/virtualservice.yaml

# Selector that matches no gateway Pod -> empty reply
kubectl -n bookstore patch gateway bookstore-gateway --type=merge \
  -p '{"spec":{"selector":{"istio":"ingress"}}}'
istioctl analyze -n bookstore
kubectl apply -f 03-gateway-virtualservice/gateway.yaml
```

Keep both objects for chapter 4. Starting state of chapter 4: `./scripts/bootstrap.sh 04`.
