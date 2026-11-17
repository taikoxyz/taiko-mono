# Nonzero-S lander continuation

Base: ea74662169262dc8ab6ada7028d2ef54137088d2, pushed to PR22280.

The user authorized implementing the remaining lander support, excluding DAO and tests.
Use production compilation, strict documentation/clippy checks, formatting and independent review.

## Tasks

- Batch/history: S-relative grid, committee 0 until global epoch transitions, authenticated
  Unzen ancestry through S, and S-1 timestamp. Worker owns batch.rs/history.rs.
- Source/journal: hash-pinned first-landing preflight, raw EIP-1967 Anchor proof in the immutable
  proof request, authenticated start tuple and S-relative overlap. Parent owns these files.
- Checkpoint import/export: S-relative authentication, explicit initial committee and independent
  original block-0 EL identity from the operator-selected runtime chainspec. Worker owns import files.
- Integrate, document the remaining dummy-proof boundary, run production checks and review.

## Decisions

- Journal schema 16 becomes 17 for the additional private witness. Reject older schemas;
  never migrate an existing signed transaction, proof request or consensus state.
- Preserve public statement, cut-leaf and blob ABI. Anchor witness is private proof material.
- First-landing readiness gates new jobs only. Pending nonce/receipt reconciliation continues.
- The start record has parent=S, generation=0, FI=0 and zero Comet/validator hashes.
- Initial committee is target 0, independent of S/L. Subsequent epoch boundaries stay global.
- Import packages remain schema 1. EL chainspec genesis remains block 0, independent of H(S).
- No real proving backend/guest is supplied by this repository. Retain and host-verify all new
  raw proof material without claiming production cryptographic proof support.

## Progress

- Stage 1 committed and remote PR head verified at ea7466216.
- Batch/history and import workers implementing disjoint files; shared APIs agreed explicitly.
- Batch/history and import implementation integrated. Raw Anchor proof is retained in PreparedBatch.
- Independent review found missing SignalService authentication for importing S and a generation-zero-only
  first-landing gate. Both paths now share the hash-pinned checkpoint check, including recovery to S.
- Production workspace check and independent EL-helper check passed. Strict clippy/docs passed for
  all production workspace features and the independent helper. just fmt and just fmt-check passed;
  both now include the independent helper workspace. No tests authored or executed.
- Focused re-review confirms both findings addressed, with no new important findings.
- Stage 2 remains a local working-tree patch for review. Stage 1 is the requested published commit.

## Verification

- cargo +1.99.0 check --workspace --lib --bins --locked --offline
- cargo +1.99.0 clippy --workspace --exclude bindings --exclude test-harness --lib --bins --all-features --locked --offline --no-deps -- -D warnings -D missing_docs -D clippy::missing_docs_in_private_items
- cargo +1.99.0 check --manifest-path tools/etna-el-import/Cargo.toml --lib --bins --locked --offline
- cargo +1.99.0 clippy --manifest-path tools/etna-el-import/Cargo.toml --lib --bins --locked --offline --no-deps -- -D warnings -D missing_docs -D clippy::missing_docs_in_private_items
- just fmt; just fmt-check; git diff --check

All commands above completed successfully. The upstream proc-macro-error2 dependency emits the
existing future-compatibility notice. No just verify/test targets were run, per the user's scope.
