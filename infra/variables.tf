
variable "prefix" {
  description = "Prefix for resources in AWS"
  default     = "ccs"
}
variable "region" {
  default = "eu-central-1"
}

variable "domain_name" {
  description = "Your Route53 hosted domain"
  default     = "codedevops.blog"

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

##########################
# EKS Variables          #
##########################

variable "eks_cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  default     = "1.32"
}

variable "eks_node_instance_type" {
  description = "Instance type for EKS worker nodes"
  default     = "t3.small"
}

variable "eks_node_group_desired_size" {
  description = "Desired number of worker nodes"
  default     = 4
}

variable "eks_node_group_min_size" {
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "eks_node_group_max_size" {
  description = "Maximum number of worker nodes"
  default     = 4
}

variable "eks_monitoring_node_instance_type" {
  description = "Instance type for EKS monitoring worker nodes"
  default     = "t3.micro"
}

variable "eks_monitoring_node_group_desired_size" {
  description = "Desired number of monitoring worker nodes"
  default     = 2
}

variable "eks_monitoring_node_group_min_size" {
  description = "Minimum number of monitoring worker nodes"
  default     = 1
}

variable "eks_monitoring_node_group_max_size" {
  description = "Maximum number of monitoring worker nodes"
  default     = 2
}
