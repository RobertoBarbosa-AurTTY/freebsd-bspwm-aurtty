# freebsd-bspwm-aurtty

Pós-instalação do **FreeBSD** que monta um ambiente **bspwm** com a aparência do tema
**Emilia** (Tokyo Night) dos [dotfiles do gh0stzk](https://github.com/gh0stzk/dotfiles).

Você instala um FreeBSD limpo, clona este repositório, roda um script, responde
4 perguntas e entra direto no bspwm.

## Capturas

Tiradas numa VM (QEMU, 1920x1080, sem aceleração de vídeo) logo depois de rodar o instalador.

**Tela de login** (LightDM com o tema `AurTTY-Login`)
![Tela de login](docs/screenshots/login.png)

**Área de trabalho** (polybar `bar07`, wallpaper FreeBSD dark)
![Área de trabalho](docs/screenshots/desktop.png)

**Menu de aplicativos** (`super+espaço`)
![Menu do rofi](docs/screenshots/menu.png)

**Terminal** (alacritty + bash com oh-my-bash powerline, fastfetch e eza)
![Terminal](docs/screenshots/terminal.png)

**Desenvolvimento** (VS Code oficial via emulação Linux e as ferramentas de backend)
![VS Code e ferramentas](docs/screenshots/apps.png)

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
| Ferramentas de desenvolvimento backend | sim |
| Google Chrome e VS Code oficiais (Debian na emulação Linux, ~1,5 GB) | sim |
| opencode (agente de código no terminal; só aparece se o Chrome/VS Code for instalado) | sim |
| IA local: modelo Qwen3 (0 = não instalar; 1.7B, 4B, 8B ou 14B) | sugerido pela RAM |

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
- **Desenvolvimento backend (opcional):** neovim, lazygit, ripgrep, fd, tmux, gh, mise
  (versões de linguagem por projeto, já ativado no `.bashrc`), uv, yq, xh, httpie, python3,
  node22 + npm, deno, sqlite3, clientes de PostgreSQL (`psql`, `pgcli`), MariaDB/MySQL e
  Valkey (`valkey-cli`, compatível com Redis), shellcheck e pre-commit. Docker não existe no
  FreeBSD: para containers use jails ou `podman-suite`.
- **Chrome e VS Code (opcional):** um Debian 13 (trixie) é instalado com `debootstrap` em
  `/compat/linux`, a pasta onde a emulação Linux do FreeBSD procura bibliotecas. O Chrome
  (`google-chrome-stable`) e o VS Code (`code`) vêm dos repositórios oficiais do Google e da
  Microsoft e rodam direto pelo usuário, sem chroot, pelos lançadores `google-chrome` e `code`
  (`--no-sandbox`, porque a emulação não tem namespaces do Linux). `/tmp` e `/home` são montados
  por nullfs (veja o `/etc/fstab`); o DNS é o do FreeBSD. O `super+b` passa a abrir o Chrome.
  Atualizar: `chroot /compat/linux apt update && chroot /compat/linux apt upgrade` (copie antes o
  `/etc/resolv.conf` para `/compat/linux/etc/` e apague depois). Não instale `linux_base-*`, ele
  usa a mesma pasta.
- **opencode (opcional):** o agente de código no terminal. Não há versão para FreeBSD, então o
  instalador baixa o binário Linux oficial (`opencode-linux-x64`, versão mais recente do npm, com
  o sha512 conferido) e ele roda pela emulação Linux, junto do Debian da opção do Chrome/VS Code.
  Os modelos gratuitos do opencode funcionam direto (`/models`); com a IA local instalada, o
  provedor `local` também aparece. Os comandos que ele executa usam primeiro as ferramentas do
  Debian em `/compat/linux` e, se não existirem lá, as do FreeBSD. Autoatualização desligada:
  para atualizar, rode o instalador de novo.
- **IA local (opcional):** llama.cpp (`llama-server`) como serviço em `127.0.0.1:8080`, com um
  modelo **Qwen3** oficial em GGUF (sha256 fixado). O instalador sugere o tamanho pela RAM
  (até 6 GB: 1.7B · 8 GB: 4B · 16 GB ou mais: 8B; o 14B é para 32 GB ou GPU de 12 GB). Funciona
  offline, usa a GPU via Vulkan quando há driver (Intel/AMD com drm-kmod ou NVIDIA) e cai para
  o processador sem ela: o `--fit` do llama.cpp ajusta camadas e contexto à memória sozinho.
  Uso: `aichat "pergunta"` no terminal, o chat em `http://127.0.0.1:8080` no navegador, ou
  qualquer extensão do VS Code compatível com a API da OpenAI (`http://127.0.0.1:8080/v1`,
  modelo `local`). Trocar de modelo: baixe outro `.gguf` para `/usr/local/share/llama/models`,
  rode `sysrc llama_server_model=<arquivo>` e `service llama-server restart`.
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
