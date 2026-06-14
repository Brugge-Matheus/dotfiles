#!/usr/bin/env bash
# Screenshot: region (+satty p/ anotar) | full | window
# Salva em ~/Pictures/Screenshots e copia pro clipboard.
set -euo pipefail

mode="${1:-region}"
dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"
file="$dir/$(date +'%Y-%m-%d_%H-%M-%S').png"

notify_ok() { notify-send -i "$1" "Screenshot" "Salvo: $(basename "$1")"; }

case "$mode" in
  full)
    grim "$file"
    wl-copy < "$file"
    notify_ok "$file"
    ;;
  window)
    geom="$(hyprctl -j activewindow | python3 -c "import json,sys; w=json.load(sys.stdin); print(f\"{w['at'][0]},{w['at'][1]} {w['size'][0]}x{w['size'][1]}\")")"
    grim -g "$geom" "$file"
    wl-copy < "$file"
    notify_ok "$file"
    ;;
  region)
    geom="$(slurp)" || exit 0   # Esc cancela
    if command -v satty >/dev/null 2>&1; then
      # abre o satty p/ anotar; salva no arquivo e copia ao confirmar
      grim -g "$geom" - | satty --filename - \
        --output-filename "$file" \
        --early-exit \
        --copy-command wl-copy
    else
      grim -g "$geom" "$file"
      wl-copy < "$file"
      notify_ok "$file"
    fi
    ;;
  *)
    echo "uso: $0 [region|full|window]"; exit 1 ;;
esac
