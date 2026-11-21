provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  s3_use_path_style           = true

  endpoints {
    s3          = var.localstack_endpoint
    cloudfront  = var.localstack_endpoint
    ecr         = var.localstack_endpoint
    eks         = var.localstack_endpoint
    rds         = var.localstack_endpoint
    elasticache = var.localstack_endpoint
    iam         = var.localstack_endpoint
    sts         = var.localstack_endpoint
    ec2         = var.localstack_endpoint
    route53     = var.localstack_endpoint
  }

  default_tags {
    tags = {
      Project     = var.project
      Environment = "localstack"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "${var.project}-localstack"
  tags = {
    Project     = var.project
    Environment = "localstack"
  }
}

resource "random_password" "db" {
  length  = 24
  special = false
}

module "network" {
  source             = "../../modules/network"
  name               = local.name
  vpc_cidr           = "10.20.0.0/16"
  az_count           = 2
  enable_nat_gateway = false
  tags               = local.tags
}

module "storage" {
  source        = "../../modules/storage"
  name_prefix   = local.name
  force_destroy = true
  tags          = local.tags
}

module "ecr" {
  source           = "../../modules/ecr"
  repository_names = ["account", "auth", "gateway", "order", "product", "exchange"]
  force_delete     = true
  tags             = local.tags
}

module "rds" {
  source                  = "../../modules/rds"
  count                   = var.enable_rds ? 1 : 0
  identifier              = "${local.name}-postgres"
  vpc_id                  = module.network.vpc_id
  subnet_ids              = module.network.private_subnet_ids
  allowed_cidr_blocks     = [module.network.vpc_cidr]
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  password                = random_password.db.result
  publicly_accessible     = true
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0
  tags                    = local.tags
}

module "elasticache" {
  source              = "../../modules/elasticache"
  count               = var.enable_elasticache ? 1 : 0
  cluster_id          = "${local.name}-redis"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids
  allowed_cidr_blocks = [module.network.vpc_cidr]
  node_type           = "cache.t4g.micro"
  tags                = local.tags
}

module "eks" {
  source               = "../../modules/eks"
  count                = var.enable_eks ? 1 : 0
  cluster_name         = local.name
  vpc_id               = module.network.vpc_id
  subnet_ids           = module.network.private_subnet_ids
  create_node_group    = false
  create_oidc_provider = false
  create_irsa          = false
  media_bucket_arn     = module.storage.media_bucket.arn
  tags                 = local.tags
}

module "cloudfront" {
  source               = "../../modules/cloudfront"
  count                = var.enable_cloudfront ? 1 : 0
  name                 = local.name
  frontend_buckets     = module.storage.frontend_buckets
  media_bucket         = module.storage.media_bucket
  cors_allowed_origins = ["*"]
  tags                 = local.tags
}
