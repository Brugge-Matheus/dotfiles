#!/usr/bin/env bash
# =====================================================================
#  resume-log.sh — chamado pelo hypridle (after_sleep_cmd) logo APOS ACORDAR.
#
#  Para que serve:
#   1) DIAGNOSTICO: grava o estado do video/lock em ~/.cache/resume-log/resume.log
#      a +0s, +2s, +5s, +12s depois do resume. Se a tela ficar PRETA com a maquina
#      viva (ja aconteceu: kernel/rede acordaram e o usuario so conseguiu desligar
#      pelo botao), este log mostra se as saidas estavam com DPMS desligado, se o
#      hyprlock estava rodando, e se o kernel reclamou (i915/NVRM/drm/xhci).
#   2) AUTO-CURA: se alguma saida estiver com DPMS desligado ou desativada, manda
#      "dpms on" de novo. Se estiver tudo ligado, nao faz nada (sem piscar a tela).
#
#  Ler o resultado:   tail -n 60 ~/.cache/resume-log/resume.log
# =====================================================================
set -u

LOG="$HOME/.cache/resume-log/resume.log"
mkdir -p "$(dirname "$LOG")"
# mantem o arquivo pequeno
if [ "$(stat -c %s "$LOG" 2>/dev/null || echo 0)" -gt 300000 ]; then
  tail -n 1500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

log() { printf '%s | %s\n' "$(date '+%F %T.%3N')" "$*" >> "$LOG"; }

# "eDP-1[dpms=on dis=False] HDMI-A-1[dpms=OFF dis=False]"  (+ exit 0 se alguma saida apagada)
MON_PY='
import json, sys
try:
    ms = json.load(sys.stdin)
except Exception:
    print("hyprctl-sem-resposta"); sys.exit(2)
off = False
parts = []
for m in ms:
    on = bool(m.get("dpmsStatus"))
    dis = bool(m.get("disabled"))
    off = off or (not on) or dis
    parts.append("%s[dpms=%s dis=%s]" % (m["name"], "on" if on else "OFF", dis))
print(" ".join(parts))
sys.exit(0 if off else 1)
'

# "eDP-1:connected/enabled/On HDMI-A-1:connected/enabled/On" (so conectores conectados ou habilitados)
drm_state() {
  local c n
  for c in /sys/class/drm/card*-*; do
    [ -f "$c/status" ] || continue
    if [ "$(cat "$c/status")" = "connected" ] || [ "$(cat "$c/enabled" 2>/dev/null)" = "enabled" ]; then
      n="$(basename "$c")"; n="${n#card*-}"
      printf '%s:%s/%s/%s ' "$n" "$(cat "$c/status")" "$(cat "$c/enabled" 2>/dev/null)" "$(cat "$c/dpms" 2>/dev/null)"
    fi
  done
}

lid_state() { cat /proc/acpi/button/lid/*/state 2>/dev/null | awk '{print $2}' | head -1; }

# quanto tempo a maquina DORMIU (a falha so aparece depois de ~10 min de sono)
sleep_secs() {
  local t
  t="$(journalctl -k -b 0 -o short-unix --no-pager -g 'PM: suspend entry' 2>/dev/null | tail -1 | awk '{print int($1)}')"
  [ -n "$t" ] && echo $(( $(date +%s) - t )) || echo '?'
}

monitors_state() { hyprctl monitors all -j 2>/dev/null | python3 -I -c "$MON_PY"; }

snapshot() {
  local label="$1" st rc locked lockpid kerr
  st="$(monitors_state)"; rc=$?
  lockpid="$(pgrep -x hyprlock | tr '\n' ',' )"
  locked="$(loginctl show-session "${XDG_SESSION_ID:-auto}" -p LockedHint --value 2>/dev/null || echo '?')"
  kerr="$(journalctl -k --since '-20s' --no-pager 2>/dev/null | grep -ciE 'i915.*(error|fail|timeout)|NVRM|xhci.*error|drm.*(error|fail)' || true)"
  log "${label} monitores: ${st} | drm: $(drm_state)| tampa=$(lid_state) | hyprlock=${lockpid:-nenhum} | LockedHint=${locked} | avisos-kernel(20s)=${kerr}"
  return $rc   # 0 = alguma saida apagada
}

log "================ ACORDOU (dormiu ~$(sleep_secs)s) ================"
prev=0
for t in 0 2 5 12; do
  [ "$t" -gt "$prev" ] && sleep $(( t - prev ))
  prev=$t
  if snapshot "+${t}s"; then
    # alguma saida apagada: tenta religar
    hyprctl dispatch 'hl.dsp.dpms("on")' >/dev/null 2>&1
    log "+${t}s CURA: saida apagada detectada -> dpms on reenviado"
  fi
done
log "---------------- fim do acompanhamento ----------------"
