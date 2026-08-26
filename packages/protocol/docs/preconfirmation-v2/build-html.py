#!/usr/bin/env python3
"""Generate slot-chain-spec.html from slot-chain-spec.md.

Usage:
    python3 build-html.py            # regenerate slot-chain-spec.html
    python3 build-html.py --check    # regenerate and exit 1 if the committed
                                     # HTML differs from the markdown (drift guard;
                                     # run after every edit to slot-chain-spec.md)

Requires: pip install markdown pymdown-extensions
(authored against markdown==3.10.x, pymdown-extensions==10.x; newer versions
should work — the --check diff will surface any rendering change).

Mermaid diagrams are emitted as <pre class="mermaid"> and rendered client-side
by mermaid.js (loaded from CDN when the page is opened; diagram source stays
readable even offline).
"""
import html
import re
import sys

import markdown
from pymdownx.superfences import SuperFencesCodeExtension


def mermaid_fence(source, language, css_class, options, md, **kwargs):
    return f'<pre class="mermaid">{html.escape(source)}</pre>'


SRC = "slot-chain-spec.md"
OUT = "slot-chain-spec.html"

with open(SRC, encoding="utf-8") as f:
    text = f.read()

md = markdown.Markdown(
    extensions=[
        "tables",
        "toc",
        SuperFencesCodeExtension(
            custom_fences=[
                {"name": "mermaid", "class": "mermaid", "format": mermaid_fence}
            ]
        ),
    ],
    extension_configs={"toc": {"slugify": lambda v, sep: re.sub(r"\s+", sep, v.strip())}},
)
body = md.convert(text)

page = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Slot-Chain：基于槽位签名链的预确认协议（v2 设计规范）</title>
<style>
  :root {{
    --fg: #24292f; --bg: #ffffff; --muted: #57606a; --line: #d0d7de;
    --code-bg: #f6f8fa; --quote: #57606a; --accent: #0969da;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --fg: #e6edf3; --bg: #0d1117; --muted: #8b949e; --line: #30363d;
      --code-bg: #161b22; --quote: #8b949e; --accent: #58a6ff;
    }}
  }}
  html {{ background: var(--bg); }}
  body {{
    color: var(--fg); background: var(--bg);
    font-family: -apple-system, "Segoe UI", "PingFang SC", "Hiragino Sans GB",
                 "Noto Sans CJK SC", "Microsoft YaHei", sans-serif;
    line-height: 1.75; max-width: 920px; margin: 0 auto; padding: 2rem 1.25rem 6rem;
  }}
  h1, h2, h3 {{ line-height: 1.35; margin-top: 2.2em; }}
  h1 {{ font-size: 1.7em; border-bottom: 1px solid var(--line); padding-bottom: .4em; }}
  h2 {{ font-size: 1.35em; border-bottom: 1px solid var(--line); padding-bottom: .3em; }}
  h3 {{ font-size: 1.12em; }}
  a {{ color: var(--accent); text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  blockquote {{
    color: var(--quote); border-left: 4px solid var(--line);
    margin: 1em 0; padding: .1em 1em;
  }}
  code {{
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
    font-size: .92em; background: var(--code-bg);
    padding: .15em .35em; border-radius: 4px;
  }}
  pre {{
    background: var(--code-bg); border-radius: 6px; padding: .9em 1em;
    overflow-x: auto; line-height: 1.5;
  }}
  pre code {{ background: none; padding: 0; }}
  pre.mermaid {{
    background: var(--bg); text-align: center;
    border: 1px dashed var(--line);
  }}
  table {{ border-collapse: collapse; display: block; overflow-x: auto; margin: 1em 0; }}
  th, td {{ border: 1px solid var(--line); padding: .45em .8em; vertical-align: top; }}
  th {{ background: var(--code-bg); }}
  hr {{ border: none; border-top: 1px solid var(--line); margin: 2.5em 0; }}
  li {{ margin: .25em 0; }}
</style>
</head>
<body>
{body}
<script type="module">
  import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
  const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  mermaid.initialize({{ startOnLoad: true, securityLevel: "loose",
                        theme: dark ? "dark" : "default" }});
</script>
<noscript><p><em>提示：mermaid 图需要启用 JavaScript（并可访问 cdn.jsdelivr.net）才能渲染；
未渲染时图的文本源码仍可直接阅读。</em></p></noscript>
</body>
</html>
"""

if "--check" in sys.argv[1:]:
    try:
        with open(OUT, encoding="utf-8") as f:
            current = f.read()
    except FileNotFoundError:
        current = None
    if current != page:
        print(f"DRIFT: {OUT} is stale — run `python3 build-html.py` and commit it")
        sys.exit(1)
    print(f"{OUT} is up to date with {SRC}")
else:
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(page)
    print(f"wrote {OUT}: {len(page)} bytes")
