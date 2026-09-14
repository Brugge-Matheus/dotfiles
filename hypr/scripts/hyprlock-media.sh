#!/usr/bin/env bash
# =====================================================================
#  hyprlock-media.sh — "now playing" (Spotify/MPRIS) na tela de bloqueio
#
#  Uso (chamado pelo hyprlock.conf):
#    hyprlock-media.sh title       -> titulo da faixa (truncado)
#    hyprlock-media.sh artist      -> artista (truncado)
#    hyprlock-media.sh prev        -> glyph  (ou vazio se nada tocando)
#    hyprlock-media.sh playpause   -> glyph play/pause conforme o status
#    hyprlock-media.sh next        -> glyph  (ou vazio)
#    hyprlock-media.sh cover       -> caminho de um arquivo de imagem (capa)
#    hyprlock-media.sh ctl <cmd>   -> executa playerctl <cmd> no player ativo
#                                     (previous | play-pause | next) — p/ onclick
#
#  Escolha do player: 1) o primeiro que estiver "Playing"; 2) senao, o Spotify
#  se estiver pausado com faixa carregada. (Evita mostrar aba de browser parada.)
#  Sem player -> labels vazios (somem) e capa = PNG transparente (invisivel).
# =====================================================================

PLACEHOLDER="$HOME/.config/hypr/assets/transparent.png"
COVER_DIR="/tmp/hyprlock-cover"
MAXLEN=38   # limite de caracteres p/ titulo/artista

# pctl — playerctl COM timeout. Isto e o que protege o RELOGIO da lock screen:
# o hyprlock roda os `cmd` dos labels dentro do ciclo de render; se um playerctl
# TRAVAR (player MPRIS que nao responde — browser pendurado, spotifyd zumbi, bus
# lento), o hyprlock fica com o recurso pendente e PULA o render inteiro -> o
# relogio congela num horario (hyprlock #499). O timeout garante que NENHUMA
# chamada bloqueie o render por mais de 1s (no pior caso o widget some por 1 ciclo,
# mas o relogio continua contando). NUNCA chamar playerctl "cru" no caminho de render.
pctl() { timeout 1 playerctl "$@" 2>/dev/null; }

# is_image ARQUIVO — true se comeca com magic bytes de imagem suportada.
# CRITICO: o hyprlock (Hyprgraphics/CAsyncResourceGatherer) ABORTA (SIGABRT) se
# mandarem um arquivo que ele nao decodifica (parcial/HTML de erro/formato ruim)
# -> derruba a tela de bloqueio. Entao NUNCA entregar caminho que nao passe aqui.
is_image() {
  [ -s "$1" ] || return 1
  sig=$(od -An -tx1 -N4 "$1" 2>/dev/null | tr -d ' \n')
  case "$sig" in
    ffd8ff*)  return 0 ;;  # JPEG
    89504e47) return 0 ;;  # PNG
    47494638) return 0 ;;  # GIF
    52494646) return 0 ;;  # RIFF/WEBP
    424d*)    return 0 ;;  # BMP
    *)        return 1 ;;
  esac
}

pick_player() {
  local players p
  players="$(pctl -l 2>/dev/null)" || return 1
  [ -z "$players" ] && return 1
  # 1) algum player efetivamente tocando
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    [ "$(pctl -p "$p" status 2>/dev/null)" = "Playing" ] && { printf '%s' "$p"; return 0; }
  done <<< "$players"
  # 2) Spotify pausado com faixa (para poder retomar pela tela de bloqueio)
  if printf '%s\n' "$players" | grep -qx spotify; then
    [ -n "$(pctl -p spotify metadata title 2>/dev/null)" ] && { printf spotify; return 0; }
  fi
  return 1
}

# corta em MAXLEN e acrescenta reticencias
truncate_field() {
  local s="$1"
  if [ "${#s}" -gt "$MAXLEN" ]; then printf '%s…' "${s:0:$MAXLEN}"; else printf '%s' "$s"; fi
}

FIELD="${1:-}"

# --- capa: le o arquivo fixo mantido em segundo plano pelo cover-daemon ---
# O download/validacao/troca-por-faixa e feito pelo cover-daemon.sh (servico
# systemd hyprlock-cover), fora do ciclo de render do hyprlock. Aqui so entregamos
# o arquivo SE for imagem valida; senao o placeholder. Nunca bloqueia (rede/IO)
# nem entrega arquivo que o hyprlock nao decodifique (evita o abort — ver #499/SIGABRT).
if [ "$FIELD" = "cover" ]; then
  FIXED="$HOME/.cache/hyprlock/cover.img"
  if is_image "$FIXED"; then printf '%s' "$FIXED"; else printf '%s' "$PLACEHOLDER"; fi
  exit 0
fi

player="$(pick_player)" || player=""

# --- controle (onclick): funciona mesmo se pick_player achou o player ---
if [ "$FIELD" = "ctl" ]; then
  [ -z "$player" ] && exit 0
  pctl -p "$player" "${2:?comando ausente}" 2>/dev/null
  exit 0
fi

# --- sem player: labels vazios (a capa ja foi tratada acima) ---
if [ -z "$player" ]; then
  exit 0
fi

case "$FIELD" in
  title)
    truncate_field "$(pctl -p "$player" metadata title 2>/dev/null)"
    ;;
  artist)
    truncate_field "$(pctl -p "$player" metadata artist 2>/dev/null)"
    ;;
  prev)     printf '󰒮' ;;   # nf-md-skip_previous
  next)     printf '󰒭' ;;   # nf-md-skip_next
  playpause)
    if [ "$(pctl -p "$player" status 2>/dev/null)" = "Playing" ]; then
      printf '󰏤'            # nf-md-pause
    else
      printf '󰐊'            # nf-md-play
    fi
    ;;
esac
