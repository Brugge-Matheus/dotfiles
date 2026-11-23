#!/usr/bin/env bash
# =====================================================================
#  rofi-cmds.sh — aba "Comandos" do launcher (SUPER + Espaco): paleta de acoes + executar qualquer comando.
#
#  Substitui o modo `run` nativo do rofi, que listava ~3.700 executaveis do PATH (ruido puro).
#  Agora:
#    1. ACOES curadas do sistema (reiniciar servicos, tempo de bloqueio, wallpaper, PiP, screenshots, ...),
#       cada uma com uma descricao; filtra por nome OU descricao.
#    2. COMANDO LIVRE: escreva `>` e o comando, e rode com Ctrl+Enter. O `>` faz o rofi parar de filtrar o que vem
#       depois, entao a lista continua na tela; o texto antes do `>` ainda filtra.
#         >comando        roda em segundo plano (apps graficos)           ex.: >pavucontrol
#         >t comando      roda num terminal que espera Enter ao acabar    ex.: >t df -h   |   >t nvim ~/x
#         >kill! zen      kill/kill!/term/close agem sobre janelas (mesma sintaxe da aba Janelas)
#       Sem `>` o texto e so busca (nada executa por engano). Se o programa nao existir, avisa e continua aberto.
#    3. RECENTES: os ultimos comandos livres que voce digitou.
#
#  Protocolo do modo script do rofi: ROFI_RETV 0 = abrir; 1 = linha escolhida (ROFI_INFO = id);
#  2 = texto digitado (Ctrl+Enter). Imprimir NADA = o rofi fecha (e o que a gente quer apos executar).
#  Estado: $XDG_CACHE_HOME/rofi-cmds/history
# =====================================================================
set -u
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-cmds"; HIST="$CACHE/history"
mkdir -p "$CACHE"; touch "$HIST"
S="$HOME/.config/waybar/scripts"; H="$HOME/.config/hypr/scripts"
TERM_CMD="${ROFI_CMDS_TERMINAL:-ghostty}"
ICON=$(printf '')          # U+F120 terminal (rotulo da aba), gerado em runtime como nos outros modos

# id|rotulo|descricao|comando   (comando roda com `sh -c`; sleeps curtos deixam o rofi devolver o foco antes)
ACTIONS=(
"restart|Reiniciar serviços do Hyprland|waybar, swaync, hypridle… (pergunta e tira snapshot)|$H/hypr-restart.sh --gui"
"snapshot|Snapshot de diagnóstico|grava o estado dos serviços, sem reiniciar|$H/hypr-restart.sh --snapshot"
"lastsnap|Abrir último snapshot|lê o log no terminal|$TERM_CMD -e sh -c 'less \"\$($H/hypr-restart.sh --last)\"'"
"locktime|Tempo de bloqueio da tela|1 a 30 min ou nunca|$S/lock-timeout.sh"
"lock|Bloquear a tela agora|hyprlock|loginctl lock-session"
"suspend|Suspender|dormir (pede senha ao voltar)|systemctl suspend"
"power|Menu de energia|desligar / reiniciar / sair|$S/powermenu.sh"
"wallpaper|Trocar wallpaper|escolhe o monitor e a imagem|$S/wallpaper.sh"
"clipboard|Histórico da área de transferência|cliphist|$S/clipboard.sh"
"shotregion|Screenshot da região|seleciona e abre o Satty|sleep 0.4; $S/screenshot.sh region"
"shotfull|Screenshot da tela cheia|salva e copia|sleep 0.4; $S/screenshot.sh full"
"shotwin|Screenshot da janela ativa||sleep 0.4; $S/screenshot.sh window"
"pip|Picture-in-Picture: ligar/desligar|janela ativa flutua num canto|sleep 0.3; $H/pip.sh toggle"
"pippin|Picture-in-Picture: fixar em todos os workspaces||sleep 0.3; $H/pip.sh pin"
"pipnext|Picture-in-Picture: próximo canto||sleep 0.3; $H/pip.sh next"
"videoreset|Reset de vídeo|socorro p/ tela preta ao acordar|$H/video-reset.sh"
"reload|Recarregar a config do Hyprland||hyprctl reload"
"keyboard|Layout do teclado|US Internacional ⇄ ABNT2|$S/keyboard-layout.sh"
"wifi|Wi-Fi|redes, conectar, ligar/desligar|$S/wifi-menu.sh"
"powerprof|Perfil de energia|performance / equilibrado / economia|$S/powerprofile.sh"
"dnd|Não perturbar: alternar|notificações do swaync|swaync-client -d -sw"
"clearnotif|Limpar notificações||swaync-client -C -sw"
"bluetooth|Bluetooth|blueman|blueman-manager"
"monitors|Monitores|nwg-displays|nwg-displays"
"look|Aparência (GTK)|nwg-look|nwg-look"
"mixer|Mixer de som|pavucontrol|pavucontrol"
"dotfiles|Editar dotfiles|nvim em ~/dotfiles|$TERM_CMD -e nvim \"\$HOME/dotfiles\""
)

emit_prompt() { printf '\0prompt\x1f%s\n' "$1"; }
emit_msg()    { printf '\0message\x1f%s\n' "$1"; }
esc()         { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }   # pango (markup-rows)

list() {
  printf '\0markup-rows\x1ftrue\n'
  emit_prompt "$ICON"
  local a id label desc
  for a in "${ACTIONS[@]}"; do
    IFS='|' read -r id label desc _ <<<"$a"
    if [ -n "$desc" ]; then
      printf '%s  <span foreground="#55555a">%s</span>\0info\x1fact:%s\n' "$(printf '%s' "$label" | esc)" "$(printf '%s' "$desc" | esc)" "$id"
    else
      printf '%s\0info\x1fact:%s\n' "$(printf '%s' "$label" | esc)" "$id"
    fi
  done
  # recentes (mais novo primeiro)
  if [ -s "$HIST" ]; then
    tac "$HIST" | head -8 | while IFS= read -r c; do
      printf '↻  %s  <span foreground="#55555a">recente</span>\0info\x1fcmd:%s\n' "$(printf '%s' "$c" | esc)" "$c"
    done
  fi
}

hint="Enter executa a ação · >comando + Ctrl+Enter, ou > comando (com espaço) + Enter · >t cmd abre no terminal"

run_action() {   # id
  local a id cmd
  for a in "${ACTIONS[@]}"; do
    IFS='|' read -r id _ _ cmd <<<"$a"
    [ "$id" = "$1" ] && { setsid -f sh -c "$cmd" >/dev/null 2>&1 < /dev/null; return 0; }
  done
  return 1
}

remember() {     # comando -> historico (sem repetir, ultimos 30)
  { grep -vxF -- "$1" "$HIST" 2>/dev/null; printf '%s\n' "$1"; } | tail -n 30 > "$HIST.tmp" && mv "$HIST.tmp" "$HIST"
}

run_free() {     # texto digitado: executa e fecha, ou avisa e mantem aberto
  local txt="$1" interactive=0 cmd first
  txt="$(printf '%s' "$txt" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$txt" ] && return 2
  case "$txt" in
    t\ *) interactive=1; cmd="${txt#t }" ;;
    *)    cmd="$txt" ;;
  esac
  cmd="$(printf '%s' "$cmd" | sed 's/^[[:space:]]*//')"
  first="${cmd%% *}"
  case "$first" in                          # kill/term/close agem sobre JANELAS (rofi-windows.sh)
    kill|kill\!|term|close)
      msg="$("$(dirname "$0")/rofi-windows.sh" --cmd ">$cmd")"
      case "$msg" in ✓*) return 0 ;; *) FAIL_MSG="$msg"; return 1 ;; esac ;;
  esac
  if ! command -v "$first" >/dev/null 2>&1 && [ ! -x "${first/#\~/$HOME}" ]; then
    FAIL_MSG="comando não encontrado: $first"; return 1
  fi
  remember "$txt"
  if [ "$interactive" = 1 ]; then
    setsid -f "$TERM_CMD" -e sh -c "$cmd; printf '\n[Enter fecha] '; read -r _" >/dev/null 2>&1 < /dev/null
  else
    setsid -f sh -c "$cmd" >/dev/null 2>&1 < /dev/null
  fi
  return 0
}

if [ "${1:-}" = "--run" ]; then            # execucao direta, sem protocolo do rofi
  run_free "${2:-}"; rc=$?
  [ $rc -eq 1 ] && printf '%s\n' "${FAIL_MSG:-erro}"
  exit $rc
fi

case "${ROFI_RETV:-0}" in
  0)  emit_msg "$hint"; list ;;
  1|2)
    info="${ROFI_INFO:-}"; sel="${1:-}"
    case "$info" in
      act:*) run_action "${info#act:}" && exit 0 ;;                # imprime nada -> fecha
      cmd:*) run_free "${info#cmd:}" && exit 0 ;;
      *)     # texto digitado (Ctrl+Enter, ou Enter com a lista vazia): so vira comando com `>`
             case "$sel" in
               *\>*) run_free "${sel#*>}"; rc=$?
                     [ $rc -eq 0 ] && exit 0
                     [ $rc -eq 1 ] && { emit_msg "${FAIL_MSG:-erro}"; list; exit 0; } ;;
               *)    emit_msg "para executar escreva > antes do comando (ex.: >pavucontrol). Sem > e so busca."; list; exit 0 ;;
             esac ;;
    esac
    emit_msg "$hint"; list ;;
esac
