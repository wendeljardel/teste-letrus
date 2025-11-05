variable "name_prefix" {
  description = "Prefixo usado para naming dos buckets"
  type        = string
}

variable "suffix" {
  description = "Suffix único para garantir unicidade dos nomes"
  type        = string
}

variable "enable_versioning" {
  description = "Habilitar versionamento nos buckets"
  type        = bool
  default     = true
}

variable "enable_lifecycle" {
  description = "Habilitar lifecycle policies"
  type        = bool
  default     = true
}

variable "lifecycle_days_to_ia" {
  description = "Dias até mover para Infrequent Access"
  type        = number
  default     = 30
}

variable "lifecycle_days_to_glacier" {
  description = "Dias até mover para Glacier"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags para aplicar aos buckets"
  type        = map(string)
  default     = {}
}

