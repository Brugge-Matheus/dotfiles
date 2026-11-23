#!/usr/bin/env bash
# =====================================================================
#  rofi-ext.sh — lancador das extensoes do rofi (chamado pelos binds do
#  Hyprland). Centraliza os comandos e resolve o caminho absoluto do
#  diretorio (o modo "script" do rofi precisa do caminho do rofi-translate.sh).
#
#  Uso: rofi-ext.sh {calc|trans|files|mixer}
#    calc  -> calculadora (rofi-calc / libqalculate)
#    trans -> tradutor (translate-shell)
#    files -> navegador de arquivos (rofi-file-browser-extended)
#    mixer -> volume por programa (rofi-mixer.py); setas Esquerda/Direita ajustam, Enter silencia
# =====================================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
export ROFI_STANDALONE=1   # nos atalhos dedicados (SUPER+= / SUPER+T) o texto puro continua valendo, sem precisar do `>`

case "${1:-}" in
  calc)
    # calculadora "dev": variaveis de sessao + round() + funcoes qalc.
    # Enter = avalia o texto DIGITADO (accept-custom); Ctrl+Enter = copia a
    # linha selecionada (accept-entry); Ctrl+Delete apaga a entrada.
    exec rofi -show calcd -modi "calcd:$DIR/rofi-calc-dev.sh" \
      -kb-custom-1 "Control+Delete" \
      -kb-custom-2 "Control+Shift+Delete" \
      -kb-accept-custom "Return,KP_Enter" \
      -kb-accept-entry "Control+Return,Control+j,Control+m"
    ;;
  trans)
    exec rofi -show trans -modi "trans:$DIR/rofi-translate.sh"
    ;;
  files)
    exec rofi -show file-browser-extended -modi file-browser-extended
    ;;
  mixer)
    # Janela PROPRIA (nao e aba do launcher): aqui as setas Esquerda/Direita viram teclas de volume (custom-3/4),
    # entao o cursor do campo de busca anda so com Ctrl+B/Ctrl+F. Numa aba do launcher isso quebraria os outros modos.
    export ROFI_MIXER_STANDALONE=1
    exec rofi -show mixer -modi "mixer:$DIR/rofi-mixer.py" -no-fixed-num-lines \
      -kb-custom-3 "Right" -kb-custom-4 "Left" \
      -kb-move-char-forward "Control+f" -kb-move-char-back "Control+b" \
      -kb-mode-next "Control+Tab" -kb-mode-previous "Control+ISO_Left_Tab"
    ;;
  *)
    echo "uso: $(basename "$0") {calc|trans|files|mixer}" >&2
    exit 1
    ;;
esac
