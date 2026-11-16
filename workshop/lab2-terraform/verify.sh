#!/usr/bin/env bash
# Uploads a file to the bucket and waits for the Lambda to log that it processed it.
set -euo pipefail

export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

case "$AWS_ENDPOINT_URL" in
  http://localhost*|http://127.0.0.1*|http://localhost.floci.io*) ;;
  *) echo "Refusing to run: AWS_ENDPOINT_URL ($AWS_ENDPOINT_URL) is not a local Floci endpoint." >&2; exit 2 ;;
esac

key="verify-$(date +%s).txt"
echo "uploaded by verify.sh at $(date)" | aws s3 cp - "s3://uploads/$key"
echo "Uploaded s3://uploads/$key, waiting for the Lambda..."

for _ in $(seq 1 30); do
  logs=$(aws logs tail /aws/lambda/process-upload --since 10m 2>/dev/null || true)
  if grep -q "PROCESSED s3://uploads/$key" <<<"$logs"; then
    grep "PROCESSED s3://uploads/$key" <<<"$logs"
    echo "✅ Pipeline works"
    exit 0
  fi
  sleep 2
done

echo "❌ The Lambda did not process s3://uploads/$key within 60 seconds."
echo "Recent Lambda logs:"
aws logs tail /aws/lambda/process-upload --since 10m 2>&1 | tail -20 || true
exit 1
