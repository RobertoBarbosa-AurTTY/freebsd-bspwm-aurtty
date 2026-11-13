# freebsd-bspwm-aurtty: saudação ao abrir o terminal
# Sorteia uma figura do universo a cada terminal novo, desenhada em blocos coloridos:
#   blackhole -> buraco negro TON 618 · pilares -> Pilares da Criação (M16) · andromeda -> M31
#   caranguejo -> Nebulosa do Caranguejo e o pulsar · etacarinae -> Homúnculo · vycma -> VY Canis Majoris
#   jupiter -> Júpiter e as luas de Galileu · marte -> Marte e Fobos · saturno -> Saturno e os anéis
#   diamante -> 55 Cancri e, o "planeta de diamante"
# Todas são procedurais (render.py de cada pasta). As estrelas piscam até o 1º comando.
# Ao lado, as informações do sistema (fastfetch), no estilo do neofetch.
# Fixar uma: FIGURA_FIXA=<pasta>. Desligar: FIGURA=0 (tudo) ou FIGURA_INFO=0 (só as informações) no ~/.bashrc,
# antes da linha que carrega este arquivo.
[[ -n ${NVIM-} || ${FIGURA-1} == 0 ]] && return

_UNIVERSO=~/.local/share/universo

# --- figura animada: as estrelas piscam só até o 1º comando, depois a figura congela ---
_figura_start() {
    [[ -n ${_FIG_DIR-} ]] || return
    command -v python3 >/dev/null || return
    _figura_stop
    local tty; tty=$(tty) || return
    python3 "$_UNIVERSO/figura_anim.py" "$$" "$tty" "$_FIG_DIR" 2 </dev/null >/dev/null 2>&1 &
    _FIG_PID=$!
    disown "$_FIG_PID" 2>/dev/null
}
# para o animador ANTES do comando escrever na tela e devolve a rolagem para a tela inteira
_figura_stop() {
    [[ -n ${_FIG_PID-} ]] || return 0
    kill "$_FIG_PID" 2>/dev/null
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$_FIG_PID" 2>/dev/null || break; sleep 0.02; done
    _FIG_PID=
    printf '\e7\e[r\e8'
}
if declare -F blehook >/dev/null; then
    blehook PREEXEC-=_figura_stop 2>/dev/null
    blehook PREEXEC+=_figura_stop
    # Ctrl+L é atalho (não comando): o PREEXEC não dispara, então para o animador aqui também
    function ble/widget/figura-clear-screen { _figura_stop; ble/widget/clear-screen; }
    blehook/eval-after-load keymap_emacs 'ble-bind -m emacs -f C-l figura-clear-screen'
    blehook/eval-after-load keymap_vi 'ble-bind -m vi_imap -f C-l figura-clear-screen; ble-bind -m vi_nmap -f C-l figura-clear-screen'
fi
figura() {
    case $1 in
        off) _figura_stop ;;
        on)  if [[ -n ${_FIG_DIR-} ]]; then printf '\e[H\e[2J'; printf '\e[%d;1H' "$_FIG_RES"; _figura_start
             else echo "esta figura não é animada (abra um terminal novo)"; fi ;;
        *)   echo "uso: figura on|off  (pisca até o próximo comando)" ;;
    esac
}

# figura com as informações à direita, centralizadas na altura (array "info" do chamador).
# Cada linha da figura tem 58 colunas (2 de recuo + 56 de imagem).
_fig_com_info() {
    local -a fl; mapfile -t -n 16 fl < "$1"
    local t=${#info[@]} i j linha right
    local off=$(( (16 - t) / 2 )); (( off < 0 )) && off=0
    for (( i = 0; i < 16; i++ )); do
        linha=${fl[i]-}
        [[ -z $linha ]] && printf -v linha '%58s' ''
        j=$((i - off)) right=
        (( j >= 0 && j < t )) && right="    ${info[j]}"
        printf '%s\e[0m%s\e[0m\n' "$linha" "$right"
    done
}

_universo_greeting() {
    _figura_stop; unset _FIG_DIR _FIG_RES
    # pasta|título|cor do título (R;G;B)|animada (1/0)
    local figuras=(
        "blackhole|TON 618|255;190;60|0"
        "pilares|PILARES DA CRIAÇÃO|110;205;215|1"
        "andromeda|ANDRÔMEDA (M31)|170;185;255|1"
        "caranguejo|NEBULOSA DO CARANGUEJO (M1) · PULSAR|255;140;90|1"
        "etacarinae|ETA CARINAE · HOMÚNCULO|240;170;120|1"
        "vycma|VY CANIS MAJORIS|255;95;60|1"
        "jupiter|JÚPITER E AS LUAS DE GALILEU|230;190;140|1"
        "marte|MARTE E FOBOS|230;110;70|1"
        "saturno|SATURNO E OS ANÉIS|235;210;150|1"
        "diamante|55 CANCRI E · PLANETA DE DIAMANTE|170;215;255|1"
    )
    local fig=${figuras[RANDOM % ${#figuras[@]}]} f
    # FIGURA_FIXA=caranguejo (nome da pasta) mostra sempre a mesma
    for f in "${figuras[@]}"; do [[ ${f%%|*} == "${FIGURA_FIXA-}" ]] && fig=$f; done
    local nome titulo cor anim
    IFS='|' read -r nome titulo cor anim <<< "$fig"
    local dir=$_UNIVERSO/$nome/frames
    local frames=("$dir"/*.ansi)
    local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
    local lines=${LINES:-$(tput lines 2>/dev/null || echo 24)}
    local n=16   # altura das figuras (56 colunas de imagem + 2 de recuo)

    # informações do sistema (fastfetch): ao lado se couber, senão embaixo do título
    local -a info=() info_baixo=()
    if [[ ${FIGURA_INFO-1} != 0 ]] && command -v fastfetch >/dev/null; then
        mapfile -t info < <(fastfetch --logo none --pipe false \
            -s Title:Separator:Kernel:Uptime:Packages:Shell:WM:Terminal:CPU:Memory:Disk:Break:Colors 2>/dev/null)
        while (( ${#info[@]} )) && [[ -z ${info[-1]//[[:space:]]/} ]]; do unset 'info[-1]'; done
        local l plain larg=0 _ext; _ext=$(shopt -p extglob); shopt -s extglob
        for l in "${info[@]}"; do
            plain=${l//$'\e'\[*([0-9;?])[a-zA-Z]/}
            (( ${#plain} > larg )) && larg=${#plain}
        done
        eval "$_ext"
        if (( cols < 58 + 4 + larg )); then info_baixo=("${info[@]}"); info=(); fi
    fi

    if [[ -r ${frames[0]} ]] && (( cols >= 58 )); then
        if [[ -t 1 ]] && (( anim )) && (( cols >= 60 && lines >= n + 10 )); then
            # figura fixa no topo (linhas 2..n+1), estrelas piscando em segundo plano
            printf '\e[H\e[2J\n'; _fig_com_info "${frames[0]}"
            _FIG_DIR=$dir _FIG_RES=$((n + 2))
            _figura_start
        else
            printf '\n'; _fig_com_info "${frames[-1]}"
        fi
    else
        info_baixo+=("${info[@]}")   # terminal estreito demais para a figura: só as informações
    fi

    local dias=(domingo segunda-feira terça-feira quarta-feira quinta-feira sexta-feira sábado)
    local meses=(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)
    local dw d m hm
    read -r dw d m hm < <(date '+%w %e %m %H:%M')
    printf '\n  \e[1;38;2;%sm%s\e[0m\e[38;5;245m  ·  %s, %s de %s · %s\e[0m\n\n' \
        "$cor" "$titulo" "${dias[dw]}" "${d// /}" "${meses[10#$m-1]}" "$hm"
    (( ${#info_baixo[@]} )) && printf '  %s\e[0m\n' "${info_baixo[@]}" && printf '\n'
}
_universo_greeting
unset -f _universo_greeting _fig_com_info
