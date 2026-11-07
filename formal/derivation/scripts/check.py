#!/usr/bin/env python3
"""Bounded Lean source/import and pinned-spec checks; Python 3.11+, standard library only."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[1]
LIBRARIES = {
    'DerivationModel': {'DerivationModel'},
    'DerivationStatements': {'DerivationStatements', 'DerivationModel'},
    'DerivationProofs': {'DerivationProofs', 'DerivationStatements', 'DerivationModel'},
    'DerivationWitnesses': {'DerivationWitnesses', 'DerivationProofs', 'DerivationStatements', 'DerivationModel'},
    'DerivationVectors': {'DerivationVectors', 'DerivationModel'},
}
REVISION = 'd4d18d398936f3fb3fce43f34f0a3b3ebc917d00'
SPEC_PATHS = ['packages/protocol/docs/Derivation.md', 'packages/protocol/docs/etna/ANCHORLESS.md']
CLAIMS = {'DerivationSafety': 'derivation_safety', 'HeaderSafety': 'header_safety',
          'ForcedInclusionSafety': 'forced_inclusion_safety', 'Claims': 'claims'}
GUARDS = {'DerivationWitnesses.Tests.' + name for name in ['Derive', 'Etna', 'Manifest', 'Rlp', 'Zlib']}
FORBIDDEN = set('sorry admit native_decide axiom unsafe partial implemented_by extern opaque '
                'run_elab elab elab_rules macro macro_rules syntax initialize builtin_initialize '
                'declare_syntax_cat register_option set_option attribute by_elab run_tac'.split())
IDENT = re.compile(r'[A-Za-z_][A-Za-z_0-9\'.]*(?:%\b)?')


def tokens(text):
    """Skip nested comments and ordinary escaped strings. Fail closed on quoted identifiers.

    This is a lexer for this package's accepted subset, not a Lean parser. Every remaining
    punctuation character is retained; imported syntax extensions are separately bounded.
    """
    out = []
    i = 0
    while i < len(text):
        if text.startswith('--', i):
            end = text.find('\n', i)
            i = len(text) if end < 0 else end + 1
        elif text.startswith('/-', i):
            depth = 1
            i += 2
            while depth and i < len(text):
                if text.startswith('/-', i):
                    depth += 1
                    i += 2
                elif text.startswith('-/', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            if depth:
                raise ValueError('unterminated block comment')
        elif text[i] == '"':
            i += 1
            while i < len(text) and text[i] != '"':
                i += 2 if text[i] == '\\' else 1
            if i >= len(text):
                raise ValueError('unterminated string')
            i += 1
            out.append('<string>')
        elif text[i] in '«»':
            raise ValueError('quoted identifiers are outside the audited source subset')
        elif text[i].isspace():
            i += 1
        else:
            match = IDENT.match(text, i)
            if match:
                out.append(match.group())
                i = match.end()
            else:
                out.append(text[i])
                i += 1
    return out


def source_errors(module, text):
    try:
        ts = tokens(text)
    except ValueError as exc:
        return [f'{module}: {exc}']
    errors = []
    for i, token in enumerate(ts):
        if (token in FORBIDDEN or token.split('.')[-1] in FORBIDDEN or
                token.startswith(('Lean.', 'debug.'))):
            # The sole explicit Lean import is JSON IO in the vector runner.
            if token == 'Lean.Data.Json' and module == 'DerivationVectors.Main' and i and ts[i - 1] == 'import':
                continue
            errors.append(f'{module}: forbidden token {token}')
        if token == '#' and not (i + 1 < len(ts) and (ts[i + 1] == '[' or (ts[i + 1] == 'guard' and module in GUARDS))):
            errors.append(f'{module}: forbidden command after #')
        if token in {'theorem', 'example'} and module.split('.')[0] in {'DerivationModel', 'DerivationStatements'}:
            errors.append(f'{module}: proof command in definition layer')
    return errors


def imports(ts):
    out = []
    # Header imports may span lines and list multiple modules. A command word ends the list.
    stops = set('import namespace open section end def abbrev structure inductive class instance '
                'theorem example private protected noncomputable universe variable export deriving'.split())
    for i, token in enumerate(ts):
        if token == 'import':
            j = i + 1
            while j < len(ts) and IDENT.fullmatch(ts[j]) and ts[j] not in stops:
                out.append(ts[j])
                j += 1
            if j == i + 1:
                raise ValueError('empty or unsupported import')
    return out


def read_manifest(root):
    return json.loads((root / 'spec-coverage.json').read_text())


def spec_errors(root, data):
    errors = []
    try:
        if not isinstance(data, dict) or set(data) != {'sources', 'claims', 'exclusions', 'drift'}:
            raise ValueError('expected sources, claims, exclusions and drift')
        sources = data['sources']
        if not isinstance(sources, list) or len(sources) != 2 or {s['path'] for s in sources} != set(SPEC_PATHS):
            raise ValueError('exactly both pinned specification paths are required')
        headings = {}
        for s in sources:
            if set(s) != {'path', 'revision', 'sha256'} or s['revision'] != REVISION:
                raise ValueError('wrong pinned revision or source fields')
            contents = (root.parents[1] / s['path']).read_bytes()
            if hashlib.sha256(contents).hexdigest() != s['sha256']:
                errors.append(f"spec drift: {s['path']}; review claims and explicitly repin")
            headings[s['path']] = set(re.findall(r'^#+ (.+)$', contents.decode(), re.M))
        if not isinstance(data['claims'], dict) or set(data['claims']) != set(CLAIMS):
            raise ValueError('all four headline claim links are required')
        for name, link in data['claims'].items():
            if set(link) != {'statement', 'theorem', 'sections'}:
                raise ValueError(f'invalid claim fields: {name}')
            if link['statement'] != f'TaikoSpec.Derivation.Statements.{name}' or link['theorem'] != f'TaikoSpec.Derivation.Proofs.{CLAIMS[name]}':
                raise ValueError(f'incorrect statement/theorem link: {name}')
            if not isinstance(link['sections'], list) or not link['sections']:
                raise ValueError(f'missing spec sections: {name}')
            for section in link['sections']:
                if set(section) != {'path', 'heading'} or section['heading'] not in headings.get(section['path'], set()):
                    raise ValueError(f'invalid specification section: {section}')
        for field in ['exclusions', 'drift']:
            if not isinstance(data[field], list) or not data[field] or not all(isinstance(x, str) and x.strip() for x in data[field]):
                raise ValueError(f'{field} must be a nonempty list of explanations')
    except (KeyError, TypeError, ValueError, OSError) as exc:
        errors.append(f'spec manifest: {exc}')
    return errors


def check(root):
    errors = []
    try:
        config = tomllib.loads((root / 'lakefile.toml').read_text())
        if set(config) != {'name', 'version', 'defaultTargets', 'lean_lib', 'lean_exe'} or any(set(x) != {'name'} for x in config.get('lean_lib', [])):
            errors.append('lakefile: unreviewed configuration or compiler options')
        if [x['name'] for x in config['lean_lib']] != list(LIBRARIES):
            errors.append('lakefile: expected exactly the five ordered libraries')
        if config.get('lean_exe') != [{'name': 'vectors', 'root': 'DerivationVectors.Main'}]:
            errors.append('lakefile: expected the vectors executable only')
        if set(config.get('defaultTargets', [])) != set(LIBRARIES) | {'vectors'}:
            errors.append('lakefile: all five libraries and vectors must be default targets')
        if (root / 'lean-toolchain').read_text().strip() != 'leanprover/lean4:v4.34.1':
            errors.append('Lean toolchain must remain 4.34.1')
        modules = {}
        for lib in LIBRARIES:
            files = [root / (lib + '.lean'), *sorted((root / lib).rglob('*.lean'))]
            for path in files:
                if not path.is_file() or path.is_symlink():
                    errors.append(f'missing or symlinked module: {path}')
                    continue
                module = '.'.join(path.relative_to(root).with_suffix('').parts)
                text = path.read_text()
                errors.extend(source_errors(module, text))
                modules[module] = imports(tokens(text))
        for path in root.glob('*.lean'):
            if path.stem not in LIBRARIES:
                errors.append(f'unclassified root module: {path.name}')
        for module, deps in modules.items():
            for dep in deps:
                if dep == 'Lean.Data.Json' and module == 'DerivationVectors.Main':
                    continue
                if dep.split('.')[0] in {'Init', 'Std'}:
                    continue
                if dep not in modules or dep.split('.')[0] not in LIBRARIES[module.split('.')[0]]:
                    errors.append(f'{module}: forbidden or missing import {dep}')
        for lib in LIBRARIES:
            reached = set()
            todo = [lib]
            while todo:
                module = todo.pop()
                if module in reached:
                    continue
                reached.add(module)
                todo.extend(d for d in modules.get(module, []) if d in modules)
            for module in modules:
                if module.split('.')[0] == lib and module not in reached:
                    errors.append(f'{module}: unreachable from library root')
        errors.extend(spec_errors(root, read_manifest(root)))
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f'check failed: {exc}')
    return errors


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    errors = check(args.root.resolve())
    print('\n'.join(errors) if errors else 'source/import/spec gates: OK')
    sys.exit(bool(errors))
