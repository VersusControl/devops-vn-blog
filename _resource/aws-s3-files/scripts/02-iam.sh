#!/usr/bin/env bash
# Step 2: two IAM roles.
#   1. ${NAME}-fs-role       : assumed by S3 Files to sync between the file system and the bucket
#   2. ${NAME}-client-role   : the EC2 instance's role, to mount the file system and read S3 directly
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

fill() { sed -e "s/ACCOUNT_ID/$ACCOUNT_ID/g" -e "s/REGION/$AWS_REGION/g" -e "s/BUCKET/$BUCKET/g" "$1"; }

# Role 1: S3 Files -> bucket
aws iam create-role --role-name "$NAME-fs-role" \
  --assume-role-policy-document "$(fill iam/s3files-trust-policy.json)" \
  --query Role.Arn --output text
aws iam put-role-policy --role-name "$NAME-fs-role" --policy-name s3files-bucket-access \
  --policy-document "$(fill iam/s3files-bucket-access-policy.json)"
save FS_ROLE_ARN "arn:aws:iam::$ACCOUNT_ID:role/$NAME-fs-role"

# Role 2: EC2 instance -> file system (+ direct S3 reads, + Session Manager instead of SSH)
aws iam create-role --role-name "$NAME-client-role" \
  --assume-role-policy-document file://iam/ec2-trust-policy.json \
  --query Role.Arn --output text
aws iam attach-role-policy --role-name "$NAME-client-role" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FilesClientFullAccess
aws iam attach-role-policy --role-name "$NAME-client-role" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam put-role-policy --role-name "$NAME-client-role" --policy-name s3-direct-read \
  --policy-document "$(fill iam/ec2-direct-read-policy.json)"
aws iam create-instance-profile --instance-profile-name "$NAME-client-profile" \
  --query InstanceProfile.Arn --output text
aws iam add-role-to-instance-profile --instance-profile-name "$NAME-client-profile" \
  --role-name "$NAME-client-role"
aws iam wait instance-profile-exists --instance-profile-name "$NAME-client-profile"

# New roles take a few seconds to be usable by other services.
sleep 10
echo "Roles ready: $FS_ROLE_ARN and $NAME-client-role"
