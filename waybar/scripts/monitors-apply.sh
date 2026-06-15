#!/usr/bin/env bash
# Aplica o ~/.config/hypr/monitors.conf (gerado pelo nwg-displays) no Hyprland.
# Necessario porque a config principal e em Lua e nao da 'source' no .conf.
# Chamado no autostart e pode ser re-rodado apos mudar layout no nwg-displays.
set -u
CONF="$HOME/.config/hypr/monitors.conf"
[ -f "$CONF" ] || exit 0

while IFS= read -r line; do
  case "$line" in
    monitor=*) hyprctl keyword monitor "${line#monitor=}" >/dev/null 2>&1 ;;
  esac
done < "$CONF"
