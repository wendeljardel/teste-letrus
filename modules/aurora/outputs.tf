output "cluster_id" {
  description = "ID da instância RDS"
  value       = aws_db_instance.main.identifier
}

output "cluster_arn" {
  description = "ARN da instância RDS"
  value       = aws_db_instance.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint da instância RDS (writer)"
  value       = aws_db_instance.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Endpoint da instância RDS (reader) - mesmo que endpoint em instância única"
  value       = aws_db_instance.main.endpoint
}

output "endpoint" {
  description = "Endpoint da instância RDS (alias para cluster_endpoint)"
  value       = aws_db_instance.main.address
}

output "reader_endpoint" {
  description = "Reader endpoint da instância RDS - mesmo que endpoint em instância única"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Porta da instância RDS"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.main.db_name
}

output "master_username" {
  description = "Username do master"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "master_password" {
  description = "Password do master"
  value       = var.master_password
  sensitive   = true
}

output "security_group_id" {
  description = "ID do security group do RDS"
  value       = aws_security_group.aurora.id
}

