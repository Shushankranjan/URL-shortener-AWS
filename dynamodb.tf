# dynamodb.tf
# The "notebook" that stores every short_code → long_url mapping.
#
# Key design decisions:
#   - PAY_PER_REQUEST: no capacity planning needed, $0 when idle
#   - TTL enabled: expired links auto-delete, no cleanup Lambda needed
#   - PITR enabled: 35-day restore window, free insurance

resource "aws_dynamodb_table" "url_shortener" {
  name         = "${var.project_name}-urls" # resolves to "url-shortener-urls"
  billing_mode = "PAY_PER_REQUEST"

  # hash_key = partition key = the field DynamoDB uses to locate your item instantly
  # Every read/write will say "find the item where short_code = X"
  hash_key = "short_code"

  # Only key attributes are declared here — DynamoDB is schemaless for everything else
  # long_url, created_at, expires_at are added freely at write time by Lambda
  attribute {
    name = "short_code"
    type = "S" # S = String
  }

  # TTL: when Lambda writes an item it can set expires_at = (now + 90 days as Unix timestamp)
  # DynamoDB checks this field and auto-deletes the item after that time
  # Items without expires_at set are kept forever
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  # Point-in-time recovery: restore table to any second in the last 35 days
  # Like Time Machine for your database — always worth enabling
  point_in_time_recovery {
    enabled = true
  }
}
