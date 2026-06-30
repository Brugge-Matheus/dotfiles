#!/usr/bin/env bash
# custom/battery — texto curto na barra (icone + %) e tooltip rico:
#   porcentagem, perfil de energia ativo (power-profiles-daemon) e tempo restante.
# Saida em JSON (return-type: json no waybar).
set -uo pipefail

BAT="$(upower -e 2>/dev/null | grep -im1 BAT || true)"
info="$(upower -i "$BAT" 2>/dev/null || true)"

# --- estado / porcentagem ---
state="$(awk '/state:/{print $2; exit}' <<<"$info")"
cap="$(grep -m1 'percentage:' <<<"$info" | grep -oE '[0-9]+' | head -1)"
cap="${cap:-0}"

# --- tempo restante (upower so mostra quando ha fluxo de energia) ---
vale="$(grep -m1 'time to empty' <<<"$info" | sed 's/.*:[[:space:]]*//')"
valf="$(grep -m1 'time to full'  <<<"$info" | sed 's/.*:[[:space:]]*//')"
fmt_time() { # "2.3 hours" / "56.0 minutes" -> "2h18" / "56min"
  local num unit mins
  num="$(awk '{print $1}' <<<"$1")"; unit="$(awk '{print $2}' <<<"$1")"
  [ -z "$num" ] && { echo ""; return; }
  case "$unit" in
    hour*)   mins="$(awk -v n="$num" 'BEGIN{printf "%d", n*60}')" ;;
    minute*) mins="$(awk -v n="$num" 'BEGIN{printf "%d", n}')" ;;
    *) echo ""; return ;;
  esac
  if [ "$mins" -ge 60 ]; then printf '%dh%02d' "$((mins/60))" "$((mins%60))"
  else printf '%dmin' "$mins"; fi
}

# --- perfil de energia (via D-Bus, igual ao powerprofile.sh) ---
prof="$(busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles \
        net.hadess.PowerProfiles ActiveProfile 2>/dev/null | sed 's/^s "//; s/"$//')"
case "$prof" in
  performance) profl="Performance" ;;
  balanced)    profl="Equilibrado" ;;
  power-saver) profl="Economia" ;;
  *)           profl="${prof:-desconhecido}" ;;
esac

# --- icone ---
case "$state" in
  charging)      icon=$'' ;;   # raio
  fully-charged) icon=$'' ;;   # tomada
  *)             if   [ "$cap" -ge 80 ]; then icon=$''
                 elif [ "$cap" -ge 60 ]; then icon=$''
                 elif [ "$cap" -ge 40 ]; then icon=$''
                 elif [ "$cap" -ge 20 ]; then icon=$''
                 else                         icon=$''; fi ;;
esac

# --- classe (cores do CSS) ---
class="normal"
if   [ "$state" = "charging" ]; then class="charging"
elif [ "$cap" -le 15 ];        then class="critical"
elif [ "$cap" -le 30 ];        then class="warning"
fi

# --- linha de tempo no tooltip ---
case "$state" in
  charging)      t="$(fmt_time "$valf")"; timeline="Carregando${t:+: $t ate cheia}" ;;
  fully-charged) timeline="Cheia" ;;
  *)             t="$(fmt_time "$vale")"; timeline="Restante${t:+: $t}" ;;
esac

nl=$'\n'
text="${icon} ${cap}%"
tooltip="Bateria: ${cap}%${nl}Perfil: ${profl}${nl}${timeline}${nl}— clique: trocar perfil"

# JSON seguro (json.dumps escapa quebras de linha e aspas)
python3 -c 'import json,sys; print(json.dumps({"text":sys.argv[1],"tooltip":sys.argv[2],"class":sys.argv[3],"percentage":int(sys.argv[4])}))' \
  "$text" "$tooltip" "$class" "$cap"
