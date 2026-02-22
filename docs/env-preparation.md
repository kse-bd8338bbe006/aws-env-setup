## Lab environment preparation

### Objectives of this lab

The objectives of this lab are to have a fully configured AWS environment for infrastructure management:

- Learn how to create a free-tier AWS account
- Become familiar with one of the popular cloud providers
- Be able to create a VPC (public and private subnets)
- Configure networking components (NAT gateway, internet gateway, route tables)
- Create a basic account configuration that can be easily set up using Terraform and torn down to minimize costs
- Make the Terraform setup production-ready (encrypted S3 bucket for Terraform state, DynamoDB for state locking, etc.)

We are going to create only the base part of the setup manually. All other AWS resources will be managed by Terraform.

### Create AWS free-tier account

Go to the [AWS Management Console](https://aws.amazon.com/console/) and click "Create Account".

![alt text](image-12.png)

Prerequisites:
- Email (use popular email providers like gmail.com or outlook.com)
- Bank card (use a virtual card with a low spending limit)
- Phone number (for mobile verification)

At the time of my registration, I was provided with 100 USD in credits and additional bonuses for completing activities:

![alt text](image-13.png)

### Region

Use the `eu-central-1` region.

### Enable access to billing

By default, only the root account can see billing and cost data. Regular IAM users — even those with `AdministratorAccess` — cannot view billing pages unless the root account explicitly enables it. Without this, your IAM users won't be able to see costs, set up budgets, or monitor spending.

To enable it:

1. Sign in as the **root user** (this setting can only be changed by the root account)
2. Navigate to **Billing Console → Account** (or use the link below)
3. Scroll down to **"IAM User and Role Access to Billing Information"**
4. Click **Edit**, check **"Activate IAM Access"**, and click **Update**

https://us-east-1.console.aws.amazon.com/billing/home?region=eu-central-1#/account

![alt text](image-14.png)

### Create a regular user

The root user has unrestricted access to everything in your AWS account. AWS best practice is to use it only for tasks that require it (like enabling billing access above) and create a regular IAM user for day-to-day work. This way you can rotate credentials and revoke access if needed, while keeping the root account locked away.

> **Note:** AWS also offers **IAM Identity Center** — a modern solution with SSO and external identity provider support. However, it may require creating an AWS Organization, which complicates a free-tier setup. We use classic IAM in this lab to keep things simple.

Go to IAM in AWS and create a new user.

![alt text](image-15.png)

On the last screen you get the Console Sign-In details:
https://894120233078.signin.aws.amazon.com/console

Add this URL to your browser bookmarks.

### Create an Administrators group

Now go to groups and create an Administrators group:
https://us-east-1.console.aws.amazon.com/iam/home?region=eu-central-1#/groups/create

![alt text](image-16.png)

Select AdministratorAccess as the attached policy:

![alt text](image-17.png)

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        }
    ]
}
```

Add the created user to the group:

![alt text](image-18.png)

We use the AWS UI so that you can feel more comfortable working with the interface and become more familiar with it. The same can be done with the AWS CLI:

<details>
<summary>CLI alternative (click to expand)</summary>

```bash
# Create group and attach policy
aws iam create-group --group-name Administrators
aws iam attach-group-policy \
  --group-name Administrators \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create user with console access
aws iam create-user --user-name john
aws iam create-login-profile \
  --user-name john \
  --password "StrongPassword123!" \
  --password-reset-required

# Add user to group
aws iam add-user-to-group \
  --user-name john \
  --group-name Administrators

# Create access key for programmatic use
aws iam create-access-key --user-name john
```

</details>

### Create an Access Key

The last step for user configuration is to create an Access Key. This key will be used for programmatic access (CLI, Terraform, CI/CD).

Go to the user's Security Credentials tab and click "Create access key":
https://us-east-1.console.aws.amazon.com/iam/home?region=eu-central-1#/users/details/admin/create-access-key

<details>
<summary>Alternatives to access keys (click to expand)</summary>

There are other recommended approaches for authentication:
- **AWS CLI V2 with `aws login`** — use your existing console credentials in the CLI. [Documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html)
- **AWS CloudShell** — a browser-based CLI to run commands. [Learn more](https://docs.aws.amazon.com/singlesignon/latest/userguide/identity-center-prerequisites.html?icmpid=docs_sso_console)
- **User federation** via external identity providers (Keycloak, AD FS, etc.) — common in companies. [Documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html)

We use access keys in this lab for simplicity.

</details>

![alt text](image-19.png)

![alt text](image-20.png)

### Create a CI/CD user

It is a good practice to separate human and machine credentials. Create a dedicated IAM user for Terraform and CI/CD named `ci-bot`:

![alt text](image-21.png)

Add it to the Administrators group:

![alt text](image-22.png)

### Create a budget in AWS

The last step is to set up a billing budget to avoid unexpected charges. You can follow [this guide](https://www.udemy.com/course/devops-deployment-automation-terraform-aws-docker/learn/lecture/43769728#notes) or configure it directly in the AWS Billing console under Budgets.


### Configure S3 bucket and DynamoDB

Terraform needs a place to store its **state file** — a record of all resources it manages. By default, Terraform stores state locally, but this does not work for team collaboration or CI/CD pipelines. We use a remote backend with:

- **S3 bucket** — stores the Terraform state file (encrypted at rest)
- **DynamoDB table** — provides state locking to prevent concurrent modifications

We create these resources manually (not via Terraform) because Terraform cannot manage its own backend — it needs the bucket and table to already exist before it can initialize.

#### Create the S3 bucket

1. Go to the [S3 Console](https://s3.console.aws.amazon.com/s3/home?region=eu-central-1)
2. Click **Create bucket**
3. Bucket name: `cicd-security-tf-state-1` (must be globally unique — adjust if taken)
4. Region: `eu-central-1`
5. Enable **Bucket Versioning** (allows recovering previous state versions)
6. Enable **Server-side encryption** (SSE-S3)
7. **Block all public access** — leave this enabled (default)
8. Click **Create bucket**

Or via the AWS CLI:

```bash
aws s3api create-bucket \
  --bucket cicd-security-tf-state-1 \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-bucket-versioning \
  --bucket cicd-security-tf-state-1 \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket cicd-security-tf-state-1 \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'
```

#### Create the DynamoDB table

1. Go to the [DynamoDB Console](https://eu-central-1.console.aws.amazon.com/dynamodbv2/home?region=eu-central-1#tables)
2. Click **Create table**
3. Table name: `cicd-security-tf-state-lock`
4. Partition key: `LockID` (type: String)
5. Leave all other settings as default
6. Click **Create table**

Or via the AWS CLI:

```bash
aws dynamodb create-table \
  --table-name cicd-security-tf-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

After both resources are created, Terraform can be initialized with `terraform init` and will use this remote backend for state management.
