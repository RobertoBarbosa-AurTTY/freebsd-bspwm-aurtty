#!/usr/bin/env python3
"""
Eta Carinae e o Homúnculo, procedural.

Eta Carinae é uma das estrelas mais massivas conhecidas (ainda não virou supernova).
Na Grande Erupção de 1843 ela expulsou a nuvem dupla chamada Homúnculo: dois lóbulos
de gás e poeira cor de cobre, com a borda mais brilhante, uma "saia" fina de matéria
no equador e a estrela brilhante no meio, com os raios de difração do Hubble.
Ao fundo, o gás avermelhado da Nebulosa de Carina. A estrela cintila e as estrelas
de fundo piscam.

Uso: render.py [largura] [linhas] [fase 0..1] > quadro.ansi
     render.py 56 16 --frames 48 frames/
     render.py 56 16 0 --png previa.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from _comum import TAU, fbm, mix, rot, run, smooth  # noqa: E402

CX, CY = 0.875, 0.50
ANG = math.radians(-50)          # eixo dos lóbulos: de cima/esquerda para baixo/direita
SKY = [0.010, 0.004, 0.012]
GAS = [0.40, 0.07, 0.14]         # Nebulosa de Carina ao fundo
LOBO = [0.95, 0.52, 0.28]
LOBO_ESC = [0.42, 0.18, 0.10]
SAIA = [1.00, 0.78, 0.55]


def lobos(u, v):
    x, y = rot(u - CX, v - CY, ANG)          # x ao longo do eixo, y perpendicular
    dens = 0.0
    for s, ganho in ((1, 1.0), (-1, 0.80)):  # o lóbulo de baixo/direita fica mais perto: mais claro
        ax = s * x
        # gota: estreita junto da estrela, larga na ponta
        rb = 0.20 * (0.40 + 0.60 * smooth(-0.02, 0.34, ax))
        d = math.hypot((ax - 0.255) / 0.255, y / rb)
        cheio = smooth(1.04, 0.80, d)
        borda = math.exp(-((d - 0.93) / 0.11) ** 2) * smooth(-0.02, 0.06, ax)
        dens = max(dens, (cheio * 0.55 + borda * 0.9) * ganho)
    return x, y, dens


def fundo(u, v):
    x, y, dens = lobos(u, v)
    n = fbm(u * 10, v * 10, 3, 4)
    # gás de Carina ao fundo
    g = fbm(u * 2.5, v * 2.5, 7, 5)
    luz = [SKY[i] + GAS[i] * smooth(0.45, 0.90, g) * 0.55 for i in range(3)]
    luz = [luz[i] + [0.10, 0.12, 0.30][i] * smooth(0.55, 0.9, fbm(u * 3, v * 3, 17, 4)) * 0.25 for i in range(3)]
    # lóbulos manchados de poeira
    cor = mix(LOBO_ESC, LOBO, smooth(0.30, 0.70, n))
    m = dens * (0.55 + 0.75 * n)
    luz = [luz[i] * (1 - min(1.0, dens * 1.3)) + cor[i] * m * 1.5 for i in range(3)]
    # saia equatorial: faixa fina perpendicular ao eixo, com raias
    raias = 0.55 + 0.45 * fbm(y * 30, 0.5, 23, 2)
    saia = math.exp(-(x / 0.020) ** 2) * smooth(0.24, 0.04, abs(y)) * raias
    luz = [luz[i] + SAIA[i] * saia * 0.55 for i in range(3)]
    return luz


def dinamico(u, v, fase):
    dx, dy = u - CX, v - CY
    d = math.hypot(dx, dy)
    if d > 0.30:
        return [0.0, 0.0, 0.0], 0.0
    cint = 1.0 + 0.30 * math.sin(TAU * fase * 2) + 0.15 * math.sin(TAU * fase * 5 + 1.3)
    nucleo = math.exp(-(d / 0.016) ** 2) * 3.0 * cint
    halo = math.exp(-d / 0.045) * 0.55 * cint
    # raios de difração (cruz) como nas fotos do Hubble
    raio = (math.exp(-abs(dy) / 0.006) * math.exp(-abs(dx) / 0.14)
            + math.exp(-abs(dx) / 0.006) * math.exp(-abs(dy) / 0.14)) * 0.55 * cint
    b = nucleo + halo + raio
    return [b * 1.0, b * 0.93, b * 0.85], 0.0


def evitar(u, v):
    return lobos(u, v)[2] > 0.05 or math.hypot(u - CX, v - CY) < 0.12


if __name__ == "__main__":
    run(fundo, dinamico, evitar, semente=1843)
