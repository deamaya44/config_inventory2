# AWS Config Inventory Lambda

Este módulo de Terraform despliega una función Lambda para generar inventarios de recursos AWS utilizando AWS Config.

## Funcionalidades

- **Función Lambda** que extrae recursos de AWS Config
- **Rol IAM** con permisos mínimos necesarios para Config y S3
- **CloudWatch Logs** para monitoreo y debugging
- **Programación opcional** via EventBridge para ejecución automática
- **Soporte para Config Aggregator** para múltiples cuentas

## Recursos que se crean

- `aws_lambda_function.config_inventory` - Función Lambda principal
- `aws_iam_role.lambda_role` - Rol de ejecución para la Lambda (usando templatefile)
- `aws_iam_policy.lambda_config_policy` - Política personalizada con permisos específicos (usando templatefile)
- `aws_cloudwatch_log_group.lambda_logs` - Grupo de logs
- `aws_cloudwatch_event_rule.lambda_schedule` - (Opcional) Regla de programación
- `aws_cloudwatch_event_target.lambda_target` - (Opcional) Target de EventBridge

## Políticas IAM con Templatefile

Este módulo utiliza `templatefile` para cargar las políticas IAM desde archivos JSON externos, lo que mejora la mantenibilidad y reutilización:

- `../iam/policies/assume-role-policy.json` - Política de assume role parametrizable
- `../iam/policies/lambda.json` - Política principal de la Lambda con variables
- `../iam/policies/cloudwatch-logs-policy.json` - Política específica para CloudWatch Logs
- `../iam/policies/s3-full-access-policy.json` - Política completa de acceso a S3

Las variables disponibles en los templates incluyen:
- `${service_principal}` - Para assume role policy
- `${s3_bucket_name}` - Nombre del bucket S3
- `${aws_region}` - Región de AWS
- `${account_id}` - ID de la cuenta AWS
- `${function_name}` - Nombre de la función Lambda

## Uso

### Básico

```hcl
module "config_inventory" {
  source = "./terraform"
  
  function_name   = "my-config-inventory"
  s3_bucket_name  = "my-inventory-bucket"
  aws_region      = "us-west-2"
}
```

### Con programación automática

```hcl
module "config_inventory" {
  source = "./terraform"
  
  function_name       = "config-inventory-prod"
  s3_bucket_name      = "prod-inventory-bucket"
  enable_schedule     = true
  schedule_expression = "cron(0 6 * * ? *)"  # Diario a las 6 AM UTC
  
  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

## Variables

| Nombre | Descripción | Tipo | Default | Requerido |
|--------|-------------|------|---------|-----------|
| `function_name` | Nombre de la función Lambda | `string` | `"config-inventory-lambda"` | no |
| `s3_bucket_name` | Bucket S3 para guardar inventarios | `string` | `"aws-inventory-organization-028139915738"` | no |
| `aws_region` | Región de AWS | `string` | `"us-east-1"` | no |
| `aggregator_name` | Nombre del Config Aggregator | `string` | `"aws-controltower-ConfigAggregatorForOrganizations"` | no |
| `enable_schedule` | Habilitar ejecución programada | `bool` | `false` | no |
| `schedule_expression` | Expresión de programación | `string` | `"rate(1 day)"` | no |
| `timeout` | Timeout en segundos | `number` | `300` | no |
| `memory_size` | Memoria en MB | `number` | `256` | no |
| `runtime` | Runtime de Python | `string` | `"python3.9"` | no |
| `log_retention_days` | Días de retención de logs | `number` | `14` | no |
| `tags` | Tags para los recursos | `map(string)` | `{}` | no |

## Outputs

| Nombre | Descripción |
|--------|-------------|
| `lambda_function_name` | Nombre de la función Lambda |
| `lambda_function_arn` | ARN de la función Lambda |
| `lambda_role_arn` | ARN del rol IAM |
| `lambda_policy_arn` | ARN de la política IAM |
| `cloudwatch_log_group` | Nombre del grupo de logs |

## Permisos IAM

La Lambda tiene los siguientes permisos:

- **AWS Config:**
  - `config:ListAggregateDiscoveredResources`
  - `config:ListDiscoveredResources`
  - `config:DescribeConfigurationRecorderStatus`

- **Amazon S3:**
  - `s3:PutObject` en el bucket especificado
  - `s3:PutObjectAcl` en el bucket especificado

- **CloudWatch Logs:**
  - Permisos básicos de ejecución de Lambda

## Tipos de recursos soportados

La Lambda extrae información de los siguientes tipos de recursos:

- EC2 (Instancias, Security Groups, VPCs, Subnets, etc.)
- S3 Buckets
- IAM (Users, Roles, Policies)
- RDS (DB Instances, DB Clusters)
- Lambda Functions
- CloudFormation Stacks
- ECS/EKS Clusters
- Load Balancers
- DynamoDB Tables
- Y muchos más...

## Estructura de salida

Los inventarios se guardan en S3 en formato CSV con las siguientes columnas:

- `ResourceType` - Tipo de recurso AWS
- `ResourceId` - ID único del recurso
- `ResourceName` - Nombre del recurso
- `SourceAccountId` - Cuenta donde se encuentra el recurso
- `SourceRegion` - Región donde se encuentra el recurso

También se genera un archivo de resumen en JSON con estadísticas del inventario.

## Ejecución manual

Para ejecutar la Lambda manualmente, usa el siguiente evento de ejemplo:

```json
{
  "region": "us-east-1",
  "aggregator_name": "aws-controltower-ConfigAggregatorForOrganizations",
  "s3_bucket": "my-inventory-bucket",
  "use_aggregator": true
}
```

## Requisitos

- AWS Config debe estar habilitado en las regiones/cuentas que quieras inventariar
- Config Aggregator debe estar configurado para organizaciones multi-cuenta
- El bucket S3 debe existir y tener los permisos apropiados
- Terraform >= 1.0
- AWS Provider >= 5.0