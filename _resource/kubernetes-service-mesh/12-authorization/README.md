# Chapter 12: Authorization Policies and JWT at the Istio Gateway

Article: https://devopsvn.tech/kubernetes-service-mesh-12-authorization-and-jwt/

Starting state: chapter 11's STRICT mTLS in `bookstore` (`./scripts/bootstrap.sh 12`).

| File | Purpose |
| --- | --- |
| `deny-all.yaml` | Default deny for `bookstore` (an empty ALLOW policy). |
| `allow-bookstore.yaml` | One ALLOW policy per workload: gateway → productpage → details/reviews, reviews → ratings. |
| `admin-host.yaml` | Adds `admin.bookstore.local` to the gateway and routes `/ratings/` to ratings. |
| `allow-ratings-admin.yaml` | ratings: reviews may GET, the ingress gateway may GET and POST. |
| `requestauthentication.yaml.tpl` | Template; `scripts/make-jwt.sh` writes `jwt/requestauthentication.yaml` with your key. |
| `gateway-admin-policy.yaml` | DENY at the gateway: admin host needs a valid JWT with `role: admin`. |

```sh
export PATH="$PWD/bin:$PATH"

kubectl apply -f 12-authorization/deny-all.yaml          # everything 403
kubectl apply -f 12-authorization/allow-bookstore.yaml   # Book Store works again

./scripts/make-jwt.sh                                     # jwt/: key, JWKS, admin.jwt, viewer.jwt
kubectl apply -f 12-authorization/admin-host.yaml -f 12-authorization/allow-ratings-admin.yaml
kubectl apply -f jwt/requestauthentication.yaml -f 12-authorization/gateway-admin-policy.yaml

R="admin.bookstore.local:8080:127.0.0.1"
curl -s --resolve "$R" http://admin.bookstore.local:8080/ratings/0                                          # 403
curl -s --resolve "$R" -H "Authorization: Bearer $(cat jwt/viewer.jwt)" http://admin.bookstore.local:8080/ratings/0  # 403
curl -s --resolve "$R" -H "Authorization: Bearer $(cat jwt/admin.jwt)" http://admin.bookstore.local:8080/ratings/0   # 200
```

Reset before chapter 13 (keep STRICT mTLS):

```sh
kubectl delete -f 12-authorization/gateway-admin-policy.yaml -f jwt/requestauthentication.yaml
kubectl delete -f 12-authorization/allow-ratings-admin.yaml -f 12-authorization/allow-bookstore.yaml \
  -f 12-authorization/deny-all.yaml --ignore-not-found
kubectl delete virtualservice bookstore-admin -n bookstore
kubectl apply -f 03-gateway-virtualservice/gateway.yaml
```
