#!/usr/bin/env bash
# Step 2: two subnets in different Availability Zones and a security group.
# The default VPC has one default subnet per AZ and an internet gateway, which an
# internet-facing proxy needs.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

read -r SUBNET_1 SUBNET_2 < <(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
  --query 'Subnets[0:2].SubnetId' --output text)
save SUBNET_1 "$SUBNET_1"
save SUBNET_2 "$SUBNET_2"

# Allow port 80 from your own IP address only.
MY_IP="$(curl -s https://checkip.amazonaws.com)"
SG_ID="$(aws ec2 create-security-group --group-name "$NAME-proxy-sg" \
  --description "ELB for Envoy demo proxy" --vpc-id "$VPC_ID" --query GroupId --output text)"
save SG_ID "$SG_ID"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 80 --cidr "$MY_IP/32" --query 'Return' --output text

# The network part of create-proxy, written to a file to keep the command short.
cat > network.json <<JSON
{
  "ipConfiguration": {
    "ipAddressingConfiguration": {
      "ipv4Addressability": "internet-facing",
      "ipv6Addressability": "off"
    }
  },
  "vpcConfiguration": {
    "subnets": [
      { "subnetId": "$SUBNET_1" },
      { "subnetId": "$SUBNET_2" }
    ],
    "securityGroups": [
      { "securityGroupId": "$SG_ID" }
    ]
  }
}
JSON
echo "Subnets $SUBNET_1 $SUBNET_2, security group $SG_ID (port 80 from $MY_IP)"
