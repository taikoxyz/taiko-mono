# Slot Chain design and implementation status

This is a non-normative coverage map for the [learning deck](slides/slot-chain-learning-deck.html)
and [PR #22139](https://github.com/taikoxyz/taiko-mono/pull/22139) as revised to the v3.0 design
in [PR #22151](https://github.com/taikoxyz/taiko-mono/pull/22151). The architecture is a reviewed
design candidate with a partial Solidity implementation and open production gates. It is not an
end-to-end release or a deployment claim.

## Sources and authority

- [Normative LaTeX](tex/main.tex) defines the design. The committed
  [`slot-chain-spec.pdf`](slot-chain-spec.pdf) is the v2.28 build and is **stale** until rebuilt
  from the v3.0 source. The v3.0 label identifies a document revision.
- [Executable models and run instructions](README.md#running-the-models) provide consistency and
  regression evidence. Proof verification, raw transaction authentication and EVM execution remain
  abstract in the settlement model.
- [Conformance ledger](../../utils/slotchain/conformance-ledger.v3.0.json) records implementation
  coverage. Its `normativeCommit` pins the commit of `tex/main.tex` it was checked against; a
  documentation refresh does not certify new conformance.
- [Artifact ownership manifest](../../utils/slotchain/artifact-ownership.json) records compiler
  ownership and source/ABI/code hashes of the surviving Slot Chain sources.

If source, specification and model disagree, the specification requires resolving that
disagreement before deployment; a slide cannot resolve it by silently choosing one behavior.

## What v3.0 changed

The v3.0 revision builds on the anchor-free L2 of
[issue #22147](https://github.com/taikoxyz/taiko-mono/issues/22147), reuses the existing
SignalService, Bridge and vaults, and upgrades the existing L1 Inbox proxy in place under the
existing DAO governance. The following v2.28 components were removed from the design and their
draft code deleted from the repository:

| Removed component | Reason |
| --- | --- |
| `AnchorV4` system transaction, `InboxApplyRouterV2`, the `0x7f` system transaction type | The L2 header field `parentBeaconBlockRoot` carries the anchor; the L2 EVM is fully standard. |
| `SourceBridgeV2`, `DestinationBridgeV2`, `BridgeCreditRegistryV2`, `BridgeInboxAdapter`, `BridgeDomainRegistry`, `SourceBundleFactory`, `InboxCreditStoreV2`, `NativeLiquidityPoolV2`, `TerminalAccumulatorV2`, `TerminalSignalVerifier`, `ProtocolReleaseAuthorityV2`, `TerminalDomainRegistrarV2`, kind-1 forced envelopes, `RegistrationMptVerifierV2` | The existing bridge stack is reused; the Settlement writes L2 checkpoints into the L1 SignalService on every canonical commit. |
| `ProtocolChangeTimelockV1`, `ProtocolVersionManagerV2`, `ActiveSettlementRouter`, `ProtocolRootFactoryV1`, `RootMigrationExecutorV1`, `ProtocolRootCreate3ProxyV1`, `LibRootBootstrapV1`, ERC-2470/CREATE3 deployment, migration arms/leases/journals | Every Slot Chain contract is a DAO-owned UUPS proxy; upgrades are ordinary governance upgrades. |
| `LegacyGenesisCutoverInboxV1`, `LegacyResumeZkPairVerifierV1`, fixed-key RISC0/SP1 adapters, the campaign fence, scans and abandonment | V1 is drained under its own rules and activated in place; nothing is abandoned. |
| `ExecutionProfileV2` and `LibSlotChainProfile` | Superseded by `ExecutionProfileV3` (specified, not yet implemented). |

## Code present in the PR

| Area | Source and checked-in evidence | Boundary |
| --- | --- | --- |
| Builder registration, membership, leases and equivocation | [BuilderRegistry](../../contracts/layer1/slotchain/impl/BuilderRegistry.sol), [Seat facet](../../contracts/layer1/slotchain/impl/BuilderRegistrySeatLifecycleFacetV1.sol), [Lease facet](../../contracts/layer1/slotchain/impl/BuilderRegistryLeaseLifecycleFacetV1.sol), [proof verifier](../../contracts/layer1/slotchain/impl/BuilderRegistryProofVerifierV1.sol), [Registry tests](../../test/layer1/slotchain/registry/) | The Registry owns roots, storage and custody; seven fixed wrappers use two immutable facets and a shared operation lock. Activation is a one-shot call by a constructor-pinned activator. The draft is still a plain contract: re-basing it on `EssentialContract` (UUPS proxy, DAO owner) as the specification requires is outstanding. |
| Schedule authentication | [ScheduleSszMultiproofVerifierV1](../../contracts/layer1/slotchain/impl/ScheduleSszMultiproofVerifierV1.sol), [history/snapshot libraries](../../contracts/layer1/slotchain/libs/), [verifier tests](../../test/layer1/slotchain/verifier/) | Proof and snapshot helpers are present; ScheduleOracle itself is missing. |
| Shared protocol foundations | [Types and interfaces](../../contracts/shared/slotchain/), [encoding, trees, signatures, evidence, economics, resources and custody libraries](../../contracts/shared/slotchain/libs/), [shared tests](../../test/shared/slotchain/) | Real Solidity code and checked-in test evidence with mixed ledger statuses. Encoding a structure does not implement its consuming state machine. |
| Reproducibility and build isolation | [Golden-vector generator](../../utils/slotchain/generateGoldenVectors.ts), [vector fixtures](../../test/shared/slotchain/vectors/), [integration checks](../../integration/slotchain/), [Foundry profiles](../../foundry.toml) | Checks cover shared-artifact consumption, ownership, Registry storage layout, ledger consistency and default-profile isolation. They do not certify a complete deployed protocol. |

## Still specified or modeled

| Protocol path | Missing components |
| --- | --- |
| Settlement | The Slot Chain implementation of the existing Inbox proxy: modes, canonical commit with the L1 `saveCheckpoint` write, normal window, recovery, data sessions, rewards, `activateSlotChainV1` and the drain behaviour. |
| Forced queue | `ForcedQueue` (kind-0 only, DAO-owned proxy) with `enqueueForcedTransactionV2`, `advanceCursor` and the depth-64 vector. |
| Scheduling and service market | `ScheduleOracle`, `AggregatorSeatMarket`. |
| L2 | No new contracts. The client fork rules (header validation of `parentBeaconBlockRoot`, `extraData`, coinbase, forced-prefix composition) and the circuits. |
| Existing contracts | `SignalService` (with `revealCheckpoint` from #22147), `Bridge` and vaults on both chains are reused unchanged and are recorded as external dependencies. |

Real circuits/keys, complete deployment artifacts and independently reproduced client execution
remain release inputs. Tests or model objects named after one of these components do not make its
production implementation present.

## Interpreting the evidence

The ledger has **60 rows: 28 missing, 25 red, 6 passing and 1 reviewed**. It includes contracts, helper
artifacts, external dependencies and address roles. These heterogeneous rows do not measure a
percentage of completion.

The [ledger checker](../../utils/slotchain/checkConformanceLedger.ts) accepts all four statuses.
It checks schema, ownership and source coverage; requires declared source/test paths for `passing`
and `reviewed` rows; and verifies the recorded source/test hashes for `reviewed` rows. It does not
execute those tests or require every row to be passing. A `reviewed` label is a ledger assertion,
not an independent audit claim. Source and tests can exist while their row remains `red`.

Default and genesis Foundry profiles skip Slot Chain sources; the dedicated layer1, layer2 and
shared profiles and ownership checks cover the additive implementation. Slot Chain is not selected
on a production path in this PR.

## Design details the deck preserves

- Builder signatures establish authorship and parent choice; validity proofs establish execution.
  Landing and recovery are permissionless, including deterministic unsigned escape blocks, which
  may be empty.
- Every block carries the candidate's L1 anchor hash in `parentBeaconBlockRoot`; EIP-4788 records
  it on L2 and `revealCheckpoint` makes it a permanent checkpoint within the 8,191-second window.
- Forced kind-0 classification is ordered `0 → 1 → 2 → 3 → 6 → 4`; code 5 is unassigned.
  Descriptor-only expiry begins strictly after `validUntil`. Dispositions are proof-internal.
- Seat premiums are sponsor-funded. A qualifying late proof can cure a duty through slash equality
  and leave the former primary's full bond as withdrawal credit. The specified bounded premium
  exposure is an accepted economic tradeoff awaiting calibration.
- Every canonical commit writes the L2 checkpoint to the L1 SignalService in the same transaction;
  the existing Bridge pause, quota and fee semantics apply.
- Upgrades are ordinary DAO upgrades with explicit reinitializers; V1 is drained and activated in
  place with nothing abandoned.

## Validation and maintenance

For the standalone models, use the commands in the [parent README](README.md#running-the-models).
For implementation evidence, install repository dependencies with `pnpm install` at the monorepo
root and use the commands defined in [the protocol package](../../package.json):

```sh
cd packages/protocol
pnpm slotchain:vectors:test
pnpm slotchain:conformance:test
pnpm slotchain:default-profile:test
pnpm slotchain:builder-registry-layout:test
pnpm slotchain:ownership:ci
```

The last command compiles the dedicated profiles and runs the configured L1/L2 Slot Chain and
integration checks. Run `pnpm test:shared` for the shared Foundry suites as the Protocol workflow
does separately.

When design or implementation changes, update this snapshot, the parent README, the deck's
implementation/readiness slides and their source links together. Follow the
[deck maintenance checks](slides/README.md#keeping-the-deck-synchronized). Keep the normative
LaTeX/PDF, model vectors and implementation ledger synchronized whenever protocol rules change.
Production still requires the complete contract set, real circuits, L2 client fork support,
measured proof/gas performance, the drain-and-activate drill, calibrated economics, multi-client
testnet soak, independent conformance reproduction and independent audits.
