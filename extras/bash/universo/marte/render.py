#!/usr/bin/env python3
"""
Marte e Fobos, procedural.

O planeta gira (uma volta por loop): solo cor de ferrugem com as manchas escuras de
rocha (como Syrtis Major), a calota polar branca no norte e uma atmosfera fina
rosada na borda. Fobos, a lua maior, pequena e irregular, dá duas voltas por loop
bem perto do planeta, passando na frente e por trás. As estrelas de fundo piscam.

Uso: render.py [largura] [linhas] [fase 0..1] > quadro.ansi
     render.py 56 16 --frames 48 frames/
     render.py 56 16 0 --png previa.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from _comum import TAU, ceu, esfera, fbm, gira, luz, mix, ruido3, run, smooth  # noqa: E402

CX, CY, R = 0.875, 0.50, 0.36
INCL = math.radians(25)          # eixo inclinado: a calota norte aparece
FERRUGEM = [0.78, 0.28, 0.12]
CLARO = [0.90, 0.48, 0.26]
ESCURO = [0.30, 0.13, 0.08]
GELO = [0.96, 0.95, 0.94]
ATM = [1.00, 0.55, 0.45]
ORB, TILT = 0.55, 0.22           # órbita de Fobos


def fundo(u, v):
    c = ceu(u, v, 8)
    # atmosfera fina: brilho rosado logo fora da borda iluminada
    d = math.hypot(u - CX, v - CY)
    halo = math.exp(-max(0.0, d - R) / 0.018) * smooth(R * 0.99, R * 1.01, d)
    lado = max(0.0, -(u - CX) * 0.8 - (v - CY) * 0.4) / R
    return [c[i] + ATM[i] * halo * 0.35 * (0.3 + lado) for i in range(3)]


def planeta(u, v, fase):
    n = esfera(u - CX, v - CY, R)
    if not n:
        return None
    nx, ny, nz = gira(*n, TAU * fase, INCL)
    lat = math.asin(max(-1.0, min(1.0, -ny)))     # norte para cima
    solo = ruido3(nx * 3, ny * 3, nz * 3, 21, 5)
    det = ruido3(nx * 9, ny * 9, nz * 9, 33, 3)
    cor = mix(FERRUGEM, CLARO, smooth(0.45, 0.70, det))
    cor = mix(cor, ESCURO, smooth(0.47, 0.60, solo) * 0.9)
    gelo = smooth(1.08, 1.20, lat + (det - 0.5) * 0.25)          # calota norte (~65°)
    gelo = max(gelo, smooth(1.30, 1.40, -lat) * 0.8)             # sul, quase escondida
    cor = mix(cor, GELO, gelo)
    b = luz(*n) * (0.55 + 0.45 * n[2] ** 0.3)
    # borda iluminada levemente rosada (atmosfera)
    borda = (1 - n[2]) ** 4 * max(0.0, luz(*n) - 0.1)
    return [cor[i] * b * 0.95 + ATM[i] * borda * 0.4 for i in range(3)], 1.0


def fobos(u, v, fase):
    a = TAU * (2 * fase + 0.15)
    lx, ly, z = CX + ORB * math.cos(a), CY + TILT * ORB * math.sin(a), math.sin(a)
    # batata irregular: elipse que gira com borda ruidosa
    dx, dy = u - lx, v - ly
    rx, ry = dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)
    q = math.hypot(rx / 0.034, ry / 0.024) + (fbm(rx * 60, ry * 60, 41, 2) - 0.5) * 0.35
    if q >= 1.0:
        return None, z
    nz = math.sqrt(max(0.0, 1 - min(1.0, q) ** 2))
    b = luz(rx / 0.034, ry / 0.024, nz, amb=0.05)
    cor = [0.55, 0.48, 0.42]
    cor = [c * (0.75 + 0.5 * fbm(u * 80, v * 80, 43, 2)) for c in cor]
    return ([cor[i] * b for i in range(3)], 1.0), z


def dinamico(u, v, fase):
    f, z = fobos(u, v, fase)
    if f and z > 0:
        return f
    p = planeta(u, v, fase)
    if p:
        return p
    if f:
        return f
    return [0.0, 0.0, 0.0], 0.0


def evitar(u, v):
    return math.hypot(u - CX, v - CY) < R * 1.15 or (abs(v - CY) < 0.16 and abs(u - CX) < 0.62)


if __name__ == "__main__":
    run(fundo, dinamico, evitar, semente=1877)
