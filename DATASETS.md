# Datasets Sintéticos

Este documento descreve os datasets sintéticos criados para o case técnico de Engenharia de Dados.

## Visão Geral

Três datasets foram criados para simular um ambiente educacional:

1. **escolas.csv** - Informações sobre escolas
2. **alunos.csv** - Informações sobre alunos
3. **notas.csv** - Notas dos alunos por disciplina

## Estrutura dos Dados

### 1. Escolas (escolas.csv)

| Campo | Tipo | Descrição | Exemplo |
|-------|------|-----------|---------|
| escola_id | String | ID único da escola | ESC001 |
| nome | String | Nome da escola | Escola Municipal Ana de Ensino |
| rede | String | Tipo de rede | pública, privada |
| regiao | String | Região do Brasil | Norte, Nordeste, Centro-Oeste, Sudeste, Sul |

**Características:**
- 20 escolas por padrão
- Distribuição aleatória entre redes públicas e privadas
- Distribuição aleatória entre as 5 regiões brasileiras

### 2. Alunos (alunos.csv)

| Campo | Tipo | Descrição | Exemplo |
|-------|------|-----------|---------|
| id | String | ID único do aluno | ALU00001 |
| nome | String | Nome completo do aluno | Ana Silva Santos |
| idade | Integer | Idade do aluno | 15 |
| genero | String | Gênero do aluno | M, F, Outro |
| escola_id | String | ID da escola (FK) | ESC001 |

**Características:**
- 500 alunos por padrão
- Idades entre 10 e 18 anos
- Distribuição aleatória de gênero
- Cada aluno está associado a uma escola

### 3. Notas (notas.csv)

| Campo | Tipo | Descrição | Exemplo |
|-------|------|-----------|---------|
| aluno_id | String | ID do aluno (FK) | ALU00001 |
| disciplina | String | Nome da disciplina | Matemática |
| nota | Float | Nota do aluno (0-10) | 7.5 |

**Disciplinas:**
- Matemática
- Português
- Ciências
- História
- Geografia
- Inglês

**Características:**
- Cada aluno tem nota em todas as 6 disciplinas
- Total de 3.000 registros de notas (500 alunos × 6 disciplinas)
- Distribuição de notas:
  - 10% notas baixas (0-4)
  - 75% notas médias (5-9)
  - 15% notas altas (9-10)

## Relacionamentos

```
escolas (1) ----< (N) alunos
alunos (1) ----< (N) notas
```

- Uma escola tem vários alunos
- Um aluno tem várias notas (uma por disciplina)
- Relação one-to-many entre escolas e alunos
- Relação one-to-many entre alunos e notas

## Geração dos Dados

Os dados são gerados usando o script `scripts/generate_synthetic_data.py`:

```bash
python scripts/generate_synthetic_data.py
```

O script usa uma seed aleatória (42) para garantir reprodutibilidade.

## Upload para S3

Após gerar os dados, faça upload para o bucket S3 raw:

```bash
# Usar script Python
BUCKET=$(terraform output -raw s3_raw_bucket_name)
python scripts/upload_to_s3.py $BUCKET

# OU usar AWS CLI diretamente
aws s3 cp data/raw/escolas.csv s3://$BUCKET/escolas/
aws s3 cp data/raw/alunos.csv s3://$BUCKET/alunos/
aws s3 cp data/raw/notas.csv s3://$BUCKET/notas/
```

Estrutura no S3:
```
s3://bucket-raw/
├── escolas/
│   └── escolas.csv
├── alunos/
│   └── alunos.csv
└── notas/
    └── notas.csv
```

## Exemplos de Consultas

### SQL (para usar após processar com Glue)

```sql
-- Média de notas por disciplina
SELECT disciplina, AVG(nota) as media_nota
FROM notas
GROUP BY disciplina
ORDER BY media_nota DESC;

-- Top 10 alunos por média geral
SELECT 
    a.id,
    a.nome,
    AVG(n.nota) as media_geral
FROM alunos a
JOIN notas n ON a.id = n.aluno_id
GROUP BY a.id, a.nome
ORDER BY media_geral DESC
LIMIT 10;

-- Média de notas por tipo de escola
SELECT 
    e.rede,
    AVG(n.nota) as media_nota
FROM escolas e
JOIN alunos a ON e.escola_id = a.escola_id
JOIN notas n ON a.id = n.aluno_id
GROUP BY e.rede;

-- Distribuição de alunos por região
SELECT 
    e.regiao,
    COUNT(DISTINCT a.id) as num_alunos
FROM escolas e
JOIN alunos a ON e.escola_id = a.escola_id
GROUP BY e.regiao
ORDER BY num_alunos DESC;
```

### Pandas (Python)

```python
import pandas as pd

# Carregar dados
escolas = pd.read_csv('data/raw/escolas.csv')
alunos = pd.read_csv('data/raw/alunos.csv')
notas = pd.read_csv('data/raw/notas.csv')

# Merge dos dados
dados_completos = (
    notas
    .merge(alunos, left_on='aluno_id', right_on='id')
    .merge(escolas, on='escola_id')
)

# Média de notas por região
media_por_regiao = dados_completos.groupby('regiao')['nota'].mean()

# Top 10 alunos
top_alunos = (
    dados_completos
    .groupby('nome')['nota']
    .mean()
    .sort_values(ascending=False)
    .head(10)
)
```

## Estatísticas dos Datasets

### Escolas
- Total: 20 escolas
- Rede pública: ~50%
- Rede privada: ~50%
- Regiões: Distribuídas entre 5 regiões

### Alunos
- Total: 500 alunos
- Idade média: ~14 anos
- Distribuição de gênero: ~33% cada (M, F, Outro)

### Notas
- Total: 3.000 registros
- Média geral: ~7.0
- Disciplina com maior média: Varia (aleatório)
- Disciplina com menor média: Varia (aleatório)

## Próximos Passos

1. ✅ Gerar dados sintéticos
2. ✅ Upload para S3
3. ⏭️ Executar Glue Crawlers para descobrir schema
4. ⏭️ Criar jobs ETL para transformar os dados
5. ⏭️ Carregar dados transformados no bucket processed
6. ⏭️ Carregar dados agregados no Aurora

