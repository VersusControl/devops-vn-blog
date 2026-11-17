# Chapter 7: Route by User and Header with Istio

Article: https://devopsvn.tech/kubernetes-service-mesh-07-route-by-user-and-header/

Starting state: the `reviews` DestinationRule from chapter 6, no `reviews` VirtualService
(`./scripts/bootstrap.sh 07`).

| File | Purpose |
| --- | --- |
| `virtualservice-reviews-qa.yaml` | `end-user: qa-team` → v3, everyone else → v1. |
| `virtualservice-reviews-preview-header.yaml` | Adds `x-bookstore-preview: true` → v3. Never fires through productpage (the header isn't forwarded). |
| `virtualservice-reviews-preview-cookie.yaml` | Fix: match a `bookstore-preview=true` cookie, which productpage forwards. |

```sh
export PATH="$PWD/bin:$PATH"

kubectl apply -f 07-header-routing/virtualservice-reviews-qa.yaml
./scripts/count-versions.sh http://bookstore.local:8080 20
curl -s --resolve bookstore.local:8080:127.0.0.1 -c /tmp/qa-cookies.txt \
  -d 'username=qa-team&passwd=anything' -o /dev/null http://bookstore.local:8080/login
CURL_OPTS="-b /tmp/qa-cookies.txt" ./scripts/count-versions.sh http://bookstore.local:8080 20

kubectl apply -f 07-header-routing/virtualservice-reviews-preview-header.yaml
CURL_OPTS='-H x-bookstore-preview:true' ./scripts/count-versions.sh http://bookstore.local:8080 20   # still v1

kubectl apply -f 07-header-routing/virtualservice-reviews-preview-cookie.yaml
CURL_OPTS='-b bookstore-preview=true' ./scripts/count-versions.sh http://bookstore.local:8080 20     # v3
```

Reset before chapter 8:

```sh
kubectl delete virtualservice reviews -n bookstore
kubectl -n bookstore delete pod tester --ignore-not-found
```
