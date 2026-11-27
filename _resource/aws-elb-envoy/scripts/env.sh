# shellcheck shell=bash
# Settings for the ELB for Envoy demo. Source this file in every terminal:
#
#   source scripts/env.sh
#
# ELB for Envoy launched in 14 Regions. ap-southeast-1 (Singapore) is the closest to Vietnam.

export AWS_REGION="${AWS_REGION:-ap-southeast-1}"
export NAME="envoy-demo"                       # proxy name, and prefix for the role and security group

# Read once from your account. Uses the default VPC.
export ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export VPC_ID="$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)"

# IDs created by the scripts are saved here, so later steps (and cleanup) can find them.
STATE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)/.state"
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
save() { echo "export $1=\"$2\"" >> "$STATE_FILE"; export "$1=$2"; }

echo "Region $AWS_REGION, account $ACCOUNT_ID, VPC $VPC_ID"
