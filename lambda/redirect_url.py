# redirect_url.py
# Triggered by: GET /{short_code}
# Behaviour:   Looks up the code, returns HTTP 301 redirect to the long URL
#              Returns 404 if the code doesn't exist or has expired

import json
import os

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb", region_name=os.environ["AWS_REGION"])
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    # API Gateway injects path parameters into event["pathParameters"]
    path_params = event.get("pathParameters") or {}
    short_code = path_params.get("short_code", "").strip()

    if not short_code:
        return _response(400, {"error": "short_code is required"})

    try:
        # get_item is the fastest DynamoDB operation — O(1) single key lookup
        result = table.get_item(
            Key={"short_code": short_code}
        )
    except ClientError as e:
        return _response(500, {"error": "Database error", "detail": str(e)})

    item = result.get("Item")

    if not item:
        # Code doesn't exist or TTL has expired and DynamoDB already deleted it
        return _response(404, {"error": f"Short code '{short_code}' not found"})

    long_url = item["long_url"]

    # HTTP 301 = Permanent Redirect
    # The browser follows the Location header automatically
    # API Gateway passes this Location header through to the caller
    return {
        "statusCode": 301,
        "headers": {
            "Location": long_url,
            "Access-Control-Allow-Origin": "*",
        },
        "body": "",  # body is empty for redirects
    }


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
