#!/usr/bin/env bash
# Step 3: the S3 file system, two security groups, and one mount target.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

# wait_for <get-file-system|get-mount-target> <id option> <id>
wait_for() {
  local status
  while true; do
    status="$(aws s3files "$1" "$2" "$3" --query status --output text)"
    echo "  $3: $status"
    [[ "$status" == "available" ]] && return 0
    [[ "$status" == "error" ]] && { aws s3files "$1" "$2" "$3"; return 1; }
    sleep 15
  done
}

FS_ID="$(aws s3files create-file-system \
  --bucket "arn:aws:s3:::$BUCKET" \
  --role-arn "$FS_ROLE_ARN" \
  --tags key=Name,value="$NAME" \
  --query fileSystemId --output text)"
save FS_ID "$FS_ID"
echo "File system $FS_ID created, waiting for it to become available"
wait_for get-file-system --file-system-id "$FS_ID"

# The instance's security group, and the mount target's group that accepts NFS (TCP 2049)
# only from the instance's group.
CLIENT_SG="$(aws ec2 create-security-group --group-name "$NAME-client" \
  --description "S3 Files demo client" --vpc-id "$VPC_ID" --query GroupId --output text)"
save CLIENT_SG "$CLIENT_SG"
MT_SG="$(aws ec2 create-security-group --group-name "$NAME-mount-target" \
  --description "S3 Files demo mount target" --vpc-id "$VPC_ID" --query GroupId --output text)"
save MT_SG "$MT_SG"
aws ec2 authorize-security-group-ingress --group-id "$MT_SG" \
  --protocol tcp --port 2049 --source-group "$CLIENT_SG" >/dev/null

MT_ID="$(aws s3files create-mount-target \
  --file-system-id "$FS_ID" \
  --subnet-id "$SUBNET_ID" \
  --security-groups "$MT_SG" \
  --query mountTargetId --output text)"
save MT_ID "$MT_ID"
echo "Mount target $MT_ID created in $SUBNET_ID, waiting (up to ~5 minutes)"
wait_for get-mount-target --mount-target-id "$MT_ID"
