#!/usr/bin/env bash
# Instala e ativa o keyd com o remap Alt+Backspace -> Ctrl+Backspace.
# Rode com:  sudo bash ~/dotfiles/keyd/install.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Rode como root: sudo bash $0"; exit 1; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ">> Instalando keyd..."
pacman -S --needed keyd

echo ">> Instalando config em /etc/keyd/default.conf..."
install -Dm644 "$SRC/default.conf" /etc/keyd/default.conf

echo ">> Habilitando e iniciando keyd..."
systemctl enable --now keyd
systemctl restart keyd     # recarrega a config recem-instalada

echo ">> Status:"
systemctl --no-pager --lines=3 status keyd || true

cat <<'EOF'

============================================================
  PRONTO. Alt+Backspace agora apaga palavra em TODO o sistema.
============================================================
  - Vale imediatamente (sem reiniciar) em apps abertos depois disso.
  - Apps ja abertos: feche/reabra para pegar o remap.
  - No terminal (ghostty): reabra o ghostty p/ valer o keybind novo.

  TESTAR:  sudo keyd monitor   (mostra os eventos; Ctrl+C p/ sair)
  REVERTER: sudo systemctl disable --now keyd
============================================================
EOF
