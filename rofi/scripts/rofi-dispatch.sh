#!/usr/bin/env bash
# =====================================================================
#  rofi-dispatch.sh — comandos com `>` nas abas NATIVAS do launcher (Apps e Arquivos).
#
#  O rofi chama este script (config.rasi: run-command) quando voce confirma com Ctrl+Enter um texto que nao e uma
#  linha da lista. Sintaxe, igual as abas Comandos e Janelas:
#       zen >kill!        o texto antes do > escolhe a janela-alvo; kill/kill!/term/close agem sobre ela
#       >kill! 1741909    alvo explicito (PID ou nome)
#       >pavucontrol      qualquer outro comando roda como na aba Comandos   |   >t df -h   abre num terminal
#  Sem `>` nada e executado (so busca) e uma notificacao avisa — evita rodar por engano o que era para ser busca.
#  Resultado e erros saem por notificacao (estas abas nao tem linha de mensagem para os scripts).
# =====================================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
txt="$*"
say() { command -v notify-send >/dev/null && notify-send -a "Launcher" -t 3500 "$1" "${2:-}"; }

case "$txt" in
  *\>*) cmd="$(printf '%s' "${txt#*>}" | sed 's/^[[:space:]]*//')" ;;
  *)    say "Para executar escreva > antes do comando" "ex.: >pavucontrol   ·   zen >kill!"; exit 0 ;;
esac
[ -z "$cmd" ] && { say "Comando vazio depois do >"; exit 0; }

first="${cmd%% *}"
case "$first" in
  kill|kill\!|term|close)
    msg="$("$DIR/rofi-windows.sh" --cmd "$txt")"          # passa o texto inteiro: o filtro antes do > escolhe o alvo
    say "$msg" ;;
  *)
    msg="$("$DIR/rofi-cmds.sh" --run "$cmd")" || say "$msg" ;;
esac
