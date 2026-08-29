# Slot Chain Contract Suite Implementation Specification

**Status:** Approved implementation architecture

**Normative protocol source:**
`packages/protocol/docs/preconfirmation-v2/tex/main.tex` (v2.25)

## 1. Objective

Implement the complete on-chain portion of Slot Chain as an additive contract suite in
`packages/protocol`. The suite must preserve the protocol document's bounded-work, solvency,
canonical-safety, migration-reversibility, and permissionless-progress properties. It must not
change the behavior of the currently deployed-path `Inbox`, `Bridge`, or vault contracts until a
separate, explicitly reviewed deployment/cutover operation selects the new suite.

The work is production-intent, but contract completion alone is not authority to deploy. A release
remains blocked until the real proof circuits, verifier keys, executable profile, generated golden
vectors, gas benchmarks, migration rehearsal, and external audits satisfy section 11 of the
normative document.

## 2. Selected Architecture

The implementation is a dependency-layered, isolated V2 suite. This was selected over:

1. extending the live `Inbox` and `Bridge` implementations while the new state machine is still
   changing, which would couple incomplete logic to the production path; and
2. building only interfaces and reference mocks, which would not exercise storage, authority,
   solvency, or bounded-gas behavior and therefore would not meet the request.

The isolated suite uses exact immutable dependencies and one-shot seals. It introduces no generic
resolver, delegate target, arbitrary storage setter, arbitrary root setter, or pause mechanism on a
canonical or claim-only path. The only legacy proxy relationship supported by the design is the
one-time installation and proof of the final frozen Bridge/vault facade; the implementation itself
contains no upgrade selector and never delegates again.

## 3. Source Layout

Chain-neutral encodings and bridge/vault logic live under the shared Foundry profile. L1 and L2
state machines live under their existing package profiles.

```text
packages/protocol/contracts/
  shared/slotchain/
    iface/       shared external interfaces and verifier boundaries
    libs/        exact hashing, encoding, Merkle/MMR and bounded-call libraries
    impl/        BridgeV2Facade and refund-capable vault components
  layer1/slotchain/
    iface/       full-NatSpec L1 interfaces
    libs/        L1 state transition and proof-authentication libraries
    impl/        permanent L1 protocol components
  layer2/slotchain/
    iface/       full-NatSpec L2 interfaces
    libs/        L2 route, credit and terminal helpers
    impl/        permanent L2 protocol components

packages/protocol/test/
  shared/slotchain/
  layer1/slotchain/
  layer2/slotchain/
```

Test-only doubles live in the matching `test/**/slotchain/mocks` directory. Production contracts
must never import a test verifier or a caller-configurable verifier.

## 4. Contract Inventory and Ownership

### 4.1 Shared primitives and custody

- `LibSlotChainEncoding`: byte-exact domain-separated encodings from the normative appendix.
- `LibFixedMerkle`: the depth-6 registry tree, depth-9 tranche tree, depth-11 admission
  tree, and depth-64 force/terminal trees. Each tree has its own pinned leaf/node domains, empty
  nodes, and bit order; callers cannot select a depth while accidentally reusing another tree's
  hashing domain.
- `LibMMR`: the bounded 2,100-leaf data-session frontier.
- `LibSafeStaticCall`: exact return-length, gas-cap, and code-hash checked static calls.
- `ISlotChainVerifier`: immutable validity-proof boundary returning only exact success magic.
- `BridgeV2Facade`: complete V1-compatible and additive V2 credit lifecycle, liabilities, terminal
  finalization, recall, cancellation, and pull payments.
- `ERC20VaultV2`, `ERC721VaultV2`, and `ERC1155VaultV2` refund components: bounded capsules,
  reservations, claim bits, and unpausable claim paths.
- `IRefundRestorableV2`: frozen bridged-token restoration boundary.

Shared custody contracts follow checks-effects-interactions, use pull payments, and guard every V1
and V2 payout/sweep with post-balance liability/reserve floors. V2 state is keyed by `creditId` and
must not reinterpret existing V1 mappings.

### 4.2 L1 permanent data plane

- `BuilderRegistry`: 64 active cells, retained liability generations, tranche roots, reservations,
  exit/tombstone transitions, and idempotent equivocation slashing.
- `ScheduleOracle`: authenticated snapshots, exact ticket allocation, fixed schedule roots, delayed
  fork-verifier registration, and the bounded live-window ring.
- `DataSession`: owner/nonce sessions, two-live-session owner limit, MMR append/seal, expiry, and
  bounded eviction.
- `ForcedQueue`: protocol-lifetime depth-64 append-only queue, descriptor storage, deposits,
  processing-fee prefixes, cursor advancement, expiries, liabilities, and pull claims.
- `BridgeCreditRegistry`: immutable credit authorization records created only by the frozen source
  Bridge.
- `BridgeDomainRegistry`: append-only source/destination/endpoint support with finalized L2
  registration confirmation.
- `BridgeInboxAdapter`: exactly-once credit enqueue with stamped router synchronization and
  caller-fee refunds on non-continuation.
- kind-0 forced-transaction ingress adapter: validates and funds a bounded queue descriptor before
  atomically appending it.
- `TerminalSignalVerifier`: immutable verification of a depth-64 terminal leaf against exact
  versioned canonical history.

These components are non-proxy contracts. Cross-component mutators authenticate exact immutable
callers. Any authority that exists only for bootstrap is one-shot and irreversibly burned.

### 4.3 L1 settlement and release control plane

- `Settlement`: `PREACTIVE`, `ACTIVE`, `MIGRATION_ARMED`, `MIGRATION_READY`, and `FROZEN` phases;
  canonical core; normal best candidate; recovery episode/round; 256-cell full-core history;
  256-cell reward-receipt ring; proof verification; and bounded canonical commits.
- `ActiveSettlementRouter`: append-only version registry, stable stamped ingress facade,
  version/sequence history routing, router-owned migration gate, and atomic proof-first activation.
- `ProtocolVersionManager`: delayed manifest and cancellation authorization, exact runtime/config
  checking, generation monotonicity, and one-shot activation consumption.
- one-shot `LegacySlotChainLaunchAdapter`: proves the drained legacy Inbox boundary and proxy/fork
  topology, imports the authenticated checkpoint, supports the separately delayed launch-cancel
  path, and permanently burns its legacy freeze/import authority after either launch or
  cancellation.
- later V2-to-V2 proof-first activation: authorized by `ProtocolVersionManager` and executed through
  `ActiveSettlementRouter`, without any retained legacy import or freeze authority. It validates
  everything before authority transfer and keeps transfer, queue advancement, history write, old
  freeze, new initialization, and router activation in one revert domain.
- `RewardDistributor`: optional best-effort payouts from recorded receipts; its failure or
  exhaustion cannot affect canonical settlement.

Settlement delegates pure calculations to libraries but retains state transition authority. The
verifier address, runtime hash, profile hash, queue, registry, schedule, data session, and router are
immutable constructor commitments. No governance path can substitute candidate state or a verifier
after deployment.

### 4.4 L2 receipt and terminal plane

- `InboxV2ActivationGate`: false at deployment and enabled once by the authenticated AnchorV4
  activation path.
- `InboxApplyRouterV2`: one global queue cursor, one call per L2 block, full-vector validation,
  append-only domain routes, at most 64 contiguous-run calls, and exact return magic.
- `InboxCreditStoreV2`: endpoint-local, callback-free, idempotent credit pins with immutable router,
  Bridge, gate, and registrar bindings.
- `ProtocolReleaseAuthorityV2`: protocol-lifetime release-manifest authentication bound to the
  reserved system origin and manifest namespace. Each version is one-shot; its manifest supplies
  the exact `anchorV4` and `anchorRuntimeHash`, both of which the authority checks at activation.
- `TerminalDomainRegistrarV2`: atomic endpoint sealing, route registration, accumulator-writer
  registration, and permanent release commitment.
- `TerminalAccumulatorV2`: protocol-lifetime depth-64 append-only terminal vector and fixed-depth
  historical proofs.
- `AnchorV4`: the profile-exact implementation installed into the authenticated legacy Anchor/fork
  topology, providing activation and per-block anchoring for the reserved custom system
  transaction. Its implementation, beacon, and fork-selector slots are proved against the manifest
  rather than assumed to be a new non-proxy deployment.

The router, store, release authority, registrar, accumulator, and gate are non-proxy and
unpausable. The router is the only credit-store writer; the registrar is the only route/writer
registrar; the registered Bridge is the only caller allowed to verify its endpoint's permanent
credit pin. The Bridge prevents replay through its own V2 lifecycle status; a successful verification
does not consume or delete the store pin.

## 5. Dependency and Activation Rules

The normative configuration has address cycles. They are resolved only by precomputing the fixed
deployment coordinator's CREATE nonce sequence recorded in the manifest and by the narrowly scoped
one-shot seals below. No general post-deployment dependency setter is allowed.

| Relationship | Binding mechanism | Initial state and sole writer | Validation and terminal behavior |
| --- | --- | --- | --- |
| `ActiveSettlementRouter` <-> `ForcedQueue` | Both constructor immutables use precomputed addresses. | No setter. Queue starts with the router and launch Settlement identities fixed. | Runtime/config hashes and empty queue commitments are manifest/proof checked. Launch cancellation leaves the original authority; activation transfers only through the router's atomic path. |
| router <-> `ProtocolVersionManager` | Constructor immutables use precomputed addresses. | No setter. | Only the manager may arm/activate an exact delayed manifest; only the router may expose/consume its exact migration generation. Cancellation restores the unchanged old authority. |
| `Settlement` -> router/queue/registry/schedule/session/verifier/profile | Constructor immutables use precomputed addresses. | Settlement starts `PREACTIVE`; no dependency setter. | Router registration checks runtime, configuration, and profile. A failed or cancelled activation leaves it permanently inert; a successful version can later only become `FROZEN`. |
| L2 registrar <-> inbox router/accumulator | Constructor immutables use precomputed addresses. | Registrar is their sole route/writer-registration caller. | Each version/domain/writer entry is append-only. Revert/cancel leaves every entry absent; success permanently records the exact manifest entry. |
| endpoint store <-> registrar/Bridge/gate/inbox router | Constructor immutables use precomputed addresses; only `destinationDomainId` is sealed. | Domain starts zero; registrar is sole one-shot writer during atomic activation. | Store runtime/config and every constructor binding are checked first. Failure reverts to zero; success writes the exact manifest domain and burns the seal authority. |
| activation gate -> AnchorV4 release path | Gate fixes the release authority/registrar activation path; Anchor identity comes from the per-version manifest. | `active=false`; only the authenticated activation transaction may set it. | Exact origin, Anchor runtime, manifest, release, and registrar effects are checked atomically. Cancellation before activation leaves it false; activation makes it permanently true. |
| accumulator <-> destination Bridge | Registrar appends one writer binding after checking the manifest and Bridge identity. | Writer entry starts absent; registrar is sole writer. | Failed activation reverts the entry; successful registration is permanent and cannot be redirected. |
| `BridgeCreditRegistry` <-> frozen source Bridge | Constructor immutables use precomputed addresses. | No setter. | Registry accepts only the exact Bridge; Bridge's stored registry/config and final runtime/layout are profile checked. A cancelled launch leaves both V2 paths disabled; success never permits replacement. |
| source `BridgeInboxAdapter.destinationDomainId` | One-shot manager seal. Other adapter dependencies are constructor immutables from precomputed addresses. | Domain starts zero; `ProtocolVersionManager` is sole writer. | The active manifest, runtime/config, source generation, Bridge, registry, and router are checked. The authority bit is burned on success. A cancelled generation remains unusable because router/generation checks reject it; it is never repointed. |
| L2 Bridge/store/accumulator endpoint identity | One-shot registrar seals for the launch legacy-proxy endpoint; fresh endpoints are immutable non-proxies. | Identity/domain/index namespaces start unset; registrar is sole writer. | The launch proof authenticates actual proxy implementation/authority/fork slots. Failure reverts all seals; success burns their authorities. A later release must exactly reproduce the stored identity. |

Every precomputed address, CREATE nonce, constructor argument, initial-zero slot, seal authority, and
burned-authority slot is emitted into the release manifest and checked by deployment tests. A
partially initialized cycle is invalid, not repairable through a public setter.

## 6. State-Machine Ordering

The Appendix's exact transition ordering is normative. There is no universal effects-before-calls
rule because several consensus transitions intentionally validate or call a fixed component before
the final cursor/root write.

| Subsystem | Required ordering |
| --- | --- |
| Registry, schedule, and data session | Synchronize migration phase; authenticate headers/proofs and all inputs; derive commitments; then write the bounded local transition. Authentication calls are static, code-hash checked, gas capped, and occur before writes. |
| Forced ingress | Synchronize and require `ACTIVE` before custody; validate/fund the complete descriptor; router stamps the generation; queue appends and accounts funds; a Bridge credit append then calls the fixed source Bridge to mark that exact record `QUEUED`. Any failure reverts queue and adapter effects together. |
| L2 inbox application | Validate the entire interval, descriptors, result hashes, routes, code/config hashes, and contiguous runs before the first call; call each fixed endpoint store; require exact success magic; advance `nextQueueIndex` only after every store call succeeds. Each store validates its complete run before writing permanent idempotent pins and makes no external call. |
| Settlement commit | Synchronize and validate candidate/context/history/queue inputs; call the immutable verifier before canonical writes; call `ForcedQueue.advanceCursor` for the exact proved interval in the specified atomic commit sequence; then write canonical core/history and best-effort reward receipt. Any queue or history failure reverts the whole commit. No reward, burn, Bridge callback, or caller-selected call occurs. |
| Destination Bridge terminalization | Authenticate the permanent pin and lifecycle; execute the bounded recipient operation while protected against reentrancy; decide DONE/FAILED; write the terminal sentinel; call the fixed accumulator; replace the sentinel with the returned index; then expose pull-credit effects. Any failure reverts the whole terminal transition. |
| Source Bridge finalization/recall/cancel | Verify the fixed terminal proof or deadline first; write the terminal lifecycle and reduce the exact liability; credit the owner's pull balance; transfer only in a later withdrawal call. |
| Launch and V2 migration | Authenticate all manifests, code/configuration, old state, queue state, target proof, and output before an irreversible write. Then perform the specification's bounded freeze, authority transfer, queue advancement, target initialization/history write, and router activation in one revert domain. No caller-controlled external call occurs after authority transfer. Cancellation runs while old authority is unchanged. |
| Pull claims and vault restoration | Authenticate the exact credit/capsule, set claimed/consumed state and reduce only the matching reserve, then perform the asset transfer/restoration. A failed transfer reverts that claim but cannot block canonical progress or other claimants. |

All paths still validate widths, domains, sequence tags, deadlines, code hashes, configuration hashes,
return lengths, and caller authority before trusting an external result. All identifiers and
commitments use the shared encoding libraries.

## 7. Cryptographic Boundary

Solidity implements and tests:

- exact public-statement hashing;
- EIP-712 header recovery with low-`s` enforcement;
- fixed Merkle/MMR operations;
- EIP-4788/EIP-2935 authentication adapters;
- bounded canonical MPT proof decoding and verification;
- verifier address/runtime/profile binding; and
- strict proof-verifier return handling.

Solidity does not fabricate the missing proof circuit. Until the real verifier and key are
available, integration tests use immutable deterministic doubles that can accept only preinstalled
statement hashes, reject, revert, return malformed data, or consume bounded gas. A test verifier is
never accepted by deployment/profile generation.

## 8. Testing Strategy

Implementation is test-driven. Each round first adds a failing test for the behavior being built,
then the minimum implementation, then adversarial and boundary coverage.

Required test classes are:

- unit tests for every state transition and custom error;
- golden-vector tests matching every Appendix commitment;
- fuzz tests for widths, timestamps, ordering, duplicate evidence, malformed encodings, and
  adversarial return data;
- invariant tests for solvency, append-only roots/counts, monotonic cursors/sequences, one-shot
  transitions, no status resurrection, and conservation of deposits/claims;
- stateful handler tests spanning registry, schedule, queue, settlement, Bridge, vault, and
  migration operations;
- cross-contract integration tests for normal settlement, recovery, forced expiry, credit
  DONE/FAILED, migration activation, cancellation, and retry after cutover;
- storage-layout compatibility tests for the final legacy Bridge/vault facade;
- selector-collision and arbitrary-calldata fuzz tests proving frozen facades cannot upgrade,
  delegate, or mutate protected slots;
- bounded-gas tests at every normative maximum, retaining the specified 30% margin; and
- differential tests against the three Python reference models and generated encoding vectors.

Tests mirror contract paths, inherit `CommonTest`, and follow current naming conventions. Layer 1,
Layer 2, and shared contracts are always compiled and tested under their own profiles and artifact
directories; no integration command recompiles all three under one EVM version.

Cross-chain tests live under `packages/protocol/integration/slotchain/`. A TypeScript harness loads
the already-built `out/layer1`, `out/layer2`, and `out/shared` artifacts and deploys them to separate
Anvil instances configured for their respective chain profiles. Shared bytecode is built once under
the oldest supported fork and deployed to either instance. The harness relays only commitment-
authenticated outputs between chains and cannot replace a verifier or inject a root.

Forge tests may directly exercise the contract effects of the reserved system call by using a test
harness sender. They do not claim to validate the custom type-`0x7f` envelope, fork decoding,
receipt construction, or block-level ordering. Those checks belong to the executable-profile/client
conformance harness and real circuit vectors and remain an explicit production gate.

## 9. Round and Commit Policy

Each implementation round is one coherent commit containing its interfaces, implementation,
tests, and any generated vectors. A round cannot be committed until:

1. focused tests pass;
2. the applicable profile builds with storage-layout output;
3. formatting and linting pass for touched Solidity;
4. an independent Solidity test review checks missing failure paths;
5. an adversarial protocol review finds no unresolved critical/high issue in that slice; and
6. existing unrelated changes remain untouched.

Later rounds may amend earlier contracts only through a new, separately explained commit with a
regression test that fails on the prior behavior.

## 10. Completion and Production Gates

The contract implementation is complete when all inventory items exist, all public interfaces are
documented, all cross-contract workflows are executable in tests, generated runtime/layout hashes
are reproducible, and the entire protocol suite passes.

The design is not declared production-ready merely because Solidity tests pass. Production release
also requires the normative section 11 artifacts: real circuit and verifier-key binding, canonical
CBOR profile, bytecode-complete release manifest, cross-language vectors, benchmark margins,
migration rehearsal, testnet soak, and independent proof-system, Solidity, Bridge, and economic
audits with no open critical/high findings.
