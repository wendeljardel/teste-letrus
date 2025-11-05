#!/usr/bin/env python3
"""
Script para fazer upload dos datasets sintéticos para o bucket S3.

Requer:
- AWS CLI configurado ou variáveis de ambiente AWS
- boto3 instalado: pip install boto3
"""

import boto3
import sys
from pathlib import Path
from botocore.exceptions import ClientError, NoCredentialsError

def upload_file_to_s3(local_file, bucket_name, s3_key):
    """Faz upload de um arquivo para o S3."""
    s3_client = boto3.client('s3')
    
    try:
        print(f"   📤 Enviando {local_file.name} -> s3://{bucket_name}/{s3_key}")
        s3_client.upload_file(str(local_file), bucket_name, s3_key)
        print(f"   ✅ Upload concluído!")
        return True
    except FileNotFoundError:
        print(f"   ❌ Erro: Arquivo {local_file} não encontrado")
        return False
    except NoCredentialsError:
        print(f"   ❌ Erro: Credenciais AWS não encontradas")
        print(f"      Configure usando: aws configure")
        return False
    except ClientError as e:
        print(f"   ❌ Erro no upload: {e}")
        return False

def main():
    """Função principal."""
    if len(sys.argv) < 2:
        print("📦 Upload de datasets para S3")
        print()
        print("Uso:")
        print(f"  python {sys.argv[0]} <bucket_name>")
        print()
        print("Exemplo:")
        print(f"  python {sys.argv[0]} data-engineering-dev-raw-abc123")
        print()
        print("Ou use os outputs do Terraform:")
        print("  BUCKET=$(terraform output -raw s3_raw_bucket_name)")
        print(f"  python {sys.argv[0]} $BUCKET")
        sys.exit(1)
    
    bucket_name = sys.argv[1]
    
    # Diretório com os dados
    data_dir = Path("data/raw")
    
    if not data_dir.exists():
        print(f"❌ Erro: Diretório {data_dir} não encontrado")
        print("   Execute primeiro: python scripts/generate_synthetic_data.py")
        sys.exit(1)
    
    # Arquivos para upload
    files_to_upload = [
        ("escolas.csv", "escolas/escolas.csv"),
        ("alunos.csv", "alunos/alunos.csv"),
        ("notas.csv", "notas/notas.csv")
    ]
    
    print(f"📤 Fazendo upload para: s3://{bucket_name}/")
    print()
    
    success_count = 0
    for local_file, s3_key in files_to_upload:
        file_path = data_dir / local_file
        
        if not file_path.exists():
            print(f"⚠️  Arquivo {local_file} não encontrado, pulando...")
            continue
        
        if upload_file_to_s3(file_path, bucket_name, s3_key):
            success_count += 1
        print()
    
    print(f"✨ Upload concluído! {success_count}/{len(files_to_upload)} arquivos enviados")
    
    if success_count == len(files_to_upload):
        print()
        print("🔍 Verifique os arquivos no S3:")
        print(f"   aws s3 ls s3://{bucket_name}/ --recursive")

if __name__ == "__main__":
    main()

