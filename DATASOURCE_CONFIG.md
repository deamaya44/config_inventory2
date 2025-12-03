# Configuración de Datasource con Archivo Fijo

## 📁 Nueva Estructura de Archivos S3

Con la nueva configuración, los archivos se organizan de la siguiente manera:

### Archivos Actuales (Datasource)
```
s3://aws-config-inventory-028139915738/
├── aws-config-inventory/current/
│   ├── resources.csv              # ← DATASOURCE PRINCIPAL
│   ├── resources_excel.csv        # Versión optimizada para Excel
│   └── summary.json               # Resumen actual
└── quicksight/
    └── manifest.json              # Manifiesto apuntando al archivo fijo
```

### Archivos Históricos (Backup)
```
s3://aws-config-inventory-028139915738/
└── aws-config-inventory/historical/
    ├── resources_20241124_143052.csv
    ├── resources_excel_20241124_143052.csv
    ├── summary_20241124_143052.json
    ├── resources_20241124_143102.csv
    └── ...
```

## ⚙️ Configuración de Programación

### EventBridge Schedule
- **Frecuencia**: Cada 10 minutos
- **Expresión**: `rate(10 minutes)`
- **Estado**: Habilitado por defecto

### Comportamiento de Archivos
1. **Archivo Principal**: Siempre se sobrescribe con el nombre `resources.csv`
2. **Archivo Histórico**: Se crea una copia con timestamp para auditoría
3. **Metadatos**: Incluye LastUpdated y RecordCount

## 📊 Configuración en QuickSight

### Método 1: Usar Manifiesto (Recomendado)
```
URL del Manifiesto: s3://aws-config-inventory-028139915738/quicksight/manifest.json
```

### Método 2: Archivo Directo
```
URL del Archivo: s3://aws-config-inventory-028139915738/aws-config-inventory/current/resources.csv
```

## 🔄 Refresh Automático

### QuickSight SPICE
- Configura **Incremental Refresh**: NO (archivo se sobrescribe)
- Configura **Full Refresh**: SÍ
- Frecuencia recomendada: Cada 15 minutos

### QuickSight Direct Query
- No requiere refresh manual
- Los datos se actualizarán automáticamente

## 📈 Ventajas del Nuevo Sistema

### Para Datasources
✅ **URL consistente**: El datasource siempre apunta al mismo archivo  
✅ **Refresh simple**: No hay que cambiar configuraciones  
✅ **Menor latencia**: No hay que buscar el archivo más reciente  

### Para Auditoría
✅ **Historia completa**: Todos los archivos históricos se conservan  
✅ **Trazabilidad**: Timestamp en cada archivo  
✅ **Metadatos**: Información adicional en S3  

## 🚨 Monitoreo y Alertas

### CloudWatch Metrics Personalizadas
```python
# En la Lambda, agregar métricas
cloudwatch = boto3.client('cloudwatch')
cloudwatch.put_metric_data(
    Namespace='AWS/ConfigInventory',
    MetricData=[
        {
            'MetricName': 'ResourceCount',
            'Value': len(all_resources),
            'Unit': 'Count'
        }
    ]
)
```

### Alertas Recomendadas
1. **Ejecución fallida**: Lambda errors > 0
2. **Datos obsoletos**: LastUpdated > 20 minutos
3. **Cambio drástico**: ResourceCount variación > 20%

## 🔍 URLs de Acceso Rápido

### Consolas AWS
- **Lambda**: `https://us-east-1.console.aws.amazon.com/lambda/home#/functions/config-inventory-lambda`
- **S3 Actual**: `https://s3.console.aws.amazon.com/s3/buckets/aws-config-inventory-028139915738/aws-config-inventory/current/`
- **S3 Histórico**: `https://s3.console.aws.amazon.com/s3/buckets/aws-config-inventory-028139915738/aws-config-inventory/historical/`
- **CloudWatch Logs**: `https://us-east-1.console.aws.amazon.com/cloudwatch/home#logsV2:log-groups/log-group/%2Faws%2Flambda%2Fconfig-inventory-lambda`

### QuickSight
- **Datasets**: `https://us-east-1.quicksight.aws.amazon.com/sn/datasets`
- **Dashboards**: `https://us-east-1.quicksight.aws.amazon.com/sn/dashboards`

## 🛠️ Comandos de Gestión

### Verificar Última Ejecución
```bash
aws s3api head-object \
  --bucket aws-config-inventory-028139915738 \
  --key aws-config-inventory/current/resources.csv \
  --query 'Metadata.LastUpdated'
```

### Listar Archivos Históricos
```bash
aws s3 ls s3://aws-config-inventory-028139915738/aws-config-inventory/historical/ \
  --human-readable --summarize
```

### Invocar Lambda Manualmente
```bash
aws lambda invoke \
  --function-name config-inventory-lambda \
  --log-type Tail \
  response.json && cat response.json
```

### Ver Logs en Tiempo Real
```bash
aws logs tail /aws/lambda/config-inventory-lambda --follow
```

## 📋 Checklist de Configuración

### Después del Despliegue
- [ ] Verificar que EventBridge esté habilitado
- [ ] Confirmar que el primer archivo se haya creado
- [ ] Probar el manifiesto en QuickSight
- [ ] Configurar refresh schedule en QuickSight
- [ ] Crear alertas de monitoreo

### Mantenimiento Mensual
- [ ] Revisar archivos históricos (considerar lifecycle)
- [ ] Verificar métricas de ejecución
- [ ] Actualizar dashboards según nuevos tipos de recursos
- [ ] Revisar costos de S3 storage

## 🔄 Migración desde Sistema Anterior

Si tenías configurado con archivos con timestamp:

1. **En QuickSight**: Actualiza la URL del dataset al manifiesto
2. **Refresh Schedule**: Cambia a Full Refresh
3. **Alertas**: Actualiza las alertas para usar los nuevos paths
4. **Scripts**: Actualiza cualquier script que use las URLs antiguas