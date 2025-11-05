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
├── modules/
│   ├── s3/
│   ├── aurora/
│   ├── glue/
│   └── iam/
├── environments/
│   └── dev/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── README.md
```

## Pré-requisitos

- Terraform >= 1.0
- AWS CLI configurado
- Credenciais AWS configuradas (via AWS CLI, variáveis de ambiente ou IAM Role)

## Configuração Inicial

1. Clone o repositório

2. Copie o arquivo de exemplo de variáveis:
```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Edite `terraform.tfvars` com suas configurações específicas

4. Inicialize o Terraform:
```bash
terraform init
```

5. Revise o plano de execução:
```bash
terraform plan
```

6. Aplique a infraestrutura:
```bash
terraform apply
```

## Variáveis Principais

- `project_name`: Nome do projeto (usado para naming de recursos)
- `environment`: Ambiente (dev, homol, prod)
- `region`: Região AWS
- `aurora_engine`: Engine do Aurora (aurora-postgresql ou aurora-mysql)
- `aurora_instance_class`: Classe da instância Aurora

Consulte `variables.tf` para lista completa de variáveis.

## Outputs

Após o `terraform apply`, os seguintes outputs estarão disponíveis:

- S3 bucket names (raw e processed)
- Aurora endpoint e port
- Glue job names e crawler names
- IAM role ARNs

Execute `terraform output` para ver todos os valores.

## Segurança

- ✅ Encryption at rest habilitado em todos os recursos
- ✅ Encryption in transit habilitado
- ✅ IAM Least Privilege Principle aplicado
- ✅ S3 buckets com versionamento e lifecycle policies
- ✅ Security groups restritivos
- ✅ VPC e subnets privadas para Aurora

## Limpeza

Para destruir toda a infraestrutura:
```bash
terraform destroy
```


## Módulos

### S3
Gerencia buckets para dados brutos e processados com:
- Encryption (SSE-S3 ou SSE-KMS)
- Versionamento
- Lifecycle policies
- Public access bloqueado

### Aurora
Provisiona cluster Aurora PostgreSQL/MySQL com:
- Multi-AZ para alta disponibilidade
- Automated backups
- Encryption at rest
- Security groups restritivos

### Glue
Configura jobs e crawlers do AWS Glue com:
- IAM roles apropriadas
- S3 paths configurados
- Database connections

### IAM
Gerencia roles e policies com:
- Least privilege principle
- Trust relationships apropriadas
- Políticas específicas para cada serviço

