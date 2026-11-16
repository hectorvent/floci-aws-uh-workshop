#!/usr/bin/env bash
# Two isolated AWS accounts on one Floci: a 12-digit access key becomes the account ID.
set -euo pipefail

export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

for account in 111111111111 222222222222; do
  echo "=== Account $account"
  AWS_ACCESS_KEY_ID=$account aws sts get-caller-identity --query Account --output text
  AWS_ACCESS_KEY_ID=$account aws s3 mb s3://same-name
  echo "agent $account was here" | AWS_ACCESS_KEY_ID=$account aws s3 cp - s3://same-name/owner.txt
done

for account in 111111111111 222222222222; do
  echo "=== s3://same-name/owner.txt as seen by $account"
  AWS_ACCESS_KEY_ID=$account aws s3 cp s3://same-name/owner.txt -
done
