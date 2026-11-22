provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = var.project
  tags = {
    Project     = var.project
    Environment = "staging"
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
  enable_nat_gateway = var.enable_nat_gateway
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
  identifier              = "${local.name}-postgres"
  vpc_id                  = module.network.vpc_id
  subnet_ids              = module.network.private_subnet_ids
  allowed_cidr_blocks     = [module.network.vpc_cidr]
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  password                = random_password.db.result
  publicly_accessible     = false
  multi_az                = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1
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
  enable_ebs_csi      = true
  cluster_name        = local.name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_capacity_type  = var.node_capacity_type
  node_desired_size   = 1
  node_min_size       = 1
  node_max_size       = 1
  media_bucket_arn    = module.storage.media_bucket.arn
  admin_principal_arn = var.admin_principal_arn
  tags                = local.tags
}
