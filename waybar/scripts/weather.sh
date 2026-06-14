#!/usr/bin/env bash
# Widget de clima (wttr.in, sem API key) para a Waybar (return-type: json).
# Fonte 100% ASCII: glifos vem de chr(codepoint) no python.
# Os dados vao por env var (WTTR) porque o heredoc ocupa o stdin do python.
export WTTR="$(curl -s -m 8 'https://wttr.in/?format=j1' 2>/dev/null)"

python3 - <<'PY'
import json, os
try:
    d = json.loads(os.environ.get("WTTR", ""))
    cur = d["current_condition"][0]
    today = d["weather"][0]
    temp  = cur["temp_C"]
    feels = cur["FeelsLikeC"]
    desc  = cur["weatherDesc"][0]["value"].strip()
    tmin, tmax = today["mintempC"], today["maxtempC"]
    dl = desc.lower()
    if   "thunder" in dl:                                   ic = chr(0xF0E7)  # raio
    elif "snow" in dl or "sleet" in dl or "ice" in dl:      ic = chr(0xF2DC)  # floco
    elif "rain" in dl or "drizzle" in dl or "shower" in dl: ic = chr(0xF043)  # gota
    elif any(x in dl for x in ("cloud","overcast","mist","fog","haze")): ic = chr(0xF0C2)  # nuvem
    else:                                                   ic = chr(0xF185)  # sol
    print(json.dumps({
        "text": f"{ic} {temp}°C",
        "tooltip": f"{desc}\nMin {tmin}°   Max {tmax}°\nSensacao {feels}°",
    }))
except Exception:
    print(json.dumps({"text": chr(0xF185), "tooltip": "Clima indisponivel"}))
PY
