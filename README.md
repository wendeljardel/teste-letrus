# Infraestrutura AWS para Engenharia de Dados

Este projeto provisiona uma infraestrutura completa na AWS para pipelines de dados, incluindo:

- **S3 Buckets**: Armazenamento de dados brutos e transformados
- **Aurora Database**: Banco de dados PostgreSQL gerenciado
- **AWS Glue**: Jobs e Crawlers para processamento de dados
- **IAM**: Roles e políticas com princípio de menor privilégio

## Arquitetura

```
┌─────────────┐
│   S3 Raw    │ ──┐
└─────────────┘   │
                  │
┌─────────────┐   │    ┌──────────────┐    ┌─────────────┐
│ S3 Processed│ ◄─┼─── │  Glue Jobs   │ ──►│   Aurora    │
└─────────────┘   │    │  & Crawlers  │    │ PostgreSQL  │
                  │    └──────────────┘    └─────────────┘
                  │           │
                  └───────────┘
```

## Estrutura do Projeto

```
.
├── modules/              # Módulos Terraform
│   ├── s3/              # Buckets S3 (raw, processed, scripts)
│   ├── aurora/          # Aurora PostgreSQL cluster
│   ├── glue/            # Glue Jobs e Crawlers
│   ├── iam/             # IAM Roles e Policies
│   ├── vpc/             # VPC e subnets
│   └── bastion/         # Bastion Host para acesso ao Aurora
├── scripts/             # Scripts Python e Bash
│   ├── glue_jobs/       # Scripts Glue e SQL
│   │   ├── etl_pipeline.py
│   │   ├── create_aurora_tables.sql
│   │   └── analytics_queries.sql
│   ├── generate_synthetic_data.py
│   ├── upload_to_s3.py
│   ├── run_pipeline.sh
│   └── create_aurora_tables.sh
├── main.tf              # Configuração principal
├── variables.tf         # Variáveis
├── outputs.tf           # Outputs
├── terraform.tfvars     # Valores das variáveis (não versionado)
├── ANALYTICS_GUIDE.md   # Guia de queries analíticas
└── README.md            # Este arquivo
```

## Pré-requisitos

- Terraform >= 1.0
- AWS CLI configurado
- Credenciais AWS configuradas (via AWS CLI, variáveis de ambiente ou IAM Role)

## Configuração Inicial

### 1. Clone o repositório

### 2. Configure as variáveis do Terraform

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars` com suas configurações específicas.

### 3. Provisione a infraestrutura

```bash
# Inicialize o Terraform
terraform init

# Revise o plano de execução
terraform plan

# Aplique a infraestrutura
terraform apply
```

### 4. Gere dados sintéticos

```bash
# Gerar datasets de exemplo
python scripts/generate_synthetic_data.py

# Fazer upload para S3
python scripts/upload_to_s3.py
```

### 5. Execute o pipeline ETL completo

```bash
./scripts/run_pipeline.sh
```

Este script automaticamente:
- Faz upload do script Glue para S3
- Cria tabelas no Aurora (via Bastion Host se necessário)
- Verifica dados no S3 Raw
- Executa o Glue Job
- Monitora a execução em tempo real

**Nota**: Se o Aurora estiver em subnet privada, você precisará criar as tabelas manualmente via Bastion Host:

```bash
# Opção 1: Script automático
./scripts/create_aurora_tables.sh

# Opção 2: Manual
# Terminal 1: Abrir tunnel SSH
./connect-aurora-alt.sh

# Terminal 2: Criar tabelas
psql -h localhost -p 15432 -U masteruser -d datawarehouse \
  -f scripts/glue_jobs/create_aurora_tables.sql
```



## Scripts Disponíveis

| Script | Descrição |
|--------|-----------|
| `generate_synthetic_data.py` | Gera datasets sintéticos (escolas, alunos, notas) |
| `upload_to_s3.py` | Faz upload dos dados para S3 Raw |
| `run_pipeline.sh` | Executa o pipeline ETL completo (setup + job + monitoramento) |
| `create_aurora_tables.sh` | Cria tabelas no Aurora via tunnel SSH |
| `connect-aurora-alt.sh` | Abre tunnel SSH para Aurora (porta 15432) |
| `etl_pipeline.py` | Job Glue que processa dados e carrega no Aurora |
| `analytics_queries.sql` | Queries analíticas para análise de dados |

## Limpeza

Para destruir toda a infraestrutura:

```bash
# Esvaziar buckets S3 primeiro
aws s3 rm s3://case-tec-dev-raw-letrus --recursive
aws s3 rm s3://case-tec-dev-processed-letrus --recursive
aws s3 rm s3://case-tec-dev-scripts-letrus --recursive

# Destruir infraestrutura
terraform destroy
```

