
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
  value = module.eks.cluster_name
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
