"""Gera extras/fonts/AurTTYIcons.otf: um glifo inspirado no logo do ArchBSD
(triângulo do Arch do Material Design Icons + chifres + rabo de diabinho) em U+E000.
Requer: pip install fonttools skia-pathops pillow
Uso: python tools/gerar-icone-archbsd.py dotfiles/fonts/MaterialDesignIconsDesktop.ttf extras/fonts/AurTTYIcons.otf preview.png"""
import sys
import pathops
from fontTools.ttLib import TTFont
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.boundsPen import BoundsPen
from PIL import Image, ImageDraw, ImageFont

mdi, saida, preview = sys.argv[1:4]
CODEPOINT = 0xE000

# --- base: triângulo do Arch ---
src = TTFont(mdi)
gs = src.getGlyphSet()
base = pathops.Path()
gs[src.getBestCmap()[0xF08C7]].draw(base.getPen())


def contorno(pts_cmds):
    p = pathops.Path()
    pen = p.getPen()
    for cmd, *args in pts_cmds:
        getattr(pen, cmd)(*args)
    return p


def espelhar(cmds, eixo=256):
    out = []
    for cmd, *args in cmds:
        out.append((cmd, *[(2 * eixo - x, y) for x, y in args]))
    return out


# --- chifres (saem das laterais, perto do topo, curvando para fora e para cima) ---
chifre_esq = [
    ("moveTo", (214, 262)),
    ("curveTo", (156, 286), (118, 350), (124, 444)),   # borda externa até a ponta
    ("curveTo", (146, 382), (182, 334), (234, 318)),   # borda interna de volta
    ("closePath",),
]
chifres = contorno(chifre_esq)
chifres = pathops.op(chifres, contorno(espelhar(chifre_esq)), pathops.PathOp.UNION)

# --- rabo: sai do pé direito, curva para a direita e sobe, ponta de seta ---
rabo_linha = pathops.Path()
pen = rabo_linha.getPen()
pen.moveTo((430, 40))
pen.curveTo((500, -40), (600, -30), (592, 90))
pen.endPath()
rabo_linha.stroke(26, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
rabo_linha.convertConicsToQuads()

ponta = contorno([
    ("moveTo", (556, 92)),
    ("lineTo", (630, 92)),
    ("lineTo", (593, 168)),
    ("closePath",),
])

# --- união de tudo ---
forma = base
for parte in (chifres, rabo_linha, ponta):
    forma = pathops.op(forma, parte, pathops.PathOp.UNION)

bp = BoundsPen(None)
forma.draw(bp)
xmin, ymin, xmax, ymax = bp.bounds
MARGEM = 16
dx = MARGEM - xmin
largura = int(round(xmax - xmin + 2 * MARGEM))

# --- monta a fonte (CFF, curvas cúbicas) ---
UPM, ASC, DESC = 512, 448, -64
cs_pen = T2CharStringPen(largura, None)


class Desloca:
    def __init__(self, outro):
        self.o = outro

    def moveTo(self, p): self.o.moveTo((p[0] + dx, p[1]))
    def lineTo(self, p): self.o.lineTo((p[0] + dx, p[1]))
    def curveTo(self, *ps): self.o.curveTo(*[(x + dx, y) for x, y in ps])
    def qCurveTo(self, *ps): self.o.qCurveTo(*[(x + dx, y) for x, y in ps])
    def closePath(self): self.o.closePath()
    def endPath(self): self.o.endPath()


forma.draw(Desloca(cs_pen))
glifo = cs_pen.getCharString()

vazio = T2CharStringPen(UPM // 2, None).getCharString()
fb = FontBuilder(UPM, isTTF=False)
fb.setupGlyphOrder([".notdef", "archbsd"])
fb.setupCharacterMap({CODEPOINT: "archbsd"})
fb.setupCFF("AurTTYIcons-Regular", {"FullName": "AurTTY Icons"},
            {".notdef": vazio, "archbsd": glifo}, {})
fb.setupHorizontalMetrics({".notdef": (UPM // 2, 0), "archbsd": (largura, MARGEM)})
fb.setupHorizontalHeader(ascent=ASC, descent=DESC)
fb.setupNameTable({"familyName": "AurTTY Icons", "styleName": "Regular",
                   "copyright": "Glifo inspirado no logo do ArchBSD; base: Material Design Icons (Apache-2.0)"})
fb.setupOS2(sTypoAscender=ASC, sTypoDescender=DESC, usWinAscent=ASC, usWinDescent=-DESC)
fb.setupPost()
fb.save(saida)

# --- preview ---
img = Image.new("RGB", (900, 420), "#1a1b26")
d = ImageDraw.Draw(img)
for tam, x, y in ((300, 30, 20), (64, 620, 60), (22, 620, 200), (17, 700, 205)):
    d.text((x, y), chr(CODEPOINT), font=ImageFont.truetype(saida, tam), fill="#e8303a")
d.text((620, 300), "AurTTY Icons U+E000", fill="#c0caf5")
img.save(preview)
print("ok", largura, bp.bounds)
