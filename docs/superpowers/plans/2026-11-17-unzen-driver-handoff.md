# Unzen driver restoration and Etna handoff

**Goal:** Restore the Rust Unzen sync/derivation driver on PR22280 and hand its execution chain to Etna ABCI at S+1.
**Architecture:** Keep Unzen sync/derivation and Etna ABCI as staged runtimes sharing one EL. Authenticate the finalized Unzen origin, drain the old runtime, then initialize Etna with exclusive Engine ownership.
**Spec:** packages/protocol/docs/etna/SPEC.md, SWITCH.md, ANCHORLESS.md; parent-chat approved implementation checklist.
**Constraints:** User excludes DAO and tests: no new test work or test runs. Preserve restored existing sources. Verify with formatting, cargo check and clippy. Restore from main d18357214fab30ea512ae9858a11699806d72ba1 onto PR head df307bf411ef59b93fc7bdbee318df4f9d99e71d. EL248 reference efc3c162ad54760a84c561da03f44af9c2adffdd. Preserve WLP-INV-001..010, generated bindings and Rust docs.

## Task 1: Restore Unzen libraries and runtime

- [x] Restore driver and required protocol/RPC/bindings while retaining Etna APIs.
- [x] Restore driver CLI/flags and workspace dependencies, adapt Engine V3/V5/V4.
- [x] Verify production compilation.

## Task 2: Generalize ABCI bootstrap

- [x] Accept authenticated nonzero S, initial_height=S+1 and zero Comet/valstate start records.
- [x] Keep generation0 committee targetEpoch=0 and global epochs with next actual switch above S.
- [x] Authenticate S/hash/root/time/Anchor implementation against own L1/EL; permit post-landing snapshot joins.

## Task 3: Coordinate handoff

- [x] Bind the driver-derived S to finalized own-L1 proposal closure and EL state.
- [x] Drain old Engine writers, wait R0 finality, then start ABCI at S+1.
- [x] Preserve fixed genesis, signer HRS and restart stages; update operator docs.
- [x] Compile/static-check and request independent review of the combined diff.

## Review focus

Finalized-L1 branch changes; custom-table gaps after beacon sync; nonzero start special hashes; committee0 versus global epochs; restart between stages; exclusive Engine writes.

## Decisions and progress

- User explicitly approved implementation, optional subagents, and no DAO/test work.
- Native managed worktree isolates original checkout and its unrelated untracked files.
- Library and ABCI implementation delegated on disjoint files; EL compatibility review is read-only.

- Driver/protocol/RPC and ABCI production check plus strict clippy/docs passed individually.
- Published scanner/provider target Alloy1; vendor compatibility copies retain production algorithms and licenses, change Alloy manifest plus one unused import.
- EL248 already provides coexistence fixes; pin updated without EL source edits.
- Parent CLI fixes shared-mount lease placement, missing-data retries and unsupported Unzen timestamp override.
- Pending combined CLI compilation, formatting/static checks and independent review.

- Independent review found two P1s in startup shortcut: per-block batch metadata can represent partial proposals, and orphaned pre-cutoff metadata must trigger replay rather than fatal exit.
- Fix in progress by driver worker: durable fsynced completion receipt after full proposal completion, exact deployment/proposal/S revalidation, full replay without evidence; finalized Unzen terminal proof is also a valid completion source. CLI receipt path under shared engine-control-dir. This is necessary because Etna may start before the final Unzen proof and cannot safely rewind to a pre-S parent on restart.
- Combined production cargo check and strict clippy/docs passed before review fix. Generated bindings excluded from formatter/doc lint and restored byte-for-byte; production importer lockfile pin validated with locked metadata.

## Final status

Completed the requested driver/bootstrap handoff stage in this managed worktree. No DAO implementation or test authoring/execution. Broader nonzero-S lander/proving deployment and import integration remain subsequent checklist work.

Final verification:

- just fmt and just fmt-check: passed, with generated/vendor source excluded through pinned-nightly rustfmt ignore configuration.
- cargo +1.99.0 check --workspace --lib --bins --locked: passed.
- cargo +1.99.0 clippy --workspace --exclude bindings --exclude test-harness --lib --bins --locked --no-deps -- -D warnings -D missing_docs -D clippy::missing_docs_in_private_items: passed.
- All six generated binding files remain byte-identical to main d183572.
- Production EL import helper locked metadata resolves at efc3c162.
- Independent review P1 partial-proposal completion and stale reorg metadata fixed; focused re-review also confirmed the FCU-build-before-import crash subcase addressed, with no direct regression found.
- Upstream proc-macro-error2 emits a future-compatibility notice; production checks exit zero.

This stage is based on PR22280 head df307bf41. The parent chat publishes its reviewed commit to PR22280 before continuing the lander phase. The original checkout and alethia-reth checkout remain unchanged.

- Pre-push integration correction: STOR-B-9 and EtnaInbox.\_writeStart set the start landing parent to S; ABCI trust and retained-origin validation now compare parent with S rather than zero.
- Repository pre-commit prettier wrapper cannot install the unchanged pnpm lockfile due to legacy dependency aliases. The exact Prettier 3.2.5 formatter is run directly from the available cache; only that wrapper hook is excluded for this commit.
