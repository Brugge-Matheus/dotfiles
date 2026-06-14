#!/usr/bin/env bash
# =====================================================================
#  FASE 2 — Camada visual (pacotes OFICIAIS)
#  Rodar com: sudo bash arch/install/02-visual.sh
#
#  Instala: waybar, awww (swww), swaync, hyprlock, hypridle,
#           brightnessctl, playerctl, wl-clipboard
#
#  AUR (walker) NAO entra aqui (yay roda como usuario). Depois rode:
#     yay -S --needed walker
#  ou:  bash arch/install.sh   (instala AUR + cria symlinks)
# =====================================================================
set -euo pipefail

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

if [ "$(id -u)" -ne 0 ]; then
  log_err "Rode como root: sudo bash $0"; exit 1
fi
if ! command -v pacman >/dev/null 2>&1; then
  log_err "Exclusivo para Arch (pacman nao encontrado)."; exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$SCRIPT_DIR/../packages/02-visual.txt"

mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE" | awk '{print $1}')
log_info "Instalando ${#PKGS[@]} pacotes da camada visual..."
pacman -Syu --needed --noconfirm "${PKGS[@]}"
log_ok "Pacotes oficiais instalados."

echo
echo "Proximo: instale o launcher (AUR) e crie os symlinks:"
echo "   yay -S --needed walker"
echo "   bash arch/install.sh"
