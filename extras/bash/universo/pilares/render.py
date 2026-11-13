#!/usr/bin/env python3
"""
Pilares da Criacao (Nebulosa da Aguia, M16) para o terminal, procedural.

Tres colunas de gas e poeira (escuras, bordas douradas iluminadas por cima pelas
estrelas jovens do aglomerado NGC 6611) sobre o gas ionizado azul-esverdeado,
na paleta do Hubble. Animacao: so as estrelas piscam
(caracteres · + ✦ por cima do gas, que fica parado).

Saida: ANSI truecolor com "▀" (2 pixels por celula), mesmo formato do buraco negro.
Uso: render.py [largura] [linhas] [fase 0..1] > quadro.ansi
     render.py 56 16 --frames 48 frames/          (gera o loop inteiro)
     render.py [largura] [linhas] [fase] --png arquivo.png   (previa ampliada)
"""
import math
import random
import struct
import sys
import zlib

W = int(sys.argv[1]) if len(sys.argv) > 1 else 56
ROWS = int(sys.argv[2]) if len(sys.argv) > 2 else 16
PHASE = float(sys.argv[3]) if len(sys.argv) > 3 and not sys.argv[3].startswith("--") else 0.0
PNG = sys.argv[5] if len(sys.argv) > 5 and sys.argv[4] == "--png" else None
H = ROWS * 2
SS = 3                      # superamostragem por eixo
TAU = 2 * math.pi


# ---------- ruido (value noise + fbm), deterministico ----------
def _h(ix, iy, s):
    n = (ix * 374761393 + iy * 668265263 + s * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, s=0):
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = _h(ix, iy, s), _h(ix + 1, iy, s)
    c, d = _h(ix, iy + 1, s), _h(ix + 1, iy + 1, s)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


def fbm(x, y, s=0, oct=5):
    t, amp, f, norm = 0.0, 0.5, 1.0, 0.0
    for i in range(oct):
        t += amp * vnoise(x * f, y * f, s + i * 17)
        norm += amp
        amp *= 0.5
        f *= 2.03
    return t / norm


def mix(a, b, t):
    return [a[i] + (b[i] - a[i]) * t for i in range(3)]


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ---------- cena ----------
# animacao em loop: a fase percorre um circulo no espaco do ruido
# gas parado (so as estrelas cintilam): fase fixa no ruido
PX, PY = 0.35, 0.0

# pilares: (x da base, x do topo, v do topo, meia-largura base, meia-largura topo, semente)
# coordenadas: u em [0, 1.75] (proporcao da tela), v em [0, 1] de cima para baixo
PILLARS = [
    (0.50, 0.58, 0.04, 0.17, 0.060, 3),   # esquerdo: o mais alto, inclinado
    (0.98, 1.00, 0.36, 0.13, 0.050, 7),   # do meio
    (1.42, 1.38, 0.55, 0.11, 0.040, 11),  # direito: o menor
]

TEAL_DEEP = [0.02, 0.07, 0.10]
TEAL = [0.10, 0.42, 0.50]
GREEN = [0.30, 0.58, 0.45]
GOLD_GAS = [0.85, 0.62, 0.30]
DUST_DARK = [0.05, 0.02, 0.01]
DUST = [0.24, 0.09, 0.035]
RIM = [1.00, 0.78, 0.42]
RIM_HOT = [1.00, 0.95, 0.80]


def pillar_field(u, v):
    """Retorna (dentro 0..1, proximidade da borda iluminada 0..1, nucleo 0..1)."""
    best = (0.0, 0.0, 0.0)
    for xb, xt, vt, wb, wt, s in PILLARS:
        # borda "fervendo": deforma o dominio com ruido animado
        wu = (fbm(u * 6 + PX, v * 6 + PY, s, 4) - 0.5) * 0.10
        wv = (fbm(u * 6 + 40 + PX, v * 6 + PY, s + 1, 4) - 0.5) * 0.06
        uu, vv = u + wu, v + wv
        top = vt + (fbm(uu * 9, 3.0, s + 2, 3) - 0.5) * 0.08
        if vv < top - 0.05:
            continue
        t = max(0.0, min(1.0, (vv - top) / (1.0 - top)))   # 0 no topo, 1 na base
        xc = xt + (xb - xt) * t
        w = wt + (wb - wt) * t ** 1.2
        w *= 1.0 + (fbm(uu * 4, vv * 8, s + 3, 3) - 0.5) * 0.5   # protuberancias
        d = abs(uu - xc) / w                     # 0 no eixo, 1 na borda
        dt = (vv - top) / 0.05                  # perto do topo arredondado
        cap = math.sqrt(max(0.0, 1 - (1 - min(1.0, dt)) ** 2)) if dt < 1 else 1.0
        d = d / max(0.05, cap)
        inside = smooth(1.08, 0.92, d)
        if inside <= best[0]:
            continue
        # luz vem de cima (e um pouco da direita): borda superior e lado direito brilham
        side = 0.55 + 0.45 * (1 if uu > xc else 0.35)
        rim = smooth(0.62, 0.98, d) * side + (1 - min(1.0, dt * 0.6)) * 0.9
        rim *= 1.0 - 0.75 * t                    # base fica na sombra
        core = smooth(0.7, 0.0, d) * t
        best = (inside, max(0.0, min(1.0, rim)), core)
    return best


def background(u, v):
    n = fbm(u * 2.2 + PX * 0.6, v * 2.2 + PY * 0.6, 101, 5)
    n2 = fbm(u * 5 + 9 - PY, v * 5 + PX, 202, 4)
    # gas azul-esverdeado mais denso no alto, dourado em volta dos pilares, fundo escuro embaixo
    c = mix(TEAL_DEEP, TEAL, smooth(0.30, 0.75, n))
    c = mix(c, GREEN, smooth(0.55, 0.85, n2) * 0.6)
    glow = 0.0
    for xb, xt, vt, wb, wt, s in PILLARS:
        dx = (u - xt) / 0.30
        dy = (v - vt - 0.05) / 0.30
        glow += math.exp(-(dx * dx + dy * dy)) * 0.55
    c = mix(c, GOLD_GAS, min(0.8, glow * smooth(0.3, 0.7, n2)))
    c = [x * (0.55 + 0.45 * (1 - v * 0.6)) for x in c]
    # filamentos escuros de poeira
    dark = smooth(0.62, 0.80, fbm(u * 3.5 - PX, v * 3.5, 303, 4))
    return mix(c, [x * 0.25 for x in c], dark * 0.7)


def sample(u, v):
    inside, rim, core = pillar_field(u, v)
    bg = background(u, v)
    if inside <= 0:
        return bg
    mott = fbm(u * 10 + PX * 0.3, v * 10, 404, 4)
    body = mix(DUST_DARK, DUST, smooth(0.3, 0.8, mott) * (1 - core * 0.8))
    lit = mix(RIM, RIM_HOT, smooth(0.75, 1.0, rim))
    body = mix(body, lit, rim ** 1.6)
    return mix(bg, body, inside)


# estrelas: desenhadas como caracteres (· + ✦) por cima da celula, nao como pixel quadrado
rng = random.Random(618)
STARS = []          # (coluna, linha, brilho, fase, ciclos por loop, cor)
_used = set()
while len(STARS) < int(W * ROWS / 26):
    cx, cy = rng.randrange(W), rng.randrange(ROWS)
    if (cx, cy) in _used or pillar_field(cx / W * 1.75, (cy * 2 + 1) / H)[0] > 0.3:
        continue
    _used.add((cx, cy))
    STARS.append((cx, cy, rng.uniform(0.45, 1.0), rng.uniform(0, 1), rng.choice([1, 1, 2]),
                  rng.choice([[1.0, 0.97, 0.92], [0.82, 0.92, 1.0], [1.0, 0.88, 0.65]])))


def render():
    """Gas e pilares (sem estrelas): calculado uma vez so."""
    img = []
    for y in range(H):
        row = []
        for x in range(W):
            acc = [0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    u = (x + (sx + 0.5) / SS) / W * 1.75
                    v = (y + (sy + 0.5) / SS) / H
                    c = sample(u, v)
                    for i in range(3):
                        acc[i] += c[i]
            row.append([a / (SS * SS) for a in acc])
        img.append(row)
    return img


def star_glyph(b):
    """Brilho 0..1 -> caractere: some, ponto, cruz, estrela de 4 pontas."""
    if b < 0.18:
        return None
    if b < 0.45:
        return "·"
    if b < 0.75:
        return "+"
    return "✦"


def tonemap(c):
    out = []
    for x in c:
        x = 1.0 - math.exp(-1.6 * x)
        out.append(x ** (1 / 2.2))
    lum = 0.3 * out[0] + 0.6 * out[1] + 0.1 * out[2]
    return [max(0, min(255, int((lum + (x - lum) * 1.25) * 255 + 0.5))) for x in out]


def write_png(path, pix, scale=8):
    h, w = len(pix), len(pix[0])
    raw = bytearray()
    for y in range(h * scale):
        raw.append(0)
        for x in range(w * scale):
            raw.extend(pix[y // scale][x // scale])
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w * scale, h * scale, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def frame(pix, phase):
    stars = {}
    for cx, cy, b, ph, k, col in STARS:
        tw = b * (0.5 + 0.5 * math.cos(TAU * (k * phase + ph))) ** 1.5    # pisca k vezes por loop
        g = star_glyph(tw)
        if g:
            stars[(cx, cy)] = (g, tw, col)
    lines = []
    for row in range(ROWS):
        top, bot = pix[row * 2], pix[row * 2 + 1]
        s = ["  "]
        for x in range(W):
            t, b = top[x], bot[x]
            st = stars.get((x, row))
            if st:
                g, tw, col = st
                bg = [(t[i] + b[i]) // 2 for i in range(3)]
                fg = [min(255, int(bg[i] + (255 * col[i] - bg[i]) * min(1.0, 0.55 + tw * 0.6))) for i in range(3)]
                s.append(f"\x1b[38;2;{fg[0]};{fg[1]};{fg[2]}m\x1b[48;2;{bg[0]};{bg[1]};{bg[2]}m{g}")
            else:
                s.append(f"\x1b[38;2;{t[0]};{t[1]};{t[2]}m\x1b[48;2;{b[0]};{b[1]};{b[2]}m▀")
        s.append("\x1b[0m")
        lines.append("".join(s))
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    # render.py W ROWS --frames N pasta  -> gera N quadros em loop (gas calculado uma vez)
    img = render()
    pix = [[tonemap(img[y][x]) for x in range(W)] for y in range(H)]
    if "--frames" in sys.argv:
        i = sys.argv.index("--frames")
        n, out = int(sys.argv[i + 1]), sys.argv[i + 2]
        import glob, os
        for f in glob.glob(os.path.join(out, "*.ansi")):
            os.remove(f)
        for k in range(n):
            with open(os.path.join(out, f"{k + 1:02d}.ansi"), "w", encoding="utf-8") as f:
                f.write(frame(pix, k / n))
        sys.exit()
    if PNG:
        write_png(PNG, pix)
        sys.exit()
    sys.stdout.write(frame(pix, PHASE))
