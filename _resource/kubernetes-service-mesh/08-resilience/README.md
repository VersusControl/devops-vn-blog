# Chapter 8: Timeouts, Retries, and Fault Injection with Istio

Article: https://devopsvn.tech/kubernetes-service-mesh-08-timeouts-retries-fault-injection/

Starting state: the `reviews` DestinationRule from chapter 6, no VirtualServices
(`./scripts/bootstrap.sh 08`).

| File | Purpose |
| --- | --- |
| `ratings-v-delayed.yaml` | A ratings build that answers half of its requests after 7 s. |
| `destinationrule-ratings.yaml` | Subsets `v1` and `v-delayed`. |
| `virtualservice-reviews-v2.yaml` | Pin reviews to v2 (waits up to 10 s for ratings). |
| `virtualservice-ratings-delayed.yaml` | All ratings traffic to the slow build, no timeout. |
| `virtualservice-ratings-timeout.yaml` | `timeout: 2s`. |
| `virtualservice-ratings-retries.yaml` | `timeout: 2s` + 2 retries with `perTryTimeout: 500ms`. |
| `virtualservice-ratings-fault.yaml` | 7 s delay for `end-user: qa-team` only (ratings back on v1). |
| `virtualservice-ratings-abort.yaml` | 50% HTTP 503 for `end-user: qa-team` only. |

```sh
export PATH="$PWD/bin:$PATH"

kubectl apply -f 08-resilience/ratings-v-delayed.yaml -f 08-resilience/destinationrule-ratings.yaml
kubectl -n bookstore rollout status deploy/ratings-v-delayed
kubectl apply -f 08-resilience/virtualservice-reviews-v2.yaml -f 08-resilience/virtualservice-ratings-delayed.yaml
./scripts/count-versions.sh http://bookstore.local:8080 20      # 500s after ~6 s

kubectl apply -f 08-resilience/virtualservice-ratings-timeout.yaml
./scripts/count-versions.sh http://bookstore.local:8080 20      # no 500s; ratings-error after 2 s

kubectl apply -f 08-resilience/virtualservice-ratings-retries.yaml
./scripts/count-versions.sh http://bookstore.local:8080 40      # mostly stars

curl -s --resolve bookstore.local:8080:127.0.0.1 -c /tmp/qa-cookies.txt \
  -d 'username=qa-team&passwd=anything' -o /dev/null http://bookstore.local:8080/login
kubectl apply -f 08-resilience/virtualservice-ratings-fault.yaml
CURL_OPTS="-b /tmp/qa-cookies.txt" ./scripts/count-versions.sh http://bookstore.local:8080 6
kubectl apply -f 08-resilience/virtualservice-ratings-abort.yaml
CURL_OPTS="-b /tmp/qa-cookies.txt" ./scripts/count-versions.sh http://bookstore.local:8080 20
```

Reset before chapter 9:

```sh
kubectl delete virtualservice ratings reviews -n bookstore
kubectl delete -f 08-resilience/destinationrule-ratings.yaml -f 08-resilience/ratings-v-delayed.yaml
```
