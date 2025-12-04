locals {
  # Configuración de la función Lambda
  function_config = {
    name         = "config-inventory-lambda"
    runtime      = "python3.9"
    timeout      = 300
    memory_size  = 256
    handler      = "main.lambda_handler"
  }

  # Configuración de AWS Config
  config_settings = {
    region          = data.aws_region.current.name
    aggregator_name = "aws-controltower-ConfigAggregatorForOrganizations"
    use_aggregator  = true
  }

  # Configuración de S3
  s3_config = {
    bucket_name   = "aws-config-inventory-${data.aws_caller_identity.current.account_id}"
    prefix        = "aws-config-inventory"
    force_destroy = false
  }

  # Configuración de archivos de salida
  output_files = {
    csv_filename          = "current-inventory.csv"
    excel_filename        = "current-inventory-excel.csv"
    summary_filename      = "current-summary.json"
  }

  # Configuración de EventBridge
  schedule_config = {
    enabled            = true
    expression         = "cron(0 13,16,21 ? * mon-fri *)"
    rule_name          = "${local.function_config.name}-schedule"
    target_id          = "ConfigInventoryTarget"
  }

  # Configuración de CloudWatch
  logging_config = {
    log_group_name     = "/aws/lambda/${local.function_config.name}"
    retention_days     = 14
  }

  # Entorno
  environment = "prod"

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
    ENVIRONMENT       = local.environment
  }

  # Tags comunes
  common_tags = merge(
    {
      Project     = "AWSInventory"
      Environment = "prod"
      ManagedBy   = "Terraform"
    },
    {
    Component = "config-inventory"
    Region    = data.aws_region.current.name
    AccountId = data.aws_caller_identity.current.account_id
    }
  )
}