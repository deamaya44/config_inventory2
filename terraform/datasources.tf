# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Crear el archivo ZIP de la función Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../main.py"
  output_path = "${path.module}/config_inventory_lambda.zip"
}