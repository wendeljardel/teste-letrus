output "glue_role_arn" {
  description = "ARN da IAM role para Glue Jobs"
  value       = aws_iam_role.glue.arn
}

output "glue_role_name" {
  description = "Nome da IAM role para Glue Jobs"
  value       = aws_iam_role.glue.name
}

output "crawler_role_arn" {
  description = "ARN da IAM role para Glue Crawlers"
  value       = aws_iam_role.crawler.arn
}

output "crawler_role_name" {
  description = "Nome da IAM role para Glue Crawlers"
  value       = aws_iam_role.crawler.name
}

output "glue_service_role_name" {
  description = "Nome da IAM role para serviço Glue (alias)"
  value       = aws_iam_role.glue.name
}

