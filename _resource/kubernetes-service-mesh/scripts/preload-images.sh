#!/usr/bin/env bash
# Pull the series' images once on your machine and copy them into every Kind node.
#
#   ./scripts/preload-images.sh            # all images
#   ./scripts/preload-images.sh bookinfo   # only the Book Store images
#
# Use it when image pulls inside the cluster are slow (registry.istio.io can take minutes
# per image), or before deleting and re-creating the cluster many times. Docker keeps the
# images, so later runs only copy them, which takes seconds per image.
set -euo pipefail

bookinfo=(
  registry.istio.io/release/examples-bookinfo-productpage-v1:1.20.3
  registry.istio.io/release/examples-bookinfo-details-v1:1.20.3
  registry.istio.io/release/examples-bookinfo-reviews-v1:1.20.3
  registry.istio.io/release/examples-bookinfo-reviews-v2:1.20.3
  registry.istio.io/release/examples-bookinfo-reviews-v3:1.20.3
  registry.istio.io/release/examples-bookinfo-ratings-v1:1.20.3
)
others=(
  docker.io/istio/proxyv2:1.32.0
  docker.io/istio/pilot:1.32.0
  docker.io/istio/proxyv2:1.31.4      # chapter 15's starting version
  docker.io/istio/pilot:1.31.4
  docker.io/curlimages/curl:8.16.0
  docker.io/mccutchen/go-httpbin:v2.15.0
  docker.io/fortio/fortio:1.69.5
  docker.io/library/python:3.13-alpine
)

images=("${bookinfo[@]}")
[[ "${1:-all}" == "bookinfo" ]] || images+=("${others[@]}")

if ! kind get clusters 2>/dev/null | grep -qx mesh; then
  echo "The Kind cluster 'mesh' doesn't exist. Create it first." >&2
  exit 1
fi

for image in "${images[@]}"; do
  docker image inspect "$image" >/dev/null 2>&1 || docker pull -q "$image"
  kind load docker-image "$image" --name mesh
done
