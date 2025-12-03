# Compresión de Archivos Históricos

Este documento explica cómo funciona la compresión automática de archivos históricos en el inventario de AWS Config.

## 🗜️ ¿Qué se comprime?

**Archivos comprimidos automáticamente:**
- ✅ CSV histórico: `current-inventory_YYYYMMDD_HHMMSS.csv.gz`
- ✅ CSV Excel histórico: `current-inventory-excel_YYYYMMDD_HHMMSS.csv.gz`
- ✅ Resumen JSON histórico: `current-summary_YYYYMMDD_HHMMSS.json.gz`

**Archivos SIN comprimir (para datasources):**
- ❌ `current-inventory.csv` (usado por QuickSight)
- ❌ `current-inventory-excel.csv` (acceso directo)
- ❌ `current-summary.json` (consulta rápida)

## 💾 Ahorro de Espacio

### Compresión típica para archivos CSV/JSON:
- **CSV**: 70-85% de reducción
- **JSON**: 80-90% de reducción
- **Ejemplo**: Archivo de 1.4 MB → ~200-400 KB

### Beneficios:
- **Reducción de costos S3** significativa
- **Transferencias más rápidas**
- **Archivos históricos organizados** y eficientes
- **Retención a largo plazo** más económica

## 📁 Estructura de Archivos

```
s3://bucket/aws-config-inventory/
├── current/                           # Sin comprimir (datasources)
│   ├── current-inventory.csv
│   ├── current-inventory-excel.csv
│   └── current-summary.json
└── historical/                        # Comprimidos (archivo)
    ├── current-inventory_20251125_031442.csv.gz
    ├── current-inventory-excel_20251125_031442.csv.gz
    ├── current-summary_20251125_031442.json.gz
    ├── current-inventory_20251125_032502.csv.gz
    └── ...
```

## 🛠️ Cómo Descomprimir Archivos

### Método 1: Script Python incluido

```bash
# Listar archivos comprimidos disponibles
python scripts/decompress_historical.py list --bucket aws-config-inventory-028139915738

# Descomprimir un archivo específico
python scripts/decompress_historical.py decompress \
  --bucket aws-config-inventory-028139915738 \
  --key aws-config-inventory/historical/current-inventory_20251125_031442.csv.gz \
  --output inventory_20251125.csv
```

### Método 2: AWS CLI + gzip

```bash
# Descargar y descomprimir en un solo comando
aws s3 cp s3://bucket/path/file.csv.gz - | gunzip > file.csv

# O descargar primero, luego descomprimir
aws s3 cp s3://bucket/path/file.csv.gz ./
gunzip file.csv.gz
```

### Método 3: Python programático

```python
import boto3
import gzip

def download_and_decompress(bucket, key, local_file):
    s3 = boto3.client('s3')
    
    # Descargar archivo comprimido
    response = s3.get_object(Bucket=bucket, Key=key)
    compressed_data = response['Body'].read()
    
    # Descomprimir y guardar
    decompressed_data = gzip.decompress(compressed_data)
    with open(local_file, 'wb') as f:
        f.write(decompressed_data)

# Uso
download_and_decompress(
    'aws-config-inventory-028139915738',
    'aws-config-inventory/historical/current-inventory_20251125_031442.csv.gz',
    'inventory.csv'
)
```

## 📊 Metadatos de Compresión

Cada archivo comprimido incluye metadatos:

```json
{
  "original-size": "1458968",
  "compression": "gzip",
  "format": "excel-friendly",
  "description": "CSV optimizado para Excel con Account IDs formateados (comprimido)"
}
```

## 🔍 Verificación de Compresión

Para verificar que la compresión funciona:

```bash
# Ver archivos en S3 con tamaños
aws s3 ls s3://bucket/aws-config-inventory/ --recursive --human-readable

# Ejemplo de output:
# 2025-11-24 22:14:43   1.4 MiB current/current-inventory.csv
# 2025-11-24 22:14:44 400.2 KiB historical/current-inventory_20251125_031442.csv.gz
```

## ⚙️ Configuración Técnica

### En el código Python:
```python
def compress_string_to_gzip(data_string):
    """Comprime un string a formato gzip"""
    data_bytes = data_string.encode('utf-8')
    compressed_buffer = BytesIO()
    
    with gzip.GzipFile(fileobj=compressed_buffer, mode='wb') as gz_file:
        gz_file.write(data_bytes)
    
    compressed_buffer.seek(0)
    return compressed_buffer
```

### Metadatos S3:
- `ContentType`: `application/gzip`
- `ContentEncoding`: `gzip`
- `Metadata`: Información de tamaño original y compresión

## 🚨 Consideraciones Importantes

### ✅ Ventajas:
- **Ahorro significativo de espacio** (70-90%)
- **Reducción de costos S3** a largo plazo
- **Transferencias más rápidas**
- **Archivos actuales sin comprimir** para acceso directo

### ⚠️ Consideraciones:
- **Archivos históricos requieren descompresión** para acceso
- **Ligero overhead de CPU** durante compresión (mínimo)
- **Herramientas deben soportar gzip** (mayoría lo hace)

## 📈 Análisis de Costos

### Ejemplo mensual (30 ejecuciones cada 10 min = 4,320 ejecuciones):
- **Sin compresión**: 4,320 × 1.4 MB = ~6 GB/mes
- **Con compresión**: 4,320 × 0.3 MB = ~1.3 GB/mes
- **Ahorro**: ~78% en costos de almacenamiento S3

### Para retención de 1 año:
- **Sin compresión**: ~72 GB
- **Con compresión**: ~15.6 GB
- **Ahorro anual**: Significativo en cuentas AWS con muchos recursos

## 🔧 Troubleshooting

### Error: "No such file or directory"
```bash
# Verificar que el archivo existe
aws s3 ls s3://bucket/path/file.gz

# Verificar permisos
aws sts get-caller-identity
```

### Error de descompresión:
```bash
# Verificar integridad del archivo
aws s3api head-object --bucket bucket --key path/file.gz
```

### Archivos muy grandes:
```bash
# Para archivos grandes, usar streaming
aws s3 cp s3://bucket/file.gz - | gunzip | head -n 100
```