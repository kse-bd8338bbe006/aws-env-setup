The best practice is to keep as much configuragion in the code as possible. But initially some configuration is created manually like bot with name ci-bot that is goign to be used in our CI

For terraform we are needed backend resources:

s3 bucket
dynamodb
so go to s3 bucket resources: https://eu-central-1.console.aws.amazon.com/s3/get-started?region=eu-central-1

and click on "Create butcket"

I give the name for the bucket: cicd-security-tf-state-1 Your name have to be unique because bucket names are unique across all of s3

Choose parameters:
![alt text](image.png)

### Enable bucket versioning
![alt text](image-1.png)

so we could revert back to the previous verions of terraform state

Leave all these stuff by default:
![alt text](image-2.png)

and click "Create bucket"
![alt text](image-3.png)

In s3 bucket we are going to keep terraform state that will be used by anyone who exeute terraform code

terraform state locking in DynamoDB
After this we have to create DynamoDB table. If more that one will try to run terraform at the same time, make changes at the same time, this can create confilct and cause issues thus we create lock id, to terraform state locking fetaure using. That dynamodb will be used by terrform to track when somecan makes change to infra

I gave the name to dynamodb cicd-security-tf-state-lock

and partition key, configure the value: LockID

keep all other settings by default and click on "Creae table"

![alt text](image-4.png)

Terraform structure
Maximize infra as IaC Least manually create infra as possible

