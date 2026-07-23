# ArgoCD Series — Code & Manifests

Ready-to-apply Kubernetes / ArgoCD manifests that accompany the
[ArgoCD series](https://devopsvn.tech/argocd-series/) on DevOps VN.

Each folder maps to a chapter of the series:

| Chapter | Folder | Topic |
|--------|--------|-------|
| 1 | `01-getting-started` | First ArgoCD `Application` for Book Info |
| 2 | `02-core-concepts` | Application, per-service apps, AppProject |
| 3 | `03-private-repo` | Connecting a private repo (Secret / ExternalSecret) |
| 5 | `05-with-helm` | Deploying Helm charts with ArgoCD |
| 6 | `06-kustomize` | Base + overlays with Kustomize |
| 7 | `07-resource-hooks` | PreSync / PostSync hooks and sync waves |
| 8 | `08-secret-management` | Sealed Secrets & External Secrets |
| 9 | `09-applicationset` | Generating Applications in bulk |
| 10 | `10-multi-cluster` | Deploying across many clusters |
| 11 | `11-sso-keycloak` | SSO with Keycloak (OIDC) + RBAC |

> These manifests reference example repositories and placeholder values
> (`<ACCOUNT_ID>`, `<token>`, cluster URLs, etc.). Replace them with your own
> before applying.

```bash
git clone https://github.com/VersusControl/devops-vn-blog.git
cd devops-vn-blog/_resource/argocd-series
```
