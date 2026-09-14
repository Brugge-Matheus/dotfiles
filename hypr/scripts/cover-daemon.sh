#!/usr/bin/env bash
# =====================================================================
#  cover-daemon.sh — mantem a capa da faixa ATUAL sempre pronta p/ o hyprlock.
#
#  Roda em segundo plano (servico systemd user: hyprlock-cover.service).
#  A cada ~3s escolhe o player ativo (mesma logica do widget) e, se a faixa
#  mudou, baixa+valida a capa e grava ATOMICO em ~/.cache/hyprlock/cover.img.
#  Sem player -> grava o placeholder transparente.
#
#  Beneficio: quando a tela bloqueia, a capa JA esta no arquivo fixo -> aparece
#  instantaneo (sem pop-in) e o hyprlock nunca faz rede/decode de lixo no render
#  (so le um arquivo local ja validado). Ver [[arch-hyprlock-now-playing]].
# =====================================================================
set -u

OUT_DIR="$HOME/.cache/hyprlock"
OUT="$OUT_DIR/cover.img"                       # arquivo fixo que o hyprlock le
PLACEHOLDER="$HOME/.config/hypr/assets/transparent.png"
CACHE="/tmp/hyprlock-cover"                     # cache por-URL (evita rebaixar)
INTERVAL=3
mkdir -p "$OUT_DIR" "$CACHE"

# playerctl com timeout, p/ um player MPRIS travado nao pendurar o loop do daemon.
pctl() { timeout 1 playerctl "$@" 2>/dev/null; }

is_image() {
  [ -s "$1" ] || return 1
  sig=$(od -An -tx1 -N4 "$1" 2>/dev/null | tr -d ' \n')
  case "$sig" in
    ffd8ff*|89504e47|47494638|52494646|424d*) return 0 ;;
    *) return 1 ;;
  esac
}

pick_player() {
  local players p
  players="$(pctl -l 2>/dev/null)" || return 1
  [ -z "$players" ] && return 1
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    [ "$(pctl -p "$p" status 2>/dev/null)" = "Playing" ] && { printf '%s' "$p"; return 0; }
  done <<< "$players"
  if printf '%s\n' "$players" | grep -qx spotify; then
    [ -n "$(pctl -p spotify metadata title 2>/dev/null)" ] && { printf spotify; return 0; }
  fi
  return 1
}

# grava SRC em OUT de forma atomica (hyprlock nunca le arquivo pela metade)
publish() { cp -f "$1" "$OUT.tmp" 2>/dev/null && mv -f "$OUT.tmp" "$OUT"; }

last_url="__init__"
while :; do
  player="$(pick_player)" || player=""
  url=""
  [ -n "$player" ] && url="$(pctl -p "$player" metadata mpris:artUrl 2>/dev/null)"

  if [ "$url" != "$last_url" ]; then
    last_url="$url"
    if [ -z "$url" ]; then
      publish "$PLACEHOLDER"
    else
      hash="$(printf '%s' "$url" | md5sum | cut -c1-12)"
      dest="$CACHE/$hash.img"
      if ! { [ -s "$dest" ] && is_image "$dest"; }; then
        # ainda nao temos essa capa em cache -> baixa e valida
        case "$url" in
          http://*|https://*)
            curl -sfL --max-time 8 "$url" -o "$dest.part" 2>/dev/null \
              && is_image "$dest.part" && mv -f "$dest.part" "$dest" || rm -f "$dest.part"
            ;;
          file://*)
            cp -f "${url#file://}" "$dest.part" 2>/dev/null \
              && is_image "$dest.part" && mv -f "$dest.part" "$dest" || rm -f "$dest.part"
            ;;
        esac
      fi
      if [ -s "$dest" ] && is_image "$dest"; then publish "$dest"; else publish "$PLACEHOLDER"; fi
    fi
  fi
  sleep "$INTERVAL"
done
