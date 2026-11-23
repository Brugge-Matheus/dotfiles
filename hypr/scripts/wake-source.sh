#!/usr/bin/env bash
# =====================================================================
#  wake-source.sh — descobre O QUE acordou o notebook da suspensao.
#
#  O kernel nao diz a causa no journal. Mas cada dispositivo capaz de acordar a maquina (teclado USB, tampa, botao
#  de energia, adaptador AC, controlador USB...) tem contadores em /sys/**/power/ que sobem quando ele e a fonte do
#  wake. Entao: guardamos os contadores ANTES de dormir e, ao acordar, mostramos quem subiu.
#    wake-source.sh save     antes de suspender (hypridle before_sleep_cmd)
#    wake-source.sh report   ao acordar (resume-log.sh): imprime uma linha "wake-por: ..." (e grava no resume.log)
#  Ver no log:   grep wake-por ~/.cache/resume-log/resume.log | tail
# =====================================================================
STATE="$HOME/.cache/resume-log/wake-counters"
mkdir -p "$(dirname "$STATE")"

counters() {   # "caminho  total_de_eventos" por dispositivo com wakeup
  local f dir n
  for f in $(find /sys/devices -path '*/power/wakeup_count' 2>/dev/null); do
    dir="$(dirname "$f")"
    n=$(( $(cat "$dir/wakeup_count" 2>/dev/null || echo 0) + $(cat "$dir/wakeup_active_count" 2>/dev/null || echo 0) + $(cat "$dir/event_count" 2>/dev/null || echo 0) ))
    [ "$n" -gt 0 ] && printf '%s %s\n' "$(readlink -f "$dir/..")" "$n"
  done | sort
}

name_of() {    # nome legivel de um caminho do sysfs
  local p="$1" d
  for d in "$p" "$p/.."; do
    [ -r "$d/product" ] && { cat "$d/product"; return; }
    [ -r "$d/name" ]    && { cat "$d/name"; return; }
  done
  basename "$p"
}

case "${1:-report}" in
  save)   counters > "$STATE" ;;
  report)
    [ -s "$STATE" ] || { echo "wake-por: sem referencia (suspenda uma vez com o hypridle novo)"; exit 0; }
    out=""
    while read -r path n; do
      old="$(awk -v p="$path" '$1==p{print $2}' "$STATE")"
      if [ "${n}" -gt "${old:-0}" ]; then out="$out [$(name_of "$path") (+$((n - ${old:-0})))]"; fi
    done < <(counters)
    irq="$(cat /sys/power/pm_wakeup_irq 2>/dev/null)"
    echo "wake-por:${out:- nenhum contador subiu} | irq=${irq:-?}"
    ;;
esac
