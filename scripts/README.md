# Scripts de Geração de Dados Sintéticos

Este diretório contém scripts para gerar e fazer upload de datasets sintéticos para o S3.

## Pré-requisitos

```bash
# Instalar dependências Python
pip install -r scripts/requirements.txt

# OU
pip install pandas boto3
```

## Uso

### 1. Gerar Datasets Sintéticos

```bash
# Gerar os arquivos CSV localmente
python scripts/generate_synthetic_data.py
```

Isso criará três arquivos CSV em `data/raw/`:
- `escolas.csv` - 20 escolas com informações de rede e região
- `alunos.csv` - 500 alunos com informações pessoais
- `notas.csv` - Notas dos alunos em 6 disciplinas

### 2. Upload para S3

#### Opção A: Usar o script Python

```bash
# Obter o nome do bucket raw do Terraform
BUCKET=$(terraform output -raw s3_raw_bucket_name)

# Fazer upload
python scripts/upload_to_s3.py $BUCKET
```

#### Opção B: Usar AWS CLI diretamente

```bash
# Obter o nome do bucket
BUCKET=$(terraform output -raw s3_raw_bucket_name)

# Fazer upload dos arquivos
aws s3 cp data/raw/escolas.csv s3://$BUCKET/escolas/
aws s3 cp data/raw/alunos.csv s3://$BUCKET/alunos/
aws s3 cp data/raw/notas.csv s3://$BUCKET/notas/
```

## Estrutura dos Datasets

### escolas.csv
```csv
escola_id,nome,rede,regiao
ESC001,Escola Municipal Ana de Ensino,pública,Norte
ESC002,Escola Estadual João Fundamental,pública,Sudeste
...
```

**Campos:**
- `escola_id`: ID único da escola (ESC001, ESC002, ...)
- `nome`: Nome da escola
- `rede`: Tipo de rede (pública/privada)
- `regiao`: Região brasileira (Norte, Nordeste, Centro-Oeste, Sudeste, Sul)

### alunos.csv
```csv
id,nome,idade,genero,escola_id
ALU00001,Ana Silva Santos,15,F,ESC001
ALU00002,João Oliveira Souza,16,M,ESC002
...
```

**Campos:**
- `id`: ID único do aluno (ALU00001, ALU00002, ...)
- `nome`: Nome completo do aluno
- `idade`: Idade do aluno (10-18 anos)
- `genero`: Gênero (M, F, Outro)
- `escola_id`: ID da escola (referência a escolas.csv)

### notas.csv
```csv
aluno_id,disciplina,nota
ALU00001,Matemática,7.5
ALU00001,Português,8.2
...
```

**Campos:**
- `aluno_id`: ID do aluno (referência a alunos.csv)
- `disciplina`: Nome da disciplina (Matemática, Português, Ciências, História, Geografia, Inglês)
- `nota`: Nota do aluno (0.0-10.0)

## Customização

Você pode editar `scripts/generate_synthetic_data.py` para ajustar:

- `NUM_ESCOLAS`: Número de escolas (padrão: 20)
- `NUM_ALUNOS`: Número de alunos (padrão: 500)
- `NUM_NOTAS_POR_ALUNO`: Número de disciplinas (padrão: 6)
- `DISCIPLINAS`: Lista de disciplinas
- `REGIOES`: Lista de regiões
- `RANDOM_SEED`: Seed para reprodutibilidade (padrão: 42)

## Verificação

Após o upload, verifique os arquivos no S3:

```bash
# Listar arquivos no bucket
aws s3 ls s3://$(terraform output -raw s3_raw_bucket_name)/ --recursive

# Baixar e verificar um arquivo
aws s3 cp s3://$(terraform output -raw s3_raw_bucket_name)/alunos/alunos.csv - | head -10
```

## Próximos Passos

Após fazer upload dos dados:

1. **Executar Crawlers do Glue** para descobrir o schema:
   ```bash
   aws glue start-crawler --name data-engineering-dev-raw-data-crawler
   ```

2. **Verificar tabelas criadas** no Glue Data Catalog:
   ```bash
   aws glue get-tables --database-name raw_data
   ```

3. **Criar jobs ETL** usando os dados no bucket raw como fonte.

