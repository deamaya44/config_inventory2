# AWS Config Inventory Lambda

Una solución completa para generar inventarios automatizados de recursos AWS utilizando AWS Config y Lambda.

## 📋 Descripción

Esta solución despliega una función Lambda que:

- 🔍 **Extrae recursos** de AWS Config usando aggregators para múltiples cuentas
- 📊 **Genera inventarios** en formato CSV con información detallada de recursos
- 📁 **Almacena resultados** en S3 con versionado y lifecycle policies
- ⏰ **Ejecuta automáticamente** mediante programación con EventBridge
- 📈 **Monitorea logs** a través de CloudWatch
- 🔐 **Políticas IAM modulares** usando `templatefile` para máxima flexibilidad

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   EventBridge   │───▶│     Lambda      │───▶│    S3 Bucket    │
│   (Schedule)    │    │  Config Inventory│    │   (Inventories) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   AWS Config    │
                       │   Aggregator    │
                       └─────────────────┘
```

## 📁 Estructura del Proyecto

```
config_inventory/
├── main.py                     # Código principal de la Lambda
├── iam/
│   └── policies/
│       ├── assume-role-policy.json      # Política de trust parametrizable
│       ├── lambda.json                  # Política principal con variables
│       ├── cloudwatch-logs-policy.json  # Política específica para logs
│       ├── s3-full-access-policy.json   # Política completa de S3
│       └── README.md                    # Documentación de políticas
├── terraform/                  # Módulo de Terraform
│   ├── main.tf                # Recursos principales
│   ├── variables.tf           # Variables del módulo
│   ├── outputs.tf             # Outputs del módulo
│   ├── versions.tf            # Versiones de providers
│   └── README.md              # Documentación del módulo
├── example/                    # Ejemplo de uso
│   ├── main.tf                # Configuración de ejemplo
│   ├── variables.tf           # Variables del ejemplo
│   ├── outputs.tf             # Outputs del ejemplo
│   └── terraform.tfvars.example # Plantilla de configuración
├── Makefile                   # Comandos de gestión
└── README.md                  # Este archivo
```

## 🚀 Inicio Rápido

### 1. Configuración inicial

```bash
# Clonar o copiar los archivos del proyecto
cd config_inventory

# Crear archivo de configuración
make setup

# Editar variables según tu entorno
vim example/terraform.tfvars
```

### 2. Configurar variables

Edita `example/terraform.tfvars` con tus valores:

```hcl
aws_region      = "us-east-1"
function_name   = "config-inventory-prod"
s3_bucket_name  = "tu-bucket-de-inventario"
aggregator_name = "tu-config-aggregator"
enable_schedule = true
```

### 3. Desplegar

```bash
# Despliegue completo
make deploy

# O paso a paso
make init
make plan
make apply
```

### 4. Verificar

```bash
# Ver outputs
make outputs

# Invocar manualmente
make invoke

# Ver logs
make logs
```

## ⚙️ Configuración

### Variables principales

| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| `function_name` | Nombre de la Lambda | `config-inventory-lambda` |
| `s3_bucket_name` | Bucket para inventarios | `aws-inventory-organization-*` |
| `enable_schedule` | Ejecución automática | `false` |
| `schedule_expression` | Programación cron | `rate(1 day)` |
| `timeout` | Timeout en segundos | `300` |
| `memory_size` | Memoria en MB | `256` |

### Programación automática

Ejemplos de expresiones de programación:

```hcl
# Diario a las 8 AM UTC
schedule_expression = "cron(0 8 * * ? *)"

# Cada 6 horas
schedule_expression = "rate(6 hours)"

# Lunes a viernes a las 9 AM
schedule_expression = "cron(0 9 ? * MON-FRI *)"
```

## 🗂️ Políticas IAM con Templatefile

Este proyecto utiliza `templatefile` de Terraform para cargar políticas IAM desde archivos JSON externos. Esto proporciona:

- **Separación de responsabilidades**: Políticas separadas del código Terraform
- **Reutilización**: Mismas políticas en diferentes módulos
- **Parametrización**: Variables para hacer políticas flexibles
- **Mantenibilidad**: Más fácil leer y mantener políticas JSON

### Archivos de políticas disponibles:

```
iam/policies/
├── assume-role-policy.json      # Trust policy parametrizable
├── lambda.json                  # Política principal de la Lambda
├── cloudwatch-logs-policy.json  # Permisos específicos de logs
├── s3-full-access-policy.json   # Acceso completo a S3
└── README.md                    # Documentación detallada
```

### Ejemplo de uso:

```hcl
policy = templatefile("${path.module}/../iam/policies/lambda.json", {
  s3_bucket_name = var.s3_bucket_name
})
```

## 🔐 Permisos IAM

La Lambda requiere los siguientes permisos mínimos:

### AWS Config
- `config:ListAggregateDiscoveredResources`
- `config:ListDiscoveredResources`  
- `config:DescribeConfigurationRecorderStatus`

### Amazon S3
- `s3:PutObject` en el bucket de destino
- `s3:PutObjectAcl` en el bucket de destino

### CloudWatch Logs
- Permisos básicos de ejecución de Lambda

## 📊 Recursos Soportados

La Lambda extrae información de 25+ tipos de recursos AWS:

- **EC2**: Instancias, Security Groups, VPCs, Subnets, EIPs, etc.
- **Storage**: S3 Buckets, EBS Volumes
- **Database**: RDS Instances, DynamoDB Tables, ElastiCache
- **Compute**: Lambda Functions, ECS/EKS Clusters
- **Network**: Load Balancers, NAT Gateways, Route Tables
- **IAM**: Users, Roles, Policies
- **Security**: KMS Keys, Secrets Manager
- **DevOps**: CodeBuild, CodePipeline, CloudFormation
- **Y muchos más...**

## 📄 Formato de Salida

### Archivo CSV principal
Ubicación: `s3://bucket/aws-config-inventory/resources_YYYYMMDD_HHMMSS.csv`

Columnas:
- `ResourceType` - Tipo de recurso AWS
- `ResourceId` - ID único del recurso  
- `ResourceName` - Nombre del recurso
- `SourceAccountId` - ID de la cuenta AWS
- `SourceRegion` - Región AWS

### Archivo de resumen JSON
Ubicación: `s3://bucket/aws-config-inventory/summary_YYYYMMDD_HHMMSS.json`

Contiene estadísticas y metadatos del inventario.

## 🛠️ Comandos Útiles

```bash
# Gestión del despliegue
make init          # Inicializar Terraform
make plan          # Ver plan de cambios
make apply         # Aplicar cambios
make destroy       # Eliminar recursos

# Desarrollo y debugging
make validate      # Validar configuración
make fmt           # Formatear código
make lint          # Verificar sintaxis
make test          # Probar localmente

# Operación
make invoke        # Ejecutar manualmente
make logs          # Ver logs en tiempo real
make outputs       # Mostrar outputs
make status        # Estado de recursos
```

## 🔍 Monitoreo

### CloudWatch Logs
- Grupo: `/aws/lambda/{function_name}`
- Retención configurable (default: 14 días)

### Métricas útiles
- Duración de ejecución
- Errores y fallos
- Número de recursos procesados
- Uso de memoria

### Alertas recomendadas
- Fallos de ejecución de la Lambda
- Timeouts frecuentes
- Errores de acceso a S3
- Problemas con Config Aggregator

## 🧪 Pruebas

### Prueba local
```bash
# Ejecutar función localmente
python3 main.py

# O usando make
make test
```

### Prueba en AWS
```bash
# Invocar Lambda desplegada
make invoke

# Con parámetros personalizados
aws lambda invoke \
  --function-name config-inventory-prod \
  --payload '{"region":"us-west-2","use_aggregator":false}' \
  response.json
```

## 📚 Ejemplos de Uso

### Despliegue básico
```hcl
module "config_inventory" {
  source = "./terraform"
  
  function_name   = "mi-inventario"
  s3_bucket_name  = "mi-bucket-inventario"
}
```

### Despliegue para producción
```hcl
module "config_inventory" {
  source = "./terraform"
  
  function_name       = "config-inventory-prod"
  s3_bucket_name      = "prod-inventory-bucket"
  enable_schedule     = true
  schedule_expression = "cron(0 6 * * ? *)"
  timeout             = 600
  memory_size         = 512
  
  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

## 🔧 Troubleshooting

### Errores comunes

1. **Config Aggregator no encontrado**
   - Verificar que el aggregator existe
   - Revisar permisos de la Lambda

2. **Acceso denegado a S3**
   - Verificar política IAM
   - Confirmar que el bucket existe

3. **Timeout de la Lambda**
   - Aumentar timeout en configuración
   - Considerar aumentar memoria

4. **No se encuentran recursos**
   - Verificar que Config esté habilitado
   - Revisar configuración del aggregator

### Logs útiles
```bash
# Ver logs en tiempo real
make logs

# Buscar errores específicos
aws logs filter-log-events \
  --log-group-name "/aws/lambda/config-inventory-prod" \
  --filter-pattern "ERROR"
```

## 📋 Requisitos Previos

- **AWS Config** habilitado en regiones/cuentas objetivo
- **Config Aggregator** configurado (para multi-cuenta)
- **Bucket S3** existente con permisos apropiados
- **Terraform** >= 1.0
- **AWS Provider** >= 5.0
- **AWS CLI** configurado (para operaciones manuales)

## 🤝 Contribuir

1. Fork del proyecto
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit de cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo LICENSE para detalles.

## 🆘 Soporte

Para reportar bugs o solicitar funcionalidades:
- Crear un issue en el repositorio
- Incluir logs relevantes y configuración
- Especificar versiones de Terraform y AWS Provider