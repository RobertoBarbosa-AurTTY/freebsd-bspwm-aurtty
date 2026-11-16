"""Gera extras/fonts/AurTTYIcons.otf: glifo próprio em U+E000 com um buraco negro
(anel do horizonte de eventos e disco de acreção inclinado passando na frente).
A parte de trás do disco some atrás do anel e a da frente abre um vão no anel,
para continuar legível no tamanho da barra (~20 px).
O glifo do ArchBSD (homenagem no wallpaper aurtty-pacbsd) é copiado, pelo nome
"archbsd", da fonte atual para U+E001.
Requer: pip install fonttools skia-pathops pillow
Uso: python tools/gerar-icone-aurtty.py extras/fonts/AurTTYIcons.otf saida.otf preview.png"""
import math
import sys

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

atual, saida, preview = sys.argv[1:4]
CODEPOINT = 0xE000
CODEPOINT_ARCHBSD = 0xE001

# glifo ArchBSD da fonte atual (antes em U+E000, depois em U+E001; sempre com o nome "archbsd")
_antiga = TTFont(atual)
_gs = _antiga.getGlyphSet()
_larg_arch, _lsb_arch = _antiga["hmtx"]["archbsd"]
_pen_arch = T2CharStringPen(_larg_arch, None)
_gs["archbsd"].draw(_pen_arch)
glifo_archbsd = _pen_arch.getCharString()
UPM, ASC, DESC = 512, 448, -64
CX = 256


def poligono(pts):
    p = pathops.Path()
    pen = p.getPen()
    pen.moveTo(pts[0])
    for pt in pts[1:]:
        pen.lineTo(pt)
    pen.closePath()
    return p


def tracar(p, largura, cap=pathops.LineCap.BUTT_CAP, join=pathops.LineJoin.MITER_JOIN):
    p.stroke(largura, cap, join, 10)
    p.convertConicsToQuads()  # o stroke do skia gera CONIC, que a fonte não aceita
    p.simplify()
    return p


def uniao(*partes):
    r = partes[0]
    for p in partes[1:]:
        r = pathops.op(r, p, pathops.PathOp.UNION)
    return r


def elipse(cx, cy, rx, ry, ang, n=120):
    """elipse rotacionada (graus), como polígono"""
    c, s_ = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * c - y * s_, cy + x * s_ + y * c))
    return poligono(pts)


def anel(cx, cy, r_ext, r_int, desloc=0):
    """anel mais grosso em cima (o disco de trás curvado pela gravidade)"""
    return pathops.op(elipse(cx, cy + desloc, r_ext, r_ext, 0), elipse(cx, cy - desloc, r_int, r_int, 0),
                      pathops.PathOp.DIFFERENCE)


CY = 192                     # centro vertical (meio entre -64 e 448)
R_EXT, R_INT = 140, 84       # anel do horizonte de eventos (o miolo fica vazado)
ANG = 11                     # inclinação do disco
VAO = 16

horizonte = anel(CX, CY, R_EXT, R_INT, 14)
# afina nas pontas (raios x quase iguais) e engrossa no meio (raios y diferentes)
disco = pathops.op(elipse(CX, CY, 252, 78, ANG), elipse(CX, CY, 222, 24, ANG), pathops.PathOp.DIFFERENCE)

# metade da frente do disco = abaixo do eixo maior
c, s_ = math.cos(math.radians(ANG)), math.sin(math.radians(ANG))
def rot(x, y):
    return (CX + x * c - y * s_, CY + x * s_ + y * c)
abaixo = poligono([rot(-400, 0), rot(400, 0), rot(400, -400), rot(-400, -400)])
frente = pathops.op(disco, abaixo, pathops.PathOp.INTERSECTION)
tras = pathops.op(disco, frente, pathops.PathOp.DIFFERENCE)

# a parte de trás some atrás da esfera; a da frente abre um vão no anel
tras = pathops.op(tras, elipse(CX, CY + 14, R_EXT + VAO, R_EXT + VAO, 0), pathops.PathOp.DIFFERENCE)
folga = uniao(tracar(pathops.Path(frente), VAO * 2, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN), frente)
horizonte = pathops.op(horizonte, folga, pathops.PathOp.DIFFERENCE)
forma = uniao(horizonte, frente, tras)

bp = BoundsPen(None)
forma.draw(bp)
xmin, ymin, xmax, ymax = bp.bounds
MARGEM = 16
dx = MARGEM - xmin
largura = int(round(xmax - xmin + 2 * MARGEM))


class Desloca:
    def __init__(self, outro):
        self.o = outro

    def moveTo(self, p): self.o.moveTo((p[0] + dx, p[1]))
    def lineTo(self, p): self.o.lineTo((p[0] + dx, p[1]))
    def curveTo(self, *ps): self.o.curveTo(*[(x + dx, y) for x, y in ps])
    def qCurveTo(self, *ps): self.o.qCurveTo(*[(x + dx, y) for x, y in ps])
    def closePath(self): self.o.closePath()
    def endPath(self): self.o.endPath()


cs_pen = T2CharStringPen(largura, None)
forma.draw(Desloca(cs_pen))
glifo = cs_pen.getCharString()

vazio = T2CharStringPen(UPM // 2, None).getCharString()
fb = FontBuilder(UPM, isTTF=False)
fb.setupGlyphOrder([".notdef", "aurtty", "archbsd"])
fb.setupCharacterMap({CODEPOINT: "aurtty", CODEPOINT_ARCHBSD: "archbsd"})
fb.setupCFF("AurTTYIcons-Regular", {"FullName": "AurTTY Icons"},
            {".notdef": vazio, "aurtty": glifo, "archbsd": glifo_archbsd}, {})
fb.setupHorizontalMetrics({".notdef": (UPM // 2, 0), "aurtty": (largura, MARGEM),
                           "archbsd": (_larg_arch, _lsb_arch)})
fb.setupHorizontalHeader(ascent=ASC, descent=DESC)
fb.setupNameTable({"familyName": "AurTTY Icons", "styleName": "Regular",
                   "copyright": "U+E000: glifo próprio (buraco negro), GPL-3.0; "
                                "U+E001: inspirado no logo do ArchBSD, base Material Design Icons (Apache-2.0)"})
fb.setupOS2(sTypoAscender=ASC, sTypoDescender=DESC, usWinAscent=ASC, usWinDescent=-DESC)
fb.setupPost()
fb.save(saida)

# --- prévia: grande, médio e nos tamanhos da barra ---
img = Image.new("RGB", (900, 420), "#1a1b26")
d = ImageDraw.Draw(img)
for tam, x, y in ((300, 30, 20), (64, 620, 60), (22, 620, 200), (17, 700, 205)):
    d.text((x, y), chr(CODEPOINT), font=ImageFont.truetype(saida, tam), fill="#e8303a")
d.text((620, 300), "AurTTY Icons U+E000", fill="#c0caf5")
d.text((770, 50), chr(CODEPOINT_ARCHBSD), font=ImageFont.truetype(saida, 64), fill="#e8303a")
d.text((770, 140), "U+E001", fill="#c0caf5")
img.save(preview)
print("ok", largura, bp.bounds)
