#!/usr/bin/env python3
"""Generate and execute a Lean kernel/type/transitive-axiom audit from exact manifests."""
import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ALLOWED_AXIOMS = {'propext', 'Classical.choice', 'Quot.sound'}
NAME = re.compile(r'^[A-Za-z_][A-Za-z_0-9]*(\.[A-Za-z_][A-Za-z_0-9]*)*$')


def run(command):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        raise ValueError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def audit(manifests, output):
    entries = []
    for manifest in manifests:
        data = json.loads(pathlib.Path(manifest).read_text())
        if data.get('schema_version') != 1 or 'theorems' not in data:
            raise ValueError('invalid manifest schema')
        entries.extend(data['theorems'])
    if not entries:
        raise ValueError('manifest contains no theorem obligations')
    ids = [entry['id'] for entry in entries]
    if len(ids) != len(set(ids)):
        raise ValueError('duplicate theorem ID')
    for entry in entries:
        for key in ('module', 'declaration'):
            if not NAME.fullmatch(entry[key]):
                raise ValueError(f'invalid or missing {key}: {entry[key]}')
        if not entry['type'] or not isinstance(entry['assumptions'], list):
            raise ValueError('complete type and explicit assumption list required')
        if entry['bridge_level'] != 'spec-proved':
            raise ValueError('core audit accepts only spec-proved declarations')
    run(['lake', 'build'])
    modules = sorted({entry['module'] for entry in entries})
    for module in modules:
        source = ROOT / (module.replace('.', '/') + '.lean')
        target = ROOT / '.lake/build/lib/lean' / (module.replace('.', '/') + '.olean')
        target.parent.mkdir(parents=True, exist_ok=True)
        run(['lake', 'env', 'lean', '-o', str(target), str(source)])
    lines = [f'import {module}' for module in modules]
    lines += ['import Lean', 'set_option pp.universes false', 'set_option pp.explicit true',
              'set_option pp.fullNames true']
    for entry in entries:
        decl = entry['declaration']
        lines += [f'-- {entry["id"]}; explicit assumptions: {json.dumps(entry["assumptions"])}',
                  f'#check ({decl} : {entry["type"]})',
                  f'run_elab do\n  let info ← Lean.getConstInfo `{decl}\n  unless info.isTheorem do throwError \"{decl} is not a theorem\"',
                  f'#print axioms {decl}']
    output.write_text('\n'.join(lines) + '\n')
    result = run(['lake', 'env', 'lean', str(output)])
    for entry in entries:
        decl = entry['declaration']
        match = re.search(re.escape("'" + decl + "'") +
                          r' (?:depends on axioms: \[([^\]]*)\]|does not depend on any axioms)', result)
        if not match:
            raise ValueError(f'missing axiom report for {decl}')
        axioms = set(filter(None, re.split(r'[,\s]+', match.group(1) or '')))
        if axioms - ALLOWED_AXIOMS:
            raise ValueError(f'{decl}: forbidden axioms {sorted(axioms - ALLOWED_AXIOMS)}')
    print(result, end='')
    print(f'Audited {len(entries)} theorem(s); allowed axioms: {sorted(ALLOWED_AXIOMS)}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', action='append', default=[])
    parser.add_argument('--output', type=pathlib.Path, default=ROOT / 'Audit.lean')
    args = parser.parse_args()
    manifests = args.manifest or sorted((ROOT / 'manifests').glob('*.json'))
    try:
        audit(manifests, args.output)
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as error:
        print(f'proof audit failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
