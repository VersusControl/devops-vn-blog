# Chapter 9: Circuit Breaking and Outlier Detection with Istio

Article: https://devopsvn.tech/kubernetes-service-mesh-09-circuit-breaking-and-outlier-detection/

Starting state: the `reviews` DestinationRule from chapter 6, no other routing objects
(`./scripts/bootstrap.sh 09`).

| File | Purpose |
| --- | --- |
| `ratings-v-faulty.yaml` | A ratings build that returns 503 for half of its requests (its `/health` stays OK). |
| `fortio.yaml` | Fortio 1.69.5 load generator inside the mesh. |
| `virtualservice-reviews-v2.yaml` | Pin reviews to v2, which calls ratings every time. |
| `destinationrule-ratings-outlier.yaml` | Eject a Pod after 2 consecutive 5xx for 30 s. |
| `destinationrule-ratings-pool.yaml` | Tiny connection pool limits (circuit breaker) + outlier detection. |
| `destinationrule-ratings-strict.yaml` | Too strict: 1 error, 100% ejection (break it). |

```sh
export PATH="$PWD/bin:$PATH"

kubectl apply -f 09-circuit-breaking/ratings-v-faulty.yaml -f 09-circuit-breaking/fortio.yaml \
  -f 09-circuit-breaking/virtualservice-reviews-v2.yaml
./scripts/count-versions.sh http://bookstore.local:8080 40

kubectl apply -f 09-circuit-breaking/destinationrule-ratings-outlier.yaml
./scripts/count-versions.sh http://bookstore.local:8080 40
istioctl proxy-config endpoint deploy/reviews-v2 -n bookstore \
  --cluster "outbound|9080||ratings.bookstore.svc.cluster.local"

kubectl delete -f 09-circuit-breaking/ratings-v-faulty.yaml
kubectl apply -f 09-circuit-breaking/destinationrule-ratings-pool.yaml
kubectl -n bookstore exec deploy/fortio -c fortio -- \
  fortio load -c 4 -qps 0 -n 40 -loglevel Warning http://ratings:9080/ratings/0
```

Reset before chapter 10:

```sh
kubectl -n bookstore scale deploy/ratings-v1 --replicas=1
kubectl delete -f 09-circuit-breaking/ratings-v-faulty.yaml -f 09-circuit-breaking/fortio.yaml \
  -f 09-circuit-breaking/virtualservice-reviews-v2.yaml --ignore-not-found
kubectl delete destinationrule ratings -n bookstore
```
