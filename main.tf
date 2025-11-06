terraform {
  required_version = ">= 1.0, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(
      var.tags,
      {
        Project     = var.project_name
        Environment = var.environment
      }
    )
  }
}



locals {
  name_prefix = "${var.project_name}-${var.environment}"
  suffix      = "letrus"
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
    }
  )
}

# Módulo de VPC (opcional, pode usar VPC existente)
module "vpc" {
  source = "./modules/vpc"
  count  = var.create_vpc ? 1 : 0

  name_prefix = local.name_prefix
  cidr        = var.vpc_cidr
  azs         = length(var.availability_zones) > 0 ? var.availability_zones : null

  tags = local.common_tags
}

# Data source para VPC existente se não criar nova
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.vpc_id != "" ? var.vpc_id : null
}

locals {
  vpc_id              = var.create_vpc ? module.vpc[0].vpc_id : data.aws_vpc.existing[0].id
  vpc_cidr            = var.create_vpc ? module.vpc[0].vpc_cidr : data.aws_vpc.existing[0].cidr_block
  private_subnet_ids  = var.create_vpc ? module.vpc[0].private_subnet_ids : []
  database_subnet_ids = var.create_vpc ? module.vpc[0].database_subnet_ids : []
  public_subnet_ids   = var.create_vpc ? module.vpc[0].public_subnet_ids : []
}

# Módulo S3
module "s3" {
  source = "./modules/s3"

  name_prefix           = local.name_prefix
  suffix                = local.suffix
  enable_versioning     = var.s3_enable_versioning
  enable_lifecycle      = var.s3_enable_lifecycle
  lifecycle_days_to_ia  = var.s3_lifecycle_days_to_ia
  lifecycle_days_to_glacier = var.s3_lifecycle_days_to_glacier

  tags = local.common_tags
}

# Módulo Aurora
# Security Group para Glue Connection (criado antes dos módulos para evitar dependência circular)
resource "aws_security_group" "glue_connection" {
  name        = "${local.name_prefix}-glue-connection-sg"
  description = "Security group para conexao Glue com Aurora"
  vpc_id      = local.vpc_id

  # Regra de ingress self-referencing (requisito do AWS Glue para conexoes JDBC)
  ingress {
    description = "Allow all inbound traffic from same security group"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Permite saida para qualquer destino (necessario para o Glue acessar o Aurora)
  egress {
    description = "Permitir saida para qualquer destino"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-glue-connection-sg"
    }
  )
}

# Modulo Bastion Host
module "bastion" {
  source = "./modules/bastion"

  name_prefix              = local.name_prefix
  vpc_id                   = local.vpc_id
  public_subnet_id         = local.public_subnet_ids[0]
  instance_type            = "t3.micro"
  ssh_public_key           = var.bastion_ssh_public_key
  allowed_ssh_cidr_blocks  = var.bastion_allowed_ssh_cidr_blocks

  tags = local.common_tags
}

module "aurora" {
  source = "./modules/aurora"

  name_prefix                     = local.name_prefix
  suffix                          = local.suffix
  engine                          = var.aurora_engine
  engine_version                  = var.aurora_engine_version
  instance_class                  = var.aurora_instance_class
  instance_count                  = var.aurora_instance_count
  database_name                   = var.aurora_database_name
  master_username                 = var.aurora_master_username
  master_password                 = var.aurora_master_password
  backup_retention_period         = var.aurora_backup_retention_period
  preferred_backup_window         = var.aurora_preferred_backup_window
  preferred_maintenance_window    = var.aurora_preferred_maintenance_window
  skip_final_snapshot             = var.aurora_skip_final_snapshot
  vpc_id                          = local.vpc_id
  database_subnet_ids             = length(local.database_subnet_ids) > 0 ? local.database_subnet_ids : local.private_subnet_ids
  allow_external_access           = false
  external_access_cidr_blocks     = []
  glue_security_group_ids         = [aws_security_group.glue_connection.id]
  bastion_security_group_id       = module.bastion.bastion_security_group_id

  tags = local.common_tags
}

# Módulo Glue
module "glue" {
  source = "./modules/glue"

  name_prefix              = local.name_prefix
  suffix                   = local.suffix
  jobs                     = var.glue_jobs
  crawlers                 = var.glue_crawlers
  s3_raw_bucket            = module.s3.raw_bucket_name
  s3_processed_bucket      = module.s3.processed_bucket_name
  s3_scripts_bucket        = module.s3.scripts_bucket_name
  glue_role_arn            = module.iam.glue_role_arn
  crawler_role_arn         = module.iam.crawler_role_arn
  aurora_endpoint                  = module.aurora.endpoint
  aurora_port                      = module.aurora.port
  aurora_engine                    = var.aurora_engine == "aurora-postgresql" ? "postgresql" : "mysql"
  aurora_database_name             = var.aurora_database_name
  aurora_security_group_id         = module.aurora.security_group_id
  database_subnet_ids              = local.private_subnet_ids
  aurora_master_username           = var.aurora_master_username
  aurora_master_password           = var.aurora_master_password
  vpc_id                           = local.vpc_id
  glue_connection_security_group_id = aws_security_group.glue_connection.id

  tags = local.common_tags
}

# Data source para account ID
data "aws_caller_identity" "current" {}

# Módulo IAM (criar antes do Glue para ter as roles)
module "iam" {
  source = "./modules/iam"

  name_prefix              = local.name_prefix
  s3_raw_bucket_arn        = module.s3.raw_bucket_arn
  s3_processed_bucket_arn  = module.s3.processed_bucket_arn
  s3_scripts_bucket_arn    = module.s3.scripts_bucket_arn
  glue_database_arn        = "" # Usará padrões genéricos, será atualizado depois se necessário
  aurora_cluster_arn       = module.aurora.cluster_arn

  tags = local.common_tags
}


