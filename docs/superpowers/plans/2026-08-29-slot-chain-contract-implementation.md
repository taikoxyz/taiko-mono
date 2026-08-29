# Slot Chain Contract Suite Multi-Round Implementation Plan

> **For implementation agents:** Follow this plan in order. Use test-driven development and the
> repository's required Solidity test-review agent in every round. Do not collapse rounds or combine
> commits.

**Goal:** Implement and test the complete on-chain Slot Chain design, including the approved
perpetual reverse-auction aggregator seat, as an additive contract suite without changing the
current production-path Inbox, Bridge, or vault behavior before the separately reviewed cutover.

**Architecture:** Permanent non-proxy L1/L2 components and frozen shared custody facades are built
from chain-neutral encodings upward. Each round closes one dependency layer, pins its external ABI
and invariants, passes the owning Foundry profile, and lands as exactly one commit. Cross-chain
composition uses separately compiled artifacts and two chain-specific Anvil instances.

**Tech stack:** Solidity 0.8.30, Foundry, forge-std/CommonTest, TypeScript/ethers v5, Python reference
models, Anvil, pnpm.

**Normative sources:**

- `packages/protocol/docs/preconfirmation-v2/tex/main.tex`
- `packages/protocol/docs/preconfirmation-v2/commitment-model.py`
- `packages/protocol/docs/preconfirmation-v2/lookahead-model.py`
- `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`
- `docs/superpowers/specs/2026-08-29-slot-chain-contract-suite.md`
- `docs/superpowers/specs/2026-08-29-perpetual-aggregator-seat-market.md`

## Rules Applied to Every Round

1. Record `git status --short` and `git diff --stat`. Preserve and never stage unrelated user work;
   each round stages only its enumerated files.
2. Add the smallest failing test first and run its exact focused command. A compile failure caused by
   the intentionally missing implementation is an acceptable first red state.
3. Implement only that round's scope. Production Solidity uses MIT licensing, named imports, full
   interface NatSpec, `@inheritdoc` on implementations, the security contact, underscored private/
   internal names, underscored parameters, suffixed return values, named mapping parameters,
   past-tense events, section dividers, and custom errors at the end.
4. Run focused tests, fuzz/invariant tests, the full owning profile, storage-layout generation,
   `forge fmt --check` on touched files, and `git diff --check`. From Round 4 onward also run
   `pnpm slotchain:artifact-owner:check`; from Round 5 onward it must pass before every commit.
5. Use the repository-required `solidity-tester` subagent to challenge missing reverts, malformed
   returndata, reentrancy, overflow, width, replay, and invariant paths. Also run an independent
   protocol review for critical/high design divergence. Fix surviving findings in the same round
   before committing.
6. Commit exactly once using the listed message. Never weaken a test or add a production bypass to
   make a mock pass.
7. If the implementation exposes a critical design contradiction, exceeds a normative gas/code-size
   bound, or needs a caller-controlled trust assumption, stop the round. Add a failing regression,
   amend the design in a separate reviewed documentation commit, and only then resume.
8. Before coding a round, create and independently review
   `docs/superpowers/plans/slotchain-round-NN-<name>.md`. That round-specific TDD plan must freeze the
   exact ABI, storage slots/packing, constructor and seal matrix, named tests and expected red state,
   focused commands, gas/code-size thresholds, and commit file set. Include the reviewed micro-plan
   in the round's single implementation commit.

## Preflight (No Commit)

**Verify:**

```bash
git status --short --branch
cd packages/protocol
python3 docs/preconfirmation-v2/commitment-model.py
python3 docs/preconfirmation-v2/lookahead-model.py
python3 docs/preconfirmation-v2/settlement-window-model.py
pnpm compile:shared
pnpm compile:l1
pnpm compile:l2
pnpm test:shared
pnpm test:l1
pnpm test:l2
```

Record baseline test counts, runtime bytecode sizes, and gas snapshots. Do not proceed if a change
overlaps this plan's files without an identified owner, or if the baseline fails. Unrelated dirty
paths are preserved and excluded from every round commit.

---

## Round 1: Normative Seat and Economic Alignment

**Files:**

- Modify: `packages/protocol/docs/preconfirmation-v2/tex/main.tex`
- Modify: `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/commitment-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/README.md`
- Regenerate: `packages/protocol/docs/preconfirmation-v2/tex/main.pdf`
- Regenerate: `packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf`
- Create: `packages/protocol/docs/preconfirmation-v2/seat-market-model.py`
- Create: `packages/protocol/docs/preconfirmation-v2/economic-profile.example.json`
- Create: `packages/protocol/docs/preconfirmation-v2/test-seat-market.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/test-settlement-window.py`
- Create: `packages/protocol/script/slotchain/check-slot-chain-docs.sh`
- Modify: `packages/protocol/package.json`

**Steps:**

1. Replace the undefined seat pointer and immediate-burn text with the reviewed transparent,
   perpetual reverse-ask mechanism. Pin one primary, three ordered standbys, four pending offers,
   native-ETH bond tranches, ask maturity, minimum improvement/tenure, event-driven handover,
   pre-funded primary and promotion runway, non-fault funding expiry, delayed release, and exact
   migration treatment. State explicitly that the seat is never proof or consensus authority.
2. Replace the single final-lag penalty with the three-threshold recovery/failover/slash state
   machine. Force-only recovery must not pause or reset the lag duty. Promotion must create a fresh
   duty with a full usable recovery runway, while the old duty and tranche remain independently
   enforceable.
3. Freeze the economic schema for every L1 custody path: builder bond asset and `L_LEASE`, data
   burned rent versus refundable session bond, forced-envelope execution/proof/permanent-cost
   deposit, seat premiums/bonds, reward classes and caps, immutable sinks, and checked formulas.
   Values without real fee/proof measurements remain visibly uncalibrated and production-invalid.
4. Extend the executable models with auction ordering, maturity reset, premium/bond conservation,
   standby promotion funding, responsibility intervals, force-recovery attachment, failover cure,
   final slash, delayed release, and migration-isolation assertions. Include adversarial traces for
   the critical cases in the seat-market specification.
5. Add `slotchain:docs:check` to run every model/unit test, rebuild `tex/main.pdf`, compare it
   byte-for-byte with `slot-chain-spec.pdf` under a pinned `SOURCE_DATE_EPOCH`, and check LaTeX
   references plus repository links.
   Regenerate and visually inspect the PDF, then obtain an independent protocol/economic review. Do
   not start Solidity while either model or the economic schema is ambiguous.
6. Commit: `docs(protocol): integrate perpetual reverse auction design`

## Round 2: Shared Types, Constants, and Consensus Encodings

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/SlotChainTypes.sol`
- Create: `packages/protocol/contracts/shared/slotchain/iface/IComponentConfigV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibSlotChainConstants.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibSlotChainEncoding.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibSlotChainEncoding.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vectors/SlotChainGoldenVectors.sol`
- Create: `packages/protocol/test/shared/slotchain/vectors/slot-chain-commitments.json`
- Create: `packages/protocol/utils/slotchain/generateGoldenVectors.ts`
- Modify: `packages/protocol/docs/preconfirmation-v2/commitment-model.py`
- Modify: `packages/protocol/package.json`

**Steps:**

1. Add failing tests for every Appendix commitment used by a contract: registry/tranche/admission
   leaves and nodes, schedule seed/root, signed header/context, data session/chunk root, queue leaves,
   bridge credit/result/domain/infrastructure, release manifest, canonical statement, reward
   receipt, and terminal leaf/root.
2. Run:
   `cd packages/protocol && FOUNDRY_PROFILE=shared forge test --match-path 'test/shared/slotchain/libs/LibSlotChainEncoding.t.sol' -vv`
   and confirm red.
3. Implement width-specific `abi.encodePacked` helpers. Reject zero/noncanonical fields at the
   calling contracts; encoding helpers must not silently narrow values.
4. Add a deterministic `--json <path>` mode to `commitment-model.py`; normal no-argument behavior
   must remain unchanged. Generate the checked-in JSON, generate Solidity constants only from that
   JSON, and add a pnpm command that fails when either regeneration changes the checked-in files.
5. Re-run the focused test, all three Python models, `pnpm compile:shared`, and `pnpm test:shared`.
6. Commit: `feat(protocol): add slot chain consensus encodings`

## Round 3: Fixed Trees, MMR, Signatures, and Checked Calls

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/libs/LibRegistryTree.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibTrancheTree.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibAdmissionTree.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibDepth64Tree.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibMMR.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibSafeStaticCall.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibSlotChainSignatures.sol`
- Create: `packages/protocol/contracts/shared/slotchain/iface/ISlotChainVerifier.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibSlotChainTrees.t.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibMMR.t.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibSafeStaticCall.t.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibSlotChainSignatures.t.sol`
- Create: `packages/protocol/test/shared/slotchain/mocks/MockStaticCallTarget.sol`

**Steps:**

1. Add failing tests pinning distinct depth-6 registry, depth-9 tranche, depth-11 admission, and
   depth-64 queue/terminal domains and empty nodes. Prove that a valid proof for one tree is invalid
   for every other tree.
2. Add MMR boundary tests at 0, 1, 2,099, and 2,100 leaves; signature tests for low-`s`, `v`, zero
   signer, and EIP-712 domain separation; checked-call tests for wrong code hash, revert, short/long
   returndata, wrong magic, and gas exhaustion.
3. Add depth-64 singleton/range vectors immediately below, at, and above `2^32`, plus
   `UINT64_MAX-1`; prove every index/count operation remains 64-bit and the final unused leaf cannot
   be appended.
4. Run the four focused test files and confirm red.
5. Implement fixed APIs without a caller-selectable tree domain. Implement exact return-length
   assembly checks and ECDSA malleability rejection.
6. Run focused fuzz tests, `pnpm compile:shared`, and `pnpm test:shared`.
7. Commit: `feat(protocol): add slot chain cryptographic primitives`

## Round 4: Compiler-Profile and Artifact Ownership Isolation

**Files:**

- Modify: `packages/protocol/foundry.toml`
- Modify: `packages/protocol/package.json`
- Create: `packages/protocol/utils/slotchain/checkArtifactOwnership.ts`
- Create: `packages/protocol/integration/slotchain/artifact-ownership.test.ts`
- Create: `packages/protocol/integration/slotchain/tsconfig.json`

**Steps:**

1. Pin shared, Layer 1, and Layer 2 compiler/EVM settings, source roots, output directories, and
   artifact ownership before any chain-specific contract exists. Record the exact settings in a
   deterministic machine-readable manifest fragment.
2. Add a checker that rejects a shared implementation compiled into an L1/L2 output directory,
   source-imported by a chain-specific deployment script, or consumed under a different EVM/
   optimizer profile. Later L1/L2 deployment must load raw shared creation bytecode only from the
   shared output.
3. Add `slotchain:artifact-owner:check` and require it in every later round's verification command.
   Prove deliberate cross-profile recompilation and stale artifacts fail.
4. Run clean shared/L1/L2 compiles twice and compare artifact hashes.
5. Commit: `build(protocol): isolate slot chain artifact ownership`

## Round 5: Canonical RLP and Bounded MPT Verification

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/libs/LibCanonicalRLP.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibMptProof.sol`
- Create: `packages/protocol/test/shared/slotchain/proofs/LibCanonicalRLP.t.sol`
- Create: `packages/protocol/test/shared/slotchain/proofs/LibMptProof.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vectors/MptProofVectors.sol`

**Steps:**

1. Add failing canonical RLP/MPT tests for inline/hash references, minimal integers, leading zeros,
   wrong trie keys, surplus nodes/bytes, and the 66-node/600-byte/80,000-byte/8,000,000-gas bounds.
2. Implement bounded canonical decoding and account/storage proof verification. No caller may
   supply a root without the authenticated carrier required by its eventual consumer.
3. Run focused fuzz/gas tests, the shared suite, and `slotchain:artifact-owner:check`.
4. Commit: `feat(protocol): add bounded canonical mpt verification`

## Round 6: Historical Authentication and Migration-Gate Boundaries

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IMigrationGate.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/ISlotChainSyncRouter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibHistoryProof.sol`
- Create: `packages/protocol/test/layer1/slotchain/proofs/LibHistoryProof.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockMigrationGate.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockSlotChainSyncRouter.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockHistoryStorage.sol`

**Steps:**

1. Add failing EIP-2935 tests for fresh and retained canonical headers, exact header hashing, expired
   history, wrong block number/hash, and the arm-history path used by equivocation evidence.
2. Add narrow predeclared gate and sync-router interfaces used before the full router exists. They
   expose the exact phase/generation, permissionless bounded `sync`, fixed active Settlement, and
   exact best/recovery window and data-session reference queries needed by registry retention,
   schedule overwrite, and data GC. Test malformed return data and prove no component can select a
   Settlement target.
3. Implement historical authentication as a thin Layer 1 consumer of Round 5's shared grammar.
4. Run focused fuzz/gas tests, shared/Layer 1 suites, and the artifact-owner check.
5. Commit: `feat(protocol): add slot chain historical authentication`

## Round 7: Immutable Economic Profile and Accounting Primitives

**Files:**

- Modify: `packages/protocol/contracts/shared/slotchain/SlotChainTypes.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibSlotChainEconomics.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibCustodyAccounting.sol`
- Create: `packages/protocol/test/shared/slotchain/economics/LibSlotChainEconomics.t.sol`
- Create: `packages/protocol/test/shared/slotchain/economics/LibCustodyAccounting.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vectors/SlotChainEconomicVectors.sol`
- Create: `packages/protocol/utils/slotchain/generateEconomicVectors.ts`
- Modify: `packages/protocol/package.json`

**Steps:**

1. Add failing cross-language vectors for builder lease collateral, data rent/session bond, forced
   envelope minimum deposit, proof/data reimbursement, seat bond/premium runway, reward-class caps,
   release horizons, and every ceiling-division or saturation boundary.
2. Pin asset ownership: the builder registry binds the profile-selected no-hook ERC20 lease asset;
   data sessions, forced envelopes, the seat market, and reward funding use native ETH. No caller
   may substitute an asset, sink, price source, or formula after construction.
3. Implement pure checked formulas and reusable accounting bucket transitions. Dynamic inputs must
   come from exact protocol-visible values such as `block.blobbasefee`, published blob count/bytes,
   declared execution gas, and immutable profile coefficients; never from a caller-provided quote.
4. Add fuzz/invariant tests for overflow, rounding direction, zero/free cases, forced ETH surplus,
   and `balance >= accounted`. Tainted fixture values must be accepted only by tests; production
   profile generation must reject the uncalibrated marker.
5. Run the three executable models, economic-vector regeneration checks, and the full shared suite.
6. Commit: `feat(protocol): add slot chain economic primitives`

## Round 8: Reverse-Ask Offers, Bond Escrow, and Refund Credits

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IAggregatorSeatMarket.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/ISeatSettlementView.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/AggregatorSeatMarket.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatBook.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatAccounting.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatMarketTestBase.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatOfferBook.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatBondAccounting.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatBondInvariant.t.sol`

**Steps:**

1. Pin the geometry as exactly four installed cells plus exactly four pending cells (`BOOK_SIZE=8`
   total). Add failing tests for ascending pending-ask ranking, deterministic ties,
   one full bond tranche per offer, quote/payout change resetting both timestamp and block maturity,
   strict minimum improvement, maximum ask, exact Settlement version/address/runtime/config opt-in,
   stale-target purge, pull refunds, and Sybil-filled capacity.
2. Add the exact capacity test: with four pending offers, a fifth must either strictly displace the
   worst pending quote or revert; it must never allocate a ninth live cell. Installed terms are not
   part of pending sorting and cannot be displaced by offer insertion.
3. Implement native-ETH bond escrow, displacement refunds, delayed pending exits, forced-ETH
   surplus, and reentrancy-safe pulls. No function calls Settlement or an operator-controlled
   target.
4. Run stateful bond/refund conservation invariants and the artifact-owner check.
5. Commit: `feat(protocol): implement perpetual reverse ask offers`

## Round 9: Seat Premium Reserve and Runway Accounting

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/iface/IAggregatorSeatMarket.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/AggregatorSeatMarket.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatAccounting.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatPremiumFunding.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatPremiumClaims.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatMarketSolvencyInvariant.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockSeatSettlementView.sol`

**Steps:**

1. Add primary activation and segregated per-standby promotion reserves. Pin all runway/tail
   inequalities, checked multiplication, zero-ask behavior, funding expiry, and monotone atomic
   extension.
2. Add delayed premium vesting tests that authenticate exact `previewPremiumCap`; malformed/revert/
   wrong-code responses reject the claim. No wall-clock-only accrual or IOU is permitted.
3. Implement free/reserved premium, claims, funder refunds, penalty credits, surplus, and exact
   `balance >= accounted` transitions without ETH pushes.
4. Run stateful solvency invariants over arbitrary funding/accrual/claim/refund sequences and the
   artifact-owner check.
5. Commit: `feat(protocol): implement seat premium accounting`

## Round 10: Builder Registry and Liability Generations

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IBuilderRegistry.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/BuilderRegistry.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibBuilderRegistry.sol`
- Create: `packages/protocol/test/layer1/slotchain/builder/BuilderRegistryTestBase.sol`
- Create: `packages/protocol/test/layer1/slotchain/builder/BuilderRegistryLifecycle.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/builder/BuilderRegistryReservations.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/builder/BuilderRegistrySlashing.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/builder/BuilderRegistryInvariant.t.sol`

**Steps:**

1. Add failing lifecycle tests for register, delayed activation, replacement, exit, tombstone,
   address-reuse rejection, generation retention, and checked counters.
2. Add reservation tests for `FREE -> RESERVED -> LIABLE -> RELEASED`, 64 active cells, the 512-leaf
   tranche tree, and 1,072 retained generations. Add equivocation tests proving one slash per
   `(builder,window)` and no slash across mismatched contexts.
3. Run:
   `cd packages/protocol && FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/slotchain/builder/*.t.sol' -vv`
   and confirm red.
4. Implement fixed-depth transitions, admission-root versioning, bond/liability accounting, pull
   reporter entitlements, and migration-phase reservation closure.
5. Run the focused suite with 10,000 fuzz runs for proof/index inputs, the stateful invariant suite,
   `pnpm compile:l1`, and `pnpm test:l1`.
6. Commit: `feat(protocol): implement slot chain builder registry`

## Round 11: Schedule Oracle and Authenticated Builder Lookahead

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IScheduleOracle.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IForkScheduleVerifier.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ScheduleOracle.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSchedule.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibBeaconProof.sol`
- Create: `packages/protocol/test/layer1/slotchain/schedule/ScheduleOracleTestBase.sol`
- Create: `packages/protocol/test/layer1/slotchain/schedule/ScheduleOracleSnapshot.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/schedule/ScheduleOracleAllocation.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/schedule/ScheduleOracleRing.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/schedule/ScheduleOracleInvariant.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockBeaconRoots.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockForkScheduleVerifier.sol`

**Steps:**

1. Add failing tests for all-64-cell snapshot reconstruction, EIP-4788/SSZ and EIP-2935/MPT
   authentication, vacant builder cells, exact 384 builder tickets, builder allocation, and
   version-independent seed semantics. `ScheduleOracle` contains no aggregator-seat input, state,
   eligibility, ordering, or authority.
2. Add ring tests for 268 live windows, eight early-seal windows, exact expiry, referenced-window
   overwrite rejection through the fixed sync router's active best/recovery references, and
   one-shot delayed fork-verifier installation.
3. Implement authenticated sealing/allocation using the Round 5/6 proof libraries, `BuilderRegistry`
   roots, and distinct tree domains. Do not accept a caller-supplied root without its authenticated
   carrier.
4. Run focused proof fuzzing, differential checks against `lookahead-model.py`, and full Layer 1
   tests.
5. Commit: `feat(protocol): implement authenticated slot schedules`

## Round 12: Data Sessions and Bounded Availability Accounting

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IDataSession.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/DataSession.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibBlobPointEvaluation.sol`
- Create: `packages/protocol/test/layer1/slotchain/data/DataSessionTestBase.sol`
- Create: `packages/protocol/test/layer1/slotchain/data/DataSessionLifecycle.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/data/DataSessionMMR.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/data/DataSessionKzg.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/data/DataSessionEviction.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/data/DataSessionInvariant.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/vectors/KzgPointEvaluationVectors.sol`

**Steps:**

1. Add failing tests for owner/nonce IDs, two live sessions per owner, blob/manifests, 2,100 leaves,
   1,024 ring cells, seal/expiry, fee accounting, and nonce replay.
2. Add migration tests showing ARMED blocks new work while eight-cell cleanup remains permissionless
   and reaches zero live sessions in at most 128 calls. Before evicting a referenced session, GC must
   permissionlessly sync and clear an expired best through the fixed router; a live reference or
   malformed sync response rejects without eviction.
3. Add exact `BLOBHASH(i)` tests, Fiat-Shamir big-endian field reduction, point-evaluation precompile
   calldata/returndata checks, wrong versioned hash, malformed/reverting precompile responses, and
   append rollback. Check in a genuine independently generated c-kzg positive/negative corpus and
   require exact reproduction before this round may commit; Solidity-only fabricated proofs are
   insufficient. Full production proof-cost benchmarking remains a later release gate.
4. Implement frontier-only MMR storage, checked expiry arithmetic, exact blobhash authentication,
   pull refunds, and bounded eviction.
5. Run focused fuzz/invariant tests, `pnpm compile:l1`, and `pnpm test:l1`.
6. Commit: `feat(protocol): implement slot chain data sessions`

## Round 13: Permanent Forced Queue Core

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IForcedQueue.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IActiveSettlementRouter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ForcedQueue.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibForcedQueueCodec.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/ForcedQueueTestBase.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/ForcedQueueAppend.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/ForcedQueueCursor.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/ForcedQueueExpiry.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/ForcedQueueInvariant.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockIngressRouter.sol`

**Steps:**

1. Add failing golden tests for kind-0 v2 and kind-1 v10 descriptors/leaves, depth-64 frontier/root,
   deposit/fee prefixes, and `dueAt(0)=UINT64_MAX`.
2. Add lifecycle tests for authorized append, phase recheck before custody, stamped generation,
   due-head ordering, missing raw transaction expiry, cursor advancement, exact beneficiary claim,
   authority transfer, and withdrawal reentrancy.
3. Add invariants: `cursor <= count`, roots/counts never decrease, actual ETH balance covers all
   deposits/fees/pull claims, and an append/authority failure leaves every value unchanged.
4. Implement fixed descriptors, authorized adapter identities, checked prefix arithmetic, bounded
   expiry, pull payments, and exact old-to-new active Settlement transfer. The queue never decodes a
   caller transaction.
5. Run focused/invariant Layer 1 suites and the artifact-owner check.
6. Commit: `feat(protocol): implement permanent forced queue`

## Round 14: Kind-0 Decoder and Forced Transaction Ingress

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IForcedTxAdapter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IForcedTxDecoder.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ForcedTxAdapter.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/ForcedTxAdapter.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/ForcedTxDecoderBoundary.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/vectors/ForcedTxVectors.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/TaintedForkTxDecoder.sol`

**Steps:**

1. Define the immutable codehash/config-bound decoder boundary and valid/invalid vectors for every
   proposed launch-fork EIP-2718 type. Parse canonical bytes, recover the sender, and enforce sender,
   chain ID, nonce, intrinsic gas, duplicated length/gas/fee fields, signature canonicality, and
   fork activation. No caller supplies decoded fields.
2. Add phase-before-custody, minimum-deposit, exact descriptor, router stamp, atomic append, replay,
   expiry/refund, malformed-return, and fault-injection tests.
3. Implement the adapter and bind the decoder/runtime/profile. The concrete decoder remains a
   visibly tainted fixture until real fork code exists; production finalization rejects it.
4. Run focused/fuzz Layer 1 tests and the artifact-owner check.
5. Commit: `feat(protocol): implement kind zero forced ingress`

## Round 15: Settlement Normal Path and Proof Statement

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/ISettlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/Settlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSettlementHash.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSettlementNormal.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementTestBase.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementInitialization.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementNormal.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementProof.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockSlotChainVerifier.sol`

**Steps:**

1. Add failing tests for constructor bindings, `PREACTIVE`, imported canonical core, normal arm/
   activation/rearm, candidate improvement ordering, frozen-prefix rules, deadline/tip lag, data and
   schedule commitments, and sequence-tagged history.
2. Add verifier tests that accept only a preinstalled statement hash and reject false, revert,
   malformed return, wrong code hash/profile/version, or excess gas. Prove no canonical write occurs
   before verifier success.
3. Implement the exact public statement and normal candidate state machine. Keep reward transfer,
   burn transfer, and arbitrary external calls out of the commit.
4. Differentially run normal traces against `settlement-window-model.py`; run focused fuzz tests and
   the full Layer 1 profile.
5. Commit: `feat(protocol): implement slot chain normal settlement`

## Round 16: Settlement Recovery and Canonical History

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/iface/ISettlement.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/Settlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSettlementRecovery.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementRecovery.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementHistory.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementInvariant.t.sol`

**Steps:**

1. Add failing recovery tests for due queue preemption, episode/revision/round monotonicity, captured
   parent hash, tier-2/3 proof rules, expiry, no round reopening while ARMED, and first sync recovery
   after reactivation.
2. Add full-core history ring wrap/tag/stale-read tests.
3. Add stateful invariants spanning candidate, recovery, and queue phases; reproduce all
   recovery scenarios from `settlement-window-model.py`.
4. Implement recovery and full-core history without rewards, seat economics, or migration authority.
5. Run focused, invariant, differential, and full Layer 1 tests.
6. Commit: `feat(protocol): implement slot chain recovery history`

## Round 17: Reward Receipts and Migration Readiness

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/iface/ISettlement.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/Settlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IRewardDistributor.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/RewardDistributor.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementMigrationPhase.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementRewardReceipt.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/rewards/RewardDistributor.t.sol`

**Steps:**

1. Add reward-ring collision/expiry/class-cap/claim tests. Reward exhaustion, malformed funding, or
   transfer failure must not affect canonical state.
2. Add `ACTIVE -> MIGRATION_ARMED -> MIGRATION_READY`, exact readiness predicates, abort, first sync
   after abort/reactivation, and permanent `FROZEN` tests. No generic target or state setter exists.
3. Implement best-effort receipts, claim-only distribution, and local migration phases without
   router cutover logic.
4. Run focused, migration-phase, reward-solvency, full Layer 1, and artifact-owner checks.
5. Commit: `feat(protocol): add settlement rewards and migration readiness`

## Round 18: Immutable Seat Terms, Roster, Handover, and Exit

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/iface/ISettlement.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/iface/ISeatSettlementView.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/iface/IAggregatorSeatMarket.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/AggregatorSeatMarket.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/Settlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatTerm.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatTerm.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatHandover.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatExit.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/AdversarialSeatMarket.sol`

**Steps:**

1. Add failing handover tests for leading sync, unchanged canonical/recovery state, maturity,
   minimum tenure/improvement, health headroom, exact staged offer/roster revision, immutable term
   IDs for untouched standbys, funded-runway proof, and atomic installation. Market failure must
   leave the old local lineup untouched.
2. Add exact tests for one tranche creating at most one immutable term, sorted primary/standby
   roster, monotone roster revisions, pending-only competition, upward active repricing rejection,
   payout/quote maturity reset, stage expiry, and reorg rollback of handover.
3. Add two-phase active/standby exit tests: funds remain locked and the term promotable until one
   noncanonical transaction removes the local term and updates market custody atomically.
4. Implement term installation, roster, staging, handover, and exit only; no duty or slash state.
5. Run focused/stateful roster tests, full Layer 1 tests, and artifact-owner check.
6. Commit: `feat(protocol): implement aggregator seat terms`

## Round 19: Local Seat Duty Creation and Qualifying Cure

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/iface/ISeatSettlementView.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/Settlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatDuty.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatDuty.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatDutyBoundary.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatDutyInvariant.t.sol`

**Steps:**

1. Add named boundary tests proving `now == recoveryAt/failoverAt/slashAt` is still curable and only
   `now > threshold` misses. Derive every instant from frozen canonical tip, never maintenance time.
2. Prove cure requires both `newSequence > startingSequence` and
   `newTipSlot >= targetTipSlot`; a one-slot or empty advance does not cure. A canonical commit scans
   no more than `SEAT_COUNT` duties and latches the first satisfying timestamp.
3. Prove force-only recovery attaches one SLA duty exactly when lag crosses recovery, and never
   pauses, resets, duplicates, or shifts a threshold. One tranche creates at most one duty.
4. Implement local duty/ring state and ring-full fail-open to objective vacancy. No canonical path
   calls the market or transfers ETH.
5. Differentially replay the duty traces from `seat-market-model.py`; run focused/invariant tests.
6. Commit: `feat(protocol): implement local seat duties`

## Round 20: Seat Failover, Successor Runway, and Breach Receipts

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/iface/ISeatSettlementView.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/Settlement.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatDuty.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatFailover.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatSuccessor.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatBreach.t.sol`

**Steps:**

1. Prove operational failover terminates without burn, selects only preinstalled standby order, and
   cannot frame an absent, exited, late, or underfunded standby.
2. Pin successor start: a cure before the next revision starts normal promoted service at the commit;
   an open outage starts responsibility only at the next usable round's `roundStartSlot`, targets
   its `escapeSlot`, and has the full deterministic tier-3 runway. Late revision/funding leaves
   vacancy. Test primary cure before and after failover so no successor remains in limbo.
3. Prove cure-through-slash equality, reorg-stability interval, immutable unique breach receipt,
   idempotence, and reorg rollback of satisfaction/failover/breach.
4. Implement fixed local transitions and `previewPremiumCap`, including unsynchronized failover and
   ring-full objective vacancy.
5. Run all force/SLA interleavings against both models and the full Layer 1 invariant suite.
6. Commit: `feat(protocol): implement seat failover and breach receipts`

## Round 21: Asynchronous Seat Enforcement, Reclamation, and Release

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/iface/IAggregatorSeatMarket.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/AggregatorSeatMarket.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/Settlement.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatEnforcement.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatRelease.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatMarketFailureIsolation.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementDutyReclamation.t.sol`

**Steps:**

1. Add exact old-Settlement/version/code/config/term/duty/tranche receipt authentication,
   idempotent slash, current-router forgery rejection, and penalty accounting tests.
2. Add release request/challenge/finalize races, direct retained-duty disposition reads, unmaterialized
   objective breach rejection, finite horizon, and withdrawal-front-running tests.
3. Add noncanonical `reclaimDutyCell` tests: authenticate terminal market state, cache local reuse,
   and prove omission only disables optional economics. Market/release/claim failure never affects
   canonical proof or recovery.
4. Run market/Settlement stateful invariants and full Layer 1 tests.
5. Commit: `feat(protocol): complete seat enforcement and release`

## Round 22: Seat Migration Tombstone and Generation Integration

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/impl/Settlement.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/AggregatorSeatMarket.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatMigration.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatMigrationMarket.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementSeatInvariant.t.sol`

**Steps:**

1. Prove leading sync materializes already-slashable duties; arm closes terms, increments seat
   generation, invalidates old quotes, excuses remaining duties, and leaves economics vacant without
   a market/ETH call.
2. Prove the retained invalid-stage tombstone enables permissionless atomic market unstage/refund
   exactly once. Abort cannot resurrect terms, stage, quotes, generation, or duty liability.
3. Prove old duties/premium caps/releases remain sourced only from the permanent old Settlement,
   while a target requires fresh exact-target/generation operator consent.
4. Run model differential, migration fault injection, full Layer 1, and artifact-owner checks.
5. Commit: `feat(protocol): integrate seat migration isolation`

## Round 23: Version Manager and Router Registry

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/iface/IActiveSettlementRouter.sol`
- Create: `packages/protocol/contracts/shared/slotchain/iface/IBridgeDomainRegistry.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IBridgeInboxAdapter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IProtocolVersionManager.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ActiveSettlementRouter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ProtocolVersionManager.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/iface/IAggregatorSeatMarket.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/AggregatorSeatMarket.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibReleaseManifest.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/MigrationTestBase.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/ProtocolVersionManager.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/ActiveSettlementRouter.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatMarketAuthorization.t.sol`

**Steps:**

1. Add failing tests for delayed manifest/cancel authorization, increasing versions/generations,
   exact runtime/config/profile checks, stable ingress stamps, append-only version registration,
   historical routing, and canceled-manifest replay rejection.
2. Add the real manager-only append path for exact
   `(version, settlement, runtimeHash, configHash, market, seatGeneration)` authorization. Reject
   canceled/replayed manifests and mismatched markets. Support append-only installation disablement
   of an old market while leaving its premium claims, historical enforcement, reclamation, and
   releases callable forever.
3. Implement manager delay/cancel records and router registry/history reads using precomputed
   constructor addresses. Expose no activation shortcut or generic target setter in this round.
4. Run manager/router/market focused and stateful registry tests plus the artifact-owner check.
5. Commit: `feat(protocol): add slot chain version registry`

## Round 24: Proof-First V2 Cutover, Abort, and Real Seat Isolation

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/impl/ActiveSettlementRouter.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/ProtocolVersionManager.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/V2Cutover.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/MigrationAbort.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/MigrationSeatIsolation.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/MigrationInvariant.t.sol`

**Steps:**

1. Add ARMED/READY sync, exact target proof, queue authority, history import, atomic activation,
   delayed exact-target abort, and canceled-generation replay tests.
2. Fault-inject every external boundary. Failure preserves old canonical/queue authority, target
   PREACTIVE state, history, gate generation, and already-terminalized seat state.
3. Using the real Market and both real Settlements, prove no seat ETH, term, duty, or confiscation
   authority moves; old duties/releases/enforcement remain readable only from old Settlement; old
   generation quotes cannot install after arm, abort, or cutover; stage-tombstone cancellation is
   exact-once; and both abort and target remain vacant pending fresh operator consent.
4. After cutover, exercise the separate noncanonical manager call that authorizes the exact active
   Settlement tuple in its Market; it may not run for a canceled, inactive, mismatched, or replayed
   manifest. Canonical cutover never calls the Market.
5. Implement cutover/abort without resurrecting consumed terms or seat generation. Run at least 20
   migration/abort generations, full Layer 1 tests, and artifact-owner check.
6. Commit: `feat(protocol): implement reversible slot chain cutover`

## Round 25: Storage-Compatible Legacy Inbox Drain and Quiescence

**Files:**

- Modify: `packages/protocol/contracts/layer1/core/impl/Inbox.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/ILegacyInboxMigration.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/LegacyInboxSlotChainMigration.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibLegacyMigrationStorage.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/LegacyInboxUpgrade.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/LegacyInboxDrain.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/LegacyInboxQuiescence.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/LegacyInboxStorageLayout.t.sol`

**Steps:**

1. Factor no-op internal admission/proposal hooks into the existing `Inbox` and prove its current
   behavior and storage layout are unchanged. Add upgrade tests for the storage-compatible migration
   implementation's namespaced state.
2. Add failing tests for `DRAINING`: new legacy forced admission rejects, proposals/proofs continue,
   and every already-admitted forced record leaves only through native consume/expiry/void rules.
   Pin auditable queue-empty and unsettled-escrow predicates. Add `QUIESCENT` tests that arm only at
   the exact finalized boundary, stop new proposals/ingress, retain old authority, and reversibly
   restore legacy operation on the separately delayed cancellation.
3. Implement the storage-compatible staged Inbox migration with no arbitrary state setter, target,
   or permanent pause. Prove failed/cancelled quiescence restores the exact pre-arm behavior and
   cannot strand admitted messages or escrow.
4. Run current Inbox regressions, storage-layout comparison, native-drain tests, quiescence fault
   injection, gas caps, and all Layer 1 tests.
5. Commit: `feat(protocol): add legacy inbox drain migration`

## Round 26: Proof-First One-Shot Legacy Launch

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/ILegacySlotChainLaunchAdapter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IExecutionHeaderDecoder.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/LegacySlotChainLaunchAdapter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibTopologyProof.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/ExecutionHeaderDecoder.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/LegacyLaunch.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/LegacyLaunchCancel.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/vectors/ExecutionHeaderVectors.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/TaintedExecutionHeaderDecoder.sol`

**Steps:**

1. Extend the Round 5 RLP/MPT corpus with exact legacy Inbox, checkpoint, account, storage, and
   proxy/fork topology proofs. Add launch tests for drained forced state, finalized header,
   Anchor/Bridge/vault slots, L2 empty state, first proof base, and cancellation.
2. Add profile-bound execution-header vectors for canonical RLP, fork fields, timestamp-to-slot,
   and exact next-basefee/next-excess-blob-gas recurrence. The concrete decoder stays a tainted test
   fixture and production finalization rejects it until real fork code is supplied.
3. Prove launch/cancel burns that generation's legacy import/freeze authority and cannot be reused
   for V2 migration. Fault-inject every proof and authority-transfer boundary; failure must leave
   the old Inbox operational or quiescent exactly as the pre-call state requires.
4. Implement bounded topology verification and the one-shot adapter. It authenticates already-
   finalized L2 Bridge/vault code and storage through the launch header/MPT proofs and verifies
   already-frozen local L1 endpoints; it never calls across domains or mutates imported L2 state.
   Use fixture runtimes here; final shared-profile facade bytecode lands after the facade rounds.
   Do not put legacy authority in the router or version manager.
5. Run proof fuzzing, launch/cancel fault injection, topology/storage checks, gas caps, and all
   Layer 1 tests.
6. Commit: `feat(protocol): implement proof first legacy slot chain launch`

## Round 27: L2 Activation Gate and Terminal Accumulator

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/iface/IInboxV2ActivationGate.sol`
- Create: `packages/protocol/contracts/shared/slotchain/iface/ITerminalAccumulatorV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/InboxV2ActivationGate.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/TerminalAccumulatorV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/libs/LibTerminalAccumulator.sol`
- Create: `packages/protocol/test/layer2/slotchain/terminal/InboxV2ActivationGate.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/terminal/TerminalAccumulatorV2.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/terminal/TerminalAccumulatorInvariant.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/mocks/MockTerminalBridge.sol`

**Steps:**

1. Add failing tests for false-to-true one-shot activation, writer registration, sentinel static read,
   DONE/FAILED leaf construction, depth-64 append, completed nodes, historical node/proof reads, and
   checked count exhaustion.
2. Add invariants that root/count are append-only, a domain/Bridge writer cannot be redirected, and
   a failed Bridge read or conflicting terminal leaves state unchanged.
3. Implement immutable registrar/gate bindings and exact fixed-depth proof APIs.
4. Run focused fuzz/invariant tests, `pnpm compile:l2`, and `pnpm test:l2`.
5. Commit: `feat(protocol): implement permanent terminal accumulator`

## Round 28: L2 Forced Inbox Router and Credit Stores

**Files:**

- Create: `packages/protocol/contracts/layer2/slotchain/iface/IInboxApplyRouterV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/iface/IInboxCreditStoreV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/InboxApplyRouterV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/InboxCreditStoreV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/libs/LibInboxRows.sol`
- Create: `packages/protocol/test/layer2/slotchain/inbox/InboxTestBase.sol`
- Create: `packages/protocol/test/layer2/slotchain/inbox/InboxCreditStoreV2.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/inbox/InboxApplyRouterV2.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/inbox/InboxApplyRouterInvariant.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/mocks/MockInboxCreditStore.sol`

**Steps:**

1. Add failing store tests for exact slots, permanent idempotent pins, conflict rejection, fixed
   process deadline, Bridge-only verification, inactive gate, and no consumption/deletion.
2. Add router tests for complete zero-to-64 intervals, all dispositions, exact 533-byte kind-1
   descriptor, no duplicates, contiguous same-domain runs, route code/config rechecks, exact `IBV2`
   return word, rollback on any store failure, cursor-after-calls ordering, and one call per block.
3. Add stateful invariants for cursor monotonicity, permanent pins, atomic multi-domain application,
   and at most 64 fixed calls/128 fresh writes.
4. Implement both non-proxy contracts and run worst-case gas tests with the required margin.
5. Run focused/invariant suites and all Layer 2 tests.
6. Commit: `feat(protocol): implement l2 forced inbox routing`

## Round 29: L2 Release Authority and Registrar

**Files:**

- Create: `packages/protocol/contracts/layer2/slotchain/iface/IProtocolReleaseAuthorityV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/iface/ITerminalDomainRegistrarV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/ProtocolReleaseAuthorityV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/TerminalDomainRegistrarV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/libs/LibL2ReleaseManifest.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/libs/LibL1ManifestProof.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/ReleaseTestBase.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/ProtocolReleaseAuthorityV2.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/TerminalDomainRegistrarV2.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/LibL1ManifestProof.t.sol`

**Steps:**

1. Add failing tests for per-version manifests, manifest-supplied Anchor identity/runtime, exact
   component descriptors, append-only route/writer/release registration, domain uniqueness, and
   atomic gate activation through a fixed Anchor boundary mock.
2. Add negative tests for direct EOA/Bridge/alternate-Anchor calls, partial seals, repeated versions,
   fresh proxy endpoints, and component config mismatch.
3. Implement the per-version authority, atomic registrar, and thin L2 wrapper over Round 5's shared
   MPT grammar for the L1 manager proof.
4. Run focused/fuzz Layer 2 tests and artifact-owner check.
5. Commit: `feat(protocol): implement l2 release registration`

## Round 30: AnchorV4 Storage and Authenticated Legacy Topology

**Files:**

- Create: `packages/protocol/contracts/layer2/slotchain/iface/IAnchorV4.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/AnchorV4.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/AnchorV4.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/AnchorTopology.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/AnchorStorageLayout.t.sol`

**Steps:**

1. Pin existing Anchor storage compatibility and the exact legacy proxy/beacon/fork-selector slots,
   implementation runtime, reserved system origin, and one-shot activation effects.
2. Reject unlisted implementation, mutable routing, wrong beacon/fork selector, live authority,
   direct alternate callers, and partial release effects.
3. Implement profile-compatible AnchorV4 logic and prove activation plus per-block anchoring against
   the real authority/registrar/gate.
4. Run storage-layout, topology, origin, fault-injection, full Layer 2, and artifact-owner checks.
5. Commit: `feat(protocol): implement anchor v4 topology`

## Round 31: L1 Terminal Verification and Destination Support Registry

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/iface/ITerminalSignalVerifier.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/TerminalSignalVerifier.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/BridgeDomainRegistry.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/TerminalSignalVerifier.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/BridgeDomainRegistry.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/BridgeDomainRegistryInvariant.t.sol`

**Steps:**

1. Add failing terminal tests for exact version/sequence tagged canonical history, canonicalization
   depth, domain/Bridge/credit/status leaf binding, 64 siblings, count/index bounds, and stale ring
   rejection.
2. Add destination registry tests for staged manifest entries, exact registrar account/code/storage
   MPT proof, 214-block support delay, append-only source/destination/endpoint entries, 64-entry
   release cap, and conflicting duplicate rejection.
3. Implement immutable router/depth verification and manager-only staging plus permissionless proof
   confirmation. Reuse only the shared bounded MPT library from Round 5.
4. Run focused fuzz/invariant/gas tests and all Layer 1 tests.
5. Commit: `feat(protocol): implement bridge domain authentication`

## Round 32: Immutable Bridge Credit Registry

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/iface/IBridgeCreditRegistry.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/BridgeCreditRegistry.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/BridgeCreditRegistry.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockFrozenBridge.sol`

**Steps:**

1. Add failing tests for exact credit-ID derivation, immutable authorization fields, one frozen
   Bridge caller, source generation/execution binding, DIRECT/CAPSULE mode rules, duplicate IDs,
   and exact fixed-size enqueue-record return data.
2. Add tests proving the registry cannot mutate an authorization after creation and cannot create a
   liability, queue status, or terminal state on behalf of the Bridge.
3. Implement the non-proxy registry using the precomputed Bridge address and width-checked records.
4. Run focused fuzz tests, both Layer 1 and shared compiles, and all Layer 1 tests.
5. Commit: `feat(protocol): implement immutable bridge credits`

## Round 33: Frozen Bridge V1 Facade and Storage Compatibility

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/iface/IBridgeV1Frozen.sol`
- Create: `packages/protocol/contracts/shared/slotchain/impl/BridgeV2Facade.sol`
- Create: `packages/protocol/contracts/shared/slotchain/impl/BridgeV2Facade_Layout.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibBridgeV1Compat.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV2FacadeTestBase.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV2V1Compatibility.t.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV1SolvencyInvariant.t.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV2FrozenSurface.t.sol`

**Steps:**

1. Pin the current Bridge storage layout, selectors, return values, message counter/hash, V1 events,
   signals, status, process/retry/fail/recall behavior, and proxy implementation/authority slots.
2. Add arbitrary-calldata/selector fuzzing proving there is no upgrade, generic storage, delegate,
   arbitrary target, or protected-slot mutation path. Assert runtime code size under EIP-170.
3. Implement the complete frozen V1 behavior without inheriting a UUPS upgrade surface. All V1
   payouts and sweeps enforce post-balance liability floors, and reserved V2 namespaces remain
   untouched.
4. Run current Bridge regression parity, shared invariants, storage-layout diff, selector corpus,
   code-size checks, and full shared tests.
5. Commit: `feat(protocol): freeze bridge v1 compatibility facade`

## Round 34: Bridge V2 Source Credit Lifecycle

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/iface/IBridgeV2.sol`
- Modify: `packages/protocol/contracts/shared/slotchain/impl/BridgeV2Facade.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibBridgeV2.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV2SourceLifecycle.t.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV2SolvencyInvariant.t.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV2SourceIsolation.t.sol`

**Steps:**

1. Add failing tests for DIRECT/CAPSULE creation, DRAFT finalization, NEW cancellation, QUEUED
   marking, DONE finalization, FAILED recall, exact liabilities, pull credits, and aggregate
   solvency. V1 entrypoints must never probe, mutate, or account V2 state.
2. Bind the immutable domain and credit registries. Both V2 send selectors reject until the exact
   source/destination registration is confirmed and its 214-block delay matures; a later domain or
   generation never retroactively enables an older tuple.
3. Add replay, width, deadline, zero-value, cancellation/finalization race, reentrancy, and
   post-balance liability tests. Faults in V2 must preserve every V1 status, signal, and reserve.
4. Implement the source lifecycle and pull accounting, then rerun V1 parity, storage layout,
   selector corpus, code-size, source invariants, and all shared tests.
5. Commit: `feat(protocol): implement bridge v2 source lifecycle`

## Round 35: Destination Bridge Execution and Terminalization

**Files:**

- Modify: `packages/protocol/contracts/shared/slotchain/iface/IBridgeV2.sol`
- Modify: `packages/protocol/contracts/shared/slotchain/impl/BridgeV2Facade.sol`
- Modify: `packages/protocol/contracts/shared/slotchain/libs/LibBridgeV2.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV2DestinationLifecycle.t.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV2TerminalOrdering.t.sol`
- Create: `packages/protocol/test/shared/slotchain/bridge/BridgeV2Reentrancy.t.sol`
- Create: `packages/protocol/test/shared/slotchain/mocks/MockInboxCreditStore.sol`
- Create: `packages/protocol/test/shared/slotchain/mocks/MockTerminalAccumulator.sol`
- Create: `packages/protocol/test/shared/slotchain/mocks/AdversarialMessageReceiver.sol`

**Steps:**

1. Add failing tests for process/retry/fail/expire, gas/value/calldata ownership checks, permanent pin
   authentication, TTL, RETRIABLE behavior, and DONE/FAILED terminal uniqueness.
2. Add fault-injection tests for recipient revert/reentrancy, accumulator revert/malformed index,
   wrong sentinel, duplicated terminalization, and rollback. Pin the order: recipient execution,
   terminal decision, sentinel write, accumulator append, returned-index write.
3. Implement destination lifecycle with fixed store/accumulator bindings and no V2 dependency on
   SignalService.
4. Run focused fuzz/reentrancy/invariant tests, code-size/gas checks, and all shared tests.
5. Commit: `feat(protocol): complete bridge v2 terminal lifecycle`

## Round 36: Bridge Inbox Adapter and Kind-1 Ingress

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/impl/BridgeInboxAdapter.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/BridgeInboxAdapter.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/BridgeInboxAdapterInvariant.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MockBridgeV2.sol`

**Steps:**

1. Add failing tests for one-shot destination-domain seal, source registry/Bridge/runtime checks,
   exact joined credit record, NEW-only enqueue, deadline, support delay, NONE/QUEUED idempotence,
   fee forwarding, queue index, and source `markQueuedV2` rollback.
2. Add ARMED/READY tests for stamped `syncIngress` and `appendFromAdapter`: SYNCED creates no record,
   retains no queue funds, and credits the full caller fee for pull withdrawal.
3. Add invariants that one `creditId` appends at most once, queue and Bridge status agree atomically,
   adapter balance equals pull claims, and a cancelled generation can never enqueue.
4. Implement immutable dependencies and exact kind-1 v10 append flow.
5. Run focused/invariant tests and all Layer 1 tests.
6. Commit: `feat(protocol): implement bridge forced inbox adapter`

## Round 37: Refund Capsules and ERC20 Vault/Token Facades

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/iface/IRefundRestorableV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/iface/IERC20VaultV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/impl/ERC20VaultV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/impl/BridgedERC20RefundV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibRefundCapsule.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/VaultV2TestBase.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC20VaultV2.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC20RefundRestorableV2.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC20VaultV2Invariant.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC20VaultV2FrozenSurface.t.sol`

**Steps:**

1. Pin the official ERC20 vault/token storage layouts and V1 behavior. Add failing V2 send tests for
   same-transaction DRAFT credit lookup, 256-word capsule bound, capsule hash finalization,
   fungible reservations, fee-on-transfer rejection, and full rollback on finalize failure. The
   full-NatSpec interface pins every additive selector, return, event, and custom-error owner.
2. Add permissionless claim tests for CANCELLED/RECALLED credits, exact refund vault, once-per-credit
   claim/restoration, quota/pause bypass only on the claim path, and preservation of every unrelated
   reserve.
3. Add malicious token/receiver, reentrancy, rounding, and arbitrary-selector tests. Burn/mint mode
   accepts only exact frozen restoration runtime.
4. Implement the frozen storage-compatible ERC20 facade and restoration template without Bridge callbacks
   on claims or an upgrade/delegate surface.
5. Run focused ERC20 tests, invariants, storage layout, code-size/gas checks, and full shared
   tests.
6. Commit: `feat(protocol): implement erc20 refund capsules`

## Round 38: ERC721 Refund Vault and Token Facade

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/iface/IERC721VaultV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/impl/ERC721VaultV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/impl/BridgedERC721RefundV2.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC721VaultV2.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC721RefundRestorableV2.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC721VaultV2Invariant.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC721VaultV2FrozenSurface.t.sol`

**Steps:**

1. Pin the official ERC721 vault/token storage and V1 behavior. Add exact-token-ID capsule,
   reservation, cancellation/recall, restoration-runtime, duplicate claim, malicious receiver,
   reentrancy, and unrelated-reserve tests.
2. Implement the ERC721-specific frozen facade using the shared capsule grammar; no loop may exceed
   the profile cap and no claim may consult mutable routing or pause state.
3. Run focused/fuzz/invariant, V1 parity, layout, selector, code-size, gas, and shared tests.
4. Commit: `feat(protocol): implement erc721 refund capsules`

## Round 39: ERC1155 Refund Vault and Token Facade

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/iface/IERC1155VaultV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/impl/ERC1155VaultV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/impl/BridgedERC1155RefundV2.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC1155VaultV2.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC1155RefundRestorableV2.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC1155VaultV2Invariant.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vault/ERC1155VaultV2FrozenSurface.t.sol`

**Steps:**

1. Pin official ERC1155 storage/V1 behavior and add bounded-batch capsules, exact ID/amount pairs,
   duplicates, partial-batch rollback, malicious receiver, reentrancy, restoration, and independent
   reserve tests.
2. Implement the frozen facade with the shared capsule grammar and profile-bounded batch loop. V2
   claim failure must not alter V1 state or another capsule.
3. Run focused/fuzz/invariant, V1 parity, layout, selector, code-size, gas, and shared tests.
4. Commit: `feat(protocol): implement erc1155 refund capsules`

## Round 40: Per-Domain Legacy Bridge Installation and Freeze

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/iface/ILegacyCustodyFreezeCoordinator.sol`
- Create: `packages/protocol/contracts/shared/slotchain/impl/LegacyBridgeFreezeCoordinator.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibLegacyProxyFreeze.sol`
- Create: `packages/protocol/test/shared/slotchain/freeze/LegacyBridgeFreeze.t.sol`
- Create: `packages/protocol/test/shared/slotchain/freeze/LegacyBridgeFreezeInvariant.t.sol`

**Steps:**

1. Using the actual legacy ERC1967/UUPS Bridge proxy and storage on each domain, prove the prestate implementation,
   owner/pending-owner and authority slots, resolver/fork slots, custody liabilities, V1 mappings,
   and manifest runtime/layout/config hashes before the first irreversible write.
2. In one chain-local revert domain, consume that domain's one-shot governance authorization, install only the raw
   shared-profile `BridgeV2Facade` implementation, run its storage-compatible freeze initializer,
   clear/burn every UUPS/owner/alternate routing authority, and verify the poststate slots/runtime.
   The final implementation contains no upgrade/delegate/arbitrary-target selector.
3. For L2, execute the freeze in an ordinary L2 governance block before quiescence and check in
   golden transaction, receipt, header, account/storage proof, and poststate vectors. The later L1
   launch only authenticates that finalized L2 state. For L1, execute the separate L1 coordinator;
   neither domain pretends to roll back or mutate the other.
4. Fault-inject ownership, upgrade, initializer, and postcheck boundaries independently per domain.
   Failure/cancellation preserves that domain's custody; success is irreversible and replay-proof.
5. Distinguish legacy proxy endpoints from fresh immutable endpoints. Run V1 parity, storage,
   selector, custody-solvency, per-domain gas, full shared, and artifact-owner checks.
6. Commit: `feat(protocol): freeze legacy bridge custody`

## Round 41: Proof-First Legacy Vault Installation and Freeze

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/impl/LegacyVaultFreezeCoordinator.sol`
- Create: `packages/protocol/test/shared/slotchain/freeze/LegacyVaultFreeze.t.sol`
- Create: `packages/protocol/test/shared/slotchain/freeze/LegacyVaultFreezeInvariant.t.sol`

**Steps:**

1. Prove exact prestate implementation/authority/fork slots, storage layouts, V1 mappings, fungible
   reserves, and exact NFT custody for every official ERC20/ERC721/ERC1155 legacy vault proxy.
2. On each domain independently, atomically install only the three raw shared-profile frozen implementations, initialize their V2
   capsule namespaces, burn all upgrade/owner/alternate routing authority, and postcheck runtime,
   layout, config, reserves, and selector surfaces. A failure at any vault reverts all vault changes.
3. Execute L2 vault freezes in an ordinary finalized L2 governance block before quiescence and
   check in golden transaction/receipt/poststate/header/MPT vectors. Execute L1 freezes through the
   independent L1 coordinator. The Round 26 launch adapter only proves the L2 results and checks
   local L1 frozen state; it never executes L2 upgrades.
4. Run per-domain rollback/gas tests, all vault V1/V2 invariants, cross-facade custody conservation,
   launch proof rejection for any mismatched code/slot, shared-profile ownership, and full shared/
   L1/L2 tests.
5. Commit: `feat(protocol): freeze legacy vault custody`

## Round 42: Deterministic Deployment and Contract Profile Fragments

**Files:**

- Create: `packages/protocol/script/layer1/slotchain/DeploySlotChainL1.s.sol`
- Create: `packages/protocol/script/layer2/slotchain/DeploySlotChainL2.s.sol`
- Create: `packages/protocol/utils/slotchain/generateContractProfileFragment.ts`
- Create: `packages/protocol/utils/slotchain/finalizeExecutionProfile.ts`
- Create: `packages/protocol/utils/slotchain/generateTaintedTestManifest.ts`
- Create: `packages/protocol/utils/slotchain/checkSlotChainArtifacts.ts`
- Create: `packages/protocol/integration/slotchain/fixtures/tainted-test-manifest.json`
- Modify: `packages/protocol/integration/slotchain/tsconfig.json`
- Create: `packages/protocol/integration/slotchain/profile.test.ts`
- Create: `packages/protocol/integration/slotchain/deployment.test.ts`
- Modify: `packages/protocol/package.json`
- Modify: `packages/protocol/foundry.toml`

**Steps:**

1. Add failing tests for the fixed CREATE nonce sequence, every constructor reference, initial-zero
   slot, one-shot sealer, authority-burn slot, runtime hash, storage-layout hash, config hash, and
   acyclic profile-hash derivation.
2. Implement separate L1 and L2 deployment scripts. For every shared Bridge/vault component they
   load raw creation bytecode from `out/shared`, append ABI-encoded constructor arguments, deploy it
   through the fixed CREATE coordinator/nonce sequence, and assert the resulting `EXTCODEHASH`
   against the shared-profile artifact. They must not source-import and `new` a shared
   implementation under a chain-specific profile. Scripts consume a manifest but do not enable V2
   or mutate existing production contracts.
3. Generate a reproducible **contract profile fragment** from real shared/L1/L2 artifacts. This
   fragment contains no verifier-key or circuit claim. Reject zero hashes, unknown topology, wrong
   owning EVM profile, dirty generated output, or a dependency cycle.
4. Add a production finalizer that accepts only a real verifier runtime/key binding, circuit public
   statement metadata, and cross-language executable-profile inputs. It must remain red while those
   inputs are absent or test-tainted.
5. Generate a separately named, visibly tainted local integration manifest using the deterministic
   test verifier. Only the local integration harness may consume it; profile finalization and
   deployment checks reject it.
6. Configure the Node 20 built-in test runner through
   `node --test -r ts-node/register integration/slotchain/*.test.ts` and a dedicated CommonJS
   integration `tsconfig.json`. Add exact `test:slotchain:integration`,
   `slotchain:fixture:check`, and `slotchain:production-rejection:test` package scripts. The first
   proves fixture confinement/reproducibility; the second passes only when production finalization
   rejects every tainted or incomplete input.
7. Build `shared`, `layer1`, and `layer2` separately; run the artifact checker and prove deterministic
   byte-for-byte fragment/test-manifest regeneration.
8. Commit: `feat(protocol): add deterministic slot chain deployment profiles`

## Round 43: Cross-Chain Functional Integration

**Files:**

- Create: `packages/protocol/integration/slotchain/harness.ts`
- Create: `packages/protocol/integration/slotchain/normal-settlement.test.ts`
- Create: `packages/protocol/integration/slotchain/recovery.test.ts`
- Create: `packages/protocol/integration/slotchain/bridge-done.test.ts`
- Create: `packages/protocol/integration/slotchain/bridge-failed.test.ts`
- Create: `packages/protocol/integration/slotchain/migration.test.ts`
- Create: `packages/protocol/integration/slotchain/seat-market.test.ts`
- Create: `packages/protocol/integration/slotchain/adversarial.test.ts`
- Modify: `packages/protocol/package.json`

**Steps:**

1. Start separate Anvil instances for Layer 1 and Layer 2 using the appropriate hardfork/profile.
   Deploy shared artifacts built under the shared profile and chain-specific artifacts from their
   own output directories. Use only the tainted local manifest and deterministic test verifier.
   The Anvil harness directly exercises the contract effects of the reserved system sender; it does
   not claim to encode, admit, or execute the custom type-`0x7f` transaction or its fork rules. Bind
   deterministic localhost ports 9545/9546 and chain IDs 1/167000; health-check both JSON-RPC
   endpoints before tests and always terminate child processes in test teardown and CI traps.
2. Execute end-to-end normal, recovery, forced-expiry, bridge DONE, bridge FAILED/recall, migration,
   migration abort/retry, repeated-generation, reverse-auction handover, funded standby promotion,
   force-recovery duty, failover/cure/slash, duty reclamation, release, and real legacy Bridge/vault
   proof-first freeze/rollback scenarios. Relay only authenticated commitments.
3. Inject every fixed-target failure and malformed response. Re-run stateful invariants across the
   complete suite and fuzz arbitrary entrypoint sequences.
4. Run all profile suites plus the integration harness twice with deterministic startup/teardown;
   compare fixtures, roots, events, balances, and final state hashes.
5. Commit: `test(protocol): add slot chain cross chain integration`

## Round 44: Gas, Code-Size, Storage-Layout, and Production Gates

**Files:**

- Create: `packages/protocol/script/slotchain/check-production-gates.sh`
- Create: `packages/protocol/gas-reports/slot-chain-contracts.txt`
- Create: `packages/protocol/test/layer1/slotchain/gas/SlotChainL1Maximums.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/gas/SlotChainL2Maximums.t.sol`
- Create: `packages/protocol/test/shared/slotchain/gas/SlotChainSharedMaximums.t.sol`
- Create: `packages/protocol/storage-layout/slotchain/expected-layouts.json`
- Create: `packages/protocol/utils/slotchain/checkSlotChainGas.ts`
- Create: `packages/protocol/utils/slotchain/checkSlotChainStorageLayouts.ts`
- Create: `packages/protocol/utils/slotchain/scanTaintedArtifacts.ts`
- Create: `packages/protocol/utils/slotchain/evaluateProductionStatus.ts`
- Modify: `packages/protocol/package.json`

**Steps:**

1. Benchmark every normative maximum with 30% margin: seat book/stage/claim, fixed duty scan,
   schedule seal, data post/seal/eviction, queue append/expiry/advance, normal/recovery proof commit,
   64-row L2 apply, terminal append/proof, bridge/vault terminal claims, each L1/L2 Bridge/vault
   freeze coordinator, and migration cutover.
2. Fail on margin regression, EIP-170 breach, initcode limit, unexpected external call, or storage
   layout drift. Compare against manifest/profile operation and block limits, never Foundry's
   permissive test block limit; a missing production limit keeps the production gate red.
3. Implement a gate evaluator that always runs every subcheck and emits deterministic JSON with
   `READY` or `BLOCKED` plus the exact missing/failed gates. Prove the tainted fixture runs local
   integration but yields `BLOCKED`; model real verifier/key, calibrated economics, fork decoder,
   client conformance, external audit, and soak evidence as distinct entries.
4. Add exact `slotchain:gas:check`, `slotchain:storage-layout:check`, `slotchain:taint-scan`, and
   `slotchain:production-status` commands that pass when evaluation itself is complete. Add
   `slotchain:production-status:test` that requires the present exact `BLOCKED` list, and a separate
   `slotchain:release-gates` command that executes `check-production-gates.sh` and exits nonzero
   unless status is `READY`.
5. Run every artifact/vector/profile/layout/gas/taint/status check twice from clean outputs, compare
   hashes, and prove the release command currently fails for only the enumerated missing artifacts.
6. Commit: `test(protocol): enforce slot chain production gates`

## Round 45: CI, Independent Final Audits, and Documentation

**Files:**

- Modify: `.github/workflows/protocol.yml`
- Modify: `packages/protocol/docs/preconfirmation-v2/README.md`
- Modify: `packages/protocol/package.json`
- Create: `packages/protocol/docs/preconfirmation-v2/contract-implementation-report.md`

**Steps:**

1. Run:

   ```bash
   cd packages/protocol
   python3 docs/preconfirmation-v2/commitment-model.py
   python3 docs/preconfirmation-v2/lookahead-model.py
   python3 docs/preconfirmation-v2/settlement-window-model.py
   python3 docs/preconfirmation-v2/seat-market-model.py
   python3 -m unittest discover -s docs/preconfirmation-v2 -p 'test-*.py'
   pnpm slotchain:docs:check
   pnpm slotchain:vectors:check
   pnpm compile:shared && pnpm compile:l1 && pnpm compile:l2
   pnpm slotchain:artifact-owner:check
   pnpm test:shared && pnpm test:l1 && pnpm test:l2
   pnpm test:slotchain:integration
   pnpm slotchain:artifacts:check
   pnpm slotchain:storage-layout:check
   pnpm slotchain:gas:check
   pnpm slotchain:taint-scan
   pnpm slotchain:production-status
   pnpm slotchain:production-status:test
   pnpm slotchain:fixture:check
   pnpm slotchain:production-rejection:test
   forge fmt --check contracts test script
   git diff --check
   ```

2. Run independent Solidity, protocol-soundness, auction/economic-solvency, bridge-solvency,
   migration/liveness, and test-gap reviews. Resolve every critical/high finding with a failing
   regression before this commit; do not waive findings through prose.
3. Add deterministic CI jobs for vector/artifact/layout/gas checks and cross-chain integration,
   with explicit Anvil health checks, timeouts, trap-based cleanup, and uploaded gas logs. CI runs
   the evaluator and asserts the reviewed `BLOCKED` status; it does not require the separate release
   command to pass until the missing external artifacts are supplied.
4. Update the README and report with exact contract/test counts, artifact hashes, audit findings,
   and honest gate status. Keep **not deployable** while any circuit/verifier key, economic
   calibration, executable-profile client conformance, external audit, or testnet soak artifact is
   absent.
5. Commit: `test(protocol): complete slot chain contract implementation`

## Final Acceptance

Implementation is complete only when every ordered reviewed round (including any separately
reviewed design-correction round required by Rule 7) has one commit, no Slot Chain implementation
change is uncommitted, every profile and integration test passes, generated artifacts are
reproducible, all specified invariants hold, and no critical/high review finding remains. Unrelated
pre-existing user changes are neither a failure nor part of these commits.

Production readiness is a separate verdict. Contracts alone cannot satisfy the circuit/verifier-key,
custom transaction/fork, cross-language profile, external audit, and soak requirements. The final
report must list each remaining non-contract gate and must not call the suite deployable until those
artifacts are real and independently reviewed.
