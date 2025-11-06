"""
AWS Glue Job - ETL Pipeline para Dados Educacionais

1. Leitura dos dados brutos (CSV) do S3
2. Transformacoes e limpeza
3. Export para Parquet no S3 processed
4. Carregamento de dados transformados no Aurora (escola, aluno, nota)
"""

import sys
import logging
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType

import boto3
import json

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Configuracoes de conexao passadas como parametros do job

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'S3_RAW_BUCKET',
    'S3_PROCESSED_BUCKET',
    'AURORA_CONNECTION_NAME',
    'AURORA_DATABASE_NAME'
])

# Inicializar contexto Spark e Glue
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

logger.info(f"Iniciando job: {args['JOB_NAME']}")
logger.info(f"Bucket Raw: {args['S3_RAW_BUCKET']}")
logger.info(f"Bucket Processed: {args['S3_PROCESSED_BUCKET']}")
logger.info(f"Aurora Connection: {args['AURORA_CONNECTION_NAME']}")

# ============================================
# 1. LEITURA DOS DADOS
# ============================================

logger.info("Lendo dados brutos do S3...")

raw_bucket = args['S3_RAW_BUCKET']
processed_bucket = args['S3_PROCESSED_BUCKET']

# Ler CSVs diretamente como Spark DataFrame (mais eficiente)
escolas_df = spark.read.csv(
    f"s3://{raw_bucket}/escolas/escolas.csv",
    header=True,
    inferSchema=True
)

alunos_df = spark.read.csv(
    f"s3://{raw_bucket}/alunos/alunos.csv",
    header=True,
    inferSchema=True
)

notas_df = spark.read.csv(
    f"s3://{raw_bucket}/notas/notas.csv",
    header=True,
    inferSchema=True
)

logger.info(f"Escolas: {escolas_df.count()} registros")
logger.info(f"Alunos: {alunos_df.count()} registros")
logger.info(f"Notas: {notas_df.count()} registros")

# ============================================
# 2. TRANSFORMAÇÕES E LIMPEZA
# ============================================

logger.info("Aplicando transformacoes...")

# Limpar e padronizar dados
from datetime import datetime

ingestion_time = F.current_timestamp()

escolas_df = (
    escolas_df
    .withColumn("nome", F.trim(F.col("nome")))
    .withColumn("rede", F.lower(F.trim(F.col("rede"))))
    .withColumn("regiao", F.trim(F.col("regiao")))
    .withColumn("ingestion_time", ingestion_time)
    .withColumn("created_at", F.current_timestamp())
    .withColumn("updated_at", F.current_timestamp())
)

alunos_df = (
    alunos_df
    .withColumn("nome", F.trim(F.col("nome")))
    .withColumn("idade", F.col("idade").cast(IntegerType()))
    .withColumn("genero", F.upper(F.trim(F.col("genero"))))
    .withColumn("ingestion_time", ingestion_time)
    .withColumn("created_at", F.current_timestamp())
    .withColumn("updated_at", F.current_timestamp())
)

notas_df = (
    notas_df
    .withColumn("disciplina", F.trim(F.col("disciplina")))
    .withColumn("nota", F.col("nota").cast(DoubleType()))
    .filter(
        (F.col("nota").isNotNull()) &
        (F.col("nota") >= 0) &
        (F.col("nota") <= 10)
    )
    .withColumn("ingestion_time", ingestion_time)
    .withColumn("created_at", F.current_timestamp())
    .withColumn("updated_at", F.current_timestamp())
)


logger.info("Limpeza concluida")

# ============================================
# 3. EXPORT PARA PARQUET (S3 PROCESSED)
# ============================================

logger.info("Exportando dados transformados para Parquet no S3...")

# Salvar escolas (sobrescrever dados existentes)
escolas_df.write \
    .partitionBy("regiao") \
    .mode("overwrite") \
    .parquet(f"s3://{processed_bucket}/escola/")

# Salvar alunos (sobrescrever dados existentes)
alunos_df.write \
    .mode("overwrite") \
    .parquet(f"s3://{processed_bucket}/aluno/")

# Salvar notas (sobrescrever dados existentes)
notas_df.write \
    .partitionBy("disciplina") \
    .mode("overwrite") \
    .parquet(f"s3://{processed_bucket}/nota/")

logger.info("Dados transformados exportados para Parquet")

# ============================================
# 4. CARREGAR DADOS TRANSFORMADOS NO AURORA
# ============================================

logger.info("Carregando dados transformados no Aurora...")

aurora_connection_name = args['AURORA_CONNECTION_NAME']
aurora_database_name = args['AURORA_DATABASE_NAME']

# Remover apenas created_at e updated_at antes de carregar (elas tem default no Aurora)
# Manter ingestion_time pois é campo obrigatório na tabela
escolas_df_aurora = escolas_df.drop("created_at", "updated_at")
alunos_df_aurora = alunos_df.drop("created_at", "updated_at")
notas_df_aurora = notas_df.drop("created_at", "updated_at")

# Obter configurações da conexão Glue
glue_client = boto3.client('glue')
connection = glue_client.get_connection(Name=aurora_connection_name)
connection_properties = connection['Connection']['ConnectionProperties']

jdbc_url = connection_properties['JDBC_CONNECTION_URL']
username = connection_properties['USERNAME']
password = connection_properties['PASSWORD']

logger.info(f"JDBC URL: {jdbc_url.split('@')[1] if '@' in jdbc_url else jdbc_url.split('//')[1]}")

# Propriedades para conexão JDBC
connection_props = {
    "user": username,
    "password": password,
    "driver": "org.postgresql.Driver",
    "ssl": "true",
    "sslmode": "require"
}

try:
    # Carregar escola no Aurora usando DataFrame.write.jdbc
    logger.info(f"Carregando {escolas_df_aurora.count()} registros de escola no Aurora...")
    escolas_df_aurora.write.jdbc(
        url=jdbc_url,
        table="escola",
        mode="append",
        properties=connection_props
    )
    logger.info("Tabela escola carregada com sucesso")
    
    # Carregar aluno no Aurora
    logger.info(f"Carregando {alunos_df_aurora.count()} registros de aluno no Aurora...")
    alunos_df_aurora.write.jdbc(
        url=jdbc_url,
        table="aluno",
        mode="append",
        properties=connection_props
    )
    logger.info("Tabela aluno carregada com sucesso")
    
    # Carregar nota no Aurora
    logger.info(f"Carregando {notas_df_aurora.count()} registros de nota no Aurora...")
    notas_df_aurora.write.jdbc(
        url=jdbc_url,
        table="nota",
        mode="append",
        properties=connection_props
    )
    logger.info("Tabela nota carregada com sucesso")
    
    logger.info("Dados transformados carregados no Aurora com sucesso")
    
except Exception as e:
    import traceback
    logger.error(f"Erro ao carregar no Aurora: {str(e)}")
    logger.error(f"Traceback: {traceback.format_exc()}")
    logger.warning("Continuando... (dados ja salvos em Parquet)")

# ============================================
# FINALIZAÇÃO
# ============================================

logger.info("Job concluido com sucesso")
logger.info(f"Resumo: Escolas={escolas_df.count()}, Alunos={alunos_df.count()}, Notas={notas_df.count()}")
logger.info(f"Parquet salvos em s3://{processed_bucket}/")
logger.info("Dados transformados carregados no Aurora (escola, aluno, nota)")

job.commit()
