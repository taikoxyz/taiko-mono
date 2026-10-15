#!/usr/bin/env python3
"""Inventory the actual solc runtime template; this does not establish reachability or refinement."""
import argparse
import collections
import hashlib
import json
import pathlib

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


def inventory(artifact):
    obj = json.loads(artifact.read_text())
    code = bytes.fromhex(obj['deployedBytecode']['object'].removeprefix('0x'))
    ops, length = disassemble(code)
    return {
        'schema_version': 1,
        'scope': 'whole EtnaInbox runtime template containing land; static instruction inventory, not land-only reachability',
        'compiler': obj['metadata']['compiler'], 'settings': obj['metadata']['settings'],
        'runtime_bytes': len(code), 'executable_prefix_bytes': length,
        'runtime_sha256': hashlib.sha256(code).hexdigest(),
        'immutable_references': obj['deployedBytecode']['immutableReferences'],
        'link_references': obj['deployedBytecode']['linkReferences'],
        'opcode_counts': dict(sorted(collections.Counter(op['opcode'] for op in ops).items())),
        'external_calls': [op for op in ops if op['opcode'] in ['CALL','DELEGATECALL','STATICCALL','CALLCODE']],
        'storage_layout': obj['storageLayout'],
        'instructions': ops,
        'solidity_refinement': 'pending',
        'gaps': ['Constructor immutable placeholders are not a bound deployment',
                 'No certified land-only CFG or bytecode-to-spec relation',
                 'Proxy DELEGATECALL, external calls, EIP-2935 state and verifier frame require proofs',
                 'EVMYulLean 4.22/Clear 4.9.1 oleans cannot be mixed into Lean 4.35 rc4',
                 'EVMYulLean Yul semantics documents gas and EXTCODESIZE/code operation gaps',
                 'Clear lacks BLOBHASH/TLOAD/TSTORE/MCOPY primitive names at pinned revision',
                 'Opcode presence in EVMYulLean is not an Osaka semantic coverage proof']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=pathlib.Path)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(inventory(args.artifact), indent=2) + '\n')
