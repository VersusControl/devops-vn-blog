#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/images/covers

# name|source article URL
entries=(
  "argocd-getting-started|https://devopsvn.tech/kubernetes/argocd-getting-started"
  "cost-30m-requests|https://devopsvn.tech/devops/cost-compare-for-30-million-requests"
  "aws-without-account|https://devopsvn.tech/aws-practice/thuc-hanh-aws-ma-khong-can-tao-tai-khoan"
  "what-is-kubernetes|https://devopsvn.tech/kubernetes/kubernetes-la-gi"
  "install-docker-one-command|https://devopsvn.tech/devops/cai-dat-docker-len-linux-voi-mot-cau-lenh"
  "intro-azure|https://devopsvn.tech/azure/gioi-thieu-microsoft-azure"
  "become-devops-engineer|https://devopsvn.tech/devops/lam-the-nao-de-tro-thanh-devops-engineer"
  "infra-millions-aws-part0|https://devopsvn.tech/xay-dung-ha-tang-phuc-vu-hang-trieu-nguoi-dung-tren-aws/bai-0-chuan-bi"
  "microservices-on-k8s|https://devopsvn.tech/kubernetes-practice/trien-khai-he-thong-microservices-len-tren-kubernetes"
  "k8s-users-rbac|https://devopsvn.tech/kubernetes/tips/tao-va-phan-quyen-nguoi-dung-tren-kubernetes"
)

for e in "${entries[@]}"; do
  name="${e%%|*}"
  url="${e#*|}"
  img=$(curl -sL --max-time 25 "$url" | grep -oiE 'og:image" content="[^"]+"' | head -1 | sed -E 's/.*content="([^"]+)"/\1/')
  if [[ -z "$img" ]]; then
    echo "MISS  $name (no og:image)"
    continue
  fi
  ext="${img##*.}"; ext="${ext%%\?*}"
  [[ "$ext" =~ ^(png|jpg|jpeg|webp|gif)$ ]] || ext="png"
  curl -sL --max-time 40 "$img" -o "assets/images/covers/${name}.${ext}"
  echo "OK    ${name}.${ext}"
done
