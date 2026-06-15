#!/usr/bin/env bash
# Restaura o ULTIMO wallpaper (por monitor) no inicio do Hyprland.
# Usa o cache do awww (swww). So aplica o default se nao houver nada salvo.
set -u

# garante o daemon e ESPERA ele aceitar comandos (em vez de sleep fixo, que
# falha em boot frio se o daemon demorar mais que o sleep p/ subir)
if ! pgrep -x awww-daemon >/dev/null; then
  awww-daemon &
  for _ in $(seq 1 50); do          # ate ~5s
    awww query >/dev/null 2>&1 && break
    sleep 0.1
  done
fi

# restaura o ultimo wallpaper de cada saida (do cache)
awww restore 2>/dev/null

# fallback (1o boot / cache vazio): aplica o default
if ! awww query 2>/dev/null | grep -q "image:"; then
  awww img "$HOME/Pictures/Wallpapers/default.png" --transition-type any
fi
