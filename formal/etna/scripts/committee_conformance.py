#!/usr/bin/env python3
"""Compare fixed JSONL goldens with independent Lean and actual production Rust reducers."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ARITY = {**dict.fromkeys(['validate', 'epoch', 'first', 'last', 'l1', 'parent', 'starting', 'switch', 'next'], 5), 'quorum': 2, 'plan': 9}


def run(args, **kwargs):
    p = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, **kwargs)
    if p.returncode:
        raise ValueError(p.stdout + p.stderr)
    return p.stdout


def check(corpus):
    rows = [json.loads(line) for line in corpus.read_text().splitlines()]
    ids = [row['id'] for row in rows]
    if len(set(ids)) != len(ids) or not rows:
        raise ValueError('empty corpus or duplicate case IDs')
    for row in rows:
        if row['op'] not in ARITY or len(row['args']) != ARITY[row['op']]:
            raise ValueError('invalid operation/arity')
        for arg in row['args']:
            if type(arg) is int and not 0 <= arg < 2**(128 if row['op'] == 'quorum' else 64):
                raise ValueError('scalar argument exceeds operation width')
    expected = ''.join(f"{r['id']}\t{r['expected']}\n" for r in rows)
    wire = ''.join('\t'.join([r['id'], r['op'], *[
        json.dumps(v, separators=(',', ':')) if not isinstance(v, str) else v for v in r['args']
    ]]) + '\n' for r in rows)
    with tempfile.TemporaryDirectory(prefix='etna-committee-conformance-') as tmp:
        binary = str(Path(tmp) / 'committee')
        library = str(Path(tmp) / 'libetna_consensus_core.rlib')
        source = ROOT.parents[1] / 'packages/taiko-client-rs/crates/etna-consensus-core/src/lib.rs'
        run(['rustc', '--edition=2024', '--crate-type=rlib', '--crate-name=etna_consensus_core', str(source), '-o', library])
        run(['rustc', '--edition=2024', '-D', 'warnings', 'adapters/committee.rs', '--extern', f'etna_consensus_core={library}', '-o', binary])
        actuals = {
            'rust': run([binary], input=wire),
            'lean': run(['lake', 'env', 'lean', '--run', 'Check/Committee.lean', str(corpus)]),
        }
    for name, actual in actuals.items():
        if actual != expected:
            mismatches = [(e, a) for e, a in zip(expected.splitlines(), actual.splitlines()) if e != a]
            raise ValueError(f'{name} corpus mismatch: {mismatches[:8]}; output lines={len(actual.splitlines())}')
    print(json.dumps({'cases': len(rows), 'sha256': hashlib.sha256(corpus.read_bytes()).hexdigest(),
                      'lean': 'pass', 'production_rust': 'pass', 'bridge': 'conformance-tested'}, sort_keys=True))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--corpus', type=Path, default=ROOT / 'corpus/committee.jsonl')
    args = parser.parse_args()
    check(args.corpus.resolve())
