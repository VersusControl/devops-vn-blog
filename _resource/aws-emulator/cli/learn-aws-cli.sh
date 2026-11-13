#!/usr/bin/env bash
# Practise AWS CLI commands against AWS Emulator: STS, S3, DynamoDB, and SQS.
# Start the emulator first (scripts/start-emulator.sh), then run:
#
#   ./cli/learn-aws-cli.sh
#
# Every command goes to the emulator. Nothing is created in a real AWS account.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/emulator-env.sh
source "$here/../scripts/emulator-env.sh"

step() { printf '\n== %s\n' "$*"; }
expect_error() { if "$@"; then echo "expected an error, got success" >&2; exit 1; fi; }

step "Who am I? (must be account 000000000000)"
account="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$account" != "000000000000" ]]; then
  echo "Requests are going to account $account, not the emulator. Stop." >&2
  exit 1
fi
aws sts get-caller-identity

step "S3: create a bucket, upload, list, and read an object"
aws s3 mb s3://devopsvn-lab
tmp="$(mktemp)"
echo "hello from the emulator" > "$tmp"
aws s3 cp "$tmp" s3://devopsvn-lab/notes/hello.txt
rm -f "$tmp"
aws s3 ls s3://devopsvn-lab --recursive
aws s3 cp s3://devopsvn-lab/notes/hello.txt -

step "S3: an invalid bucket name fails the same way as on AWS"
expect_error aws s3 mb s3://Bad_Bucket

step "DynamoDB: create a table and wait for it"
aws dynamodb create-table --table-name orders \
  --attribute-definitions AttributeName=order_id,AttributeType=S \
  --key-schema AttributeName=order_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --query 'TableDescription.{Name:TableName,Status:TableStatus}'
aws dynamodb wait table-exists --table-name orders

step "DynamoDB: write and read an item"
aws dynamodb put-item --table-name orders \
  --item '{"order_id":{"S":"ord-001"},"customer":{"S":"alice"},"total":{"N":"42"}}'
aws dynamodb get-item --table-name orders --key '{"order_id":{"S":"ord-001"}}'

step "DynamoDB: a conditional write rejects a duplicate order"
expect_error aws dynamodb put-item --table-name orders \
  --item '{"order_id":{"S":"ord-001"},"customer":{"S":"bob"},"total":{"N":"1"}}' \
  --condition-expression 'attribute_not_exists(order_id)'

step "SQS: create a queue, send a message, and receive it"
queue_url="$(aws sqs create-queue --queue-name order-events --query QueueUrl --output text)"
echo "$queue_url"
aws sqs send-message --queue-url "$queue_url" --message-body '{"order_id":"ord-001"}'
aws sqs receive-message --queue-url "$queue_url" --wait-time-seconds 1 --query 'Messages[].Body'

step "Done. Restart the emulator to start again with empty state."
