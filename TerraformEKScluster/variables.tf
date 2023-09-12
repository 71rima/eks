variable "region" {
  default     = "eu-central-1"
  description = "AWS region"
}

variable "account_id" {
  default     = "930436893219"
  description = "AccountId"
}

locals {
  cluster_name = "btEKS"
}
