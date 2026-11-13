# Unzen zk gas metering model

This package is an executable Lean model of Unzen zk gas metering as alethia-reth implements it:
the gas each interpreter step uses, and how a block's charges are accounted. It has proved claims
about both, and a trace checker that replays the shared vector corpus through it. It pins the
specification [`zk_gas_spec.md`](../../packages/protocol/docs/zk_gas_spec.md) at revision
`43839f0c823e962fcba140085bcf593937339ce8` in [`spec-coverage.json`](spec-coverage.json);
the specification's `step_gas` definition refers to this model for the gas of a failing step.
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

  The model takes `usize` to be 64 bits, as on the hosts alethia-reth runs on, so
  `as_usize_or_fail!` rejects an offset or length of 2^64 or more and keeps the frame's gas
  (`usizeBound` in [`Step/Memory.lean`](ZkGasModel/Step/Memory.lean)); the specification states
  the same bound. A 32-bit build of revm, such as a riscv32 zkVM guest, rejects every value of
  2^32 or more there instead, so a step with a length in [2^32, 2^64) halts keeping its gas.
  Where the opcode next charges a word or data cost for that length, as KECCAK256 and LOG do, a
  64-bit build cannot pay it and spends all its gas. The corpus has 13 such steps: KECCAK256
  with length 2^32 (in `create.create.collision_nonce`, for example) and LOG0 to LOG3 with a
  larger data length (in `log.log0.size_above_cap_data_oog`, for example). Their zk gas differs
  on a 32-bit build, and neither the model nor the corpus is checked on one.

  Each step result names the branch that decided it: one per distinct sequence of revm checks
  and charges and its outcome. `allBranches` lists them all (see [Coverage gate](#coverage-gate)).

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
(a harness frame's to `meterTx`) to reproduce the vector's expected values. It takes a step model,
which gives each step's `gas_after`, outcome, branch and, for a step that opens a frame, the gas
it forwards to it, and runs `stepModel`, which is `stepOutcome` on Unzen. Every step must be
decided by the model: a step it cannot decide, such as one whose pre-state lacks a fact the model
reads, fails the check.

Every step must be metered (`charged` true). A charge's `zk` is its amount saturated at
2^64 - 1, as the clients record a refused charge whose product overflows a u64; the meter is
charged the full amount, which exceeds every limit a vector can set, so the charge is rejected
as the clients' checked multiplication rejects it. A harness run that calls a precompile
directly ends with `halt` exactly when the run failed, unless the meter rejected its charge.

For every step, the checker compares `spawn` (a step spawns exactly when its outcome is a new
frame) and `gas_after` with the model's; for a spawn step, `gas_after` is the gas left after the
gas it forwards, which alethia-reth records exactly. Unless the meter rejected the step's charge,
it checks the outcome against the event after the step, and the gas that event starts from:

- A step that continues is followed by a step at its depth whose `gas` is the step's
  `gas_after`.
- A step that ends a child frame is followed by a step exactly one depth up, and a step that ends
  the top frame by the end of the tx or frame, where a harness trace's `frame_end` has the status
  of its outcome (`success` for STOP, RETURN and SELFDESTRUCT, `revert` for REVERT, `halt` for
  the other halts).
- A step that opens a frame is followed by a step one deeper, a precompile run or a step at its
  depth, never by the end. The new frame's gas is the gas the model says the step forwards plus
  the 2,300 stipend of a CALL or CALLCODE with a non-zero value: the child's first step starts
  with it, and the precompile run is supplied it, at the address `stack[1]` names (revm runs a
  precompile by the call's target address, also when the target has an EIP-7702 delegation).
  When the new frame runs no step (an account without code, or a frame the handler refuses), the
  next step at its depth resumes with the spawn step's `gas_after` plus the new frame's gas. revm
  loses that gas only when the handler halts: for a CREATE or CREATE2 whose address collides or
  whose new account's balance would overflow, and for a CALL with a value that would overflow the
  target's balance. The trace does not show which case ran, so for those opcodes the checker
  also accepts the `gas_after` alone.

It also checks the gas each frame gets back, following revm-handler 43.0.2 `src/frame.rs`. When
a child frame that ran steps ends, the frame that opened it resumes with its spawn step's
`gas_after` plus what the child returns: the child's gas left when the child's last step
succeeds or reverts (a CALL child's includes a value transfer's stipend), and nothing when it
halts. A CREATE child that returns code first pays a code deposit of 200 gas per byte; code
above 24,576 bytes, a deposit it cannot pay or code starting with 0xEF makes it a halt. The trace
does not record the code's first byte, so a CREATE child that can pay its deposit may return
either the rest or nothing. After a precompile run that a spawn step opened, the caller resumes
with the spawn step's `gas_after` plus the precompile's `left`. So every step's `gas` is checked
except the first step of a tx or harness frame.

The checker stops at the first failure with the vector id, the event index and the reason, and
exits 1. Every vector needs a trace and every trace a vector, and a corpus without a `traces/`
directory fails. Then it runs the coverage gate. The gate script always runs `check-traces`.
Trace checking is executable checking, not part of the proved claims below.

### Pre-state trust boundary

The checker trusts each step's pre-state as the trace records it: the opcode, program counter,
depth, static flag, stack length, the top of the stack, the memory size, the gas of a tx's or
harness frame's first step and the `supplied` gas of a precompile run that is its tx's or frame's
only event (every other step's gas and run's `supplied` are checked, see above), and the `facts`
(whether an account or slot is warm, whether an account is empty, whether a CALL target's
EIP-7702 delegate is warm or the target has no delegation (`delegate_warm` null), an SSTORE's
original and current values, whether a JUMP target is valid, the return data size, a
SELFDESTRUCT's own balance). The client's trace exporter reports them; the model computes the
step's gas and outcome from them and cannot tell whether they are true. Two checks outside this
package guard them:

- taiko-geth exports its own trace of every vector and compares it with the committed
  alethia-reth trace event by event, pre-state included; a difference in a step's pre-state is
  reported as a setup divergence. Two independently written exporters must therefore report the
  same pre-state for every step of the corpus, apart from the normalized steps described there
  (an empty-initcode frame's implicit STOP, which only the committed trace has and which carries
  no zk gas).
- Reading the facts must not change what is metered. In each client, a traced run of a vector
  must give the vector's expected values, as an untraced run does. alethia-reth takes the charges
  from its production execution path and the facts from a second run on its inspector path, and
  requires both runs to report exactly the same charges.

A fact that both exporters report wrongly in the same way would pass both checks. The corpus
README gives the rules for reading [facts](../../testdata/zk_gas_vectors/README.md#facts) and
for [comparing client traces](../../testdata/zk_gas_vectors/README.md#comparing-client-traces).

### Coverage gate

`allBranches` (`ZkGasModel/Step/Basic.lean`) lists every branch of the step model, which the
headline `BranchesComplete` proves. `check-traces` prints how many corpus steps each branch
decided (`check-traces: branch <name>: <n> steps`) and a summary of the form
`<n> vectors, <n> events, <n> steps checked by the model; <n> of <n> branches hit, <n> unreachable`
(the corpus README's [coverage statistics](../../testdata/zk_gas_vectors/README.md#coverage-statistics)
give the current corpus size). It fails, listing them, when a branch decided no step and `unreachableBranches` does not list
it, when a listed branch decided a step, or when a step reports a branch outside `allBranches`.

`unreachableBranches` (`ZkGasModel/Step.lean`) lists the branches no Unzen execution can reach,
each with the reason, for example a branch whose condition an earlier check always rules out. The
gate exempts them from the coverage requirement and fails if a corpus step does reach one, so a
wrong reason shows up. The list is empty: every branch is reachable and reached by corpus steps.
A reachable branch with no corpus step needs a new vector written by alethia-reth, not an entry
in the list.

## Claims to review

Start with [`ZkGasStatements/Claims.lean`](ZkGasStatements/Claims.lean), then
[`ZkGasProofs/Claims.lean`](ZkGasProofs/Claims.lean) (metering) and
[`ZkGasProofs/Step.lean`](ZkGasProofs/Step.lean) (the step model). The seven headline theorems
have exactly the corresponding named proposition as their type; the audit rejects added premises
or a replacement conclusion at that boundary.

| Statement                 | Theorem in `TaikoSpec.ZkGas.Proofs` | Proof                                                | What it says                                                                                                                                                            |
| ------------------------- | ----------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BlockWithinLimit`        | `block_within_limit`                | [`ZkGasProofs/Claims.lean`](ZkGasProofs/Claims.lean) | A block's total never exceeds the schedule's block limit, whatever its transactions charge.                                                                             |
| `AbortContributesNothing` | `abort_contributes_nothing`         | [`ZkGasProofs/Claims.lean`](ZkGasProofs/Claims.lean) | After committed transactions, a transaction whose charges exceed what the block has left ends the block: the total stays the same and later transactions get no result. |
| `TotalIsSum`              | `total_is_sum`                      | [`ZkGasProofs/Claims.lean`](ZkGasProofs/Claims.lean) | A committed transaction's total is the sum of its charges, intrinsic charge included, and the block total is the sum of the committed totals.                           |
| `FitCommits`              | `fit_commits`                       | [`ZkGasProofs/Claims.lean`](ZkGasProofs/Claims.lean) | After committed transactions, a transaction whose charges fit what the block has left commits with their sum, which the block total gains.                              |
| `BranchesComplete`        | `branches_complete`                 | [`ZkGasProofs/Step.lean`](ZkGasProofs/Step.lean)     | `allBranches` lists every branch of the step model, so the coverage gate leaves none out.                                                                               |
| `StepGasMonotone`         | `step_gas_monotone`                 | [`ZkGasProofs/Step.lean`](ZkGasProofs/Step.lean)     | In the step model on Unzen, no step leaves its frame more gas than it had, so the gas a step uses is never negative.                                                    |
| `SpawnOnlyForSpawnOps`    | `spawn_only_for_spawn_ops`          | [`ZkGasProofs/Step.lean`](ZkGasProofs/Step.lean)     | In the step model on Unzen, only an opcode with a spawn estimate (the CALL and CREATE families) opens a new frame.                                                      |

Statement names are under `TaikoSpec.ZkGas.Statements`. The metering claims range over every
schedule, so they hold for `unzen` in particular; `FitCommits` rules out a meter that would
satisfy the other three by aborting transactions that fit. The step claims are about
`stepOutcome` on Unzen, which the traces check against alethia-reth.

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
alethia-reth files must be those of the commit `testdata/zk_gas_vectors/reference.json` names as
the one that wrote the vectors (the generator compares them with that commit through git) and the
header names it. The sources are outside this repository, so CI cannot regenerate the file. Run the generator locally
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

Outside the claims' scope: how each charge is computed (the step model's results are checked
against the traces, not proved equal to a client's); EVM execution and discarding an aborted
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

## Witnesses and the Lean trust boundary

[`ZkGasWitnesses/Tests.lean`](ZkGasWitnesses/Tests.lean) holds executable `#guard` regressions:
table spot checks against the specification and revm (ADD, PUSH1, point_evaluation, an unlisted
precompile, ADD and CREATE static gas), meter cases at and just past the block limit, and the
trace parser and checker on fixture traces: canonical hex up to 2^256 - 1, malformed records and
`facts`, the two smoke vectors' traces, and each kind of failure (event order, step, precompile
and intrinsic charges, meter verdicts, an aborted tx without a rejected charge, totals against
the expected values, model disagreement, a spawn step's `gas_after`, a precompile that leaves
more than it was supplied), the two shapes with no step: a tx skipped before its intrinsic
charge (a lone skipped `tx_end`) and a harness call to an account without code (`frame_end`
alone), and a hand-made step whose pre-state lacks the fact the model reads, which fails the
check. Guards that flip one modeled step's outcome check that the checker rejects an outcome the
next event contradicts, including a child frame's last step that ends at the wrong depth or
returns the wrong gas (committed traces of a returned stipend, a halt, a CREATE's implicit STOP
and a code deposit) and a precompile that leaves the wrong gas, and guards that change one gas
value a step hands on (a continuing step's next step, a child frame's first step, a precompile
run's `supplied` and address, the resume after a frame that runs no step) check that the checker
rejects a broken hand-off. The step model has at least one
guard per branch: a step line copied verbatim from a committed reth trace, which expects that
line's `gas_after` (for a spawn step, the gas left after the gas it forwards). Further guards
cover a missing fact or stack item, every opcode being modeled and the undefined ones being
exactly those revm does not define, checks whose order the traces cannot show (the static
context before the pops, SSTORE's pops before its sentry, CALL's static-frame value check before
its memory operands, the CALL family's input range before its output range and both before the
transfer cost), each EIP-7702 delegate stage at its gas boundaries, and the coverage gate,
including that every branch name is its constructor's and no two branches share one. They run
during compilation and are **not kernel proofs**.

The full gate combines independent checks:

1. Python lexes the accepted source subset, ignoring nested comments and escaped strings, and
   rejects proof escapes, metaprogramming commands and unreviewed compiler options. `#guard` is
   allowed only in `ZkGasWitnesses/Tests.lean`. Model and Statements forbid source
   theorem/example commands, and no library may declare a `notation`, `infix`, `infixl`,
   `infixr`, `prefix` or `postfix`. Every library may import Lean core's `Init` and `Std`
   modules; the only other `Lean` import allowed is `Lean.Data.Json`, and only `ZkGasTraces.Json`
   and `ZkGasTraces.Check` may import it and name its types. The statement files
   (`ZkGasStatements.lean` and `ZkGasStatements/Claims.lean`) are pinned by their SHA-256 hashes
   in `scripts/check.py`, so editing a statement fails the gate until it is reviewed and
   repinned.
2. The import graph enforces downward library dependencies, existing modules and reachability
   from every library root.
3. The specification gate checks the exact source path, revision, hash, headline mappings,
   existing section headings and nonempty drift/exclusion explanations.
4. The separately compiled [`scripts/Audit.lean`](scripts/Audit.lean) inspects all five
   libraries. Every owned declaration may depend only on `propext`, `Classical.choice` and
   `Quot.sound`. It checks seven exact headline types and named claim dependencies, and rejects
   proof-valued declarations in Model and Statements. [`scripts/AuditTests.lean`](scripts/AuditTests.lean)
   checks that it rejects weakened or missing headlines, extra axioms and erased dependencies.
5. `leanchecker` replays all five libraries in Lean's kernel.

Mechanical limits: the source gate is a bounded lexer, not a complete Lean parser or adversarial
sandbox. Named dependency anchors catch accidental erasure but not arbitrary weakening of
statement bodies; review proposition meanings directly (the statement hash pin makes every such
edit visible as a repin). Neither these checks nor kernel replay
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
lake exe check-traces ../../testdata/zk_gas_vectors  # traces, then the coverage gate
```

In CI, [`.github/workflows/formal-zk-gas--test.yml`](../../.github/workflows/formal-zk-gas--test.yml)
runs `python3 scripts/check.py` before building, then `bash scripts/gate.sh`. It runs on pull
requests (drafts included) and pushes to `main` that change this package, the shared vector
corpus, the pinned specification or the workflow. The corpus's own format checks
(`testdata/zk_gas_vectors/check.py`) run in `.github/workflows/repo--zk-gas-vectors.yml`, and the
clients run the vectors in their own CI against a pinned taiko-mono commit (see the
[corpus README](../../testdata/zk_gas_vectors/README.md#continuous-integration)).
