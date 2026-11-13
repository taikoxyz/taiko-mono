# Unzen zk gas metering model

This package is an executable Lean model of Unzen zk gas metering as alethia-reth implements it,
with proved claims about how one block's charges are accounted. It pins the specification
[`zk_gas_spec.md`](../../packages/protocol/docs/zk_gas_spec.md) at revision
`aef6a3e4b954cc84cdff3d2434a1fe060a80bcd3` in [`spec-coverage.json`](spec-coverage.json).
The theorems concern this model; they do not establish equivalence of production clients.

## Scope

The model has two parts:

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

How a charge's amount is computed from an opcode's step gas, a spawn estimate or a precompile's
gas use is not modeled yet. [`ZkGasModel/Pre.lean`](ZkGasModel/Pre.lean) defines `Pre`, the
interpreter state a step model will read: the opcode, depth, gas, the top of the stack, the memory
size and the state facts the opcode's gas depends on.

## Trace checker

`lake exe check-traces <corpus-dir> [--allow-unmodeled]` checks every vector's trace,
`traces/<id>.jsonl` in the corpus (format: "Trace schema v1" in
[`testdata/zk_gas_vectors/README.md`](../../testdata/zk_gas_vectors/README.md#trace-schema-v1)),
against the model and the vector's expected values. [`ZkGasTraces/Json.lean`](ZkGasTraces/Json.lean)
parses the events and rejects anything outside the schema;
[`ZkGasTraces/Check.lean`](ZkGasTraces/Check.lean) checks the event order, each step's and
precompile's charge, each charge's meter verdict, and feeds every tx's charges to `meterBlock`
(a harness frame's to `meterTx`) to reproduce the vector's expected values. It takes a step model
`Pre → Except String (Option (gas_after × spawn × branch))`; the model checks `gas_after` and
`spawn` of every step it covers. No step is modeled yet, so `--allow-unmodeled` lets the
uncovered steps pass; without it, an uncovered step fails. The checker stops at the first
failure with the vector id, the event index and the reason, and exits 1. Every vector needs a
trace and every trace a vector. The gate runs it with `--allow-unmodeled` once the corpus has a
`traces/` directory and skips it before then. Trace checking is not part of the evidence below.

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

Outside scope: how each charge is computed; EVM execution and discarding an aborted
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
and intrinsic charges, meter verdicts, totals against the expected values, model disagreement),
and the two shapes with no step: a tx skipped before its intrinsic charge (a lone skipped
`tx_end`) and a harness call to an account without code (`frame_end` alone). They run during
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
lake exe check-traces ../../testdata/zk_gas_vectors --allow-unmodeled  # once traces/ exists
```

CI runs on drafts and watches the pinned specification, the package, the shared vector corpus
and the workflow.
