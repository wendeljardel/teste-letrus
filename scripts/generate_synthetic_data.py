#!/usr/bin/env python3
"""
Script para gerar datasets sintéticos para o case de Engenharia de Dados.

Gera três datasets:
1. alunos.csv - Informações dos alunos
2. escolas.csv - Informações das escolas
3. notas.csv - Notas dos alunos por disciplina
"""

import pandas as pd
import random
from pathlib import Path

# Configurações
RANDOM_SEED = 42
NUM_ESCOLAS = 20
NUM_ALUNOS = 500
NUM_NOTAS_POR_ALUNO = 6  # 6 disciplinas por aluno

# Disciplinas
DISCIPLINAS = [
    "Matemática",
    "Português",
    "Ciências",
    "História",
    "Geografia",
    "Inglês"
]

# Regiões brasileiras
REGIOES = [
    "Norte",
    "Nordeste",
    "Centro-Oeste",
    "Sudeste",
    "Sul"
]

# Tipos de rede
REDES = ["pública", "privada"]

# Gêneros
GENEROS = ["M", "F", "Outro"]

# Nomes fictícios (primeiros nomes brasileiros comuns)
PRIMEIROS_NOMES = [
    "Ana", "João", "Maria", "Pedro", "Juliana", "Carlos", "Fernanda",
    "Lucas", "Beatriz", "Rafael", "Camila", "Gabriel", "Mariana",
    "Felipe", "Larissa", "Bruno", "Patricia", "André", "Jessica",
    "Rodrigo", "Amanda", "Thiago", "Priscila", "Marcos", "Vanessa",
    "Daniel", "Juliana", "Ricardo", "Renata", "Gustavo", "Carolina",
    "Fábio", "Simone", "Leandro", "Tatiana", "Roberto", "Cristina",
    "Alexandre", "Monica", "Paulo", "Adriana", "Eduardo", "Carla"
]

SOBRENOMES = [
    "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira",
    "Alves", "Pereira", "Lima", "Gomes", "Ribeiro", "Carvalho",
    "Almeida", "Lopes", "Martins", "Rocha", "Fernandes", "Costa",
    "Araújo", "Mendes", "Nascimento", "Moreira", "Freitas", "Barbosa",
    "Nunes", "Melo", "Teixeira", "Monteiro", "Cardoso", "Cavalcanti"
]

def gerar_nome_completo():
    """Gera um nome completo fictício."""
    primeiro = random.choice(PRIMEIROS_NOMES)
    sobrenome1 = random.choice(SOBRENOMES)
    sobrenome2 = random.choice(SOBRENOMES)
    return f"{primeiro} {sobrenome1} {sobrenome2}"

def gerar_escolas(num_escolas=NUM_ESCOLAS):
    """Gera dataset de escolas."""
    escolas = []
    
    for i in range(1, num_escolas + 1):
        escola_id = f"ESC{i:03d}"
        nome = f"Escola {random.choice(['Municipal', 'Estadual', 'Particular'])} {gerar_nome_completo().split()[0]} {random.choice(['de Ensino', 'Fundamental', 'Médio'])}"
        rede = random.choice(REDES)
        regiao = random.choice(REGIOES)
        
        escolas.append({
            "escola_id": escola_id,
            "nome": nome,
            "rede": rede,
            "regiao": regiao
        })
    
    return pd.DataFrame(escolas)

def gerar_alunos(num_alunos=NUM_ALUNOS, escolas_df=None):
    """Gera dataset de alunos."""
    alunos = []
    escola_ids = escolas_df["escola_id"].tolist()
    
    for i in range(1, num_alunos + 1):
        aluno_id = f"ALU{i:05d}"
        nome = gerar_nome_completo()
        idade = random.randint(10, 18)
        genero = random.choice(GENEROS)
        escola_id = random.choice(escola_ids)
        
        alunos.append({
            "id": aluno_id,
            "nome": nome,
            "idade": idade,
            "genero": genero,
            "escola_id": escola_id
        })
    
    return pd.DataFrame(alunos)

def gerar_notas(alunos_df=None):
    """Gera dataset de notas."""
    notas = []
    aluno_ids = alunos_df["id"].tolist()
    
    for aluno_id in aluno_ids:
        # Cada aluno tem notas em todas as disciplinas
        for disciplina in DISCIPLINAS:
            # Distribuição de notas: maioria entre 5-9, algumas abaixo e acima
            # Simula distribuição mais realista
            rand = random.random()
            if rand < 0.10:  # 10% notas baixas (0-4)
                nota = round(random.uniform(0, 4), 1)
            elif rand < 0.85:  # 75% notas médias (5-9)
                nota = round(random.uniform(5, 9), 1)
            else:  # 15% notas altas (9-10)
                nota = round(random.uniform(9, 10), 1)
            
            notas.append({
                "aluno_id": aluno_id,
                "disciplina": disciplina,
                "nota": nota
            })
    
    return pd.DataFrame(notas)

def main():
    """Função principal."""
    # Set seed para reprodutibilidade
    random.seed(RANDOM_SEED)
    
    print("🎓 Gerando datasets sintéticos...")
    print(f"📊 Configuração:")
    print(f"   - Escolas: {NUM_ESCOLAS}")
    print(f"   - Alunos: {NUM_ALUNOS}")
    print(f"   - Disciplinas: {len(DISCIPLINAS)}")
    print()
    
    # Criar diretório de output
    output_dir = Path("data/raw")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Gerar datasets
    print("📚 Gerando escolas...")
    escolas_df = gerar_escolas()
    escolas_path = output_dir / "escolas.csv"
    escolas_df.to_csv(escolas_path, index=False, encoding='utf-8')
    print(f"   ✅ Criado: {escolas_path} ({len(escolas_df)} registros)")
    
    print("👥 Gerando alunos...")
    alunos_df = gerar_alunos(escolas_df=escolas_df)
    alunos_path = output_dir / "alunos.csv"
    alunos_df.to_csv(alunos_path, index=False, encoding='utf-8')
    print(f"   ✅ Criado: {alunos_path} ({len(alunos_df)} registros)")
    
    print("📝 Gerando notas...")
    notas_df = gerar_notas(alunos_df=alunos_df)
    notas_path = output_dir / "notas.csv"
    notas_df.to_csv(notas_path, index=False, encoding='utf-8')
    print(f"   ✅ Criado: {notas_path} ({len(notas_df)} registros)")
    
    print()
    print("✨ Datasets sintéticos gerados com sucesso!")
    print()
    print("📊 Estatísticas:")
    print(f"   - Total de escolas: {len(escolas_df)}")
    print(f"   - Total de alunos: {len(alunos_df)}")
    print(f"   - Total de notas: {len(notas_df)}")
    print(f"   - Média de notas: {notas_df['nota'].mean():.2f}")
    print()
    print("📁 Arquivos criados em: data/raw/")
    print("   - escolas.csv")
    print("   - alunos.csv")
    print("   - notas.csv")

if __name__ == "__main__":
    main()
