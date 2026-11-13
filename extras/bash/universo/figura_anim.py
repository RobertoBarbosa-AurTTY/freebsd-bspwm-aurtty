#!/usr/bin/env python3
"""
Anima a figura da saudacao como um GIF, fixa no topo do terminal.

Uso: figura_anim.py <pid_do_shell> <tty> <pasta_frames> <linha_inicial>
- Define a area de rolagem (DECSTBM) abaixo da figura: o resto do terminal rola,
  a figura fica parada no topo.
- Escreve so as celulas que mudaram (as estrelas), entre \\e7/\\e8 (salva/restaura
  cursor e cores), num unico write(): nao se mistura com o que o shell escreve.
- Pisca so ate o 1o comando: o gancho PREEXEC do ble.sh (_figura_stop) mata este
  processo antes do comando escrever; se nao houver gancho, sai ao ver um comando.
- Termina sozinho quando o shell fecha.
"""
import glob
import os
import re
import signal
import sys
import time

shell_pid = int(sys.argv[1])
tty = sys.argv[2]
frames_dir = sys.argv[3]
top = int(sys.argv[4])          # linha (1-based) onde comeca a figura

FPS_DELAY = 0.08   # ~12 quadros/s
files = sorted(glob.glob(os.path.join(frames_dir, "*.ansi")))
frames = [open(f, encoding="utf-8").read().rstrip("\n").split("\n") for f in files]
if not frames:
    sys.exit()
nlines = len(frames[0])
reserved = top + nlines          # linhas fixas: 1..top+nlines-1 (+1 linha em branco)

fd = os.open(tty, os.O_WRONLY | os.O_NOCTTY)

# cada linha vira uma lista de celulas (codigos de cor + caractere)
CELL = re.compile(r"((?:\x1b\[[0-9;]*m)*)([^\x1b])")
# codigos de cor no fim da linha (o reset \e[0m) nao tem caractere depois: sem tirar, o
# findall pularia o ESC e desenharia "[0m" como texto na borda direita da figura
FIM = re.compile(r"(?:\x1b\[[0-9;]*m)+$")
grids = [[CELL.findall(FIM.sub("", l)) for l in f] for f in frames]


def full(g):
    """Desenha a figura inteira (primeiro quadro e ao redesenhar)."""
    return "".join(f"\x1b[{top + r};1H" + "".join(a + c for a, c in row) + "\x1b[0m"  # sem \e[K: preserva a tabela de logs à direita
                   for r, row in enumerate(g))


def diff(a, b):
    """So as celulas que mudaram de a para b (as estrelas que piscaram)."""
    out = []
    for r, (ra, rb) in enumerate(zip(a, b)):
        for c, (ca, cb) in enumerate(zip(ra, rb)):
            if ca != cb:
                out.append(f"\x1b[{top + r};{c + 1}H\x1b[0m{cb[0]}{cb[1]}")
    return "".join(out) + ("\x1b[0m" if out else "")


n = len(grids)
fulls = [full(g) for g in grids]
diffs = [diff(grids[i], grids[(i + 1) % n]) for i in range(n)]   # diffs[i]: quadro i -> i+1
running = True


def release(*_):
    global running
    running = False


# SIGTERM: morre na hora (acao padrao); quem devolve a rolagem e o shell (_figura_stop)
signal.signal(signal.SIGUSR1, release)
signal.signal(signal.SIGHUP, release)


def shell_at_prompt():
    """True se o grupo em primeiro plano do terminal e o proprio shell (nada rodando).
    Sem /proc: funciona no Linux e no FreeBSD."""
    try:
        os.kill(shell_pid, 0)
        return os.tcgetpgrp(fd) == os.getpgid(shell_pid)
    except OSError:
        return None   # shell morreu


def write(s):
    try:
        os.write(fd, s.encode())
        return True
    except OSError:
        return False


i = 0
drawn = False        # figura inteira ja desenhada (e area de rolagem valida)?
last_size = None
while running:
    state = shell_at_prompt()
    if state is None:
        break
    try:
        cols, rows = os.get_terminal_size(fd)
    except OSError:
        break
    fits = cols >= 60 and rows >= reserved + 8
    if (cols, rows) != last_size:
        drawn = False            # redimensionou: redesenha tudo e refaz a area de rolagem
        last_size = (cols, rows)
    if not state:
        break                    # rodou um comando: congela (o gancho do shell normalmente ja matou antes)
    elif fits:
        if not drawn:
            ok = write(f"\x1b7\x1b[{reserved + 1};{rows}r\x1b8\x1b7{fulls[i]}\x1b8")
            drawn = True
        elif diffs[i]:
            ok = write(f"\x1b7{diffs[i]}\x1b8")
        else:
            ok = True
        if not ok:
            break
        i = (i + 1) % n
    elif drawn:
        write("\x1b7\x1b[r\x1b8")      # janela pequena: devolve a tela inteira
        drawn = False
    time.sleep(FPS_DELAY)

# saida: devolve a rolagem para a tela inteira (so se o shell ainda existe)
if shell_at_prompt():
    write("\x1b7\x1b[r\x1b8")
