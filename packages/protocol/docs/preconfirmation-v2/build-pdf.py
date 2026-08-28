#!/usr/bin/env python3
"""从 slot-chain-spec.en.md 生成学术论文式 LaTeX 与 PDF（XeLaTeX，单栏，Palatino）。

规范源是中文的 `slot-chain-spec.md`；`slot-chain-spec.en.md` 是它的英文版，也是 PDF 的
排版输入。两者的同步靠英文版头部记录的中文源 sha256，`--check` 会比对（见下）。

用法:
    python3 build-pdf.py            # 生成 tex/main.tex 并编译出 slot-chain-spec.pdf
    python3 build-pdf.py --tex-only # 只生成 tex，不编译
    python3 build-pdf.py --check    # 两道漂移防护，任一不一致则非零退出：
                                    #   (a) 英文版头部 sha256 vs 中文源实际 sha256
                                    #   (b) tex/main.tex vs 由英文版重新生成的结果
                                    # 改 md 后必须重新生成并提交

两项结构性转换（其余为纯排版）：
  1. 评审注记外置——正文中形如"（评审 r39）""（独立审核第 5 轮高危 1——…）"的出处括注
     被抽出为尾注，集中到附录 E；正文只保留规范性陈述。出处在后、实质内容在前的括注
     只搬出处部分，保住参数值等规范内容（见 split_annotation）。
  2. mermaid 图 → TikZ 灰阶图（tex/figures.tex，按出现顺序 1..10 对应 fig:1..fig:10）。
"""

import hashlib
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "slot-chain-spec.en.md")
SRC_ZH = os.path.join(HERE, "slot-chain-spec.md")
TEXDIR = os.path.join(HERE, "tex")
MAIN = os.path.join(TEXDIR, "main.tex")
FIGS = os.path.join(TEXDIR, "figures.tex")
PDF_OUT = os.path.join(HERE, "slot-chain-spec.pdf")

# ---------------------------------------------------------------------------
# 1. 评审注记的识别与抽取
# ---------------------------------------------------------------------------
# 出处标记：评审轮次 rNN、独立审核轮次、外部评审者名、所有者决定、版本号
MARK = re.compile(
    r"review\s+r\d|independent review|the owner|owner's|DeepSeek|Codex|"
    r"finding \d|warning \d|option C|"
    r"(?<![A-Za-z])r\d{1,2}(?:-\d)?(?![\d])|v1\.\d+|v15",
    re.I,
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
        self.section = "Front matter"

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


# 英文版不加载 CJK 字体：注记抽取之后，残留的全角标点必须归一化为 ASCII，
# 否则 XeLaTeX 会报 Missing character（抽取本身要靠全角 （） 识别出处，故顺序不能反）。
CJK_PUNCT = {
    "（": "(", "）": ")", "【": "[", "】": "]", "《": "<", "》": ">",
    "〔": "[", "〕": "]", "「": "\u201c", "」": "\u201d", "『": "\u201c", "』": "\u201d",
    "：": ": ", "；": "; ", "，": ", ", "。": ". ", "、": ", ",
    "！": "!", "？": "?", "％": "%", "　": " ",
    "“": "``", "”": "''", "‘": "`", "’": "'",
    "——": "---", "—": "---", "…": r"\ldots{}",
}


def normalize_punct(s: str) -> str:
    s = s.replace("——", "---")
    for k, v in CJK_PUNCT.items():
        s = s.replace(k, v)
    return re.sub(r"  +", " ", s)


def esc(s: str) -> str:
    return "".join(SPECIALS.get(c, c) for c in s)


def code_inline(s: str) -> str:
    """行内等宽片段：在分隔符后插入零宽断点，避免长公式撑破版心。"""
    e = esc(s)
    for tok in (r"\_", ",", "/", "(", "+", "-"):
        e = e.replace(tok, tok + r"\allowbreak{}")
    return "\\texttt{%s}" % e


# 本文实际存在的节号，convert() 开头填充。只有它们才生成可点击引用——
# 指向 v15 或已删除小节的 §N（如 v15 §6.8、旧 §5.7）若一律加 \hyperref，
# 会产出没有 \label 的死链接（PDF 里点击无反应，且 LaTeX 静默不报错）。
KNOWN_SECS = set()


def sec_ref(m):
    """§5.6 → 可点击交叉引用；指向不存在的小节时退化为纯文本。"""
    num = m.group(1)
    if num not in KNOWN_SECS:
        return "\\S%s" % num
    return "\\hyperref[sec:%s]{\\S%s}" % (num, num)


def inline(text: str, store: NoteStore = None) -> str:
    if store is not None:
        text = extract_annotations(text, store)
    text = normalize_punct(text)
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
    text = re.sub(r"Appendix ([A-E])(?![\w-])",
                  lambda m: "\\hyperref[app:%s]{Appendix~%s}" % (m.group(1), m.group(1)), text)
    # 还原
    text = re.sub(r"\x02([^\x02]*)\x02", lambda m: code_inline(m.group(1)), text)
    text = re.sub(r"\x01(\d+)\x01", lambda m: notes[int(m.group(1))], text)
    text = re.sub(r"\x00(\d+)\x00",
                  lambda m: code_inline(spans[int(m.group(1))]), text)
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
        e = esc(normalize_punct(ln)).replace(" ", "~")
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
    KNOWN_SECS.clear()
    KNOWN_SECS.update(re.findall(r"^#{2,3} (\d+(?:\.\d+)?)[.．]?\s", md, re.M))
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

        # --- HTML 注释（源文件元信息）：不进正文 ---
        if stripped.startswith("<!--"):
            while i < len(lines) and "-->" not in lines[i]:
                i += 1
            i += 1
            continue

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
            app = re.match(r"^Appendix ([A-E])[:：]\s*(.*)$", title)
            if app:
                letter, rest = app.group(1), app.group(2)
                store.section = "Appendix " + letter
                full, clean = heading_pair(rest, store)
                out.append("\\clearpage\\section*{Appendix %s: %s}\\label{app:%s}"
                           % (letter, full, letter))
                out.append("\\addcontentsline{toc}{section}{Appendix %s: %s}"
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
        if re.match(r"\*\*(目录|Contents)\*\*[:：]", stripped):
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
PREAMBLE = r"""\documentclass[a4paper,11pt]{article}
\usepackage[margin=2.6cm,bottom=3cm]{geometry}
\usepackage[T1]{fontenc}
\usepackage{mathpazo}          % Palatino text + matching math: classic paper face
\usepackage{microtype}
\usepackage{amsmath,amssymb}
\usepackage{booktabs}
\usepackage{tabularx}
\usepackage{longtable}
\usepackage{tikz}
\usepackage{graphicx}
\usepackage{enumitem}
\usepackage{titlesec}
\usepackage{fancyhdr}
\usepackage{textcomp}
\usepackage[hidelinks,bookmarks=true]{hyperref}
\usepackage{newunicodechar}

% Palatino/T1 has no glyph for these; route them through math (which is also
% the typographically correct rendering for a paper).
\newunicodechar{≈}{\ensuremath{\approx}}
\newunicodechar{≤}{\ensuremath{\leq}}
\newunicodechar{≥}{\ensuremath{\geq}}
\newunicodechar{≠}{\ensuremath{\neq}}
\newunicodechar{→}{\ensuremath{\rightarrow}}
\newunicodechar{←}{\ensuremath{\leftarrow}}
\newunicodechar{⇒}{\ensuremath{\Rightarrow}}
\newunicodechar{⇔}{\ensuremath{\Leftrightarrow}}
\newunicodechar{∨}{\ensuremath{\vee}}
\newunicodechar{∧}{\ensuremath{\wedge}}
\newunicodechar{∞}{\ensuremath{\infty}}
\newunicodechar{×}{\ensuremath{\times}}
\newunicodechar{−}{\ensuremath{-}}
\newunicodechar{⊥}{\ensuremath{\bot}}
\newunicodechar{′}{\ensuremath{{}^{\prime}}}
\newunicodechar{✓}{\ensuremath{\checkmark}}
\newunicodechar{–}{\textendash}
\newunicodechar{—}{\textemdash}
\newunicodechar{…}{\ldots}
\newunicodechar{Δ}{\ensuremath{\Delta}}
\newunicodechar{Σ}{\ensuremath{\Sigma}}
\newunicodechar{φ}{\ensuremath{\varphi}}
\newunicodechar{δ}{\ensuremath{\delta}}
\newunicodechar{θ}{\ensuremath{\theta}}
\newunicodechar{①}{\circled{1}}
\newunicodechar{②}{\circled{2}}
\newunicodechar{③}{\circled{3}}
\newunicodechar{④}{\circled{4}}
\newunicodechar{⑤}{\circled{5}}
\newunicodechar{⑥}{\circled{6}}
\newcommand{\circled}[1]{\textcircled{\raisebox{-0.4pt}{\scriptsize #1}}}

% --- academic page discipline ---
\linespread{1.06}
\setlength{\parskip}{0.35em}
\setlength{\parindent}{0pt}
\setlist{itemsep=0.2em,parsep=0.2em,topsep=0.35em,leftmargin=1.5em}
\titleformat{\section}{\normalfont\large\bfseries}{\thesection}{0.7em}{}
\titleformat{\subsection}{\normalfont\normalsize\bfseries}{\thesubsection}{0.6em}{}
\titlespacing*{\section}{0pt}{1.7em}{0.7em}
\titlespacing*{\subsection}{0pt}{1.2em}{0.5em}

\pagestyle{fancy}\fancyhf{}
\renewcommand{\headrulewidth}{0.4pt}
\fancyhead[L]{\footnotesize\itshape Slot-Chain: A Preconfirmation Protocol}
\fancyhead[R]{\footnotesize Draft @VERSION@}
\fancyfoot[C]{\footnotesize\thepage}

% --- verbatim-ish code block ---
\newenvironment{codeblock}
  {\par\smallskip\begingroup\ttfamily\scriptsize
   \begin{list}{}{\leftmargin=1.2em\rightmargin=0pt\parsep=0pt\itemsep=0pt
                  \topsep=0pt\partopsep=0pt}%
   \item[]\raggedright}
  {\end{list}\endgroup\smallskip}

% --- design note (was a markdown blockquote) ---
\newenvironment{designnote}
  {\par\smallskip\begin{list}{}{\leftmargin=1.1em\rightmargin=0.4em
      \parsep=0.3em\itemsep=0pt\topsep=0.3em}\item[]\small\itshape}
  {\end{list}\smallskip}

% --- review endnote marker ---
\newcommand{\revnote}[1]{\textsuperscript{\textnormal{[#1]}}}
"""

TITLEBLOCK = r"""
\begin{document}

\title{\vspace{-1.2cm}\bfseries Slot-Chain: A Preconfirmation Protocol\\[0.15em]
Built on Per-Slot Signature Chains\\[0.5em]
\large\mdseries v2 Design Specification}
\author{}
\date{Draft @VERSION@ \quad\textperiodcentered\quad August 2026}
\maketitle
\thispagestyle{fancy}

\begin{abstract}
\noindent
This document specifies the successor design (v2) of the Taiko preconfirmation
protocol. L2 time is divided into one-second slots; a lookahead schedule,
published an epoch in advance, assigns each slot to a unique builder. The
builder produces a block and signs it, and because each signature covers the
parent hash, the not-yet-landed blocks form a \emph{signature chain}. Submitting
such a chain to L1 together with a validity proof is called \emph{landing}: an
aggregator elected by a perpetual auction performs it in the normal case, but
anyone may perform it when the aggregator is absent, because a block's authority
comes from its builder's signature rather than from whoever lands it. Finality
is given by the proof system together with a deterministic \emph{settlement
window}: among the candidates that have landed and been proven, the heaviest one
is finalized when the window closes at a predetermined L1 height. We give the
trust model, the liveness accounting, the slashing rules and the parameter
geometry, and we state the accepted residual risks and the remaining open items
explicitly rather than eliding them --- including the deliberate absence of a
censorship-resistance floor, which this design does not provide.
\end{abstract}

\tableofcontents
\clearpage
\setcounter{section}{-1}
"""


def build():
    md = open(SRC, encoding="utf-8").read()
    # 版本号取自文档标题（中文"草案 v1.NN"或英文"Draft v1.NN"）
    ver = re.search(r"(?:草案|Draft),? (v1\.\d+)", md[:2000])
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
    notes_tex = ["\\clearpage\\section*{Appendix E: Index of Review Notes}\\label{app:E}",
                 "\\addcontentsline{toc}{section}{Appendix E: Index of Review Notes}",
                 "This appendix collects every provenance note marked \\revnote{n} in the body. "
                 "Each records which adversarial review round, which external reviewer, or which "
                 "decision by the owner produced the rule it is attached to. The body therefore "
                 "carries only normative statements; consult this appendix when tracing where a "
                 "rule came from. The full per-version revision record is separate, in "
                 "\\hyperref[app:D]{Appendix~D}.",
                 "\\begin{enumerate}[leftmargin=2.8em,itemsep=0.12em]"]
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
        ok = check_translation_sync()
        current = open(MAIN, encoding="utf-8").read() if os.path.exists(MAIN) else None
        if current != tex:
            print("DRIFT: %s 与 markdown 不一致 —— 运行 `python3 build-pdf.py` 并提交"
                  % os.path.relpath(MAIN, HERE))
            ok = False
        else:
            print("%s 与 markdown 一致" % os.path.relpath(MAIN, HERE))
        sys.exit(0 if ok else 1)
    open(MAIN, "w", encoding="utf-8").write(tex)
    print("wrote %s (%d bytes, %d review notes, %d figures)"
          % (MAIN, len(tex), len(store.notes), n_figs))
    return len(store.notes)


def esc_sec(s):
    return s if s.startswith("\\S") else esc(s)


def check_translation_sync():
    """规范源（中文）与英文版的同步防护。

    英文版头部有一行 `<!-- generated-from: slot-chain-spec.md  sha256:… -->`，记录翻译
    时中文源的摘要。改了中文源却没重译，这里就会失配 —— 否则 PDF 会静默停在旧语义上，
    而中文版才是规范的那一份。重译后把新摘要写回该行即可。
    """
    en = open(SRC, encoding="utf-8").read()
    m = re.search(r"generated-from:\s*slot-chain-spec\.md\s+sha256:([0-9a-f]+)", en)
    if not m:
        print("DRIFT: %s 头部缺少 `generated-from … sha256:` 同步标记"
              % os.path.relpath(SRC, HERE))
        return False
    stored = m.group(1)
    zh = open(SRC_ZH, encoding="utf-8").read()
    live = hashlib.sha256(zh.encode("utf-8")).hexdigest()[:len(stored)]
    if stored != live:
        print("DRIFT: 中文规范源已改动但英文版未重译 —— %s 记录 sha256:%s，"
              "%s 实际为 sha256:%s。请重译英文版并更新该标记。"
              % (os.path.relpath(SRC, HERE), stored,
                 os.path.relpath(SRC_ZH, HERE), live))
        return False
    print("%s 与规范源同步（sha256:%s）" % (os.path.relpath(SRC, HERE), stored))
    return True


def compile_pdf():
    # -V 4 让 xdvipdfmx 输出 PDF 1.4：经典 xref 表 + trailer 字典，不用对象流
    # (/ObjStm) 和交叉引用流 (/XRef)。后者是 PDF 1.5 的默认结构，体积小约 28%，
    # 但只实现 PDF 1.4 的老解析器（不少电子书阅读器、电纸书固件属于此类）找不到
    # `trailer` 关键字就报"文件已损坏"。这里用体积换可打开性。
    for run in range(3):
        r = subprocess.run(["xelatex", "-interaction=nonstopmode",
                            "-halt-on-error",
                            "-output-driver=xdvipdfmx -V 4 -q", "main.tex"],
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
