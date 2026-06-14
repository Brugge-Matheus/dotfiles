#!/usr/bin/env bash
# Abre ou foca o Spotify (clique no widget da Waybar).
if hyprctl clients -j 2>/dev/null | grep -qiE '"class": *"[Ss]potify"'; then
  hyprctl dispatch focuswindow "class:(?i)spotify" >/dev/null 2>&1
elif command -v spotify >/dev/null 2>&1; then
  setsid -f spotify >/dev/null 2>&1
elif command -v spotify-launcher >/dev/null 2>&1; then
  setsid -f spotify-launcher >/dev/null 2>&1
else
  notify-send "Spotify" "Nao instalado. Instale com: yay -S spotify"
fi
