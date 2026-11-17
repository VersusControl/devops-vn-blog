#!/usr/bin/env bash
# Download Istio, check the archive's SHA-256, and install Istio into the current cluster.
#
#   ./cluster/install-istio.sh            # download (once) and install
#   ./cluster/install-istio.sh download   # download only
#
# The release is unpacked into .istio/istio-<version>/ and istioctl is linked into ./bin,
# so the series always uses the same istioctl, whatever version is on your PATH.
# ISTIO_VERSION=1.31.4 ./cluster/install-istio.sh download  fetches another release
# (its Helm charts are in .istio/istio-1.31.4/manifests/charts) without changing ./bin.
set -euo pipefail
cd "$(dirname "$0")/.."

SERIES_VERSION=1.32.0
ISTIO_VERSION="${ISTIO_VERSION:-$SERIES_VERSION}"
action="${1:-install}"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)               platform=osx-arm64 ;;
  Darwin-x86_64)              platform=osx ;;
  Linux-x86_64)               platform=linux-amd64 ;;
  Linux-aarch64|Linux-arm64)  platform=linux-arm64 ;;
  *) echo "Unsupported platform: $(uname -s) $(uname -m)" >&2; exit 1 ;;
esac

dir=".istio/istio-$ISTIO_VERSION"
if [[ ! -x "$dir/bin/istioctl" ]]; then
  archive="istio-$ISTIO_VERSION-$platform.tar.gz"
  url="https://github.com/istio/istio/releases/download/$ISTIO_VERSION/$archive"
  mkdir -p .istio
  echo "Downloading $url"
  curl -fsSL -o ".istio/$archive" "$url"
  curl -fsSL -o ".istio/$archive.sha256" "$url.sha256"

  # The .sha256 file holds "<hash> <file name>". Compare the hash directly.
  expected="$(awk '{print $1}' ".istio/$archive.sha256")"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum ".istio/$archive" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 ".istio/$archive" | awk '{print $1}')"
  fi
  if [[ "$expected" != "$actual" ]]; then
    echo "SHA-256 mismatch for $archive: expected $expected, got $actual" >&2
    rm -f ".istio/$archive"
    exit 1
  fi
  echo "SHA-256 ok"
  tar -xzf ".istio/$archive" -C .istio
  rm -f ".istio/$archive" ".istio/$archive.sha256"
fi

# ./bin/istioctl always points at the series version. Other versions (chapter 15 downloads
# 1.31.4 for its charts) stay in .istio/ without replacing it.
if [[ "$ISTIO_VERSION" == "$SERIES_VERSION" ]]; then
  mkdir -p bin
  ln -sf "../$dir/bin/istioctl" bin/istioctl
  echo "istioctl $ISTIO_VERSION is at ./bin/istioctl"
else
  echo "Istio $ISTIO_VERSION is in $dir"
fi

[[ "$action" == "download" ]] && exit 0

if [[ "$(kubectl config current-context)" != "kind-mesh" ]]; then
  echo "kubectl points at '$(kubectl config current-context)', not kind-mesh. Run: kubectl config use-context kind-mesh" >&2
  exit 1
fi

bin/istioctl install -f cluster/istio-install.yaml -y
