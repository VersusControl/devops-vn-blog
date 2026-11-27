#!/usr/bin/env bash
# Step 3: create the proxy with envoy/config.yaml and wait until it is active.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

# Safe to run again: if a proxy was already created, wait for it instead of creating another.
if [[ -z "${PROXY_ARN:-}" ]]; then
  PROXY_ARN="$(aws elb-proxy create-proxy \
    --name "$NAME" \
    --type envoy \
    --proxy-version 1.40 \
    --role-arn "$ROLE_ARN" \
    --network-configuration file://network.json \
    --configuration 'configurationFile={configurationBytes@=fileb://envoy/config.yaml}' \
    --query arn --output text)"
  save PROXY_ARN "$PROXY_ARN"
else
  echo "Proxy already created, waiting for it: $PROXY_ARN"
fi

# Poll instead of `aws elb-proxy wait proxy-active`, so a failure stops the loop with its reason.
while true; do
  STATUS="$(aws elb-proxy get-proxy --proxy-identifier "$PROXY_ARN" --query status.code --output text)"
  echo "$(date +%T) $STATUS"
  case "$STATUS" in
    active) break ;;
    action-required)
      aws elb-proxy get-proxy --proxy-identifier "$PROXY_ARN" --query status.reasons
      echo "Fix the reason above, then run this script again. The proxy clears this state on its own."
      exit 1 ;;
    create-failed)
      aws elb-proxy get-proxy --proxy-identifier "$PROXY_ARN" --query status.reasons
      echo "Creation failed. Run scripts/cleanup.sh, fix the reason above, and start again from step 1."
      exit 1 ;;
  esac
  sleep 15
done

save DNS_NAME "$(aws elb-proxy get-proxy --proxy-identifier "$PROXY_ARN" --query dnsName --output text)"
echo "Proxy is active: http://$DNS_NAME/"
