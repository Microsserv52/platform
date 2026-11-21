output "region" { value = var.aws_region }
output "localstack_endpoint" { value = var.localstack_endpoint }
output "vpc_id" { value = module.network.vpc_id }

output "registry" {
  value = try(split("/", values(module.ecr.repository_urls)[0])[0], "")
}
output "ecr_repository_urls" { value = module.ecr.repository_urls }

output "rds_endpoint" { value = try(module.rds[0].address, "") }
output "rds_port" { value = try(module.rds[0].port, 5432) }
output "rds_db_name" { value = try(module.rds[0].db_name, "platform") }
output "rds_username" { value = try(module.rds[0].username, "platform") }
output "rds_password" {
  value     = random_password.db.result
  sensitive = true
}

output "redis_endpoint" { value = try(module.elasticache[0].address, "") }
output "redis_port" { value = try(module.elasticache[0].port, 6379) }

output "media_bucket" { value = module.storage.media_bucket }
output "frontend_buckets" { value = module.storage.frontend_buckets }

output "cloudfront_distribution_id" { value = try(module.cloudfront[0].distribution_id, "") }
output "cloudfront_domain_name" { value = try(module.cloudfront[0].distribution_domain_name, "") }

output "eks_cluster_name" { value = try(module.eks[0].cluster_name, "") }
output "product_irsa_role_arn" { value = try(module.eks[0].irsa_role_arn, "") }
