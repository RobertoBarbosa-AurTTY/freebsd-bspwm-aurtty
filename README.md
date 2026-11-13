# freebsd-bspwm-aurtty

Pós-instalação do **FreeBSD** que monta um ambiente **bspwm** com a aparência do tema
**Emilia** (Tokyo Night) dos [dotfiles do gh0stzk](https://github.com/gh0stzk/dotfiles).

Você instala um FreeBSD limpo, clona este repositório, roda um script, responde
4 perguntas e entra direto no bspwm.

## Instalação

Num FreeBSD 14 ou 15 recém-instalado, como `root`:

```sh
pkg install -y git
git clone https://github.com/RobertoBarbosa-AurTTY/freebsd-bspwm-aurtty
cd freebsd-bspwm-aurtty
sh install.sh
```

O script pergunta:

| Pergunta | Padrão |
|---|---|
| Usuário (existente ou novo) | — |
| Layout do teclado | `br` (ABNT2) |
| Driver de vídeo: VM com BIOS (vesa), UEFI sem driver (scfb), Intel/AMD (drm-kmod), NVIDIA | detecta VM, BIOS ou UEFI |
| Como entrar: tela de login gráfica (LightDM), login no `ttyv0` abrindo o bspwm, ou manual (`startx`) | LightDM |
| Terminal estilo AurTTY: bash + oh-my-bash (powerline) + ble.sh como shell padrão | sim |

O log fica em `/var/log/freebsd-bspwm-aurtty.log`. As configs que já existiam em
`~/.config` são movidas para `~/.config-backup-<data>`.

## O que é instalado

- **Janela/barra:** bspwm, sxhkd, polybar (`bar07`), picom, rofi, dunst, jgmenu, alacritty
- **Aparência:** tema GTK `TokyoNight-zk`, ícones `TokyoNight-SE`, cursor `Qogirr-Dark`,
  JetBrainsMono Nerd Font, FontAwesome, Material Design Icons, wallpapers do Emilia
- **Sistema:** Xorg, dbus, pulseaudio, driver de vídeo escolhido
- **Tela de login (opcional, padrão):** LightDM com tema próprio `AurTTY-Login` (`extras/lightdm/gtk.css`,
  sobre o TokyoNight-zk): cartão translúcido arredondado, campos e botão no azul do Emilia,
  avatar redondo com o diabinho do ArchBSD (`extras/lightdm/avatar.png`), wallpaper FreeBSD dark
  e a sessão `bspwm (AurTTY)`. Config em
  `/usr/local/etc/lightdm/lightdm-gtk-greeter.conf`.
- **Terminal (opcional):** bash, oh-my-bash com tema powerline, ble.sh (realce e sugestões),
  eza (`ls`/`ll`/`lt` com ícones), zoxide e fzf (`Ctrl+R` histórico, `Ctrl+T` arquivos).
  **fzf-tab**: o `TAB` abre o fzf com pré-visualização (pastas com eza, arquivos com bat),
  no mesmo estilo do fzf-tab do zsh do gh0stzk ([fzf-tab-completion](https://github.com/lincheney/fzf-tab-completion)).
  O `.bashrc` fica em `extras/bash/bashrc`; `rr` reinicia o terminal limpo.
- Temas e fontes externos são baixados com **sha256 fixado** (veja o topo do `install.sh`)

## Atalhos principais

| Atalho | Ação |
|---|---|
| `super + Return` | terminal |
| `super + space` | lançador (rofi) |
| `alt + F1` | lista de atalhos |
| `super + 1..9` | áreas de trabalho |
| `super + x` | fechar janela |
| `super + Escape` | recarregar atalhos (sxhkd) |

## Diferenças em relação ao original (Arch)

- Só o tema **Emilia** e a barra **bar07**. O seletor de temas existe, mas tem uma opção só.
- Sem **eww**, que não tem pacote no FreeBSD: os widgets de perfil e do player não abrem.
- Módulos da barra removidos: bateria e bluetooth (leem `/sys` do Linux), atualizações (pacman).
- Wallpapers próprios (`extras/walls/`, gerados por `tools/gerar-wallpapers.py`):
  **FreeBSD dark** (padrão) e uma **homenagem ao ArchBSD/PacBSD**. Os do Emilia continuam
  disponíveis no seletor (`super + alt + w`).
- Paleta opcional de **fogo** para a barra (`extras/polybar/fogo.ini`), desligada por padrão.
  Para ativar, troque `include-file = ../colors.ini` por `include-file = fogo.ini` em
  `~/.config/bspwm/bars/bar07/config.ini`.
- Área de trabalho ativa: logo do **FreeBSD** (glifo `nf-linux-freebsd` da Nerd Font) no lugar do pacman.
- Ícone do launcher: logo inspirado no **ArchBSD** (o Arch vermelho com chifres e rabo de diabinho),
  numa fonte própria (`extras/fonts/AurTTYIcons.otf`, gerada por `tools/gerar-icone-archbsd.py`).
  A cor fica em `arch_icon` no `theme-config.bash` do Emilia.
- `freebsd-bin/`: pequenos *shims* para os scripts do gh0stzk, que esperam ferramentas GNU/Linux
  (`sed`→`gsed`, `stat`/`date`/`shuf` do coreutils, `pidof` e `ip route` emulados).
  Eles ficam no início do `PATH` da sessão bspwm.

## Manutenção

`dotfiles/` é gerado, não editado à mão:

```sh
tools/sincronizar-upstream.sh            # commit fixado em UPSTREAM
tools/sincronizar-upstream.sh <commit>   # atualizar para outro commit do gh0stzk
```

O script baixa o upstream, mantém só o Emilia e aplica as adaptações para FreeBSD.

## Créditos e licença

Configurações, scripts, wallpapers e temas: **[gh0stzk](https://github.com/gh0stzk/dotfiles)**.
Ícone do launcher: releitura do logo do ArchBSD/PacBSD sobre o glifo `arch` do
Material Design Icons (Apache-2.0).
Este projeto é um derivado e segue a mesma licença, **GPL-3.0** (veja `LICENSE`).
