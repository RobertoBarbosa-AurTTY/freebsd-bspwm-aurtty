#!/usr/bin/env python3
"""
Galaxia de Andromeda (M31) para o terminal, procedural.

Disco espiral visto quase de lado (inclinado ~77 graus e girado na tela), nucleo
dourado brilhante, aneis de poeira escura no lado mais proximo, bracos azulados com
regioes de formacao estelar rosadas, e as satelites M32 (compacta) e M110 (alongada).
Estrelas de primeiro plano como caracteres (· + ✦) que piscam.

Saida: ANSI truecolor com "▀" (2 pixels por celula), mesmo formato dos pilares.
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
# coordenadas: u em [0, 1.75] (proporcao da tela), v em [0, 1] de cima para baixo
CX, CY = 0.875, 0.50
ANG = math.radians(30)           # eixo maior inclinado (sobe para a direita)
COS, SIN = math.cos(ANG), math.sin(ANG)
INCL = 0.27                      # razao eixo menor / maior (disco quase de lado)

SKY = [0.0, 0.0, 0.004]
CORE = [1.00, 0.86, 0.60]
BULGE = [0.95, 0.72, 0.45]
DISK_IN = [0.80, 0.74, 0.70]
DISK_OUT = [0.45, 0.60, 0.95]
HII = [1.00, 0.45, 0.65]
DUST = [0.10, 0.05, 0.03]


def disk_coords(u, v, cx=CX, cy=CY, cs=COS, sn=SIN, incl=INCL):
    dx, dy = u - cx, v - cy
    x = dx * cs - dy * sn          # ao longo do eixo maior
    y = dx * sn + dy * cs          # ao longo do eixo menor (projetado)
    return x, y, math.hypot(x, y / incl)


def galaxy(u, v):
    """Cor e brilho da galaxia (sem estrelas de primeiro plano)."""
    x, y, r = disk_coords(u, v)
    th = math.atan2(y / INCL, x)
    n = fbm(u * 7, v * 7, 11, 4)
    # nucleo + bojo + disco exponencial
    core = math.exp(-(r / 0.018) ** 1.2) * 2.2
    bulge = math.exp(-(r / 0.09)) * 1.1
    disk = math.exp(-r / 0.26) * 0.75 * (0.75 + 0.5 * n)
    disk *= smooth(0.95, 0.70, r)                       # borda do disco se apaga
    # bracos espirais (logaritmicos) vistos de lado: aneis um pouco deformados
    arm = 0.5 + 0.5 * math.cos(2 * th - 9.0 * math.log(max(r, 0.02)) + n * 2.5)
    arm = arm ** 3 * smooth(0.12, 0.30, r) * smooth(0.95, 0.55, r)
    c = mix(DISK_IN, DISK_OUT, smooth(0.15, 0.55, r))
    light = [c[i] * (disk + arm * 0.45) for i in range(3)]
    # regioes de formacao estelar rosadas nos bracos
    knots = smooth(0.72, 0.86, fbm(u * 22, v * 22, 77, 3)) * arm
    light = [light[i] + HII[i] * knots * 0.55 for i in range(3)]
    light = [light[i] + BULGE[i] * bulge + CORE[i] * core for i in range(3)]
    # poeira: aneis escuros, mais fortes no lado proximo (y > 0) e fora do bojo
    lane = 0.0
    for rr, w in ((0.20, 0.035), (0.33, 0.04), (0.47, 0.05)):
        lane = max(lane, math.exp(-((r - rr + (n - 0.5) * 0.06) / w) ** 2))
    near = 0.35 + 0.65 * smooth(-0.01, 0.03, y)
    dust = lane * near * smooth(0.10, 0.20, r) * smooth(0.95, 0.6, r)
    light = mix(light, [DUST[i] * (disk + 0.1) for i in range(3)], dust * 0.85)
    # satelites: M32 (compacta, perto do nucleo) e M110 (eliptica difusa, mais longe)
    m32 = math.exp(-(((u - 0.74) ** 2 + (v - 0.80) ** 2) / 0.0010)) * 0.9
    _, _, r110 = disk_coords(u, v, 0.50, 0.15, math.cos(-0.6), math.sin(-0.6), 0.55)
    m110 = math.exp(-(r110 / 0.045) ** 1.3) * 0.45
    light = [light[i] + BULGE[i] * (m32 + m110) for i in range(3)]
    return light, core + bulge + disk + m32 + m110


def sample(u, v):
    g, _ = galaxy(u, v)
    return [SKY[i] + g[i] for i in range(3)]


def pillar_field(u, v):
    """Usado pelo posicionamento das estrelas: evita o miolo brilhante da galaxia."""
    return (1.0 if galaxy(u, v)[1] > 0.30 else 0.0,)


# estrelas: desenhadas como caracteres (· + ✦) por cima da celula, nao como pixel quadrado
rng = random.Random(618)
STARS = []          # (coluna, linha, brilho, fase, ciclos por loop, cor)
_used = set()
while len(STARS) < int(W * ROWS / 22):
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
