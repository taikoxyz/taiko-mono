#!/usr/bin/env python3
"""Actual source mutants: re-extracted scalar proofs and focused native adapter assertions.

Run exclusively: production/generated files are temporarily changed, then byte-restored in
finally blocks even on failure. This tool never edits a generated algorithm by hand.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
WORKSPACE = REPO / 'packages/taiko-client-rs'
CORE = WORKSPACE / 'crates/etna-consensus-core/src'
GENERATED = ROOT / 'Etna/Refinement/Rust/EtnaConsensusCore.lean'
PROVENANCE = ROOT / 'Etna/Refinement/Rust/provenance.json'


def run(command, log, cwd=ROOT, env=None):
    with log.open('w') as output:
        return subprocess.run(command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT).returncode


def require_failed(command, log, marker, **kwargs):
    code = run(command, log, **kwargs)
    if code == 0 or marker not in log.read_text():
        raise RuntimeError(f'mutant failed to reach intended assertion gate: {log} (exit {code})')
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--group', choices=['core', 'adapters', 'all'], default='all')
    parser.add_argument('--output', type=Path, default=Path('/private/tmp/etna-committee-mutations'))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    env = dict(os.environ)
    generated_original = GENERATED.read_bytes()
    provenance_original = PROVENANCE.read_bytes()
    core_mutants = [
        ('activation-early', CORE / 'schedule.rs', 'height.checked_add(2)', 'height.checked_add(3)'),
        ('activation-late', CORE / 'schedule.rs', 'height.checked_add(2)', 'height.checked_add(1)'),
        ('quorum-inclusive', CORE / 'lib.rs', 'signed_power > (total_power / 3)', 'signed_power >= (total_power / 3)'),
    ]
    if args.group in ['core', 'all']:
        for name, path, before, after in core_mutants:
            original = path.read_bytes()
            target = args.output / name
            target.mkdir(exist_ok=True)
            try:
                source = original.decode()
                assert source.count(before) == 1
                path.write_text(source.replace(before, after))
                corpus_code = require_failed(['python3', 'scripts/committee_conformance.py'],
                                             target / 'corpus.log', 'rust corpus mismatch')
                extraction = ['python3', 'scripts/extract_rust_core.py', '--work', str(target / 'extraction'),
                              '--output', str(target / 'generated')]
                if run(extraction, target / 'extraction.log', env=env):
                    raise RuntimeError(f'extraction failed: {target}')
                GENERATED.write_bytes((target / 'generated/EtnaConsensusCore.lean').read_bytes())
                proof_code = require_failed(['lake', 'build', 'Etna.Refinement.Rust.Committee'],
                                            target / 'refinement.log', 'error: Etna/Refinement/Rust/Committee.lean')
                records.append({'mutation': name, 'corpus_exit': corpus_code, 'refinement_exit': proof_code,
                                'gate': 'actual regenerated source refinement and fixed corpus'})
            finally:
                path.write_bytes(original)
                GENERATED.write_bytes(generated_original)
                PROVENANCE.write_bytes(provenance_original)
                assert path.read_bytes() == original
                assert GENERATED.read_bytes() == generated_original
                assert PROVENANCE.read_bytes() == provenance_original
    if args.group in ['adapters', 'all']:
        mutants = [
            ('candidate-anchor', WORKSPACE / 'crates/abci/src/app/validate.rs',
             'let derived = candidate_committee(state, params, height, committee)?;',
             'let mut candidate_state = state.clone(); candidate_state.anchor = anchor.clone(); '
             'let derived = candidate_committee(&candidate_state, params, height, committee)?;',
             'app::tests::committee_witness::committee_witness_proven_at_the_parent_anchor_is_accepted'),
            ('drop-pending-insertion', WORKSPACE / 'crates/abci/src/app/finalize.rs',
             'if let Some(epoch) = plan.insert_epoch {',
             'if let Some(epoch) = plan.insert_epoch.filter(|_| false) {',
             'app::tests::finalize::every_switch_height_finds_both_committees'),
        ]
        for name, path, before, after, test in mutants:
            original = path.read_bytes()
            try:
                source = original.decode()
                assert source.count(before) == 1
                path.write_text(source.replace(before, after))
                code = require_failed(['cargo', '+1.95', 'test', '-p', 'abci', '--lib', test, '--', '--exact'],
                                      args.output / (name + '.log'), 'test result: FAILED', cwd=WORKSPACE, env=env)
                records.append({'mutation': name, 'test': test, 'exit': code, 'gate': 'actual native adapter assertion'})
            finally:
                path.write_bytes(original)
                assert path.read_bytes() == original
    for record in records:
        record['restored'] = True
    paths = [CORE / 'lib.rs', CORE / 'schedule.rs', CORE / 'transition.rs', GENERATED, PROVENANCE,
             WORKSPACE / 'crates/abci/src/app/validate.rs', WORKSPACE / 'crates/abci/src/app/finalize.rs']
    report = {'mutations': records, 'restored_sha256': {
        str(p.relative_to(REPO)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
    (args.output / f'{args.group}.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, sort_keys=True))


if __name__ == '__main__':
    main()
