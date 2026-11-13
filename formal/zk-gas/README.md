# Unzen zk gas metering model

This package is an executable Lean model of Unzen zk gas metering as alethia-reth implements it,
with proved claims about how one block's charges are accounted. It pins the specification
[`zk_gas_spec.md`](../../packages/protocol/docs/zk_gas_spec.md) at revision
`aef6a3e4b954cc84cdff3d2434a1fe060a80bcd3` in [`spec-coverage.json`](spec-coverage.json).
The theorems concern this model; they do not establish equivalence of production clients.

## Scope

The model has three parts:

- **Tables.** [`ZkGasModel/Tables.lean`](ZkGasModel/Tables.lean) holds the Unzen block limit,
  intrinsic charge, fail-safe multiplier, opcode and precompile multipliers and spawn estimates,
  and revm's Osaka static gas and stack inputs per opcode. It is generated from the sources (see
  [Tables](#tables)); do not edit it by hand.
- **Metering.** [`ZkGasModel/Meter.lean`](ZkGasModel/Meter.lean) defines `Schedule`, the `unzen`
  schedule, `precompileMult` (listed value, else 65535), `meterTx` and `meterBlock`. A
  transaction is the list of its charges in metering order, starting with its intrinsic charge:
  alethia-reth charges `TX_INTRINSIC_ZK_GAS` through the same meter as every opcode and
  precompile charge, so it can abort the transaction like any other. `meterTx` returns the
  transaction's total, or `none` as soon as the total exceeds the block limit minus the block's
  committed zk gas. `meterBlock` stops at the first aborted transaction; the transactions after
  it get no result.
- **Steps.** [`ZkGasModel/Step.lean`](ZkGasModel/Step.lean) defines `stepOutcome`, the gas
  after one interpreter step, how it ended and the branch that decided it, from `Pre`
  ([`ZkGasModel/Pre.lean`](ZkGasModel/Pre.lean)): the opcode, depth, gas, the top of the stack,
  the memory size and the state facts the opcode's gas depends on. It transcribes alethia-reth's
  metered step (revm's `Interpreter::step`, with the halt materialized before the charge): the
  static gas first, whose shortfall spends all gas, then the instruction body. Each opcode
  category's body is in [`ZkGasModel/Step/`](ZkGasModel/Step); the result types and branch
  names are in [`Step/Basic.lean`](ZkGasModel/Step/Basic.lean). It covers STOP, the arithmetic,
  bitwise and stack opcodes, the environment reads (SELFBALANCE and BLOCKHASH included), JUMP,
  JUMPI, JUMPDEST, EXP, the opcodes not activated on Unzen, INVALID and undefined ones, the
  memory opcodes (MLOAD, MSTORE, MSTORE8, MCOPY) and KECCAK256 with their memory expansion,
  CALLDATACOPY, CODECOPY, RETURNDATACOPY, EXTCODECOPY (with its cold surcharge), RETURN, REVERT,
  LOG0..LOG4, the state access opcodes: SLOAD, SSTORE (with its reentrancy sentry and
  EIP-2200/2929 costs), BALANCE, EXTCODESIZE, EXTCODEHASH, SELFDESTRUCT, TLOAD and TSTORE, and
  the CALL family (CALL, CALLCODE, DELEGATECALL, STATICCALL: memory ranges, value transfer, cold
  target, new account, EIP-7702 delegate) and CREATE and CREATE2 (initcode limit and word cost,
  memory, base and hashing cost), whose warm, cold and empty accounts and slots come from the
  step's facts. Every opcode is modeled. A CALL or CREATE that passes its checks opens a new
  frame, which alethia-reth charges its spawn estimate; what the frame then does (depth,
  balance, nonce, address collision, empty code, a precompile) does not change that step.

  Facts are read before the step. For a CALL-family target whose EIP-7702 delegation points at
  the target itself, revm warms the target before it loads the delegate, so the delegate is
  warm for revm while the step's `delegate_warm` fact says cold when the target was cold: the
  model charges that case 2,500 gas more than revm. The corpus authoring rules forbid such a
  target.

How a precompile's gas use is computed is not modeled. The claims below take every charge
amount as given; the step model is checked against the traces only.

## Trace checker

`lake exe check-traces <corpus-dir>` checks every vector's trace, `traces/<id>.jsonl` in the
corpus (format: "Trace schema v1" in
[`testdata/zk_gas_vectors/README.md`](../../testdata/zk_gas_vectors/README.md#trace-schema-v1)),
against the model and the vector's expected values. [`ZkGasTraces/Json.lean`](ZkGasTraces/Json.lean)
parses the events and rejects anything outside the schema;
[`ZkGasTraces/Check.lean`](ZkGasTraces/Check.lean) checks the event order, each step's and
precompile's charge, each charge's meter verdict, and feeds every tx's charges to `meterBlock`
(a harness frame's to `meterTx`) to reproduce the vector's expected values. It takes a step model
`Pre → Except String (gas_after × outcome × branch)` and runs `stepModel`, which is
`stepOutcome` on Unzen. Every step must be decided by the model: a step it cannot decide, such
as one whose pre-state lacks a fact the model reads, fails the check.

For every step, the checker compares `spawn` (a step spawns exactly when its outcome is a new
frame) and `gas_after` with the model's; for a spawn step, `gas_after` is the gas left after the
gas it forwards, which alethia-reth records exactly. Unless the meter rejected the step's charge,
it checks the outcome against the event after the step: a step that continues is followed by a
step at its depth; a step that ends a child frame by a step exactly one depth up, and a step that
ends the top frame by the end of the tx or frame, where a harness trace's `frame_end` has the
status of its outcome (`success` for STOP, RETURN and SELFDESTRUCT, `revert` for REVERT, `halt`
for the other halts); a step that opens a frame by a step one deeper, a precompile, a step at its
depth (the new frame ran no step) or the end.

It also checks the gas each frame gets back, following revm-handler 43.0.2 `src/frame.rs`. When
a child frame that ran steps ends, the frame that opened it resumes with its spawn step's
`gas_after` plus what the child returns: the child's gas left when the child's last step
succeeds or reverts (a CALL child's includes a value transfer's stipend), and nothing when it
halts. A CREATE child that returns code first pays a code deposit of 200 gas per byte; code
above 24,576 bytes, a deposit it cannot pay or code starting with 0xEF makes it a halt. The trace
does not record the code's first byte, so a CREATE child that can pay its deposit may return
either the rest or nothing. After a precompile run that a spawn step opened, the caller resumes
with the spawn step's `gas_after` plus the precompile's `left`. A spawn step whose new frame
runs no step (an account without code, or a frame the handler refuses) is not checked this way.

The checker stops at the first failure with the vector id, the event index and the reason, and
exits 1. Every vector needs a trace and every trace a vector. The gate runs `check-traces` once
the corpus has a `traces/` directory and skips it before then. Trace checking is not part of the
evidence below.

## Claims to review

Start with [`ZkGasStatements/Claims.lean`](ZkGasStatements/Claims.lean), then
[`ZkGasProofs/Claims.lean`](ZkGasProofs/Claims.lean). The three headline theorems have exactly
the corresponding named proposition as their type; the audit rejects added premises or a
replacement conclusion at that boundary.

| Statement                 | Theorem in `TaikoSpec.ZkGas.Proofs` | Content                                                                                                                                                                 |
| ------------------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BlockWithinLimit`        | `block_within_limit`                | A block's total never exceeds the schedule's block limit, whatever its transactions charge.                                                                             |
| `AbortContributesNothing` | `abort_contributes_nothing`         | After committed transactions, a transaction whose charges exceed what the block has left ends the block: the total stays the same and later transactions get no result. |
| `TotalIsSum`              | `total_is_sum`                      | A committed transaction's total is the sum of its charges, intrinsic charge included, and the block total is the sum of the committed totals.                           |

Statement names are under `TaikoSpec.ZkGas.Statements`. The claims range over every schedule, so
they hold for `unzen` in particular. Together they do not force a transaction that fits to be
committed; the witnesses below check that behavior on examples.

## Tables

[`scripts/gen_tables.py`](scripts/gen_tables.py) reads these sources and writes `Tables.lean`,
whose header records each source file's SHA-256 hash:

- alethia-reth `crates/evm/src/zk_gas/unzen.rs` (`UNZEN_ZK_GAS_SCHEDULE`: block limit, intrinsic
  charge, opcode and precompile multipliers, spawn estimates), `schedule.rs` (the fail-safe
  multiplier and the precompile lookup) and `meter.rs` (the opcode of each spawn estimate);
  `spec.rs` maps Unzen to revm `SpecId::OSAKA`;
- revm-interpreter 43.0.1 `src/instructions.rs` (`gas_table_spec`), revm-context-interface
  43.0.1 `src/cfg/gas.rs` (its named constants), revm-primitives 43.0.0 `src/hardfork.rs` (fork
  order) and revm-bytecode 43.0.0 `src/opcode.rs` (opcode numbers and `OpCode::inputs()`). The
  generator checks that alethia-reth's `Cargo.lock` selects these versions.

The parsers accept only the statement shapes these sources use and fail on anything else. The
sources are outside this repository, so CI cannot regenerate the file. Run the generator locally
with `--check` to confirm the committed file still matches them:

```bash
python3 scripts/gen_tables.py --reth <alethia-reth checkout> \
  --registry ~/.cargo/registry/src/index.crates.io-<hash> --check
```

In CI, the gate tests compare the committed multipliers, spawn estimates, block limit and
intrinsic charge with the specification's protocol constants, pseudocode and Appendix B.

Static gas is the value revm charges before an opcode runs. Some entries need care when the step
model uses them:

- `CREATE`, `CREATE2` and `SSTORE` have static gas 0; revm charges their costs inside the
  instruction. `SELFDESTRUCT` has 5,000 and the CALL family 100.
- `SLOTNUM` (0x4b), `DUPN`, `SWAPN` and `EXCHANGE` (0xe6–0xe8) are in revm's gas table and
  opcode list, but Unzen lists no multiplier for them, so they get the fail-safe multiplier.
  revm-bytecode gives `DUPN`, `SWAPN` and `EXCHANGE` zero stack inputs.
- Opcodes revm-bytecode does not define have static gas 0 and inputs 0.

## Specification traceability and exclusions

The manifest links every headline to headings in the pinned file and verifies its SHA-256 hash.
Links and hashes are traceability, not a percentage of the specification proved. Review the
[pseudocode](../../packages/protocol/docs/zk_gas_spec.md#pseudocode) and
[core idea](../../packages/protocol/docs/zk_gas_spec.md#core-idea) alongside the statements.

Outside the claims' scope: how each charge is computed (the step model's results are
checked against the traces, not proved); EVM execution and discarding an aborted
transaction's state changes; which transactions are invalid for reasons other than zk gas; block
builders' transaction selection, which may skip an overflowing candidate and continue (block
execution and proving stop at the first one); publishing the block total in the header and
checking it on import; and equivalence with production clients.

The model follows alethia-reth where the pseudocode is phrased differently:

- The pseudocode computes in uint64 and treats an overflow as exceeding the limit. The model uses
  unbounded natural numbers; an overflowing sum or product already exceeds the block limit, so
  both abort.
- The pseudocode adds each charge and then compares block plus transaction zk gas with the limit.
  The model, like alethia-reth, rejects a charge once the transaction total would exceed the
  limit minus the block's committed zk gas. The conditions agree because the running total never
  exceeds the limit.
- The intrinsic charge is the first entry of a transaction's charge list rather than a separate
  step.

Specification changes intentionally fail CI until the model, claims, exclusions and pins are
reviewed together.

## Witnesses and trust boundary

[`ZkGasWitnesses/Tests.lean`](ZkGasWitnesses/Tests.lean) holds executable `#guard` regressions:
table spot checks against the specification and revm (ADD, PUSH1, point_evaluation, an unlisted
precompile, ADD and CREATE static gas), meter cases at and just past the block limit, and the
trace parser and checker on fixture traces: canonical hex up to 2^256 - 1, malformed records and
`facts`, the two smoke vectors' traces, and each kind of failure (event order, step, precompile
and intrinsic charges, meter verdicts, totals against the expected values, model disagreement,
a spawn step's `gas_after`), the two shapes with no step: a tx skipped before its intrinsic
charge (a lone skipped `tx_end`) and a harness call to an account without code (`frame_end`
alone), and a hand-made step whose pre-state lacks the fact the model reads, which fails the
check. Guards that flip one modeled step's outcome check that the checker rejects an outcome the
next event contradicts, including a child frame's last step that ends at the wrong depth or
returns the wrong gas (committed traces of a returned stipend, a halt, a CREATE's implicit STOP
and a code deposit) and a precompile that leaves the wrong gas. The step model has at least one
guard per branch: a step line copied verbatim from a committed reth trace, which expects that
line's `gas_after` (for a spawn step, the gas left after the gas it forwards). Further guards
cover a missing fact or stack item, every opcode being modeled and the undefined ones being
exactly those revm does not define, checks whose order the traces cannot show (the static
context before the pops, SSTORE's pops before its sentry, CALL's static-frame value check before
its memory operands, the CALL family's input range before its output range and both before the
transfer cost) and each EIP-7702 delegate stage at its gas boundaries. They run during
compilation and are **not kernel proofs**.

The full gate combines independent checks:

1. Python lexes the accepted source subset, ignoring nested comments and escaped strings, and
   rejects proof escapes, metaprogramming commands and unreviewed compiler options. `#guard` is
   allowed only in `ZkGasWitnesses/Tests.lean`. Model and Statements forbid source
   theorem/example commands. The only explicit `Lean` import allowed is `Lean.Data.Json`, and
   only `ZkGasTraces.Json` and `ZkGasTraces.Check` may import it and name its types.
2. The import graph enforces downward library dependencies, existing modules and reachability
   from every library root.
3. The specification gate checks the exact source path, revision, hash, headline mappings,
   existing section headings and nonempty drift/exclusion explanations.
4. The separately compiled [`scripts/Audit.lean`](scripts/Audit.lean) inspects all five
   libraries. Every owned declaration may depend only on `propext`, `Classical.choice` and
   `Quot.sound`. It checks three exact headline types and named claim dependencies, and rejects
   proof-valued declarations in Model and Statements. [`scripts/AuditTests.lean`](scripts/AuditTests.lean)
   checks that it rejects weakened or missing headlines, extra axioms and erased dependencies.
5. `leanchecker` replays all five libraries in Lean's kernel.

Mechanical limits: the source gate is a bounded lexer, not a complete Lean parser or adversarial
sandbox. Named dependency anchors catch accidental erasure but not arbitrary weakening of
statement bodies; review proposition meanings directly. Neither these checks nor kernel replay
prove that the model matches the prose, the clients or the generated tables' sources. Executable
tests also trust Lean's compiler and runtime; theorem checking trusts the Lean kernel and the
three standard axioms.

## Layout and validation

| Library           | Responsibility                    | Allowed package imports                      |
| ----------------- | --------------------------------- | -------------------------------------------- |
| `ZkGasModel`      | Tables and executable definitions | Model                                        |
| `ZkGasStatements` | Propositions                      | Statements, Model                            |
| `ZkGasProofs`     | Lemmas and headline proofs        | Proofs, Statements, Model                    |
| `ZkGasWitnesses`  | Regressions                       | Witnesses, Proofs, Statements, Model, Traces |
| `ZkGasTraces`     | Trace parser and checker          | Traces, Model                                |

Audit tooling is outside these libraries in `scripts/`. Lean is pinned to 4.34.1, with no
third-party Lean packages. Install that toolchain through elan and use Python 3.11 or later.
From `formal/zk-gas`, the complete local and CI validation command is:

```bash
bash scripts/gate.sh
```

To inspect individual stages:

```bash
python3 scripts/check.py
python3 -m unittest discover -s scripts/tests -v
lake build
mkdir -p .lake/audit
lake env lean -o .lake/audit/Audit.olean scripts/Audit.lean
LEAN_PATH="$PWD/.lake/audit" lake env lean scripts/AuditTests.lean
LEAN_PATH="$PWD/.lake/audit" lake env lean --run scripts/RunAudit.lean
for library in ZkGasModel ZkGasStatements ZkGasProofs ZkGasWitnesses ZkGasTraces; do
  lake env leanchecker "$library"
done
lake exe check-traces ../../testdata/zk_gas_vectors  # once traces/ exists
```

CI runs on drafts and watches the pinned specification, the package, the shared vector corpus
and the workflow.
