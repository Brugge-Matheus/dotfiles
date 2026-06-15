#!/usr/bin/env bash
# Screenshot: region | full | window
# Em TODOS os modos abre o satty (anotar/recortar/copiar/salvar). Ao confirmar,
# salva em ~/Pictures/Screenshots e copia pro clipboard.
set -euo pipefail

mode="${1:-region}"
dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"
file="$dir/$(date +'%Y-%m-%d_%H-%M-%S').png"

# 1) Captura (para stdout) conforme o modo escolhido.
case "$mode" in
  full)
    capture() { grim -; }
    ;;
  window)
    geom="$(hyprctl -j activewindow | python3 -c "import json,sys; w=json.load(sys.stdin); print(f\"{w['at'][0]},{w['at'][1]} {w['size'][0]}x{w['size'][1]}\")")"
    capture() { grim -g "$geom" -; }
    ;;
  region)
    geom="$(slurp)" || exit 0   # Esc cancela
    capture() { grim -g "$geom" -; }
    ;;
  *)
    echo "uso: $0 [region|full|window]"; exit 1 ;;
esac

# 2) Edicao: abre o satty (tela p/ decidir o que fazer). Sem satty, salva direto.
if command -v satty >/dev/null 2>&1; then
  capture | satty --filename - \
    --output-filename "$file" \
    --early-exit \
    --copy-command wl-copy
else
  capture > "$file"
  wl-copy < "$file"
  notify-send -i "$file" "Screenshot" "Salvo: $(basename "$file")"
fi
