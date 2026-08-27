#!/usr/bin/env python3
"""从 slot-chain-spec.md 生成学术论文式 LaTeX 与 PDF（XeLaTeX + ctex，单栏）。

用法:
    python3 build-pdf.py            # 生成 tex/main.tex 并编译出 slot-chain-spec.pdf
    python3 build-pdf.py --tex-only # 只生成 tex，不编译
    python3 build-pdf.py --check    # 重新生成并比对，tex 与 markdown 不一致则非零退出
                                    # （漂移防护：改 md 后必须重新生成并提交）

两项结构性转换（其余为纯排版）：
  1. 评审注记外置——正文中形如"（评审 r39）""（独立审核第 5 轮高危 1——…）"的出处括注
     被抽出为尾注，集中到附录 E；正文只保留规范性陈述。出处在后、实质内容在前的括注
     只搬出处部分，保住参数值等规范内容（见 split_annotation）。
  2. mermaid 图 → TikZ 灰阶图（tex/figures.tex，按出现顺序 1..10 对应 fig:1..fig:10）。
"""

import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "slot-chain-spec.md")
TEXDIR = os.path.join(HERE, "tex")
MAIN = os.path.join(TEXDIR, "main.tex")
FIGS = os.path.join(TEXDIR, "figures.tex")
PDF_OUT = os.path.join(HERE, "slot-chain-spec.pdf")

# ---------------------------------------------------------------------------
# 1. 评审注记的识别与抽取
# ---------------------------------------------------------------------------
# 出处标记：评审轮次 rNN、独立审核轮次、外部评审者名、所有者决定、版本号
MARK = re.compile(
    r"评审|独立审核|DeepSeek|Codex|所有者|"
    r"(?<![A-Za-z])r\d{1,2}(?:-\d)?(?![\d])|v1\.\d+"
)
# 出处从这里开始：标记本身，或"标记前最近的分隔符"
SEPS = "，；,;：:—"


def split_annotation(inner: str):
    """把括注内容切成 (留在正文的部分, 移入尾注的部分)。

    以出处开头 → 整条移入尾注（正文不留）；
    实质内容在前、出处在后 → 从出处前最近的分隔符切开，只搬后半。
    """
    m = MARK.search(inner)
    if not m:
        return inner, None
    # 出处出现在开头附近（前 8 个字符内）→ 整条是出处/出处引出的论证
    if m.start() <= 8:
        return None, inner
    # 否则回退到出处前最近的分隔符
    cut = -1
    for i in range(m.start() - 1, -1, -1):
        if inner[i] in SEPS:
            cut = i
            break
    if cut <= 0:
        return None, inner  # 找不到干净切点：整条移走，避免切碎句子
    keep = inner[:cut].rstrip(SEPS + " ")
    note = inner[cut + 1:].strip()
    if not keep:
        return None, inner
    if not note:
        return keep, None
    return keep, note


class NoteStore:
    """尾注仓库：正文插入 \\revnote{n}，附录 E 按序输出。"""

    def __init__(self):
        self.notes = []       # (section_label, text)
        self.section = "前言"

    def add(self, text: str) -> str:
        self.notes.append((self.section, text.strip()))
        return "\\revnote{%d}" % len(self.notes)


def extract_annotations(text: str, store: NoteStore) -> str:
    """就地替换一行（或一段）中的出处括注。假定代码块已被保护在外。"""
    out, pos = [], 0
    for m in re.finditer(r"（([^（）]*)）", text):
        inner = m.group(1)
        keep, note = split_annotation(inner)
        if note is None:
            continue
        out.append(text[pos:m.start()])
        marker = store.add(note)
        out.append(("（%s）" % keep if keep else "") + marker)
        pos = m.end()
    out.append(text[pos:])
    return "".join(out)


# ---------------------------------------------------------------------------
# 2. 行内 Markdown → LaTeX
# ---------------------------------------------------------------------------
SPECIALS = {
    "\\": r"\textbackslash{}", "{": r"\{", "}": r"\}", "$": r"\$",
    "&": r"\&", "#": r"\#", "^": r"\textasciicircum{}", "_": r"\_",
    "~": r"\textasciitilde{}", "%": r"\%",
}


def esc(s: str) -> str:
    return "".join(SPECIALS.get(c, c) for c in s)


def sec_ref(m):
    """§5.6 / §12 → 可点击交叉引用。"""
    num = m.group(1)
    return "\\hyperref[sec:%s]{\\S%s}" % (num, num)


def inline(text: str, store: NoteStore = None) -> str:
    if store is not None:
        text = extract_annotations(text, store)
    # 保护行内代码
    spans = []

    def stash(m):
        spans.append(m.group(1))
        return "\x00%d\x00" % (len(spans) - 1)

    text = re.sub(r"`([^`]+)`", stash, text)
    # 保护已生成的尾注宏
    notes = []

    def stash_note(m):
        notes.append(m.group(0))
        return "\x01%d\x01" % (len(notes) - 1)

    text = re.sub(r"\\revnote\{\d+\}", stash_note, text)
    # 链接：[文本](目标) —— 本地文件链接降级为等宽文件名
    text = re.sub(r"\[`?([^\]`]+)`?\]\(([^)]+)\)",
                  lambda m: "\x02%s\x02" % m.group(1), text)
    text = esc(text)
    # 粗体（正文保留的是行首标签式加粗）
    text = re.sub(r"\*\*([^*]+?)\*\*", r"\\textbf{\1}", text)
    # 章节引用
    text = re.sub(r"§\s*(\d+(?:\.\d+)?)", sec_ref, text)
    text = re.sub(r"附录 ([A-E])(?![\w-])",
                  lambda m: "\\hyperref[app:%s]{附录~%s}" % (m.group(1), m.group(1)), text)
    # 还原
    text = re.sub(r"\x02([^\x02]*)\x02", lambda m: "\\texttt{%s}" % esc(m.group(1)), text)
    text = re.sub(r"\x01(\d+)\x01", lambda m: notes[int(m.group(1))], text)
    text = re.sub(r"\x00(\d+)\x00",
                  lambda m: "\\texttt{%s}" % esc(spans[int(m.group(1))]), text)
    text = text.replace("**", "")          # 注记外置后可能留下的孤立粗体标记
    return text


# ---------------------------------------------------------------------------
# 3. 块级转换
# ---------------------------------------------------------------------------
def code_block(lines):
    """每行渲染为一个不可断的盒子 + 显式换行；空行也给 \\mbox{} 以免
    "There's no line here to end"。空格转不断空格以保留缩进。"""
    while lines and not lines[-1].strip():
        lines = lines[:-1]
    body = []
    for ln in lines:
        e = esc(ln).replace(" ", "~")
        body.append("\\mbox{}" + e + r"\\")
    return "\\begin{codeblock}\n" + "\n".join(body) + "\n\\end{codeblock}\n"


def table_block(rows, store):
    header = [c.strip() for c in rows[0].strip().strip("|").split("|")]
    data = [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows[2:]]
    n = len(header)
    # 首列窄、其余等分；总宽受 tabularx 控制以免超页
    if n == 2:
        spec = "p{0.30\\linewidth}X"
    elif n == 3:
        spec = "p{0.20\\linewidth}p{0.22\\linewidth}X"
    elif n == 4:
        spec = "p{0.20\\linewidth}p{0.11\\linewidth}p{0.11\\linewidth}X"
    else:
        spec = "X" * n
    out = ["\\begin{center}\\footnotesize",
           "\\begin{tabularx}{\\linewidth}{%s}" % spec, "\\toprule"]
    out.append(" & ".join("\\textbf{%s}" % inline(h, store) for h in header) + r" \\")
    out.append("\\midrule")
    for r in data:
        r = (r + [""] * n)[:n]
        out.append(" & ".join(inline(c, store) for c in r) + r" \\")
    out += ["\\bottomrule", "\\end{tabularx}", "\\end{center}"]
    return "\n".join(out) + "\n"


def heading_pair(title: str, store: NoteStore):
    """返回 (带注记标记的标题, 用于目录/书签的干净标题)。"""
    marked = extract_annotations(title, store)
    full = inline(marked)
    clean = re.sub(r"\\revnote\{\d+\}", "", full)
    return full, clean


def convert(md: str, store: NoteStore, figures_present: int):
    lines = md.split("\n")
    out = []
    i = 0
    fig_no = 0
    list_stack = []          # [(源缩进, 环境名)]；层级只逐级增长，避免空外层嵌套

    def close_lists(to_depth=0):
        while len(list_stack) > to_depth:
            _, kind = list_stack.pop()
            out.append("\\end{%s}" % kind)

    while i < len(lines):
        ln = lines[i]
        stripped = ln.strip()

        # --- 代码围栏 ---
        if stripped.startswith("```"):
            lang = stripped[3:].strip()
            j = i + 1
            buf = []
            while j < len(lines) and not lines[j].strip().startswith("```"):
                buf.append(lines[j])
                j += 1
            close_lists()
            if lang == "mermaid":
                fig_no += 1
                if fig_no <= figures_present:
                    out.append("\\FIGUREPLACEHOLDER%d" % fig_no)
            else:
                out.append(code_block(buf))
            i = j + 1
            continue

        # --- 标题 ---
        m = re.match(r"^(#{1,3})\s+(.*)$", stripped)
        if m:
            close_lists()
            if len(m.group(1)) == 1:      # H1 由标题页承担，正文不重复
                i += 1
                continue
            level, title = len(m.group(1)), m.group(2)
            num = re.match(r"^(\d+(?:\.\d+)?)[.、．]?\s+(.*)$", title)
            app = re.match(r"^附录 ([A-E])[:：]\s*(.*)$", title)
            if app:
                letter, rest = app.group(1), app.group(2)
                store.section = "附录 " + letter
                full, clean = heading_pair(rest, store)
                out.append("\\clearpage\\section*{附录 %s：%s}\\label{app:%s}"
                           % (letter, full, letter))
                out.append("\\addcontentsline{toc}{section}{附录 %s：%s}"
                           % (letter, clean))
                out.append("\\markboth{}{}")
            elif num:
                sec, rest = num.group(1), num.group(2)
                store.section = "\\S" + sec
                full, clean = heading_pair(rest, store)
                cmd = "section" if "." not in sec else "subsection"
                out.append("\\%s[%s]{%s}\\label{sec:%s}" % (cmd, clean, full, sec))
            else:
                full, clean = heading_pair(title, store)
                cmd = "section" if level <= 2 else "subsection"
                out.append("\\%s*{%s}" % (cmd, full))
                out.append("\\addcontentsline{toc}{%s}{%s}" % (cmd, clean))
            i += 1
            continue

        # --- 水平线 ---
        if stripped in ("---", "***", "___"):
            close_lists()
            i += 1
            continue

        # --- 引用块（设计说明） ---
        if stripped.startswith(">"):
            close_lists()
            buf = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                buf.append(re.sub(r"^\s*>\s?", "", lines[i]))
                i += 1
            para = merge_paragraph(buf)
            out.append("\\begin{designnote}\n%s\n\\end{designnote}\n"
                       % "\n\n".join(inline(p, store) for p in para))
            continue

        # --- 表格 ---
        if stripped.startswith("|") and i + 1 < len(lines) and \
                re.match(r"^\s*\|[\s:\-|]+\|\s*$", lines[i + 1]):
            close_lists()
            buf = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                buf.append(lines[i])
                i += 1
            out.append(table_block(buf, store))
            continue

        # --- 列表项 ---
        m = re.match(r"^(\s*)([-*+]|\d+\.)\s+(.*)$", ln)
        if m:
            indent = len(m.group(1))
            ordered = m.group(2)[0].isdigit()
            kind = "enumerate" if ordered else "itemize"
            # 收缩：关掉所有缩进更深的层级
            while list_stack and list_stack[-1][0] > indent:
                out.append("\\end{%s}" % list_stack.pop()[1])
            if not list_stack or list_stack[-1][0] < indent:
                # 展开：一次只开一层（LaTeX 不允许外层无 \item 就嵌套）
                list_stack.append((indent, kind))
                out.append("\\begin{%s}" % kind)
            elif list_stack[-1][1] != kind:
                # 同层但列表类型变了
                out.append("\\end{%s}" % list_stack.pop()[1])
                list_stack.append((indent, kind))
                out.append("\\begin{%s}" % kind)
            # 收集续行（缩进更深且非新列表项）
            buf = [m.group(3)]
            i += 1
            while i < len(lines):
                nxt = lines[i]
                if not nxt.strip():
                    break
                if re.match(r"^(\s*)([-*+]|\d+\.)\s+", nxt):
                    break
                if nxt.strip().startswith(("```", "|", ">", "#")):
                    break
                buf.append(nxt.strip())
                i += 1
            out.append("\\item %s" % inline(" ".join(buf), store))
            continue

        # --- 空行 ---
        if not stripped:
            i += 1
            continue

        # --- markdown 版目录：LaTeX 自带 \tableofcontents，跳过 ---
        if stripped.startswith("**目录**："):
            while i < len(lines) and lines[i].strip():
                i += 1
            continue

        # --- 普通段落 ---
        buf = []
        while i < len(lines) and lines[i].strip() and \
                not re.match(r"^(\s*)([-*+]|\d+\.)\s+", lines[i]) and \
                not lines[i].strip().startswith(("```", "|", ">", "#", "---")):
            buf.append(lines[i].strip())
            i += 1
        close_lists()
        out.append(inline(" ".join(buf), store) + "\n")

    close_lists()
    return "\n".join(out)


def merge_paragraph(lines):
    paras, cur = [], []
    for ln in lines:
        if ln.strip():
            cur.append(ln.strip())
        elif cur:
            paras.append(" ".join(cur))
            cur = []
    if cur:
        paras.append(" ".join(cur))
    return paras


# ---------------------------------------------------------------------------
# 4. 装配
# ---------------------------------------------------------------------------
PREAMBLE = r"""\documentclass[a4paper,11pt]{ctexart}
\usepackage[margin=2.6cm,bottom=3cm]{geometry}
\usepackage{fontspec}
\usepackage{amsmath,amssymb}
\usepackage{booktabs}
\usepackage{tabularx}
\usepackage{longtable}
\usepackage{tikz}
\usepackage{graphicx}
\usepackage{enumitem}
\usepackage{titlesec}
\usepackage{fancyhdr}
\usepackage[hidelinks,bookmarks=true]{hyperref}
\usepackage{newunicodechar}

% 拉丁正文字体缺这些符号：映射到数学模式（学术排版本就该如此）
\newunicodechar{≥}{\ensuremath{\geq}}
\newunicodechar{≤}{\ensuremath{\leq}}
\newunicodechar{≈}{\ensuremath{\approx}}
\newunicodechar{≠}{\ensuremath{\neq}}
\newunicodechar{⇒}{\ensuremath{\Rightarrow}}
\newunicodechar{⇔}{\ensuremath{\Leftrightarrow}}
\newunicodechar{∨}{\ensuremath{\vee}}
\newunicodechar{∧}{\ensuremath{\wedge}}
\newunicodechar{∞}{\ensuremath{\infty}}
\newunicodechar{×}{\ensuremath{\times}}
\newunicodechar{①}{\ensuremath{\circled{1}}}
\newunicodechar{②}{\ensuremath{\circled{2}}}
\newunicodechar{③}{\ensuremath{\circled{3}}}
\newunicodechar{④}{\ensuremath{\circled{4}}}
\newunicodechar{⑤}{\ensuremath{\circled{5}}}
\newunicodechar{⑥}{\ensuremath{\circled{6}}}
\newcommand{\circled}[1]{\text{\raisebox{0.2pt}{\textcircled{\raisebox{-0.7pt}{\scriptsize #1}}}}}

\setCJKmainfont{WenQuanYi Zen Hei}
\setCJKsansfont{WenQuanYi Zen Hei}
\setCJKmonofont{WenQuanYi Zen Hei}
\setmonofont{DejaVu Sans Mono}[Scale=0.85]

% --- 学术论文式版面 ---
\linespread{1.15}
\setlength{\parskip}{0.35em}
\setlist{itemsep=0.15em,parsep=0.15em,topsep=0.3em,leftmargin=1.4em}
\titleformat{\section}{\normalfont\large\bfseries}{\thesection}{0.7em}{}
\titleformat{\subsection}{\normalfont\normalsize\bfseries}{\thesubsection}{0.6em}{}
\titlespacing*{\section}{0pt}{1.6em}{0.7em}
\titlespacing*{\subsection}{0pt}{1.1em}{0.5em}

\pagestyle{fancy}\fancyhf{}
\renewcommand{\headrulewidth}{0.4pt}
\fancyhead[L]{\footnotesize Slot-Chain：基于槽位签名链的预确认协议}
\fancyhead[R]{\footnotesize 草案 @VERSION@}
\fancyfoot[C]{\footnotesize\thepage}

% --- 代码块 ---
\newenvironment{codeblock}
  {\par\smallskip\begingroup\ttfamily\scriptsize
   \begin{list}{}{\leftmargin=1.2em\rightmargin=0pt\parsep=0pt\itemsep=0pt
                  \topsep=0pt\partopsep=0pt\baselineskip=1.15\baselineskip}%
   \item[]\raggedright}
  {\end{list}\endgroup\smallskip}

% --- 设计说明（原 markdown 引用块）---
\newenvironment{designnote}
  {\par\smallskip\begin{list}{}{\leftmargin=1.1em\rightmargin=0.4em
      \parsep=0.3em\itemsep=0pt\topsep=0.3em}\item[]\small\itshape}
  {\end{list}\smallskip}

% --- 评审尾注标记 ---
\newcommand{\revnote}[1]{\textsuperscript{\textnormal{[#1]}}}
"""

TITLEBLOCK = r"""
\begin{document}
\begin{titlepage}
\centering
\vspace*{3.5cm}
{\LARGE\bfseries Slot-Chain：基于槽位签名链的预确认协议\par}
\vspace{0.8em}
{\large v2 设计规范\par}
\vspace{2.2cm}
{\large 草案 @VERSION@\par}
\vspace{0.5em}
{\normalsize 2026 年 8 月\par}
\vspace{3cm}
\begin{minipage}{0.82\linewidth}
\small
\noindent\textbf{摘要}\quad
本文给出 Taiko 预确认协议的后继设计（v2）。L2 时间被切成 1 秒的槽位（slot），
提前两个 epoch 公布的排班表（lookahead）为每个槽位指定唯一构建者；构建者出块并签名，
签名覆盖父块哈希，未上链的块因此串成一条签名链（signature chain）。把这条链连同有效性
证明提交上 L1 的动作称为落地（landing）：常态由拍卖产生的聚合者执行，聚合者掉线时任何人
都可以执行——块的权威来自构建者签名，不来自落地者。最终性由证明系统与确定性的结算窗口
共同给出：窗口内最重的已证明候选于收盘时最终化。本文同时给出该设计的信任模型、活性核算、
强制包含底线、罚没规则与参数几何，并如实标注全部已接受的残留风险与仍开放的待定项。
\end{minipage}
\vfill
\end{titlepage}

\tableofcontents
\clearpage
\setcounter{section}{-1}
"""


def build():
    md = open(SRC, encoding="utf-8").read()
    ver = re.search(r"草案 (v1\.\d+)", md.split("\n", 1)[0])
    version = ver.group(1) if ver else "v?"

    figures_src = ""
    n_figs = 0
    if os.path.exists(FIGS):
        figures_src = open(FIGS, encoding="utf-8").read()
        n_figs = len(re.findall(r"% ==== FIGURE \d+ ====", figures_src))

    store = NoteStore()
    body = convert(md, store, n_figs)

    # 图：把占位符替换为对应 figure 环境
    if n_figs:
        blocks = dict(re.findall(
            r"% ==== FIGURE (\d+) ====\n(.*?)% ==== END FIGURE \d+ ====",
            figures_src, re.S))
        preamble_extra = figures_src.split("% ==== FIGURE 1 ====")[0]
        # 倒序替换：\FIGUREPLACEHOLDER1 是 ...10 的前缀，正序会把图 10 覆盖成图 1
        for k in range(n_figs, 0, -1):
            body = body.replace("\\FIGUREPLACEHOLDER%d" % k, blocks.get(str(k), ""))
    else:
        preamble_extra = ""
    body = re.sub(r"\\FIGUREPLACEHOLDER\d+", "", body)

    # 附录 E：评审注记
    notes_tex = ["\\clearpage\\section*{附录 E：评审注记索引}\\label{app:E}",
                 "\\addcontentsline{toc}{section}{附录 E：评审注记索引}",
                 "本附录汇集正文中以 \\revnote{n} 标出的全部出处注记——它们记录每条规则由哪一轮"
                 "对抗评审、哪位评审者或所有者的哪次决定促成。正文因此只承载规范性陈述；"
                 "追溯某条规则的来龙去脉时查阅本附录。完整的逐版本修订记录另见"
                 "\\hyperref[app:D]{附录~D}。",
                 "\\begin{enumerate}[leftmargin=2.6em,itemsep=0.12em]"]
    for k, (sec, txt) in enumerate(store.notes, 1):
        notes_tex.append("\\item[{[%d]}] \\textbf{%s}\\quad %s"
                         % (k, esc_sec(sec), inline(txt)))
    notes_tex.append("\\end{enumerate}")

    tex = (PREAMBLE + preamble_extra + TITLEBLOCK + body
           + "\n".join(notes_tex) + "\n\\end{document}\n")
    tex = tex.replace("@VERSION@", version)

    # 一致性：markdown 里的 mermaid 块是图的位置标记，数量必须与 figures.tex 对齐，
    # 否则会出现"图排错位置"或"图丢失"这类静默错误。
    n_marks = len(re.findall(r"^\s*```mermaid\s*$", md, re.M))
    if n_marks != n_figs:
        print("WARNING: markdown 有 %d 个图位标记，figures.tex 有 %d 幅图"
              % (n_marks, n_figs))

    os.makedirs(TEXDIR, exist_ok=True)
    if "--check" in sys.argv[1:]:
        current = open(MAIN, encoding="utf-8").read() if os.path.exists(MAIN) else None
        if current != tex:
            print("DRIFT: %s 与 markdown 不一致 —— 运行 `python3 build-pdf.py` 并提交"
                  % os.path.relpath(MAIN, HERE))
            sys.exit(1)
        print("%s 与 markdown 一致" % os.path.relpath(MAIN, HERE))
        sys.exit(0)
    open(MAIN, "w", encoding="utf-8").write(tex)
    print("wrote %s (%d bytes, %d review notes, %d figures)"
          % (MAIN, len(tex), len(store.notes), n_figs))
    return len(store.notes)


def esc_sec(s):
    return s if s.startswith("\\S") else esc(s)


def compile_pdf():
    for run in range(3):
        r = subprocess.run(["xelatex", "-interaction=nonstopmode",
                            "-halt-on-error", "main.tex"],
                           cwd=TEXDIR, capture_output=True, text=True)
        if r.returncode != 0:
            log = os.path.join(TEXDIR, "main.log")
            tail = open(log, encoding="utf-8", errors="replace").read()[-3000:] \
                if os.path.exists(log) else r.stdout[-3000:]
            print("XeLaTeX FAILED on run %d:\n%s" % (run + 1, tail))
            return False
    shutil.copy(os.path.join(TEXDIR, "main.pdf"), PDF_OUT)
    print("wrote %s" % PDF_OUT)
    return True


if __name__ == "__main__":
    build()
    if "--tex-only" not in sys.argv:
        sys.exit(0 if compile_pdf() else 1)
