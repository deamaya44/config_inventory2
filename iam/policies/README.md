# Políticas IAM para Config Inventory Lambda

Este directorio contiene las políticas IAM en formato JSON que utiliza el módulo de Terraform mediante `templatefile`.

## Archivos de Políticas

### `assume-role-policy.json`
Política de trust para permitir que servicios de AWS asuman el rol.

**Variables:**
- `${service_principal}` - Servicio que puede asumir el rol (ej: `lambda.amazonaws.com`)

**Uso:**
```hcl
assume_role_policy = templatefile("${path.module}/../iam/policies/assume-role-policy.json", {
  service_principal = "lambda.amazonaws.com"
})
```

### `lambda.json`
Política principal para la función Lambda con permisos para AWS Config y S3.

**Permisos incluidos:**
- `config:ListAggregateDiscoveredResources`
- `config:ListDiscoveredResources`
- `config:DescribeConfigurationRecorderStatus`
- `s3:PutObject` y `s3:PutObjectAcl`

**Variables:**
- `${s3_bucket_name}` - Nombre del bucket S3 de destino

**Uso:**
```hcl
policy = templatefile("${path.module}/../iam/policies/lambda.json", {
  s3_bucket_name = var.s3_bucket_name
})
```

### `cloudwatch-logs-policy.json`
Política específica para escritura de logs en CloudWatch.

**Variables:**
- `${aws_region}` - Región de AWS
- `${account_id}` - ID de la cuenta AWS
- `${function_name}` - Nombre de la función Lambda

**Uso:**
```hcl
policy = templatefile("${path.module}/../iam/policies/cloudwatch-logs-policy.json", {
  aws_region    = var.aws_region
  account_id    = data.aws_caller_identity.current.account_id
  function_name = var.function_name
})
```

### `s3-full-access-policy.json`
Política completa de acceso a S3 (lectura, escritura, eliminación).

**Permisos incluidos:**
- `s3:GetObject`, `s3:PutObject`, `s3:PutObjectAcl`, `s3:DeleteObject`
- `s3:ListBucket`

**Variables:**
- `${s3_bucket_name}` - Nombre del bucket S3

**Uso:**
```hcl
policy = templatefile("${path.module}/../iam/policies/s3-full-access-policy.json", {
  s3_bucket_name = var.s3_bucket_name
})
```

## Ventajas del Uso de Templatefile

1. **Separación de responsabilidades**: Las políticas están separadas del código Terraform
2. **Reutilización**: Las mismas políticas pueden usarse en diferentes módulos
3. **Mantenibilidad**: Más fácil de leer y mantener las políticas JSON
4. **Flexibilidad**: Variables permiten parametrizar las políticas
5. **Versionado**: Las políticas se pueden versionar independientemente

## Mejores Prácticas

- Usar variables descriptivas en los templates
- Documentar qué variables requiere cada política
- Validar las políticas con herramientas como `aws iam simulate-policy`
- Aplicar principio de menor privilegio
- Revisar periódicamente los permisos otorgados

## Ejemplo de Validación

Para validar una política antes del despliegue:

```bash
# Validar sintaxis JSON
jq '.' iam/policies/lambda.json

# Simular política (requiere valores reales)
aws iam simulate-policy \
  --policy-document file://iam/policies/lambda.json \
  --action-names config:ListDiscoveredResources \
  --resource-arns "*"
```