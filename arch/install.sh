#!/usr/bin/env bash
# =====================================================================
#  Orquestrador do setup Arch + Hyprland (parte de USUARIO, sem sudo)
#  Rodar com: bash arch/install.sh
#
#  Faz (idempotente):
#   - Cria symlinks das configs do desktop (~/.config/...)
#   - Ativa servicos de usuario (PipeWire)
#
#  A parte de SISTEMA (drivers, pacotes) fica em arch/install/*.sh e
#  precisa de sudo. Veja arch/README.md para a ordem das fases.
# =====================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

if [ "$(id -u)" -eq 0 ]; then
  log_err "NAO rode como root. Este script e de usuario: bash arch/install.sh"
  exit 1
fi

# --- symlink seguro (com backup), mesma logica do setup.sh do repo ---
safe_link() {
  local src="$1" dst="$2"
  [ -e "$src" ] || { log_err "Origem nao existe: $src"; return 1; }
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    [ "$(readlink "$dst")" = "$src" ] && { log_ok "Link ja correto: $dst"; return 0; }
    rm "$dst"
  elif [ -e "$dst" ]; then
    log_warn "Backup: $dst -> ${dst}.bak"; mv "$dst" "${dst}.bak"
  fi
  ln -sf "$src" "$dst" && log_ok "Linked: $dst -> $src"
}

# ---------------------------------------------------------------------
# 1. Symlinks das configs do desktop
# ---------------------------------------------------------------------
log_info "Criando symlinks das configs do Hyprland..."
safe_link "$DOTFILES_DIR/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
# (Fase 2+ adiciona aqui: hyprlock, hypridle, hyprpaper, waybar, etc.)

# ---------------------------------------------------------------------
# 2. Servicos de usuario
# ---------------------------------------------------------------------
log_info "Ativando servicos de usuario do PipeWire..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null \
  && log_ok "PipeWire ativo" \
  || log_warn "Falha ao ativar PipeWire (rode dentro de uma sessao de usuario)"

echo
log_ok "Setup de usuario concluido. Recarregue o Hyprland (SUPER+SHIFT+R quando configurado) ou relogue."
