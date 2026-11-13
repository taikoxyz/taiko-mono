#!/usr/bin/env python3
"""Generate the offline Lean statement/source viewer (CI uploads it as a workflow artifact).

This is a source browser, not a replacement for the kernel audit. Named source
declarations are indexed with the package's existing Lean lexer. Compiler-generated
projections/recursors and anonymous examples/instances are not separate entries.
Theorem types, roles, assumptions and rule edges come from the reviewed manifests.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import check_imports as graph
import check_spec_coverage as coverage
import rule_coverage

KINDS = {'def','abbrev','structure','inductive','class','theorem','lemma','opaque','instance'}


def source_line_map(text):
    """Map each marker-stripped inventory line to its one-based raw source line."""
    return [number for number,line in enumerate(text.splitlines(keepends=True),1)
            if not coverage.CODE_MARKER_LINE.fullmatch(line)]


def source_declarations(text):
    """Index named source declarations, tracking namespace/section/mutual scopes.

    This deliberately reuses check_imports' lexer and namespace convention. It
    does not resolve Lean terms or claim to enumerate the elaborated environment.
    """
    tokens=graph.lexer().tokenize(text)
    scopes, rows, boundaries=[], [], []
    lines=text.splitlines(keepends=True)
    offsets=[0]
    for line in lines: offsets.append(offsets[-1]+len(line))

    def following(index):
        if index+1 < len(tokens) and tokens[index+1][0]=='ident' and tokens[index+1][2]==tokens[index][2]:
            return tokens[index+1][1]
        return ()

    for index,(kind,value,line) in enumerate(tokens):
        if kind!='ident': continue
        if value==('namespace',):
            scopes+=following(index); boundaries.append(line)
        elif value in (('section',),('mutual',)):
            scopes.append(None); boundaries.append(line)
        elif value==('end',) and scopes:
            count=1 if scopes[-1] is None else max(1,len(following(index)))
            del scopes[-count:]; boundaries.append(line)
        elif len(value)==1 and value[0] in KINDS and following(index):
            parts=following(index)
            full=parts[1:] if parts[0]=='_root_' else tuple(c for c in scopes if c)+parts
            prefix=text[max(0,offsets[line-1]-20000):offsets[line-1]]
            start=prefix.rfind('/--')
            doc=''
            if start>=0:
                match=re.fullmatch(r'/--(.*?)-/\s*(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|noncomputable)\s+)*',
                                   prefix[start:],re.S)
                if match:
                    doc=match[1].strip()
                    doc_offset=max(0,offsets[line-1]-20000)+start
                    boundaries.append(text.count('\n',0,doc_offset)+1)
            rows.append(dict(name='.'.join(full),kind=value[0],line=line,doc=doc))
            boundaries.append(line)
    for row in rows:
        row['endLine']=min((b-1 for b in boundaries if b>row['line']),default=len(lines))
        while row['endLine']>row['line'] and not lines[row['endLine']-1].strip():
            row['endLine']-=1
    return rows


def build_catalogue(root=ROOT,repo=REPO):
    manifest=json.loads((root/'manifests/design.json').read_text())['theorems']
    contracts={e['declaration']:e for e in manifest}
    files, declarations={}, []
    for library in graph.declared_libraries(root):
        for path in graph.library_files(root,library):
            file=path.relative_to(root).as_posix()
            text=path.read_text()
            module=graph.module_name(root,path)
            files[file]=dict(text=text,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                             imports=[m for m,_ in graph.header_imports(graph.lexer().tokenize(text))])
            for row in source_declarations(text):
                row.update(file=file,module=module,library=library,
                           profile='current' if any(p.startswith('Current') for p in module.split('.'))
                                   or '.Current.' in row['name'] else 'shared')
                if row['name'] in contracts:
                    if contracts[row['name']]['module']!=module:
                        raise ValueError('manifest/source module mismatch: '+row['name'])
                    row['contract']=contracts[row['name']]
                declarations.append(row)
    names=[d['name'] for d in declarations]
    if len(names)!=len(set(names)): raise ValueError('duplicate named source declarations')
    missing=set(contracts)-set(names)
    if missing: raise ValueError('manifest declarations missing from source index: '+', '.join(sorted(missing)))
    clauses=coverage.inventory(root,repo)
    line_maps={path:source_line_map((repo/path).read_text())
               for _,_,path,_ in coverage.SOURCE_INPUTS}
    for clause in clauses:
        lines=line_maps[clause['path']]
        clause['github_start_line']=lines[clause['start_line']-1]
        clause['github_end_line']=lines[clause['end_line']-1]
    rules=rule_coverage.rule_rows(root,repo)
    pins=json.loads((root/'spec-coverage.json').read_text())
    authorities={path:{**pins[key],'github_path':path}
                 for key,_,path,_ in coverage.SOURCE_INPUTS}
    # No clock, current HEAD or network access: a clean checkout always reproduces the bytes.
    inputs=[root/'manifests/design.json',root/'spec-coverage.json',root/'rule-coverage.json',
            root/'scripts/current-plumbing.json',root/'lean-toolchain',root/'lakefile.toml']
    fingerprints={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    return dict(title='Etna · Lean audit reader',toolchain=(root/'lean-toolchain').read_text().strip(),
                declarations=declarations,files=files,clauses=clauses,rules=rules,authorities=authorities,
                fingerprints=fingerprints,counts=dict(Counter(d['profile'] for d in declarations)),
                github='https://github.com/taikoxyz/taiko-mono',branch='codex/etna-lean-verification')


def render_page(data):
    assets=Path(__file__).with_name('statements')
    css=(assets/'reader.css').read_text()
    js=(assets/'reader.js').read_text()
    template=(assets/'reader.html').read_text()
    payload=json.dumps(data,ensure_ascii=False,separators=(',',':'))
    for a,b in [('&','\\u0026'),('<','\\u003c'),('>','\\u003e'),('\u2028','\\u2028'),('\u2029','\\u2029')]:
        payload=payload.replace(a,b)
    import base64
    def csp_hash(value): return base64.b64encode(hashlib.sha256(value.encode()).digest()).decode()
    return (template.replace('@@STYLE_HASH@@',csp_hash(css)).replace('@@SCRIPT_HASH@@',csp_hash(js))
            .replace('<!-- @@STYLE@@ -->','<style>'+css+'</style>')
            .replace('<!-- @@DATA@@ -->','<script type="application/json" id="etna-data">'+payload+'</script>')
            .replace('<!-- @@SCRIPT@@ -->','<script>'+js+'</script>'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,default=ROOT/'STATEMENTS.html')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    try:
        data=build_catalogue()
        page=render_page(data)
        if args.check:
            if not args.out.is_file() or args.out.read_text()!=page:
                raise ValueError('missing/stale STATEMENTS.html; run python3 scripts/generate_statements.py')
        else: args.out.write_text(page)
        print(('Checked' if args.check else 'Generated')+f' offline reader: {len(data["declarations"])} named declarations, '
              f'{len(data["files"])} source files, {len(data["rules"])} rule rows.')
        return 0
    except (ValueError,OSError,KeyError,TypeError) as exc:
        print('statement generation failed: '+str(exc),file=sys.stderr)
        return 1


if __name__=='__main__': sys.exit(main())
