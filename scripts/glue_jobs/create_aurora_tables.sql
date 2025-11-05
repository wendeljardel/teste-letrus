-- Script SQL para criar tabelas no Aurora PostgreSQL
-- Execute este script antes de rodar o Glue Job pela primeira vez

-- Conectar ao banco de dados
-- psql -h <aurora-endpoint> -U admin -d datawarehouse

-- 1. Tabela: Média por aluno
CREATE TABLE IF NOT EXISTS media_alunos (
    aluno_id VARCHAR(50) PRIMARY KEY,
    media_geral DECIMAL(5,2),
    num_disciplinas INTEGER,
    nota_maxima DECIMAL(4,1),
    nota_minima DECIMAL(4,1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabela: Média por disciplina
CREATE TABLE IF NOT EXISTS media_disciplinas (
    disciplina VARCHAR(50) PRIMARY KEY,
    media_nota DECIMAL(5,2),
    num_alunos INTEGER,
    nota_maxima DECIMAL(4,1),
    nota_minima DECIMAL(4,1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Tabela: Estatísticas por escola
CREATE TABLE IF NOT EXISTS estatisticas_escolas (
    escola_id VARCHAR(50) PRIMARY KEY,
    escola_nome VARCHAR(255),
    escola_rede VARCHAR(50),
    regiao VARCHAR(50),
    num_alunos INTEGER,
    media_geral_escola DECIMAL(5,2),
    total_notas INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Tabela: Estatísticas por região
CREATE TABLE IF NOT EXISTS estatisticas_regiao (
    regiao VARCHAR(50) PRIMARY KEY,
    num_escolas INTEGER,
    num_alunos INTEGER,
    media_geral_regiao DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_media_alunos_media_geral ON media_alunos(media_geral DESC);
CREATE INDEX IF NOT EXISTS idx_estatisticas_escolas_regiao ON estatisticas_escolas(regiao);
CREATE INDEX IF NOT EXISTS idx_estatisticas_escolas_rede ON estatisticas_escolas(escola_rede);

-- Comentários nas tabelas
COMMENT ON TABLE media_alunos IS 'Média geral de notas por aluno';
COMMENT ON TABLE media_disciplinas IS 'Estatísticas de notas por disciplina';
COMMENT ON TABLE estatisticas_escolas IS 'Estatísticas agregadas por escola';
COMMENT ON TABLE estatisticas_regiao IS 'Estatísticas agregadas por região';

-- Verificar tabelas criadas
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('media_alunos', 'media_disciplinas', 'estatisticas_escolas', 'estatisticas_regiao')
ORDER BY table_name;
