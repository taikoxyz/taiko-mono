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
- `LibFixedMerkle`: depth-6, depth-9, and depth-64 trees with pinned empty nodes and bit order.
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
- `MigrationCoordinator`: launch import and later proof-first cutover orchestration. It performs all
  validation before authority transfer and keeps transfer, queue advancement, history write, old
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
- `ProtocolReleaseAuthorityV2`: one-shot release-manifest authentication bound to the reserved
  system origin and exact AnchorV4 caller.
- `TerminalDomainRegistrarV2`: atomic endpoint sealing, route registration, accumulator-writer
  registration, and permanent release commitment.
- `TerminalAccumulatorV2`: protocol-lifetime depth-64 append-only terminal vector and fixed-depth
  historical proofs.
- `AnchorV4`: exact activation and per-block anchoring entry point for the reserved custom system
  transaction.

All L2 components are non-proxy and unpausable. The router is the only credit-store writer; the
registrar is the only route/writer registrar; the registered Bridge is the only caller allowed to
verify and consume its endpoint credit.

## 5. Dependency and Activation Rules

The deployment dependency graph is intentionally acyclic:

```text
shared libraries/interfaces
       |
       +--> L1 registries / queue / sessions / schedule
       |          |
       |          +--> Settlement --> ActiveSettlementRouter
       |                              |
       |                              +--> adapters / version manager / migration
       |
       +--> L2 gate / authority / accumulator / router
                  |
                  +--> endpoint store / registrar / AnchorV4
       |
       +--> credit registry --> frozen Bridge facade --> vault refund components
```

Where two deployed addresses refer to one another, deterministic deployment order and one-shot
sealing replace circular constructor dependencies. A seal may only change an unset value to the one
manifest-authenticated value, validates runtime/configuration, and burns its authority in the same
transaction.

## 6. State-Machine Rules

Every external state transition follows this order:

1. synchronize the shared migration phase when applicable;
2. reject if the phase does not permit the operation, before taking custody or writing a durable
   record;
3. validate widths, domains, sequence tags, deadlines, code hashes, configuration hashes, exact
   return lengths, and caller authority;
4. compute all derived identifiers and commitments using a single shared library implementation;
5. update status, liabilities, roots, counts, cursors, and replay markers;
6. perform only fixed-target external calls required for the atomic transition; and
7. emit the past-tense event after state is committed.

Potentially failing asset transfers are separated from canonical commits and use pull claims.
Canonical settlement performs no reward transfer, burn transfer, Bridge callback, or caller-selected
external call.

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

Tests mirror contract paths, inherit `CommonTest`, and follow current naming conventions. The
relevant Foundry profile is run after each focused test; all Layer 1, Layer 2, and shared suites run
at integration boundaries.

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
