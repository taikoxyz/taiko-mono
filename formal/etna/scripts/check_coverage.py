#!/usr/bin/env python3
"""Fail closed on missing obligations, changed source/type bytes and bridge downgrades.

This ledger does not upgrade conformance or a refined scalar function to whole-program
correctness. Default execution also invokes the Lean full-type/transitive-axiom audit.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from audit_proofs import audit, validate_refinement
from landing_conformance import PIN, pinned_inputs

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
UPSTREAM_CLIENT = '2af0f30485b9990eae87074037bede11c59e8883'
# Frozen independently of the manifests/ledger. Deleting both copies is still rejected.
POLICY = ROOT/'schemas/coverage-policy.json'
POLICY_SHA256 = '866810ac3a55e8d3eb9dfae9cb77ae81aab56054a59fd6a1c74fc9d5f2721a50'
if hashlib.sha256(POLICY.read_bytes()).hexdigest() != POLICY_SHA256:
    raise ValueError('coverage policy changed without explicit checker review')
_POLICY = json.loads(POLICY.read_text())
REQUIRED = _POLICY['required']
REQUIRED_FILES = _POLICY['required_files']
PENDING = {'GUEST-SOUNDNESS', 'TIME-RULE-REFINEMENT', 'SOLIDITY-BYTECODE-REFINEMENT'}
LEVELS = {'spec-proved', 'rust-refinement-proved'}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def inside(root, relative):
    path = (root/relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError('ledger path escapes root')
    return path


def load_entries():
    entries = []
    for path in sorted((ROOT/'manifests').glob('*.json')):
        entries += json.loads(path.read_text())['theorems']
    return entries


def check_ledger(ledger, entries, source_root=None):
    if set(ledger) != {'schema_version','identities','obligations','pending','files','contract_artifacts'} or type(ledger['schema_version']) is not int or ledger['schema_version'] != 1:
        raise ValueError('invalid coverage schema')
    identities = ledger['identities']
    if identities != {'upstream_client':UPSTREAM_CLIENT,'paired_protocol':PIN,
                      'verification_overlay':'current Git HEAD plus checked working-tree digests'}:
        raise ValueError('three source identities must remain explicit')
    ids = [e['id'] for e in entries]
    if len(ids) != len(set(ids)) or set(ids) != set(REQUIRED):
        raise ValueError('mandatory theorem IDs missing, duplicated or unexpected')
    obligations = ledger['obligations']
    if len(obligations) != len(REQUIRED) or {e['id'] for e in obligations} != set(REQUIRED):
        raise ValueError('mandatory ledger IDs missing or duplicated')
    index = {e['id']:e for e in entries}
    for row in obligations:
        if set(row) != {'id','declaration','module','type_sha256','bridge_level','premises','source_symbols','tests'}:
            raise ValueError('invalid obligation schema')
        entry = index[row['id']]
        required = REQUIRED[row['id']]
        if [entry['declaration'],entry['bridge_level']] != required[:2] or [row['declaration'],row['bridge_level']] != required[:2]:
            raise ValueError('mandatory declaration/bridge changed or downgraded: '+row['id'])
        if [[v['path'],v['symbol'],v['relation']] for v in row['source_symbols']] != required[2]:
            raise ValueError('mandatory source symbol bridge removed or changed')
        if canonical(row['premises']) != required[3]:
            raise ValueError('mandatory named premises removed or changed')
        if row['module'] != entry['module'] or row['type_sha256'] != canonical(entry['type']):
            raise ValueError('theorem type/module digest mismatch: '+row['id'])
        if row['premises'] != entry['assumptions'] or row['tests'] != entry['tests'] or not row['tests']:
            raise ValueError('premise/test coverage differs: '+row['id'])
        module = inside(ROOT, entry['module'].replace('.','/')+'.lean')
        if not module.is_file() or not re.search(r'\btheorem\s+'+re.escape(entry['declaration'].split('.')[-1])+r'\b',module.read_text()):
            raise ValueError('declared theorem source missing: '+row['id'])
        if entry['bridge_level'] == 'rust-refinement-proved':
            validate_refinement(entry)
        for test in row['tests']:
            if not inside(ROOT,test).is_file():
                raise ValueError('declared test missing: '+test)
        for source in row['source_symbols']:
            if set(source) != {'path','symbol','sha256','relation'} or source['relation'] not in {'source-mapped-spec','exact-extracted-function'}:
                raise ValueError('invalid source-symbol bridge')
            if source['relation'] == 'exact-extracted-function' and entry['bridge_level'] != 'rust-refinement-proved':
                raise ValueError('scalar refinement cannot upgrade wrapper/model theorem')
            base = source_root if source['path'].startswith('packages/protocol/') else REPO
            if base is None:
                raise ValueError('--protocol is required for actual contract source verification')
            path = inside(base,source['path'])
            if sha(path) != source['sha256'] or source['symbol'] not in path.read_text():
                raise ValueError('source symbol/digest mismatch: '+source['path'])
    pending = ledger['pending']
    if len(pending) != len(PENDING) or {p['id'] for p in pending} != PENDING:
        raise ValueError('mandatory pending external boundary missing')
    for item in pending:
        if set(item) != {'id','status','reason','source','symbol'} or item['status'] != 'pending' or not item['reason']:
            raise ValueError('unproved boundary was hidden or upgraded')
        base = source_root if item['source'].startswith('packages/protocol/') else REPO
        if base is None or item['symbol'] not in inside(base,item['source']).read_text():
            raise ValueError('pending source symbol missing')
    required_files = set(REQUIRED_FILES)
    required_files |= {e['module'].replace('.','/')+'.lean' for e in entries}
    required_files |= {'Etna/Refinement/Rust/EtnaConsensusCore.lean','Etna/Refinement/Rust/provenance.json',
                      'tools.lock.json','corpus/landing.jsonl','adapters/solidity/EtnaInboxLeanConformance.t.sol',
                      'adapters/solidity/EtnaInboxCutsConformance.t.sol'}
    if not required_files <= ledger['files'].keys():
        raise ValueError('mandatory source/generated file digest removed')
    for path, digest in ledger['files'].items():
        if sha(inside(ROOT,path)) != digest:
            raise ValueError('stale generated/model/adapter digest: '+path)
    return {'theorems':len(entries),'exact_rust_functions':sum(e['bridge_level']=='rust-refinement-proved' for e in entries),
            'pending':sorted(PENDING)}


def check_contract_artifacts(protocol, expected):
    """Read actual sources, compiled ABI/layout/runtime and generator provenance; no build."""
    pinned_inputs(protocol)
    fixture_dir = REPO/'packages/taiko-client-rs/crates/lander/tests/fixtures/contracts'
    manifest = json.loads((fixture_dir/'manifest.json').read_text())
    if manifest['protocolRevision'] != PIN or sha(fixture_dir/'manifest.json') != expected['manifest_sha256']:
        raise ValueError('contract artifact provenance revision/digest mismatch')
    for name, provenance in manifest['artifacts'].items():
        fixture = fixture_dir/(name+'.json')
        if sha(fixture) != provenance['sha256']:
            raise ValueError('generated artifact changed: '+name)
        for source, digest in provenance['sources'].items():
            # Installed pnpm packages may be symlinks outside this checkout. Their
            # exact compiler-input bytes are authenticated by generator provenance.
            relative = Path(source)
            if relative.is_absolute() or '..' in relative.parts:
                raise ValueError('unsafe compiler source path')
            source_path = protocol/relative if source.startswith('node_modules/') else inside(protocol,source)
            if sha(source_path) != digest['sha256']:
                raise ValueError('actual compiler source differs: '+source)
        actual = json.loads(inside(protocol.parents[1],provenance['sourceArtifact']).read_text())
        generated = json.loads(fixture.read_text())
        if actual['abi'] != generated['abi']:
            raise ValueError('actual compiled ABI differs: '+name)
        for field in ['bytecode','deployedBytecode']:
            if actual[field]['object'] != generated[field]['object']:
                raise ValueError('actual executable bytecode differs: '+name)
        raw_metadata = json.loads(actual['rawMetadata'])
        if set(raw_metadata['sources']) != set(provenance['sources']) or any(
                raw_metadata['sources'][source]['keccak256'] != digest['keccak256']
                for source,digest in provenance['sources'].items()):
            raise ValueError('actual compiler source metadata differs: '+name)
        for key in ['compiler','settings']:
            if raw_metadata[key] != provenance[key]:
                raise ValueError('actual compiler provenance differs: '+name)
    actual = json.loads((protocol/'out/layer1/EtnaInbox.sol/EtnaInbox.json').read_text())
    if canonical(actual['storageLayout']) != expected['inbox_layout_sha256']:
        raise ValueError('actual Inbox storage layout differs')
    if sha(protocol/'contracts/layer1/etna/iface/IEtnaInbox.sol') != manifest['interface']['sha256']:
        raise ValueError('generated interface source stale')
    for path, digest in manifest['vectors']['files'].items():
        if sha(REPO/manifest['vectors']['source']/path) != digest:
            raise ValueError('generated vector stale')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--protocol',type=Path,required=True)
    parser.add_argument('--ledger',type=Path,default=ROOT/'coverage.json')
    parser.add_argument('--static-only',action='store_true',help='explicitly omit kernel audit; not a complete release gate')
    parser.add_argument('--report',type=Path,default=ROOT/'reports/coverage-verification.json')
    args=parser.parse_args()
    try:
        ledger=json.loads(args.ledger.read_text())
        result=check_ledger(ledger,load_entries(),args.protocol.resolve().parents[1])
        check_contract_artifacts(args.protocol.resolve(),ledger['contract_artifacts'])
        if not args.static_only:
            audit(sorted((ROOT/'manifests').glob('*.json')),ROOT/'Audit.lean')
        result |= {'schema_version':1,'kernel_audit':not args.static_only,
            'upstream_client':UPSTREAM_CLIENT,'paired_protocol':PIN,
            'verification_overlay':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip(),
            'ledger_sha256':sha(args.ledger),'contract_sources_abi_layout_bytecode':'verified against actual paired artifacts',
            'solidity_bridge':'specification plus finite conformance; bytecode refinement remains pending'}
        args.report.write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result,indent=2))
    except (ValueError,KeyError,OSError,RuntimeError,json.JSONDecodeError) as error:
        print('coverage check failed: '+str(error),file=sys.stderr)
        return 1
    return 0

if __name__=='__main__':
    raise SystemExit(main())
