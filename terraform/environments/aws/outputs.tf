output "region" { value = var.aws_region }
output "vpc_id" { value = module.network.vpc_id }

output "registry" {
  value = try(values(module.ecr.repository_urls)[0], "")
}
output "ecr_repository_urls" { value = module.ecr.repository_urls }

output "rds_endpoint" { value = module.rds.address }
output "rds_port" { value = module.rds.port }
output "rds_db_name" { value = module.rds.db_name }
output "rds_username" { value = module.rds.username }
output "rds_password" {
  value     = random_password.db.result
  sensitive = true
}

output "redis_endpoint" { value = module.elasticache.address }
output "redis_port" { value = module.elasticache.port }

output "media_bucket" { value = module.storage.media_bucket }
output "frontend_buckets" { value = module.storage.frontend_buckets }

output "cloudfront_distribution_id" { value = try(module.cloudfront[0].distribution_id, "") }
output "cloudfront_domain_name" { value = try(module.cloudfront[0].distribution_domain_name, "") }

output "eks_cluster_name" { value = module.eks.cluster_name }
output "eks_cluster_endpoint" { value = module.eks.cluster_endpoint }
output "product_irsa_role_arn" { value = module.eks.irsa_role_arn }
output "certificate_arn" { value = local.certificate_arn }
