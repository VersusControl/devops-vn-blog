# Back up and restore Argo CD

Example code for the article
[Back Up and Restore Argo CD](https://devopsvn.tech/kubernetes-backup-restore-argocd/).
Tested on Kind (Kubernetes 1.37) with Argo CD v3.6.3 and the `argocd` CLI.

| File | Purpose |
| --- | --- |
| `install-argocd.sh` | Installs a pinned Argo CD version (default `v3.6.3`). |
| `demo-state.yaml` | A repository credential (fake token), a project, and the guestbook application. |
| `backup-cronjob.yaml` | A nightly in-cluster `argocd admin export` to a PVC, with a read-only Role. |
| `reset-admin-password.sh` | Sets a new admin password after a restore. |

```sh
./install-argocd.sh
kubectl apply -f demo-state.yaml

argocd admin export -n argocd > argocd-backup.yaml       # back up
kubectl delete namespace argocd                           # the "disaster"
./install-argocd.sh                                       # reinstall the same version
argocd admin import -n argocd - < argocd-backup.yaml      # restore

kubectl apply -f backup-cronjob.yaml                      # automate it
kubectl -n argocd create job --from=cronjob/argocd-backup argocd-backup-manual
```

The backup file contains credentials. Store it encrypted, and never commit it.
