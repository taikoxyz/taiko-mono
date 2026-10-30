#!/usr/bin/env python3
"""Check the Etna library graph before Lean runs.

The package is split so a reviewer reads definitions and claims without proofs:

  EtnaModel       definitions, structures, inductives, instances (no theorems)
  EtnaStatements  the premise record and headline claims, stated without proofs
  EtnaProofs      theorems about the model and proofs of the claims
  EtnaWitnesses   regressions, satisfying runs and counterexamples
  EtnaVectors     the conformance-vector generator (optional; reads only the model)

Each library is one Lake `lean_lib` with root `<Name>.lean` and modules `<Name>/**/*.lean`.
A module may import Init, Std, its own library and the libraries below it:
EtnaWitnesses -> EtnaProofs -> EtnaStatements -> EtnaModel, and EtnaVectors -> EtnaModel.
This checks the lakefile's library names, every module's imports, that each module is
reachable from its library root (otherwise Lake would not build it), and that Model and
Statements sources declare no `theorem` outside ALLOWED_MODEL_THEOREMS. The check is on
source tokens (scripts/lint_sources.py's Lean lexer), so it fails before Lean runs; the proof
audit (scripts/EtnaAudit.lean `checkLibraryContents`) checks the built declarations: no
theorem, axiom, `opaque` constant or proof-valued definition in Model/Statements (apart from
ALLOWED_MODEL_THEOREMS), no public non-theorem in EtnaProofs, and `Etna.Proofs` only in
EtnaProofs.Headline.
"""
import argparse
import importlib.util
from pathlib import Path
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[1]

# Library -> libraries its modules may import (besides Init and Std), in canonical order.
LIBRARIES = {
    'EtnaModel': ('EtnaModel',),
    'EtnaStatements': ('EtnaStatements', 'EtnaModel'),
    'EtnaProofs': ('EtnaProofs', 'EtnaStatements', 'EtnaModel'),
    'EtnaWitnesses': ('EtnaWitnesses', 'EtnaProofs', 'EtnaStatements', 'EtnaModel'),
    'EtnaVectors': ('EtnaVectors', 'EtnaModel'),
}
REQUIRED_LIBRARIES = ('EtnaModel', 'EtnaStatements', 'EtnaProofs', 'EtnaWitnesses')
THEOREM_FREE_LIBRARIES = ('EtnaModel', 'EtnaStatements')
STANDARD_ROOTS = ('Init', 'Std')

# Theorems a definition genuinely needs (cited by a definition body, a termination proof or
# a structure field), so they must sit next to the definitions. Keep this list minimal.
ALLOWED_MODEL_THEOREMS = {
}

_LEXER = []


def lexer():
    """scripts/lint_sources.py, loaded on first use (the lint loads this module at import time)."""
    if not _LEXER:
        spec = importlib.util.spec_from_file_location('etna_import_lexer', Path(__file__).with_name('lint_sources.py'))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _LEXER.append(module)
    return _LEXER[0]


def declared_libraries(root=ROOT):
    """`lean_lib` names in lakefile.toml order (raises on an unreadable lakefile)."""
    config = tomllib.loads((root/'lakefile.toml').read_text())
    libs = config.get('lean_lib', [])
    if not isinstance(libs, list):
        raise ValueError('lakefile.toml: lean_lib must be a list of tables')
    return [lib.get('name') if isinstance(lib, dict) else None for lib in libs]


def lakefile_errors(root=ROOT):
    try:
        names = declared_libraries(root)
    except (OSError, ValueError, tomllib.TOMLDecodeError) as exc:
        return [f'lakefile.toml unreadable: {exc}']
    errors = []
    for name in names:
        if name not in LIBRARIES:
            errors.append(f'lakefile.toml: library {name!r} is not one of the Etna libraries '
                          f'({", ".join(LIBRARIES)})')
    if len(names) != len(set(names)):
        errors.append('lakefile.toml: duplicate lean_lib names')
    for name in REQUIRED_LIBRARIES:
        if name not in names:
            errors.append(f'lakefile.toml: required library {name} is missing')
    return errors


def module_name(root, path):
    return '.'.join(path.relative_to(root).with_suffix('').parts)


def library_files(root, library):
    files = [root/f'{library}.lean', *sorted((root/library).rglob('*.lean'))]
    return [p for p in files if p.exists()]


def module_path(root, module):
    return root.joinpath(*module.split('.')).with_suffix('.lean')


def read_tokens(path, root, errors):
    try:
        return lexer().tokenize(path.read_bytes().decode('utf-8'))
    except (OSError, UnicodeDecodeError, lexer().LintError) as exc:
        errors.append(f'{path.relative_to(root)}: unreadable Lean source: {exc}')
        return None


def header_imports(tokens):
    """Imported module names of the leading `import` commands."""
    out, k = [], 0
    while k+1 < len(tokens) and tokens[k][:2] == ('ident', ('import',)) and tokens[k+1][0] == 'ident':
        out.append(('.'.join(tokens[k+1][1]), tokens[k][2]))
        k += 2
    return out


def theorems(tokens):
    """(full user name, line) of each `theorem` command, tracking namespaces and sections."""
    scopes, found = [], []  # one entry per namespace component; None for a section/mutual block

    def name_after(index):
        if index+1 < len(tokens) and tokens[index+1][0] == 'ident' and tokens[index+1][2] == tokens[index][2]:
            return tokens[index+1][1]
        return ()

    for index, (kind, value, line) in enumerate(tokens):
        if kind != 'ident':
            continue
        if value == ('namespace',):
            scopes += name_after(index)
        elif value in (('section',), ('mutual',)):
            scopes.append(None)
        elif value == ('end',) and scopes:
            count = 1 if scopes[-1] is None else max(1, len(name_after(index)))
            del scopes[-count:]
        elif value == ('theorem',) and index+1 < len(tokens) and tokens[index+1][0] == 'ident':
            parts = tokens[index+1][1]
            full = parts[1:] if parts[0] == '_root_' else tuple(c for c in scopes if c)+parts
            found.append(('.'.join(full), line))
    return found


def graph_errors(root=ROOT, libraries=None):
    """Import direction, root reachability and theorem-free Model/Statements sources."""
    if libraries is None:
        try:
            libraries = [n for n in declared_libraries(root) if n in LIBRARIES]
        except (OSError, ValueError, tomllib.TOMLDecodeError):
            libraries = list(LIBRARIES)
    errors, seen_allowed = [], set()
    for library in LIBRARIES:
        files = library_files(root, library)
        if library not in libraries:
            for path in files:
                errors.append(f'{path.relative_to(root)}: no [[lean_lib]] {library} in lakefile.toml builds it')
            continue
        allowed = LIBRARIES[library]
        graph = {}
        for path in files:
            where = str(path.relative_to(root))
            tokens = read_tokens(path, root, errors)
            if tokens is None:
                continue
            imports = header_imports(tokens)
            graph[module_name(root, path)] = [m for m, _ in imports]
            for module, line in imports:
                top = module.split('.')[0]
                if top in STANDARD_ROOTS:
                    continue
                if top not in allowed:
                    errors.append(f'{where}:{line}: {library} may import only Init, Std and '
                                  f'{", ".join(allowed)}; `{module}` is not allowed')
                elif top in LIBRARIES and not module_path(root, module).exists():
                    errors.append(f'{where}:{line}: imported module `{module}` has no source file')
            if library in THEOREM_FREE_LIBRARIES:
                for name, line in theorems(tokens):
                    if name in ALLOWED_MODEL_THEOREMS:
                        seen_allowed.add(name)
                    else:
                        errors.append(f'{where}:{line}: theorem `{name}` in {library}: Model and Statements hold '
                                      'no proofs; move it to EtnaProofs or list it in ALLOWED_MODEL_THEOREMS '
                                      '(scripts/check_imports.py) with the definition that needs it')
        reached, todo = set(), [library]
        while todo:
            module = todo.pop()
            if module in reached or module not in graph:
                continue
            reached.add(module)
            todo += [m for m in graph[module] if m.split('.')[0] == library]
        for module in sorted(set(graph)-reached):
            errors.append(f'{module_path(root, module).relative_to(root)}: not imported from {library}.lean, '
                          'so Lake would not build it')
    for name, reason in ALLOWED_MODEL_THEOREMS.items():
        if not isinstance(reason, str) or not reason.strip():
            errors.append(f'ALLOWED_MODEL_THEOREMS: {name} needs a reason')
        if name not in seen_allowed:
            errors.append(f'ALLOWED_MODEL_THEOREMS: stale entry {name} (no such theorem in Model or Statements)')
    return errors


def errors(root=ROOT):
    return lakefile_errors(root)+graph_errors(root)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    root = args.root.resolve()
    found = errors(root)
    if found:
        print('import check failed:\n  '+'\n  '.join(found), file=sys.stderr)
        return 1
    libraries = declared_libraries(root)
    count = sum(len(library_files(root, lib)) for lib in libraries)
    print(f'Checked the import graph of {count} modules in {len(libraries)} libraries '
          f'({", ".join(libraries)}); {len(ALLOWED_MODEL_THEOREMS)} allowlisted Model theorems.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
