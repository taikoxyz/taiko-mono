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


@contextlib.contextmanager
def staged(protocol, corpus):
    """Restore exactly the previous owned adapter files, even on failure/interruption."""
    targets = {
        protocol/'test/layer1/etna/EtnaInboxLeanConformance.t.sol':
            (ROOT/'adapters/solidity/EtnaInboxLeanConformance.t.sol').read_bytes(),
        protocol/'test/layer1/etna/landing-corpus.json': json.dumps(corpus).encode(),
    }
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


def compare(corpus, observations):
    expected_ids = [r['id'] for r in corpus]
    actual_ids = [r['id'] for r in observations]
    if sorted(actual_ids) != sorted(expected_ids) or len(set(actual_ids)) != len(actual_ids):
        raise ValueError('actual output must contain each corpus ID exactly once')
    actual = {r['id']:r for r in observations}
    augmented = []
    for row in corpus:
        obs = actual[row['id']]
        context = obs['context']
        # Identities/configuration are actual fixture inputs, not expected outcomes.
        r = row | {'parentHash':context['parentHash']}
        if obs.get('actualPreimage') and len(obs['actualPreimage']) == 1154:
            ordered = []
            for blob in row['blobs']:
                if int(blob,16) == 0:
                    break
                ordered.append(blob[2:])
            r |= {'context':context,'blobCommitment':keccak('0x'+''.join(ordered))}
        augmented.append(r)
    with tempfile.TemporaryDirectory(prefix='etna-landing-') as temporary:
        p = Path(temporary)/'input.jsonl'
        p.write_text(''.join(json.dumps(v)+'\n' for v in augmented))
        lean = [json.loads(s) for s in run(['lake','env','lean','--run','Check/Landing.lean',str(p)]).splitlines()]
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
        if 'expectedPreimage' in expected:
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
