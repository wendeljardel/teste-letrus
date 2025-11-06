"""
AWS Glue Job - ETL Pipeline para Dados Educacionais

1. Leitura dos dados brutos (CSV) do S3
2. Transformacoes e limpeza
3. Join das tabelas
4. Agregacoes
5. Export para Parquet no S3 processed
6. Carregamento de dados agregados no Aurora
"""

import sys
import logging
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame

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
    'AURORA_DATABASE_NAME',
    'AURORA_TABLE_NAME'
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
# 1. LEITURA DOS DADOS BRUTOS (CSV)
# ============================================

logger.info("Lendo dados brutos do S3...")

# Ler CSV do S3 usando Glue DynamicFrame
raw_bucket = args['S3_RAW_BUCKET']
processed_bucket = args['S3_PROCESSED_BUCKET']

# Esquemas explícitos para melhor performance
escola_schema = StructType([
    StructField("escola_id", StringType(), True),
    StructField("nome", StringType(), True),
    StructField("rede", StringType(), True),
    StructField("regiao", StringType(), True)
])

aluno_schema = StructType([
    StructField("id", StringType(), True),
    StructField("nome", StringType(), True),
    StructField("idade", IntegerType(), True),
    StructField("genero", StringType(), True),
    StructField("escola_id", StringType(), True)
])

nota_schema = StructType([
    StructField("aluno_id", StringType(), True),
    StructField("disciplina", StringType(), True),
    StructField("nota", DoubleType(), True)
])

# Ler CSVs usando Glue Catalog ou diretamente do S3
escolas_dyf = glueContext.create_dynamic_frame.from_options(
    connection_type="s3",
    connection_options={
        "paths": [f"s3://{raw_bucket}/escolas/escolas.csv"]
    },
    format="csv",
    format_options={
        "withHeader": True,
        "separator": ","
    },
    transformation_ctx="escolas_dyf"
)

alunos_dyf = glueContext.create_dynamic_frame.from_options(
    connection_type="s3",
    connection_options={
        "paths": [f"s3://{raw_bucket}/alunos/alunos.csv"]
    },
    format="csv",
    format_options={
        "withHeader": True,
        "separator": ","
    },
    transformation_ctx="alunos_dyf"
)

notas_dyf = glueContext.create_dynamic_frame.from_options(
    connection_type="s3",
    connection_options={
        "paths": [f"s3://{raw_bucket}/notas/notas.csv"]
    },
    format="csv",
    format_options={
        "withHeader": True,
        "separator": ","
    },
    transformation_ctx="notas_dyf"
)

logger.info(f"Escolas: {escolas_dyf.count()} registros")
logger.info(f"Alunos: {alunos_dyf.count()} registros")
logger.info(f"Notas: {notas_dyf.count()} registros")

# Converter para Spark DataFrame
escolas_df = escolas_dyf.toDF()
alunos_df = alunos_dyf.toDF()
notas_df = notas_dyf.toDF()

# ============================================
# 2. TRANSFORMAÇÕES E LIMPEZA
# ============================================

logger.info("Aplicando transformacoes...")

# Limpar e padronizar
escolas_df = (
    escolas_df
    .withColumn("nome", F.trim(F.col("nome")))
    .withColumn("rede", F.lower(F.trim(F.col("rede"))))
    .withColumn("regiao", F.trim(F.col("regiao")))
)

alunos_df = (
    alunos_df
    .withColumn("nome", F.trim(F.col("nome")))
    .withColumn("genero", F.upper(F.trim(F.col("genero"))))
    .withColumn("idade", F.col("idade").cast(IntegerType()))
)

notas_df = (
    notas_df
    .withColumn("disciplina", F.trim(F.col("disciplina")))
    .withColumn("nota", F.col("nota").cast(DoubleType()))
    # Remover notas invalidas
    .filter(
        (F.col("nota").isNotNull()) &
        (F.col("nota") >= 0) &
        (F.col("nota") <= 10)
    )
)

logger.info("Limpeza concluida")

# ============================================
# 3. JOINS - CRIAR DATASET CONSOLIDADO
# ============================================

logger.info("Fazendo joins das tabelas...")

# Join: alunos + escolas
alunos_escolas_df = alunos_df.join(
    escolas_df,
    alunos_df.escola_id == escolas_df.escola_id,
    "inner"
).select(
    alunos_df["id"].alias("aluno_id"),
    alunos_df["nome"].alias("aluno_nome"),
    alunos_df["idade"],
    alunos_df["genero"],
    escolas_df["escola_id"],
    escolas_df["nome"].alias("escola_nome"),
    escolas_df["rede"].alias("escola_rede"),
    escolas_df["regiao"]
)

# Join: adicionar notas
dados_consolidados_df = alunos_escolas_df.join(
    notas_df,
    alunos_escolas_df.aluno_id == notas_df.aluno_id,
    "inner"
).select(
    alunos_escolas_df["*"],
    notas_df["disciplina"],
    notas_df["nota"]
)

logger.info(f"Dataset consolidado: {dados_consolidados_df.count()} registros")

# ============================================
# 4. AGREGAÇÕES
# ============================================

logger.info("Criando agregacoes...")

# Média geral por aluno
media_alunos_df = (
    notas_df
    .groupBy("aluno_id")
    .agg(
        F.avg("nota").alias("media_geral"),
        F.count("disciplina").alias("num_disciplinas"),
        F.max("nota").alias("nota_maxima"),
        F.min("nota").alias("nota_minima")
    )
)

# Média por disciplina
media_disciplinas_df = (
    notas_df
    .groupBy("disciplina")
    .agg(
        F.avg("nota").alias("media_nota"),
        F.count("aluno_id").alias("num_alunos"),
        F.max("nota").alias("nota_maxima"),
        F.min("nota").alias("nota_minima")
    )
)

# Estatísticas por escola
estatisticas_escolas_df = (
    dados_consolidados_df
    .groupBy("escola_id", "escola_nome", "escola_rede", "regiao")
    .agg(
        F.countDistinct("aluno_id").alias("num_alunos"),
        F.avg("nota").alias("media_geral_escola"),
        F.count("nota").alias("total_notas")
    )
)

# Estatísticas por região
estatisticas_regiao_df = (
    dados_consolidados_df
    .groupBy("regiao")
    .agg(
        F.countDistinct("escola_id").alias("num_escolas"),
        F.countDistinct("aluno_id").alias("num_alunos"),
        F.avg("nota").alias("media_geral_regiao")
    )
)

logger.info("Agregacoes criadas:")
logger.info(f"Média por aluno: {media_alunos_df.count()} registros")
logger.info(f"Média por disciplina: {media_disciplinas_df.count()} registros")
logger.info(f"Estatisticas por escola: {estatisticas_escolas_df.count()} registros")
logger.info(f"Estatisticas por regiao: {estatisticas_regiao_df.count()} registros")

# ============================================
# 5. EXPORT PARA PARQUET (S3 PROCESSED)
# ============================================

logger.info("Exportando para Parquet no S3...")

# Converter para DynamicFrame
dados_consolidados_dyf = DynamicFrame.fromDF(
    dados_consolidados_df,
    glueContext,
    "dados_consolidados_dyf"
)

# Salvar em Parquet particionado por regiao e disciplina
glueContext.write_dynamic_frame.from_options(
    frame=dados_consolidados_dyf,
    connection_type="s3",
    connection_options={
        "path": f"s3://{processed_bucket}/dados_consolidados/",
        "partitionKeys": ["regiao", "disciplina"]
    },
    format="parquet",
    transformation_ctx="write_consolidated"
)

# Salvar agregações também
glueContext.write_dynamic_frame.from_options(
    frame=DynamicFrame.fromDF(media_alunos_df, glueContext, "media_alunos_dyf"),
    connection_type="s3",
    connection_options={
        "path": f"s3://{processed_bucket}/agregacoes/media_alunos/"
    },
    format="parquet",
    transformation_ctx="write_media_alunos"
)

glueContext.write_dynamic_frame.from_options(
    frame=DynamicFrame.fromDF(media_disciplinas_df, glueContext, "media_disciplinas_dyf"),
    connection_type="s3",
    connection_options={
        "path": f"s3://{processed_bucket}/agregacoes/media_disciplinas/"
    },
    format="parquet",
    transformation_ctx="write_media_disciplinas"
)

glueContext.write_dynamic_frame.from_options(
    frame=DynamicFrame.fromDF(estatisticas_escolas_df, glueContext, "estatisticas_escolas_dyf"),
    connection_type="s3",
    connection_options={
        "path": f"s3://{processed_bucket}/agregacoes/estatisticas_escolas/"
    },
    format="parquet",
    transformation_ctx="write_estatisticas_escolas"
)

glueContext.write_dynamic_frame.from_options(
    frame=DynamicFrame.fromDF(estatisticas_regiao_df, glueContext, "estatisticas_regiao_dyf"),
    connection_type="s3",
    connection_options={
        "path": f"s3://{processed_bucket}/agregacoes/estatisticas_regiao/"
    },
    format="parquet",
    transformation_ctx="write_estatisticas_regiao"
)

logger.info("Dados exportados para Parquet")

# ============================================
# 6. CARREGAR DADOS AGREGADOS NO AURORA
# ============================================

logger.info("Carregando dados agregados no Aurora...")

aurora_connection_name = args['AURORA_CONNECTION_NAME']
aurora_database_name = args['AURORA_DATABASE_NAME']

try:
    # Converter DataFrames para DynamicFrames
    media_alunos_dyf = DynamicFrame.fromDF(media_alunos_df, glueContext, "media_alunos_dyf")
    media_disciplinas_dyf = DynamicFrame.fromDF(media_disciplinas_df, glueContext, "media_disciplinas_dyf")
    estatisticas_escolas_dyf = DynamicFrame.fromDF(estatisticas_escolas_df, glueContext, "estatisticas_escolas_dyf")
    estatisticas_regiao_dyf = DynamicFrame.fromDF(estatisticas_regiao_df, glueContext, "estatisticas_regiao_dyf")
    
    # Carregar no Aurora usando Glue JDBC connection
    # Tabela: media_alunos
    glueContext.write_dynamic_frame.from_jdbc_conf(
        frame=media_alunos_dyf,
        catalog_connection=aurora_connection_name,
        connection_options={
            "dbtable": "media_alunos",
            "database": aurora_database_name
        },
        transformation_ctx="write_aurora_media_alunos"
    )
    
    # Tabela: media_disciplinas
    glueContext.write_dynamic_frame.from_jdbc_conf(
        frame=media_disciplinas_dyf,
        catalog_connection=aurora_connection_name,
        connection_options={
            "dbtable": "media_disciplinas",
            "database": aurora_database_name
        },
        transformation_ctx="write_aurora_media_disciplinas"
    )
    
    # Tabela: estatisticas_escolas
    glueContext.write_dynamic_frame.from_jdbc_conf(
        frame=estatisticas_escolas_dyf,
        catalog_connection=aurora_connection_name,
        connection_options={
            "dbtable": "estatisticas_escolas",
            "database": aurora_database_name
        },
        transformation_ctx="write_aurora_estatisticas_escolas"
    )
    
    # Tabela: estatisticas_regiao
    glueContext.write_dynamic_frame.from_jdbc_conf(
        frame=estatisticas_regiao_dyf,
        catalog_connection=aurora_connection_name,
        connection_options={
            "dbtable": "estatisticas_regiao",
            "database": aurora_database_name
        },
        transformation_ctx="write_aurora_estatisticas_regiao"
    )
    
    logger.info("Dados carregados no Aurora")
    
except Exception as e:
    logger.warning(f"Erro ao carregar no Aurora: {str(e)}")
    logger.warning("Continuando... (dados ja salvos em Parquet)")

# ============================================
# FINALIZAÇÃO
# ============================================

logger.info("Job concluido com sucesso")
logger.info(f"Resumo: Dados consolidados={dados_consolidados_df.count()} registros, Parquet salvos em s3://{processed_bucket}/")
logger.info("Dados agregados carregados no Aurora")

job.commit()
