#!/usr/bin/env bash
# Power menu da Waybar — menu pequeno ancorado abaixo do botao (fuzzel).
set -euo pipefail

# toggle: se ja estiver aberto, fecha
if pgrep -x fuzzel >/dev/null; then
  pkill -x fuzzel
  exit 0
fi

if ! command -v fuzzel >/dev/null 2>&1; then
  notify-send "Power menu" "fuzzel nao instalado. Rode: sudo pacman -S fuzzel"
  exit 0
fi

# Entradas (icone + label) geradas via python p/ embutir glifos com seguranca.
menu="$(python3 - <<'PY'
labels = [
    (0xF023, "Bloquear"),
    (0xF08B, "Sair"),
    (0xF186, "Suspender"),
    (0xF021, "Reiniciar"),
    (0xF011, "Desligar"),
]
print("\n".join(f"{chr(cp)}   {name}" for cp, name in labels))
PY
)"

chosen="$(printf '%s' "$menu" | fuzzel --dmenu \
  --config "$HOME/.config/fuzzel/powermenu.ini")"

case "$chosen" in
  *Bloquear)  loginctl lock-session ;;
  *Sair)      hyprctl dispatch exit ;;
  *Suspender)
      # Trava PRIMEIRO e espera o hyprlock desenhar; so entao suspende.
      # (Evita a corrida onde o lock acende a tela bem na hora de dormir.)
      loginctl lock-session
      for _ in 1 2 3 4 5 6 7 8 9 10; do pidof hyprlock >/dev/null && break; sleep 0.1; done
      sleep 0.3
      systemctl suspend
      ;;
  *Reiniciar) systemctl reboot ;;
  *Desligar)  systemctl poweroff ;;
esac
