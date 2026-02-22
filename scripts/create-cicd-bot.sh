#!/bin/bash

# Script to create CI/CD bot user using AWS CLI
# Permissions will be applied through Terraform

set -e  # Exit on any error

# Configuration
USER_NAME="cicd-bot"
REGION="eu-central-1"

echo "🤖 Creating CI/CD bot user: $USER_NAME"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ Error: AWS CLI is not configured or credentials are invalid"
    echo "Please run 'aws configure' or set up your AWS credentials"
    exit 1
fi

echo "✅ AWS CLI is configured"

# Check if user already exists
if aws iam get-user --user-name "$USER_NAME" &>/dev/null; then
    echo "⚠️  User $USER_NAME already exists"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Deleting existing user..."
        
        # Delete access keys if they exist
        ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
        for key in $ACCESS_KEYS; do
            echo "🔑 Deleting access key: $key"
            aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$key"
        done
        
        # Detach all policies
        ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USER_NAME" --query 'AttachedPolicies[].PolicyArn' --output text)
        for policy in $ATTACHED_POLICIES; do
            echo "📋 Detaching policy: $policy"
            aws iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$policy"
        done
        
        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-user-policies --user-name "$USER_NAME" --query 'PolicyNames[]' --output text)
        for policy in $INLINE_POLICIES; do
            echo "📋 Deleting inline policy: $policy"
            aws iam delete-user-policy --user-name "$USER_NAME" --policy-name "$policy"
        done
        
        # Delete user
        aws iam delete-user --user-name "$USER_NAME"
        echo "✅ User deleted successfully"
    else
        echo "❌ Exiting without changes"
        exit 1
    fi
fi

# Create the user
echo "👤 Creating IAM user: $USER_NAME"
aws iam create-user \
    --user-name "$USER_NAME" \
    --tags Key=Project,Value=ci-cd-security-course \
           Key=Purpose,Value=CI-CD-automation \
           Key=ManagedBy,Value=aws-cli

echo "✅ User created successfully"

# Create access keys
echo "🔑 Creating access keys for $USER_NAME"
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$USER_NAME" --output json)

# Extract access key details
ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')

echo "✅ Access keys created successfully"

# Display the results
echo ""
echo "🎉 CI/CD Bot Setup Complete!"
echo "================================"
echo "User Name: $USER_NAME"
echo "Access Key ID: $ACCESS_KEY_ID"
echo "Secret Access Key: $SECRET_ACCESS_KEY"
echo ""
echo "⚠️  IMPORTANT SECURITY NOTES:"
echo "1. Save these credentials securely - the secret key cannot be retrieved again"
echo "2. Add these to your GitHub repository secrets:"
echo "   - AWS_ACCESS_KEY_ID: $ACCESS_KEY_ID"
echo "   - AWS_SECRET_ACCESS_KEY: $SECRET_ACCESS_KEY"
echo "   - AWS_REGION: $REGION"
echo "3. This user has NO permissions yet - apply permissions through Terraform"
echo "4. Never commit these credentials to your repository"
echo ""
echo "📝 Next steps:"
echo "1. Add credentials to GitHub repository secrets"
echo "2. Run 'terraform apply' to grant necessary permissions"
echo "3. Test the CI/CD pipeline"
echo ""
echo "🔗 GitHub Secrets URL: https://github.com/TorinKS/CICD-security-course/settings/secrets/actions"
