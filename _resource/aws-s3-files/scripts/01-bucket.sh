#!/usr/bin/env bash
# Step 1: a general purpose bucket with versioning (S3 Files requires it) and some data.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

if [[ "$AWS_REGION" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "$BUCKET"
else
  aws s3api create-bucket --bucket "$BUCKET" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# A few objects so the file system has something to show.
mkdir -p /tmp/s3files-sample/reports
echo "id,title,stars" > /tmp/s3files-sample/reports/ratings.csv
echo "0,The Comedy of Errors,5" >> /tmp/s3files-sample/reports/ratings.csv
echo "Shared notes for the team" > /tmp/s3files-sample/README.txt
aws s3 cp --recursive /tmp/s3files-sample "s3://$BUCKET/"
aws s3 ls --recursive "s3://$BUCKET/"
