#!/usr/bin/env python3
"""Reject build-time code, trust escapes and foreign dependencies before Lean runs.

The Etna libraries and the Lean regression files must be plain declarations over Init/Std.
This lint runs before `lake build` (so no package code executes first) and again from the
proof audit, and includes the library-graph check (scripts/check_imports.py). It tokenizes
like Lean's lexer (nested block comments, the character skipped after a plain `/-`,
string/char/raw-string literals, `«»` identifiers and numeric literals), so words inside
comments, strings or longer identifiers such as `external` or `initialized` never match,
and code cannot hide behind a lexer mismatch.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tomllib
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
_graph_spec = importlib.util.spec_from_file_location('etna_check_imports', Path(__file__).with_name('check_imports.py'))
GRAPH = importlib.util.module_from_spec(_graph_spec)
_graph_spec.loader.exec_module(GRAPH)
TOOLCHAIN = 'leanprover/lean4:v4.35.0-rc4'

# Keywords/identifiers that run code during elaboration, define syntax/macros, register
# runtime hooks, trust compiled code or skip proofs. Matched against whole tokens only.
FORBIDDEN_TOKENS = {
    'run_cmd', 'run_elab', 'run_meta', 'run_tac', 'by_elab', 'elab', 'elab_rules', 'macro',
    'macro_rules', 'syntax', 'declare_syntax_cat', 'notation', 'infix', 'infixl', 'infixr',
    'prefix', 'postfix', 'binder_predicate', 'initialize', 'unsafe', 'opaque', 'partial',
    'axiom', 'sorry', 'admit', 'native_decide', 'native', 'bv_decide', 'export', 'meta',
    'simproc', 'dsimproc', 'simproc_decl', 'dsimproc_decl', 'register_simp_attr',
    'register_option', 'register_tactic_tag', 'register_label_attr', 'register_linter_set',
    'declare_config_elab', 'declare_command_config_elab', 'implemented_by', 'extern', 'csimp',
    'prelude', 'module', 'public',
}
FORBIDDEN_PREFIXES = ('builtin_',)
# Identifier components that name trust-the-compiler axioms or unsafe evaluation.
FORBIDDEN_COMPONENTS = {
    'ofReduceBool', 'ofReduceNat', 'reduceBool', 'reduceNat', 'trustCompiler',
    'unsafeIO', 'unsafeBaseIO', 'unsafeEIO', 'unsafeCast', 'implemented_by', 'native_decide',
}
FORBIDDEN_OPTIONS = ('debug.', 'trust', 'bootstrap.', 'compiler.', 'interpreter.',
                     'allowUnsafeReducibility')
# Attributes are an allowlist: e.g. `@[macro k]` with only `import Std` rewrites terms.
ALLOWED_ATTRIBUTES = {
    'simp', 'reducible', 'irreducible', 'semireducible', 'instance', 'default_instance',
    'inline', 'noinline', 'specialize', 'ext', 'refl', 'symm', 'congr', 'match_pattern',
    'elab_as_elim', 'induction_eliminator', 'cases_eliminator', 'grind', 'deprecated',
    'inherit_doc', 'norm_cast', 'pp_nodot',
}
ATTRIBUTE_MODIFIERS = {'local', 'scoped'}
ALLOWED_IMPORT_ROOTS = ('Init', 'Std', *GRAPH.LIBRARIES)
# The optional conformance-vector executable, built from the EtnaVectors library.
VECTORS_EXE = [{'name': 'etna-vectors', 'root': 'EtnaVectors.Main'}]
# EtnaVectors renders JSON, so its string literals may contain `{` as long as no `{…}` pair in
# them encloses anything and no interpolation prefix (`s!`, `f!`, `println!`, `dbg_trace`)
# precedes them: an interpolated term between braces is code the token checks would not see.
# Nothing imports EtnaVectors (scripts/check_imports.py) and every other rule applies to it.
VECTORS_LIBRARY = 'EtnaVectors'
HASH_ALLOWED = {'#v'}  # `#v[...]` vector literal; every `#command` is rejected.
BIDI = {chr(c) for c in (*range(0x202A, 0x202F), *range(0x2066, 0x206A), 0x200E, 0x200F, 0x061C)}


class LintError(ValueError):
    pass


def letter_like(ch):
    v = ord(ch)
    return ((0x3b1 <= v <= 0x3c9 and v != 0x3bb) or (0x391 <= v <= 0x3a9 and v not in (0x3a0, 0x3a3))
            or 0x3ca <= v <= 0x3fb or 0x1f00 <= v <= 0x1ffe or 0x2100 <= v <= 0x214f
            or 0x1d49c <= v <= 0x1d59f)


def subscript_alnum(ch):
    v = ord(ch)
    return 0x2080 <= v <= 0x2089 or 0x2090 <= v <= 0x209c or 0x1d62 <= v <= 0x1d6a


def digit(ch):
    return ch != '' and ch in '0123456789'


def id_first(ch):
    return (ch.isascii() and ch.isalpha()) or ch == '_' or letter_like(ch)


def id_rest(ch):
    return (id_first(ch) or digit(ch) or ch in "'!?" or subscript_alnum(ch))


def tokenize(text):
    """Return Lean-like tokens: (kind, value, line); comments are skipped.

    kinds: ident (value = tuple of components), string (body), char, raw, number, symbol.
    """
    out, i, n, line = [], 0, len(text), 1

    def at(k):
        return text[k] if k < n else ''

    while i < n:
        c = text[i]
        if c == '\n':
            line, i = line+1, i+1
            continue
        if c.isspace():
            i += 1
            continue
        if text.startswith('--', i):
            j = text.find('\n', i)
            i = n if j < 0 else j
            continue
        if text.startswith('/-', i):
            # Lean's whitespace skips the character after a plain `/-`; doc comments
            # `/--` and `/-!` also begin their body after three characters.
            depth, j = 1, i+3
            while depth:
                if j >= n:
                    raise LintError(f'line {line}: unterminated block comment')
                if text.startswith('-/', j):
                    depth, j = depth-1, j+2
                elif text.startswith('/-', j):
                    depth, j = depth+1, j+2
                else:
                    j += 1
            line += text.count('\n', i, j)
            i = j
            continue
        start = line
        if c == '"':
            j = i+1
            while True:
                if j >= n:
                    raise LintError(f'line {start}: unterminated string literal')
                if text[j] == '\\':
                    j += 2
                elif text[j] == '"':
                    break
                else:
                    j += 1
            out.append(('string', text[i+1:j], start))
            line += text.count('\n', i, j+1)
            i = j+1
            continue
        if c == "'" and at(i+1) != "'":
            j = i+1
            if at(j) == '\\':
                j += {'x': 4, 'u': 6}.get(at(j+1), 2)
            else:
                j += 1
            if at(j) != "'":
                raise LintError(f'line {start}: malformed character literal')
            out.append(('char', text[i+1:j], start))
            i = j+1
            continue
        if digit(c):
            j = i+1
            if c == '0' and at(j) in ('x', 'X', 'b', 'B', 'o', 'O'):
                digits = {'x': '0123456789abcdefABCDEF_', 'b': '01_', 'o': '01234567_'}[at(j).lower()]
                j += 1
                while at(j) and at(j) in digits:
                    j += 1
            else:
                while digit(at(j)) or at(j) == '_':
                    j += 1
                if at(j) == '.' and digit(at(j+1)):
                    j += 1
                    while digit(at(j)) or at(j) == '_':
                        j += 1
                if at(j) in ('e', 'E'):
                    k = j+1+(at(j+1) in ('+', '-'))
                    if digit(at(k)):
                        j = k
                        while digit(at(j)) or at(j) == '_':
                            j += 1
            out.append(('number', text[i:j], start))
            i = j
            continue
        if c == 'r' and (at(i+1) == '"' or at(i+1) == '#'):
            k = i+1
            while at(k) == '#':
                k += 1
            if at(k) == '"':
                hashes = k-i-1
                close = '"'+'#'*hashes
                j = text.find(close, k+1)
                if j < 0:
                    raise LintError(f'line {start}: unterminated raw string literal')
                out.append(('raw', text[k+1:j], start))
                line += text.count('\n', i, j)
                i = j+len(close)
                continue
        if c == '`' and (id_first(at(i+1)) or at(i+1) == '«'):
            i += 1
            c = text[i]
        if id_first(c) or c == '«':
            parts, j = [], i
            while True:
                if at(j) == '«':
                    k = text.find('»', j+1)
                    if k < 0:
                        raise LintError(f'line {start}: unterminated identifier escape')
                    parts.append(text[j+1:k])
                    line += text.count('\n', j, k)
                    j = k+1
                else:
                    k = j+1
                    while k < n and id_rest(text[k]):
                        k += 1
                    parts.append(text[j:k])
                    j = k
                if at(j) == '.' and (id_first(at(j+1)) or at(j+1) == '«'):
                    j += 1
                    continue
                break
            out.append(('ident', tuple(parts), start))
            i = j
            continue
        if c == '#' and id_first(at(i+1)):
            j = i+1
            while j < n and id_rest(text[j]):
                j += 1
            out.append(('hash', text[i:j], start))
            i = j
            continue
        if c == '@' and at(i+1) == '[':
            out.append(('symbol', '@[', start))
            i += 2
            continue
        if c in (']', 'Σ', '×') and at(i+1) == "'":
            # Init tokens `]'`, `Σ'`, `×'` win over a character literal (longest match).
            out.append(('symbol', c+"'", start))
            i += 2
            continue
        if c == '#' and at(i+1) == "'":
            raise LintError(f"line {start}: `#'` is ambiguous (scoped BitVec token or char literal)")
        out.append(('symbol', c, start))
        i += 1
    return out


def dotted(parts):
    return '.'.join(parts)


def attribute_errors(tokens, k, where):
    """Check one bracketed attribute list starting after its `[`; return (errors, end)."""
    errors, depth, item_start = [], 1, True
    while k < len(tokens) and depth:
        kind, value, line = tokens[k]
        if kind == 'symbol' and value in ('[', '@['):
            depth += 1
        elif kind == 'symbol' and value == ']':
            depth -= 1
        elif depth == 1 and kind == 'symbol' and value == ',':
            item_start = True
            k += 1
            continue
        elif depth == 1 and item_start:
            if kind == 'symbol' and value == '-':
                k += 1
                continue
            if kind == 'ident' and dotted(value) in ATTRIBUTE_MODIFIERS:
                k += 1
                continue
            name = dotted(value) if kind == 'ident' else str(value)
            if kind != 'ident' or name not in ALLOWED_ATTRIBUTES:
                errors.append(f'{where}:{line}: attribute `{name}` is not in the reviewed allowlist')
            item_start = False
        k += 1
    return errors, k


def interpolated(tokens, index):
    """Whether the string token at `index` could hold an interpolated term: some `{…}` pair in it
    encloses something, or an interpolation prefix (`s!`, `f!`, `println!`, `dbg_trace`) precedes it."""
    value = tokens[index][1]
    previous = tokens[index-1] if index > 0 else None
    prefixed = previous is not None and previous[0] == 'ident' and (
        previous[1][-1].endswith('!') or previous[1] == ('dbg_trace',))
    return prefixed or re.search(r'\{[^}]+\}', value) is not None


def vectors_source(root, path):
    """Whether `path` is a module of the EtnaVectors library."""
    first = path.relative_to(root).parts[0]
    return first in (VECTORS_LIBRARY, VECTORS_LIBRARY+'.lean')


def lint_text(text, where='<input>', vectors=False):
    """Return lint errors for one Lean source text; `vectors` marks an EtnaVectors source, whose
    non-interpolated string literals may contain `{`."""
    errors = []
    bad = sorted({f'U+{ord(ch):04X}' for ch in text if ch in BIDI or (unicodedata.category(ch) == 'Cc' and ch not in '\n')})
    if bad:
        errors.append(f'{where}: control/bidirectional characters are not allowed: {", ".join(bad)}')
    try:
        tokens = tokenize(text)
    except LintError as exc:
        return errors+[f'{where}:{exc}']
    k = 0
    while k < len(tokens) and tokens[k][:2] == ('ident', ('import',)):
        line = tokens[k][2]
        if k+1 >= len(tokens) or tokens[k+1][0] != 'ident':
            errors.append(f'{where}:{line}: malformed import')
            break
        module = tokens[k+1][1]
        if module[0] not in ALLOWED_IMPORT_ROOTS:
            errors.append(f'{where}:{line}: import `{dotted(module)}` is outside Init/Std and the Etna libraries')
        k += 2
    for index, (kind, value, line) in enumerate(tokens):
        if kind == 'ident':
            name = dotted(value)
            if index >= k and value == ('import',):
                errors.append(f'{where}:{line}: import after the module header')
            if len(value) == 1 and (name in FORBIDDEN_TOKENS or name.startswith(FORBIDDEN_PREFIXES)):
                errors.append(f'{where}:{line}: forbidden keyword `{name}`')
            elif FORBIDDEN_COMPONENTS.intersection(value):
                errors.append(f'{where}:{line}: forbidden identifier `{name}`')
            if value == ('set_option',):
                option = tokens[index+1] if index+1 < len(tokens) else None
                if option is None or option[0] != 'ident':
                    errors.append(f'{where}:{line}: malformed set_option')
                elif dotted(option[1]).startswith(FORBIDDEN_OPTIONS):
                    errors.append(f'{where}:{line}: forbidden option `{dotted(option[1])}`')
            if value == ('attribute',) and index+1 < len(tokens) and tokens[index+1][:2] == ('symbol', '['):
                errors += attribute_errors(tokens, index+2, where)[0]
        elif kind == 'hash' and not (value in HASH_ALLOWED and index+1 < len(tokens)
                                     and tokens[index+1][:2] == ('symbol', '[')):
            errors.append(f'{where}:{line}: forbidden command `{value}`')
        elif kind == 'symbol' and value == '@[':
            errors += attribute_errors(tokens, index+1, where)[0]
        elif kind == 'string' and '{' in value and not (vectors and not interpolated(tokens, index)):
            errors.append(f'{where}:{line}: string literal with `{{` (interpolation) is not allowed')
    return errors


def package_errors(root=ROOT):
    """The package is the Etna libraries only, with no dependencies or build options."""
    errors = []
    if (root/'lakefile.lean').exists():
        errors.append('lakefile.lean is not allowed (it is arbitrary build code)')
    try:
        config = tomllib.loads((root/'lakefile.toml').read_text())
    except (OSError, tomllib.TOMLDecodeError) as exc:
        return errors+[f'lakefile.toml unreadable: {exc}']
    errors += GRAPH.lakefile_errors(root)
    libs = config.get('lean_lib')
    names = [lib.get('name') for lib in libs if isinstance(lib, dict)] if isinstance(libs, list) else []
    canonical = [name for name in GRAPH.LIBRARIES if name in names]
    expected = {'name': 'etna', 'version': config.get('version'), 'defaultTargets': canonical,
                'lean_lib': [{'name': name} for name in canonical]}
    if 'EtnaVectors' in canonical and 'lean_exe' in config:
        expected['lean_exe'] = VECTORS_EXE
    if config != expected or not isinstance(config.get('version'), str):
        errors.append('lakefile.toml must declare only name/version, defaultTargets listing the declared '
                      'libraries, and one plain [[lean_lib]] per Etna library in the order '
                      f'{", ".join(GRAPH.LIBRARIES)} (plus, with EtnaVectors, the [[lean_exe]] etna-vectors '
                      'rooted at EtnaVectors.Main; no requires, options or other targets)')
    try:
        manifest = json.loads((root/'lake-manifest.json').read_text())
        if manifest.get('packages') != []:
            errors.append('lake-manifest.json must not list dependency packages')
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f'lake-manifest.json unreadable: {exc}')
    try:
        if (root/'lean-toolchain').read_text().strip() != TOOLCHAIN:
            errors.append('lean-toolchain must pin '+TOOLCHAIN)
    except OSError as exc:
        errors.append(f'lean-toolchain unreadable: {exc}')
    return errors


def tracked_build_outputs(root=ROOT):
    """Committed Lake/olean state could make `lake build` reuse artifacts that differ from
    the reviewed sources; build outputs must never be tracked."""
    try:
        result = subprocess.run(['git', '-C', str(root), 'ls-files', '-z', '--', '.lake', '.scratch',
                                 ':(glob)**/*.olean', ':(glob)**/*.ilean'], capture_output=True, text=True)
    except OSError:
        return []
    if result.returncode:  # not a git checkout (e.g. a temporary mutation copy)
        return []
    return [p for p in result.stdout.split('\0') if p]


def lean_sources(root=ROOT):
    files = [p for library in GRAPH.LIBRARIES for p in GRAPH.library_files(root, library)]
    return files+sorted((root/'tests').glob('*.lean'))


def lint(root=ROOT):
    errors = package_errors(root)
    tracked = tracked_build_outputs(root)
    if tracked:
        errors.append('tracked build outputs are not allowed: '+', '.join(tracked[:5]))
    for path in lean_sources(root):
        try:
            text = path.read_bytes().decode('utf-8')
        except (OSError, UnicodeDecodeError) as exc:
            errors.append(f'{path.relative_to(root)}: unreadable UTF-8 source: {exc}')
            continue
        errors += lint_text(text, str(path.relative_to(root)), vectors=vectors_source(root, path))
    return errors+GRAPH.graph_errors(root)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    errors = lint(args.root.resolve())
    if errors:
        print('source lint failed:\n  '+'\n  '.join(errors), file=sys.stderr)
        return 1
    print(f'Linted {len(lean_sources(args.root.resolve()))} Lean sources, the package configuration and the '
          'library import graph.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
