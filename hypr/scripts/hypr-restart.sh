#!/usr/bin/env bash
# hypr-restart — reinicia os servicos do Hyprland (waybar, swaync, hypridle, ...) SEM perder estado,
# depois de gravar um SNAPSHOT de diagnostico (para depurar o que estava errado).
#
# Uso:
#   hypr-restart                    pergunta (s/N), tira o snapshot e reinicia tudo
#   hypr-restart -y                 sem perguntar
#   hypr-restart --gui              pergunta com um menu (fuzzel) — usado pelo SUPER+, -> "Reiniciar servicos"
#   hypr-restart --only waybar,swaync   so esses (ver --list)
#   hypr-restart --snapshot         so o snapshot, sem reiniciar
#   hypr-restart --list             lista os servicos
#   hypr-restart --last             mostra o caminho do ultimo snapshot
#
# O que e preservado: wallpaper por monitor (cache do awww), "Nao perturbe" do swaync, historico do
# clipboard (cliphist, em disco), tempo de bloqueio (hypridle.conf), janelas/workspaces (nao sao tocados).
# O que se perde (inevitavel): notificacoes na tela do swaync, o relogio de inatividade do hypridle (zera).
# NAO reinicia: Hyprland, hyprlock (nunca matar com a tela travada), pipewire, portais (use --only portals).
#
# Snapshots: ~/.cache/hypr-restart/snapshot-AAAAMMDD-HHMMSS.log   (guarda os 30 ultimos)
# Historico de execucoes: ~/.cache/hypr-restart/restart.log
set -uo pipefail

DIR="$HOME/.cache/hypr-restart"; mkdir -p "$DIR"
TS="$(date +%Y%m%d-%H%M%S)"
SNAP="$DIR/snapshot-$TS.log"
RLOG="$DIR/restart.log"
CFG="$HOME/.config/fuzzel/powermenu.ini"
ALL="waybar swaync hypridle clipboard wallpaper wsbuttons polkit"
EXTRA="portals"

YES=0; GUI=0; ONLY=""; SNAPONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) YES=1 ;;
    --gui) GUI=1 ;;
    --only) shift; ONLY="${1//,/ }" ;;
    --snapshot) SNAPONLY=1 ;;
    --last) ls -1t "$DIR"/snapshot-*.log 2>/dev/null | head -1; exit 0 ;;
    --list) echo "padrao: $ALL"; echo "extra (so com --only): $EXTRA"; exit 0 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "opcao desconhecida: $1" >&2; exit 2 ;;
  esac; shift
done
TARGETS="${ONLY:-$ALL}"
for t in $TARGETS; do case " $ALL $EXTRA " in *" $t "*) ;; *) echo "servico desconhecido: $t (veja --list)" >&2; exit 2;; esac; done

say() { printf '%s\n' "$*"; }
notify() { command -v notify-send >/dev/null && notify-send -a "Hypr" "$@" || true; }
log() { printf '%s | %s\n' "$(date '+%F %T')" "$*" >> "$RLOG"; }

# ---------------------------------------------------------------- confirmacao
confirm() {
  if [ "$YES" = 1 ] || [ "$SNAPONLY" = 1 ]; then return 0; fi
  if [ "$GUI" = 1 ] || [ ! -t 0 ]; then
    local r
    r="$(printf 'Sim, reiniciar\nNão\n' | fuzzel --dmenu --config "$CFG" --anchor center \
         --width 30 --lines 2 --prompt "Reiniciar serviços? " 2>/dev/null)" || return 1
    [ "$r" = "Sim, reiniciar" ]
  else
    say "Serviços: $TARGETS"
    say "Será gravado um snapshot em $DIR e depois os serviços reiniciam (janelas e workspaces não são tocados)."
    read -r -p "Tem certeza? [s/N] " a
    case "$a" in s|S|sim|SIM|y|Y) return 0;; *) return 1;; esac
  fi
}

# ---------------------------------------------------------------- snapshot
proc_line() { # pid -> uma linha com o estado do processo
  local p=$1
  [ -d "/proc/$p" ] || { echo "  pid $p: (nao existe)"; return; }
  local st wc th cs1 cs2 rss et
  st=$(awk '/^State:/{print $2}' /proc/$p/status); th=$(awk '/^Threads:/{print $2}' /proc/$p/status)
  rss=$(awk '/^VmRSS:/{print $2" kB"}' /proc/$p/status); wc=$(cat /proc/$p/wchan 2>/dev/null)
  cs1=$(awk '/^voluntary_ctxt/{print $2}' /proc/$p/status); sleep 0.3
  cs2=$(awk '/^voluntary_ctxt/{print $2}' /proc/$p/status 2>/dev/null)
  et=$(ps -o etime= -p "$p" | tr -d ' ')
  echo "  pid $p | up $et | estado $st | threads $th | RSS $rss | wchan ${wc:-?} | ctxt-switches +$((cs2-cs1)) em 0.3s | $(tr '\0' ' ' < /proc/$p/cmdline | cut -c1-110)"
}

snapshot() {
  {
    echo "=== SNAPSHOT hypr-restart $(date '+%F %T') ==="
    echo "alvo: $TARGETS | host: $(uname -n) | kernel: $(uname -r) | $(hyprctl version 2>/dev/null | head -1)"
    echo; echo "## Hyprland"
    echo "config errors: $(hyprctl configerrors 2>&1 | tr '\n' ' ' | cut -c1-300)"
    echo "-- monitores (nome, resolucao, posicao, reservado[l,t,r,b], workspace ativo, dpms)"
    hyprctl monitors -j 2>/dev/null | python3 -c "
import json,sys
for m in json.load(sys.stdin): print('  ',m['name'],'%dx%d@%.0f'%(m['width'],m['height'],m['refreshRate']),(m['x'],m['y']),'reservado',m['reserved'],'ws',m['activeWorkspace']['id'],'dpms',m.get('dpmsStatus'),'focado',m['focused'])" 2>&1
    echo "-- workspaces (id, monitor, janelas, fullscreen)"
    hyprctl workspaces -j 2>/dev/null | python3 -c "
import json,sys
for w in json.load(sys.stdin): print('  ws',w['id'],'mon',w['monitorID'],'janelas',w['windows'],'fullscreen',w['hasfullscreen'])" 2>&1
    echo "-- janelas (SO classe/estado; titulos omitidos de proposito)"
    hyprctl clients -j 2>/dev/null | python3 -c "
import json,sys
for c in json.load(sys.stdin): print('  ',c['class'][:28].ljust(28),'ws',c['workspace']['id'],'mon',c['monitor'],'float',c['floating'],'fs',c['fullscreen'],'pin',c['pinned'],c['size'])" 2>&1
    echo "-- layers da waybar (nivel 0=bg 1=bottom 2=top 3=overlay; alpha 0 = barra escondida)"
    hyprctl layers -j 2>/dev/null | python3 -c "
import json,sys
for mon,v in json.load(sys.stdin).items():
    for lvl,l in v['levels'].items():
        for x in l:
            if x['namespace']=='waybar': print('  ',mon,'nivel',lvl,'alpha',x['alpha'],'pid',x['pid'],(x['x'],x['y'],x['w'],x['h']))" 2>&1

    echo; echo "## Processos"
    echo "-- waybar (uma por monitor)"
    for p in $(pgrep -x waybar); do proc_line "$p"; done
    echo "-- swaync";    for p in $(pgrep -x swaync);   do proc_line "$p"; done
    echo "-- hypridle";  for p in $(pgrep -x hypridle); do proc_line "$p"; done
    echo "-- awww-daemon"; for p in $(pgrep -x awww-daemon); do proc_line "$p"; done
    echo "-- wl-paste/cliphist"; for p in $(pgrep -f '^wl-paste --type (text|image) --watch cliphist store$'); do proc_line "$p"; done
    echo "-- hyprpolkitagent"; for p in $(pgrep -f hyprpolkitagent); do proc_line "$p"; done
    echo "-- hyprlock (so leitura; nunca reiniciado)"; for p in $(pgrep -x hyprlock); do proc_line "$p"; done; pgrep -x hyprlock >/dev/null || echo "  (nao esta rodando = tela destravada)"

    echo; echo "## Servicos systemd --user"
    for u in waybar-fullscreen waybar-ws-watch hyprlock-cover hyprpolkitagent xdg-desktop-portal xdg-desktop-portal-hyprland; do
      systemctl --user show "$u.service" -p ActiveState -p SubState -p MainPID -p NRestarts -p Result -p ActiveEnterTimestamp 2>/dev/null | tr '\n' ' '; echo " <- $u"
    done
    echo "-- falhos:"; systemctl --user --failed --no-legend 2>&1 | sed 's/^/  /'
    for u in waybar-fullscreen waybar-ws-watch; do
      echo "-- journal $u (ultimas 40 linhas)"; journalctl --user -u "$u.service" --no-pager -n 60 2>&1 | grep -E '^[a-zç]{3} [0-9]{1,2} [0-9:]{8} ' | tail -40 | cut -c1-200 | sed 's/^/  /'
    done

    echo; echo "## Estado que sera PRESERVADO (para conferir depois)"
    echo "swaync: dnd=$(swaync-client -D 2>&1 | head -1) | notificacoes=$(swaync-client -c 2>&1 | head -1)"
    echo "cliphist: $(cliphist list 2>/dev/null | wc -l) itens"
    echo "wallpaper (awww):"; awww query 2>&1 | sed 's/^/  /'
    echo "bloqueio: $("$HOME/.config/waybar/scripts/lock-timeout.sh" get 2>&1)s | brilho: $(brightnessctl -m 2>/dev/null | cut -d, -f4)"

    echo; echo "## Sistema"
    echo "-- avisos/erros do usuario nesta sessao (ultimos 30)"; journalctl --user -b -p warning --no-pager -n 80 2>&1 | grep -E '^[a-zç]{3} [0-9]{1,2} [0-9:]{8} ' | grep -v 'Inhibiting other than idle' | tail -25 | cut -c1-180 | sed 's/^/  /'
    echo "-- crashes (coredumps nas ultimas 24h)"; coredumpctl list --since -1d --no-pager 2>&1 | tail -6 | cut -c1-150 | sed 's/^/  /'
    echo "-- memoria/carga"; free -h | sed -n 1,2p | sed 's/^/  /'; echo "  load: $(cut -d' ' -f1-3 /proc/loadavg)"
    echo "=== fim do snapshot ==="
  } > "$SNAP" 2>&1
  # mantem so os 30 ultimos
  ls -1t "$DIR"/snapshot-*.log 2>/dev/null | tail -n +31 | xargs -r rm -f
}

# ---------------------------------------------------------------- reinicios
wait_for() { # wait_for <segundos> <comando...>  -> 0 se o comando passar a dar certo
  local n=$1; shift; local i
  for i in $(seq 1 $((n * 5))); do "$@" >/dev/null 2>&1 && return 0; sleep 0.2; done; return 1
}
launch() { setsid -f "$@" >/dev/null 2>&1 < /dev/null; }  # desanexa (sobrevive a este script)

RESULTS=()
ok()  { RESULTS+=("OK   $1"); say "  ✓ $1"; log "ok $1"; }
bad() { RESULTS+=("FALHA $1 — $2"); say "  ✗ $1: $2"; log "FALHA $1: $2"; }

bars_ok() { # toda saida conectada tem uma waybar com layer criada
  hyprctl layers -j | python3 -c "
import json,sys,subprocess
mons=[m['name'] for m in json.loads(subprocess.check_output(['hyprctl','monitors','-j']))]
have={o for o,v in json.load(sys.stdin).items() for l in v['levels'].values() for x in l if x['namespace']=='waybar'}
sys.exit(0 if all(m in have for m in mons) else 1)"
}

restart_waybar() {
  for p in $(pgrep -x waybar); do kill -TERM "$p" 2>/dev/null; done
  wait_for 3 sh -c '! pgrep -x waybar' || pkill -KILL -x waybar
  systemctl --user restart waybar-fullscreen.service      # lanca 1 barra por monitor e religa o auto-hide
  wait_for 12 bars_ok && ok "waybar (todas as saidas com barra)" || bad "waybar" "alguma saida ficou sem barra — veja o journal de waybar-fullscreen"
}
restart_swaync() {
  local dnd; dnd="$(swaync-client -D 2>/dev/null | head -1)"
  pkill -x swaync; wait_for 3 sh -c '! pgrep -x swaync' || pkill -KILL -x swaync
  launch swaync
  wait_for 8 swaync-client -c || { bad "swaync" "nao respondeu apos reiniciar"; return; }
  [ "$dnd" = "true" ] && swaync-client -dn >/dev/null 2>&1       # restaura "Nao perturbe"
  ok "swaync (nao perturbe: ${dnd:-?} restaurado)"
}
restart_hypridle() {
  pkill -x hypridle; wait_for 3 sh -c '! pgrep -x hypridle' || pkill -KILL -x hypridle
  launch hypridle
  wait_for 5 pgrep -x hypridle && ok "hypridle (relogio de inatividade zerado)" || bad "hypridle" "nao subiu"
}
restart_clipboard() {
  local before after; before=$(cliphist list 2>/dev/null | wc -l)
  pkill -f '^wl-paste --type (text|image) --watch cliphist store$'
  wait_for 3 sh -c '! pgrep -f "^wl-paste --type (text|image) --watch cliphist store$"' || true
  launch wl-paste --type text  --watch cliphist store
  launch wl-paste --type image --watch cliphist store
  sleep 0.5; after=$(cliphist list 2>/dev/null | wc -l)
  if [ "$(pgrep -fc '^wl-paste --type (text|image) --watch cliphist store$')" = 2 ] && [ "$after" -ge "$before" ]; then
    ok "clipboard (historico: $before -> $after itens)"
  else bad "clipboard" "watchers=$(pgrep -fc '^wl-paste --type') historico $before -> $after"; fi
}
restart_wallpaper() {
  pkill -x awww-daemon; wait_for 3 sh -c '! pgrep -x awww-daemon' || pkill -KILL -x awww-daemon
  "$HOME/.config/waybar/scripts/wallpaper-restore.sh" >/dev/null 2>&1
  wait_for 6 sh -c 'awww query | grep -q "image:"' && ok "wallpaper (restaurado do cache por monitor)" || bad "wallpaper" "awww nao restaurou a imagem"
}
restart_wsbuttons() {
  systemctl --user restart waybar-ws-watch.service
  wait_for 4 systemctl --user is-active --quiet waybar-ws-watch.service && ok "botoes de workspace (ws-watch)" || bad "ws-watch" "servico nao ficou ativo"
}
restart_polkit() {
  systemctl --user restart hyprpolkitagent.service
  wait_for 5 systemctl --user is-active --quiet hyprpolkitagent.service && ok "hyprpolkitagent" || bad "hyprpolkitagent" "nao ficou ativo"
}
restart_portals() {
  systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service xdg-desktop-portal.service
  sleep 1; systemctl --user is-active --quiet xdg-desktop-portal.service && ok "portais (compartilhamento de tela reconecta ao reabrir o app)" || bad "portais" "xdg-desktop-portal inativo"
}

# ---------------------------------------------------------------- execucao
confirm || { say "Cancelado."; log "cancelado"; exit 0; }

say "Tirando snapshot..."; snapshot
say "Snapshot: $SNAP"; log "snapshot $SNAP (alvo: $TARGETS)"
[ "$SNAPONLY" = 1 ] && { notify "Snapshot salvo" "$SNAP"; exit 0; }

say "Reiniciando: $TARGETS"
for t in $TARGETS; do "restart_$t" || true; done

{ echo; echo "## RESULTADO do reinicio ($(date '+%F %T'))"; printf '%s\n' "${RESULTS[@]}"; } >> "$SNAP"
fails=$(printf '%s\n' "${RESULTS[@]}" | grep -c '^FALHA' || true)
if [ "$fails" -eq 0 ]; then notify "Serviços reiniciados" "Tudo certo. Snapshot: $(basename "$SNAP")"; say "Pronto. Snapshot: $SNAP"
else notify -u critical "Reinício com falhas" "$fails serviço(s) falharam. Veja $(basename "$SNAP")"; say "Terminou com $fails falha(s). Snapshot: $SNAP"; fi
