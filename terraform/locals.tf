locals {
  # Configuración de la función Lambda
  function_config = {
    name         = var.function_name
    runtime      = var.runtime
    timeout      = var.timeout
    memory_size  = var.memory_size
    handler      = "main.lambda_handler"
  }

  # Configuración de AWS Config
  config_settings = {
    region          = data.aws_region.current.name
    aggregator_name = var.aggregator_name
    use_aggregator  = var.use_aggregator
  }

  # Configuración de S3
  s3_config = {
    bucket_name = var.s3_bucket_name
    prefix      = var.s3_key_prefix
  }

  # Configuración de archivos de salida
  output_files = {
    csv_filename          = var.csv_filename
    excel_filename        = var.excel_filename
    summary_filename      = var.summary_filename
  }

  # Configuración de EventBridge
  schedule_config = {
    enabled            = var.enable_schedule
    expression         = var.schedule_expression
    rule_name          = "${var.function_name}-schedule"
    target_id          = "ConfigInventoryTarget"
  }

  # Configuración de CloudWatch
  logging_config = {
    log_group_name     = "/aws/lambda/${var.function_name}"
    retention_days     = var.log_retention_days
  }

  # Variables de entorno para la Lambda
  lambda_environment = {
    # AWS Config settings  
    REGION           = local.config_settings.region
    AGGREGATOR_NAME   = local.config_settings.aggregator_name
    USE_AGGREGATOR    = tostring(local.config_settings.use_aggregator)
    
    # S3 settings
    S3_BUCKET         = aws_s3_bucket.config_inventory.bucket
    S3_KEY_PREFIX     = local.s3_config.prefix
    
    # Output file settings
    CSV_FILENAME      = local.output_files.csv_filename
    EXCEL_FILENAME    = local.output_files.excel_filename
    SUMMARY_FILENAME  = local.output_files.summary_filename
    
    # Additional settings
    ACCOUNT_ID        = data.aws_caller_identity.current.account_id
    ENVIRONMENT       = var.environment
  }

  # Tags comunes
  common_tags = merge(var.tags, {
    Component = "config-inventory"
    Region    = data.aws_region.current.name
    AccountId = data.aws_caller_identity.current.account_id
  })
}