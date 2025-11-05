#!/bin/bash
# Script helper para configurar e executar o pipeline completo

set -e

echo "🚀 Configurando Pipeline ETL"
echo ""

# Verificar se Terraform foi aplicado
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform não encontrado. Instale primeiro."
    exit 1
fi

# 1. Obter outputs do Terraform
echo "📋 Obtendo informações da infraestrutura..."
SCRIPTS_BUCKET=$(terraform output -raw s3_scripts_bucket_name 2>/dev/null || echo "")
RAW_BUCKET=$(terraform output -raw s3_raw_bucket_name 2>/dev/null || echo "")
AURORA_ENDPOINT=$(terraform output -raw aurora_endpoint 2>/dev/null || echo "")

if [ -z "$SCRIPTS_BUCKET" ] || [ -z "$RAW_BUCKET" ]; then
    echo "❌ Erro: Terraform outputs não encontrados"
    echo "   Execute: terraform apply"
    exit 1
fi

echo "   ✅ Bucket Scripts: $SCRIPTS_BUCKET"
echo "   ✅ Bucket Raw: $RAW_BUCKET"
if [ -n "$AURORA_ENDPOINT" ]; then
    echo "   ✅ Aurora Endpoint: $AURORA_ENDPOINT"
fi
echo ""

# 2. Upload do script do Glue Job
echo "📤 Fazendo upload do script do Glue Job..."
if [ -f "scripts/glue_jobs/etl_pipeline.py" ]; then
    aws s3 cp scripts/glue_jobs/etl_pipeline.py s3://$SCRIPTS_BUCKET/scripts/ 2>/dev/null || {
        echo "   ⚠️  Erro ao fazer upload. Verificando se bucket existe..."
        aws s3 ls s3://$SCRIPTS_BUCKET/ 2>/dev/null || {
            echo "   ❌ Bucket não acessível. Verifique permissões AWS."
            exit 1
        }
        exit 1
    }
    echo "   ✅ Script upload concluído"
else
    echo "   ⚠️  Arquivo scripts/glue_jobs/etl_pipeline.py não encontrado"
    exit 1
fi
echo ""

# 3. Criar tabelas no Aurora (se endpoint disponível)
if [ -n "$AURORA_ENDPOINT" ]; then
    echo "🗄️  Configurando tabelas no Aurora..."
    echo "   ℹ️  Para criar as tabelas, execute:"
    echo "   psql -h $AURORA_ENDPOINT -U admin -d datawarehouse -f scripts/glue_jobs/create_aurora_tables.sql"
    echo ""
fi

# 4. Verificar se dados existem no S3 raw
echo "📊 Verificando dados no S3 raw..."
if aws s3 ls s3://$RAW_BUCKET/escolas/ 2>/dev/null | grep -q ".csv"; then
    echo "   ✅ Dados encontrados no bucket raw"
else
    echo "   ⚠️  Dados não encontrados no bucket raw"
    echo "   Execute: python scripts/generate_synthetic_data.py"
    echo "   Depois: python scripts/upload_to_s3.py $RAW_BUCKET"
    echo ""
fi

# 5. Resumo
echo "✨ Configuração concluída!"
echo ""
echo "📝 Próximos passos:"
echo ""
echo "1. Criar tabelas no Aurora (se ainda não fez):"
if [ -n "$AURORA_ENDPOINT" ]; then
    echo "   psql -h $AURORA_ENDPOINT -U admin -d datawarehouse -f scripts/glue_jobs/create_aurora_tables.sql"
else
    echo "   AURORA_ENDPOINT=\$(terraform output -raw aurora_endpoint)"
    echo "   psql -h \$AURORA_ENDPOINT -U admin -d datawarehouse -f scripts/glue_jobs/create_aurora_tables.sql"
fi
echo ""
echo "2. Executar o Glue Job:"
echo "   JOB_NAME=\$(terraform output -json glue_job_names | jq -r '.\"etl-pipeline\"')"
echo "   aws glue start-job-run --job-name \$JOB_NAME"
echo ""
echo "3. Monitorar execução:"
echo "   aws logs tail /aws-glue/jobs/output --follow"
echo ""

