#!/usr/bin/env bash
# Trocador de wallpaper: escolhe uma imagem de ~/Pictures/Wallpapers (fuzzel)
# e aplica via awww (swww). Sem arg = menu; "random" = aleatorio.
set -euo pipefail

dir="$HOME/Pictures/Wallpapers"
mkdir -p "$dir"

# garante o daemon do awww rodando
pgrep -x awww-daemon >/dev/null || { awww-daemon & sleep 0.5; }

apply() {
  awww img "$1" --transition-type any --transition-fps 60 --transition-duration 1
  # lembra o ultimo (p/ restaurar no proximo boot, se quiser)
  ln -sf "$1" "$dir/.current"
}

mapfile -t imgs < <(find "$dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)

if [ "${#imgs[@]}" -eq 0 ]; then
  notify-send "Wallpaper" "Nenhuma imagem em $dir"
  exit 0
fi

if [ "${1:-}" = "random" ]; then
  apply "${imgs[RANDOM % ${#imgs[@]}]}"
  exit 0
fi

if pgrep -x fuzzel >/dev/null; then pkill -x fuzzel; exit 0; fi

# menu com os nomes; aplica o escolhido
chosen="$(printf '%s\n' "${imgs[@]}" | xargs -n1 basename | fuzzel --dmenu \
  --config "$HOME/.config/fuzzel/powermenu.ini" \
  --anchor center --width 40 --lines 10)" || exit 0

[ -n "$chosen" ] && apply "$dir/$chosen"
