# Etna validator-state semantics implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan inline.

**Goal:** Add executable CometBFT v0.40.0 validator-state semantics and prove per-height replay, H+2 activation and the recovery-origin exception against Etna decoded headers.

**Architecture:** A concrete validator-set machine records ordered members, signed priorities and the stored proposer. A semantic replay layer checks existing decoded blocks and cut hashes, with a genesis override at generation origins and authenticated preimages elsewhere. Existing H1–H4 keep their statements; the new layer exports precise refinement results and fixes the actual decoded node-trust origin exception.

**Tech Stack:** Lean 4.35.0, Init/Std, Python unittest. Reference: CometBFT v0.40.0 types/validator_set.go and state/{state,execution}.go.

**Spec:** packages/protocol/docs/etna/SPEC.md PROOF-6.2-40/41a, COMM-4.3-13/15, SYNC-9-5/5c, ENC-A-29a.

## Global constraints

- No product-contract or specification edits; preserve pre-existing untracked TLA files.
- No sorry, new axioms, native_decide or mathlib dependencies.
- Preserve exact signed division, centering, saturation, address tie-breaking and stored proposer semantics.
- Commit-time priority replay increments once per height, never one historical multi-step increment.
- Hashing and public-key/address authentication remain explicit boundaries; do not claim production refinement.

## Review focus

- Negative priority division: rescaling truncates toward zero; averaging floors with Go big.Int.Div.
- A removed member's voting power participates in the pre-removal new-member penalty.
- H+2 pipeline and genesis initial_height greater than one.
- Recovery-origin stored hash may differ from new-generation genesis hash; later origins must authenticate preimages.
- Batched priority increments can differ from repeated per-height increments.

### Task 1: Concrete validator-set machine

Files: EtnaModel/CurrentValidatorState.lean; tests/CurrentValidatorState.lean; tests/test_current_validator_state.py.

- [x] Add failing regressions for genesis, tie-breaking, updates/removal, centering and per-height vs batched replay.
- [x] Implement bounded signed priorities, update checks, initial priorities, normalization, proposer selection and two-set state transition.
- [x] Compile and run regressions; compare pinned upstream vectors.

### Task 2: Semantic replay and proofs

Files: EtnaModel/CurrentValidatorState.lean; EtnaProofs/CurrentValidatorState.lean; library roots; manifests/design.json.

- [x] Add per-height replay, semantic block/cut checks and separate origin/genesis admission.
- [x] Prove pipeline/H+2, replay decomposition/determinism, per-block hash binding and recovery-origin independence.
- [x] Add theorem contracts and narrow coverage edges only for the proven results.

### Task 3: Trust exception, evidence and verification

Files: EtnaModel/CurrentProtocol.lean; tests/CurrentProtocol.lean; README.md; reports/validator-state.md; coverage and generated audit artifacts.

- [x] Add a failing recovery-origin trust regression, then make only the validator-state hash comparison conditional on being above origin.
- [x] Document the concrete layer, exact source mapping, remaining integration/crypto boundaries and unchanged H1–H4.
- [x] Run lake build, all source/import/coverage/vector/statement/audit gates and the fast suite; run targeted mutants.
- [x] Obtain one independent final review and address substantive findings.
