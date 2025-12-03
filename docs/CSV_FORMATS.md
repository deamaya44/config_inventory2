# Configuración de Formatos de Salida para AWS Config Inventory

## Problema Identificado

Los valores de Account ID se estaban mostrando en notación científica en Excel:
- `1,2057E+11` en lugar de `120571234567`
- `1,78974E+11` en lugar de `178974567890`

## Soluciones Implementadas

### 1. CSV Principal (`resources_TIMESTAMP.csv`)
- Formato estándar para herramientas de análisis
- Account ID con fórmula Excel: `="123456789012"`
- Compatible con QuickSight y herramientas de BI

### 2. CSV Excel (`resources_excel_TIMESTAMP.csv`)
- Optimizado específicamente para Microsoft Excel
- Account ID con padding de ceros: `012345678901`
- Todas las celdas entrecomilladas (`QUOTE_ALL`)

## Formatos Disponibles

### Formato 1: Fórmula Excel
```csv
"ResourceType","ResourceId","ResourceName","SourceAccountId","SourceRegion"
"AWS::EC2::Instance","i-1234567890abcdef0","MyInstance","=""123456789012""","us-east-1"
```

### Formato 2: Padding con Ceros
```csv
"ResourceType","ResourceId","ResourceName","SourceAccountId","SourceRegion"
"AWS::EC2::Instance","i-1234567890abcdef0","MyInstance","123456789012","us-east-1"
```

## Configuración de Excel

### Para abrir correctamente los CSV:
1. **Método 1 - Importar datos:**
   - Excel → Datos → Obtener datos → Desde archivo → Desde texto/CSV
   - Seleccionar el archivo CSV
   - En "Tipo de datos", cambiar SourceAccountId a "Texto"

2. **Método 2 - Abrir directamente:**
   - Usar el archivo `resources_excel_*.csv`
   - Excel reconocerá automáticamente el formato

### Configuración regional:
- Si usas Excel en español, asegúrate de que el separador decimal sea coma (,)
- El separador de miles debe ser punto (.) o espacio

## Variables de Entorno

Puedes controlar el formato añadiendo variables de entorno a la Lambda:

```json
{
  "CSV_FORMAT": "excel",
  "ACCOUNT_ID_PADDING": "true",
  "QUOTE_ALL_FIELDS": "true"
}
```

## Uso en QuickSight

### Para el CSV principal:
```json
{
  "fileLocations": [
    {
      "URIPrefixes": ["s3://bucket/aws-config-inventory/"],
      "URISuffixes": [".csv"]
    }
  ]
}
```

### Para el CSV Excel:
```json
{
  "fileLocations": [
    {
      "URIPrefixes": ["s3://bucket/aws-config-inventory/"],
      "URISuffixes": ["_excel_.csv"]
    }
  ]
}
```

## Troubleshooting

### Problema: Account ID sigue en notación científica
**Solución:** Usa el archivo `resources_excel_*.csv` y abre con "Importar datos"

### Problema: Caracteres raros en nombres de recursos
**Solución:** Especificar encoding UTF-8 al importar

### Problema: Fechas incorrectas
**Solución:** Los timestamps están en formato ISO 8601 UTC

## Mejores Prácticas

1. **Para análisis en Excel:** Usa `resources_excel_*.csv`
2. **Para QuickSight/BI:** Usa `resources_*.csv`
3. **Para programación:** Usa el JSON summary
4. **Para auditoría:** Conserva ambos formatos

## Automatización Adicional

Puedes crear un script PowerShell/VBA para automatizar la importación en Excel:

```vba
Sub ImportConfigInventory()
    Dim ws As Worksheet
    Set ws = ActiveSheet
    
    With ws.QueryTables.Add(Connection:="TEXT;s3://bucket/file.csv", _
                           Destination:=ws.Range("A1"))
        .TextFileParseType = xlDelimited
        .TextFileCommaDelimiter = True
        .TextFileColumnDataTypes = Array(1, 1, 1, 2, 1) ' 2 = Text for AccountId
        .Refresh
    End With
End Sub
```