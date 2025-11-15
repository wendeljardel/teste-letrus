"""
ETL Pipeline for Educational Data Processing

This Glue job performs the following operations:
- Reads raw CSV data from S3
- Applies data quality transformations
- Exports processed data to Parquet format
- Loads cleaned data into RDS PostgreSQL database
"""

import sys
import logging
import traceback

import boto3
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.types import IntegerType, DoubleType

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'S3_RAW_BUCKET',
    'S3_PROCESSED_BUCKET',
    'AURORA_CONNECTION_NAME',
    'AURORA_DATABASE_NAME'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

logger.info(f"Iniciando job: {args['JOB_NAME']}")
logger.info(f"Bucket raw: {args['S3_RAW_BUCKET']}")
logger.info(f"Bucket processed: {args['S3_PROCESSED_BUCKET']}")
logger.info(f"Conexão database: {args['AURORA_CONNECTION_NAME']}")

raw_bucket = args['S3_RAW_BUCKET']
processed_bucket = args['S3_PROCESSED_BUCKET']

logger.info("Lendo dados brutos do S3...")

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

logger.info(f"Dados carregados - Escolas: {escolas_df.count()}, Alunos: {alunos_df.count()}, Notas: {notas_df.count()}")

logger.info("Aplicando transformações de dados...")

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

logger.info("Transformações de qualidade de dados concluídas")

logger.info("Escrevendo dados transformados no S3 em formato Parquet...")

escolas_df.write \
    .partitionBy("regiao") \
    .mode("overwrite") \
    .parquet(f"s3://{processed_bucket}/escola/")

alunos_df.write \
    .mode("overwrite") \
    .parquet(f"s3://{processed_bucket}/aluno/")

notas_df.write \
    .partitionBy("disciplina") \
    .mode("overwrite") \
    .parquet(f"s3://{processed_bucket}/nota/")

logger.info("Arquivos Parquet escritos com sucesso no S3")

logger.info("Carregando dados no RDS PostgreSQL...")

aurora_connection_name = args['AURORA_CONNECTION_NAME']
aurora_database_name = args['AURORA_DATABASE_NAME']

escolas_df_rds = escolas_df.drop("created_at", "updated_at")
alunos_df_rds = alunos_df.drop("created_at", "updated_at")
notas_df_rds = notas_df.drop("created_at", "updated_at")

glue_client = boto3.client('glue')
connection = glue_client.get_connection(Name=aurora_connection_name)
connection_properties = connection['Connection']['ConnectionProperties']

jdbc_url = connection_properties['JDBC_CONNECTION_URL']
username = connection_properties['USERNAME']
password = connection_properties['PASSWORD']

logger.info(f"Conectando em: {jdbc_url.split('@')[1] if '@' in jdbc_url else jdbc_url.split('//')[1]}")

connection_props = {
    "user": username,
    "password": password,
    "driver": "org.postgresql.Driver",
    "ssl": "true",
    "sslmode": "require"
}

try:
    logger.info(f"Carregando {escolas_df_rds.count()} registros de escola...")
    escolas_df_rds.write.jdbc(
        url=jdbc_url,
        table="escola",
        mode="append",
        properties=connection_props
    )
    
    logger.info(f"Carregando {alunos_df_rds.count()} registros de aluno...")
    alunos_df_rds.write.jdbc(
        url=jdbc_url,
        table="aluno",
        mode="append",
        properties=connection_props
    )
    
    logger.info(f"Carregando {notas_df_rds.count()} registros de nota...")
    notas_df_rds.write.jdbc(
        url=jdbc_url,
        table="nota",
        mode="append",
        properties=connection_props
    )
    
    logger.info("Todos os dados carregados com sucesso no RDS")
    
except Exception as e:
    logger.error(f"Falha ao carregar dados no database: {str(e)}")
    logger.error(f"Traceback: {traceback.format_exc()}")
    logger.warning("Continuando execução - dados preservados em formato Parquet")

logger.info("Job ETL concluído com sucesso")
logger.info(f"Resumo: Escolas={escolas_df.count()}, Alunos={alunos_df.count()}, Notas={notas_df.count()}")
logger.info(f"Arquivos Parquet salvos em s3://{processed_bucket}/")
logger.info("Dados carregados nas tabelas RDS: escola, aluno, nota")

job.commit()
