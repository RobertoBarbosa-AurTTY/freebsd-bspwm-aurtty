#!/usr/bin/env python3
"""
55 Cancri e, o "planeta de diamante", procedural (versão artística).

Um planeta rochoso colado na sua estrela, que ficou famoso porque um estudo sugeriu
que ele teria tanto carbono que parte do interior seria diamante (hoje isso é só uma
hipótese). Aqui ele aparece como uma esfera de facetas cristalinas escuras: cada
faceta reflete a luz da estrela (55 Cancri, amarela, à esquerda) num ângulo próprio,
com um pouco de dispersão de cor, e as facetas cintilam enquanto o planeta gira.

Uso: render.py [largura] [linhas] [fase 0..1] > quadro.ansi
     render.py 56 16 --frames 48 frames/
     render.py 56 16 0 --png previa.png
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from _comum import TAU, ceu, esfera, gira, run, smooth  # noqa: E402

CX, CY, R = 1.02, 0.50, 0.36
ESTRELA = (0.10, 0.42)           # a estrela fica à esquerda, parcialmente fora da tela
SOL = [1.00, 0.82, 0.50]
L = (-0.80, -0.15, 0.58)
_l = math.sqrt(sum(c * c for c in L))
L = tuple(c / _l for c in L)
H = (L[0], L[1], L[2] + 1.0)     # meio caminho entre a luz e o olho (brilho especular)
_h = math.sqrt(sum(c * c for c in H))
H = tuple(c / _h for c in H)

# centros das facetas espalhados na esfera (Fibonacci + jitter)
rng = random.Random(55)
FACETAS = []
N = 90
for i in range(N):
    y = 1 - 2 * (i + 0.5) / N
    r = math.sqrt(1 - y * y)
    t = i * math.pi * (3 - math.sqrt(5)) + rng.uniform(-0.25, 0.25)
    # inclinação própria de cada faceta: assim várias cintilam ao mesmo tempo
    FACETAS.append((r * math.cos(t), y, r * math.sin(t), rng.random(),
                    rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45)))


def fundo(u, v):
    c = ceu(u, v, 55)
    d = math.hypot(u - ESTRELA[0], v - ESTRELA[1])
    brilho = math.exp(-d / 0.08) * 2.2 + math.exp(-d / 0.30) * 0.10
    disco = smooth(0.105, 0.095, d) * 2.5
    return [c[i] + SOL[i] * (brilho + disco) for i in range(3)]


def matiz(h):
    """Cor do arco-íris para a dispersão (h de 0 a 1)."""
    return [0.5 + 0.5 * math.cos(TAU * (h + k)) for k in (0.0, 0.33, 0.67)]


def dinamico(u, v, fase):
    n = esfera(u - CX, v - CY, R)
    if not n:
        return [0.0, 0.0, 0.0], 0.0
    p = gira(*n, -TAU * fase, math.radians(15))     # ponto no corpo do planeta
    # faceta mais próxima: a normal é a do centro dela (superfície plana, lapidada)
    melhor, seg, fac = -2.0, -2.0, None
    for f in FACETAS:
        d = p[0] * f[0] + p[1] * f[1] + p[2] * f[2]
        if d > melhor:
            melhor, seg, fac = d, melhor, f
        elif d > seg:
            seg = d
    # volta a normal da faceta para o espaço da tela
    fx, fy, fz = fac[0] + fac[4] * 0.6, fac[1] + fac[5] * 0.6, fac[2]
    nf = math.sqrt(fx * fx + fy * fy + fz * fz)
    fx, fy, fz = fx / nf, fy / nf, fz / nf
    a = TAU * fase
    c, s = math.cos(a), math.sin(a)
    fx, fz = fx * c + fz * s, -fx * s + fz * c
    i = math.radians(-15)
    fy, fz = fy * math.cos(i) - fz * math.sin(i), fy * math.sin(i) + fz * math.cos(i)
    dif = max(0.0, fx * L[0] + fy * L[1] + fz * L[2])
    esp = max(0.0, fx * H[0] + fy * H[1] + fz * H[2]) ** 24
    aresta = smooth(0.012, 0.0, melhor - seg)         # linhas entre as facetas
    base = [0.012, 0.016, 0.028]
    cor = [base[k] + dif * 0.10 * [0.55, 0.65, 0.85][k] for k in range(3)]
    disp = matiz(fac[3] + fase * 0.5)
    cor = [cor[k] + esp * (2.4 * SOL[k] * 0.6 + 1.2 * disp[k]) for k in range(3)]
    cor = [cor[k] * (1 - 0.55 * aresta) + aresta * 0.10 * dif for k in range(3)]
    # borda iluminada (reflexo de fresnel)
    fr = (1 - n[2]) ** 3 * max(0.0, n[0] * L[0] + n[1] * L[1]) * 0.7
    return [cor[k] + fr * [0.7, 0.85, 1.0][k] for k in range(3)], 1.0


def evitar(u, v):
    return (math.hypot(u - CX, v - CY) < R * 1.1
            or math.hypot(u - ESTRELA[0], v - ESTRELA[1]) < 0.22)


if __name__ == "__main__":
    run(fundo, dinamico, evitar, semente=2004)
