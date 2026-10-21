# SP1-only Prover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SP1 the sole ZK proof type requested by taiko-client's prover and remove RISC0 and the ZK-only mode.

**Architecture:** Retain the existing Raiko SP1 producer and SGX companion aggregation. Collapse the submitter's RISC0/SP1 selector to SP1, then remove dead CLI, control-plane, metrics, and test code. Preserve the legacy forced SGX mode and generic transaction pair ordering.

**Tech Stack:** Go, urfave/cli, Raiko proof HTTP API, go-ethereum bindings.

**Spec:** `docs/superpowers/specs/2026-10-21-sp1-only-prover-design.md`

## Global Constraints

- Default pair: `[SGX_GETH, SP1]`; optional SGX_RETH companion pair: `[SGX_RETH, SP1]`.
- Keep `--prover.forceSGXProof` behavior; remove `--prover.zkOnlyProofs` and obsolete RISC0/SP1 selection flags.
- Keep protocol contracts, generated bindings, and historical CHANGELOG entries untouched.
- Open a draft PR with the flag migration and verification results.

## Review Focus

- Default requests must use SP1 even far ahead of the last finalized proposal (Task 1 selection test).
- A missing producer response must return an error instead of entering the proof buffer (Task 1 nil-response test).
- A partial SP1 buffer must aggregate when its timer expires without a proof-type switch (Task 1 aggregation test).
- An empty single SP1 response must still aggregate into a nonempty batch proof (Task 2 producer test).
- SGX_RETH companion and forced SGX must remain mutually exclusive at configuration time (Task 2 config test).

---

### Task 1: Make submitter selection SP1-only

**Files:** Modify `packages/taiko-client/prover/proof_submitter/proof_submitter.go`, `packages/taiko-client/prover/init.go`, and their tests. Delete `proof_submitter/risc0_sp1_fallback.go`, `sp1_proof_share.go`, and their dedicated tests. Replace `risc0_sp1_selection_test.go` and `zk_only_test.go` with focused SP1 selection tests.

**Interfaces:** `enabledProofTypes(forceSGXProof bool) []producer.ProofType`; `requestProposalProof(ctx context.Context, opts proofProducer.ProofRequestOptions, proposalID *big.Int, meta metadata.TaikoProposalMetaData, startAt time.Time) (*proofProducer.ProofResponse, error)`; `NewProofSubmitter` retains only `forceSGXProof` and `sgxRethCompanionProof` mode parameters after `proposalWindowSize`.

- [ ] Write/retain tests asserting SP1 plus SGX_GETH by default, SP1 plus SGX_RETH with the companion flag, SGX plus SGX_GETH in forced SGX mode, nil-response error, and timer-triggered aggregation.
- [ ] Run `go test ./prover/proof_submitter ./prover` from `packages/taiko-client`; confirm the new SP1 expectations fail before changing production code.
- [ ] Simplify selection, constructor fields and call sites; remove RISC0 fallback/share code, RISC0-specific buffer switching, and obsolete tests. Keep full-buffer and timer-triggered aggregation.
- [ ] Run `go test ./prover/proof_submitter ./prover`; expect PASS.
- [ ] Commit the runtime and test change with `refactor(taiko-client): select SP1 for ZK proofs`.

### Task 2: Remove obsolete producer, configuration, and metrics surface

**Files:** Modify `packages/taiko-client/cmd/flags/prover.go`, `prover/config.go`, `prover/proof_producer/{interface.go,common.go,proof_producer.go,compose_proof_producer_test.go}`, `prover/proof_submitter/transaction/builder_order_test.go`, `internal/metrics/metrics.go`, and affected tests. Delete `prover/proof_producer/risc0_backlog.go` and its test.

**Interfaces:** `ProofTypeZKSP1` remains `"sp1"`; `ProofTypeZKR0` and `Risc0BacklogController` disappear. `Config` retains `ForceSGXProof` and `SGXRethCompanionProof`; the four removed CLI flags are absent from `ProverFlags`.

- [ ] Update tests to assert removed flags are absent, default configuration uses SP1 without an RISC0 selector, incompatible SGX flags reject, empty single SP1 proof remains accepted, and SP1 aggregation retains its verifier ID and proof bytes.
- [ ] Run `go test ./prover ./prover/proof_producer ./cmd/flags`; confirm outdated expectations or new assertions fail.
- [ ] Remove four CLI flags and config fields, RISC0 control-plane client/type/metrics, and RISC0-only producer tests; keep SP1 empty individual response handling and generic pair ordering.
- [ ] Run `go test ./prover ./prover/proof_producer ./cmd/flags ./prover/proof_submitter/...`; expect PASS.
- [ ] Commit with `refactor(taiko-client): remove RISC0 proving configuration`.

### Task 3: Document migration and verify end to end

**Files:** Modify `packages/taiko-client/README.md` and current CLI help text if needed. Do not modify generated bindings or historical CHANGELOG entries; the PR body serves as the release note.

**Interfaces:** Document default SP1+SGX_GETH, optional SP1+SGX_RETH, removed flags and environment variables, and the removed ZK-only mode.

- [ ] Update README and confirm the removed switches no longer appear in prover `--help` or current documentation.
- [ ] Run `go test ./prover/... ./cmd/flags/...` and `go build ./cmd/...` from `packages/taiko-client`; record results and any environment limitation.
- [ ] Run `rg -n -i 'boundless|risc0|zkr0|\br0\b' packages/taiko-client/{prover,cmd/flags/prover.go,internal/metrics/metrics.go,README.md}` and inspect any remaining matches; expect none. Run `git diff --check`.
- [ ] Commit documentation with `docs(taiko-client): document SP1-only proving`.
- [ ] Push `codex/sp1-only-prover`, create a draft PR via `gh` with motivation, migration, tests, and limitation notes; attach the PR to this task.
