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
    data_bytes = data_string.encode('utf-8')
    compressed_buffer = BytesIO()
    
    with gzip.GzipFile(fileobj=compressed_buffer, mode='wb') as gz_file:
        gz_file.write(data_bytes)
    
    compressed_buffer.seek(0)
    return compressed_buffer

def lambda_handler(event, context):
    """
    Función Lambda para extraer recursos de AWS Config y guardar en S3
    """
    
    # Configuración desde variables de entorno
    region = os.environ.get('REGION')
    aggregator_name = os.environ.get('AGGREGATOR_NAME')
    s3_bucket = os.environ.get('S3_BUCKET')
    use_aggregator = os.environ.get('USE_AGGREGATOR', 'true').lower() == 'true'
    
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
    
    # Generar CSV con formato para Excel
    if all_resources:
        csv_buffer = StringIO()
        fieldnames = ['ResourceType', 'ResourceId', 'ResourceName', 'SourceAccountId', 'SourceRegion']
        writer = csv.DictWriter(csv_buffer, fieldnames=fieldnames, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        
        excel_resources = []
        for resource in all_resources:
            excel_resource = {
                'ResourceType': str(resource.get('ResourceType', '')),
                'ResourceId': str(resource.get('ResourceId', '')),
                'ResourceName': str(resource.get('ResourceName', '')),
                'SourceAccountId': str(resource.get('SourceAccountId', '')).zfill(12),
                'SourceRegion': str(resource.get('SourceRegion', ''))
            }
            excel_resources.append(excel_resource)
        
        writer.writerows(excel_resources)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        # Generar resumen JSON
        summary = {
            'timestamp': timestamp,
            'last_updated': datetime.now().isoformat(),
            'total_resources': len(all_resources),
            'resources_by_type': dict(resource_count)
        }
        
        # Crear archivo consolidado con CSV y JSON
        consolidated_content = f"""=== AWS CONFIG INVENTORY ===
Timestamp: {timestamp}
Total Resources: {len(all_resources)}

=== SUMMARY (JSON) ===
{json.dumps(summary, indent=2)}

=== INVENTORY DATA (CSV) ===
{csv_buffer.getvalue()}
"""
        
        # Subir versión actual sin comprimir
        s3_key = f'{s3_key_prefix}/current/{csv_filename}'
        
        try:
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
            print(f"✓ CSV actual subido a s3://{s3_bucket}/{s3_key}")
            
            # Subir UNA sola copia histórica comprimida con todo
            historical_filename = f'inventory-complete_{timestamp}.txt.gz'
            s3_key_historical = f'{s3_key_prefix}/historical/{historical_filename}'
            
            compressed_data = compress_string_to_gzip(consolidated_content)
            s3_client.put_object(
                Bucket=s3_bucket,
                Key=s3_key_historical,
                Body=compressed_data.getvalue(),
                ContentType='application/gzip',
                ContentEncoding='gzip',
                Metadata={
                    'original-size': str(len(consolidated_content)),
                    'compression': 'gzip',
                    'contains': 'summary-json-and-csv-data'
                }
            )
            print(f"✓ Archivo histórico consolidado comprimido subido a s3://{s3_bucket}/{s3_key_historical}")
            
        except Exception as e:
            print(f"✗ Error subiendo a S3: {str(e)}")
            raise
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Inventario completado exitosamente',
                'timestamp': timestamp,
                'total_resources': len(all_resources),
                'current_csv': f's3://{s3_bucket}/{s3_key}',
                'historical_consolidated': f's3://{s3_bucket}/{s3_key_historical}',
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


if __name__ == "__main__":
    print("ADVERTENCIA: Configure las variables de entorno requeridas")
    result = lambda_handler({}, None)
    print(json.dumps(result, indent=2))
