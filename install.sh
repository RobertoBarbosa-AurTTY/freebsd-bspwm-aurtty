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
INICIO=$(date +%s)

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
firefox pcmanfm neovim ripgrep fd-find"

# ferramentas de desenvolvimento backend (opcional). Os py3xx-* entram depois,
# com a versão do python padrão do repositório. Sem Docker no FreeBSD.
DEV_PKGS="lazygit tmux gh mise uv go-yq xh python3 node22 npm-node22 deno
sqlite3 postgresql17-client mariadb114-client valkey hs-ShellCheck bastille"
DEV_PY="httpie pgcli pre-commit"

# ---------- interface ----------
UI_TTY=0
if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then UI_TTY=1; fi

UI_COR=0
if [ "$UI_TTY" -eq 1 ] && [ -z "${NO_COLOR:-}" ]; then UI_COR=1; fi

UI_256=0
case ${TERM:-} in *256color*) UI_256=1 ;; esac

C_RST=; C_BOLD=; C_DIM=; C_ACC=; C_MAG=; C_GRN=; C_RED=; C_YEL=
if [ "$UI_COR" -eq 1 ]; then
  C_RST=$(printf '\033[0m')
  C_BOLD=$(printf '\033[1m')
  C_DIM=$(printf '\033[2m')
  if [ "$UI_256" -eq 1 ]; then
    C_ACC=$(printf '\033[38;5;111m')
    C_MAG=$(printf '\033[38;5;141m')
    C_GRN=$(printf '\033[38;5;114m')
    C_RED=$(printf '\033[38;5;204m')
    C_YEL=$(printf '\033[38;5;180m')
  else
    C_ACC=$(printf '\033[36m')
    C_MAG=$(printf '\033[35m')
    C_GRN=$(printf '\033[32m')
    C_RED=$(printf '\033[31m')
    C_YEL=$(printf '\033[33m')
  fi
fi

cor() { if [ "$UI_COR" -eq 1 ]; then printf '\033[%sm%s\033[0m\n' "$1" "$2"; else printf '%s\n' "$2"; fi; }

banner() {
  printf '\n'
  printf '  %s─────────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RST"
  printf '  %s▄▀█ █░█ █▀█ ▀█▀ ▀█▀ █▄█%s\n' "$C_MAG" "$C_RST"
  printf '  %s█▀█ █▄█ █▀▄ ░█░ ░█░ ░█░%s\n' "$C_ACC" "$C_RST"
  printf '\n'
  printf '  %s%sfreebsd-bspwm-aurtty%s\n' "$C_BOLD" "$C_ACC" "$C_RST"
  printf '  %sPós-instalação do FreeBSD para desenvolvimento, redes e segurança%s\n' "$C_DIM" "$C_RST"
  printf '  %sFreeBSD %s · %s%s\n' "$C_DIM" "$(uname -r)" "$(uname -m)" "$C_RST"
  printf '  %s─────────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RST"
}

titulo() {
  printf '\n  %s◆%s %s%s%s\n' "$C_MAG" "$C_RST" "$C_BOLD" "$*" "$C_RST"
  printf '  %s─────────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RST"
}

info()  { printf '  %s·%s %s\n' "$C_ACC" "$C_RST" "$*"; }
ok()    { printf '  %sok%s   %s\n' "$C_GRN" "$C_RST" "$*"; }
aviso() { printf '  %s!%s %s\n' "$C_YEL" "$C_RST" "$*"; }
erro()  { printf '\n  %s%sERRO%s %s\n\n' "$C_RED" "$C_BOLD" "$C_RST" "$*" >&2; exit 1; }

_prompt() { # texto [dica]
  printf '  %s?%s %s' "$C_ACC" "$C_RST" "$1"
  if [ -n "${2:-}" ]; then printf ' %s[%s]%s' "$C_DIM" "$2" "$C_RST"; fi
  printf ': '
}

perguntar() { # perguntar "texto" padrão -> $RESPOSTA
  _prompt "$1" "$2"
  read -r RESPOSTA </dev/tty || true
  [ -n "$RESPOSTA" ] || RESPOSTA=$2
}

sim() { # sim "texto" s|n
  case $2 in [sS]) _dica='S/n' ;; *) _dica='s/N' ;; esac
  _prompt "$1" "$_dica"
  read -r RESPOSTA </dev/tty || true
  [ -n "$RESPOSTA" ] || RESPOSTA=$2
  case $RESPOSTA in [sSyY]*) return 0 ;; *) return 1 ;; esac
}

opcoes() { # opcoes 1 "texto" 2 "texto" ...
  while [ $# -ge 2 ]; do
    printf '      %s%s)%s %s\n' "$C_ACC" "$1" "$C_RST" "$2"
    shift 2
  done
}

_barra() { # porcentagem [largura]
  _bp=$1
  _bw=${2:-20}
  _bf=$((_bp * _bw / 100))
  _be=$((_bw - _bf))
  printf '%s' "$C_GRN"
  while [ "$_bf" -gt 0 ]; do printf '█'; _bf=$((_bf - 1)); done
  printf '%s' "$C_DIM"
  while [ "$_be" -gt 0 ]; do printf '░'; _be=$((_be - 1)); done
  printf '%s' "$C_RST"
}

_spinner_exec() { # rótulo comando...
  _se_rotulo=$1
  shift
  if [ "$UI_TTY" -eq 0 ]; then
    if "$@" >>"$LOG" 2>&1; then return 0; else return 1; fi
  fi
  _se_dir=$(mktemp -d)
  ( if "$@" >>"$LOG" 2>&1; then echo 0 >"$_se_dir/rc"; else echo 1 >"$_se_dir/rc"; fi ) &
  _se_pid=$!
  _se_i=0
  while [ ! -f "$_se_dir/rc" ]; do
    case $((_se_i % 4)) in
      0) _se_spin='|' ;;
      1) _se_spin='/' ;;
      2) _se_spin='-' ;;
      *) _se_spin='\' ;;
    esac
    printf '\r\033[K    %s↓%s %-50.50s %s%s%s' "$C_ACC" "$C_RST" "$_se_rotulo" "$C_DIM" "$_se_spin" "$C_RST"
    sleep 0.12
    _se_i=$((_se_i + 1))
  done
  wait "$_se_pid" || true
  _se_rc=$(cat "$_se_dir/rc")
  rm -rf "$_se_dir"
  printf '\r\033[K'
  return "$_se_rc"
}

instalar_pacote() { # pacote número total
  _ip_pkg=$1
  _ip_num=$2
  _ip_tot=$3
  _ip_pct=$((_ip_num * 100 / _ip_tot))
  if [ "$UI_TTY" -eq 0 ]; then
    printf '  [%3d/%d] %3d%% %-30.30s ' "$_ip_num" "$_ip_tot" "$_ip_pct" "$_ip_pkg"
    if pkg install -q "$_ip_pkg" </dev/null >>"$LOG" 2>&1; then
      printf 'ok\n'
    else
      printf 'falhou\n'
      FALHARAM="$FALHARAM $_ip_pkg"
    fi
    return 0
  fi
  _ip_dir=$(mktemp -d)
  ( if pkg install -q "$_ip_pkg" </dev/null >>"$LOG" 2>&1; then echo 0 >"$_ip_dir/rc"; else echo 1 >"$_ip_dir/rc"; fi ) &
  _ip_pid=$!
  _ip_i=0
  while [ ! -f "$_ip_dir/rc" ]; do
    case $((_ip_i % 4)) in
      0) _ip_spin='|' ;;
      1) _ip_spin='/' ;;
      2) _ip_spin='-' ;;
      *) _ip_spin='\' ;;
    esac
    printf '\r\033[K  [%s] %3d%% %3d/%d  %-30.30s %s%s%s' "$(_barra "$_ip_pct" 20)" "$_ip_pct" "$_ip_num" "$_ip_tot" "$_ip_pkg" "$C_DIM" "$_ip_spin" "$C_RST"
    sleep 0.12
    _ip_i=$((_ip_i + 1))
  done
  wait "$_ip_pid" || true
  _ip_rc=$(cat "$_ip_dir/rc")
  rm -rf "$_ip_dir"
  printf '\r\033[K  [%s] %3d%% %3d/%d  %-30.30s ' "$(_barra "$_ip_pct" 20)" "$_ip_pct" "$_ip_num" "$_ip_tot" "$_ip_pkg"
  if [ "$_ip_rc" -eq 0 ]; then
    printf '%sok%s\n' "$C_GRN" "$C_RST"
  else
    printf '%sfalhou%s\n' "$C_RED" "$C_RST"
    FALHARAM="$FALHARAM $_ip_pkg"
  fi
}

baixar_verificado() { # url sha256 destino
  _bv_nome=${1##*/}
  if _spinner_exec "$_bv_nome" fetch -q -o "$3" "$1"; then
    if [ "$(sha256 -q "$3")" = "$2" ]; then
      printf '    %s↓%s %-50.50s %sok%s %s(sha256)%s\n' "$C_ACC" "$C_RST" "$_bv_nome" "$C_GRN" "$C_RST" "$C_DIM" "$C_RST"
    else
      erro "checksum não confere: $1 (veja $LOG)"
    fi
  else
    erro "falha ao baixar $1 (veja $LOG)"
  fi
}

# ---------- checagens ----------
[ "$(uname -s)" = FreeBSD ] || erro "este script é para FreeBSD"
[ "$(id -u)" -eq 0 ] || erro "rode como root (su -)"
[ -d "$DOT/config/bspwm" ] || erro "pasta dotfiles/ não encontrada ao lado do script"

banner

# ---------- perguntas ----------
titulo "Configuração"
info "Enter aceita o valor padrão entre colchetes."

perguntar "Usuário que vai usar o bspwm (existente ou novo)" "${SUDO_USER:-}"
USUARIO=$RESPOSTA
[ -n "$USUARIO" ] || erro "informe um usuário"
CRIAR_USUARIO=0
id "$USUARIO" >/dev/null 2>&1 || CRIAR_USUARIO=1
if [ $CRIAR_USUARIO -eq 1 ]; then
  info "o usuário '$USUARIO' não existe e será criado"
  while :; do
    _prompt "Senha para $USUARIO" ""
    stty -echo </dev/tty; read -r SENHA </dev/tty; stty echo </dev/tty; echo
    _prompt "Repita a senha" ""
    stty -echo </dev/tty; read -r SENHA2 </dev/tty; stty echo </dev/tty; echo
    [ -n "$SENHA" ] && [ "$SENHA" = "$SENHA2" ] && break
    aviso "as senhas não conferem (ou estão vazias), tente de novo"
  done
fi

perguntar "Layout do teclado (br = ABNT2, us)" "br"
TECLADO=$RESPOSTA

# sugere o driver de vídeo
if [ "$(sysctl -n kern.vm_guest)" != none ]; then
  if [ "$(sysctl -n machdep.bootmethod 2>/dev/null)" = UEFI ]; then SUG=2; else SUG=1; fi
else
  SUG=3
fi
printf '\n'
opcoes 1 "VM com BIOS (vesa)" \
       2 "VM/PC com UEFI sem driver (scfb)" \
       3 "Intel ou AMD (drm-kmod)" \
       4 "NVIDIA"
perguntar "Driver de vídeo" "$SUG"
VIDEO=$RESPOSTA
case $VIDEO in 1|2|3|4) ;; *) erro "opção de vídeo inválida" ;; esac

printf '\n'
opcoes 1 "tela de login gráfica (LightDM, tema AurTTY)" \
       2 "terminal (ttyv0) com autostart do bspwm" \
       3 "manual (startx)"
perguntar "Como entrar no bspwm" 1
LOGIN=$RESPOSTA
case $LOGIN in 1|2|3) ;; *) erro "opção de login inválida" ;; esac
AUTOX=0; [ "$LOGIN" = 2 ] && AUTOX=1

printf '\n'
info "Terminal: bash + oh-my-bash (powerline) + ble.sh + fzf-tab"
TERMINAL=0
sim "Usar esse terminal como shell padrão?" s && TERMINAL=1

info "Backend: node, deno, python, mise, clientes de banco e devdb"
DEV=0
sim "Instalar as ferramentas de desenvolvimento backend?" s && DEV=1

case $VIDEO in
  1) VID_TXT="vesa (VM com BIOS)" ;;
  2) VID_TXT="scfb (UEFI sem driver)" ;;
  3) VID_TXT="drm-kmod (Intel/AMD)" ;;
  4) VID_TXT="NVIDIA (nvidia-driver)" ;;
esac
case $LOGIN in
  1) LOGIN_TXT="LightDM (tela gráfica)" ;;
  2) LOGIN_TXT="ttyv0 (autostart do bspwm)" ;;
  3) LOGIN_TXT="startx (manual)" ;;
esac
if [ $TERMINAL -eq 1 ]; then TERM_TXT=sim; else TERM_TXT=não; fi
if [ $DEV -eq 1 ]; then DEV_TXT=sim; else DEV_TXT=não; fi

printf '\n  %sResumo%s\n' "$C_BOLD" "$C_RST"
printf '  %s·%s Usuário: %s%s%s\n' "$C_ACC" "$C_RST" "$C_BOLD" "$USUARIO" "$C_RST"
printf '  %s·%s Teclado: %s\n' "$C_ACC" "$C_RST" "$TECLADO"
printf '  %s·%s Vídeo: %s\n' "$C_ACC" "$C_RST" "$VID_TXT"
printf '  %s·%s Login: %s\n' "$C_ACC" "$C_RST" "$LOGIN_TXT"
printf '  %s·%s Terminal: %s\n' "$C_ACC" "$C_RST" "$TERM_TXT"
printf '  %s·%s Dev/redes: %s\n' "$C_ACC" "$C_RST" "$DEV_TXT"
printf '\n'
sim "Continuar com a instalação?" s || exit 0

# ---------- pacotes ----------
titulo "Pacotes"
info "log: $LOG"
export ASSUME_ALWAYS_YES=yes
pkg bootstrap -q </dev/null >>"$LOG" 2>&1 || true
if _spinner_exec "atualizando índices do pkg" pkg update -q </dev/null; then
  ok "índices de pacotes atualizados"
else
  erro "pkg update falhou (veja $LOG)"
fi

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

TOTAL=$(printf '%s\n' $PACOTES $VIDEO_PKGS $EXTRA_PKGS | wc -l | tr -d ' ')
info "$TOTAL pacotes na fila"
FALHARAM=""
_i=0
for p in $PACOTES $VIDEO_PKGS $EXTRA_PKGS; do
  _i=$((_i + 1))
  instalar_pacote "$p" "$_i" "$TOTAL"
done
if [ -z "$FALHARAM" ]; then
  ok "fila de pacotes concluída"
fi

# ---------- sistema ----------
titulo "Configurando o sistema"
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
ok "xorg.conf.d configurado (teclado: $TECLADO)"

# ---------- usuário ----------
titulo "Usuário $USUARIO"
if [ $CRIAR_USUARIO -eq 1 ]; then
  printf '%s\n' "$SENHA" | pw useradd "$USUARIO" -m -G wheel,video -s /bin/sh -c "$USUARIO" -h 0
  unset SENHA SENHA2
  ok "usuário $USUARIO criado (grupos wheel e video)"
else
  pw groupmod video -m "$USUARIO"
  pw groupmod wheel -m "$USUARIO"
  ok "usuário $USUARIO já existe (grupos wheel e video garantidos)"
fi
CASA=$(pw usershow "$USUARIO" | cut -d: -f9)
GRUPO=$(id -gn "$USUARIO")

# ---------- temas GTK, ícones e cursor ----------
titulo "Tema GTK TokyoNight-zk, ícones TokyoNight-SE e cursor Qogirr"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for item in "$TEMA_GTK" "$TEMA_ICONES" "$TEMA_CURSOR"; do
  arq=${item% *}; sha=${item#* }
  baixar_verificado "$GH0STZK_PKGS/$arq" "$sha" "$TMP/$arq"
done
mkdir -p /usr/local/share/themes /usr/local/share/icons
tar -xf "$TMP/${TEMA_GTK% *}" -C /usr/local/share/themes --strip-components 3 usr/share/themes/TokyoNight-zk
tar -xf "$TMP/${TEMA_ICONES% *}" -C /usr/local/share/icons --strip-components 3 usr/share/icons
tar -xf "$TMP/${TEMA_CURSOR% *}" -C /usr/local/share/icons --strip-components 3 usr/share/icons
gtk-update-icon-cache -q -f /usr/local/share/icons/TokyoNight-SE 2>/dev/null || true
ok "tema GTK, ícones e cursor instalados"

# ---------- fontes ----------
titulo "Fontes"
FONTES=/usr/local/share/fonts/aurtty
mkdir -p "$FONTES"
cp "$DOT"/fonts/* "$FONTES/"
baixar_verificado "$NERDFONT_URL" "$NERDFONT_SHA" "$TMP/JetBrainsMono.tar.xz"
tar -xf "$TMP/JetBrainsMono.tar.xz" -C "$FONTES" '*.ttf'
fc-cache -f >/dev/null 2>&1
ok "JetBrainsMono Nerd Font, FontAwesome, Material Design Icons e MesloLGS NF instaladas"

# ---------- dotfiles ----------
titulo "Dotfiles do tema Emilia"
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
ok "configurações copiadas para ~/.config"
[ -d "$BACKUP" ] && info "configs anteriores salvas em $BACKUP"

# ---------- AstroNvim (configuração do Neovim) ----------
titulo "AstroNvim"
baixar_verificado "$ASTRONVIM_URL" "$ASTRONVIM_SHA" "$TMP/astronvim.tar.gz"
if [ -e "$CASA/.config/nvim" ]; then
  mkdir -p "$BACKUP"
  mv "$CASA/.config/nvim" "$BACKUP/"
fi
mkdir -p "$CASA/.config/nvim"
tar -xf "$TMP/astronvim.tar.gz" -C "$CASA/.config/nvim" --strip-components 1
ok "config em ~/.config/nvim (o 'nvim' instala os plugins na primeira execução)"

cat > "$CASA/.xinitrc" <<'EOF'
#!/bin/sh
# gerado pelo freebsd-bspwm-aurtty
export LANG=${LANG:-pt_BR.UTF-8}
export XDG_CURRENT_DESKTOP=bspwm
export BROWSER=firefox
export FILEMANAGER=pcmanfm
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
  titulo "Tela de login: LightDM com o tema Emilia"
  info "instalando lightdm e lightdm-gtk-greeter"
  for p in lightdm lightdm-gtk-greeter; do
    pkg install -q "$p" </dev/null >>"$LOG" 2>&1 || FALHARAM="$FALHARAM $p"
  done

  # sessão própria: o mesmo que o .xinitrc (dbus + bspwm)
  cat > /usr/local/bin/aurtty-session <<'EOF'
#!/bin/sh
# freebsd-bspwm-aurtty: sessão bspwm aberta pela tela de login
export LANG=${LANG:-pt_BR.UTF-8}
export XDG_CURRENT_DESKTOP=bspwm
export BROWSER=firefox
export FILEMANAGER=pcmanfm
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
  ok "LightDM ativado (abre sozinho no boot)"
else
  sysrc -q lightdm_enable=NO >/dev/null 2>&1 || true
fi

# ---------- terminal ----------
if [ $TERMINAL -eq 1 ]; then
  titulo "Terminal: bash + oh-my-bash (powerline) + ble.sh + fzf-tab"
  baixar_verificado "$OMB_URL" "$OMB_SHA" "$TMP/omb.tar.gz"
  baixar_verificado "$BLE_URL" "$BLE_SHA" "$TMP/ble.tar.xz"
  baixar_verificado "$FZFTAB_URL" "$FZFTAB_SHA" "$TMP/fzftab.tar.gz"
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
install -m 755 "$RAIZ/extras/bin/atualizar" /usr/local/bin/atualizar
if [ "$(mount -p | awk '$2 == "/" {print $3}')" = zfs ]; then
  ok "atualizar: cria uma cópia do sistema antes de atualizar (atualizar --voltar desfaz)"
else
  aviso "atualizar: sistema em UFS, atualiza sem cópia (o desfazer precisa de ZFS)"
fi

# ---------- devdb: bancos de desenvolvimento em jails ----------
if [ $DEV -eq 1 ]; then
  install -m 755 "$RAIZ/extras/bin/devdb" /usr/local/bin/devdb
  sysrc -q bastille_enable=YES >/dev/null     # as jails dos bancos voltam sozinhas no boot
  ok "devdb pronto: 'devdb criar postgres' (ou mysql, valkey, mongo) sobe o banco numa jail"
fi

# Sem GPU (vesa/scfb) o OpenGL é por software e o picom com glx inverte
# vermelho/azul nas janelas transparentes (rofi). O xrender evita isso.
if [ "$VIDEO" = 1 ] || [ "$VIDEO" = 2 ]; then
  sed -i '' 's/^backend = "glx";/backend = "xrender";/' "$CASA/.config/bspwm/config/picom/picom.conf"
  ok "picom: backend xrender (sem aceleração de vídeo)"
fi

chown -R "$USUARIO:$GRUPO" "$CASA/.config" "$CASA/.xinitrc" "$CASA/.gtkrc-2.0" "$CASA/.icons"
[ -e "$CASA/.profile" ] && chown "$USUARIO:$GRUPO" "$CASA/.profile"
[ -d "$BACKUP" ] && chown -R "$USUARIO:$GRUPO" "$BACKUP"

# ---------- fim ----------
titulo "Instalação concluída"
if [ -n "$FALHARAM" ]; then
  aviso "pacotes com falha (veja $LOG):"
  for p in $FALHARAM; do printf '      - %s\n' "$p"; done
else
  ok "todos os pacotes instalados"
fi
if [ "$VIDEO" = 3 ] || [ "$VIDEO" = 4 ]; then
  info "driver de vídeo configurado para carregar no boot"
fi
if [ "$LOGIN" = 1 ]; then
  info "reinicie com 'reboot' e a tela de login abre sozinha"
elif [ $AUTOX -eq 1 ]; then
  info "entre como '$USUARIO' no ttyv0 e o bspwm abre sozinho"
else
  info "entre como '$USUARIO' e rode: startx"
fi
info "atalhos: super+Return (terminal), super+espaço (menu), alt+F1 (ajuda)"
info "apps: super+b Firefox, super+f PCManFM, nvim (AstroNvim)"
_DUR=$(( $(date +%s) - INICIO ))
printf '\n  %s─────────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RST"
printf '  %slog:%s %s\n' "$C_DIM" "$C_RST" "$LOG"
printf '  %stempo total:%s %d min %d s\n' "$C_DIM" "$C_RST" "$((_DUR / 60))" "$((_DUR % 60))"
