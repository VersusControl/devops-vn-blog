# Chapter 6: Release a New Version with Istio: Subsets and Weighted Routing

Article: https://devopsvn.tech/kubernetes-service-mesh-06-subsets-and-weighted-routing/

Starting state: Book Store at http://bookstore.local:8080 (`./scripts/bootstrap.sh 06`).

| File | Purpose |
| --- | --- |
| `destinationrule-reviews.yaml` | Subsets v1, v2, v3 of `reviews`, selected by the `version` label. |
| `virtualservice-reviews-v1.yaml` | All `reviews` traffic to v1. |
| `virtualservice-reviews-90-10.yaml` | Canary: 90% v1, 10% v3. |
| `virtualservice-reviews-50-50.yaml` | 50% v1, 50% v3. |
| `virtualservice-reviews-v3.yaml` | All traffic to v3. |

```sh
export PATH="$PWD/bin:$PATH"

# Wrong order: VirtualService before DestinationRule -> 503 NC
kubectl apply -f 06-traffic-shifting/virtualservice-reviews-v1.yaml
./scripts/count-versions.sh http://bookstore.local:8080 10
istioctl analyze -n bookstore

# Right order
kubectl apply -f 06-traffic-shifting/destinationrule-reviews.yaml
./scripts/count-versions.sh http://bookstore.local:8080 20

# Canary
for step in 90-10 50-50 v3; do
  kubectl apply -f 06-traffic-shifting/virtualservice-reviews-$step.yaml
  ./scripts/count-versions.sh http://bookstore.local:8080 100
done
```

Reset before chapter 7 (keep the DestinationRule):

```sh
kubectl delete -f 06-traffic-shifting/virtualservice-reviews-90-10.yaml
kubectl delete namespace outside --ignore-not-found
```
