# Kubernetes DNS: the ndots search list

Example code for the article
[Why DNS Lookups Are Slow in Kubernetes, and How to Fix Them](https://devopsvn.tech/kubernetes-reduce-dns-resolution-time/).
Tested on Kind (Kubernetes 1.37) with the default CoreDNS.

| File | Purpose |
| --- | --- |
| `pods.yaml` | Two Pods: one with the default `ndots:5`, one with `ndots:2`. |
| `enable-coredns-log.sh` | Turns on the CoreDNS `log` plugin so you can see every query. Test clusters only. |
| `count-queries.sh` | Resolves one name from a Pod and lists the queries CoreDNS received. |
| `bench.py` | Average time for 300 lookups of one name from inside a Pod. |

```sh
./enable-coredns-log.sh
kubectl apply -f pods.yaml
kubectl wait --for=condition=Ready pod/app-default pod/app-ndots2

./count-queries.sh app-default api.github.com     # 8 queries, 6 NXDOMAIN
./count-queries.sh app-default api.github.com.    # 2 queries
./count-queries.sh app-ndots2  api.github.com     # 2 queries

kubectl cp bench.py app-default:/tmp/bench.py
kubectl exec app-default -- python /tmp/bench.py api.github.com
kubectl exec app-default -- python /tmp/bench.py api.github.com.

kubectl delete -f pods.yaml
```
