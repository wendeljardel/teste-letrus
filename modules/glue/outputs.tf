output "database_name" {
  description = "Nome do Glue Data Catalog database"
  value       = aws_glue_catalog_database.main.name
}

output "database_arn" {
  description = "ARN do Glue Data Catalog database"
  value       = aws_glue_catalog_database.main.arn
}

output "connection_name" {
  description = "Nome da conexão Glue com Aurora"
  value       = aws_glue_connection.aurora.name
}

output "connection_arn" {
  description = "ARN da conexão Glue com Aurora"
  value       = aws_glue_connection.aurora.arn
}

output "job_names" {
  description = "Mapa de nomes dos jobs do Glue criados"
  value       = { for k, v in aws_glue_job.main : k => v.name }
}

output "job_arns" {
  description = "Mapa de ARNs dos jobs do Glue criados"
  value       = { for k, v in aws_glue_job.main : k => v.arn }
}

output "crawler_names" {
  description = "Mapa de nomes dos crawlers do Glue criados"
  value       = { for k, v in aws_glue_crawler.main : k => v.name }
}

