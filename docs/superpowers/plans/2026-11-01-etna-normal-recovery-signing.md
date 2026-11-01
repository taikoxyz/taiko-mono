# Etna normal-recovery signing implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Compose confirmed-key exclusion with actual current-chain signing through ordinary rotation and normal recovery, and classify every premise by trust versus implementation responsibility.

**Architecture:** Extend the existing model with a normal-run provenance relation that projects to original ordinary steps. Derive confirmation coverage and clock bounds, transport confirmation provenance through a real recovery into a later trusted prefix, then reuse lifetime exclusion and actual signer binding.

**Tech Stack:** Lean 4.35.0-rc4, standard Lean/Python libraries, existing exact-type/kernel audit.

**Spec:** docs/superpowers/specs/2026-11-01-etna-normal-recovery-signing-design.md

## Global Constraints

- Keep the seven headline premises and H1-H3 claim types unchanged.
- No production contract, client, signer gate or protocol validity rule changes.
- No custom axioms, sorry, native evaluation or new dependencies.
- No desired cutoff inequality, key exclusion, live bond or positive collateral as an input.
- Current authenticated views must cover confirmation; no global freshness guarantee or verifier-failure rollback claim.
- The user authorized implementation and updating #22292 after approving the complete scope in chat; proceed natively through all tasks without another scope/permission checkpoint.

## Review Focus

- An older confirmation checkpoint below a recovery origin must remain covered without impossible same-generation replay inclusion.
- Same-block recovery/confirmation ordering must use original ordered transitions, not a strict L1-block inequality that excludes lawful transactions.
- All original ordinary operations, including nonce invalidation, must project correctly even when equal output states could come from another operation.
- Released slots and reused bond ids must not allow a retired lifetime key to reappear.
- A signature must remain bound to actual next height, domain/generation, key, decoded message and fresh durable-log return.

### Task 1: Normal provenance and composition

**Files:** Create EtnaModel/NormalSigning.lean, EtnaProofs/NormalSigning.lean and tests/NormalSigning.lean under formal/etna; update the Model/Proofs roots and manifests/design.json.

**Interfaces:** Consume SnapshotSource, TrustedPrefix, IncludedCheckpoint, ObservedCall, EngineRequest, original OrdinaryStep/Trace, lifetime exclusion and signer-binding results. Produce NormalSigning.Run, ConfirmationSource, run_trace, run_snapshot_trace, run_snapshot_below, run_covered, confirmation_source_bound and fresh_signing_connection. The recovery source contains actual successful recovery plus ordinary paths and unchanged current origin/generation, never an assumed cutoff inequality.

- [x] Add Lean regressions requiring run projection, derived coverage, recovery-aware cutoff transport and actual fresh-call composition; watch missing declarations fail.
- [x] Define the normal provenance relation: accepted valid landings with exact deployment construction, prior snapshot source and the existing reference-block contract; all non-advancing OrdinarySteps remain available.
- [x] Derive original trace projection, monotone snapshots, coverage and snapshot-before-clock using original transition functions.
- [x] Define replay or actual-recovery confirmation provenance and derive its bound in the current built selector, including checkpoints below a new origin.
- [x] Compose with persistent lifetime exclusion and actual next-height signer results; add an initialized corollary with explicit initial key/history/confirmation conditions.
- [x] Run targeted silent Lean regressions, register exact theorem contracts/roles and commit the passing deliverable.

### Task 2: Initialized recovery witness and binding mutations

**Files:** Create EtnaWitnesses/Regressions/NormalSigning.lean and tests/test_normal_signing.py; update EtnaWitnesses.lean, tests/NormalSigning.lean and theorem manifest.

**Interfaces:** Consume Task 1's Run, ConfirmationSource and fresh_signing_connection. Produce a real initialized rotation/exit/withdrawal/recovery/fresh-signing witness with a replacement key, plus retained old-checkpoint and old-key exclusion facts.

- [x] Extend the targeted Lean regression with the desired initialized recovery witness and observe failure.
- [x] Reuse HistoricalEscrow/SigningBridgeRegression fixtures, add valid post-confirmation landing/recovery as needed to place the old checkpoint strictly below the origin, then sign the next recovered-generation height.
- [x] Cover slot reuse and a post-recovery ordinary handover with the same general theorem or independent targeted instantiation.
- [x] Add silent baseline and syntactically valid kernel mutations for recovery time/origin/generation provenance and next-height/member/request bindings; assert real proof failures.
- [x] Run targeted Python/Lean tests, register exact contracts/roles and commit.

### Task 3: Premise responsibility and complete verification

**Files:** Add formal/etna/reports/premise-responsibilities.md and normal-signing-composition.md; update README.md and applicable current report links. No change to existing premise types or headline claims.

**Interfaces:** Document all seven existing premise fields and every new normal-run/recovery/signing obligation. Consume verified Task 1/2 theorem statements and actual test output.

- [x] Document external primitives/dependencies separately from initialization, guest, encoding, authenticated-history and signing implementation contracts, including mixed fields.
- [x] Explain the new conditional composition, source completeness limits, initial-state requirements and explicit exclusions without promoting clause traceability.
- [x] Run source lint/import checks, clean complete Lean build, vector freshness, deterministic artifacts, source/clause/rule gates, strict fresh-kernel audit and all Python tests.
- [x] Update measured counts and reports, format changed documents, and commit.
- [x] Obtain fresh independent review of the complete PR update and fix confirmed Critical/Important findings with regressions.
- [x] Recheck remote head, push fast-forward to codex/etna-lean-verification, update the PR description with verified results and attach it to this chat.
