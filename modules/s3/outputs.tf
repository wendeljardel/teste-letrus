output "raw_bucket_id" {
  description = "ID do bucket S3 para dados brutos"
  value       = aws_s3_bucket.raw.id
}

output "raw_bucket_name" {
  description = "Nome do bucket S3 para dados brutos"
  value       = aws_s3_bucket.raw.id
}

output "raw_bucket_arn" {
  description = "ARN do bucket S3 para dados brutos"
  value       = aws_s3_bucket.raw.arn
}

output "processed_bucket_id" {
  description = "ID do bucket S3 para dados processados"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_name" {
  description = "Nome do bucket S3 para dados processados"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  description = "ARN do bucket S3 para dados processados"
  value       = aws_s3_bucket.processed.arn
}

output "scripts_bucket_id" {
  description = "ID do bucket S3 para scripts"
  value       = aws_s3_bucket.scripts.id
}

output "scripts_bucket_name" {
  description = "Nome do bucket S3 para scripts"
  value       = aws_s3_bucket.scripts.id
}

output "scripts_bucket_arn" {
  description = "ARN do bucket S3 para scripts"
  value       = aws_s3_bucket.scripts.arn
}

