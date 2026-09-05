# Slot Chain V2.26 Full Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement, differentially verify, and security-audit every Slot Chain V2.26 on-chain
boundary on PR #22096 without selecting it on a production path.

**Architecture:** Use a conformance-led incremental rebuild. Each dependency-ordered round starts
with a meaningful failing test, implements one bounded state-machine slice, maps the normative
surface into a machine-checked ledger, and ends only after focused tests, profile tests, invariant
tests, artifact checks, and independent Critical/High review pass. Existing code is retained only
after it proves exact conformance with the frozen `9df3ad82f` design baseline.

**Tech Stack:** Solidity 0.8.30, Foundry/forge-std/CommonTest, Python 3.12 reference models,
TypeScript with ethers v5, pnpm 9.15.9, two local Anvil chains, GitHub Actions.

---

## 1. Non-negotiable execution rules

- PR #22064 (`claude/chain-liveness-builder-roles-cda13y`) owns LaTeX, PDF, protocol models, and
  normative design corrections. PR #22096 (`codex/slot-chain-v2-contracts`) owns Solidity, tests,
  generated contract fixtures, conformance/deployment tooling, and this implementation plan.
- The normative protocol commit is `9df3ad82f0282550cd790a72b0330690a15458bd`. Before every
  implementation round, read the relevant `main.tex` subsection and executable-model transition.
- If code requires a rule absent from or contradictory to the normative sources, stop that slice.
  Add a failing model regression and repair the design on PR #22064 first; then merge that design
  commit into PR #22096. Never hide a contradiction in Solidity or a test fixture.
- All additions are isolated from currently selected production Inbox, Bridge, Resolver, vault,
  verifier, genesis, and deployment paths. This PR does not authorize a production cutover.
- Interfaces contain full NatSpec. Implementations use `@inheritdoc`, named imports, repository
  naming conventions, typed custom errors, MIT license, and the security-contact tag.
- Every public transition gets success, authorization, replay, boundary-equality, malformed-call,
  external-fault, and unchanged-state-on-revert coverage. Tests assert error selectors and complete
  rollback, not only `expectRevert()`.
- A round is complete only when its conformance-ledger rows are `reviewed`, not merely `passing`.
  Each round is one focused commit unless splitting is necessary to keep a compilable dependency
  boundary; never combine unrelated cleanup.
- Use `/Users/d/.pyenv/versions/3.12.8/bin/python3` for the models. Use repository-pinned pnpm
  9.15.9; do not update the lockfile to work around the current pnpm-11 alias incompatibility.
- Do not claim “bug free.” The achievable closeout is: no known Critical/High defect after five
  independent adversarial review passes, all machine gates green, and explicit external release
  gates documented.

## 2. Required red/green/review loop for every round

- [ ] Read the exact normative subsection, commitment rows, and relevant model transition.
- [ ] Add ledger rows as `missing`, with source section, selector/encoding, implementation path,
      test path, error branches, limits, and expected artifact owner.
- [ ] Add the smallest focused test that fails because behavior is absent or wrong. Run it and save
      the meaningful failing output; compilation failure counts only when the missing API is what
      the test is introducing.
- [ ] Implement the minimum complete state transition and typed errors. Avoid compatibility shims
      for any superseded V2 draft.
- [ ] Add fuzz, invariant-handler, maximum-capacity, first/last actor, transition-boundary,
      reentrancy, OOG, short/trailing returndata, and rollback cases that apply to the slice.
- [ ] Run focused tests, the owning Foundry profile, `forge fmt --check`, `git diff --check`, fresh
      artifact-ownership checks, and storage/gas checks.
- [ ] Independently challenge the diff for protocol soundness, implementation feasibility,
      security, liveness, permissionlessness, accounting, and readability. Resolve every
      Critical/High finding; record Medium release risks in the ledger.
- [ ] Mark ledger rows `reviewed`, including source/test hashes, only after review and rerun.
- [ ] Commit only enumerated files with the round's commit message and push PR #22096.

Focused Foundry command pattern:

```bash
cd packages/protocol
FOUNDRY_PROFILE=<shared|layer1|layer2> forge test \
  --match-path '<test glob>' -vvv
```

Full per-profile command pattern:

```bash
cd packages/protocol
FOUNDRY_PROFILE=shared forge test --match-path 'test/shared/slotchain/**/*.t.sol'
FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/slotchain/**/*.t.sol'
FOUNDRY_PROFILE=layer2 forge test --match-path 'test/layer2/slotchain/**/*.t.sol'
```

## 3. Preflight snapshot — no implementation commit

**Inspect:**

- `packages/protocol/docs/preconfirmation-v2/README.md`
- `packages/protocol/docs/preconfirmation-v2/tex/main.tex`
- all five Python model/test files in that directory
- `packages/protocol/CLAUDE.md`
- `docs/superpowers/specs/2026-09-01-slot-chain-v2-contract-implementation-design.md`

- [ ] Fetch `origin`; prove PR #22096 contains PR #22064's current head and that no local
      normative-document diff exists relative to the stacked base.
- [ ] Run all design oracles:

  ```bash
  cd packages/protocol/docs/preconfirmation-v2
  /Users/d/.pyenv/versions/3.12.8/bin/python3 commitment-model.py
  /Users/d/.pyenv/versions/3.12.8/bin/python3 lookahead-model.py
  /Users/d/.pyenv/versions/3.12.8/bin/python3 settlement-window-model.py
  /Users/d/.pyenv/versions/3.12.8/bin/python3 -m unittest test-seat-market.py
  /Users/d/.pyenv/versions/3.12.8/bin/python3 -m unittest test-economic-profile.py
  /Users/d/.pyenv/versions/3.12.8/bin/python3 test-settlement-window.py
  ```

  Expected: 812 golden vectors / 1,593 assertion sites; 38 lookahead assertions; 186 settlement
  assertions; 114 seat-market tests; 38 economic tests; 293 settlement tests.

- [ ] Record current shared/L1/L2 builds, tests, gas, runtime sizes, artifact hashes, and known CI
      failures before touching code.
- [ ] Confirm the only untracked Slot Chain files are the four explicitly provisional
      ScheduleOracle files listed in Round 0.

## 4. Round 0 — clean baseline, conformance ledger, and CI trust point

**Delete:**

- `packages/protocol/contracts/layer1/slotchain/iface/IScheduleOracleV1.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/ScheduleOracleV1.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibScheduleOracleReads.sol`
- `packages/protocol/test/layer1/slotchain/schedule/ScheduleOracleV1.t.sol`

**Create:**

- `packages/protocol/utils/slotchain/conformance-ledger.v2.26.json`
- `packages/protocol/utils/slotchain/conformance-ledger.schema.json`
- `packages/protocol/utils/slotchain/checkConformanceLedger.ts`
- `packages/protocol/integration/slotchain/conformance-ledger.test.ts`

**Modify as required by evidence:**

- `packages/protocol/package.json`
- `.github/workflows/protocol.yml`
- `packages/protocol/utils/slotchain/artifact-ownership.json`
- `packages/protocol/utils/slotchain/checkArtifactOwnership.ts`
- `packages/protocol/contracts/layer1/slotchain/root/ProtocolRootFactoryV1.sol`
- `packages/protocol/contracts/layer1/slotchain/root/libs/LibRootBootstrapV1.sol`
- their existing Foundry tests

- [ ] Delete the four incomplete files; prove no tracked source, manifest, artifact, or fixture
      references their selectors or types.
- [ ] Seed the ledger from the exhaustive inventories in implementation-design §3.2: all eighteen
      root artifacts, all remaining PR-owned deployables, all creation-only artifacts, all external
      dependencies, and every existing shared primitive. Reject duplicate IDs and unclassified
      Slot Chain production sources.
- [ ] Give each row `normativeRef`, `ownerProfile`, `lifecycle`, `abiOrEncoding`, `sourcePaths`,
      `testPaths`, `failureBranches`, `limits`, `status`, and reviewed source/test hashes. The
      checker must reject a missing field, stale hash, a `reviewed` row without tests, an unknown
      source, or an artifact-owned contract emitted by two profiles.
- [ ] Add red tests for those checker failures, then implement the checker and wire
      `slotchain:conformance:check` into `slotchain:ownership:ci` after fresh profile builds/tests.
- [ ] Re-export all 812 typed commitment rows and fail if generated JSON/Solidity differs.
- [ ] Fix current CI failures without weakening a gate. In particular, add a factory entry lock or
      equivalent state-before-call protection around root finalization and ensure the bootstrap
      exact-call helper reserves gas after return-data copy/memory expansion, not only before the
      external call. Add malicious callback, huge-returndata, OOG, and unchanged-state tests.
- [ ] Force-build all three profiles, run ownership/vector/ledger tests, and inspect `gh pr checks
22096` after push.
- [ ] Commit: `build(protocol): establish slot chain v2.26 conformance baseline`.

## 5. Round 1 — shared byte-exact and accounting primitives

**Retain only after conformance; modify/create under:**

- `packages/protocol/contracts/shared/slotchain/SlotChainTypes.sol`
- `packages/protocol/contracts/shared/slotchain/iface/`
- `packages/protocol/contracts/shared/slotchain/libs/`
- `packages/protocol/test/shared/slotchain/`
- `packages/protocol/utils/slotchain/generateGoldenVectors.ts`

- [ ] Add red differential tests that consume the Python export directly for every shared-owned
      row among all 812 vectors. Do not recompute expected values in Solidity or TypeScript.
- [ ] Revalidate widths, enum ranges, canonical padding, selectors, EIP-712 domains, all tree
      domains/depths, the depth-64 frontier, Data MMR, RLP/MPT total consumption, and empty roots.
- [ ] Implement/revalidate `LibExactCall`, low-`s` signature checks, checked narrowing/math,
      `LibSlotChainEconomics`, `LibCustodyAccounting`, and typed native-ETH sink interfaces.
- [ ] Test 0/1/max-1/max capacities, one-past-max, dirty padding, trailing bytes, no-code targets,
      code/config mismatch, revert, OOG, return bombs, EIP-150 reserve, forced ETH, surplus, and
      callback reentry.
- [ ] Add handlers proving every custody relation is conserved and every tree/frontier transition
      is monotone and bounded.
- [ ] Prove source-inline libraries have no callable production ABI/link references and shared
      deployables are loaded from their single owner artifact.
- [ ] Run the full shared profile, vector generator/checker, fuzz/invariants, artifact checker, and
      ledger checker.
- [ ] Commit: `feat(protocol): complete slot chain v2.26 shared primitives`.

## 6. Round 2 — deterministic protocol-root bootstrap primitives

**Modify/revalidate:**

- `packages/protocol/contracts/layer1/slotchain/root/`
- `packages/protocol/test/layer1/slotchain/root/`

**Create/complete root-level interfaces and implementations under:**

- `packages/protocol/contracts/layer1/slotchain/iface/`
- `packages/protocol/contracts/layer1/slotchain/impl/`
- `packages/protocol/contracts/layer1/slotchain/libs/`

- [ ] Add red harness tests for the exact eighteen-artifact inventory compiled by one `layer1`
      invocation, the nine ordered role slots, PRF1's exact 736-byte/23-word return, PVM1's exact
      1,184-byte return, repeated SourceBundleFactory identity, and the one retained terminal
      verifier identity. This round proves encodings and bootstrap mechanics only; concrete
      cross-component finalization is deferred until every role exists.
- [ ] Test every CREATE2/CREATE3 first/last boundary: prefunded child/proxy, occupied code, dirty
      nonce, wrong proxy runtime, front-run exact code, duplicate salt, partial deployment, callback
      reentry, and complete rollback.
- [ ] Revalidate `RootMigrationExecutorV1`, `ProtocolRootFactoryV1`,
      `ProtocolRootCreate3ProxyV1`, `ProtocolRootComponentV1`, and `LibRootBootstrapV1`; implement
      the reusable immutable root-component boundary. Harnesses may supply exact fixed test
      artifacts but cannot cause concrete BRC1/SOC1/PCT1/PVM1/SBF1/STF1 rows to become `reviewed`.
- [ ] Prove bootstrap authority is exactly unused or irreversibly consumed, role/config/runtime
      hashes cannot be replaced, and no generic setter/Resolver/delegate target exists.
- [ ] Measure root initcode/runtime against EIP-3860/EIP-170 and gas at the complete maximum root,
      including the final artifact and final role receipt.
- [ ] Mark only bootstrap/proxy/factory/encoding rows `reviewed`; leave concrete root-assembly and
      cross-graph rows `missing` or `passing` until Round 10A.
- [ ] Run L1 root tests, artifact/ledger checks, deployment transcript precursor, and independent
      bootstrap/security review.
- [ ] Commit: `feat(protocol): complete deterministic slot chain root bootstrap`.

## 7. Round 3 — BuilderRegistry and liability generations

**Create:**

- `packages/protocol/contracts/layer1/slotchain/iface/IBuilderRegistry.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/BuilderRegistry.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibBuilderRegistry.sol`
- `packages/protocol/test/layer1/slotchain/registry/BuilderRegistry.t.sol`
- `packages/protocol/test/layer1/slotchain/registry/BuilderEvidence.t.sol`
- `packages/protocol/test/layer1/slotchain/registry/BuilderRegistryInvariant.t.sol`

- [ ] Add red tests for registration, collateral custody, deterministic replacement/tie victim,
      tombstones, generation/address reuse, active-set capacity 64, reservation, release equality,
      pull credits, and surplus.
- [ ] Add the complete evidence corpus: distinct low-`s` headers in one exact context, independent
      history-carrier arms, signed/current admission membership for one retained generation/index,
      correct per-window tranche, first report, duplicate report, deadline equality, and one-step
      late failure.
- [ ] Implement fixed-capacity/O(1) indexes and independently slashable window liabilities. A first
      valid report atomically tombstones the key, slashes only its window tranche, and credits the
      reporter; no push payment or operator callback is allowed.
- [ ] Fuzz maximum churn and first/last builder transitions. Prove a retained key cannot re-enter
      while any evidence horizon survives and distinct windows never share slashable accounting.
- [ ] Pin exact `componentConfigHashV2` and reward-class calls, return sizes, gas, padding, unknown
      classes, and malformed external behavior.
- [ ] Run L1 registry tests/invariants, storage/gas, artifact/ledger checks, and review.
- [ ] Commit: `feat(protocol): implement slot chain builder registry`.

## 8. Round 4 — authenticated schedule and ForcedQueue

**Create/complete:**

- `packages/protocol/contracts/layer1/slotchain/iface/IScheduleOracle.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/ScheduleOracle.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibBuilderSchedule.sol`
- `packages/protocol/contracts/layer1/slotchain/iface/IForcedQueue.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/ForcedQueue.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibForcedQueue.sol`
- corresponding `schedule/` and `queue/` L1 tests

- [ ] Add red golden/differential schedule tests for 0, 1, 6, and 64 eligible builders; carrier
      parent semantics; fork interval selection; seal/snapshot/expiry; quota allocation; ring wrap;
      tombstone timing; and reorg rollback.
- [ ] Explicitly test the last slot of window W and first slot of W+1: the same key may occupy only
      that boundary pair, global same-key run is at most two, and the windows use different retained
      tranches and clocks.
- [ ] Complete the append-only delayed fork verifier registry and exact fixed-width SFV/SFC calls.
      Reject wrong code/config/interval, short/trailing returndata, one-less gas, revert/OOG, dirty
      padding, and statement/header substitution with zero writes.
- [ ] Revalidate the existing `ScheduleSszMultiproofVerifierV1`, fork-verifier interface/call
      boundary, seal witness, snapshot evaluator, exact fork/config selection, and all malformed
      proof/return/gas paths; its ledger rows cannot remain implicitly covered by ScheduleOracle.
- [ ] Add red Queue tests for kind-0/kind-1 authorization, permanent cursor/order, deposit/refund,
      cancellation race, V11 credit encoding, migration authority, maximum batch, and historical
      source generation. Implement O(1) storage and pull payments.
- [ ] Fuzz all queue/window boundary crossings and prove neither seat-holder nor operator
      availability is required for append, expiry, recovery eligibility, or later progress.
- [ ] Run focused and full L1 tests, Python lookahead differential, gas/capacity, artifact/ledger
      checks, and review.
- [ ] Commit: `feat(protocol): implement slot chain schedule data and forced queue`.

## 9. Round 5 — Settlement-owned data sessions, normal settlement, and canonical history

**Create:**

- `packages/protocol/contracts/layer1/slotchain/iface/ISlotChainSettlement.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/SlotChainSettlement.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibCandidateValidation.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibCanonicalHistory.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibSettlementAccounting.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibDataSession.sol`
- L1 `settlement/` unit, vector, fuzz, invariant, and fault-target tests

- [ ] Add red data-session tests for open/publish/consume/expire at every time equality,
      byte/blob/count capacity, MMR root/frontier, data rent/bond, blob-market-indexed
      reimbursement input, canonical reconstruction, and complete Settlement-owned accounting.
- [ ] Add red tests for every candidate field/commitment, proposer signature, schedule membership,
      parent/canonical prestate, verifier statement/config/code, data session, proof tier, duplicate,
      deadline, and exact returndata branch.
- [ ] Implement normal activation/settlement and canonical publication with authenticated bounded
      history. Publish only after all proof, data, and accounting joins succeed.
- [ ] Test first block, ring wrap, final representable counter, one-past-capacity, same-height races,
      reorg-carrier failure, verifier substitution, callback reentry, return bomb, OOG, and rollback
      of every touched word/liability/event condition.
- [ ] Prove canonical progress has no Market/seat/operator mutating call and remains callable by any
      account with valid inputs.
- [ ] Differentially replay applicable commitment and settlement-model traces. Add handlers for
      canonical monotonicity, one canonical child, bounded history, and Settlement solvency.
- [ ] Run L1 settlement tests/invariants, storage/gas/size, artifact/ledger checks, and review.
- [ ] Commit: `feat(protocol): implement slot chain normal settlement`.

## 10. Round 6 — recovery, rewards, and permissionless liveness

**Modify/complete:**

- `packages/protocol/contracts/layer1/slotchain/impl/SlotChainSettlement.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/ForcedQueue.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibSettlementAccounting.sol`
- L1 `settlement/Recovery*.t.sol`, `settlement/Rewards*.t.sol`, and liveness invariant handlers

- [ ] Add red traces for recovery entry/equality, unsigned forced escape, tier-3 proof, repeated
      candidate levels, smallest-tip holder, marginal-block rewards, data reimbursement, close,
      expiry, claim, and migration-retained receipts.
- [ ] Implement exactly one fixed cost per distinct `(count, tip_slot)` level, payable at close to
      the smallest `tip_hash` holder. Prove a 40-candidate same-level grind pays one fixed cost, one
      equivocation slash cannot drain more than its bounded liability, and earned marginal-block
      rewards remain intact.
- [ ] Index `phi_data` to the authenticated blob-market price and reimburse only bytes consumed by
      the winning chain. Test simultaneous price spike and aggregator withholding.
- [ ] Test recovery horizon including `W_settle_max`, exit-bond retention, first/last candidate,
      empty/all-malicious builder sets, seat absence/failure, full Queue, and equality on every
      deadline.
- [ ] Prove proof submission, forced recovery, sync, close, and claims are permissionless and that
      economic payout failure cannot block canonical progress.
- [ ] Run differential settlement/economic models, L1 tests/invariants, worst-case gas, ledger, and
      review.
- [ ] Commit: `feat(protocol): implement slot chain recovery and rewards`.

## 11. Round 7 — perpetual reverse-ask AggregatorSeatMarket

**Create:**

- `packages/protocol/contracts/layer1/slotchain/iface/IAggregatorSeatMarket.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/AggregatorSeatMarket.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibSeatMarket.sol`
- L1 `market/` unit, wire, custody, fuzz, and invariant tests

- [ ] Add red tests for the bounded four-cell continuous offer book, lower ask ordering/ties,
      deposits, premium runway/reserve, APPLY, staging, handover, terms, pull credits, withdrawal,
      slash, release request, expiry, and reclamation.
- [ ] Prove this is a perpetual reverse auction: offers can arrive continuously and compete by ask;
      there is no fixed auction window or seatless mode.
- [ ] Pin the exact Settlement–Market fixed-width mutation wire. Reject arbitrary callers,
      historical Settlement, malformed/dirty returns, replay, reentrancy, OOG, and partial writes.
- [ ] Separate scheduling from duty: APPLY may start service but allocates no duty; only strict
      `now > recoveryAt` creates a duty using the then-current responsibility base. Builder
      scheduling cannot create/cure/failover/slash a seat duty.
- [ ] Exhaust first/last cell, old/new term, same-timestamp offer/APPLY, equality at recoveryAt,
      late cure, failover, exhausted premium, slash, release during migration, successor handover,
      and forced ETH/token surplus.
- [ ] Differentially replay all 114 seat-market tests and add conservation/monotonicity handlers.
      Prove a missing/malicious seat can reduce only its service, never canonical safety or forced
      recovery.
- [ ] Run L1 market tests/invariants, model differential, maximum gas, ledger, and review.
- [ ] Commit: `feat(protocol): implement perpetual reverse ask seat market`.

## 12. Round 7A — BridgeDomainRegistry, proof verifiers, and kind-0 ingress

**Create/complete:**

- `packages/protocol/contracts/layer1/slotchain/iface/IBridgeDomainRegistry.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/BridgeDomainRegistry.sol`
- `packages/protocol/contracts/layer1/slotchain/libs/LibBridgeDomainRegistry.sol`
- `packages/protocol/contracts/layer1/slotchain/iface/IKind0IngressAdapter.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/Kind0IngressAdapter.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/RegistrationMptVerifierV2.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/ScheduleSszMultiproofVerifierV1.sol`
- L1 `registry/BridgeDomainRegistry*.t.sol`, `ingress/Kind0IngressAdapter*.t.sol`, and verifier tests

- [ ] Add red tests for both append-only BridgeDomainRegistry namespaces and every exact raw read
      or mutation wire: BRS1, BRD1, BRC1, ABR2, BRX1, BIP1, BID1, PIR2, PIM2, and PIA2. Cover
      canonical padding/length, delay, stage idempotence, consume, active route, reverse indexes,
      destination proofs, topology joins, version/manifest/profile binding, replay, and restart from
      public state only.
- [ ] Revalidate `RegistrationMptVerifierV2` against its locally derived twelve-field statement,
      exact 452+ceil32(proof) ABI, canonical bounded RLP/MPT, proof/key hashes, 65-node-per-path and
      130-total-node caps, 600-byte node cap, exact 78,264-byte inner-proof cap, 11,000,000-gas
      dispatch, and exact return. BridgeDomainRegistry derives the sequence-tagged canonical tuple
      only from ActiveSettlementRouter; this verifier does not read or accept an EIP-2935 carrier.
- [ ] Revalidate `ScheduleSszMultiproofVerifierV1` as the concrete schedule-fork verifier artifact;
      prove it cannot be replaced by the interface/call wrapper or a permissive test verifier.
- [ ] Implement the distinct kind-0 adapter. Canonically re-encode the raw transaction call,
      recover and match sender/nonce/chain/fees/gas/length/hash, require direct `msg.sender`, stamp
      the active Router/Queue/release binding, and make append, processing-fee transfer, SYNCED
      refund, delayed append, PREACTIVE/ACTIVE migration transition, and rollback one bounded
      state machine. It must never accept kind 1 or a relayed kind-0 path.
- [ ] Test bytes lengths and EIP-2718 forms at 0/1/31/32/33/max, deadline equality, underfunding,
      wrong nonce/chain/signer, Queue capacity race, callback/reentry/OOG, stale release, and complete
      value/fee/Queue/adapter rollback.
- [ ] Mark standalone verifier, namespace-storage, codec, and kind-0 state-machine rows `reviewed`.
      Leave BRS1/BRD1/BRC1/ABR2 paths that require the concrete Router/PVM graph `passing` until
      the real post-assembly rerun in Round 10A; a Router/PVM mock cannot close those rows.
- [ ] Run verifier, registry, and ingress L1 suites, fresh artifact/ledger checks, maximum gas, cold
      restart tests, and independent review.
- [ ] Commit: `feat(protocol): implement bridge registry proofs and kind zero ingress`.

## 13. Round 8 — source Bridge bundle and root-lifetime terminal verifier

**Create:**

- `packages/protocol/contracts/layer1/slotchain/impl/SourceBundleFactory.sol`
- the manifest-named source-bundle deployer
- `packages/protocol/contracts/layer1/slotchain/impl/BridgeInboxAdapter.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/SourceBridgeV2.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/BridgeCreditRegistryV2.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/SourceQuotaManager.sol`
- `packages/protocol/contracts/layer1/slotchain/impl/SourceTerminalVerifier.sol`
- source bridge interfaces/libraries and L1 `bridge/` tests

- [ ] Add red deterministic bundle tests: SBF1 is the only role-9 preactivation read; SBD1/SAD1
      require ACTIVE; fresh release-scoped children use exact CREATE ordering; terminal verifier is
      root-lifetime and byte/address/config identical across releases.
- [ ] Implement source send, immutable generation/domain/route, exact authorization versus funded
      liability, kind-1 enqueue, quota, pull refunds, cancel-before-enqueue, queue-before-
      cancel, QUEUED callback, and proof-first DONE/FAILED terminal finalization.
- [ ] Add only an integration assertion that the separately implemented direct-sender kind-0 path
      coexists with the bundle. `BridgeInboxAdapter` is kind-1-only; SourceBridge never accepts,
      relays, or forwards kind 0.
- [ ] Test DIRECT ETH separately from LP credit; never reuse/mutate the live V1 Bridge. Historical
      endpoints cannot mint but retain refunds and terminal verification.
- [ ] Fault every call edge for wrong caller/origin, route/version/domain, short/trailing return,
      code/config drift, duplicate, OOG, callback/reentrancy, partial transfer, and complete rollback.
- [ ] Prove source liabilities, authorization, terminal outcomes, pulls, quota, refunds, and surplus
      conserve under fuzzed interleavings and maximum capacities.
- [ ] Mark standalone source custody, bundle, codec, and kind-1 adapter rows `reviewed`; leave ACTIVE
      SBD1/SAD1 and terminal paths requiring the concrete PVM/Router/root graph `passing` until the
      Round 10A post-assembly rerun.
- [ ] Run L1 bridge tests/invariants, artifact/root-count checks, gas/size, ledger, and review.
- [ ] Commit: `feat(protocol): implement slot chain source bridge plane`.

## 14. Round 9 — destination lifetime and release-scoped bridge plane

**Create:**

- `packages/protocol/contracts/layer2/slotchain/impl/ProtocolReleaseAuthorityV2.sol`
- `packages/protocol/contracts/layer2/slotchain/impl/InboxApplyRouterV2.sol`
- `packages/protocol/contracts/layer2/slotchain/impl/TerminalDomainRegistrarV2.sol`
- `packages/protocol/contracts/layer2/slotchain/impl/TerminalAccumulatorV2.sol`
- `packages/protocol/contracts/layer2/slotchain/impl/NativeLiquidityPoolV2.sol`
- `packages/protocol/contracts/layer2/slotchain/impl/InboxCreditStoreV2.sol`
- `packages/protocol/contracts/layer2/slotchain/impl/DestinationBridgeV2.sol`
- `packages/protocol/contracts/layer2/slotchain/impl/DestinationQuotaManager.sol`
- required L2 interfaces/libraries and `test/layer2/slotchain/` suites

- [ ] Add red tests for immutable release authority, apply route, endpoint/domain Store, exact O(1)
      ICV2 credit/fee reads, native Pool tickets, funding, claim, retries, cancellation/refund,
      terminal append, depth-64 frontier, permanent pins, and exact AnchorV4 install journal.
- [ ] Implement complete transient authorization tuples and explicit reentrancy states. Only the
      exact child callback is admitted while entered.
- [ ] Fault target success/revert/OOG/reentry and every owner/non-owner initial/retry/last-attempt
      branch. A failed child frame must restore Pool/ticket, quota, pull, Store, Bridge, and terminal
      state before the normative outer catch writes RETRIABLE or the owner-last finalizer writes
      FAILED plus one terminal leaf.
- [ ] Test duplicate/unpinned/foreign credits, wrong route/writer, overflow, max frontier, terminal
      count/pin equality, historical release, and forced native surplus.
- [ ] Add cross-component handlers proving credit, fee, quota, Pool, Bridge pull, pin, terminal, and
      raw-balance conservation.
- [ ] Run L2 tests/invariants, maximum gas/size, artifact/ledger checks, and review.
- [ ] Commit: `feat(protocol): implement slot chain destination bridge plane`.

## 15. Round 10 — protocol authority and delayed genesis compatibility

**Create/complete:**

- `ProtocolChangeTimelockV1`, `ProtocolVersionManagerV2`, and `ActiveSettlementRouter`
- migration-transition verifier interfaces/call library
- `LegacyGenesisCutoverInboxV1`, `LegacyResumeZkPairVerifierV1`, fixed-key RISC0/SP1 adapters,
  fenced legacy SignalService boundary, and `LibGenesisCampaign`
- L1 `migration/` and `genesis/` tests

- [ ] Add red exact-ABI/config tests for operations, delay/cancel/expiry, release registration,
      ExecutionProfileV2, PVM1, Router state, one migration-gate storage word, verifier descriptors,
      and authoritative fixed-width reads. No caller-supplied historical target may gain authority.
- [ ] Implement a delayed, bounded genesis campaign with immutable resume profile/target/cutoffs,
      block/time deadlines, 1,024-row caps, 4 MiB cap, maximum-progress 16-row scans, review and
      abandonment receipts, reversible QUIESCENT, permissionless proof landing, and expiry resume.
- [ ] Reproduce the deployed legacy storage/config and final storage-compatible facade exactly.
      Test proxy-only installation, storage collision, legacy events/withdrawals/selectors, direct
      fixed-key RISC0/SP1 graph, upgrade fence, maximum 128 scans, pending-row abandonment, forced
      ETH, and full landing rollback.
- [ ] Treat compatibility as a stop gate: if the actual deployed Inbox/SignalService graph cannot
      install the exact specified artifacts, mark in-place genesis unsupported and return to the
      design PR for an independently initialized migration. Do not approximate.
- [ ] Run L1 authority/genesis tests, layout diff, model differential, gas/size, ledger, and review.
- [ ] Commit: `feat(protocol): implement slot chain authority and delayed genesis`.

## 16. Round 10A — concrete eighteen-artifact root assembly

**Modify/complete:**

- `packages/protocol/contracts/layer1/slotchain/root/`
- all concrete root roles and role-9-reachable artifacts completed in Rounds 3–10
- `packages/protocol/test/layer1/slotchain/root/ProtocolRootAssemblyV1.t.sol`
- `packages/protocol/test/layer1/slotchain/root/ProtocolRootCrossGraphV1.t.sol`

- [ ] Replace every root test artifact with the real optimized BuilderRegistry, ScheduleOracle,
      ProtocolChangeTimelockV1, ProtocolVersionManagerV2, ActiveSettlementRouter, ForcedQueue,
      AggregatorSeatMarket, BridgeDomainRegistry, SourceBundleFactory, bundle deployer,
      BridgeInboxAdapter, SourceBridgeV2, BridgeCreditRegistryV2, source QuotaManager, and retained
      SourceTerminalVerifier artifacts.
- [ ] Finalize the real BRC1/SOC1/PCT1/PVM1/SBF1/STF1 graph and exact 736-byte PRF1 receipt. Prove
      the role-9 manifest/source root resolve to byte-identical SourceBundleFactory creation/runtime
      code and the terminal verifier address/runtime/config repeat across releases.
- [ ] Re-run every first/last/collision/prefund/reentry/rollback test with concrete artifacts,
      enforce one `layer1` compiler invocation and owner profile for all eighteen artifacts, and
      measure the complete root against gas/EIP-170/EIP-3860 bounds.
- [ ] Re-run BRS1/BRD1/BRC1/ABR2 registration, stage, consume, and active-route paths plus ACTIVE
      SBD1/SAD1 and terminal paths using only the real Router, PVM, Queue, BridgeDomainRegistry,
      SourceBundleFactory/bundle, and SourceTerminalVerifier. Restart the harness from raw public
      reads before finalization; no mock handle or private fixture may provide authority.
- [ ] Only now mark concrete root-assembly/cross-graph rows `reviewed`; mocks/harnesses do not
      satisfy the ledger.
- [ ] Commit: `feat(protocol): finalize concrete slot chain protocol root`.

## 17. Round 11 — later migration, abort, release rotation, and reclamation

**Modify/complete L1 authority/settlement/queue/source components; create:**

- `packages/protocol/contracts/layer1/slotchain/libs/LibMigrationJournal.sol`
- `packages/protocol/contracts/layer2/slotchain/libs/LibReleaseReclamation.sol`
- `packages/protocol/contracts/layer2/slotchain/libs/LibForceSend.sol`
- L1 `migration/VersionMigration*.t.sol`
- L2 `release/ReleaseRetirement.t.sol`, `ReleaseReclamation.t.sol`, and `ForceSend.t.sol`

- [ ] Add the exact success trace: proof STATICCALL; ACTIVATING; MFRZ; MCAN; kind-0 bind;
      SourceBridge activate/index; BRC1; destination seal; Bridge bind; QMIG; three MAPS reads;
      registration/receipt/successor writes; public ACTIVE; context clear; Router IDLE; VMC1; PVM
      IDLE. VMC1 is the only post-QMIG mutating call and the final external call.
- [ ] Inject failure, reentrancy, OOG, wrong magic, short/trailing return, and bad post-read at every
      journal edge. Prove the entire old READY/IDLE authority, Queue, lease, source/destination
      bindings, registrations, receipts, context, and balances return exactly to entry state.
- [ ] Implement permissionless hard-expiry abort with monotone `armFreshAfter`; rows queued at or
      before abort are unusable and only a strictly later row serving a fresh seven-day delay arms.
- [ ] Implement atomic rotation with RAV2/DRV2/DSV2, proof-bound Queue watermark, direct successor,
      route/writer/lifetime graph, applied cursor, terminalized-pinned equality, zero pull liability,
      exact ForceSend transfer, and one-shot retired bit. ForceSend is the normative 22-byte CREATE2
      constructor that self-destructs to the typed sink; reclamation must never CALL the sink.
- [ ] Test zero surplus performs no CREATE2; exact salt/helper/initcode/compiler-build/EVM-rules
      hashes; fixed/precreate/child/postcheck gas and one-less gas; prefunded helper; nonce/code
      collision; post-balance zero; absence of sink callbacks; and complete rollback before
      `retired` on any ForceSend failure.
- [ ] Test A-to-B-to-C: A reclaims from A-to-B after B-to-C while B independently uses B-to-C;
      latest-tip substitution, partial transfer, callback, reentry, duplicate, graph mismatch, and
      unmet watermark/count/liability all change nothing.
- [ ] Run both profiles, settlement model differential, migration/reclamation invariants, maximum
      gas, ledger, and independent review.
- [ ] Commit: `feat(protocol): implement atomic migration and release reclamation`.

## 18. Round 12 — deterministic deployment and build conformance

**Create:**

- `packages/protocol/script/layer1/slotchain/DeploySlotChainL1.s.sol`
- `packages/protocol/script/layer2/slotchain/DeploySlotChainL2.s.sol`
- `packages/protocol/utils/slotchain/generateExecutionProfile.ts`
- `packages/protocol/utils/slotchain/verifyBuildConformance.ts`
- `packages/protocol/utils/slotchain/checkDeploymentTranscript.ts`
- independent Python build-conformance verifier and schemas/fixtures
- L1/L2 deployment tests and TypeScript conformance tests

- [ ] Pin the three deployment authorities: ERC-2470 singleton for release Settlement, root
      SourceBundleFactory for source bundles, and the audited one-shot root bootstrap sequence.
- [ ] Add red deterministic tests for every protocol-lifetime/release-scoped address, first/last
      nonce, CREATE2/CREATE3 formula, constructor/seal/burned authority, front-run exact-code
      acceptance, collision, wrong factory/nonce/artifact, and restart from chain reads.
- [ ] Generate strict ExecutionProfileV2 from the exhaustive ownership manifest. Reject test
      verifiers, null/uncalibrated economics, artifact/source-inline drift, endpoint reuse,
      lifetime-address drift, stale layouts, unknown owners, or incomplete authority burning.
- [ ] Build all profiles twice from empty output/cache directories; compare creation/runtime,
      immutable/link references, ABI, storage layout, compiler input, source tree, config hashes,
      addresses, receipts, and complete deployment transcripts.
- [ ] Produce the byte-exact build-conformance report and independently reproduce it from the
      published input bundle in Python. Mutate every field/order/length/source/artifact and require
      rejection.
- [ ] Assert no current production deployment script or Resolver selects V2.
- [ ] Run all deployment/profile/conformance/ownership/ledger tests and review.
- [ ] Commit: `build(protocol): add deterministic slot chain v2.26 deployment`.

## 19. Round 13 — two-chain end-to-end integration

**Create:**

- `packages/protocol/integration/slotchain/artifacts.ts`
- `packages/protocol/integration/slotchain/deploy.ts`
- `packages/protocol/integration/slotchain/relay.ts`
- `packages/protocol/integration/slotchain/slot-chain-v2.integration.test.ts`
- `packages/protocol/integration/slotchain/slot-chain-v2.restart.integration.test.ts`

- [ ] Start distinct L1/L2 Anvil processes and deploy only profile-owned bytecode. The relay may
      deliver committed proofs/messages but may not inject roots, bypass verifiers, or share object
      state between chains.
- [ ] Exercise normal settlement and every recovery route with 0/1/64 builders, first/last boundary
      builder, same-key two-slot boundary, no seat, malicious seat, full Queue, and tier-3 escape.
- [ ] Exercise DIRECT ETH and LP funding through DONE, RETRIABLE, FAILED, cancel, refund, terminal
      proof, historical endpoint, and source pull finalization.
- [ ] Exercise genesis success/expiry, later migration success/failure/abort, release rotation,
      A-to-B-to-C reclamation, and fault injection at each external boundary.
- [ ] Kill the off-chain harness, reconstruct every address/cursor/route/release from raw chain
      reads, and continue through another release without private fixtures.
- [ ] Run the full integration suite twice with different fuzz seeds plus all profile tests,
      ownership/transcript/ledger checks, and model differentials.
- [ ] Commit: `test(protocol): add slot chain v2.26 two chain integration`.

## 20. Rounds 14–18 — five independent adversarial audits

Each pass starts from the complete repository state, not the previous report. Findings are traced
to exploitability and fixed with regression tests in the owning implementation round. A pass is
repeated after any material fix.

### Round 14: protocol safety and authority

- [ ] Challenge signatures/proofs, canonical history, root/manifest identities, Router/PVM/legacy
      authority, historical targets, replay, reorgs, selector/length confusion, and atomic journals.
- [ ] Commit fixes/tests: `fix(protocol): harden slot chain safety and authority`.

### Round 15: accounting, incentives, and market manipulation

- [ ] Challenge ETH/token solvency, forced funds, pulls, premium/runway, level metering, data-price
      spikes, equivocation/grinding, griefing, auction ties, exit/release horizons, and MEV ordering.
- [ ] Commit fixes/tests: `fix(protocol): harden slot chain accounting and incentives`.

### Round 16: liveness, permissionlessness, and all actor boundaries

- [ ] Challenge empty/all-malicious builder sets, first/last builder, same-key cross-window pair,
      first/last market cell, absent/malicious seat, verifier outage, Queue saturation, deadline
      equalities, failed economic maintenance, migration expiry/abort, and reclamation after hops.
- [ ] Commit fixes/tests: `fix(protocol): harden slot chain liveness boundaries`.

### Round 17: EVM faults, gas, and denial of service

- [ ] Challenge reentrancy, callbacks, return bombs, memory expansion, EIP-150, OOG, code/config
      replacement, constructor self-calls, CREATE collisions, maximum proof/blob/batch/frontier/ring
      inputs, EIP-170/EIP-3860, and bounded storage/work.
- [ ] Commit fixes/tests: `fix(protocol): harden slot chain evm fault handling`.

### Round 18: cross-chain lifecycle, restart, and design-to-code sync

- [ ] Trace every LaTeX transition and all 812 vectors into reviewed ledger rows; challenge bridge
      inner/outer rollback, terminal/pin counts, retirement/reclaim, direct successors, restart,
      serialization, and deploy/rebuild reproducibility.
- [ ] Compare both PR diffs and ensure design fixes exist only on #22064 while code/tests/tooling
      exist only on #22096. Regenerate and verify the PDF if any normative correction occurred.
- [ ] Commit fixes/tests: `fix(protocol): close slot chain v2.26 implementation audit`.

## 21. Final acceptance matrix

- [ ] All model counts exactly match the frozen README and all 812 vector rows match Solidity.
- [ ] Every normative component/interface/selector/return/state/error/limit/invariant has one
      reviewed ledger row; no dead, provisional, duplicate, or unclassified source/artifact exists.
- [ ] Shared, L1, L2, fuzz, invariant, fault, migration, bridge, and two-chain integration suites
      pass from clean caches.
- [ ] From `packages/protocol`, the complete repository regression commands pass from clean caches:
      `pnpm compile`, `pnpm test`, `pnpm layout:shared`, `pnpm layout:l1`, `pnpm layout:l2`, and
      `pnpm snapshot:l1`; the L1 gas snapshot has no unexplained regression.
- [ ] New-suite line and branch coverage exceed 95%, and every semantic boundary listed above has
      explicit assertions regardless of percentage.
- [ ] Runtime/initcode, maximum gas, storage layouts, ownership, deterministic addresses,
      configuration, deployment transcript, and independent build-conformance gates pass.
- [ ] GitHub CI is green on both PRs except an intentional merge-policy label; neither PR has an
      unresolved Critical/High review finding or open review thread.
- [ ] PR #22064 contains no Solidity/test/tooling diff; PR #22096 contains no unreviewed normative
      design divergence and does not modify a selected production path.
- [ ] Final report distinguishes implementation readiness from production readiness. Real proof
      circuits/keys, calibrated production economics, client/fork support, testnet rehearsal/soak,
      operations/monitoring, and independent proof-system/Solidity/Bridge/economic audits remain
      external release gates even if this plan passes completely.
