-- Queries Analiticas para Dados Educacionais
-- Execute essas queries no Aurora PostgreSQL para analise dos dados

-- ============================================
-- 1. MEDIA DE NOTAS POR ESCOLA
-- ============================================

-- Media de notas por escola (com informacoes da escola)
SELECT 
    e.escola_id,
    e.nome AS escola_nome,
    e.rede,
    e.regiao,
    COUNT(DISTINCT a.id) AS total_alunos,
    COUNT(n.nota) AS total_notas,
    ROUND(AVG(n.nota)::numeric, 2) AS media_geral,
    ROUND(MIN(n.nota)::numeric, 2) AS nota_minima,
    ROUND(MAX(n.nota)::numeric, 2) AS nota_maxima,
    ROUND(STDDEV(n.nota)::numeric, 2) AS desvio_padrao
FROM escola e
LEFT JOIN aluno a ON e.escola_id = a.escola_id
LEFT JOIN nota n ON a.id = n.aluno_id
GROUP BY e.escola_id, e.nome, e.rede, e.regiao
ORDER BY media_geral DESC NULLS LAST;

-- ============================================
-- 2. MEDIA DE NOTAS POR REGIAO
-- ============================================

-- Media de notas por regiao
SELECT 
    e.regiao,
    COUNT(DISTINCT e.escola_id) AS total_escolas,
    COUNT(DISTINCT a.id) AS total_alunos,
    COUNT(n.nota) AS total_notas,
    ROUND(AVG(n.nota)::numeric, 2) AS media_geral,
    ROUND(MIN(n.nota)::numeric, 2) AS nota_minima,
    ROUND(MAX(n.nota)::numeric, 2) AS nota_maxima
FROM escola e
LEFT JOIN aluno a ON e.escola_id = a.escola_id
LEFT JOIN nota n ON a.id = n.aluno_id
GROUP BY e.regiao
ORDER BY media_geral DESC NULLS LAST;

-- ============================================
-- 3. MEDIA DE NOTAS POR ESCOLA E REGIAO (COMBINADO)
-- ============================================

-- Ranking de escolas dentro de cada regiao
SELECT 
    e.regiao,
    e.nome AS escola_nome,
    e.rede,
    ROUND(AVG(n.nota)::numeric, 2) AS media_escola,
    RANK() OVER (PARTITION BY e.regiao ORDER BY AVG(n.nota) DESC) AS ranking_na_regiao,
    ROUND(AVG(AVG(n.nota)) OVER (PARTITION BY e.regiao)::numeric, 2) AS media_da_regiao
FROM escola e
LEFT JOIN aluno a ON e.escola_id = a.escola_id
LEFT JOIN nota n ON a.id = n.aluno_id
GROUP BY e.escola_id, e.regiao, e.nome, e.rede
ORDER BY e.regiao, ranking_na_regiao;

-- ============================================
-- 4. DIFERENCA DE DESEMPENHO: PUBLICA vs PRIVADA
-- ============================================

-- Comparacao geral entre escolas publicas e privadas
SELECT 
    e.rede,
    COUNT(DISTINCT e.escola_id) AS total_escolas,
    COUNT(DISTINCT a.id) AS total_alunos,
    COUNT(n.nota) AS total_notas,
    ROUND(AVG(n.nota)::numeric, 2) AS media_geral,
    ROUND(STDDEV(n.nota)::numeric, 2) AS desvio_padrao,
    ROUND(MIN(n.nota)::numeric, 2) AS nota_minima,
    ROUND(MAX(n.nota)::numeric, 2) AS nota_maxima,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n.nota)::numeric, 2) AS mediana
FROM escola e
LEFT JOIN aluno a ON e.escola_id = a.escola_id
LEFT JOIN nota n ON a.id = n.aluno_id
GROUP BY e.rede
ORDER BY media_geral DESC;


-- Desempenho por rede em cada regiao
SELECT 
    e.regiao,
    e.rede,
    COUNT(DISTINCT e.escola_id) AS total_escolas,
    COUNT(DISTINCT a.id) AS total_alunos,
    ROUND(AVG(n.nota)::numeric, 2) AS media_nota
FROM escola e
LEFT JOIN aluno a ON e.escola_id = a.escola_id
LEFT JOIN nota n ON a.id = n.aluno_id
GROUP BY e.regiao, e.rede
ORDER BY e.regiao, media_nota DESC;

-- ============================================
-- 5. DISTRIBUICAO DAS NOTAS POR DISCIPLINA
-- ============================================

-- Estatisticas gerais por disciplina
SELECT 
    n.disciplina,
    COUNT(n.aluno_id) AS total_notas,
    COUNT(DISTINCT n.aluno_id) AS total_alunos,
    ROUND(AVG(n.nota)::numeric, 2) AS media,
    ROUND(STDDEV(n.nota)::numeric, 2) AS desvio_padrao,
    ROUND(MIN(n.nota)::numeric, 2) AS nota_minima,
    ROUND(MAX(n.nota)::numeric, 2) AS nota_maxima,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY n.nota)::numeric, 2) AS percentil_25,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n.nota)::numeric, 2) AS mediana,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY n.nota)::numeric, 2) AS percentil_75
FROM nota n
GROUP BY n.disciplina
ORDER BY media DESC;

-- Distribuicao por faixas de nota (histograma) por disciplina
SELECT 
    disciplina,
    COUNT(CASE WHEN nota >= 0 AND nota < 2 THEN 1 END) AS faixa_0_2,
    COUNT(CASE WHEN nota >= 2 AND nota < 4 THEN 1 END) AS faixa_2_4,
    COUNT(CASE WHEN nota >= 4 AND nota < 6 THEN 1 END) AS faixa_4_6,
    COUNT(CASE WHEN nota >= 6 AND nota < 8 THEN 1 END) AS faixa_6_8,
    COUNT(CASE WHEN nota >= 8 AND nota <= 10 THEN 1 END) AS faixa_8_10,
    COUNT(*) AS total_notas,
    ROUND(AVG(nota)::numeric, 2) AS media
FROM nota
GROUP BY disciplina
ORDER BY media DESC;

-- Ranking de disciplinas com melhor e pior desempenho
SELECT 
    disciplina,
    ROUND(AVG(nota)::numeric, 2) AS media_nota,
    RANK() OVER (ORDER BY AVG(nota) DESC) AS ranking_geral,
    CASE 
        WHEN AVG(nota) >= 7.0 THEN 'Excelente'
        WHEN AVG(nota) >= 6.0 THEN 'Bom'
        WHEN AVG(nota) >= 5.0 THEN 'Regular'
        ELSE 'Precisa Melhorar'
    END AS classificacao
FROM nota
GROUP BY disciplina
ORDER BY media_nota DESC;

-- Comparacao de disciplinas entre redes (publica vs privada)
SELECT 
    n.disciplina,
    e.rede,
    COUNT(n.nota) AS total_notas,
    ROUND(AVG(n.nota)::numeric, 2) AS media_nota,
    ROUND(STDDEV(n.nota)::numeric, 2) AS desvio_padrao
FROM nota n
JOIN aluno a ON n.aluno_id = a.id
JOIN escola e ON a.escola_id = e.escola_id
GROUP BY n.disciplina, e.rede
ORDER BY n.disciplina, media_nota DESC;

