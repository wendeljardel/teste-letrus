#!/bin/bash
# Script para criar tabelas no RDS PostgreSQL via tunnel SSH

set -e

echo "═══════════════════════════════════════════════"
echo "  CRIAR TABELAS NO RDS POSTGRESQL"
echo "═══════════════════════════════════════════════"
echo ""

# Obter informações do Terraform
BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
RDS_ENDPOINT=$(terraform output -raw aurora_endpoint 2>/dev/null || echo "")
RDS_PASSWORD=$(terraform output -raw aurora_master_password 2>/dev/null || echo "")

if [ -z "$BASTION_IP" ] || [ -z "$RDS_ENDPOINT" ] || [ -z "$RDS_PASSWORD" ]; then
    echo "Erro: Nao foi possivel obter informacoes do Terraform"
    echo "Execute: terraform apply"
    exit 1
fi

echo "RDS Endpoint: ${RDS_ENDPOINT}"
echo "Bastion IP: ${BASTION_IP}"
echo ""

# Verificar se psql está instalado
if ! command -v psql &> /dev/null; then
    echo "Erro: psql nao encontrado. Instale o PostgreSQL client."
    exit 1
fi

# Verificar se a chave SSH existe
SSH_KEY="/Users/user/.ssh/bastion-key.pem"
if [ ! -f "$SSH_KEY" ]; then
    echo "Erro: Chave SSH nao encontrada em $SSH_KEY"
    exit 1
fi

echo "Abrindo tunnel SSH em background..."
echo "(Usando porta local 15432)"
echo ""

# Matar qualquer tunnel existente na porta 15432
pkill -f "ssh.*15432.*$RDS_ENDPOINT" 2>/dev/null || true
sleep 1

# Abrir tunnel SSH em background
ssh -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -f \
    -N \
    -L "15432:$RDS_ENDPOINT:5432" \
    -i "$SSH_KEY" \
    ec2-user@$BASTION_IP

echo "Tunnel SSH aberto com sucesso!"
echo ""

# Aguardar um pouco para o tunnel estar pronto
sleep 2

echo "Criando tabelas no RDS PostgreSQL..."
echo ""

export PGPASSWORD="$RDS_PASSWORD"

if psql -h localhost -p 15432 -U masteruser -d datawarehouse -f scripts/glue_jobs/create_rds_tables.sql 2>&1; then
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TABELAS CRIADAS COM SUCESSO!"
    echo "═══════════════════════════════════════════════"
    echo ""
else
    echo ""
    echo "Erro ao criar tabelas."
    echo ""
    exit 1
fi

unset PGPASSWORD

# Fechar o tunnel
echo "Fechando tunnel SSH..."
pkill -f "ssh.*15432.*$RDS_ENDPOINT" 2>/dev/null || true

echo "Concluido!"
echo ""

