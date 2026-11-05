"""Check that testdata/etna_current_conformance is a fresh `lake exe etna-vectors` run.

The proof audit (scripts/audit_proofs.py) runs the same check; CI runs it as its own step first.
"""
from pathlib import Path
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT.parents[1]/'testdata/etna_current_conformance'


def check():
    (ROOT/'.scratch').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=ROOT/'.scratch') as tmp:
        result = subprocess.run(['lake','exe','etna-vectors','--write',tmp],
                                cwd=ROOT,capture_output=True,text=True)
        if result.returncode:
            raise ValueError(result.stdout+result.stderr)
        generated = {p.name:p.read_bytes() for p in Path(tmp).glob('*.json')}
        committed = {p.name:p.read_bytes() for p in DIRECTORY.glob('*.json')}
        if not generated or generated != committed:
            raise ValueError('testdata/etna_current_conformance differs from a fresh run; run '
                             '`lake exe etna-vectors --write ../../testdata/etna_current_conformance` in formal/etna')
    return len(generated)


if __name__ == '__main__':
    try:
        print(f'The {check()} committed conformance vector file(s) equal a fresh lake exe etna-vectors run.')
    except (OSError,ValueError) as exc:
        print('current vector check failed: '+str(exc),file=sys.stderr)
        sys.exit(1)
