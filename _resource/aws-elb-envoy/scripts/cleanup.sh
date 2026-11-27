#!/usr/bin/env bash
# Delete the proxy, the security group, the proxy role, and the log group.
# Safe to run again if a step failed.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

if [[ -n "${PROXY_ARN:-}" ]]; then
  aws elb-proxy delete-proxy --proxy-identifier "$PROXY_ARN" >/dev/null 2>&1 || true
  echo "Waiting for the proxy to be deleted..."
  until ! aws elb-proxy get-proxy --proxy-identifier "$PROXY_ARN" >/dev/null 2>&1; do sleep 15; done
fi

# The proxy's network interfaces can take a few minutes to go away after deletion.
if [[ -n "${SG_ID:-}" ]]; then
  for i in $(seq 1 20); do
    if aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null; then echo "Deleted $SG_ID"; break; fi
    [[ $i -eq 20 ]] && { echo "Security group $SG_ID is still in use; run cleanup again later."; exit 1; }
    sleep 30
  done
fi

aws iam delete-role-policy --role-name "$NAME-proxy-role" --policy-name elb-proxy-logs 2>/dev/null || true
aws iam delete-role --role-name "$NAME-proxy-role" 2>/dev/null || true
aws logs delete-log-group --log-group-name "/aws/elb-proxy/$NAME" 2>/dev/null || true

rm -f .state network.json
echo "Cleanup done."
