#!/usr/bin/env python3
"""
Nebulosa do Caranguejo (M1) com o pulsar no centro, procedural.

O que sobrou da supernova vista em 1054: uma nuvem oval com filamentos vermelhos e
laranja (hidrogênio e enxofre) por fora e o brilho azulado de síncrotron por dentro.
No centro, o pulsar (estrela de nêutrons girando 30 vezes por segundo): pisca e
varre o espaço com dois feixes opostos que giram. As estrelas de fundo piscam.

Uso: render.py [largura] [linhas] [fase 0..1] > quadro.ansi
     render.py 56 16 --frames 48 frames/
     render.py 56 16 0 --png previa.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from _comum import TAU, fbm, mix, ridged, rot, run, smooth  # noqa: E402

CX, CY = 0.875, 0.50
ANG = math.radians(-32)          # eixo maior inclinado
SKY = [0.0, 0.0, 0.012]
SYNC = [0.42, 0.55, 1.00]        # síncrotron (azulado)
RED = [1.00, 0.22, 0.10]
ORANGE = [1.00, 0.55, 0.20]
YELLOW = [0.95, 0.85, 0.45]


def forma(u, v):
    x, y = rot(u - CX, v - CY, ANG)
    r = math.hypot(x / 0.62, y / 0.41)
    r2 = r + (fbm(u * 3.2, v * 3.2, 5, 3) - 0.5) * 0.38     # contorno irregular
    return x, y, r, r2


def fundo(u, v):
    x, y, r, r2 = forma(u, v)
    corpo = smooth(1.0, 0.72, r2)
    # brilho difuso de síncrotron no miolo
    sync = math.exp(-(r / 0.40) ** 2) * 0.55 * corpo
    # filamentos: rede de cristas, mais fortes na casca externa
    wu, wv = u + (fbm(u * 4, v * 4, 9, 3) - 0.5) * 0.25, v + (fbm(u * 4, v * 4, 13, 3) - 0.5) * 0.25
    fil = ridged(wu * 8.5, wv * 8.5, 21, 4) ** 8
    fil *= corpo * (0.35 + 0.65 * smooth(0.15, 0.85, r2))
    cor = mix(RED, ORANGE, smooth(0.45, 0.80, fbm(u * 5, v * 5, 31, 3)))
    cor = mix(cor, YELLOW, smooth(0.70, 0.85, fbm(u * 7, v * 7, 41, 3)) * 0.6)
    luz = [SKY[i] + SYNC[i] * sync + cor[i] * fil * 2.6 for i in range(3)]
    # poeira escura entre os filamentos (pouca)
    luz = [c * (0.80 + 0.20 * fbm(u * 12, v * 12, 51, 2)) for c in luz]
    return luz


def dinamico(u, v, fase):
    dx, dy = u - CX, v - CY
    d = math.hypot(dx, dy)
    if d > 0.55:
        return [0.0, 0.0, 0.0], 0.0
    pulso = (0.5 + 0.5 * math.cos(TAU * fase * 4)) ** 8         # 4 flashes por loop
    nucleo = math.exp(-(d / 0.013) ** 2) * (1.2 + 3.0 * pulso)
    halo = math.exp(-d / 0.05) * (0.15 + 0.35 * pulso)
    # dois feixes opostos girando (uma volta por loop)
    a = math.atan2(dy, dx) - TAU * fase
    da = min(abs(math.remainder(a, TAU)), abs(math.remainder(a - math.pi, TAU)))
    feixe = math.exp(-(da / 0.07) ** 2) * math.exp(-d / 0.28) * smooth(0.0, 0.025, d) * 0.85
    luz = [1.0 * nucleo + 0.55 * halo + 0.55 * feixe,
           1.0 * nucleo + 0.70 * halo + 0.78 * feixe,
           1.0 * nucleo + 1.00 * halo + 1.00 * feixe]
    return luz, 0.0


def evitar(u, v):
    return forma(u, v)[3] < 1.05


if __name__ == "__main__":
    run(fundo, dinamico, evitar, semente=1054)
