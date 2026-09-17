# Slot Chain design and implementation status

This is a non-normative coverage map for the [learning deck](slides/slot-chain-learning-deck.html)
and [PR #22139](https://github.com/taikoxyz/taiko-mono/pull/22139), checked on 2026-09-17 against
commit [`b7896b758ef5500ce9b67064ba645c4416d8cfb5`](https://github.com/taikoxyz/taiko-mono/commit/b7896b758ef5500ce9b67064ba645c4416d8cfb5).
The architecture is a reviewed design candidate with a partial Solidity implementation and open
production gates. It is not an end-to-end release or a deployment claim.

## Sources and authority

- [Normative LaTeX](tex/main.tex) and [built specification](slot-chain-spec.pdf) define the design.
  The source at this snapshot is byte-identical to the deck's previous `c77efc25` source; its Git
  blob is `819e4d5fa9ba74724b45978761779b5b839a6239`. The v2.28 label identifies a document revision.
- [Executable models and run instructions](README.md#running-the-models) provide consistency and
  regression evidence. Proof verification, raw transaction authentication and EVM execution remain
  abstract in the settlement model; its rollback snapshots are not compiled gas measurements.
- [Conformance ledger](../../utils/slotchain/conformance-ledger.v2.28.json) records implementation
  coverage. Its own `normativeCommit` remains `4cc7bc0e3cd96ea4cf0af72aa1a9e6e03bec8e52`; this
  documentation refresh does not change that pin or certify new conformance.
- [Artifact ownership manifest](../../utils/slotchain/artifact-ownership.json) records compiler
  ownership, source/ABI/code hashes and the planned root artifact cohort.

Read links in a checkout of the snapshot above when reproducing this assessment. If source,
specification and model disagree, the specification requires resolving that disagreement before
deployment; a slide cannot resolve it by silently choosing one behavior.

## Code present in the PR

| Area | Source and checked-in evidence | Boundary |
| --- | --- | --- |
| Builder registration, membership, leases and equivocation | [BuilderRegistry](../../contracts/layer1/slotchain/impl/BuilderRegistry.sol), [Seat facet](../../contracts/layer1/slotchain/impl/BuilderRegistrySeatLifecycleFacetV1.sol), [Lease facet](../../contracts/layer1/slotchain/impl/BuilderRegistryLeaseLifecycleFacetV1.sol), [proof verifier](../../contracts/layer1/slotchain/impl/BuilderRegistryProofVerifierV1.sol), [Registry tests](../../test/layer1/slotchain/registry/) | The Registry owns roots, storage and custody. Seven fixed wrappers use two immutable facets and a shared operation lock. These components have `passing` ledger rows; complete integration with ScheduleOracle and Router remains outstanding. |
| Historical registration and schedule authentication | [RegistrationMptVerifierV2](../../contracts/layer1/slotchain/impl/RegistrationMptVerifierV2.sol), [ScheduleSszMultiproofVerifierV1](../../contracts/layer1/slotchain/impl/ScheduleSszMultiproofVerifierV1.sol), [history/snapshot libraries](../../contracts/layer1/slotchain/libs/), [verifier tests](../../test/layer1/slotchain/verifier/) | Proof and snapshot helpers are present; ScheduleOracle itself is missing. These helpers do not constitute a complete schedule service or an L2 execution-validity circuit. |
| Protocol root bootstrap | [RootMigrationExecutorV1](../../contracts/layer1/slotchain/root/RootMigrationExecutorV1.sol), [ProtocolRootFactoryV1](../../contracts/layer1/slotchain/root/ProtocolRootFactoryV1.sol), [CREATE3 proxy](../../contracts/layer1/slotchain/root/ProtocolRootCreate3ProxyV1.sol), [root tests](../../test/layer1/slotchain/root/) | Executor queues/stages a root campaign; Factory deploys nine pinned roles and finalizes their activation. Factory and executor rows remain `red`; the proxy and several primitives are `reviewed`. Missing role contracts prevent a complete root release. |
| Shared protocol foundations | [Types and interfaces](../../contracts/shared/slotchain/), [encoding, trees, signatures, profiles, economics, resources and custody libraries](../../contracts/shared/slotchain/libs/), [shared tests](../../test/shared/slotchain/) | There is real Solidity code and checked-in test evidence, with mixed ledger statuses. Encoding a structure or validating resource arithmetic does not implement its consuming state machine. |
| Reproducibility and build isolation | [Golden-vector generator](../../utils/slotchain/generateGoldenVectors.ts), [vector fixtures](../../test/shared/slotchain/vectors/), [integration checks](../../integration/slotchain/), [Foundry profiles](../../foundry.toml) | Checks cover shared-artifact consumption, ownership, Registry storage layout, ledger consistency and default-profile isolation. They do not certify a complete deployed protocol. |

The builder Seat facet concerns registry membership. It is separate from `AggregatorSeatMarket`,
whose proving-service auction is described by the specification and Python model.
Likewise, `RootMigrationExecutorV1` is a root-bootstrap authority; its presence does not implement
the Router's proof-first later-version MFRZ/MCAN/QMIG/MAPS/VMC1/VML1 journal.

## Still specified or modeled

The ledger marks the following major components `missing`, and their named Slot Chain source
files are absent at this snapshot:

| Protocol path | Missing components |
| --- | --- |
| Scheduling, settlement and forced recovery | ScheduleOracle, SlotChainSettlement, ForcedQueue, Kind0IngressAdapter and the ordinary Settlement validity-verifier interface/call library. |
| Service market and version control | AggregatorSeatMarket, ActiveSettlementRouter, ProtocolChangeTimelockV1 and ProtocolVersionManagerV2. |
| L1 bridge ingress and custody | BridgeDomainRegistry, SourceBundleFactory, SourceBundleDeployerV1, BridgeInboxAdapter, SourceBridgeV2, BridgeCreditRegistryV2, SourceQuotaManager and SourceTerminalVerifier. |
| L2 execution and bridge delivery | AnchorV4, ProtocolReleaseAuthorityV2, InboxApplyRouterV2, InboxCreditStoreV2, TerminalDomainRegistrarV2, TerminalAccumulatorV2, NativeLiquidityPoolV2, DestinationBridgeV2 and DestinationQuotaManager. |
| Legacy genesis and resume | LegacyGenesisCutoverInboxV1, LegacyResumeZkPairVerifierV1, fixed-key RISC0/SP1 adapters, LegacyCampaignFencedProposerCheckerV1 and LegacyDirectSignalServiceV1. |

Real circuits/keys, complete deployment artifacts and independently reproduced client execution
remain release inputs. Tests or model objects named after one of these components do not make its
production implementation present. Existing V1 contracts are not substitutes for the specified
fresh V2 custody and authority graph.

## Interpreting the evidence

At the snapshot above the ledger has **146 rows: 101 missing, 25 red, 12 passing and 8 reviewed**.
It includes contracts, helper artifacts, init-code bundles, external dependencies and address roles.
These heterogeneous rows do not measure a percentage of completion.

The [ledger checker](../../utils/slotchain/checkConformanceLedger.ts) accepts all four statuses.
It checks schema, ownership and source coverage; requires declared source/test paths for `passing`
and `reviewed` rows; and verifies the recorded source/test hashes for `reviewed` rows. It does not
execute those tests or require every row to be passing. A `reviewed` label is a ledger assertion,
not an independent audit claim. Source and tests can exist while their row remains `red`.

The ownership manifest's root cohort remains **`planned`**, with **21 required artifacts**.
The nine Factory-deployed roles are only part of that cohort. A complete release must reproduce
the pinned compiler/profile, exact init/runtime/configuration hashes and all size/gas bounds.
Checked-in gas snapshots and synthetic budget arithmetic do not establish those full-path gates.

Default and genesis Foundry profiles skip Slot Chain sources; the dedicated layer1, layer2 and
shared profiles and ownership checks cover the additive implementation. V2 is not selected on a
production path in this PR.

## Design details the deck preserves

- Builder signatures establish authorship and parent choice; validity proofs establish execution.
  Landing and recovery are permissionless, including deterministic unsigned escape blocks.
- Forced kind-0 classification is ordered `0 → 1 → 2 → 3 → 6 → 4`; code 5 belongs to kind-1 credits.
  Descriptor-only expiry begins strictly after `validUntil`. A missing live body is not evidence
  of invalidity. Per-block FIFO budgets and candidate-wide limits are separate.
- Seat premiums are sponsor-funded. A qualifying late proof can cure a duty through slash equality
  and leave the former primary's full bond as withdrawal credit. The specified bounded premium
  exposure is an accepted economic tradeoff awaiting calibration.
- Launch bridge ingress is same-L1 DIRECT ETH with fresh V2 custody, durable destination pins and
  LP-funded processing. Queue consumption does not itself deliver ETH to a recipient.
- Later migration retains seven-day notice, a seven-day arm execution window and a separate
  non-extendable seven-day live lease. At lease expiry activation rejects and anyone can abort;
  a successful expiry abort requires every retry arm to be queued strictly later and wait anew.
- Legacy genesis has a finite campaign, exact bounded scans and reversible QUIESCENT state.
  In-place cutover imports the last finalized checkpoint and explicitly abandons unfinalized
  proposals and pending forced records. Lossless requirements or incompatible legacy deployments
  require a separate state migration.

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
does separately. These are reproduction instructions; their presence here does not assert that
all were rerun for this documentation update.

When design or implementation changes, update this snapshot, the parent README, the deck's
implementation/readiness slides and their source links together. Follow the
[deck maintenance checks](slides/README.md#keeping-the-deck-synchronized), including desktop,
narrow-screen and print inspection. Keep the normative LaTeX/PDF, model vectors and implementation
ledger synchronized whenever protocol rules change. Production still requires the complete
release bundle, measured proof/gas performance, independent conformance reproduction, calibrated
economics, migration/archive-loss drills, multi-client testnet soak and independent audits.
