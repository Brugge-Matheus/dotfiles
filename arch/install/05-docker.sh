#!/usr/bin/env bash
# =====================================================================
#  Docker — instala, habilita o servico e libera uso SEM sudo
#  Rodar com: sudo bash arch/install/05-docker.sh
# =====================================================================
set -euo pipefail

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

[ "$(id -u)" -eq 0 ] || { log_err "Rode como root: sudo bash $0"; exit 1; }
command -v pacman >/dev/null 2>&1 || { log_err "Exclusivo para Arch."; exit 1; }

# usuario que invocou o sudo (p/ adicionar ao grupo docker)
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$SCRIPT_DIR/../packages/05-docker.txt"

mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE" | awk '{print $1}')
log_info "Instalando: ${PKGS[*]}"
pacman -Syu --needed --noconfirm "${PKGS[@]}"
log_ok "Pacotes instalados."

log_info "Habilitando e iniciando o docker.service..."
systemctl enable --now docker.service
log_ok "docker.service ativo."

if [ -n "$TARGET_USER" ]; then
  log_info "Adicionando '$TARGET_USER' ao grupo docker (usar sem sudo)..."
  usermod -aG docker "$TARGET_USER"
  log_ok "Usuario adicionado ao grupo docker."
  log_warn "FACA LOGOUT/LOGIN (ou reinicie) para o grupo docker valer."
else
  log_warn "Nao identifiquei o usuario; rode manualmente: sudo usermod -aG docker <voce>"
fi

echo
echo "Teste depois do relogin:  docker run hello-world"
echo "TUI de containers:        lazydocker"
