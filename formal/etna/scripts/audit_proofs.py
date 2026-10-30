#!/usr/bin/env python3
"""Local exact-type and kernel-replay audit; not automatic specification equivalence.

Order: source/package lint and library graph (scripts/lint_sources.py, which runs
scripts/check_imports.py) before any Lean runs, manifest and shadowing-allowlist schema,
pinned compiler, zero-warning `lake build`, fresh conformance vectors
(scripts/check_vectors.py), a fresh kernel replay of every Etna library and its whole import
closure (`leanchecker --fresh`), then a generated Audit module (checks compiled separately in
scripts/EtnaAudit.lean, manifest types passed as string data) and the Lean regression files in
tests/, each kernel-replayed.

The generated module checks every manifest entry (exact type, mechanical role, axioms), the
package (namespaces, manifest modules, axioms, shadowing, what each library may hold, manifest
completeness) and the headline layer: `Etna.Proofs.claims` and the three headline theorems
have exactly their statement-layer claim as type and only the standard axioms, and every field
of `Etna.Statements.Premises` is read by at least one headline proof.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
ALLOWED_AXIOMS = {'propext', 'Classical.choice', 'Quot.sound'}
ROLES = {'property', 'constant', 'supporting', 'regression'}
# Model theorems keep the model's namespace; the headline claims' proofs live in `Etna.Proofs`.
ACTIVE_NAMESPACES = ('Etna.Design.', 'Etna.Proofs.')
# Libraries that hold manifested theorems. EtnaModel/EtnaStatements hold none, apart from the
# definition-obligation theorems allowlisted in scripts/check_imports.py ALLOWED_MODEL_THEOREMS.
THEOREM_LIBRARIES = ('EtnaProofs', 'EtnaWitnesses')
HEADLINE_MODULES = 'EtnaProofs.Headline.'
# The headline layer: theorem -> the statement-layer claim that is exactly its type. `CLAIMS`
# is the conjunction; every premise field must be read by one of the three HEADLINES' proofs.
CLAIMS = ('Etna.Proofs.claims', 'Etna.Statements.Claims')
HEADLINES = {
    'Etna.Proofs.fund_safety': 'Etna.Statements.FundSafety',
    'Etna.Proofs.accountable_finality': 'Etna.Statements.AccountableFinality',
    'Etna.Proofs.forced_inclusion_integrity': 'Etna.Statements.ForcedInclusionIntegrity',
}
PREMISES = 'Etna.Statements.Premises'
PREMISE_USE = re.compile(r'^premise use: (\S+) <- (.+)$', re.MULTILINE)
NAME = re.compile(r'^[A-Za-z_][A-Za-z_0-9]*(\.[A-Za-z_][A-Za-z_0-9]*)*$')
ANY_NAME = re.compile(r"^[A-Za-z_][A-Za-z_0-9'!?]*(\.[A-Za-z_][A-Za-z_0-9'!?]*)*$")
TEST_STEM = re.compile(r'^[A-Z][A-Za-z0-9_]*$')


def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(file))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


LINT = _load('etna_lint_sources', 'lint_sources.py')
GRAPH = LINT.GRAPH
COVERAGE = _load('etna_spec_coverage', 'check_spec_coverage.py')
VECTORS = _load('etna_check_vectors', 'check_vectors.py')


def run(command, cwd=ROOT):
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if result.returncode:
        raise ValueError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def lean_string(text):
    """Escape data as a Lean string literal (manifest text is never pasted as code)."""
    for ch in text:
        if (unicodedata.category(ch) in ('Cc', 'Cf', 'Cs') and ch != '\n') or ch in LINT.BIDI:
            raise ValueError(f'control/format character U+{ord(ch):04X} not allowed in audit data')
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


def validate_entries(entries):
    if not isinstance(entries,list) or not entries:
        raise ValueError('missing theorem obligations')
    names = set()
    for entry in entries:
        expected = {'module','declaration','type','assumptions','bridge_level','role','sources','scope'}
        if set(entry) != expected:
            raise ValueError('invalid theorem schema')
        name = entry['declaration']
        if name in names:
            raise ValueError('duplicate theorem identity: '+str(name))
        names.add(name)
        for key, valid in (('module', lambda m: m.split('.')[0] in GRAPH.LIBRARIES),
                           ('declaration', lambda d: d.startswith(ACTIVE_NAMESPACES))):
            if not isinstance(entry[key],str) or not NAME.fullmatch(entry[key]) or not valid(entry[key]):
                raise ValueError('invalid active module/declaration: '+str(entry[key]))
        module = entry['module']
        if module.split('.')[0] not in THEOREM_LIBRARIES and name not in GRAPH.ALLOWED_MODEL_THEOREMS:
            raise ValueError(f'manifest module {module} of {name}: theorems live in '
                             f'{" or ".join(THEOREM_LIBRARIES)} (EtnaModel/EtnaStatements only for an '
                             'ALLOWED_MODEL_THEOREMS entry, scripts/check_imports.py)')
        if name.startswith('Etna.Proofs.') and not module.startswith(HEADLINE_MODULES):
            raise ValueError(f'manifest module {module} of {name}: the Etna.Proofs namespace (the headline '
                             f'proofs) lives in {HEADLINE_MODULES}*')
        if not isinstance(entry['type'],str) or not entry['type'].strip():
            raise ValueError('full theorem type required: '+name)
        lean_string(entry['type'])
        if not isinstance(entry['assumptions'],list) or not entry['assumptions']:
            raise ValueError('named proof boundaries required: '+name)
        if entry['bridge_level'] != 'spec-proved':
            raise ValueError('the design model claims specification proofs only: '+name)
        unsourced = isinstance(entry['sources'],list) and not entry['sources'] and name in COVERAGE.UNSOURCED
        if entry['role'] not in ROLES or not (entry['sources'] or unsourced) or not entry['scope'].strip():
            raise ValueError('theorem evidence role/source/scope required: '+name)


def validate_contract(manifest, root=ROOT):
    if manifest.get('schema_version') != 2 or manifest.get('spec_version') != 1:
        raise ValueError('design manifest schema/version required')
    validate_entries(manifest['theorems'])
    names = {e['declaration'] for e in manifest['theorems']}
    for name in (CLAIMS[0], *HEADLINES, *COVERAGE.UNSOURCED):
        if name not in names:
            raise ValueError('missing manifest entry: '+name)


def load_shadow_allowlist(root=ROOT):
    """Reviewed `(declaration, shadows)` pairs; the Lean audit requires exact equality."""
    data = json.loads((root/'manifests/shadowing-allowlist.json').read_text())
    if set(data) != {'schema_version','scope','entries'} or data['schema_version'] != 1:
        raise ValueError('invalid shadowing allowlist schema')
    pairs = []
    for entry in data['entries']:
        if (set(entry) != {'declaration','shadows','reason'} or not ANY_NAME.fullmatch(entry['declaration'])
                or not entry['declaration'].startswith('Etna.') or not ANY_NAME.fullmatch(entry['shadows'])
                or not isinstance(entry['reason'],str) or not entry['reason'].strip()):
            raise ValueError('invalid shadowing allowlist entry: '+json.dumps(entry)[:200])
        pairs.append((entry['declaration'], entry['shadows']))
    if len(set(pairs)) != len(pairs):
        raise ValueError('duplicate shadowing allowlist entry')
    return pairs


def render_package_check(entries, shadows=None):
    """Namespace containment, manifest modules, axioms, shadowing, library contents and
    completeness."""
    shadows = load_shadow_allowlist() if shadows is None else shadows
    manifest = '\n'.join(e['declaration']+' '+e['module'] for e in entries)
    allowlist = '\n'.join(a+' '+b for a, b in shadows)
    model = '\n'.join(GRAPH.ALLOWED_MODEL_THEOREMS)
    return (f'run_elab _root_.EtnaAudit.checkPackage {lean_string(manifest)} {lean_string(allowlist)} '
            f'{lean_string(model)}')


def render_headline_check(claims=CLAIMS, headlines=None, premises=PREMISES):
    """The headline layer: exact claim types and axioms, then premise use (one
    `premise use: field <- theorem …` line per field)."""
    headlines = HEADLINES if headlines is None else headlines
    rows = '\n'.join(' '.join(pair) for pair in (claims, *headlines.items()))
    theorems = '\n'.join(headlines)
    return [f'run_elab _root_.EtnaAudit.checkHeadline {lean_string(rows)}',
            f'run_elab _root_.EtnaAudit.checkPremiseUse {lean_string(premises)} {lean_string(theorems)}']


def render_audit(entries, complete=True, shadows=None, libraries=None):
    """Audit module text. All checks live in scripts/EtnaAudit.lean (compiled without the
    Etna libraries, so model instances/attributes cannot alter them); this file imports
    every declared library and only calls the checks with string literals, inside each
    theorem's namespace for the exact-type check."""
    validate_entries(entries)
    libraries = GRAPH.declared_libraries() if libraries is None else libraries
    lines = ['import Lean', 'import EtnaAudit', *(f'import {lib}' for lib in libraries),
             'set_option pp.universes false', 'set_option pp.explicit true', 'set_option pp.fullNames true']
    if complete:
        lines.append(render_package_check(entries, shadows))
        lines += render_headline_check()
    for e in entries:
        ns = e['declaration'].rsplit('.', 1)[0]
        lines += [f'namespace {ns}', f'-- Named boundaries: {json.dumps(e["assumptions"])}',
                  'run_elab _root_.EtnaAudit.checkContract '+' '.join(
                      lean_string(e[k]) for k in ('declaration','role','type')),
                  f'#print axioms _root_.{e["declaration"]}', f'end {ns}']
    return '\n'.join(lines) + '\n'


def check_axioms(entries, output):
    """Check each entry's transitive axiom report and collect the `derivation chain:` line
    that exactly the `property` entries print; any other output fails. Returns
    `{declaration: [declaration, ..., induction principle]}` for the property entries."""
    remaining = output
    chains = {}
    for e in entries:
        name = e['declaration']
        pattern = re.escape("'"+name+"'")+r' (?:depends on axioms: \[([^\]]*)\]|does not depend on any axioms)'
        matches = list(re.finditer(pattern,output))
        if not matches:
            raise ValueError('missing transitive axiom report: '+name)
        if len(matches) != 1:
            raise ValueError('ambiguous transitive axiom report: '+name)
        axioms = set(filter(None,re.split(r'[,\s]+',matches[0].group(1) or '')))
        if axioms - ALLOWED_AXIOMS:
            raise ValueError('forbidden axioms: '+str(sorted(axioms-ALLOWED_AXIOMS)))
        remaining = re.sub(pattern,'',remaining)
        chain = r'^derivation chain: '+re.escape(name)+r'((?: -> \S+)+)$'
        matches = list(re.finditer(chain,remaining,re.MULTILINE))
        if len(matches) != (e['role'] == 'property'):
            raise ValueError(f'expected {int(e["role"] == "property")} derivation chain report(s), '
                             f'found {len(matches)}: {name}')
        if matches:
            chains[name] = [name]+matches[0].group(1).split(' -> ')[1:]
            remaining = re.sub(chain,'',remaining,flags=re.MULTILINE)
    if remaining.strip():
        raise ValueError('unexpected audit output: '+remaining[:500])
    return chains


def premise_uses(output):
    """`({field: [theorem, ...]}, output without those lines)` from the headline check's
    `premise use:` report."""
    uses = {m[1]: m[2].split() for m in PREMISE_USE.finditer(output)}
    if len(uses) != len(PREMISE_USE.findall(output)):
        raise ValueError('duplicate premise use report')
    return uses, PREMISE_USE.sub('', output)


def summarize_chains(chains):
    """One line on how the property entries are derived (the chains are for human review)."""
    direct = sum(len(c) == 2 for c in chains.values())
    longest = max((len(c)-1 for c in chains.values()), default=0)
    return (f'{len(chains)} property derivation chains ({direct} use induction directly, {len(chains)-direct} '
            f'through derived Etna theorems, longest {longest} steps)')


def kernel_dir(root=ROOT):
    return root/'.scratch/kernel'


def lean_env(root=ROOT, extra=()):
    """`lake env` prefix whose LEAN_PATH also contains the given olean directories."""
    search = run(['lake', 'env', 'printenv', 'LEAN_PATH'], cwd=root).strip()
    return ['lake', 'env', 'env', 'LEAN_PATH='+':'.join([*map(str, extra), search])]


def build_audit_library(root=ROOT):
    """Compile the audit checks with only `import Lean`; returns their olean directory."""
    lib = kernel_dir(root)/'lib'
    lib.mkdir(parents=True, exist_ok=True)
    output = run(['lake', 'env', 'lean', '--root='+str(root/'scripts'), '-o', str(lib/'EtnaAudit.olean'),
                  str(root/'scripts/EtnaAudit.lean')], cwd=root)
    if output.strip():
        raise ValueError('audit library diagnostics: '+output[:500])
    return lib


def check_kernel_file(path, root=ROOT):
    """Compile one audit file and replay its declarations with leanchecker."""
    path = Path(path).resolve()
    lib = build_audit_library(root)
    out = kernel_dir(root)/'files'
    out.mkdir(parents=True, exist_ok=True)
    env = lean_env(root, [lib, out])
    output = run(env+['lean', '-o', str(out/(path.stem+'.olean')), str(path)], cwd=root)
    run(env+['leanchecker', path.stem], cwd=root)
    return output


def kernel_replay(root=ROOT):
    """Replay every declared Etna library and every module it imports (Init/Std included) in
    a fresh kernel. `leanchecker --fresh` takes a single module, so this compiles a module
    that only imports the library roots and replays that."""
    out = kernel_dir(root)/'replay'
    out.mkdir(parents=True, exist_ok=True)
    source = out/'EtnaReplay.lean'
    source.write_text(''.join(f'import {lib}\n' for lib in GRAPH.declared_libraries(root)))
    output = run(['lake', 'env', 'lean', '-o', str(out/'EtnaReplay.olean'), str(source)], cwd=root)
    if output.strip():
        raise ValueError('replay module diagnostics: '+output[:500])
    return subprocess.Popen(lean_env(root, [out])+['leanchecker', '--fresh', 'EtnaReplay'], cwd=root, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)


def check_test_modules(root=ROOT):
    """tests/*.lean: zero diagnostics, kernel replay and only the standard axioms."""
    lib = build_audit_library(root)
    shutil.rmtree(lib/'tests', ignore_errors=True)
    (lib/'tests').mkdir()
    modules = []
    for path in sorted((root/'tests').glob('*.lean')):
        if not TEST_STEM.fullmatch(path.stem):
            raise ValueError('invalid Lean regression module name: '+path.name)
        output = run(['lake', 'env', 'lean', '--root='+str(root), '-o', str(lib/'tests'/(path.stem+'.olean')),
                      str(path)], cwd=root)
        if output.strip():
            raise ValueError(f'Lean diagnostics in tests/{path.name} (warnings, including sorry, fail): '+output[:800])
        modules.append('tests.'+path.stem)
    if not modules:
        return modules
    env = lean_env(root, [lib])
    run(env+['leanchecker', 'tests'], cwd=root)
    probe = kernel_dir(root)/'TestsAudit.lean'
    probe.write_text('import Lean\nimport EtnaAudit\n'+''.join(f'import {m}\n' for m in modules)
                     + 'run_elab _root_.EtnaAudit.checkTestModules "tests"\n')
    output = run(env+['lean', str(probe)], cwd=root)
    if output.strip():
        raise ValueError('unexpected regression audit output: '+output[:500])
    return modules


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output',type=Path,default=ROOT/'.scratch/generated/Audit.lean')
    args = parser.parse_args()
    fresh = None
    try:
        errors = LINT.lint(ROOT)
        if errors:
            raise ValueError('source lint failed:\n  '+'\n  '.join(errors))
        manifest = json.loads((ROOT/'manifests/design.json').read_text())
        validate_contract(manifest)
        load_shadow_allowlist()
        run([sys.executable,str(ROOT/'scripts/generate_artifacts.py')])
        version = run(['lake','env','lean','--version'])
        if 'version 4.35.0-rc4,' not in version:
            raise ValueError('exact pinned Lean compiler required')
        build = run(['lake','build'])
        if re.search('warning', build, re.IGNORECASE):
            raise ValueError(build)
        stale = VECTORS.check(ROOT)
        if stale:
            raise ValueError('conformance vectors are not a fresh generator run:\n  '+'\n  '.join(stale))
        fresh = kernel_replay()
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(render_audit(manifest['theorems']))
        uses, output = premise_uses(check_kernel_file(args.output))
        if not uses:
            raise ValueError('missing premise use report')
        chains = check_axioms(manifest['theorems'],output)
        tests = check_test_modules()
        replay, _ = fresh.communicate()
        if fresh.returncode:
            raise ValueError('fresh kernel replay of the Etna libraries failed: '+replay[-2000:])
        generated = ROOT/'.scratch/generated'
        derivations = dict(scope='why each property entry counts as derived: the first induction principle or '
                                 'derived Etna theorem found in its proof term once unused bindings are removed; '
                                 'a syntactic record for human review, not evidence that the induction is needed',
                           chains={name: ' -> '.join(chain) for name, chain in sorted(chains.items())})
        (generated/'derivation-chains.json').write_text(json.dumps(derivations,indent=2)+'\n')
        result = dict(theorem_contracts=len(manifest['theorems']),compiler=version.strip(),
                      full_types='passed',roles='mechanically checked',
                      derivation_chains='.scratch/generated/derivation-chains.json',
                      kernel_replay=' '.join(GRAPH.declared_libraries())+' --fresh (whole import closure), '
                                    'generated Audit and '+', '.join(tests),
                      headline=dict(claims=' : '.join(CLAIMS), theorems=HEADLINES, premise_use=uses),
                      vectors='testdata/etna_conformance equals a fresh lake exe etna-vectors run',
                      axioms=sorted(ALLOWED_AXIOMS),scope='conditional decoded specification only')
        (generated/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
        print(f'Audited {len(manifest["theorems"])} full theorem contracts; source lint, fresh vectors, fresh kernel '
              f'replay, exact types, mechanical roles, shadowing, library contents, headline claims and transitive '
              f'axioms pass; {len(tests)} Lean regression modules replayed.')
        print(f'Every one of the {len(uses)} premise fields is read by a headline proof: '
              + '; '.join(f'{field} <- {", ".join(t.rsplit(".", 1)[1] for t in by)}' for field, by in uses.items()))
        print(f'Recorded {summarize_chains(chains)} in .scratch/generated/derivation-chains.json.')
        return 0
    except (ValueError,KeyError,OSError,TypeError,json.JSONDecodeError) as exc:
        print('proof audit failed: '+str(exc),file=sys.stderr)
        return 1
    finally:
        if fresh is not None and fresh.returncode is None:
            os.killpg(fresh.pid, signal.SIGKILL)
            fresh.communicate()


if __name__ == '__main__':
    sys.exit(main())
