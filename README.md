# freebsd-bspwm-aurtty

**Pós-instalação do FreeBSD com bspwm Tokyo Night para desenvolvimento, redes e segurança da informação.**

![Licença: GPL-3.0](https://img.shields.io/badge/licen%C3%A7a-GPL--3.0-blue.svg)
![FreeBSD 14 | 15](https://img.shields.io/badge/FreeBSD-14%20%7C%2015-AB2B28?logo=freebsd&logoColor=white)
![Shell: POSIX sh](https://img.shields.io/badge/shell-POSIX%20sh-4EAA25.svg)
![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

> Projeto **open source** (GPL-3.0) mantido pela AurTTY. O `install.sh` transforma um
> FreeBSD 14/15 limpo em um ambiente gráfico completo, com ferramentas de
> desenvolvimento, redes e bancos de dados — um laboratório reproduzível para
> estudantes e uma estação de trabalho pronta para profissionais.

## Sumário

- [Sobre o projeto](#sobre-o-projeto)
- [Público-alvo](#público-alvo)
- [Ficha técnica](#ficha-técnica)
- [Capturas](#capturas)
- [Arquitetura](#arquitetura)
- [Pipeline de instalação](#pipeline-de-instalação)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Componentes](#componentes)
- [devdb: bancos em jails](#devdb-bancos-em-jails)
- [Atualizações com rollback](#atualizações-com-rollback)
- [Integridade e reprodutibilidade](#integridade-e-reprodutibilidade)
- [Atalhos](#atalhos)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Solução de problemas](#solução-de-problemas)
- [Manutenção e contribuição](#manutenção-e-contribuição)
- [Diferenças em relação ao original (Arch)](#diferenças-em-relação-ao-original-arch)
- [Créditos e licença](#créditos-e-licença)

## Sobre o projeto

Este é um projeto **open source** (licença GPL-3.0), mantido pela AurTTY, cujo
objetivo é montar um ambiente FreeBSD completo para **desenvolvimento, redes de
computadores e segurança da informação**. O instalador é um script POSIX `sh`
que automatiza a pós-instalação: Xorg, bspwm com visual Tokyo Night, terminal
configurado, navegador, gerenciador de arquivos, editor (AstroNvim), ferramentas
de backend e bancos de dados locais.

O diferencial é a **reprodutibilidade**: pacotes com versões fixadas, downloads
externos verificados por SHA-256, log de instalação, backup das configurações
existentes e atualização com *rollback* via boot environments do ZFS. Você
instala um FreeBSD limpo, clona o repositório, roda um script, responde algumas
perguntas e entra direto no bspwm — sem montar o desktop peça por peça.

O código é aberto: use, estude, modifique e compartilhe à vontade. Se encontrar
um problema ou tiver uma ideia, abra uma issue ou envie um pull request.

## Público-alvo

O projeto foi pensado para dois usos principais:

- **Uso acadêmico** — estudantes de **Redes de Computadores** e de **Segurança da
  Informação** que querem um laboratório local em FreeBSD para estudar sistemas
  operacionais, shell, protocolos, bancos de dados, isolamento por jails e
  administração de serviços. O `devdb` sobe PostgreSQL, MariaDB, Valkey e MongoDB
  em jails isoladas, sem depender de Docker (que não existe no FreeBSD).
- **Uso profissional** — administradores e analistas que gerenciam redes de
  computadores e precisam de uma estação de trabalho FreeBSD pronta para usar,
  com clientes de banco, clientes HTTP, tmux, versionamento, editores e
  ferramentas de diagnóstico de rede (`route`, `netstat`, `sockstat`, `xh`,
  `httpie`) já instalados.

Também serve para **entusiastas do FreeBSD** que querem um desktop moderno sem
repetir a configuração manual a cada instalação.

> Escopo: o script prepara uma **estação de trabalho de estudo/desenvolvimento**.
> Ele não é um appliance de segurança endurecido e não substitui firewall,
> segmentação de rede ou ferramentas de produção. Bancos do `devdb` usam
> credenciais de desenvolvimento e devem ficar restritos à máquina local.

## Ficha técnica

| Item | Valor |
|---|---|
| Base | FreeBSD 14.x ou 15.x (amd64), recém-instalado |
| Gerenciador de janelas | bspwm + sxhkd |
| Barra / compositor | polybar (`bar07`) + picom |
| Launcher / menu | rofi, jgmenu |
| Notificações / clipboard | dunst, clipcat |
| Terminal / shell | alacritty; bash + oh-my-bash + ble.sh |
| Editor | Neovim + AstroNvim |
| Login gráfico | LightDM + tema `AurTTY-Login` |
| Bancos locais | PostgreSQL 17, MariaDB 11.4, Valkey, MongoDB 7 (jails) |
| Instalador | um único `install.sh` POSIX `sh` |
| Licença | GPL-3.0 |

**Estado:** capturas feitas em VM QEMU (1920x1080, sem aceleração de vídeo). O
projeto não possui suíte de testes automatizada; a verificação é feita pelo log
do instalador, pela checagem de checksums e pelo teste manual em VM.

## Capturas

**Instalador** (`bsddialog` no console: escolha do vídeo, resumo, progresso por etapa e tela final)
![Instalador](docs/screenshots/installer-v4.png)

**Tela de login** (LightDM com o tema `AurTTY-Login`)
![Tela de login](docs/screenshots/login-v2.png)

**Área de trabalho** (polybar `bar07` em cima)
![Área de trabalho](docs/screenshots/desktop-v4.png)

**Menu de aplicativos** (`super+espaço`)
![Menu do rofi](docs/screenshots/menu-v4.png)

**Terminal** (saudação do universo sorteada a cada terminal, com as informações do sistema ao lado)
![Terminal](docs/screenshots/terminal-v4.png)

## Arquitetura

```
FreeBSD 14/15 (ZFS ou UFS)
│
├── Xorg + driver de vídeo (vesa | scfb | drm-kmod | nvidia)
│   └── LightDM (tema AurTTY-Login)  ou  ttyv0 autostart  ou  startx
│       └── bspwm (tema Emilia / Tokyo Night)
│           ├── sxhkd            atalhos de teclado
│           ├── polybar bar07    barra superior
│           ├── picom            composição de janelas
│           ├── rofi / jgmenu    launcher e menu de aplicativos
│           ├── dunst / clipcat  notificações e histórico de clipboard
│           ├── alacritty        bash + oh-my-bash + ble.sh + fzf-tab
│           └── aplicativos      Firefox, PCManFM, AstroNvim
│
└── Bastille (jails "thin")
    └── devdb-<banco>            PostgreSQL | MariaDB | Valkey | MongoDB
```

O desktop segue o tema **Emilia** dos dotfiles do gh0stzk, adaptado para
FreeBSD. As peças que o upstream espera do Linux (coreutils GNU, `iproute2`,
`/sys`, `pacman`) são substituídas por *shims* próprios em `freebsd-bin/`.

## Pipeline de instalação

O `install.sh` roda com `set -eu` e executa as etapas na seguinte ordem:

| # | Etapa | O que acontece |
|---|---|---|
| 1 | Pré-checagem | Confirma FreeBSD, execução como root e presença de `dotfiles/` |
| 2 | Entrevista | Usuário, senha (se novo), layout de teclado, driver de vídeo, modo de login, terminal e ferramentas de dev |
| 3 | Pacotes | `pkg bootstrap` + `pkg update`, instala base, driver de vídeo e pacotes de desenvolvimento; registra falhas por pacote |
| 4 | Sistema | Ativa dbus, carrega módulo de vídeo via `kld_list`, gera `xorg.conf.d` (teclado e driver) |
| 5 | Usuário | Cria o usuário com `pw` ou adiciona aos grupos `wheel` e `video` |
| 6 | Aparência | Baixa temas GTK, ícones e cursor (SHA-256), instala fontes Nerd Font e pacotes do tema |
| 7 | Dotfiles | Copia `dotfiles/` para `~/.config`; configurações antigas vão para `~/.config-backup-<data>` |
| 8 | AstroNvim | Baixa o template oficial com commit fixado e instala em `~/.config/nvim` |
| 9 | Login | Instala e configura o LightDM com tema, sessão `bspwm (AurTTY)` e regras de polkit |
| 10 | Terminal | oh-my-bash, ble.sh, fzf-tab, `eza`, `zoxide`, saudação do universo, `.bashrc` e `.bash_profile` |
| 11 | Operação | Instala `atualizar` e, se escolhido, `devdb`; habilita Bastille no boot |
| 12 | Ajustes | Em vesa/scfb troca o backend do picom para `xrender`; resume avisos e reboots pendentes |

O log completo fica em **`/var/log/freebsd-bspwm-aurtty.log`**. O script imprime
cada pacote como `ok` ou `falhou` e, ao final, lista os que falharam (sem abortar
a instalação inteira). Erros inesperados interrompem o script por causa do
`set -e`.

## Requisitos

- **FreeBSD 14.x ou 15.x (amd64)** recém-instalado, com acesso à internet.
- **Acesso root** (o script grava em `/usr/local`, `/etc` e no home do usuário).
- Espaço em disco suficiente para Xorg, Firefox e o toolchain (alguns GB).
- **ZFS recomendado**: permite criar boot environments e desfazer uma atualização
  com `atualizar --voltar`. Em UFS tudo funciona, mas sem rollback do sistema.
- Driver de vídeo compatível:
  - `vesa` — VM com BIOS;
  - `scfb` — VM/PC com UEFI sem driver;
  - `drm-kmod` — Intel ou AMD (o script escolhe `i915kms` ou `amdgpu`);
  - `nvidia-driver` — NVIDIA (com `nvidia-modeset`).

O instalador detecta VM (`kern.vm_guest`) e método de boot (`machdep.bootmethod`)
para sugerir o driver correto.

## Instalação

Num FreeBSD 14 ou 15 recém-instalado, como `root`:

```sh
pkg install -y git
git clone https://github.com/RobertoBarbosa-AurTTY/freebsd-bspwm-aurtty.git
cd freebsd-bspwm-aurtty
sh install.sh
```

O instalador usa o `bsddialog` do sistema base (FreeBSD 14+), com menus, checklist
e uma tela de progresso por etapa; o tema fica em `extras/installer/bsddialog.theme`.
Sem terminal interativo ou com `AURTTY_TEXTO=1 sh install.sh`, as mesmas perguntas
aparecem em texto simples. Durante a instalação, a saída detalhada vai para
`/var/log/freebsd-bspwm-aurtty.log`.

Perguntas feitas pelo instalador:

| Pergunta | Padrão | Observações |
|---|---|---|
| Usuário (existente ou novo) | — | Usuário novo é criado nos grupos `wheel` e `video` |
| Senha do usuário | — | Só para usuário novo, com confirmação |
| Layout do teclado | `br` (ABNT2) | Gravado em `xorg.conf.d/10-teclado.conf` |
| Driver de vídeo | detecta VM/BIOS/UEFI | vesa, scfb, drm-kmod ou NVIDIA |
| Como entrar | LightDM | Tela gráfica, login no `ttyv0` com autostart, ou manual (`startx`) |
| Terminal estilo AurTTY | sim | bash + oh-my-bash (powerline) + ble.sh + fzf-tab |
| Ferramentas de desenvolvimento backend | sim | Pacotes de dev/redes + `devdb` |

Depois da instalação:

```sh
tail -f /var/log/freebsd-bspwm-aurtty.log   # acompanhar o log
reboot                                      # carregar driver de vídeo / LightDM
```

- Configurações preexistentes em `~/.config` são movidas para
  `~/.config-backup-<data>`; um `.bashrc` antigo também é preservado.
- Se a lista final indicar pacotes com falha, instale-os manualmente com
  `pkg install <pacote>` e consulte o log para o motivo.
- Em Intel/AMD e NVIDIA, o driver só é carregado no próximo boot.
- Com LightDM, a tela de login sobe sozinha após o reboot.

## Componentes

### Desktop e sessão gráfica

| Camada | Componentes |
|---|---|
| Sessão | Xorg, bspwm, sxhkd |
| Barra e composição | polybar (`bar07`), picom |
| Launcher e menu | rofi, jgmenu |
| Notificações e clipboard | dunst, clipcat |
| Utilitários | feh, xsettingsd, xdo, xdotool, maim, xclip, jq, ImageMagick7 |
| Áudio | pulseaudio, pavucontrol, pamixer, playerctl |
| Bloqueio de tela | i3lock-color |
| Navegador e arquivos | Firefox (`super+b`), PCManFM (`super+f`) |

### Terminal

- **bash** como shell padrão, com **oh-my-bash** (tema `powerline`) e **ble.sh**
  (realce e sugestões enquanto digita).
- **eza** (`ls`, `ll`, `lt` com ícones), **zoxide** e **fzf**
  (`Ctrl+R` histórico, `Ctrl+T` arquivos).
- **fzf-tab-completion**: `TAB` abre o fzf com pré-visualização (pastas com
  `eza`, arquivos com `bat`), no estilo do fzf-tab do zsh do gh0stzk.
- **Saudação do universo**: cada terminal novo sorteia uma figura procedural em
  blocos coloridos — Andrômeda (M31), Pilares da Criação (M16), buraco negro
  TON 618, Nebulosa do Caranguejo (M1), Homúnculo de Eta Carinae, VY Canis
  Majoris, Júpiter, Marte, Saturno e 55 Cancri e. As figuras são geradas sem
  fotos (`extras/bash/universo/*/render.py`) e animam até o primeiro comando
  (exceto TON 618). Ao lado, informações do sistema via fastfetch.
  - `figura off` desliga a animação;
  - `FIGURA_FIXA=<pasta>` fixa uma figura;
  - `FIGURA=0` desliga a saudação; `FIGURA_INFO=0` desliga só as informações.
- O `root` continua com `/bin/sh` como shell de segurança; em `su -` interativo
  o `.profile` troca para o bash com o mesmo tema.

### Desenvolvimento, redes e bancos

| Categoria | Ferramentas |
|---|---|
| Versionamento e terminal | lazygit, tmux, gh, mise, uv |
| Clientes HTTP e dados | xh, httpie, yq, jq |
| Linguagens | python3, node22 + npm, deno |
| Bancos (clientes) | sqlite3, `psql`, `pgcli`, MariaDB/MySQL, `valkey-cli` |
| Qualidade | shellcheck, pre-commit |
| Bancos locais | Bastille + `devdb` (PostgreSQL, MariaDB, Valkey, MongoDB) |

**Docker não existe no FreeBSD.** No lugar dele, o `devdb` sobe cada banco em
uma jail própria, isolada do sistema e acessível em `127.0.0.1`.

### Shims FreeBSD (`freebsd-bin/`)

Os scripts do tema Emilia esperam ferramentas GNU/Linux. Os shims ficam no
início do `PATH` da sessão bspwm e evitam alterar o sistema:

| Shim | Substitui | Implementação |
|---|---|---|
| `sed` | GNU sed | `exec /usr/local/bin/gsed` |
| `date` | GNU date | `exec /usr/local/bin/gdate` |
| `stat`, `shuf`, `tac` | coreutils | wrappers/aliases para as versões GNU |
| `pidof` | procps | implementado sobre `pgrep -x` (aceita `-q`, `-s`, `-x`) |
| `ip route show default` | iproute2 | traduzido para `route -n get default` |
| `NetStatus` | `internal/network` da polybar | lê a interface padrão e calcula a taxa com `netstat -I` |
| `FsUsage` | `internal/fs` da polybar | usa `df -h` no lugar de `/proc` |

### Aparência

- Tema GTK **TokyoNight-zk**, ícones **TokyoNight-SE**, cursor **Qogirr-Dark**.
- **JetBrainsMono Nerd Font**, FontAwesome e Material Design Icons.
- Wallpapers próprios (`extras/walls/`, gerados por `tools/gerar-wallpapers.py`):
  **FreeBSD dark** (padrão) e uma homenagem ao ArchBSD/PacBSD. Os do Emilia
  continuam disponíveis no seletor (`super + alt + w`).
- Paleta opcional de **fogo** para a barra (`extras/polybar/fogo.ini`),
  desligada por padrão. Para ativar, troque
  `include-file = ../colors.ini` por `include-file = fogo.ini` em
  `~/.config/bspwm/bars/bar07/config.ini`.
- Área de trabalho ativa com o logo do FreeBSD (glifo `nf-linux-freebsd`) e
  launcher com o diabinho do ArchBSD (`extras/fonts/AurTTYIcons.otf`, gerado por
  `tools/gerar-icone-archbsd.py`).

### Tela de login (opcional, padrão)

LightDM com o tema próprio `AurTTY-Login` (`extras/lightdm/gtk.css`, sobre o
TokyoNight-zk): cartão translúcido arredondado, campos e botão no azul do Emilia,
avatar redondo com o diabinho do ArchBSD (`extras/lightdm/avatar.png`), wallpaper
FreeBSD dark e a sessão `bspwm (AurTTY)`.

- Config: `/usr/local/etc/lightdm/lightdm-gtk-greeter.conf`
- Sessão: `/usr/local/share/xsessions/bspwm-aurtty.desktop`
- Regra de polkit: o greeter roda como `lightdm`; usuários de `wheel`/`operator`
  podem desligar, reiniciar e suspender pela tela de login.

## devdb: bancos em jails

O `devdb` mantém um banco de dados de desenvolvimento por jail, com ciclo de
vida próprio:

```sh
devdb criar postgres     # ou mysql, valkey, mongo
devdb lista              # bancos e estado
devdb parar <banco>
devdb iniciar <banco>
devdb shell <banco>
devdb apagar <banco>
```

| Banco | Pacote no jail | Porta | Conexão local |
|---|---|---|---|
| PostgreSQL | `postgresql17-server` | 5432 | `psql -h 127.0.0.1 -U postgres` (sem senha) |
| MariaDB/MySQL | `mariadb114-server` | 3306 | `mysql://dev:dev@127.0.0.1:3306` |
| Valkey (Redis) | `valkey` | 6379 | `redis://127.0.0.1:6379` (`valkey-cli`) |
| MongoDB | `mongodb70` | 27017 | `mongodb://127.0.0.1:27017` |

**Como funciona:**

- Cada banco vira uma jail **thin** do Bastille chamada `devdb-<banco>` em
  `/usr/local/bastille/jails/devdb-<banco>`, isolando filesystem e processos.
- A jail usa a pilha de rede do host; os serviços são acessados em
  `127.0.0.1` na porta padrão. A configuração é *local-first*: o MariaDB é preso
  explicitamente a `127.0.0.1`; os demais seguem a configuração padrão de escuta
  local. Não exponha essas portas na LAN ou na internet.
- Antes de criar, o script verifica se a porta já está em uso com
  `sockstat -4l -p` e recusa a operação se estiver.
- O PostgreSQL recebe `sysvshm`, `sysvsem` e `sysvmsg` próprios da jail.
- As jails voltam sozinhas no boot: `bastille_enable=YES` e os serviços são
  habilitados dentro de cada jail.
- O primeiro `criar` baixa o sistema base da mesma versão do host
  (`bastille bootstrap <release>`) — uma vez por versão.
- Precisa de root; como o FreeBSD não traz `sudo` por padrão, o `devdb` pede a
  senha do root via `su`.
- Log: `/var/log/devdb.log`.

> **Segurança:** credenciais padrão (`postgres` sem senha, `dev`/`dev`), sem TLS,
> pensadas para laboratório e desenvolvimento local. Jails isolam filesystem e
> processos, mas **não** substituem segmentação de rede, firewall ou hardening.
> Para produção, use serviços dedicados, autenticação forte e criptografia.

## Atualizações com rollback

O comando `atualizar` atualiza o sistema base e os pacotes de uma vez:

```sh
atualizar            # atualiza o FreeBSD e os pacotes
atualizar --lista    # mostra as cópias (boot environments)
atualizar --voltar   # ativa a cópia mais recente e pede reboot
```

- Detecta **pkgbase** (`FreeBSD-runtime`) e, nesse caso, atualiza o base junto
  com os pacotes via `pkg upgrade`. Caso contrário, usa
  `freebsd-update fetch install` e depois `pkg upgrade`.
- Com o sistema em **ZFS**, cria antes um boot environment
  `antes-<AAAAMMDD-HHMMSS>` com `bectl create`, guarda os **5 mais recentes** e
  permite voltar com `atualizar --voltar` ou pelo menu do boot (opção 8 →
  `antes-<data>`).
- Em **UFS**, avisa que não há cópia e pede confirmação antes de continuar.
- Pede a senha do root via `su`.

## Integridade e reprodutibilidade

Tudo o que é baixado de fora do FreeBSD tem **versão e SHA-256 fixados** no topo
do `install.sh`; a função `baixar_verificado` roda `fetch` e aborta se o
checksum não conferir.

| Recurso | Fixação |
|---|---|
| Dotfiles do gh0stzk | commit `793f584892f1041c7703be6a48faa018502dc27a` (`UPSTREAM`) |
| JetBrainsMono Nerd Font | release `v3.4.0` + SHA-256 |
| oh-my-bash | commit `abf846186ab0a8a41ec5888e827ece6277dfe446` + SHA-256 |
| ble.sh | release `v0.4.0-devel3` + SHA-256 |
| fzf-tab-completion | commit `7014e0a7cd68fe3530e2f58c45740d17e98f05b8` + SHA-256 |
| Template AstroNvim | commit `49a7161b776f8bc6c23508819ea1ad4e7b359bee` + SHA-256 |
| Tema GTK, ícones e cursor | pacotes do gh0stzk + SHA-256 |

Os pacotes do FreeBSD vêm dos repositórios oficiais (`pkg`), conforme a
configuração de *branch* do sistema — não são fixados pelo projeto. Os
`dotfiles/` são **gerados** por `tools/sincronizar-upstream.sh`, nunca editados à
mão.

## Atalhos

| Atalho | Ação |
|---|---|
| `super + Return` | terminal |
| `super + space` | lançador (rofi) |
| `super + b` | Firefox |
| `super + f` | PCManFM |
| `alt + F1` | lista de atalhos |
| `super + 1..9` | áreas de trabalho |
| `super + x` | fechar janela |
| `super + Escape` | recarregar atalhos (sxhkd) |

## Estrutura do repositório

```
freebsd-bspwm-aurtty/
├── install.sh                 # instalador POSIX sh
├── UPSTREAM                   # URL + commit dos dotfiles do gh0stzk
├── LICENSE                    # GPL-3.0
├── dotfiles/                  # gerado por tools/sincronizar-upstream.sh
│   ├── config/                # bspwm, polybar, rofi, dunst, picom, alacritty...
│   ├── home/                  # .gtkrc-2.0, .icons
│   └── fonts/                 # fontes usadas pela barra
├── extras/
│   ├── bash/                  # bashrc, fzf-tab-preview, universo/
│   ├── bin/                   # atualizar, devdb
│   ├── installer/             # tema do bsddialog usado pelo install.sh
│   ├── fonts/                 # AurTTYIcons.otf
│   ├── lightdm/               # gtk.css, avatar.png
│   ├── polybar/               # fogo.ini
│   └── walls/                 # wallpapers próprios
├── freebsd-bin/               # shims FreeBSD para scripts do tema
├── tools/
│   ├── gerar-wallpapers.py
│   ├── gerar-icone-archbsd.py
│   └── sincronizar-upstream.sh
└── docs/screenshots/
```

## Solução de problemas

| Sintoma | O que verificar |
|---|---|
| Pacotes falharam no fim | `grep -i erro /var/log/freebsd-bspwm-aurtty.log` e instale manualmente com `pkg install` |
| Driver de vídeo não carregou | Reinicie após a instalação; confira `kldstat` e `sysrc -n kld_list` |
| Cores invertidas/transparência estranha em VM | Esperado sem GPU: o instalador troca o picom para `xrender`; confirme em `~/.config/bspwm/config/picom/picom.conf` |
| LightDM não aparece | `sysrc -n lightdm_enable`, `service lightdm status`, `/var/log/lightdm/` |
| Tema ou avatar errado no login | Confira `/usr/local/etc/lightdm/lightdm-gtk-greeter.conf` e `/usr/local/share/themes/AurTTY-Login` |
| Terminal sem tema | O shell precisa ser bash; confira `echo $SHELL` e `~/.bashrc` |
| `devdb` falha | Precisa de root e Bastille; veja `/var/log/devdb.log`, `bastille list`, portas em uso com `sockstat -4l` |
| Jail não volta no boot | `sysrc -n bastille_enable` deve ser `YES`; `bastille list` mostra o estado |
| Atualização quebrou algo | `atualizar --voltar` + `reboot` (somente ZFS), ou opção 8 no menu do boot |
| Recuperar configs antigas | `~/.config-backup-<data>` no home do usuário |

## Manutenção e contribuição

`dotfiles/` é gerado, não editado à mão:

```sh
tools/sincronizar-upstream.sh            # commit fixado em UPSTREAM
tools/sincronizar-upstream.sh <commit>   # atualizar para outro commit do projeto original
```

O script baixa o upstream, mantém só o tema Emilia e aplica as adaptações para
FreeBSD (remoção de eww/módulos Linux, shims, wallpapers próprios, ajustes da
polybar e do picom).

Outras ferramentas:

```sh
tools/gerar-wallpapers.py        # regenera os wallpapers próprios
tools/gerar-icone-archbsd.py     # regenera a fonte de ícones do launcher
```

**Contribuições são bem-vindas.** Para enviar uma mudança:

1. Teste em uma VM FreeBSD 14/15 limpa (QEMU é suficiente).
2. Mantenha o estilo POSIX `sh` do `install.sh` (sem dependências de bash no
   instalador).
3. Não edite `dotfiles/` à mão: altere `tools/sincronizar-upstream.sh` e
   regenere.
4. Não inclua segredos, senhas ou chaves no repositório.
5. Descreva no PR o que foi testado e o resultado do log.

Abra issues para bugs, sugestões e dúvidas de uso.

## Diferenças em relação ao original (Arch)

- Só o tema **Emilia** e a barra **bar07**. O seletor de temas existe, mas tem
  uma opção só.
- Sem **eww**, que não tem pacote no FreeBSD: os widgets de perfil e do player
  não abrem.
- Módulos da barra removidos: bateria e bluetooth (leem `/sys` do Linux),
  atualizações (pacman).
- Wallpapers próprios (`extras/walls/`, gerados por
  `tools/gerar-wallpapers.py`): **FreeBSD dark** (padrão) e uma homenagem ao
  ArchBSD/PacBSD. Os do Emilia continuam disponíveis no seletor
  (`super + alt + w`).
- Paleta opcional de **fogo** para a barra (`extras/polybar/fogo.ini`),
  desligada por padrão.
- Área de trabalho ativa: logo do **FreeBSD** no lugar do pacman.
- Ícone do launcher: releitura do logo do **ArchBSD** numa fonte própria
  (`extras/fonts/AurTTYIcons.otf`).
- `freebsd-bin/`: shims para os scripts do tema que esperam ferramentas
  GNU/Linux (`sed`, `date`, `stat`, `shuf`, `pidof`, `ip route`).
- Sem Docker: bancos de desenvolvimento rodam em jails via `devdb`.
- Atualização com rollback por boot environments do ZFS (`atualizar`).

## Créditos e licença

O visual (configurações do bspwm, polybar, rofi, dunst e picom, scripts, temas
GTK, ícones, cursor e wallpapers do tema Emilia) vem dos
**[dotfiles do gh0stzk](https://github.com/gh0stzk/dotfiles)**, publicados sob
GPL-3.0. Os arquivos copiados de lá ficam em `dotfiles/` com os cabeçalhos
originais; as adaptações para FreeBSD são aplicadas por
`tools/sincronizar-upstream.sh`.

- Ícone do launcher: releitura do logo do ArchBSD/PacBSD sobre o glifo `arch` do
  Material Design Icons (Apache-2.0).
- Fontes: JetBrainsMono Nerd Font, FontAwesome e Material Design Icons.
- oh-my-bash, ble.sh, fzf-tab-completion e AstroNvim pertencem aos seus
  respectivos autores.

Este projeto é um derivado e segue a mesma licença, **GPL-3.0** (veja
`LICENSE`). O software é fornecido **sem garantia**, conforme os termos da GPL.
