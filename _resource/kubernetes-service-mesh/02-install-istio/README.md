# Chapter 2: Install Istio on Kind and Join the Mesh

Article: https://devopsvn.tech/kubernetes-service-mesh-02-install-istio-and-join-the-mesh/

Starting state: Book Store running without Istio (`./scripts/bootstrap.sh 02`).

The install files live in `cluster/` because every later chapter uses them:

| File | Purpose |
| --- | --- |
| `cluster/install-istio.sh` | Downloads Istio 1.32.0 from GitHub, checks its SHA-256, links `istioctl` into `./bin`, installs. |
| `cluster/istio-install.yaml` | IstioOperator: `default` profile, access logs, NodePort ingress gateway (30080/30443), egress gateway. |
| `cluster/addons.sh` | Prometheus and Kiali from the same release (`grafana jaeger` in chapter 13). |

```sh
./cluster/install-istio.sh download
export PATH="$PWD/bin:$PATH"
istioctl version --remote=false

./cluster/install-istio.sh
kubectl -n istio-system get pods,svc
istioctl version

# Join the mesh: label, then restart (existing Pods are never injected)
kubectl label namespace bookstore istio-injection=enabled
istioctl analyze -n bookstore          # IST0103: pod is missing the Istio proxy
kubectl -n bookstore rollout restart deploy
./scripts/wait-for-app.sh
kubectl -n bookstore get pods          # 2/2
istioctl analyze -n bookstore

# Traffic capture rules and access logs
kubectl -n bookstore logs deploy/productpage-v1 -c istio-init \
  | grep -E 'REDIRECT --to-ports|-m owner --uid-owner 1337 -j RETURN' | sort -u
kubectl -n bookstore port-forward svc/productpage 9000:9080     # terminal 2
./scripts/count-versions.sh http://localhost:9000 30
kubectl -n bookstore logs deploy/productpage-v1 -c istio-proxy --tail=1

# Proxies and Kiali
istioctl proxy-status
./cluster/addons.sh
istioctl dashboard kiali
```

Starting state of chapter 3: `./scripts/bootstrap.sh 03`.
