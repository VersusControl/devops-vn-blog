# Chapter 15: Deploy Istio in Your Environment: Helm, Revisions, and Canary Upgrades

Article: https://devopsvn.tech/kubernetes-service-mesh-15-deploy-istio-in-your-environment/

Starting state: a new cluster with Book Store and no Istio (`./scripts/bootstrap.sh 15`).
If image pulls are slow, run `./scripts/preload-images.sh` after the cluster exists.

| File | Purpose |
| --- | --- |
| `istiod-values.yaml` | istiod chart values: 2-3 replicas, access logs, smaller sidecar requests. |
| `gateway-values.yaml` | gateway chart values: NodePort 30080/30443 for Kind, 2-3 replicas, PDB. |
| `gateway.yaml` | Chapter 3's Gateway with selector `istio: ingress` (the Helm gateway's label). |

The charts come from the release archives (`.istio/istio-<version>/manifests/charts`).

```sh
export PATH="$PWD/bin:$PATH"
ISTIO_VERSION=1.31.4 ./cluster/install-istio.sh download

# Install 1.31.4 as revision 1-31, tag "prod"
C1=.istio/istio-1.31.4/manifests/charts
helm install istio-base $C1/base -n istio-system --create-namespace --set defaultRevision="" --wait
helm install istiod-1-31 $C1/istio-control/istio-discovery -n istio-system \
  --set revision=1-31 -f 15-production/istiod-values.yaml --wait --timeout 10m
istioctl tag set prod --revision 1-31
istioctl tag set default --revision 1-31     # validation for objects without a revision label
kubectl create namespace istio-ingress
kubectl label namespace istio-ingress istio.io/rev=prod
helm install istio-ingress $C1/gateway -n istio-ingress -f 15-production/gateway-values.yaml --wait --timeout 10m
kubectl label namespace bookstore istio.io/rev=prod
kubectl -n bookstore rollout restart deploy && ./scripts/wait-for-app.sh
kubectl apply -f 15-production/gateway.yaml -f 03-gateway-virtualservice/virtualservice.yaml
istioctl proxy-status --revision 1-31

# Canary upgrade to 1.32.0
C2=.istio/istio-1.32.0/manifests/charts
helm upgrade istio-base $C2/base -n istio-system --set defaultRevision="" --wait
helm install istiod-1-32 $C2/istio-control/istio-discovery -n istio-system \
  --set revision=1-32 -f 15-production/istiod-values.yaml --wait --timeout 10m
istioctl tag set prod --revision 1-32 --overwrite
istioctl tag set default --revision 1-32 --overwrite
kubectl -n bookstore rollout restart deploy && ./scripts/wait-for-app.sh
helm upgrade istio-ingress $C2/gateway -n istio-ingress -f 15-production/gateway-values.yaml --wait
istioctl proxy-status --revision 1-32

# Rollback = move the tag back and restart; when done, remove the old revision
helm uninstall istiod-1-31 -n istio-system
```
