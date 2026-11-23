#!/usr/bin/python3
"""rofi-windows.sh — aba "Janelas" do launcher (SUPER + Espaco): janelas abertas com PID, app, icone e kill.

Substitui o modo `window` nativo do rofi, que so mostrava classe + titulo. Agora cada linha traz:
    [icone] App   titulo da janela          PID 1234 · 312 MB · ws 2 · flutuante/fixada/tela cheia
Ordem: janela focada primeiro, depois a ultima que voce usou (como um alt-tab).

  Enter numa linha          foca a janela (troca de workspace/monitor se preciso)
  COMANDOS: escreva `>` e o comando; rode com Ctrl+Enter. O `>` faz o rofi PARAR de filtrar por aquilo que vem depois,
  entao a lista continua na tela. O texto ANTES do `>` ainda filtra (e escolhe o alvo):
      zen >kill!            filtra "zen" e mata o unico processo que combina
      >kill! 1741909        alvo explicito pelo PID (a lista segue visivel para voce ler os PIDs)
      >kill zen             alvo explicito pelo nome
    kill  <alvo>            encerra a FORCA (kill -9 no processo e nos filhos)
    kill! <alvo>            igual, mas confirma quando o PID tem VARIAS janelas (ex.: 2 terminais = 1 processo)
    term  <alvo>            pede com educacao (SIGTERM)
    close <alvo>            fecha so a janela (o app decide), sem matar o processo
    qualquer outra coisa    roda como comando de shell (igual a aba Comandos; `t cmd` abre num terminal)
  <alvo> = PID ou nome do app/classe (nunca o titulo). Sem alvo explicito vale o filtro antes do `>`. Se casar com
  mais de um processo, NADA e morto: ele lista os candidatos. So alvos que aparecem na lista sao aceitos.

Protocolo do modo script do rofi: ROFI_RETV 0 = abrir; 1/2 = linha escolhida (ROFI_INFO) ou texto digitado.
Imprimir NADA fecha o rofi (usado apos focar). Apos kill/term/close a lista e reexibida com o resultado.
"""
import configparser
import glob
import json
import os
import re
import signal
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
ICON = chr(0xF2D0)                       # rotulo da aba (glifo "janela"), gerado em runtime
DIM = "#8a8a8f"
HINT = 'Enter foca · filtro >kill! + Ctrl+Enter, ou filtro > kill! (com espaço) + Enter · >term · >close'


def out(s=""):
    sys.stdout.write(s + "\n")


def opt(key, val):
    sys.stdout.write(f"\0{key}\x1f{val}\n")


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def hypr(*args):
    try:
        return json.loads(subprocess.run(["hyprctl", *args, "-j"], capture_output=True, text=True, timeout=3).stdout)
    except Exception:
        return []


# ---------------------------------------------------------------- app -> (nome bonito, icone)
def desktop_index():
    idx = {}
    for path in glob.glob("/usr/share/applications/*.desktop") + glob.glob(HOME + "/.local/share/applications/*.desktop"):
        cp = configparser.RawConfigParser(strict=False, interpolation=None)
        cp.optionxform = str
        try:
            cp.read(path, encoding="utf-8")
            e = cp["Desktop Entry"]
        except Exception:
            continue
        name, icon = e.get("Name", ""), e.get("Icon", "")
        keys = {os.path.basename(path)[:-8].lower()}
        if e.get("StartupWMClass"):
            keys.add(e["StartupWMClass"].lower())
        m = re.match(r"\s*(?:env\s+\S+=\S+\s+)*(\S+)", e.get("Exec", ""))
        if m:
            keys.add(os.path.basename(m.group(1)).lower())
        for k in keys:
            idx.setdefault(k, (name, icon))
    return idx


def app_info(idx, cls, icls):
    for c in (cls, icls):
        c = (c or "").lower()
        if c in idx:
            return idx[c]
    for c in (cls, icls):                # ex.: classe "zen" x desktop "zen-browser"
        c = (c or "").lower()
        for k, v in idx.items():
            if c and (k.startswith(c + "-") or c.startswith(k + "-")):
                return v
    return ((cls or icls or "?").split(".")[-1], (cls or "").lower())


# ---------------------------------------------------------------- janelas
def rss_mb(pid):
    try:
        for line in open(f"/proc/{pid}/status"):
            if line.startswith("VmRSS"):
                return int(line.split()[1]) // 1024
    except Exception:
        pass
    return 0


def windows():
    idx = desktop_index()
    cs = [c for c in hypr("clients") if c.get("mapped")]
    per_pid = {}
    for c in cs:
        per_pid[c["pid"]] = per_pid.get(c["pid"], 0) + 1
    res = []
    for c in sorted(cs, key=lambda c: c.get("focusHistoryID", 99)):
        name, icon = app_info(idx, c["class"], c.get("initialClass"))
        res.append({"addr": c["address"], "pid": c["pid"], "app": name, "icon": icon, "title": c["title"],
                    "cls": c["class"], "ws": c["workspace"]["name"], "mem": rss_mb(c["pid"]),
                    "flags": [f for f, on in (("flutuante", c["floating"]), ("fixada", c["pinned"]),
                                              ("tela cheia", c["fullscreen"] > 0)) if on],
                    "siblings": per_pid[c["pid"]]})
    return res


def listing(note=None):
    opt("markup-rows", "true")
    opt("prompt", ICON)
    # UMA linha so: uma quebra de linha na mensagem faria o rofi tratar o resto como item da lista
    opt("message", esc(note) if note else esc(HINT))
    ws = windows()
    if not ws:
        out("  — nenhuma janela aberta\0nonselectable\x1ftrue")
    for w in ws:
        # o que importa vem PRIMEIRO (app, PID); o titulo vai por ultimo porque e o que o rofi corta
        bits = [f"PID {w['pid']}"]
        if w["mem"]:
            bits.append(f"{w['mem']} MB")
        bits.append(f"ws {w['ws']}")
        bits += w["flags"]
        if w["siblings"] > 1:
            bits.append(f"{w['siblings']} janelas")
        title = w["title"] if len(w["title"]) <= 70 else w["title"][:69] + "…"
        row = (f"<b>{esc(w['app'])}</b>  <span foreground=\"{DIM}\">{esc(' · '.join(bits))}</span>  {esc(title)}")
        sys.stdout.write(f"{row}\0icon\x1f{w['icon']}\x1finfo\x1fwin:{w['addr']}\n")


# ---------------------------------------------------------------- acoes
def focus(addr):
    # depois que o rofi fechar, senao o foco volta para a janela anterior
    subprocess.Popen(["sh", "-c", f"sleep 0.15; hyprctl dispatch 'hl.dsp.focus({{ window = \"address:{addr}\" }})'"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, start_new_session=True)


def descendants(pid):
    seen, todo = [], [pid]
    while todo:
        p = todo.pop()
        try:
            kids = subprocess.run(["pgrep", "-P", str(p)], capture_output=True, text=True).stdout.split()
        except Exception:
            kids = []
        for k in map(int, kids):
            if k not in seen:
                seen.append(k)
                todo.append(k)
    return seen


def kill_tree(pid, sig):
    """envia `sig` ao processo e a todos os descendentes (filhos primeiro: nao sobra helper orfao).
    Retorna (lista de filhos atingidos, erro|None)."""
    kids = descendants(pid)
    for p in reversed(kids):
        try:
            os.kill(p, sig)
        except (ProcessLookupError, PermissionError):
            pass
    try:
        os.kill(pid, sig)
    except ProcessLookupError:
        return kids, f"PID {pid} já não existe"
    except PermissionError:
        return kids, f"sem permissão para matar o PID {pid}"
    return kids, None


def row_text(w):
    return " ".join([w["app"], w["cls"], w["title"], f"PID {w['pid']}", w["ws"], *w["flags"]]).lower()


def by_filter(filt, ws):
    toks = filt.lower().split()
    return [w for w in ws if toks and all(t in row_text(w) for t in toks)]


def resolve(arg, ws, filt=""):
    """alvo -> (lista de janelas, erro). Sem `arg`, usa o filtro digitado antes do `>`."""
    arg = arg.strip()
    if not arg and filt.strip():
        m = by_filter(filt, ws)
        if not m:
            return [], f"nenhuma janela combina com o filtro '{filt.strip()}'"
        pids = sorted({w["pid"] for w in m})
        if len(pids) > 1:
            names = "; ".join(f"{next(w['app'] for w in m if w['pid'] == p)} PID {p}" for p in pids)
            return [], f"o filtro '{filt.strip()}' combina com {len(pids)} processos ({names}) — afine o filtro ou use o PID"
        return m, None
    if not arg:
        return [], "faltou o alvo: filtre a lista antes do > ou diga PID/nome (ex.: >kill! 1234)"
    if re.fullmatch(r"\d+", arg):
        m = [w for w in ws if w["pid"] == int(arg)]
        return (m, None) if m else ([], f"PID {arg} não está na lista de janelas (só alvos listados são aceitos)")
    a = arg.lower()
    # SO app e classe: casar com o titulo mataria o app errado (ex.: aba do navegador falando de outro app)
    m = [w for w in ws if a in w["app"].lower() or a in w["cls"].lower()]
    if not m:
        return [], f"nenhuma janela combina com '{arg}'"
    pids = sorted({w["pid"] for w in m})
    if len(pids) > 1:
        names = "; ".join(f"{next(w['app'] for w in m if w['pid'] == p)} PID {p}" for p in pids)
        return [], f"'{arg}' combina com {len(pids)} processos ({names}) — use o PID"
    return m, None


def free_command(cmd):
    """qualquer outro comando: roda como na aba Comandos (rofi-cmds.sh --run)"""
    r = subprocess.run([os.path.join(os.path.dirname(os.path.abspath(__file__)), "rofi-cmds.sh"), "--run", cmd],
                       capture_output=True, text=True)
    return ("✗ " + r.stdout.strip()) if r.returncode else f"✓ executado: {cmd}"


def split_cmd(text):
    """'zen >kill! 12' -> ('zen', 'kill! 12'); sem '>' -> (texto, None)"""
    if ">" not in text:
        return text, None
    i = text.index(">")
    return text[:i].strip(), text[i + 1:].strip()


def run_command(text):
    filt, cmd = split_cmd(text)
    if cmd is None:
        return "use > para escrever um comando (ex.: zen >kill!  ou  >kill! 1234) e Ctrl+Enter"
    if not cmd:
        return "comando vazio depois do >"
    m = re.match(r"(kill!|kill|term|close)(?:\s+(.*))?$", cmd, re.I)
    if not m:
        return free_command(cmd)
    verb, arg = m.group(1).lower(), m.group(2) or ""
    ws = windows()
    targets, err = resolve(arg, ws, filt)
    if err:
        return "✗ " + err
    w = targets[0]
    pid, n = w["pid"], w["siblings"]
    if verb == "close":
        for t in targets:
            subprocess.run(["hyprctl", "dispatch", f"hl.dsp.window.close({{ window = \"address:{t['addr']}\" }})"],
                           capture_output=True)
        return f"✓ pedi para fechar {len(targets)} janela(s) de {w['app']}"
    if verb == "kill" and n > 1:
        return (f"⚠ PID {pid} ({w['app']}) tem {n} janelas no MESMO processo — matar fecharia todas. "
                f"Se é isso que você quer: kill! {pid}")
    sig = signal.SIGTERM if verb == "term" else signal.SIGKILL
    kids, err = kill_tree(pid, sig)
    if err:
        return "✗ " + err
    time.sleep(0.5)                       # deixa o Hyprland atualizar a lista
    nome = "kill -9" if sig == signal.SIGKILL else "SIGTERM"
    return f"✓ {nome} em {w['app']} (PID {pid}" + (f", +{len(kids)} filhos)" if kids else ")")


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--cmd":      # usado pelo despachante (abas nativas) e pela aba Comandos
        print(run_command(sys.argv[2]))
        return
    retv = os.environ.get("ROFI_RETV", "0")
    info = os.environ.get("ROFI_INFO", "")
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    if retv in ("1", "2"):
        if info.startswith("win:") and retv == "1":
            focus(info[4:])
            return                        # nada impresso -> o rofi fecha
        if arg.strip():
            listing(run_command(arg))     # texto digitado (Ctrl+Enter): precisa do `>`
            return
    listing()


if __name__ == "__main__":
    main()
