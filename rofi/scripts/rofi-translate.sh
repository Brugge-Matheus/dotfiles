#!/usr/bin/env bash
# =====================================================================
#  rofi-translate.sh — tradutor no rofi via translate-shell (o `trans`).
#  Modo "script" do rofi. Traduz o texto para PT-BR e para EN ao mesmo tempo (sem detectar idioma).
#
#  COMO USAR
#    na aba do launcher (SUPER + Espaco):  >texto + Ctrl+Enter  (a lista fica)   ex.:  >hello world
#                                          > texto + Enter        (com ESPACO: a lista some e o Enter executa)
#    no atalho dedicado (SUPER + T):       escreva  texto   e Enter           (o `>` e opcional)
#    Enter numa linha (resultado ou do historico)  -> COPIA aquela traducao (wl-copy) e fecha
#    >clear                                         -> LIMPA o historico  (mesmo comando da calculadora)
#      ("clear" sozinho e reservado; para traduzir a palavra, escreva mais de uma: >clear text)
#
#  HISTORICO  as 6 ultimas traducoes (a mais nova no topo, cada uma com a linha PT e a linha EN e o texto original)
#    ficam salvas em $XDG_CACHE_HOME/rofi-translate/history (30 no total; repetir o mesmo texto so sobe ele).
#    Texto  <TAB>  pt  <TAB>  en  por linha. Sobrevive a fechar o rofi e a reiniciar.
#
#  Requer: translate-shell (trans) + wl-clipboard (wl-copy). Precisa de internet (o `trans` consulta uma API);
#  sem internet avisa em vez de fechar e o historico continua consultavel.
#  Chamado por: rofi-ext.sh trans (SUPER+T) e pela aba "Tradutor" do launcher (rofi/config.rasi).
#
#  Protocolo do modo script do rofi:
#    ROFI_RETV=0 -> chamada inicial   | 1 -> linha escolhida (ROFI_INFO) ou texto digitado (em $1)
#    2 -> texto digitado com Ctrl+Enter ($1)
#    linhas em stdout viram itens; "texto\0info\x1fVALOR" anexa metadado; imprimir NADA fecha o rofi
# =====================================================================
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-translate"
HIST="$CACHE/history"
KEEP=30      # quantas traducoes ficam salvas
SHOW=6       # quantas aparecem na lista
mkdir -p "$CACHE"; touch "$HIST"

# Glifo Nerd Font "language" (U+F1AB) gerado em runtime (evita salvar o char PUA no arquivo). O rofi usa o prompt do
# script como rotulo da aba no mode-switcher, entao o prompt e o icone -> a aba "Tradutor" vira o icone.
ICON=$(printf '')
emit_prompt() { printf '\0prompt\x1f%s\n' "$1"; }
emit_msg()    { printf '\0message\x1f%s\n' "$1"; }

if [ -n "${ROFI_STANDALONE:-}" ]; then
  HELP="texto + Enter traduz (PT e EN) · Enter numa linha copia · >clear limpa o histórico"
else
  HELP="escreva >texto e Ctrl+Enter, ou > texto (com espaço) e Enter · Enter numa linha copia · >clear limpa o histórico"
fi

# linha-ancora: sempre presente, senao uma lista vazia FECHARIA o rofi
anchor() { printf '  — >texto + Ctrl+Enter  ou  > texto + Enter  ·  >clear limpa o histórico\0nonselectable\x1ftrue\n'; }

list_hist() {   # mais nova primeiro: 2 linhas (pt/en) por traducao, com o original ao lado
  [ -s "$HIST" ] || return
  tac "$HIST" | head -n "$SHOW" | while IFS=$'\t' read -r src pt en; do
    [ -n "$pt" ] && printf '%s pt  %s   ← %s\0info\x1fcopy:%s\n' "$ICON" "$pt" "$src" "$pt"
    [ -n "$en" ] && printf '%s en  %s   ← %s\0info\x1fcopy:%s\n' "$ICON" "$en" "$src" "$en"
  done
}

screen() {      # mensagem + historico + ancora (sempre nessa ordem)
  emit_prompt "$ICON"; emit_msg "$1"; list_hist; anchor
}

remember() {    # texto pt en -> historico (sem repetir o mesmo texto; guarda os ultimos $KEEP)
  { awk -F'\t' -v s="$1" '$1!=s' "$HIST"; printf '%s\t%s\t%s\n' "$1" "$2" "$3"; } | tail -n "$KEEP" > "$HIST.tmp" \
    && mv "$HIST.tmp" "$HIST"
}

trim()  { sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
oneline() { tr '\t\n' '  '; }

case "${ROFI_RETV:-0}" in
  0)
    screen "$HELP"
    ;;
  1|2)
    sel="${1:-}"; info="${ROFI_INFO:-}"
    # linha escolhida (resultado ou historico): copia a traducao e fecha
    if [ "${info#copy:}" != "$info" ]; then
      printf '%s' "${info#copy:}" | wl-copy
      exit 0
    fi
    sel="$(printf '%s' "$sel" | trim)"
    [ -z "$sel" ] && { screen "$HELP"; exit 0; }

    # Na ABA do launcher o texto so vira traducao/comando com `>` (sem ele e so busca); nos atalhos dedicados
    # (rofi-ext.sh exporta ROFI_STANDALONE=1) o texto puro traduz, e o `>` so e preciso para comandos (>clear).
    cmd_mode=0
    case "$sel" in
      *\>*) txt="$(printf '%s' "${sel#*>}" | trim)"; cmd_mode=1 ;;
      *)    if [ -n "${ROFI_STANDALONE:-}" ]; then txt="$sel"
            else screen "para traduzir escreva > antes do texto (ex.: >hello world) e Ctrl+Enter"; exit 0; fi ;;
    esac
    [ -z "$txt" ] && { screen "$HELP"; exit 0; }

    # comando: limpar o historico
    if [ "$cmd_mode" = 1 ] && [ "$txt" = "clear" ]; then
      : > "$HIST"; screen "histórico limpo"; exit 0
    fi

    # Traduz nas duas direcoes (sem precisar detectar idioma):
    pt=$(trans -b -no-ansi -t pt "$txt" 2>/dev/null | oneline | trim)
    en=$(trans -b -no-ansi -t en "$txt" 2>/dev/null | oneline | trim)
    if [ -z "$pt" ] && [ -z "$en" ]; then   # sem internet: avisa, nao salva, e o historico segue na tela
      screen "sem tradução: o tradutor precisa de internet. O histórico abaixo continua disponível."
      exit 0
    fi
    remember "$(printf '%s' "$txt" | oneline)" "$pt" "$en"
    screen "Enter numa linha copia a tradução · >clear limpa o histórico"
    ;;
esac
