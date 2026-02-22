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

At the time of my registration, you may provided with 100 USD in credits and additional bonuses for completing activities:

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

### IAM vs IAM Identity Center

IAM Identity Center is the modern, recommended solution for managing user access in AWS. It supports SSO and integrates with external identity providers. However, for this lab we use classic IAM to keep things simple.

### Create a regular user

Go to IAM in AWS and create a new user.

> **Note:** There is the newer IAM Identity Center, but it may require upgrading from a free-tier account since it creates an AWS Organization. We use classic IAM in this lab.

![alt text](image-15.png)

On the last screen you get the Console Sign-In details:
https://894120233078.signin.aws.amazon.com/console

Add this url to the browser bookmarks.

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

Add the user to the group:
![alt text](image-18.png)

The same can be done with the AWS CLI:

```bash
aws iam create-group --group-name Administrators

aws iam attach-group-policy \
  --group-name Administrators \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

aws iam create-user --user-name john

aws iam create-login-profile \
  --user-name john \
  --password "StrongPassword123!" \
  --password-reset-required
```

If you want an access key for programmatic use:

```bash
aws iam create-access-key --user-name john
```

Add the user to the group:

```bash
aws iam add-user-to-group \
  --user-name john \
  --group-name Administrators
```

We use the AWS UI so that you can feel more comfortable working with the interface and become more familiar with it.

The last step for user configuration is to create an Access Key:
https://us-east-1.console.aws.amazon.com/iam/home?region=eu-central-1#/users/details/admin/create-access-key

Note that there are two other recommended alternatives to access keys:

- **AWS CLI V2 with `aws login`** — use your existing console credentials in the CLI. [Documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html)
- **AWS CloudShell** — a browser-based CLI to run commands. [Learn more](https://docs.aws.amazon.com/singlesignon/latest/userguide/identity-center-prerequisites.html?icmpid=docs_sso_console)

Another recommended approach is to federate users via an external identity provider ([documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html)). This is common in companies that already have their own identity providers:
- Keycloak
- AD FS
- etc.

We are not going to use any of these approaches. We keep things simple and create an access key for use in CI/CD:

![alt text](image-19.png)

![alt text](image-20.png)

You also need to create a separate IAM user for Terraform and CI named `ci-bot`:

![alt text](image-21.png)

Add it to the Administrators group:

![alt text](image-22.png)

### Create a budget in AWS
And the last step we have to set up a billing budget to avoid unexpected charges. You can follow [this guide](https://www.udemy.com/course/devops-deployment-automation-terraform-aws-docker/learn/lecture/43769728#notes) or configure it directly in the AWS Billing console under Budgets.
