# This file launch the bar/s
for mon in $(polybar --list-monitors | cut -d":" -f1); do
	MONITOR=$mon polybar -q emi-bar -c "$HOME/.config/bspwm/bars/${main_bar}/config.ini" &
done
# freebsd-bspwm-aurtty: dock embaixo, só no monitor principal
[ -f "$HOME/.config/bspwm/bars/dock.ini" ] && \
	MONITOR=$(polybar --list-monitors | grep primary | cut -d":" -f1) polybar -q aurtty-dock -c "$HOME/.config/bspwm/bars/dock.ini" &
