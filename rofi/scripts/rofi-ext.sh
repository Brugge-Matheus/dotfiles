#!/usr/bin/env bash
# =====================================================================
#  rofi-ext.sh — lancador das extensoes do rofi (chamado pelos binds do
#  Hyprland). Centraliza os comandos e resolve o caminho absoluto do
#  diretorio (o modo "script" do rofi precisa do caminho do rofi-translate.sh).
#
#  Uso: rofi-ext.sh {calc|trans|files}
#    calc  -> calculadora (rofi-calc / libqalculate)
#    trans -> tradutor (translate-shell)
#    files -> navegador de arquivos (rofi-file-browser-extended)
# =====================================================================
DIR="$(cd "$(dirname "$0")" && pwd)"

case "${1:-}" in
  calc)
    # calculadora "dev": variaveis de sessao + round() + funcoes qalc.
    # Enter = avalia o texto DIGITADO (accept-custom); Ctrl+Enter = copia a
    # linha selecionada (accept-entry); Ctrl+Delete apaga a entrada.
    exec rofi -show calcd -modi "calcd:$DIR/rofi-calc-dev.sh" \
      -kb-custom-1 "Control+Delete" \
      -kb-accept-custom "Return,KP_Enter" \
      -kb-accept-entry "Control+Return,Control+j,Control+m"
    ;;
  trans)
    exec rofi -show trans -modi "trans:$DIR/rofi-translate.sh"
    ;;
  files)
    exec rofi -show file-browser-extended -modi file-browser-extended
    ;;
  *)
    echo "uso: $(basename "$0") {calc|trans|files}" >&2
    exit 1
    ;;
esac
