# Etna proof foundation

This package pins Lean, Mathlib and extraction tools and checks 261 declarations:
FI and committee specification proofs, 21 exact extracted Rust function refinements,
Landing specification proofs for the V8 statement and its L2 reward record, a model of
the L2 fee vault's reward claim, and conditional joint-trace/landing/reward composition.
`coverage.json` records exact theorem/type/source digests, named premises and tests;
`schemas/coverage-policy.json` fixes the mandatory obligations independently of the
manifests. Wrapper conformance and scalar-function refinement remain separate levels.
Real guest soundness, execution header/time rules and Solidity bytecode refinement
are mandatory pending ledger entries.
Current upstream dependencies are client `6f91f50c6185213ac512a4a46683767c75d8d831`
(#22280) and protocol `cf4095818050bd670d7d6b8b9f742d55c01e49f0` (#22286). The client's
lander fixtures were generated at protocol `2a4bfa747edcafae96c15b58159e31eea0ebe78a`,
whose contracts, `foundry.toml` and lockfile are byte-identical to the tested pin; the
coverage gate checks that identity before accepting the fixtures. The client pin names
the upstream base; this verification branch adds the production core, adapter wiring
and FI proofs. Exact current source/Cargo/generated digests are recorded in
`Etna/Refinement/Rust/provenance.json`; `reports/v8-sync.json` records this refresh's
pins, removed and new obligations, conformance counts and mutants. `reports/pair-refresh.json`
is the earlier pair's merge-overlay record. Original
source baselines remain historical; the original contract inventory is retained
in Git at `44afbca320dfd9f23fdb6ea46ad641cb1b51a01e` and identified by digest
in the pair-refresh report.

Run from this directory:

```sh
lake update
lake build
python3 -m unittest discover -s tests -v
python3 scripts/audit_proofs.py
lake env lean Audit.lean
```

Commit `lake-manifest.json` changes only as reviewed toolchain updates. The auditor
rebuilds and compares each theorem’s raw declared type with its independently elaborated manifest type (without applying or specializing the theorem), requires theorem
rather than axiom declarations, and rejects transitive axioms other than `propext`,
`Classical.choice` and `Quot.sound`. Its real-Lean tests poison imports, declaration
existence, the complete type, `sorry`, and an extra custom axiom. Axiom checks cannot
detect a vacuous proposition or an invalid explicit premise: those require review.
Use repeated `--manifest path` arguments to audit a selected paired source scope.

## Extraction tool health

Clone Aeneas and Charon to scratch, check out the exact revisions in
`tools.lock.json`, and initialize Charon's submodules. Build Charon with its
`nightly-2026-09-17` toolchain and Aeneas using its documented OCaml 5 environment.
The source compatibility check verifies upstream `charon-pin`, `rust-toolchain`,
backend `lean-toolchain`, and all resolved Lake revisions.

```sh
AENEAS_ROOT=/path/to/aeneas CHARON_ROOT=/path/to/charon \
  scripts/toolchain_smoke.sh
```

The smoke copies the **unchanged upstream** `tests/src/bool-cmp.rs` to ignored
scratch, runs Charon and Aeneas, and compiles the generated Lean. Missing binaries
and failed generation/compilation are errors. A successful smoke establishes tool
health only; production refinement stays pending until real production extraction
and its refinement theorems pass. No handwritten function substitutes generated code.

## Actual production Rust extraction

`packages/taiko-client-rs/crates/etna-consensus-core` is the dependency-free, no_std,
allocation-free authority used by both ABCI and lander. Its scalar rules cover
forced inclusion presence/classification/resolution/cursor advancement, checked
schedule arithmetic, committee mutation plans, and overflow-safe strict quorum.
ABCI retains serialized schedule fields, rich skip bytes/cache equality, MPT and
canonical decoding; engine completion and header checks stay in the adapter.
Committee equality, validator update unions and signature checks remain there too.

Regenerate directly from that actual production crate (no copied extraction helper):

```sh
AENEAS_ROOT=/path/to/pinned/aeneas CHARON_ROOT=/path/to/pinned/charon \
AENEAS_EXE=/path/to/built/aeneas \
  python3 scripts/extract_rust_core.py --compile
lake build
python3 scripts/audit_proofs.py
```

`Etna/Refinement/Rust/EtnaConsensusCore.lean` is generated without hand edits or
source normalization and imported by the root package. `provenance.json` records
all 21 Rust function roots and generated names, source digests, tool pins and the
adapter fact boundary. Aeneas translates 24 transparent bodies (21 functions plus three
constant initializers: the forced-inclusion byte cap, `UINT48_MAX` and the 4096
committee-size cap) and ten opaque
LLBC standard-library declarations resolved by its pinned backend models; there
are zero unresolved generated axioms or opaque stubs. The extractor rejects such
placeholders, missing roots and tool failures. Original fixture and captured
behavior corpus provenance is in `reports/rust-behavior-baseline.json`.

Twenty-one exact total-output refinement theorems connect the generated functions to
the scalar specification. This covers those named production functions only; it does
not upgrade the async wrapper, authentication, whole committee history or guest to
implementation correctness.

## Solidity feasibility

`reports/solidity-inventory.json` inventories the actual Osaka, solc 0.8.30,
optimizer-200, non-via-IR EtnaInbox artifact at the pinned contract source revision.
It includes the runtime SHA256, every instruction PC, CALL/DELEGATECALL/STATICCALL
sites, compiler storage layout, settings and deployment immutable references.
PUSH data and CBOR metadata are excluded from instruction counts. This is the
**whole runtime containing land**, without claiming land-only CFG reachability.
Regenerate from an actual Foundry artifact. The generator validates raw solc compiler/settings metadata, all source Keccak hashes (including dependencies), and tracked source blobs at the immutable revision. It derives capability gaps from the pinned tool sources, rather than adding them to the report by hand:

```sh
python3 scripts/solidity_inventory.py /path/to/EtnaInbox.json \
  --source-checkout /path/to/exact/taiko-mono/packages/protocol \
  --source-revision cf4095818050bd670d7d6b8b9f742d55c01e49f0 \
  --evmyul-root /path/to/pinned/EVMYulLean --clear-root /path/to/pinned/Clear \
  --output reports/solidity-inventory.json
```

The pinned EVMYulLean has opcode cases for MCOPY, TLOAD/TSTORE and BLOBHASH; this is
not proof of complete Osaka semantics. Its README documents Yul gas and external
code-operation gaps. Clear's pinned `Clear/PrimOps.lean:92-102` marks external calls
and logs as dummy implementations, and its primitives lack the newer opcode names.
Their Lean versions (4.22.0 and 4.9.1) are incompatible with this package's 4.35 rc4
olean files. No Solidity proof level is granted, and no compilation setting or opcode
was changed to accommodate either tool.

External authentication, hash/encoding, completed singleton execution, consensus,
rollback/frame and real guest facts are explicit parameterized interfaces in
`Etna/Common/Assumptions.lean`. Constructing these interfaces is not evidence that
the facts hold; protocol theorems must accept and use the precise required facts.

## Forced inclusion verification

`Etna/FI/Model.lean` and `Proofs.lean` cover FI-01 through FI-09. The staged model checks witness/index before authenticated storage and preimage checks. Its evidence binds the committed anchor root/time/tail, Inbox and ordered slots, the actual execution-list head, and the exact singleton parent/attributes/anchor/transaction request. Four complete authenticated examples in `Examples.lean` establish satisfiability. Finite valid traces carry those intermediate validation and execution results. Successful evaluation/resolution derives consumed-index equality and the authenticated-tail bound; the bound is not a supplied trace field. Induction then proves cursor conservation and bounds.

`Etna/Refinement/Rust/Forced.lean` proves exact total output equalities for all six **actual generated production functions**: pending-entry, preimage, due, classify, resolve and cursor advance. Each result is outer `Aeneas.Std.Result.ok`, preserving Rust's inner `Ok`/`Err` and payloads, including maximum-u64 overflow. These are total proofs, with no partial-WP divergence escape. The pinned compiler/Charon/Aeneas translation and Aeneas standard models remain the extraction trust boundary. No byte parser, MPT, Keccak, async Engine, ABCI handler, storage or Solidity implementation proof is claimed.

`manifests/client.json` records full theorem types, explicit assumptions and source boundaries. `scripts/audit_proofs.py` verifies the actual theorem type, transitive axioms, generated-function equality shape, source symbol and source/generated/toolchain provenance. The pinned producer schema and exact mandatory tool/source/Cargo/generated key sets are required before checking values, so empty or truncated maps cannot bypass checks. Only `propext`, `Classical.choice` and `Quot.sound` are permitted. The manifest includes the accepted FI and committee obligations; whole-application and external bridge obligations remain distinct.

Run `python3 scripts/fi_conformance.py` to compare the fixed 94-case JSONL corpus with the independent Lean model and actual Rust reducer source. The corpus preserves the original 60 authenticated-classifier goldens and adds witness, boundary, resolution and overflow cases. Actual Process/Finalize/Commit/reopen, cancellation, missing history, wrong headers and stale checked-cache fields are covered separately by Rust adapter tests; this is conformance evidence, not formal refinement.

With `AENEAS_ROOT` and `CHARON_ROOT` set to the pinned built tools (and optional `AENEAS_EXE`/`CARGO_TARGET_DIR` overrides), `python3 scripts/fi_mutations.py` temporarily mutates real production source, requires semantic test failures, regenerates the two scalar mutants and requires their Lean refinements to fail. It restores original source/generated/provenance bytes in `finally`; run it exclusively, without another build or editor touching those files. The three async mutants cover error-as-empty and removal of hot-only or cold-only consumption.

Exact historical admission bytes require trace-local hash separation; no global Keccak injectivity is assumed. FI-08 compares successful hot/cold results from equal canonical inputs and checked intermediate facts, with explicit successful durable-write/reopen laws. Production cache comparisons use a digest and selected fresh fields; arbitrary context changes are not claimed to miss. FI-09 preserves behavior only while both timestamps remain due. The finite example codec is a satisfiability witness, not a cryptographic implementation.

Format the standalone Rust harness with `rustfmt +nightly-2025-09-27 --config-path adapters/rustfmt.toml adapters/fi.rs`. Its `skip_children = true` setting prevents traversal into the pinned production source referenced by `#[path]`; workspace formatting remains `just fmt`.

`reports/fi-coverage.json` maps every requested FI scenario to57 concrete test references in12 behavior groups, including the existing forced/Engine/Process/calldata/lander tests and the two focused Finalize additions. These are conformance evidence; tests are reused when already adequate instead of duplicating them to touch each named file.

### Committee schedule, authority and replay

`Etna/Committee` proves COM-01 through COM-07 on an independent checked-arithmetic and authenticated-history specification. `Etna/Refinement/Rust/Committee.lean` proves exact outer `Result.ok` output equality for all typed inputs of the eleven actual generated Schedule functions (including checked
validation, anchor progress and the publish urgency hint), the three quorum/configuration
predicates, and `transition_committee`. The quorum theorem covers all `u128` inputs, including values for which `3*signed` or `2*total` would overflow a machine word. No partial correctness/divergence escape is used.

The checked model preserves intermediate `Option` failures. With `M=u64::MAX`, `L=3`, `N=M/3`, `h_last(N-1)` is `None` even though its mathematical last height is `M`; the intermediate next `H` overflows. At `M-1`, `next_switch_target` returns `N` while `switch_target` is `None`. Epoch zero has its separate no-derivation rule, and the pure core's height-zero behavior is distinguished from wrapper assertions.

The history model binds snapshot verification to the committed parent's state root and cutoff through `Authentication.sound`, uses deterministic `derive(snapshot)` and full record/member equality, rejects empty derivations/conflicts/missing authority, and checks certificate chain/height/block identity and distinct signer keys. Only valid block votes add power; nil/absent votes add zero. `Crypto.sound` is the named signature boundary. A concrete eight-block authenticated history crosses D/S/S+1/H and demonstrates that these premises are satisfiable. Replay concatenation is proved by induction for arbitrary cuts; successful online and reopened replay derive equal final committee states and ordered updates.

These are distinct proof levels. The full history `step` is a specification, while the fifteen named committee/quorum/configuration scalar functions are refined to actual extraction. The history's update record pairs carry complete outgoing/incoming inputs to the adapter's deterministic validator-update union. MPT correctness, full election sorting, ZIP215/canonical signed-byte verification (including round/time/part-set encoding), validator-power provenance, update serialization, Comet's `h+2` application (`CometAdapter.appliesAfterTwo`), and durable Commit/reopen remain explicit adapter boundaries. Native tests cover those behaviors separately; no whole asynchronous application or cold-Finalize availability proof is claimed. The exact behavior-to-test index is `reports/committee-coverage.json`.

Run `python3 scripts/committee_conformance.py` for the fixed JSONL corpus, then `python3 scripts/audit_proofs.py` for exact theorem-type, transitive-axiom and generated-source/provenance checks. `scripts/committee_mutations.py` temporarily changes real sources and must run exclusively; it checks early/late activation, inclusive quorum, candidate-anchor substitution and dropped pending insertion, restores every byte in `finally`, and records digests. The three scalar mutants are re-extracted through the pinned tools and must fail both fixed corpus and generated-function refinement.

The owner-configuration gaps reported earlier are now closed in the client and proved
here. `validate` keeps the first transition inside the protocol's uint48 height and
anchor ranges (with checked arithmetic, so `E=u64::MAX` and `L=u64::MAX` are rejected
rather than panicking), and `ChainParams::validate` requires `d_max > margin_v`, so the
unsettled cap is at least one and the first block cannot fail back-pressure at
checkpoint zero. The V7 epoch-length cap (`L <= 429496`, which bounded packed proposer
scores in the removed L1 reward pool) and the epoch-end batch cut are gone with that
pool, and the committee-size cap is now 4096, the registry's leaf capacity. Protocol
uint48 anchors and Comet int64 heights still restrict the practical domain beyond the
first transition; see [configuration evidence](reports/configuration-boundaries.md).

### Landing operation and actual contract conformance

`Etna/Landing` models V8 `land(input, proof)` at protocol `cf4095818`. `LandInput` has
eight ABI fields; V8 adds `l2RewardRecipient` (checked nonzero right after the FI fee
recipient) and `baseFeeAmount`. Caller is recorded in the batch event and is not a
statement word. The staged World includes Inbox identity/configuration/checkpoint, queue
head/tail and retained uint64 fee entries, SignalService checkpoint effects, the
`rewardCommitments` ledger (slot 283), protocol logs, Inbox-issued transfer instructions
and the transient guard. A persistent journal retains tentative writes and unwinds them
under the named generic EVM journal law. It excludes sender nonce/gas and unrelated
recipient account effects. The callback frame also protects the reward ledger.

The exact twenty-word encoder returns 640 bytes and has a proved decoder/left inverse;
all bounded uint256 encodings are injective, and addresses have 12 zero prefix bytes.
The domain is the length-checked ASCII tag `TAIKO_ETNA_LAND_V8`. Ordered fixed-width
blob concatenation is injective before hashing. Actual Keccak and trace-local
collision separation are distinct assumptions; global Keccak injectivity is never
assumed.

After the verifier returns, `_recordReward` builds the receipt from the parent read
before landing, the stored generation, both chain ids and the executing proxy, plus the
proven endpoint, recipient and amount. It reverts `RewardAlreadyRecorded` on an occupied
slot, writes `commitment(receipt)` at `batchId(receipt)` and emits its event, all before
the FI fee transfer. `Etna/Landing/Reward.lean` encodes both `LibEtnaRewards` preimages
and proves their injectivity. The proofs show three things. First, every receipt field
is a word of the verified statement. Second, a successful landing writes exactly one
commitment (`reward_recorded_exact`). Third, from an empty ledger the occupied-slot revert
is unreachable along any sequence of successful landings: parent heights strictly increase,
so batch ids differ under trace-local separation (`reward_slot_fresh`). Earlier slots
are never overwritten.

`Etna/Landing/Claim.lean` models `L2FeeVault.claim`. A successful claim pays exactly
the receipt's recipient and amount once and marks its batch id. A second claim for the
same id reverts. Against any ledger reached by successful landings, a claim pays a
recorded receipt: same id, recipient and amount. The account/storage proof against the
EIP-4788 anchored root is the named `ProofSound` boundary; the vault itself has no
Lean-compared harness here.

```sh
lake build
python3 scripts/audit_proofs.py
# Read-only comparison with retained actual observations (also runs the Rust leg):
python3 scripts/landing_conformance.py \
  --observations reports/landing-solidity-observations.jsonl
# Required Solidity tester only; reversible actual-protocol assembly:
python3 scripts/landing_conformance.py \
  --protocol /path/to/pinned/taiko-mono/packages/protocol --run-solidity \
  --observations /tmp/landing-observations.jsonl
```

`corpus/landing.jsonl` keeps the 56 earlier cases and adds nine reward cases. The
added cases cover a zero reward recipient and its check order, an occupied slot, the
verifier preceding that check, zero and maximum amounts, and a payment failure after
the reward write. All 65 rows agree on every field between Lean, the actual Inbox proxy
and, for the 36 rows that reach statement hashing, the production Rust preimage/digest.
The reward ledger is checked three ways: the Lean receipt preimages, an independent
Python preimage and the actual event id and slot value. Both Keccak values come from
`cast`. The cut harness lands four partitions of one six-block trace with per-block
credits of h gwei. Recorded rewards total 21 gwei for every partition, every receipt id
is distinct, and earlier slots survive later landings. This is **spec-proved plus actual
Solidity conformance-tested**; Solidity bytecode correctness remains pending.

The conformance gate requires nonempty, unique, identical case-ID sets in the corpus,
Lean output and Solidity output. Preimage groups must be complete and present exactly
when the model reaches statement hashing. Before staging, the runner checks pinned
protocol/helper/fixture/config and root manifest bytes, file modes and Git index, and
rejects unexpected source/config inputs, compiler environment overrides and staging
symlinks. Run `python3 -m unittest discover -s tests -p test_landing_conformance.py`
for the 40 negative/completeness, reward-gate and temporary-Git regressions.

## Joint traces, actual cuts and coverage gate

`Etna/Integration/Composition.lean` couples actual FI and committee successful steps
on the same authenticated blocks. It derives consumed count, exact public height and
head, full committee state/update history, and fee composition across any finite
sequence of valid successful landings. `GuestSoundness` requires the concrete
`ValidBatch` relation; `DummyProofProvider` supplies no such instance. Canonical
payload/blob decoding, seed/genesis/config/anchor authentication, cryptographic
primitives/local binding, and EVM/journal/callback semantics remain explicit boundaries.
`Examples.lean` supplies a coherent nonempty two-call witness and rejects a forged
output head. These finite interpretations establish satisfiability, not real crypto.

V8 adds a reward leg. `ValidBatch` now also requires the base-fee word to be the checked
uint256 sum of the EL treasury credits of the batch's blocks (base fee times charged
gas). The authenticated `treasuryCredit` view is an execution boundary that assumes the
sharing byte is zero and there is no anchor exemption. Any finite sequence of landed
cuts then records receipts summing exactly to the credits of every landed block
(`landed_cuts_rewards`). Combined with the claim model, any sequence of successful
claims of recorded receipts pays at most those credits (`claims_bounded_by_credits`).
So the fee vault cannot be asked for more than it was credited. The examples land two
batches (5 + 3 credited), claim both once, reject the replay and a forged base-fee word,
and satisfy the bound.

The durable comparison invokes actual Rust `lander::statement::preimage/hash` and
FI `advance_cursor`, the executable Lean models, and the tester-owned actual Inbox
proxy harness. It requires every one of 65 cases, all 36 reached 640-byte preimages,
and four sampled cut plans with 12 intervals. Cut samples exercise real admissions,
including empty payment intervals, separately from the arbitrary-cut theorem.

```sh
# Only the repository-required Solidity tester runs --run-solidity interactively.
CARGO_TARGET_DIR=/path/to/reusable/target python3 scripts/landing_conformance.py \
  --protocol /path/to/paired/packages/protocol --run-solidity \
  --observations /tmp/etna-observations.jsonl --report reports/integration-conformance.json
# Read-only actual source/ABI/layout/bytecode provenance plus full kernel audit.
python3 scripts/check_coverage.py --protocol /path/to/paired/packages/protocol
```

The coverage gate checks current source bytes and actual compiled artifacts against
client artifact provenance at the paired protocol revision. It rejects missing IDs,
changed mandatory declarations/premises/bridge levels, missing or stale generated
sources, removed pending boundaries, and type/axiom drift. `--static-only` explicitly
omits the kernel audit and is not a complete release gate. Source/artifact changes
require the existing artifact and core generators, each twice for determinism; never
hand-edit generated output.
The upstream client pin, paired protocol pin and tested verification overlay/digests
are retained separately.

## Paired PR, nightly and release checks

The first-phase implementation now includes `.github/workflows/etna--formal.yml` and self-contained bootstrap, pair ownership/provenance, seeded conformance, nightly mutation and release-boundary scripts. The stable `Etna formal gate` also appears for Draft and unrelated PRs. See [CI acceptance and rollout](reports/ci-acceptance.md) for exact trigger simulations, proof-review requirements, runner budgets, current Linux limitations and post-default-branch ruleset adoption.

With the pinned toolchain/dependencies installed and an immutable protocol checkout:

```sh
python3 formal/etna/scripts/run_conformance.py --scope paired --seed 20261015 \
  --protocol /path/to/protocol-checkout/packages/protocol --output /fresh/run-directory
```

This invokes real Lean, Rust 1.95 and Foundry adapters. Local protocol test execution uses the required repository Solidity tester; CI is ordinary deterministic automation. Fresh extraction uses `check_provenance.py --output /fresh/extraction-directory` with the source-built pinned tools; output must match committed Lean and provenance exactly. No historical report counts as a new run. The hosted Linux tool-build/extraction acceptance is still pending; local/static checks do not claim that run passed.

Solidity bytecode refinement remains pending. [Concrete EVM feasibility](reports/solidity-refinement-feasibility.md) preserves immutable source/line evidence and explicit no-build/no-proof-attempt qualification. [Configuration findings](reports/configuration-boundaries.md) record the now-closed genesis gaps and the remaining practical domain. Funds release remains blocked by genuine guest, clock/header rules and exact bytecode/proxy refinement obligations.

Pairing is fail-closed after adoption: only the declared stacked PR at the immutable client base may use the premerge exception, and its own protocol/compiler/dependency projection must remain unchanged. Main, scheduled, release, dispatched and other-base PR runs require exact event protocol input equality with the tested protocol pin, including squash merges. See [event ownership and adoption order](reports/ci-acceptance.md#event-protocol-ownership-and-adoption-order); a changed protocol requires a reviewed pin/artifact update rather than green verification of an older dependency.
