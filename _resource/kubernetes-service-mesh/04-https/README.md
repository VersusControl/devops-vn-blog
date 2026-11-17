# Chapter 4: HTTPS, Redirects, and Several Hosts on One Istio Gateway

Article: https://devopsvn.tech/kubernetes-service-mesh-04-https-and-multiple-hosts/

Starting state: chapter 3's Gateway and VirtualService (`./scripts/bootstrap.sh 04`).

| File | Purpose |
| --- | --- |
| `../scripts/make-certs.sh` | Local CA + certificates in `certs/` (bookstore.local, api.bookstore.local, payments.bookstore.local, partner-client). |
| `gateway-https.yaml` | Step 1: HTTP + HTTPS (`SIMPLE`) for bookstore.local. |
| `gateway-redirect.yaml` | Step 2: `httpsRedirect` on the HTTP server. |
| `gateway-hosts.yaml` | Step 3: adds api.bookstore.local (`MUTUAL`) and payments.bookstore.local (`PASSTHROUGH`). |
| `virtualservice-api.yaml` | Partner API host: only `/api/v1/products`. |
| `payments.yaml` | go-httpbin serving HTTPS with its own certificate. |
| `virtualservice-payments.yaml` | `tls` route by SNI for PASSTHROUGH. |

```sh
export PATH="$PWD/bin:$PATH"
./scripts/make-certs.sh

# SIMPLE
kubectl -n istio-system create secret tls bookstore-local-tls \
  --cert=certs/bookstore.local.crt --key=certs/bookstore.local.key
kubectl apply -f 04-https/gateway-https.yaml
curl -s --resolve bookstore.local:8443:127.0.0.1 --cacert certs/ca.crt https://bookstore.local:8443/productpage
istioctl proxy-config secret -n istio-system deploy/istio-ingressgateway

# Redirect
kubectl apply -f 04-https/gateway-redirect.yaml
curl -si -H "Host: bookstore.local" http://localhost:8080/productpage | head -2

# MUTUAL + PASSTHROUGH
kubectl -n istio-system create secret generic api-bookstore-local-tls \
  --from-file=tls.crt=certs/api.bookstore.local.crt \
  --from-file=tls.key=certs/api.bookstore.local.key \
  --from-file=ca.crt=certs/ca.crt
kubectl -n bookstore create secret tls payments-tls \
  --cert=certs/payments.bookstore.local.crt --key=certs/payments.bookstore.local.key
kubectl apply -f 04-https/payments.yaml -f 04-https/gateway-hosts.yaml \
  -f 04-https/virtualservice-api.yaml -f 04-https/virtualservice-payments.yaml
curl -s --resolve api.bookstore.local:8443:127.0.0.1 --cacert certs/ca.crt \
  --cert certs/partner-client.crt --key certs/partner-client.key \
  https://api.bookstore.local:8443/api/v1/products
curl -s --resolve payments.bookstore.local:8443:127.0.0.1 --cacert certs/ca.crt \
  https://payments.bookstore.local:8443/get
```

Reset before chapter 5 (back to chapter 3's HTTP-only gateway):

```sh
kubectl apply -f 03-gateway-virtualservice/gateway.yaml
kubectl delete -f 04-https/virtualservice-api.yaml -f 04-https/virtualservice-payments.yaml \
  -f 04-https/payments.yaml
kubectl -n bookstore delete secret payments-tls
kubectl -n istio-system delete secret bookstore-local-tls api-bookstore-local-tls
```
