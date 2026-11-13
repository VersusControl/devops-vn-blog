"""A small order service that uses DynamoDB, S3, and SQS.

The code has no emulator-specific settings. boto3 reads the endpoint, the
credentials, and the certificate from the environment, so the same code calls
AWS Emulator in tests and real AWS in production.
"""

import json
import uuid
from dataclasses import dataclass
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError


class DuplicateOrderError(Exception):
    """Raised when an order with the same ID already exists."""


@dataclass
class OrderService:
    table_name: str
    bucket: str
    queue_url: str

    def __post_init__(self):
        self._table = boto3.resource("dynamodb").Table(self.table_name)
        self._s3 = boto3.client("s3")
        self._sqs = boto3.client("sqs")

    def place_order(self, customer_id, items, order_id=None):
        """Save the order, store a receipt, and publish an order-placed event."""
        if not items:
            raise ValueError("an order needs at least one item")

        order_id = order_id or f"ord-{uuid.uuid4().hex[:12]}"
        total = sum(Decimal(str(i["price"])) * i["quantity"] for i in items)

        # The condition makes the write fail if the order ID is already used.
        try:
            self._table.put_item(
                Item={
                    "order_id": order_id,
                    "customer_id": customer_id,
                    "items": items,
                    "total": total,
                    "status": "PLACED",
                },
                ConditionExpression="attribute_not_exists(order_id)",
            )
        except ClientError as err:
            if err.response["Error"]["Code"] == "ConditionalCheckFailedException":
                raise DuplicateOrderError(order_id) from err
            raise

        receipt_key = f"receipts/{order_id}.json"
        self._s3.put_object(
            Bucket=self.bucket,
            Key=receipt_key,
            Body=json.dumps({"order_id": order_id, "total": str(total)}),
            ContentType="application/json",
        )

        self._sqs.send_message(
            QueueUrl=self.queue_url,
            MessageBody=json.dumps({"type": "order_placed", "order_id": order_id}),
        )
        return order_id

    def get_order(self, order_id):
        return self._table.get_item(Key={"order_id": order_id}).get("Item")
