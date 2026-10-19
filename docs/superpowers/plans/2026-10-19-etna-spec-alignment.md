# Etna remaining spec alignment implementation plan

> For agentic workers: use superpowers:subagent-driven-development. The user approved policy and updates to existing PRs/pages; do not pause for repeat authorization.

Goal: implement the four approved behavioral rules and synchronize both specs' exact encoding.
Architecture: pure shared committee/FI rules; bounded active-stake event accounting; node-local latest-checkpoint trust with a real signer boundary. Use stock CometBFT/FilePV and new-genesis rollout only.
Tech Stack: Rust1.95, Solidity0.8.30/Foundry, Go with CometBFT v0.40.0, Notion.
Spec: ../specs/2026-10-19-etna-spec-alignment-design.md; builder review /private/tmp/etna-alignment-builder-review.md (no blocking questions).

## Global constraints

- Client base cbf3b3dd4c93e70d9ea99e80c9cf27d5ba46b0ef; protocol base e2ebc10a86a279096eb754100d5ed7ec51fbae43.
- Config domain ETNA_PARENT_ANCHOR_V4, eleven words; APP_VERSION4. Envelope6/payload6/V10/journal12/record2/rewardV1 structural formats unchanged; no signed job rewrite.
- No full governance recovery, real guest, slashing, Unzen or populated-registry migration.
- Preserve existing node-facing storage slots and entry/checkpoint encodings, withdrawal gates and actual signing committee snapshot proof binding.
- Deterministic historical block validity never depends on moving latest-checkpoint or wall clock. Trust/readiness/signing are separate local state.
- Workers are not alone; respect ownership and coordinate shared files. No worker external PR/Notion writes or pushes. Normal local commits only after focused evidence; parent integrates/reviews/pushes.

## Review focus

1. Top-N holds seats before heartbeat removal; empty result halts and no attacker below cutoff backfills.
2. Low fee cap classification only affects due skip; matching tx0 inclusion and pre-due rules preserved, errors never prove skip.
3. Active stake transitions exactly at effective blocks, withdrawal cleanup and slot reuse are neutral, full-width and near-cap gas/state bounds hold.
4. Trust checkpoint is authenticated and hash-linked to durable committed state; replay possible while closed, mismatch never becomes trusted, no stale-session Ready race.
5. Actual signer denies all sign paths including nil/locked/retained requests while closed; reconnect/app restart fails closed, no FilePV reset/fallback, stock catch-up works at high voting power.

## Task A: protocol active-stake churn and shared config provenance

Owner: protocol worktree /Users/davidcai/.codex/worktrees/etna-liveness-protocol/taiko-mono.
Files: registry implementation/interface, new LibStakeSchedule, registry/library tests and invariant models, protocol README/layout, V4 config references/vectors/generator and directly affected protocol tests.

- [ ] Add independent active-sum regressions and RED pending registration/early exit denominator cases before implementation.
- [ ] Implement appended two unsigned Fenwick trees and current-only activeStake; subtract events on matured withdrawal; preserve legacy bondedStake and queues/slot offsets.
- [ ] Exercise full-width/sentinel/index boundaries and fix only necessary mathematical overflow intermediates with checked equivalents.
- [ ] Upgrade V3 config domain references toV4 in protocol deployment/helper/tests and vector generator. Regenerate vectors, never hand-edit generated JSON. Coordinates, record tags and format stay otherwise unchanged.
- [ ] Run baseline/focused/full protocol tests, 256-depth50 invariants including near-cap, Python genesis, gas budgets, normalized old-slot layout and ABI addition checks. Commit intended files; report exact results.

## Task B: client pure heartbeat/FI rules

Owner: client committee/mod.rs/tests, forced.rs/tests and relevant FI/committee fixture/test consumers. Own config domain V4 and same shared vector generator/copy in client branch; root will replace with canonical protocol generator output during final integration.

- [ ] RED no-backfill test nmax1 and partial seats; change selection to base eligibility->dedup->rank/cap->heartbeat->set ordering/power.
- [ ] RED due low-fee skip, equality at1gwei, pre-due unchanged, included low-fee allowed and eligible singleton required; implement shared pure fee eligibility helper while retaining generic canonical decoder.
- [ ] Fix existing eligible FI fixtures to use genuine>=1gwei caps, preserving original test purpose. Do not weaken assertions or reinterpret RPC errors.
- [ ] Update V4 config constant/vectors; test old opening rejection. No App/mod.rs edits (Task C owns APP_VERSION).
- [ ] Focused unit and mutation checks; format/Clippy at coordinated intervals, commit owned files. Full suite only after integration.

## Task C: app latest-checkpoint trust and private control

Owner: client abci app/{mod,info,init,finalize,trust}, server lifecycle, store path accessor if needed, trust unit tests and common MockL1/Engine trust support. Own APP_VERSION4, not pure committee/FI files or harness.

- [ ] RED authentic target/mismatch/ancestry/session tests.
- [ ] Authenticate latest finalized Inbox proof at pinned L1 root. Startup/restart begins closed; transient proof/history failure retries with bounded I/O, never opens or fabricates a match.
- [ ] Permit actual Info and historical Init/Finalize/Commit progress; exact target mismatch before settle, readiness only after durable save and refreshed checkpoint/current ancestry check. Stored head beyond target must prove contiguous parentHash linkage. Do not use EL presence alone.
- [ ] Add trust-ready/syncing/target/trusted-head status separate from deterministic AppState/app_hash. Safe FCU while closed uses proven checkpoint/genesis, not candidate head. Keep historical finalized ancestry fence.
- [ ] Serve local Unix control socket <store-dir>/checkpoint-trust.sock (0600 in controlled directory), bounded JSON-lines protocol described below. BeginSession closes immediately, increments session, schedules refresh without waiting on replay; CheckSession returns read-only current snapshot. Old async result cannot publish into new session. Revoke on app/server termination/fatal error. No public ABCI reset endpoint.
- [ ] Background/request-boundary retries must permit bootstrap to become ready after temporary L1 failure even when no blocks can yet be signed. Avoid blocking Info waiting for a future height or control reads waiting for the sequential worker.
- [ ] Run focused tests, report integration API and commit owned files; coordinate mocks edits with B.

## Task D: actual guarded signer and runtime/harness integration

Owner: tools/etna-signer standalone Go module, its script/justfile/Docker packaging, test-harness signer lifecycle/boot/Comet homes, Docker checkpoint_trust tests, CLI runtime docs. Coordinate with C using private control contract; no C-owned app edits.

- [ ] Use official CometBFT0.40.0 FilePV/SignerServer; validate existing key/state files, never create/reset actual signing state automatically.
- [ ] Wrap SocketDialer: after connecting to Comet, BeginSession against local control before returning transport; every SignVote/SignProposal fresh CheckSession for same session/chain and Ready, then stock handler. PubKey/Ping ungated. Timeout/malformed/unavailable/mismatch denies with signer error and unchanged FilePV state.
- [ ] Go tests for message families, session/app loss, nil requests, replay/double-sign persistence and errors. Reuse official protocol/secret connection, no custom crypto.
- [ ] Harness launches host signer using ephemeral keys outside Comet-mounted home, sets priv_validator_laddr, retains existing FilePV state over restarts and scopes cleanup. Build helper through just/test entrypoint and package it in application image; preserve normal full-node mode.
- [ ] Actual Comet tests: latest target ahead catch-up without signatures, exact mismatch, first startup, app-only/Comet-only restart/reconnect, high voting power and sole validator with retained peer history. Never reset WAL/state or relax gate to pass.

## Private control contract (C/D shared interface)

Unix stream, one JSON request/response per newline, bounded to16KiB, schema_version1. Requests: {"schema_version":1,"op":"begin_session"} or {"schema_version":1,"op":"check_session","session_id":"opaque-session-token"}. Response has schema_version, session_id, chain_id (null until verified init), generation, trust_ready, syncing, phase, target (null or {l1_number,l1_hash,height,hash,generation,inbox}), committed_head (null or {height,hash}), trusted_consensus_head (null or {height,hash}), reason. Check for wrong session returns trust_ready=false; it never starts/restarts a session. Begin returns promptly with closed state. Signer trusts only current response with exact session+chain, not a cached response. Malformed/version mismatch is an error, not Ready. Hash/address strings canonical0x. Connection reset increments session and invalidates old results. No cross-process atomic-revocation claim for a signature already authorized before crash.

## Task E: integration, review, publication and bilingual specs

Owner: root.

- [ ] Integrate all task commits; regenerate all affected contract/test fixtures and coordinated config/ABI copies using scripts after protocol commit. Update every protocol pin (script, manifest, contracts.rs, AGENTS, README).
- [ ] Review old format/version rejection and no automatic migration. Complete independent task/final reviews and fix findings.
- [ ] Run just fmt/clippy-fix, Go tests/race, full protocol verification and final client just verify once final code/artifacts stable. Retain genuine failures and RED evidence; rerun only for changes/failures.
- [ ] Update PRs with normal pushes after fresh head check. No force or merge. Update descriptions with actual behavior and validation.
- [ ] Re-fetch/target-update both Notion specs, AppendixA final wire/hash/versioned fields, activeStake semantics and signer/trust architecture/status limitations. Preserve pending guest/recovery scope. Read back both and verify parity/no unrelated edits.
