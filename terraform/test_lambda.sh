#!/bin/bash

# Script para probar la función Lambda de Config Inventory

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧪 Probando Lambda Config Inventory${NC}"
echo "=================================="

# Obtener nombre de la función desde Terraform
FUNCTION_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "config-inventory-lambda")
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

echo -e "📋 Función Lambda: ${GREEN}$FUNCTION_NAME${NC}"
if [ ! -z "$BUCKET_NAME" ]; then
    echo -e "🪣 Bucket S3: ${GREEN}$BUCKET_NAME${NC}"
fi

echo ""
echo -e "${YELLOW}1. Verificando que la función existe...${NC}"
if aws lambda get-function --function-name $FUNCTION_NAME >/dev/null 2>&1; then
    echo -e "✅ ${GREEN}Función Lambda encontrada${NC}"
else
    echo -e "❌ ${RED}Función Lambda no encontrada${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}2. Invocando función Lambda...${NC}"

# Crear evento de prueba
cat > /tmp/test_event.json << EOF
{
  "region": "us-east-1",
  "use_aggregator": true
}
EOF

# Invocar función
echo "Invocando función (esto puede tomar varios minutos)..."
if aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload file:///tmp/test_event.json \
    --log-type Tail \
    /tmp/lambda_response.json > /tmp/lambda_invoke.log 2>&1; then
    
    echo -e "✅ ${GREEN}Invocación exitosa${NC}"
    
    # Mostrar respuesta
    echo ""
    echo -e "${YELLOW}📤 Respuesta de la Lambda:${NC}"
    cat /tmp/lambda_response.json | python3 -m json.tool 2>/dev/null || cat /tmp/lambda_response.json
    
    # Mostrar logs si están disponibles
    if grep -q "LogResult" /tmp/lambda_invoke.log; then
        echo ""
        echo -e "${YELLOW}📋 Logs de ejecución:${NC}"
        grep "LogResult" /tmp/lambda_invoke.log | cut -d'"' -f4 | base64 --decode
    fi
    
else
    echo -e "❌ ${RED}Error en la invocación${NC}"
    cat /tmp/lambda_invoke.log
    exit 1
fi

echo ""
echo -e "${YELLOW}3. Verificando archivos generados en S3...${NC}"
if [ ! -z "$BUCKET_NAME" ]; then
    echo "Listando objetos recientes en el bucket..."
    if aws s3 ls s3://$BUCKET_NAME/aws-config-inventory/ --recursive | tail -10; then
        echo -e "✅ ${GREEN}Archivos encontrados en S3${NC}"
    else
        echo -e "⚠️  ${YELLOW}No se encontraron archivos recientes (puede ser normal si es la primera ejecución)${NC}"
    fi
else
    echo -e "⚠️  ${YELLOW}No se pudo determinar el nombre del bucket${NC}"
fi

echo ""
echo -e "${YELLOW}4. Verificando logs de CloudWatch...${NC}"
LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
echo "Obteniendo logs recientes del grupo: $LOG_GROUP"

if aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP >/dev/null 2>&1; then
    echo -e "✅ ${GREEN}Grupo de logs encontrado${NC}"
    
    # Obtener logs recientes
    echo "Logs de las últimas 10 líneas:"
    aws logs tail $LOG_GROUP --since 10m --format short | tail -10 || echo "No hay logs recientes"
else
    echo -e "⚠️  ${YELLOW}Grupo de logs no encontrado${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Prueba completada!${NC}"

# Limpiar archivos temporales
rm -f /tmp/test_event.json /tmp/lambda_response.json /tmp/lambda_invoke.log

echo ""
echo -e "${YELLOW}💡 Comandos útiles:${NC}"
echo "  • Ver logs en tiempo real: aws logs tail $LOG_GROUP --follow"
echo "  • Listar archivos S3: aws s3 ls s3://$BUCKET_NAME/aws-config-inventory/ --recursive"
echo "  • Invocar manualmente: aws lambda invoke --function-name $FUNCTION_NAME response.json"