# Etna Governance Recovery Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update PR #22280 with dedicated recovery commands that authenticate a governance-created generation, start its nodes, produce blocks and complete landing without losing signing or transaction state.

**Architecture:** Share one proof-checked recovery origin between genesis, app, signer authorization, lander and the operator command. Preserve existing generation-zero formats; stage new generation directories and use a durable activation journal. Keep the pinned EL's unwind flag disabled and promote the recovered branch through its first ordinary Commit.

**Tech Stack:** Rust 1.95, Tokio/Clap/Alloy from the existing lockfile, Go 1.27.2 guarded FilePV signer, Python 3.11+ supervisor, stock CometBFT v0.40.0, pinned alethia-reth and real Etna test contracts.

**Spec:** [Approved design](../specs/2026-11-02-etna-recovery-command-design.md). Read it with this plan; SPEC/ACCEPTANCE at `b9f3eb367` provide normative recovery rules including #22327.

## Global Constraints

- Base runtime revision: PR #22280 `bce302828c2c35476726d271a3741e6eec0e2a6a`; recheck remote head before execution/push.
- Preserve registered keys, every prior FilePV HRS state, old Comet WAL/history and immutable signed landing bytes. Never migrate or rewrite them into a new generation.
- Keep stock CometBFT v0.40.0, protocol fixtures `1b14b634c8d213b5b30d8fc61ca6f6dcec344389` and EL `6ac93d4b38e1cd72b993cef1ed1dc2cb0affa7b4` unless an evidenced compatibility requirement needs an explicit change.
- Generation genesis: full chain_id, initial_height=c+1, genesis_time=R.timestamp, app_hash=ELHash(c); first Comet LastBlockID/LastCommit empty.
- Global epoch H(t)=1+t\*L and global K grid remain unchanged. Recovery committee targetEpoch=floor(c/L), snapshot R, effective c+1; old pending updates are discarded.
- Keep `--engine.allow-unwind-canonical-header` disabled. Building on canonical ancestor c may succeed while the old head stays above c.
- Require usable local c state. Full snapshot/app import, real proving/guests, Unzen migration, verifier-failure rollback and upgrade activation remain outside this change.
- Every production Rust symbol needs doc comments. Do not edit generated bindings/artifacts manually. Preserve no-default-feature protocol consumers.
- Use `just fmt && just clippy-fix` after coherent code batches and one final `just verify` after final fixes.
- Local controller manages only owned children. External services must be stopped first; uncertain ownership or signer state fails closed.
- Use Context7 for new library/API syntax; verify version-sensitive behavior against the pinned source. Use gh for GitHub.
- Existing isolated worktree is `/Users/cai/.codex/worktrees/etna-recovery-command/taiko-mono`; preserve unrelated `.build/` files. Administrative Git operations may need sandbox approval.

## Review Focus

1. Another recovery or landing occurs between prepare and activate: reject a superseded generation but retain the fixed origin when only the latest trust target advances (Tasks 1, 7, 9).
2. Recovery at S(t) discards the old pending committee: keep R's set active even across the next H(t) when that generation never ran its S(t) (Tasks 2, 3, 10).
3. Crash between new HRS creation and authority publication, or loss of an enrolled file: resume only provably unsigned staging; never recreate enrolled/uncertain HRS (Task 4).
4. Controller SIGKILL leaves children or a reused PID: participating leases prevent duplicate writers; report ownership uncertainty without killing another process (Tasks 8, 9).
5. An old landing transaction is mined or reorganized after recovery: retain its signed bytes/nonce and reconcile before issuing a new transaction from that account (Tasks 6, 10).

## File and Responsibility Map

All paths below are relative to repository root; package commands run in `packages/taiko-client-rs`.

| Files                                                                                                      | Responsibility                                                          |
| ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `crates/abci/src/recovery/{mod,types,verify,fetch}.rs` under the package                                   | Recovery witness, proof-checked fixed origin and own-L1 authentication  |
| `crates/abci/src/genesis/{doc,build}.rs`, `genesis.rs`                                                     | Versioned recovery app_state and nonzero-height genesis                 |
| `crates/abci/src/{store,schedule}.rs`, `app/{init,info,trust,checkpoint,validate,prepare,finalize,mod}.rs` | Origin-aware state, committees, bootstrap and execution                 |
| `tools/etna-signer/{authority,authority_store,domain_signer}.go`                                           | Private per-domain FilePV authority and crash-safe transition           |
| `tools/etna-signer/{gate,main}.go`, `script/etna_validator.py`                                             | Session authorization and configured-generation supervision             |
| `crates/lander/src/{l1,batch,history,types,runner}.rs`                                                     | Recovery-origin proof context and cross-generation nonce reconciliation |
| `crates/abci/src/ownership.rs`                                                                             | Private node/component leases shared by supported writers               |
| `bin/client/src/recovery/{mod,profile,plan,store,prepare,activate,process,status}.rs`                      | Operator state machine and foreground owned runtime                     |
| `bin/client/src/commands/abci_recover.rs`, `cli.rs`                                                        | Thin CLI parser/dispatch                                                |
| Existing unit/process tests, new `bin/client/tests/governance_recovery.rs`                                 | Behavioral, process, real-contract/Comet and pinned-EL acceptance       |

Do not create a new workspace crate or introduce another process orchestration framework.

---

### Task 1: Authenticate fixed recovery origins

**Files:** Create `packages/taiko-client-rs/crates/abci/src/recovery/{mod,types,verify,fetch}.rs`; modify package-relative `crates/abci/src/{lib,genesis,test_utils}.rs`, `l1/{layout,witness}.rs` and `test_utils/fixture.rs`.

**Interfaces:**

- Produce `RecoveryWitness` version 1: original `GenesisWitness`; finalized L1 header/Inbox proof; R header/Inbox proof; R committee witness; authenticated c EL header and required parent header.
- Produce serializable `RecoveryOrigin { generation, height, l1_number, l1_timestamp, el_hash, state_root, comet_hash, forced_cursor, committee }`, using u64 for bounded numbers, B256 for hashes and existing CommitteeState.
- `verify_recovery_witness(w: &RecoveryWitness, params: &ChainParams) -> Result<RecoveryOrigin, RecoveryError>` is pure; its docs explicitly require independent L1 canonicality/finality.
- `async authenticate_recovery<L: L1Source + ?Sized, E: Engine + ?Sized>(l1: &L, engine: &E, params: &ChainParams, generation: u64) -> Result<RecoveryWitness, RecoveryError>` obtains and checks canonical finalized facts.
- `async check_recovery_canonicality<L: L1Source + ?Sized>(l1: &L, params: &ChainParams, w: &RecoveryWitness) -> Result<(), RecoveryError>` rechecks a retained witness against current own-L1 generation/origin without changing its fixed c.
- RecoveryError distinguishes unavailable inputs, contradictory/invalid witnesses, configuration mismatch and superseded generation; callers preserve that distinction.

- [ ] **Step 1: Write failing origin tests** for c=6, generation=1, R=100, an original generation-zero landing at c, and R-selected committee targetEpoch=floor(c/L). Assert retained origin FI cursor is used even when current head/checkpoint has advanced. Tamper each origin word, landing hash/cursor, R header, committee root/config/domain and assert rejection. Exercise absent mapping versus legitimate c=0, repeated generation 2 at the same c, same-block recoveries, non-final R and latest checkpoint beyond c.

  Name the main unit case `recovery_witness_binds_fixed_origin_and_r_snapshot`:

  ```rust
  let origin = verify_recovery_witness(&witness, &params).unwrap();
  assert_eq!((origin.generation, origin.height, origin.l1_number), (1, 6, 100));
  assert_eq!(origin.forced_cursor, 3); // latest cursor is 8 in this fixture
  assert_eq!(origin.committee.record.cutoff_l1_block, 100);
  ```

- [ ] **Step 2: Run RED:** `cargo test -p abci --lib recovery`; require failure because the new API/behavior is absent, not an RPC fixture error.
- [ ] **Step 3: Implement the interfaces.** Decode exact proof slot sets and packed widths; authenticate R and origin through own finalized L1, including end-of-R registry state. Discovery reads/logs never authorize. Accept an older generation on c's retained landing record only through the authenticated origin case; do not require it to equal generation-1. Keep the existing strict generation-zero verifier.
- [ ] **Step 4: Run GREEN:** same targeted command, plus existing `cargo test -p abci --lib genesis` and layout/witness tests. Assert fetch/verification perform no Engine forkchoice/build.
- [ ] **Step 5: Commit** the proof-checked origin changes with `feat(taiko-client-rs): authenticate recovery origins`.

### Task 2: Preserve global committee timing across recovery

**Files:** Modify `packages/taiko-client-rs/crates/abci/src/{store,schedule}.rs`, `app/{validate,prepare,finalize}.rs`, related `app/tests/{proposal,prepare,finalize}.rs`; create `app/tests/recovery_schedule.rs` and register it.

**Interfaces:**

- Consume Task 1 RecoveryOrigin.
- Add `AppState.recovery: Option<RecoveryOrigin>` with serde default/skip-None. Continue emitting schema 13 for generation zero; schema 14 is exclusively fresh recovery state and requires this field. Never upgrade an existing file on load.
- `AppState.origin_height() -> u64`, `anchor_floor() -> u64`, `initial_committee_epoch() -> u64`, `committee_at(height: u64) -> Option<&CommitteeState>` centralize origin-aware selection.
- Retain `Schedule::h0() == 1` and global epoch arithmetic. Ordinary activation heights remain H(t); the initial recovery set is active from c+1.

- [ ] **Step 1: Write failing timing tests** with c=6/K=6 and L=8 (c=D(1), first block S(1)), L=7 (c=S(1)), and L=6 (c=H(1)-1). Assert R's set at c+1; for L=7 it remains active at H(1)=8 and through height 14, because S(1) was discarded; new S(2)=13 updates activate at H(2)=15. For L=8 updates at 7 activate at 9. Assert old pending sets never activate and R floors old-prefix D(t) snapshot selection.

  Name the L=7 case `recovery_schedule_keeps_initial_set_when_old_switch_was_discarded`:

  ```rust
  assert_eq!(state.committee_at(8), Some(&r_committee));
  assert_eq!(state.committee_at(14), Some(&r_committee));
  assert_eq!(state.committee_at(15), Some(&epoch_two_committee));
  ```

- [ ] **Step 2: Run RED:** `cargo test -p abci --lib recovery_schedule`.
- [ ] **Step 3: Implement origin-aware accessors and pruning.** Select the latest actually active authenticated record rather than assuming every global epoch has a new set. Missing rotation is allowed only where S(t) preceded this generation's first block; a missing update from a switch within this generation still rejects. Keep strict generation-zero rotation checks. Do not prune the still-active R set merely because global epoch advanced. Verify switch witnesses under S(t)'s own anchor root, and authenticate any D(t) prefix header used with its inherited anchor context.
- [ ] **Step 4: Run GREEN:** targeted schedule tests, existing schedule/committee/proposal tests and `cargo test -p abci --test etna_conformance`.
- [ ] **Step 5: Commit** with `feat(taiko-client-rs): retain recovery committee timing`.

### Task 3: Bootstrap and trust nonzero-height generations

**Files:** Modify `packages/taiko-client-rs/crates/abci/src/genesis.rs`, `genesis/{doc,build}.rs`, `app/{init,info,mod,trust,checkpoint}.rs`, `store.rs`; create `recovery/genesis.rs`, `app/tests/recovery_init.rs`; update existing info/trust/restart fixtures.

**Interfaces:**

- Add `BootstrapWitness::{Initial(GenesisWitness), Recovery(RecoveryWitness)}` and `decode_bootstrap_state(bytes: &[u8]) -> Result<BootstrapWitness, GenesisError>`.
- Keep legacy app_state JSON and legacy RLP byte-for-byte. Recovery uses the same witness JSON wrapper with disjoint `0x01 || rlp(RecoveryWitness)` bytes. Existing `decode_app_state` remains generation-zero-only.
- `async build_recovery_genesis<L: L1Source + ?Sized, E: Engine + ?Sized>(l1: &L, engine: &E, params: &ChainParams, generation: u64) -> Result<GenesisDoc, RecoveryError>`; document builder and InitChain independent authentication.
- `AppState.has_generation_commit() -> bool` is `last_height > origin_height()`. Origin EL c and its retained Comet hash are distinct from a new Comet commit.

- [ ] **Step 1: Write failing bootstrap tests** asserting initial_height=7 for c=6, time=R.timestamp, app_hash=ELHash(6), exact R members; Info height 0/empty hash before first generation Commit; repeated InitChain returns the same app hash after restart. After Commit(7), assert Info(7, ELHash(7)). Assert c=0 recovery works and c=6 does not reset the block-1 base-fee rule. Test bad versions/trailing bytes/config/domain/validators/time and original gen-zero bytes unchanged.

  Name the process-independent case `recovery_init_preserves_stock_zero_height_handshake`:

  ```rust
  assert_eq!(doc.initial_height, "7");
  assert_eq!(info_before.last_block_height.value(), 0);
  assert!(info_before.last_block_app_hash.as_bytes().is_empty());
  assert_eq!(info_after.last_block_height.value(), 7);
  ```

- [ ] **Step 2: Run RED:** `cargo test -p abci --lib recovery_init` and the named codec tests.
- [ ] **Step 3: Implement codecs, genesis and init.** Logical parent/last_height start at c, last new-generation Comet hash is empty, and initial trust uses the authenticated retained c Comet boundary. Save immutable recovery witness/context before publishing new state. First block requires an R-or-later finalized anchor and starts FI at origin cursor. Keep genesis deployment record immutable and old app formats rejected when structurally incompatible.
- [ ] **Step 4: Add trust regressions:** origin checkpoint succeeds without fabricating a Comet block at c; later targets require actual new-generation commits; initial target s>c stays untrusted until replay matches both hashes; authenticated supersession halts/revokes; old-generation header at c is allowed only as origin. Run `cargo test -p abci --lib` and doctests; every existing gen-zero/bootstrap test must pass.
- [ ] **Step 5: Commit** with `feat(taiko-client-rs): bootstrap recovered generations`.

### Task 4: Add durable per-domain signer authority

**Files:** Create `packages/taiko-client-rs/tools/etna-signer/{authority,authority_store,domain_signer}.go` and corresponding `_test.go`; modify `{main,gate}.go`, native interop/process tests, `crates/abci/src/app/trust.rs` and `server/trust_control.rs`.

**Interfaces:**

- Go `openAuthority(config authorityConfig) (*authority, error)` owns canonical key/legacy-state/authority-root locks; config binds full decimal L1/L2 ids, Inbox, native key and original state path.
- `(*authority).authorize(chain string, response *trustResponse) (types.PrivValidator, error)` validates the fresh private response and selects/creates only the authenticated domain's stock FilePV.
- `domainSigner` implements stock PrivValidator with PubKey available before enrollment and vote/proposal signing delegated to stock FilePV after the existing gate authorizes.
- Private control schema 2 adds `recovery_origin` summary with generation, c, R identity/time, EL/Comet hashes, FI cursor and committee hash. Keep schema 1 for legacy generation-zero callers; no schema-1 downgrade for recovered generations. Strict unknown/duplicate/null checks remain.
- New authority-mode flags identify root/deployment/generation explicitly. Once a legacy state has an authority marker, invoking the old standalone mode must refuse rather than bypass the registry.

- [ ] **Step 1: Write failing signer tests** for old HRS height 20 and recovered first height 7: new domain signs 7, old file stays byte-identical, retry returns identical signature and height regression within the same domain fails. Assert old generation denied after new watermark, generation 2 can follow 0 when 1 was skipped, full-width deployment IDs remain bound, and two state-path aliases cannot get two owners.

  Name the core case `TestRecoveryDomainRetainsLegacyHRS`:

  ```go
  if !bytes.Equal(legacyBefore, legacyAfter) { t.Fatal("legacy HRS changed") }
  if !bytes.Equal(signature, retrySignature) { t.Fatal("same-HRS retry changed") }
  if _, err := authority.authorize(oldChain, oldReady); err == nil {
      t.Fatal("superseded domain authorized")
  }
  ```

- [ ] **Step 2: Run RED:** `go test -mod=readonly -race ./...` in `tools/etna-signer`; isolate the new test names while iterating.
- [ ] **Step 3: Implement crash-safe authority persistence.** Explicitly enroll the original generation-zero HRS without rewriting it, only after its old owner is fenced. Validate signed-byte domain when present. Retain an external marker at the canonical original state path. Use a fsynced transition intent before exclusive creation of an unsigned new-domain state; fsync state/directory before atomically publishing the manifest+monotonic watermark. No signature can escape before publication.
- [ ] **Step 4: Add failure-injection/process tests** before/after intent, state creation, marker publication, manifest publication and first signature. An intent plus provably unsigned un-enrolled staging may finish; an enrolled file missing/corrupt, a missing authority registry behind an existing marker, ambiguous signing state or signed orphan must fail closed. Preserve originals on every failure. PubKey/Ping must work while new-domain trust is closed, without creating a replacement enrolled HRS. Run the full signer race suite and Rust trust-control tests.
- [ ] **Step 5: Commit** with `feat(taiko-client-rs): persist signer authority per generation`.

### Task 5: Supervise authenticated generations

**Files:** Modify `packages/taiko-client-rs/script/{etna_validator.py,start_etna_validator.sh}`, `tests/supervisor_test.py`, signer README and runtime image tests only for packaged flag compatibility.

**Interfaces:**

- Consume Task 4 control schema/authority flags and Task 3 recovery genesis.
- `Supervisor` derives expected generation from explicit configuration bound to the exact genesis chain ID; replace literal generation-zero conditions with that identity.
- Preserve existing same-generation denial restart, first-start PubKey/Ping handshake and durable terminal latch behavior.

- [ ] **Step 1: Write failing process tests** for generation 1 first start, closed-to-ready trust, timeout refusal/restart with unchanged HRS, generation 2 superseding generation 1, and restartAlways preserving an unrelated fatal latch. Assert shutdown reaps Comet before signer and stale-gen observations never cause an automatic generation switch.

  Add `test_generation_one_trust_restart_preserves_signing_state` with:

  ```python
  self.assertEqual(observation["generation"], 1)
  self.assertEqual(hrs_before_restart, hrs_after_restart)
  self.assertEqual(events.index("comet_reaped") < events.index("signer_stopped"), True)
  ```

- [ ] **Step 2: Run RED:** `python3 tests/supervisor_test.py` from the package.
- [ ] **Step 3: Implement configuration/observation updates.** Pass canonical authority paths and expected identity to the signer. Keep old generation-zero environment support. Do not reinterpret a generic terminal/safety latch as an expected supersession or clear old evidence.
- [ ] **Step 4: Run GREEN:** full supervisor tests and `just signer-test`; check native startup/runtime image parser tests keep the existing private-mount boundary.
- [ ] **Step 5: Commit** with `feat(taiko-client-rs): supervise recovered validators`.

### Task 6: Land from a recovery origin and retain nonce safety

**Files:** Modify `packages/taiko-client-rs/crates/lander/src/{types,l1,batch,history,runner}.rs`, `test_utils/{runtime_l1,runtime_runner}.rs`; add `src/test_utils/recovery.rs` when it keeps the fixtures focused. Keep existing journal schema/signed bytes intact.

**Interfaces:**

- Add `LandingSnapshot.recovery: Option<abci::recovery::RecoveryOrigin>` with serde default/skip-None so old journal projections remain identical. Require it for nonzero generations. Its source independently authenticates Task 1 facts. Never trust an app plan or Comet RPC as L1 authority.
- Existing BatchSource/Runner entry points remain. Centralize `LandingSnapshot.origin_height() -> u64`, `origin_comet_hash() -> B256`, `initial_committee() -> Option<&CommitteeState>`.
- On recovery, ordinary runner reconciliation owns account nonce before preparing new-generation work; public proof statement/blob formats stay unchanged.

- [ ] **Step 1: Write failing lander tests** for p=c at a recovery origin whose EL header/retained Comet record belong to an older generation, R's initial set with nonzero targetEpoch, first current-generation block empty LastCommit, later origin p>c, epoch-crossing and overlapping batches. Assert every new root is R-or-later and activeCommitteeSnapshot remains R until ordinary activation actually occurs.

  Name the main case `recovery_origin_uses_retained_boundary_and_r_committee`:

  ```rust
  assert_eq!(snapshot.origin_height(), 6);
  assert_eq!(snapshot.origin_comet_hash(), old_landing_comet_hash);
  assert_eq!(snapshot.initial_committee(), Some(&r_committee));
  assert_eq!(restored_signed_bytes, original_signed_bytes);
  ```

  Starting a recovered lander before Comet's first new Commit must wait for data,
  not reject its temporarily empty block store as malformed history.

- [ ] **Step 2: Run RED:** `cargo test -p lander --lib recovery` and named origin tests.
- [ ] **Step 3: Implement recovery-aware snapshot and batch verification.** Replace generation-zero assumptions at checkpoint/origin/initial-committee boundaries only. Authenticate full R-to-reference material. Do not infer the recovery set from the parent header's old extraData or genesisCutoff.
- [ ] **Step 4: Add journal regressions** for each existing state: Prepared, Signed-never-scheduled, Pending and Confirming. A generation change cannot mutate original proof/input/sidecar/signed bytes. Possibly broadcast work retains its nonce until canonical receipt/account reconciliation, including a receipt reorg; status waits instead of replacing. Test obsolete unsent work through normal allowed transitions and two instances sharing one sender/journal. Run `cargo test -p lander --all-features --lib`.
- [ ] **Step 5: Commit** with `feat(taiko-client-rs): land recovered generations safely`.

### Task 7: Prepare immutable operator recovery plans

**Files:** Create `packages/taiko-client-rs/bin/client/src/recovery/{mod,profile,plan,store,prepare,status}.rs` and `commands/abci_recover.rs`; modify `commands/mod.rs`, `cli.rs`, `error.rs`, `Cargo.toml`; extend `bin/client/tests/native_cli.rs` and package-relative `crates/abci/src/engine/{mod,rpc_engine}.rs` plus `test_utils/mocks.rs` for required nonmutating reads.

**Interfaces:**

- `RecoveryProfile` schema 1 has NodeRole validator/full-node, original component paths, private signer paths when validator, explicit endpoints/JWT/ChainParams file, executable argv/peers and optional lander config. Reject unknown keys, unsupported role combinations and paths overlapping signer/Comet mounts. Add serde/serde_json as existing workspace dependencies; no new framework.
- `RecoveryPlan` schema 1 binds profile digest, full deployment, RecoveryWitness/RecoveryOrigin, genesis bytes and immutable staged artifact hashes. `RecoveryPlan::id() -> B256` hashes canonical serialized fields excluding its own ID, secrets and nondeterministic timestamps. Private profiles stay mode 0600; reports are redacted.
- `async prepare<L: L1Source + ?Sized, E: Engine + ?Sized>(profile: &RecoveryProfile, generation: u64, root: &Path, l1: &L, engine: &E) -> Result<RecoveryPlan, RecoveryCommandError>` uses Tasks 1/3 and writes only staging/plan data.
- `RecoveryStore::{load_plan, publish_plan, load_journal, save_journal}` use bounded reads, exclusive staging and file+directory fsync. Introduce RecoveryCommandError for parsing, IO, busy ownership, plan mismatch, missing prerequisites and core/runtime errors.
- CLI prepare: `abci-recover prepare --profile <toml> --generation <n> --root <private-dir> [--json]`; status: `abci-recover status --root <dir> --plan <id> [--json]`.
- Add bounded Engine reads `finalized_header() -> Result<Option<Header>, EngineError>` and `historical_state_available(hash: B256) -> Result<bool, EngineError>` using the existing RPC provider. Every mock implements actual behavior, never default success. Task 9 consumes these reads.

- [ ] **Step 1: Write failing parser/store/prepare tests**: exact requested generation required; full nodes omit signer, validators require it; idempotent identical publication; changed witnesses/profile produce a new ID; mismatched existing plan cannot be overwritten; secrets never occur in JSON/text errors; malformed/oversize/truncated plans are rejected.

  Name the parser case `recovery_prepare_requires_explicit_target`:

  ```rust
  assert!(Cli::try_parse_from(["taiko-client", "abci-recover", "prepare",
      "--profile", "node.toml", "--generation", "1", "--root", "private"]).is_ok());
  assert!(Cli::try_parse_from(["taiko-client", "abci-recover", "prepare",
      "--profile", "node.toml", "--root", "private"]).is_err());
  ```

- [ ] **Step 2: Run RED:** `cargo test -p taiko-client --test native_cli recovery` and package binary unit recovery tests.
- [ ] **Step 3: Implement prepare.** Fetch/authenticate current generation and fixed origin, produce genesis, read header/ancestor/preliminary state information without Engine forkchoice/build, and report the actual-build check as pending activation. Create fresh per-generation config directories, preserving old stores and signer state. Avoid raw shell command assembly and secret argv echoing.
- [ ] **Step 4: Add race/status tests**: newer generation at second finality check aborts; later checkpoint in the same generation preserves c/genesis; missing material reports a specific prerequisite without an authorization result. Assert no child starts, no forkchoice/build occurs and no signer authority file changes. Run native CLI and recovery module tests.
- [ ] **Step 5: Commit** with `feat(taiko-client-rs): prepare authenticated recovery plans`.

### Task 8: Fence participating node writers and own child processes

**Files:** Create `packages/taiko-client-rs/crates/abci/src/ownership.rs`, `bin/client/src/recovery/process.rs`; modify `commands/{abci,lander}.rs`, `script/etna_validator.py` and relevant native/supervisor process tests. Reuse the existing std File locking pattern; promote the already locked libc version to a production dependency only if Unix process-group signaling needs it.

**Interfaces:**

- `acquire_activation(root: &Path, plan_id: B256) -> Result<ActivationLease, OwnershipError>` owns the private controller lock.
- `ComponentLease::acquire(paths: &ComponentPaths, grant: Option<&OwnerGrant>) -> Result<ComponentLease, OwnershipError>` protects each canonical app/supervisor/lander writer. OwnerGrant is an opaque private token, not signing authority. Standalone participating startup refuses a conflicting live controller; children only join its matching grant.
- `OwnedRuntime::spawn(role: ComponentRole, spec: &ProcessSpec) -> Result<(), RecoveryCommandError>` and `async stop(&mut self) -> Result<(), RecoveryCommandError>` retain actual tokio Child handles and private component leases.
- Shutdown order is Comet/signing supervisor, app, with lander stopped before account reuse. A component's existing supervisor keeps Comet-before-signer ordering. Never act on an unverified stale PID.

- [ ] **Step 1: Write failing process tests** for duplicate controllers, competing app/lander writers, canonical path aliases, externally running original services and SIGKILL with surviving children. A reused PID must not be signaled; live/uncertain ownership must report Busy, preserve files and create no duplicate process.

  Name the ownership case `recovery_controller_cannot_duplicate_live_owner`:

  ```rust
  let first = acquire_activation(root, plan_id).unwrap();
  assert!(acquire_activation(root, plan_id).is_err());
  drop(first);
  assert!(acquire_activation(root, plan_id).is_ok());
  ```

- [ ] **Step 2: Run RED:** native CLI recovery process tests and `python3 tests/supervisor_test.py`.
- [ ] **Step 3: Implement leases, owned spawning and bounded stop/reap.** Profile names exact old/current directories; verify old standalone control/listeners and original signer/journal locks are quiescent before mutation. External service control is an operator prerequisite, never a port/PID heuristic that grants permission. On orphaned live ownership, expose an actionable blocker until the owner is stopped; do not silently adopt/kill it.
- [ ] **Step 4: Run GREEN:** process tests, including cancellation and descriptor cleanup. Assert no registered key/HRS becomes readable from a Comet mount and no safety latch is deleted.
- [ ] **Step 5: Commit** with `feat(taiko-client-rs): fence recovery process ownership`.

### Task 9: Activate and resume the recovered runtime

**Files:** Create `packages/taiko-client-rs/bin/client/src/recovery/activate.rs`; extend recovery/{store,status,process}.rs, commands/abci_recover.rs and native CLI tests. Consume the Engine reads introduced in Task 7.

**Interfaces:**

- `ActivationPhase::{Prepared,Stopping,Isolated,ElOriginReady,Installed,Running,Trusted,Settled}` and version-1 ActivationJournal bind plan_id, observed components, active descriptor and blocker. Treat phases as observations, not authority.
- `async activate(profile: RecoveryProfile, root: PathBuf, plan_id: B256) -> Result<(), RecoveryCommandError>` stays in foreground and retains the Task 8 lease/runtime.
- `async probe_recovery_state<E: Engine + ?Sized>(engine: &E, params: &ChainParams, origin: &RecoveryOrigin, parent: &ParentInfo, anchor: &AnchorState) -> Result<(), RecoveryCommandError>` builds a non-promoted empty candidate with normal expected header/attributes on c, using authenticated R-or-later anchor context. It makes no consensus/FI inclusion claim about that candidate.
- RecoveryStatus reports plan/generation/c/R, phase, trust/commit/landing/finality progress and redacted blocker. It never supplies signature authorization.

- [ ] **Step 1: Write failing activation tests** for current-generation revalidation before and after lock acquisition, same-generation latest-target advancement, atomic descriptor publication and every durable phase interrupted/retried. Live mixed/foreign stores or contradictory completed phases must fail without starting writers.

  Name the pinned-semantics case `recovery_el_origin_ready_does_not_require_head_rewind`:

  ```rust
  assert_eq!(journal.phase, ActivationPhase::ElOriginReady);
  assert!(old_canonical_head > 6);
  assert_eq!(observed_build_parent, origin.el_hash);
  assert_ne!(status.phase, ActivationPhase::Settled);
  ```

- [ ] **Step 2: Run RED:** targeted client recovery activation tests.
- [ ] **Step 3: Implement ordered activation.** Fence/reap old writers, check c/finality/state, perform the actual Engine build probe with unwind disabled, fsync bundle then atomically publish active descriptor, start app then closed signer+Comet or full-node Comet, and optional journal-safe lander. Enroll legacy signing authority only after its owner stops. The pre-commit EL head may remain above c; the first new-generation Commit/newPayload/FCU performs branch promotion.
- [ ] **Step 4: Implement resume/status monitoring.** Report Trusted only from exact private session observations, and Settled only after own finalized L1 authenticates a new-generation landing above c. Keep uncertain old-account jobs waiting while node production proceeds. A safety halt preserves evidence; a new generation invalidates the old plan. Cancellation and retry never reopen old signing domains. After Settled continue supervising owned children until normal shutdown.
- [ ] **Step 5: Run GREEN:** native activation/process tests with fault injection around side effects, fsync/rename, private trust, first Commit and landing observation. Verify probe rejects pruned state and authentic contradictions without unsafe flags/raw DB changes. Commit with `feat(taiko-client-rs): activate and resume governance recovery`.

### Task 10: Prove the complete command on real contracts, Comet and pinned EL

**Files:** Create `packages/taiko-client-rs/bin/client/tests/governance_recovery.rs` plus focused support modules under `bin/client/tests/support/recovery/`; extend `crates/test-harness/src/consensus.rs` and existing support modules only for reusable owned-resource fixtures; update `tests/entrypoint.sh`/nextest configuration if required to include the new tests in full verification.

**Interfaces:**

- Test fixture methods `recover_and_finalize(...)`, `prepare_command(...)`, `activate_command(...)`, `wait_committed(height)` and `wait_finalized_landing_after(c)` execute real protocol calls and CLI processes. Test-only helpers may choose argument structs; production interfaces from earlier tasks remain unchanged.
- Keep normal runtime `ProofProvider` and journal path; explicitly use the disposable MockVerifier/dummy provider in the test profile, not a direct bypass of lander validation.

- [ ] **Step 1: Write the failing main scenario**: run native-key stock Comet validators, create a real landing at c=6, continue above c, execute finalized governance recover, run prepare/activate, require first new commit at 7 and a real land transaction from the recovered CLI that finalizes with the expected generation/FI/committee snapshot. The EL initially remains canonically above c with unwind disabled; first new Commit replaces its suffix and survives EL/app/Comet restart.

  Name the Docker scenario `governance_recovery_command_produces_and_lands`:

  ```rust
  assert_eq!(first_comet.header.height.value(), 7);
  assert!(first_comet.header.last_block_id.is_none());
  assert_eq!(finalized_landing.generation, 1);
  assert!(finalized_landing.height > 6);
  assert_eq!(canonical_restarted_hash, recovered_committed_hash);
  ```

- [ ] **Step 2: Run RED:** `just test governance_recovery`; require a missing recovery behavior failure, not an image/port/setup failure. Preserve logs.
- [ ] **Step 3: Complete fixture integration and fix only evidenced missing behavior.** No test directly writes app/Comet/contract storage to manufacture a recovery or settlement result. Keep the primitive ContractFixture/ContractConsensus lifecycle and owned-label cleanup.
- [ ] **Step 4: Add the bounded scenario matrix**: empty lists/exclusions/FI blanking/combined lists; excluded key and standby membership; old pending committee cancellation; L=8/7/6 boundaries at c=6; c=0; generation 2 recovering at the same c; delayed full-node join after a later checkpoint; first FI trial; epoch/overlap landing; old pending transaction receipt/reorg; kill/restart at first InitChain, signature, Commit and broadcast. Assert unchanged archived HRS/WAL/signed bytes, current private trust, no old-domain signatures and no duplicate live owners.
- [ ] **Step 5: Run GREEN:** new scenarios through `just test`, then affected existing native multi-validator/restart/lander scenarios. Commit with `test(taiko-client-rs): exercise governance recovery end to end`.

### Task 11: Document, verify and update the existing PR

**Files:** Update `packages/taiko-client-rs/README.md`, `CHANGELOG.md`, `tools/etna-signer/README.md`, client AGENTS guidance only where assumptions changed, and add `docs/governance-recovery.md` inside the package for the runbook/profile/status examples. Preserve the design/plan as implementation references.

**Interfaces:**

- Publish exact profile/CLI examples for validator, full node and separate lander, external service stop prerequisite, private authority enrollment/retention, waiting old nonce and interrupted activation.
- PR #22280 description states the resulting behavior, actual validation and explicit dummy-proof/local-state scope. Remove obsolete blanket claims that governance recovery is excluded or all runtime paths are generation-zero-only.

- [ ] **Step 1: Write/check runbook examples** against CLI parser/process tests. Require prepare/activate/status commands to parse exactly as documented, secret fields to stay redacted, and observed command output to match the machine-readable schema. Document unresolved ownership/HRS/safety evidence as operator repair, never a reset instruction.
- [ ] **Step 2: Run final formatting/fixes:** `just fmt && just clippy-fix`. Inspect the resulting diff; do not hand-edit generated bindings or unrelated files. Then run one final `just verify` from the package and retain its full log. Every required lane must pass; mock results cannot claim production proving/resource acceptance.
- [ ] **Step 3: Obtain whole-branch review** through the execution workflow's required review skill. Supply the approved design, this plan, exact base/head and verification log. Resolve substantive findings, rerun affected checks and final verification when changes justify it. Keep spec/model divergence updates explicit rather than weakening vectors.
- [ ] **Step 4: Commit final docs/fixes** with a conventional subject. Recheck remote PR head and fetch it. If it advanced, integrate normally and rerun affected verification; never force-push over another contributor.
- [ ] **Step 5: Update PR #22280.** Push verified commits to `feat/taiko-client-rs-abci` without merging the PR. Write the multiline PR description to a temporary file and use `gh pr edit --body-file`. Attach the existing PR using codex_app attach_artifact, and report actual tests plus any remaining production acceptance separately.

## Self-review and coverage

- Proof/origin rules and changed-finality races -> Task 1; global schedule and skipped switches -> Task 2.
- Genesis, Info, first-block ancestry, latest-target trust, FI origin -> Task 3.
- Per-domain signing, one-time enrollment, monotonic watermark and crash windows -> Task 4; supported restart/latches -> Task 5.
- Origin proof boundaries, historical committees, unchanged jobs/nonces -> Task 6.
- Private/redacted profiles, immutable prepare and bounded files -> Task 7; process ownership and external stop boundary -> Task 8.
- All activation phases, EL state probe/first branch promotion, resume and finality status -> Task 9.
- Real contracts/Comet/EL, command-level final settlement and fault/boundary matrix -> Task 10.
- Runbooks, required verification, final review and existing-PR update -> Task 11.

All five Review Focus conditions have explicit owning tests. Later-task interfaces
refer to the exact types/functions introduced above. Local-state and dummy-proof
boundaries match the approved design; no production snapshot/proving completion
is implied. The tasks form one dependent recovery feature, so separating them
into independently shipped projects would leave incomplete startup paths.

## Execution handoff

The user approved the full design on 2026-11-02. This implementation plan still
requires the writing-plans handoff review and an execution-method choice before
runtime changes. Recommend subagent-driven execution: origin/app, private signer,
process ownership and transaction-journal changes each warrant an independent
review gate despite sharing the recovery identity contract. Native execution is
the lower-overhead alternative with one fresh whole-branch review at the end.
