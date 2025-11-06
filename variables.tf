variable "project_name" {
  description = "Nome do projeto usado para naming de recursos"
  type        = string
  default     = "data-engineering"
}

variable "environment" {
  description = "Ambiente de deployment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Tags comuns aplicadas a todos os recursos"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "DataEngineering"
  }
}

# S3 Variables
variable "s3_enable_versioning" {
  description = "Habilitar versionamento nos buckets S3"
  type        = bool
  default     = true
}

variable "s3_enable_lifecycle" {
  description = "Habilitar lifecycle policies nos buckets S3"
  type        = bool
  default     = true
}

variable "s3_lifecycle_days_to_ia" {
  description = "Número de dias antes de mover objetos para IA"
  type        = number
  default     = 30
}

variable "s3_lifecycle_days_to_glacier" {
  description = "Número de dias antes de mover objetos para Glacier"
  type        = number
  default     = 90
}

# Aurora Variables
variable "aurora_engine" {
  description = "Engine do Aurora (aurora-postgresql ou aurora-mysql)"
  type        = string
  default     = "aurora-postgresql"
  validation {
    condition     = contains(["aurora-postgresql", "aurora-mysql"], var.aurora_engine)
    error_message = "Aurora engine deve ser 'aurora-postgresql' ou 'aurora-mysql'."
  }
}

variable "aurora_engine_version" {
  description = "Versão do engine Aurora"
  type        = string
  default     = "" # Será definido nos módulos baseado no engine
}

variable "aurora_instance_class" {
  description = "Classe da instância Aurora"
  type        = string
  default     = "db.t3.medium"
}

variable "aurora_instance_count" {
  description = "Número de instâncias no cluster Aurora"
  type        = number
  default     = 2
}

variable "aurora_database_name" {
  description = "Nome do banco de dados inicial"
  type        = string
  default     = "datawarehouse"
}

variable "aurora_master_username" {
  description = "Username do master do Aurora"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "aurora_master_password" {
  description = "Password do master do Aurora"
  type        = string
  sensitive   = true
}

variable "aurora_backup_retention_period" {
  description = "Período de retenção de backups em dias"
  type        = number
  default     = 7
}

variable "aurora_preferred_backup_window" {
  description = "Janela de backup preferida (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "aurora_preferred_maintenance_window" {
  description = "Janela de manutenção preferida (UTC)"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "aurora_skip_final_snapshot" {
  description = "Pular snapshot final ao destruir (não recomendado para prod)"
  type        = bool
  default     = false
}

variable "aurora_allow_external_access" {
  description = "Permitir acesso externo ao Aurora (via DBeaver, etc). Requer subnets públicas."
  type        = bool
  default     = false
}

variable "aurora_external_access_cidr_blocks" {
  description = "CIDR blocks permitidos para acesso externo (ex: [\"0.0.0.0/0\"] para qualquer IP ou [\"SEU_IP/32\"] para IP específico)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "bastion_ssh_public_key" {
  description = "Chave publica SSH para acesso ao Bastion Host"
  type        = string
  default     = ""
}

variable "bastion_allowed_ssh_cidr_blocks" {
  description = "CIDR blocks permitidos para SSH no Bastion Host (ex: [\"SEU_IP/32\"])"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Permitir qualquer IP por padrão (ALTERE PARA SEU IP EM PRODUÇÃO!)
}

# VPC Variables
variable "vpc_id" {
  description = "ID da VPC existente (deixe vazio para criar nova)"
  type        = string
  default     = ""
}

variable "create_vpc" {
  description = "Criar nova VPC ou usar existente"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de Availability Zones"
  type        = list(string)
  default     = []
}

# Glue Variables
variable "glue_jobs" {
  description = "Mapa de jobs do Glue a serem criados"
  type = map(object({
    script_location = string
    python_version  = optional(string, "3")
    glue_version    = optional(string, "4.0")
    max_capacity    = optional(number, 2)
    timeout         = optional(number, 2880)
  }))
  default = {}
}

variable "glue_crawlers" {
  description = "Mapa de crawlers do Glue a serem criados"
  type = map(object({
    s3_paths         = list(string)
    database_name    = optional(string, "")
    schema_change_policy = optional(object({
      update_behavior = optional(string, "UPDATE_IN_DATABASE")
      delete_behavior = optional(string, "LOG")
    }), {})
  }))
  default = {}
}

variable "glue_scripts_bucket" {
  description = "Bucket S3 para armazenar scripts do Glue (deixe vazio para criar)"
  type        = string
  default     = ""
}

