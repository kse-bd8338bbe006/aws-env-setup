## Architecture overview

### High-level infrastructure diagram

```mermaid
graph LR
    subgraph GitHub
        Dev[Developer] -->|PR| Actions[GitHub Actions]
        Actions -->|credentials| Secrets[PROD Environment Secrets]
    end

    Actions -->|terraform apply| AWS

    subgraph AWS["AWS (eu-central-1)"]
        IAM["IAM<br/>admin + cicd-bot"]
        Backend["TF Backend<br/>S3 + DynamoDB"]
        VPC["VPC 10.1.0.0/16<br/>Public + Private Subnets"]
        ALB["ALB<br/>(public subnets)"]
        EC2["EC2 t3.micro<br/>Nginx (private subnet)"]
        Budget["Budget $50/mo"]
    end
```

### CI/CD and AWS components

```mermaid
graph TB
    subgraph GitHub["GitHub Actions"]
        direction LR
        PR[Pull Request] -.->|trigger| Plan
        Main[Push to main] -.->|trigger| Apply

        subgraph Plan[Plan Job]
            Validate[terraform validate]
            Checkov[Checkov scan + SARIF upload]
            TFPlan[terraform plan]
            Comment[Post plan to PR]
        end

        subgraph Apply[Apply Job]
            Checkov2[Checkov scan + SARIF upload]
            TFPlan2[terraform plan -out=tfplan]
            TFApply[terraform apply]
        end
    end

    subgraph AWS["AWS (eu-central-1)"]
        subgraph IAM
            Admin["admin<br/>(human, console + CLI)"]
            CICD["cicd-bot<br/>(machine, CI/CD)"]
        end

        subgraph Backend["TF Backend (manual)"]
            S3[S3 state bucket]
            DDB[DynamoDB lock table]
        end

        subgraph VPC["VPC: 10.1.0.0/16"]
            subgraph Public
                PubA["public-a<br/>10.1.1.0/24"]
                PubB["public-b<br/>10.1.2.0/24"]
                ALB2[ALB]
            end
            IGW[Internet Gateway]
            NAT[NAT Gateway + EIP]
            subgraph Private
                PrivA["private-a<br/>10.1.10.0/24"]
                PrivB["private-b<br/>10.1.11.0/24"]
                EC2["EC2 t3.micro<br/>Nginx + SSM"]
            end
        end

        subgraph Endpoints["VPC Endpoints"]
            CW[CloudWatch Logs]
            SSMC[SSM Core]
            SSMM[SSM Messages]
            S3EP[S3 Gateway]
        end

        Budget["Budget: $50/mo<br/>Alert at 80%"]
    end

    TFApply -->|deploy| AWS
    CICD -.->|credentials| GitHub
```

### CI/CD deploy workflow

```mermaid
sequenceDiagram
    actor Dev as Developer
    participant GH as GitHub
    participant Plan as Plan Job
    participant Apply as Apply Job
    participant Approver as Reviewer
    participant AWS as AWS

    Dev->>GH: Push feature branch
    Dev->>GH: Open Pull Request

    Note over GH: Trigger: pull_request on main<br/>Path filter: infra/**

    GH->>Plan: Start plan job
    Plan->>AWS: terraform init (S3 backend)
    Plan->>Plan: terraform validate
    Plan->>Plan: Checkov scan + SARIF upload
    Plan->>AWS: terraform plan
    Plan->>GH: Post plan as PR comment

    Approver->>GH: Review plan + approve PR
    Dev->>GH: Merge PR to main

    Note over GH: Trigger: push to main<br/>Path filter: infra/**

    GH->>Apply: Start apply job
    Apply->>AWS: terraform init
    Apply->>Apply: Checkov scan + SARIF upload
    Apply->>AWS: terraform plan -out=tfplan
    Apply->>AWS: terraform apply tfplan
    AWS-->>Apply: Resources created/updated
```

### Destroy workflow

```mermaid
sequenceDiagram
    actor Dev as Developer
    participant GH as GitHub
    participant DJ as Destroy Job
    participant Approver as Reviewer
    participant AWS as AWS

    Dev->>GH: Trigger workflow_dispatch

    Note over GH: Manual trigger only

    GH->>DJ: Start destroy job

    Note over DJ,Approver: PROD environment<br/>requires manual approval

    Approver->>GH: Approve destruction
    DJ->>AWS: terraform init
    DJ->>AWS: terraform destroy -auto-approve
    AWS-->>DJ: All resources destroyed<br/>(cicd-bot not managed by TF)
```

### Network architecture

```mermaid
graph TB
    Internet((Internet))

    subgraph VPC["VPC: 10.1.0.0/16"]
        IGW[Internet Gateway]

        subgraph PubSub["Public Subnets"]
            PubA["public-a<br/>10.1.1.0/24<br/>AZ: eu-central-1a"]
            PubB["public-b<br/>10.1.2.0/24<br/>AZ: eu-central-1b"]
            ALB["ALB<br/>HTTP :80"]
        end

        EIP["Elastic IP"]
        NAT["NAT Gateway"]

        subgraph PrivSub["Private Subnets"]
            PrivA["private-a<br/>10.1.10.0/24<br/>AZ: eu-central-1a"]
            PrivB["private-b<br/>10.1.11.0/24<br/>AZ: eu-central-1b"]
            EC2["EC2 t3.micro<br/>Nginx + SSM agent"]
        end

        subgraph EP["VPC Endpoints"]
            CWEP["CloudWatch Logs<br/>(Interface)"]
            SSMEP["SSM Core<br/>(Interface)"]
            SSMMEP["SSM Messages<br/>(Interface)"]
            S3EP["S3<br/>(Gateway)"]
        end

        SG["Security Group<br/>endpoint-access<br/>Ingress: 443/tcp<br/>from VPC CIDR"]
    end

    Internet <-->|inbound/outbound| IGW
    IGW <--> PubA & PubB
    Internet -->|HTTP :80| ALB
    ALB -->|forward :80| EC2
    PubA --> NAT
    EIP --- NAT
    NAT -->|outbound only| PrivA & PrivB
    PrivA & PrivB -.->|private traffic| CWEP & SSMEP & SSMMEP & S3EP
    SG -.->|protects| CWEP & SSMEP & SSMMEP
```

### Repository structure

```
aws-env-setup/
├── .github/
│   └── workflows/
│       ├── terraform-deploy.yml    # Plan on PR, apply on merge
│       └── terraform-destroy.yml   # Manual teardown
├── infra/                          # Terraform root module
│   ├── main.tf                     # Provider, backend, locals
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # ALB DNS name output
│   ├── ec2.tf                      # EC2, ALB, security groups
│   ├── iam.tf                      # IAM role + instance profile for SSM
│   ├── network.tf                  # VPC, subnets, NAT, endpoints
│   └── budgets.tf                  # AWS budget alarm
├── check/                          # Custom Checkov policies
│   ├── check.sh                    # Runner script
│   └── custom_checks/              # Python + YAML policies
├── scripts/
│   └── setup-cicd-bot.sh           # One-time cicd-bot IAM setup
├── docs/                           # Lab documentation
└── .gitignore                      # Terraform state exclusions
```

### What is managed manually vs. by Terraform

| Resource | Managed by | Why |
|---|---|---|
| AWS account, root user | Manual | One-time setup |
| `admin` IAM user + Administrators group | Manual | Needed before Terraform can run |
| S3 bucket (state) | Manual | Terraform can't manage its own backend. S3 bucket names are globally unique — choose your own name |
| DynamoDB table (lock) | Manual | Same reason |
| VPC, subnets, NAT, endpoints | Terraform | Core infrastructure |
| ALB + EC2 instance (Nginx) | Terraform | Web server in private subnet behind ALB |
| IAM role + instance profile (SSM) | Terraform | EC2 access via SSM Session Manager |
| `cicd-bot` IAM user + policies | Manual (`scripts/setup-cicd-bot.sh`) | CI/CD credentials — managed outside Terraform to avoid circular dependency |
| Budget alarm ($50/month) | Terraform | Automated cost control |
| GitHub environment + secrets | Manual | GitHub-side config, not AWS |

### Setting up cicd-bot (one-time)

The `cicd-bot` IAM user is managed **outside of Terraform** to avoid circular dependencies (CI needs credentials to run Terraform, but Terraform would need to create those credentials).

Run the setup script once with admin AWS credentials:

```bash
./scripts/setup-cicd-bot.sh
```

The script creates the user, attaches policies, and prints the access key credentials. Add them to GitHub (Settings > Environments > PROD > Secrets):
- `AWS_ACCESS_KEY_ID` — access key ID
- `AWS_SECRET_ACCESS_KEY` — secret access key
- `AWS_REGION` (variable) — `eu-central-1`

After this, CI handles all deploys and destroys automatically. The `cicd-bot` user is never touched by `terraform destroy`.

### Safety mechanisms

| Mechanism | What it does |
|---|---|
| Path filtering (`infra/**`) | Only infra changes trigger the pipeline |
| Concurrency control | Queues runs, never cancels in-progress applies |
| `-out=tfplan` | Apply uses the exact saved plan, no re-evaluation |
| DynamoDB state locking | Prevents concurrent state modifications |
| PROD environment approval | Requires manual approval before apply |
| Checkov security scan + SARIF | Catches misconfigurations, uploads results to GitHub Security tab |
| Branch protection | All changes go through PRs, no direct push to `main` |

### Network design

The VPC follows a standard two-tier architecture across two availability zones:

**Public subnets** (`10.1.1.0/24`, `10.1.2.0/24`):
- Route to the internet via Internet Gateway
- Host public-facing resources (ALB, NAT Gateway)
- Auto-assign public IPs

**Private subnets** (`10.1.10.0/24`, `10.1.11.0/24`):
- Route outbound traffic through a single NAT Gateway in `public-a`
- Host internal resources (EC2 instances)
- No public IP assignment

**VPC Endpoints** reduce NAT costs and improve latency for AWS services:
- **CloudWatch Logs** (Interface) — application logging
- **SSM Core** (Interface) — SSM control channel
- **SSM Messages** (Interface) — SSM Session Manager data channel
- **S3** (Gateway) — free, no NAT charges for S3 access

> **Cost note:** The NAT Gateway is the most expensive component in this setup (~$32/month + data transfer). VPC endpoints help offset this by routing AWS service traffic directly, bypassing the NAT.

### Tagging strategy

All resources are tagged via the provider's `default_tags`:

| Tag | Value | Purpose |
|---|---|---|
| `Environment` | `default` (workspace name) | Identify environment |
| `Project` | `ci-cd-security-course` | Group resources by project |
| `Contact` | `kostia.shiian@gmail.com` | Owner for billing/questions |
| `ManageBy` | `Terraform/setup` | Distinguish IaC-managed resources |
