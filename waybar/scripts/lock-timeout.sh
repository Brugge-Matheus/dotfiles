#!/usr/bin/env bash
# lock-timeout.sh — define em quanto tempo de inatividade a tela BLOQUEIA (hypridle).
#   lock-timeout.sh            abre o menu (fuzzel) e aplica a escolha
#   lock-timeout.sh get        imprime o valor atual em segundos (ou "never")
#   lock-timeout.sh set <seg|never>   aplica direto (ex.: set 600)
# Edita o listener do `loginctl lock-session` em ~/.config/hypr/hypridle.conf e reinicia o hypridle.
# O "dim" de brilho acompanha: 150s, ou (bloqueio - 30s) quando o bloqueio vem antes disso.
# Variaveis p/ teste: HYPRIDLE_CONF=<arquivo>  NORESTART=1
set -euo pipefail
CONF="${HYPRIDLE_CONF:-$HOME/.config/hypr/hypridle.conf}"

py() { CONF="$CONF" python3 - "$@"; }

cur() { py get <<'PY'
import os, re, sys
t = open(os.environ["CONF"]).read()
m = re.search(r'^(#off# )?listener \{\s*\n(?:#off# )?\s*timeout = (\d+)\s*\n(?:#off# )?\s*on-timeout = loginctl lock-session', t, re.M)
print("never" if (m and m.group(1)) else (m.group(2) if m else "?"))
PY
}

apply() { py set "$1" <<'PY'
import os, re, sys
p = os.environ["CONF"]; val = sys.argv[2]
t = open(p).read()
lines = t.split("\n")
# acha o bloco listener do lock (on-timeout = loginctl lock-session), ligado ou desligado
for i, l in enumerate(lines):
    if re.match(r'^(#off# )?\s*on-timeout = loginctl lock-session', l):
        break
else:
    sys.exit("listener de bloqueio nao encontrado em " + p)
s = i
while not re.match(r'^(#off# )?listener \{', lines[s]): s -= 1
e = i
while not re.match(r'^(#off# )?\}', lines[e]): e += 1
if val == "never":
    for k in range(s, e + 1):
        if not lines[k].startswith("#off# "): lines[k] = "#off# " + lines[k]
    lock = None
else:
    lock = int(val)
    for k in range(s, e + 1):
        if lines[k].startswith("#off# "): lines[k] = lines[k][6:]
        lines[k] = re.sub(r'(timeout = )\d+', r'\g<1>%d' % lock, lines[k])
# comentario acima do bloco: documenta o valor (sem quebrar o bloco)
# dim de brilho: 150s, ou 30s antes do bloqueio quando ele vem antes
dim = 150 if (lock is None or lock >= 180) else max(lock - 30, 10)
for k, l in enumerate(lines):
    if re.match(r'^\s*timeout = \d+', l) and any('brightnessctl -s set' in x for x in lines[k:k+3]):
        lines[k] = re.sub(r'(timeout = )\d+', r'\g<1>%d' % dim, l)
open(p, "w").write("\n".join(lines))
PY
}

restart() {
  [ -n "${NORESTART:-}" ] && return 0
  pkill -x hypridle 2>/dev/null || true
  setsid -f hypridle >/dev/null 2>&1
}

label() { case "$1" in never) echo "Nunca";; ?*) s=$1; if [ $((s % 60)) -eq 0 ]; then echo "$((s/60)) min"; else echo "${s}s"; fi;; esac; }

case "${1:-menu}" in
  get) cur ;;
  set) apply "$2"; restart ;;
  menu)
    if pgrep -x fuzzel >/dev/null; then pkill -x fuzzel; exit 0; fi
    now="$(cur)"
    opts=("60:1 min" "120:2 min" "180:3 min" "300:5 min" "600:10 min" "900:15 min" "1800:30 min" "never:Nunca")
    menu=""
    for o in "${opts[@]}"; do
      v="${o%%:*}"; n="${o#*:}"
      mark="   "; [ "$v" = "$now" ] && mark="●  "
      menu+="${mark}${n}"$'\n'
    done
    chosen="$(printf '%s' "$menu" | fuzzel --dmenu --config "$HOME/.config/fuzzel/powermenu.ini" \
      --anchor center --width 22 --lines 8 --prompt "Bloquear apos: ")" || exit 0
    chosen="${chosen#*  }"; chosen="${chosen# }"
    for o in "${opts[@]}"; do
      [ "${o#*:}" = "$chosen" ] || continue
      apply "${o%%:*}"; restart
      notify-send -a Bloqueio "Bloqueio de tela" "Agora bloqueia após: $chosen de inatividade"
    done ;;
esac
