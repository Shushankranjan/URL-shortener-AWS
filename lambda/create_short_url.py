# create_short_url.py
# Triggered by: POST /shorten
# Input body:  { "long_url": "https://some-long-url.com" }
# Output:      { "short_url": "https://execute-api.../k9xZ2aB1" }

import json
import os
import secrets
import string
import time

import boto3
from botocore.exceptions import ClientError

# boto3.resource is the high-level DynamoDB interface — cleaner than low-level client
dynamodb = boto3.resource("dynamodb", region_name=os.environ["AWS_REGION"])

# TABLE_NAME is injected as an environment variable by Terraform — never hardcode table names
table = dynamodb.Table(os.environ["TABLE_NAME"])

# Character set for short codes: a-z, A-Z, 0-9 = 62 characters
# 62^8 = ~218 trillion combinations — collision chance is negligible
ALPHABET = string.ascii_letters + string.digits
CODE_LENGTH = 8


def generate_short_code() -> str:
    # secrets.choice is cryptographically random — stronger than random.choice
    # Important: predictable codes would let attackers enumerate your links
    return "".join(secrets.choice(ALPHABET) for _ in range(CODE_LENGTH))


def lambda_handler(event, context):
    # API Gateway wraps the HTTP body as a string inside event["body"]
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Request body must be valid JSON"})

    long_url = body.get("long_url", "").strip()

    # Basic validation — must be non-empty and start with http
    if not long_url:
        return _response(400, {"error": "long_url is required"})
    if not long_url.startswith(("http://", "https://")):
        return _response(400, {"error": "long_url must start with http:// or https://"})

    # Collision loop: generate a code, attempt to write it, retry if it already exists
    # In practice this loop almost never runs more than once with 8-char codes
    for _ in range(5):  # max 5 attempts before giving up
        short_code = generate_short_code()

        try:
            # ConditionExpression: only write if short_code does NOT already exist
            # This is an atomic check-and-write — no race conditions
            table.put_item(
                Item={
                    "short_code": short_code,
                    "long_url":   long_url,
                    "created_at": int(time.time()),              # Unix timestamp
                    "expires_at": int(time.time()) + 60 * 60 * 24 * 90,  # 90 days TTL
                },
                ConditionExpression="attribute_not_exists(short_code)",
            )

            # Build the short URL using the API Gateway base URL injected by Terraform
            base_url = os.environ["BASE_URL"].rstrip("/")
            short_url = f"{base_url}/{short_code}"

            return _response(201, {
                "short_url":  short_url,
                "short_code": short_code,
                "long_url":   long_url,
                "expires_in": "90 days",
            })

        except ClientError as e:
            error_code = e.response["Error"]["Code"]
            if error_code == "ConditionalCheckFailedException":
                # Code collision — extremely rare, just retry
                continue
            # Any other DynamoDB error is unexpected — surface it
            return _response(500, {"error": "Database error", "detail": str(e)})

    # Exhausted all 5 attempts — should never happen in practice
    return _response(500, {"error": "Could not generate a unique short code. Try again."})


def _response(status_code: int, body: dict) -> dict:
    # Every Lambda behind API Gateway must return this exact structure
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            # CORS header: allows browsers to call this API from any origin
            # Tighten this to a specific domain in production
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
