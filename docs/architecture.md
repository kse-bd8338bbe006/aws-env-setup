## Architecture overview

### High-level infrastructure diagram

```mermaid
graph TB
    subgraph GitHub["GitHub"]
        Dev[Developer] -->|push| FB[Feature Branch]
        FB -->|open| PR[Pull Request]
        PR -->|merge| Main[main branch]

        subgraph CI["GitHub Actions"]
            PR -.->|trigger| Plan[Plan Job]
            Main -.->|trigger| Apply[Apply Job]

            Plan --> Validate[terraform validate]
            Plan --> Checkov[Checkov security scan]
            Plan --> TFPlan[terraform plan]
            Plan --> Comment[Post plan to PR]

            Apply --> TFPlan2[terraform plan -out=tfplan]
            TFPlan2 --> Approval{PROD environment\nmanual approval}
            Approval -->|approved| TFApply[terraform apply tfplan]
        end

        subgraph Secrets["PROD Environment"]
            AWS_KEY[AWS_ACCESS_KEY_ID]
            AWS_SECRET[AWS_SECRET_ACCESS_KEY]
            AWS_REGION_VAR[AWS_REGION]
        end
    end

    TFApply -->|deploy| AWS

    subgraph AWS["AWS (eu-central-1)"]
        subgraph IAM["IAM"]
            Admin["admin (human)\nAdministratorAccess\nConsole + CLI"]
            CICD["cicd-bot (machine)\nAdministratorAccess\n+ S3/DynamoDB policies"]
        end

        subgraph Backend["Terraform Backend (manual)"]
            S3["S3: cicd-security-tf-state-1\nVersioning + AES-256"]
            DDB["DynamoDB: cicd-security-tf-state-lock\nPartition key: LockID"]
        end

        subgraph VPC["VPC: 10.1.0.0/16"]
            subgraph Public["Public Subnets"]
                PubA["public-a\n10.1.1.0/24\nAZ: eu-central-1a"]
                PubB["public-b\n10.1.2.0/24\nAZ: eu-central-1b"]
            end

            IGW[Internet Gateway]
            NAT["NAT Gateway\n+ Elastic IP"]

            subgraph Private["Private Subnets"]
                PrivA["private-a\n10.1.10.0/24\nAZ: eu-central-1a"]
                PrivB["private-b\n10.1.11.0/24\nAZ: eu-central-1b"]
            end

            subgraph Endpoints["VPC Endpoints"]
                CW["CloudWatch Logs\n(Interface)"]
                SSM["SSM Messages\n(Interface)"]
                S3EP["S3\n(Gateway)"]
            end
        end

        Budget["Budget: $50/month\nAlert at 80% forecasted"]
    end

    PubA & PubB --> IGW
    IGW --> Internet((Internet))
    NAT --> IGW
    PrivA & PrivB --> NAT
    PrivA & PrivB --> CW & SSM & S3EP
    CICD -.->|credentials| Secrets
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
    Plan->>Plan: Checkov security scan
    Plan->>AWS: terraform plan
    Plan->>GH: Post plan as PR comment

    Approver->>GH: Review plan + approve PR
    Dev->>GH: Merge PR to main

    Note over GH: Trigger: push to main<br/>Path filter: infra/**

    GH->>Apply: Start apply job
    Apply->>AWS: terraform init
    Apply->>AWS: terraform plan -out=tfplan

    Note over Apply,Approver: PROD environment<br/>requires manual approval

    Approver->>GH: Approve deployment
    Apply->>AWS: terraform apply tfplan
    AWS-->>Apply: Resources created/updated
```

### Destroy workflow

```mermaid
sequenceDiagram
    actor Dev as Developer
    participant GH as GitHub
    participant Destroy as Destroy Job
    participant Approver as Reviewer
    participant AWS as AWS

    Dev->>GH: Trigger workflow_dispatch

    Note over GH: Manual trigger only

    GH->>Destroy: Start destroy job

    Note over Destroy,Approver: PROD environment<br/>requires manual approval

    Approver->>GH: Approve destruction
    Destroy->>AWS: terraform init
    Destroy->>Destroy: terraform state rm (IAM resources)
    Note over Destroy: Remove cicd-bot from state<br/>so destroy won't delete its own credentials
    Destroy->>AWS: terraform destroy -auto-approve
    AWS-->>Destroy: All resources destroyed<br/>(cicd-bot preserved)
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
        end

        EIP["Elastic IP"]
        NAT["NAT Gateway"]

        subgraph PrivSub["Private Subnets"]
            PrivA["private-a<br/>10.1.10.0/24<br/>AZ: eu-central-1a"]
            PrivB["private-b<br/>10.1.11.0/24<br/>AZ: eu-central-1b"]
        end

        subgraph EP["VPC Endpoints"]
            CWEP["CloudWatch Logs<br/>(Interface endpoint)"]
            SSMEP["SSM Messages<br/>(Interface endpoint)"]
            S3EP["S3<br/>(Gateway endpoint)"]
        end

        SG["Security Group<br/>endpoint-access<br/>Ingress: 443/tcp<br/>from VPC CIDR"]
    end

    Internet <-->|inbound/outbound| IGW
    IGW <--> PubA & PubB
    PubA --> NAT
    EIP --- NAT
    NAT -->|outbound only| PrivA & PrivB
    PrivA & PrivB -.->|private traffic| CWEP & SSMEP & S3EP
    SG -.->|protects| CWEP & SSMEP
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
│   ├── outputs.tf                  # cicd-bot access keys
│   ├── iam.tf                      # cicd-bot user + policies
│   ├── network.tf                  # VPC, subnets, NAT, endpoints
│   └── budgets.tf                  # AWS budget alarm
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
| `cicd-bot` IAM user + policies | Terraform (`prevent_destroy`) | CI/CD credentials — removed from state before destroy to avoid deleting its own credentials |
| Budget alarm ($50/month) | Terraform | Automated cost control |
| GitHub environment + secrets | Manual | GitHub-side config, not AWS |

### Retrieving cicd-bot credentials

The `cicd-bot` IAM user and access key are managed by Terraform with `prevent_destroy` lifecycle. After `terraform apply`, retrieve the credentials:

```bash
terraform output cd_user_access_key_id
terraform output -raw cd_user_access_key_secret
```

Add these to your GitHub repository secrets (Settings > Environments > PROD):
- `AWS_ACCESS_KEY_ID` — access key ID
- `AWS_SECRET_ACCESS_KEY` — secret access key
- `AWS_REGION` (variable) — `eu-central-1`

### Safety mechanisms

| Mechanism | What it does |
|---|---|
| Path filtering (`infra/**`) | Only infra changes trigger the pipeline |
| Concurrency control | Queues runs, never cancels in-progress applies |
| `-out=tfplan` | Apply uses the exact saved plan, no re-evaluation |
| DynamoDB state locking | Prevents concurrent state modifications |
| PROD environment approval | Requires manual approval before apply |
| Checkov security scan | Catches misconfigurations in Terraform code |
| Branch protection | All changes go through PRs, no direct push to `main` |

### Network design

The VPC follows a standard two-tier architecture across two availability zones:

**Public subnets** (`10.1.1.0/24`, `10.1.2.0/24`):
- Route to the internet via Internet Gateway
- Host public-facing resources (ALB, NAT Gateway)
- Auto-assign public IPs

**Private subnets** (`10.1.10.0/24`, `10.1.11.0/24`):
- Route outbound traffic through a single NAT Gateway in `public-a`
- Host internal resources (ECS tasks, databases)
- No public IP assignment

**VPC Endpoints** reduce NAT costs and improve latency for AWS services:
- **CloudWatch Logs** (Interface) — container/application logging
- **SSM Messages** (Interface) — ECS Exec and remote access
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
