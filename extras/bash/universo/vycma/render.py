#!/usr/bin/env python3
"""
VY Canis Majoris, procedural.

Hipergigante vermelha, uma das maiores estrelas conhecidas (cerca de 1.400 vezes o
raio do Sol). A superfície é feita de células de convecção enormes que fervem, com
o centro mais claro e a borda escurecida. Ela perde massa sem parar: em volta, uma
nuvem de poeira avermelhada com nós soltos, mais de um lado só. A superfície
ferve em loop e as estrelas de fundo piscam.

Uso: render.py [largura] [linhas] [fase 0..1] > quadro.ansi
     render.py 56 16 --frames 48 frames/
     render.py 56 16 0 --png previa.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from _comum import TAU, fbm, mix, run, smooth  # noqa: E402

CX, CY, R = 0.62, 0.52, 0.34     # estrela à esquerda; a nuvem se estende para a direita
SKY = [0.006, 0.003, 0.008]
POEIRA = [0.70, 0.20, 0.08]
QUENTE = [1.00, 0.52, 0.18]
MORNO = [0.80, 0.18, 0.03]
FRIO = [0.22, 0.02, 0.01]


def fundo(u, v):
    dx, dy = u - CX, v - CY
    d = math.hypot(dx, dy)
    luz = list(SKY)
    # nuvem de poeira assimétrica (mais para a direita) com nós soltos
    lado = smooth(-0.15, 0.35, dx)
    n = fbm(u * 4, v * 4, 61, 5)
    nuvem = math.exp(-max(0.0, d - R) / 0.30) * (0.25 + 0.75 * lado) * smooth(0.40, 0.85, n) * 0.30
    nos = smooth(0.80, 0.90, fbm(u * 14, v * 14, 83, 3)) * lado * math.exp(-max(0.0, d - R) / 0.35) * 0.6
    luz = [luz[i] + POEIRA[i] * (nuvem + nos) for i in range(3)]
    # brilho em volta da estrela (atmosfera estendida)
    glow = math.exp(-max(0.0, d - R) / 0.045) * smooth(R * 0.97, R * 1.02, d)
    luz = [luz[i] + MORNO[i] * glow * 0.5 for i in range(3)]
    return luz


def dinamico(u, v, fase):
    dx, dy = u - CX, v - CY
    d = math.hypot(dx, dy)
    if d > R * 1.02:
        return [0.0, 0.0, 0.0], 0.0
    alfa = smooth(R * 1.015, R * 0.985, d)
    mu = math.sqrt(max(0.0, 1 - (d / R) ** 2))          # escurecimento de borda
    # convecção fervendo em loop: o ruído anda num círculo, volta ao início no fim
    ox, oy = 0.35 * math.cos(TAU * fase), 0.35 * math.sin(TAU * fase)
    c1 = fbm(u * 5.5 + ox, v * 5.5 + oy, 91, 4)
    c2 = fbm(u * 11 - oy, v * 11 + ox, 97, 3)
    t = smooth(0.25, 0.80, c1 * 0.75 + c2 * 0.25)
    cor = mix(FRIO, MORNO, smooth(0.0, 0.55, t))
    cor = mix(cor, QUENTE, smooth(0.55, 1.0, t))
    b = (0.25 + 0.85 * mu ** 0.8) * 0.85
    return [cor[i] * b * alfa for i in range(3)], alfa


def evitar(u, v):
    return math.hypot(u - CX, v - CY) < R * 1.25


if __name__ == "__main__":
    run(fundo, dinamico, evitar, semente=2007)
