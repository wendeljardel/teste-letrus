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
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


@dataclass
class Escola:
    escola_id: str
    nome: str
    rede: str
    regiao: str

    def to_dict(self) -> dict:
        return {
            "escola_id": self.escola_id,
            "nome": self.nome,
            "rede": self.rede,
            "regiao": self.regiao
        }


@dataclass
class Aluno:
    id: str
    nome: str
    idade: int
    genero: str
    escola_id: str

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "nome": self.nome,
            "idade": self.idade,
            "genero": self.genero,
            "escola_id": self.escola_id
        }


@dataclass
class Nota:
    aluno_id: str
    disciplina: str
    nota: float

    def to_dict(self) -> dict:
        return {
            "aluno_id": self.aluno_id,
            "disciplina": self.disciplina,
            "nota": self.nota
        }


@dataclass
class DataGeneratorConfig:
    random_seed: int = 42
    num_escolas: int = 20
    num_alunos: int = 500
    num_notas_por_aluno: int = 6
    
    disciplinas: List[str] = field(default_factory=lambda: [
        "Matemática", "Português", "Ciências", "História", "Geografia", "Inglês"
    ])
    
    regioes: List[str] = field(default_factory=lambda: [
        "Norte", "Nordeste", "Centro-Oeste", "Sudeste", "Sul"
    ])
    
    redes: List[str] = field(default_factory=lambda: ["pública", "privada"])
    
    generos: List[str] = field(default_factory=lambda: ["M", "F", "Outro"])
    
    primeiros_nomes: List[str] = field(default_factory=lambda: [
        "Ana", "João", "Maria", "Pedro", "Juliana", "Carlos", "Fernanda",
        "Lucas", "Beatriz", "Rafael", "Camila", "Gabriel", "Mariana",
        "Felipe", "Larissa", "Bruno", "Patricia", "André", "Jessica",
        "Rodrigo", "Amanda", "Thiago", "Priscila", "Marcos", "Vanessa",
        "Daniel", "Juliana", "Ricardo", "Renata", "Gustavo", "Carolina",
        "Fábio", "Simone", "Leandro", "Tatiana", "Roberto", "Cristina",
        "Alexandre", "Monica", "Paulo", "Adriana", "Eduardo", "Carla"
    ])
    
    sobrenomes: List[str] = field(default_factory=lambda: [
        "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira",
        "Alves", "Pereira", "Lima", "Gomes", "Ribeiro", "Carvalho",
        "Almeida", "Lopes", "Martins", "Rocha", "Fernandes", "Costa",
        "Araújo", "Mendes", "Nascimento", "Moreira", "Freitas", "Barbosa",
        "Nunes", "Melo", "Teixeira", "Monteiro", "Cardoso", "Cavalcanti"
    ])


class NameGenerator:
    def __init__(self, config: DataGeneratorConfig):
        self.config = config
        random.seed(config.random_seed)
    
    def generate_full_name(self) -> str:
        primeiro = random.choice(self.config.primeiros_nomes)
        sobrenome1 = random.choice(self.config.sobrenomes)
        sobrenome2 = random.choice(self.config.sobrenomes)
        return f"{primeiro} {sobrenome1} {sobrenome2}"


class EscolaGenerator:
    def __init__(self, config: DataGeneratorConfig, name_generator: NameGenerator):
        self.config = config
        self.name_generator = name_generator
    
    def generate(self) -> List[Escola]:
        escolas = []
        tipos_escola = ['publica', 'privada']
        tipos_escola_publica = ['Municipal', 'Estadual']
        prefixos_escola_privada = ['Centro Educacional', "Colégio", "Escola"]
        sufixos_escola_privada = ['de Ensino']
        
        for i in range(1, self.config.num_escolas + 1):
            escola_id = f"ESC{i:03d}"
            primeiro_nome = self.name_generator.generate_full_name().split()[0] + " " + self.name_generator.generate_full_name().split()[1]
            tipo = random.choice(tipos_escola)
            if tipo =='publica':
                rede = 'pública'
                sufixo = random.choice(tipos_escola_publica)
                nome = f"Escola {sufixo} {primeiro_nome}"
            else:
                rede = 'privada'
                prefixo = random.choice(prefixos_escola_privada)
                nome = f"{prefixo} {primeiro_nome}"
            regiao = random.choice(self.config.regioes)
            
            escolas.append(Escola(
                escola_id=escola_id,
                nome=nome,
                rede=rede,
                regiao=regiao
            ))
        
        return escolas


class AlunoGenerator:
    def __init__(self, config: DataGeneratorConfig, name_generator: NameGenerator):
        self.config = config
        self.name_generator = name_generator
    
    def generate(self, escolas: List[Escola]) -> List[Aluno]:
        alunos = []
        escola_ids = [e.escola_id for e in escolas]
        
        for i in range(1, self.config.num_alunos + 1):
            aluno_id = f"ALU{i:05d}"
            nome = self.name_generator.generate_full_name()
            idade = random.randint(10, 18)
            genero = random.choice(self.config.generos)
            escola_id = random.choice(escola_ids)
            
            alunos.append(Aluno(
                id=aluno_id,
                nome=nome,
                idade=idade,
                genero=genero,
                escola_id=escola_id
            ))
        
        return alunos


class NotaGenerator:
    def __init__(self, config: DataGeneratorConfig):
        self.config = config
    
    def generate(self, alunos: List[Aluno]) -> List[Nota]:
        notas = []
        aluno_ids = [a.id for a in alunos]
        
        for aluno_id in aluno_ids:
            for disciplina in self.config.disciplinas:
                rand = random.random()
                if rand < 0.10:
                    nota = round(random.uniform(0, 4), 1)
                elif rand < 0.85:
                    nota = round(random.uniform(5, 9), 1)
                else:
                    nota = round(random.uniform(9, 10), 1)
                
                notas.append(Nota(
                    aluno_id=aluno_id,
                    disciplina=disciplina,
                    nota=nota
                ))
        
        return notas


class DatasetWriter:
    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def write_escolas(self, escolas: List[Escola]) -> Path:
        escolas_data = [e.to_dict() for e in escolas]
        df = pd.DataFrame(escolas_data)
        path = self.output_dir / "escolas.csv"
        df.to_csv(path, index=False, encoding='utf-8')
        return path
    
    def write_alunos(self, alunos: List[Aluno]) -> Path:
        alunos_data = [a.to_dict() for a in alunos]
        df = pd.DataFrame(alunos_data)
        path = self.output_dir / "alunos.csv"
        df.to_csv(path, index=False, encoding='utf-8')
        return path
    
    def write_notas(self, notas: List[Nota]) -> Path:
        notas_data = [n.to_dict() for n in notas]
        df = pd.DataFrame(notas_data)
        path = self.output_dir / "notas.csv"
        df.to_csv(path, index=False, encoding='utf-8')
        return path


class SyntheticDataGenerator:
    def __init__(self, config: Optional[DataGeneratorConfig] = None):
        self.config = config or DataGeneratorConfig()
        self.name_generator = NameGenerator(self.config)
        self.escola_generator = EscolaGenerator(self.config, self.name_generator)
        self.aluno_generator = AlunoGenerator(self.config, self.name_generator)
        self.nota_generator = NotaGenerator(self.config)
        random.seed(self.config.random_seed)
    
    def generate_all(self, output_dir: Path) -> dict:
        logger.info("Gerando datasets sinteticos...")
        logger.info(f"Configuracao: Escolas={self.config.num_escolas}, Alunos={self.config.num_alunos}, Disciplinas={len(self.config.disciplinas)}")
        
        writer = DatasetWriter(output_dir)
        
        logger.info("Gerando escolas...")
        escolas = self.escola_generator.generate()
        escolas_path = writer.write_escolas(escolas)
        logger.info(f"Criado: {escolas_path} ({len(escolas)} registros)")
        
        logger.info("Gerando alunos...")
        alunos = self.aluno_generator.generate(escolas)
        alunos_path = writer.write_alunos(alunos)
        logger.info(f"Criado: {alunos_path} ({len(alunos)} registros)")
        
        logger.info("Gerando notas...")
        notas = self.nota_generator.generate(alunos)
        notas_path = writer.write_notas(notas)
        logger.info(f"Criado: {notas_path} ({len(notas)} registros)")
        
        notas_df = pd.DataFrame([n.to_dict() for n in notas])
        media_notas = notas_df['nota'].mean()
        
        logger.info("Datasets sinteticos gerados com sucesso")
        logger.info(f"Estatisticas: Escolas={len(escolas)}, Alunos={len(alunos)}, Notas={len(notas)}, Media={media_notas:.2f}")
        logger.info("Arquivos criados em: data/raw/ (escolas.csv, alunos.csv, notas.csv)")
        
        return {
            "escolas": escolas,
            "alunos": alunos,
            "notas": notas,
            "paths": {
                "escolas": escolas_path,
                "alunos": alunos_path,
                "notas": notas_path
            }
        }


def main():
    config = DataGeneratorConfig()
    generator = SyntheticDataGenerator(config)
    output_dir = Path("data/raw")
    generator.generate_all(output_dir)


if __name__ == "__main__":
    main()
