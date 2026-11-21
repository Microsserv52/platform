provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = "aws"
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront certificates and OACs must live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project
      Environment = "aws"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = var.project
  tags = {
    Project     = var.project
    Environment = "aws"
  }
}

resource "random_password" "db" {
  length  = 32
  special = false
}

module "network" {
  source             = "../../modules/network"
  name               = local.name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = true
  tags               = local.tags
}

module "storage" {
  source               = "../../modules/storage"
  name_prefix          = local.name
  cors_allowed_origins = var.cors_allowed_origins
  force_destroy        = false
  tags                 = local.tags
}

module "ecr" {
  source           = "../../modules/ecr"
  repository_names = ["account", "auth", "gateway", "order", "product", "exchange"]
  force_delete     = false
  tags             = local.tags
}

module "rds" {
  source                  = "../../modules/rds"
  identifier              = "${local.name}-postgres"
  vpc_id                  = module.network.vpc_id
  subnet_ids              = module.network.private_subnet_ids
  allowed_cidr_blocks     = [module.network.vpc_cidr]
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  password                = random_password.db.result
  publicly_accessible     = false
  skip_final_snapshot     = false
  deletion_protection     = true
  backup_retention_period = 7
  tags                    = local.tags
}

module "elasticache" {
  source              = "../../modules/elasticache"
  cluster_id          = "${local.name}-redis"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids
  allowed_cidr_blocks = [module.network.vpc_cidr]
  node_type           = var.redis_node_type
  tags                = local.tags
}

module "eks" {
  source              = "../../modules/eks"
  cluster_name        = local.name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  media_bucket_arn    = module.storage.media_bucket.arn
  admin_principal_arn = var.admin_principal_arn
  tags                = local.tags
}

module "dns" {
  source                    = "../../modules/dns"
  count                     = var.create_dns ? 1 : 0
  providers                 = { aws = aws.us_east_1 }
  domain_name               = var.domain_name
  subject_alternative_names = var.api_domain_name == "" ? [] : [var.api_domain_name]
  hosted_zone_id            = var.hosted_zone_id
  tags                      = local.tags
}

locals {
  certificate_arn = var.create_dns ? one(module.dns[*].certificate_arn) : var.acm_certificate_arn
  cloudfront_aliases = var.domain_name == "" ? [] : (
    var.api_domain_name == "" ? [var.domain_name] : [var.domain_name, var.api_domain_name]
  )
}

module "cloudfront" {
  source                     = "../../modules/cloudfront"
  count                      = var.enable_cloudfront ? 1 : 0
  name                       = local.name
  frontend_buckets           = module.storage.frontend_buckets
  media_bucket               = module.storage.media_bucket
  aliases                    = local.cloudfront_aliases
  certificate_arn            = local.certificate_arn
  api_origin_domain          = var.cloudfront_api_origin_domain
  api_origin_protocol_policy = var.cloudfront_api_origin_protocol_policy
  tags                       = local.tags
}

resource "aws_route53_record" "app" {
  count   = var.domain_name != "" && var.hosted_zone_id != "" && var.enable_cloudfront ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.cloudfront[0].distribution_domain_name
    zone_id                = module.cloudfront[0].distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api" {
  count   = var.api_domain_name != "" && var.cloudfront_api_origin_domain != "" && var.hosted_zone_id != "" && var.enable_cloudfront ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.api_domain_name
  type    = "A"

  alias {
    name                   = module.cloudfront[0].distribution_domain_name
    zone_id                = module.cloudfront[0].distribution_hosted_zone_id
    evaluate_target_health = false
  }
}
