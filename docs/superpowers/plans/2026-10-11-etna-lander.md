# Etna lander implementation plan

Date: 2026-10-11
Status: implementation and final verification complete; pushed to the existing PR

> For execution: use superpowers:subagent-driven-development if the user
> selects delegated execution, or superpowers:executing-plans for inline
> execution. Follow the approved spec and track the checkboxes below.

**Goal:** add a runnable permissionless Etna lander to PR #22280, with an
asynchronous proof-provider trait and a dummy implementation returning 0x00.

**Architecture:** construct one immutable, authenticated proving job from the
current Inbox checkpoint and CometBFT history. Encode complete block/commit
pairs into blobs, bind the contract's V3 statement, obtain the proof, and track
one signed transaction/nonce through restart-safe submission. The lander runs
separately from ABCI.

**Stack:** Rust 1.95, Alloy 1.8.3, tendermint/tendermint-proto 0.40.4, prost 0.13,
nextest, anvil, stock CometBFT v0.40.0, and the existing alethia-reth test image.

**Approved spec:** ../specs/2026-10-11-etna-lander-design.md

## Working rules and execution gates

- Work in the existing isolated checkout on codex/pr22280-genesis-simplification.
  The existing .build directory and unrelated main-checkout changes are outside
  the edit scope.
- All implementation paths below are relative to packages/taiko-client-rs.
  The only root paths are the design and plan documents.
- Preserve ABCI state/wire/header/generation behavior and raiko2's protocol and
  Anchor dependencies. Do not add contract source changes to #22280.
- Add no real prover, HTTP prover transport, fee-replacement policy, nonce
  cancellation, forced inclusions, reward system, or database.
- Generate contract snapshots/artifacts from protocol revision
  639bae72ba2e69fc44387306d56f9fef7cb6703d. Keep the ABI and fixture provenance
  reproducible; do not hand-edit generated bindings.
- Use compiling stubs where needed so a red test fails on an observable
  behavior, not only a missing import. Confirm the intended failure, implement
  the smallest complete increment, then rerun that test.
- After each coherent code increment run just fmt and just clippy-fix. Inspect
  their diff. Required final checks remain both just clippy passes, just unit,
  just test, and git diff --check.
- Local commits may checkpoint tested slices. Push only after complete
  verification and independent review; use a normal fast-forward update of
  feat/taiko-client-rs-abci.
- No implementation begins until the user approves this written plan and
  selects its execution method.

## Ownership when using subagents

The coordinator owns manifests, exports, CLI integration, test-harness changes,
fixture generation, documentation, global format/lint runs, final verification,
commits, and push.

Delegate disjoint responsibilities after the foundation exists:

- Protocol worker: contracts.rs, statement.rs, codec.rs, blob.rs, proof.rs and
  their unit tests.
- Consensus worker: validate.rs, committee.rs, batch.rs, comet.rs and their
  unit tests.
- Runtime worker: l1.rs, tx.rs, store.rs, runner.rs and their unit tests.

Workers are not alone in the checkout. They must not revert others' changes,
must stay within assigned files, and must coordinate interface changes through
the coordinator. The coordinator integrates dependency changes and runs global
format/lint tools to avoid competing edits. Tasks with unfinished dependencies
remain sequential. Inline execution uses the same task order.

## Task 1: Workspace foundation and proof contract

**Files:** Cargo.toml, Cargo.lock, crates/lander/Cargo.toml,
crates/lander/src/{lib,types,error,proof}.rs.

- [x] Add the lander workspace member and its manifest, using workspace-pinned
      dependencies. Enable the KZG and signing features needed by this crate without
      changing protocol's default/no-default-feature contract.
- [x] Define documented immutable context types: landing snapshot, limits,
      prepared batch, ProofRequest, provider error, and sidecar mode. Keep
      contract-independent domain types separate from generated ABI types.
- [x] Add a compiling ProofProvider async trait with the spec's request/response
      contract. Write an observable request/response test that distinguishes one
      zero byte from empty bytes and a 32-byte ABI integer; confirm red behavior.
- [x] Implement DummyProofProvider as a stateless provider returning one zero
      byte. Add an injectable rejecting/delayed provider to exercise error and
      deadline propagation in later runner tests.
- [x] Add crate-wide production-symbol doc linting consistent with abci.
- [x] Run cargo nextest run -p lander --all-features -E '!kind(test)',
      cargo check -p protocol --no-default-features --locked, then format/lint.

**Checkpoint:** the crate compiles and the public proof boundary is usable;
there is no network prover adapter.

## Task 2: Pinned contract types and V3 statement

**Files:** crates/lander/contracts/IEtnaInbox.sol,
crates/lander/src/{contracts,statement}.rs,
script/gen_lander_artifacts.sh,
crates/lander/tests/fixtures/contracts/manifest.json.

- [x] Add a generator accepting a protocol checkout path and verifying its
      pinned Git revision before exporting snapshots. Use gh for any GitHub fetch
      required to obtain that checkout. Install pnpm dependencies before invoking
      Foundry, following repository instructions.
- [x] Export the exact IEtnaInbox interface, preserving NatSpec, and generate
      Alloy types with sol! from that snapshot. Record source revision, source
      hashes, compiler/settings, and artifact hashes. Keep existing Anchor bindings
      untouched.
- [x] Write red fixed-vector tests for recordsHash, blobHashesHash, and the
      complete 512-byte V3 preimage. Pin the reference hashes:
      records 0x0fc2fb3087e71a5875752ba977cada62484ec8f9e897200fc61fde95b414fff1;
      blobs 0xe7591a4eb3dcfdc958b08bf3db6054ebae1f9b1a82b8c685499c13314381ea64;
      statement 0x90607f5e39a9f1a365d93fbf59a9397c3243e004182898c0c8db284ae190a56b.
- [x] Implement the exact static sixteen-word ABI encoding from the spec.
      Keep the dynamic records array's offset word and the packed blob hash list.
- [x] Mutate Inbox, registry, chain ids, generation, parent, starting record,
      reference, terminal block/root, records, and blob order independently; each
      must alter the digest. Test selectors and ABI field order against the snapshot.
- [x] Run the statement unit tests, then the required format/lint increment.

**Checkpoint:** Rust's public statement matches the current #22286 encoding.

## Task 3: Canonical batch codec

**Files:** crates/lander/src/codec.rs,
crates/lander/src/test_utils/{mod,blocks}.rs.

- [x] Build small valid CometBFT block/commit fixtures with exactly one Etna
      envelope transaction and canonical v0_38 protobuf conversions.
- [x] Write red V1 wire-vector and multi-block round-trip tests. Include the
      version byte, canonical RLP byte strings, ordinary protobuf encoding without
      an extra length delimiter, and preservation of envelope bytes.
- [x] Implement bounded encoding/decoding of
      0x01 || rlp([[comet_block_proto, commit_proto], ...]).
- [x] Reject empty batches, wrong versions, trailing data, truncated messages,
      noncanonical protobuf/RLP, and configured count/byte limit violations.
      Check length limits before allocations and conversions.
- [x] Add independent mutation cases against encoded fixtures, rather than
      only comparing an encoder with its decoder.
- [x] Run codec unit tests and format/lint.

**Checkpoint:** payload V1 is stable and can later be decoded by the guest.

## Task 4: Blob construction and transaction sidecars

**Files:** crates/lander/src/blob.rs.

- [x] Write red tests for a payload crossing a blob boundary, exact capacity
      limits, maximum blob count, and a complete block exceeding capacity.
- [x] Reuse protocol::shasta::BlobCoder through a small documented adapter.
      Build sidecars with Alloy's EIP-4844 and EIP-7594 builders.
- [x] Expose ordered versioned hashes and payload-size/blob-count checks. Avoid
      rebuilding expensive KZG proofs while merely selecting a batch boundary.
- [x] Decode real generated blobs back to V1 bytes. Verify commitments and
      proofs, and confirm both sidecar modes bind identical blobs/hashes.
- [x] Verify empty or truncated blob collections and reordered blobs are
      rejected or produce a different public commitment as appropriate.
- [x] Run blob unit tests, protocol no-default-feature checks, and format/lint.

**Dependencies:** Tasks 1 and 3. Sidecar construction uses no RPC.

## Task 5: Commit and committee validation

**Files:** crates/lander/src/{validate,committee}.rs,
crates/lander/src/test_utils/signatures.rs; coordinator-only changes to
crates/abci/src/rules/{mod,tests}.rs and crates/abci/src/app/validate.rs.

- [x] Generate genuine Ed25519 precommits using Tendermint's canonical vote
      sign bytes, chain id, height, round, block id, and per-signature timestamp.
- [x] Write red cases for wrong chain/generation/height/round, bad signatures,
      nil/absent votes, duplicated signers, exactly two thirds, and more than two
      thirds. Counting a signer twice must never increase accepted power.
- [x] Validate CometBFT header/data/evidence/last-commit consistency and the
      current commit's block id. Validate one envelope, EL height, and EL parent
      hash against the expected parent.
- [x] Reconstruct the MEM-08 member root and total stake/power; verify canonical
      member ordering and mapping. Match the full starting record to the on-chain
      hash and the reconstructed Tendermint validator set to the block header.
- [x] Have the coordinator extract the existing private checkpoint/record
      landing predicate into a documented pure rules helper. Keep the ABCI
      wrapper's committee-presence checks and existing Rejection variants/error
      order unchanged. Characterize the old switch behavior before extraction
      and rerun the ABCI switch unit tests afterward.
- [x] Reuse abci's pure schedule, committee witness, cutoff, record-hash, and
      shared landing predicate for derived and previously landed committees. Verify H+2
      timing and exact e + 1 outputs at epoch starts.
- [x] Run validation/committee unit tests and format/lint.

**Dependencies:** Tasks 1 and 3. Do not copy consensus algorithms into a divergent
implementation when a public ABCI helper already provides the required rule.

## Task 6: Bounded CometBFT HTTP source

**Files:** crates/lander/src/comet.rs,
crates/lander/src/test_utils/http.rs.

- [x] Define the read-only source trait and typed HTTP adapter for status,
      block, commit, and /committee/<epoch> ABCI queries.
- [x] Write red HTTP fixture tests covering string-encoded heights, protobuf
      conversion, RPC errors, nonzero ABCI response codes, malformed base64,
      oversized bodies, deadlines, and requested/returned height disagreement.
- [x] Implement bounded streaming response reads and typed decoding. Preserve
      timestamps, signatures, block ids and envelope bytes exactly.
- [x] Fetch only the requested consecutive range and required committee
      contexts; report pruned/missing history with the specific height or epoch.
- [x] Check node chain identity, decided height, and block/commit pairing before
      passing data to batch assembly.
- [x] Run Comet source unit tests and format/lint.

**Dependencies:** Tasks 1 and 3; independent of L1 submission.

## Task 7: Coherent L1 snapshot and reference chain

**Files:** crates/lander/src/l1.rs,
crates/lander/src/test_utils/l1.rs.

- [x] Define the L1 source interface around hash-pinned Inbox reads, finalized
      headers, parent EL headers, contract hash cross-checks, and receipt queries.
- [x] Write red tests where unpinned getter responses would mix checkpoints,
      generations, committee hashes, or implementation/registry identities.
- [x] Implement a coherent landing snapshot, genesis/epoch checks, L2 parent
      header authentication, and the local/contract V3 digest cross-check.
- [x] Select a finalized reference covering all consumed anchors and collect
      its raw parent-header chain. Reuse ABCI raw-header support; check numbers,
      hashes, state roots, canonicality and the contract's reference availability.
- [x] Cover inherited anchors, a reference later than the last anchor, L1
      finality lag, expired references, wrong forks, genesis parent context, and
      endpoint chain-id/configuration mismatches.
- [x] Run L1 source unit tests and format/lint.

**Dependencies:** Tasks 1, 2 and 5. Configure the registry identity from validated
chain parameters and detect mismatch through the proxy's statement helper.

## Task 8: Immutable batch builder

**Files:** crates/lander/src/batch.rs.

- [x] Write red observable tests for building from genesis and from a middle-of-
      epoch checkpoint, using authenticated source fixtures.
- [x] Assemble consecutive blocks, validate certificates and committee changes,
      authenticate the L1 reference chain, and compute exact ordered outputs.
- [x] Select the largest complete prefix fitting the configured block/blob
      limits. Do not request a proof when there is no complete publishable batch.
- [x] Build blobs once for the selected prefix, then the LandInput and V3 hash.
      Verify the contract helper and create an immutable ProofRequest.
- [x] Cover a batch crossing a derivation height and a switch height, missing or
      extra committee outputs, incomplete history, and oversized first blocks.
- [x] Run batch unit tests and all pure-core lander tests; format/lint.

**Dependencies:** Tasks 2 through 7.

## Task 9: Signed blob transaction transport

**Files:** crates/lander/src/tx.rs.

- [x] Write red tests that decode the signed network envelope and inspect chain
      id, recipient, nonce, zero value, LandInput, exact 0x00 proof, ordered blob
      hashes, sidecar mode, and fee bounds.
- [x] Load the signer from a key file without logging/storing key bytes. Obtain
      pending nonce, estimate gas, and fill fees within the explicit operator caps.
- [x] Return a complete signed transaction and deterministic hash without
      broadcasting it; the caller must journal these bytes first.
- [x] Implement bounded raw broadcast, transaction lookup, receipt lookup, and
      canonical receipt-block checks. Handle already-known responses idempotently.
- [x] Test ambiguous broadcast failures and sender/chain/nonce mismatches.
      Implement no fee replacement or cancellation in this version.
- [x] Run transaction unit tests and format/lint.

**Dependencies:** Tasks 1, 2 and 4.

## Task 10: Atomic journal and exclusive ownership

**Files:** crates/lander/src/store.rs.

- [x] Write red tests for prepared/signed/pending round-trips, interrupted temp
      writes, an existing directory lock, corrupt data, and identity mismatches.
- [x] Define a versioned journal containing the immutable job, proof, signed
      network envelope/sidecar, hash, sender, nonce, and confirmation context.
- [x] Save with file fsync, rename, and directory fsync. Retain the prior
      committed file on interruption and reject corrupt main state.
- [x] Acquire an exclusive data-directory lock before network mutation.
      Validate loaded identities and signed bytes before resuming a journal.
- [x] Bound journal size and keep private keys and endpoint credentials outside
      persisted data. Support an empty directory by rebuilding from L1.
- [x] Run store tests and format/lint.

**Dependencies:** Tasks 1, 8 and 9.

## Task 11: Polling runner, races, and recovery

**Files:** crates/lander/src/runner.rs,
crates/lander/src/test_utils/runner.rs.

- [x] Write a mock-source state-machine test through Idle, Prepared, Signed,
      Pending, Confirming, and back to Idle. Observe calls and durable state.
- [x] Inject crashes immediately before and after journal commits and broadcast
      responses. After restart, reconcile receipt/nonce state before signing; an
      ambiguous response must not allocate a second nonce.
- [x] Implement bounded polling/backoff, provider deadlines, coherent
      pre-submission rereads, reference freshness checks, and journal-first
      broadcast ordering.
- [x] Cover another lander advancing part/all of the batch before proof,
      before broadcast, and while a transaction is pending. Track outstanding
      nonce resolution even when its job becomes obsolete.
- [x] Cover dropped transactions, canonical receipt confirmations, receipt
      reorgs, checkpoint rollback, deterministic proof/schema reverts, and safety
      contradictions. Reuse the spec's retry-versus-stop classification.
- [x] Run all runner and lander unit tests, then format/lint.

**Dependencies:** Tasks 8 through 10.

## Task 12: CLI, configuration, and metrics

**Files:** bin/client/Cargo.toml, bin/client/src/{cli,error}.rs,
bin/client/src/commands/{mod,lander}.rs,
bin/client/src/flags/{mod,common,lander}.rs,
crates/lander/src/{config,metrics}.rs.

- [x] Add the thin lander subcommand and its documented flags. Require public
      RPC endpoints, key path, separate data directory, limits, fee caps, and
      sidecar mode. Keep Engine/JWT flags out of this command.
- [x] Extract only reusable logging/metrics options/helpers needed to preserve
      existing ABCI CLI behavior; do not refactor unrelated CLI flows.
- [x] Write red parser/config tests for missing values, unsupported URL schemes,
      zero limits/deadlines, invalid confirmation counts, and priority fee above
      the execution fee cap. Check existing ABCI mandatory flags remain mandatory.
- [x] Wire configuration, sources, DummyProofProvider, signer, store, runner,
      metrics, and the existing graceful shutdown handling.
- [x] Expose dummy mode, progress/depth, batch/blob sizes, pending nonce/hash,
      receipt status, and classified waits/retries without secret data.
- [x] Run client lander/parser tests, existing client unit tests, and format/lint.

**Dependencies:** Tasks 7 through 11. Coordinator owns shared CLI files.

## Task 13: Actual-contract Docker integration

**Files:** crates/lander/tests/{landing,recovery,collector}.rs,
crates/lander/tests/support/{mod,contracts,fixtures}.rs,
crates/lander/tests/fixtures/contracts/\*.json,
crates/test-harness/src/{lib,anvil}.rs,
tests/entrypoint.sh, .config/nextest.toml.

- [x] Extend the artifact generator to compile actual pinned Inbox, registry,
      SignalService, ERC1967 proxy, and the accepting/rejecting test verifier.
      Record compiler settings and artifact hashes; verify regeneration before
      checking in generated JSON.
- [x] Add a small standalone-anvil harness reusing existing Docker ownership,
      timeouts, log dumps, and cleanup. It must not depend on lander, preventing a
      crate dependency cycle. Deploy the actual contracts and authorized proxies.
- [x] Use prepared, cryptographically valid CometBFT fixtures bound to the test
      deployment. Submit actual blob transactions and inspect the recorded
      checkpoint, SignalService checkpoint, committee events/outputs, transaction
      input, and canonical receipt.
- [x] Cover cross-epoch outputs, a competing sender advancing the checkpoint,
      a rejecting verifier with atomic rollback, and mismatch refusal before
      broadcast. Verify actual transaction blob hashes against the prepared job.
- [x] Exercise the production Comet adapter against a live existing Devnet.
      Compare block/commit decoding, committee queries and certificates; do not
      mistake the existing fake lander's storage writes for real landing coverage.
- [x] Prefix every new Docker scenario name with lander\_ (including the live
      collector). Add lander to the Docker entrypoint's package selection and
      retain the existing serial integration group. Run
      PULL_POLICY=missing just test lander for targeted integration and require
      the named actual-contract and collector scenarios to appear in the results.
- [x] Run the actual-contract and live-collector scenarios separately and
      inspect every assertion and container cleanup.

**Dependencies:** Tasks 2 through 12. Contract tests use real contract logic plus
a dummy-proof verifier; they do not establish real guest soundness.

## Task 14: Actual CLI restart and shutdown coverage

**Files:** bin/client/Cargo.toml,
bin/client/tests/lander_cli.rs,
bin/client/tests/support/lander.rs,
tests/entrypoint.sh.

- [x] Add Docker-ignored CLI tests using CARGO_BIN_EXE_taiko-client. Include the
      client package in the integration entrypoint so Cargo builds the tested
      executable without an ad-hoc nested build.
- [x] Start the real lander command against the contract fixture and a bounded
      Comet RPC fixture. Confirm a checkpoint advance using a blob transaction.
- [x] Send SIGTERM and restart from the same data directory. Send SIGKILL
      around a persisted outstanding transaction, restart, and verify nonce
      reconciliation and continued progress.
- [x] Assert failure to obtain the directory lock, invalid configuration, and
      a corrupt journal exits without submitting a transaction. Inspect output to
      ensure signing-key material is absent.
- [x] Run targeted CLI Docker scenarios and verify every child process and
      container is stopped on both success and failure.
- [x] Run format/lint for the complete integrated change.

**Dependencies:** Tasks 12 and 13.

## Task 15: Documentation, full verification, review, and push

**Files:** README.md, AGENTS.md, generated-artifact provenance docs,
the existing GitHub PR description.

- [x] Document the lander command, required configuration/fee units, data
      directory, blob V1, sidecar selection, RPC/history requirements, races,
      restart behavior, pending-fee limitation, and dummy verifier requirement.
- [x] Update repository guidance for the new crate and expanded Docker suite;
      keep raiko2 and existing ABCI guidance accurate.
- [x] Verify latest #22286 still matches the pinned ABI/schema. If its head has
      changed, inspect the difference and update compatible snapshots/tests before
      continuing; a changed protocol requirement must be reflected in the spec.
- [x] Run the final complete sequence from the package root with the pinned
      images: just fmt, just clippy, just unit, PULL_POLICY=missing just test, and
      git diff --check. Require all existing nine ABCI Docker scenarios and all new
      lander/CLI scenarios to pass.
- [x] Review the complete implementation diff independently for V3 identity
      binding, blob integrity, certificate quorums, committee timing, nonce/journal
      durability, permissionless races, and preserved ABCI behavior. Fix supported
      findings and rerun the affected checks; repeat the full sequence if code
      changed after final verification.
- [x] Commit the completed change. Check the remote PR branch is still the
      expected ancestor; integrate any concurrent updates and reverify as needed.
      Push normally to origin HEAD:refs/heads/feat/taiko-client-rs-abci.
- [x] Rewrite the PR description around its final ABCI + lander scope, exact
      validation, dummy-only proof status, real-guest follow-up, and operating
      requirements. Use gh with a body file.
- [ ] Confirm remote HEAD, tracked working-tree state, and the attached PR.
      Report the commit(s), test results and material limitations concisely.

## Implementation review checklist

- The signed transaction's recipient, proxy-bound statement identities and
  ordered blobs match the immutable job; no response can override them.
- L1 reference is distinct from every block's own anchor.
- No invalid/missing certificate, extra committee output, truncated block, or
  unbounded HTTP/codec/journal allocation reaches signing.
- More than two thirds means strictly more than, with no duplicate-signature
  power. H+2 switches use the authenticated correct committee.
- Checkpoint races and ambiguous broadcasts do not blindly consume a new nonce.
- Restart can recover signed bytes before broadcast and receipts afterward.
- Dummy success is described as transaction-path testing, never real validity
  proof verification.
- Existing ABCI commits, header/wire rules, generation behavior and state-loss
  replay retain their prior results.

## Final verification evidence

- just fmt, just clippy-fix, both just clippy passes, and git diff --check passed.
- just unit: 663 workspace tests, 58 protocol tests without default features, and 2 doctests passed.
- just test: all 20 Docker scenarios passed, including the original nine ABCI scenarios.
- Independent protocol/runtime review and the confirmed gas-boundary fix follow-up found no remaining P1/P2.
- Gas-boundary regression was observed failing before checked 20% headroom, then passing with a real EIP-2935 lookup.
