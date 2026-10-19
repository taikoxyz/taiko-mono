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
    parser.add_argument('--only', action='append', default=[], help='Exact mutation IDs to run; repeat for a focused fresh proof regression')
    parser.add_argument('--corpus-only', action='store_true',
                        help='With --group core, refresh only standalone compiler/corpus gates; no extraction or proof rerun')
    parser.add_argument('--output', type=Path, default=Path('/private/tmp/etna-committee-mutations'))
    args = parser.parse_args()
    if args.corpus_only and args.group != 'core':
        parser.error('--corpus-only requires --group core')
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    env = dict(os.environ)
    corpus_compiler = (subprocess.check_output(['rustc', '+1.95', '--version'], cwd=ROOT, text=True).strip()
                       if args.group in ['core', 'all'] else None)
    index_before = subprocess.check_output(['git', 'ls-files', '--stage'], cwd=REPO)
    generated_original = GENERATED.read_bytes()
    provenance_original = PROVENANCE.read_bytes()
    core_mutants = [
        ('activation-early', CORE / 'schedule.rs', 'height.checked_add(2)', 'height.checked_add(3)'),
        ('activation-late', CORE / 'schedule.rs', 'height.checked_add(2)', 'height.checked_add(1)'),
        ('quorum-inclusive', CORE / 'lib.rs', 'signed_power > (total_power / 3)', 'signed_power >= (total_power / 3)'),
        ('committee-size-cap-relaxed', CORE / 'lib.rs', 'pub const MAX_N_MAX: usize = 4096;', 'pub const MAX_N_MAX: usize = 4097;'),
        ('positive-cap-inclusive', CORE / 'lib.rs', 'd_max > margin', 'd_max >= margin'),
        ('first-height-range-bypass', CORE / 'schedule.rs',
         'match self.h_first(1) {\n            Some(first) if first <= UINT48_MAX => (),',
         'match self.h_first(1) {\n            Some(_first) => (),'),
        ('first-anchor-range-bypass', CORE / 'schedule.rs',
         'match self.checked_l1_first(1) {\n            Some(first) if first <= UINT48_MAX => (),\n            _ => return Err(ScheduleError::FirstEpochBeyondAnchorRange),\n        }',
         'match self.checked_l1_first(1) {\n            Some(_first) => (),\n            None => (),\n        }'),
        ('anchor-overflow-admitted', CORE / 'schedule.rs',
         'None => Err(AnchorError::EpochNotOpen { epoch, l1_first: u64::MAX }),', 'None => Ok(()),'),
        ('urgency-overflow-true', CORE / 'schedule.rs',
         '                None => false,\n            },\n            None => false,\n        };',
         '                None => true,\n            },\n            None => false,\n        };'),
    ]
    all_ids = {item[0] for item in core_mutants} | {'candidate-anchor', 'drop-pending-insertion'}
    if set(args.only) - all_ids:
        parser.error('unknown mutation IDs: ' + str(sorted(set(args.only) - all_ids)))
    active_ids = all_ids if args.group == 'all' else ({item[0] for item in core_mutants} if args.group == 'core' else {'candidate-anchor', 'drop-pending-insertion'})
    if set(args.only) - active_ids:
        parser.error('requested mutation is outside the selected group')
    if args.group in ['core', 'all']:
        for name, path, before, after in core_mutants:
            if args.only and name not in args.only:
                continue
            original = path.read_bytes()
            target = args.output / name
            target.mkdir(exist_ok=True)
            try:
                source = original.decode()
                assert source.count(before) == 1
                mutated = source.replace(before, after)
                path.write_text(mutated)
                mutation_identity = {'source': str(path.relative_to(REPO)),
                                     'source_before_sha256': hashlib.sha256(original).hexdigest(),
                                     'source_mutant_sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                corpus_code = require_failed(['python3', 'scripts/committee_conformance.py'],
                                             target / 'corpus.log', 'rust corpus mismatch')
                if args.corpus_only:
                    records.append({'mutation': name, **mutation_identity, 'corpus_exit': corpus_code,
                                    'gate': 'actual production Rust fixed corpus; extraction/refinement not rerun'})
                    continue
                extraction = ['python3', 'scripts/extract_rust_core.py', '--work', str(target / 'extraction'),
                              '--output', str(target / 'generated')]
                if run(extraction, target / 'extraction.log', env=env):
                    raise RuntimeError(f'extraction failed: {target}')
                GENERATED.write_bytes((target / 'generated/EtnaConsensusCore.lean').read_bytes())
                proof_code = require_failed(['lake', 'build', 'Etna.Refinement.Rust.Committee'],
                                            target / 'refinement.log', 'error: Etna/Refinement/Rust/Committee.lean')
                records.append({'mutation': name, **mutation_identity, 'corpus_exit': corpus_code, 'refinement_exit': proof_code,
                                'generated_mutant_sha256': hashlib.sha256(GENERATED.read_bytes()).hexdigest(),
                                'gate': 'actual regenerated source refinement and fixed corpus'})
            finally:
                path.write_bytes(original)
                if not args.corpus_only:
                    GENERATED.write_bytes(generated_original)
                    PROVENANCE.write_bytes(provenance_original)
                assert path.read_bytes() == original
                assert GENERATED.read_bytes() == generated_original
                assert PROVENANCE.read_bytes() == provenance_original
                assert subprocess.check_output(['git', 'ls-files', '--stage'], cwd=REPO) == index_before
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
            if args.only and name not in args.only:
                continue
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
    if not records:
        raise RuntimeError('no semantic mutation checks executed')
    assert subprocess.check_output(['git', 'ls-files', '--stage'], cwd=REPO) == index_before
    for record in records:
        record['restored'] = True
    paths = [CORE / 'lib.rs', CORE / 'schedule.rs', CORE / 'transition.rs', GENERATED, PROVENANCE,
             WORKSPACE / 'crates/abci/src/app/validate.rs', WORKSPACE / 'crates/abci/src/app/finalize.rs']
    report = {'index_before_after_sha256': hashlib.sha256(index_before).hexdigest(), 'mutator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'mutations': records, 'standalone_rust_compiler': corpus_compiler, 'restored_sha256': {
        str(p.relative_to(REPO)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
    (args.output / f'{args.group}{"-corpus" if args.corpus_only else ""}.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, sort_keys=True))


if __name__ == '__main__':
    main()
