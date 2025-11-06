output "cluster_id" {
  description = "ID do cluster Aurora"
  value       = aws_rds_cluster.aurora.cluster_identifier
}

output "cluster_arn" {
  description = "ARN do cluster Aurora"
  value       = aws_rds_cluster.aurora.arn
}

output "cluster_endpoint" {
  description = "Endpoint do cluster Aurora (writer)"
  value       = aws_rds_cluster.aurora.endpoint
}

output "cluster_reader_endpoint" {
  description = "Endpoint do cluster Aurora (reader)"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "endpoint" {
  description = "Endpoint do cluster Aurora (alias para cluster_endpoint)"
  value       = aws_rds_cluster.aurora.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint do cluster Aurora"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "port" {
  description = "Porta do cluster Aurora"
  value       = aws_rds_cluster.aurora.port
}

output "database_name" {
  description = "Nome do banco de dados"
  value       = aws_rds_cluster.aurora.database_name
}

output "master_username" {
  description = "Username do master"
  value       = aws_rds_cluster.aurora.master_username
  sensitive   = true
}

output "master_password" {
  description = "Password do master"
  value       = var.master_password
  sensitive   = true
}

output "security_group_id" {
  description = "ID do security group do Aurora"
  value       = aws_security_group.aurora.id
}

