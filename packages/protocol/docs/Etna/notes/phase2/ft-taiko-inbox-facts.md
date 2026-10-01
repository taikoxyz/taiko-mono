# Taiko Inbox propose-path facts vs. the "Nonce as a Lock" PDF

Date: 2026-09-30. Repo: the repository root at HEAD `61d8f18` (shallow clone, 52 commits, oldest `f9a4949` 2026-08-31).
All file:line references below are to the working tree at that HEAD. Every claim is tagged VERIFIED (with the
file:line or URL it was checked against) or UNVERIFIED.

Legend for revert classification:
- **self-inflicted only** = only the sender's own inputs / own state can make it fire.
- **triggerable by others** = a third party (another proposer, a forced-inclusion submitter, a prover stall, governance) can make the sender's otherwise-valid tx revert.

---

## 0. Scope note on the PDF

Input read in full: `packages/protocol/docs/Etna/inputs/nonce-as-a-lock.txt` (315 lines, 7 PDF pages).
Its EIP-8141 / EIP-8038 / EIP-2780 / EIPs-PR claims are **out of scope for this report** and are listed as UNVERIFIED at the end;
this report only checks the Taiko-side claims.

---

## (a) The "4 uses of msg.sender on the propose path" — VERIFIED, line numbers match exactly

PDF claim (nonce-as-a-lock.txt:205-206): `Inbox.sol:596 (forced-inclusion fee recipient), :603 (checkProposer), :606 (hasSufficientBond), :615 (the proposer field)`.

Current code, `packages/protocol/contracts/layer1/core/impl/Inbox.sol`:

| # | line | quoted code | role |
|---|------|-------------|------|
| 1 | 595-596 | `ConsumptionResult memory result =` / `_consumeForcedInclusions(msg.sender, _input.numForcedInclusions);` | FI fee recipient (`_feeRecipient`) |
| 2 | 602-603 | `uint48 endOfSubmissionWindowTimestamp =` / `_proposerChecker.checkProposer(msg.sender, _lookahead);` | proposer authorization |
| 3 | 606 | `require(_bondStorage.hasSufficientBond(msg.sender, _minBond), InsufficientBond());` | bond check (guarded by `if (_minBond > 0)` at 604) |
| 4 | 615 | `proposer: msg.sender,` | `Proposal.proposer` field |

`grep -n "msg.sender" Inbox.sol` on the propose path (`propose` 270-290, `_buildProposal` 577-623, `_consumeForcedInclusions` 637-675, `_dequeueAndProcessForcedInclusions` 686-721, `_validateProposeInput` 764-766) yields exactly these four. Other `msg.sender` uses (lines 337, 404, 409, 414, 419, 424, 441) are on `prove`, bond, and `saveForcedInclusion` paths, not `propose`.
The PDF's line numbers are exact for this HEAD. **VERIFIED.**

`_buildProposal`'s NatSpec (Inbox.sol:567-570) also documents the msg.sender dependency: `/// - If msg.sender can propose.` / `/// - If msg.sender has sufficient bond.`

**tx.origin**: `grep -rn "tx.origin" packages/protocol/contracts/layer1/core packages/protocol/contracts/layer1/preconf packages/protocol/contracts/shared/common/EssentialContract.sol` returns nothing. The PDF's invariant "The Inbox never reads tx.origin" (txt:180) holds for the current Inbox. **VERIFIED.**

---

## (b) "One proposal per L1 block" — VERIFIED

Enforcement, Inbox.sol:588-590:
```solidity
// Enforce one propose call per Ethereum block to prevent spam attacks that could
// deplete the ring buffer
require(block.number > _lastProposalBlockId, CannotProposeInCurrentBlock());
```
State update, Inbox.sol:285: `_coreState.lastProposalBlockId = uint48(block.number);`
State field, IInbox.sol:86-87: `/// @notice The L1 block number where the most recent proposal was made.` / `uint48 lastProposalBlockId;`
Activation seeds it, LibInboxSetup.sol:79-84: `// Set lastProposalBlockId to 1 to ensure the first proposal happens at block 2 or later.` ... `state_.lastProposalBlockId = 1;`
Doc comment, Inbox.sol:268-269: `NOTE: This function can only be called once per block to prevent spams that can fill the ring buffer.`

Mechanism: a strict `block.number > lastProposalBlockId` check; the first successful propose in a block bumps `lastProposalBlockId` to the current block, so a second propose in the same block reverts with `CannotProposeInCurrentBlock`. **Triggerable by others** (any other authorized proposer landing first in the same block). Error declared at Inbox.sol:818.

The PDF's §3 statement that "n+1 in the same block ... reverts at the Inbox's CannotProposeInCurrentBlock" (txt:277-278) is consistent. **VERIFIED.**

Note: the field was named `nextProposalBlockId` when introduced by PR #20186 (see §PRs); it is now `lastProposalBlockId` with a `>` comparison instead of `>=`.

---

## (c) Forced-inclusion consumption rule — VERIFIED; PDF's characterization is accurate

Inbox.sol:637-675 `_consumeForcedInclusions(address _feeRecipient, uint256 _numForcedInclusionsRequested)`:

```solidity
650  uint256 available = tail - head;
651  uint256 dueToProcess;
652  uint256 maxToInspect = available.min(MAX_FORCED_INCLUSIONS_PER_PROPOSAL);
653  for (uint256 i; i < maxToInspect; ++i) {
654      IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[head + i];
655      uint256 timestamp = inclusion.blobSlice.timestamp;
656      if (timestamp == 0 || block.timestamp < timestamp + uint256(_forcedInclusionDelay))
657      {
658          break;
659      }
660      ++dueToProcess;
661  }
662  require(
663      _numForcedInclusionsRequested >= dueToProcess, UnprocessedForcedInclusionIsDue()
664  );
665
666  uint256 toProcess = _numForcedInclusionsRequested.min(available)
667      .min(MAX_FORCED_INCLUSIONS_PER_PROPOSAL);
```
`MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10` (Inbox.sol:65, with the rationale at 63-64: `Must be < 12 to avoid derived block timestamps drifting into the future ... Derivation enforces 1s block times`).

So:
- **toProcess = min(requested, available, 10)** — exactly what the PDF says (txt:210-211). "Due" is **not** a component of `toProcess`; it only appears as the floor check `requested >= dueToProcess` (line 662-664). Non-due queued entries ARE consumed if the proposer asks for them. **VERIFIED.**
- `dueToProcess` is computed against `_forcedInclusionDelay` (mainnet 576 s, MainnetInbox.sol:47) and stops at the first non-due entry (`break`), so it is the count of the leading due prefix, capped at 10.
- The PDF's proposed `min(max(requested, due), available, 10)` is **not** current behaviour. **VERIFIED (as a difference).**

`numForcedInclusions` input: `uint16` (IInbox.sol:108), packed as 2 bytes (LibCodec.sol:28/42). The IInbox NatSpec (IInbox.sol:105-107) says only "The number of forced inclusions that the proposer wants to process ... can be set to 0 if no forced inclusions are due". **There is no sentinel semantics in the contract**: 0xffff is just a large request clamped by `min(available, 10)`. **VERIFIED.**

Both production clients send 0xffff as an "as many as possible" convention:
- Go: `packages/taiko-client/proposer/transaction_builder/blob.go:117-118` — `// We try to include all the forced inclusions in the source manifest.` / `NumForcedInclusions: math.MaxUint16,`
- Rust: `packages/taiko-client-rs/crates/proposer/src/transaction_builder.rs:181-182` — `// Include all forced inclusions in the source manifest.` / `numForcedInclusions: u16::MAX,`
So the PDF's "combined with 0xffff, it lets anyone stuff FIs into someone else's proposal in the same block" (txt:211-212) is consistent with client behaviour: a proposer sending 0xffff will consume any entry that lands in the queue before its tx executes, due or not, up to 10. **VERIFIED (mechanism); the PDF's gas figures 76,485 / 100,517 / 218,805 are UNVERIFIED (not re-measured here).**

The "1 second per FI" timestamp shift (txt:214) is consistent with the Inbox.sol:63-64 comment about 1s block times, but the derivation-side rule itself lives outside the files in scope. **UNVERIFIED here.**

---

## (d) ProposeInput layout — VERIFIED: 15 bytes, deadline exists, expectedProposalId does NOT exist

Struct, IInbox.sol:99-109:
```solidity
struct ProposeInput {
    /// @notice The deadline timestamp for transaction inclusion (0 = no deadline).
    uint48 deadline;
    /// @notice Blob reference for proposal data.
    LibBlobs.BlobReference blobReference;
    uint16 numForcedInclusions;
}
```
`BlobReference` (LibBlobs.sol:10-17): `uint16 blobStartIndex; uint16 numBlobs; uint24 offset;`

Packed encoding, LibCodec.sol:17-29 (`encoded_ = new bytes(15);`), big-endian, in this order:

| offset | bytes | field |
|---|---|---|
| 0 | 6 | `deadline` (uint48) |
| 6 | 2 | `blobReference.blobStartIndex` (uint16) |
| 8 | 2 | `blobReference.numBlobs` (uint16) |
| 10 | 3 | `blobReference.offset` (uint24) |
| 13 | 2 | `numForcedInclusions` (uint16) |
| **15** | | total |

This matches the PDF's G pseudocode bit positions when the 15 bytes are left-aligned in a 32-byte word `w` (txt:137-146): `w >> 208` = deadline (bits 255..208), `(w >> 192) & 0xffff` = start, `(w >> 176) & 0xffff` = numBlobs, `(w >> 136) & 0xffff` = numForcedInclusions (offset occupies bits 175..152, numForcedInclusions 151..136). **VERIFIED.**

- `deadline` **exists**; checked at Inbox.sol:764-766 `require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());`. **VERIFIED.**
- `expectedProposalId` **does not exist** in the struct, codec, or Inbox. `grep -rn expectedProposalId packages/protocol/contracts` → nothing. The PDF correctly presents it as a *required addition* ("ProposeInput grows from 15 to 21 bytes", txt:221). **VERIFIED (absent).**

Decoder laxity (PDF txt:162-163 "the deployed LibCodec accepts non-canonical offsets, dirty padding, and _data of any length"):
- `LibCodec.decodeProposeInput(bytes memory _data)` (LibCodec.sol:32-43) does `ptr = P.dataPtr(_data)` then five `unpack*` calls with **no length check**. `LibPackUnpack.dataPtr` (LibPackUnpack.sol:302-306) is `add(_data, 0x20)`; `unpackUint48/16/24` (LibPackUnpack.sol:205-250) are bare `shr(N, mload(_pos))`. LibPackUnpack's header (lines 7-22) states "trust-the-caller pattern with no bounds checking". So a short `_data` decodes whatever bytes follow in memory (zeros for a freshly copied calldata array); a long `_data` ignores trailing bytes. **VERIFIED.** ("Non-canonical ABI offsets" refers to the outer `bytes calldata` ABI decoding, which is standard solc behaviour — UNVERIFIED here beyond the fact that `propose` takes `bytes calldata _data`.)

---

## (e) Forced-inclusion fee payment — VERIFIED: push, via CALL with all remaining gas, revert on failure

Inbox.sol:709-710:
```solidity
// Transfer accumulated fees
_feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);
```
`LibAddress.sendEtherAndVerify(address,uint256)` (shared/libs/LibAddress.sol:60-62) → `sendEtherAndVerify(_to, _amount, gasleft())` → (52-55) `if (_amount == 0) return; require(sendEther(_to, _amount, _gasLimit, ""), ETH_TRANSFER_FAILED());` → `sendEther` (20-46) does a raw `call(_gasLimit, _to, _amount, ...)` with empty calldata and reverts only via the outer `require`.

Consequences:
- **Push**, not pull. No accounting / `claimFees` exists; `grep -rn claimFees packages/protocol/contracts` → nothing.
- All remaining gas is forwarded (`gasleft()`), so a recipient with a fallback that reverts, or that consumes all gas, makes `propose` revert with `ETH_TRANSFER_FAILED` (LibAddress.sol:10).
- Only fires when `_toProcess > 0` (Inbox.sol:697-699 early return) **and** `totalFees > 0` (LibAddress.sol:53 early return; fees are non-zero by construction since `forcedInclusionFeeInGwei != 0` is enforced at LibInboxSetup.sol:37 and `getCurrentForcedInclusionFee` ≥ base fee).
- Recipient is `msg.sender` (Inbox.sol:596). If msg.sender is an EOA (or 7702-delegated to code that accepts ETH) it succeeds. The PDF's concern (txt:215-216) — a 7702-delegated P whose delegate rejects ETH would revert the whole propose — is consistent with this code. **VERIFIED (mechanism).**

Also note the `saveForcedInclusion` refund path (Inbox.sol:439-442) uses the same `sendEtherAndVerify`, but that is not on the propose path.

---

## (f) Pause switch on propose — VERIFIED: none

Inbox.sol:270: `function propose(bytes calldata _lookahead, bytes calldata _data) external nonReentrant {` — only `nonReentrant`; no `whenNotPaused`.
`EssentialContract` provides `whenNotPaused` (EssentialContract.sol:89-92, `_checkNotPaused` → `require(!paused(), INVALID_PAUSE_STATUS())` at 243-245) and public `pause()`/`unpause()` (150-164) but `Inbox` does not apply the modifier to `propose` or `prove` (Inbox.sol:321). `grep -n whenNotPaused Inbox.sol` → nothing.
The PDF's "propose has no whenNotPaused" (txt:187-188) is correct. **VERIFIED.**

Reentrancy: `nonReentrant` (EssentialContract.sol:75-80) reverts with `REENTRANT_CALL` (235-237). Relevant because `sendEtherAndVerify` calls out to `msg.sender` mid-propose; a re-entrant `propose` from the fee callback would hit `REENTRANT_CALL` (self-inflicted).

---

## (g) `_proposerChecker` — VERIFIED immutable; points to the PreconfWhitelist EIP-1967 proxy

- Declared `IProposerChecker internal immutable _proposerChecker;` (Inbox.sol:74-75); set once in the constructor (Inbox.sol:157) from `Config.proposerChecker`; must be non-zero (LibInboxSetup.sol:27 `require(_config.proposerChecker != address(0), ProposerCheckerZero());`). Exposed via `getConfig()` (Inbox.sol:531). **VERIFIED immutable.**
- Interface `IProposerChecker.checkProposer(address _proposer, bytes calldata _lookaheadData) external returns (uint48 endOfSubmissionWindowTimestamp_)` (IProposerChecker.sol:16-21); NatSpec: `@dev This function must revert if the address is not a valid proposer` (line 15); `error InvalidProposer();` (line 8). Note it is **not `view`** in the interface (the implementation is `view`).
- Only implementation in-repo: `PreconfWhitelist` (`packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol:14`, `contract PreconfWhitelist is EssentialContract, IPreconfWhitelist, IProposerChecker`). Its `checkProposer` (127-141):
  ```solidity
  address operator = _getOperatorForEpoch(epochStartTimestamp(0));
  require(operator != address(0), InvalidProposer());
  require(operator == _proposer, InvalidProposer());
  // Slashing is not enabled for whitelisted preconfers, so we return 0
  endOfSubmissionWindowTimestamp_ = 0;
  ```
  i.e. exactly one operator per epoch (selected from beacon-root randomness, 275-314); `_lookaheadData` is ignored. So today at most one address can propose in a given epoch, which matters for the frame-tx design: same-slot races between *different* proposers cannot currently happen through this checker; only the same operator racing itself. **VERIFIED.**
- Mainnet wiring: `DeployShastaContracts.s.sol:113-124` constructs `new MainnetInbox(proofVerifier, config.preconfWhitelist, proverWhitelist, config.l1SignalService, config.taikoToken)` and `DeployShastaMainnet.s.sol:22` sets `config.preconfWhitelist = LibL1Addrs.PRECONF_WHITELIST` = `0xFD019460881e6EeC632258222393d5821029b2ac` (LibL1Addrs.sol:38). The deployment log (`deployments/mainnet-contract-logs-L1.md:332-346`) lists `preconf_whitelist` proxy `0xFD0194…b2ac`, impl `0xDBae46E3…c149` (upgraded Mar 31 2026, Proposal0009), owner `controller.taiko.eth`, and shows it has been `upgradeTo`'d twice, i.e. it is an upgradeable (UUPS/EIP-1967) proxy. **VERIFIED from repo scripts/logs.**
- The Inbox proxy `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f`, current impl `0x5253D4C91e80b880DdB54B78E74082Abe066F6b9` (Unzen, Aug 3 2026, Proposal0019) (`mainnet-contract-logs-L1.md:213-222`). Proposal0019.md documents the new impl's changed immutable as `ZK_REQUIRED_VERIFIER` only (Proposal0019.md:91, 267-268); it does not restate the proposerChecker arg.
- **UNVERIFIED**: that the live impl `0x5253…F6b9`'s `getConfig().proposerChecker` actually equals `0xFD01…b2ac` on chain (no `cast`/RPC in this environment; `which cast forge` → nothing). Strongly implied by the scripts above.

The PDF's "_proposerChecker is immutable, but it points to an EIP-1967 proxy, so upgrading the checker to allow anyone is enough" (txt:226-227) is consistent with the above. **VERIFIED (modulo the on-chain read).**

---

## (h) Bond check on propose — VERIFIED: gated on `_minBond > 0`; mainnet/devnet minBond = 0

Inbox.sol:604-607:
```solidity
if (_minBond > 0) {
    // Only if there is a minimum bond set, execute this check
    require(_bondStorage.hasSufficientBond(msg.sender, _minBond), InsufficientBond());
}
```
`LibBonds.hasSufficientBond` (LibBonds.sol:130-141): `return bond_.balance >= _minBond && bond_.withdrawalRequestedAt == 0;`
`_minBond` is `uint64 internal immutable` (Inbox.sol:86-87), set at Inbox.sol:161.
- `MainnetInbox.sol:37`: `minBond: 0, // During prover whitelist, bonds are not necessary` and `livenessBond: 0` (line 38). **VERIFIED**: the mainnet build has minBond 0, so the `InsufficientBond` branch is dead code on mainnet. The PDF's "mainnet Shasta's minBond has been 0 since activation" (txt:228) is consistent with the source; whether it was 0 *since activation* (Mar 4 2026 impl `3c66b0f8d`) is **UNVERIFIED** (would need that commit's MainnetInbox.sol; shallow clone).
- `DevnetInbox.sol:36`: `minBond: 0` as well.
- The bond check is "triggerable by others" only in the weak sense that nobody else can lower your balance on the propose path (`settleLivenessBond` runs in `prove`, Inbox.sol:740-742, and only when `livenessBond`>0 and proof is late; mainnet livenessBond = 0). Withdrawal request is self-inflicted. Classified **self-inflicted** for mainnet (and dead code).

---

## Every revert on the propose path (Inbox.propose → _validateProposeInput → _buildProposal → _consumeForcedInclusions → _dequeueAndProcessForcedInclusions → LibBlobs.validateBlobReference → PreconfWhitelist.checkProposer)

| # | file:line | revert | condition | class |
|---|-----------|--------|-----------|-------|
| 1 | EssentialContract.sol:235-237 via `nonReentrant` (Inbox.sol:270) | `REENTRANT_CALL` | re-entering `propose` during the FI fee `call` | self-inflicted (only msg.sender's fallback can re-enter) |
| 2 | Inbox.sol:765 | `DeadlineExceeded` | `deadline != 0 && block.timestamp > deadline` | self-inflicted in isolation, **but the PDF's point holds**: on a shared-nonce path a proposer could deliberately set a past deadline to burn a nonce. In the direct path only the sender pays. |
| 3 | Inbox.sol:278 | `ActivationRequired` | `nextProposalId == 0` (not activated) | governance state; not per-tx triggerable |
| 4 | Inbox.sol:590 | `CannotProposeInCurrentBlock` | `block.number <= lastProposalBlockId` | **triggerable by others** (any earlier propose in the same L1 block) |
| 5 | Inbox.sol:591-593 | `NotEnoughCapacity` | `nextProposalId - lastFinalizedProposalId >= ringBufferSize` (mainnet 21_600, MainnetInbox.sol:18) | **triggerable by others** (provers stalling ~3 days; hits everyone equally) |
| 6 | Inbox.sol:662-664 | `UnprocessedForcedInclusionIsDue` | `numForcedInclusions < dueToProcess` | **triggerable by others** if the proposer requests < 10: a FI submitter can make entries become due. With clients sending 0xffff this cannot fire; with the PDF's proposed pin `numForcedInclusions == 0` under the *current* rule it would fire whenever any FI is due — hence the PDF's required rule change (txt:210-211). |
| 7 | Inbox.sol:710 → LibAddress.sol:54 | `ETH_TRANSFER_FAILED` | FI fee `call` to `msg.sender` fails (recipient reverts / OOG / is zero addr) | self-inflicted for an EOA; for a contract/7702 recipient, whoever controls the recipient's code. Only reachable when ≥1 FI is consumed, which **others** control by enqueueing FIs. |
| 8 | LibBlobs.sol:42 (from Inbox.sol:599) | `NoBlobs` | `blobReference.numBlobs == 0` | self-inflicted |
| 9 | LibBlobs.sol:47 (from Inbox.sol:599) | `BlobNotFound` | `blobhash(blobStartIndex + i) == 0` for any i (blob index beyond the tx's blobs, or non-blob tx) | self-inflicted (own tx's blob count / indices) |
| 10 | PreconfWhitelist.sol:137 (via Inbox.sol:603) | `InvalidProposer` | no operator for the current epoch | **triggerable by others** (whitelist owner removing operators; `operatorCount == 0`) |
| 11 | PreconfWhitelist.sol:138 (via Inbox.sol:603) | `InvalidProposer` | `msg.sender != operator for epoch` | self-inflicted for the wrong sender; but it is also the mechanism by which *another* proposer is excluded. For the frame-tx design, whether G's `_proposer` is the epoch operator is decided by the checker, not by G. |
| 12 | Inbox.sol:606 | `InsufficientBond` | `_minBond > 0 && !(balance >= minBond && withdrawalRequestedAt == 0)` | self-inflicted; **dead on mainnet/devnet (minBond = 0)** |
| 13 | LibBlobs.sol:46-47 | (implicit) `blobhash(...)` with `blobStartIndex + i` in `unchecked`? | `blobStartIndex + i` is a uint16 + uint256 → uint256 add, no overflow issue; noted only to record it was checked | n/a |
| 14 | Inbox.sol:286 `_setProposalHash` / 288 `_emitProposedEvent` | none | no reverts | n/a |

Arithmetic reverts: `propose` and `_buildProposal`/`_consumeForcedInclusions` are inside `unchecked` blocks (Inbox.sol:271, 587, 644, 696), so there are no checked-arithmetic panics on this path. `LibCodec.decodeProposeInput` has no reverts (LibCodec.sol:32-43). `_validateProposeInput` has only #2.

Not on the propose path (for completeness): `ProverNotWhitelisted`, `ParentBlockHashMismatch`, `LastProposalHashMismatch`, `EmptyBatch`, `First/LastProposalIdTooLarge`, `LastProposalAlreadyFinalized` (prove); `IncorrectProposalCount`, `InsufficientFee`, `OnlySingleBlobAllowed`, `InvalidFeeDoubleThreshold` (saveForcedInclusion); `InvalidRecoveryState` (init2).

**PDF check (txt:288-290)**: "after the §1.3 changes and G's pins on deadline and numForcedInclusions, the only reverts others can still trigger are a full ring buffer and n+1 in the same block". Against the table: with deadline pinned to 0 (#2 gone), FI rule changed to auto-process due entries (#6 gone), fees made pull-based (#7 gone), bond check skipped on the G path (#12 gone), and the checker opened to anyone (#10/#11 gone), the remaining other-triggerable reverts are indeed #4 and #5. **VERIFIED as a consistent derivation from current code** (the §1.3 changes themselves are proposals, not code).

---

## Other Taiko-side facts a frame-transaction gate would depend on

- **Storage layout** (`MainnetInbox_Layout.sol:21-26`): `activationTimestamp` slot 251, `_coreState` 252-253, `_proposalHashes` 254, `_forcedInclusionStorage` 255-256, `_bondStorage` 257, `__gap uint256[43]` at **slot 258**. Inbox.sol:145 `uint256[43] private __gap;`. The PDF's "append a mapping at slot 258, shrink __gap from 43 to 42" (txt:218-219) is exactly right. **VERIFIED.**
- **Reinitializer**: `init2` uses `reinitializer(2)` (Inbox.sol:223), `init3` uses `reinitializer(3)` (Inbox.sol:253, called on mainnet Aug 3 2026 per log line 222). So the next one is 4, as the PDF says (txt:219). **VERIFIED.**
- **Proposal struct / Proposed event** (IInbox.sol:60-79, 169-176): `proposer` is a plain `address` field/indexed topic. A `proposeFor(_proposer, …)` that fills `proposer` from calldata would leave both unchanged, as the PDF claims (txt:207-208). **VERIFIED (shape).**
- **ProposeInput NatSpec on deadline**: "(0 = no deadline)" (IInbox.sol:101). G's `deadline == 0` pin therefore maps to "no Inbox-side time bound". **VERIFIED.**
- **Origin block**: `_buildProposal` uses `block.number - 1` and `blockhash(parentBlockNumber)` (Inbox.sol:609-618); L1 reorgs change `originBlockHash` without changing the id — the PDF's motivation for an `expectedParentProposalHash` (txt:224-225) has a concrete field to bind to (`parentProposalHash: getProposalHash(_nextProposalId - 1)`, Inbox.sol:616).
- **Timestamps**: `Proposal.timestamp = uint48(block.timestamp)` (Inbox.sol:613); FI `blobSlice.timestamp` is set at enqueue time (LibBlobs.sol:53 via LibForcedInclusion.sol:51).
- **saveForcedInclusion is permissionless and payable** (Inbox.sol:431-443; fee = base × (threshold + pending)/threshold, LibForcedInclusion.sol:89-93; mainnet base 0.001 ETH, doubles at 50 pending, MainnetInbox.sol:48-49). This is the lever behind "anyone can stuff FIs into someone else's proposal" — cost to the attacker is ≥0.001 ETH per entry, refunded to nobody (fee goes to whichever proposer consumes it).
- **Ring buffer**: `_ringBufferSize` mainnet 21_600 (MainnetInbox.sol:15-18, "3 days at 1 proposal per L1 slot").
- **No `proposeFor`, `_proposalGate`, `_directProposeDisabled`, `NotProposalGate`, `DirectProposeDisabled`** exist in the current code (grep over `packages/protocol/contracts` → nothing). All of §1.3 is proposed, not present. **VERIFIED (absent).**

---

## The three cited PRs (GitHub API via github MCP, fetched 2026-09-30; not in the shallow local history — `git log --all --grep` for #18570/#20186/#19488 returned nothing)

### PR #18570 — "feat(protocol): propose a batch blocks conditionally" — VERIFIED
- https://github.com/taikoxyz/taiko-mono/pull/18570 — merged 2024-12-16 by YoGhurt111, base `main`, 10 files, +62/-33.
- Diff (get_diff): in the **Ontake-era `ProverSet.sol`** it renamed `proposeBlockV2Conditionally(bytes,bytes)` → `proposeBlocksV2Conditionally(bytes[],bytes[])`, keeping the guard
  `require(taiko.lastProposedIn() != block.number, NOT_FIRST_PROPOSAL());` before calling `taiko.proposeBlocksV2(...)`; added a `--revertProtection` / `REVERT_PROTECTION` flag to the Go proposer (`cmd/flags/proposer.go`, `proposer/config.go`) and made the blob/calldata builders pack `proposeBlocksV2Conditionally` when the flag is on.
- So "conditional propose" = an **application-level, opt-in, wrapper-contract** guard: land-and-revert with `NOT_FIRST_PROPOSAL` if someone else proposed first in the block. This is the pre-Shasta ancestor of the PDF's "2025 guard era" and of the current in-Inbox `CannotProposeInCurrentBlock`. The PDF's characterization "Today's application-level guard plus private, revert-protected builder submission is only builder policy" (txt:271-272) is consistent with this being a flag + a revert, not a protocol rule.

### PR #20186 — "feat(protocol): propose function can only be called once per Ethereum block" — VERIFIED
- https://github.com/taikoxyz/taiko-mono/pull/20186 — merged 2025-09-19 by dantaik, milestone "Shasta Hard Fork (v5)", 27 files, +687/-417.
- Body: "Fix Inbox vulnerability where malicious preconfers could deplete Inbox's ring buffer by proposing may proposals. Now a preconfer can only call the `propose` function once per L1 block."
- Diff lines (from get_files patch): added `uint48 nextProposalBlockId;` to `CoreState` (then at `contracts/layer1/shasta/iface/IInbox.sol`), `require(block.number >= _input.coreState.nextProposalBlockId, CannotProposeInCurrentBlock());`, `coreState.nextProposalBlockId = uint48(block.number + 1);`, initial `nextProposalBlockId = 2` "to ensure the first proposal happens at block 2 or later", and `error CannotProposeInCurrentBlock();`.
- Current code is the same rule renamed: `lastProposalBlockId` with `block.number > lastProposalBlockId` (Inbox.sol:590) and seeded to 1 (LibInboxSetup.sol:84). The PDF's "spam is bounded by one proposal per block (PR #20186)" (txt:229) is correct.

### PR #19488 — "feat(protocol): add optional lastBlockId check in PreconfRouter" — VERIFIED
- https://github.com/taikoxyz/taiko-mono/pull/19488 — merged 2025-05-19 by cyberhorsey, author merklefruit (chainbound), base branch `preconf_configs_4` (a preconf devnet branch, **not main**), 1 file, +19.
- Body: "Supersedes #19471 … The approach using parentMetaHash ended up not working because it requires knowing the `block.timestamp` of when the transaction will land in a block, which makes it unreliable."
- Diff: added to Pacaya-era `PreconfRouter.sol` `error InvalidLastBlockId(uint96 _actual, uint96 _expected);` and `proposeBatchWithExpectedLastBlockId(bytes _params, bytes _txList, uint96 _expectedLastBlockId)` which calls `this.proposeBatch(...)` then `require(info_.lastBlockId == _expectedLastBlockId, InvalidLastBlockId(...))`.
- Lesson the PDF draws ("lessons from parentMetaHash", txt:311-312): binding to a hash that includes the landing timestamp is unreliable; binding to an **expected id** is what worked. This is the precedent for the PDF's `expectedProposalId` (an id, not a hash) and for treating `expectedParentProposalHash` as an *optional extra*. Consistent. Note the merged code binds `lastBlockId` post-hoc after the call, i.e. it still lands-and-reverts.

---

## UNVERIFIED items (explicitly not checked in this report)

1. All EIP-8141 / EIP-8038 / EIP-2780 / EIP-8250 / EIP-7732 semantics, opcode numbers (`0xaa`, `0xb0–0xb5`, `TXPARAM`/`FRAMEPARAM`/`SIGPARAM` indices), `EXPIRY_VERIFIER = 0x8141`, `MAX_VERIFY_GAS = 100k`, EIPs PRs #12252 / #12198, commit `b75cbe6115`, and reth/geth/Nethermind mempool behaviour cited in the PDF — out of scope for this Taiko-side report; require primary-source fetches (eips.ethereum.org / github.com/ethereum/EIPs / client repos).
2. Gas numbers in the PDF (30,944; 75,594; 76,485; 100,517; 218,805; "+13.5k / +18%") — not re-measured.
3. "mainnet Shasta's minBond has been 0 **since activation**" — current source says 0; historical value at commit `3c66b0f8d` (Mar 4 2026) not checked (shallow clone).
4. On-chain `getConfig().proposerChecker` of impl `0x5253D4C91e80b880DdB54B78E74082Abe066F6b9` — no RPC/`cast` here; inferred from `DeployShastaContracts.s.sol` + `LibL1Addrs.PRECONF_WHITELIST`.
5. The derivation-side "1 second per forced-inclusion block" timestamp rule and the "default manifest containing only the anchor" fallback — lives in client/derivation code, not in the five contract files in scope.
6. The PDF's on-chain sampling figures ("0.002 losers per proposal", "34%/38% blob-fee share in 2024-11 / 2025-02").
7. PR #18570's body text was not returned by the API (only title/metadata/diff); the summary above is from the diff.

## Sources
- packages/protocol/docs/Etna/inputs/nonce-as-a-lock.txt (read 2026-09-30)
- packages/protocol/contracts/layer1/core/impl/Inbox.sol
- packages/protocol/contracts/layer1/core/libs/LibCodec.sol
- packages/protocol/contracts/layer1/core/libs/LibForcedInclusion.sol
- packages/protocol/contracts/layer1/core/libs/LibBlobs.sol
- packages/protocol/contracts/layer1/core/libs/LibBonds.sol
- packages/protocol/contracts/layer1/core/libs/LibPackUnpack.sol
- packages/protocol/contracts/layer1/core/libs/LibInboxSetup.sol
- packages/protocol/contracts/layer1/core/iface/IInbox.sol
- packages/protocol/contracts/layer1/core/iface/IProposerChecker.sol
- packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol
- packages/protocol/contracts/layer1/mainnet/MainnetInbox.sol, MainnetInbox_Layout.sol, LibL1Addrs.sol
- packages/protocol/contracts/layer1/devnet/DevnetInbox.sol
- packages/protocol/contracts/shared/libs/LibAddress.sol
- packages/protocol/contracts/shared/common/EssentialContract.sol
- packages/protocol/script/layer1/core/DeployShastaContracts.s.sol, DeployShastaMainnet.s.sol
- packages/protocol/script/layer1/proposals/Proposal0017.md, Proposal0019.md
- packages/protocol/deployments/mainnet-contract-logs-L1.md
- packages/taiko-client/proposer/transaction_builder/blob.go
- packages/taiko-client-rs/crates/proposer/src/transaction_builder.rs
- https://github.com/taikoxyz/taiko-mono/pull/18570 (GitHub API, 2026-09-30)
- https://github.com/taikoxyz/taiko-mono/pull/20186 (GitHub API, 2026-09-30)
- https://github.com/taikoxyz/taiko-mono/pull/19488 (GitHub API, 2026-09-30)
