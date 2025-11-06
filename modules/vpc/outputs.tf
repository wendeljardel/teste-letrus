output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs das subnets do database"
  value       = aws_subnet.database[*].id
}

output "database_subnet_group_name" {
  description = "Nome do DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "availability_zones" {
  description = "Lista de Availability Zones usadas"
  value       = local.azs
}
