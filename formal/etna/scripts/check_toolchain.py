#!/usr/bin/env python3
"""Validate immutable upstream source pins, their compatibility files, and Lake lock."""
import argparse
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]


def require_equal(name, actual, expected):
    if actual != expected:
        raise ValueError(f'{name} pin mismatch: expected {expected}, got {actual}')


def check(aeneas, charon):
    lock = json.loads((ROOT / 'tools.lock.json').read_text())
    for name, path in [('aeneas', aeneas), ('charon', charon)]:
        actual = subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()
        require_equal(name, actual, lock[name])
    pin = re.findall(r'(?m)^[0-9a-f]{40}$', (aeneas / 'charon-pin').read_text())
    require_equal('aeneas charon-pin', pin, [lock['charon']])
    require_equal('aeneas lean', (aeneas / 'backends/lean/lean-toolchain').read_text().strip(), lock['lean'])
    channel = re.search(r'channel\s*=\s*"([^"]+)"', (charon / 'rust-toolchain').read_text()).group(1)
    require_equal('charon rust', channel, lock['extractor_rust'])
    require_equal('package lean', (ROOT / 'lean-toolchain').read_text().strip(), lock['lean'])
    packages = json.loads((ROOT / 'lake-manifest.json').read_text())['packages']
    require_equal('mathlib', next(p['rev'] for p in packages if p['name'] == 'mathlib'), lock['mathlib'])
    for package in packages:
        if not re.fullmatch('[0-9a-f]{40}', package['rev']):
            raise ValueError(f'unpinned Lake package: {package["name"]}')
    print('Tool source compatibility and all Lake revisions match immutable locks')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aeneas', type=pathlib.Path, required=True)
    parser.add_argument('--charon', type=pathlib.Path, required=True)
    args = parser.parse_args()
    check(args.aeneas, args.charon)
