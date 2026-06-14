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
# 0. Pacotes do AUR (via yay, se presente)
# ---------------------------------------------------------------------
if command -v yay >/dev/null 2>&1; then
  for f in "$DOTFILES_DIR"/arch/packages/*-aur.txt; do
    [ -f "$f" ] || continue
    mapfile -t AUR < <(grep -vE '^\s*#|^\s*$' "$f" | awk '{print $1}')
    [ "${#AUR[@]}" -eq 0 ] && continue
    log_info "Instalando ${#AUR[@]} pacote(s) do AUR: ${AUR[*]}"
    yay -S --needed --noconfirm "${AUR[@]}" || log_warn "Falha em algum pacote AUR"
  done
else
  log_warn "yay nao encontrado — pule ou instale os pacotes do AUR manualmente"
fi

# ---------------------------------------------------------------------
# 1. Symlinks das configs do desktop
# ---------------------------------------------------------------------
log_info "Criando symlinks das configs do desktop..."
safe_link "$DOTFILES_DIR/hypr/hyprland.lua"  "$HOME/.config/hypr/hyprland.lua"
safe_link "$DOTFILES_DIR/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
safe_link "$DOTFILES_DIR/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
safe_link "$DOTFILES_DIR/waybar"             "$HOME/.config/waybar"
safe_link "$DOTFILES_DIR/swaync"             "$HOME/.config/swaync"
safe_link "$DOTFILES_DIR/gsimplecal/config"  "$HOME/.config/gsimplecal/config"
safe_link "$DOTFILES_DIR/gtk-3.0/gtk.css"    "$HOME/.config/gtk-3.0/gtk.css"
safe_link "$DOTFILES_DIR/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
safe_link "$DOTFILES_DIR/fuzzel/powermenu.ini" "$HOME/.config/fuzzel/powermenu.ini"
# Unit que ativa o graphical-session.target (portais/polkit no Hyprland do TTY)
safe_link "$DOTFILES_DIR/systemd/user/tty-graphical-session.target" "$HOME/.config/systemd/user/tty-graphical-session.target"

# Wallpaper padrao (gera se nao existir)
if [ ! -f "$HOME/Pictures/Wallpapers/default.png" ]; then
  log_info "Gerando wallpaper padrao..."
  python3 "$DOTFILES_DIR/arch/scripts/gen-default-wallpaper.py" || log_warn "Falha ao gerar wallpaper"
fi

# ---------------------------------------------------------------------
# 2. Servicos de usuario
# ---------------------------------------------------------------------
log_info "Ativando servicos de usuario do PipeWire..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null \
  && log_ok "PipeWire ativo" \
  || log_warn "Falha ao ativar PipeWire (rode dentro de uma sessao de usuario)"

echo
log_ok "Setup de usuario concluido. Recarregue o Hyprland (SUPER+SHIFT+R quando configurado) ou relogue."
