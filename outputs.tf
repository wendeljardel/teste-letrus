# ============================================
# S3 Outputs
# ============================================

output "s3_raw_bucket_name" {
  description = "Nome do bucket S3 para dados brutos"
  value       = module.s3.raw_bucket_name
}

output "s3_raw_bucket_arn" {
  description = "ARN do bucket S3 para dados brutos"
  value       = module.s3.raw_bucket_arn
}

output "s3_processed_bucket_name" {
  description = "Nome do bucket S3 para dados processados"
  value       = module.s3.processed_bucket_name
}

output "s3_processed_bucket_arn" {
  description = "ARN do bucket S3 para dados processados"
  value       = module.s3.processed_bucket_arn
}

output "s3_scripts_bucket_name" {
  description = "Nome do bucket S3 para scripts do Glue"
  value       = module.s3.scripts_bucket_name
}

output "s3_scripts_bucket_arn" {
  description = "ARN do bucket S3 para scripts do Glue"
  value       = module.s3.scripts_bucket_arn
}

# ============================================
# Aurora Outputs
# ============================================

output "aurora_cluster_id" {
  description = "ID do cluster Aurora"
  value       = module.aurora.cluster_id
  sensitive   = false
}

output "aurora_cluster_arn" {
  description = "ARN do cluster Aurora"
  value       = module.aurora.cluster_arn
}

output "aurora_endpoint" {
  description = "Endpoint do cluster Aurora (writer)"
  value       = module.aurora.endpoint
  sensitive   = true
}

output "aurora_reader_endpoint" {
  description = "Endpoint do cluster Aurora (reader)"
  value       = module.aurora.reader_endpoint
  sensitive   = true
}

output "aurora_port" {
  description = "Porta do cluster Aurora"
  value       = module.aurora.port
}

output "aurora_database_name" {
  description = "Nome do banco de dados"
  value       = module.aurora.database_name
}

output "aurora_master_username" {
  description = "Username do master do Aurora"
  value       = module.aurora.master_username
  sensitive   = true
}

output "aurora_master_password" {
  description = "Password do master do Aurora"
  value       = module.aurora.master_password
  sensitive   = true
}

# Bastion Host
output "bastion_public_ip" {
  description = "IP publico do Bastion Host"
  value       = module.bastion.bastion_public_ip
}

output "bastion_ssh_command" {
  description = "Comando SSH para conectar ao Bastion"
  value       = module.bastion.ssh_command
}

output "dbeaver_ssh_tunnel_instructions" {
  description = "Instrucoes para configurar SSH tunnel no DBeaver"
  value       = <<-EOT
  
  === CONFIGURAR SSH TUNNEL NO DBEAVER ===
  
  1. Crie a chave privada em: ~/.ssh/bastion-key.pem
  2. No DBeaver, ao conectar ao banco:
     - Main tab:
       * Host: localhost
       * Port: 5432
       * Database: datawarehouse
       * Username: masteruser
       * Password: ${nonsensitive(module.aurora.master_password)}
     
     - SSH tab:
       * Use SSH Tunnel: ✓
       * Host/IP: ${module.bastion.bastion_public_ip}
       * Port: 22
       * User Name: ec2-user
       * Authentication Method: Public Key
       * Private Key: ~/.ssh/bastion-key.pem
  
  Ou via terminal:
  ssh -i ~/.ssh/bastion-key.pem -N -L 5432:${module.aurora.endpoint}:5432 ec2-user@${module.bastion.bastion_public_ip}
  EOT
}

# ============================================
# Glue Outputs
# ============================================

output "glue_database_name" {
  description = "Nome do database do Glue Data Catalog"
  value       = module.glue.database_name
}

output "glue_database_arn" {
  description = "ARN do database do Glue Data Catalog"
  value       = module.glue.database_arn
}

output "glue_job_names" {
  description = "Nomes dos jobs do Glue criados"
  value       = module.glue.job_names
}

output "glue_crawler_names" {
  description = "Nomes dos crawlers do Glue criados"
  value       = module.glue.crawler_names
}

output "glue_connection_name" {
  description = "Nome da conexão do Glue com Aurora"
  value       = module.glue.connection_name
}

# ============================================
# IAM Outputs
# ============================================

output "glue_role_arn" {
  description = "ARN da IAM role para jobs do Glue"
  value       = module.iam.glue_role_arn
}

output "crawler_role_arn" {
  description = "ARN da IAM role para crawlers do Glue"
  value       = module.iam.crawler_role_arn
}

output "glue_service_role_name" {
  description = "Nome da IAM role para serviço do Glue"
  value       = module.iam.glue_service_role_name
}

# ============================================
# Network Outputs
# ============================================

output "vpc_id" {
  description = "ID da VPC"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = var.create_vpc ? module.vpc[0].private_subnet_ids : []
}

output "database_subnet_ids" {
  description = "IDs das subnets do database"
  value       = var.create_vpc ? module.vpc[0].database_subnet_ids : []
}

# ============================================
# General Outputs
# ============================================

output "project_name" {
  description = "Nome do projeto"
  value       = var.project_name
}

output "environment" {
  description = "Ambiente de deployment"
  value       = var.environment
}

output "region" {
  description = "Região AWS"
  value       = var.region
}

