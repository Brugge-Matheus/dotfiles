#!/usr/bin/env bash
# =====================================================================
#  video-reset.sh — "botao de panico" p/ TELA PRETA ao acordar da suspensao.
#  Atalho: SUPER + CTRL + ALT + R   (funciona ate com a tela de bloqueio ativa:
#  o bind em hyprland.lua usa { locked = true }).
#
#  Quando usar: a maquina acordou (o kernel, a rede e o Hyprland estao vivos),
#  mas a tela esta preta com o backlight ligado. Em vez de segurar o botao de
#  energia (que perde o journal), tente este atalho.
#
#  O que faz (nesta ordem, do mais leve ao mais pesado):
#   1) dpms on           -> religa saidas que o Hyprland tenha como apagadas.
#   2) hyprctl reload    -> reaplica a config dos monitores (novo modeset do painel
#                           e do HDMI). Pode piscar a tela 1-3 s.
#   3) se houver hyprlock rodando (sessao travada): reinicia o hyprlock p/ ele
#      recriar as superficies de bloqueio em TODAS as saidas. O lock.sh relanca
#      sozinho e a sessao CONTINUA travada (a senha segue sendo exigida).
#
#  NAO faz "dpms off": o hyprlock nao lida com o display sumindo com a sessao
#  travada (issue hyprwm/hyprlock#953). Tudo fica registrado em
#  ~/.cache/resume-log/resume.log (o mesmo log do resume-log.sh).
# =====================================================================
set -u

LOG="$HOME/.cache/resume-log/resume.log"
mkdir -p "$(dirname "$LOG")"
log() { printf '%s | %s\n' "$(date '+%F %T.%3N')" "$*" >> "$LOG"; }

# "eDP-1[dpms=on dis=False] HDMI-A-1[dpms=OFF dis=False]"
MON_PY='
import json, sys
try:
    ms = json.load(sys.stdin)
except Exception:
    print("hyprctl-sem-resposta"); sys.exit()
print(" ".join("%s[dpms=%s dis=%s]" % (m["name"], "on" if m.get("dpmsStatus") else "OFF", bool(m.get("disabled"))) for m in ms))
'
mons() { hyprctl monitors all -j 2>/dev/null | python3 -I -c "$MON_PY"; }
lock_pids() { pgrep -x hyprlock | tr '\n' ',' ; }

log "======== VIDEO-RESET acionado (SUPER+CTRL+ALT+R) ========"
log "antes : monitores: $(mons) | hyprlock=$(lock_pids)"

# 1) religa o DPMS
hyprctl dispatch 'hl.dsp.dpms("on")' >/dev/null 2>&1
sleep 0.5

# 2) reaplica os monitores (config + monitors.lua)
hyprctl reload >/dev/null 2>&1
log "hyprctl reload enviado"
sleep 2

# 3) sessao travada? reinicia o hyprlock (o lock.sh o relanca e continua exigindo senha)
if pgrep -x hyprlock >/dev/null 2>&1; then
  pkill -x hyprlock
  log "hyprlock reiniciado (lock.sh relanca; a sessao segue travada)"
  sleep 2
fi

# logo apos o reload os monitores aparecem como dpms=OFF por alguns segundos (reconfiguracao).
# Espera voltarem (ate 10 s); se seguirem apagados passados 6 s, reenvia "dpms on".
t0=$(date +%s%N); resent=0
for i in $(seq 1 20); do
  mons | grep -q 'OFF' || break
  if [ "$i" -ge 12 ] && [ "$resent" -eq 0 ]; then
    hyprctl dispatch 'hl.dsp.dpms("on")' >/dev/null 2>&1
    log "monitores ainda OFF apos ~6 s -> dpms on reenviado"
    resent=1
  fi
  sleep 0.5
done
ms=$(( ( $(date +%s%N) - t0 ) / 1000000 ))
log "depois: monitores: $(mons) | hyprlock=$(lock_pids) | demorou ${ms} ms p/ estabilizar"
log "---------------- fim do video-reset ----------------"
