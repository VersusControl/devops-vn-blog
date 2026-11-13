import os
import uuid

import boto3
import pytest

EMULATOR_ACCOUNT = "000000000000"


def pytest_sessionstart(session):
    """Refuse to run if the tests would reach real AWS."""
    endpoint = os.environ.get("AWS_ENDPOINT_URL", "")
    if not endpoint.startswith("https://127.0.0.1:"):
        pytest.exit(
            "AWS_ENDPOINT_URL does not point at a local emulator. "
            "Run: source scripts/emulator-env.sh",
            returncode=2,
        )
    account = boto3.client("sts").get_caller_identity()["Account"]
    if account != EMULATOR_ACCOUNT:
        pytest.exit(f"Requests reach account {account}, not the emulator.", returncode=2)


@pytest.fixture
def infra():
    """Create a fresh table, bucket, and queue for each test.

    The emulator has no reset route, so unique names keep tests independent
    without restarting it.
    """
    suffix = uuid.uuid4().hex[:8]
    table_name = f"orders-{suffix}"
    bucket = f"receipts-{suffix}"

    dynamodb = boto3.client("dynamodb")
    dynamodb.create_table(
        TableName=table_name,
        AttributeDefinitions=[{"AttributeName": "order_id", "AttributeType": "S"}],
        KeySchema=[{"AttributeName": "order_id", "KeyType": "HASH"}],
        BillingMode="PAY_PER_REQUEST",
    )
    dynamodb.get_waiter("table_exists").wait(TableName=table_name)

    boto3.client("s3").create_bucket(Bucket=bucket)
    queue_url = boto3.client("sqs").create_queue(QueueName=f"order-events-{suffix}")["QueueUrl"]

    return {"table_name": table_name, "bucket": bucket, "queue_url": queue_url}
