#Requires -Version 5.1

<#
.SYNOPSIS
    Creates the cicd-bot IAM user with AdministratorAccess + TF backend permissions.
.DESCRIPTION
    Run once before the first CI/CD deploy. Requires admin AWS credentials.
.EXAMPLE
    .\scripts\setup-cicd-bot.ps1
#>

$ErrorActionPreference = "Stop"

$UserName       = "cicd-bot"
$Region         = "eu-central-1"
$TfStateBucket  = "cicd-security-tf-state-1"
$TfStateKey     = "tf-state-setup"
$TfLockTable    = "cicd-security-tf-state-lock"

Write-Host "==> Creating IAM user: $UserName"
try {
    aws iam get-user --user-name $UserName 2>$null | Out-Null
    Write-Host "    User already exists, skipping creation"
} catch {
    aws iam create-user --user-name $UserName
    if ($LASTEXITCODE -ne 0) { throw "Failed to create user" }
}

Write-Host "==> Attaching AdministratorAccess policy"
aws iam attach-user-policy `
    --user-name $UserName `
    --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
if ($LASTEXITCODE -ne 0) { throw "Failed to attach AdministratorAccess policy" }

Write-Host "==> Creating S3 backend policy"
$S3Policy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::$TfStateBucket"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::$TfStateBucket/$TfStateKey"
    }
  ]
}
"@

$AccountId = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) { throw "Failed to get account ID" }

$S3PolicyArn = "arn:aws:iam::${AccountId}:policy/${UserName}-tf-s3"
try {
    aws iam get-policy --policy-arn $S3PolicyArn 2>$null | Out-Null
    Write-Host "    S3 policy already exists, skipping"
} catch {
    $S3PolicyFile = [System.IO.Path]::GetTempFileName()
    $S3Policy | Out-File -Encoding utf8 -FilePath $S3PolicyFile
    aws iam create-policy `
        --policy-name "${UserName}-tf-s3" `
        --description "Allow user to use S3 for TF backend" `
        --policy-document "file://$S3PolicyFile"
    Remove-Item $S3PolicyFile -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) { throw "Failed to create S3 policy" }
}

aws iam attach-user-policy `
    --user-name $UserName `
    --policy-arn $S3PolicyArn
if ($LASTEXITCODE -ne 0) { throw "Failed to attach S3 policy" }

Write-Host "==> Creating DynamoDB backend policy"
$DdbPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:*:*:table/$TfLockTable"
    }
  ]
}
"@

$DdbPolicyArn = "arn:aws:iam::${AccountId}:policy/${UserName}-tf-dynamodb"
try {
    aws iam get-policy --policy-arn $DdbPolicyArn 2>$null | Out-Null
    Write-Host "    DynamoDB policy already exists, skipping"
} catch {
    $DdbPolicyFile = [System.IO.Path]::GetTempFileName()
    $DdbPolicy | Out-File -Encoding utf8 -FilePath $DdbPolicyFile
    aws iam create-policy `
        --policy-name "${UserName}-tf-dynamodb" `
        --description "Allow user to use DynamoDB for TF state locking" `
        --policy-document "file://$DdbPolicyFile"
    Remove-Item $DdbPolicyFile -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) { throw "Failed to create DynamoDB policy" }
}

aws iam attach-user-policy `
    --user-name $UserName `
    --policy-arn $DdbPolicyArn
if ($LASTEXITCODE -ne 0) { throw "Failed to attach DynamoDB policy" }

Write-Host "==> Creating access key"
$ExistingKeys = aws iam list-access-keys --user-name $UserName --query "AccessKeyMetadata[].AccessKeyId" --output text
if ($LASTEXITCODE -ne 0) { throw "Failed to list access keys" }

if ($ExistingKeys -and $ExistingKeys.Trim()) {
    Write-Host "    Access key already exists: $ExistingKeys"
    Write-Host "    To create a new key, first delete the existing one:"
    Write-Host "    aws iam delete-access-key --user-name $UserName --access-key-id $ExistingKeys"
} else {
    $CredsJson = aws iam create-access-key --user-name $UserName --query "AccessKey.[AccessKeyId,SecretAccessKey]" --output text
    if ($LASTEXITCODE -ne 0) { throw "Failed to create access key" }

    $Parts = $CredsJson -split "\s+"
    $AccessKeyId = $Parts[0]
    $SecretKey   = $Parts[1]

    Write-Host ""
    Write-Host "============================================"
    Write-Host "  ACCESS_KEY_ID:     $AccessKeyId"
    Write-Host "  SECRET_ACCESS_KEY: $SecretKey"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "Save these now! The secret won't be shown again."
    Write-Host "Add to GitHub: Settings > Environments > PROD > Secrets"
}

Write-Host ""
Write-Host "Done."
Write-Host ""
Write-Host "NOTE: Using long-lived IAM access keys is not the recommended approach nowadays."
Write-Host "The preferred method is to use GitHub OIDC (OpenID Connect) with AWS IAM"
Write-Host "roles, which eliminates the need for stored credentials entirely."
Write-Host ""
Write-Host "With OIDC, GitHub Actions requests a short-lived token from AWS on each"
Write-Host "workflow run. No secrets to rotate, no keys to leak. AWS trusts GitHub"
Write-Host "as an identity provider and issues temporary credentials scoped to the"
Write-Host "specific repository, branch, and environment."
Write-Host ""
Write-Host "To migrate to OIDC:"
Write-Host "  1. Create an OIDC identity provider in AWS IAM for token.actions.githubusercontent.com"
Write-Host "  2. Create an IAM role with a trust policy that allows your repo to assume it"
Write-Host "  3. Replace aws-actions/configure-aws-credentials secrets with:"
Write-Host "       role-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-terraform"
Write-Host "       role-session-name: github-actions"
Write-Host ""
Write-Host "See: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services"
