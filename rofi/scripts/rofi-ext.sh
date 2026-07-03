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
    exec rofi -show calc -modi calc
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
