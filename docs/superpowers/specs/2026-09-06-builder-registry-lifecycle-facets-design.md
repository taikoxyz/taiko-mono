# BuilderRegistry frozen lifecycle facets

**Status:** normative Slot-Chain v2.27 implementation boundary. This document supersedes the
single-helper code-size conclusion in `2026-09-06-builder-registry-proof-verifier-design.md`; its
proof-verifier protocol remains normative.

## Decision

The Registry remains above EIP-170 after every proof calculation is extracted into the stateless
`BuilderRegistryProofVerifierV1`. A measured second stateless planner made Registry 309 bytes
larger: lifecycle, custody, and storage transitions still dominated while larger request encoders
replaced compact proof calls.

The production boundary is one immutable Registry facade plus two immutable execution facets:

- `BuilderRegistry` is the only state, token-custody, event-emitter, and authoritative address.
- `BuilderRegistrySeatLifecycleFacetV1` owns the three seat-lifecycle selectors.
- `BuilderRegistryLeaseLifecycleFacetV1` owns the four reservation/release selectors.
- credit claim and equivocation remain in the Registry facade.
- every operational selector is an explicit Registry wrapper; there is no fallback, selector
  table, mutable target, administrator, upgrade, or caller-selected call.
- a wrapper dispatches unchanged `msg.data` to one constructor-pinned target through
  `DELEGATECALL`, after checking that target's live `EXTCODEHASH`, and bubbles exact return/revert
  data up to the closed 224-byte response bound.

This is static code sharding, not an upgradeable diamond. Facets have full Registry authority while
executing, so their exact runtimes, configurations, selector ownership, and common storage layout
are part of the root trust boundary.

## Exact selector ownership

Seat facet, kind `1`:

| Selector | Signature |
| --- | --- |
| `0x5fc42c69` | `registerBuilderV1(uint192,uint64,uint8,bytes)` |
| `0xc8f20b55` | `requestBuilderExitV1(uint64)` |
| `0x0e1ffc68` | `processBuilderMaintenanceV1(uint8,bytes)` |

Lease facet, kind `2`:

| Selector | Signature |
| --- | --- |
| `0x46a53315` | `reserveBuilderWindowV1(uint64,uint64,bytes)` |
| `0x5e7c8afe` | `normalizeBuilderTranchesV1(address,uint64,bytes)` |
| `0xf8668bb9` | `releaseBuilderTrancheV1(address,uint64,uint64,bytes)` |
| `0xe7bae370` | `releaseBuilderGenerationV1(address,uint64,bytes)` |

This order is canonical. `claimBuilderLeaseCreditV1(address)` and
`submitBuilderEquivocationV1(bytes)` remain facade code. Each facet makes every non-owned Registry
mutation revert `UnsupportedFacetSelector`; compiler dead-code elimination alone is not an
externally reachable surface guarantee.

## Shared storage and context

Registry and both facets inherit the same `BuilderRegistryStorageV1` directly; no subclass appends
state. Its first three slots exactly mirror the `ProtocolRootComponentV1` factory-runtime-hash,
campaign-key, and activation-state prefix. The proof-verifier descriptor is constructor-written
storage with no reachable writer because delegated code cannot read Registry runtime immutables.
The schema also contains `_registrySelf`, set only by Registry construction to `address(this)`, one
global `_operationLock`, and the narrower pre-existing token lock.

Every facet operation first requires an active root and
`_registrySelf == address(this) && _registrySelf != address(0)`. Direct calls to a generic facet
therefore reject before proof, state, or token access. Testing `msg.sender == Registry` is wrong:
`DELEGATECALL` preserves the original caller.

The release build emits Solidity storage-layout JSON for Registry, both facets, the common storage
base, and common abstract logic. Normalize each by recursively sorting object keys, retaining every
entry's `label`, `slot`, `offset`, referenced canonical type, and full reachable `types` graph, then
encoding without insignificant whitespace. All five byte strings must be identical; their
`keccak256` is `builderRegistryStorageLayoutHash`, pinned by the release manifest. The 53-entry
non-via-IR prototype digest after adding the global lock is
`0xe9530d93d58f89bfc204b96dd4063445b3c2823458ae18e8580c8436f3853930`; final code must regenerate
it, and any change requires an explicit manifest update. The lock packs at slot 5 offset 20 after
`_registrySelf`; `_settlementChainId` remains slot 6 and `_tokenLock` remains slot 6869 offset 0.

## Facet configuration and deployment

Each facet implements the exact 192-byte read:

```solidity
builderRegistryLifecycleFacetConfigV1() returns
 (bytes4 magic,uint8 schema,uint8 facetKind,
  bytes32 storageLayoutHash,bytes32 selectorSetHash,
  bytes32 configurationHash)
```

The selector is `0x5c19dfed`; `magic = 0x42524631` (`BRF1`) and `schema = 1`.
Narrow words are canonically zero padded. Let `S = u8(facetKind) || u8(selectorCount) ||` the
canonical ordered selector bytes above. Then:

```text
selectorSetHash = H(
  "slot-chain-builder-registry-facet-selectors-v1" || u16(byteLength(S)) || S)
configurationHash = H(
  "slot-chain-builder-registry-lifecycle-facet-config-v1" ||
  u8(facetKind) || storageLayoutHash || selectorSetHash)
```

The resulting `(selectorSetHash, configurationHash)` pairs are Seat
`(0x92e9dd5f246684dbc6137c40eb276993130005222bc31be614359dbc1164bbf5,
0x8dceb04e2485c4e9b73ca0ed5b7c820f0a3454c5157696b255945e8fa8ef65c4)` and Lease
`(0x895e8723291f0a1f397a981815290e003eab16a87807eadc3b3bc0d805b8fb78,
0x033d38df4112f42f6766257b4fe7ee0af66367cfd9c6e0b9f57cea236f584f11)`.

Exact `componentConfigHashV2()` equals `configurationHash`. Both facets have no-argument creation
code and are predeployed through canonical ERC-2470. For each kind:

```text
facetInitCodeHash = H(type(FacetKind).creationCode)
facetSalt = H(
  "slot-chain-builder-registry-lifecycle-facet-salt-v1" ||
  u256(settlementChainId) || manifestNamespace || u8(facetKind) || configurationHash)
facetAddress = low20(H(0xff || address20(ERC2470) || facetSalt || facetInitCodeHash))
```

Factory constructor-pins and PRF1 exposes each facet's init-code hash, salt, derived address,
runtime hash, configuration hash, selector-set hash, and the common layout hash. It exact-reads BRF1
and `componentConfigHashV2()` before staging and again before finalization. Missing or changed code
or configuration blocks root activation.

## Registry commitments

`BuilderRegistryConstructorV1` places the Seat address/runtime/configuration triple followed by the
Lease triple immediately after the proof-verifier triple. It is 45 static words; with the three
activation arguments, complete constructor encoding is 48 words / 1,536 bytes.

Registry topology appends those triples in Seat-then-Lease order immediately after the verifier
triple and before the economic configuration hash. Its domain is
`slot-chain-builder-registry-topology-v2`; packed payload length is 573 bytes. BRC1 remains 800 bytes
and does not duplicate facet descriptors. Factory recomputes topology using the BRC1 fields plus
its independently pinned facets and requires equality with Registry topology. PRF1 is the
observer-visible descriptor source.

Registry construction requires nonzero, pairwise-distinct Registry/verifier/facet addresses,
authenticates both runtimes and both exact BRF1/component rows, and derives topology rather than
accepting it. Thus topology transitively commits all code holding Registry storage authority.

## Global operation lock

One lock covers all seven facet selectors plus facade credit claim and equivocation. A token-only
lock is inadequate because token callbacks could otherwise enter maintenance, normalization,
release, or evidence during another transition.

The dispatcher rejects a set lock with `RegistryOperationReentry`, checks and sets it, performs the
fixed-target delegatecall, records success and `RETURNDATASIZE`, clears `_operationLock`, and only
then copies and returns/reverts with the exact bytes. The maximum is 224 bytes: that is the largest
canonical delegated success (`BTR1`, seven words), while every declared custom error is four bytes
and a Solidity panic is 36. A larger response rejects as `LifecycleFacetReturnDataTooLarge`
without copying it. A
normal postlude modifier around assembly `RETURN` is forbidden: `RETURN` skips modifier cleanup and
would permanently lock Registry. Facade claim/evidence use an ordinary modifier on the same lock.
No mutating Registry operation may enter while it is set; views remain callable.

Tests use adversarial token callbacks to enter every cross-facet and facade mutation from every
token-moving path and prove atomic rejection with unchanged roots, locators, escrows, credits, and
counters.

## Build and release gates

Canonical build is non-via-IR, optimizer runs 200, Osaka. The root cohort is exactly 21 artifacts:
the prior 19 plus two facets. Runtime is at most 24,576 bytes, complete init code at most 49,152,
and Registry keeps its 23,500-byte engineering ceiling. Initial read-only measurements are:

| Artifact | Runtime | Init code |
| --- | ---: | ---: |
| `BuilderRegistry` | 14,191 | 23,781 |
| `BuilderRegistrySeatLifecycleFacetV1` | 20,533 | 20,561 |
| `BuilderRegistryLeaseLifecycleFacetV1` | 17,972 | 18,000 |
| `BuilderRegistryProofVerifierV1` | 14,680 | 14,708 |

The complete Registry deployment input was 25,317 bytes. These are feasibility measurements, not
substitutes for clean-release measurements after final code is frozen.

Release also fails on selector overlap or misrouting, an uncommitted delegatecall, subclass storage,
layout-digest disagreement, BRF1 disagreement, direct-call reachability, stale lock, mixed compiler
profiles, or nondeterministic two-build hashes.

## Required adversarial coverage

Cover every selector through the facade and reject it directly on both facets; missing/wrong facet
code and every BRF1 substitution; selector misrouting; exact revert/return bubbling and the
225-byte rejection boundary; callback
reentrancy into all nine mutations; first/last builder and first/last window; vacancy/full-seat
replacement; equal/minimum/maximum bond tie-breaking; liability-ring wrap/overwrite; exit/entry and
release deadline equality; empty/full tranche masks; generation reuse; all proof faults;
conservation/solvency; and differential equality with the Python model.

The final transcript records all four size rows, the common layout digest, selector/configuration
hashes, two deterministic builds, and invariant/fuzz/coverage results. No code-only substitution for
these commitments is permitted.
