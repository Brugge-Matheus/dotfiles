#!/usr/bin/env bash
# =====================================================================
#  FASE 7 — App de configuracoes + dark mode completo (Qt)
#  Rodar com: sudo bash arch/install/07-settings.sh
#
#  Instala: xfce4-settings (control-center), qt6ct/qt5ct/kvantum (Qt dark),
#           nm-connection-editor (rede).
#  O dark do GTK ja e aplicado via gsettings + gtk-3.0/4.0 (install.sh).
# =====================================================================
set -euo pipefail

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

[ "$(id -u)" -eq 0 ] || { log_err "Rode como root: sudo bash $0"; exit 1; }
command -v pacman >/dev/null 2>&1 || { log_err "Exclusivo para Arch."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$SCRIPT_DIR/../packages/07-settings.txt"
mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE" | awk '{print $1}')
log_info "Instalando: ${PKGS[*]}"
pacman -Syu --needed --noconfirm "${PKGS[@]}"
log_ok "Instalado."

echo
echo "Apps disponiveis:"
echo "  xfce4-settings-manager   -> central de configuracoes"
echo "  qt6ct                    -> tema dos apps Qt (ja vem dark via config)"
echo "  nm-connection-editor     -> rede (wifi/conexoes)"
echo
echo "Relogue (ou reinicie o Hyprland) p/ o QT_QPA_PLATFORMTHEME=qt6ct valer."
