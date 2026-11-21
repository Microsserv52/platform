resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.identifier}-subnets", ManagedBy = "terraform" })
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-postgres"
  description = "PostgreSQL access for ${var.identifier}"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL within the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.identifier}-postgres", ManagedBy = "terraform" })
}

resource "aws_db_instance" "this" {
  identifier                = var.identifier
  engine                    = "postgres"
  engine_version            = var.engine_version
  instance_class            = var.instance_class
  allocated_storage         = var.allocated_storage
  storage_encrypted         = true
  db_name                   = var.db_name
  username                  = var.username
  password                  = var.password
  db_subnet_group_name      = aws_db_subnet_group.this.name
  vpc_security_group_ids    = [aws_security_group.this.id]
  publicly_accessible       = var.publicly_accessible
  multi_az                  = var.multi_az
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final"
  deletion_protection       = var.deletion_protection
  backup_retention_period   = var.backup_retention_period
  apply_immediately         = true

  tags = merge(var.tags, { Name = var.identifier, ManagedBy = "terraform" })
}
