# 🐧 Arch Linux + Hyprland

Dotfiles de **instalação e configuração** do ambiente desktop: Arch Linux com Hyprland (Wayland), dark, minimalista e funcional — no estilo *omarchy*.

> A parte de **ambiente de dev** (zsh, nvim/LazyVim, tmux, starship) está na raiz do repo
> e é instalada pelo [`../setup.sh`](../setup.sh). Este módulo cobre o **desktop**.

---

## 🖥️ Máquina-alvo

| | |
|---|---|
| **Notebook** | Avell (`avell-brugge`) |
| **CPU** | Intel Core i5-13420H (Raptor Lake) |
| **GPU** | Híbrida **Optimus**: Intel UHD (iGPU) + **NVIDIA RTX 3050 6GB** (dGPU) |
| **Boot** | `limine` + **UKI** (`/boot/EFI/Linux/arch-linux.efi`). ⚠️ O cmdline que **vale** é o `cmdline:` do `/boot/limine/limine.conf` (o limine **sobrepõe** o embutido na UKI / `/etc/kernel/cmdline`) |
| **FS** | Btrfs (subvol `@`) sobre LVM |
| **Compositor** | Hyprland (config em **Lua**, `hyprland.lua` — formato v0.55+) |
| **Teclado** | US Internacional (acentos via dead keys) |

## ⚠️ Armadilha crítica — NVIDIA Optimus

O painel deste notebook é controlado pela **Intel**. **NÃO** coloque os módulos NVIDIA em
early-KMS no initramfs (`MODULES=(nvidia ...)`) nem use `fbdev=1` — isso causa **tela preta**
no boot. A config conhecida-boa (aplicada por `install/01-foundation.sh`):

- `/etc/mkinitcpio.conf` → `MODULES=()`
- `/etc/modprobe.d/nvidia.conf` → `options nvidia_drm modeset=1` (sem `fbdev=1`)
- Intel dirige a tela; NVIDIA fica para **offload**: `prime-run <app>`

## 🗺️ Fases do setup

Cada fase de **sistema** é um script `install/NN-*.sh` (precisa de `sudo`) com sua lista
de pacotes em `packages/NN-*.txt`. A parte de **usuário** (symlinks, AUR, serviços) é o
`install.sh`.

| Script | Escopo | Status |
|---|---|---|
| `install/01-foundation.sh` | Drivers (NVIDIA offload + Intel VA-API), polkit, portal, áudio, base | ✅ |
| `install/02-visual.sh` | Rofi (launcher), Waybar, wallpaper (awww), hyprlock/hypridle, SwayNC | ✅ |
| `install/03-features.sh` | Screenshots (grim+slurp+satty), clipboard (cliphist) | ✅ |
| `install/04-apps.sh` | Zen, Thunar+yazi, Discord, Obsidian, Spotify, btop, pavucontrol | ✅ |
| `install/05-docker.sh` | Docker + Docker Compose (adiciona o usuário ao grupo) | ✅ |
| `install/06-boot-experience.sh` | quiet + Plymouth + autologin (tty1) → uwsm/Hyprland | ✅ |
| `install/07-settings.sh` | Dark mode (GTK/Qt), tema black, fontes | ✅ |
| `install/08-settings-apps.sh` | Apps de configuração (nwg-look, nwg-displays, blueman, etc.) | ✅ |
| `install/09-printing.sh` | Impressão (CUPS) + Xerox Phaser 3020 USB (driver AUR) | ✅ |
| `install/switch-to-networkmanager.sh` | Migra rede para NetworkManager (backend iwd) | ✅ |
| `install.sh` (usuário) | AUR + symlinks das configs + serviços (PipeWire) | ✅ |
| `../setup.sh` | Ambiente dev: zsh + tmux + LazyVim + asdf | ✅ |

> **Tema:** black minimalista com pegada dev (paleta `#0a0a0a`, ícones Papirus-Dark,
> fonte JetBrainsMono Nerd Font). O *lockscreen* (`hyprlock`) herda um visual Tokyo Night.

## 🚀 Como usar (numa máquina nova)

```bash
git clone https://github.com/Brugge-Matheus/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 1) Fundação do sistema (precisa de sudo) — depois REINICIE
sudo bash arch/install/01-foundation.sh
sudo reboot   # NÃO edite a cmdline no menu do limine

# 2) Demais fases de sistema (sudo) — na ordem
sudo bash arch/install/02-visual.sh
sudo bash arch/install/03-features.sh
sudo bash arch/install/04-apps.sh
sudo bash arch/install/05-docker.sh
sudo bash arch/install/06-boot-experience.sh
sudo bash arch/install/07-settings.sh
sudo bash arch/install/08-settings-apps.sh
sudo bash arch/install/switch-to-networkmanager.sh   # opcional: rede via NetworkManager

# 3) Configs de usuário (AUR + symlinks + serviços) — SEM sudo
bash arch/install.sh

# 4) Ambiente dev (opcional) — SEM sudo
bash setup.sh

# 5) Reinicie: o autologin no tty1 inicia o Hyprland via uwsm
sudo reboot
```

## 📁 Estrutura

```
arch/
├── README.md                  # este arquivo
├── KEYBINDS.md                # todos os atalhos do Hyprland
├── ROFI.md                    # launcher rofi: tema + extensoes (calc, tradutor, files)
├── install.sh                 # orquestrador de usuário (AUR + symlinks + serviços)
├── install/
│   ├── 01-foundation.sh       # drivers + NVIDIA offload + initramfs (sudo)
│   ├── 02-visual.sh           # rofi, waybar, wallpaper, lock/idle, swaync
│   ├── 03-features.sh         # screenshots, clipboard
│   ├── 04-apps.sh             # navegador, file manager, apps do dia a dia
│   ├── 05-docker.sh           # docker + compose
│   ├── 06-boot-experience.sh  # quiet + plymouth + autologin
│   ├── 07-settings.sh         # dark mode, tema, fontes
│   ├── 08-settings-apps.sh    # apps de configuração
│   └── switch-to-networkmanager.sh
├── packages/                  # uma lista NN-*.txt (e NN-*-aur.txt) por fase
└── scripts/                   # gen-default-wallpaper.py, thunar-minimal.sh

hypr/   → hyprland.lua, hyprlock.conf, hypridle.conf  (symlinks p/ ~/.config/hypr/)
          scripts/: lock.sh · resume-log.sh · video-reset.sh · suspend-stats.py  (ver Suspend/idle)
waybar/ → config.jsonc, style.css, scripts/           (uma instância por monitor)
rofi/   → config.rasi, colors-*.rasi, scripts/        (launcher + extensões — ver ROFI.md)
```

## 🔧 Comandos úteis

```bash
# Validar o config do Hyprland sem iniciar a sessão
Hyprland --verify-config

# Rodar um app na GPU NVIDIA (offload)
prime-run <app>

# Conferir a GPU dedicada
nvidia-smi
```

## 🌐 Rede

Migrado para **NetworkManager** com backend **iwd** (reaproveita o WiFi/credenciais do iwd).
Migração feita por `install/switch-to-networkmanager.sh`. A Waybar mostra o WiFi e
abre `nmtui` ao clicar. `systemd-networkd` foi desativado.

## 📌 Notas

- **Terminal:** ghostty · **File manager:** Thunar (GUI) + yazi (terminal) · **Navegador:** Zen
  · **Launcher:** rofi (`SUPER+Espaço`, tema black em `rofi/config.rasi`).
- **Login:** autologin no tty1 → `.zprofile` → `uwsm start hyprland.desktop`. A sessão
  **trava no boot** via `hypr/scripts/lock.sh` (guard resiliente: relança o `hyprlock` se
  ele morrer sem desbloquear), funcionando como tela de login. O mesmo `hyprlock` cobre
  idle/suspensão/bloqueio manual (`SUPER+L`).
- **Suspend/idle:** serviços `nvidia-suspend/resume/hibernate` (em `01-foundation.sh`) +
  `i915.enable_psr=0` na cmdline (em `06-boot-experience.sh`) evitam **tela preta ao acordar**.
  O PSR (Panel Self Refresh) do i915 causava tela-preta **intermitente** no resume de suspend
  longo (o painel Intel — `card1-eDP-1`, driver **i915** — não refazia o link training);
  desligá-lo resolveu. ⚠️ **Pegadinha:** o flag só vale se estiver no `cmdline:` do
  `/boot/limine/limine.conf` (não basta o `/etc/kernel/cmdline`). Se editar o cmdline à mão,
  edite a **1ª** entrada do `limine.conf` (a 2ª é a de resgate) e **reinicie**. O
  `06-boot-experience.sh` já sincroniza isso (passo 2b); rode-o de novo se o cmdline divergir.
  A NVIDIA já preserva a VRAM (`PreserveVideoMemoryAllocations`, serviços `nvidia-*`) — não é
  ela a causa. O `hypridle` faz
  dim → lock; **não** faz `dpms off` com a sessão travada (o hyprlock não lida com o display
  sumindo — issue hyprwm/hyprlock#953).
  - **Estado atual (medido em 20/11/2026, journal de 121 boots / 338 suspensões):** a tela
    preta ao acordar **ainda acontece em ≈ 9% dos ciclos** (32 falhas) — o `enable_psr=0`
    ajudou pouco (≈ 14% → 8,8%, mas só 43 ciclos antes dele) e **não resolveu**. Em todas as
    falhas o kernel, a rede e o logind acordaram (o desligamento pelo botão curto foi *limpo*):
    é a **saída de vídeo** que não volta. Padrão: quase só depois de **mais de ~10 min de sono**
    (0/37 entre 1–10 min; ≈ 17% de 10 min em diante) e mais com a **tampa** (14,7% ao abrir a
    tampa vs 5–7% por tecla). **Causa raiz não provada.** Hipóteses: estados profundos do
    display Intel, re-modeset do HDMI no resume, NVIDIA em D3cold (menos provável).
  - **Restrição:** manter o sono profundo (S3) com o **mínimo de bateria** — não adotar
    `mem_sleep_default=s2idle`, `i915.enable_dc=0` nem desligar o D3cold como "correção".
  - **Quando acontecer (tela preta com a máquina viva):** espere ~15 s, tente
    **`SUPER+CTRL+ALT+R`** (reset de vídeo, `hypr/scripts/video-reset.sh`; funciona na tela de
    bloqueio). Se não resolver: **Ctrl+Alt+F3 → Ctrl+Alt+F1**, ou fechar e abrir a tampa, ou
    digitar a senha às cegas. Só então o **botão de energia em clique CURTO** (nunca segurar:
    o desligamento limpo preserva o journal). Anote qual passo funcionou.
  - **Ferramentas (em `hypr/scripts/`):**
    - `resume-log.sh` — chamado pelo `hypridle` (`after_sleep_cmd`); grava em
      `~/.cache/resume-log/resume.log`, em +0/2/5/12 s após acordar: duração do sono, tampa,
      estado dos conectores DRM, `dpms` dos monitores, `hyprlock` e avisos do kernel; e religa
      saídas que sigam apagadas (sem piscar se estiver tudo ligado).
    - `video-reset.sh` — o atalho `SUPER+CTRL+ALT+R` (log no mesmo arquivo). Não faz `dpms off`
      (hyprlock#953).
    - `suspend-stats.py` — taxa de falha por duração do sono / tampa a partir do journal
      (~10 s). `suspend-stats.py --desde AAAA-MM-DD` compara *antes × depois* de uma mudança
      (com ≈ 17% de falha em sonos longos, 20 sonos longos sem nenhuma falha já é evidência
      forte de melhora).
  - Depois de uma falha: `tail -n 60 ~/.cache/resume-log/resume.log` e `journalctl -b -1`.
- **Vídeo por hardware (VA-API):** a **iGPU Intel** (que dirige a tela) decodifica VP9/AV1/H264
  em hardware → YouTube 1440p sem travar e sem torrar a CPU. `intel-media-driver` (iHD) é
  instalado no `01-foundation.sh`; o `install.sh` linka `zen/user.js` no perfil do Zen para
  ligar o decode acelerado. Conferir: `vainfo` (perfis de decode) e `intel_gpu_top` (engine
  `Video` subindo com um vídeo rodando). Em Optimus o decode vai pela Intel de propósito
  (a NVIDIA fica só para offload de render/compute via `prime-run`).
- **Players de vídeo:** **mpv** (padrão do dia a dia — minimalista, `hwdec=auto-safe` usa a
  VA-API acima, tema ayu, config em `mpv/mpv.conf` + `mpv/input.conf`) e **vlc** (o "canivete":
  abre tudo, converte, grava, filtros, streams). `yt-dlp` deixa o mpv tocar links direto
  (`mpv <url>`, limitado a 1440p no `ytdl-format`). Pacotes em `packages/02-visual.txt`.
  No mpv: `i` mostra stats (confirma `hwdec: vaapi`), `S` tira print do frame limpo.
- **Imagem:** **qimgv** (AUR) — visualizador rápido, é o **padrão** de imagem (definido por
  `xdg-mime` no `install.sh`, então o Thunar abre nele). Tema ayu em `qimgv/theme.conf`
  (symlink; só persiste com o tema em **Custom** nas Settings — em preset o qimgv sobrescreve
  o arquivo). Edição leve embutida: `X` crop · `R` resize · `Ctrl+R`/`Ctrl+L` girar · `H`/`V`
  flip. **`G` abre a imagem no GIMP** (script `gimp %file%`, ver `[Scripts]`/`[Controls]` no
  `qimgv/qimgv.conf` — versionado por **cópia**, não symlink, pois o qimgv reescreve via
  QSettings). Editor pesado = **gimp** (`packages/02-visual.txt`).

## 📊 Waybar — funcionalidades

Uma instância **por monitor** (daemon `waybar/scripts/waybar-fullscreen.sh`: auto-hide em
fullscreen + revelar-ao-hover, por monitor). ⚠️ **Não recarregue com `SIGUSR2`** (crasha);
para aplicar mudanças, reinicie esse daemon.

**Bandeja (tray):** o `StatusNotifierWatcher` roda num serviço próprio (`waybar-sni-watcher.service`, `waybar/scripts/sni-watcher.py`),
independente da waybar. Antes ele morava na primeira waybar; quando ela era relançada (ex.: HDMI religado ao acordar) a lista de
ícones sumia e apps como o Discord só voltavam reiniciando. Agora as waybars são só "hosts" e os ícones sobrevivem aos relançamentos.

**Menus abertos pela barra em fullscreen:** a barra fica **fixa** enquanto um menu dela estiver aberto (botão direito
num app da bandeja como Discord, sliders de brilho/volume, menus fuzzel/rofi, central de notificações). Ela solta
quando o menu fecha: **Esc**, ou clique fora da barra. Como o menu da bandeja (GTK) não aparece em `hyprctl layers`,
o daemon usa binds não-consumidores de clique/`Esc` em `hypr/hyprland.lua` (tocam `$XDG_RUNTIME_DIR/waybar/click|esc`);
sliders e menus de launcher são detectados pela layer-surface (`MENU_LAYERS` no daemon).

- **Workspaces (`custom/ws1..10`):** botões dinâmicos (só ocupados + o ativo). Reconstruídos
  como módulos custom porque o clique do módulo nativo `hyprland/workspaces` **quebra** na
  config Lua do Hyprland 0.55+ (manda `dispatch workspace N` por IPC, que o interpretador
  Lua rejeita — bug upstream waybar#5008/#5035). O clique chama `ws-focus.sh` →
  `hl.dsp.focus({workspace=N})` (troca) **+ leva o cursor** para a janela focada. Atualização
  instantânea via `ws-watch.sh` (escuta o socket2 e sinaliza `SIGRTMIN+9`).
- **Taskbar (`wlr/taskbar`):** uma caixa por janela aberta (ícone do app); clique foca a
  janela, botão do meio fecha.
- **Bateria (`custom/battery`):** tooltip com %, perfil de energia (power-profiles-daemon via
  D-Bus) e tempo restante (upower); clique abre o menu de perfis.
- **Settings (`SUPER + ,`):** menu fuzzel com troca de **layout de teclado** e **menu Wi-Fi**
  (nmcli) embutidos — ver [`KEYBINDS.md`](KEYBINDS.md).
