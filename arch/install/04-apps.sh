#!/usr/bin/env bash
# =====================================================================
#  FASE 4 — Apps do dia a dia
#  Rodar com: sudo bash arch/install/04-apps.sh   (oficiais)
#  AUR (zen-browser, spotify): rodar como usuario (yay) — ver no fim.
# =====================================================================
set -euo pipefail

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

[ "$(id -u)" -eq 0 ] || { log_err "Rode como root: sudo bash $0"; exit 1; }
command -v pacman >/dev/null 2>&1 || { log_err "Exclusivo para Arch."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$SCRIPT_DIR/../packages/04-apps.txt"

mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE" | awk '{print $1}')
log_info "Instalando ${#PKGS[@]} apps oficiais..."
pacman -Syu --needed --noconfirm "${PKGS[@]}"
log_ok "Apps oficiais instalados."

echo
echo "Agora os apps do AUR (como usuario, NAO root):"
echo "   yay -S --needed zen-browser-bin spotify"
echo "ou: bash arch/install.sh   (instala AUR + symlinks)"
