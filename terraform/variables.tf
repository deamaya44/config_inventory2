variable "function_name" {
  description = "Nombre de la función Lambda"
  type        = string
  default     = "config-inventory-lambda"
}

variable "runtime" {
  description = "Runtime de la función Lambda"
  type        = string
  default     = "python3.9"
}

variable "timeout" {
  description = "Timeout de la función Lambda en segundos"
  type        = number
  default     = 300
}

variable "memory_size" {
  description = "Memoria asignada a la función Lambda en MB"
  type        = number
  default     = 256
}

variable "aws_region" {
  description = "Región de AWS donde se ejecutará la Lambda"
  type        = string
  default     = "us-east-1"
}

variable "aggregator_name" {
  description = "Nombre del Config Aggregator"
  type        = string
  default     = "aws-controltower-ConfigAggregatorForOrganizations"
}

variable "s3_bucket_name" {
  description = "Nombre del bucket S3 donde se guardarán los inventarios"
  type        = string
  default     = "aws-config-inventory-028139915738"
}

variable "s3_force_destroy" {
  description = "Permite eliminar el bucket S3 aunque contenga objetos"
  type        = bool
  default     = false
}

variable "s3_key_prefix" {
  description = "Prefijo para los objetos en S3"
  type        = string
  default     = "aws-config-inventory"
}

variable "use_aggregator" {
  description = "Usar Config Aggregator para múltiples cuentas"
  type        = bool
  default     = true
}

variable "csv_filename" {
  description = "Nombre del archivo CSV principal"
  type        = string
  default     = "current-inventory.csv"
}

variable "excel_filename" {
  description = "Nombre del archivo CSV compatible con Excel"
  type        = string
  default     = "current-inventory-excel.csv"
}

variable "summary_filename" {
  description = "Nombre del archivo de resumen JSON"
  type        = string
  default     = "current-summary.json"
}

variable "log_retention_days" {
  description = "Días de retención para los logs de CloudWatch"
  type        = number
  default     = 14
}

variable "enable_schedule" {
  description = "Habilitar ejecución programada de la Lambda"
  type        = bool
  default     = true
}

variable "schedule_expression" {
  description = "Expresión de programación para EventBridge (formato cron o rate)"
  type        = string
  default     = "cron(0 13,16,21 ? * mon-fri *)"
}

variable "environment" {
  description = "Entorno de despliegue (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Tags a aplicar a todos los recursos"
  type        = map(string)
  default = {
    Project     = "AWSInventory"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}