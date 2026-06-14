#!/usr/bin/env bash
# =====================================================================
#  FASE 3 — Funcionalidades (pacotes OFICIAIS)
#  Rodar com: sudo bash arch/install/03-features.sh
#
#  Instala: grim, slurp, satty, cliphist
#  (screenshots, anotacao, historico de clipboard)
# =====================================================================
set -euo pipefail

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

[ "$(id -u)" -eq 0 ] || { log_err "Rode como root: sudo bash $0"; exit 1; }
command -v pacman >/dev/null 2>&1 || { log_err "Exclusivo para Arch."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$SCRIPT_DIR/../packages/03-features.txt"

mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE" | awk '{print $1}')
log_info "Instalando ${#PKGS[@]} pacotes da Fase 3..."
pacman -Syu --needed --noconfirm "${PKGS[@]}"
log_ok "Fase 3 instalada. Recarregue o Hyprland (SUPER+SHIFT+R) ou relogue."
