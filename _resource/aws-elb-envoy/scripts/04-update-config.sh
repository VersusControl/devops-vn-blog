#!/usr/bin/env bash
# Step 4: replace the configuration with envoy/config-v2.yaml (Lua API key check + local rate limit).
# Envoy hot-restarts; the old process drains connections for 60 seconds.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

UPDATE_ID="$(aws elb-proxy update-proxy-configuration \
  --proxy-identifier "$PROXY_ARN" \
  --configuration-file 'configurationBytes@=fileb://envoy/config-v2.yaml' \
  --query updateId --output text)"
echo "Update $UPDATE_ID submitted"

while true; do
  read -r VALIDATION PROPAGATION < <(aws elb-proxy get-proxy-update \
    --proxy-identifier "$PROXY_ARN" --update-identifier "$UPDATE_ID" \
    --query '[state.validationStatus, state.propagationStatus]' --output text)
  echo "$(date +%T) validation=$VALIDATION propagation=$PROPAGATION"
  case "$PROPAGATION" in
    complete) break ;;
    failed|cancelled|skipped)
      aws elb-proxy get-proxy-update --proxy-identifier "$PROXY_ARN" \
        --update-identifier "$UPDATE_ID" --query state.reasons
      exit 1 ;;
  esac
  sleep 10
done
echo "Version 2 is live on http://$DNS_NAME/"
