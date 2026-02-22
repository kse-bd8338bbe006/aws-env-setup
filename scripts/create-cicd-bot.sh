#!/bin/bash

# Script to create CI/CD bot user with all required permissions.
# This user is managed outside of Terraform to avoid destroying
# its own credentials during `terraform destroy`.

set -euo pipefail

# Configuration
USER_NAME="cicd-bot"
REGION="eu-central-1"
TF_STATE_BUCKET="cicd-security-tf-state-1"
TF_STATE_KEY="tf-state-setup"
TF_LOCK_TABLE="cicd-security-tf-state-lock"

# Clean up temp files on exit
TMPDIR_POLICIES=$(mktemp -d)
trap 'rm -rf "$TMPDIR_POLICIES"' EXIT

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "Error: AWS CLI is not configured or credentials are invalid"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo "Using AWS account: $ACCOUNT_ID"

# Check if user already exists
if aws iam get-user --user-name "$USER_NAME" &>/dev/null; then
    echo "User $USER_NAME already exists"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing user..."

        # Delete access keys
        ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
        for key in $ACCESS_KEYS; do
            echo "  Deleting access key: $key"
            aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$key"
        done

        # Detach managed policies
        ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USER_NAME" --query 'AttachedPolicies[].PolicyArn' --output text)
        for policy in $ATTACHED_POLICIES; do
            echo "  Detaching policy: $policy"
            aws iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$policy"
        done

        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-user-policies --user-name "$USER_NAME" --query 'PolicyNames[]' --output text)
        for policy in $INLINE_POLICIES; do
            echo "  Deleting inline policy: $policy"
            aws iam delete-user-policy --user-name "$USER_NAME" --policy-name "$policy"
        done

        aws iam delete-user --user-name "$USER_NAME"
        echo "User deleted"

        # Clean up custom policies
        for policy_name in "${USER_NAME}-tf-s3" "${USER_NAME}-tf-dynamodb"; do
            policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"
            if aws iam get-policy --policy-arn "$policy_arn" &>/dev/null; then
                echo "  Deleting policy: $policy_name"
                aws iam delete-policy --policy-arn "$policy_arn"
            fi
        done
    else
        echo "Exiting without changes"
        exit 1
    fi
fi

# Create user
echo "Creating IAM user: $USER_NAME"
aws iam create-user \
    --user-name "$USER_NAME" \
    --tags Key=Project,Value=ci-cd-security-course \
           Key=ManagedBy,Value=aws-cli

# Attach AdministratorAccess
echo "Attaching AdministratorAccess policy"
aws iam attach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"

# Create S3 backend policy
echo "Creating S3 backend policy"
cat > "$TMPDIR_POLICIES/s3-policy.json" <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": ["arn:aws:s3:::${TF_STATE_BUCKET}"]
        },
        {
            "Effect": "Allow",
            "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
            "Resource": ["arn:aws:s3:::${TF_STATE_BUCKET}/${TF_STATE_KEY}"]
        }
    ]
}
EOF

S3_POLICY_ARN=$(aws iam create-policy \
    --policy-name "${USER_NAME}-tf-s3" \
    --description "Allow user to use S3 for TF backend" \
    --policy-document "file://$TMPDIR_POLICIES/s3-policy.json" \
    --query 'Policy.Arn' --output text)

aws iam attach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "$S3_POLICY_ARN"

# Create DynamoDB backend policy
echo "Creating DynamoDB backend policy"
cat > "$TMPDIR_POLICIES/dynamodb-policy.json" <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:DescribeTable",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem"
            ],
            "Resource": ["arn:aws:dynamodb:*:*:table/${TF_LOCK_TABLE}"]
        }
    ]
}
EOF

DYNAMO_POLICY_ARN=$(aws iam create-policy \
    --policy-name "${USER_NAME}-tf-dynamodb" \
    --description "Allow user to use DynamoDB for TF state locking" \
    --policy-document "file://$TMPDIR_POLICIES/dynamodb-policy.json" \
    --query 'Policy.Arn' --output text)

aws iam attach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "$DYNAMO_POLICY_ARN"

# Create access key
echo "Creating access key"
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$USER_NAME" --output json)

ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')

echo ""
echo "CI/CD Bot setup complete!"
echo "========================="
echo "User Name:         $USER_NAME"
echo "Access Key ID:     $ACCESS_KEY_ID"
echo "Secret Access Key: $SECRET_ACCESS_KEY"
echo ""
echo "Add these to your GitHub repository secrets:"
echo "  AWS_ACCESS_KEY_ID:     $ACCESS_KEY_ID"
echo "  AWS_SECRET_ACCESS_KEY: $SECRET_ACCESS_KEY"
echo "  AWS_REGION:            $REGION"
