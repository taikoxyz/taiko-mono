#!/usr/bin/env python3
"""Reproduce ignored audit/inventory artifacts from one reviewed evidence manifest.

`--check` only re-renders and compares with the files already in --out, i.e. it proves
deterministic generation and catches stale or hand-edited outputs. The `source_sha256`
digests in coverage.json are informational fingerprints of the inputs used for this
rendering; nothing compares them with an independently reviewed record.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

from audit_proofs import GRAPH, ROOT, load_shadow_allowlist, render_audit, validate_contract
from check_spec_coverage import (CURRENT_CONFIG, HISTORICAL_CONFIG, INDEX_PATH, REPO, archive_bytes,
                                 current_inventory, inventory, source_documents)


def artifacts(root=ROOT, repo=REPO):
    manifest = json.loads((root/'manifests/design.json').read_text())
    validate_contract(manifest,root)
    by_profile = {'current': current_inventory(root, repo), 'historical': inventory(root, repo)}
    shadows = load_shadow_allowlist(root)
    paths = [root/name for name in ('lean-toolchain', 'lakefile.toml', 'lake-manifest.json',
                                   CURRENT_CONFIG, HISTORICAL_CONFIG, 'rule-coverage.json')]
    paths += [p for library in GRAPH.LIBRARIES for p in GRAPH.library_files(root,library)]
    for directory, suffixes in [('manifests',{'.json'}),('scripts',{'.py','.lean'}),('tests',{'.py','.lean'})]:
        paths += [p for p in (root/directory).glob('*') if p.suffix in suffixes]
    hashes = {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(paths))}
    for path in [*source_documents(root, repo, profile='current'), INDEX_PATH]:
        hashes[path] = hashlib.sha256((repo/path).read_bytes()).hexdigest()
    for path, (_, _, text) in source_documents(root, repo).items():
        hashes['historical/'+path] = hashlib.sha256(text.encode()).hexdigest()
    index = json.loads((root/'rule-coverage.json').read_text())['index']
    hashes['historical/'+INDEX_PATH] = hashlib.sha256(archive_bytes(repo, INDEX_PATH, index['commit'])).hexdigest()
    report = dict(generated=True,scope='source clauses are not atomic requirements or a coverage percentage',
                  clauses=[r for rows in by_profile.values() for r in rows],
                  statuses={profile:dict(Counter(r['status'] for r in rows)) for profile,rows in by_profile.items()},
                  source_sha256=hashes,
                  source_sha256_scope='informational input fingerprints; not validated against a reviewed record')
    return {'Audit.lean':render_audit(manifest['theorems'],shadows=shadows),
            'coverage.json':json.dumps(report,ensure_ascii=False,indent=2)+'\n'}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--out',type=Path,default=ROOT/'.scratch/generated')
    parser.add_argument('--check',action='store_true',
                        help='re-render and compare with existing ignored artifacts (determinism/staleness only; digests are not validated)')
    args = parser.parse_args()
    try:
        rendered = artifacts()
        if args.check:
            for name,text in rendered.items():
                if not (args.out/name).exists() or (args.out/name).read_text() != text:
                    raise ValueError('missing/stale generated artifact: '+name)
        else:
            args.out.mkdir(parents=True,exist_ok=True)
            for name,text in rendered.items():
                (args.out/name).write_text(text)
        count = len(json.loads(rendered['coverage.json'])['clauses'])
        print(('Checked deterministic re-rendering of' if args.check else 'Generated')
              +f' Audit.lean and {count}-clause inventory (ignored build output; input digests are informational).')
        return 0
    except (ValueError,KeyError,OSError,TypeError) as exc:
        print('generation failed: '+str(exc),file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
