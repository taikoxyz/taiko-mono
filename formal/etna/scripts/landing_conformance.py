#!/usr/bin/env python3
"""Compare Lean with actual Inbox/proxy traces; optionally stage the tester-owned harness.
Protocol test execution must be performed by the repository-required solidity-tester.
"""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PIN = '27777e9d7147e7b1d3543711f4d7370a0377fa53'
FIELDS = ['schemaVersion','id','status','error','head','tail','checkpointHeight',
          'checkpointHash','signalPresent','signalHeight','signalHash','signalRoot',
          'paidTo','paidWei','batchEvent','consumedEvent','tentativeHead',
          'tentativeCheckpointHeight','tentativeSignalPresent','tentativeBatchEvent']


def run(args, cwd=ROOT, env=None):
    p = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)
    if p.returncode:
        raise RuntimeError(f'{args!r}\n{p.stdout}\n{p.stderr}')
    return p.stdout


def load(path):
    return [json.loads(line) for line in Path(path).read_text().splitlines() if line.strip()]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_inventory(protocol):
    files = sorted((protocol/'contracts').rglob('*.sol')) + [protocol/'foundry.toml']
    return {str(p.relative_to(protocol)):digest(p) for p in files}


OWNED_STAGE_PATHS = {
    'test/layer1/etna/EtnaInboxLeanConformance.t.sol',
    'test/layer1/etna/landing-corpus.json',
}
# Installed packages and generated Foundry artifacts are separate, explicit trust/cache
# boundaries. They are never deleted or confused with Git-authenticated protocol inputs.
IGNORED_ROOTS = {'out', 'cache', 'node_modules', '.git'}


def pinned_inputs(protocol):
    """Authenticate source/config/helper/fixture bytes and index against the pinned tree.

    Client-package overlays are outside this immutable protocol dependency. Installed
    node_modules remain governed by pinned manifests/toolchain inventory, not Git blobs.
    """
    overrides = [key for key in os.environ
                 if key.startswith(('FOUNDRY_', 'DAPP_', 'SOLC_')) and key not in
                 {'FOUNDRY_PROFILE', 'FOUNDRY_DISABLE_NIGHTLY_WARNING'}]
    if overrides:
        raise ValueError('unexpected compilation environment override: '+', '.join(sorted(overrides)))
    protocol = protocol.resolve()
    repo = Path(run(['git','rev-parse','--show-toplevel'], protocol).strip())
    relative = protocol.relative_to(repo).as_posix()
    if run(['git','rev-parse','HEAD'], protocol).strip() != PIN:
        raise ValueError(f'Protocol dependency HEAD differs from pinned {PIN}')
    scopes = [relative, 'package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml',
              'testdata/etna_vectors', 'foundry.toml', 'remappings.txt']
    owned = {relative+'/'+p for p in OWNED_STAGE_PATHS}
    indexed = run(['git','diff','--cached','--name-only','-z',PIN,'--',*scopes], repo)
    if any(p and p not in owned for p in indexed.split('\0')):
        raise ValueError('index differs from pinned compilation inputs')
    tree = run(['git','ls-tree','-r','-z',PIN,'--',*scopes], repo)
    expected = {}
    for entry in tree.split('\0'):
        if not entry:
            continue
        metadata, name = entry.split('\t',1)
        mode, kind, oid = metadata.split()
        if kind != 'blob':
            raise ValueError('unsupported pinned compilation input kind: '+name)
        expected[name] = (mode, oid)
    for name, (mode, oid) in expected.items():
        if name in owned:
            continue
        path = repo/name
        if mode == '120000':
            if not path.is_symlink():
                raise ValueError('pinned symlink replaced: '+name)
            link = os.readlink(path)
            # A pinned alias may target only another directly tracked regular input.
            # Authenticate the link text itself; the target bytes/mode are checked below
            # in their own tree entry. Do not follow arbitrary or chained external links.
            target = Path(os.path.normpath(path.parent/link))
            if not target.is_relative_to(repo) or expected.get(
                    target.relative_to(repo).as_posix(), ('', ''))[0] not in {'100644','100755'}:
                raise ValueError('pinned symlink has unsupported target: '+name)
            actual = subprocess.check_output(['git','hash-object','--stdin'],input=link.encode(),
                                             cwd=repo).decode().strip()
        else:
            if mode not in {'100644','100755'} or not path.is_file() or path.is_symlink():
                raise ValueError('pinned input missing, replaced or unsupported: '+name)
            if bool(path.stat().st_mode & 0o111) != (mode == '100755'):
                raise ValueError('pinned input mode changed: '+name)
            actual = run(['git','hash-object','--no-filters','--',str(path)], repo).strip()
        if actual != oid:
            raise ValueError('worktree differs from pinned compilation input: '+name)
    # Include ignored sources/config: git status alone misses these. Walk only the
    # protocol tree, deliberately pruning known dependency/cache roots, not deleting them.
    for directory, dirs, files in os.walk(protocol):
        base = Path(directory)
        if base == protocol:
            dirs[:] = [d for d in dirs if d not in IGNORED_ROOTS]
        for name in files:
            path = base/name
            local = path.relative_to(protocol).as_posix()
            tracked = path.relative_to(repo).as_posix() in expected
            compilation_input = (local.split('/')[0] in {'contracts','test','script'} or
                                 path.suffix in {'.sol','.yul'} or
                                 name in {'foundry.toml','remappings.txt','.env'})
            if compilation_input and not tracked and local not in OWNED_STAGE_PATHS:
                raise ValueError('unexpected compilation input: '+local)
        for name in dirs:
            path = base/name
            if path.is_symlink() and path.relative_to(repo).as_posix() not in expected:
                raise ValueError('unexpected compilation input symlink: '+str(path))
    for parent in [repo, protocol.parent]:
        for name in ['foundry.toml','remappings.txt','.env']:
            path=parent/name
            if path.exists() and path.relative_to(repo).as_posix() not in expected:
                raise ValueError('unexpected compilation configuration: '+str(path))
    return expected


@contextlib.contextmanager
def staged(protocol, corpus):
    """Restore exactly the previous owned adapter files, even on failure/interruption."""
    targets = {
        protocol/'test/layer1/etna/EtnaInboxLeanConformance.t.sol':
            (ROOT/'adapters/solidity/EtnaInboxLeanConformance.t.sol').read_bytes(),
        protocol/'test/layer1/etna/landing-corpus.json': json.dumps(corpus).encode(),
    }
    pinned_inputs(protocol)  # Authenticate before writing any owned staging file.
    if any(p.is_symlink() for p in targets):
        raise ValueError('unexpected owned staging symlink')
    saved = {p:p.read_bytes() if p.exists() else None for p in targets}
    before = source_inventory(protocol)
    head = run(['git','rev-parse','HEAD'], protocol).strip()
    if head != PIN:
        raise ValueError(f'Protocol dependency HEAD differs from {PIN}: {head}')
    try:
        for p, data in targets.items():
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
        yield protocol/'test/layer1/etna/landing-corpus.json'
    finally:
        for p, data in saved.items():
            if data is None:
                p.unlink(missing_ok=True)
            else:
                p.write_bytes(data)
        if source_inventory(protocol) != before:
            raise RuntimeError('production Solidity/config changed during adapter run')
        if run(['git','rev-parse','HEAD'], protocol).strip() != head:
            raise RuntimeError('protocol dependency HEAD changed')
        pinned_inputs(protocol)


def solidity(protocol, corpus, output):
    with staged(protocol, corpus) as path:
        env = os.environ | {'FOUNDRY_PROFILE':'layer1','ETNA_LANDING_CORPUS':str(path)}
        # Scoped lint can leave an ABI-only artifact that Forge otherwise treats as cached.
        # Bypass the compiler cache; never delete shared user artifacts.
        cmd = ['forge','test','--no-cache','--match-path','test/layer1/etna/EtnaInboxLeanConformance.t.sol',
               '--match-test','test_land_LeanCorpus','-vvv']
        p = subprocess.run(cmd,cwd=protocol,env=env,text=True,capture_output=True)
        output.with_suffix('.log').write_text(p.stdout+p.stderr)
        if p.returncode:
            raise RuntimeError(f'actual harness failed; see {output.with_suffix(".log")}')
        observations = []
        for line in p.stdout.splitlines():
            if line.strip().startswith('LAND_OBSERVATION '):
                observations.append(json.loads(line.strip().removeprefix('LAND_OBSERVATION ')))
        output.write_text(''.join(json.dumps(v)+'\n' for v in observations))
        return observations


def normalize(v):
    return v.lower() if isinstance(v,str) and v.startswith('0x') else v


def keccak(hex_bytes):
    return run(['cast','keccak',hex_bytes]).strip().lower()


def exact_ids(rows, label, expected=None):
    ids = [r.get('id') for r in rows]
    if not ids or any(not isinstance(i,str) or not i for i in ids) or len(set(ids)) != len(ids):
        raise ValueError(f'{label} must contain nonempty unique case IDs')
    if expected is not None and (len(ids) != len(expected) or set(ids) != set(expected)):
        raise ValueError(f'{label} must contain each corpus ID exactly once')
    return ids


def compare(corpus, observations):
    expected_ids = exact_ids(corpus, 'corpus')
    exact_ids(observations, 'Solidity output', expected_ids)
    actual = {r['id']:r for r in observations}
    augmented = []
    for row in corpus:
        obs = actual[row['id']]
        context = obs['context']
        # Identities/configuration are actual fixture inputs, not expected outcomes.
        ordered = []
        for blob in row['blobs']:
            if int(blob,16) == 0:
                break
            ordered.append(blob[2:])
        # Compute all model inputs independently of whether Solidity emitted a preimage.
        r = row | {'parentHash':context['parentHash'], 'context':context,
                   'blobCommitment':keccak('0x'+''.join(ordered))}
        augmented.append(r)
    with tempfile.TemporaryDirectory(prefix='etna-landing-') as temporary:
        p = Path(temporary)/'input.jsonl'
        p.write_text(''.join(json.dumps(v)+'\n' for v in augmented))
        lean = [json.loads(s) for s in run(['lake','env','lean','--run','Check/Landing.lean',str(p)]).splitlines()]
    exact_ids(lean, 'Lean output', expected_ids)
    failures = []
    encoded = 0
    for expected in lean:
        obs = actual[expected['id']]
        for field in FIELDS:
            if field == 'error' and expected[field] == 'environment-error' and obs.get(field) in ('anchor-unavailable','blobs-required'):
                continue
            if field not in obs or normalize(expected[field]) != normalize(obs[field]):
                failures.append({'id':expected['id'],'field':field,'lean':expected[field],
                                 'solidity':obs.get(field)})
        expected_encoding = 'expectedPreimage' in expected
        actual_group = [key in obs for key in ('actualPreimage','actualDigest','statementWords')]
        reaches_statement = expected['error'] in {'none','signal-unauthorized','signal-invalid','verifier','payment'}
        if (expected_encoding != reaches_statement or any(actual_group) != reaches_statement or
                (any(actual_group) and not all(actual_group))):
            failures.append({'id':expected['id'],'field':'preimage-presence'})
            continue
        if expected_encoding:
            if (not isinstance(expected['expectedPreimage'],str) or len(expected['expectedPreimage']) != 1154 or
                    not isinstance(obs['actualPreimage'],str) or len(obs['actualPreimage']) != 1154 or
                    not isinstance(obs['actualDigest'],str) or len(obs['actualDigest']) != 66 or
                    not isinstance(obs['statementWords'],list) or len(obs['statementWords']) != 18):
                failures.append({'id':expected['id'],'field':'preimage-shape'})
                continue
            encoded += 1
            preimage = expected['expectedPreimage']
            if preimage.lower() != obs['actualPreimage'].lower():
                failures.append({'id':expected['id'],'field':'actualPreimage'})
            if keccak(preimage) != obs['actualDigest'].lower():
                failures.append({'id':expected['id'],'field':'actualDigest'})
            if ['0x'+preimage[2+i*64:2+(i+1)*64] for i in range(18)] != [s.lower() for s in obs['statementWords']]:
                failures.append({'id':expected['id'],'field':'statementWords'})
    return {'schema_version':1,'cases':len(corpus),'actual_preimages':encoded,
            'failures':failures,'specification':'Lean executable staged model',
            'bridge':'actual production Inbox/proxy conformance; bytecode refinement pending',
            'crypto':'cast Keccak oracle; local hash separation required for binding proofs',
            'observations':'committed business state plus separately recorded tentative effects'}


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--corpus',type=Path,default=ROOT/'corpus/landing.jsonl')
    p.add_argument('--observations',type=Path,required=True)
    p.add_argument('--protocol',type=Path,help='packages/protocol path; requires --run-solidity')
    p.add_argument('--run-solidity',action='store_true',help='only repository-required solidity-tester runs this')
    p.add_argument('--report',type=Path,default=ROOT/'reports/landing-conformance.json')
    a=p.parse_args()
    corpus=load(a.corpus)
    observations=solidity(a.protocol,corpus,a.observations) if a.run_solidity else load(a.observations)
    result=compare(corpus,observations)
    result |= {'corpus_sha256':digest(a.corpus),'observations_sha256':digest(a.observations)}
    a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return bool(result['failures'])

if __name__=='__main__':
    raise SystemExit(main())
