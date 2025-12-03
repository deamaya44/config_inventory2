# Guía de Integración con Amazon QuickSight

Esta guía te ayuda a conectar Amazon QuickSight con tu bucket S3 de inventarios de AWS Config.

## 📋 Archivos de Manifiesto

### `manifest.json` - Básico
Manifiesto simple para conectar QuickSight con los archivos CSV de inventario.

### `manifest-detailed.json` - Detallado  
Incluye configuraciones adicionales para manejo de datos y metadatos.

### `manifest-template.json` - Parametrizado
Template que usa variables de Terraform para generar dinámicamente el manifiesto.

## 🚀 Configuración en QuickSight

### Paso 1: Crear Data Source
1. En QuickSight, ve a **Datasets** → **New dataset**
2. Selecciona **S3** como fuente de datos
3. Usa la URL del manifiesto: `s3://aws-config-inventory-028139915738/quicksight/manifest.json`

### Paso 2: Configurar Permisos
El bucket ya tiene los permisos necesarios para QuickSight:
```json
{
  "Sid": "QuickSightAccess",
  "Effect": "Allow", 
  "Principal": {
    "Service": "quicksight.amazonaws.com"
  },
  "Action": [
    "s3:GetObject",
    "s3:GetObjectVersion", 
    "s3:ListBucket"
  ]
}
```

### Paso 3: Crear Dataset
1. Selecciona el manifiesto subido
2. QuickSight detectará automáticamente el esquema CSV
3. Revisa y confirma los tipos de datos

## 📊 Estructura de Datos

Los archivos CSV contienen las siguientes columnas:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `ResourceType` | String | Tipo de recurso AWS (ej: AWS::EC2::Instance) |
| `ResourceId` | String | Identificador único del recurso |
| `ResourceName` | String | Nombre del recurso |
| `SourceAccountId` | String | ID de la cuenta AWS |
| `SourceRegion` | String | Región AWS |

## 📈 Visualizaciones Recomendadas

### 1. Recursos por Tipo
```sql
SELECT ResourceType, COUNT(*) as ResourceCount
FROM inventory_table
GROUP BY ResourceType
ORDER BY ResourceCount DESC
```

### 2. Distribución por Región
```sql
SELECT SourceRegion, ResourceType, COUNT(*) as Count
FROM inventory_table  
GROUP BY SourceRegion, ResourceType
```

### 3. Recursos por Cuenta
```sql
SELECT SourceAccountId, COUNT(*) as TotalResources
FROM inventory_table
GROUP BY SourceAccountId
```

### 4. Timeline de Inventarios
Si tienes múltiples archivos por fecha:
```sql
SELECT 
  DATE_TRUNC('day', file_timestamp) as InventoryDate,
  COUNT(*) as ResourceCount
FROM inventory_table
GROUP BY DATE_TRUNC('day', file_timestamp)
ORDER BY InventoryDate
```

## 🔄 Actualización Automática

### Refresh Programado
1. En tu dataset, configura **Refresh Schedule**
2. Frecuencia recomendada: Diaria (coincide con la Lambda)
3. QuickSight detectará automáticamente nuevos archivos

### Incremental Refresh
Para datasets grandes, configura **Incremental Refresh**:
- Campo de fecha: Usa el timestamp del archivo
- Lookback window: 7 días

## 🎨 Dashboards de Ejemplo

### Dashboard Ejecutivo
- **KPI Cards**: Total de recursos, cuentas, regiones
- **Donut Chart**: Distribución por tipo de recurso  
- **Map**: Distribución geográfica por región
- **Trend Line**: Crecimiento de recursos en el tiempo

### Dashboard Técnico
- **Table**: Lista detallada de recursos
- **Tree Map**: Recursos por cuenta y región
- **Bar Chart**: Top 10 tipos de recursos
- **Heat Map**: Matriz cuenta vs región

## 🔍 Filtros Útiles

### Filtros Recomendados
1. **ResourceType** - Dropdown con todos los tipos
2. **SourceAccountId** - Multi-select para cuentas
3. **SourceRegion** - Multi-select para regiones  
4. **Date Range** - Para filtrar por período

### Filtros Avanzados
```sql
-- Solo recursos de producción (por naming convention)
WHERE ResourceName LIKE '%prod%'

-- Solo recursos críticos
WHERE ResourceType IN (
  'AWS::RDS::DBInstance',
  'AWS::EC2::Instance', 
  'AWS::ELB::LoadBalancer'
)
```

## 🚨 Alertas y Monitoreo

### Alertas Sugeridas
1. **Crecimiento anómalo**: >20% incremento en recursos
2. **Nuevos tipos de recursos**: Recursos no vistos antes
3. **Regiones inusuales**: Recursos en regiones no aprobadas

### Configuración de Alertas
1. Crea **Calculated Fields** para métricas
2. Usa **Conditional Formatting** para highlighting
3. Configura **Email Alerts** en dashboards

## 🔗 URLs de Acceso

Después del despliegue de Terraform:

- **Manifiesto**: `${quicksight_manifest_url}`
- **Datos**: `${quicksight_data_source_url}`
- **Bucket**: `https://s3.console.aws.amazon.com/s3/buckets/aws-config-inventory-028139915738`

## 🛠️ Troubleshooting

### Error: Access Denied
- Verifica que QuickSight tenga permisos en tu cuenta
- Confirma que la política del bucket esté aplicada

### Error: No Data Found  
- Verifica que la Lambda haya ejecutado correctamente
- Confirma que existan archivos CSV en el bucket

### Error: Schema Mismatch
- Revisa que el manifiesto coincida con la estructura CSV
- Actualiza el manifiesto si cambias el código de la Lambda

## 📚 Recursos Adicionales

- [QuickSight S3 Data Sources](https://docs.aws.amazon.com/quicksight/latest/user/supported-manifest-file-format.html)
- [Manifest File Format](https://docs.aws.amazon.com/quicksight/latest/user/supported-manifest-file-format.html)  
- [QuickSight Best Practices](https://aws.amazon.com/quicksight/resources/)

## 🔄 Mantenimiento

### Actualización del Schema
Si agregas campos al inventario:
1. Actualiza `manifest-template.json`
2. Ejecuta `terraform apply` 
3. Refresh el dataset en QuickSight

### Optimización de Performance
- Usa **SPICE** para datasets < 10GB
- Configura **Incremental Refresh** para datasets grandes
- Considera **Direct Query** solo para datos en tiempo real