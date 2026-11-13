"""
Base comum das figuras procedurais novas (caranguejo, etacarinae, vycma).

Cada render.py descreve a cena com funções de (u, v), onde u vai de 0 a 1,75
(proporção da tela) e v de 0 a 1 (de cima para baixo), e chama run():

  fundo(u, v)            -> [r, g, b]          parte parada (calculada uma vez)
  dinamico(u, v, fase)   -> ([r, g, b], alfa)  parte que muda a cada quadro (opcional)
                            resultado = fundo * (1 - alfa) + rgb
  evitar(u, v)           -> True onde não pode haver estrela de primeiro plano

Saída: ANSI truecolor com "▀" (2 pixels por célula), igual às outras figuras.
Uso: render.py [largura] [linhas] [fase 0..1] > quadro.ansi
     render.py 56 16 --frames 48 frames/          (gera o loop inteiro)
     render.py 56 16 0 --png arquivo.png          (prévia ampliada)
"""
import glob
import math
import os
import random
import struct
import sys
import zlib

TAU = 2 * math.pi


# ---------- ruído (value noise + fbm), determinístico ----------
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


def ridged(x, y, s=0, oct=4):
    """Ruído de cristas: linhas finas e ramificadas (filamentos)."""
    return 1.0 - abs(2.0 * fbm(x, y, s, oct) - 1.0)


def mix(a, b, t):
    return [a[i] + (b[i] - a[i]) * t for i in range(3)]


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def rot(dx, dy, ang):
    c, s = math.cos(ang), math.sin(ang)
    return dx * c - dy * s, dx * s + dy * c


# ---------- planetas ----------
def esfera(dx, dy, r):
    """Normal (nx, ny, nz) do ponto da esfera de raio r visto de frente, ou None fora dela."""
    x, y = dx / r, dy / r
    q = x * x + y * y
    if q >= 1.0:
        return None
    return x, y, math.sqrt(1.0 - q)


def gira(nx, ny, nz, ang, incl=0.0):
    """Gira a normal em torno do eixo do planeta (ang) e inclina o eixo (incl)."""
    if incl:
        ny, nz = ny * math.cos(incl) - nz * math.sin(incl), ny * math.sin(incl) + nz * math.cos(incl)
    c, s = math.cos(ang), math.sin(ang)
    return nx * c + nz * s, ny, -nx * s + nz * c


def ruido3(x, y, z, s=0, oct=4):
    """Ruído 3D aproximado (soma de três planos): sem emenda numa esfera que gira."""
    return (fbm(x, y, s, oct) + fbm(y + 3.1, z, s + 5, oct) + fbm(z + 7.7, x, s + 11, oct)) / 3.0


LUZ = (-0.62, -0.32, 0.72)       # Sol vindo de cima/esquerda/frente


def luz(nx, ny, nz, amb=0.03):
    l = math.sqrt(sum(c * c for c in LUZ))
    return amb + max(0.0, (nx * LUZ[0] + ny * LUZ[1] + nz * LUZ[2]) / l)


def lua(u, v, cx, cy, r, cor, amb=0.04):
    """Lua pequena iluminada: (rgb, alfa) ou None."""
    n = esfera(u - cx, v - cy, r)
    if not n:
        return None
    b = luz(*n, amb=amb)
    return [cor[i] * b for i in range(3)], 1.0


def ceu(u, v, s=0):
    """Fundo estrelado bem escuro com um pouco de poeira."""
    g = fbm(u * 3, v * 3, s, 4)
    return [0.003 + 0.008 * smooth(0.6, 0.9, g), 0.003 + 0.005 * smooth(0.6, 0.9, g), 0.008 + 0.014 * smooth(0.55, 0.9, g)]


# ---------- saída ----------
def tonemap(c):
    out = []
    for x in c:
        x = 1.0 - math.exp(-1.6 * max(0.0, x))
        out.append(x ** (1 / 2.2))
    lum = 0.3 * out[0] + 0.6 * out[1] + 0.1 * out[2]
    return [max(0, min(255, int((lum + (x - lum) * 1.25) * 255 + 0.5))) for x in out]


def star_glyph(b):
    if b < 0.18:
        return None
    if b < 0.45:
        return "·"
    if b < 0.75:
        return "+"
    return "✦"


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


def run(fundo, dinamico=None, evitar=None, semente=1, ss=3, ss_din=2):
    args = [a for a in sys.argv[1:]]
    W = int(args[0]) if args and not args[0].startswith("--") else 56
    ROWS = int(args[1]) if len(args) > 1 and not args[1].startswith("--") else 16
    fase0 = float(args[2]) if len(args) > 2 and not args[2].startswith("--") else 0.0
    H = ROWS * 2

    def uv(x, y, sx, sy, n):
        return (x + (sx + 0.5) / n) / W * 1.75, (y + (sy + 0.5) / n) / H

    # parte parada, com superamostragem
    base = []
    for y in range(H):
        row = []
        for x in range(W):
            acc = [0.0, 0.0, 0.0]
            for sy in range(ss):
                for sx in range(ss):
                    c = fundo(*uv(x, y, sx, sy, ss))
                    for i in range(3):
                        acc[i] += c[i]
            row.append([a / (ss * ss) for a in acc])
        base.append(row)

    # estrelas de primeiro plano (caracteres que piscam)
    rng = random.Random(semente)
    stars, usados, tent = [], set(), 0
    while len(stars) < int(W * ROWS / 22) and tent < 5000:
        tent += 1
        cx, cy = rng.randrange(W), rng.randrange(ROWS)
        if (cx, cy) in usados or (evitar and evitar(cx / W * 1.75, (cy * 2 + 1) / H)):
            continue
        usados.add((cx, cy))
        stars.append((cx, cy, rng.uniform(0.45, 1.0), rng.uniform(0, 1), rng.choice([1, 1, 2]),
                      rng.choice([[1.0, 0.97, 0.92], [0.82, 0.92, 1.0], [1.0, 0.88, 0.65]])))

    def imagem(fase):
        if not dinamico:
            img = base
        else:
            img = []
            for y in range(H):
                row = []
                for x in range(W):
                    acc = [0.0, 0.0, 0.0]
                    for sy in range(ss_din):
                        for sx in range(ss_din):
                            u, v = uv(x, y, sx, sy, ss_din)
                            rgb, a = dinamico(u, v, fase)
                            b = base[y][x]
                            for i in range(3):
                                acc[i] += b[i] * (1 - a) + rgb[i]
                    row.append([c / (ss_din * ss_din) for c in acc])
                img.append(row)
        return [[tonemap(img[y][x]) for x in range(W)] for y in range(H)]

    def quadro(pix, fase):
        st = {}
        for cx, cy, b, ph, k, col in stars:
            tw = b * (0.5 + 0.5 * math.cos(TAU * (k * fase + ph))) ** 1.5
            g = star_glyph(tw)
            if g:
                st[(cx, cy)] = (g, tw, col)
        lines = []
        for r in range(ROWS):
            top, bot = pix[r * 2], pix[r * 2 + 1]
            s = ["  "]
            for x in range(W):
                t, b = top[x], bot[x]
                e = st.get((x, r))
                if e:
                    g, tw, col = e
                    bg = [(t[i] + b[i]) // 2 for i in range(3)]
                    fg = [min(255, int(bg[i] + (255 * col[i] - bg[i]) * min(1.0, 0.55 + tw * 0.6))) for i in range(3)]
                    s.append(f"\x1b[38;2;{fg[0]};{fg[1]};{fg[2]}m\x1b[48;2;{bg[0]};{bg[1]};{bg[2]}m{g}")
                else:
                    s.append(f"\x1b[38;2;{t[0]};{t[1]};{t[2]}m\x1b[48;2;{b[0]};{b[1]};{b[2]}m▀")
            s.append("\x1b[0m")
            lines.append("".join(s))
        return "\n".join(lines) + "\n"

    if "--frames" in args:
        i = args.index("--frames")
        n, out = int(args[i + 1]), args[i + 2]
        os.makedirs(out, exist_ok=True)
        for f in glob.glob(os.path.join(out, "*.ansi")):
            os.remove(f)
        pix = None if dinamico else imagem(0)
        for k in range(n):
            p = pix or imagem(k / n)
            with open(os.path.join(out, f"{k + 1:02d}.ansi"), "w", encoding="utf-8") as f:
                f.write(quadro(p, k / n))
        return
    if "--png" in args:
        write_png(args[args.index("--png") + 1], imagem(fase0))
        return
    sys.stdout.write(quadro(imagem(fase0), fase0))
