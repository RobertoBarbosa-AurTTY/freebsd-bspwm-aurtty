"""Gera os wallpapers do freebsd-bspwm-aurtty em extras/walls/ (2560x1440, webp).

  aurtty-freebsd-dark.webp   logo do FreeBSD (glifo nf-linux-freebsd) em brasa
  aurtty-pacbsd.webp         homenagem ao ArchBSD/PacBSD (glifo AurTTY Icons U+E000)

Requer: pip install pillow
Uso: python tools/gerar-wallpapers.py <JetBrainsMonoNerdFontPropo-Regular.ttf> \
        <JetBrainsMonoNerdFont-Bold.ttf> extras/fonts/AurTTYIcons.otf extras/walls
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

NF_PROPO, NF_BOLD, AURTTY, SAIDA = sys.argv[1:5]
W, H = 2560, 1440

CARVAO = (7, 4, 4)
BRASA = (38, 14, 10)
CINZA = (246, 227, 207)
VERMELHO = (255, 42, 26)
LARANJA = (255, 122, 26)
AMARELO = (255, 201, 74)


def fundo(cx, cy):
    """Gradiente radial: brasa escura no centro, carvão nas bordas."""
    img = Image.new("RGB", (W, H), CARVAO)
    px = img.load()
    rmax = math.hypot(W, H) * 0.55
    for y in range(H):
        for x in range(0, W):
            t = min(1.0, math.hypot(x - cx, (y - cy) * 1.25) / rmax)
            t = t ** 1.6
            px[x, y] = tuple(int(BRASA[i] * (1 - t) + CARVAO[i] * t) for i in range(3))
    return img


def brilho(img, desenhar, raio, intensidade=1.0):
    """Desenha numa camada, borra e soma (glow)."""
    camada = Image.new("RGB", img.size, (0, 0, 0))
    desenhar(ImageDraw.Draw(camada))
    glow = camada.filter(ImageFilter.GaussianBlur(raio))
    if intensidade != 1.0:
        glow = glow.point(lambda v: min(255, int(v * intensidade)))
    return ImageChops.add(img, glow)


def fagulhas(img, semente, n=260, regiao=None):
    rnd = random.Random(semente)
    x0, y0, x1, y1 = regiao or (0, 0, W, H)
    camada = Image.new("RGB", img.size, (0, 0, 0))
    d = ImageDraw.Draw(camada)
    for _ in range(n):
        x = rnd.uniform(x0, x1)
        y = rnd.uniform(y0, y1)
        r = rnd.choice([1.2, 1.6, 2.2, 3.0, 4.0])
        cor = rnd.choice([VERMELHO, LARANJA, LARANJA, AMARELO])
        k = rnd.uniform(0.35, 1.0) * (1 - (y - y0) / max(1, (y1 - y0)) * 0.3)
        cor = tuple(int(c * k) for c in cor)
        d.ellipse((x - r, y - r, x + r, y + r), fill=cor)
    img = ImageChops.add(img, camada.filter(ImageFilter.GaussianBlur(2.5)))
    return ImageChops.add(img, camada.filter(ImageFilter.GaussianBlur(0.6)))


def texto_centro(d, cx, y, txt, fonte, cor, espaco=0):
    if espaco:
        larg = sum(d.textlength(c, font=fonte) for c in txt) + espaco * (len(txt) - 1)
        x = cx - larg / 2
        for c in txt:
            d.text((x, y), c, font=fonte, fill=cor)
            x += d.textlength(c, font=fonte) + espaco
    else:
        d.text((cx, y), txt, font=fonte, fill=cor, anchor="ma")


def glifo_centro(d, cx, cy, ch, fonte, cor):
    d.text((cx, cy), ch, font=fonte, fill=cor, anchor="mm")


def salvar(img, nome):
    os.makedirs(SAIDA, exist_ok=True)
    caminho = os.path.join(SAIDA, nome)
    img.save(caminho, "WEBP", quality=90, method=6)
    print(caminho, os.path.getsize(caminho) // 1024, "KiB")


# ---------- 1) FreeBSD dark ----------
cx, cy = W // 2, int(H * 0.44)
img = fundo(cx, cy)
logo = ImageFont.truetype(NF_PROPO, 560)
FREEBSD = ""
img = brilho(img, lambda d: glifo_centro(d, cx, cy, FREEBSD, logo, (150, 18, 8)), 90, 1.3)
img = brilho(img, lambda d: glifo_centro(d, cx, cy, FREEBSD, logo, (255, 70, 20)), 28, 0.7)
img = fagulhas(img, 7, 320, (0, int(H * 0.25), W, H))
d = ImageDraw.Draw(img)
glifo_centro(d, cx, cy, FREEBSD, logo, VERMELHO)
titulo = ImageFont.truetype(NF_BOLD, 64)
sub = ImageFont.truetype(NF_PROPO, 26)
texto_centro(d, cx, int(H * 0.72), "freebsd", titulo, CINZA, espaco=22)
texto_centro(d, cx, int(H * 0.72) + 96, "bspwm  ·  aurtty", sub, (150, 110, 95), espaco=6)
salvar(img, "aurtty-freebsd-dark.webp")

# ---------- 2) Homenagem ArchBSD / PacBSD ----------
cx, cy = W // 2, int(H * 0.42)
img = fundo(cx, cy)

# trama discreta de triângulos ao fundo
trama = Image.new("RGB", (W, H), (0, 0, 0))
dt = ImageDraw.Draw(trama)
passo = 120
for j, y in enumerate(range(-passo, H + passo, passo)):
    for x in range(-passo, W + passo, passo):
        ox = x + (passo // 2 if j % 2 else 0)
        dt.polygon([(ox, y + passo * 0.8), (ox + passo / 2, y), (ox + passo, y + passo * 0.8)],
                   outline=(26, 10, 8))
img = ImageChops.add(img, trama)

logo = ImageFont.truetype(AURTTY, 620)
ARCHBSD = ""
img = brilho(img, lambda d: glifo_centro(d, cx, cy, ARCHBSD, logo, (150, 18, 8)), 90, 1.3)
img = brilho(img, lambda d: glifo_centro(d, cx, cy, ARCHBSD, logo, (255, 70, 20)), 26, 0.7)
img = fagulhas(img, 13, 260, (0, int(H * 0.3), W, H))
d = ImageDraw.Draw(img)
glifo_centro(d, cx, cy, ARCHBSD, logo, VERMELHO)
titulo = ImageFont.truetype(NF_BOLD, 76)
sub = ImageFont.truetype(NF_PROPO, 28)
mono = ImageFont.truetype(NF_PROPO, 22)
texto_centro(d, cx, int(H * 0.72), "PacBSD", titulo, CINZA, espaco=18)
texto_centro(d, cx, int(H * 0.72) + 108, "em memória do ArchBSD", sub, (190, 140, 120), espaco=4)
texto_centro(d, cx, int(H * 0.72) + 160, "pacman  +  kernel FreeBSD", mono, (120, 80, 68), espaco=3)
salvar(img, "aurtty-pacbsd.webp")
