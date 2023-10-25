variable "aws_region" {
  type        = string
  description = "AWS region to create resources. Default Milan"
  default     = "eu-south-1"
}

variable "app_name" {
  type        = string
  description = "App name."
  default     = "interop-be-signalhub"
}

variable "app_version" {
  type        = string
  description = "App version (registry image tag)"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment. Possible values are: Dev, Uat, Prod"
}

variable "env_short" {
  type        = string
  default     = "d"
  description = "Evnironment short."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC cidr."
}

variable "azs" {
  type        = list(string)
  description = "Availability zones"
  default     = ["eu-south-1a", "eu-south-1b", "eu-south-1c"]
}

variable "cluster_version" {
  description = "Kubernetes <major>.<minor> version to use for the EKS cluster (i.e.: 1.24)"
  default     = "1.28"
  type        = string
}

## Public Dns zones
##  variable "public_dns_zones" {
##  type        = map(any)
##  description = "Route53 Hosted Zone"
##}

variable "dns_record_ttl" {
  type        = number
  description = "Dns record ttl (in sec)"
  default     = 86400 # 24 hours
}

variable "tags" {
  type = map(any)
  default = {
    CreatedBy = "Terraform"
  }
}

#variable "iam_users" {
#  type        = list(string)
#  description = "IAM users"
#}

variable "namespace" {
  type        = string
  description = "Namespace for microservices"
  default     = "signalhub"
}

variable "registry_server" {
  type        = string
  description = "Registry image server"
  default     = "ghcr.io/pagopa"
}

#variable "registry_username" {
#  type        = string
#  description = "Registry image server username"
#}
#
#variable "registry_password" {
#  type        = string
#  description = "Registry image server password (or token)"
#}
#
#variable "registry_email" {
#  type        = string
#  description = "Registry image server user email"
#}

variable "aurora_rds_cluster_min_capacity" {
  description = "Aurora serverless cluster min capacity"
  type        = number
  default     = 2
}

variable "aurora_rds_cluster_max_capacity" {
  description = "Aurora serverless cluster max capacity"
  type        = number
  default     = 4
}


variable "pdnd_api_endpoint" {
  type        = string
  description = "Endpoint of Interop API"
}

variable "pdnd_auth_client_id" {
  type        = string
  description = "Client id of Interop API"
}

variable "pdnd_auth_token_uri" {
  type        = string
  description = "Interop Voucher token endpoint"
}

variable "pdnd_auth_jwk_uri" {
  type        = string
  description = "Interop Voucher jwk endpoint"
}



variable "helm_aws_load_balancer_version" {
  type        = string
  description = "Helm Chart AWS Load balancer controller version"
}

variable "helm_metrics_server_version" {
  type        = string
  description = "Helm Chart Metrics Server version"
}

variable "helm_prometheus_version" {
  type        = string
  description = "Helm Chart Metric Server version"
}

variable "helm_reloader_version" {
  type        = string
  description = "Helm Chart Reloader version"
}

variable "initial_load_s3_bucket" {
  type        = string
  description = "Bucket for initial eservices and agreements loading"
}