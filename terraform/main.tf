

# S3 Bucket para almacenar inventarios de Config
resource "aws_s3_bucket" "config_inventory" {
  bucket        = local.s3_config.bucket_name
  force_destroy = local.s3_config.force_destroy
  
  tags = merge(local.common_tags, {
    Purpose = "AWS Config Inventory Storage"
  })
}

# Versionado del bucket
resource "aws_s3_bucket_versioning" "config_inventory" {
  bucket = aws_s3_bucket.config_inventory.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptación del bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "config_inventory" {
  bucket = aws_s3_bucket.config_inventory.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Bloquear acceso público
resource "aws_s3_bucket_public_access_block" "config_inventory" {
  bucket = aws_s3_bucket.config_inventory.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Política del bucket para Config
resource "aws_s3_bucket_policy" "config_inventory" {
  bucket = aws_s3_bucket.config_inventory.id
  
  policy = templatefile("${path.module}/../iam/policies/s3-bucket-policy.json", {
    bucket_name      = aws_s3_bucket.config_inventory.bucket
    lambda_role_arn  = aws_iam_role.lambda_role.arn
  })
  
  depends_on = [aws_s3_bucket_public_access_block.config_inventory]
}

# Lifecycle configuration para gestión de objetos
resource "aws_s3_bucket_lifecycle_configuration" "config_inventory" {
  bucket = aws_s3_bucket.config_inventory.id

  rule {
    id     = "inventory_lifecycle"
    status = "Enabled"

    filter {
      prefix = "${local.s3_config.prefix}/"
    }

    # Eliminar después de 30 días
    expiration {
      days = 90
    }

    # Limpiar versiones no actuales después de 30 días
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Función Lambda
resource "aws_lambda_function" "config_inventory" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.function_config.name
  role            = aws_iam_role.lambda_role.arn
  handler         = local.function_config.handler
  runtime         = local.function_config.runtime
  timeout         = local.function_config.timeout
  memory_size     = local.function_config.memory_size
  
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = local.lambda_environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy,
    aws_cloudwatch_log_group.lambda_logs,
    aws_s3_bucket_policy.config_inventory,
  ]

  tags = local.common_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = local.logging_config.log_group_name
  retention_in_days = local.logging_config.retention_days
  tags              = local.common_tags
}

# Rol IAM para la función Lambda usando templatefile
resource "aws_iam_role" "lambda_role" {
  name = "${local.function_config.name}-role"

  assume_role_policy = templatefile("${path.module}/../iam/policies/assume-role-policy.json", {
    service_principal = "lambda.amazonaws.com"
  })

  tags = local.common_tags
}

# Política IAM personalizada para Config y S3 usando templatefile
resource "aws_iam_policy" "lambda_config_policy" {
  name        = "${local.function_config.name}-config-policy"
  description = "Política para acceso a AWS Config y S3 para inventario de recursos"

  policy = templatefile("${path.module}/../iam/policies/lambda.json", {
    s3_bucket_name = aws_s3_bucket.config_inventory.bucket
  })

  tags = local.common_tags
}

# Adjuntar política personalizada al rol
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_config_policy.arn
}

# Adjuntar política básica de ejecución de Lambda
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# EventBridge rule para ejecutar la Lambda periódicamente (opcional)
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  count               = local.schedule_config.enabled ? 1 : 0
  name                = local.schedule_config.rule_name
  description         = "Ejecutar inventario de recursos AWS Config"
  schedule_expression = local.schedule_config.expression

  tags = local.common_tags
}

# EventBridge target
resource "aws_cloudwatch_event_target" "lambda_target" {
  count     = local.schedule_config.enabled ? 1 : 0
  rule      = aws_cloudwatch_event_rule.lambda_schedule[0].name
  target_id = local.schedule_config.target_id
  arn       = aws_lambda_function.config_inventory.arn
}

# Permiso para EventBridge invocar la Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  count         = local.schedule_config.enabled ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.config_inventory.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule[0].arn
}

