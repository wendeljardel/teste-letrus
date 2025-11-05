# Pipeline ETL - AWS Glue

Este documento descreve o pipeline ETL completo implementado para processar os dados educacionais.

## Visão Geral

O pipeline ETL é executado por um AWS Glue Job que:

1. **Extrai** dados brutos (CSV) do bucket S3 raw
2. **Transforma** e limpa os dados
3. **Carrega** dados processados em Parquet no S3 processed e agregados no Aurora

## Arquitetura do Pipeline

```
┌─────────────────┐
│   S3 Raw        │
│   (CSV files)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Glue Job       │
│  ETL Pipeline   │
│                 │
│  • Read CSV     │
│  • Transform    │
│  • Join         │
│  • Aggregate    │
└─────┬───────┬───┘
      │       │
      ▼       ▼
┌─────────┐ ┌──────────────┐
│ S3      │ │  Aurora      │
│Processed│ │  PostgreSQL  │
│(Parquet)│ │  (Aggregates)│
└─────────┘ └──────────────┘
```

## Fluxo de Dados

### 1. Extração (Extract)

**Fonte**: S3 Raw Bucket
- `escolas/escolas.csv`
- `alunos/alunos.csv`
- `notas/notas.csv`

**Método**: Leitura via Glue DynamicFrame diretamente do S3

### 2. Transformação (Transform)

#### Limpeza de Dados
- Remoção de espaços em branco
- Padronização de case (maiúsculas/minúsculas)
- Validação de tipos de dados
- Filtragem de registros inválidos (notas fora do range 0-10)

#### Joins
- `alunos` JOIN `escolas` (via escola_id)
- Resultado JOIN `notas` (via aluno_id)

#### Agregações
- **Média por aluno**: Média geral, min, max, número de disciplinas
- **Média por disciplina**: Média, contagem de alunos, min, max
- **Estatísticas por escola**: Número de alunos, média geral, total de notas
- **Estatísticas por região**: Número de escolas, alunos, média geral

### 3. Carga (Load)

#### S3 Processed (Parquet)
- **Dados consolidados**: Tabela única com todos os dados
  - Particionado por `regiao` e `disciplina` para otimização
- **Agregações**: Arquivos Parquet separados para cada agregação

#### Aurora PostgreSQL
- 4 tabelas com dados agregados:
  - `media_alunos`
  - `media_disciplinas`
  - `estatisticas_escolas`
  - `estatisticas_regiao`

## Formato Parquet

### Vantagens do Parquet
- ✅ **Compactação**: 50-80% menor que CSV
- ✅ **Performance**: Leitura mais rápida (columnar storage)
- ✅ **Schema**: Tipo de dados preservado
- ✅ **Particionamento**: Consultas mais eficientes
- ✅ **Compatibilidade**: Suportado por Spark, Athena, Redshift, etc.

### Estrutura no S3

```
s3://bucket-processed/
├── dados_consolidados/
│   ├── regiao=Norte/
│   │   ├── disciplina=Matemática/
│   │   │   └── part-00000.parquet
│   │   ├── disciplina=Português/
│   │   │   └── part-00000.parquet
│   │   └── ...
│   ├── regiao=Sudeste/
│   │   └── ...
│   └── ...
├── agregacoes/
│   ├── media_alunos/
│   │   └── part-00000.parquet
│   ├── media_disciplinas/
│   │   └── part-00000.parquet
│   ├── estatisticas_escolas/
│   │   └── part-00000.parquet
│   └── estatisticas_regiao/
│       └── part-00000.parquet
```

## Tabelas no Aurora

### media_alunos
```sql
CREATE TABLE media_alunos (
    aluno_id VARCHAR(50) PRIMARY KEY,
    media_geral DECIMAL(5,2),
    num_disciplinas INTEGER,
    nota_maxima DECIMAL(4,1),
    nota_minima DECIMAL(4,1),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

### media_disciplinas
```sql
CREATE TABLE media_disciplinas (
    disciplina VARCHAR(50) PRIMARY KEY,
    media_nota DECIMAL(5,2),
    num_alunos INTEGER,
    nota_maxima DECIMAL(4,1),
    nota_minima DECIMAL(4,1),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

### estatisticas_escolas
```sql
CREATE TABLE estatisticas_escolas (
    escola_id VARCHAR(50) PRIMARY KEY,
    escola_nome VARCHAR(255),
    escola_rede VARCHAR(50),
    regiao VARCHAR(50),
    num_alunos INTEGER,
    media_geral_escola DECIMAL(5,2),
    total_notas INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

### estatisticas_regiao
```sql
CREATE TABLE estatisticas_regiao (
    regiao VARCHAR(50) PRIMARY KEY,
    num_escolas INTEGER,
    num_alunos INTEGER,
    media_geral_regiao DECIMAL(5,2),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

## Execução do Pipeline

### Pré-requisitos

1. ✅ Infraestrutura Terraform aplicada
2. ✅ Dados sintéticos no S3 raw
3. ✅ Tabelas criadas no Aurora
4. ✅ Script do job no S3 scripts bucket

### Passos

#### 1. Criar Tabelas no Aurora

```bash
AURORA_ENDPOINT=$(terraform output -raw aurora_endpoint)
psql -h $AURORA_ENDPOINT -U admin -d datawarehouse \
  -f scripts/glue_jobs/create_aurora_tables.sql
```

#### 2. Upload do Script do Job

```bash
SCRIPTS_BUCKET=$(terraform output -raw s3_scripts_bucket_name)
aws s3 cp scripts/glue_jobs/etl_pipeline.py \
  s3://$SCRIPTS_BUCKET/scripts/
```

#### 3. Atualizar Terraform (se necessário)

Se o job ainda não estiver no Terraform:

```bash
terraform apply
```

#### 4. Executar o Job

```bash
# Obter nome do job
JOB_NAME=$(terraform output -json glue_job_names | jq -r '."etl-pipeline"')

# Executar
aws glue start-job-run --job-name $JOB_NAME
```

## Monitoramento

### CloudWatch Logs

```bash
# Ver logs em tempo real
aws logs tail /aws-glue/jobs/output --follow
```

### Verificar Status

```bash
# Status do último run
aws glue get-job-runs \
  --job-name data-engineering-dev-etl-pipeline \
  --max-items 1 \
  --query 'JobRuns[0].[Id,JobRunState,StartedOn]' \
  --output table
```

### Métricas Importantes

- **Duration**: Tempo de execução do job
- **Records Processed**: Número de registros processados
- **DPU Hours**: Unidades de processamento utilizadas
- **Success Rate**: Taxa de sucesso das execuções

## Performance

### Otimizações Implementadas

1. **Particionamento**: Dados particionados por região e disciplina
2. **Formato Parquet**: Compressão e leitura otimizada
3. **Schemas explícitos**: Evita inferência de schema
4. **Filtros precoces**: Remove dados inválidos antes de joins

### Tamanhos Estimados

- **CSV Raw**: ~500KB (3 arquivos)
- **Parquet Processed**: ~150-200KB (comprimido)
- **Aurora**: ~10-20KB (apenas agregações)

### Tempo de Execução

- **Job pequeno**: ~2-5 minutos
- **Job médio**: ~5-10 minutos
- Depende do tamanho dos dados e DPU alocados

## Consultas Exemplo

### SQL no Aurora

```sql
-- Top 10 alunos com maior média
SELECT * FROM media_alunos 
ORDER BY media_geral DESC 
LIMIT 10;

-- Média por tipo de escola
SELECT escola_rede, AVG(media_geral_escola) as media
FROM estatisticas_escolas
GROUP BY escola_rede;

-- Comparação entre regiões
SELECT * FROM estatisticas_regiao
ORDER BY media_geral_regiao DESC;
```

### Athena (sobre Parquet no S3)

```sql
-- Criar tabela externa no Glue Catalog
CREATE EXTERNAL TABLE dados_consolidados
STORED AS PARQUET
LOCATION 's3://bucket-processed/dados_consolidados/';

-- Consulta
SELECT regiao, disciplina, AVG(nota) as media
FROM dados_consolidados
GROUP BY regiao, disciplina;
```

## Troubleshooting

### Job Falha na Leitura

- Verificar permissões IAM do Glue
- Confirmar que arquivos CSV existem no S3
- Verificar formato dos CSVs

### Job Falha no Aurora

- Verificar conexão Glue com Aurora
- Confirmar credenciais na conexão
- Verificar se tabelas existem
- Checar security groups

### Performance Lenta

- Aumentar `max_capacity` (mais DPUs)
- Verificar particionamento
- Otimizar queries/transformações

## Próximos Passos

1. ⏭️ Agendar execução (cron)
2. ⏭️ Adicionar alertas CloudWatch
3. ⏭️ Implementar versionamento de dados
4. ⏭️ Criar visualizações (QuickSight, Grafana)
5. ⏭️ Adicionar testes de qualidade de dados

