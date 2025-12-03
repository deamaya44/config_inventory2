output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.config_inventory.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.config_inventory.arn
}

output "lambda_invoke_arn" {
  description = "ARN para invocar la función Lambda"
  value       = aws_lambda_function.config_inventory.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN del rol IAM de la función Lambda"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_role_name" {
  description = "Nombre del rol IAM de la función Lambda"
  value       = aws_iam_role.lambda_role.name
}

output "lambda_policy_arn" {
  description = "ARN de la política IAM personalizada"
  value       = aws_iam_policy.lambda_config_policy.arn
}

output "cloudwatch_log_group" {
  description = "Nombre del grupo de logs de CloudWatch"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "eventbridge_rule_name" {
  description = "Nombre de la regla de EventBridge (si está habilitada)"
  value       = var.enable_schedule ? aws_cloudwatch_event_rule.lambda_schedule[0].name : null
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 creado"
  value       = aws_s3_bucket.config_inventory.bucket
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3 creado"
  value       = aws_s3_bucket.config_inventory.arn
}

output "s3_bucket_domain_name" {
  description = "Nombre de dominio del bucket S3"
  value       = aws_s3_bucket.config_inventory.bucket_domain_name
}

output "quicksight_manifest_url" {
  description = "URL del manifiesto para QuickSight"
  value       = "s3://${aws_s3_bucket.config_inventory.bucket}/${aws_s3_object.quicksight_manifest.key}"
}

output "quicksight_data_source_url" {
  description = "URL de la fuente de datos para QuickSight"
  value       = "s3://${aws_s3_bucket.config_inventory.bucket}/aws-config-inventory/"
}