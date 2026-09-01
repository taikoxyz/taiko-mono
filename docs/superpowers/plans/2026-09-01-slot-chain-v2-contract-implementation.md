# Slot Chain V2 Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement and test the complete additive Slot Chain V2 contract suite without selecting it
on any production path.

**Architecture:** Build the protocol from byte-exact shared primitives upward into isolated L1 and
L2 non-proxy components. Each round starts with a failing Foundry test, closes one bounded authority
or accounting boundary, is independently challenged, and lands as one code/test commit on the
stacked implementation branch.

**Tech Stack:** Solidity 0.8.30, Foundry, forge-std/CommonTest, Python reference models,
TypeScript/ethers v5, two Anvil chains, pnpm 9.15.9.

---

## 1. Branch and artifact policy

The branch split is normative for the work:

- `claude/chain-liveness-builder-roles-cda13y` / PR #22064 owns every design, LaTeX, PDF,
  executable-model and implementation-plan change.
- `codex/slot-chain-v2-contracts` / its active stacked implementation PR owns only Solidity,
  Foundry tests, generated test vectors, required build/profile tooling and integration harnesses.
  PR #22092 was the zero-diff staging PR and is already marked merged; the first code commit opens
  its replacement from the same branch against PR #22064's head.
- After a design-plan commit lands on PR #22064, fast-forward the implementation branch to that
  commit before adding code. The implementation PR must never carry a documentation diff against
  its base.
- If code exposes a design contradiction, stop the implementation round. Add the regression to the
  executable model and fix the normative sources on PR #22064, obtain review, then fast-forward the
  code branch and resume. Never hide a contradiction with a Solidity-only exception.

Normative sources, in order:

1. `packages/protocol/docs/preconfirmation-v2/tex/main.tex`
2. `packages/protocol/docs/preconfirmation-v2/commitment-model.py`
3. `packages/protocol/docs/preconfirmation-v2/lookahead-model.py`
4. `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`
5. `packages/protocol/docs/preconfirmation-v2/test-settlement-window.py`
6. `docs/superpowers/specs/2026-09-01-slot-chain-v2-contract-implementation-design.md`
7. `packages/protocol/CLAUDE.md`

The August 29 specification and 45-round plan are historical only. In particular, do not restore
the deleted legacy vault/refund-facade suite, caller-selected migration targets, shared-cap rewards,
seatless scheduling, fixed-window auctions, relayer authority or live V1 custody reuse.

## 2. Locked file structure

```text
packages/protocol/contracts/
  shared/slotchain/
    SlotChainTypes.sol                 consensus-width structs and enums only
    iface/                             full-NatSpec external boundaries
    libs/                              encodings, trees, MMR, RLP/MPT, calls, signatures, math
    impl/                              chain-neutral immutable custody helpers, if required
  layer1/slotchain/
    iface/                             L1 interfaces
    libs/                              pure transition and accounting libraries
    impl/                              registry, schedule, queue, settlement, market, migration,
                                       source Bridge and terminal verifier
  layer2/slotchain/
    iface/                             L2 interfaces
    libs/                              route, credit, context and terminal helpers
    impl/                              activation, apply router, stores, destination Bridge, pool,
                                       release authority, registrar and accumulator

packages/protocol/test/
  shared/slotchain/                    shared unit, fuzz and invariant tests
  layer1/slotchain/                    L1 unit, fuzz, handler and integration tests
  layer2/slotchain/                    L2 unit, fuzz, handler and integration tests

packages/protocol/integration/slotchain/
  artifacts.ts                         profile-owned artifact loader
  deploy.ts                            deterministic two-chain deployment
  relay.ts                             commitment-authenticated relay helper
  slot-chain-v2.integration.test.ts    end-to-end scenarios

packages/protocol/utils/slotchain/
  generateGoldenVectors.ts             Python-to-JSON-to-Solidity vector generation
  checkArtifactOwnership.ts            cross-profile ownership and hash checker
  checkDeploymentTranscript.ts         deterministic address/config/runtime checker
```

Do not put a production contract and its test harness in the same file. Interfaces own complete
NatSpec; implementations use `@inheritdoc`. All non-test Solidity files use MIT, named imports and
`/// @custom:security-contact security@taiko.xyz`.

## 3. Rules applied to every implementation round

- [ ] Read the exact normative subsection and its model transition before writing the round plan.
- [ ] Add or update the round-specific plan only on PR #22064, review it, and fast-forward the
      stacked implementation branch.
- [ ] Record `git status --short` and stage only the round's enumerated code/test files.
- [ ] Write the smallest failing test first and run its focused command to confirm a meaningful red
      state.
- [ ] Implement only the minimum behavior needed for that round, including typed errors and exact
      post-reads.
- [ ] Ask the repository-required `solidity-tester` subagent to challenge reverts, widths,
      reentrancy, replay, overflow, gas bounds, boundary equality and rollback.
- [ ] Run an independent code/security review for Critical and High findings and fix them before the
      commit.
- [ ] Run the focused tests, owning Foundry profile, formatter, `git diff --check`, artifact-owner
      checker once available, and storage/gas checks appropriate to the round.
- [ ] Commit exactly once using the listed message. The commit contains code and tests only.

Use `/Users/d/.pyenv/shims/python3` for the executable models because it provides the required
Keccak implementation. Use the repository-pinned pnpm 9.15.9; do not let a different pnpm rewrite
the lockfile.

## 4. Preflight — no commit

**Files:** None.

- [ ] **Step 1: Confirm the stacked branches are aligned**

  Run:

  ```bash
  git fetch origin
  git merge-base --is-ancestor origin/claude/chain-liveness-builder-roles-cda13y HEAD
  git diff --exit-code origin/claude/chain-liveness-builder-roles-cda13y...HEAD -- docs
  ```

  Expected: success and no documentation diff.

- [ ] **Step 2: Run every executable design oracle**

  Run from `packages/protocol/docs/preconfirmation-v2`:

  ```bash
  /Users/d/.pyenv/shims/python3 commitment-model.py
  /Users/d/.pyenv/shims/python3 lookahead-model.py
  /Users/d/.pyenv/shims/python3 settlement-window-model.py
  /Users/d/.pyenv/shims/python3 -m unittest test-seat-market.py
  /Users/d/.pyenv/shims/python3 -m unittest test-economic-profile.py
  /Users/d/.pyenv/shims/python3 test-settlement-window.py
  ```

  Expected: 648 commitment vectors / 1,409 assertion sites, 38 lookahead properties, 184 settlement
  properties, 102 seat tests, 38 economics tests and 254 settlement tests.

- [ ] **Step 3: Record existing Solidity baselines**

  Run from `packages/protocol`:

  ```bash
  FOUNDRY_PROFILE=shared forge build
  FOUNDRY_PROFILE=layer1 forge build
  FOUNDRY_PROFILE=layer2 forge build
  FOUNDRY_PROFILE=shared forge test
  FOUNDRY_PROFILE=layer1 forge test
  FOUNDRY_PROFILE=layer2 forge test
  ```

  Expected: baseline passes, or any unrelated baseline failure is recorded before Slot Chain files
  are created.

## 5. Implementation rounds

### Round 1: Profile isolation and artifact ownership

**Files:**

- Modify: `.github/workflows/protocol.yml`
- Modify: `packages/protocol/foundry.toml`
- Modify: `packages/protocol/package.json`
- Create: `packages/protocol/utils/slotchain/checkArtifactOwnership.ts`
- Create: `packages/protocol/utils/slotchain/artifact-ownership.json`
- Create: `packages/protocol/integration/slotchain/artifact-ownership.test.ts`
- Create: `packages/protocol/integration/slotchain/default-profile-isolation.test.ts`
- Create: `packages/protocol/integration/slotchain/shared-artifact-consumption.test.ts`
- Create: `packages/protocol/integration/slotchain/tsconfig.json`
- Create: `packages/protocol/test/shared/slotchain/fixtures/LibSourceInlineProbe.sol`
- Create: `packages/protocol/test/shared/slotchain/fixtures/ISharedArtifactProbe.sol`
- Create: `packages/protocol/test/shared/slotchain/fixtures/SharedArtifactProbe.sol`
- Create: `packages/protocol/test/layer1/slotchain/build/SourceInlineL1Consumer.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/build/SourceInlineL2Consumer.t.sol`

- [ ] **Step 1: Write a failing ownership test** that deliberately presents a shared bytecode
      artifact under `out/layer1` and asserts rejection with `CROSS_PROFILE_RECOMPILE`. Also reject
      a missing owner, output-path drift, an unlisted artifact and a lifecycle/address-scope mismatch.
- [ ] **Step 2: Run** `pnpm exec ts-node integration/slotchain/artifact-ownership.test.ts` and
      confirm it fails because the checker is absent.
- [ ] **Step 3: Publish an exhaustive ownership manifest** with disjoint `source-inline` and
      `artifact-owned` classes. `source-inline` is limited to types, interfaces, constants and
      libraries whose production members are exclusively internal. Each such row pins the canonical
      source hash, source kind, allowlisted consumer profiles and compiler-language version.
      ABI-only interfaces may declare external functions but must produce no bytecode; internal
      libraries must expose no public/external production function and consumers must produce no
      link reference. No source-inline row may have independently loaded bytecode, a deployed
      address or a release-manifest row. `artifact-owned` covers every deployable and raw creation
      artifact and pins its sole owning profile/output, compiler tuple, consumption mode, factory
      class and lifecycle/address scope. An ABI-only consumer imports a separately classified
      source-inline interface, never the artifact-owned implementation. Any externally linked
      library is confined to its artifact-owner profile; logic shared by L1 and L2 must be internal
      source-inline code or an ordinary external ABI boundary.
      The manifest-named owning profile for the
      storage-compatible legacy Inbox/SignalService artifacts is exactly `layer1` (`out/layer1`,
      `cache/layer1`), and AnchorV4 is exactly `layer2` (`out/layer2`, `cache/layer2`); neither is
      compiled by `default` or a second profile. Configure `default` to skip every Slot Chain source,
      and route each test only through `test/shared/slotchain`, `test/layer1/slotchain` or
      `test/layer2/slotchain`. Build-info has no trustworthy profile-name field: the checker binds a
      profile to the clean `FOUNDRY_PROFILE=<name>` invocation and fixed output directory, then
      compares `forge config --json` source/test/script/out/cache and compiler settings with the
      manifest. `default`, `genesis` and `layer1o` are explicit forbidden-owner profiles whose
      recursive Slot Chain skip is pinned and checked. The checker consumes the complete Foundry
      build-info standard input/output, validates format/compiler/settings/exact source content and
      source AST, rejects duplicate compiler outputs, and byte-for-byte cross-checks the single
      `output.contracts[sourcePath][contractName]` object against the emitted artifact JSON. The
      AST for every managed source must be a structurally valid Solidity `SourceUnit`: its root
      `nodeType` is `SourceUnit`, `nodes` is an array, and every child is an object with a string
      `nodeType`. Missing, falsy or malformed AST data is never evidence, including for a
      `free-definitions` row that emits no contract artifact. The
      artifact-owned checker key is
      `(sourcePath, contractName, profile, solcVersion, evmVersion, optimizerRuns, abiHash,
linkReferencesHash, immutableReferencesHash, creationHash, runtimeHash)` and fails closed on
      any absent or duplicate owner.
- [ ] **Step 4: Prove both real cross-profile consumption mechanisms before protocol code exists.**
      First, implement a test-only internal hashing library with the same call shape as the planned
      encoding/proof libraries and import it from L1 and L2 consumers. Inspect build-info/ABI/link
      references to prove both profiles compiled the exact manifest-pinned source, exposed no
      external/public library function and inlined it with zero link references. Second, build one
      shared deployable artifact and a separate source-inline interface. Both L1 and L2 tests load
      the exact creation bytes only from `out/shared`, deploy them, and call through that interface;
      prove neither consumer recompiled the artifact-owned implementation. A source import of an
      artifact-owned implementation is an explicit failure even when its hash happens to match.
      Every usage row binds the owned module to an exact artifact-owned consumer module and its
      owning profile, and names the exact source-inline interface when ABI consumption is claimed.
      The checker proves that the consumer and interface are present in that profile's build input,
      that their source and ABI hashes match their manifest rows, that the consumer imports the
      named interface, and that raw-bytecode consumption passes the owner's canonical artifact path
      to `vm.getCode`. These facts are read from the compiler AST rather than matched in source
      comments. A test-only direct-CREATE usage must additionally be a `.t.sol` consumer whose AST
      contains the `CREATE` path. A declaration without this compiled, hash-pinned evidence is not
      consumption and cannot satisfy a required consumer profile.
- [ ] **Step 5: Add** `slotchain:artifact-owner:check` and run clean shared/L1/L2 builds twice.
      Each build uses `--force --build-info --ast --extra-output storage-layout`; a warm incremental
      artifact directory is not admissible evidence.
      Run the default-profile exclusion build with CLI-overridden temporary out/cache/build-info
      paths so it cannot erase the three owner-profile outputs, and inspect build-info inputs as
      well as emitted artifacts so free-definition sources cannot escape the check.
      For source-inline rows, compare source hashes, allowed profile inputs, ABI and zero link
      references across every compiler output, including consumers outside the Slot Chain source
      subtree. Reject a symlink at a scanned source/output root as well as any nested symlink. For
      artifact-owned rows, compare creation/runtime/link/immutable-reference hashes
      and prove a later profile consumes the content-addressed shared artifact without producing a
      second owned artifact. Constructor-derived component configuration hashes are deliberately
      deferred to the Round-24 deployment-transcript checker; Round 1 must not invent them from
      compiler output.
- [ ] **Step 6: Wire one clean-checkout aggregate command into protocol CI.** It runs the isolated
      default exclusion build, forced shared/L1/L2 builds, both cross-profile Solidity consumer
      tests and all adversarial checker tests. Because Forge tests have FFI authority and build
      outputs are mutable, the final trust point then force-rebuilds shared, L1 and L2 once more and
      immediately runs the ownership checker with no executable test in between. Standalone L1/L2
      test commands force-rebuild the shared owner artifact before use; existence alone is not
      freshness evidence.
- [ ] **Step 7: Treat this as a stop gate.** If the checker cannot distinguish and enforce
      source-inline compilation from artifact-owned bytecode/ABI consumption, or Foundry cannot
      support either selected mechanism, do not weaken the checker or start Round 2. Return to PR
      #22064 and revise the artifact architecture first.
- [ ] **Step 8: Commit** `build(protocol): isolate slot chain artifact ownership`.

### Round 2: Consensus types, constants and golden encodings

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/SlotChainTypes.sol`
- Create: `packages/protocol/contracts/shared/slotchain/iface/IComponentConfigV2.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibSlotChainConstants.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibSlotChainEncoding.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibSlotChainEncoding.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vectors/SlotChainGoldenVectors.sol`
- Create: `packages/protocol/test/shared/slotchain/vectors/slot-chain-commitments.json`
- Create: `packages/protocol/utils/slotchain/generateGoldenVectors.ts`
- Modify: `packages/protocol/utils/slotchain/artifact-ownership.json`
- Modify: `packages/protocol/package.json`

- [ ] **Step 1: Generate the JSON oracle** from `commitment-model.py` without changing its normal
      no-argument results.
- [ ] **Step 2: Write failing tests** for every on-chain Appendix encoding: builder/tranche,
      schedule, signed header/context, data, queue, candidate, canonical history, reward receipt, migration,
      Bridge, release, retirement/successor, ICV2 and terminal commitments.
- [ ] **Step 3: Run**
      `FOUNDRY_PROFILE=shared forge test --match-path 'test/shared/slotchain/libs/LibSlotChainEncoding.t.sol' -vv`
      and confirm a missing-library red state.
- [ ] **Step 4: Implement width-specific helpers** using explicit casts before arithmetic and no
      caller-selectable domain. A representative API is:

  ```solidity
  function hashForcedUserLeaf(
      uint64 _index,
      SlotChainTypes.Kind0ForcedDescriptorV2 memory _descriptor
  )
      internal
      pure
      returns (bytes32 hash_);
  ```

- [ ] **Step 5: Regenerate and compare** JSON and Solidity vectors byte-for-byte. The generator has
      a check-only mode and obtains expected values one-way from the Python model; it does not
      recompute a second expected result in TypeScript or Solidity. Solidity tests independently
      construct the fixture inputs and call the production encoding library.
- [ ] **Step 6: Extend the exhaustive ownership manifest** before running the focused tests, all
      Python models, shared build/test and artifact ownership. Classify production types/constants/
      encodings and the generated vector helper as source-inline rows with the appropriate kind and
      profile allowlist, and classify the shared Forge test as a test-only artifact-owned row. No
      new Slot Chain source may be exempted from the Round-1 gate merely because it is generated or
      test-only.
- [ ] **Step 7: Commit** `feat(protocol): add slot chain consensus encodings`.

### Round 3: Fixed trees, MMR, signatures and checked calls

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/libs/LibRegistryTree.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibTrancheTree.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibAdmissionTree.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibDepth64Tree.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibMMR.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibExactCall.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibSlotChainSignatures.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibSlotChainTrees.t.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibMMR.t.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibExactCall.t.sol`
- Create: `packages/protocol/test/shared/slotchain/libs/LibSlotChainSignatures.t.sol`
- Create: `packages/protocol/test/shared/slotchain/mocks/ExactCallTarget.sol`

- [ ] **Step 1: Write failing cross-domain tree tests** proving a depth-6 proof cannot verify as
      depth-9, depth-11 or depth-64.
- [ ] **Step 2: Add failing boundaries** at 0, 1, maximum-1 and maximum for every tree/MMR count,
      including the final unused depth-64 leaf.
- [ ] **Step 3: Add failing call/signature cases** for code-hash mismatch, wrong magic/length,
      trailing bytes, revert, OOG/EIP-150 reserve, high-`s`, bad `v` and zero signer.
- [ ] **Step 4: Implement fixed-domain APIs** and exact return-length assembly checks.
- [ ] **Step 5: Run** the four focused tests, fuzz them, and run the shared profile.
- [ ] **Step 6: Commit** `feat(protocol): add slot chain cryptographic primitives`.

### Round 4: Canonical RLP, bounded MPT and historical carriers

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/libs/LibCanonicalRLP.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibMptProof.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibHistoryProof.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IRegistrationMptVerifierV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/RegistrationMptVerifierV2.sol`
- Create: `packages/protocol/test/shared/slotchain/proofs/LibCanonicalRLP.t.sol`
- Create: `packages/protocol/test/shared/slotchain/proofs/LibMptProof.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/proofs/LibHistoryProof.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/proofs/RegistrationMptVerifier.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vectors/MptProofVectors.sol`

- [ ] **Step 1: Write failing canonicality tests** for leading zeros, nonminimal lengths, surplus
      nodes/bytes, inline/hash reference confusion, wrong trie key and every normative size/gas cap.
- [ ] **Step 2: Write failing EIP-2935/EIP-4788 carrier tests** for future, missing, expired and
      substituted roots.
- [ ] **Step 3: Write the exact RegistrationMptVerifierV2 corpus** for the twelve-field locally
      derived statement, canonical 452+ceil32(proof.length) ABI, public-input/proof schema hashes,
      66/132 node caps, 600-byte node cap, 80,000-byte proof cap, configuration getter and
      8,000,000-gas dispatch. Pin the configuration getter's exact four-byte calldata, exactly
      50,000-gas STATICCALL and exactly one 32-byte return. Reject one-less gas, substituted
      statements, caller roots, Boolean returns, wrong code/config, malformed proof/calldata/return,
      revert and OOG before support state.
- [ ] **Step 4: Implement bounded decoders and the immutable profile-pinned verifier** that consume
      the complete input and return only the locally recomputed statement hash; no default verifier
      or caller-trusted root exists.
- [ ] **Step 5: Run** focused fuzz/gas tests and shared plus L1 profiles.
- [ ] **Step 6: Commit** `feat(protocol): add bounded historical proof verification`.

### Round 5: Economic profile and custody accounting

**Files:**

- Create: `packages/protocol/contracts/shared/slotchain/libs/LibSlotChainEconomics.sol`
- Create: `packages/protocol/contracts/shared/slotchain/libs/LibCustodyAccounting.sol`
- Create: `packages/protocol/contracts/shared/slotchain/iface/INativeEthSinkV2.sol`
- Create: `packages/protocol/test/shared/slotchain/economics/LibSlotChainEconomics.t.sol`
- Create: `packages/protocol/test/shared/slotchain/economics/LibCustodyAccounting.t.sol`
- Create: `packages/protocol/test/shared/slotchain/vectors/SlotChainEconomicVectors.sol`

- [ ] **Step 1: Write failing differential vectors** for lease collateral, data rent/bond, forced
      deposit, the non-consensus reward cap formula, seat runway, slash and release horizons.
- [ ] **Step 2: Write invariant handlers** asserting the one-Settlement-account relation
      `balance >= liveBondLiability + refundBondLiability + totalRewardFunding`, exact equality of
      the reward total to its three class buckets, disjoint liabilities and exact conservation/
      surplus sweeping under forced ETH.
- [ ] **Step 3: Implement checked formulas** with explicit rounding direction and typed immutable
      NATIVE_ETH sink boundaries; reject zero/uncalibrated production fields. The sink fixture must
      reject callbacks/reentrancy and cannot become canonical-progress authority.
- [ ] **Step 4: Run** economic Python tests, focused fuzz/invariants and shared profile.
- [ ] **Step 5: Commit** `feat(protocol): add slot chain economic primitives`.

### Round 6: Builder registry and liability generations

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IBuilderRegistry.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/BuilderRegistry.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibBuilderRegistry.sol`
- Create: `packages/protocol/test/layer1/slotchain/registry/BuilderRegistry.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/registry/BuilderEvidence.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/registry/BuilderRegistryInvariant.t.sol`

- [ ] **Step 1: Write failing tests** for registration, replacement, deterministic tie victim,
      tombstone, liability retention, address reuse, tranche reservation and release equality.
- [ ] **Step 2: Confirm red** with the registry test path.
- [ ] **Step 3: Add the complete equivocation corpus** before implementation: two distinct low-`s`
      headers in the exact same context, independent EIP-2935 arm authentication, one membership
      proof under the signed admission root, one under the current admission root for the same
      retained generation/index, current tranche proof for exactly the derived window, and equality
      at `evidenceReplayDeadline(W)`. Cross-context, stale-history, newer-generation, mismatched-root,
      duplicate and one-second/one-block-late evidence must fail without credit or slash.
- [ ] **Step 4: Implement** a fixed 64-entry active set, versioned generations, O(1) reverse indexes,
      bounded replacement and idempotent `(builder,window)` evidence. A first valid report atomically
      tombstones the key, slashes only that window's retained tranche and creates the exact reporter
      pull credit; no operator callback or push payment is permitted.
- [ ] **Step 5: Implement and fault-test** the immutable `componentConfigHashV2()` and
      `rewardClassV1(uint8)` views over the constructor-written, writerless tier rows. Pin exact
      selector, 36-byte calldata, 224-byte RCV1/config-echo/class-echo/term return, 50,000-gas
      STATICCALL behavior, canonical padding, unknown-class rejection and short/trailing/OOG/
      caller-dependent faults.
- [ ] **Step 6: Fuzz** maximum churn and prove a retained key cannot re-enter before all evidence
      horizons expire, while distinct windows remain independently slashable.
- [ ] **Step 7: Run** L1 tests, layout, gas and artifact checks.
- [ ] **Step 8: Commit** `feat(protocol): add slot chain builder registry`.

### Round 7: Authenticated schedule and cross-window builder boundaries

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IScheduleOracle.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IScheduleForkVerifierV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ScheduleForkVerifierV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ScheduleOracle.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibBuilderSchedule.sol`
- Create: `packages/protocol/test/layer1/slotchain/schedule/ScheduleOracle.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/schedule/ScheduleForkVerifierRegistry.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/schedule/ScheduleForkVerifier.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/schedule/ScheduleBoundaryInvariant.t.sol`

- [ ] **Step 1: Import failing golden schedule vectors** for zero, one, six and 64 eligible
      builders.
- [ ] **Step 2: Add explicit first/last tests** proving each window owns an independent tranche,
      the same key may occupy only the boundary pair, and the global same-key run is at most two.
- [ ] **Step 3: Pin the fork-verifier wire protocol** before sealing logic: exact FVI1/FVR1/SFV1/
      SFC1 selectors, fixed return lengths, canonical padding, code/config hashes, strict increasing
      `firstWindow`, immutable predecessor successor pair, unique interval selection, delayed PVM-only
      installation with exactly 500,000 gas, getter with exactly 100,000 gas, and verifier row bound
      in `[100,000,5,000,000]`. Fault-inject one-less gas, revert, OOG, wrong interval,
      caller-dependent getter, short/trailing return and statement/header mismatch with zero writes.
- [ ] **Step 4: Implement** authenticated snapshot, quota allocation, deterministic placement,
      immutable sealing, the concrete current-fork verifier with reviewed Deneb/Electra/Fulu
      gindices/witness schema, append-only delayed fork registry and bounded retained-window ring.
- [ ] **Step 5: Fuzz** tombstone timing, missing carrier, reorg, verifier-boundary and ring-wrap cases.
- [ ] **Step 6: Run** lookahead differential, L1 tests and gas at maximum eligibility.
- [ ] **Step 7: Commit** `feat(protocol): add authenticated builder schedule`.

### Round 8: Settlement-owned data sessions and availability accounting

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/ISlotChainSettlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IActiveSettlementRouter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/SlotChainSettlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibDataSessions.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibDataMMR.sol`
- Create: `packages/protocol/test/layer1/slotchain/data/SettlementDataSessions.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/data/DataSessionInvariant.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/ActiveSettlementRouterStub.sol`

- [ ] **Step 1: Create the immutable Settlement shell and write failing tests** for its internal
      1,024-cell region, 2,100-record cap, at-most-two LIVE cells per owner, sorted unique
      references, post/seal expiry equality, point-evaluation binding, refunds, forfeiture and exact
      8-cell GC. There is deliberately no second data-session contract or custody address.
- [ ] **Step 2: Implement inside Settlement** the tagged ring, owner/live/sequence counters, bounded
      MMR frontier, live-owner-only index and exact accounting/MAPS views used by migration. The
      same Settlement balance owns refundable bond and rent liabilities; ordinary payable fallback,
      receive, migration and maintenance paths reject value, and only the specified session entry
      points can increase session custody.
- [ ] **Step 3: Inject failures** after rent, blob validation, MMR append, seal and refund credit and
      assert complete rollback.
- [ ] **Step 4: Pin deployment and migration poststate** for PREACTIVE/ACTIVE gates, empty-cell
      cursor, exact MAPS tuple, constructor layout hash and `balance >= session liabilities`; prove a
      second custody/session authority cannot satisfy the manifest. Settlement reads the one shared
      gate word through the immutable ActiveSettlementRouter; there is no gate account, setter or
      replaceable contract.
- [ ] **Step 5: Run** fuzz/invariants, 128-call maximum migration cleanup and L1 gas tests.
- [ ] **Step 6: Commit** `feat(protocol): add bounded data sessions`.

### Round 9: Permanent forced queue and kind-0 ingress

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IForcedQueue.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ForcedQueue.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/Kind0IngressAdapter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibForcedIngress.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/ForcedQueue.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/Kind0IngressAdapter.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/queue/ForcedQueueInvariant.t.sol`

- [ ] **Step 1: Write failing tests** for stamped two-phase append, 64-bit count/frontier,
      prefix liabilities, due monotonicity, capacity, dynamic deposit and refundable sync.
- [ ] **Step 2: Prove direct queue append, stale stamp, wrong adapter and post-sync replay fail.**
- [ ] **Step 3: Implement** immutable queue authority, typed descriptors, O(64) frontier update and
      pull credits. A representative boundary is:

  ```solidity
  function appendFromAdapterV2(
      uint64 _activeProtocolVersion,
      uint64 _routerGeneration,
      uint8 _kind,
      bytes calldata _descriptorBytes
  ) external payable returns (uint8 result_, uint64 index_);
  ```

- [ ] **Step 4: Fault-inject** every write boundary and assert adapter/Router/Queue atomicity.
- [ ] **Step 5: Run** L1 fuzz/invariants and maximum-count gas checks.
- [ ] **Step 6: Commit** `feat(protocol): add permanent forced ingress`.

### Round 10: Settlement normal path and canonical history

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/iface/ISlotChainSettlement.sol`
- Create: `packages/protocol/contracts/shared/slotchain/iface/ISlotChainVerifier.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/SlotChainSettlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibCandidateValidation.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibCanonicalHistory.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementNormal.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementHistory.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/SlotChainVerifierStub.sol`

- [ ] **Step 1: Write failing tests** for context arm/activation, all three tiers, signed timestamp,
      parent gap, data references, queue interval and exact verifier statement.
- [ ] **Step 2: Add rollback tests** for verifier reject/revert/OOG/bad return, queue fault and
      history fault.
- [ ] **Step 3: Implement proof-first validation** and monotone sequence-indexed canonical history;
      no market/operator call occurs on this path.
- [ ] **Step 4: Differential-test** every commitment against Python vectors.
- [ ] **Step 5: Run** L1 profile, layout and worst-case candidate gas.
- [ ] **Step 6: Commit** `feat(protocol): add slot chain normal settlement`.

### Round 11: Recovery, unsigned escape and liveness

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/impl/SlotChainSettlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibRecovery.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementRecovery.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/SettlementLivenessInvariant.t.sol`

- [ ] **Step 1: Write failing equality tests** for objective entry, renewable expiry, final lag,
      forced-head boundaries, `G_MAX`, EIP-2935 geometry and zero sentinels.
- [ ] **Step 2: Write a stateful liveness handler** where every builder/seat is malicious and only a
      permissionless tier-3 prover acts.
- [ ] **Step 3: Implement deterministic recovery targets** with bounded prefix count/bytes/gas,
      no discretionary transactions and reconstructable prestate requirements.
- [ ] **Step 4: Prove** stale rounds, insufficient depth, unavailable data and omitted due messages
      reject without blocking a later valid escape.
- [ ] **Step 5: Run** settlement differential, invariants and maximum recovery gas.
- [ ] **Step 6: Commit** `feat(protocol): add permissionless slot chain recovery`.

### Round 12: Perpetual reverse-ask market book and premiums

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IAggregatorSeatMarket.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/ISeatSettlementView.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/AggregatorSeatMarket.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatBook.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatAccounting.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatMarketTestBase.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatOfferBook.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatPremiumInvariant.t.sol`

- [ ] **Step 1: Write failing tests** for four installed plus four pending cells, reverse-ask order,
      deterministic ties, maturity reset, minimum improvement, exact target/generation cache and
      stale-offer purge.
- [ ] **Step 2: Write custody invariants** for bond tranches, premium reserves, pull refunds,
      runway and forced ETH surplus.
- [ ] **Step 3: Implement** continuous offers with no fixed auction window and no consensus/proof
      authority.
- [ ] **Step 4: Fuzz** Sybil-filled capacity, replacement, top-up, accrual, funding expiry and
      migration-stage cancellation.
- [ ] **Step 5: Run** the Python seat oracle, L1 fuzz/invariants and gas.
- [ ] **Step 6: Commit** `feat(protocol): add perpetual aggregator seat market`.

### Round 13: Seat terms, duties, failover and release

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/impl/SlotChainSettlement.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/AggregatorSeatMarket.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatDuty.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibSeatWire.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatTerm.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatDuty.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatFailover.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/seat/SeatReleaseInvariant.t.sol`

- [ ] **Step 1: Write failing APPLY tests** proving installation creates no duty and strict
      `now > recoveryAt` creates exactly one duty from the then-current responsibility base.
- [ ] **Step 2: Add first/last transition tests** separating builder schedule liabilities from seat
      duties at every window boundary.
- [ ] **Step 3: Add failing handover/failover tests** for mature best replay, pre-funded successor,
      late cure, next usable revision, no-duty funding expiry, full-lineup vacancy and slash.
- [ ] **Step 4: Implement** fixed four-seat roster, O(1) duty reverse indexes, immutable tranches,
      asynchronous enforcement and permissionless release/reclamation.
- [ ] **Step 5: Fault-inject** every Settlement-Market call and prove canonical progress remains
      independent.
- [ ] **Step 6: Run** seat oracle, L1 handler invariants, layout and gas.
- [ ] **Step 7: Commit** `feat(protocol): add aggregator seat duty lifecycle`.

### Round 14: Reward receipts and migration readiness

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/impl/SlotChainSettlement.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibRewardMetering.sol`
- Create: `packages/protocol/test/layer1/slotchain/settlement/RewardReceipts.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/MigrationReadiness.t.sol`

- [ ] **Step 1: Write failing reward tests** for tier-derived class selection,
      proof-authenticated execution-gas/published-byte metrics, cap-aware payout arithmetic, exact
      receipt commitment, timestamp/deadline and reorg-margin equality boundaries, all 256
      collision positions in each class-local ring, cross-class saturation isolation, expiration,
      insufficient funding, transfer failure, reentry and double
      claim. Exercise reward-to-session/sweep/canonical and session/sweep-to-reward cross-reentry
      against the single Settlement guard and the one physical ETH balance.
- [ ] **Step 2: Prove class, metric, profile, beneficiary and timestamp substitution fail.** Pin
      that losing candidates and improvement levels receive no protocol receipt, data rent remains
      unreimbursed, and a full/live same-class receipt ring only emits `receiptStored=false` without reverting
      canonical progress.
- [ ] **Step 3: Implement three class-isolated 256-cell best-effort immutable receipt rings** and separately accounted per-class
      funding buckets on the immutable Settlement with permissionless exact-beneficiary pull claims. The claim path computes
      `min(cap,fixed+perGas*gas+perByte*bytes)` with cap-aware checked arithmetic, marks/debits
      before transfer in one revert domain, exact-reads the immutable BuilderRegistry class row,
      has no funding withdrawal/sweep, uses the profile's immutable word-106 claim window and
      word-85 reorg margin, and is not a canonical dependency.
- [ ] **Step 4: Implement bounded readiness** for sessions, seats, queue and canonical boundary with
      exact fixed-width views.
- [ ] **Step 5: Run** economics oracle, focused tests, L1 profile and gas.
- [ ] **Step 6: Commit** `feat(protocol): add reward metering and migration readiness`.

### Round 15: Source Bridge bundle, quota and route package

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/ISourceBridgeV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IBridgeCreditRegistryV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IBridgeDomainRegistryV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IBridgeInboxAdapterV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/SourceFactoryV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/SourceBundleDeployerV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/BridgeInboxAdapterV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/SourceBridgeV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/BridgeCreditRegistryV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/BridgeDomainRegistryV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/SourceQuotaManagerV2.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/SourceFactory.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/SourceBundleDeployer.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/BridgeInboxAdapter.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/BridgeRoutePackage.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/SourceBridgeAccountingInvariant.t.sol`

- [ ] **Step 1: Write failing deterministic deployment tests** for the one protocol-root Source
      factory, a CREATE2 inert bundle deployer, and exactly three constructor CREATEs at nonces 1--3
      producing the fresh release-scoped SourceBridge, credit Registry and source QuotaManager.
      Derive every address from the Appendix RLP formulas and pin bundle init/runtime plus child
      creation/runtime/config hashes; no child address may occur in the bundle CREATE2 preimage.
- [ ] **Step 2: Pin the adapter artifact in the same immutable factory configuration.** The factory
      commits both compiled bundle and BridgeInboxAdapter creation artifacts, and independently
      deploys each release adapter at exact
      `saltA = H("slot-chain-bridge-adapter-salt-v1" || u64(version) || sourceDescriptorId)` and
      `initHashA = H(adapterCreationCode || abi.encode(adapterConfigHash, sourceBridge,
creditRegistry, router, queue, sealAuthority))`. Test the derived CREATE2 address,
      exact 100-byte `creditRegistry || sourceBridge || Router || Queue || ProtocolVersionManager`
      component configuration in that order, front-run code/config checks, wrong salt/artifact/config
      rejection and root-deployment receipt binding.
- [ ] **Step 3: Write failing BRX1/BRS1/BRC1 tests** for fixed raw rows, review delay, target joins,
      one-shot consumption, malformed returns and route substitution.
- [ ] **Step 4: Implement append-only credit authorization, source custody buckets and the immutable
      adapter's PREACTIVE/exact-source/exact-registry/stamped Queue boundary;** no V1 Bridge selector
      or storage is touched.
- [ ] **Step 5: Prove** front-run deployment is accepted only for the complete exact bundle and
      adapter, constructor failure reverts all three bundle children, the deployed bundle runtime is
      inert, historical bundles remain refund-only, and a successor uses a fresh endpoint/domain.
- [ ] **Step 6: Run** L1 fuzz/invariants, deterministic address checks and gas.
- [ ] **Step 7: Commit** `feat(protocol): add slot chain source bridge bundle`.

### Round 16: L2 InboxApply, endpoint Store and ICV2

**Files:**

- Create: `packages/protocol/contracts/layer2/slotchain/iface/ITerminalDomainRegistrarV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/iface/IInboxApplyRouterV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/iface/IInboxCreditStoreV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/InboxApplyRouterV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/InboxCreditStoreV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/libs/LibInboxCreditV2.sol`
- Create: `packages/protocol/test/layer2/slotchain/inbox/InboxApplyRouter.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/inbox/InboxCreditStore.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/inbox/ICV2Boundary.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/mocks/TerminalDomainRegistrarStub.sol`

- [ ] **Step 1: Write failing contiguous-run tests** for empty, single and maximum intervals,
      route/config rechecks, duplicate pins and cursor monotonicity.
- [ ] **Step 2: Write the exact ICV2 corpus** for credit identity, fee/value, pin state, wrong Store,
      malformed/long return and OOG.
- [ ] **Step 3: Implement validate-all-before-call apply**; Store validates its full run before any
      permanent pin and makes no external call. Its checked `uint64 pinnedCount` increments only for
      an absent pin written by the exact authorized route; duplicate, foreign-route, overflow or
      failed batch changes neither pin nor count.
- [ ] **Step 4: Fault-inject each Store in a multi-run batch** and assert prior pins, each Store's
      `pinnedCount` and the global cursor all roll back.
- [ ] **Step 5: Run** L2 fuzz/invariants and maximum batch gas.
- [ ] **Step 6: Commit** `feat(protocol): add slot chain inbox credit application`.

### Round 17: Native liquidity and destination Bridge lifecycle

**Files:**

- Create: `packages/protocol/contracts/layer2/slotchain/iface/ITerminalAccumulatorV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/iface/INativeQuotaManagerV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/iface/INativeLiquidityPoolV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/iface/IDestinationBridgeV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/NativeLiquidityPoolV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/DestinationBridgeV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/libs/LibBridgeExecutionV2.sol`
- Create: `packages/protocol/test/layer2/slotchain/bridge/NativeLiquidityPool.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/bridge/DestinationBridge.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/bridge/DestinationBridgeInvariant.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/mocks/TerminalAccumulatorStub.sol`
- Create: `packages/protocol/test/layer2/slotchain/mocks/NativeQuotaManagerStub.sol`

- [ ] **Step 1: Write failing NEW/RETRIABLE/DONE/FAILED tests** for success, target revert, OOG,
      non-invocable selector, manual owner retry, last attempt and hard expiry.
- [ ] **Step 2: Pin every outer-catch branch:** non-owner failure leaves state unchanged;
      owner-initial failure writes only RETRIABLE; owner-last finalizer atomically writes FAILED and
      terminal leaf; finalizer failure restores outer entry state.
- [ ] **Step 3: Implement child-frame snapshots** conceptually via EVM revert domains, explicit
      reentrancy tuples, exact EIP-150 reserves and pull credits.
- [ ] **Step 4: Fuzz callbacks** and prove no Pool/ticket/quota/pull/terminal mutation escapes a
      failed child frame.
- [ ] **Step 5: Run** L2 invariants, solvency, call-gas and code-size checks.
- [ ] **Step 6: Commit** `feat(protocol): add slot chain destination bridge`.

### Round 18: AnchorV4 atomic release activation and L2 lifetime plane

**Files:**

- Create: `packages/protocol/contracts/layer2/slotchain/iface/IAnchorV4.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/iface/IProtocolReleaseAuthorityV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/AnchorV4.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/ProtocolReleaseAuthorityV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/TerminalDomainRegistrarV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/TerminalAccumulatorV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/impl/NativeQuotaManagerV2.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/AnchorV4.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/ReleaseAuthority.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/ReleaseActivationAtomicity.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/NativeQuotaManager.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/terminal/TerminalAccumulator.t.sol`

- [ ] **Step 1: Pin the custom tx0 envelope.** Test exact unsigned transaction type, index zero,
      reserved system sender, `msg.sender`/`tx.origin`, zero GASPRICE, nonce/balance non-transition,
      initial warm set, intrinsic gas, refund quotient, exact 1,892-byte calldata and the identical
      58-word manifest plus retirement watermark passed to all three activation calls.
- [ ] **Step 2: Use the real Round-16/17 Store, Router, Pool and Bridge implementations** to write
      failing one-journal tests: Anchor stores its one-shot tuple, then calls Authority and Registrar
      with identical inputs; a failure at any Authority/Registrar/route/Pool/writer/Store/Bridge seal
      boundary rolls back Anchor, RAV2 and every registrar write. Mocks cannot satisfy this full-graph
      acceptance suite.
- [ ] **Step 3: Authenticate fresh release-owned endpoints** including a Bridge-unique native
      QuotaManager with full initial nonzero quota, zero nonce/liability/private mappings and no
      owner/proxy/reinitializer. Pin the real fresh Store and Bridge state, arbitrary preactivation
      Bridge surplus, lifetime Pool solvency and exact component/config/layout hashes.
- [ ] **Step 4: Implement** AnchorV4 as the sole tx0 entry, the protocol-lifetime Authority,
      Registrar and TerminalAccumulator, plus the release-owned native QuotaManager. Direct reserved-
      sender, EOA, Bridge, wrong Anchor, replay and malformed component calls reject before writes.
- [ ] **Step 5: Implement the checked per-domain `terminalizedPinnedCount`.** It increments only in
      the terminal append journal after exact Registrar route/Store/Bridge authentication, an existing
      pin, DONE/FAILED status and an absent `(domainId,creditId)` guard. Duplicate, unpinned, foreign,
      overflow or failed append rolls back count, leaf, root/frontier, guard and Bridge status.
- [ ] **Step 6: Fuzz caller/origin, manifest words, watermark, late-failure rollback, pin/terminal
      conservation and depth-64 terminal boundaries; run L2 profile and maximum gas tests.**
- [ ] **Step 7: Commit** `feat(protocol): add slot chain l2 release plane`.

### Round 19: Source send, kind-1 ingress and terminal finalization

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/impl/SourceBridgeV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/TerminalSignalVerifierV2.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/SourceBridgeLifecycle.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/BridgeInboxAdapterLifecycle.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/bridge/TerminalSignalVerifier.t.sol`

- [ ] **Step 1: Write failing source lifecycle tests** for fresh message IDs, authorization versus
      funded liability, enqueue deadline equality, cancel-before-enqueue, queue-before-cancel,
      refunds and LP terminal pull.
- [ ] **Step 2: Write failing kind-1 tests** requiring same-L1 direct credit comparison, exact
      immutable source generation/domain/Bridge and live liability.
- [ ] **Step 3: Implement atomic adapter append plus source QUEUED callback** and proof-first
      DONE/FAILED liability reclassification.
- [ ] **Step 4: Prove historical endpoints cannot mint** but retain refunds and terminal proof
      finalization.
- [ ] **Step 5: Run** L1 fuzz/invariants, bridge differential and gas.
- [ ] **Step 6: Commit** `feat(protocol): add slot chain bridge lifecycle`.

### Round 20: Version manager, Router migration state, timelock and release registration

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/IProtocolVersionManagerV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IProtocolChangeTimelockV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/IMigrationTransitionVerifierV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ProtocolVersionManagerV2.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ProtocolChangeTimelockV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/ActiveSettlementRouter.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibReleaseRegistration.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibExecutionProfile.sol`
- Create: `packages/protocol/test/layer1/slotchain/mocks/MigrationTransitionVerifierStub.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/ReleaseRegistration.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/MigrationGate.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/ProtocolTimelock.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/RouterAuthority.t.sol`

- [ ] **Step 1: Write failing exact-ABI tests** for delayed protocol operations, cancellation,
      target registration, strict canonical execution-profile decoding, component/profile codecs,
      migration-gate states, verifier descriptor/hash binding and active Router reads.
- [ ] **Step 2: Prove caller-supplied Settlement, route, source bundle or historical version cannot
      become authority.**
- [ ] **Step 3: Implement append-only release rows**, the immutable PVM--Router graph, the Router-
      owned single migration-gate word/getter/mutations, generation lease, test-only fixed transition
      verifier and fixed raw static views. There is no standalone gate contract or address.
      Production-profile construction must reject the stub and every unregistered/mutable verifier
      graph.
- [ ] **Step 4: Fuzz** selector, payload width, return width, nonce, timing and replay boundaries.
- [ ] **Step 5: Run** L1 tests, layout, config-hash and gas checks.
- [ ] **Step 6: Commit** `feat(protocol): add slot chain protocol authority`.

### Round 21: Exact legacy genesis compatibility and bounded campaign

**Files:**

- Create: `packages/protocol/contracts/layer1/slotchain/iface/ILegacyGenesisCutoverInboxV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/iface/ILegacyResumeZkPairVerifierV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/LegacyGenesisCutoverInboxV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/LegacyResumeZkPairVerifierV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/LegacyResumeRisc0VerifierAdapterV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/LegacyResumeSp1VerifierAdapterV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/FencedLegacySignalServiceV1.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibGenesisCampaign.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/ActiveSettlementRouter.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/ProtocolVersionManagerV2.sol`
- Create: `packages/protocol/test/layer1/slotchain/genesis/GenesisCampaign.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/genesis/GenesisCampaignRollback.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/genesis/LegacyLayoutCompatibility.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/genesis/LegacyResumeVerifier.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/genesis/LegacySignalServiceFence.t.sol`

- [ ] **Step 1: Install only the exact final implementation in the deployed legacy Inbox proxy.**
      Reproduce its byte-identical storage/configuration, collision-free gap slot, `onlyProxy`,
      preserved events/bond withdrawals and local phase/upgrade fence. Prove a sidecar cannot
      intercept either old proposal or forced-inclusion selector and never introduce one.
- [ ] **Step 2: Pin the supported resume graph** to ownerless `LegacyResumeZkPairVerifierV1`, exactly
      ascending RISC0_RETH=5 plus SP1_RETH=6, immutable block/aggregation keys, recursively bound
      remote dispatch, no SGX/age/time dependency and the final direct SignalService implementation
      sharing the campaign upgrade fence. Generic ComposeVerifier, mutable trust maps, ForkRouter,
      delegate targets and unfenced checkpoint paths must reject the profile.
- [ ] **Step 3: Write bounded-scan tests** for proposal/forced cutoffs, 128 maximal batches,
      abandonment values, data-expiry envelope, review commitment, QUIESCENT and permissionless
      resume, plus hard block/time expiry that restores unchanged legacy ACTIVE.
- [ ] **Step 4: Pin the genesis-specific journal order and fault every boundary.** After internal
      campaign/calldata checks Router writes `ACTIVATING` before its first external operation,
      exact-reads QUIESCENT LGS1 and all component state, preflights target/Queue/receipt/index
      absence, computes and stores the landing-block activation context, and only then dispatches the
      bounded proof verifier. After proof success it calls LGAR; exact-reads transaction-local READY
      LGS1; executes LGFN, target MCAN and singleton-Queue QMIG; exact-reads SOURCE/TARGET/QUEUE MAPS;
      consumes registration; writes abandonment event, complete genesis receipt and indexes plus
      `firstV2BlockNumber`; makes target and public gate ACTIVE; marks campaign CONSUMED; clears the
      context; and writes Router IDLE last. Each injected failure must restore the identical legacy
      QUIESCENT snapshot, old Queue authority and absence of all target/receipt/index/context writes.
      Before `genesisConsumed=true`, Router authority remains `LEGACY_BOOTSTRAP`; every later-version
      migration entry must reject. This order must not reuse later migration's verifier-before-
      ACTIVATING sequence.
- [ ] **Step 5: Treat compatibility as a stop gate.** If the real deployed Inbox layout/config or
      direct SignalService graph cannot install these exact artifacts, mark in-place GENESIS_IMPORT
      unsupported and do not implement an approximation; the only supported path is a separately
      initialized state migration requiring a new design decision on PR #22064.
- [ ] **Step 6: Run** the manifest-named owner directly:
      `FOUNDRY_PROFILE=layer1 forge build` and
      `FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/slotchain/genesis/*.t.sol'`;
      verify every legacy artifact exists only under `out/layer1`, then run proxy layout diff,
      fixed-key/fence corpus, maximum scans, complete rollback matrix and gas tests.
- [ ] **Step 7: Commit** `feat(protocol): add delayed slot chain genesis campaign`.

### Round 22: Proof-first later-version migration and abort

**Files:**

- Modify: `packages/protocol/contracts/layer1/slotchain/impl/ActiveSettlementRouter.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/ProtocolVersionManagerV2.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/SlotChainSettlement.sol`
- Modify: `packages/protocol/contracts/layer1/slotchain/impl/ForcedQueue.sol`
- Create: `packages/protocol/contracts/layer1/slotchain/libs/LibMigrationJournal.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/VersionMigration.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/migration/VersionMigrationRollback.t.sol`

- [ ] **Step 1: Write the exact successful trace test:** verifier STATICCALL, ACTIVATING, MFRZ,
      MCAN, kind-0 binding, SourceBridge activation, source indexes, BRC1, destination seal, Bridge
      binding, QMIG, three MAPS reads, registration/receipt/successor writes, public ACTIVE, context
      clear, Router IDLE, VMC1, PVM IDLE.
- [ ] **Step 2: Prove the genesis ordering fence:** later-version activation is unreachable until
      the exact legacy campaign has atomically set `genesisConsumed=true`; once consumed, the
      `LEGACY_BOOTSTRAP` authority can never reappear.
- [ ] **Step 3: Write one failure test at every boundary** including malformed return and VMC1
      revert/bad magic/bad post-read.
- [ ] **Step 4: Assert exact rollback** of old READY authority, target, Queue, lease, route arm,
      adapter seal, SourceBridge, ingress/profile maps, registrations and receipts.
- [ ] **Step 5: Implement** proof-first activation. VMC1 uses exact 100-byte calldata, zero value,
      exact caller, requested 200,000 gas, 96-byte return and is the sole mutating call after QMIG.
- [ ] **Step 6: Implement permissionless hard-expiry abort** without a post-abort callback. A
      successful abort writes monotone `armFreshAfter=block.timestamp` before PVM IDLE in the same
      rollback journal; a future arm is eligible only when `queuedAt > armFreshAfter` strictly.
- [ ] **Step 7: Prove stale siblings cannot bypass notice.** Rows queued before abort and at the exact
      abort timestamp remain permanently unusable; only a strictly later row that serves the full new
      seven-day delay may arm. Inject faults before/after the watermark and prove Router/source state
      and `armFreshAfter` roll back together.
- [ ] **Step 8: Run** migration fuzz/fault matrix, L1 profile and maximum proof calldata/gas tests.
- [ ] **Step 9: Commit** `feat(protocol): add atomic slot chain version migration`.

### Round 23: Destination retirement and direct-successor reclamation

**Files:**

- Modify: `packages/protocol/contracts/layer2/slotchain/impl/ProtocolReleaseAuthorityV2.sol`
- Modify: `packages/protocol/contracts/layer2/slotchain/impl/TerminalDomainRegistrarV2.sol`
- Modify: `packages/protocol/contracts/layer2/slotchain/impl/InboxApplyRouterV2.sol`
- Modify: `packages/protocol/contracts/layer2/slotchain/impl/DestinationBridgeV2.sol`
- Create: `packages/protocol/contracts/layer2/slotchain/libs/LibReleaseReclamation.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/ReleaseRetirement.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/release/ReleaseReclamation.t.sol`

- [ ] **Step 1: Write exact ownership tests for activation records.** Authority alone writes RAV2
      during Anchor tx0. Registrar alone derives and writes the predecessor watermark, checked
      successor index, DRV2 receipt, DSV2 reverse index and new active tuple in that same tx0 journal,
      atomically with route, Pool funding-authority and accumulator-writer seals. Genesis has
      canonical-zero predecessor fields and no DSV2 row; UINT64_MAX admits no successor.
- [ ] **Step 2: Add a three-hop A-to-B-to-C corpus** proving every receipt uses the authenticated
      tx0 block and identical manifest/count, predecessor rows are immutable, and no Bridge or
      reclamation call can create or repair RAV2/DRV2/DSV2.
- [ ] **Step 3: Gate reclamation independently** on Queue watermark, applied cursor,
      `terminalizedPinnedCount == pinnedCount`, zero pull liability, exact route/writer/lifetime
      graph and direct successor.
- [ ] **Step 4: Implement permissionless one-shot surplus transfer** to the typed sink before the
      retired bit; reject partial transfer, callback, reentrancy and duplicate calls atomically.
- [ ] **Step 5: Prove A can reclaim from A-to-B after B-to-C** while B independently uses B-to-C and
      historical source/terminal proof state remains.
- [ ] **Step 6: Run** L2 handler invariants and gas.
- [ ] **Step 7: Commit** `feat(protocol): add slot chain release reclamation`.

### Round 24: Deterministic deployment and production-profile rejection

**Files:**

- Modify: `packages/protocol/package.json`
- Create: `packages/protocol/contracts/layer1/slotchain/impl/SlotChainRootDeployerV1.sol`
- Create: `packages/protocol/script/layer1/slotchain/DeploySlotChainL1.s.sol`
- Create: `packages/protocol/script/layer2/slotchain/DeploySlotChainL2.s.sol`
- Create: `packages/protocol/utils/slotchain/generateExecutionProfile.ts`
- Create: `packages/protocol/utils/slotchain/verifyBuildConformance.ts`
- Create: `packages/protocol/utils/slotchain/packageBuildConformanceRelease.ts`
- Create: `packages/protocol/utils/slotchain/independentBuildConformance.py`
- Create: `packages/protocol/utils/slotchain/build-conformance.schema.json`
- Create: `packages/protocol/utils/slotchain/checkDeploymentTranscript.ts`
- Create: `packages/protocol/test/slotchain/conformance/fixtures/verifier-executable.bin`
- Create: `packages/protocol/test/slotchain/conformance/fixtures/input-bundle.bin`
- Create: `packages/protocol/test/slotchain/conformance/fixtures/build-conformance-report.bin`
- Create: `packages/protocol/test/slotchain/conformance/fixtures/build-conformance-diagnostics.json`
- Create: `packages/protocol/integration/slotchain/build-conformance.test.ts`
- Create: `packages/protocol/test/layer1/slotchain/deployment/SettlementRootFactory.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/deployment/RootNonceSequence.t.sol`
- Create: `packages/protocol/test/layer1/slotchain/deployment/L1Deployment.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/deployment/L2Deployment.t.sol`

- [ ] **Step 1: Pin the three distinct deployment authorities** instead of a generic factory:
      release Settlements derive only from the protocol-pinned ERC-2470 singleton factory and exact
      salt/initcode; source bundles derive only through the protocol-root SourceFactory plus inert
      CREATE2 bundle deployer and CREATE nonces 1--3; mutually bound permanent roots derive only
      from one audited self-disabling nonce-sequence deployment with no intervening CREATE.
- [ ] **Step 2: Write failing deterministic-address tests** for every protocol-lifetime versus
      release-scoped component, the Appendix CREATE/CREATE2 formulas, every constructor/seal/burned-
      authority slot, front-run exact-code acceptance and any wrong factory/nonce/artifact.
- [ ] **Step 3: Implement strict ExecutionProfileV2 generation** as the exact canonical ABI value
      with 267 fixed value words, the sole dynamic artifact offset/tail and no aliases/gaps/trailing
      bytes. It consumes the exhaustive Round-1 ownership manifest and rejects missing owners, test
      verifiers, uncalibrated economics, unknown ownership classes, artifact-owned recompilations or
      output/hash drift, source-inline source/profile/ABI/link drift, endpoint reuse,
      lifetime-address drift and incomplete authority burning.
- [ ] **Step 4: Generate and verify the complete build-conformance release package.** Canonicalize the ABI,
      storage layout, constructor schema, compiler/build JSON, pinned standard-json input and complete
      source tree; verify compiler/EVM/optimizer/remapping/library inputs, immutable/link references,
      creation/runtime hashes, constructor opcode constraints and constructor poststate. Publish four
      concrete outputs: the byte-exact bundled verifier executable; a complete self-contained input
      bundle containing the pinned solc executable bytes, no-BOM/no-newline RFC 8785 standard-json
      input, exact sorted source `entryBytes`, ABI/layout/schema/build preimages, profile and expected
      artifacts; the canonical 481-byte binary report; and human-readable diagnostics.
- [ ] **Step 5: Pin the report encoding and independent reproduction.** The binary report is exactly
      `u8(1)` followed in normative order by all 15 nonzero 32-byte hashes, and its domain-separated
      hash uses literal `u16(481)`. Mutate each word, order, version, length, executable byte, input,
      source and artifact and require rejection. Build the verifier executable twice from clean
      directories and require byte identity, then run both builds over the complete bundle and
      require identical reports/diagnostics. The independent Python implementation must parse the
      same published executable and input bytes and reproduce all 15 fields, all profile outputs and
      `buildConformanceReportHash` without importing the TypeScript implementation.
- [ ] **Step 6: Build twice from clean caches** and compare creation/runtime/config/layout/address
      transcript hashes. Prove all shared creation artifacts are loaded from their owner output and
      no deployment script recompiles them.
- [ ] **Step 7: Assert no current deployment script or Resolver selects V2.**
- [ ] **Step 8: Run** all profile builds, profile generation, build-conformance, artifact/transcript
      checks and deployment tests.
- [ ] **Step 9: Commit** `build(protocol): add deterministic slot chain deployment`.

### Round 25: Two-chain functional integration

**Files:**

- Create: `packages/protocol/integration/slotchain/artifacts.ts`
- Create: `packages/protocol/integration/slotchain/deploy.ts`
- Create: `packages/protocol/integration/slotchain/relay.ts`
- Create: `packages/protocol/integration/slotchain/slot-chain-v2.integration.test.ts`
- Create: `packages/protocol/integration/slotchain/slot-chain-v2.restart.integration.test.ts`
- Modify: `packages/protocol/package.json`

- [ ] **Step 1: Start separate L1/L2 Anvil chains** and load only profile-owned artifacts.
- [ ] **Step 2: Add a failing normal/recovery scenario** from builder scheduling through canonical
      settlement and forced tier-3 escape.
- [ ] **Step 3: Add failing Bridge scenarios** for DIRECT ETH, LP funding, DONE, RETRIABLE, FAILED,
      cancel/refund and terminal source finalization.
- [ ] **Step 4: Add failing migration scenarios** for later-version success, every late rollback,
      abort, genesis expiry/resume and A-to-B-to-C reclamation.
- [ ] **Step 5: Implement only commitment-authenticated relay helpers;** the harness may not inject
      a root, bypass a verifier or share contract object state across chains.
- [ ] **Step 6: Add a process-restart/serialization test** that kills and reconstructs only the
      off-chain harness from chain reads, then continues through another release. It must preserve
      Queue and apply cursors, old routes/releases/writers, data/session and custody liabilities,
      Pool tickets/reverse indexes, accumulator frontier/root/count, active release and every
      RAV2/DRV2/DSV2/registration receipt; no post-activation object binding or memory snapshot may
      repair state.
- [ ] **Step 7: Run** all integration cases twice from clean deployments and once with restarts
      injected before/after every activation boundary.
- [ ] **Step 8: Commit** `test(protocol): add slot chain two-chain integration`.

### Round 26: Coverage, gas, layout and adversarial release audit

**Files:**

- Modify only implementation/test/build files needed to fix measured failures.
- Modify: `packages/protocol/package.json`
- Create: `packages/protocol/test/layer1/slotchain/invariant/SlotChainL1Invariant.t.sol`
- Create: `packages/protocol/test/layer2/slotchain/invariant/SlotChainL2Invariant.t.sol`
- Create: `packages/protocol/integration/slotchain/adversarial-boundaries.test.ts`
- Create: `packages/protocol/integration/slotchain/cross-language-conformance.test.ts`
- Create: `packages/protocol/utils/slotchain/checkCoverage.ts`
- Create: `packages/protocol/utils/slotchain/checkGasCertificates.ts`
- Create: `packages/protocol/utils/slotchain/checkStorageLayouts.ts`
- Create: `packages/protocol/utils/slotchain/checkBytecodeSizes.ts`
- Create: `packages/protocol/test/slotchain/certificates/slot-chain-gas.json`
- Create: `packages/protocol/test/slotchain/certificates/slot-chain-layout.json`

- [ ] **Step 1: Produce separate shared/L1/L2 LCOV files, combine them, and enforce greater than 95%
      for both line and branch coverage** over every new non-test Slot Chain source. Exclusions are
      explicit and reviewed; a passing global repository percentage cannot mask an uncovered V2
      component or normative transition/error.
- [ ] **Step 2: Generate versioned maximum-input gas certificates** for proof/call parsing, queue
      append/consume, data open/post/seal/refund/8-cell cleanup, schedule sealing, market maintenance,
      normal/recovery settlement, genesis scans, later migration, tx0 activation, InboxApply,
      Bridge attempts/retries/finalization/reclaim and terminal append. Enforce the normative 30%
      margin and run a one-less-gas harness proving each bound fails closed with no partial write.
- [ ] **Step 3: Compare deterministic storage-layout hashes** against the reviewed certificate and
      fail on any slot/type/order drift. Enforce EIP-170 runtime and EIP-3860 initcode limits for
      every deployable; no warning or manual waiver counts as a pass.
- [ ] **Step 4: Run adversarial first/last-builder, first/last-seat, zero/one/max/max+1, exact
      equality, overflow, reorg, reentrancy, callback, cross-window, cross-release, multi-hop,
      restart and every migration-boundary scenario.**
- [ ] **Step 5: Reproduce every commitment and externally observable transition result** in Solidity
      and the Python/TypeScript reference implementations, including invalid-input/revert classes.
      Any disagreement is a release blocker, not an accepted fixture update.
- [ ] **Step 6: Run a deep code/security review** and independently compare Solidity against every
      security invariant and exact transition ordering in the normative PDF.
- [ ] **Step 7: Fix all Critical/High findings** and rerun the complete matrix.
- [ ] **Step 8: Commit** `test(protocol): complete slot chain v2 release audit`.

## 6. Complete verification matrix

Run from `packages/protocol` before marking the stacked implementation PR ready:

```bash
FOUNDRY_PROFILE=shared forge fmt --check contracts/shared/slotchain test/shared/slotchain
FOUNDRY_PROFILE=layer1 forge fmt --check contracts/layer1/slotchain test/layer1/slotchain
FOUNDRY_PROFILE=layer2 forge fmt --check contracts/layer2/slotchain test/layer2/slotchain
FOUNDRY_PROFILE=shared forge build --sizes --build-info --extra-output storage-layout
FOUNDRY_PROFILE=layer1 forge build --sizes --build-info --extra-output storage-layout
FOUNDRY_PROFILE=layer2 forge build --sizes --build-info --extra-output storage-layout
FOUNDRY_PROFILE=shared forge test --match-path 'test/shared/slotchain/**/*.t.sol'
FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/slotchain/**/*.t.sol'
FOUNDRY_PROFILE=layer2 forge test --match-path 'test/layer2/slotchain/**/*.t.sol'
FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/slotchain/genesis/*.t.sol'
FOUNDRY_PROFILE=layer2 forge test --match-path 'test/layer2/slotchain/release/AnchorV4.t.sol'
pnpm slotchain:artifact-owner:check
pnpm slotchain:profile:generate
pnpm slotchain:build-conformance:package --fixture
pnpm slotchain:build-conformance:check
pnpm slotchain:deployment-transcript:check
pnpm slotchain:integration
FOUNDRY_PROFILE=shared forge coverage --match-path 'test/shared/slotchain/**/*.t.sol' --report lcov --report-file lcov.shared.info
FOUNDRY_PROFILE=layer1 forge coverage --match-path 'test/layer1/slotchain/**/*.t.sol' --report lcov --report-file lcov.layer1.info
FOUNDRY_PROFILE=layer2 forge coverage --match-path 'test/layer2/slotchain/**/*.t.sol' --report lcov --report-file lcov.layer2.info
pnpm slotchain:coverage:check lcov.shared.info lcov.layer1.info lcov.layer2.info
pnpm slotchain:gas-certificates:check
pnpm slotchain:storage-layouts:check
pnpm slotchain:bytecode-sizes:check
pnpm slotchain:cross-language-conformance
```

Then rerun all six Python/model commands from preflight and compare generated vectors. Run the
existing non-Slot-Chain shared/L1/L2 tests to prove the additive suite changed no production path.
Re-run the clean-build transcript and restart suite after deleting every generated cache/output;
an artifact or harness that only passes with retained process state is a failure.

## 7. Final acceptance

The stacked implementation PR is implementation-complete only when:

- every normative on-chain interface/component exists and is deployable under its owner profile;
- every generated commitment and externally observable transition/revert result is reproduced by
  Solidity plus two independently maintained Python/TypeScript implementations;
- all focused, fuzz, invariant, integration, gas, size, layout and existing-regression tests pass;
- per-profile combined line and branch coverage both exceed 95%, deterministic layout certificates
  match, all runtime/initcode limits pass, and maximum plus one-less-gas certificates are enforced;
- restart tests reconstruct the complete lifetime/release state graph solely from authenticated
  chain reads and continue safely across migration and reclamation;
- no Critical or High code/design finding remains;
- the implementation PR has no design/spec/documentation diff against PR #22064;
- no live Inbox, Bridge, vault, Resolver or deployment path selects V2; and
- the PR description explicitly retains the external release gates: real circuits and production
  verifier keys; proof-performance and compiled activation-gas certificates; calibrated economics;
  client/fork and custom-system-transaction support; shadow-fork genesis/later-migration/abort drills;
  archive-loss and recovery rehearsals; multi-client testnet soak and monitoring; and independent
  teams reproducing every hash/execution result and auditing the proof system, Solidity, Bridge and
  economics.

Passing this plan makes the additive contract suite complete enough for external audit and testnet
rehearsal. The protocol is not production-ready until every external gate above has independently
passed; none may be waived by a green local contract suite.
