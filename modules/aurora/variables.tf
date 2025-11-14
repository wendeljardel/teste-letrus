variable "name_prefix" {
  description = "Prefixo usado para naming dos recursos"
  type        = string
}

variable "suffix" {
  description = "Suffix único para garantir unicidade dos nomes"
  type        = string
}

variable "engine" {
  description = "Engine do Aurora (aurora-postgresql ou aurora-mysql)"
  type        = string
}

variable "engine_version" {
  description = "Versão do engine (deixe vazio para usar a mais recente)"
  type        = string
  default     = ""
}

variable "instance_class" {
  description = "Classe da instância Aurora"
  type        = string
  default     = "db.t3.medium"
}

variable "instance_count" {
  description = "Número de instâncias no cluster"
  type        = number
  default     = 2
}

variable "database_name" {
  description = "Nome do banco de dados inicial"
  type        = string
}

variable "master_username" {
  description = "Username do master"
  type        = string
  sensitive   = true
}

variable "master_password" {
  description = "Password do master"
  type        = string
  sensitive   = true
}

variable "backup_retention_period" {
  description = "Período de retenção de backups em dias"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Janela de backup preferida (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Janela de manutenção preferida (UTC)"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "skip_final_snapshot" {
  description = "Pular snapshot final ao destruir"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "database_subnet_ids" {
  description = "IDs das subnets do database"
  type        = list(string)
}

variable "tags" {
  description = "Tags para aplicar aos recursos"
  type        = map(string)
  default     = {}
}

variable "allow_external_access" {
  description = "Permitir acesso externo ao Aurora (via DBeaver, etc)"
  type        = bool
  default     = false
}

variable "external_access_cidr_blocks" {
  description = "CIDR blocks permitidos para acesso externo (ex: [\"0.0.0.0/0\"] para qualquer IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "glue_security_group_ids" {
  description = "IDs dos Security Groups do Glue Connection que precisam acessar o Aurora"
  type        = list(string)
  default     = []
}

variable "bastion_security_group_id" {
  description = "ID do Security Group do Bastion Host"
  type        = string
}

variable "allocated_storage" {
  description = "Storage inicial alocado em GB (FREE TIER: até 20GB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage máximo para autoscaling em GB (0 = desabilitado)"
  type        = number
  default     = 0
}