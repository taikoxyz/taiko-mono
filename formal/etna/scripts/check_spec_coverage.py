#!/usr/bin/env python3
"""Check the pinned spec revision and explicit theorem/claim evidence edges.

This is a traceability report and its consistency check, not the verification result. The
result is the three headline theorems under `Etna.Statements.Premises` (README). A clause
marked partial has an edge from some `property` or `constant` theorem; it is not proved.

Roles: `property` (Rule P: with every leading `∀`/hypothesis binder stripped, each atom of
the conclusion, split at `∧`/`∨`/`∃`, uses one of those binders and is not trivially true,
reading `Etna.Statements` definitions as their bodies; and derived: the proof uses an
induction principle or a derived Etna theorem) and `constant` (closed statement) edges make
a clause partial; only `property` edges may back proof claims; `supporting` (Rule P fails
or not derived) and `regression` edges never do.
The role text is not trusted: the proof audit (scripts/EtnaAudit.lean, checkContract)
checks each `property`/`supporting` role both ways against the kernel type and proof term.

The source is the in-repo spec, packages/protocol/docs/etna-pos-zk/sources/spec.md, pinned
in spec-coverage.json by revision and SHA-256 and cross-checked against that directory's
manifest.json. Any edit to the spec fails this check until the clause links are reviewed
against the new text and the pin is updated.

Every theorem cites at least one clause, except the reviewed plumbing in UNSOURCED, which
cites none: it is audited like any theorem but is the obligation of no clause.
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
SPEC_DIR = 'packages/protocol/docs/etna-pos-zk/sources'
SPEC_PATH = SPEC_DIR+'/spec.md'
ROLES = {'property', 'constant', 'supporting', 'regression'}
PARTIAL_ROLES = {'property', 'constant'}
SCOPE = 'conditional decoded specification property only'
# Theorems that back no clause (each must cite none): modelling plumbing, not a spec obligation.
UNSOURCED = {
    'Etna.Proofs.run_trace': 'Run ⊆ Trace: restates a run of the headline claims as a protocol trace; '
                             'an obligation of no clause (it used to cite the whole 6.1 land clause)',
    'Etna.Proofs.trace_run': 'Trace ⊆ Run for an environment that submits every landing land accepts on a '
                             "trace-reachable World: Run's side condition excludes nothing; an obligation of no clause",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def normalized(text):
    return ' '.join(text.split())


def clauses(text, language):
    """Content IDs survive unrelated line insertions; line ranges are derived locations.

    Equal content gets an occurrence suffix. Changing clause text requires a reviewed
    new link; it is never silently matched by line number or fuzzy similarity.
    """
    lines = text.splitlines()
    if '<content>' in lines:
        start, end = lines.index('<content>')+1, lines.index('</content>')
    else:
        start, end = 0, len(lines)
    section, result, pending, counts = 'preamble', [], [], Counter()
    fence = False

    def flush():
        if not pending:
            return
        first, last = pending[0][0], pending[-1][0]
        raw = '\n'.join(line for _, line in pending)
        key = language.upper()+'-'+digest(normalized(raw).encode())[:16]
        counts[key] += 1
        identity = key if counts[key] == 1 else key+'-'+str(counts[key])
        result.append(dict(id=identity,language=language,section=section,start_line=first,
                           end_line=last,text_sha256=digest(raw.encode()),summary=raw[:180]))
        pending.clear()

    for i in range(start, end):
        line = lines[i]
        heading = re.match(r'^#{1,6} (.+)', line)
        if not fence and heading:
            flush()
            section = heading[1]
        elif not fence and (not line.strip() or re.fullmatch(r'</?toggle[^>]*>|<table-of-contents />', line)):
            flush()
        else:
            if not fence and (re.match(r'^\s*(?:[-*] |[0-9]+\. )', line) or line.startswith('|')):
                flush()
            pending.append((i+1,line))
            if line.startswith('```'):
                fence = not fence
                if not fence:
                    flush()
    flush()
    return result


def content_key(identity):
    """`EN-<digest>` without the order-based `-N` duplicate suffix."""
    return '-'.join(identity.split('-')[:2])


def source_rows(root=ROOT, repo=REPO):
    source = json.loads((root/'spec-coverage.json').read_text())['source']
    if source.get('path') != SPEC_PATH:
        raise ValueError('the spec source must be '+SPEC_PATH)
    data = (repo/SPEC_PATH).read_bytes()
    if digest(data) != source['sha256']:
        raise ValueError(f'spec digest mismatch: {SPEC_PATH} differs from the reviewed revision {source["revision"]}; '
                         'review the clause links against the new text, then update source in spec-coverage.json')
    manifest = json.loads((repo/SPEC_DIR/'manifest.json').read_text())
    entry = next(d for d in manifest['documents'] if d['source'] == 'spec.md')
    if manifest['revision'] != source['revision'] or entry['sha256'] != source['sha256']:
        raise ValueError(f'pinned spec revision differs from {SPEC_DIR}/manifest.json')
    return clauses(data.decode(),'en')


def inventory(root=ROOT, repo=REPO):
    spec = json.loads((root/'spec-coverage.json').read_text())
    if spec.get('schema_version') != 3 or spec.get('scope') != SCOPE:
        raise ValueError('unsupported inventory schema/scope')
    rows = source_rows(root, repo)
    ids = {r['id'] for r in rows}
    if len(ids) != len(rows):
        raise ValueError('duplicate content identity')
    entries = json.loads((root/'manifests/design.json').read_text())['theorems']
    names = [e['declaration'] for e in entries]
    if len(names) != len(set(names)):
        raise ValueError('duplicate theorem identity')
    links = {source:[] for source in ids}
    roles = {}
    for entry in entries:
        name, role, sources = entry['declaration'], entry['role'], entry['sources']
        if role not in ROLES:
            raise ValueError(f'unknown theorem role {role!r}: {name}')
        if len(sources) != len(set(sources)) or (not sources and name not in UNSOURCED):
            raise ValueError(f'empty or duplicate theorem source list: {name}')
        if sources and name in UNSOURCED:
            raise ValueError(f'{name} is listed in UNSOURCED (backs no clause) but cites {sources[0]}; '
                             'drop its sources or its UNSOURCED entry')
        for source in sources:
            if source not in ids:
                raise ValueError(f'unknown theorem source {source}: {name}')
        if not entry['scope'].strip():
            raise ValueError(f'theorem scope required: {name}')
        roles[name] = role
        for source in sources:
            links[source].append(name)
    pending = spec['design_pending']
    if len(pending) != len(set(pending)):
        raise ValueError('duplicate design-pending source')
    for source in pending:
        if source not in ids:
            raise ValueError(f'unknown design-pending source {source}')
    # Equal normalized text gets order-based `-N` IDs; deleting an earlier copy would
    # silently rebind a reviewed edge, so linked/pending clauses must be unique text.
    base = Counter(content_key(r['id']) for r in rows)
    for row in rows:
        if (links[row['id']] or row['id'] in pending) and base[content_key(row['id'])] > 1:
            raise ValueError(f'clause {row["id"]} has edges/design-pending status but its normalized text is '
                             f'duplicated in the snapshot; its content ID is order-dependent: {sorted(links[row["id"]])}')
    for row in rows:
        row['theorems'] = sorted(links[row['id']])
        row['status'] = ('design-pending' if row['id'] in pending else
                         'partial' if any(roles[n] in PARTIAL_ROLES for n in row['theorems']) else 'deferred')
    by_id = {r['id']:r for r in rows}
    by_name = {e['declaration']:e for e in entries}
    claim_ids = set()
    for claim in spec['claims']:
        cid = claim['id']
        if cid in claim_ids:
            raise ValueError(f'duplicate proof claim {cid}')
        claim_ids.add(cid)
        if claim['status'] != 'proved' or claim['scope'] != SCOPE or not claim['description'].strip():
            raise ValueError(f'incorrect proof claim scope: {cid}')
        if not claim['assumptions'] or any(b not in spec['boundaries'] for b in claim['assumptions']):
            raise ValueError(f'named boundaries required in proof claim {cid}')
        if not claim['evidence']:
            raise ValueError(f'claim evidence required: {cid}')
        for source, declarations in claim['evidence'].items():
            if source not in by_id:
                raise ValueError(f'unknown source clause in proof claim {cid}: {source}')
            if by_id[source]['status'] not in {'partial','proved'}:
                raise ValueError(f'proof claim {cid} targets deferred/design-pending source {source}')
            if not declarations or len(declarations) != len(set(declarations)):
                raise ValueError(f'nonempty unique claim evidence required: {cid} {source}')
            for name in declarations:
                if name not in by_name:
                    raise ValueError(f'unknown theorem in proof claim {cid} {source}: {name}')
                if source not in by_name[name]['sources']:
                    raise ValueError(f'claim edge missing from theorem source map: {cid} {source} {name}')
                if by_name[name]['role'] != 'property':
                    raise ValueError(f'general property evidence required; constants/finite regressions/helpers '
                                     f'cannot support proof claims: {cid} {source} {name} ({by_name[name]["role"]})')
    return rows


def validate(root=ROOT, repo=REPO):
    return len(inventory(root, repo))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--repo',type=Path,default=REPO)
    args = parser.parse_args()
    try:
        rows = inventory(args.root, args.repo)
        print(f'Validated {len(rows)} spec clauses of {SPEC_PATH}, explicit claim edges and roles; '+str(dict(Counter(r['status'] for r in rows))))
        return 0
    except (ValueError,KeyError,OSError,TypeError) as exc:
        print('spec coverage failed: '+str(exc),file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
