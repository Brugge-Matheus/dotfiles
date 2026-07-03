#!/usr/bin/env bash
# =====================================================================
#  rofi-translate.sh — tradutor no rofi via translate-shell (o `trans`).
#  Modo "script" do rofi: digite o texto e Enter -> mostra a traducao
#  para PT-BR e para EN. Enter numa das linhas copia pro clipboard.
#
#  Requer: translate-shell (trans) + wl-clipboard (wl-copy).
#  Chamado por: rofi-ext.sh trans  (bind SUPER+T no Hyprland).
#
#  Protocolo do modo script do rofi:
#    ROFI_RETV=0 -> chamada inicial (montar prompt/instrucoes)
#    ROFI_RETV=1 -> usuario digitou/selecionou algo (vem em $1)
#    ROFI_INFO   -> metadado da linha selecionada (aqui: a traducao limpa)
#    linhas em stdout viram itens; "texto\0info\x1fVALOR" anexa metadado
# =====================================================================
# Glifo Nerd Font "language" (U+F1AB) gerado em runtime (evita salvar o char PUA
# no arquivo). O rofi usa o prompt do script como rotulo da aba no mode-switcher,
# entao setamos o prompt como o icone -> a aba "Traduzir" vira o icone.
ICON=$(printf '\uf1ab')
emit_prompt() { printf '\0prompt\x1f%s\n' "$1"; }
emit_msg()    { printf '\0message\x1f%s\n' "$1"; }

case "$ROFI_RETV" in
  0)
    emit_prompt "$ICON"
    emit_msg "Digite o texto e tecle Enter (traduz p/ PT e EN)"
    ;;
  1)
    sel="$1"
    # Se selecionou uma linha de resultado, ela carrega a traducao em
    # ROFI_INFO -> copia pro clipboard e sai.
    if [ -n "$ROFI_INFO" ]; then
      printf '%s' "$ROFI_INFO" | wl-copy
      exit 0
    fi
    [ -z "$sel" ] && { emit_prompt "$ICON"; exit 0; }
    # Traduz nas duas direcoes (sem precisar detectar idioma):
    pt=$(trans -b -no-ansi -t pt "$sel" 2>/dev/null)
    en=$(trans -b -no-ansi -t en "$sel" 2>/dev/null)
    emit_prompt "$ICON"
    emit_msg "Enter copia a traducao"
    [ -n "$pt" ] && printf ' pt  %s\0info\x1f%s\n' "$pt" "$pt"
    [ -n "$en" ] && printf ' en  %s\0info\x1f%s\n' "$en" "$en"
    ;;
esac
