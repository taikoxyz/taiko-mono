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
PIN = 'cf4095818050bd670d7d6b8b9f742d55c01e49f0'
FIELDS = ['schemaVersion','id','status','error','head','tail','checkpointHeight',
          'checkpointHash','signalPresent','signalHeight','signalHash','signalRoot',
          'paidTo','paidWei','batchEvent','consumedEvent','tentativeHead',
          'tentativeCheckpointHeight','tentativeSignalPresent','tentativeBatchEvent',
          'rewardEvent','rewardCommitment','tentativeRewardCommitment']
REWARD_STAGE = {'none','payment','reward-already-recorded'}


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
    'test/layer1/etna/EtnaInboxCutsConformance.t.sol',
    'test/layer2/core/L2FeeVaultLeanConformance.t.sol',
    'test/layer2/core/claim-corpus.json',
}
# Installed packages and generated Foundry artifacts are separate, explicit trust/cache
# boundaries. They are never deleted or confused with Git-authenticated protocol inputs.
IGNORED_ROOTS = {'out', 'cache', 'node_modules', '.git'}


def pinned_inputs(protocol, expected_mutant=None):
    """Authenticate source/config/helper/fixture bytes and index against the pinned tree.

    Client-package overlays are outside this immutable protocol dependency. Installed
    node_modules remain governed by pinned manifests/toolchain inventory, not Git blobs.
    """
    overrides = [key for key in os.environ
                 if key.startswith(('FOUNDRY_', 'DAPP_', 'SOLC_')) and key not in
                 {'FOUNDRY_PROFILE', 'FOUNDRY_DISABLE_NIGHTLY_WARNING'}]
    if overrides:
        raise ValueError('unexpected compilation environment override: '+', '.join(sorted(overrides)))
    mutation = None
    if expected_mutant is not None:
        import claim_mutant_specs
        import landing_mutant_specs
        specs = [m for m in (landing_mutant_specs, claim_mutant_specs) if expected_mutant in m.MUTANTS]
        if len(specs) != 1:
            raise ValueError('unknown expected mutant')
        mutation, expected_bytes = specs[0].MUTANTS[expected_mutant], specs[0].expected_bytes
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
        if mutation is not None and name == relative+'/'+mutation[0]:
            original = subprocess.check_output(['git','show',PIN+':'+name],cwd=repo)
            mutated = expected_bytes(expected_mutant, original)
            if path.read_bytes() != mutated:
                raise ValueError('worktree differs from exact expected mutant: '+name)
            oid = subprocess.check_output(['git','hash-object','--stdin'], input=mutated,
                                          cwd=repo).decode().strip()
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
def staged(protocol, corpus, expected_mutant=None):
    """Stage the landing harnesses and corpus; see `staged_files`."""
    files = {
        'test/layer1/etna/EtnaInboxCutsConformance.t.sol':
            (ROOT/'adapters/solidity/EtnaInboxCutsConformance.t.sol').read_bytes(),
        'test/layer1/etna/EtnaInboxLeanConformance.t.sol':
            (ROOT/'adapters/solidity/EtnaInboxLeanConformance.t.sol').read_bytes(),
        'test/layer1/etna/landing-corpus.json': json.dumps(corpus).encode(),
    }
    with staged_files(protocol, files, expected_mutant) as root:
        yield root/'test/layer1/etna/landing-corpus.json'


@contextlib.contextmanager
def staged_files(protocol, files, expected_mutant=None):
    """Restore exactly the previous owned adapter files, even on failure/interruption."""
    protocol = protocol.resolve()
    if not files or not set(files) <= OWNED_STAGE_PATHS:
        raise ValueError('only owned adapter paths may be staged')
    targets = {protocol/relative:data for relative, data in files.items()}
    pinned_inputs(protocol, expected_mutant)  # Authenticate before writing any owned staging file.
    for target in targets:
        # Reject special files before read_bytes: a FIFO would otherwise hang and a
        # directory is not an adapter. Parent links must not redirect staging writes.
        if target.is_symlink() or any(parent.is_symlink() for parent in target.parents
                                     if parent != protocol and parent.is_relative_to(protocol)):
            raise ValueError('unexpected owned staging symlink')
        if target.exists() and not target.is_file():
            raise ValueError('unexpected non-regular owned staging file')
    saved = {p:p.read_bytes() if p.exists() else None for p in targets}
    before = source_inventory(protocol)
    head = run(['git','rev-parse','HEAD'], protocol).strip()
    if head != PIN:
        raise ValueError(f'Protocol dependency HEAD differs from {PIN}: {head}')
    try:
        for p, data in targets.items():
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
        yield protocol
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
        pinned_inputs(protocol, expected_mutant)


def solidity(protocol, corpus, output):
    with staged(protocol, corpus) as path:
        env = os.environ | {'FOUNDRY_PROFILE':'layer1','ETNA_LANDING_CORPUS':str(path)}
        # Scoped lint can leave an ABI-only artifact that Forge otherwise treats as cached.
        # Bypass the compiler cache; never delete shared user artifacts.
        cmd = ['forge','test','--no-cache','--extra-output','storageLayout','--match-path','test/layer1/etna/*Conformance.t.sol',
               '--match-test','test_land_(LeanCorpus|ContiguousCuts)','-vvv']
        p = subprocess.run(cmd,cwd=protocol,env=env,text=True,capture_output=True)
        output.with_suffix('.log').write_text(p.stdout+p.stderr)
        if p.returncode:
            raise RuntimeError(f'actual harness failed; see {output.with_suffix(".log")}')
        observations = []
        cuts = []
        for line in p.stdout.splitlines():
            if line.strip().startswith('LAND_OBSERVATION '):
                observations.append(json.loads(line.strip().removeprefix('LAND_OBSERVATION ')))
            if line.strip().startswith('ETNA_CUT '):
                cuts.append(json.loads(line.strip().removeprefix('ETNA_CUT ')))
        output.with_suffix('.cuts.jsonl').write_text(''.join(json.dumps(v)+'\n' for v in cuts))
        output.write_text(''.join(json.dumps(v)+'\n' for v in observations))
        return observations


def normalize(v):
    return v.lower() if isinstance(v,str) and v.startswith('0x') else v


def keccak(hex_bytes):
    return run(['cast','keccak',hex_bytes]).strip().lower()


def word(value):
    return format(value, '064x')


def tag(text):
    return text.encode().hex().ljust(64, '0')


def receipt_preimages(row, context):
    """Independently build LibEtnaRewards' batch-id and commitment preimages (hex, no 0x)."""
    batch = ''.join([tag('ETNA_L2_REWARD_BATCH_V1'), word(context['chainid']), word(context['l2chainid']),
                     word(int(context['proxy'],16)), word(context['generation']), word(row['parentHeight']),
                     context['parentHash'][2:].lower().rjust(64,'0'), word(row['lastHeight']),
                     row['lastBlockHash'][2:].lower().rjust(64,'0')])
    batch_id = keccak('0x'+batch)
    commitment = ''.join([tag('ETNA_L2_REWARD_RECEIPT_V1'), batch_id[2:], word(int(row['l2RewardRecipient'],16)),
                          word(int(row['baseFeeAmount']))])
    return batch, batch_id, commitment, keccak('0x'+commitment)


def exact_ids(rows, label, expected=None):
    ids = [r.get('id') for r in rows]
    if not ids or any(not isinstance(i,str) or not i for i in ids) or len(set(ids)) != len(ids):
        raise ValueError(f'{label} must contain nonempty unique case IDs')
    if expected is not None and (len(ids) != len(expected) or set(ids) != set(expected)):
        raise ValueError(f'{label} must contain each corpus ID exactly once')
    return ids


def compare(corpus, observations, rust_rows=None):
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
        _, batch_id, _, commitment = receipt_preimages(row, context)
        r = row | {'parentHash':context['parentHash'], 'context':context,
                   'blobCommitment':keccak('0x'+''.join(ordered)),
                   'rewardBatchId':batch_id, 'rewardCommitmentValue':commitment}
        augmented.append(r)
    with tempfile.TemporaryDirectory(prefix='etna-landing-') as temporary:
        p = Path(temporary)/'input.jsonl'
        p.write_text(''.join(json.dumps(v)+'\n' for v in augmented))
        lean = [json.loads(s) for s in run(['lake','env','lean','--run','Check/Landing.lean',str(p)]).splitlines()]
    exact_ids(lean, 'Lean output', expected_ids)
    failures = []
    rust = None
    if rust_rows is not None:
        exact_ids(rust_rows, 'Rust output', expected_ids)
        rust = {r['id']:r for r in rust_rows}
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
        reaches_statement = expected['error'] in {'none','signal-unauthorized','signal-invalid','verifier',
                                                  'reward-already-recorded','payment'}
        row = next(r for r in corpus if r['id'] == expected['id'])
        batch, batch_id, commitment_pre, commitment = receipt_preimages(row, obs['context'])
        reaches_reward = expected['error'] in REWARD_STAGE
        lean_reward = ('expectedRewardBatchPreimage' in expected, 'expectedRewardCommitmentPreimage' in expected)
        if lean_reward != (reaches_reward, reaches_reward):
            failures.append({'id':expected['id'],'field':'reward-preimage-presence'})
        elif reaches_reward:
            if expected['expectedRewardBatchPreimage'].lower() != '0x'+batch:
                failures.append({'id':expected['id'],'field':'rewardBatchPreimage'})
            if keccak(expected['expectedRewardBatchPreimage']) != batch_id:
                failures.append({'id':expected['id'],'field':'rewardBatchId'})
            if expected['expectedRewardCommitmentPreimage'].lower() != '0x'+commitment_pre:
                failures.append({'id':expected['id'],'field':'rewardCommitmentPreimage'})
            if keccak(expected['expectedRewardCommitmentPreimage']) != commitment:
                failures.append({'id':expected['id'],'field':'rewardCommitmentValue'})
        actual_id = obs.get('actualRewardId','0x'+'0'*64).lower()
        if int(actual_id,16) != 0 and actual_id != batch_id:
            failures.append({'id':expected['id'],'field':'actualRewardId'})
        if (int(actual_id,16) != 0) != (expected['error'] in {'none','payment'}):
            failures.append({'id':expected['id'],'field':'reward-event-presence'})
        if (expected_encoding != reaches_statement or any(actual_group) != reaches_statement or
                (any(actual_group) and not all(actual_group))):
            failures.append({'id':expected['id'],'field':'preimage-presence'})
            continue
        if expected_encoding:
            if (not isinstance(expected['expectedPreimage'],str) or len(expected['expectedPreimage']) != 1282 or
                    not isinstance(obs['actualPreimage'],str) or len(obs['actualPreimage']) != 1282 or
                    not isinstance(obs['actualDigest'],str) or len(obs['actualDigest']) != 66 or
                    not isinstance(obs['statementWords'],list) or len(obs['statementWords']) != 20):
                failures.append({'id':expected['id'],'field':'preimage-shape'})
                continue
            encoded += 1
            preimage = expected['expectedPreimage']
            if rust is not None:
                r = rust[expected['id']]
                for field, value in [('rustPreimage',preimage),('rustDigest',obs['actualDigest'])]:
                    if normalize(r.get(field)) != normalize(value):
                        failures.append({'id':expected['id'],'field':field})
            if preimage.lower() != obs['actualPreimage'].lower():
                failures.append({'id':expected['id'],'field':'actualPreimage'})
            if keccak(preimage) != obs['actualDigest'].lower():
                failures.append({'id':expected['id'],'field':'actualDigest'})
            if ['0x'+preimage[2+i*64:2+(i+1)*64] for i in range(20)] != [s.lower() for s in obs['statementWords']]:
                failures.append({'id':expected['id'],'field':'statementWords'})
    return {'schema_version':1,'cases':len(corpus),'actual_preimages':encoded,
            'failures':failures,'specification':'Lean executable staged model',
            'bridge':'actual production Inbox/proxy conformance; bytecode refinement pending',
            'crypto':'cast Keccak oracle; local hash separation required for binding proofs',
            'observations':'committed business state plus separately recorded tentative effects'}



def rust_observations(corpus, observations, cuts_path):
    """Execute actual lander functions via Rust1.95, with no expected bytes in its inputs."""
    exact_ids(observations, 'Solidity output', exact_ids(corpus, 'corpus'))
    contexts = {r['id']:r['context'] for r in observations}
    with tempfile.TemporaryDirectory(prefix='etna-rust-statement-') as directory:
        path = Path(directory)
        inputs, output, cuts_output = path/'inputs.jsonl', path/'rust.jsonl', path/'cuts.jsonl'
        inputs.write_text(''.join(json.dumps(r | {'context':contexts[r['id']]})+'\n' for r in corpus))
        env = os.environ | {'ETNA_STATEMENT_INPUT':str(inputs),'ETNA_STATEMENT_OUTPUT':str(output),
            'ETNA_CUT_INPUT':str(cuts_path.resolve()),'ETNA_CUT_OUTPUT':str(cuts_output)}
        # Respect the caller's reusable cache; do not bake a developer-specific absolute path.
        run(['cargo','+1.95','test','-p','lander','--test','formal_statement','--','--nocapture'],
            ROOT.parents[1]/'packages/taiko-client-rs',env)
        return load(output), load(cuts_output)


CUT_PLANS = {'cut-6':[6], 'cut-1-6':[1,6], 'cut-2-4-6':[2,4,6], 'cut-every':[1,2,3,4,5,6]}
CUT_STEPS = [1,0,1,1,0,1]


def compare_cuts(rows, rust_rows):
    exact_ids(rows, 'Solidity cuts', list(CUT_PLANS))
    exact_ids(rust_rows, 'Rust cuts', list(CUT_PLANS))
    first = rows[0]
    for row in rows:
        if (row['schemaVersion'] != 1 or row['steps'] != CUT_STEPS or
                row['cuts'] != CUT_PLANS[row['id']] or row['initialHead'] != 0 or
                row['initialHeight'] != 0 or len(row['feesGwei']) != 4 or
                any(not isinstance(f,str) or not f.isdecimal() or not 0 < int(f) < 2**64 for f in row['feesGwei'])):
            raise ValueError('invalid frozen cut scenario')
        for field in ['feesGwei','proxy','registry','finalHash','finalRoot']:
            if normalize(row[field]) != normalize(first[field]):
                raise ValueError('cut plans do not share admission/context identity: '+field)
        if int(row['finalHash'],16) != 0x1006 or int(row['finalRoot'],16) != 0x2006:
            raise ValueError('wrong actual terminal checkpoint')
    with tempfile.TemporaryDirectory(prefix='etna-cuts-') as directory:
        path = Path(directory)/'inputs.jsonl'
        # Strip all observed outcomes: each language derives them independently.
        path.write_text(''.join(json.dumps({k:r[k] for k in
            ['id','initialHead','initialHeight','steps','cuts','feesGwei']})+'\n' for r in rows))
        lean = [json.loads(s) for s in run(['lake','env','lean','--run','Check/Cuts.lean',str(path)]).splitlines()]
    exact_ids(lean, 'Lean cuts', list(CUT_PLANS))
    expected = {r['id']:r for r in lean}
    rust = {r['id']:r for r in rust_rows}
    failures = []
    for row in rows:
        for field in ['finalHead','finalHeight','paidWei','intervals']:
            for language, result in [('solidity',row),('rust',rust[row['id']])]:
                if result.get(field) != expected[row['id']][field]:
                    failures.append({'id':row['id'],'field':field,'language':language})
    return {'plans':len(rows),'intervals':sum(len(r['cuts']) for r in rows),'failures':failures,
            'boundary':'finite actual contract samples; arbitrary-cut theorem is separate; accepting verifier is not guest soundness'}

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--corpus',type=Path,default=ROOT/'corpus/landing.jsonl')
    p.add_argument('--observations',type=Path,required=True)
    p.add_argument('--protocol',type=Path,help='packages/protocol path; requires --run-solidity')
    p.add_argument('--run-solidity',action='store_true',help='only repository-required solidity-tester runs this')
    p.add_argument('--cuts-observations',type=Path,default=ROOT/'reports/landing-cuts-observations.jsonl')
    p.add_argument('--report',type=Path,default=ROOT/'reports/landing-conformance.json')
    a=p.parse_args()
    corpus=load(a.corpus)
    observations=solidity(a.protocol,corpus,a.observations) if a.run_solidity else load(a.observations)
    cuts_path = a.observations.with_suffix('.cuts.jsonl') if a.run_solidity else a.cuts_observations
    rust, rust_cuts = rust_observations(corpus,observations,cuts_path)
    result=compare(corpus,observations,rust)
    result['rust_statement_rows']=len(rust)
    result['cuts']=compare_cuts(load(cuts_path),rust_cuts)
    result['failures'] += result['cuts']['failures']
    result |= {'corpus_sha256':digest(a.corpus),'observations_sha256':digest(a.observations)}
    a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return bool(result['failures'])

if __name__=='__main__':
    raise SystemExit(main())
