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
  aurora_endpoint          = module.aurora.endpoint
  aurora_port              = module.aurora.port
  aurora_engine            = var.aurora_engine == "aurora-postgresql" ? "postgresql" : "mysql"
  aurora_database_name     = var.aurora_database_name
  aurora_security_group_id = module.aurora.security_group_id
  database_subnet_ids      = length(local.database_subnet_ids) > 0 ? local.database_subnet_ids : local.private_subnet_ids

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


