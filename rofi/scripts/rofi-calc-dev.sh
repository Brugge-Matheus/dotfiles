#!/usr/bin/env bash
# =====================================================================
#  rofi-calc-dev.sh — calculadora "dev" no rofi (modo script).
#  Motor: libqalculate (qalc). Recursos:
#    - variaveis de sessao:   base = 10 - 2      (define base = 8)
#    - reuso + funcoes:       round(base*10/100, 2)
#    - tudo do qalc:          sqrt(2), 200 * 15%, hex(255), 2 GiB to MB...
#    - comandos:              :vars  :clear  :clearhist  :del <nome>
#    - Enter num resultado/variavel  -> COPIA o valor (wl-copy)
#    - Control+Delete numa entrada   -> APAGA aquela variavel/linha (kb-custom-1)
#
#  As variaveis sao substituidas (palavra inteira) pelos valores ANTES de ir
#  pro qalc -> evita colisao com palavras reservadas (ex.: "base"). E o qalc
#  roda com inbase=10 (decimal) p/ nao depender do qalc.cfg do usuario.
#  Estado em $XDG_CACHE_HOME/rofi-calc-dev/ (momentaneo; :clear zera).
# =====================================================================
set -u
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-calc-dev"
VARS="$CACHE/vars"        # linhas: nome=valor (valor ja avaliado)
HIST="$CACHE/history"     # linhas: expr => resultado
mkdir -p "$CACHE"; touch "$VARS" "$HIST"

emit_prompt(){ printf '\0prompt\x1f%s\n' "$1"; }
emit_msg(){ printf '\0message\x1f%s\n' "$1"; }
strip_ansi(){ sed 's/\x1b\[[0-9;]*m//g'; }

# substitui cada 'nome' (palavra inteira) por '(valor)' no texto
subst(){
  local expr="$1" name val esc
  while IFS='=' read -r name val; do
    [ -z "$name" ] && continue
    esc=$(printf '%s' "$val" | sed -e 's/[&/\]/\\&/g')
    expr=$(printf '%s' "$expr" | sed -E "s/\<${name}\>/(${esc})/g")
  done < "$VARS"
  printf '%s' "$expr"
}

# avalia via qalc (terse, decimal, sem cor); vazio se falhar
evalq(){
  local e out; e=$(subst "$1")
  out=$(qalc -t --set "inbase 10" "$e" 2>/dev/null | strip_ansi | tr -d '\n' | sed 's/^ *//; s/ *$//')
  printf '%s' "$out"
}

list_vars(){
  [ -s "$VARS" ] || return
  while IFS='=' read -r name val; do
    [ -z "$name" ] && continue
    printf '  %s = %s\0info\x1fvar:%s\n' "$name" "$val" "$name"
  done < "$VARS"
}
list_hist(){
  [ -s "$HIST" ] || return
  tac "$HIST" 2>/dev/null | head -15 | while IFS= read -r line; do
    printf '  %s\0info\x1fhis:%s\n' "$line" "$line"
  done
}
# IMPORTANTE: se o script imprime NADA, o rofi FECHA. Entao SEMPRE terminamos
# imprimindo linhas (refresh) e NUNCA usamos 'exit' no meio -> a janela fica aberta.
refresh(){
  emit_prompt "Calc"
  list_vars
  list_hist
  # linha-ancora sempre presente: garante saida nao-vazia (senao o rofi fecharia)
  printf '  — digite uma conta ou  nome = expr\0nonselectable\x1ftrue\n'
}

msg_default="conta · nome = expr · round(x,2) · Ctrl+Enter copia · Ctrl+Del apaga · :clear :clearhist :del nome"

case "${ROFI_RETV:-0}" in
  0)
    emit_prompt "Calc"
    emit_msg "$msg_default"
    list_vars
    list_hist
    printf '  — digite uma conta ou  nome = expr\0nonselectable\x1ftrue\n'
    ;;
  1)
    sel="${1:-}"; info="${ROFI_INFO:-}"
    # Ctrl+Enter numa linha existente (accept-entry) -> COPIA o valor e continua aberto
    if [ -n "$info" ]; then
      case "$info" in
        var:*) name="${info#var:}"; val=$(grep -E "^${name}=" "$VARS" | head -1 | cut -d= -f2-); printf '%s' "$val" | wl-copy; emit_msg "copiado: $val" ;;
        his:*) line="${info#his:}"; r="${line##* => }"; printf '%s' "$r" | wl-copy; emit_msg "copiado: $r" ;;
        *)     emit_msg "$msg_default" ;;
      esac
      refresh; exit 0
    fi
    # texto digitado (accept-custom)
    if [ -z "$sel" ]; then emit_msg "$msg_default"; refresh; exit 0; fi
    sel="$(printf '%s' "$sel" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    case "$sel" in
      :clear)     : > "$VARS"; emit_msg "variaveis limpas" ;;
      :clearhist) : > "$HIST"; emit_msg "historico limpo" ;;
      :vars)      emit_msg "$msg_default" ;;
      :del\ *)
        n=$(printf '%s' "${sel#:del }" | sed 's/[^A-Za-z0-9_].*//')
        sed -i -E "/^${n}=/d" "$VARS"; emit_msg "apagada: $n" ;;
      *=*)
        name=$(printf '%s' "$sel" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=.*/\1/')
        rhs=$(printf '%s' "$sel"  | sed -E 's/^[^=]*=[[:space:]]*//')
        if printf '%s' "$name" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
          res=$(evalq "$rhs")
          if [ -n "$res" ]; then
            sed -i -E "/^${name}=/d" "$VARS"
            printf '%s=%s\n' "$name" "$res" >> "$VARS"
            emit_msg "$name = $res   (definida)"
          else emit_msg "erro: nao consegui avaliar '$rhs'"; fi
        else emit_msg "nome de variavel invalido"; fi
        ;;
      *)
        res=$(evalq "$sel")
        if [ -n "$res" ]; then
          printf '%s => %s\n' "$sel" "$res" >> "$HIST"
          printf '%s' "$res" | wl-copy          # auto-copia o resultado
          emit_msg "= $res   (copiado)"
        else emit_msg "expressao invalida: $sel"; fi
        ;;
    esac
    refresh; exit 0
    ;;
  10)  # kb-custom-1 (Control+Delete): apaga a entrada selecionada
    info="${ROFI_INFO:-}"
    case "$info" in
      var:*) sed -i -E "/^${info#var:}=/d" "$VARS"; emit_msg "variavel apagada" ;;
      his:*) line="${info#his:}"; grep -vxF "$line" "$HIST" > "$HIST.tmp" 2>/dev/null && mv "$HIST.tmp" "$HIST"; emit_msg "entrada apagada" ;;
      *)     emit_msg "selecione uma variavel/entrada p/ apagar" ;;
    esac
    refresh; exit 0
    ;;
esac
