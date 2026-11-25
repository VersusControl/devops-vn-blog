#!/usr/bin/env bash
# Step 4: an Amazon Linux 2023 instance in the same subnet as the mount target.
# No SSH key and no open port: connect with Session Manager.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

AMI_ID="$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)"

INSTANCE_ID="$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.small \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$CLIENT_SG" \
  --iam-instance-profile Name="$NAME-client-profile" \
  --user-data file://scripts/user-data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME}]" \
  --query 'Instances[0].InstanceId' --output text)"
save INSTANCE_ID "$INSTANCE_ID"
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
echo "Instance $INSTANCE_ID is ready. Connect with:"
echo "  aws ssm start-session --target $INSTANCE_ID"
echo "Then mount with:"
echo "  sudo mkdir -p /mnt/s3files && sudo mount -t s3files $FS_ID:/ /mnt/s3files"
