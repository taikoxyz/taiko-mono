#!/usr/bin/env python3
"""Check the pinned spec revision and explicit theorem/claim evidence edges.

This is a traceability report and its consistency check, not the verification result. The
results are the exact H1–H3 composition under `Etna.Statements.Current.Premises` (README). A
clause marked partial has an edge from some `property` or `constant` theorem; it is not proved.

Roles: `property` (Rule P: with every leading `∀`/hypothesis binder stripped, each atom of
the conclusion, split at `∧`/`∨`/`∃`, uses one of those binders and is not trivially true,
reading `Etna.Statements` definitions as their bodies; and derived: the proof uses an
induction principle or a derived Etna theorem) and `constant` (closed statement) edges make
a clause partial; only `property` edges may back proof claims; `supporting` (Rule P fails
or not derived) and `regression` edges never do.
The role text is not trusted: the proof audit (scripts/EtnaAudit.lean, checkContract)
checks each `property`/`supporting` role both ways against the kernel type and proof term.

SPEC.md, ACCEPTANCE.md, ANCHORLESS.md and SWITCH.md are independently pinned in
spec-coverage.json by source path, reviewed Git commit, revision date and SHA-256.
No editor-export manifest is needed. Any edit to an authority's text fails this check
until the clause links are reviewed against the new text and its pin is updated. The pin
and the clauses cover the text with rule-reference markers removed (strip_markers).

Clauses use LIVE_* IDs. Only Etna.Design.Current declarations may cite them. Every
theorem cites at least one clause, except the reviewed plumbing in UNSOURCED, which cites
none: it is audited like any theorem but is the obligation of no clause. UNSOURCED holds
the current plumbing (scripts/current-plumbing.json) and SHARED: lemmas outside the
Current namespace that current proofs reuse; their evidence is the Current declarations
that use them.
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
SPEC_DIR = 'packages/protocol/docs/etna'
SPEC_PATH = SPEC_DIR+'/SPEC.md'
ACCEPTANCE_PATH = SPEC_DIR+'/ACCEPTANCE.md'
ANCHORLESS_PATH = SPEC_DIR+'/ANCHORLESS.md'
SWITCH_PATH = SPEC_DIR+'/SWITCH.md'
SOURCE_INPUTS = (('source', 'spec', SPEC_PATH, 'live_en'),
                 ('acceptance_source', 'acceptance', ACCEPTANCE_PATH, 'live_acceptance'),
                 ('anchorless_source', 'anchorless', ANCHORLESS_PATH, 'live_anchorless'),
                 ('switch_source', 'switch', SWITCH_PATH, 'live_switch'))
ROLES = {'property', 'constant', 'supporting', 'regression'}
PARTIAL_ROLES = {'property', 'constant'}
SCOPE = 'conditional decoded specification property only'
# Theorems that back no clause (each must cite none): modelling plumbing, not a spec obligation.
SHARED_REASON = ('Shared lemma outside the Current namespace, reused by current proofs; '
                 'its evidence is the Etna.Design.Current declarations that use it')
UNSOURCED = {name: SHARED_REASON for name in (
    'Etna.Design.Consensus.election_valid_iff',
    'Etna.Design.Contracts.config_ok_eq',
    'Etna.Design.Contracts.signed_power_eq',
    'Etna.Design.Contracts.vote_valid_iff',
    'Etna.Design.Contracts.commit_valid_iff',
    'Etna.Design.Contracts.dual_ok_eq',
    'Etna.Design.Contracts.double_sign_eq',
    'Etna.Design.Contracts.bond_balance_eq',
    'Etna.Design.Contracts.forfeit_penalty_eq',
    'Etna.Design.Contracts.ordered_iff',
    'Etna.Design.Contracts.forced_step_eq',
    'Etna.Design.Contracts.election_eq',
    'Etna.Design.Contracts.forced_fee_eq',
    'Etna.Design.Contracts.committee_schedule_eq',
    'Etna.Design.gridLeaves_getD',
    'Etna.Design.Committee.chosen_eligible',
    'Etna.Design.Staking.fraction_bounded',
    'Etna.Design.Forced.step_one_or_zero',
    'Etna.Design.Forced.overdue_from_block_time',
    'Etna.Design.Consensus.commit_strict_quorum',
    'Etna.Design.Consensus.signed_power_bounded',
    'Etna.Design.RegistryHistory.record_head',
    'Etna.Design.RegistryHistory.record_preserves_order',
    'Etna.Design.Accountability.overlap_power',
    'Etna.Design.Accountability.conflicting_commits_overlap',
    'Etna.Proofs.selected_power_le',
    'Etna.Design.Staking.forfeit_penalty_bounded',
    'Etna.Design.Staking.forfeit_penalty_ceiling',
    'Etna.Design.Locking.polc_unique',
    'Etna.Design.Locking.commit_has_polc',
    'Etna.Design.Locking.polc_after_commit',
    'Etna.Design.Locking.commit_agreement',
    'Etna.Design.Locking.commitValid_bridge',
    'Etna.Design.ActualQueue.opened_advance_action',
)}


def _current_plumbing():
    """Reviewed exact-name policy, not an automatic exemption for a module/prefix."""
    data = json.loads(Path(__file__).with_name('current-plumbing.json').read_text())
    if set(data) != {'schema_version','scope','theorems'} or data['schema_version'] != 1:
        raise ValueError('invalid current plumbing policy')
    entries = data['theorems']
    if not isinstance(entries,dict) or not entries or not data['scope'].strip():
        raise ValueError('current plumbing declarations/reasons required')
    for name, reason in entries.items():
        if (not name.startswith('Etna.Design.Current.') or not isinstance(reason,str) or not reason.strip()):
            raise ValueError('invalid reviewed current plumbing declaration/reason: '+str(name))
    if set(entries) & set(UNSOURCED):
        raise ValueError('duplicate current/shared plumbing policy')
    return entries


UNSOURCED.update(_current_plumbing())


def digest(data):
    return hashlib.sha256(data).hexdigest()


def normalized(text):
    return ' '.join(text.split())


# Rule-reference markers (packages/protocol/docs/etna/rules/README.md) are citation
# handles, not clause text: an inline `**[FI-7.2-1]** ` prefix, or a `// [ENC-A-6]` line above
# a definition-block line. They are removed before the pin is checked and clauses are read,
# so adding or moving a marker changes neither a clause identity nor a `spec L…` line number.
MARKER_ID = r'[A-Z][A-Z0-9]*-[0-9.ABC]+-[0-9]+[a-z]?'
INLINE_MARKER = re.compile(r'\*\*\['+MARKER_ID+r'\]\*\* ?')
CODE_MARKER_LINE = re.compile(r'^[ \t]*// \['+MARKER_ID+r'\][ \t]*\n', re.M)


def strip_markers(text):
    return INLINE_MARKER.sub('', CODE_MARKER_LINE.sub('', text))


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
        elif not fence and (not line.strip() or re.fullmatch(r'</?(?:toggle|details)[^>]*>|<summary>.*</summary>|<table-of-contents />', line.strip())):
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
    """Read only the reviewed authority paths and validate each independent byte pin.

    The inventory is the reviewed record: revision/commit metadata identifies the
    source of the pinned bytes, rather than requiring an editor manifest or local
    Git history (a source checkout or scratch-copy test is sufficient).
    """
    spec = json.loads((root/'spec-coverage.json').read_text())
    result = []
    for key, label, path, language in SOURCE_INPUTS:
        source = spec.get(key)
        if not isinstance(source, dict):
            raise ValueError(f'{label} reviewed source pin required')
        if source.get('path') != path:
            raise ValueError(f'the {label} source must be '+path)
        if not re.fullmatch(r'[0-9a-f]{40}', source.get('commit', '')):
            raise ValueError(f'the {label} source requires a full Git commit')
        if not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', source.get('revision', '')):
            raise ValueError(f'the {label} source requires an ISO revision date')
        text = strip_markers((repo/path).read_bytes().decode())
        if digest(text.encode()) != source.get('sha256'):
            raise ValueError(f'{label} digest mismatch: {path} differs from the reviewed revision '
                             f'{source["revision"]} ({source["commit"]}); review the clause links '
                             'against the new text, then update its pin in spec-coverage.json')
        rows = clauses(text, language)
        for row in rows:
            row.update(path=path, source_commit=source['commit'])
        result.extend(rows)
    return result


def inventory(root=ROOT, repo=REPO):
    spec = json.loads((root/'spec-coverage.json').read_text())
    if spec.get('schema_version') != 4 or spec.get('scope') != SCOPE:
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
            if not name.startswith('Etna.Design.Current.'):
                raise ValueError(f'theorem authority mismatch: {name} cites {source}')
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
        print(f'Validated {len(rows)} clauses (SPEC/ACCEPTANCE/ANCHORLESS/SWITCH): '+str(dict(Counter(r['status'] for r in rows))))
        return 0
    except (ValueError,KeyError,OSError,TypeError) as exc:
        print('spec coverage failed: '+str(exc),file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
