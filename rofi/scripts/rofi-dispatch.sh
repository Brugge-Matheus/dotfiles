#!/usr/bin/env bash
# =====================================================================
#  rofi-dispatch.sh — comandos com `>` nas abas NATIVAS do launcher (Apps e Arquivos).
#
#  O rofi chama este script (config.rasi: run-command) quando voce confirma com Ctrl+Enter um texto que nao e uma
#  linha da lista. Sintaxe, igual as abas Comandos e Janelas:
#       zen >kill!        o texto antes do > escolhe a janela-alvo; kill/kill!/term/close agem sobre ela
#       >kill! 1741909    alvo explicito (PID ou nome)
#       >pavucontrol      qualquer outro comando roda como na aba Comandos   |   >t df -h   abre num terminal
#  Sem `>`: se for um programa existente roda (e como a aba Apps LANCA os apps: o rofi passa o Exec= por aqui); senao so avisa.
#  Resultado e erros saem por notificacao (estas abas nao tem linha de mensagem para os scripts).
# =====================================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
txt="$*"
say() { command -v notify-send >/dev/null && notify-send -a "Launcher" -t 3500 "$1" "${2:-}"; }

case "$txt" in
  *\>*) cmd="$(printf '%s' "${txt#*>}" | sed 's/^[[:space:]]*//')" ;;
  *)    # Sem `>`: o rofi usa este mesmo run-command para LANCAR o app escolhido na aba Apps (recebe a linha Exec=
        # do .desktop). Entao so executamos se for um programa de verdade; texto solto vira aviso, nao execucao.
        first="${txt%% *}"; first="${first#\"}"; first="${first#\'}"
        if command -v "$first" >/dev/null 2>&1 || [ -x "${first/#\~/$HOME}" ]; then
          setsid -f sh -c "$txt" >/dev/null 2>&1 < /dev/null; exit 0
        fi
        say "Para executar escreva > antes do comando" "ex.: >pavucontrol   ·   zen >kill!"; exit 0 ;;
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
