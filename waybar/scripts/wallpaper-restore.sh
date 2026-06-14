#!/usr/bin/env bash
# Restaura o ULTIMO wallpaper (por monitor) no inicio do Hyprland.
# Usa o cache do awww (swww). So aplica o default se nao houver nada salvo.
set -u

# garante o daemon
pgrep -x awww-daemon >/dev/null || { awww-daemon & sleep 0.6; }

# restaura o ultimo wallpaper de cada saida (do cache)
awww restore 2>/dev/null
sleep 0.4

# fallback (1o boot / cache vazio): aplica o default
if ! awww query 2>/dev/null | grep -q "image:"; then
  awww img "$HOME/Pictures/Wallpapers/default.png" --transition-type any
fi
