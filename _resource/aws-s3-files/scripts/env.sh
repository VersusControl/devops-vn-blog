# Settings for the S3 Files demo. Source this file in every terminal:
#
#   source scripts/env.sh
#
# Change BUCKET to a globally unique name. Everything else can stay as it is.

export AWS_REGION="${AWS_REGION:-us-east-1}"
export BUCKET="${BUCKET:-s3files-demo-CHANGE-ME}"
export NAME="s3files-demo"                     # prefix for roles, security groups, the instance

# Read once from your account. Uses the default VPC and its first subnet.
export ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export VPC_ID="$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)"
export SUBNET_ID="$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" \
  Name=default-for-az,Values=true --query 'Subnets[0].SubnetId' --output text)"

# IDs created by the scripts are saved here, so later steps (and cleanup) can find them.
STATE_FILE="$(dirname "${BASH_SOURCE[0]:-$0}")/../.state"
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
save() { echo "export $1=\"$2\"" >> "$STATE_FILE"; export "$1=$2"; }

echo "Region $AWS_REGION, account $ACCOUNT_ID, bucket $BUCKET, VPC $VPC_ID, subnet $SUBNET_ID"
