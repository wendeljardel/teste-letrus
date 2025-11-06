variable "name_prefix" {
  description = "Prefixo usado para naming dos recursos"
  type        = string
}

variable "s3_raw_bucket_arn" {
  description = "ARN do bucket S3 para dados brutos"
  type        = string
}

variable "s3_processed_bucket_arn" {
  description = "ARN do bucket S3 para dados processados"
  type        = string
}

variable "s3_scripts_bucket_arn" {
  description = "ARN do bucket S3 para scripts"
  type        = string
}

variable "glue_database_arn" {
  description = "ARN do database do Glue Data Catalog (pode ser um padrão)"
  type        = string
  default     = ""
}

variable "aurora_cluster_arn" {
  description = "ARN do cluster Aurora"
  type        = string
}

variable "tags" {
  description = "Tags para aplicar aos recursos"
  type        = map(string)
  default     = {}
}
