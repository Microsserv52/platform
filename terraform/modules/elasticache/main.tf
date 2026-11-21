resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.cluster_id}-subnets"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.cluster_id}-subnets", ManagedBy = "terraform" })
}

resource "aws_security_group" "this" {
  name        = "${var.cluster_id}-redis"
  description = "Redis access for ${var.cluster_id}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis within the VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.cluster_id}-redis", ManagedBy = "terraform" })
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = var.cluster_id
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_nodes      = 1
  parameter_group_name = var.parameter_group_name
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.this.id]
  apply_immediately    = true

  tags = merge(var.tags, { Name = var.cluster_id, ManagedBy = "terraform" })
}
