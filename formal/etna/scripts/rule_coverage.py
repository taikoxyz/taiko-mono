"""Exact reviewed rule-to-theorem traceability over the pinned live authorities.

Schema 2 requires an explicit evidence entry for each supported rule. Clause sharing
never supplies evidence to another rule. A reviewed edge names the exact theorem and
source clause; the theorem must cite that clause and be current. Mechanical supporting
guards remain visible as supporting, never counted as partial property evidence.
This validates traceability metadata, not semantic adequacy or complete verification.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
CONFIG = 'rule-coverage.json'
REPORT = 'reports/rule-coverage.md'
SPEC_PATH = 'packages/protocol/docs/etna/SPEC.md'
INDEX_PATH = 'packages/protocol/docs/etna/rules/INDEX.md'
RULE_ID = r'[A-Z]+-[0-9A-C.]+-[0-9]+[a-z]?'
CODE_MARKER = re.compile(r'^\s*//\s*\[(' + RULE_ID + r')\]\s*$')
INLINE_MARKER = re.compile(r'\*\*\[(' + RULE_ID + r')\]\*\*')
INDEX_ROW = re.compile(r'^\| (' + RULE_ID + r') +\| (\w+) +\| (.+?) +\| ([0-9A-C.]+) +\|', re.M)
TYPES = ('rule', 'limitation', 'assumption', 'retired')

_spec = importlib.util.spec_from_file_location('check_spec_coverage', ROOT/'scripts/check_spec_coverage.py')
coverage = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(coverage)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def pinned_text(repo, pin, path, label):
    if pin.get('path') != path:
        raise ValueError(f'the {label} pin must name {path}')
    if not re.fullmatch(r'[0-9a-f]{40}', pin.get('commit', '')):
        raise ValueError(f'the {label} pin requires a full Git commit')
    data = (repo/path).read_bytes()
    if digest(data) != pin.get('sha256'):
        raise ValueError(f'{label} digest mismatch: {path} differs from the reviewed commit {pin["commit"]}; '
                         'review the rule mapping and overrides against the new text, then update the pin')
    return data.decode()


def marker_lines(text):
    """Line of each rule ID in the marker-free text (the clause inventory's coordinates)."""
    lines, pending, number = {}, [], 0
    for raw in text.splitlines():
        code = CODE_MARKER.match(raw)
        if code:
            pending.append(code[1])
            continue
        number += 1
        for rule in pending:
            lines.setdefault(rule, number)
        pending = []
        for match in INLINE_MARKER.finditer(raw):
            if match[1] in lines:
                raise ValueError(f'duplicate marker {match[1]}')
            lines[match[1]] = number
    return lines


def index_rows(text):
    rows = {}
    for match in INDEX_ROW.finditer(text):
        rule, kind, title, section = match.groups()
        if kind not in TYPES:
            raise ValueError(f'unknown INDEX type {kind} for {rule}')
        if rule in rows:
            raise ValueError(f'duplicate INDEX row {rule}')
        rows[rule] = dict(type=kind, title=title.strip(), section=section)
    return rows


def rule_rows(root=ROOT, repo=REPO, config=None):
    config = config if config is not None else json.loads((root/CONFIG).read_text())
    if config.get('schema_version') != 2 or 'via' in config or 'narrow' in config:
        raise ValueError('unsupported rule-coverage schema: schema 2 exact evidence required')
    spec_text = pinned_text(repo, config.get('spec', {}), SPEC_PATH, 'spec')
    index = index_rows(pinned_text(repo, config.get('index', {}), INDEX_PATH, 'index'))
    lines = marker_lines(spec_text)
    live = {rule for rule, row in index.items() if row['type'] != 'retired'}
    if set(lines) != live:
        raise ValueError(f'markers and INDEX rows differ: only in SPEC {sorted(set(lines)-live)[:5]}, '
                         f'only in INDEX {sorted(live-set(lines))[:5]}')

    clauses = [r for r in coverage.inventory(root, repo) if r['path'] == SPEC_PATH]
    by_id = {r['id']: r for r in clauses}
    entries = {e['declaration']:e for e in json.loads((root/'manifests/design.json').read_text())['theorems']}

    def clause_at(line):
        hits = [r for r in clauses if r['start_line'] <= line <= r['end_line']]
        if len(hits) != 1:
            raise ValueError(f'line {line} lies in {len(hits)} clauses')
        return hits[0]

    owner = {rule:clause_at(line) for rule,line in lines.items()}
    sharing = Counter(row['id'] for row in owner.values())
    evidence = config.get('evidence')
    if not isinstance(evidence, dict):
        raise ValueError('exact rule evidence object required')
    for rule in evidence:
        if rule not in live:
            raise ValueError(f'evidence for unknown rule {rule}')
        if index[rule]['type'] != 'rule':
            raise ValueError(f'evidence for non-rule {rule}')

    result = []
    for rule in lines:
        clause, status, route, names, reason = owner[rule], 'deferred', None, [], ''
        if rule in evidence:
            edge = evidence[rule]
            if not isinstance(edge, dict) or not isinstance(edge.get('theorems'), list) or not edge['theorems']:
                raise ValueError(f'evidence for {rule} requires nonempty exact theorem list')
            reason = edge.get('reason','').strip()
            if not reason:
                raise ValueError(f'evidence for {rule} needs a reason describing the narrow result')
            target = by_id.get(edge.get('clause',clause['id']))
            if target is None:
                raise ValueError(f'evidence for {rule} names unknown live SPEC clause')
            names = edge['theorems']
            if len(names) != len(set(names)):
                raise ValueError(f'duplicate theorem evidence for {rule}')
            for name in names:
                theorem = entries.get(name)
                if theorem is None:
                    raise ValueError(f'unknown theorem {name} for {rule}')
                if not name.startswith('Etna.Design.Current.'):
                    raise ValueError(f'{rule} needs a current theorem, not {name}')
                if name in coverage.UNSOURCED:
                    raise ValueError(f'{name} is plumbing, not protocol evidence for {rule}')
                if target['id'] not in theorem['sources']:
                    raise ValueError(f'{name} does not cite {target["id"]} for {rule}')
                if theorem['role'] not in {'property','constant','supporting'}:
                    raise ValueError(f'{name} has no general supporting/property role for {rule}')
            route = target if target['id'] != clause['id'] else None
            partial = any(entries[name]['role'] in coverage.PARTIAL_ROLES for name in names)
            status = ('partial-via' if route else 'partial') if partial else 'supporting'
        result.append(dict(rule=rule,type=index[rule]['type'],title=index[rule]['title'],
                           section=index[rule]['section'],status=status,clause=clause['id'],
                           via=route['id'] if route else None,shared=sharing[clause['id']],
                           theorems=sorted(names),reason=reason))
    return result


def table(header, align, body):
    """A Markdown table padded the way the repository's prettier hook pads it."""
    rows = [header] + body
    widths = [max(3, *(len(r[i]) for r in rows)) for i in range(len(header))]

    def cells(row):
        return '| ' + ' | '.join((c.rjust(w) if a == 'r' else c.ljust(w))
                                 for c, w, a in zip(row, widths, align)) + ' |'
    rule = '| ' + ' | '.join(('-'*(w-1)+':') if a == 'r' else '-'*w for w, a in zip(widths, align)) + ' |'
    return [cells(header), rule] + [cells(r) for r in body]


def render(rows):
    out = ['# Exact rule-level traceability', '',
           'Generated by `scripts/rule_coverage.py` from pinned authorities and the reviewed schema-2 evidence map.',
           'Only an explicit rule-to-theorem edge can make a rule `partial` or `supporting`.',
           'Shared clauses never transfer evidence to neighboring IDs. `partial` is narrow property/constant',
           'evidence, not proof of the whole rule; `supporting` exposes exact guards or projections without',
           'counting them as a derived property. Raw decoder/EL/crypto and acceptance obligations remain separate.', '']
    totals = defaultdict(Counter)
    families = defaultdict(Counter)
    for row in rows:
        totals[row['type']][row['status']] += 1
        if row['type'] == 'rule':
            families[row['rule'].split('-')[0]][row['status']] += 1
    statuses = ['partial', 'partial-via', 'supporting', 'deferred', 'design-pending']
    counts = 'l' + 'r'*(1+len(statuses))
    out += ['## Totals', '']
    out += table(['Type', 'Count'] + statuses, counts,
                 [[kind, str(sum(totals[kind].values()))] + [str(totals[kind][s]) for s in statuses]
                  for kind in ('rule', 'limitation', 'assumption')])
    out += ['', '## Rules by family', '']
    out += table(['Family', 'Rules'] + statuses, counts,
                 [[family, str(sum(c.values()))] + [str(c[s]) for s in statuses]
                  for family, c in sorted(families.items(), key=lambda kv: (-sum(kv[1].values()), kv[0]))])
    body = []
    for row in rows:
        clause = row['clause'] + (f' → {row["via"]}' if row['via'] else '')
        names = row['theorems']
        shown = ', '.join('`'+n.rsplit('.', 1)[-1]+'`' for n in names[:3]) + (f' +{len(names)-3}' if len(names) > 3 else '')
        body.append([row['rule'], row['type'], row['status'], clause, str(row['shared']), shown])
    out += ['', '## Every ID', '']
    out += table(['ID', 'Type', 'Status', 'Clause', 'Shared', 'Theorems'], 'llllrl', body)
    out += ['', '## Narrow evidence scopes', '']
    out += [f'- **{row["rule"]}**: {row["reason"]}' for row in rows if row['theorems']]
    return '\n'.join(out) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true', help='fail unless the committed report is fresh')
    args = parser.parse_args()
    try:
        rows = rule_rows()
    except ValueError as error:
        print(f'rule coverage: {error}', file=sys.stderr)
        return 1
    text = render(rows)
    path = ROOT/REPORT
    if args.check:
        if not path.exists() or path.read_text() != text:
            print(f'rule coverage: {REPORT} is stale; run python3 scripts/rule_coverage.py', file=sys.stderr)
            return 1
    else:
        path.write_text(text)
    counts = Counter((r['type'], r['status']) for r in rows)
    print(f'Mapped {len(rows)} rule IDs of {SPEC_PATH} to clauses: '
          + ', '.join(f'{t}/{s} {n}' for (t, s), n in sorted(counts.items())))
    return 0


if __name__ == '__main__':
    sys.exit(main())
