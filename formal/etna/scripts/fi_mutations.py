#!/usr/bin/env python3
"""Run real source mutations with exact finally restoration; no expected failures are simulated."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
WORKSPACE = REPO / 'packages/taiko-client-rs'
CORE = WORKSPACE / 'crates/etna-consensus-core/src/forced.rs'
GENERATED = ROOT / 'Etna/Refinement/Rust/EtnaConsensusCore.lean'
PROVENANCE = ROOT / 'Etna/Refinement/Rust/provenance.json'


def run(command, log, cwd=ROOT, env=None):
    with log.open('w') as output:
        return subprocess.run(command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT).returncode


def require_failed(command, log, marker, **kwargs):
    code = run(command, log, **kwargs)
    if code == 0 or marker not in log.read_text():
        raise RuntimeError(f'mutant did not fail at intended gate: {log} (exit {code})')
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--group', choices=['core', 'adapters', 'all'], default='all')
    parser.add_argument('--corpus-only', action='store_true',
                        help='With --group core, refresh only standalone compiler/corpus gates; no extraction or proof rerun')
    parser.add_argument('--output', type=Path, default=Path('/private/tmp/etna-fi-mutations'))
    args = parser.parse_args()
    if args.corpus_only and args.group != 'core':
        parser.error('--corpus-only requires --group core')
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    generated_original, provenance_original = GENERATED.read_bytes(), PROVENANCE.read_bytes()
    env = dict(os.environ)
    corpus_compiler = (subprocess.check_output(['rustc', '+1.95', '--version'], cwd=ROOT, text=True).strip()
                       if args.group in ['core', 'all'] else None)
    if args.group in ['core', 'all'] and not args.corpus_only:
        for required in ['AENEAS_ROOT', 'CHARON_ROOT']:
            if not env.get(required):
                raise ValueError(f'{required} must identify the pinned built extractor')
        env.setdefault('AENEAS_EXE', str(Path(env['AENEAS_ROOT']) / 'src/_build/default/main.exe'))
    core = [
        ('due-strict', 'anchor_timestamp as u128 >= timestamp as u128 + delay as u128',
         'anchor_timestamp as u128 > timestamp as u128 + delay as u128'),
        ('unfinished-consumes', 'SingletonOutcome::NotBuilt => Err(ForcedError::NeedsSingleton)',
         'SingletonOutcome::NotBuilt => Ok(Some(index))'),
    ]
    if args.group in ['core', 'all']:
        for name, before, after in core:
            original = CORE.read_bytes()
            target = args.output / name
            target.mkdir(exist_ok=True)
            try:
                source = original.decode()
                assert source.count(before) == 1
                CORE.write_text(source.replace(before, after))
                corpus_code = require_failed(['python3', 'scripts/fi_conformance.py'],
                                             target / 'corpus.log', 'rust corpus mismatch')
                if args.corpus_only:
                    records.append({'mutation': name, 'corpus_exit': corpus_code,
                                    'gate': 'actual production Rust fixed corpus; extraction/refinement not rerun'})
                    continue
                extraction = ['python3', str(ROOT / 'scripts/extract_rust_core.py'),
                              '--work', str(target / 'extraction'), '--output', str(target / 'generated')]
                if run(extraction, target / 'extraction.log', env=env):
                    raise RuntimeError(f'extraction failed: {target}')
                GENERATED.write_bytes((target / 'generated/EtnaConsensusCore.lean').read_bytes())
                proof_code = require_failed(['lake', 'build', 'Etna.Refinement.Rust.Forced'],
                                            target / 'refinement.log', 'error: Etna/Refinement/Rust/Forced.lean')
                records.append({'mutation': name, 'corpus_exit': corpus_code, 'refinement_exit': proof_code,
                                'gate': 'actual regenerated source refinement and corpus'})
            finally:
                CORE.write_bytes(original)
                if not args.corpus_only:
                    GENERATED.write_bytes(generated_original)
                    PROVENANCE.write_bytes(provenance_original)
                assert CORE.read_bytes() == original
                assert GENERATED.read_bytes() == generated_original
                assert PROVENANCE.read_bytes() == provenance_original
    if args.group in ['adapters', 'all']:
        finalize = WORKSPACE / 'crates/abci/src/app/finalize.rs'
        engine = WORKSPACE / 'crates/abci/src/engine/forced.rs'
        test = 'app::tests::finalize::hot_canonical_skip_matches_cold_replay_and_persists_after_commit'
        mutants = [
            ('error-as-empty', engine,
             'let rebuilt = engine.build_block(context.expected.parent_hash, attrs).await?;',
             'let rebuilt = match engine.build_block(context.expected.parent_hash, attrs).await { '
             'Ok(block) => block, Err(_) => { let ForcedDecision::NeedsSkip { index, .. } = decision '
             'else { unreachable!() }; return Ok(Some(*index)); } };',
             'engine::forced::tests::engine_failures_and_incomplete_results_do_not_authorize_consumption'),
            ('hot-consumption-removed', finalize, '(cached, false)',
             '({ let mut cached = cached; cached.forced = None; cached }, false)', test),
            ('cold-consumption-removed', finalize,
             'validated.forced = self.confirm_forced(state, height, &validated).await?;',
             'let _ = self.confirm_forced(state, height, &validated).await?; validated.forced = None;', test),
        ]
        for name, path, before, after, test_name in mutants:
            original = path.read_bytes()
            try:
                source = original.decode()
                assert source.count(before) == 1
                path.write_text(source.replace(before, after))
                code = require_failed(['cargo', 'test', '-p', 'abci', '--lib', test_name, '--', '--exact'],
                                      args.output / (name + '.log'), 'test result: FAILED', cwd=WORKSPACE, env=env)
                records.append({'mutation': name, 'test': test_name, 'exit': code,
                                'gate': 'actual async adapter assertion'})
            finally:
                path.write_bytes(original)
                assert path.read_bytes() == original
    for record in records:
        record['restored'] = True
    report = {'mutations': records, 'standalone_rust_compiler': corpus_compiler, 'core_sha256': hashlib.sha256(CORE.read_bytes()).hexdigest(),
              'generated_sha256': hashlib.sha256(GENERATED.read_bytes()).hexdigest()}
    (args.output / f'{args.group}{"-corpus" if args.corpus_only else ""}.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, sort_keys=True))


if __name__ == '__main__':
    main()
