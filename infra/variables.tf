
variable "prefix" {
  description = "Prefix for resources in AWS"
  default     = "ccs"
}
variable "region" {
  default = "eu-central-1"
}



variable "tf_state_bucket" {
  description = "Name of S3 bucket in AWS for storing TF state"
  default     = "cicd-security-tf-state-1"
}

variable "tf_state_lock_table" {
  description = "Name of DynamoDB table for TF state locking"
  default     = "cicd-security-tf-state-lock"
}

variable "project" {
  description = "Project name for tagging resources"
  default     = "ci-cd-security-course"
}

variable "contact" {
  description = "Contact name for tagging resources"
  default     = "kostia.shiian@gmail.com"
}

