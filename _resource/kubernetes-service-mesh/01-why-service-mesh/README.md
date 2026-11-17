# Chapter 1: What a Service Mesh Solves

Article: https://devopsvn.tech/kubernetes-service-mesh-01-what-a-service-mesh-solves/

Book Store on plain Kubernetes, with no Istio yet.

```sh
./scripts/preflight.sh
kind create cluster --config cluster/kind-config.yaml
kubectl apply -k app
./scripts/wait-for-app.sh

# Terminal 2
kubectl -n bookstore port-forward svc/productpage 9000:9080

# Terminal 1
./scripts/count-versions.sh http://localhost:9000 30
```

Experiments:

```sh
# A dependency that is down
kubectl -n bookstore scale deploy/ratings-v1 --replicas=0
kubectl -n bookstore scale deploy/ratings-v1 --replicas=1

# A new ratings build that is slow half the time
kubectl apply -f 01-why-service-mesh/ratings-v-delayed.yaml

# Any Pod can call any service
kubectl create namespace experiments
kubectl -n experiments run curl --image=docker.io/curlimages/curl:8.16.0 \
  --restart=Never --command -- sleep 3600
kubectl -n experiments wait --for=condition=Ready pod/curl --timeout=60s
kubectl -n experiments exec curl -- curl -s http://ratings.bookstore:9080/ratings/0
```

Reset before chapter 2 (keep the cluster):

```sh
kubectl delete -f 01-why-service-mesh/ratings-v-delayed.yaml
kubectl delete namespace experiments
```
