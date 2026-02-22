The final configuration
In our AWS acccounts we would have typical configura of infra that would spin up for our test on demand: VPC

Private Subnet
Public Subnet
GW (for external traffic from private subnet to Internet , to allow hosts in private subnets download packages, pull images, etc)
minimalistic EKS cluster
S3 bucket for storing terraform state
DynamoDB for working with the terraform locks
Instead of:

Terraform
AWS VPC
What is VPS: https://www.udemy.com/course/aws-solutions-architect-professional/learn/lecture/18387196#questions

