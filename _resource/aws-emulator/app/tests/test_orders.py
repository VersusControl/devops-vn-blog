import json
import sys
from decimal import Decimal
from pathlib import Path

import boto3
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from orders import DuplicateOrderError, OrderService  # noqa: E402

ITEMS = [{"sku": "book-devops", "price": "19.50", "quantity": 2}]


@pytest.fixture
def service(infra):
    return OrderService(**infra)


def test_place_order_saves_order_receipt_and_event(service, infra):
    order_id = service.place_order("alice", ITEMS)

    order = service.get_order(order_id)
    assert order["status"] == "PLACED"
    # DynamoDB normalizes numbers: 39.00 is stored and returned as 39.
    assert order["total"] == Decimal("39")

    receipt = boto3.client("s3").get_object(
        Bucket=infra["bucket"], Key=f"receipts/{order_id}.json"
    )
    assert json.loads(receipt["Body"].read())["total"] == "39.00"

    messages = boto3.client("sqs").receive_message(
        QueueUrl=infra["queue_url"], WaitTimeSeconds=1
    )["Messages"]
    assert json.loads(messages[0]["Body"]) == {"type": "order_placed", "order_id": order_id}


def test_duplicate_order_is_rejected(service):
    service.place_order("alice", ITEMS, order_id="ord-fixed")

    with pytest.raises(DuplicateOrderError):
        service.place_order("bob", ITEMS, order_id="ord-fixed")

    # The first order is unchanged.
    assert service.get_order("ord-fixed")["customer_id"] == "alice"


def test_empty_order_is_rejected_before_any_aws_call(service):
    with pytest.raises(ValueError):
        service.place_order("alice", [])
