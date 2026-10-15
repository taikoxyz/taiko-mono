# Etna proof foundation

This package fixes Lean, Mathlib and extraction tool revisions for the Etna protocol
models. `manifests/core.json` currently covers the two common arithmetic lemmas only.
It does **not** establish FI, committee, landing, Rust implementation, or Solidity
implementation correctness. Each future theorem manifest records its full Lean type,
explicit assumptions, bridge level, production symbols and conformance tests.

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
all 17 Rust function roots and generated names, source digests, tool pins and the
adapter fact boundary. Aeneas translates 18 transparent bodies (17 functions plus the byte-cap constant
initializer) and eight opaque
LLBC standard-library declarations resolved by its pinned backend models; there
are zero unresolved generated axioms or opaque stubs. The extractor rejects such
placeholders, missing roots and tool failures. Original fixture and captured
behavior corpus provenance is in `reports/rust-behavior-baseline.json`.

Generation and compilation establish a usable extracted implementation model.
**Rust refinement theorems remain pending**; no FI or committee implementation
correctness claim follows from extraction or tests alone.

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
  --source-revision 41241d5e6440c2ab244ccfdf572d1af8016f70c6 \
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

`manifests/client.json` records full theorem types, explicit assumptions and source boundaries. `scripts/audit_proofs.py` verifies the actual theorem type, transitive axioms, generated-function equality shape, source symbol and source/generated/toolchain provenance. The pinned producer schema and exact mandatory tool/source/Cargo/generated key sets are required before checking values, so empty or truncated maps cannot bypass checks. Only `propext`, `Classical.choice` and `Quot.sound` are permitted. The file is additive: committee obligations remain pending.

Run `python3 scripts/fi_conformance.py` to compare the fixed 94-case JSONL corpus with the independent Lean model and actual Rust reducer source. The corpus preserves the original 60 authenticated-classifier goldens and adds witness, boundary, resolution and overflow cases. Actual Process/Finalize/Commit/reopen, cancellation, missing history, wrong headers and stale checked-cache fields are covered separately by Rust adapter tests; this is conformance evidence, not formal refinement.

With `AENEAS_ROOT` and `CHARON_ROOT` set to the pinned built tools (and optional `AENEAS_EXE`/`CARGO_TARGET_DIR` overrides), `python3 scripts/fi_mutations.py` temporarily mutates real production source, requires semantic test failures, regenerates the two scalar mutants and requires their Lean refinements to fail. It restores original source/generated/provenance bytes in `finally`; run it exclusively, without another build or editor touching those files. The three async mutants cover error-as-empty and removal of hot-only or cold-only consumption.

Exact historical admission bytes require trace-local hash separation; no global Keccak injectivity is assumed. FI-08 compares successful hot/cold results from equal canonical inputs and checked intermediate facts, with explicit successful durable-write/reopen laws. Production cache comparisons use a digest and selected fresh fields; arbitrary context changes are not claimed to miss. FI-09 preserves behavior only while both timestamps remain due. The finite example codec is a satisfiability witness, not a cryptographic implementation.

Format the standalone Rust harness with `rustfmt +nightly-2025-09-27 --config-path adapters/rustfmt.toml adapters/fi.rs`. Its `skip_children = true` setting prevents traversal into the pinned production source referenced by `#[path]`; workspace formatting remains `just fmt`.

`reports/fi-coverage.json` maps every requested FI scenario to57 concrete test references in12 behavior groups, including the existing forced/Engine/Process/calldata/lander tests and the two focused Finalize additions. These are conformance evidence; tests are reused when already adequate instead of duplicating them to touch each named file.
