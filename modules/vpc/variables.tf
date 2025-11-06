variable "name_prefix" {
  description = "Prefixo usado para naming dos recursos"
  type        = string
}

variable "cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Lista de Availability Zones (null para usar as default da região)"
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "Tags para aplicar aos recursos"
  type        = map(string)
  default     = {}
}

