#!/usr/bin/env python3
"""Generate ZkGasModel/Tables.lean from alethia-reth's Unzen schedule and revm's Osaka tables.

Python 3.11+, standard library only. The sources are outside this repository, so CI cannot run
this script. Run it locally, and use --check to confirm that the committed file still matches:

    python3 scripts/gen_tables.py --reth <alethia-reth checkout> --registry <crates.io src dir> [--check]

<crates.io src dir> is Cargo's registry source directory, for example
~/.cargo/registry/src/index.crates.io-<hash>. The revm crate versions are pinned below and must be
the ones alethia-reth's Cargo.lock selects. The parsers accept only the statement shapes these
sources use today and fail on anything else, so a changed source cannot be misread silently.
"""
import argparse
import hashlib
from pathlib import Path
import re
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'ZkGasModel' / 'Tables.lean'
CRATES = {
    'revm-interpreter': '43.0.1',
    'revm-bytecode': '43.0.0',
    'revm-context-interface': '43.0.1',
    'revm-primitives': '43.0.0',
}
RETH_FILES = {
    'unzen': 'crates/evm/src/zk_gas/unzen.rs',
    'schedule': 'crates/evm/src/zk_gas/schedule.rs',
    'meter': 'crates/evm/src/zk_gas/meter.rs',
    'spec': 'crates/evm/src/spec.rs',
}
# spec.rs and Cargo.lock change for unrelated reasons, so only the facts read from them (Unzen's
# SpecId and the crate versions) are checked; the files that define the tables are also hashed.
RETH_HASHED = {'unzen', 'schedule', 'meter'}
REVM_FILES = {
    'instructions': ('revm-interpreter', 'src/instructions.rs'),
    'gas': ('revm-context-interface', 'src/cfg/gas.rs'),
    'hardfork': ('revm-primitives', 'src/hardfork.rs'),
    'opcode': ('revm-bytecode', 'src/opcode.rs'),
}
INT = r'(?:0x[0-9a-fA-F_]+|[0-9][0-9_]*)'


class SourceError(ValueError):
    """A source no longer has the exact shape this generator understands."""


def number(text):
    return int(text.replace('_', ''), 0)


def strip_comments(text):
    """Drop // line comments and /* */ block comments; the parsed regions contain no strings
    with slashes."""
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


def delimited(text, start, open_='{', close='}'):
    """Return the text between the first `open_` at or after `start` and its matching `close`."""
    i = text.find(open_, start)
    if i < 0:
        raise SourceError(f'missing {open_!r}')
    depth = 0
    for j in range(i, len(text)):
        if text[j] == open_:
            depth += 1
        elif text[j] == close:
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
    raise SourceError(f'unbalanced {open_!r}')


def item_body(text, pattern, open_='{', close='}'):
    match = re.search(pattern, text)
    if not match:
        raise SourceError(f'missing item: {pattern}')
    return delimited(text, match.end(), open_, close)


def statements(body):
    return [s.strip() for s in body.split(';') if s.strip()]


def single(pattern, text, what):
    found = re.findall(pattern, text)
    if len(found) != 1:
        raise SourceError(f'expected exactly one {what}, found {len(found)}')
    return found[0]


# --- alethia-reth ---------------------------------------------------------------------------

def parse_reth(src):
    """Return block limit, intrinsic, fail-safe, opcode multipliers, precompiles and spawn
    estimates exactly as the Unzen schedule uses them, and the revm SpecId Unzen maps to."""
    unzen = strip_comments(src['unzen'])
    limit = number(single(rf'pub const BLOCK_ZK_GAS_LIMIT: u64 = ({INT});', unzen, 'BLOCK_ZK_GAS_LIMIT'))
    intrinsic = number(single(rf'pub const TX_INTRINSIC_ZK_GAS: u64 = ({INT});', unzen, 'TX_INTRINSIC_ZK_GAS'))

    # The Unzen schedule must be built from exactly these constants and tables.
    args = item_body(unzen, r'pub static UNZEN_ZK_GAS_SCHEDULE: ZkGasSchedule = unzen_schedule_with', '(', ')')
    if [a.strip() for a in args.split(',') if a.strip()] != [
            'BLOCK_ZK_GAS_LIMIT', 'TX_INTRINSIC_ZK_GAS', 'unzen_opcode_multipliers()', 'UNZEN_PRECOMPILE_MULTIPLIERS']:
        raise SourceError(f'UNZEN_ZK_GAS_SCHEDULE arguments changed: {args.split()}')
    params = item_body(unzen, r'const fn unzen_schedule_with', '(', ')')
    names = re.findall(r'(\w+)\s*:', params)
    if names != ['block_limit', 'tx_intrinsic_zk_gas', 'opcode_multipliers', 'precompile_multipliers']:
        raise SourceError(f'unzen_schedule_with parameters changed: {names}')
    builder = item_body(unzen, r'const fn unzen_schedule_with[^{]*')
    literal = item_body(builder, r'ZkGasSchedule\s*')
    spawn_fields = item_body(literal, r'spawn_estimates:\s*SpawnEstimates\s*')
    rest = literal.replace(spawn_fields, '')
    for field in names:
        if not re.search(rf'(?:^|,)\s*{field}\s*,', rest):
            raise SourceError(f'ZkGasSchedule field {field} is not the shorthand parameter')
    spawn = {}
    for field in [f.strip() for f in spawn_fields.split(',') if f.strip()]:
        match = re.fullmatch(rf'(\w+):\s*({INT})', field)
        if not match or match.group(1) in spawn:
            raise SourceError(f'unsupported spawn estimate field: {field}')
        spawn[match.group(1)] = number(match.group(2))

    schedule = strip_comments(src['schedule'])
    failsafe = single(rf'pub const FAILSAFE_MULTIPLIER: u16 = (u16::MAX|{INT});', schedule, 'FAILSAFE_MULTIPLIER')
    failsafe = 0xFFFF if failsafe == 'u16::MAX' else number(failsafe)
    lookup = item_body(schedule, r'pub fn precompile_multiplier\(&self, address: &Address\) -> u16')
    if 'map_or(FAILSAFE_MULTIPLIER' not in lookup or 'addr == address' not in lookup:
        raise SourceError('precompile_multiplier no longer falls back to FAILSAFE_MULTIPLIER by exact address')

    body = item_body(unzen, r'const fn unzen_opcode_multipliers\(\) -> \[u16; 256\]')
    body = statements(body.replace('[FAILSAFE_MULTIPLIER; 256]', '[FAILSAFE_MULTIPLIER x 256]', 1))
    if body[0] != 'let mut array = [FAILSAFE_MULTIPLIER x 256]' or body[-1] != 'array':
        raise SourceError('unzen_opcode_multipliers no longer starts from FAILSAFE_MULTIPLIER')
    opcode_mult = {}
    for stmt in body[1:-1]:
        match = re.fullmatch(rf'array\[(0x[0-9a-fA-F]{{2}})\] = ({INT})', stmt)
        if not match:
            raise SourceError(f'unsupported opcode multiplier statement: {stmt}')
        op = number(match.group(1))
        if op in opcode_mult:
            raise SourceError(f'opcode multiplier 0x{op:02x} assigned twice')
        opcode_mult[op] = number(match.group(2))

    header = r'const UNZEN_PRECOMPILE_MULTIPLIERS: &\[\(Address, u16\)\] = &'
    listing = item_body(unzen, header, '[', ']')
    precompiles = {}
    pattern = re.compile(r'\(\s*(?:Address::with_last_byte\((0x[0-9a-fA-F]{1,2})\)|address!\("(0x[0-9a-fA-F]{40})"\))'
                         rf'\s*,\s*({INT})\s*\)')
    for match in pattern.finditer(listing):
        addr = number(match.group(1) or match.group(2))
        if addr in precompiles:
            raise SourceError(f'precompile 0x{addr:x} listed twice')
        precompiles[addr] = number(match.group(3))
    if pattern.sub('', listing).replace(',', '').strip():
        raise SourceError('unsupported entry in UNZEN_PRECOMPILE_MULTIPLIERS')
    # Names for the generated comments only: an entry's trailing comment, or else the first word
    # of the comment block just above it.
    precompile_names, above = {}, None
    for line in item_body(src['unzen'], header, '[', ']').splitlines():
        code, _, note = line.partition('//')
        match = pattern.search(code)
        if match:
            precompile_names[number(match.group(1) or match.group(2))] = (note.split() or [above])[0]
            above = None
        elif note.split() and not code.strip() and above is None:
            above = note.split()[0]
    if set(precompile_names) != set(precompiles):
        raise SourceError('precompile comments and entries differ')

    meter = strip_comments(src['meter'])
    arms = item_body(meter, r'fn spawn_estimate\(schedule: &ZkGasSchedule, opcode: u8\) -> u64[^{]*\{\s*match opcode')
    arm_list = [a.strip() for a in arms.split(',') if a.strip()]
    if not arm_list or not arm_list[-1].startswith('_ => unreachable!'):
        raise SourceError('spawn_estimate no longer rejects non-spawn opcodes')
    spawn_by_op, used = {}, set()
    for arm in arm_list[:-1]:
        match = re.fullmatch(r'(0x[0-9a-fA-F]{2}) => schedule\.spawn_estimates\.(\w+)', arm)
        if not match or match.group(2) not in spawn or number(match.group(1)) in spawn_by_op:
            raise SourceError(f'unsupported spawn_estimate arm: {arm}')
        spawn_by_op[number(match.group(1))] = spawn[match.group(2)]
        used.add(match.group(2))
    if used != set(spawn) or len(spawn_by_op) != len(spawn):
        raise SourceError('spawn estimate fields and spawn_estimate arms differ')
    spawn_set = single(r'fn is_spawn_opcode\(opcode: u8\) -> bool \{\s*matches!\(opcode, ([^)]*)\)', meter, 'is_spawn_opcode')
    if {number(x.strip()) for x in spawn_set.split('|')} != set(spawn_by_op):
        raise SourceError('is_spawn_opcode and spawn_estimate disagree')

    spec = single(r'Self::UNZEN => SpecId::(\w+),', strip_comments(src['spec']), 'UNZEN SpecId mapping')
    return {'limit': limit, 'intrinsic': intrinsic, 'failsafe': failsafe, 'opcode_mult': opcode_mult,
            'precompiles': precompiles, 'precompile_names': precompile_names, 'spawn': spawn_by_op, 'spec': spec}


# --- revm -----------------------------------------------------------------------------------

def parse_revm(src, spec):
    """Return opcode names/inputs and the static gas table that `gas_table_spec(spec)` builds,
    plus the fork blocks that table skips."""
    order = [v.split('=')[0].strip() for v in
             re.sub(r'#\[[^\]]*\]', '', item_body(strip_comments(src['hardfork']), r'pub enum SpecId')).split(',')
             if v.strip()]
    if spec not in order:
        raise SourceError(f'unknown SpecId {spec}')

    consts = {name: number(value) for name, value in
              re.findall(rf'(?m)^pub const (\w+): u64 = ({INT});', strip_comments(src['gas']))}

    ops = {}
    for stmt in statements(item_body(strip_comments(src['opcode']), r'(?m)^opcodes! ')):
        match = re.fullmatch(r'(0x[0-9A-Fa-f]{2})\s*=>\s*(\w+)\s*=>\s*(.*)', stmt, re.S)
        io = match and re.search(r'stack_io\((\d+),\s*(\d+)\)', match.group(3))
        if not io or number(match.group(1)) in ops:
            raise SourceError(f'unsupported opcode entry: {stmt}')
        ops[number(match.group(1))] = (match.group(2), int(io.group(1)))
    by_name = {name: op for op, (name, _) in ops.items()}

    def value(expr):
        match = re.fullmatch(rf'({INT})|gas::(\w+) as u16', expr.strip())
        if not match:
            raise SourceError(f'unsupported gas table value: {expr}')
        result = number(match.group(1)) if match.group(1) else consts.get(match.group(2))
        if result is None or not 0 <= result < 1 << 16:
            raise SourceError(f'unknown or out-of-range gas constant: {expr}')
        return result

    def assign(table, stmt):
        match = re.fullmatch(r'table\[(\w+) as usize\] = (.+)', stmt, re.S)
        if not match or match.group(1) not in by_name:
            raise SourceError(f'unsupported gas table statement: {stmt}')
        table[by_name[match.group(1)]] = value(match.group(2))

    instructions = strip_comments(src['instructions'])
    if 'pub const fn gas_table() -> GasTable {\n    const { gas_table_impl() }\n}' not in instructions:
        raise SourceError('gas_table() no longer returns gas_table_impl()')
    base = item_body(instructions, r'const fn gas_table_impl\(\) -> GasTable')
    base = statements(base.replace('[0u16; 256]', '[0u16 x 256]', 1))
    if base[:2] != ['use bytecode::opcode::*', 'let mut table = [0u16 x 256]'] or base[-1] != 'table':
        raise SourceError('gas_table_impl no longer starts from a zero table')
    table = [0] * 256
    for stmt in base[2:-1]:
        assign(table, stmt)

    body = item_body(instructions, r'pub const fn gas_table_spec\(spec: SpecId\) -> GasTable')
    skipped = []
    blocks = list(re.finditer(r'if spec\.is_enabled_in\((\w+)\)', body))
    rest = body
    for match in blocks:
        fork = match.group(1)
        inner = delimited(body, match.end())
        rest = rest.replace(f'if spec.is_enabled_in({fork}) {{{inner}}}', '', 1)
        if fork not in order:
            raise SourceError(f'unknown fork {fork}')
        if order.index(fork) > order.index(spec):
            skipped.append(fork)
            continue
        for stmt in statements(inner):
            assign(table, stmt)
    if statements(rest) != ['use bytecode::opcode::*', 'use SpecId::*', 'let mut table = gas_table()', 'table']:
        raise SourceError('gas_table_spec has statements outside its fork blocks')
    return {'ops': ops, 'static': table, 'skipped': skipped}


# --- sources and rendering ------------------------------------------------------------------

def load(reth, registry):
    lock = tomllib.loads((reth / 'Cargo.lock').read_text())
    for crate, version in CRATES.items():
        versions = sorted(p['version'] for p in lock['package'] if p['name'] == crate)
        if versions != [version]:
            raise SourceError(f'alethia-reth Cargo.lock selects {crate} {versions}, not {version}')
    files, src = [], {}
    for key, rel in RETH_FILES.items():
        path = reth / rel
        src[key] = path.read_text()
        if key in RETH_HASHED:
            files.append((f'alethia-reth `{rel}`', path))
    for key, (crate, rel) in REVM_FILES.items():
        crate_dir = registry / f'{crate}-{CRATES[crate]}'
        manifest = tomllib.loads((crate_dir / 'Cargo.toml').read_text())['package']
        if (manifest['name'], manifest['version']) != (crate, CRATES[crate]):
            raise SourceError(f'{crate_dir} is not {crate} {CRATES[crate]}')
        path = crate_dir / rel
        src[key] = path.read_text()
        files.append((f'{crate} {CRATES[crate]} `{rel}`', path))
    return src, [(label, hashlib.sha256(path.read_bytes()).hexdigest()) for label, path in files]


def entries(pairs, names=None):
    """One `(key, value)` pair per line, keys in hex, with the opcode name as a comment."""
    lines = []
    for i, (key, val) in enumerate(pairs):
        sep = ',' if i + 1 < len(pairs) else ''
        name = f'  -- {names[key]}' if names and key in names else ''
        lines.append(f'  (0x{key:02x}, {val}){sep}{name}')
    return '\n'.join(lines)


def render(reth, revm, hashes):
    ops = revm['ops']
    names = {op: name for op, (name, _) in ops.items()}
    defined = sorted(ops)
    sources = '\n'.join(f'- {label}: `{digest}`' for label, digest in hashes)
    return f'''/-!
# Unzen zk gas tables and revm {reth['spec'].capitalize()} opcode tables

Generated by `scripts/gen_tables.py`; do not edit by hand. To regenerate, or to confirm with
`--check` that this file still matches its sources, run from `formal/zk-gas`:

```
python3 scripts/gen_tables.py --reth <alethia-reth checkout> --registry <crates.io src dir> [--check]
```

Sources and their SHA-256 hashes (alethia-reth's `Cargo.lock` selects these crate versions):
{sources}

The Unzen values come from `UNZEN_ZK_GAS_SCHEDULE` in `unzen.rs`, the fail-safe multiplier from
`schedule.rs` and the spawn opcode of each estimate from `spawn_estimate` in `meter.rs`. Unzen
runs revm `SpecId::{reth['spec']}` (`spec.rs`). Static gas is the table
`gas_table_spec({reth['spec']})` builds; it skips the fork blocks for {', '.join(revm['skipped']) or 'no forks'}.
`inputs` is revm-bytecode's `OpCode::inputs()`. Opcodes revm-bytecode does not define have static
gas 0 and inputs 0. An opcode with no multiplier entry gets the fail-safe multiplier.
-/
namespace TaikoSpec.ZkGas

/-- `BLOCK_ZK_GAS_LIMIT`: the zk gas one Unzen block may use. -/
def unzenBlockLimit : Nat := {reth['limit']}

/-- `TX_INTRINSIC_ZK_GAS`: the zk gas every block transaction is charged first. -/
def unzenTxIntrinsic : Nat := {reth['intrinsic']}

/-- `FAILSAFE_MULTIPLIER` (`u16::MAX`): the multiplier of an unlisted opcode or precompile. -/
def failsafeMultiplier : Nat := {reth['failsafe']}

/-- A 256-entry table: `default` everywhere except at the listed opcodes. -/
def denseTable (default : Nat) (entries : List (Nat × Nat)) : Array Nat :=
  (List.range 256).toArray.map fun op => (entries.lookup op).getD default

/-- Unzen opcode multipliers that differ from the fail-safe default, by opcode. -/
def unzenOpcodeMultiplierEntries : List (Nat × Nat) := [
{entries(sorted(reth['opcode_mult'].items()), names=names)}
]

/-- Unzen precompile multipliers by full precompile address. -/
def unzenPrecompileMultipliers : List (Nat × Nat) := [
{entries(sorted(reth['precompiles'].items()), names=reth['precompile_names'])}
]

/-- Unzen raw-gas estimates of the spawn opcodes, by opcode. -/
def unzenSpawnEstimates : List (Nat × Nat) := [
{entries(sorted(reth['spawn'].items()), names=names)}
]

/-- revm static gas (`gas_table_spec({reth['spec']})`) of every opcode revm-bytecode defines. -/
def staticGasEntries : List (Nat × Nat) := [
{entries([(op, revm['static'][op]) for op in defined], names=names)}
]

/-- revm-bytecode `OpCode::inputs()` of every opcode it defines. -/
def inputsEntries : List (Nat × Nat) := [
{entries([(op, ops[op][1]) for op in defined], names=names)}
]

/-- The Unzen opcode multiplier table, indexed by opcode. -/
def unzenOpcodeMultipliers : Array Nat := denseTable failsafeMultiplier unzenOpcodeMultiplierEntries

/-- revm static gas by opcode: the table the interpreter charges before running an opcode. -/
def staticGasTable : Array Nat := denseTable 0 staticGasEntries

/-- revm-bytecode stack inputs by opcode. -/
def inputsTable : Array Nat := denseTable 0 inputsEntries

/-- revm {reth['spec'].capitalize()} static gas of opcode `op` (0 outside the opcode range). -/
def staticGas (op : Nat) : Nat := staticGasTable.getD op 0

/-- revm-bytecode `OpCode::inputs()` of opcode `op` (0 outside the opcode range). -/
def inputs (op : Nat) : Nat := inputsTable.getD op 0

end TaikoSpec.ZkGas
'''


def check_consistency(reth, revm):
    """Return the table entries whose source is ambiguous or needs a reviewer's note."""
    notes = []
    static = revm['static']
    for op in revm['ops']:
        if static[op] and op not in reth['opcode_mult']:
            notes.append(f"0x{op:02x} {revm['ops'][op][0]}: static gas {static[op]} but no Unzen multiplier "
                         '(fail-safe)')
    for op in reth['opcode_mult']:
        if op not in revm['ops']:
            notes.append(f'0x{op:02x}: Unzen multiplier for an opcode revm-bytecode does not define')
    return notes


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--reth', type=Path, required=True, help='alethia-reth checkout')
    parser.add_argument('--registry', type=Path, required=True, help="Cargo's crates.io source directory")
    parser.add_argument('--check', action='store_true', help='compare instead of writing')
    parser.add_argument('--output', type=Path, default=OUTPUT)
    args = parser.parse_args()
    try:
        src, hashes = load(args.reth, args.registry)
        reth = parse_reth(src)
        revm = parse_revm(src, reth['spec'])
    except (OSError, KeyError, ValueError) as exc:
        print(f'gen_tables: {exc}', file=sys.stderr)
        return 1
    text = render(reth, revm, hashes)
    for note in check_consistency(reth, revm):
        print(f'note: {note}')
    if args.check:
        if not args.output.is_file() or args.output.read_text() != text:
            print(f'{args.output.name} differs from its sources; regenerate it', file=sys.stderr)
            return 1
        print(f'{args.output.name}: matches its sources')
        return 0
    args.output.write_text(text)
    print(f'wrote {args.output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
