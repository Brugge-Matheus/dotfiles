#!/usr/bin/env python3
"""md2pdf.py — gera um PDF de consulta a partir de um manual em Markdown (o .md e a fonte da verdade).

Uso:
    python3 docs/md2pdf.py docs/gcc-manual.md docs/gcc-manual.pdf

Suporta o subconjunto de Markdown usado nos manuais deste repo:
  # titulo | _subtitulo_ | paragrafo de abertura | ## secao (entra no sumario) | ### subsecao
  paragrafos com **negrito** e `codigo` | tabelas | blocos ``` ``` | notas "> **Titulo.** texto"
Requer: reportlab (pip install reportlab). Usa so as fontes padrao (Latin-1: acentos do portugues ok;
nao use setas/emoji nos manuais).
"""
import re
import sys
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Frame, PageBreak, PageTemplate, Paragraph,
                                Preformatted, Spacer, Table, TableStyle)
from reportlab.platypus.tableofcontents import TableOfContents

ACC = colors.HexColor("#8a3b00")
INK = colors.HexColor("#1d2330")
MUTE = colors.HexColor("#5b6472")
CODEBG = colors.HexColor("#f2f4f7")
WARNBG = colors.HexColor("#fff4e0")

base = ParagraphStyle("b", fontName="Helvetica", fontSize=10, leading=14.5, textColor=INK, spaceAfter=5)
h1s = ParagraphStyle("h1", parent=base, fontName="Helvetica-Bold", fontSize=17, leading=21, textColor=ACC,
                     spaceBefore=8, spaceAfter=8)
h2s = ParagraphStyle("h2", parent=base, fontName="Helvetica-Bold", fontSize=12, leading=16, spaceBefore=8, spaceAfter=4)
codes = ParagraphStyle("c", fontName="Courier", fontSize=8.4, leading=11, textColor=INK, backColor=CODEBG,
                       borderPadding=(5, 6, 5, 6), spaceBefore=3, spaceAfter=9, leftIndent=6, rightIndent=6)
small = ParagraphStyle("s", parent=base, fontSize=8.5, leading=11.5, textColor=MUTE)
cell = ParagraphStyle("cell", parent=base, fontSize=8.8, leading=11.8, spaceAfter=0)
cellb = ParagraphStyle("cellb", parent=cell, fontName="Helvetica-Bold")


def inline(t):
    t = escape(t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"(?<![\w*])_(.+?)_(?![\w*])", r"<i>\1</i>", t)
    t = re.sub(r"`(.+?)`", r"<font face='Courier'>\1</font>", t)
    return t


def plain(t):
    return re.sub(r"[`*]", "", t)


def parse(md):
    """-> (titulo, subtitulo, intro, blocos). Blocos: (tipo, ...)."""
    lines = md.splitlines()
    titulo = sub = intro = ""
    blocos, i = [], 0
    # cabecalho: "# titulo", "_subtitulo_", paragrafo de abertura
    while i < len(lines) and not lines[i].startswith("## "):
        l = lines[i]
        if l.startswith("# ") and not titulo:
            titulo = l[2:].strip()
        elif re.fullmatch(r"_.+_", l.strip()) and not sub:
            sub = l.strip()[1:-1]
        elif l.strip() and not intro:
            intro = l.strip()
        i += 1
    while i < len(lines):
        l = lines[i]
        if l.startswith("## "):
            blocos.append(("h1", l[3:].strip())); i += 1
        elif l.startswith("### "):
            blocos.append(("h2", l[4:].strip())); i += 1
        elif l.startswith("```"):
            i += 1; cod = []
            while i < len(lines) and not lines[i].startswith("```"):
                cod.append(lines[i]); i += 1
            i += 1
            blocos.append(("code", "\n".join(cod).replace("\t", "    ")))
        elif l.startswith("|"):
            tab = []
            while i < len(lines) and lines[i].startswith("|"):
                tab.append(lines[i]); i += 1
            rows = [[c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", r.strip())[1:-1]] for r in tab]
            rows = [r for k, r in enumerate(rows) if not (k == 1 and all(re.fullmatch(r":?-+:?", c) for c in r))]
            blocos.append(("table", rows[0], rows[1:]))
        elif l.startswith("> "):
            txt = []
            while i < len(lines) and lines[i].startswith(">"):
                txt.append(lines[i].lstrip("> ").rstrip()); i += 1
            t = " ".join(x for x in txt if x)
            m = re.match(r"\*\*(.+?)\.\*\*\s*(.*)", t)
            blocos.append(("note", m.group(1) if m else "Nota", m.group(2) if m else t))
        elif l.strip():
            par = [l.strip()]; i += 1
            while i < len(lines) and lines[i].strip() and not re.match(r"(#|```|\||> )", lines[i]):
                par.append(lines[i].strip()); i += 1
            blocos.append(("p", " ".join(par)))
        else:
            i += 1
    return titulo, sub, intro, blocos


def larguras(head, rows, total):
    """colunas proporcionais ao conteudo (com minimo), somando `total` mm."""
    n = len(head)
    peso = [max(8, min(60, max(len(plain(r[c])) if c < len(r) else 0 for r in [head] + rows))) for c in range(n)]
    s = sum(peso)
    return [max(18, total * p / s) * mm for p in peso]


class Doc(BaseDocTemplate):
    def __init__(self, path, titulo, **k):
        super().__init__(path, pagesize=A4, title=plain(titulo), author="dotfiles", **k)
        self.rodape = plain(titulo)
        f = Frame(18 * mm, 17 * mm, A4[0] - 36 * mm, A4[1] - 34 * mm, id="f")
        self.addPageTemplates([PageTemplate(id="p", frames=[f], onPage=self.deco)])

    def deco(self, c, d):
        c.saveState()
        c.setFont("Helvetica", 8)
        c.setFillColor(MUTE)
        c.drawString(18 * mm, 9.5 * mm, self.rodape + " - manual de bolso")
        c.drawRightString(A4[0] - 18 * mm, 9.5 * mm, str(d.page))
        c.setStrokeColor(ACC)
        c.setLineWidth(1.2)
        c.line(18 * mm, A4[1] - 13 * mm, A4[0] - 18 * mm, A4[1] - 13 * mm)
        c.restoreState()

    def afterFlowable(self, fl):
        if isinstance(fl, Paragraph) and fl.style.name == "h1":
            key = "h%d_%d" % (self.page, id(fl) % 100000)
            self.canv.bookmarkPage(key)
            self.notify("TOCEntry", (0, fl.getPlainText(), self.page, key))


def main(src, dst):
    titulo, sub, intro, blocos = parse(open(src, encoding="utf-8").read())
    W = A4[0] - 36 * mm
    S = [Spacer(1, 40 * mm),
         Paragraph(inline(titulo), ParagraphStyle("t", parent=h1s, fontSize=30, leading=36)),
         Spacer(1, 5 * mm),
         Paragraph(inline(sub), ParagraphStyle("st", parent=base, fontSize=13, leading=19, textColor=MUTE)),
         Spacer(1, 12 * mm),
         Paragraph(inline(intro), small),
         PageBreak()]
    toc = TableOfContents()
    toc.levelStyles = [ParagraphStyle("toc0", parent=base, fontSize=10.5, leading=17)]
    S += [Paragraph("Sumário", ParagraphStyle("tt", parent=h1s)), toc, PageBreak()]
    for b in blocos:
        k = b[0]
        if k == "h1":
            S.append(CondPageBreak(60 * mm))   # titulo de secao nunca fica orfao no fim da pagina
            S.append(Paragraph(inline(b[1]), h1s))
        elif k == "h2":
            S.append(Paragraph(inline(b[1]), h2s))
        elif k == "p":
            S.append(Paragraph(inline(b[1]), base))
        elif k == "code":
            S.append(Preformatted(b[1], codes))
        elif k == "table":
            head, rows = b[1], b[2]
            data = [[Paragraph(inline(c), cellb) for c in head]]
            for r in rows:
                data.append([Paragraph(inline(c), cell) for c in r + [""] * (len(head) - len(r))])
            tb = Table(data, colWidths=larguras(head, rows, W / mm), repeatRows=1)
            tb.setStyle(TableStyle([
                ("VALIGN", (0, 0), (-1, -1), "TOP"), ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#c9ced6")),
                ("LEFTPADDING", (0, 0), (-1, -1), 5), ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#f3e6dc"))]))
            S += [tb, Spacer(1, 9)]
        elif k == "note":
            tb = Table([[Paragraph("<b>%s.</b> %s" % (escape(b[1]), inline(b[2])), cell)]], colWidths=[W])
            tb.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), WARNBG),
                                    ("LINEBEFORE", (0, 0), (0, -1), 3, colors.HexColor("#e0a030")),
                                    ("LEFTPADDING", (0, 0), (-1, -1), 8), ("TOPPADDING", (0, 0), (-1, -1), 5),
                                    ("BOTTOMPADDING", (0, 0), (-1, -1), 6)]))
            S += [tb, Spacer(1, 8)]
    Doc(dst, titulo).multiBuild(S)
    print("ok:", dst)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
