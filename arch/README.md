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
| **Boot** | `limine` + **UKI** (`/boot/EFI/Linux/arch-linux.efi`), cmdline em `/etc/kernel/cmdline` |
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
| `install/01-foundation.sh` | Drivers (NVIDIA offload), polkit, portal, áudio, base | ✅ |
| `install/02-visual.sh` | Walker, Waybar, wallpaper (awww), hyprlock/hypridle, SwayNC | ✅ |
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
├── install.sh                 # orquestrador de usuário (AUR + symlinks + serviços)
├── install/
│   ├── 01-foundation.sh       # drivers + NVIDIA offload + initramfs (sudo)
│   ├── 02-visual.sh           # walker, waybar, wallpaper, lock/idle, swaync
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
waybar/ → config.jsonc, style.css, scripts/           (uma instância por monitor)
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

- **Terminal:** ghostty · **File manager:** Thunar (GUI) + yazi (terminal) · **Navegador:** Zen.
- **Login:** autologin no tty1 → `.zprofile` → `uwsm start hyprland.desktop`. A sessão
  **trava no boot** via `hypr/scripts/lock.sh` (guard resiliente: relança o `hyprlock` se
  ele morrer sem desbloquear), funcionando como tela de login. O mesmo `hyprlock` cobre
  idle/suspensão/bloqueio manual (`SUPER+L`).
- **Suspend/idle:** `cursor:warp_on_change_workspace` da NVIDIA + serviços
  `nvidia-suspend/resume/hibernate` (em `01-foundation.sh`) evitam tela preta ao acordar.
  O `hypridle` faz dim → lock; **não** faz `dpms off` com a sessão travada (o hyprlock não
  lida com o display sumindo — issue hyprwm/hyprlock#953).

## 📊 Waybar — funcionalidades

Uma instância **por monitor** (daemon `waybar/scripts/waybar-fullscreen.sh`: auto-hide em
fullscreen + revelar-ao-hover, por monitor). ⚠️ **Não recarregue com `SIGUSR2`** (crasha);
para aplicar mudanças, reinicie esse daemon.

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
