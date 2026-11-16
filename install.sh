#!/bin/sh
# freebsd-bspwm-aurtty: pós-instalação do FreeBSD para desenvolvimento, com bspwm.
# Visual baseado no tema Emilia (créditos e licença no README; GPL-3.0).
#
# Uso, como root, num FreeBSD recém-instalado:
#   pkg install -y git && git clone https://github.com/RobertoBarbosa-AurTTY/freebsd-bspwm-aurtty
#   cd freebsd-bspwm-aurtty && sh install.sh
set -eu

RAIZ=$(cd "$(dirname "$0")" && pwd)
DOT="$RAIZ/dotfiles"
LOG=/var/log/freebsd-bspwm-aurtty.log

# Recursos externos fixados (versão + sha256)
GH0STZK_PKGS=https://gh0stzk.github.io/pkgs/x86_64
TEMA_GTK="gh0stzk-gtk-themes-1.0-1-any.pkg.tar.zst 98c8192717126744a5b7c025ae01d0afc3a493460a938adb7123650db38f7574"
TEMA_ICONES="gh0stzk-icons-tokyo-night-1.0-0-any.pkg.tar.zst 3a2b49bee84bce10bd0207d67107d536e8e5d2528d3a768e94bceda104671c5f"
TEMA_CURSOR="gh0stzk-cursor-qogirr-1.0-1-any.pkg.tar.zst e75ccb3ca87a2d4d1e3acff824b58f945b01fb78e506df9af17fd57dc753d062"
NERDFONT_URL=https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.tar.xz
NERDFONT_SHA=ef552a3e638f25125c6ad4c51176a6adcdce295ab1d2ffacf0db060caf8c1582
OMB_URL=https://codeload.github.com/ohmybash/oh-my-bash/tar.gz/abf846186ab0a8a41ec5888e827ece6277dfe446
OMB_SHA=aedeaafe48c9da52a2c8e338842cd7f2f784f81442aca53bb59dad3b2af34c97
BLE_URL=https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel3/ble-0.4.0-devel3.tar.xz
BLE_SHA=c8612ee612bc6b10dbfd6e85c6cbdfd7caf152a12d1f9de22ea0a9d735b3080c
FZFTAB_URL=https://codeload.github.com/lincheney/fzf-tab-completion/tar.gz/7014e0a7cd68fe3530e2f58c45740d17e98f05b8
FZFTAB_SHA=eec482c89e536884c5101d20944905e93d864b2c22404d01381d4e80f9cbf718
# AstroNvim: template oficial com o commit fixado (sha256 do tarball)
ASTRONVIM_URL=https://codeload.github.com/AstroNvim/template/tar.gz/49a7161b776f8bc6c23508819ea1ad4e7b359bee
ASTRONVIM_SHA=8941afa733b63a07ba8626dd9daa91728365c411e73ed6a389d35dfc50c2202b

PACOTES="xorg bspwm sxhkd polybar picom rofi dunst alacritty feh xsettingsd jgmenu clipcat
xdo xdotool jq ImageMagick7 maim xclip pamixer playerctl pavucontrol pulseaudio
i3lock-color webp webp-pixbuf-loader bash gsed coreutils git curl dbus jetbrains-mono noto-basic
papirus-icon-theme eza zoxide fzf bat gawk gnugrep fastfetch python3
firefox thunar thunar-archive-plugin gsimplecal xdg-user-dirs neovim ripgrep fd-find"

# ferramentas de desenvolvimento backend (opcional). Os py3xx-* entram depois,
# com a versão do python padrão do repositório. Sem Docker no FreeBSD.
DEV_PKGS="lazygit tmux gh mise uv go-yq xh python3 node22 npm-node22 deno
sqlite3 postgresql17-client mariadb114-client valkey hs-ShellCheck bastille"
DEV_PY="httpie pgcli pre-commit"

# ---------- interface ----------
# Com terminal e bsddialog (base do FreeBSD 14+), as perguntas e o progresso
# são telas com o tema de extras/installer. Sem terminal, sem bsddialog ou com
# AURTTY_TEXTO=1, as mesmas perguntas aparecem em texto simples.
UI=texto
if [ -z "${AURTTY_TEXTO:-}" ] && [ -t 0 ] && [ -t 1 ] && command -v bsddialog >/dev/null 2>&1; then
  UI=dialog
fi
TEMA_UI="$RAIZ/extras/installer/bsddialog.theme"
FUNDO="freebsd-bspwm-aurtty  |  FreeBSD $(uname -r)  |  $(uname -m)"
LARG=66            # largura das janelas (cabe no console 80x25)
INSTALANDO=0       # 1 depois da confirmação: a saída vai para o log
ERRO_MOSTRADO=0
TMP=""

# console VGA em modo texto (boot BIOS): a fonte da placa (CP437) não tem ã/õ
CP437=0
case $(tty 2>/dev/null) in
  /dev/ttyv*) if grep -qs '^VT(vga): text' /var/run/dmesg.boot; then CP437=1; fi ;;
esac

cor() { if [ -t 1 ]; then printf '\033[%sm%s\033[0m\n' "$1" "$2"; else printf '%s\n' "$2"; fi; }
titulo() { echo; cor '1;35' "==> $*"; }
info() { cor '0;36' "    $*"; }

_t() { # texto adaptado à fonte do console
  if [ "$CP437" -eq 1 ]; then
    printf '%s' "$1" | sed 's/ã/a/g; s/õ/o/g; s/Ã/A/g; s/Õ/O/g; s/Á/A/g; s/À/A/g; s/Â/A/g; s/Ê/E/g; s/Í/I/g; s/Ó/O/g; s/Ô/O/g; s/Ú/U/g'
  else
    printf '%s' "$1"
  fi
}

_linhas() { # imprime um texto com "\n" como linhas recuadas (modo texto)
  printf '%s\n' "$1" | awk '{ n = split($0, l, /\\n/); for (i = 1; i <= n; i++) print "    " l[i] }'
}

dlg() { # dlg "título" --<diálogo> ...  -> saída em $RESPOSTA, retorna o código do bsddialog
  _dt=$(_t "$1"); shift
  _dn=$#
  while [ "$_dn" -gt 0 ]; do set -- "$@" "$(_t "$1")"; shift; _dn=$((_dn - 1)); done
  _drc=0
  RESPOSTA=$(bsddialog --load-theme "$TEMA_UI" --backtitle "$(_t "$FUNDO")" \
    --title " $_dt " "$@" 2>&1 </dev/tty >/dev/tty) || _drc=$?
  return "$_drc"
}

erro() {
  if [ "$UI" = dialog ] && [ "$INSTALANDO" -eq 1 ]; then
    printf 'ERRO: %s\n' "$*"
    ERRO_MOSTRADO=1
    dlg "Erro" --msgbox "$*\n\nDetalhes no log: $LOG" 0 "$LARG" || true
    clear </dev/tty >/dev/tty 2>&1 || true
    printf 'ERRO: %s (log: %s)\n' "$*" "$LOG" >&4
  else
    cor '1;31' "ERRO: $*" >&2
  fi
  exit 1
}

perguntar() { # perguntar "texto" padrão -> $RESPOSTA (modo texto)
  printf '\033[1;34m?\033[0m %s [%s]: ' "$1" "$2"
  read -r RESPOSTA </dev/tty || true
  [ -n "$RESPOSTA" ] || RESPOSTA=$2
}

sim() { # sim "texto" s|n (modo texto)
  perguntar "$1 (s/n)" "$2"
  case $RESPOSTA in [sSyY]*) return 0 ;; *) return 1 ;; esac
}

sair_se_quiser() { # depois de "Sair" ou Esc numa tela
  if dlg "Sair" --yes-label Sair --no-label Voltar --default-no \
    --yesno "Sair do instalador?\n\nNada foi alterado no sistema até aqui." 9 "$LARG"; then
    clear </dev/tty >/dev/tty 2>&1 || true
    _t "Instalação cancelada. Nada foi alterado."; echo
    exit 0
  fi
}

ui_aviso() { # ui_aviso "texto"
  if [ "$UI" = dialog ]; then
    dlg "Atenção" --msgbox "$1" 0 "$LARG" || true
  else
    cor '1;31' "    $(_linhas "$1" | sed 's/^ *//')"
  fi
}

ui_input() { # ui_input título texto padrão -> $RESPOSTA
  if [ "$UI" = dialog ]; then
    until dlg "$1" --ok-label Próximo --cancel-label Sair --inputbox "$2" 0 "$LARG" "$3"; do sair_se_quiser; done
  else
    echo; _linhas "$2"; perguntar "$1" "$3"
  fi
}

ui_senha() { # ui_senha título texto -> $RESPOSTA (sem eco)
  if [ "$UI" = dialog ]; then
    until dlg "$1" --insecure --ok-label Próximo --cancel-label Sair --passwordbox "$2" 0 "$LARG"; do sair_se_quiser; done
  else
    printf '\033[1;34m?\033[0m %s: ' "$1"
    stty -echo </dev/tty; read -r RESPOSTA </dev/tty || true; stty echo </dev/tty; echo
  fi
}

ui_menu() { # ui_menu título texto padrão tag desc [tag desc]... -> $RESPOSTA
  _mt=$1; _mx=$2; _mp=$3; shift 3
  if [ "$UI" = dialog ]; then
    until dlg "$_mt" --default-item "$_mp" --ok-label Escolher --cancel-label Sair \
      --menu "$_mx" 0 "$LARG" 0 "$@"; do sair_se_quiser; done
    return 0
  fi
  echo; _linhas "$_mx"
  _tags=" "
  while [ $# -ge 2 ]; do info "  $1) $2"; _tags="$_tags$1 "; shift 2; done
  while :; do
    perguntar "$_mt" "$_mp"
    case $_tags in *" $RESPOSTA "*) return 0 ;; esac
    cor '1;31' "    opção inválida: $RESPOSTA"
  done
}

ui_check() { # ui_check título texto tag desc on|off [...] -> $RESPOSTA com as tags marcadas
  _ct=$1; _cx=$2; shift 2
  if [ "$UI" = dialog ]; then
    until dlg "$_ct" --ok-label Próximo --cancel-label Sair \
      --checklist "$_cx" 0 "$LARG" 0 "$@"; do sair_se_quiser; done
    RESPOSTA=$(printf '%s' "$RESPOSTA" | tr -d "\"'")
    return 0
  fi
  _sel=""
  while [ $# -ge 3 ]; do
    _pd=n; [ "$3" = on ] && _pd=s
    if sim "$2?" "$_pd"; then _sel="$_sel $1"; fi
    shift 3
  done
  RESPOSTA=$_sel
}

marcado() { # marcado tag "lista" -> 0 se a tag está na lista
  case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# ---------- progresso ----------
# ETAPAS: "peso:nome", uma por linha, na ordem em que rodam. O peso divide a
# barra geral (os pacotes levam a maior parte do tempo).
ETAPAS=""
ETAPA=0
PCT=0
etapa() { # etapa "nome": começa a próxima etapa
  ETAPA=$((ETAPA + 1))
  titulo "$1"
  progresso 0 ""
}

progresso() { # progresso pct_da_etapa "detalhe"
  PCT=$1
  [ "$UI" = dialog ] || return 0
  _pp=$1; _pdet=$2
  _ptot=0; _pfeito=0; _pi=0
  set --
  _pifs=$IFS; IFS='
'
  for _pe in $ETAPAS; do
    _pi=$((_pi + 1)); _peso=${_pe%%:*}; _nome=${_pe#*:}
    _ptot=$((_ptot + _peso))
    if [ "$_pi" -lt "$ETAPA" ]; then
      _pfeito=$((_pfeito + _peso * 100)); set -- "$@" "  $_nome" 100
    elif [ "$_pi" -eq "$ETAPA" ]; then
      _pfeito=$((_pfeito + _peso * _pp)); set -- "$@" "> $_nome" "$_pp"
    else
      set -- "$@" "  $_nome" 0
    fi
  done
  IFS=$_pifs
  dlg "Instalando" --mixedgauge "\n${_pdet:- }\n\nLog: $LOG" 0 "$LARG" "$((_pfeito / _ptot))" "$@" || true
}

ao_sair() {
  _rc=$?
  [ -n "$TMP" ] && rm -rf "$TMP"
  if [ "$_rc" -ne 0 ] && [ "$INSTALANDO" -eq 1 ] && [ "$UI" = dialog ] && [ "$ERRO_MOSTRADO" -eq 0 ]; then
    tail -n 40 "$LOG" > "$LOG.fim" 2>/dev/null || true
    dlg "A instalação parou (código $_rc)" --exit-label Fechar --textbox "$LOG.fim" 20 76 || true
    rm -f "$LOG.fim"
    clear </dev/tty >/dev/tty 2>&1 || true
    printf 'A instalação parou (código %s). Log completo: %s\n' "$_rc" "$LOG" >&4
  fi
}
trap ao_sair EXIT
trap 'exit 130' INT TERM

baixar_verificado() { # url sha256 destino [nome na tela]
  progresso "$PCT" "Baixando e conferindo (sha256): ${4:-${1##*/}}"
  fetch -q -o "$3" "$1" || erro "falha ao baixar $1"
  [ "$(sha256 -q "$3")" = "$2" ] || erro "checksum não confere: $1"
}

# ---------- checagens ----------
[ "$(uname -s)" = FreeBSD ] || erro "este script é para FreeBSD"
[ "$(id -u)" -eq 0 ] || erro "rode como root (su -)"
[ -d "$DOT/config/bspwm" ] || erro "pasta dotfiles/ não encontrada ao lado do script"

# ---------- perguntas ----------
if [ "$UI" = dialog ]; then
  dlg "Bem-vindo" --yes-label Começar --no-label Sair --yesno \
"Este instalador transforma o FreeBSD num ambiente de desenvolvimento com o bspwm e o tema Emilia.\n\n\
Instala o Xorg, bspwm, polybar, picom, rofi, alacritty, Firefox, Thunar e Neovim (AstroNvim), com temas, ícones e fontes.\n\n\
Nada muda no sistema até você confirmar o resumo.\n\
Setas e Tab navegam, Espaço marca, Enter confirma." 0 "$LARG" || sair_se_quiser
else
  cat <<'EOF'

  ┌──────────────────────────────────────────────┐
  │  freebsd-bspwm-aurtty                        │
  │  ambiente de desenvolvimento com bspwm       │
  └──────────────────────────────────────────────┘
EOF
  titulo "Configuração"
fi

# sugestão do driver de vídeo
if [ "$(sysctl -n kern.vm_guest)" != none ]; then
  if [ "$(sysctl -n machdep.bootmethod 2>/dev/null)" = UEFI ]; then SUG=2; else SUG=1; fi
else
  SUG=3
fi

USUARIO=${SUDO_USER:-}; TECLADO=br; VIDEO=$SUG; LOGIN=1; OPCIONAIS="terminal dev"
while :; do
  while :; do
    ui_input "Usuário" "Usuário que vai usar o bspwm.\nSe ele não existir, será criado agora." "$USUARIO"
    USUARIO=$RESPOSTA
    if [ -z "$USUARIO" ]; then ui_aviso "Informe um usuário."; continue; fi
    CRIAR_USUARIO=0
    id "$USUARIO" >/dev/null 2>&1 || CRIAR_USUARIO=1
    if [ $CRIAR_USUARIO -eq 1 ]; then
      case $USUARIO in
        [a-z_]*[!a-z0-9_-]*|[!a-z_]*)
          ui_aviso "Nome inválido: '$USUARIO'.\nUse letras minúsculas, números, _ ou -, começando por letra."
          continue ;;
      esac
    fi
    break
  done
  if [ $CRIAR_USUARIO -eq 1 ]; then
    while :; do
      ui_senha "Senha" "O usuário '$USUARIO' não existe e será criado.\nSenha para $USUARIO:"
      SENHA=$RESPOSTA
      ui_senha "Senha" "Repita a senha de $USUARIO:"
      SENHA2=$RESPOSTA
      [ -n "$SENHA" ] && [ "$SENHA" = "$SENHA2" ] && break
      ui_aviso "As senhas não conferem (ou estão vazias). Tente de novo."
    done
  fi

  ui_menu "Teclado" "Layout do teclado no ambiente gráfico." "$TECLADO" \
    br "Português do Brasil (ABNT2)" \
    us "Inglês (EUA)" \
    outro "Outro layout do XKB (digitar o nome)"
  TECLADO=$RESPOSTA
  if [ "$TECLADO" = outro ]; then
    ui_input "Teclado" "Nome do layout no XKB (ex.: pt, es, de, fr):" ""
    TECLADO=${RESPOSTA:-br}
  fi

  ui_menu "Vídeo" "Qual vídeo este computador usa?\nA sugestão para esta máquina já vem marcada ($SUG)." "$VIDEO" \
    1 "VM com BIOS (vesa)" \
    2 "VM ou PC com UEFI, sem driver (scfb)" \
    3 "Intel ou AMD (drm-kmod)" \
    4 "NVIDIA"
  VIDEO=$RESPOSTA

  ui_menu "Login" "Como você quer entrar no bspwm?" "$LOGIN" \
    1 "Tela de login gráfica (LightDM, tema Emilia)" \
    2 "Terminal: entrar no ttyv0 e o bspwm abre sozinho" \
    3 "Manual: rodar startx"
  LOGIN=$RESPOSTA

  _on_t=off; marcado terminal "$OPCIONAIS" && _on_t=on
  _on_d=off; marcado dev "$OPCIONAIS" && _on_d=on
  ui_check "Opcionais" "Espaço marca ou desmarca." \
    terminal "Terminal AurTTY: oh-my-bash, ble.sh, fzf-tab" "$_on_t" \
    dev "Ferramentas backend: node, deno, python..." "$_on_d"
  OPCIONAIS=$RESPOSTA
  TERMINAL=0; marcado terminal "$OPCIONAIS" && TERMINAL=1
  DEV=0; marcado dev "$OPCIONAIS" && DEV=1

  case $VIDEO in
    1) VIDEO_DESC="VM com BIOS (vesa)" ;;
    2) VIDEO_DESC="UEFI sem driver (scfb)" ;;
    3) VIDEO_DESC="Intel ou AMD (drm-kmod)" ;;
    4) VIDEO_DESC="NVIDIA" ;;
  esac
  case $LOGIN in
    1) LOGIN_DESC="tela de login (LightDM)" ;;
    2) LOGIN_DESC="ttyv0, abre o bspwm sozinho" ;;
    3) LOGIN_DESC="manual (startx)" ;;
  esac
  _novo=""; [ $CRIAR_USUARIO -eq 1 ] && _novo=" (novo)"
  _sn() { if [ "$1" -eq 1 ]; then echo sim; else echo não; fi; }
  RESUMO="Usuário:   $USUARIO$_novo\nTeclado:   $TECLADO\nVídeo:     $VIDEO_DESC\nEntrada:   $LOGIN_DESC\nTerminal:  $(_sn $TERMINAL)\nBackend:   $(_sn $DEV)"

  if [ "$UI" = dialog ]; then
    _rc=0
    dlg "Resumo" --yes-label Instalar --no-label Refazer --yesno \
      "$RESUMO\n\nA instalação leva alguns minutos e baixa os pacotes da internet." 0 "$LARG" || _rc=$?
    case $_rc in
      0) break ;;
      1) continue ;;
      *) sair_se_quiser ;;
    esac
  else
    echo; titulo "Resumo"; _linhas "$RESUMO"; echo
    sim "Continuar?" s || exit 0
    break
  fi
done
AUTOX=0; [ "$LOGIN" = 2 ] && AUTOX=1

ETAPAS="55:Pacotes
3:Sistema e usuário
8:Temas, ícones e cursor
8:Fontes
4:Dotfiles e AstroNvim"
[ "$LOGIN" = 1 ] && ETAPAS="$ETAPAS
6:Tela de login"
[ $TERMINAL -eq 1 ] && ETAPAS="$ETAPAS
8:Terminal AurTTY"
ETAPAS="$ETAPAS
2:Ajustes finais"

# daqui em diante a saída detalhada vai para o log e a tela mostra o progresso
INSTALANDO=1
if [ "$UI" = dialog ]; then
  exec 3>&1 4>&2 >>"$LOG" 2>&1
  printf '\n===== freebsd-bspwm-aurtty: %s =====\n' "$(date)"
else
  exec 3>&1 4>&2
fi

# ---------- pacotes ----------
etapa "Pacotes"
info "log em $LOG"
progresso 0 "Atualizando o catálogo de pacotes (pkg update)..."
export ASSUME_ALWAYS_YES=yes
pkg bootstrap -q </dev/null >>"$LOG" 2>&1 || true
pkg update -q </dev/null >>"$LOG" 2>&1

VIDEO_PKGS=""
case $VIDEO in
  1) VIDEO_PKGS="xf86-video-vesa" ;;
  2) VIDEO_PKGS="xf86-video-scfb" ;;
  3) VIDEO_PKGS="drm-kmod libva-intel-media-driver" ;;
  4) VIDEO_PKGS="nvidia-driver nvidia-xconfig" ;;
esac

# py3xx do python padrão (python3 -> python312 -> py312-httpie...)
EXTRA_PKGS=""
if [ $DEV -eq 1 ]; then
  PY=$(pkg rquery '%dn' python3 2>/dev/null | grep '^python3' | head -1 | sed 's/^python/py/')
  EXTRA_PKGS=$DEV_PKGS
  for p in $DEV_PY; do EXTRA_PKGS="$EXTRA_PKGS ${PY:-py312}-$p"; done
fi

FALHARAM=""
TODOS=$(echo $PACOTES $VIDEO_PKGS $EXTRA_PKGS)
N_PKGS=$(echo "$TODOS" | wc -w | tr -d ' ')
N=0
for p in $TODOS; do
  N=$((N + 1))
  progresso $(((N - 1) * 100 / N_PKGS)) "Pacote $N de $N_PKGS:  $p"
  printf '    %-28s' "$p"
  if pkg install -q "$p" </dev/null >>"$LOG" 2>&1; then cor '0;32' ok; else cor '0;31' falhou; FALHARAM="$FALHARAM $p"; fi
done

# ---------- sistema ----------
etapa "Sistema e usuário"
sysrc -q dbus_enable=YES >/dev/null
service dbus status >/dev/null 2>&1 || service dbus start >>"$LOG" 2>&1 || true

case $VIDEO in
  3)
    if pciconf -lv | grep -A1 '^vgapci' | grep -qi intel; then
      sysrc -q kld_list+=i915kms >/dev/null
    else
      sysrc -q kld_list+=amdgpu >/dev/null
    fi ;;
  4) sysrc -q kld_list+=nvidia-modeset >/dev/null ;;
esac

mkdir -p /usr/local/etc/X11/xorg.conf.d
cat > /usr/local/etc/X11/xorg.conf.d/10-teclado.conf <<EOF
Section "InputClass"
    Identifier "teclado"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$TECLADO"
EndSection
EOF
case $VIDEO in
  1|2)
    DRV=vesa; [ "$VIDEO" = 2 ] && DRV=scfb
    cat > /usr/local/etc/X11/xorg.conf.d/20-video.conf <<EOF
Section "Device"
    Identifier "video"
    Driver "$DRV"
EndSection
EOF
    ;;
  4)
    cat > /usr/local/etc/X11/xorg.conf.d/20-video.conf <<'EOF'
Section "Device"
    Identifier "video"
    Driver "nvidia"
EndSection
EOF
    ;;
esac
info "xorg.conf.d: teclado=$TECLADO"

# ---------- usuário ----------
titulo "Usuário $USUARIO"
if [ $CRIAR_USUARIO -eq 1 ]; then
  printf '%s\n' "$SENHA" | pw useradd "$USUARIO" -m -G wheel,video -s /bin/sh -c "$USUARIO" -h 0
  unset SENHA SENHA2
  info "usuário criado"
else
  pw groupmod video -m "$USUARIO"
  pw groupmod wheel -m "$USUARIO"
fi
CASA=$(pw usershow "$USUARIO" | cut -d: -f9)
GRUPO=$(id -gn "$USUARIO")

# ---------- temas GTK, ícones e cursor ----------
etapa "Temas, ícones e cursor"
TMP=$(mktemp -d)
for item in "$TEMA_GTK" "$TEMA_ICONES" "$TEMA_CURSOR"; do
  arq=${item% *}; sha=${item#* }
  info "$arq"
  baixar_verificado "$GH0STZK_PKGS/$arq" "$sha" "$TMP/$arq"
done
mkdir -p /usr/local/share/themes /usr/local/share/icons
tar -xf "$TMP/${TEMA_GTK% *}" -C /usr/local/share/themes --strip-components 3 usr/share/themes/TokyoNight-zk
tar -xf "$TMP/${TEMA_ICONES% *}" -C /usr/local/share/icons --strip-components 3 usr/share/icons
tar -xf "$TMP/${TEMA_CURSOR% *}" -C /usr/local/share/icons --strip-components 3 usr/share/icons
gtk-update-icon-cache -q -f /usr/local/share/icons/TokyoNight-SE 2>/dev/null || true

# ---------- fontes ----------
etapa "Fontes"
FONTES=/usr/local/share/fonts/aurtty
mkdir -p "$FONTES"
cp "$DOT"/fonts/* "$FONTES/"
baixar_verificado "$NERDFONT_URL" "$NERDFONT_SHA" "$TMP/JetBrainsMono.tar.xz"
tar -xf "$TMP/JetBrainsMono.tar.xz" -C "$FONTES" '*.ttf'
fc-cache -f >/dev/null 2>&1
info "JetBrainsMono Nerd Font, FontAwesome, Material Design Icons, MesloLGS NF"

# ---------- dotfiles ----------
etapa "Dotfiles e AstroNvim"
BACKUP="$CASA/.config-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$CASA/.config"
for d in bspwm alacritty dunst jgmenu clipcat gtk-3.0; do
  if [ -e "$CASA/.config/$d" ]; then
    mkdir -p "$BACKUP"
    mv "$CASA/.config/$d" "$BACKUP/"
  fi
  cp -R "$DOT/config/$d" "$CASA/.config/$d"
done
for f in .gtkrc-2.0 .icons; do
  if [ -e "$CASA/$f" ]; then mkdir -p "$BACKUP"; mv "$CASA/$f" "$BACKUP/"; fi
  cp -R "$DOT/home/$f" "$CASA/$f"
done
[ -d "$BACKUP" ] && info "configs anteriores salvas em $BACKUP"

# ---------- AstroNvim (configuração do Neovim) ----------
titulo "AstroNvim"
baixar_verificado "$ASTRONVIM_URL" "$ASTRONVIM_SHA" "$TMP/astronvim.tar.gz" AstroNvim
if [ -e "$CASA/.config/nvim" ]; then
  mkdir -p "$BACKUP"
  mv "$CASA/.config/nvim" "$BACKUP/"
fi
mkdir -p "$CASA/.config/nvim"
tar -xf "$TMP/astronvim.tar.gz" -C "$CASA/.config/nvim" --strip-components 1
info "config em ~/.config/nvim; o 'nvim' instala os plugins na primeira execução"

# calendário do relógio da barra (gsimplecal)
mkdir -p "$CASA/.config/gsimplecal"
install -m 644 "$RAIZ/extras/gsimplecal/config" "$CASA/.config/gsimplecal/config"

# pastas padrão na home (Desktop, Documents, Downloads, Pictures...), em inglês
su -m "$USUARIO" -c "HOME='$CASA' LANG=en_US.UTF-8 xdg-user-dirs-update" 2>/dev/null || true

# Thunar como gerenciador de arquivos padrão (pastas abrem nele)
if ! grep -qs '^inode/directory=' "$CASA/.config/mimeapps.list"; then
  grep -qs '^\[Default Applications\]' "$CASA/.config/mimeapps.list" ||
    printf '[Default Applications]\n' >> "$CASA/.config/mimeapps.list"
  printf 'inode/directory=thunar.desktop\n' >> "$CASA/.config/mimeapps.list"
fi

# menu de apps (rofi) só com o que se usa: esconde demos do GTK, xterm e utilitários
mkdir -p "$CASA/.local/share/applications"
for app in gtk3-demo gtk3-icon-browser gtk3-widget-factory org.gtk.Demo4 org.gtk.PrintEditor4 \
  org.gtk.WidgetFactory4 org.gtk.gtk4.NodeEditor org.gtk.IconBrowser4 xterm uxterm jgmenu picom feh \
  rofi rofi-theme-selector thunar-bulk-rename thunar-settings; do
  cat > "$CASA/.local/share/applications/$app.desktop" <<EOF2
[Desktop Entry]
# gerado pelo freebsd-bspwm-aurtty: esconde do menu de apps
Type=Application
Name=$app
NoDisplay=true
EOF2
done
chown -R "$USUARIO:$GRUPO" "$CASA/.local"

# Firefox com o tema escuro (o usuário pode trocar; é só o padrão)
mkdir -p /usr/local/lib/firefox/distribution
install -m 644 "$RAIZ/extras/firefox/policies.json" /usr/local/lib/firefox/distribution/policies.json

cat > "$CASA/.xinitrc" <<'EOF'
#!/bin/sh
# gerado pelo freebsd-bspwm-aurtty
export LANG=en_US.UTF-8
export XDG_CURRENT_DESKTOP=bspwm
export BROWSER=firefox
export FILEMANAGER=thunar
exec dbus-launch --exit-with-session bspwm
EOF

# remove o bloco de startx de instalações anteriores (volta a ser escrito se LOGIN=2)
for perfil in .profile .bash_profile; do
  arq="$CASA/$perfil"
  [ -f "$arq" ] || continue
  awk '/^# freebsd-bspwm-aurtty: abre o bspwm ao entrar no ttyv0$/ {pula=1; next}
       pula && /^fi$/ {pula=0; next}
       !pula' "$arq" > "$arq.tmp" && mv "$arq.tmp" "$arq"
done

if [ $AUTOX -eq 1 ]; then
  for perfil in .profile .bash_profile; do
    [ "$perfil" = .bash_profile ] && [ ! -e "$CASA/$perfil" ] && continue
    arq="$CASA/$perfil"
    touch "$arq"
    if ! grep -q 'abre o bspwm ao entrar no ttyv0' "$arq"; then
      cat >> "$arq" <<'EOF'
# freebsd-bspwm-aurtty: abre o bspwm ao entrar no ttyv0
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = /dev/ttyv0 ]; then
  exec startx
fi
EOF
    fi
  done
fi

# ---------- tela de login (LightDM) ----------
if [ "$LOGIN" = 1 ]; then
  etapa "Tela de login"
  for p in lightdm lightdm-gtk-greeter; do
    progresso 30 "Pacote: $p"
    pkg install -q "$p" </dev/null >>"$LOG" 2>&1 || FALHARAM="$FALHARAM $p"
  done

  # sessão própria: o mesmo que o .xinitrc (dbus + bspwm)
  cat > /usr/local/bin/aurtty-session <<'EOF'
#!/bin/sh
# freebsd-bspwm-aurtty: sessão bspwm aberta pela tela de login
export LANG=en_US.UTF-8
export XDG_CURRENT_DESKTOP=bspwm
export BROWSER=firefox
export FILEMANAGER=thunar
exec dbus-launch --exit-with-session bspwm
EOF
  chmod 755 /usr/local/bin/aurtty-session
  mkdir -p /usr/local/share/xsessions
  cat > /usr/local/share/xsessions/bspwm-aurtty.desktop <<'EOF'
[Desktop Entry]
Name=bspwm (AurTTY)
Comment=bspwm com o tema Emilia
Exec=/usr/local/bin/aurtty-session
Type=Application
EOF

  # fundo da tela de login: o wallpaper padrão em png (lido pelo usuário do lightdm)
  mkdir -p /usr/local/share/backgrounds/aurtty
  magick "$DOT/config/bspwm/rices/emilia/walls/aurtty-freebsd-dark.webp" \
    /usr/local/share/backgrounds/aurtty/login.png
  chmod 644 /usr/local/share/backgrounds/aurtty/login.png
  install -m 644 "$RAIZ/extras/lightdm/avatar.png" /usr/local/share/backgrounds/aurtty/avatar.png

  # tema só da tela de login: TokyoNight-zk + CSS do cartão, campos e botões
  mkdir -p /usr/local/share/themes/AurTTY-Login/gtk-3.0
  install -m 644 "$RAIZ/extras/lightdm/gtk.css" /usr/local/share/themes/AurTTY-Login/gtk-3.0/gtk.css

  cat > /usr/local/etc/lightdm/lightdm-gtk-greeter.conf <<'EOF'
# gerado pelo freebsd-bspwm-aurtty (tema Emilia / Tokyo Night)
[greeter]
background = /usr/local/share/backgrounds/aurtty/login.png
user-background = false
theme-name = AurTTY-Login
icon-theme-name = TokyoNight-SE
cursor-theme-name = Qogirr-Dark
cursor-theme-size = 24
font-name = JetBrainsMono Nerd Font 11
xft-antialias = true
xft-hintstyle = hintslight
xft-rgba = rgb
indicators = ~host;~spacer;~clock;~spacer;~session;~power
clock-format = %a %d/%m  %H:%M
position = 80%,center 50%,center
hide-user-image = false
default-user-image = /usr/local/share/backgrounds/aurtty/avatar.png
EOF

  mkdir -p /usr/local/etc/lightdm/lightdm.conf.d
  cat > /usr/local/etc/lightdm/lightdm.conf.d/50-aurtty.conf <<'EOF'
# gerado pelo freebsd-bspwm-aurtty
[Seat:*]
greeter-session = lightdm-gtk-greeter
user-session = bspwm-aurtty
EOF
  # botões desligar/reiniciar/suspender: o greeter roda como "lightdm", fora
  # de uma sessão ativa, e o polkit nega. Libera para ele e para wheel/operator.
  mkdir -p /usr/local/etc/polkit-1/rules.d
  cat > /usr/local/etc/polkit-1/rules.d/50-aurtty-energia.rules <<'EOF'
// gerado pelo freebsd-bspwm-aurtty
// tela de login (usuario lightdm) e grupos wheel/operator podem desligar, reiniciar e suspender
polkit.addRule(function (action, subject) {
    if (action.id.indexOf("org.freedesktop.consolekit.system.") == 0 &&
        (subject.user == "lightdm" || subject.isInGroup("wheel") || subject.isInGroup("operator"))) {
        return polkit.Result.YES;
    }
});
EOF
  sysrc -q lightdm_enable=YES >/dev/null
  info "LightDM ativado (abre sozinho no boot)"
else
  sysrc -q lightdm_enable=NO >/dev/null 2>&1 || true
fi

# ---------- terminal ----------
if [ $TERMINAL -eq 1 ]; then
  etapa "Terminal AurTTY"
  baixar_verificado "$OMB_URL" "$OMB_SHA" "$TMP/omb.tar.gz" oh-my-bash
  baixar_verificado "$BLE_URL" "$BLE_SHA" "$TMP/ble.tar.xz"
  baixar_verificado "$FZFTAB_URL" "$FZFTAB_SHA" "$TMP/fzftab.tar.gz" fzf-tab-completion
  # mesmo terminal para o usuário e para o root (su -)
  for alvo in "$CASA:$USUARIO:$GRUPO" "/root:root:wheel"; do
    casa=${alvo%%:*}; dono=${alvo#*:}; dono=${dono%%:*}; grupo=${alvo##*:}
    rm -rf "$casa/.oh-my-bash" "$casa/.local/share/blesh" "$casa/.local/share/fzf-tab-completion"
    mkdir -p "$casa/.oh-my-bash" "$casa/.local/share/blesh" "$casa/.local/share/fzf-tab-completion" "$casa/.local/bin"
    tar -xf "$TMP/omb.tar.gz" -C "$casa/.oh-my-bash" --strip-components 1
    tar -xf "$TMP/ble.tar.xz" -C "$casa/.local/share/blesh" --strip-components 1
    tar -xf "$TMP/fzftab.tar.gz" -C "$casa/.local/share/fzf-tab-completion" --strip-components 1
    install -m 755 "$RAIZ/extras/bash/fzf-tab-preview" "$casa/.local/bin/fzf-tab-preview"
    # saudação com figuras do universo (Andrômeda, Pilares da Criação, TON 618)
    rm -rf "$casa/.local/share/universo"
    cp -R "$RAIZ/extras/bash/universo" "$casa/.local/share/universo"
    if [ -e "$casa/.bashrc" ] && ! grep -q 'freebsd-bspwm-aurtty' "$casa/.bashrc"; then
      mkdir -p "$BACKUP"; mv "$casa/.bashrc" "$BACKUP/bashrc-$dono"
    fi
    cp "$RAIZ/extras/bash/bashrc" "$casa/.bashrc"
    # o bash de login lê o .bash_profile: repassa para o .profile (startx) e o .bashrc
    cat > "$casa/.bash_profile" <<'EOF2'
# gerado pelo freebsd-bspwm-aurtty
[ -f ~/.bashrc ] && . ~/.bashrc
[ -f ~/.profile ] && . ~/.profile
EOF2
    chown -R "$dono:$grupo" "$casa/.oh-my-bash" "$casa/.local" "$casa/.bashrc" "$casa/.bash_profile"
  done
  pw usermod "$USUARIO" -s /usr/local/bin/bash
  # O shell do root continua /bin/sh (o FreeBSD recomenda: entra mesmo se o
  # bash do pkg quebrar). No login interativo (su -, console) ele vira bash.
  if ! grep -q 'freebsd-bspwm-aurtty: sh interativo' /root/.profile; then
    cat >> /root/.profile <<'EOF2'
# freebsd-bspwm-aurtty: sh interativo vira bash com o tema (o shell continua /bin/sh)
case $- in
  *i*) [ -z "${BASH_VERSION:-}" ] && [ -x /usr/local/bin/bash ] && exec /usr/local/bin/bash -l ;;
esac
EOF2
  fi
  info "root (su -): mesmo terminal, com /bin/sh como shell de segurança"
  info "shell padrão de $USUARIO: /usr/local/bin/bash"
fi

# ---------- atualizar: atualização com "desfazer" (boot environment do ZFS) ----------
etapa "Ajustes finais"
install -m 755 "$RAIZ/extras/bin/atualizar" /usr/local/bin/atualizar
if [ "$(mount -p | awk '$2 == "/" {print $3}')" = zfs ]; then
  info "atualizar: tira uma cópia do sistema antes de atualizar (atualizar --voltar desfaz)"
else
  info "atualizar: sistema em UFS, atualiza sem cópia (o desfazer precisa de ZFS)"
fi

# ---------- devdb: bancos de desenvolvimento em jails ----------
if [ $DEV -eq 1 ]; then
  install -m 755 "$RAIZ/extras/bin/devdb" /usr/local/bin/devdb
  sysrc -q bastille_enable=YES >/dev/null     # as jails dos bancos voltam sozinhas no boot
  info "devdb: 'devdb criar postgres' (ou mysql, valkey, mongo) sobe o banco numa jail"
fi

# Sem GPU (vesa/scfb) o OpenGL é por software e o picom com glx inverte
# vermelho/azul nas janelas transparentes (rofi). O xrender evita isso.
if [ "$VIDEO" = 1 ] || [ "$VIDEO" = 2 ]; then
  sed -i '' 's/^backend = "glx";/backend = "xrender";/' "$CASA/.config/bspwm/config/picom/picom.conf"
  info "picom: backend xrender (sem aceleração de vídeo)"
fi

chown -R "$USUARIO:$GRUPO" "$CASA/.config" "$CASA/.xinitrc" "$CASA/.gtkrc-2.0" "$CASA/.icons"
[ -e "$CASA/.profile" ] && chown "$USUARIO:$GRUPO" "$CASA/.profile"
[ -d "$BACKUP" ] && chown -R "$USUARIO:$GRUPO" "$BACKUP"

# ---------- fim ----------
progresso 100 "Concluído"
REINICIAR=0
FIM="A instalação terminou."
[ -n "$FALHARAM" ] && FIM="A instalação terminou, mas alguns pacotes falharam (veja o log):\n$FALHARAM"
if [ "$VIDEO" = 3 ] || [ "$VIDEO" = 4 ]; then
  REINICIAR=1
  FIM="$FIM\n\nO driver de vídeo é carregado no boot: reinicie com 'reboot'."
fi
if [ "$LOGIN" = 1 ]; then
  REINICIAR=1
  FIM="$FIM\n\nReinicie com 'reboot' e a tela de login abre sozinha."
elif [ $AUTOX -eq 1 ]; then
  FIM="$FIM\n\nEntre como '$USUARIO' no ttyv0 e o bspwm abre sozinho."
else
  FIM="$FIM\n\nEntre como '$USUARIO' e rode: startx"
fi
FIM="$FIM\n\nAtalhos: super+Enter terminal, super+Espaço menu, alt+F1 ajuda\nApps: super+b Firefox, super+f Thunar, nvim (AstroNvim)\nLog: $LOG"

INSTALANDO=0
exec 1>&3 2>&4
if [ "$UI" = dialog ]; then
  if [ $REINICIAR -eq 1 ]; then
    if dlg "Pronto" --yes-label "Reiniciar agora" --no-label Depois --default-no --yesno "$FIM" 0 "$LARG"; then
      clear; shutdown -r now; exit 0
    fi
  else
    dlg "Pronto" --ok-label Fechar --msgbox "$FIM" 0 "$LARG" || true
  fi
  clear
fi
titulo "Pronto"
_linhas "$(_t "$FIM")"
