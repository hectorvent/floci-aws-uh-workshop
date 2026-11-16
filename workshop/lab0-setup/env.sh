# Fallback only. The labs use: eval "$(floci aws env)"
# Use this when the floci CLI isn't installed: source lab0-setup/env.sh
# Fake credentials. They only work against Floci, never against a real AWS account.
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Make sure no real profile sneaks in.
unset AWS_PROFILE AWS_SESSION_TOKEN

echo "AWS CLI now points at Floci ($AWS_ENDPOINT_URL) with fake credentials."
