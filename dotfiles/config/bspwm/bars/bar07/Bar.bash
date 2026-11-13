# This file launch the bar/s
for mon in $(polybar --list-monitors | cut -d":" -f1); do
	MONITOR=$mon polybar -q emi-bar -c "$HOME/.config/bspwm/bars/${main_bar}/config.ini" &
done
# freebsd-bspwm-aurtty: dock embaixo (super+d mostra/esconde)
command -v aurtty-dock >/dev/null && aurtty-dock iniciar
