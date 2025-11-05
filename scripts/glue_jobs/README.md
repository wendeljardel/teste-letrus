# AWS Glue Jobs - ETL Pipeline

Este diretório contém os scripts para os jobs do AWS Glue que processam os dados sintéticos.

## Estrutura

```
scripts/glue_jobs/
├── etl_pipeline.py          # Job principal de ETL
├── create_aurora_tables.sql # Script SQL para criar tabelas no Aurora
└── README.md                # Este arquivo
```

## Job Principal: ETL Pipeline

O job `etl_pipeline.py` realiza o seguinte fluxo:

1. **Leitura**: Lê CSVs do bucket S3 raw
2. **Transformação**: Limpa e padroniza os dados
3. **Join**: Une as tabelas (escolas, alunos, notas)
4. **Agregação**: Cria estatísticas agregadas
5. **Export Parquet**: Salva dados processados em Parquet no S3 processed
6. **Load Aurora**: Carrega dados agregados no Aurora PostgreSQL

## Preparação

### 1. Criar Tabelas no Aurora

Antes de executar o job pela primeira vez, crie as tabelas no Aurora:

```bash
# Obter endpoint do Aurora
AURORA_ENDPOINT=$(terraform output -raw aurora_endpoint)

# Conectar e executar script SQL
psql -h $AURORA_ENDPOINT -U admin -d datawarehouse -f scripts/glue_jobs/create_aurora_tables.sql
```

OU via AWS Console:
- Conecte ao Aurora via RDS Query Editor ou cliente PostgreSQL
- Execute o conteúdo de `create_aurora_tables.sql`

### 2. Upload do Script para S3

```bash
# Obter bucket de scripts
SCRIPTS_BUCKET=$(terraform output -raw s3_scripts_bucket_name)

# Criar diretório e fazer upload
aws s3 mkdir s3://$SCRIPTS_BUCKET/scripts/
aws s3 cp scripts/glue_jobs/etl_pipeline.py s3://$SCRIPTS_BUCKET/scripts/
```

### 3. Configurar Glue Job no Terraform

O job já está configurado no Terraform, mas você pode verificar/ajustar em `terraform.tfvars`:

```hcl
glue_jobs = {
  "etl-pipeline" = {
    script_location = "s3://data-engineering-dev-scripts-XXX/scripts/etl_pipeline.py"
    python_version  = "3"
    glue_version    = "4.0"
    max_capacity    = 2
    timeout         = 2880
  }
}
```

## Parâmetros do Job

O job espera os seguintes parâmetros (configurados automaticamente pelo Terraform):

- `S3_RAW_BUCKET`: Nome do bucket S3 com dados brutos
- `S3_PROCESSED_BUCKET`: Nome do bucket S3 para dados processados
- `AURORA_CONNECTION_NAME`: Nome da conexão Glue com Aurora
- `AURORA_DATABASE_NAME`: Nome do banco de dados no Aurora
- `AURORA_TABLE_NAME`: Prefixo para nomes de tabelas (opcional)

## Executando o Job

### Via AWS CLI

```bash
# Iniciar job
aws glue start-job-run \
  --job-name data-engineering-dev-etl-pipeline \
  --arguments '{
    "--S3_RAW_BUCKET": "data-engineering-dev-raw-XXX",
    "--S3_PROCESSED_BUCKET": "data-engineering-dev-processed-XXX",
    "--AURORA_CONNECTION_NAME": "data-engineering-dev-aurora-connection",
    "--AURORA_DATABASE_NAME": "datawarehouse"
  }'
```

### Via Console AWS

1. Acesse AWS Glue > Jobs
2. Selecione o job `data-engineering-dev-etl-pipeline`
3. Clique em "Run job"
4. Verifique os logs em CloudWatch

### Via Terraform Output

Após aplicar o Terraform, você pode usar os outputs:

```bash
# Obter nome do job
JOB_NAME=$(terraform output -json glue_job_names | jq -r '."etl-pipeline"')

# Executar job
aws glue start-job-run --job-name $JOB_NAME
```

## Outputs

### S3 Processed

O job cria os seguintes arquivos Parquet no bucket processed:

```
s3://bucket-processed/
├── dados_consolidados/
│   └── regiao=XX/disciplina=YY/part-XXX.parquet
├── agregacoes/
│   ├── media_alunos/part-XXX.parquet
│   ├── media_disciplinas/part-XXX.parquet
│   ├── estatisticas_escolas/part-XXX.parquet
│   └── estatisticas_regiao/part-XXX.parquet
```

### Aurora

O job carrega dados nas seguintes tabelas:

- `media_alunos`: Média geral por aluno
- `media_disciplinas`: Estatísticas por disciplina
- `estatisticas_escolas`: Estatísticas por escola
- `estatisticas_regiao`: Estatísticas por região

## Verificação

### Verificar dados no S3

```bash
# Listar arquivos Parquet criados
aws s3 ls s3://$(terraform output -raw s3_processed_bucket_name)/ --recursive

# Contar arquivos
aws s3 ls s3://$(terraform output -raw s3_processed_bucket_name)/ --recursive | wc -l
```

### Verificar dados no Aurora

```bash
# Conectar ao Aurora
AURORA_ENDPOINT=$(terraform output -raw aurora_endpoint)
psql -h $AURORA_ENDPOINT -U admin -d datawarehouse

# Consultas de exemplo
SELECT * FROM media_alunos ORDER BY media_geral DESC LIMIT 10;
SELECT * FROM media_disciplinas ORDER BY media_nota DESC;
SELECT * FROM estatisticas_escolas ORDER BY media_geral_escola DESC;
SELECT * FROM estatisticas_regiao;
```

## Logs e Monitoramento

Os logs do job ficam disponíveis em:
- **CloudWatch Logs**: `/aws-glue/jobs/output`
- **Job History**: AWS Glue Console > Jobs > Job runs

Para ver logs em tempo real:

```bash
# Obter ID da última execução
JOB_RUN_ID=$(aws glue get-job-runs \
  --job-name data-engineering-dev-etl-pipeline \
  --max-items 1 \
  --query 'JobRuns[0].Id' \
  --output text)

# Ver logs
aws logs tail /aws-glue/jobs/output --follow
```

## Troubleshooting

### Erro: Tabela não existe no Aurora
- Execute `create_aurora_tables.sql` antes de rodar o job

### Erro: Connection not found
- Verifique se a conexão Glue com Aurora está configurada
- Confirme credenciais na conexão

### Erro: Permissão negada no S3
- Verifique IAM roles do Glue
- Confirme que as roles têm acesso aos buckets

### Job muito lento
- Aumente `max_capacity` no job (custo maior)
- Use particionamento adequado
- Considere usar Glue Data Catalog para leitura

## Próximos Passos

Após executar o job com sucesso:

1. ✅ Dados processados em Parquet no S3
2. ✅ Dados agregados no Aurora
3. ⏭️ Criar visualizações/queries analíticas
4. ⏭️ Configurar agendamento do job (cron/schedule)
5. ⏭️ Adicionar alertas CloudWatch para falhas

