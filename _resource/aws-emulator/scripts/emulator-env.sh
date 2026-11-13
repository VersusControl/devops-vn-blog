# Point the AWS CLI and AWS SDKs in the current shell at AWS Emulator.
# Source this file; do not execute it:
#
#   source scripts/emulator-env.sh
#
# Uses port 9297 unless EMULATOR_PORT is set.

EMULATOR_PORT="${EMULATOR_PORT:-9297}"
EMULATOR_DIR="$HOME/.aws/emulator/$EMULATOR_PORT"

# Remove anything that could supply real AWS credentials. Environment variables
# win over the credentials file, and the emulator rejects real keys anyway.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_BEARER_TOKEN_BEDROCK

export AWS_ENDPOINT_URL="https://127.0.0.1:${EMULATOR_PORT}"
export AWS_SHARED_CREDENTIALS_FILE="$EMULATOR_DIR/emulator_credentials"
export AWS_CONFIG_FILE="$EMULATOR_DIR/config"
export AWS_CA_BUNDLE="$EMULATOR_DIR/ca.pem"
export AWS_EC2_METADATA_DISABLED=true
export AWS_DISABLE_HOST_PREFIX_INJECTION=true
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

# The Node.js SDK does not read AWS_CA_BUNDLE. (The Rust and .NET SDKs need
# SSL_CERT_FILE instead; it is not set here because it replaces the trusted
# certificates for every program in the shell, including pip and curl.)
export NODE_EXTRA_CA_CERTS="$AWS_CA_BUNDLE"

echo "AWS CLI and SDKs now point at $AWS_ENDPOINT_URL"
