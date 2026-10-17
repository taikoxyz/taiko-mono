#!/usr/bin/env python3
"""Compare Lean `claim` with actual L2FeeVault traces; optionally stage the tester-owned harness.
Protocol test execution must be performed by the repository-required solidity-tester.
"""
import argparse
import functools
import json
import os
from pathlib import Path
import subprocess
import tempfile

from landing_conformance import ROOT, digest, exact_ids, load, normalize, run, staged_files, tag, word
import landing_conformance

FIELDS = ['schemaVersion','id','status','error','batchId','claimed','paidTo','paidWei',
          'vaultBalanceWei','rewardEvents','eventBatchId','eventRecipient','eventAmount',
          'rootQueries','recipientCalls','nestedResult','priorClaimed']
HARNESS = 'test/layer2/core/L2FeeVaultLeanConformance.t.sol'
STAGED_CORPUS = 'test/layer2/core/claim-corpus.json'
ROW_KEYS = {'schemaVersion','id','vault','receipt','ledger','accountProof','storageProof','root',
            'anchorTimestamp','recipient','caller'}
OPTIONAL_KEYS = {'prior','reentry'}
VAULT_KEYS = {'l1ChainId','chainId','inbox','balanceWei','entered'}
RECEIPT_KEYS = {'l1ChainId','l2ChainId','inbox','generation','parentHeight','parentHash','lastHeight',
                'lastBlockHash','l2RewardRecipient','baseFeeAmount'}
PROOF_MODES = {'valid','empty','corrupt'}
ROOT_MODES = {'published','storage-root','missing','expired','zero','other'}
RECIPIENT_MODES = {'eoa','rejecting','reentrant'}
ROOTS_BUFFER = 8191


@functools.lru_cache(maxsize=None)
def keccak(hex_bytes):
    return landing_conformance.keccak(hex_bytes)


def address_word(value):
    return word(int(value, 16))


def batch_preimage(r):
    """LibEtnaRewards.batchId's abi.encode, built independently of Lean and Solidity."""
    return ''.join([tag('ETNA_L2_REWARD_BATCH_V1'), word(int(r['l1ChainId'])), word(r['l2ChainId']),
                    address_word(r['inbox']), word(r['generation']), word(r['parentHeight']),
                    r['parentHash'][2:].lower().rjust(64,'0'), word(r['lastHeight']),
                    r['lastBlockHash'][2:].lower().rjust(64,'0')])


def commitment_preimage(batch_id, r):
    return ''.join([tag('ETNA_L2_REWARD_RECEIPT_V1'), batch_id[2:], address_word(r['l2RewardRecipient']),
                    word(int(r['baseFeeAmount']))])


def receipts(row):
    found = [row['receipt'], row['ledger']['receipt']]
    found += [row[k]['receipt'] for k in sorted(OPTIONAL_KEYS) if k in row]
    return found


def oracle(row):
    """Exact preimage bytes to cast digests for every receipt the row can hash."""
    pairs = {}
    for r in receipts(row):
        batch = '0x'+batch_preimage(r)
        batch_id = keccak(batch)
        commitment = '0x'+commitment_preimage(batch_id, r)
        pairs[batch] = batch_id
        pairs[commitment] = keccak(commitment)
    return [[k, v] for k, v in sorted(pairs.items())]


def _uint(value, bits, label):
    if type(value) is not int or not 0 <= value < 2**bits:
        raise ValueError(f'invalid uint{bits}: '+label)


def _decimal(value, label):
    if not isinstance(value, str) or not value.isdecimal() or int(value) >= 2**256:
        raise ValueError('invalid uint256 decimal: '+label)


def _hex(value, nibbles, label):
    if (not isinstance(value, str) or not value.startswith('0x') or len(value) != 2+nibbles
            or any(c not in '0123456789abcdefABCDEF' for c in value[2:])):
        raise ValueError('invalid hex: '+label)


def check_receipt(r, label):
    if not isinstance(r, dict) or set(r) != RECEIPT_KEYS:
        raise ValueError('invalid receipt schema: '+label)
    _decimal(r['l1ChainId'], label); _decimal(r['baseFeeAmount'], label)
    for key in ['l2ChainId','generation','parentHeight','lastHeight']:
        _uint(r[key], 64, label+'.'+key)
    for key in ['inbox','l2RewardRecipient']:
        _hex(r[key], 40, label+'.'+key)
    for key in ['parentHash','lastBlockHash']:
        _hex(r[key], 64, label+'.'+key)


def validate(corpus):
    """Frozen claim schema v1 (adapters/solidity/claim-schema.md); rejects implicit defaults."""
    exact_ids(corpus, 'corpus')
    for row in corpus:
        label = row['id']
        if not ROW_KEYS <= set(row) <= ROW_KEYS | OPTIONAL_KEYS or row['schemaVersion'] != 1:
            raise ValueError('invalid claim row schema: '+label)
        vault = row['vault']
        if not isinstance(vault, dict) or set(vault) != VAULT_KEYS or type(vault['entered']) is not bool:
            raise ValueError('invalid vault schema: '+label)
        _decimal(vault['l1ChainId'], label); _decimal(vault['balanceWei'], label)
        _uint(vault['chainId'], 64, label+'.chainId'); _hex(vault['inbox'], 40, label+'.inbox')
        # The constructor rejects a zero L1 identity; every row deploys a real vault.
        if int(vault['l1ChainId']) == 0 or int(vault['inbox'], 16) == 0 or vault['chainId'] == 0:
            raise ValueError('vault identity must be nonzero: '+label)
        ledger = row['ledger']
        if not isinstance(ledger, dict) or set(ledger) != {'account','mappingSlot','receipt'}:
            raise ValueError('invalid ledger schema: '+label)
        _hex(ledger['account'], 40, label+'.ledger'); _uint(ledger['mappingSlot'], 256, label+'.slot')
        check_receipt(row['receipt'], label); check_receipt(ledger['receipt'], label+'.ledger')
        if (row['accountProof'] not in PROOF_MODES or row['storageProof'] not in PROOF_MODES or
                row['root'] not in ROOT_MODES or row['recipient'] not in RECIPIENT_MODES):
            raise ValueError('invalid proof/root/recipient mode: '+label)
        _hex(row['caller'], 40, label+'.caller')
        recipient = int(row['receipt']['l2RewardRecipient'], 16)
        if int(row['caller'], 16) in {0, recipient}:
            raise ValueError('caller must be a distinct nonzero account: '+label)
        if row['recipient'] != 'eoa' and recipient == 0:
            raise ValueError('contract recipient fixtures need an address: '+label)
        if ('reentry' in row) != (row['recipient'] == 'reentrant'):
            raise ValueError('reentry is required exactly for reentrant recipients: '+label)
        # Each anchored root lives in one EIP-4788 ring slot. Rows may share a slot only for the
        # identical same-receipt nested claim; expiry deliberately reuses the observed slot.
        slots = {}
        def use(timestamp, owner):
            _uint(timestamp, 64, label+'.'+owner)
            if timestamp == 0:
                raise ValueError('EIP-4788 rejects timestamp zero: '+label)
            if slots.setdefault(timestamp % ROOTS_BUFFER, (timestamp, owner)) != (timestamp, owner):
                raise ValueError('EIP-4788 ring slot collision: '+label)
        use(row['anchorTimestamp'], 'claim')
        for key in sorted(OPTIONAL_KEYS & set(row)):
            nested = row[key]
            if not isinstance(nested, dict) or set(nested) != {'receipt','anchorTimestamp'}:
                raise ValueError('invalid '+key+' schema: '+label)
            check_receipt(nested['receipt'], label+'.'+key)
            same = (key == 'reentry' and nested['anchorTimestamp'] == row['anchorTimestamp'] and
                    nested['receipt'] == row['receipt'] == ledger['receipt'] and row['root'] == 'published')
            if not same:
                use(nested['anchorTimestamp'], key)
            if int(nested['receipt']['l2RewardRecipient'], 16) in {0, int(row['caller'], 16)}:
                raise ValueError(key+' must pay a distinct nonzero recipient: '+label)
        if row['root'] == 'expired' and (row['anchorTimestamp']+ROOTS_BUFFER) >= 2**64:
            raise ValueError('expiry write overflows uint64: '+label)
        if 'prior' in row and vault['entered']:
            raise ValueError('prior claims run on the unlocked vault: '+label)


def solidity(protocol, corpus, output, expected_mutant=None):
    """Stage, run and parse the actual harness; returns (exit code, log, observations)."""
    files = {HARNESS:(ROOT/'adapters/solidity/L2FeeVaultLeanConformance.t.sol').read_bytes(),
             STAGED_CORPUS:json.dumps(corpus).encode()}
    with staged_files(protocol, files, expected_mutant) as root:
        env = os.environ | {'FOUNDRY_PROFILE':'layer2','ETNA_CLAIM_CORPUS':str(root/STAGED_CORPUS)}
        # Bypass the compiler cache so a mutant or scoped lint artifact is never reused.
        cmd = ['forge','test','--no-cache','--match-path',HARNESS,'--match-test','test_claim_LeanCorpus','-vvv']
        p = subprocess.run(cmd,cwd=root,env=env,text=True,capture_output=True)
    log = p.stdout+p.stderr
    output.with_suffix('.log').write_text(log)
    observations = [json.loads(line.strip().removeprefix('CLAIM_OBSERVATION '))
                    for line in p.stdout.splitlines() if line.strip().startswith('CLAIM_OBSERVATION ')]
    output.write_text(''.join(json.dumps(v)+'\n' for v in observations))
    return p.returncode, log, observations


def compare(corpus, observations):
    validate(corpus)
    expected_ids = exact_ids(corpus, 'corpus')
    exact_ids(observations, 'Solidity output', expected_ids)
    actual = {r['id']:r for r in observations}
    augmented = [row | {'keccakOracle':oracle(row)} for row in corpus]
    with tempfile.TemporaryDirectory(prefix='etna-claim-') as temporary:
        p = Path(temporary)/'input.jsonl'
        p.write_text(''.join(json.dumps(v)+'\n' for v in augmented))
        lean = [json.loads(s) for s in run(['lake','env','lean','--run','Check/Claim.lean',str(p)]).splitlines()]
    exact_ids(lean, 'Lean output', expected_ids)
    rows = {r['id']:r for r in corpus}
    failures = []
    for expected in lean:
        obs = actual[expected['id']]
        for field in FIELDS:
            if field not in obs or normalize(expected[field]) != normalize(obs[field]):
                failures.append({'id':expected['id'],'field':field,'lean':expected[field],
                                 'solidity':obs.get(field)})
        # Lean's receipt encodings must be the independent ones, else its oracle lookups and
        # every batch-id comparison above would be vacuous.
        r = rows[expected['id']]['receipt']
        batch = '0x'+batch_preimage(r)
        batch_id = keccak(batch)
        if not isinstance(expected.get('expectedBatchPreimage'), str) or expected['expectedBatchPreimage'].lower() != batch:
            failures.append({'id':expected['id'],'field':'batchPreimage'})
        if normalize(expected['batchId']) != batch_id or normalize(obs.get('batchId')) != batch_id:
            failures.append({'id':expected['id'],'field':'independentBatchId'})
        commitment = '0x'+commitment_preimage(batch_id, r)
        if not isinstance(expected.get('expectedCommitmentPreimage'), str) or expected['expectedCommitmentPreimage'].lower() != commitment:
            failures.append({'id':expected['id'],'field':'commitmentPreimage'})
    return {'schema_version':1,'cases':len(corpus),'failures':failures,
            'specification':'Lean executable Etna.Landing.claim',
            'bridge':'actual production L2FeeVault with real single-leaf MPT proofs and the canonical EIP-4788 runtime; bytecode refinement pending',
            'crypto':'cast Keccak oracle keyed by exact preimage; the account/storage proof is the ProofSound boundary',
            'observations':'committed business state plus executed STATICCALL/CALL counts of the observed call'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--corpus',type=Path,default=ROOT/'corpus/claim.jsonl')
    p.add_argument('--observations',type=Path,required=True)
    p.add_argument('--protocol',type=Path,help='packages/protocol path; requires --run-solidity')
    p.add_argument('--run-solidity',action='store_true',help='only repository-required solidity-tester runs this')
    p.add_argument('--report',type=Path,default=ROOT/'reports/claim-conformance.json')
    a=p.parse_args()
    corpus=load(a.corpus)
    validate(corpus)
    if a.run_solidity:
        code, _, observations = solidity(a.protocol, corpus, a.observations)
        if code:
            raise RuntimeError(f'actual harness failed; see {a.observations.with_suffix(".log")}')
    else:
        observations = load(a.observations)
    result=compare(corpus,observations)
    result |= {'corpus_sha256':digest(a.corpus),'observations_sha256':digest(a.observations)}
    a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return bool(result['failures'])

if __name__=='__main__':
    raise SystemExit(main())
