#!/usr/bin/env python3
"""Lock the review surface: the headline/witness statements and every definition they mean.

The review surface starts at the four headline theorems and the five joint-premise witnesses
(audit_proofs.CURRENT_*). From their kernel types it follows every Etna constant they use:
definitions, inductives, constructors and recursors contribute their type and value;
theorems contribute their type only, so proofs never enter the surface. Init/Std constants
are recorded by name (the toolchain is pinned). Each constant's kernel terms are hashed
(SHA-256 of their `repr`) into review-surface.lock.json.

  review_surface.py            recompute and write review-surface.lock.json (after lake build)
  review_surface.py --check    recompute and require the committed lock to match
  review_surface.py --against REF
                               no Lean: compare the committed lock and the gate files with
                               REF; exit 3 and print the changed constants/files if they differ

CI runs `--against` from the base revision's copy of this script, so a pull request cannot
weaken the comparison it is judged by. A difference needs the `formal-statement-change` label.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
LOCK = ROOT/'review-surface.lock.json'
LOCK_PATH = 'formal/etna/review-surface.lock.json'
# Files that define how evidence is judged. Changing one needs the same review as a statement.
GATE_PATHS = ('formal/etna/scripts', ':(glob)formal/etna/tests/*.py', 'formal/etna/lakefile.toml',
              'formal/etna/lean-toolchain', 'formal/etna/lake-manifest.json',
              '.github/workflows/formal--etna.yml')
SCOPE = ('Kernel terms of the headline/witness statements and of every Etna definition they use; '
         'theorem proofs are excluded. A change here changes what H1-H3 or the witnesses mean.')

PROGRAM = r'''import Lean
import EtnaModel
import EtnaStatements
import EtnaProofs
import EtnaWitnesses
open Lean Elab Command

run_cmd do
  let env ← getEnv
  let mods := env.header.moduleNames
  let etna (n : Name) : Bool := match env.getModuleIdxFor? n with
    | some i => (mods[i.toNat]!).getRoot.toString.startsWith "Etna"
    | none => false
  let mut seen : NameSet := {}
  let mut stack : Array Name := (@@ROOTS@@ : List String).toArray.map String.toName
  let mut out : Array String := #[]
  while !stack.isEmpty do
    let n := stack.back!
    stack := stack.pop
    if seen.contains n then continue
    seen := seen.insert n
    let some ci := env.find? n | throwError m!"unknown review-surface constant {n}"
    if !etna n then
      out := out.push (Json.compress (Json.mkObj [("name", Json.str n.toString), ("kind", "external")]))
      continue
    let r (e : Expr) : Json := Json.str (reprStr e)
    let (kind, parts, deps) : String × List Json × Array Name := match ci with
      | .thmInfo v => ("theorem", [r v.type], v.type.getUsedConstants)
      | .defnInfo v => ("def", [r v.type, r v.value], v.type.getUsedConstants ++ v.value.getUsedConstants)
      | .opaqueInfo v => ("opaque", [r v.type, r v.value], v.type.getUsedConstants ++ v.value.getUsedConstants)
      | .inductInfo v => ("inductive", [r v.type, Json.str (toString v.ctors), Json.num v.numParams,
          Json.num v.numIndices], v.type.getUsedConstants ++ v.ctors.toArray)
      | .ctorInfo v => ("constructor", [r v.type], v.type.getUsedConstants.push v.induct)
      | .recInfo v => ("recursor", [r v.type], v.type.getUsedConstants)
      | .axiomInfo v => ("axiom", [r v.type], v.type.getUsedConstants)
      | .quotInfo v => ("quot", [r v.type], v.type.getUsedConstants)
    out := out.push (Json.compress (Json.mkObj
      [("name", Json.str n.toString), ("kind", Json.str kind), ("parts", Json.arr parts.toArray)]))
    for d in deps do
      if !seen.contains d then stack := stack.push d
  IO.FS.writeFile @@OUT@@ (String.intercalate "\n" out.toList ++ "\n")
'''


def _audit():
    import importlib.util
    spec = importlib.util.spec_from_file_location('etna_audit_proofs', Path(__file__).with_name('audit_proofs.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def roots():
    audit = _audit()
    return [audit.CURRENT_CLAIMS[0], *audit.CURRENT_HEADLINES, audit.CURRENT_ACCEPTING_WITNESS,
            *audit.CURRENT_PROFILE_WITNESSES]


def lean_string(text):
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


def compute(root=ROOT):
    """The lock document for the built tree (requires `lake build`)."""
    names = roots()
    work = root/'.scratch/generated'
    work.mkdir(parents=True, exist_ok=True)
    source, out = work/'ReviewSurface.lean', work/'review-surface.jsonl'
    source.write_text(PROGRAM.replace('@@ROOTS@@', '[' + ', '.join(lean_string(n) for n in names) + ']')
                      .replace('@@OUT@@', lean_string(str(out))))
    result = subprocess.run(['lake', 'env', 'lean', str(source)], cwd=root, capture_output=True, text=True)
    if result.returncode or result.stdout.strip() or result.stderr.strip():
        raise ValueError('review-surface extraction failed: ' + (result.stdout + result.stderr)[-2000:])
    constants = {}
    for line in out.read_text().splitlines():
        row = json.loads(line)
        if row['kind'] == 'external':
            constants[row['name']] = 'external'
        else:
            body = json.dumps([row['kind'], row['parts']], ensure_ascii=False, separators=(',', ':'))
            constants[row['name']] = row['kind'] + ':' + hashlib.sha256(body.encode()).hexdigest()
    constants = dict(sorted(constants.items()))
    digest = hashlib.sha256(''.join(f'{k} {v}\n' for k, v in constants.items()).encode()).hexdigest()
    return dict(schema_version=1, scope=SCOPE, toolchain=(root/'lean-toolchain').read_text().strip(),
                roots=names, sha256=digest, constants=constants)


def render(lock):
    return json.dumps(lock, ensure_ascii=False, indent=2) + '\n'


def diff(old, new):
    """Human-readable differences between two lock documents."""
    lines = []
    for key in ('toolchain', 'roots'):
        if old.get(key) != new.get(key):
            lines.append(f'- {key}: {old.get(key)!r} -> {new.get(key)!r}')
    a, b = old.get('constants', {}), new.get('constants', {})
    for name in sorted(set(a) | set(b)):
        if name not in b:
            lines.append(f'- removed `{name}`')
        elif name not in a:
            lines.append(f'- added `{name}` ({b[name].split(":")[0]})')
        elif a[name] != b[name]:
            lines.append(f'- changed `{name}` ({b[name].split(":")[0]})')
    return lines


def git(repo, *args):
    return subprocess.run(['git', '-C', str(repo), *args], capture_output=True, text=True)


def against(ref, repo=None):
    """Compare the committed lock and gate files of the checkout in the current directory
    with `ref`. Returns (status, markdown). Runs from any copy of this file: CI executes the
    base revision's copy outside the checkout."""
    if repo is None:
        top = subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True)
        if top.returncode:
            raise ValueError('run --against inside the repository checkout')
        repo = Path(top.stdout.strip())
    base = git(repo, 'show', f'{ref}:{LOCK_PATH}')
    if base.returncode:
        return 0, (f'Review surface: `{ref}` has no `{LOCK_PATH}`; this change introduces the lock '
                   '(bootstrap), so there is nothing to compare.')
    changes = diff(json.loads(base.stdout), json.loads((repo/LOCK_PATH).read_text()))
    files = git(repo, 'diff', '--name-only', ref, '--', *GATE_PATHS)
    if files.returncode:
        raise ValueError('git diff failed: ' + files.stderr)
    gates = [f for f in files.stdout.split('\n') if f]
    if not changes and not gates:
        return 0, f'Review surface and gate files are unchanged from `{ref}`.'
    text = [f'Review surface or gate files differ from `{ref}`. A reviewer must read these changes '
            'and apply the `formal-statement-change` label.', '']
    if changes:
        text += ['Statement surface:', *changes[:300], '']
    if gates:
        text += ['Gate files:', *(f'- `{f}`' for f in gates)]
    return 3, '\n'.join(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--check', action='store_true')
    group.add_argument('--against', metavar='REF')
    args = parser.parse_args()
    try:
        if args.against:
            status, text = against(args.against)
            print(text)
            return status
        lock = compute()
        if args.check:
            if not LOCK.is_file():
                raise ValueError('missing review-surface.lock.json; run python3 scripts/review_surface.py')
            changes = diff(json.loads(LOCK.read_text()), lock)
            if changes or LOCK.read_text() != render(lock):
                raise ValueError('review-surface.lock.json is stale; run python3 scripts/review_surface.py and '
                                 'review the changes:\n  ' + '\n  '.join(changes[:50]))
            print(f'Review surface matches the lock: {len(lock["constants"])} constants, sha256 {lock["sha256"]}.')
        else:
            LOCK.write_text(render(lock))
            print(f'Wrote review-surface.lock.json: {len(lock["constants"])} constants, sha256 {lock["sha256"]}.')
        return 0
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as exc:
        print('review surface failed: ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
