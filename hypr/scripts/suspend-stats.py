#!/usr/bin/env python3
"""suspend-stats.py — estatistica de falhas ao ACORDAR da suspensao, a partir do journal.

Uma FALHA = o ultimo ciclo de suspensao de um boot, quando o boot terminou em ate 5 min depois
de acordar (ou nunca acordou no log) E foi por botao de energia ("Power key pressed") ou fim
abrupto. Corresponde ao caso "acordei mas a tela ficou preta e tive que desligar pelo botao".

Uso:
    suspend-stats.py                      # todo o historico
    suspend-stats.py --desde 2026-11-21   # so ciclos a partir de uma data (p/ comparar ANTES x DEPOIS
                                          #  de uma mudanca, ex.: i915.enable_dc=0)

Demora ~1-2 min (le o journal de todos os boots).
"""
import argparse
import collections
import datetime as dt
import re
import subprocess


def jc(*a):
    return subprocess.run(["journalctl", *a, "--no-pager"], capture_output=True, text=True).stdout.splitlines()


def ts(line):
    m = re.match(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+)", line)
    return dt.datetime.fromisoformat(m.group(1)) if m else None


# -g casa so o TEXTO da mensagem (nao o nome do programa que a emitiu)
PAT = (r"PM: suspend (entry|exit)|Lid (opened|closed)|Power key pressed|Suspend key pressed|"
       r"System is (powering down|rebooting)|Shutting down|Journal stopped|"
       r"Reached target .*(Shutdown|Power-Off|Reboot)|Stopping Journal Service")
FIM = re.compile(r"System is (powering down|rebooting)|Shutting down|Journal stopped|"
                 r"Reached target .*(Shutdown|Power-Off|Reboot)|Stopping Journal Service")


def coletar():
    ciclos = []
    for boot in [l.split()[0] for l in jc("--list-boots")]:
        linhas = jc("-b", boot, "-o", "short-iso-precise", "-g", PAT)
        ultima = jc("-b", boot, "-o", "short-iso-precise", "-n", "1")
        if not ultima:
            continue
        fim = ts(ultima[0])
        ev = [(ts(l), l) for l in linhas if ts(l)]
        fim_normal = any(FIM.search(l) for _, l in ev)
        entradas = [t for t, l in ev if "suspend entry" in l]
        saidas = [t for t, l in ev if "suspend exit" in l]
        do_boot = []
        for te in entradas:
            tx = next((t for t in saidas if t > te), None)
            inicio = "idle/outro"
            for t, l in reversed(ev):
                if te - dt.timedelta(seconds=15) <= t <= te:
                    if "Lid closed" in l:
                        inicio = "tampa"; break
                    if "Suspend key" in l:
                        inicio = "tecla suspender"; break
                    if "Power key" in l:
                        inicio = "botao energia"; break
            acordou = "tecla/outro"
            pk = None
            if tx is not None:
                if any(tx - dt.timedelta(seconds=3) <= t <= tx + dt.timedelta(seconds=3) and "Lid opened" in l
                       for t, l in ev):
                    acordou = "tampa"
                pk = next((t for t, l in ev if t > tx and "Power key pressed" in l), None)
            do_boot.append(dict(boot=boot, te=te, tx=tx, dur=(tx - te).total_seconds() if tx else None,
                                inicio=inicio, acordou=acordou,
                                depois=((fim - tx).total_seconds() if tx else (fim - te).total_seconds()),
                                fim_normal=fim_normal, pk=pk is not None))
        if do_boot:
            do_boot.sort(key=lambda c: c["te"])
            ultimo = do_boot[-1]
            ultimo["falha"] = ultimo["tx"] is None or (ultimo["depois"] <= 300 and (ultimo["pk"] or not ultimo["fim_normal"]))
            for c in do_boot[:-1]:
                c["falha"] = False
            ciclos += do_boot
    return ciclos


def faixa(d):
    if d is None:
        return "nunca acordou no log"
    return ("<1 min" if d < 60 else "1-10 min" if d < 600 else "10 min-2 h" if d < 7200
            else "2-8 h" if d < 28800 else ">8 h")


def tabela(titulo, ciclos, chave, ordem=None):
    tot, fal = collections.Counter(), collections.Counter()
    for c in ciclos:
        k = chave(c)
        tot[k] += 1
        fal[k] += c["falha"]
    print(f"\n{titulo}")
    for k in (ordem or sorted(tot)):
        if tot[k]:
            print(f"  {k:<22} {fal[k]:>3} / {tot[k]:<4} = {100 * fal[k] / tot[k]:5.1f}%")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--desde", help="AAAA-MM-DD: considera so ciclos a partir desta data")
    args = ap.parse_args()
    ciclos = coletar()
    if args.desde:
        d0 = dt.datetime.fromisoformat(args.desde)
        ciclos = [c for c in ciclos if c["te"] >= d0]
    n = len(ciclos)
    f = sum(c["falha"] for c in ciclos)
    if not n:
        print("nenhum ciclo de suspensao no periodo")
        return
    print(f"ciclos de suspensao: {n} | falhas (tela preta ao acordar): {f} = {100 * f / n:.1f}%")
    tabela("por DURACAO do sono:", ciclos, lambda c: faixa(c["dur"]),
           ["<1 min", "1-10 min", "10 min-2 h", "2-8 h", ">8 h", "nunca acordou no log"])
    tabela("por como ACORDOU:", ciclos, lambda c: c["acordou"])
    tabela("por como COMECOU:", ciclos, lambda c: c["inicio"])
    print("\n  (com ~17% de falha em sonos longos, 20 ciclos longos sem NENHUMA falha ja e evidencia forte:"
          " 0.83^20 = 2,4% de chance de acontecer por sorte)")


if __name__ == "__main__":
    main()
