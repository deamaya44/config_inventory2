import boto3
import csv
import json
import os
import gzip
from io import StringIO, BytesIO
from datetime import datetime
from collections import defaultdict

def compress_string_to_gzip(data_string):
    """
    Comprime un string a formato gzip y retorna BytesIO
    """
    # Convertir string a bytes
    data_bytes = data_string.encode('utf-8')
    
    # Crear buffer de bytes comprimidos
    compressed_buffer = BytesIO()
    
    # Comprimir datos
    with gzip.GzipFile(fileobj=compressed_buffer, mode='wb') as gz_file:
        gz_file.write(data_bytes)
    
    # Resetear posición del buffer
    compressed_buffer.seek(0)
    return compressed_buffer

def lambda_handler(event, context):
    """
    Función Lambda para extraer recursos de AWS Config y guardar en S3
    
    Variables de entorno requeridas (configuradas por Terraform):
    - REGION: Región de AWS
    - AGGREGATOR_NAME: Nombre del Config Aggregator
    - S3_BUCKET: Bucket de destino
    - USE_AGGREGATOR: Usar aggregator (true/false)
    - CSV_FILENAME: Nombre del archivo CSV principal
    - EXCEL_FILENAME: Nombre del archivo CSV para Excel
    - SUMMARY_FILENAME: Nombre del archivo de resumen JSON
    - S3_KEY_PREFIX: Prefijo para las llaves de S3
    - ACCOUNT_ID: ID de la cuenta AWS
    - ENVIRONMENT: Entorno (dev/prod/staging)
    """
    
    # Configuración desde variables de entorno únicamente
    region = os.environ.get('REGION')
    aggregator_name = os.environ.get('AGGREGATOR_NAME')
    s3_bucket = os.environ.get('S3_BUCKET')
    use_aggregator = os.environ.get('USE_AGGREGATOR', 'true').lower() == 'true'
    
    # Configuración de archivos de salida
    csv_filename = os.environ.get('CSV_FILENAME')
    excel_filename = os.environ.get('EXCEL_FILENAME')
    summary_filename = os.environ.get('SUMMARY_FILENAME')
    s3_key_prefix = os.environ.get('S3_KEY_PREFIX')
    account_id = os.environ.get('ACCOUNT_ID')
    environment = os.environ.get('ENVIRONMENT')
    
    # Validar variables requeridas
    required_vars = {
        'REGION': region,
        'AGGREGATOR_NAME': aggregator_name,
        'S3_BUCKET': s3_bucket,
        'CSV_FILENAME': csv_filename,
        'EXCEL_FILENAME': excel_filename,
        'SUMMARY_FILENAME': summary_filename,
        'S3_KEY_PREFIX': s3_key_prefix,
        'ACCOUNT_ID': account_id
    }
    
    missing_vars = [var for var, value in required_vars.items() if not value]
    if missing_vars:
        error_msg = f"Variables de entorno requeridas faltantes: {', '.join(missing_vars)}"
        print(f"ERROR: {error_msg}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_msg,
                'missing_variables': missing_vars
            })
        }
    
    # Clientes AWS
    config_client = boto3.client('config', region_name=region)
    s3_client = boto3.client('s3')
    
    print(f"Iniciando extracción de recursos...")
    print(f"Event recibido: {json.dumps(event, default=str)}")
    print(f"Variables de entorno - REGION: {os.environ.get('REGION')}")
    print(f"Variables de entorno - AGGREGATOR_NAME: {os.environ.get('AGGREGATOR_NAME')}")
    print(f"Variables de entorno - S3_BUCKET: {os.environ.get('S3_BUCKET')}")
    print(f"Configuración final:")
    print(f"  Región: {region}")
    print(f"  Aggregator: {aggregator_name}")
    print(f"  S3 Bucket: {s3_bucket}")
    print(f"  Use Aggregator: {use_aggregator}")
    
    # Tipos de recursos a extraer
    resource_types = [
        'AWS::EC2::Instance',
        'AWS::EC2::SecurityGroup',
        'AWS::EC2::VPC',
        'AWS::EC2::Subnet',
        'AWS::EC2::Volume',
        'AWS::EC2::NetworkInterface',
        'AWS::EC2::EIP',
        'AWS::EC2::RouteTable',
        'AWS::EC2::InternetGateway',
        'AWS::EC2::NatGateway',
        'AWS::S3::Bucket',
        'AWS::IAM::User',
        'AWS::IAM::Role',
        'AWS::IAM::Policy',
        'AWS::RDS::DBInstance',
        'AWS::RDS::DBCluster',
        'AWS::Lambda::Function',
        'AWS::CloudFormation::Stack',
        'AWS::ECS::Cluster',
        'AWS::ECS::Service',
        'AWS::EKS::Cluster',
        'AWS::ElasticLoadBalancingV2::LoadBalancer',
        'AWS::ElasticLoadBalancingV2::TargetGroup',
        'AWS::DynamoDB::Table',
        'AWS::SNS::Topic',
        'AWS::SQS::Queue',
        'AWS::CloudWatch::Alarm',
        'AWS::KMS::Key',
        'AWS::SecretsManager::Secret',
        'AWS::ECR::Repository',
        'AWS::CodeBuild::Project',
        'AWS::CodePipeline::Pipeline',
        'AWS::CloudFront::Distribution',
        'AWS::ApiGateway::RestApi',
        'AWS::ApiGatewayV2::Api',
        'AWS::ElastiCache::CacheCluster',
        'AWS::Redshift::Cluster',
        'AWS::AutoScaling::AutoScalingGroup',
        'AWS::ElasticBeanstalk::Application',
        'AWS::Backup::BackupPlan',
    ]
    
    # Recolectar recursos
    all_resources = []
    resource_count = defaultdict(int)
    
    for resource_type in resource_types:
        print(f"Procesando: {resource_type}")
        
        try:
            if use_aggregator:
                # Usar aggregator para múltiples cuentas
                paginator = config_client.get_paginator('list_aggregate_discovered_resources')
                page_iterator = paginator.paginate(
                    ConfigurationAggregatorName=aggregator_name,
                    ResourceType=resource_type
                )
                
                for page in page_iterator:
                    resources = page.get('ResourceIdentifiers', [])
                    for resource in resources:
                        all_resources.append({
                            'ResourceType': resource.get('ResourceType', ''),
                            'ResourceId': resource.get('ResourceId', ''),
                            'ResourceName': resource.get('ResourceName', ''),
                            'SourceAccountId': resource.get('SourceAccountId', ''),
                            'SourceRegion': resource.get('SourceRegion', ''),
                        })
                        resource_count[resource_type] += 1
            else:
                # Usar cuenta y región actual
                paginator = config_client.get_paginator('list_discovered_resources')
                page_iterator = paginator.paginate(resourceType=resource_type)
                
                for page in page_iterator:
                    resources = page.get('resourceIdentifiers', [])
                    for resource in resources:
                        all_resources.append({
                            'ResourceType': resource.get('resourceType', ''),
                            'ResourceId': resource.get('resourceId', ''),
                            'ResourceName': resource.get('resourceName', ''),
                            'SourceAccountId': context.invoked_function_arn.split(':')[4],
                            'SourceRegion': resource.get('region', region),
                        })
                        resource_count[resource_type] += 1
            
            if resource_count[resource_type] > 0:
                print(f"  ✓ Encontrados: {resource_count[resource_type]} recursos")
        
        except Exception as e:
            print(f"  ⚠ Error procesando {resource_type}: {str(e)}")
            continue
    
    print(f"\nTotal de recursos encontrados: {len(all_resources)}")
    
    # Generar CSV con formato correcto para Excel
    if all_resources:
        csv_buffer = StringIO()
        fieldnames = ['ResourceType', 'ResourceId', 'ResourceName', 'SourceAccountId', 'SourceRegion']
        writer = csv.DictWriter(csv_buffer, fieldnames=fieldnames, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        
        # Formatear datos para evitar notación científica en Excel
        formatted_resources = []
        for resource in all_resources:
            # Asegurar que SourceAccountId sea tratado como texto
            account_id = str(resource.get('SourceAccountId', ''))
            
            formatted_resource = {
                'ResourceType': str(resource.get('ResourceType', '')),
                'ResourceId': str(resource.get('ResourceId', '')),
                'ResourceName': str(resource.get('ResourceName', '')),
                'SourceAccountId': f'="{account_id}"',  # Fórmula Excel para forzar texto
                'SourceRegion': str(resource.get('SourceRegion', ''))
            }
            formatted_resources.append(formatted_resource)
        
        writer.writerows(formatted_resources)
        
        # Subir a S3 con nombres configurables
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        s3_key = f'{s3_key_prefix}/current/{csv_filename}'
        s3_key_excel = f'{s3_key_prefix}/current/{excel_filename}'
        
        # También guardar copia con timestamp para histórico (comprimidas)
        s3_key_historical = f'{s3_key_prefix}/historical/{csv_filename.replace(".csv", f"_{timestamp}.csv.gz")}'
        excel_s3_key_historical = f'{s3_key_prefix}/historical/{excel_filename.replace(".csv", f"_{timestamp}.csv.gz")}'
        
        try:
            # Subir CSV principal con nombre fijo (datasource)
            s3_client.put_object(
                Bucket=s3_bucket,
                Key=s3_key,
                Body=csv_buffer.getvalue(),
                ContentType='text/csv',
                Metadata={
                    'LastUpdated': timestamp,
                    'RecordCount': str(len(all_resources))
                }
            )
            print(f"✓ CSV actual subido exitosamente a s3://{s3_bucket}/{s3_key}")
            
            # Subir copia histórica comprimida
            compressed_csv = compress_string_to_gzip(csv_buffer.getvalue())
            s3_client.put_object(
                Bucket=s3_bucket,
                Key=s3_key_historical,
                Body=compressed_csv.getvalue(),
                ContentType='application/gzip',
                ContentEncoding='gzip',
                Metadata={
                    'original-size': str(len(csv_buffer.getvalue())),
                    'compression': 'gzip'
                }
            )
            print(f"✓ CSV histórico comprimido subido a s3://{s3_bucket}/{s3_key_historical}")
            
            # Generar versión para Excel sin fórmulas (usando comillas simples)
            excel_csv_buffer = StringIO()
            excel_writer = csv.DictWriter(excel_csv_buffer, fieldnames=fieldnames, quoting=csv.QUOTE_ALL)
            excel_writer.writeheader()
            
            excel_resources = []
            for resource in all_resources:
                excel_resource = {
                    'ResourceType': str(resource.get('ResourceType', '')),
                    'ResourceId': str(resource.get('ResourceId', '')),
                    'ResourceName': str(resource.get('ResourceName', '')),
                    'SourceAccountId': str(resource.get('SourceAccountId', '')).zfill(12),  # Pad con ceros
                    'SourceRegion': str(resource.get('SourceRegion', ''))
                }
                excel_resources.append(excel_resource)
            
            excel_writer.writerows(excel_resources)
            
            # Subir versión Excel actual
            s3_client.put_object(
                Bucket=s3_bucket,
                Key=s3_key_excel,
                Body=excel_csv_buffer.getvalue(),
                ContentType='text/csv',
                Metadata={
                    'format': 'excel-friendly',
                    'LastUpdated': timestamp,
                    'RecordCount': str(len(all_resources))
                }
            )
            print(f"✓ CSV Excel actual subido a s3://{s3_bucket}/{s3_key_excel}")
            
            # Subir versión Excel histórica comprimida
            compressed_excel = compress_string_to_gzip(excel_csv_buffer.getvalue())
            s3_client.put_object(
                Bucket=s3_bucket,
                Key=excel_s3_key_historical,
                Body=compressed_excel.getvalue(),
                ContentType='application/gzip',
                ContentEncoding='gzip',
                Metadata={
                    'format': 'excel-friendly',
                    'description': 'CSV optimizado para Excel con Account IDs formateados (comprimido)',
                    'original-size': str(len(excel_csv_buffer.getvalue())),
                    'compression': 'gzip'
                }
            )
            print(f"✓ CSV Excel histórico comprimido subido a s3://{s3_bucket}/{excel_s3_key_historical}")
            
        except Exception as e:
            print(f"✗ Error subiendo a S3: {str(e)}")
            raise
        
        # Guardar resumen JSON actual y histórico
        summary = {
            'timestamp': timestamp,
            'last_updated': datetime.now().isoformat(),
            'total_resources': len(all_resources),
            'resources_by_type': dict(resource_count),
            'current_csv': f's3://{s3_bucket}/{s3_key}',
            'current_excel_csv': f's3://{s3_bucket}/{s3_key_excel}',
            'historical_csv': f's3://{s3_bucket}/{s3_key_historical}',
            'historical_excel_csv': f's3://{s3_bucket}/{excel_s3_key_historical}'
        }
        
        summary_key_current = f'{s3_key_prefix}/current/{summary_filename}'
        summary_key_historical = f'{s3_key_prefix}/historical/{summary_filename.replace(".json", f"_{timestamp}.json.gz")}'
        
        try:
            # Resumen actual
            s3_client.put_object(
                Bucket=s3_bucket,
                Key=summary_key_current,
                Body=json.dumps(summary, indent=2),
                ContentType='application/json'
            )
            print(f"✓ Resumen actual subido a s3://{s3_bucket}/{summary_key_current}")
            
            # Subir resumen histórico comprimido
            summary_json = json.dumps(summary, indent=2)
            compressed_summary = compress_string_to_gzip(summary_json)
            s3_client.put_object(
                Bucket=s3_bucket,
                Key=summary_key_historical,
                Body=compressed_summary.getvalue(),
                ContentType='application/gzip',
                ContentEncoding='gzip',
                Metadata={
                    'original-size': str(len(summary_json)),
                    'compression': 'gzip'
                }
            )
            print(f"✓ Resumen histórico comprimido subido a s3://{s3_bucket}/{summary_key_historical}")
        except Exception as e:
            print(f"⚠ Error subiendo resumen: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Inventario completado exitosamente',
                'timestamp': timestamp,
                'total_resources': len(all_resources),
                'current_csv': f's3://{s3_bucket}/{s3_key}',
                'current_excel_csv': f's3://{s3_bucket}/{s3_key_excel}',
                'historical_csv_compressed': f's3://{s3_bucket}/{s3_key_historical}',
                'historical_excel_csv_compressed': f's3://{s3_bucket}/{excel_s3_key_historical}',
                'current_summary': f's3://{s3_bucket}/{summary_key_current}',
                'historical_summary_compressed': f's3://{s3_bucket}/{summary_key_historical}',
                'compression_info': {
                    'historical_files_compressed': True,
                    'compression_type': 'gzip',
                    'estimated_space_savings': '70-90%'
                },
                'resources_by_type': dict(resource_count)
            })
        }
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({
                'message': 'No se encontraron recursos',
                'total_resources': 0
            })
        }


# Para pruebas locales (NO USAR - configurar variables de entorno en su lugar)
if __name__ == "__main__":
    print("ADVERTENCIA: Para pruebas locales, configure las variables de entorno requeridas:")
    print("- REGION")
    print("- AGGREGATOR_NAME") 
    print("- S3_BUCKET")
    print("- CSV_FILENAME")
    print("- EXCEL_FILENAME")
    print("- SUMMARY_FILENAME")
    print("- S3_KEY_PREFIX")
    print("- ACCOUNT_ID")
    print("- ENVIRONMENT")
    print("- USE_AGGREGATOR")
    
    # La función ahora requiere variables de entorno, no event parameters
    result = lambda_handler({}, None)
    print(json.dumps(result, indent=2))