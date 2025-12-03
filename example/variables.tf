variable "aws_region" {
  description = "Región de AWS donde desplegar los recursos"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Nombre de la función Lambda"
  type        = string
  default     = "config-inventory-prod"
}

variable "s3_bucket_name" {
  description = "Nombre del bucket S3 para almacenar inventarios"
  type        = string
  default     = "aws-inventory-organization-028139915738"
}

variable "aggregator_name" {
  description = "Nombre del Config Aggregator de AWS Control Tower"
  type        = string
  default     = "aws-controltower-ConfigAggregatorForOrganizations"
}

variable "enable_schedule" {
  description = "Habilitar ejecución programada automática"
  type        = bool
  default     = true
}

variable "schedule_expression" {
  description = "Expresión cron para la ejecución programada"
  type        = string
  default     = "cron(0 8 * * ? *)"  # Todos los días a las 8 AM UTC
}

variable "lambda_timeout" {
  description = "Timeout de la Lambda en segundos"
  type        = number
  default     = 600  # 10 minutos para organizaciones grandes
}

variable "lambda_memory_size" {
  description = "Memoria asignada a la Lambda en MB"
  type        = number
  default     = 512
}

variable "lambda_runtime" {
  description = "Runtime de Python para la Lambda"
  type        = string
  default     = "python3.9"
}

variable "log_retention_days" {
  description = "Días de retención para los logs de CloudWatch"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Tags comunes para todos los recursos"
  type        = map(string)
  default = {
    Project     = "AWSInventory"
    Environment = "production"
    ManagedBy   = "Terraform"
    Team        = "Platform"
  }
}