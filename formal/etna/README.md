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
