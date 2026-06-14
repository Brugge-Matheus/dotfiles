#!/usr/bin/env bash
# Menu de perfis de energia (power-profiles-daemon) — clique no botao de bateria.
# Usa D-Bus (busctl), sem depender do powerprofilesctl/python-gobject.
# Sem icones: a bolinha indica o perfil ativo.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUS="net.hadess.PowerProfiles"
OBJ="/net/hadess/PowerProfiles"

# toggle
if pgrep -x fuzzel >/dev/null; then pkill -x fuzzel; exit 0; fi

ppd_get() { busctl --system get-property "$BUS" "$OBJ" "$BUS" ActiveProfile 2>/dev/null | sed 's/^s "//; s/"$//'; }
ppd_set() { busctl --system set-property "$BUS" "$OBJ" "$BUS" ActiveProfile s "$1" 2>/dev/null; }

current="$(ppd_get)"; current="${current:-balanced}"

menu="$(python3 - "$current" <<'PY'
import sys
current = sys.argv[1]
dot = chr(0xF111)  # bolinha = ativo
items = [("performance","Performance"), ("balanced","Equilibrado"), ("power-saver","Economia")]
print("\n".join(f"{label}   {dot}" if pid == current else label for pid, label in items))
PY
)"

chosen="$(printf '%s' "$menu" | "$DIR/fuzzel-menu.sh")"

case "$chosen" in
  Performance*) ppd_set performance ;;
  Equilibrado*) ppd_set balanced ;;
  Economia*)    ppd_set power-saver ;;
  *) exit 0 ;;
esac

notify-send -t 1500 "Energia" "Perfil: $(ppd_get)"
