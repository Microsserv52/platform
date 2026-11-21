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
  source        = "../../modules/storage"
  name_prefix   = local.name
  force_destroy = !var.protect_state
  tags          = local.tags
}

module "ecr" {
  source           = "../../modules/ecr"
  repository_names = ["account", "auth", "gateway", "order", "product", "exchange"]
  force_delete     = !var.protect_state
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
  skip_final_snapshot     = !var.protect_state
  deletion_protection     = var.protect_state
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
  source                    = "../../modules/eks"
  enable_ebs_csi            = var.enable_observability
  cluster_name              = local.name
  kubernetes_version        = var.kubernetes_version
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  node_instance_types       = var.node_instance_types
  node_capacity_type        = var.node_capacity_type
  create_cluster_autoscaler = true
  node_desired_size         = var.node_desired_size
  node_min_size             = var.node_min_size
  node_max_size             = var.node_max_size
  media_bucket_arn          = module.storage.media_bucket.arn
  admin_principal_arn       = var.admin_principal_arn
  tags                      = local.tags
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
  cors_allowed_origins       = var.cors_allowed_origins
  certificate_arn            = local.certificate_arn
  api_origin_domain          = var.cloudfront_api_origin_domain != "" ? var.cloudfront_api_origin_domain : aws_lb.gateway.dns_name
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


data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "gateway_nlb" {
  name        = "${local.name}-gateway-nlb"
  description = "CloudFront-only access to the Gateway NLB"
  vpc_id      = module.network.vpc_id

  ingress {
    description     = "HTTP from CloudFront origin-facing ranges"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    description = "Health checks and forwarding to node targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-gateway-nlb" })
}


resource "aws_lb" "gateway" {
  name               = "${local.name}-gateway"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.gateway_nlb.id]
  subnets            = module.network.public_subnet_ids

  enable_deletion_protection = false
  tags                       = merge(local.tags, { Name = "${local.name}-gateway" })
}

resource "aws_lb_target_group" "gateway" {
  name        = "${local.name}-gateway"
  port        = 30080
  protocol    = "TCP"
  vpc_id      = module.network.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(local.tags, { Name = "${local.name}-gateway" })
}

resource "aws_lb_listener" "gateway" {
  load_balancer_arn = aws_lb.gateway.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  tags = merge(local.tags, { Name = "${local.name}-gateway" })
}

resource "aws_autoscaling_attachment" "gateway" {
  autoscaling_group_name = module.eks.node_group_asg_name
  lb_target_group_arn    = aws_lb_target_group.gateway.arn
}

resource "aws_security_group_rule" "gateway_nodes_vpc" {
  type              = "ingress"
  security_group_id = module.eks.eks_cluster_security_group_id
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  cidr_blocks       = [module.network.vpc_cidr]
  description       = "Gateway NodePort from the VPC and NLB health checks"
}

resource "aws_security_group_rule" "gateway_nodes_cloudfront" {
  type              = "ingress"
  security_group_id = module.eks.eks_cluster_security_group_id
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  description       = "Gateway NodePort from CloudFront"
}


resource "aws_security_group_rule" "gateway_nodes_health" {
  type              = "ingress"
  security_group_id = module.eks.eks_cluster_security_group_id
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow NLB health checks to the Gateway NodePort"
}
