#!/usr/bin/env python3
"""Check that the committed conformance vectors are a fresh generator run.

testdata/etna_conformance holds the behavioral vectors the Etna contracts and the Rust client
replay. This runs `lake exe etna-vectors --write <tmp>` (after `lake build`) and requires the
committed directory to hold exactly the generated JSON files, byte for byte. The proof audit
(scripts/audit_proofs.py) runs the same check; CI runs it as its own step first.
"""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
COMMITTED = ROOT.parents[1]/'testdata/etna_conformance'
REFRESH = 'run `lake exe etna-vectors --write ../../testdata/etna_conformance` in formal/etna'


def differences(fresh, committed):
    """Missing, extra and stale vector files of `committed` against the generated `fresh` directory."""
    generated = {p.name for p in Path(fresh).glob('*.json')}
    present = {p.name for p in Path(committed).glob('*.json')}
    errors = [f'{name} is missing' for name in sorted(generated-present)]
    errors += [f'{name} is not generated' for name in sorted(present-generated)]
    errors += [f'{name} is stale' for name in sorted(generated & present)
               if (Path(fresh)/name).read_bytes() != (Path(committed)/name).read_bytes()]
    return [f'{error}: {REFRESH}' for error in errors]


def check(root=ROOT, committed=COMMITTED):
    """Generate the vectors into a scratch directory and compare (raises if the generator fails)."""
    (root/'.scratch').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=root/'.scratch') as tmp:
        result = subprocess.run(['lake', 'exe', 'etna-vectors', '--write', tmp], cwd=root, text=True,
                                capture_output=True)
        if result.returncode:
            raise ValueError('lake exe etna-vectors failed: '+(result.stdout+result.stderr)[-2000:])
        return differences(tmp, committed)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--committed', type=Path, default=COMMITTED)
    args = parser.parse_args()
    try:
        errors = check(committed=args.committed.resolve())
    except (ValueError, OSError) as exc:
        print('vector check failed: '+str(exc), file=sys.stderr)
        return 1
    if errors:
        print('vector check failed:\n  '+'\n  '.join(errors), file=sys.stderr)
        return 1
    count = len(list(args.committed.glob('*.json')))
    print(f'The {count} committed conformance vector files equal a fresh lake exe etna-vectors run.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
