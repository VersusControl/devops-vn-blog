---
layout: post
title: "Back Up and Restore Argo CD"
subtitle: "What Argo CD stores, how to export it with one command, restore it after the namespace is deleted, and run the backup every night."
date: 2026-11-27
author: Quan Huynh
tags: [kubernetes, argocd, gitops, backup]
image: /assets/images/posts/kubernetes-backup-restore-argocd/cover.svg
---

Someone runs `kubectl delete namespace argocd` on the wrong cluster. Your applications keep
running, but Argo CD is gone. So is everything you set up in it: the credentials for your
private Git repositories, the projects that decide which team can deploy where, the
Applications themselves, and the RBAC rules. Rebuilding all of that by hand takes hours, and
it's easy to miss something.

*Argo CD* is a GitOps tool. It keeps the workloads in your cluster in sync with the manifests in
Git. Git holds your application manifests, but not Argo CD's own configuration. That
configuration is what you need to back up.

By the end of this post you will be able to:

- list what Argo CD stores, and what it doesn't;
- back it up with `argocd admin export` and restore it with `argocd admin import`;
- deal with two things that catch people out: secrets in the backup file, and the admin
  password after a restore;
- run the backup automatically every night.

> **Code for this post:** [_resource/argocd-backup-restore](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/argocd-backup-restore).
> I ran every step on Kind with Kubernetes 1.37, Argo CD v3.6.3, and the `argocd` CLI, including
> deleting the `argocd` namespace and restoring it. The outputs below come from that run.

## What Argo CD Stores

Argo CD keeps its state as ordinary Kubernetes objects in its own namespace, usually `argocd`:

| What | Stored as | Lost if the namespace is deleted? |
| --- | --- | --- |
| Applications (what to deploy, from where, to where) | `Application` objects | Yes |
| Projects (which repos and namespaces a team may use) | `AppProject` objects | Yes |
| Repository and cluster credentials | Secrets with the `argocd.argoproj.io/secret-type` label | Yes |
| Settings, RBAC rules, known SSH hosts, TLS certificates | `argocd-cm`, `argocd-rbac-cm`, and other ConfigMaps | Yes |
| Admin password and signing key | The `argocd-secret` Secret | Yes |
| Your application manifests | Git | No |
| The running workloads | Their own namespaces | No |

Because of the last two rows, losing Argo CD doesn't take your apps down. But everything in the
first five rows is gone, and `argocd admin export` is the command that saves it.

![Argo CD state in the argocd namespace, all saved by argocd admin export and all lost if the namespace is deleted: Applications, AppProjects, repository credentials, the argocd-cm and argocd-rbac-cm ConfigMaps, and argocd-secret. Outside the namespace, Git with the application manifests and the guestbook namespace with its running Pods are not in the backup and not lost.](/assets/images/posts/kubernetes-backup-restore-argocd/what-to-back-up.svg)

## Step 1: Set Up Something Worth Backing Up

Install Argo CD and give it some state: a repository credential, a project, and an application
from Argo CD's public example repository.

```sh
git clone https://github.com/VersusControl/devops-vn-blog.git
cd devops-vn-blog/_resource/argocd-backup-restore
./install-argocd.sh
kubectl apply -f demo-state.yaml
```

`install-argocd.sh` installs a pinned version, v3.6.3 by default. The pin matters in Step 4,
where you restore into the same version. `demo-state.yaml` creates three objects:

- a repository credential with a fake token, for a placeholder private repository;
- a project, `team-a`;
- an application, `guestbook`, which deploys from Argo CD's public example repository.

After about a minute, check that the application synced and its Deployment is up:

```sh
kubectl -n argocd get applications
kubectl -n guestbook get deploy
```

```text
NAME        SYNC STATUS   HEALTH STATUS
guestbook   Synced        Healthy

NAME           READY   UP-TO-DATE   AVAILABLE   AGE
guestbook-ui   1/1     1            1           25s
```

I hit two errors while building this setup. `demo-state.yaml` already avoids both, but you may
see them if you write your own:

- Use real credentials, or none. I first attached the fake token to the public example
  repository. GitHub rejected it ("Invalid username or token") even though the repository is
  public, and the application couldn't sync.
- `CreateNamespace=true` needs project permission. The sync failed with
  `resource :Namespace is not permitted in project team-a` until the project allowed the
  `Namespace` kind in `clusterResourceWhitelist`.

## Step 2: Back It Up

Before the backup, I changed two settings. After the restore, they show whether settings come
back too, not only Applications:

```sh
kubectl -n argocd patch cm argocd-cm --type merge \
  -p '{"data":{"timeout.reconciliation":"120s"}}'
kubectl -n argocd patch cm argocd-rbac-cm --type merge \
  -p '{"data":{"policy.csv":"g, team-a-devs, role:readonly\n"}}'
```

The `argocd admin export` command reads Argo CD's objects through the Kubernetes API and writes
them as YAML. It uses your current kubeconfig context, so check that the context points at the
right cluster, then run:

```sh
argocd admin export -n argocd > argocd-backup.yaml
```

The file is a list of ordinary Kubernetes objects. Counted by kind, the file from my run held:

```text
   1 kind: Application
   2 kind: AppProject
   4 kind: ConfigMap
   2 kind: Secret
```

That's the `guestbook` application, two projects (`team-a` and the built-in `default`), four
ConfigMaps (`argocd-cm`, `argocd-rbac-cm`, `argocd-ssh-known-hosts-cm`, and
`argocd-tls-certs-cm`), and two Secrets: the repository credential and `argocd-secret`. The
whole file was 19,774 bytes.

### Treat the Backup File as a Secret

This is the repository Secret inside the file, shortened:

```text
data:
  password: <redacted>
  url: aHR0cHM6Ly9naXRodWIuY29tL2V4YW1wbGUtb3JnL3ByaXZhdGUtY2hhcnRzLmdpdA==
  username: ZGVwbG95LWJvdA==
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {...,"stringData":{"password":"ghp_example_not_a_real_token",...}}
```

The token appears twice. In `data` it's base64, which anyone can decode; base64 is an encoding,
not encryption. In the `last-applied-configuration` annotation, which `kubectl apply` adds, it's
in plain text. The file also holds `argocd-secret`, with the admin password hash and the key that
signs login sessions.

So handle the backup like a password file. Store it encrypted (for example, in an encrypted S3
bucket with tight access), never commit it to Git, and don't paste it into a ticket.

## Step 3: Simulate the Disaster

Delete the whole namespace, then check the application's Pods:

```sh
kubectl delete namespace argocd
kubectl -n guestbook get pods
```

```text
namespace "argocd" deleted
NAME                            READY   STATUS    RESTARTS   AGE
guestbook-ui-6d476cf4df-crzht   1/1     Running   0          66s
```

Argo CD is gone, and the application is still running. But nothing reconciles it now. A change
pushed to Git won't reach the cluster until Argo CD is back.

> **Warning:** The `guestbook` Application has no `resources-finalizer.argocd.argoproj.io`
> finalizer. With that finalizer, deleting the Application tells Argo CD to delete everything
> it deployed. I didn't test deleting the namespace with that finalizer in place, so check your
> Applications' finalizers before you rely on this step.

## Step 4: Restore

Reinstall Argo CD at the same version the backup came from, then import the file:

```sh
./install-argocd.sh v3.6.3
argocd admin import -n argocd - < argocd-backup.yaml
```

```text
import process started argocd
/ConfigMap argocd-cm in namespace argocd updated
/ConfigMap argocd-rbac-cm in namespace argocd updated
/Secret argocd-secret in namespace argocd updated
/Secret repo-private-charts in namespace argocd created
argoproj.io/AppProject team-a in namespace argocd created
argoproj.io/Application guestbook in namespace argocd created
Import process completed successfully in namespace argocd at 2026-11-27T23:44:08+07:00, duration: 80.461791ms
```

The fresh install had already created the default ConfigMaps and `argocd-secret`, so the import
updated those with the backed-up values. It created the repository Secret, the `team-a` project,
and the application. A few seconds later, the application and the `team-a` project were back (`default` comes with every install):

```sh
kubectl -n argocd get applications,appprojects
```

```text
NAME                                SYNC STATUS   HEALTH STATUS
application.argoproj.io/guestbook   Synced        Healthy

NAME                             AGE
appproject.argoproj.io/default   36s
appproject.argoproj.io/team-a    5s
```

The two settings from Step 2 came back too: `timeout.reconciliation: 120s` in `argocd-cm` and
the RBAC line `g, team-a-devs, role:readonly` in `argocd-rbac-cm`.

The guestbook Pod was still `guestbook-ui-6d476cf4df-crzht`, the same Pod as before the
deletion, with no restart. The restored Argo CD found the running workload already matched Git,
so it didn't redeploy anything.

## After the Restore, the Admin Password Is the Old One

A fresh install writes a random admin password to `argocd-initial-admin-secret`. After the
import, that password no longer works:

```text
rpc error: code = Unauthenticated desc = Invalid username or password
```

The import replaced `argocd-secret` with the copy from the backup, and that copy holds the old
password hash. The old `argocd-initial-admin-secret` isn't in the export. If nobody saved the old
password, set a new one:

```sh
./reset-admin-password.sh 'a-new-strong-password'
```

The script hashes the password with `argocd account bcrypt` and patches the hash into
`argocd-secret`. After that, `argocd login` worked, and `argocd app list` showed `guestbook` as
`Synced` and `Healthy`.

Many teams log in through SSO and keep the local admin account disabled. For them, the admin
password matters mostly for break-glass access.

## Step 5: Back Up Every Night

A manual export only helps if someone remembers to run it. `backup-cronjob.yaml` runs the export
inside the cluster every night at 02:00 (in the time zone of the cluster's controller manager):

```yaml
containers:
- name: export
  image: quay.io/argoproj/argocd:v3.6.3   # same version as your Argo CD
  command: ["sh", "-c"]
  args:
  - |
    set -e
    FILE="/backup/argocd-$(date +%Y%m%d-%H%M%S).yaml"
    argocd admin export -n argocd > "$FILE"
    echo "wrote $FILE ($(wc -c < "$FILE") bytes)"
    ls -1t /backup/argocd-*.yaml | tail -n +8 | xargs -r rm --   # keep the newest 7
```

This is the container part of the CronJob. The full file also creates the ServiceAccount, Role,
RoleBinding, and a PersistentVolumeClaim mounted at `/backup`. The script names each file with a
timestamp, logs its size, and deletes all but the newest seven.

The job runs as its own ServiceAccount. Its Role can only `get` and `list` ConfigMaps, Secrets,
Applications, AppProjects, and ApplicationSets in the `argocd` namespace, which is all the export
reads. To test the job without waiting for 02:00, start one run by hand:

```sh
kubectl apply -f backup-cronjob.yaml
kubectl -n argocd create job --from=cronjob/argocd-backup argocd-backup-manual
kubectl -n argocd logs job/argocd-backup-manual
```

```text
wrote /backup/argocd-20261127-164458.yaml (19774 bytes)
```

The file is 19,774 bytes, the same size as the manual export from Step 2. The timestamp in the name is in UTC,
the container's time zone.

> **Warning:** This CronJob writes to a PersistentVolumeClaim in the same cluster. If you lose
> the cluster, you lose the backups with it. In production, add a step that copies the file to
> object storage in another account or Region, such as an encrypted S3 bucket. Give that step
> credentials from IRSA or EKS Pod Identity rather than a stored access key. I didn't test that
> upload step for this post.

## Before You Rely on It

- Restore into the same Argo CD version the backup came from. The export holds Argo CD's own
  objects and settings. Restore first, then upgrade the normal way.
- Practice the restore. Run Steps 3 and 4 on a test cluster once a quarter. Until you've
  restored a backup, you don't know that it works.
- Check what's not in the export. By default it reads only the `argocd` namespace. If you use
  Applications or ApplicationSets in other namespaces (the "apps in any namespace" feature),
  add `--application-namespaces` and `--applicationset-namespaces`, or set them in
  `argocd-cmd-params-cm`. Your SSO provider's own settings need their own plan.
- Consider keeping Argo CD's configuration in Git. If Applications, projects, and settings are
  declared in a Git repository (an "app of apps"), rebuilding Argo CD is mostly re-applying that
  repository. You still need the export for the secrets you keep out of Git.

## Summary

- Losing Argo CD doesn't stop your apps, but it loses Applications, projects, repository
  credentials, settings, and RBAC.
- `argocd admin export -n argocd > argocd-backup.yaml` saves all of it in one file;
  `argocd admin import -n argocd - < argocd-backup.yaml` restores it into a fresh install of the same
  version.
- After a restore, Argo CD took over the running app without restarting it. The admin
  password, though, is the one from the backup. Keep it, or reset it with
  `argocd account bcrypt`.
- The backup contains credentials in readable form. Encrypt it, keep it out of Git, and copy it
  off the cluster.
- A CronJob with a read-only Role runs the export every night.

Next step: export your real Argo CD, import the file into a test cluster with
`argocd admin import`, and check that every Application comes back `Synced`.

## Resources

- [`argocd admin export`](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_admin_export/) and [`argocd admin import`](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_admin_import/)
- [Disaster recovery](https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/), Argo CD operator manual
- [Declarative setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/): managing Argo CD's own configuration as YAML
