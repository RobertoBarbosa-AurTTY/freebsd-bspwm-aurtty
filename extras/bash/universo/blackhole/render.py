#!/usr/bin/env python3
"""
Ray tracer de buraco negro (Schwarzschild) para o terminal.

Cada raio de luz e integrado na geometria de Schwarzschild (unidades com rs = 1),
usando a forma classica  a = -1.5 * h^2 * r_vec / r^5  (h = momento angular),
que reproduz exatamente a curvatura da luz. O disco de acrecao e fino, no plano
y = 0, com perfil de temperatura de Shakura-Sunyaev e efeito Doppler relativistico
(o lado que se aproxima fica mais brilhante e azulado, o que se afasta mais escuro).

Saida: arquivo ANSI truecolor usando o caractere "▀" (2 pixels por celula).
Uso: render.py [largura_colunas] [altura_linhas] [fase] > quadro.ansi
(fase = tempo da animacao: o plasma gira mais rapido perto do buraco, lei de Kepler)
"""
import math
import sys
from multiprocessing import Pool

W = int(sys.argv[1]) if len(sys.argv) > 1 else 80
ROWS = int(sys.argv[2]) if len(sys.argv) > 2 else 20
PHASE = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
H = ROWS * 2                      # pixels verticais (meio-bloco)

CAM_DIST = 26.0                   # distancia da camera (em raios de Schwarzschild)
INCL = math.radians(87.5)         # quase de lado, como o Gargantua
FOV = 0.47                        # campo de visao horizontal (radianos)
R_IN, R_OUT = 1.7, 11.0           # Gargantua gira muito rapido: o disco chega quase ao horizonte
STAR_SEED = 1337
SS = 3                            # superamostragem: SS x SS raios por pixel
DOPPLER = 0.25                    # Gargantua: Doppler quase removido (como no filme)


def norm(v):
    l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    return (v[0] / l, v[1] / l, v[2] / l)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


# camera: olha para a origem, levemente acima do plano do disco
cam = (0.0, CAM_DIST * math.cos(INCL), -CAM_DIST * math.sin(INCL))
fwd = norm((-cam[0], -cam[1], -cam[2]))
right = norm(cross((0.0, 1.0, 0.0), fwd))
up = cross(fwd, right)


def blackbody(t):
    """t em [0, ~1.6]: cor aproximada de corpo negro (vermelho -> laranja -> branco -> azulado)."""
    stops = [
        (0.00, (0.0, 0.0, 0.0)),
        (0.15, (0.45, 0.05, 0.0)),
        (0.35, (0.95, 0.30, 0.02)),
        (0.60, (1.00, 0.62, 0.20)),
        (0.85, (1.00, 0.86, 0.62)),
        (1.10, (1.00, 0.97, 0.92)),
        (1.60, (0.80, 0.88, 1.00)),
    ]
    if t <= 0:
        return stops[0][1]
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if t <= b:
            f = (t - a) / (b - a)
            return tuple(ca[i] + (cb[i] - ca[i]) * f for i in range(3))
    return stops[-1][1]


def gold(t):
    """Paleta do Gargantua: laranja queimado -> dourado -> branco quente."""
    stops = [(0.0, (0.55, 0.20, 0.03)), (0.45, (0.95, 0.55, 0.15)),
             (0.75, (1.00, 0.78, 0.42)), (1.00, (1.00, 0.92, 0.75))]
    t = max(0.0, min(1.0, t))
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if t <= b:
            f = (t - a) / (b - a)
            return tuple(ca[i] + (cb[i] - ca[i]) * f for i in range(3))
    return stops[-1][1]


def disk_color(p, d):
    """Cor emitida pelo disco no ponto p, para um foton viajando na direcao d."""
    r = math.hypot(p[0], p[2])
    # temperatura (Shakura-Sunyaev, com borda interna em R_IN)
    temp = (R_IN / r) ** 0.75 * max(0.0, 1.0 - math.sqrt(R_IN / r)) ** 0.25
    temp /= 0.488                  # normaliza o pico em ~1
    # velocidade orbital kepleriana (rs = 1): v = sqrt(1 / (2 (r - 1)))
    v = min(0.75, math.sqrt(0.5 / (r - 1.0)))
    vel = (-p[2] / r * v, 0.0, p[0] / r * v)          # rotacao no plano xz
    gamma = 1.0 / math.sqrt(1.0 - v * v)
    # o foton chega a camera viajando ao longo de -d (raio tracado ao contrario)
    cos_t = -(vel[0] * d[0] + vel[1] * d[1] + vel[2] * d[2]) / v
    g = 1.0 / (gamma * (1.0 - v * cos_t))              # fator Doppler
    g *= math.sqrt(1.0 - 1.0 / r)                      # desvio gravitacional
    g = 1.0 + (g - 1.0) * DOPPLER
    intensity = temp ** 4 * g ** 3.5
    # textura sutil de turbulencia (aneis)
    # rotacao diferencial: velocidade angular ~ r^-1.5 (o interior gira mais rapido)
    ang = math.atan2(p[2], p[0]) - PHASE * (R_IN / r) ** 1.5
    # bracos espirais de plasma mais quente + faixas finas de turbulencia
    arms = (0.5 + 0.5 * math.sin(3.0 * ang - 4.0 * math.log(r))) ** 2
    tex = 0.72 + 0.32 * arms + 0.08 * math.sin(r * 5.3 + 2.0 * math.sin(ang * 3.0 + r))
    c = gold(temp * g)
    k = min(1.4, intensity * 1.5) * tex
    return (c[0] * k, c[1] * k, c[2] * k)


def star_color(d):
    """Campo de estrelas procedural (deterministico) na direcao d."""
    u = math.atan2(d[0], d[2])
    v = math.asin(max(-1.0, min(1.0, d[1])))
    cu, cv = int(u * 90), int(v * 90)
    h = (cu * 73856093 ^ cv * 19349663 ^ STAR_SEED) & 0xFFFFFFFF
    h = (h * 2654435761) & 0xFFFFFFFF
    if h % 263 == 0:
        b = 0.10 + (h >> 8) % 100 / 400.0
        tint = (h >> 16) % 3
        return (b * (0.85 if tint == 0 else 1.0), b * 0.95, b * (1.0 if tint else 0.8))
    return (0.0008, 0.0008, 0.0016)   # fundo do espaco: quase preto, levemente azulado


def trace(px, py):
    sx = (px - W / 2) / W * FOV * 2
    sy = -(py - H / 2) / W * FOV * 2
    d = norm((fwd[0] + right[0] * sx + up[0] * sy,
              fwd[1] + right[1] * sx + up[1] * sy,
              fwd[2] + right[2] * sx + up[2] * sy))
    p = list(cam)
    vel = list(d)
    h = cross(p, vel)
    h2 = h[0] * h[0] + h[1] * h[1] + h[2] * h[2]
    col = [0.0, 0.0, 0.0]
    alpha = 1.0                    # transparencia restante (disco e semi-opaco)
    for _ in range(3000):
        r2 = p[0] * p[0] + p[1] * p[1] + p[2] * p[2]
        r = math.sqrt(r2)
        if r < 1.0:                # caiu no horizonte de eventos
            return col, True
        if r > CAM_DIST * 1.6:     # escapou: fundo transparente (sem estrelas)
            return col, False
        dt = 0.08 * min(r, 6.0) if r < 8 else 0.4
        # integracao (Verlet) da equacao de geodesica nula
        a = -1.5 * h2 / (r2 * r2 * r)
        np_ = [p[i] + vel[i] * dt + 0.5 * a * p[i] * dt * dt for i in range(3)]
        rn = math.sqrt(np_[0] ** 2 + np_[1] ** 2 + np_[2] ** 2)
        an = -1.5 * h2 / (rn ** 5)
        nv = [vel[i] + 0.5 * (a * p[i] + an * np_[i]) * dt for i in range(3)]
        # cruzou o plano do disco?
        if (p[1] > 0) != (np_[1] > 0):
            f = p[1] / (p[1] - np_[1])
            hit = [p[i] + (np_[i] - p[i]) * f for i in range(3)]
            rh = math.hypot(hit[0], hit[2])
            if R_IN <= rh <= R_OUT:
                edge = min(1.0, (R_OUT - rh) / 5.0) ** 1.5      # borda externa suave
                c = disk_color(hit, norm(vel))
                op = 0.92 * edge
                for i in range(3):
                    col[i] += alpha * op * c[i]
                alpha *= 1.0 - op
                if alpha < 0.02:
                    return col, False
        p, vel = np_, nv
    return col, False


def render_row(py):
    row = []
    for px in range(W):
        acc = [0.0, 0.0, 0.0, 0.0]          # r, g, b, fracao dentro do horizonte
        for j in range(SS):
            for i in range(SS):
                c, hole = trace(px + (i + 0.5) / SS, py + (j + 0.5) / SS)
                for k in range(3):
                    acc[k] += c[k]
                acc[3] += hole
        row.append([a / (SS * SS) for a in acc])
    return row


def tonemap(c):
    out = []
    for x in c:
        x = 1.0 - math.exp(-1.0 * x)                     # exposicao (estilo filme)
        x = x ** (1 / 2.2)                               # gamma
        out.append(x)
    lum = 0.3 * out[0] + 0.6 * out[1] + 0.1 * out[2]
    sat = 1.7                                           # cor mais quente/saturada
    return [max(0, min(255, int((lum + (x - lum) * sat) * 255 + 0.5))) for x in out]


if __name__ == "__main__":
    with Pool() as pool:
        img = pool.map(render_row, range(H))
    # bloom: brilho suave em volta das areas mais claras (como lente de camera)
    glow = [[[0.0] * 3 for _ in range(W)] for _ in range(H)]
    R = 3
    for y in range(H):
        for x in range(W):
            c = img[y][x]
            lum = 0.3 * c[0] + 0.6 * c[1] + 0.1 * c[2]
            if lum > 0.9:
                for dy in range(-R, R + 1):
                    for dx in range(-R * 2, R * 2 + 1):
                        yy, xx = y + dy, x + dx
                        if 0 <= yy < H and 0 <= xx < W:
                            w = math.exp(-(dx * dx / 4 + dy * dy) / 3.0) * 0.02 * (lum - 0.9)
                            for i in range(3):
                                glow[yy][xx][i] += c[i] * w
    pix = [[tonemap([img[y][x][i] + glow[y][x][i] for i in range(3)]) for x in range(W)] for y in range(H)]
    # fundo transparente: so pinta o pixel se tiver disco/brilho ou se for a sombra (preta)
    opaque = [[img[y][x][3] >= 0.5 or max(pix[y][x]) >= 34 for x in range(W)] for y in range(H)]
    for y in range(H):
        for x in range(W):
            if img[y][x][3] >= 0.5 and max(pix[y][x]) < 34:
                pix[y][x] = [0, 0, 0]
    lines = []
    for row in range(ROWS):
        top, bot = pix[row * 2], pix[row * 2 + 1]
        s = ["  "]
        for x in range(W):
            t, b = top[x], bot[x]
            to, bo = opaque[row * 2][x], opaque[row * 2 + 1][x]
            if to and bo:
                s.append(f"\x1b[38;2;{t[0]};{t[1]};{t[2]}m\x1b[48;2;{b[0]};{b[1]};{b[2]}m▀")
            elif to:
                s.append(f"\x1b[0m\x1b[38;2;{t[0]};{t[1]};{t[2]}m▀")
            elif bo:
                s.append(f"\x1b[0m\x1b[38;2;{b[0]};{b[1]};{b[2]}m▄")
            else:
                s.append("\x1b[0m ")
        s.append("\x1b[0m")
        lines.append("".join(s))
    sys.stdout.write("\n".join(lines) + "\n")
