# BuilderRegistry deployability repair

**Status:** accepted design repair for Slot-Chain v2.27  
**Ownership:** normative LaTeX/model changes belong to PR #22064; Solidity and tests belong to
PR #22096.

## Problem and constraints

The first complete `BuilderRegistry` implementation is not deployable. With the release compiler
settings its runtime is 34,790 bytes (34,428 bytes even at optimizer runs 1), above EIP-170's
24,576-byte limit. Its exact flattened 22-argument constructor also fails the non-via-IR compiler
before the constructor body executes, proving that the ABI decoder itself is over the stack limit.
Removing only equivocation verification leaves approximately 25,433 runtime bytes and therefore
does not solve the deployment failure.

The repair must preserve these properties:

- `BuilderRegistry` remains the sole state and custody authority. It alone owns roots, locators,
  counters, replay state, tombstones, credits, token transfers, and all state-changing entry points.
- No proxy, delegatecall, mutable implementation, administrator, pause, arbitrary target, callback,
  or helper-owned state is introduced.
- Proof computation is deterministic, bounded, configuration-authenticated, and fail-closed.
- Every helper request and response is unambiguously bound to the exact prestate and witness.
- Both deployable runtimes and their complete init code satisfy EIP-170 and EIP-3860 with margin.

## Selected architecture

Add exactly one root-lifetime artifact, `BuilderRegistryProofVerifierV1`. It is immutable,
stateless, ownerless, non-proxy, nonpayable, and callable only through its two exact proof interfaces
and two selector-only configuration reads. Its runtime contains the fixed-tree proof engine and signed-header/equivocation
verification. It never calls `BuilderRegistry` or another user-selected target, never transfers
value, and has no storage-writing opcode, fallback, receive function, selfdestruct, delegatecall, or
generic dispatch.

The verifier is permissionlessly predeployed through the canonical ERC-2470 singleton using its
release-pinned no-argument creation code. Let:

```text
helperInitCodeHash = H(type(BuilderRegistryProofVerifierV1).creationCode)
helperSalt = H("slot-chain-builder-registry-proof-verifier-salt-v1" ||
               u256(settlementChainId) || manifestNamespace ||
               helperConfigurationHash)
helperAddress = low20(H(0xff ||
                address20(0xce0042B868300000d44A59004Da54A005ffdcf9f) ||
                helperSalt || helperInitCodeHash))
```

Factory's constructor pins the init-code, runtime, and configuration hashes and derives the salt
and address. `BuilderRegistry` receives the derived address plus runtime/configuration hashes.
Factory staging and finalization authenticate the live verifier and require the BRC1 fields to equal
its derived pins.
Predeployment avoids embedding the verifier's creation code inside Registry init code and avoids a
constructor-created child whose code could evade the Factory's independent artifact check.

This verifier is the nineteenth root artifact. It is not a tenth component role, has no activation
state, and is never redeployed per release. The root manifest still has roles 1 through 9.

## Typed Registry constructor

The actual constructor is:

```solidity
constructor(
    address protocolRootFactory,
    bytes32 factoryRuntimeHash,
    bytes32 campaignKey,
    BuilderRegistryConstructorV1 memory config
)
```

`BuilderRegistryConstructorV1` is one fully static tuple in this exact order:

```text
uint256 settlementChainId
address builderLeaseToken
bytes32 builderLeaseTokenRuntimeHash
uint8 builderLeaseTokenDecimals
uint192 leasePerWindowAtomic
uint192 maximumBondAtomic
uint192 reporterRewardCapAtomic
uint64 genesisTimestamp
uint64 evidenceDelaySeconds
uint64 reorgMarginSeconds
uint64 firstManagedWindow
address builderPenaltySink
uint64 rewardClaimWindowSeconds
address activeSettlementRouter
bytes32 routerRuntimeHash
bytes32 routerConfigurationHash
address scheduleOracle
bytes32 scheduleOracleRuntimeHash
address builderProofVerifier
bytes32 builderProofVerifierRuntimeHash
bytes32 builderProofVerifierConfigurationHash
BuilderRewardClassConfigV1[3] rewardClasses
```

The tuple is 39 static words; the complete constructor encoding is 42 words (1,344 bytes). It has
no dynamic offset, decoder alias, optional suffix, or alternate packed form. Implementations access
the tuple through staged validation helpers and do not destructure it into a stack-sized flat list.

## Verifier configuration

`builderRegistryProofVerifierConfigV1()` has selector `0x0d1c9932` and returns exactly 512 bytes:

```text
(bytes4 magic,uint8 schema,uint16 registryLeaves,uint16 admissionUsedLeaves,
 uint16 admissionTreeLeaves,uint16 trancheLeaves,uint8 registryDepth,
 uint8 admissionDepth,uint8 trancheDepth,uint8 maximumTrancheBatch,
 uint32 identityCallGas,uint32 registryCallGas,uint32 admissionCallGas,
 uint32 trancheBatchCallGas,uint32 evidenceCallGas,bytes32 configurationHash)
```

The fixed row is `BPV1,1,64,1136,2048,512,6,11,9,18,350000,120000,160000,700000,450000`.
Let `C` be the exact 71-byte packed concatenation of the fourteen numeric fields after the initial
BPV1 magic, then the two selectors below, magics `BPV1,EIV1,BPR1,BPO1`, and widths
`u16(512),u16(320),u16(192),u16(432),u16(531),u16(6770),u16(2727)`.

```text
configurationHash = H(
  "slot-chain-builder-proof-verifier-config-v1" || u16(71) || C)
```

`componentConfigHashV2()` returns this same hash in exactly 32 bytes. BPV1 is read with exactly
100,000 gas and the component getter with exactly 50,000 gas. Registry authenticates the
verifier's `EXTCODEHASH`, 512-byte BPV1 row, and 32-byte component hash once before the first
verifier call in each external operation. A fault, short/trailing/dirty return, or mismatch reverts
before a root, escrow, credit, locator, or counter write. The release gate measures each published
gas stipend and its one-gas-below boundary against the final compiled artifact; a stipend that does
not pass this certificate is a blocking spec defect, not an implementation discretion.

## Exact identity interface

```text
verifyBuilderEquivocationIdentityV1(uint256 expectedSettlementChainId,bytes evidence)
selector 0x7c09d62d
```

The call is nonpayable only by ABI declaration but Registry invokes it with `STATICCALL` and zero
value. Its dynamic offset is `0x40`; `evidence` is exactly 2,366 bytes; total calldata is 2,468
bytes with exactly two zero tail-padding bytes and no suffix. Define
`evidenceHash = H(evidence)` over exactly those 2,366 evidence bytes. The exact 320-byte EIV1 return
is:

```text
(bytes4 magic,bytes32 verifierConfigurationHash,bytes32 evidenceHash,
 bytes32 identityCommitment,address builder,uint64 window,uint64 protocolVersion,
 address verifyingContract,uint64 signedAdmissionVersion,bytes32 signedAdmissionRoot)
```

The verifier performs all signed-header width, tier, pair-equality, domain, ordering, low-s,
recovery, and `window=slot/384` checks frozen in the normative specification. Both signed settlement
chain IDs must equal `expectedSettlementChainId`, and the protocol version must fit `uint64`.

Before this call, Registry checks the exact evidence length, cheaply decodes and pair-checks both
signed settlement chain IDs, protocol versions, and verifying contracts, requires the local chain
and `uint64` version, and successfully authenticates RTR2 for that version/Settlement. This preserves
the rule that an unregistered EIP-712 domain is rejected before signature recovery. The verifier
repeats all of these identity checks; Registry then requires every returned field to equal its
prechecked values.

```text
identityCommitment = H(
  "slot-chain-builder-equivocation-identity-v1" || u16(192) ||
  verifierConfigurationHash || evidenceHash || u256(expectedSettlementChainId) ||
  u64(protocolVersion) || address20(verifyingContract) || u64(window) ||
  u64(signedAdmissionVersion) || signedAdmissionRoot || address20(builder))
```

## Exact proof interface

```text
verifyBuilderRegistryProofV1(bytes request)
selector 0xa9ca9190
```

The canonical offset is `0x20`; total calldata is `68+ceil32(requestLength)` with zero padding and
no gap, alias, value, or suffix. Every request starts `BPR1 || u8(opcode)` and is packed big-endian.
Registry supplies exactly 120,000, 160,000, 700,000, or 450,000 gas for opcodes 1 through 4;
the identity interface receives exactly 350,000 gas. Immediately before each STATICCALL it requires
at least `L+ceil(L/63)+10006` gas so EIP-150 cannot reduce the requested operand. Later insufficient
gas reverts the entire Registry transaction and cannot publish a partial transition.
The exact 192-byte BPO1 return is:

```text
(bytes4 magic,bytes32 verifierConfigurationHash,bytes32 requestCommitment,
 bytes32 newRegistryRoot,bytes32 newAdmissionRoot,bytes32 newTrancheRoot)
```

The output mask is exact: opcode 1 is `(R,0,0)`, opcode 2 is `(0,A,0)`, and opcode 3 is `(0,0,T)`
in `(newRegistryRoot,newAdmissionRoot,newTrancheRoot)` order. Opcode 4 always returns T, returns R
iff the current location is ACTIVE, and returns A iff this evidence first replaces the tombstone
sentinel. Every masked-off word is exact zero; Registry preserves the corresponding pre-root rather
than treating zero as a root. Registry computes the request commitment independently and accepts
only:

```text
requestCommitment = H(
  "slot-chain-builder-proof-request-v1" || u32(requestLength) || request)
```

The canonical packed cells are:

```text
registryCell[100] = address20(builder) || u192(baseBond) || u64(registrationIndex) ||
                    u64(effectiveL2Slot) || bytes32(trancheRoot) || u64(tombstone)
admissionCell[68] = address20(builder) || u192(baseBond) || u64(registrationIndex) ||
                    u64(effectiveL2Slot) || u64(tombstone)
trancheLeaf[43]   = u16(index) || u64(window) || u8(state) || u192(amount) || u64(deadline)
```

The opcodes are:

1. `REGISTRY_REPLACE`, exactly 432 bytes:
   `BPR1||01||root32||index8||oldOccupied8||oldCell100||newOccupied8||newCell100||siblings[6]`.
   Offsets are root 5, index 37, old flag 38, old cell 39, new flag 139, new cell 140,
   siblings 240.
2. `ADMISSION_REPLACE`, exactly 531 bytes:
   `BPR1||02||root32||position16||oldOccupied8||oldLocation8||oldCell68||newOccupied8||`
   `newLocation8||newCell68||siblings[11]`. Offsets are root 5, position 37, old flag/location
   39/40, old cell 41, new flag/location 109/110, new cell 111, siblings 179. Position is below
   1,136; empty has zero cell/location; occupied location is exactly 1 or 2.
3. `TRANCHE_BATCH`, exactly `38+374*n` bytes for `1<=n<=18`:
   `BPR1||03||initialRoot32||u8(n)||repeat(oldLeaf43||newLeaf43||siblings[9])`.
   Each transition anchors the root produced by its predecessor. Maximum request length is 6,770.
4. `EQUIVOCATION`, exactly 2,727 bytes. It contains the exact 2,366-byte evidence, expected chain,
   `evidenceHash`, `identityCommitment`, returned builder, current generation identity/location,
   current roots, reservation state and current tranche leaf. The normative LaTeX fixes every
   offset. The verifier recomputes evidence identity; proves historical and current admission,
   current tranche transition to `SLASHED`, and active registry replacement; or, for liability,
   requires the six registry siblings to be exact zero. It returns all changed roots together so
   no partially validated evidence transition is accepted.

All flags, locations, indices, widths, empty encodings, leaf semantics, transition classes, path
orders, and tree depths are verified inside the helper. Registry constructs requests solely from
authenticated storage plus the caller's already length-bounded sibling bytes, checks the returned
commitment and roots, rechecks the storage prestate used in the request, and only then commits the
state transition. There is no mutating external call between request construction and commit.

## Factory and deployment joins

`ProtocolRootFactoryV1` adds the verifier init-code hash, runtime hash, and configuration hash to its
constructor. Its configuration hash and PRF1 row also commit those values plus the derived salt and
address. Before root staging and again before finalization it authenticates the exact
BPV1/component-config views. Role-1 BRC1 adds the derived address, runtime hash, and configuration
hash after the Schedule runtime hash. The BRC1 return becomes 800 bytes; its topology preimage
becomes 405 bytes. Factory requires exact equality between its own pins and BRC1 before activation.

The canonical zero-value ERC-2470 call is `deploy(bytes,bytes32)`, selector `0x4af63f02`, head
`[0x40,helperSalt]`, followed by the exact contiguous init-code length/data and zero padding. It must
return the exact derived address. An earlier exact-code deployment at that address is accepted;
different init code derives a different address. Missing/wrong code, wrong config, malformed return,
or a dirty collision blocks before Factory/root activation. Deployment order is verifier, Factory,
then the nine-role campaign. An aborted campaign reuses the verifier; there is no mutable fallback.

The root artifact gate covers nineteen artifacts in one release-pinned Layer-1 build. It rejects a
verifier with storage writes or mutable/delegate/callback reachability, either runtime above 24,576
bytes, either complete init code above 49,152 bytes, or Registry runtime above 23,500 bytes. The
23,500-byte Registry ceiling is a release engineering margin, not an EVM consensus rule. If the
selected split misses it, the same verifier may absorb additional whole proof-plan opcodes; adding a
second helper or moving state/custody authority is not an authorized implementation shortcut.

## Rejected alternatives

- **Evidence-only helper:** the measured Registry remains above EIP-170.
- **Constructor-created helper:** embeds helper creation code in Registry init code, weakens the
  Factory's independent pin, and creates a second EIP-3860/code-deposit coupling.
- **Linked external library/delegatecall/diamond:** gives proof code Registry storage authority and
  expands upgrade or layout risk.
- **Stateful sub-registry:** splits root, replay, custody, and locator authority and creates atomicity
  and cross-contract liveness failures.
- **Opaque custom-packed constructor bytes:** avoids one compiler symptom but removes typed ABI
  guarantees and creates an unnecessary parser attack surface.

## Implementation gates

The repair is complete only when tests prove:

1. non-via-IR constructor compilation and exact 1,344-byte tuple encoding;
2. exact BPV1/BRC1/PRF1 returns and all one-field substitutions;
3. selector, offset, length, padding, suffix, value, gas, return-size, and dirty-word rejection for
   both verifier calls;
4. differential equality with the Python tree/evidence model for every opcode;
5. all four active/liability by first/already-tombstoned equivocation output masks, duplicate/
   idempotence, first/last builder, ring wrap, first/last window, maximum batch, and alias-resistant
   old/new leaf transitions;
6. fault injection for absent/wrong verifier code, wrong configuration, revert, OOG, malformed and
   adversarial return data;
7. stateful root/custody/credit/counter invariants under verifier faults;
8. compiled size gates for both runtimes and complete init code, including the 23,500-byte Registry
   engineering ceiling; and
9. a clean two-build deterministic artifact transcript containing all nineteen artifacts.

The pre-existing 1,500,000-gas Executor-to-Factory stage operand is also a blocking measurement
gate because stage now performs BPV1 plus component-config reads. The widened compiled cold path
must succeed at exactly 1,500,000 and preserve the release safety margin; its measured minimum and
one-gas-below rejection are recorded. If it does not, PR #22064 raises the frozen operand and
regenerates RME1/configuration vectors before the code round can be accepted.
