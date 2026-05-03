# Rust Preconfirmation Reorg Head L1 Origin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reset `head_l1_origin` after Rust event sync proves a proposal log is orphaned, so preconfirmation ingress is not blocked by an orphaned confirmed boundary.

**Architecture:** Keep the fix in `crates/driver/src/sync/event.rs`, where orphaned L1 proposal logs are already detected. Add pure helper functions for rollback decisions, then call a best-effort async reconciler from the existing orphaned-log branch in `process_log_batch`. Do not change `whitelist-preconfirmation-driver` gossip, cache, or status code.

**Tech Stack:** Rust, Tokio, Alloy providers/RPC, existing `driver` crate unit tests, `just fmt`, `just clippy-fix`, `just test`.

---

## File Structure

- Modify: `crates/driver/src/sync/event.rs`
  - Add pure helper functions near `resolve_confirmed_sync_probe`.
  - Add one private async helper on `EventSyncer<P>` near `is_permanently_orphaned_proposal_log`.
  - Call the async helper from the `Ok(true)` orphaned-log branch in `process_log_batch`.
  - Add focused unit tests in the existing `#[cfg(test)] mod tests`.
- Reference only: `docs/superpowers/specs/2026-05-04-rust-preconf-reorg-head-l1-origin-design.md`
  - Confirms scope, non-goals, and affected `WLP-INV` invariants.

### Task 1: Add Pure Rollback Decision Helpers

**Files:**

- Modify: `crates/driver/src/sync/event.rs`

- [ ] **Step 1: Add failing pure-helper tests**

Add these tests inside the existing `#[cfg(test)] mod tests` in `crates/driver/src/sync/event.rs`, near the confirmed-sync helper tests:

```rust
    #[test]
    fn reorg_head_l1_origin_action_resets_only_when_head_is_ahead() {
        assert_eq!(
            resolve_reorg_head_l1_origin_action(Some(15), Some(12)),
            HeadL1OriginReorgAction::Reset { previous_head: 15, rollback_block: 12 }
        );
        assert_eq!(
            resolve_reorg_head_l1_origin_action(Some(12), Some(12)),
            HeadL1OriginReorgAction::Noop
        );
        assert_eq!(
            resolve_reorg_head_l1_origin_action(Some(11), Some(12)),
            HeadL1OriginReorgAction::Noop
        );
        assert_eq!(
            resolve_reorg_head_l1_origin_action(None, Some(12)),
            HeadL1OriginReorgAction::Noop
        );
        assert_eq!(
            resolve_reorg_head_l1_origin_action(Some(15), None),
            HeadL1OriginReorgAction::Noop
        );
    }

    #[test]
    fn canonical_reorg_rollback_block_resolves_zero_target_to_genesis() {
        assert_eq!(resolve_canonical_reorg_rollback_block(0, None), Some(0));
        assert_eq!(resolve_canonical_reorg_rollback_block(0, Some(99)), Some(0));
    }

    #[test]
    fn canonical_reorg_rollback_block_uses_batch_mapping_for_nonzero_target() {
        assert_eq!(resolve_canonical_reorg_rollback_block(7, Some(12)), Some(12));
        assert_eq!(resolve_canonical_reorg_rollback_block(7, None), None);
    }
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```sh
cargo test -p driver reorg_head_l1_origin_action -- --nocapture
cargo test -p driver canonical_reorg_rollback_block -- --nocapture
```

Expected:

```text
error[E0425]: cannot find function `resolve_reorg_head_l1_origin_action` in this scope
error[E0433]: failed to resolve: use of undeclared type `HeadL1OriginReorgAction`
error[E0425]: cannot find function `resolve_canonical_reorg_rollback_block` in this scope
```

- [ ] **Step 3: Add the pure helpers**

Add this code near `resolve_confirmed_sync_probe` in `crates/driver/src/sync/event.rs`:

```rust
/// Reconciliation action for an orphaned proposal's stale `head_l1_origin` pointer.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum HeadL1OriginReorgAction {
    /// Reset the execution engine's confirmed boundary to the rollback block.
    Reset {
        /// Previously stored `head_l1_origin` block id.
        previous_head: u64,
        /// Canonical block id that should become the confirmed boundary.
        rollback_block: u64,
    },
    /// Leave the execution engine's confirmed boundary unchanged.
    Noop,
}

/// Resolve the canonical rollback block for a reorged proposal target.
fn resolve_canonical_reorg_rollback_block(
    target_proposal_id: u64,
    target_block: Option<u64>,
) -> Option<u64> {
    if target_proposal_id == 0 { Some(0) } else { target_block }
}

/// Decide whether an orphaned proposal requires rewinding `head_l1_origin`.
fn resolve_reorg_head_l1_origin_action(
    current_head_l1_origin: Option<u64>,
    rollback_block: Option<u64>,
) -> HeadL1OriginReorgAction {
    match (current_head_l1_origin, rollback_block) {
        (Some(previous_head), Some(rollback_block)) if previous_head > rollback_block => {
            HeadL1OriginReorgAction::Reset { previous_head, rollback_block }
        }
        _ => HeadL1OriginReorgAction::Noop,
    }
}
```

- [ ] **Step 4: Run helper tests and verify they pass**

Run:

```sh
cargo test -p driver reorg_head_l1_origin_action -- --nocapture
cargo test -p driver canonical_reorg_rollback_block -- --nocapture
```

Expected:

```text
test result: ok.
```

- [ ] **Step 5: Commit helper tests and helpers**

Run:

```sh
git add crates/driver/src/sync/event.rs
git commit -m "test(driver): pin reorg head l1 origin decisions"
```

### Task 2: Reconcile `head_l1_origin` From Orphaned Proposal Handling

**Files:**

- Modify: `crates/driver/src/sync/event.rs`

- [ ] **Step 1: Extend the existing orphaned-log test to prove reconciliation is non-fatal**

In `process_log_batch_skips_orphaned_proposal_log_and_continues_batch`, add a third L1 mock response after the existing orphaned-log recheck responses:

```rust
        asserter.push_success(&Option::<RpcBlock<TxEnvelope>>::None);
        asserter.push_success(&2u64);
        asserter.push_failure_msg("core state unavailable");
```

This pins the best-effort contract: reconciliation RPC failure must not stop the later canonical log in the same batch.

- [ ] **Step 2: Run the existing test and verify it still passes before implementation**

Run:

```sh
cargo test -p driver process_log_batch_skips_orphaned_proposal_log_and_continues_batch -- --nocapture
```

Expected:

```text
test result: ok. 1 passed
```

The test still passes before implementation because the extra mock response is unused until the reconciler is added.

- [ ] **Step 3: Add the async reconciliation helper**

Add this method inside the existing `impl<P> EventSyncer<P>` block, directly after `is_permanently_orphaned_proposal_log`:

```rust
    /// Best-effort reset for stale `head_l1_origin` after a proposal log is proven orphaned.
    #[instrument(skip(self), level = "debug")]
    async fn reconcile_head_l1_origin_after_orphaned_proposal(
        &self,
        orphaned_proposal_id: u64,
        orphaned_l1_block_hash: B256,
        orphaned_l1_block_number: Option<u64>,
        orphaned_transaction_hash: Option<B256>,
    ) {
        let core_state = match self.rpc.shasta.inbox.getCoreState().call().await {
            Ok(core_state) => core_state,
            Err(err) => {
                warn!(
                    ?err,
                    orphaned_proposal_id,
                    orphaned_l1_block_number,
                    orphaned_l1_block_hash = ?orphaned_l1_block_hash,
                    orphaned_transaction_hash = ?orphaned_transaction_hash,
                    "failed to read core state while reconciling orphaned proposal head l1 origin"
                );
                return;
            }
        };
        let target_proposal_id = core_state.nextProposalId.to::<u64>().saturating_sub(1);

        let target_block = if target_proposal_id == 0 {
            None
        } else {
            match self.rpc.last_block_id_by_batch_id(U256::from(target_proposal_id)).await {
                Ok(block_id) => block_id.map(|block_id| block_id.to::<u64>()),
                Err(err) => {
                    warn!(
                        ?err,
                        orphaned_proposal_id,
                        target_proposal_id,
                        orphaned_l1_block_number,
                        orphaned_l1_block_hash = ?orphaned_l1_block_hash,
                        orphaned_transaction_hash = ?orphaned_transaction_hash,
                        "failed to resolve canonical rollback block for orphaned proposal"
                    );
                    return;
                }
            }
        };
        let rollback_block =
            resolve_canonical_reorg_rollback_block(target_proposal_id, target_block);

        if target_proposal_id > 0 && rollback_block.is_none() {
            warn!(
                orphaned_proposal_id,
                target_proposal_id,
                orphaned_l1_block_number,
                orphaned_l1_block_hash = ?orphaned_l1_block_hash,
                orphaned_transaction_hash = ?orphaned_transaction_hash,
                "canonical rollback block missing; skipping orphaned proposal head l1 origin reset"
            );
            return;
        }

        let current_head = match self.rpc.head_l1_origin().await {
            Ok(origin) => origin.map(|origin| origin.block_id.to::<u64>()),
            Err(err) => {
                warn!(
                    ?err,
                    orphaned_proposal_id,
                    target_proposal_id,
                    rollback_block,
                    orphaned_l1_block_number,
                    orphaned_l1_block_hash = ?orphaned_l1_block_hash,
                    orphaned_transaction_hash = ?orphaned_transaction_hash,
                    "failed to read head l1 origin while reconciling orphaned proposal"
                );
                return;
            }
        };

        let HeadL1OriginReorgAction::Reset { previous_head, rollback_block } =
            resolve_reorg_head_l1_origin_action(current_head, rollback_block)
        else {
            debug!(
                orphaned_proposal_id,
                target_proposal_id,
                current_head_l1_origin = ?current_head,
                rollback_block,
                "head l1 origin does not need orphaned proposal reconciliation"
            );
            return;
        };

        if let Err(err) = self.rpc.set_head_l1_origin(U256::from(rollback_block)).await {
            warn!(
                ?err,
                orphaned_proposal_id,
                target_proposal_id,
                previous_head,
                rollback_block,
                orphaned_l1_block_number,
                orphaned_l1_block_hash = ?orphaned_l1_block_hash,
                orphaned_transaction_hash = ?orphaned_transaction_hash,
                "failed to reset head l1 origin after orphaned proposal"
            );
            return;
        }

        warn!(
            orphaned_proposal_id,
            target_proposal_id,
            previous_head,
            rollback_block,
            orphaned_l1_block_number,
            orphaned_l1_block_hash = ?orphaned_l1_block_hash,
            orphaned_transaction_hash = ?orphaned_transaction_hash,
            "reset head l1 origin after orphaned proposal"
        );
    }
```

- [ ] **Step 4: Call the helper from the orphaned-log branch**

In the `Ok(true)` branch inside `process_log_batch`, insert the reconciliation call after the orphaned-proposal counter and before the existing warning:

```rust
                                syncer
                                    .reconcile_head_l1_origin_after_orphaned_proposal(
                                        proposal_id,
                                        block_hash,
                                        log.block_number,
                                        log.transaction_hash,
                                    )
                                    .await;
```

The branch should now have this shape:

```rust
                            Ok(true) => {
                                counter!(DriverMetrics::EVENT_ORPHANED_PROPOSAL_LOGS_TOTAL)
                                    .increment(1);
                                syncer
                                    .reconcile_head_l1_origin_after_orphaned_proposal(
                                        proposal_id,
                                        block_hash,
                                        log.block_number,
                                        log.transaction_hash,
                                    )
                                    .await;
                                warn!(
                                    ?err,
                                    block_number = log.block_number,
                                    block_hash = ?block_hash,
                                    transaction_hash = ?log.transaction_hash,
                                    "skipping permanently orphaned proposal log",
                                );
                                Ok(ProposalLogResult::SkippedOrphaned)
                            }
```

- [ ] **Step 5: Run focused tests**

Run:

```sh
cargo test -p driver reorg_head_l1_origin_action -- --nocapture
cargo test -p driver canonical_reorg_rollback_block -- --nocapture
cargo test -p driver process_log_batch_skips_orphaned_proposal_log_and_continues_batch -- --nocapture
```

Expected:

```text
test result: ok.
```

- [ ] **Step 6: Commit the reconciliation implementation**

Run:

```sh
git add crates/driver/src/sync/event.rs
git commit -m "fix(driver): reset head l1 origin after proposal reorg"
```

### Task 3: Final Verification

**Files:**

- Verify: `crates/driver/src/sync/event.rs`
- Verify: `docs/superpowers/specs/2026-05-04-rust-preconf-reorg-head-l1-origin-design.md`

- [ ] **Step 1: Run formatting and lint fix**

Run:

```sh
just fmt && just clippy-fix
```

Expected:

```text
Finished
```

If `just clippy-fix` modifies `crates/driver/src/sync/event.rs`, inspect the diff before continuing:

```sh
git diff -- crates/driver/src/sync/event.rs
```

- [ ] **Step 2: Run full test verification**

Run:

```sh
just test
```

Expected:

```text
PASS
```

The command may run Docker-backed integration tests. If ports `18545` or `28545-28551` are occupied, stop the conflicting local process and rerun the command.

- [ ] **Step 3: Inspect final diff scope**

Run:

```sh
git status --short
git diff --stat HEAD~2..HEAD
git diff -- crates/driver/src/sync/event.rs
```

Expected:

```text
Only crates/driver/src/sync/event.rs changed for implementation commits.
```

- [ ] **Step 4: Commit any formatter changes**

If `just fmt && just clippy-fix` changed files after Task 2, run:

```sh
git add crates/driver/src/sync/event.rs
git commit -m "chore(driver): format reorg head l1 origin fix"
```

If there are no formatter changes, do not create an empty commit.
