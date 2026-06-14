#!/usr/bin/env bash
# Power menu via walker (--dmenu). Chamado pelo botao de power da Waybar.
set -euo pipefail

chosen="$(printf '  Bloquear\n  Sair\n  Suspender\n  Reiniciar\n  Desligar' | walker --dmenu)"

case "$chosen" in
  *Bloquear)  loginctl lock-session ;;
  *Sair)      hyprctl dispatch exit ;;
  *Suspender) systemctl suspend ;;
  *Reiniciar) systemctl reboot ;;
  *Desligar)  systemctl poweroff ;;
esac
