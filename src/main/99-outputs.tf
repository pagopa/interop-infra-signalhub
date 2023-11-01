
# ROUTE53 OUTPUTS
output "hosted_zone_id_env_signalhub_interop_pagopa_it" {
  description = "<env>.signalhub.interop.pagopa.it hosted zone id"
  value       = aws_route53_zone.env_signalhub_interop_pagopa_it.zone_id
}

output "ns_env_signalhub_interop_pagopa_it" {
  description = "NS for <env>.signalhub.interop.pagopa.it"
  value       = aws_route53_zone.env_signalhub_interop_pagopa_it.name_servers
}

output "signalhub_cluster_name" {
  description = "Cluster name"
  value       = module.eks.cluster_name
}

output "sqs" {
  value = module.sqs.queue_url
}

output "redis" {
  value = module.redis.elasticache_replication_group_primary_endpoint_address
}

output "cluster_iam_role_name" {
  value = module.eks.cluster_iam_role_name
}


output "aws_caller_identity_current_arn" {
  value = data.aws_caller_identity.current.arn
}

output "aws_caller_identity_current_id" {
  value = data.aws_caller_identity.current.id
}

output "interop_client_key_arn" {
  value = aws_kms_key.interop_client_key.arn
}

output "interop_client_key_id" {
  value = aws_kms_key.interop_client_key.key_id
}

output "fargate_profiles" {
  value = module.eks.fargate_profiles
}

output "fargate_profiles_role_names" {
  value = local.fargate_log_role_names
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cloudwatch_log_group_name" {
  value = module.eks.cloudwatch_log_group_name
}