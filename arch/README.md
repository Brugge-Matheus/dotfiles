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

| Fase | Escopo | Status |
|---|---|---|
| **0 — Fundação** | Drivers (NVIDIA offload), polkit, portal, áudio, NetworkManager (instala) | ✅ feito |
| **1 — Núcleo Hyprland** | `hyprland.lua`: monitor, input US-Intl, keybinds, regras, env GPU | ✅ feito |
| **2 — Visual** | Walker, Waybar, wallpaper (awww), hyprlock/hypridle, SwayNC, tema Tokyo Night, rede → NetworkManager | ✅ feito |
| **3 — Funcionalidades** | Screenshots (grim+slurp+satty), clipboard (cliphist), trocador de wallpaper | ✅ feito |
| **4 — Apps** | Zen, Thunar+yazi, Discord, Obsidian, Spotify, btop, pavucontrol | ✅ feito |
| **6 — Boot elegante** | quiet + Plymouth + autologin (tty1) → Hyprland no hyprlock | ✅ feito |
| **5 — Dotfiles dev** | zsh + tmux + LazyVim (via `../setup.sh`) | 🔜 |

## 🚀 Como usar (numa máquina nova)

```bash
git clone https://github.com/Brugge-Matheus/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 1) Fundação do sistema (precisa de sudo) — depois REINICIE
sudo bash arch/install/01-foundation.sh
sudo reboot   # NÃO edite a cmdline no menu do limine

# 2) Configs de usuário (symlinks + serviços) — sem sudo
bash arch/install.sh

# 3) Inicie o Hyprland
Hyprland
```

## 📁 Estrutura

```
arch/
├── README.md                  # este arquivo
├── KEYBINDS.md                # todos os atalhos do Hyprland (atuais + planejados)
├── install.sh                 # orquestrador de usuário (symlinks + serviços)
├── install/
│   └── 01-foundation.sh       # Fase 0: drivers + NVIDIA offload + initramfs (sudo)
└── packages/
    └── 01-foundation.txt      # lista de pacotes da fundação

hypr/
└── hyprland.lua               # config do Hyprland (symlink -> ~/.config/hypr/)
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

## 📌 Pendências conhecidas

- Apps a definir: file manager, navegador, terminal definitivo (Fase 4).
