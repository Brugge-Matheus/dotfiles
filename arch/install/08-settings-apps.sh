#!/usr/bin/env bash
# =====================================================================
#  FASE 8 — Apps de configuracao dedicados (control panel)
#  Rodar com: sudo bash arch/install/08-settings-apps.sh
#
#  Instala apps (GTK) por area: aparencia, monitores, bluetooth (blueman),
#  impressoras, som. Habilita CUPS e Bluetooth.
# =====================================================================
set -euo pipefail

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

[ "$(id -u)" -eq 0 ] || { log_err "Rode como root: sudo bash $0"; exit 1; }
command -v pacman >/dev/null 2>&1 || { log_err "Exclusivo para Arch."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$SCRIPT_DIR/../packages/08-settings-apps.txt"
mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE" | awk '{print $1}')
log_info "Instalando: ${PKGS[*]}"
pacman -Syu --needed --noconfirm "${PKGS[@]}"
log_ok "Apps oficiais instalados."

log_info "Habilitando servicos (CUPS impressao + Bluetooth)..."
systemctl enable --now cups.service 2>/dev/null && log_ok "CUPS ativo." || true
systemctl enable --now bluetooth.service 2>/dev/null && log_ok "Bluetooth ativo." || true

echo
echo "Abra o painel de configuracoes com:  SUPER + ,"
