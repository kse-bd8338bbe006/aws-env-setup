variable "prefix" {
  description = "Prefix for resources in AWS"
  default     = "ccs"
}

variable "region" {
  default = "eu-central-1"
}

variable "project" {
  description = "Project name for tagging resources"
  default     = "ci-cd-security-course"
}

variable "contact" {
  description = "Contact name for tagging resources"
  default     = "kostia.shiian@gmail.com"
}
