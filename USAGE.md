# Guia de Uso Rápido

## Configuração Inicial

1. **Copie o arquivo de variáveis de exemplo:**
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. **Edite `terraform.tfvars` com suas configurações:**
   - Defina `aurora_master_password` (em produção, use AWS Secrets Manager)
   - Ajuste `project_name` e `environment` conforme necessário
   - Configure os paths dos crawlers e jobs do Glue

3. **Importante: Configuração dos Crawlers do Glue**

Os crawlers precisam de paths S3 corretos. Você tem duas opções:

### Opção 1: Usar outputs do Terraform (Recomendado)

Após criar a infraestrutura, use os outputs para configurar os crawlers:

```bash
# Obter os nomes dos buckets
terraform output s3_raw_bucket_name
terraform output s3_processed_bucket_name

# Atualize o terraform.tfvars com os valores corretos
```

### Opção 2: Usar placeholders e atualizar depois

O Terraform criará os buckets com nomes únicos. Você precisará atualizar os `s3_paths` nos crawlers após a criação inicial.

## Inicialização e Deploy

```bash
# Inicializar Terraform
terraform init

# Validar configuração
terraform validate

# Ver plano de execução
terraform plan

# Aplicar infraestrutura
terraform apply
```

## Configuração Pós-Deploy

### 1. Configurar Conexão Glue com Aurora

A conexão do Glue com Aurora precisa de credenciais. Você pode configurá-las via:

**Opção A: Console AWS**
- Vá para AWS Glue > Connections
- Edite a conexão criada
- Adicione username e password

**Opção B: Terraform (recomendado)**
- Use AWS Secrets Manager para armazenar as credenciais
- Atualize o módulo Glue para usar Secrets Manager

### 2. Upload de Scripts do Glue

Faça upload dos scripts Python para o bucket de scripts:

```bash
# Obter o nome do bucket de scripts
BUCKET=$(terraform output -raw s3_scripts_bucket_name)

# Upload do script
aws s3 cp scripts/etl_job.py s3://$BUCKET/scripts/
```

### 3. Configurar Crawlers

Atualize os `s3_paths` nos crawlers usando os outputs do Terraform ou atualize manualmente via Console.

## Verificação

```bash
# Listar todos os outputs
terraform output

# Ver outputs específicos
terraform output aurora_endpoint
terraform output s3_raw_bucket_name
terraform output glue_job_names
```

## Exemplo de Script Glue Básico

Crie um arquivo `scripts/etl_job.py` no bucket de scripts:

```python
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Seu código ETL aqui

job.commit()
```

## Troubleshooting

### Erro: Bucket name already exists
- O suffix único deve resolver isso
- Se persistir, mude o `project_name` ou `environment`

### Erro: IAM role not found
- Verifique se o módulo IAM foi criado antes do Glue
- Execute `terraform apply` novamente se necessário

### Erro: Glue connection não consegue conectar ao Aurora
- Verifique se o security group permite tráfego na porta do Aurora
- Confirme que as credenciais estão configuradas na conexão
- Verifique se o Aurora está acessível das subnets configuradas

## Limpeza

```bash
# Destruir toda a infraestrutura
terraform destroy

# Nota: Se skip_final_snapshot = false, será criado um snapshot final do Aurora
```

