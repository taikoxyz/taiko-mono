#!/usr/bin/env python3
"""Inventory the actual solc runtime template; this does not establish reachability or refinement."""
import argparse
import collections
import hashlib
import json
import pathlib
import re
import subprocess

# PUSH/DUP/SWAP/LOG are filled algorithmically; unnamed bytes remain visible.
NAMES = {0x00:'STOP',0x01:'ADD',0x02:'MUL',0x03:'SUB',0x04:'DIV',0x05:'SDIV',0x06:'MOD',0x07:'SMOD',0x08:'ADDMOD',0x09:'MULMOD',0x0a:'EXP',0x0b:'SIGNEXTEND',0x10:'LT',0x11:'GT',0x12:'SLT',0x13:'SGT',0x14:'EQ',0x15:'ISZERO',0x16:'AND',0x17:'OR',0x18:'XOR',0x19:'NOT',0x1a:'BYTE',0x1b:'SHL',0x1c:'SHR',0x1d:'SAR',0x20:'KECCAK256',0x30:'ADDRESS',0x31:'BALANCE',0x32:'ORIGIN',0x33:'CALLER',0x34:'CALLVALUE',0x35:'CALLDATALOAD',0x36:'CALLDATASIZE',0x37:'CALLDATACOPY',0x38:'CODESIZE',0x39:'CODECOPY',0x3a:'GASPRICE',0x3b:'EXTCODESIZE',0x3c:'EXTCODECOPY',0x3d:'RETURNDATASIZE',0x3e:'RETURNDATACOPY',0x3f:'EXTCODEHASH',0x40:'BLOCKHASH',0x41:'COINBASE',0x42:'TIMESTAMP',0x43:'NUMBER',0x44:'PREVRANDAO',0x45:'GASLIMIT',0x46:'CHAINID',0x47:'SELFBALANCE',0x48:'BASEFEE',0x49:'BLOBHASH',0x4a:'BLOBBASEFEE',0x50:'POP',0x51:'MLOAD',0x52:'MSTORE',0x53:'MSTORE8',0x54:'SLOAD',0x55:'SSTORE',0x56:'JUMP',0x57:'JUMPI',0x58:'PC',0x59:'MSIZE',0x5a:'GAS',0x5b:'JUMPDEST',0x5c:'TLOAD',0x5d:'TSTORE',0x5e:'MCOPY',0x5f:'PUSH0',0xf0:'CREATE',0xf1:'CALL',0xf2:'CALLCODE',0xf3:'RETURN',0xf4:'DELEGATECALL',0xf5:'CREATE2',0xfa:'STATICCALL',0xfd:'REVERT',0xfe:'INVALID',0xff:'SELFDESTRUCT'}
NAMES.update({i: f'PUSH{i-0x5f}' for i in range(0x60, 0x80)})
NAMES.update({i: f'DUP{i-0x7f}' for i in range(0x80, 0x90)})
NAMES.update({i: f'SWAP{i-0x8f}' for i in range(0x90, 0xa0)})
NAMES.update({i: f'LOG{i-0xa0}' for i in range(0xa0, 0xa5)})


def disassemble(code):
    metadata = int.from_bytes(code[-2:], 'big')
    # Solidity's CBOR trailer starts with a map. Preserve arbitrary raw code.
    length = len(code)
    if 0 < metadata < len(code) - 2 and 0xa0 <= code[-metadata-2] <= 0xbf:
        length -= metadata + 2
    ops = []
    pc = 0
    while pc < length:
        byte = code[pc]
        ops.append({'pc': pc, 'opcode': NAMES.get(byte, f'UNKNOWN_{byte:02x}')})
        pc += 1 + (byte - 0x5f if 0x60 <= byte <= 0x7f else 0)
    return ops, length


def git(checkout, *args):
    return subprocess.check_output(['git', '-C', str(checkout), *args])


def keccak(data):
    # cast implements Ethereum Keccak-256; hashlib.sha3_256 is a different hash.
    return subprocess.check_output(['cast', 'keccak', '0x' + data.hex()], text=True).strip()


def validate_sources(metadata, checkout, revision):
    if not re.fullmatch('[0-9a-f]{40}', revision) or git(checkout, 'rev-parse', 'HEAD').decode().strip() != revision:
        raise ValueError('source revision mismatch: use an exact immutable checkout')
    repo = pathlib.Path(git(checkout, 'rev-parse', '--show-toplevel').decode().strip())
    prefix = checkout.resolve().relative_to(repo.resolve())
    sources = metadata['sources']
    tracked = []
    for name, source in sources.items():
        path = (checkout / name).resolve()
        if pathlib.PurePosixPath(name).is_absolute() or '..' in pathlib.PurePosixPath(name).parts:
            raise ValueError(f'source path outside checkout: {name}')
        content = path.read_bytes()
        if keccak(content) != source['keccak256']:
            raise ValueError(f'source hash mismatch: {name}')
        relative = str(prefix / name)
        exists = subprocess.run(['git', '-C', str(repo), 'cat-file', '-e', f'{revision}:{relative}'], capture_output=True)
        if exists.returncode == 0:
            if git(repo, 'show', f'{revision}:{relative}') != content:
                raise ValueError(f'source differs from pinned git blob: {name}')
            tracked.append(name)
    targets = metadata['settings']['compilationTarget']
    if not targets or any(target not in tracked for target in targets):
        raise ValueError('compilation target must be tracked at source revision')
    return {'source_revision': revision, 'source_hashes': sources,
            'tracked_sources_at_revision': sorted(tracked),
            'dependency_sources_hash_verified': sorted(set(sources) - set(tracked))}


def capability_gaps(evmyul_readme, clear_primitives):
    gaps = ['Constructor immutable placeholders are not a bound deployment',
            'No certified land-only CFG or bytecode-to-spec relation',
            'Proxy DELEGATECALL, external calls, EIP-2935 state and verifier frame require proofs',
            'EVMYulLean 4.22/Clear 4.9.1 oleans cannot be mixed into Lean 4.35 rc4',
            'Opcode presence in EVMYulLean is not an Osaka semantic coverage proof']
    if 'gas' in evmyul_readme.lower() and 'EXTCODESIZE' in evmyul_readme:
        gaps.append('EVMYulLean Yul semantics documents gas and EXTCODESIZE/code operation gaps')
    if not any(name in clear_primitives.lower() for name in ['blobhash', 'tload', 'tstore', 'mcopy']):
        gaps.append('Clear lacks BLOBHASH/TLOAD/TSTORE/MCOPY primitives at pinned revision')
    if 'dummy implementations' in clear_primitives:
        gaps.append('Clear PrimOps explicitly marks CALL/STATICCALL/DELEGATECALL/log handling as dummy implementations')
    return gaps


def capabilities(evmyul, clear):
    lock = json.loads((pathlib.Path(__file__).resolve().parents[1] / 'tools.lock.json').read_text())
    contents = []
    evidence = []
    for name, checkout, file in [('evmyullean', evmyul, 'README.md'), ('clear', clear, 'Clear/PrimOps.lean')]:
        revision = lock[name]['revision']
        if git(checkout, 'rev-parse', 'HEAD').decode().strip() != revision:
            raise ValueError(f'{name} source revision mismatch')
        content = git(checkout, 'show', f'{revision}:{file}')
        contents.append(content.decode())
        evidence.append({'tool': name, 'revision': revision, 'file': file,
                         'sha256': hashlib.sha256(content).hexdigest()})
    return {'gaps': capability_gaps(*contents), 'capability_sources': evidence}


def inventory(artifact, checkout, revision, evmyul, clear):
    obj = json.loads(artifact.read_text())
    raw_metadata = json.loads(obj['rawMetadata'])
    # Foundry normalizes remapping contexts and ABI internalType fields. Validate
    # all source/compiler/settings fields against the authoritative solc metadata.
    normalized = json.loads(obj['rawMetadata'])
    normalized['settings']['remappings'] = [value.removeprefix(':') for value in normalized['settings'].get('remappings', [])]
    for key in ['compiler', 'language', 'sources', 'settings', 'version']:
        if normalized[key] != obj['metadata'][key]:
            raise ValueError(f'raw solc metadata mismatch: {key}')
    provenance = validate_sources(raw_metadata, checkout, revision)
    coverage = capabilities(evmyul, clear)
    code = bytes.fromhex(obj['deployedBytecode']['object'].removeprefix('0x'))
    ops, length = disassemble(code)
    return {
        'schema_version': 1,
        **provenance,
        'scope': 'whole EtnaInbox runtime template containing land; static instruction inventory, not land-only reachability',
        'compiler': obj['metadata']['compiler'], 'settings': obj['metadata']['settings'],
        'raw_metadata_sha256': hashlib.sha256(obj['rawMetadata'].encode()).hexdigest(),
        'runtime_bytes': len(code), 'executable_prefix_bytes': length,
        'runtime_sha256': hashlib.sha256(code).hexdigest(),
        'immutable_references': obj['deployedBytecode']['immutableReferences'],
        'link_references': obj['deployedBytecode']['linkReferences'],
        'opcode_counts': dict(sorted(collections.Counter(op['opcode'] for op in ops).items())),
        'external_calls': [op for op in ops if op['opcode'] in ['CALL','DELEGATECALL','STATICCALL','CALLCODE']],
        'storage_layout': obj['storageLayout'],
        'instructions': ops,
        'solidity_refinement': 'pending',
        **coverage}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=pathlib.Path)
    parser.add_argument('--source-checkout', type=pathlib.Path, required=True,
                        help='Exact protocol package checkout, containing contracts/ and node_modules/')
    parser.add_argument('--source-revision', required=True)
    parser.add_argument('--evmyul-root', type=pathlib.Path, required=True)
    parser.add_argument('--clear-root', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(inventory(args.artifact, args.source_checkout, args.source_revision,
                                               args.evmyul_root, args.clear_root), indent=2) + '\n')
