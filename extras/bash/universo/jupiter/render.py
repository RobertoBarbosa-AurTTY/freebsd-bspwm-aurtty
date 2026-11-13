#!/usr/bin/env python3
"""
Júpiter e as luas de Galileu, procedural.

O planeta gira (uma volta por loop) com as faixas de nuvens bege e marrons, a
turbulência entre elas e a Grande Mancha Vermelha. Em volta, Io (amarela), Europa
(clara), Ganimedes (cinza) e Calisto (escura) orbitam no plano do equador e passam
na frente e por trás do planeta. As estrelas de fundo piscam.

Uso: render.py [largura] [linhas] [fase 0..1] > quadro.ansi
     render.py 56 16 --frames 48 frames/
     render.py 56 16 0 --png previa.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from _comum import TAU, ceu, esfera, fbm, gira, lua, luz, mix, ruido3, run, smooth  # noqa: E402

CX, CY, R = 0.875, 0.50, 0.38
INCL = math.radians(8)
CLARO = [0.95, 0.86, 0.70]
MEDIO = [0.80, 0.60, 0.40]
ESCURO = [0.52, 0.32, 0.20]
MANCHA = [0.85, 0.38, 0.22]
# luas: raio da órbita, voltas por loop, fase, tamanho, cor
LUAS = [(0.48, 4, 0.10, 0.022, [1.00, 0.88, 0.40]),     # Io
        (0.60, 2, 0.55, 0.020, [0.95, 0.92, 0.85]),     # Europa
        (0.72, 1, 0.30, 0.028, [0.62, 0.58, 0.52]),     # Ganimedes
        (0.84, 1, 0.80, 0.026, [0.42, 0.38, 0.34])]     # Calisto
TILT = 0.10                      # órbitas vistas quase de lado


def fundo(u, v):
    return ceu(u, v, 4)


def planeta(u, v, fase):
    n = esfera(u - CX, v - CY, R)
    if not n:
        return None
    nx, ny, nz = gira(*n, TAU * fase, INCL)
    lat = math.asin(max(-1.0, min(1.0, ny)))
    lon = math.atan2(nx, nz)
    turb = ruido3(nx * 4, ny * 4, nz * 4, 7, 4)
    faixa = 0.5 + 0.5 * math.sin(lat * 11 + (turb - 0.5) * 2.2)
    cor = mix(ESCURO, MEDIO, smooth(0.15, 0.55, faixa))
    cor = mix(cor, CLARO, smooth(0.55, 0.95, faixa))
    # Grande Mancha Vermelha (lat -22°)
    dl = math.remainder(lon - 1.0, TAU)
    gm = math.exp(-((dl / 0.32) ** 2 + ((lat + 0.38) / 0.10) ** 2))
    cor = mix(cor, MANCHA, smooth(0.25, 0.7, gm))
    cor = [c * (0.85 + 0.3 * fbm(lon * 3, lat * 20, 9, 3)) for c in cor]
    b = luz(*n) * (0.35 + 0.65 * n[2] ** 0.25)      # borda um pouco mais escura
    return [cor[i] * b * 1.15 for i in range(3)], 1.0


def dinamico(u, v, fase):
    luas_frente, luas_tras = [], []
    for raio, voltas, f0, tam, cor in LUAS:
        a = TAU * (voltas * fase + f0)
        lx, ly, z = CX + raio * math.cos(a), CY + TILT * raio * math.sin(a), math.sin(a)
        (luas_frente if z > 0 else luas_tras).append((lx, ly, tam, cor))
    for lx, ly, tam, cor in luas_frente:
        r = lua(u, v, lx, ly, tam, cor)
        if r:
            return r
    p = planeta(u, v, fase)
    if p:
        return p
    for lx, ly, tam, cor in luas_tras:
        r = lua(u, v, lx, ly, tam, cor)
        if r:
            return r
    return [0.0, 0.0, 0.0], 0.0


def evitar(u, v):
    return math.hypot(u - CX, v - CY) < R * 1.15 or abs(v - CY) < 0.12


if __name__ == "__main__":
    run(fundo, dinamico, evitar, semente=1610)
