#!/usr/bin/env bash
# Relogio da Waybar em pt-BR (garantido via LC_TIME).
# Ex.: "Domingo, 14 de junho  15:51"
LC_TIME=pt_BR.UTF-8 date '+%A, %d de %B  %H:%M' | sed 's/./\U&/'
