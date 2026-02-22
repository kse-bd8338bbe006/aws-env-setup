## Github repo configuration
We are going to make decision about github branching strategy. There are different of them:
- gitflow
- github 
- gitlab

For infra structue code the popular approach is to use branching model 
Branching Model
 - main → production
 - dev → development
- stage or preprod → optional

Developers create short-lived branches from `dev`:

```bash
dev
 ├── feature/ecs-module-update
 ├── feature/vpc-hardening
 └── feature/security-groups-refactor
```

Merge `dev -> stage -> main` as part of promotion.

## **Terraform Directory Layout**

```r
infra/
  dev/
  stage/
  prod/
```

## **GitHub Actions Behavior**
    -   on PR → run `terraform plan`
    -   on merge into `dev` → `terraform apply` for **dev**
    -   on merge into `stage` → deploy to **stage**
    -   on merge into `main` → deploy to **production**


### Why this strategy works best:

✔ Clear environment isolation  
✔ Predictable promotion path  
✔ Protects `main` with reviews  
✔ CI knows exactly which environment it is deploying


TODO: describe different environamntents and why they are important. Describe stage env that have to be as a pord , the importance for testing. Dev could be unstable, raw changes can impact the dev env.

There are could be another strategies but we choose to use the describe above. The one difference is that we will not use DEV, STAGE. We are goingo to deploy all our changes to the PROD, we have only PROD env for cost saving and simplification of our test lab.

You can easialy extend this approach to work also with dev and stage environment if it would be neccessary.


### Github actions configuration
GitHub Actions Behavior
on creating PR -> run terraform plan
on merge into main -> deploy to production

### github branching strategy
# ✅ **Most Effective GitHub Branching Strategies**

## 1\. **GitHub Flow (Simple, Continuous Delivery)**

**Best for:** SaaS, small teams, rapid release cycles, trunk-based development.

**Branches**

-   `main` → always deployable
    
-   Feature branches → short-lived (`feature/...`)
    

**Workflow**

1.  Create branch from `main`
    
2.  Commit small changes frequently
    
3.  Open PR early
    
4.  Get review + automated checks
    
5.  Merge to `main`
    
6.  Auto-deploy


### Github repo configuration 
#### Create PROD environment
Go to environments and create new PROD environment
![alt text](image-1.png)

Get AWS configuration

![alt text](image.png)

and set them in Environemnt Secrets and Environment Variables
Environment secrets:
  - AWS_ACCESS_KEY_ID
  - AWS_SECRET_ACCESS_KEY

Environment variables:
  - AWS_REGION





#### Write github actions
The simplest workflow automatically performs apply right after plan, the steps look like the following:
```yaml
      # Plan
      - name: Terraform Plan
        run: terraform plan -input=false -out=tfplan
        working-directory: ./infra

      # Apply (proceed only on main)
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -input=false -auto-approve tfplan
        working-directory: ./infra
```
![alt text](image-3.png)

Thist is not convient and not corrected parametera can be applied. More sophisticated approaches requires review be fore applying. 
Also there are application like `Atlantis` that helps to manage PRs.
https://github.com/kse-bd8338bbe006/aws-env-setup/actions/runs/19733892873/job/56541111754

We are going to keep things simple so we just will use Github environments for deploy to prod that forces manual review before deploying.

For this we need two jobs:
- plan 
- apply
See - https://github.com/kse-bd8338bbe006/aws-env-setup/blob/main/.github/workflows/terraform.yml

And now we need to configure protection rules. Check this documentation for details: https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/configure-custom-protection-rules#enabling-custom-deployment-protection-rules-for-the-environment

Go to Settings / Environments.
Your project has to have Public access:
"The general built-in protection features (like requiring manual approvals, wait timers, branch/tag restrictions when using GitHub Actions environments) are available for public repositories under all plans — including free/pro/plus."

Go to Enironments and set deployment protection rules
![alt text](image-4.png)

Now you will see that approve is required:
![alt text](image-5.png)

and can just approve it
![alt text](image-6.png)

After job plan finished  its execution, you can go to plan job
![alt text](image-7.png)

check plan and only after reviewing approve "apply" job. 

But other option which is prefferable is:
- trigger terraform init and plan only for create PR event
- after all checks are finished and feature branch is merge into main, only then run terraform apply.

To configure this, go to branches:
https://github.com/kse-bd8338bbe006/aws-env-setup/settings/branches

and classic Branch Protection Rule:
https://github.com/kse-bd8338bbe006/aws-env-setup/settings/branch_protection_rules/new


TODO: remove






Here’s exactly where this is configured in GitHub:

✅ How to configure these settings (GitHub → Environment Protection Rules)
https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/configure-custom-protection-rules

Go to your repository on GitHub
In the top menu, click Settings
In the left sidebar, click Environments
Select your environment — in this case: PROD
Inside the PROD environment, scroll to Protection rules





![alt text](image-2.png)



### Using monorepo
Using monorepo for you  terraform infra code has benefits:
- you can use terragrunt that could simplify a lot of terraform related restriction pay
- you can easilly move changes from the dev to stage and prod in your IDE

just show example....



### Gigthub environments
https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments

https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments


### Security 
#### Disable direct push to the main branch


First we have to make default main branch is protected from direct push commits. This will ensure that we will be able to add securiy check that 
