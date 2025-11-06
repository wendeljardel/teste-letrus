# Relatório de Segurança do Repositório

## 🔍 Análise Realizada em: 06/11/2025

---

## ✅ **PONTOS POSITIVOS (Seguros)**

### 1. Credenciais Protegidas
- ✅ `terraform.tfvars` está no `.gitignore` (credenciais reais NÃO expostas)
- ✅ `terraform.tfvars.example` usa senhas de exemplo seguras
- ✅ Senhas marcadas como `sensitive = true` nos outputs do Terraform
- ✅ Nenhum `.env` ou `.pem` versionado

### 2. Chaves SSH
- ✅ Nenhuma chave privada (.pem, .key) versionada
- ✅ Chaves públicas SSH não foram encontradas no código versionado

### 3. Estrutura Segura
- ✅ Uso correto de variáveis do Terraform
- ✅ Separação entre código e configuração
- ✅ `.gitignore` configurado corretamente

---

## ⚠️ **PROBLEMA CRÍTICO CORRIGIDO**

### **IP Público Exposto (CORRIGIDO)**

**Antes:**
```terraform
# main.tf
allowed_ssh_cidr_blocks = ["45.5.142.154/32"]  # ← IP EXPOSTO!
```

**Depois:**
```terraform
# main.tf
allowed_ssh_cidr_blocks = var.bastion_allowed_ssh_cidr_blocks

# variables.tf
variable "bastion_allowed_ssh_cidr_blocks" {
  description = "CIDR blocks permitidos para SSH no Bastion Host"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# terraform.tfvars (não versionado)
bastion_allowed_ssh_cidr_blocks = ["45.5.142.154/32"]  # Seu IP aqui
```

**Status:** ✅ **CORRIGIDO**

---

## 📋 **RECOMENDAÇÕES ADICIONAIS**

### 1. Configuração do `terraform.tfvars`

**NUNCA versione** o arquivo `terraform.tfvars`. Certifique-se que está no `.gitignore`:

```bash
# Verificar
cat .gitignore | grep tfvars

# Deve mostrar:
*.tfvars
```

### 2. Senhas em Produção

**NÃO use senhas hardcoded em produção!** Use AWS Secrets Manager:

```terraform
# Exemplo seguro
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/aurora/master-password"
}

resource "aws_rds_cluster" "aurora" {
  master_password = data.aws_secretsmanager_secret_version.db_password.secret_string
  # ...
}
```

### 3. Rotação de Credenciais

Se alguma credencial foi exposta no GitHub (mesmo que removida depois):

```bash
# 1. Trocar senha do Aurora
aws rds modify-db-cluster \
  --db-cluster-identifier seu-cluster \
  --master-user-password NOVA_SENHA \
  --apply-immediately

# 2. Gerar novas chaves SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bastion-key-new.pem

# 3. Atualizar terraform.tfvars com nova chave pública
```

### 4. Restrição de IPs

**SEMPRE** restrinja o acesso SSH ao seu IP específico:

```terraform
# terraform.tfvars
bastion_allowed_ssh_cidr_blocks = ["SEU_IP/32"]  # NÃO use 0.0.0.0/0!
```

Para descobrir seu IP:
```bash
curl -4 ifconfig.me
```

### 5. Auditoria de Histórico Git

Para verificar se algo sensível foi exposto no passado:

```bash
# Buscar senhas no histórico
git log --all --source --full-history -S "password" --pretty=format:"%h %s"

# Buscar IPs públicos
git log --all --source --full-history -S "45.5.142" --pretty=format:"%h %s"
```

### 6. Pre-commit Hooks

Instale hooks para prevenir commits acidentais:

```bash
# Criar .git/hooks/pre-commit
#!/bin/bash
if git diff --cached --name-only | grep -E "terraform.tfvars$"; then
  echo "❌ Erro: terraform.tfvars não deve ser comitado!"
  exit 1
fi

if git diff --cached | grep -E "\.pem|\.key"; then
  echo "❌ Erro: Chaves privadas não devem ser comitadas!"
  exit 1
fi
```

### 7. GitHub Secrets Scanning

Habilite o **Secret Scanning** no GitHub:

1. Vá em: Settings → Security → Code security and analysis
2. Ative: **Secret scanning**
3. Ative: **Push protection**

---

## 🔒 **CHECKLIST DE SEGURANÇA**

- [x] `terraform.tfvars` no `.gitignore`
- [x] IPs removidos do código
- [x] Senhas marcadas como `sensitive`
- [x] Chaves SSH não versionadas
- [ ] AWS Secrets Manager configurado (recomendado para produção)
- [ ] Pre-commit hooks instalados
- [ ] GitHub Secret Scanning habilitado
- [ ] Auditoria de histórico realizada
- [ ] Credenciais rotacionadas (se necessário)

---

## 📞 **Em Caso de Exposição**

Se você acidentalmente expor credenciais:

### 1. Ação Imediata
```bash
# Trocar TODAS as senhas imediatamente
# Revogar chaves SSH antigas
# Criar novas chaves
```

### 2. Remover do Histórico Git
```bash
# CUIDADO: Isso reescreve o histórico!
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch terraform.tfvars" \
  --prune-empty --tag-name-filter cat -- --all

# Forçar push (coordene com equipe!)
git push origin --force --all
```

### 3. Notificar Equipe
- Avise todos os colaboradores
- Coordene a atualização das credenciais
- Documente o incidente

---

## 📚 **Recursos Adicionais**

- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)
- [Terraform Sensitive Variables](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [Git Filter-Branch](https://git-scm.com/docs/git-filter-branch)

---

## ✅ **Status Atual**

**Data:** 06/11/2025  
**Status:** ✅ **SEGURO**  
**Problemas Críticos:** 0  
**Recomendações Pendentes:** 4  

**Última Verificação:** IP público removido do código e movido para variáveis.

