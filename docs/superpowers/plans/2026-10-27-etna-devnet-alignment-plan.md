# Etna devnet alignment implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Execute tasks serially with one implementer and one scoped reviewer per task; final integration review follows. Do not ask for design approval again: the user approved this design and execution on 2026-10-27.

**Goal:** Update client PR #22280 and deployment PR #1663 into one tested, runnable fresh-genesis devnet; leave deployment to the user.

**Architecture:** Refresh the client to the single current V1 protocol and native stock secp256k1eth consensus, retain the lean EL's generic build interface, and update the operator bootstrap/configuration to those exact artifacts. Real guests and governance recovery remain excluded. Use existing module boundaries and generated-artifact workflows.

**Tech Stack:** Rust 1.95, stock CometBFT v0.40.0, existing Go FilePV helper, Solidity/Foundry fixtures, Docker, Helm and shell.

**Spec:** `docs/superpowers/specs/2026-10-27-etna-devnet-alignment-design.md`; canonical spec snapshot `/tmp/etna-client-align-spec.txt`.

## Global Constraints

- Approved immutable inputs: protocol `23963b68e43b4cbeaf83113eeb61fbc1bddb4c46`, EL `b046734a0a47b17ca66c33ccbc7c9087cbbf9b1e`.
- APP_VERSION=1, seven-word config, V1 tags, five-field entry/committee, envelope/payload 0x06, K=6, executionBlock <=124000 bytes, maxBlockBytes=124000 on every Etna build.
- Native consensus SEC1 keys are 33 bytes, validator addresses are Ethereum addresses, signatures are 65-byte low-s R||S||V, chain_id is 48-byte `etna-` plus unpadded base64url of the full deployment/generation digest.
- No true guest, governance recovery, deployed-state migration, Kubernetes apply/delete, live deployment or merge. Do not change protocol #22286 or the Notion spec.
- Preserve non-Etna render/behavior, Shasta helpers and FixedKSigner consumers; do not hand-edit generated bindings or artifacts.
- Every production Rust symbol has contract docs. Follow package just fmt / just clippy / just verify instructions. Design supersedes stale protocol-format details in the old package AGENTS.md; update those details when their implementation changes.
- Client worktree `/private/tmp/etna-devnet-client` on `codex/etna-devnet-client-align`; K8s worktree `/private/tmp/etna-devnet-k8s` on `codex/etna-devnet-k8s-align`. Other worktrees and unpublished V15 drafts are read-only references, never authorities.
- Use CARGO_TARGET_DIR=/private/tmp/etna-devnet-target for client work. Heavy tests run once per coherent change; no concurrent Cargo/Docker verification runs.

## Review Focus

- An old heartbeat/fee-vault/journal artifact must never be accepted as the new genesis or silently reused.
- An eligible low-fee FI may execute: removal of the obsolete 1-gwei shortcut must not turn temporary failure or missing state into a legal skip.
- A signer restart, missing state PVC or trust reconnect must preserve HRS and cannot create a new height-zero authority for a registered key.
- Competing grid landings must retain the original signed bytes and nonce; only the newly settled suffix advances state.
- Deployment must reference existing images/artifacts of the tested revisions, preserve non-Etna manifests and stop before any live cluster mutation.

---

### Task 1: Refresh the ABCI runtime and Engine boundary

**Files:**
- Modify `packages/taiko-client-rs/crates/abci/src/**` and its manifest/test data.
- Modify shared `crates/protocol/src/shasta` payload/extra-data helpers and `crates/rpc/src/auth.rs` only where the approved Etna/EL boundary needs it.
- Modify workspace `Cargo.toml`/`Cargo.lock` to pin all alethia-reth dependencies to b046734 and reconcile required compatible dependencies.
- Update ABCI-focused fixture builders/tests and package AGENTS.md's superseded runtime-format guidance.

**Interfaces:**
- Preserve exported runtime `App`, `Engine`, `RpcEngine`, `ChainParams`, `GenesisWitness`, `ExecutionBlock` entry points wherever reasonable.
- Add `key::ConsensusKey` with `from_slice(&[u8])->Result<Self,KeyError>`, `as_bytes()->&[u8;33]`, `prefix()->u8`, `x()->B256`, `address()->Address`, and `verify_signature(&[u8],&[u8])->bool`.
- Add `domain::DeploymentDomain { l1_chain_id: U256, l2_chain_id: U256, inbox: Address, generation: u64 }` and `chain_id(&DeploymentDomain)->Result<String,...>`; publish exact ancillary interfaces in the task report for consumers.
- RegistryEntry is the canonical five-field shape; Member carries a validated consensus key, effStake and power, with no registered reward recipient. CommitteeRecord is targetEpoch/cutoff/checkpointIndex/setRoot/totalPower. `ChainParams` authenticates U directly; local fee-recipient selection is separate from committee validity.
- Keep generic `Engine::build_block(parent_hash, attrs)`, with attrs.max_block_bytes=Some(124000); -38100 is definitive.

- [ ] Step 1: Read the design/spec and protocol schema-4 vectors. Add focused failing behavioral checks against current code: native key/domain/vector mismatch, direct committee config/root mismatch, fee-sharing 100, raw byte overflow and definitive -38100. Keep RED output in the report; do not manufacture source-grep tests.
- [ ] Step 2: Implement native key/domain/wire/genesis and direct committee/ABI/storage changes. A minimal native ABCI wire adapter is allowed if typed tendermint-rs cannot carry secp256k1eth. Reference `4c71bd0a1` key/domain/wire code for transport mechanics only, never import V15 consensus tags/rules wholesale.
- [ ] Step 3: Align header/FI/Engine behavior, raw L1-header decoding, trust/startup and fresh generation-0-only enforcement. Preserve all failure/rollback semantics in the design. Remove superseded heartbeat, fee-vault and registered-recipient assumptions in this scope.
- [ ] Step 4: Run all ABCI library tests and protocol/RPC targeted consumers; fix regressions. Expected: new vectors and retained non-obsolete tests pass. A workspace consumer needing Task 3 migration must be listed precisely, not papered over with a compatibility mode or stub.
- [ ] Step 5: Commit `feat(abci): align fresh Etna consensus with the V1 spec`. Report changed public interfaces, test evidence, dependent migration work and any concrete concern. Do not push.

### Task 2: Native guarded signer and bootstrap key tooling

**Files:** `packages/taiko-client-rs/tools/etna-signer/**`, `script/build_etna_signer.sh`, `script/start_etna_validator.sh`, signer documentation/Docker wiring as needed.

**Interfaces:**
- Consume Task 1's canonical domain/key semantics and stock CometBFT v0.40.0 wire bytes.
- Keep existing guarded serve flags (`--comet-signer-addr`, `--trust-socket`, `--chain-id`, `--priv-key`, `--priv-state`).
- Provide explicit bootstrap-only `etna-signer keygen --priv-key PATH --priv-state PATH` producing exclusive new FilePV files and JSON publicKey/address output; refuse either existing output.
- Provide `etna-signer pop --priv-key PATH --owner ADDRESS --registry ADDRESS --l1-chain-id NUMBER` returning JSON publicKey/signature. EIP-712 name EtnaStakingRegistry, version 1, Register(address owner); signature R||S||V with V in {0,1}. No private material on stdout.

- [ ] Step 1: Add failing stock-key/signature and exclusive-creation/PoP tests, including low-s boundaries and Ethereum address recovery.
- [ ] Step 2: Implement using stock crypto/FilePV APIs. Every signature remains fresh-session gated. Normal serve refuses absent key/state and never initializes/reset HRS. Keep transport identities distinct from consensus identities.
- [ ] Step 3: Run Go race/process/interop tests and signer build. Expected: exact current protocol vectors pass, conflict/reconnect/missing-state tests remain closed without modifying HRS.
- [ ] Step 4: Commit `feat(signer): support native Etna keys and registration proofs`; report exact machine-readable command outputs and runtime paths for Tasks 3/4. Do not push.

### Task 3: V1 lander, generated artifacts, CLI and devnet harness

**Files:** `packages/taiko-client-rs/crates/lander/**`, `crates/test-harness/**`, `bin/client/**`, generation/test scripts, Docker test assets, README/AGENTS.md, root `testdata/etna_vectors` generated copies. Minimal Task 1 consumer adaptation is in scope; avoid unrelated Shasta changes.

**Interfaces:**
- Consume Task 1 types/runtime/Engine and Task 2 signer/keygen/PoP CLI; use protocol 23963b6 ABI/layout/schema-4 vectors and EL b046734.
- LandInput has eight protocol fields; `land(input, leaves, proof)`. Statement has 21 static words / 672 bytes; cutLeaf has (height,EL hash,Comet hash,FI cursor), cutHash V1.
- Blob public content is execution blocks only. Private host inputs retain original envelope, Comet header/commit and witnesses; preserve their authentication.
- Grid endpoints p,c,h are multiples of 6. p<=c<h keeps signed job bytes/nonce unchanged; c>=h completes it.

- [ ] Step 1: Add failing vectors/codec/grid/overlap/fee-routing checks before implementation; retain tests of meaningful nonce, trust and signature contracts while replacing obsolete reward tests.
- [ ] Step 2: Regenerate fixtures/bindings/vectors from the pinned protocol using the actual generators; migrate constructors and artifact manifests. Remove Etna reward vault/receipt/lander-claim paths and obsolete CLI flags; all fees go to proposer locally, FI fees remain protocol funds.
- [ ] Step 3: Implement V1 landing, current public DA and immutable journal behavior, CLI genesis/config/fee-recipient integration, and native guarded-signing harness with no local FilePV fallback.
- [ ] Step 4: Add one real local four-validator scenario using current contracts + EL b046734 + stock Comet: bootstrap, normal/FI inclusion, epoch transition, dummy land/checkpoint advance and restart/catch-up. Also cover raw 124000/124001 boundaries, -38100/transient classification and old artifact rejection across the complete flow.
- [ ] Step 5: Run focused tests, formatting/clippy batches, signer tests, artifact reproducibility, then one final `just verify` on the completed client tree. Expected: all current fast and Docker scenarios pass, no ignored failures or warnings left unexplained. Coordinate local EL-image availability with controller before Docker verification.
- [ ] Step 6: Commit `feat(lander): align Etna settlement and devnet integration`; update client docs around final scope and validation. Do not push until task review is clean.

### Task 4: Internal-devnet deployment and bootstrap alignment

**Files:** K8s `internal-devnet/config/etna/*.sh`, Etna templates/helpers/values/Makefile and associated offline validation/runbook; client signer/genesis machine-output documentation only if needed.

**Interfaces:**
- Consume the final client revision and Task 2 CLI, protocol 23963b6 deployment script, EL b046734 alloc-only genesis and published immutable images.
- Defaults: four equal-stake validators, K=6, U=3600, L=900, 4s commit, lander min60/max120/six blobs/300s; positive registry delays, nonzero protocol treasury; existing valid FI delay/maxAnchorAge retained.
- Runtime signer key/state are outside Comet home; bootstrap mounts signer PVCs and initializes once for fresh keys/domain. Runtime missing signer state fails closed, including an empty replacement PVC. Bootstrap never reuses an existing chain's signing authority.

- [ ] Step 1: Add failing behavior tests for new bootstrap outputs, missing signing-state rejection and stale artifacts. Record non-Etna rendered baseline before changes.
- [ ] Step 2: Replace old heartbeat/vault/predicted-Inbox bootstrap with proxy→registry→registration PoP→activation/finality→committee+EL genesis→Inbox init→authenticated Comet genesis. Publish only the current artifacts/config.
- [ ] Step 3: Wire guarded signer storage, app-trust readiness and supported process startup into the four validators. Preserve networking, JWT isolation, archive state and non-Etna templates; no permanent unwind flags.
- [ ] Step 4: Pin verified source/image revisions and genesis content hash. Provide manual operator reset/bring-up checks, defaulting to retaining compatible L1 and replacing Etna/L2 artifacts; never execute them.
- [ ] Step 5: Run Helm lint/render/schema validation, shell syntax/lint/behavior tests and render stability comparison; exercise rendered bootstrap/config with local test endpoints or the Docker devnet. Expected: current CLI/contracts match, old paths are absent, missing state cannot reset HRS, no cluster mutations.
- [ ] Step 6: Commit `feat(internal-devnet): align Etna bootstrap and validator signing`; report validation and exact operator handoff. Do not push.

### Task 5: Image provenance, whole-project review and PR publication

**Files:** Final PR descriptions/runbook and immutable image pins; minimal trusted build-workflow changes only if required to produce approved images, with no EL behavior change.

**Interfaces:** Consume reviewed commits from Tasks 1–4 and green client/K8s gates; preserve draft/open/base states of existing PRs.

- [ ] Step 1: Ensure exact EL b046734 image exists or build/publish it with repository Docker tooling; client image comes from the existing #22280 branch CI workflow. Validate manifests/digests and source provenance. No fabricated SHA tags.
- [ ] Step 2: Review the full coordinated change and all recorded decisions with a fresh strongest reviewer. Fix concrete critical/important findings and run appropriate regression gates for changed code.
- [ ] Step 3: Confirm remote heads before normal fast-forward pushes; update #22280 and #1663 title/body around actual final behavior, validated image pins and commands. Preserve known scope exclusions and all deployment prerequisites.
- [ ] Step 4: Verify remote commits, green relevant checks and image availability; leave clean worktrees and a concise deployment handoff. No merge or live deployment.
