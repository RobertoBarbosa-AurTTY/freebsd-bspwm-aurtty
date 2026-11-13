#!/usr/bin/env python3
"""
Saturno e os anéis, procedural.

O planeta gira (uma volta por loop) com as faixas suaves cor de creme. Os anéis
inclinados passam na frente do planeta embaixo e por trás em cima, com a Divisão de
Cassini (o vão escuro) e a sombra do planeta caindo sobre eles. Titã, a maior lua,
dá uma volta por loop. As estrelas de fundo piscam.

Uso: render.py [largura] [linhas] [fase 0..1] > quadro.ansi
     render.py 56 16 --frames 48 frames/
     render.py 56 16 0 --png previa.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from _comum import TAU, ceu, esfera, fbm, gira, lua, luz, mix, rot, ruido3, run, smooth  # noqa: E402

CX, CY, R = 0.875, 0.50, 0.30
ANG = math.radians(-12)          # anéis um pouco inclinados na tela
ABRE = 0.30                      # quanto os anéis "abrem" (eixo menor / maior)
CREME = [0.95, 0.85, 0.62]
FAIXA = [0.78, 0.62, 0.40]
ANEL_A = [0.80, 0.74, 0.62]
ANEL_B = [0.96, 0.90, 0.76]
ANEL_C = [0.45, 0.42, 0.38]
TITA = [0.90, 0.68, 0.35]


def fundo(u, v):
    return ceu(u, v, 12)


def anel(u, v):
    """(rgb, alfa, frente) do anel neste ponto, ou None."""
    x, y = rot(u - CX, v - CY, -ANG)
    rr = math.hypot(x, y / ABRE) / R               # raio no plano dos anéis, em raios do planeta
    if rr < 1.25 or rr > 2.30:
        return None
    if rr < 1.52:                                   # anel C: fino e escuro
        cor, a = ANEL_C, 0.35
    elif rr < 1.95:                                 # anel B: o mais brilhante
        cor, a = ANEL_B, 0.95
    elif rr < 2.03:                                 # Divisão de Cassini
        cor, a = ANEL_C, 0.12
    else:                                           # anel A
        cor, a = ANEL_A, 0.80
    a *= 0.80 + 0.20 * math.sin(rr * 55)           # sulcos finos
    a *= smooth(1.25, 1.30, rr) * smooth(2.30, 2.24, rr)
    frente = y > 0
    # sombra do planeta nos anéis (atrás do planeta, do lado oposto ao Sol)
    sx, sy = x - 0.55 * R * 0.9, y / ABRE
    sombra = 0.25 if (not frente and abs(sy) < R and sx > 0) else 1.0
    b = 0.85 * sombra
    return [cor[i] * b * a for i in range(3)], a, frente


def planeta(u, v, fase):
    n = esfera(u - CX, v - CY, R)
    if not n:
        return None
    nx, ny, nz = gira(*n, TAU * fase, math.radians(-14))
    lat = math.asin(max(-1.0, min(1.0, ny)))
    t = ruido3(nx * 3, ny * 3, nz * 3, 51, 3)
    f = 0.5 + 0.5 * math.sin(lat * 9 + (t - 0.5) * 1.2)
    cor = mix(FAIXA, CREME, smooth(0.25, 0.85, f))
    b = luz(*n) * (0.5 + 0.5 * n[2] ** 0.3)
    # sombra dos anéis no planeta: faixa logo acima do equador
    x, y = rot(u - CX, v - CY, -ANG)
    if -0.055 < y < -0.012 and abs(x) < R:
        b *= 0.45
    return [cor[i] * b * 1.05 for i in range(3)], 1.0


def dinamico(u, v, fase):
    # Titã (uma volta por loop, órbita larga)
    a = TAU * (fase + 0.35)
    tx, ty = rot(0.80 * math.cos(a), 0.80 * ABRE * math.sin(a), ANG)
    tita = lua(u, v, CX + tx, CY + ty, 0.024, TITA)
    if tita and math.sin(a) > 0:
        return tita
    an = anel(u, v)
    if an and an[2]:                                # anel na frente do planeta
        p = planeta(u, v, fase)
        base = p[0] if p else [0.0, 0.0, 0.0]
        return [base[i] * (1 - an[1]) + an[0][i] for i in range(3)], 1.0 if p else an[1]
    p = planeta(u, v, fase)
    if p:
        return p
    if tita:
        return tita
    if an:
        return an[0], an[1]
    return [0.0, 0.0, 0.0], 0.0


def evitar(u, v):
    x, y = rot(u - CX, v - CY, -ANG)
    return math.hypot(x, y / ABRE) < R * 2.5 or math.hypot(u - CX, v - CY) < R * 1.2


if __name__ == "__main__":
    run(fundo, dinamico, evitar, semente=1610 + 55)
