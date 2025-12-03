#!/usr/bin/env python3
"""
Script para descomprimir archivos históricos del inventario de AWS Config
"""

import gzip
import boto3
import argparse
from pathlib import Path

def decompress_s3_file(bucket_name, s3_key, output_file=None):
    """
    Descarga y descomprime un archivo .gz desde S3
    
    Args:
        bucket_name (str): Nombre del bucket S3
        s3_key (str): Key del archivo en S3
        output_file (str): Archivo de salida (opcional)
    """
    s3_client = boto3.client('s3')
    
    try:
        # Descargar archivo comprimido
        print(f"Descargando s3://{bucket_name}/{s3_key}")
        response = s3_client.get_object(Bucket=bucket_name, Key=s3_key)
        
        # Descomprimir contenido
        compressed_content = response['Body'].read()
        decompressed_content = gzip.decompress(compressed_content)
        
        # Determinar archivo de salida
        if not output_file:
            # Remover .gz y usar nombre base
            output_file = Path(s3_key).name.replace('.gz', '')
        
        # Escribir archivo descomprimido
        with open(output_file, 'wb') as f:
            f.write(decompressed_content)
        
        print(f"✓ Archivo descomprimido guardado como: {output_file}")
        print(f"✓ Tamaño original: {len(decompressed_content):,} bytes")
        print(f"✓ Tamaño comprimido: {len(compressed_content):,} bytes")
        print(f"✓ Ratio de compresión: {(1 - len(compressed_content)/len(decompressed_content))*100:.1f}%")
        
        return output_file
        
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return None

def list_compressed_files(bucket_name, prefix="aws-config-inventory/historical/"):
    """
    Lista archivos comprimidos disponibles en S3
    
    Args:
        bucket_name (str): Nombre del bucket S3
        prefix (str): Prefijo para buscar archivos
    """
    s3_client = boto3.client('s3')
    
    try:
        print(f"Listando archivos comprimidos en s3://{bucket_name}/{prefix}")
        print("-" * 80)
        
        paginator = s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name, Prefix=prefix)
        
        compressed_files = []
        for page in pages:
            if 'Contents' in page:
                for obj in page['Contents']:
                    if obj['Key'].endswith('.gz'):
                        size_mb = obj['Size'] / (1024 * 1024)
                        print(f"📁 {obj['Key']}")
                        print(f"   📊 Tamaño: {size_mb:.2f} MB")
                        print(f"   📅 Fecha: {obj['LastModified']}")
                        print()
                        compressed_files.append(obj['Key'])
        
        print(f"Total de archivos comprimidos: {len(compressed_files)}")
        return compressed_files
        
    except Exception as e:
        print(f"✗ Error listando archivos: {str(e)}")
        return []

def main():
    parser = argparse.ArgumentParser(
        description="Gestionar archivos comprimidos del inventario AWS Config"
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Comandos disponibles')
    
    # Comando para listar archivos
    list_parser = subparsers.add_parser('list', help='Listar archivos comprimidos')
    list_parser.add_argument('--bucket', required=True, help='Nombre del bucket S3')
    list_parser.add_argument('--prefix', default='aws-config-inventory/historical/', 
                           help='Prefijo de búsqueda')
    
    # Comando para descomprimir archivo
    decompress_parser = subparsers.add_parser('decompress', help='Descomprimir archivo')
    decompress_parser.add_argument('--bucket', required=True, help='Nombre del bucket S3')
    decompress_parser.add_argument('--key', required=True, help='Key del archivo en S3')
    decompress_parser.add_argument('--output', help='Archivo de salida (opcional)')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    if args.command == 'list':
        list_compressed_files(args.bucket, args.prefix)
    
    elif args.command == 'decompress':
        decompress_s3_file(args.bucket, args.key, args.output)

if __name__ == "__main__":
    main()