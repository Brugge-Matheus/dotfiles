#!/usr/bin/env bash
# Instala e configura greetd + ReGreet como tela de login (greeter).
# Rode com:  sudo bash ~/dotfiles/greetd/install.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Rode como root: sudo bash $0"; exit 1; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALL_SRC="/home/brugge-matheus/Pictures/Wallpapers/dark-01-mountains-dark.jpg"

echo ">> Instalando pacotes (greetd, greetd-regreet, cage)..."
pacman -S --needed greetd greetd-regreet cage

echo ">> Copiando wallpaper de fundo do greeter..."
install -Dm644 "$WALL_SRC" /usr/share/backgrounds/regreet-bg.jpg

echo ">> Instalando configs em /etc/greetd/..."
install -Dm644 "$SRC/config.toml"            /etc/greetd/config.toml
install -Dm644 "$SRC/regreet.toml"           /etc/greetd/regreet.toml
install -Dm644 "$SRC/hyprland-greeter.conf"  /etc/greetd/hyprland-greeter.conf

echo ">> Garantindo diretorios de estado/cache do ReGreet (lembrar ultimo usuario)..."
install -d -o greeter -g greeter /var/cache/regreet /var/lib/regreet 2>/dev/null || true

echo ">> Habilitando greetd no boot..."
systemctl enable greetd.service

# O autologin do getty@tty1 (agetty --autologin) loga direto e compete com o
# greetd pela tty1 — precisa sair pra a tela de login aparecer. Backup + remocao.
AUTOLOGIN="/etc/systemd/system/getty@tty1.service.d/autologin.conf"
if [ -f "$AUTOLOGIN" ]; then
  echo ">> Desabilitando autologin do getty@tty1 (backup em ${AUTOLOGIN}.bak)..."
  mv "$AUTOLOGIN" "${AUTOLOGIN}.bak"
  systemctl daemon-reload
fi

cat <<'EOF'

============================================================
  PRONTO. greetd + ReGreet habilitado para o PROXIMO boot.
============================================================
  - NAO foi iniciado agora (evita derrubar sua sessao atual).
  - Ao reiniciar, voce vera a tela de login grafica:
      * selecione o usuario
      * em "sessao", escolha:  Hyprland (uwsm-managed)
      * botoes de desligar/reiniciar ficam na propria tela
  - O "Sair" da waybar agora encerra a sessao e volta pra ca.

  SE ALGO DER ERRADO (tela preta/greeter nao sobe):
      1) Ctrl+Alt+F2  -> loga no shell (TTY)
      2) sudo systemctl disable greetd
      3) (opcional) restaurar autologin antigo:
         sudo mv /etc/systemd/system/getty@tty1.service.d/autologin.conf.bak \
                 /etc/systemd/system/getty@tty1.service.d/autologin.conf
      4) reinicie -> volta ao fluxo antigo (uwsm no tty1)
============================================================
EOF
