variable "name_prefix" {
  description = "Prefixo usado para naming dos recursos"
  type        = string
}

variable "suffix" {
  description = "Suffix único para garantir unicidade dos nomes"
  type        = string
}

variable "jobs" {
  description = "Mapa de jobs do Glue a serem criados"
  type = map(object({
    script_location   = string
    python_version    = optional(string, "3")
    glue_version      = optional(string, "4.0")
    worker_type       = optional(string, "G.1X") # G.1X = 1 DPU (mínimo para ETL)
    number_of_workers = optional(number, 2)      # 2 workers × 1 DPU = 2 DPU total
    timeout           = optional(number, 2880)
  }))
  default = {}
}

variable "crawlers" {
  description = "Mapa de crawlers do Glue a serem criados"
  type = map(object({
    s3_paths      = list(string)
    database_name = optional(string, "")
    schema_change_policy = optional(object({
      update_behavior = optional(string, "UPDATE_IN_DATABASE")
      delete_behavior = optional(string, "LOG")
    }), {})
  }))
  default = {}
}

variable "s3_raw_bucket" {
  description = "Nome do bucket S3 para dados brutos"
  type        = string
}

variable "s3_processed_bucket" {
  description = "Nome do bucket S3 para dados processados"
  type        = string
}

variable "s3_scripts_bucket" {
  description = "Nome do bucket S3 para scripts"
  type        = string
}

variable "glue_role_arn" {
  description = "ARN da IAM role para Glue Jobs"
  type        = string
}

variable "crawler_role_arn" {
  description = "ARN da IAM role para Glue Crawlers"
  type        = string
}

variable "aurora_endpoint" {
  description = "Endpoint do cluster Aurora"
  type        = string
}

variable "aurora_security_group_id" {
  description = "ID do security group do Aurora (usado para permitir acesso do Glue)"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "glue_connection_security_group_id" {
  description = "ID do Security Group para a conexão Glue com Aurora"
  type        = string
}

variable "database_subnet_ids" {
  description = "IDs das subnets do database"
  type        = list(string)
}

variable "aurora_port" {
  description = "Porta do cluster Aurora"
  type        = number
}

variable "aurora_engine" {
  description = "Engine do Aurora (postgresql ou mysql)"
  type        = string
  default     = "postgresql"
}

variable "aurora_database_name" {
  description = "Nome do banco de dados Aurora"
  type        = string
}

variable "aurora_master_username" {
  description = "Username do master do Aurora"
  type        = string
  sensitive   = true
}

variable "aurora_master_password" {
  description = "Password do master do Aurora"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags para aplicar aos recursos"
  type        = map(string)
  default     = {}
}
