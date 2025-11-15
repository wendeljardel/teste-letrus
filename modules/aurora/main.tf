# Data source para obter versão mais recente se não especificada
data "aws_rds_engine_version" "default" {
  engine  = var.engine == "aurora-postgresql" ? "postgres" : (var.engine == "aurora-mysql" ? "mysql" : var.engine)
  version = var.engine_version != "" ? var.engine_version : null
}

locals {
  # Converter engine Aurora para RDS tradicional (free tier)
  actual_engine             = var.engine == "aurora-postgresql" ? "postgres" : (var.engine == "aurora-mysql" ? "mysql" : var.engine)
  engine_version            = var.engine_version != "" ? var.engine_version : data.aws_rds_engine_version.default.version
  port                      = contains(["aurora-postgresql", "postgres"], var.engine) ? 5432 : 3306
  family                    = data.aws_rds_engine_version.default.parameter_group_family
  instance_identifier       = "${var.name_prefix}-rds-${var.suffix}"
  final_snapshot_identifier = "${var.name_prefix}-rds-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}

# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name       = var.allow_external_access ? "${var.name_prefix}-aurora-subnet-group-public" : "${var.name_prefix}-aurora-subnet-group"
  subnet_ids = var.database_subnet_ids

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name = var.allow_external_access ? "${var.name_prefix}-aurora-subnet-group-public" : "${var.name_prefix}-aurora-subnet-group"
    }
  )
}

# Security Group para RDS
resource "aws_security_group" "aurora" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Security group para RDS instance"
  vpc_id      = var.vpc_id

  # Permite acesso da VPC
  ingress {
    description = "PostgreSQL/MySQL from VPC"
    from_port   = local.port
    to_port     = local.port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  # Permite acesso do Glue Connection (via Security Group)
  ingress {
    description     = "Acesso do Glue Connection"
    from_port       = local.port
    to_port         = local.port
    protocol        = "tcp"
    security_groups = var.glue_security_group_ids
  }

  # Permite acesso do Bastion Host (via Security Group)
  ingress {
    description     = "Acesso do Bastion Host"
    from_port       = local.port
    to_port         = local.port
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
  }

  # Saída liberada para qualquer destino
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-sg"
    }
  )
}


# Data source para VPC (para obter CIDR)
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Parameter Group para RDS tradicional
resource "aws_db_parameter_group" "main" {
  name        = "${var.name_prefix}-rds-params"
  family      = local.family
  description = "Parameter group para RDS ${var.name_prefix}"

  parameter {
    name  = "timezone"
    value = "UTC"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-params"
    }
  )
}

# RDS Instance (substituindo Aurora Cluster para economia - FREE TIER elegível)
# FREE TIER: 750h/mês de db.t3.micro, db.t2.micro ou db.t4g.micro
# FREE TIER: 20GB de storage SSD
# FREE TIER: 20GB de backups
resource "aws_db_instance" "main" {
  identifier     = local.instance_identifier
  engine         = local.actual_engine
  engine_version = local.engine_version
  instance_class = var.instance_class

  # Database configuration
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  # Storage (FREE TIER: 20GB)
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3" # gp3 é mais econômico que gp2
  storage_encrypted     = true

  # Network
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]
  publicly_accessible    = var.allow_external_access
  port                   = local.port

  # Backup (FREE TIER: 1 dia de retenção incluso)
  backup_retention_period  = var.backup_retention_period
  backup_window            = var.preferred_backup_window
  maintenance_window       = var.preferred_maintenance_window
  skip_final_snapshot      = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : local.final_snapshot_identifier

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Monitoring
  enabled_cloudwatch_logs_exports = contains(["postgres", "aurora-postgresql"], var.engine) ? ["postgresql", "upgrade"] : ["error", "general", "slowquery"]
  monitoring_interval             = 0 # Desabilitar enhanced monitoring para economia (custa $0.30/instância/mês)

  # Performance
  performance_insights_enabled = false # Desabilitar para economia (custa extra)

  # High Availability
  multi_az            = false # Desabilitar Multi-AZ em dev para economia (~2x o custo)
  deletion_protection = false

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Copiar tags para snapshots
  copy_tags_to_snapshot = true

  tags = merge(
    var.tags,
    {
      Name = local.instance_identifier
    }
  )
}

