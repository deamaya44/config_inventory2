# Ejemplo de uso del módulo Config Inventory Lambda

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Crear bucket S3 si no existe (opcional)
resource "aws_s3_bucket" "inventory_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = false

  tags = {
    Name        = "AWS Config Inventory Bucket"
    Purpose     = "Store AWS resource inventories"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "inventory_bucket_versioning" {
  bucket = aws_s3_bucket.inventory_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "inventory_bucket_encryption" {
  bucket = aws_s3_bucket.inventory_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "inventory_bucket_lifecycle" {
  bucket = aws_s3_bucket.inventory_bucket.id

  rule {
    id     = "delete_old_inventories"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Módulo principal de Config Inventory
module "config_inventory_lambda" {
  source = "./terraform"

  function_name   = var.function_name
  s3_bucket_name  = aws_s3_bucket.inventory_bucket.bucket
  aws_region      = var.aws_region
  
  # Configuración de programación
  enable_schedule     = var.enable_schedule
  schedule_expression = var.schedule_expression
  
  # Configuración de la Lambda
  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size
  runtime     = var.lambda_runtime
  
  # Configuración de Config
  aggregator_name = var.aggregator_name
  
  # Configuración de logs
  log_retention_days = var.log_retention_days
  
  tags = merge(var.common_tags, {
    Component = "config-inventory"
  })

  depends_on = [aws_s3_bucket.inventory_bucket]
}