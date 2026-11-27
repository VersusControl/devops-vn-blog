#!/usr/bin/env bash
# Step 1: the proxy role. ELB for Envoy assumes it to write Envoy logs to CloudWatch Logs.
# You need one per account and Region; every proxy can reuse it.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

aws iam create-role --role-name "$NAME-proxy-role" \
  --assume-role-policy-document file://iam/proxy-trust-policy.json \
  --query Role.Arn --output text
aws iam put-role-policy --role-name "$NAME-proxy-role" --policy-name elb-proxy-logs \
  --policy-document file://iam/proxy-logs-policy.json
save ROLE_ARN "arn:aws:iam::$ACCOUNT_ID:role/$NAME-proxy-role"

# A new role takes a few seconds before other services can assume it.
sleep 10
echo "Proxy role ready: $ROLE_ARN"
