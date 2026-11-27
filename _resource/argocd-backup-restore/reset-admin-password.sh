#!/usr/bin/env bash
# After an import, the admin password is the one from the backup, not the new install's
# argocd-initial-admin-secret. If nobody knows the old one, set a new one.
#   ./reset-admin-password.sh 'new-password'
set -euo pipefail
HASH="$(argocd account bcrypt --password "$1")"
kubectl -n argocd patch secret argocd-secret \
  -p "{\"stringData\":{\"admin.password\":\"$HASH\",\"admin.passwordMtime\":\"$(date -u +%FT%TZ)\"}}"
