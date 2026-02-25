### Checkov configuration for terraform code scan

The simplest approach of Checkov configuration is to add it as another step. We can create a separate action with Checkov and also call this action from the step of the job. Also we can create a callable workflow.

With the workflow configuration as this:
```yaml
name: Terraform AWS Deploy

on:
  pull_request:
    branches: [ "main" ]
    paths: [ "infra/**" ]
  push:
    branches: [ "main" ]
    paths: [ "infra/**" ]
  workflow_dispatch:

permissions:
  contents: read
  id-token: write
  pull-requests: write
  security-events: write  # For uploading Checkov SARIF results

concurrency:
  group: terraform-deploy
  cancel-in-progress: false

jobs:
  checkov:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Run Checkov Security Scan
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: infra
          framework: terraform
          output_format: sarif
          output_file_path: checkov-results.sarif

      - name: Upload Checkov results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: checkov-results.sarif

  plan:
    runs-on: ubuntu-latest
    environment: PROD
    if: github.event_name == 'pull_request'

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Cache TF plugins
        uses: actions/cache@v4
        with:
          path: ~/.terraform.d/plugin-cache
          key: terraform-${{ runner.os }}-${{ hashFiles('infra/**/*.tf') }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.5

      - name: Terraform Init
        run: terraform init -input=false
        working-directory: ./infra

      - name: Terraform Validate
        run: terraform validate
        working-directory: ./infra

      - name: Terraform Plan
        id: plan
        run: terraform plan -input=false -out=tfplan -no-color
        working-directory: ./infra

      - name: Add Plan to PR
        if: github.event_name == 'pull_request'
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          message: |
            ## Terraform Plan
            ```
            ${{ steps.plan.outputs.stdout }}
            ```

  apply:
    runs-on: ubuntu-latest
    environment: PROD
    if: github.ref == 'refs/heads/main' && (github.event_name == 'push' || github.event_name == 'workflow_dispatch')

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.5

      - name: Terraform Init
        run: terraform init -input=false
        working-directory: ./infra

      - name: Run Checkov Security Scan
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: infra
          framework: terraform
          output_format: sarif
          output_file_path: checkov-results.sarif
        continue-on-error: true

      - name: Upload Checkov results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: checkov-results.sarif

      - name: Terraform Plan
        run: terraform plan -input=false -out=tfplan
        working-directory: ./infra

      - name: Terraform Apply
        run: terraform apply -input=false tfplan
        working-directory: ./infra
```

We actually just highlight the problem with the terraform code:
![alt text](image-5.png)

and it does not prevent us from merging it to the main and deploy code. See at screenshot below the "Merge pull request" button is active
![alt text](image-6.png)

Different companies handle it differently. But for strict gate in CI we need just perform a few configuration options.
Go to Settings / Branches and for main branch rule configure:
 - Require status checks to pass before merging
 - Require branches to be up to date before merging
 select status checks that are required = "plan"

as shown below
![alt text](image-8.png)

and ensure that

....

Do not allow bypassing the above settings
The above settings will apply to administrators and custom roles with the "bypass branch protections" permission.

is "enabled".
Now we are not able to merge PR:

![alt text](image-4.png)

After changing continue-on-error to "true" value.

      - name: Run Checkov Security Scan
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: infra
          framework: terraform
          output_format: sarif
          output_file_path: checkov-results.sarif
        continue-on-error: true

it will allow to merge PR. The plan execution is shown as successful despite that Checkov exited with exit code 1 after finding security issues:
![alt text](image-9.png)
![alt text](image-10.png)


to sum it up:
   - continue-on-error set to true allows to avoid any repo security settings, Require status checks to pass before merging
   - without configuring "Require status checks to pass before merging" we can merge PR even when continue-on-error = false
   - if we want to create a strict gate (security / quality / etc) both continue-on-error for the step and "Require status checks to pass before merging" need to be configured

## Behavior Matrix

The following table shows the interaction between `continue-on-error` setting and branch protection rules:

| `continue-on-error` | Branch Protection Enabled | Workflow Status | Can Merge PR? | Notes |
|-------------------|--------------------------|----------------|---------------|--------|
| `false` | No | Failed | **Yes** | Workflow fails but merge is allowed |
| `true` | Yes | Success | **Yes** | Step failure is ignored, workflow succeeds |
| `false` | Yes | Failed | **No** | **Strict gate - Recommended** |
| `true` | No | Success | **Yes** | Step failure is ignored |

### Key Takeaways:

- **`continue-on-error: true`** always allows merging (workflow shows success even if Checkov finds issues)
- **No branch protection** always allows merging (regardless of workflow status)
- **For strict security enforcement**: Use `continue-on-error: false` + "Require status checks to pass before merging"
- **Best practice**: Both settings must be configured together to create an effective security gate


### GitHub Rulesets

GitHub Rulesets is a modern approach which plays a similar role as branch protection rules, but it allows to configure rules in a more advanced way as well as share these rules. Play with the rulesets configuration separately.


### Possible misconfiguration
Be careful with configuration. If your job is triggered by the block of the configuration:
```yaml
on:
  pull_request:
    branches: [ "main" ]
    paths: [ "infra/**" ]
  push:
    branches: [ "main" ]
    paths: [ "infra/**" ]
```
you will not be able to make changes to the workflow configuration (terraform-deploy.yml)

![alt text](image-11.png)


because actions start running only after changes to the infra directory, and we set the plan job as mandatory in GitHub settings which will not run. To avoid this some bump version or similar changes to TF can be made.


This is why the Checkov check has to be moved to a separate action.
