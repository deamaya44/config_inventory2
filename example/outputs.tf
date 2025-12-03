output "lambda_function_name" {
  description = "Nombre de la función Lambda desplegada"
  value       = module.config_inventory_lambda.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN completo de la función Lambda"
  value       = module.config_inventory_lambda.lambda_function_arn
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 donde se almacenan los inventarios"
  value       = aws_s3_bucket.inventory_bucket.bucket
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.inventory_bucket.arn
}

output "lambda_role_arn" {
  description = "ARN del rol IAM de la Lambda"
  value       = module.config_inventory_lambda.lambda_role_arn
}

output "cloudwatch_log_group" {
  description = "Grupo de logs de CloudWatch para monitoreo"
  value       = module.config_inventory_lambda.cloudwatch_log_group
}

output "eventbridge_rule_name" {
  description = "Nombre de la regla de EventBridge para programación automática"
  value       = module.config_inventory_lambda.eventbridge_rule_name
}

# URLs útiles para monitoreo
output "lambda_console_url" {
  description = "URL de la consola de AWS para la función Lambda"
  value       = "https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions/${module.config_inventory_lambda.lambda_function_name}"
}

output "s3_console_url" {
  description = "URL de la consola de AWS para el bucket S3"
  value       = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.inventory_bucket.bucket}"
}

output "cloudwatch_logs_url" {
  description = "URL de la consola de CloudWatch Logs"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(module.config_inventory_lambda.cloudwatch_log_group, "/", "%2F")}"
}