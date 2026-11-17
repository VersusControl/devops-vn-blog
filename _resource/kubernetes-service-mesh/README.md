# Kubernetes Advanced: Service Mesh

Code for the [Kubernetes Advanced: Service Mesh](https://devopsvn.tech/kubernetes-service-mesh-series/)
series on DevOps VN. The series teaches Istio by running it on a local Kind cluster with
**Book Store**, an app built from Istio's Bookinfo sample images with our own manifests.

Run every command from this folder (`_resource/kubernetes-service-mesh`).

## Tested with

| Tool | Version |
| --- | --- |
| Kind | v0.33.0 (node image `kindest/node:v1.37.0`) |
| kubectl | v1.31 or later |
| Istio | 1.32.0 (from chapter 2); 1.31.4 → 1.32.0 upgrade in chapter 15 |
| Gateway API CRDs | v1.6.1 (chapter 14) |
| Helm | 3.15 (chapter 15) |
| Docker | 8 GB memory recommended, 6 GB minimum |

## Layout

| Path | Purpose |
| --- | --- |
| `cluster/kind-config.yaml` | The `mesh` cluster: 1 control plane, 2 workers, ports 8080/8443/9080 on `127.0.0.1`. |
| `cluster/install-istio.sh` | Downloads Istio 1.32.0 (SHA-256 checked), links `istioctl` into `./bin`, installs with `cluster/istio-install.yaml`. |
| `cluster/addons.sh` | Installs Prometheus and Kiali (and Grafana, Jaeger on request) from the same Istio release. |
| `app/` | Book Store manifests: productpage, details, reviews v1/v2/v3, ratings. Apply with `kubectl apply -k app`. |
| `scripts/preflight.sh` | Checks Docker memory, free ports, and tools before you start. |
| `scripts/wait-for-app.sh` | Waits for each Deployment and names the one that is stuck. |
| `scripts/count-versions.sh` | Sends N requests and counts which reviews version answered. |
| `scripts/preload-images.sh` | Pulls the series' images once and copies them into the Kind nodes (for slow registries). |
| `scripts/bootstrap.sh NN` | Deletes the `mesh` cluster and rebuilds the starting state of chapter NN. |
| `NN-<topic>/` | Files that belong to one chapter. |

## Start

```sh
./scripts/preflight.sh
kind create cluster --config cluster/kind-config.yaml
kubectl apply -k app
./scripts/wait-for-app.sh
```

From chapter 2 on, put the series' `istioctl` first on your PATH in every terminal:

```sh
export PATH="$PWD/bin:$PATH"
```

If the cluster gets into a state you don't understand, start again from any chapter:

```sh
./scripts/bootstrap.sh 01
```

## Delete everything

```sh
kind delete cluster --name mesh
```
