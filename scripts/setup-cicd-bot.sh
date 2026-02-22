#!/usr/bin/env bash
set -euo pipefail

# Creates the cicd-bot IAM user with AdministratorAccess + TF backend permissions.
# Run once before the first CI/CD deploy. Requires admin AWS credentials.
#
# Usage: ./scripts/setup-cicd-bot.sh

USER_NAME="cicd-bot"
REGION="eu-central-1"
TF_STATE_BUCKET="cicd-security-tf-state-1"
TF_STATE_KEY="tf-state-setup"
TF_LOCK_TABLE="cicd-security-tf-state-lock"

echo "==> Creating IAM user: $USER_NAME"
if aws iam get-user --user-name "$USER_NAME" &>/dev/null; then
  echo "    User already exists, skipping creation"
else
  aws iam create-user --user-name "$USER_NAME"
fi

echo "==> Attaching AdministratorAccess policy"
aws iam attach-user-policy \
  --user-name "$USER_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"

echo "==> Creating S3 backend policy"
S3_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${TF_STATE_BUCKET}"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::${TF_STATE_BUCKET}/${TF_STATE_KEY}"
    }
  ]
}
EOF
)

if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/${USER_NAME}-tf-s3" &>/dev/null; then
  echo "    S3 policy already exists, skipping"
else
  aws iam create-policy \
    --policy-name "${USER_NAME}-tf-s3" \
    --description "Allow user to use S3 for TF backend" \
    --policy-document "$S3_POLICY"
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam attach-user-policy \
  --user-name "$USER_NAME" \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${USER_NAME}-tf-s3"

echo "==> Creating DynamoDB backend policy"
DDB_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:*:*:table/${TF_LOCK_TABLE}"
    }
  ]
}
EOF
)

if aws iam get-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${USER_NAME}-tf-dynamodb" &>/dev/null; then
  echo "    DynamoDB policy already exists, skipping"
else
  aws iam create-policy \
    --policy-name "${USER_NAME}-tf-dynamodb" \
    --description "Allow user to use DynamoDB for TF state locking" \
    --policy-document "$DDB_POLICY"
fi

aws iam attach-user-policy \
  --user-name "$USER_NAME" \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${USER_NAME}-tf-dynamodb"

echo "==> Creating access key"
EXISTING_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query "AccessKeyMetadata[].AccessKeyId" --output text)
if [ -n "$EXISTING_KEYS" ]; then
  echo "    Access key already exists: $EXISTING_KEYS"
  echo "    To create a new key, first delete the existing one:"
  echo "    aws iam delete-access-key --user-name $USER_NAME --access-key-id $EXISTING_KEYS"
else
  CREDS=$(aws iam create-access-key --user-name "$USER_NAME" --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
  ACCESS_KEY_ID=$(echo "$CREDS" | awk '{print $1}')
  SECRET_KEY=$(echo "$CREDS" | awk '{print $2}')

  echo ""
  echo "============================================"
  echo "  ACCESS_KEY_ID:     $ACCESS_KEY_ID"
  echo "  SECRET_ACCESS_KEY: $SECRET_KEY"
  echo "============================================"
  echo ""
  echo "Save these now! The secret won't be shown again."
  echo "Add to GitHub: Settings > Environments > PROD > Secrets"
fi

echo ""
echo "Done."
