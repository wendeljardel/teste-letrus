#!/usr/bin/env python3
"""
Script para fazer upload dos datasets sintéticos para o bucket S3.

Requer:
- AWS CLI configurado ou variáveis de ambiente AWS
- boto3 instalado: pip install boto3
"""

import boto3
import sys
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Tuple
from botocore.exceptions import ClientError, NoCredentialsError

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


@dataclass
class UploadConfig:
    bucket_name: str
    data_dir: Path = field(default_factory=lambda: Path("data/raw"))
    
    files_to_upload: List[Tuple[str, str]] = field(default_factory=lambda: [
        ("escolas.csv", "escolas/escolas.csv"),
        ("alunos.csv", "alunos/alunos.csv"),
        ("notas.csv", "notas/notas.csv")
    ])


@dataclass
class UploadResult:
    success_count: int
    total_count: int
    failed_files: List[str] = field(default_factory=list)
    
    @property
    def is_success(self) -> bool:
        return self.success_count == self.total_count
    
    @property
    def success_rate(self) -> float:
        if self.total_count == 0:
            return 0.0
        return (self.success_count / self.total_count) * 100


class S3Uploader:
    def __init__(self, bucket_name: str):
        self.bucket_name = bucket_name
        self.s3_client = boto3.client('s3')
        self.logger = logging.getLogger(__name__)
    
    def upload_file(self, local_file: Path, s3_key: str) -> bool:
        try:
            self.logger.info(f"Enviando {local_file.name} -> s3://{self.bucket_name}/{s3_key}")
            self.s3_client.upload_file(str(local_file), self.bucket_name, s3_key)
            self.logger.info("Upload concluido")
            return True
        except FileNotFoundError:
            self.logger.error(f"Arquivo {local_file} nao encontrado")
            return False
        except NoCredentialsError:
            self.logger.error("Credenciais AWS nao encontradas. Configure usando: aws configure")
            return False
        except ClientError as e:
            self.logger.error(f"Erro no upload: {e}")
            return False


class S3UploadManager:
    def __init__(self, config: UploadConfig):
        self.config = config
        self.uploader = S3Uploader(config.bucket_name)
        self.logger = logging.getLogger(__name__)
    
    def validate_data_dir(self) -> bool:
        if not self.config.data_dir.exists():
            self.logger.error(f"Diretorio {self.config.data_dir} nao encontrado")
            self.logger.error("Execute primeiro: python scripts/generate_synthetic_data.py")
            return False
        return True
    
    def upload_all(self) -> UploadResult:
        if not self.validate_data_dir():
            sys.exit(1)
        
        self.logger.info(f"Fazendo upload para: s3://{self.config.bucket_name}/")
        
        success_count = 0
        failed_files = []
        
        for local_file, s3_key in self.config.files_to_upload:
            file_path = self.config.data_dir / local_file
            
            if not file_path.exists():
                self.logger.warning(f"Arquivo {local_file} nao encontrado, pulando...")
                failed_files.append(local_file)
                continue
            
            if self.uploader.upload_file(file_path, s3_key):
                success_count += 1
            else:
                failed_files.append(local_file)
        
        result = UploadResult(
            success_count=success_count,
            total_count=len(self.config.files_to_upload),
            failed_files=failed_files
        )
        
        self.logger.info(f"Upload concluido: {result.success_count}/{result.total_count} arquivos enviados")
        
        if result.is_success:
            self.logger.info(f"Verifique os arquivos no S3: aws s3 ls s3://{self.config.bucket_name}/ --recursive")
        
        return result


def print_usage(script_name: str):
    logger.error("Upload de datasets para S3")
    logger.error("Uso: python %s <bucket_name>", script_name)
    logger.error("Exemplo: python %s data-engineering-dev-raw-abc123", script_name)
    logger.error("Ou use os outputs do Terraform:")
    logger.error("  BUCKET=$(terraform output -raw s3_raw_bucket_name)")
    logger.error("  python %s $BUCKET", script_name)


def main():
    if len(sys.argv) < 2:
        print_usage(sys.argv[0])
        sys.exit(1)
    
    bucket_name = sys.argv[1]
    config = UploadConfig(bucket_name=bucket_name)
    manager = S3UploadManager(config)
    result = manager.upload_all()
    
    if not result.is_success:
        sys.exit(1)


if __name__ == "__main__":
    main()
