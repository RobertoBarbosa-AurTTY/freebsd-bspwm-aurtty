#!/usr/bin/env bash
# Monta a pasta dotfiles/ a partir dos dotfiles do gh0stzk (GPL-3.0),
# apenas com o tema Emilia, já adaptada para FreeBSD.
# Uso (na máquina do mantenedor): tools/sincronizar-upstream.sh [commit]
set -euo pipefail

UPSTREAM=https://github.com/gh0stzk/dotfiles
COMMIT=${1:-793f584892f1041c7703be6a48faa018502dc27a}

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
DEST="$RAIZ/dotfiles"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo ">> baixando $UPSTREAM @ $COMMIT"
git -C "$TMP" init -q
git -C "$TMP" remote add origin "$UPSTREAM"
git -C "$TMP" fetch -q --depth 1 origin "$COMMIT"
git -C "$TMP" checkout -q FETCH_HEAD
U="$TMP"

rm -rf "$DEST"
mkdir -p "$DEST/config" "$DEST/home" "$DEST/fonts"

# --- bspwm: só Emilia, só a bar07, sem eww e sem wallpapers animados ---
cp -a "$U/config/bspwm" "$DEST/config/bspwm"
B="$DEST/config/bspwm"
rm -rf "$B/eww"
find "$B/rices" -mindepth 1 -maxdepth 1 ! -name emilia -exec rm -rf {} +
find "$B/bars" -mindepth 1 -maxdepth 1 ! -name bar07 -exec rm -rf {} +
rm -f "$B"/config/assets/*.mp4
rm -f "$B"/rices/emilia/preview.webp "$B"/bars/bar07/preview-bar.webp

# Módulos do Theme.sh para programas que não instalamos
for m in 05-kitty 05-ghostty 05-st 06-eww 06-firefox 07-geany 07-nvim 08-mpv 09-zathura; do
  rm -f "$B/config/modules/$m.sh"
done
rm -f "$B"/config/modules/*.disabled

echo emilia > "$B/.rice"
echo alacritty > "$B/config/.term"

# bspwmrc: shims GNU/Linux no PATH, sem eww/lxpolkit, com pulseaudio
awk '
  /^export PATH=/ { print "export PATH=\"$HOME/.config/bspwm/freebsd-bin:$HOME/.config/bspwm/bin:$PATH\""; next }
  /eww/ || /lxpolkit/ { next }
  # pulseaudio antes da barra: senão o módulo de volume da polybar sobe vazio
  /^# Load current theme/ { print "# Start pulseaudio (before polybar, for the volume module)"; print "pulseaudio --check 2>/dev/null || pulseaudio --start --exit-idle-time=-1"; print ""; print; next }
  { print }
' "$B/bspwmrc" > "$B/bspwmrc.new" && mv "$B/bspwmrc.new" "$B/bspwmrc"
chmod +x "$B/bspwmrc"

# bar07: tira módulos sem suporte no FreeBSD (bateria/bluetooth via sysfs, updates do pacman, player do eww)
# e os de música (mpd/mpd_control): o mpd não é instalado e a barra mostrava "No Music" o tempo todo
sed -i 's/^modules-right = .*/modules-right = bi network bd sep bi pulseaudio bd sep bi date bd sep tray sep power/' \
  "$B/bars/bar07/config.ini"
sed -i 's/^\(modules-left = .*\)bi mpd_control bd sep /\1/' "$B/bars/bar07/config.ini"
grep -q mpd_control "$B/bars/bar07/config.ini" && { echo "bar07: mpd_control continua na barra" >&2; exit 1; }

# bar07: internal/fs e internal/network não funcionam no FreeBSD -> custom/script
# (mantém os ícones e cores originais, só troca a fonte dos dados)
awk '
  /^\[module\// { sec = $0 }
  sec == "[module/filesystem]" {
    if ($0 ~ /^type =/)              { print "type = custom/script"; print "exec = FsUsage /"; next }
    if ($0 ~ /^(mount-0|fixed-values|format-unmounted|label-unmounted)/) next
    sub(/^format-mounted/, "format"); sub(/<label-mounted>/, "<label>"); sub(/^label-mounted =.*/, "label = %output%"); sub(/^label-mounted/, "label")
  }
  sec == "[module/network]" {
    if ($0 ~ /^type =/)              { print "type = custom/script"; print "exec = NetStatus"; next }
    if ($0 ~ /^(interface|accumulate-stats|unknown-as-up|speed-unit|format-disconnected|label-disconnected)/) next
    if ($0 ~ /^interval/)            { print "interval = 3"; next }
    sub(/^format-connected/, "format"); sub(/<label-connected>/, "<label>"); sub(/%netspeed%/, "%output%"); sub(/^label-connected/, "label")
  }
  { print }
' "$B/bars/bar07/modules.ini" > "$B/bars/bar07/modules.ini.new" && mv "$B/bars/bar07/modules.ini.new" "$B/bars/bar07/modules.ini"

# relógio em 24h; clique abre o calendário (gsimplecal, abre na posição do mouse)
awk '
  /^\[module\// { sec = $0 }
  sec == "[module/date]" && /^time = / { print "time = %H:%M"; next }
  sec == "[module/date]" && /^date-alt = / { next }
  sec == "[module/date]" && /^format = / { print "format = %{A1:gsimplecal:}<label>%{A}"; next }
  { print }
' "$B/bars/bar07/modules.ini" > "$B/bars/bar07/modules.ini.new" && mv "$B/bars/bar07/modules.ini.new" "$B/bars/bar07/modules.ini"

# calendário do relógio flutuando (senão o bspwm o coloca lado a lado com as janelas)
awk '
  /^    pavucontrol\)/ { print "    Gsimplecal)"; print "        result \"state=floating sticky=on\""; print "        ;;" }
  { print }
' "$B/bin/ExternalRules" > "$B/bin/ExternalRules.new" && mv "$B/bin/ExternalRules.new" "$B/bin/ExternalRules"
chmod +x "$B/bin/ExternalRules"
grep -q Gsimplecal "$B/bin/ExternalRules" || { echo "ExternalRules: regra do calendário não aplicada" >&2; exit 1; }

# Launcher da barra: buraco negro (fonte própria AurTTY Icons, U+E000) em vermelho
# áreas de trabalho com ícone por função, seguindo o ExternalRules do tema
# (1 terminal, 2 arquivos/Thunar, 3 web/Firefox, 4 chat/Telegram, 5 código, 6 música);
# a ativa fica destacada na cor do tema, as ocupadas em azul e as vazias apagadas
sed -i 's/^font-4 = .*/&\nfont-5 = "AurTTY Icons:size=18;5"\nfont-6 = "JetBrainsMono Nerd Font Propo:size=11;3"/' "$B/bars/bar07/config.ini"
awk '
  /^\[module\// { sec = $0 }
  sec == "[module/launcher]" && /^label = / { print "label = \xee\x80\x80"; next }
  sec == "[module/launcher]" && /^label-font = / { print "label-font = 6"; next }
  sec == "[module/bspwm]" && /^occupied-scroll = / {
    print
    print "ws-icon-0 = 1;\xf3\xb0\x86\x8d"
    print "ws-icon-1 = 2;\xf3\xb0\x89\x8b"
    print "ws-icon-2 = 3;\xf3\xb0\x88\xb9"
    print "ws-icon-3 = 4;\xf3\xb0\x8d\xa9"
    print "ws-icon-4 = 5;\xf3\xb0\x85\xa9"
    print "ws-icon-5 = 6;\xf3\xb0\x9d\x9a"
    print "ws-icon-default = \xf3\xb0\x8a\xa0"
    next
  }
  sec == "[module/bspwm]" && /^label-(focused|occupied|urgent|empty) = / { sub(/=.*/, "= %icon%"); print; split($1, k, "-"); print "label-" k[2] "-font = 7"; next }
  sec == "[module/bspwm]" && /^label-focused-foreground = / { print "label-focused-foreground = ${color.blue-arch}"; next }
  sec == "[module/bspwm]" && /^label-empty-foreground = / { print "label-empty-foreground = ${color.black-bright}"; next }
  { print }
' "$B/bars/bar07/modules.ini" > "$B/bars/bar07/modules.ini.new" && mv "$B/bars/bar07/modules.ini.new" "$B/bars/bar07/modules.ini"
sed -i 's/^arch_icon=.*/arch_icon="#e8303a"   # ícone AurTTY (buraco negro)/' "$B/rices/emilia/theme-config.bash"
# terminal levemente transparente (o Theme.sh aplica no alacritty.toml)
sed -i 's/^P_TERM_OPACITY=.*/P_TERM_OPACITY="0.8"\t# Terminal transparency. Range: 0.1 - 1.0 (1.0 = disabled)/' "$B/rices/emilia/theme-config.bash"

# Wallpapers próprios (tools/gerar-wallpapers.py) no Emilia; o FreeBSD dark vira o padrão
cp "$RAIZ"/extras/walls/*.webp "$B/rices/emilia/walls/"
sed -i 's|^DEFAULT_WALL=.*|DEFAULT_WALL="$HOME/.config/bspwm/rices/emilia/walls/aurtty-freebsd-dark.webp"|' "$B/rices/emilia/theme-config.bash"

# Paleta opcional de fogo para a barra (desligada: a barra usa as cores do Emilia).
# Para ativar: em bars/bar07/config.ini troque "include-file = ../colors.ini" por "include-file = fogo.ini"
cp "$RAIZ/extras/polybar/fogo.ini" "$B/bars/bar07/fogo.ini"

# Theme.sh: espera o polybar fechar no máximo 3s e depois força (no FreeBSD o
# polybar-msg às vezes não acha o canal IPC e o reload travava para sempre)
awk '
  /^wait_for_termination\(\) \{/ { inwait = 1 }
  inwait && /while pgrep -f "\$process_name"/ {
    print "    local n=0"
    print "    while pgrep -f \"$process_name\" >/dev/null; do"
    print "        n=$((n + 1))"
    print "        [ \"$n\" -ge 10 ] && { pkill -9 -f \"$process_name\"; break; }"
    getline; print; next
  }
  inwait && /^}/ { inwait = 0 }
  { print }
' "$B/bin/Theme.sh" > "$B/bin/Theme.sh.new" && mv "$B/bin/Theme.sh.new" "$B/bin/Theme.sh"
chmod +x "$B/bin/Theme.sh"

# PowerMenu: um clique executa a opção (no rofi o padrão é clique duplo, e o
# clique simples só selecionava: "clica e nada acontece")
sed -i 's|^\trofi -dmenu \\$|\trofi -dmenu -me-select-entry "" -me-accept-entry MousePrimary \\|' "$B/bin/PowerMenu"
grep -q 'me-accept-entry MousePrimary' "$B/bin/PowerMenu" || { echo "PowerMenu: regra do clique não aplicada" >&2; exit 1; }

# --- outros programas ---
for d in alacritty dunst jgmenu clipcat gtk-3.0; do
  cp -a "$U/config/$d" "$DEST/config/$d"
done
sed -i 's/^opacity = .*/opacity = 0.8/' "$DEST/config/alacritty/alacritty.toml"
cp -a "$U/home/.gtkrc-2.0" "$U/home/.icons" "$DEST/home/"

# --- fontes usadas pela barra ---
for f in FontAwesome6-Free-Solid.otf MaterialDesignIconsDesktop.ttf MesloLGS_NF_Regular.ttf; do
  cp "$U/misc/fonts/$f" "$DEST/fonts/"
done

# --- shims FreeBSD (nossos, não vêm do upstream) ---
cp -a "$RAIZ/freebsd-bin" "$B/freebsd-bin"
cp "$RAIZ"/extras/fonts/* "$DEST/fonts/"

cp "$U/LICENSE" "$RAIZ/LICENSE"
printf '%s\n%s\n' "$UPSTREAM" "$COMMIT" > "$RAIZ/UPSTREAM"
echo ">> pronto: $(du -sh "$DEST" | cut -f1) em dotfiles/"
