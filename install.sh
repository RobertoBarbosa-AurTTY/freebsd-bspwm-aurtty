#!/bin/sh
# freebsd-bspwm-aurtty: pós-instalação do FreeBSD com bspwm e o tema Emilia
# (dotfiles do gh0stzk, https://github.com/gh0stzk/dotfiles, GPL-3.0).
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

PACOTES="xorg bspwm sxhkd polybar picom rofi dunst alacritty feh xsettingsd jgmenu clipcat
xdo xdotool jq ImageMagick7 maim xclip pamixer playerctl pavucontrol pulseaudio
i3lock-color webp webp-pixbuf-loader bash gsed coreutils git curl dbus jetbrains-mono noto-basic
papirus-icon-theme eza zoxide fzf bat gawk gnugrep"

# ---------- utilitários ----------
cor() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
titulo() { echo; cor '1;35' "==> $*"; }
info() { cor '0;36' "    $*"; }
erro() { cor '1;31' "ERRO: $*" >&2; exit 1; }

perguntar() { # perguntar "texto" padrão -> $RESPOSTA
  printf '\033[1;34m?\033[0m %s [%s]: ' "$1" "$2"
  read -r RESPOSTA </dev/tty || true
  [ -n "$RESPOSTA" ] || RESPOSTA=$2
}

sim() { # sim "texto" s|n
  perguntar "$1 (s/n)" "$2"
  case $RESPOSTA in [sSyY]*) return 0 ;; *) return 1 ;; esac
}

baixar_verificado() { # url sha256 destino
  fetch -q -o "$3" "$1" || erro "falha ao baixar $1"
  [ "$(sha256 -q "$3")" = "$2" ] || erro "checksum não confere: $1"
}

# ---------- checagens ----------
[ "$(uname -s)" = FreeBSD ] || erro "este script é para FreeBSD"
[ "$(id -u)" -eq 0 ] || erro "rode como root (su -)"
[ -d "$DOT/config/bspwm" ] || erro "pasta dotfiles/ não encontrada ao lado do script"

cat <<'EOF'

  ┌──────────────────────────────────────────────┐
  │  freebsd-bspwm-aurtty · bspwm + tema Emilia  │
  │  dotfiles originais: gh0stzk (GPL-3.0)       │
  └──────────────────────────────────────────────┘
EOF

# ---------- perguntas ----------
titulo "Configuração"

perguntar "Usuário que vai usar o bspwm (existente ou novo)" "${SUDO_USER:-}"
USUARIO=$RESPOSTA
[ -n "$USUARIO" ] || erro "informe um usuário"
CRIAR_USUARIO=0
id "$USUARIO" >/dev/null 2>&1 || CRIAR_USUARIO=1
if [ $CRIAR_USUARIO -eq 1 ]; then
  info "o usuário '$USUARIO' não existe e será criado"
  while :; do
    printf '\033[1;34m?\033[0m Senha para %s: ' "$USUARIO"
    stty -echo </dev/tty; read -r SENHA </dev/tty; stty echo </dev/tty; echo
    printf '\033[1;34m?\033[0m Repita a senha: '
    stty -echo </dev/tty; read -r SENHA2 </dev/tty; stty echo </dev/tty; echo
    [ -n "$SENHA" ] && [ "$SENHA" = "$SENHA2" ] && break
    cor '1;31' "    as senhas não conferem (ou estão vazias), tente de novo"
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
echo
info "Vídeo:  1) VM com BIOS (vesa)   2) VM/PC com UEFI sem driver (scfb)"
info "        3) Intel ou AMD (drm-kmod)   4) NVIDIA"
perguntar "Driver de vídeo" "$SUG"
VIDEO=$RESPOSTA
case $VIDEO in 1|2|3|4) ;; *) erro "opção de vídeo inválida" ;; esac

echo
info "Login:  1) tela de login gráfica (LightDM, com o tema Emilia)"
info "        2) entrar no terminal (ttyv0) e o bspwm abre sozinho   3) manual (startx)"
perguntar "Como entrar no bspwm" 1
LOGIN=$RESPOSTA
case $LOGIN in 1|2|3) ;; *) erro "opção de login inválida" ;; esac
AUTOX=0; [ "$LOGIN" = 2 ] && AUTOX=1

TERMINAL=0
sim "Terminal estilo AurTTY (bash + oh-my-bash powerline + ble.sh + fzf-tab) como shell padrão?" s && TERMINAL=1

echo
info "Resumo: usuário=$USUARIO teclado=$TECLADO vídeo=$VIDEO login=$LOGIN terminal=$TERMINAL"
sim "Continuar?" s || exit 0

# ---------- pacotes ----------
titulo "Instalando pacotes (log em $LOG)"
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

FALHARAM=""
for p in $PACOTES $VIDEO_PKGS; do
  printf '    %-28s' "$p"
  if pkg install -q "$p" </dev/null >>"$LOG" 2>&1; then cor '0;32' ok; else cor '0;31' falhou; FALHARAM="$FALHARAM $p"; fi
done

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
titulo "Tema GTK TokyoNight-zk, ícones TokyoNight-SE e cursor Qogirr"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
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
titulo "Fontes"
FONTES=/usr/local/share/fonts/aurtty
mkdir -p "$FONTES"
cp "$DOT"/fonts/* "$FONTES/"
baixar_verificado "$NERDFONT_URL" "$NERDFONT_SHA" "$TMP/JetBrainsMono.tar.xz"
tar -xf "$TMP/JetBrainsMono.tar.xz" -C "$FONTES" '*.ttf'
fc-cache -f >/dev/null 2>&1
info "JetBrainsMono Nerd Font, FontAwesome, Material Design Icons, MesloLGS NF"

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
[ -d "$BACKUP" ] && info "configs anteriores salvas em $BACKUP"

cat > "$CASA/.xinitrc" <<'EOF'
#!/bin/sh
# gerado pelo freebsd-bspwm-aurtty
export LANG=${LANG:-pt_BR.UTF-8}
export XDG_CURRENT_DESKTOP=bspwm
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
  for p in lightdm lightdm-gtk-greeter; do
    pkg install -q "$p" </dev/null >>"$LOG" 2>&1 || FALHARAM="$FALHARAM $p"
  done

  # sessão própria: o mesmo que o .xinitrc (dbus + bspwm)
  cat > /usr/local/bin/aurtty-session <<'EOF'
#!/bin/sh
# freebsd-bspwm-aurtty: sessão bspwm aberta pela tela de login
export LANG=${LANG:-pt_BR.UTF-8}
export XDG_CURRENT_DESKTOP=bspwm
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
  sysrc -q lightdm_enable=YES >/dev/null
  info "LightDM ativado (abre sozinho no boot)"
else
  sysrc -q lightdm_enable=NO >/dev/null 2>&1 || true
fi

# ---------- terminal ----------
if [ $TERMINAL -eq 1 ]; then
  titulo "Terminal: bash + oh-my-bash (powerline) + ble.sh + fzf-tab"
  baixar_verificado "$OMB_URL" "$OMB_SHA" "$TMP/omb.tar.gz"
  baixar_verificado "$BLE_URL" "$BLE_SHA" "$TMP/ble.tar.xz"
  baixar_verificado "$FZFTAB_URL" "$FZFTAB_SHA" "$TMP/fzftab.tar.gz"
  rm -rf "$CASA/.oh-my-bash" "$CASA/.local/share/blesh" "$CASA/.local/share/fzf-tab-completion"
  mkdir -p "$CASA/.oh-my-bash" "$CASA/.local/share/blesh" "$CASA/.local/share/fzf-tab-completion" "$CASA/.local/bin"
  tar -xf "$TMP/omb.tar.gz" -C "$CASA/.oh-my-bash" --strip-components 1
  tar -xf "$TMP/ble.tar.xz" -C "$CASA/.local/share/blesh" --strip-components 1
  tar -xf "$TMP/fzftab.tar.gz" -C "$CASA/.local/share/fzf-tab-completion" --strip-components 1
  install -m 755 "$RAIZ/extras/bash/fzf-tab-preview" "$CASA/.local/bin/fzf-tab-preview"
  if [ -e "$CASA/.bashrc" ] && ! grep -q 'freebsd-bspwm-aurtty' "$CASA/.bashrc"; then
    mkdir -p "$BACKUP"; mv "$CASA/.bashrc" "$BACKUP/"
  fi
  cp "$RAIZ/extras/bash/bashrc" "$CASA/.bashrc"
  # o bash de login lê o .bash_profile: repassa para o .profile (startx) e o .bashrc
  cat > "$CASA/.bash_profile" <<'EOF2'
# gerado pelo freebsd-bspwm-aurtty
[ -f ~/.bashrc ] && . ~/.bashrc
[ -f ~/.profile ] && . ~/.profile
EOF2
  pw usermod "$USUARIO" -s /usr/local/bin/bash
  chown -R "$USUARIO:$GRUPO" "$CASA/.oh-my-bash" "$CASA/.local" "$CASA/.bashrc" "$CASA/.bash_profile"
  info "shell padrão de $USUARIO: /usr/local/bin/bash"
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
titulo "Pronto"
[ -n "$FALHARAM" ] && cor '1;33' "    pacotes que falharam (veja $LOG):$FALHARAM"
if [ "$VIDEO" = 3 ] || [ "$VIDEO" = 4 ]; then
  info "o driver de vídeo é carregado no boot: reinicie com 'reboot'"
fi
if [ "$LOGIN" = 1 ]; then
  info "reinicie com 'reboot' e a tela de login abre sozinha"
elif [ $AUTOX -eq 1 ]; then
  info "entre como '$USUARIO' no ttyv0 e o bspwm abre sozinho"
else
  info "entre como '$USUARIO' e rode: startx"
fi
info "atalhos: super+Return (terminal), super+@space (menu), alt+F1 (ajuda)"
