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
sed -i 's/^modules-right = .*/modules-right = mpd sep bi network bd sep bi pulseaudio bd sep bi date bd sep tray sep power/' \
  "$B/bars/bar07/config.ini"

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

# Launcher da barra: logo do ArchBSD (fonte própria AurTTY Icons, U+E000) em vermelho
# área de trabalho ativa: logo do FreeBSD (glifo nf-linux-freebsd U+F30C da JetBrainsMono Nerd Font) no lugar do pacman
sed -i 's/^font-4 = .*/&\nfont-5 = "AurTTY Icons:size=15;4"\nfont-6 = "JetBrainsMono Nerd Font Propo:size=11;3"/' "$B/bars/bar07/config.ini"
awk '
  /^\[module\// { sec = $0 }
  sec == "[module/launcher]" && /^label = / { print "label = \xee\x80\x80"; next }
  sec == "[module/launcher]" && /^label-font = / { print "label-font = 6"; next }
  sec == "[module/bspwm]" && /^label-focused = / { print "label-focused = \xef\x8c\x8c"; print "label-focused-font = 7"; next }
  sec == "[module/bspwm]" && /^label-focused-foreground = / { print "label-focused-foreground = ${color.blue-arch}"; next }
  { print }
' "$B/bars/bar07/modules.ini" > "$B/bars/bar07/modules.ini.new" && mv "$B/bars/bar07/modules.ini.new" "$B/bars/bar07/modules.ini"
sed -i 's/^arch_icon=.*/arch_icon="#e8303a"   # logo ArchBSD/' "$B/rices/emilia/theme-config.bash"
# terminal levemente transparente (o Theme.sh aplica no alacritty.toml)
sed -i 's/^P_TERM_OPACITY=.*/P_TERM_OPACITY="0.8"\t# Terminal transparency. Range: 0.1 - 1.0 (1.0 = disabled)/' "$B/rices/emilia/theme-config.bash"

# Wallpapers próprios (tools/gerar-wallpapers.py) no Emilia; o FreeBSD dark vira o padrão
cp "$RAIZ"/extras/walls/*.webp "$B/rices/emilia/walls/"
sed -i 's|^DEFAULT_WALL=.*|DEFAULT_WALL="$HOME/.config/bspwm/rices/emilia/walls/aurtty-freebsd-dark.webp"|' "$B/rices/emilia/theme-config.bash"


# Dock embaixo com os ícones reais (Plank, sem fundo): sobe junto com a bar07.
# O aurtty-dock (extras/dock, instalado em /usr/local/bin) respeita se o usuário escondeu.
cat >> "$B/bars/bar07/Bar.bash" <<'EOF'
# freebsd-bspwm-aurtty: dock embaixo (super+d mostra/esconde)
command -v aurtty-dock >/dev/null && aurtty-dock iniciar
EOF
cat >> "$B/config/sxhkdrc" <<'EOF'

# Dock: mostra/esconde (freebsd-bspwm-aurtty)
super + d
	aurtty-dock alternar
EOF

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
