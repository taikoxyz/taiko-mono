# CLAIM adapter schema v1 (frozen shared interface)

Input: UTF-8 JSONL, one isolated fixture per row (`corpus/claim.jsonl`). The file staged for
Foundry is a JSON array of those exact rows. Every row deploys a fresh actual `L2FeeVault`
and installs the canonical EIP-4788 runtime (the bytes `build_etna_genesis.py` installs; its
SHA-256 is asserted). uint64 fields are JSON integers; uint256 fields are decimal strings.
`claim_conformance.py` rejects missing, extra or out-of-range fields; there are no defaults.

Required fields:

- `schemaVersion: 1`, unique nonempty `id`.
- `vault`: `l1ChainId` (decimal, nonzero), `chainId` (uint64, set with `vm.chainId`),
  `inbox` (nonzero address), `balanceWei` (decimal, set with `vm.deal`), `entered` (bool).
  `entered: true` stores 1 in the vault's slot 0 (`_entered`) after any prior claim.
- `receipt`: the `LibEtnaRewards.Receipt` passed to `claim`, with fields `l1ChainId`,
  `l2ChainId`, `inbox`, `generation`, `parentHeight`, `parentHash`, `lastHeight`,
  `lastBlockHash`, `l2RewardRecipient`, `baseFeeAmount`.
- `ledger`: the L1 state the anchored root commits to. `account`'s storage holds
  `commitment(ledger.receipt)` at `keccak256(abi.encode(batchId(ledger.receipt), mappingSlot))`.
  `EtnaRewardProof._proof` builds the single-leaf account and storage proof for it; the
  test base's `EtnaVaultProof` supplies the independent `batchId`/`commitment` encodings.
- `accountProof`, `storageProof`: `valid`, `empty` (no nodes) or `corrupt` (last byte of the
  only node flipped after the root was computed).
- `root`: what the EIP-4788 contract holds for `anchorTimestamp`. `published` is the proof's
  state root; `storage-root` is the ledger account's storage root (LibTrieProof's storage-root
  mode); `missing` writes nothing (the real contract reverts); `expired` publishes the root and
  then a later root one ring length (8191) later; `zero` and `other` store `0` and `123`.
- `anchorTimestamp`: nonzero uint64 passed to `claim`.
- `recipient`: `eoa` (no code), `rejecting` or `reentrant`. The contract modes etch the test
  base's `EtnaClaimReceiver` at the receipt recipient. `rejecting` reverts on receipt;
  `reentrant` calls `claim` again with `reentry`, catches the result and accepts the value.
- `caller`: the `msg.sender` of the observed call; distinct from every recipient.

Optional fields (absent means none):

- `prior`: `{receipt, anchorTimestamp}`. A claim with its own intact proof and published root
  runs first and must succeed. It pays an EOA.
- `reentry`: `{receipt, anchorTimestamp}`, required exactly when `recipient` is `reentrant`.
  Its root is published as for `prior`.

Each root occupies one ring slot (`timestamp % 8191`). Only an identical same-receipt nested
claim may share the observed claim's slot; `expired` reuses it deliberately.

Output (`CLAIM_OBSERVATION` lines, one JSON object per row), compared with Lean:

`status` (`ok`/`revert`); `error`: `none`, `reentrant`, `invalid-receipt`,
`empty-account-proof`, `already-claimed`, `invalid-anchor-root`, `proof`, `transfer`. `proof`
is any LibTrieProof, SecureMerkleTrie (`MerkleTrie: ` reason) or RLPReader rejection; another
selector fails the harness. Committed state: `batchId` (from the test base's independent
encoding), `claimed`, `paidTo`/`paidWei` (committed value calls by the vault),
`vaultBalanceWei`, `rewardEvents` and the last event's `eventBatchId`, `eventRecipient`,
`eventAmount` (zero after a revert). Executed in the observed call, including nested frames
and failed calls: `rootQueries` (vault STATICCALLs to the roots contract) and
`recipientCalls` (vault CALLs). `nestedResult` is `none` when no re-entry ran, else the nested
call's error name or `ok`. `priorClaimed` echoes `prior`.

Lean side: `Check/Claim.lean` builds the vault and `ClaimCall` from the row. The Keccak oracle
maps exact preimages to the driver's `cast keccak` digests; a preimage it does not hold is an
error. `proofAccepted` holds when the storage proof is intact, the mapping slot is 283 and the
ledger receipt has the claimed receipt's batch id and commitment, with either an intact
account proof of the vault's Inbox against a `published` root, or no account proof against a
`storage-root` root. `rootAvailable` is `published`, `storage-root` or `other`. `transferOk`
is a non-rejecting recipient and an amount within the balance. A re-entry runs the model on the
locked vault. The driver also checks Lean's batch-id and commitment preimages against its own
encoding and the actual `batchId`.

Harness-only assertions, checked on the actual result from row inputs: a revert leaves the
flag and every balance unchanged. A success needs an unclaimed batch, the configured identity,
a nonempty account proof, a published root and the anchored commitment. It pays exactly the
receipt, makes one call (none for a zero amount) and emits one event. Its callback sees the
flag already set, and a re-entry hits the guard.
