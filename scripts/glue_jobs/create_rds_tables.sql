-- Script SQL para criar tabelas no RDS PostgreSQL
-- Execute este script antes de rodar o Glue Job pela primeira vez

-- Conectar ao banco de dados
-- psql -h <rds-endpoint> -U masteruser -d datawarehouse

-- 1. Tabela: Escola
CREATE TABLE IF NOT EXISTS escola (
    escola_id VARCHAR(50) PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    rede VARCHAR(50) NOT NULL,
    regiao VARCHAR(50) NOT NULL,
    ingestion_time TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabela: Aluno
CREATE TABLE IF NOT EXISTS aluno (
    id VARCHAR(50) PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    idade INTEGER NOT NULL,
    genero VARCHAR(10) NOT NULL,
    escola_id VARCHAR(50) NOT NULL,
    ingestion_time TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_aluno_escola FOREIGN KEY (escola_id) REFERENCES escola(escola_id)
);

-- 3. Tabela: Nota
CREATE TABLE IF NOT EXISTS nota (
    aluno_id VARCHAR(50) NOT NULL,
    disciplina VARCHAR(50) NOT NULL,
    nota DECIMAL(4,1) NOT NULL CHECK (nota >= 0 AND nota <= 10),
    ingestion_time TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (aluno_id, disciplina),
    CONSTRAINT fk_nota_aluno FOREIGN KEY (aluno_id) REFERENCES aluno(id)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_aluno_escola_id ON aluno(escola_id);
CREATE INDEX IF NOT EXISTS idx_aluno_idade ON aluno(idade);
CREATE INDEX IF NOT EXISTS idx_nota_aluno_id ON nota(aluno_id);
CREATE INDEX IF NOT EXISTS idx_nota_disciplina ON nota(disciplina);
CREATE INDEX IF NOT EXISTS idx_escola_regiao ON escola(regiao);
CREATE INDEX IF NOT EXISTS idx_escola_rede ON escola(rede);

-- Comentários nas tabelas
COMMENT ON TABLE escola IS 'Tabela de escolas';
COMMENT ON TABLE aluno IS 'Tabela de alunos';
COMMENT ON TABLE nota IS 'Tabela de notas dos alunos por disciplina';

-- Verificar tabelas criadas
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('escola', 'aluno', 'nota')
ORDER BY table_name;
