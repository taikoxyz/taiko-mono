# Client mempool / builder behaviour relevant to a same-nonce race design

Date of research: 2026-09-30. Every claim below is tagged **VERIFIED** (primary source fetched on 2026-09-30, URL given) or **UNVERIFIED** (could not be confirmed from a primary source; treat as an assumption). Quotes are verbatim from the fetched source unless marked as paraphrase.

Fetch failures recorded: `raw.githubusercontent.com/ethereum/consensus-specs/dev/specs/gloas/*.md` returned 404 (the `dev` branch path does not exist); the same files on `master` were fetched successfully. `flashbots.github.io/relay-specs/` returned an empty page to the fetcher (no quotable content); the relay README and the flashbots/builder validation code were used instead.

---

## 1. Same-nonce replacement rules (geth, reth, Nethermind)

### 1a. geth legacy pool (non-blob txs: legacy, access-list, 1559, 7702 set-code)

- **VERIFIED** Default `PriceBump` is **10 (%)**. `DefaultConfig = Config{ ... PriceLimit: 1, PriceBump: 10, AccountSlots: 16, GlobalSlots: 4096 + 1024, AccountQueue: 64, GlobalQueue: 1024, Lifetime: 3 * time.Hour }`; field comment: "Minimum price bump percentage to replace an already existing transaction (nonce)".
  Source: https://raw.githubusercontent.com/ethereum/go-ethereum/master/core/txpool/legacypool/legacypool.go (fetched 2026-09-30)
- **VERIFIED** Replacement requires **both** `GasFeeCap` and `GasTipCap` of the new tx to be >= old * (100+bump)/100, and strictly greater than the old values (`list.Add`):
  ```go
  if old.GasFeeCapCmp(tx) >= 0 || old.GasTipCapCmp(tx) >= 0 { return false, nil }
  a := big.NewInt(100 + int64(priceBump))
  aFeeCap := new(big.Int).Mul(a, old.GasFeeCap()); aTip := a.Mul(a, old.GasTipCap())
  b := big.NewInt(100)
  thresholdFeeCap := aFeeCap.Div(aFeeCap, b); thresholdTip := aTip.Div(aTip, b)
  if tx.GasFeeCapIntCmp(thresholdFeeCap) < 0 || tx.GasTipCapIntCmp(thresholdTip) < 0 { return false, nil }
  ```
  Failure surfaces as `txpool.ErrReplaceUnderpriced` in `LegacyPool.add()`: `inserted, old := list.Add(tx, pool.config.PriceBump); if !inserted { ... return false, txpool.ErrReplaceUnderpriced }`.
  Sources: https://raw.githubusercontent.com/ethereum/go-ethereum/master/core/txpool/legacypool/list.go and .../legacypool.go (fetched 2026-09-30)
- **VERIFIED** The legacy pool contains no blob txs: `Pending()` — "If only blob transactions are requested, this pool is unsuitable as it contains none, don't even bother." Source: legacypool.go above.
- **VERIFIED** Cross-subpool exclusivity: geth's `ReservationTracker` "is used to reserve the account and ensure that one address cannot initiate transactions, authorizations, and other state-changing behaviors in different pools at the same time"; `Hold` "Returns an error if the account is already reserved" (`ErrAlreadyReserved`). So a sender cannot have a blob tx in the blob pool and a non-blob tx in the legacy pool simultaneously (a same-nonce non-blob tx cannot replace a pooled blob tx, and vice versa).
  Source: https://raw.githubusercontent.com/ethereum/go-ethereum/master/core/txpool/reserver.go (fetched 2026-09-30)

### 1b. geth blob pool (EIP-4844 type-3 txs)

- **VERIFIED** Default `PriceBump` is **100 (%)**: `DefaultConfig` has `Datadir: "blobpool"`, `Datacap: 10 * 1024 * 1024 * 1024 / 4`, `PriceBump: 100`, `BlockedRatio: 0.5`; field comment "Minimum price bump percentage to replace an already existing nonce".
  Source: https://raw.githubusercontent.com/ethereum/go-ethereum/master/core/txpool/blobpool/config.go (fetched 2026-09-30)
- **VERIFIED** All three fee fields must be bumped — exec fee cap, exec tip cap **and blob fee cap**:
  ```go
  multiplier   = uint256.NewInt(100 + p.config.PriceBump)
  onehundred   = uint256.NewInt(100)
  minGasFeeCap     = Div(Mul(multiplier, prev.execFeeCap), onehundred)
  minGasTipCap     = Div(Mul(multiplier, prev.execTipCap), onehundred)
  minBlobGasFeeCap = Div(Mul(multiplier, prev.blobFeeCap), onehundred)
  ```
  with errors of the form `"%w: new tx gas fee cap %v < %v queued + %d%% replacement penalty"` wrapping `txpool.ErrReplaceUnderpriced`. Rationale comment in the file: "Replacements are expensive. Given their size, propagating a replacement blob transaction to an existing one should be aggressively discouraged. Whilst generic transactions can start at 1 Wei gas cost and require a 10% fee bump to replace, we suggest requiring a higher min cost (e.g. 1 gwei) and a more aggressive bump (100%)."
  Source: https://raw.githubusercontent.com/ethereum/go-ethereum/master/core/txpool/blobpool/blobpool.go (fetched 2026-09-30)
- **VERIFIED** Per-account cap `maxTxsPerAccount = 16` — "The limit is enforced to minimize the DoS potential of a private tx cancelling publicly propagated blobs." Accounts with a (pending) 7702 delegation are limited to "at most one in-flight executable transaction, e.g. disallow stacked and gapped transactions from the account." Source: blobpool.go above.

### 1c. reth (`crates/transaction-pool`)

- **VERIFIED** Constants in `config.rs`:
  ```rust
  pub const DEFAULT_PRICE_BUMP: u128 = 10;          // "Default price bump (in %) for the transaction pool underpriced check."
  pub const REPLACE_BLOB_PRICE_BUMP: u128 = 100;    // "This enforces that a blob transaction requires a 100% price bump to be replaced"
  pub const TXPOOL_MAX_ACCOUNT_SLOTS_PER_SENDER: usize = 16; // "Guarantees max transactions for one sender, compatible with geth/erigon"
  pub struct PriceBumpConfig { pub default_price_bump: u128, pub replace_blob_tx_price_bump: u128 }
  impl Default for PriceBumpConfig { fn default() -> Self { Self { default_price_bump: DEFAULT_PRICE_BUMP, replace_blob_tx_price_bump: REPLACE_BLOB_PRICE_BUMP } } }
  ```
  Source: https://raw.githubusercontent.com/paradigmxyz/reth/main/crates/transaction-pool/src/config.rs (fetched 2026-09-30)
- **VERIFIED** In `pool/txpool.rs` the replacement check is `existing_transaction.is_replacement_underpriced(maybe_replacement, &self.price_bumps)` → error `ReplacementUnderpriced`; the new tx must exceed the existing `max_fee_per_gas`, priority fee and `max_fee_per_blob_gas` by the configured bump. Type exclusivity: "blob vs non blob transactions are mutually exclusive for the same sender" → `TxTypeConflict`.
  Source: https://raw.githubusercontent.com/paradigmxyz/reth/main/crates/transaction-pool/src/pool/txpool.rs (fetched 2026-09-30)

### 1d. Nethermind

- **VERIFIED** Non-blob replacement bump is **10%**: `private const ulong PartOfFeeRequiredToIncrease = 10;` with comment "To replace old transaction, new transaction needs to have fee higher by at least 10% (1/10) of current fee." Computation: `bumpMaxFeePerGas = oldTx.MaxFeePerGas / PartOfFeeRequiredToIncrease; bumpMaxPriorityFeePerGas = oldTx.MaxPriorityFeePerGas / PartOfFeeRequiredToIncrease;` (legacy: `bumpGasPrice = oldTx.GasPrice / PartOfFeeRequiredToIncrease`). Rejection result: `AcceptTxResult.ReplacementNotAllowed` ("Transaction is not allowed to replace the one already in the pool. Fee bump is too low or some requirements are not fulfilled", message `ReplacementTransactionUnderpriced`).
  Sources: https://raw.githubusercontent.com/NethermindEth/nethermind/master/src/Nethermind/Nethermind.TxPool/Comparison/CompareReplacedTxByFee.cs ; https://github.com/NethermindEth/nethermind/blob/master/src/Nethermind/Nethermind.TxPool/AcceptTxResult.cs (fetched 2026-09-30)
- **VERIFIED** Blob replacement requires **2x (100%)** on all of `MaxFeePerGas`, `MaxPriorityFeePerGas`, `MaxFeePerBlobGas`: "To replace old blob transaction, new transaction needs to have fee at least 2x higher than current fee. 2x higher must be MaxPriorityFeePerGas, MaxFeePerGas and MaxFeePerDataGas"; `if (oldTx.MaxFeePerBlobGas * 2 > newTx.MaxFeePerBlobGas) return KeepOld`. Additionally a replacement with fewer blob versioned hashes is rejected, and a replacement with a newer network-wrapper version is always allowed.
  Source: https://raw.githubusercontent.com/NethermindEth/nethermind/master/src/Nethermind/Nethermind.TxPool/Comparison/CompareReplacedBlobTx.cs (fetched 2026-09-30)

### 1e. Summary table

| Client | Non-blob bump | Blob bump | Which fields | Cross-type same-nonce |
|---|---|---|---|---|
| geth | 10% | 100% | feeCap + tip (+ blobFeeCap for blob) | blocked by account reservation (ErrAlreadyReserved) |
| reth | 10% | 100% | max_fee, priority_fee, max_fee_per_blob_gas | `TxTypeConflict` |
| Nethermind | 10% | 100% (2x) | MaxFee, MaxPriority, MaxFeePerBlobGas | not checked in this research (UNVERIFIED) |

---

## 2. "One pending transaction per sender" — EIP-8141 frame transactions, implementation status as of 2026-09-30

### 2a. What the EIP text says

- **VERIFIED** EIP-8141 "Frame Transaction", Status: **Draft**, Standards Track: Core, Created 2026-01-29, tx type `0x06`. Authors: Vitalik Buterin, lightclient, Felix Lange, Yoav Weiss, Alex Forshtat, Dror Tirosh, Shahaf Nacson, Derek Chiang, Toni Wahrstätter, Stavros Vlachakis. Requires EIP-1559, 2718, 2780, 3529, 3607, 4844, 7594, 7702, 7708, 7778, 7825, 7976, 8037.
- **VERIFIED** Mempool rule: "A node should keep at most one pending frame transaction per sender in the public mempool. A new transaction from the same sender MAY replace the existing one only if it uses the same nonce and satisfies the replacement rules below." And: "Pending frame transactions are identified by `(sender, nonce)`. The sender's nonce is consumed exactly once per transaction when payment is approved, so two pending transactions sharing it are alternatives, of which at most one can ever be included."
- **VERIFIED** Replacement: "A replacement must be valid under all rules in this section and should only be accepted and propagated if it increases both `max_fee_per_gas` and `max_priority_fee_per_gas` by at least a node-configured minimum increment (10% is the conventional default)." "A blob-carrying frame transaction additionally follows the blob pool's replacement conventions for `max_fee_per_blob_gas`." "A replacement may name a different payer than the transaction it replaces. The node should release the reservation or exposure held for the old payer and shift it to the new payer atomically with the replacement."
- **VERIFIED** Nonce semantics: "Ensure `tx.nonce == state[tx.sender].nonce`" at tx start; the nonce is incremented when `APPROVE` executes: "Increment the sender's nonce, set `payer = resolved_target`, and collect the transaction's `max_cost` from `payer`."
- **VERIFIED** Eviction / revalidation: "A block producer SHOULD bound the unpaid validation work it spends on any one pending frame transaction: after a bounded number of consecutive block-building attempts in which the transaction's validation prefix fails to approve, the producer MAY evict it." "When a new canonical block is accepted, the node removes any included frame transactions from the public mempool, updates paymaster reservations accordingly, and identifies the remaining pending transactions whose tracked dependencies were touched by the block... The node then re-simulates the validation prefix of only those affected transactions against the new head and evicts any transaction that no longer satisfies the public mempool rules."
  Sources: https://eips.ethereum.org/EIPS/eip-8141 and https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md (fetched 2026-09-30)
- **VERIFIED** EIP-8250 "Keyed Nonces for Frame Transactions" (Draft, created 2026-04-16, requires 7623/8037/8141) "preserves EIP-8141's limit of one pending frame transaction per sender in the public mempool" while replacing the pending-tx identity with `(sender, nonce_keys, nonce_seq)`. Source: https://eips.ethereum.org/EIPS/eip-8250 (fetched 2026-09-30)

### 2b. go-ethereum

- **VERIFIED** No frame-tx support on `master` yet. PR #35666 "core: implement eip-8141 frames tx" (lightclient) is an **open draft** against `master`, described as "Still WIP"; its commit `a00d0f1` notes frame txs "were previously rejected at submission with 'transaction type not supported'" and the update "Accept[s] type 6 in the legacy pool once Bogota is active". Source: https://github.com/ethereum/go-ethereum/pull/35666 (fetched 2026-09-30)
- **VERIFIED** A devnet branch `frames-devnet-0` exists; its `legacypool.go` merely lists `types.FrameTxType` among accepted types (`FilterType` and `ValidateTxBasics` Accept mask) with **no** per-sender limit, replacement, or revalidation logic specific to frame txs. Source: https://raw.githubusercontent.com/ethereum/go-ethereum/frames-devnet-0/core/txpool/legacypool/legacypool.go (fetched 2026-09-30)
- **VERIFIED** PR #35814 "core, core/txpool: enforce the eip-8141 public mempool policy for frame transactions" (AnkushinDaniil, base `frames-devnet-0`) proposed "One pending frame transaction per sender (new `ErrFrameTxSenderPending`, same-nonce replacement still works)", "On every new head all pooled frame transactions are validated again and the ones that fail are removed", and a `MAX_PENDING_TXS_USING_NON_CANONICAL_PAYMASTER` cap — but it was **closed without merging on 2026-09-29**. Source: https://github.com/ethereum/go-ethereum/pull/35814 (fetched 2026-09-30)
- Other geth frame-tx PRs found (search 2026-09-30): #33954 "core: (Draft) Implement frame Txn 8141" (closed), #35810/#35811/#35812/#35815/#35816 (tracing, receipts, blob-carrying frame txs; closed 2026-09-27..29), #35831/#35832 (open, RPC). Source: https://github.com/ethereum/go-ethereum/pulls?q=8141
- **Conclusion (geth): no "one pending frame tx per sender" enforcement exists in any geth branch found; the one PR that added it was closed unmerged.** (VERIFIED as of 2026-09-30)

### 2c. reth

- **VERIFIED** PR #27154 "DNM: feat: add EIP-8141 frame transaction support (#27153)" (mattsse) is an **open draft** against `main`, no description. PRs #27363 "feat(rpc): support frame transaction RPCs" and #27430 "feat: frame tx rpcs" are closed (merged per commit references inside #27154). Source: https://github.com/paradigmxyz/reth/pull/27154 (fetched 2026-09-30)
- **VERIFIED** GitHub code search on 2026-09-30 for `frame` in `paradigmxyz/reth path:crates/transaction-pool` and `FrameTx` repo-wide returned **0 results** on the default branch — the reth pool has no frame-tx-specific logic (and therefore no one-per-sender rule) on `main`. Source: GitHub code search (`frame repo:paradigmxyz/reth path:crates/transaction-pool`, `FrameTx repo:paradigmxyz/reth`).
- reth PR #27528 "feat: implement eip-8250 keyed nonces" is open (created 2026-09-29). Source: https://github.com/paradigmxyz/reth/pull/27528

### 2d. Nethermind

- **VERIFIED** Nethermind has by far the most EIP-8141 mempool work (373 PR search hits for "8141 / frame transaction"). A devnet branch `eip8141-frame-txs-devnet7` is the integration target. Merged pieces include: #12617 "EIP-8141: per-payer mempool exposure accounting for frame transactions" (merged 2026-08-14 into `eip8141-frame-txs-devnet7`; rejects a frame tx when "reserved + max_cost > balance" for the payer, explicitly deferring "replacement payer-switch atomicity, eviction ordering, dependency-indexed revalidation"); #12620 (MAX_VERIFY_GAS admission bound); #13058 (MAX_VERIFY_GAS 300k→100k, merged); #13283 "correct four frame transaction admission and selection bounds" (closed; adds per-sender pending count bound for keyed txs, notes `MaxPendingTxsPerSender` default `0` = no limit); #13377 "tie the frame-tx eviction retry ledger to pool membership" (closed 2026-09-11). Sources: https://github.com/NethermindEth/nethermind/pull/12617 ; https://github.com/NethermindEth/nethermind/pull/13283 ; https://github.com/NethermindEth/nethermind/pulls?q=8141 (fetched 2026-09-30)
- **VERIFIED** Nethermind test PR #13044 states the keyed-nonce lane "admits at most one transaction per key per block through the public mempool. This matches EIP-8250, which preserves EIP-8141's one-pending-frame-transaction-per-sender guidance". Source: https://github.com/NethermindEth/nethermind/pull/13044 (fetched 2026-09-30)
- **UNVERIFIED** Whether Nethermind's pool literally enforces "at most one pending frame tx per sender" (as opposed to per-payer exposure + keyed-nonce bounds). A fetch of `master` `TxPool.cs` found frame-tx dependency tracking (`_frameDependencies.Set(...)`) but the summariser reported no explicit one-per-sender gate; PR #13619 (open) describes "the one EIP-8141 baseline pending transaction" that a sender may keep, implying such a baseline exists on the devnet branch, but I could not quote the enforcing code.

### 2e. ethereumjs

- **VERIFIED (negative)** GitHub PR search for "8141 / frame transaction" in `ethereumjs/ethereumjs-monorepo` returned only unrelated results (EIP-8037, Amsterdam gas schedule); code search for `8141` returned only chain/test-data files; issue search found no EIP-8141 tracking issue. **No EIP-8141 implementation found in ethereumjs as of 2026-09-30.** Source: GitHub search (repo:ethereumjs/ethereumjs-monorepo).

### 2f. EELS / execution-specs

- **VERIFIED** PR #3047 "Frame Transactions (EIP-8141)" (SamWilsn) **merged 2026-08-13** into branch `eips/amsterdam/eip-8141`; followed by #3114 "feat(specs): implement frame tx", #3396 "update EIP-8141 implementation", and many test PRs (#3443, #3487, #3500, #3523, #3539). EELS models block/state transition only; it has no mempool, so it does not implement the one-per-sender rule (which is a networking/mempool "should" in the EIP). Source: https://github.com/ethereum/execution-specs/pull/3047 ; https://github.com/ethereum/execution-specs/pulls?q=8141 (fetched 2026-09-30)

### 2g. Other contract-sender schemes

- **VERIFIED** geth blobpool restricts 7702-delegated accounts to "at most one in-flight executable transaction" (see 1b). This is the only existing "one pending tx per sender" rule found in a shipped client pool; it applies to blob txs from delegated EOAs, not to contract senders generally.

---

## 3. Revalidation after a new block: nonce-too-low eviction

- **VERIFIED (geth legacy pool)** On every head change `reset()` → `demoteUnexecutables()` / `promoteExecutables()` call `list.Forward(nonce)` — "Forward removes all transactions from the list with a nonce lower than the provided threshold. Every removed transaction is returned for any post-removal maintenance." The caller comment: "Drop all transactions that are deemed too old (low nonce)"; removed txs are deleted from `pool.all` (`log.Trace("Removed old pending transaction", ...)`). Stale-nonce txs are **dropped**, not kept. Sources: legacypool.go and list.go (URLs in §1a; fetched 2026-09-30)
- **VERIFIED (geth blob pool)** `recheck()` — "If there is overlap between the chain state and the blob pool, drop anything below the current state": `for len(txs) > 0 && txs[0].nonce < next { ... p.offload(...) ...; txs = txs[1:] }` then `log.Trace("Dropping overlapped blob transactions", ...)`. Dropped. Source: blobpool.go (URL in §1b)
- **VERIFIED (reth)** `on_canonical_state_change` "(1) removes mined transactions by hash, (2) updates fees ... (3) applies account updates ... (4) processes fee-based promotions"; in `update_txs`: "discard all transactions with a nonce lower than the current state nonce". Outcome carries `mined` and `discarded` lists. Dropped. Source: https://raw.githubusercontent.com/paradigmxyz/reth/main/crates/transaction-pool/src/pool/txpool.rs (fetched 2026-09-30)
- **VERIFIED (Nethermind)** `ProcessNewHeads()` → `RemoveProcessedTransactions(args.Block)` (removes each included tx via `RemoveIncludedTransaction` → `RemoveTransaction(tx.Hash)` and `_broadcaster.EnsureStopBroadcastUpToNonce(tx)`), `ReAddReorganisedTransactions(args.PreviousBlock)` (re-submits txs from reorged-out blocks), and `UpdateBucketsWithoutRevalidation()` whose delegate `UpdateGasBottleneckAndMarkForEviction` marks for eviction txs below the account's current nonce. Source: https://raw.githubusercontent.com/NethermindEth/nethermind/master/src/Nethermind/Nethermind.TxPool/TxPool.cs (fetched 2026-09-30; paraphrased from fetched code by the summariser)
- **VERIFIED (reorg)** geth's `reset()` re-injects transactions from the dropped side of a reorg (legacypool reset logic: "reinject" of discarded txs) and Nethermind re-adds via `ReAddReorganisedTransactions` — i.e. a "stale" tx is only stale relative to the current canonical head; on a reorg that un-mines the competing same-nonce tx, the losing alternative can become valid again. (geth reinject detail is well-known but the specific code was not quoted in this run → treat the geth reinject claim as **UNVERIFIED** in this document; Nethermind's is VERIFIED above.)

**Design implication (analysis, not a sourced claim):** once one of two same-nonce alternatives is included, every client drops the other on the next head; there is no "keep and retry" state. The losing alternative can only re-enter the pool via explicit resubmission (subject to the 10%/100% bump rule if the winner is still pending, or freely if the winner was mined and the nonce has advanced — in which case it is nonce-too-low and rejected).

---

## 4. Builder behaviour: MEV-Boost vs ePBS, revert protection

### 4a. MEV-Boost (current mainnet)

- **VERIFIED** The relay validates every builder submission by executing the block. In `flashbots/builder` `eth/block-validation/api.go`: `ValidateBuilderSubmissionV2/V3` convert the payload to a block and call `api.validateBlock(block, params.Message, params.RegisteredGasLimit)`, which runs `ValidatePayload(block, feeRecipient, expectedProfit, registeredGasLimit, vmconfig, useBalanceDiffProfit, excludeWithdrawals)` with `expectedProfit := msg.Value.ToBig()`; a comment states "proposer payment is calculated as a balance difference". V3 additionally runs `validateBlobsBundle`. Source: https://raw.githubusercontent.com/flashbots/builder/main/eth/block-validation/api.go (fetched 2026-09-30)
- **VERIFIED** The proposer is paid **inside the payload**: "Coinbase of the block is set to the address of the block proposer, fee recipient of the validator receives its eth in the last tx in the block." "We reserve gas for the proposer payment using `proposerTxPrepare` and commit proposer payment after txs are added with `proposerTxCommit`." Source: https://raw.githubusercontent.com/flashbots/builder/main/README.md (fetched 2026-09-30)
- **VERIFIED** mev-boost-relay README: "on getPayload, the block has to be validated and broadcast by a local beacon node before it is returned to the proposer" and references a "builder block submission validation request timeout (default: `3000`)". Source: https://raw.githubusercontent.com/flashbots/mev-boost-relay/main/README.md (fetched 2026-09-30)
- **VERIFIED** Optimistic relaying: "The relay simulates the block; the simulation must complete before the bid can win the auction." Under optimistic mode builders "post collateral to the relay which will be used to refund proposers if a slot or payment is missed" and an invalid block "results in a missed slot (because the proposer signed an invalid header)". Source: https://raw.githubusercontent.com/michaelneuder/optimistic-relay-documentation/main/towards-epbs.md (fetched 2026-09-30)
- **Conclusion (MEV-Boost):** a builder **cannot** include an EL-invalid transaction and get paid: the block fails relay simulation (non-optimistic) or, if optimistically relayed, causes a missed slot and the builder's collateral refunds the proposer. Payment is an EL transaction inside the same payload, so an invalid payload carries no payment. (VERIFIED via the three sources above.)

### 4b. ePBS (EIP-7732, Gloas CL fork / Glamsterdam)

- **VERIFIED** Status: EIP-7732 page says "This EIP is in the process of being peer-reviewed" (Review). Glamsterdam (ePBS + block-level access lists) is scheduled on **Sepolia at epoch 353,024, slot 11,296,768 (2026-10-06 13:53:36 UTC)**; "Hoodi and mainnet activation dates have not yet been decided." Sources: https://eips.ethereum.org/EIPS/eip-7732 ; https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement (fetched 2026-09-30). **ePBS is NOT live on mainnet as of 2026-09-30** (VERIFIED by the EF blog post above; geth `MainnetChainConfig` has `AmsterdamTime` unset and `BogotaTime: nil` — https://raw.githubusercontent.com/ethereum/go-ethereum/master/params/config.go).
- **VERIFIED** EIP-7732 text: "When processing the `BeaconBlock`, the committed value is deducted from the builder's beacon chain balance and later a withdrawal is placed to an address, of the proposer's choosing, in the execution layer." "Proposer unconditional payment refers to the fact that in the third scenario [Empty: the beacon block has been included on-chain, but the committed execution payload has not] the beacon block proposer received payment from the corresponding builder." Free-option note: "Economically rational but malicious ... builders may chose to withhold their payload in the event that it would be profitable for them." Source: https://eips.ethereum.org/EIPS/eip-7732 (fetched 2026-09-30)
- **VERIFIED** Gloas spec mechanics (consensus-specs `master`, 2026-09-30):
  - `process_execution_payload_bid`: asserts `can_builder_cover_bid(state, builder_index, amount)`, `len(bid.blob_kzg_commitments) <= get_blob_parameters(...).max_blobs_per_block`, then if `amount > 0` records `BuilderPendingPayment(weight=Gwei(0), withdrawal=BuilderPendingWithdrawal(fee_recipient=bid.fee_recipient, amount=amount, builder_index=builder_index), proposer_index=get_beacon_proposer_index(state))` at `state.builder_pending_payments[SLOTS_PER_EPOCH + bid.slot % SLOTS_PER_EPOCH]`.
  - Settlement path A (payload revealed & processed): the *next* block's `process_parent_execution_payload` → `apply_parent_execution_payload` calls `settle_builder_payment(state, payment_index)`, which appends the withdrawal to `builder_pending_withdrawals` "if payment.withdrawal.amount > 0".
  - Settlement path B (payload absent/empty): `process_attestation` accumulates `payment.weight += state.validators[index].effective_balance` for timely same-slot attestations; at the epoch boundary `process_builder_pending_payments` pays "if payment.weight >= quorum" where `quorum = get_builder_payment_quorum_threshold(state)` = `per_slot_balance * BUILDER_PAYMENT_THRESHOLD_NUMERATOR // BUILDER_PAYMENT_THRESHOLD_DENOMINATOR` with `6/10` (60%).
  - Validity of the payload: `verify_execution_payload_envelope(state, signed_envelope, execution_engine)` ends with `assert execution_engine.verify_and_notify_new_payload(NewPayloadRequest(execution_payload=payload, versioned_hashes=..., parent_beacon_block_root=..., execution_requests=...))`; the fork-choice handler `on_execution_payload_envelope` calls it and only then does `store.payloads[envelope.beacon_block_root] = envelope`. A payload the EL rejects therefore never enters the store; the block's payload status stays `PAYLOAD_STATUS_EMPTY` (`PayloadStatus(0)`; `FULL = 1`, `PENDING = 2`).
  Sources: https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/gloas/beacon-chain.md ; https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/gloas/fork-choice.md (fetched 2026-09-30)
- **Conclusion (ePBS):** the builder's bid is paid at the CL whether or not it reveals a valid payload — *provided* the beacon block itself gathers >= 60% same-slot attestation weight (path B) or the payload is applied (path A). An EL-invalid payload is **not** accepted (`assert verify_and_notify_new_payload`), so the slot is "Empty" and the builder pays without getting its transactions executed. So under ePBS a builder **can lose the bid value while including an EL-invalid tx**, but it **cannot get an invalid tx executed**. (The task's framing "paid unconditionally at the CL layer but an invalid payload is not accepted" is VERIFIED with the 60%-attestation-quorum nuance.)

### 4c. Revert protection and public-mempool copies

- **VERIFIED** Flashbots Protect: "Transactions are only included in the block if they do not revert. Users do not pay fees for failed transactions." "Transactions are hidden from the public mempool away from front-running and sandwich bots." In fast mode transactions are "multiplexed, or shared, with all registered builders within one block after they are received." Warning: "Do Not Switch RPCs Before Transaction Confirmation" because MetaMask may resend transactions to the public mempool. Sources: https://docs.flashbots.net/flashbots-protect/overview ; https://docs.flashbots.net/flashbots-protect/quick-start (fetched 2026-09-30)
- **VERIFIED** Flashbots RPC: `eth_sendBundle.revertingTxHashes` = "A list of tx hashes that are allowed to revert"; `eth_sendPrivateTransaction` with `fast: true` "Sends transactions to all registered block builders, sets MEV-Share revenue share to 50%". Builder side (`flashbots/builder`): when a bundle tx "has error on commit, and its hash is specified as one that can revert in the request body, the builder will discard the hash of the failed transaction from the submitted bundle" (`--builder.discard_revertible_tx_on_error`). Sources: https://docs.flashbots.net/flashbots-auction/advanced/rpc-endpoint ; https://raw.githubusercontent.com/flashbots/builder/main/README.md (fetched 2026-09-30)
- **VERIFIED** Titan Builder: `eth_sendBundle` parameters `revertingTxHashes` = "A list of tx hashes that are allowed to revert or be discarded", `droppingTxHashes` = "A list of tx hashes that are allowed to be discarded, but may not revert"; "We will never unbundle a bundle, and will never broadcast any bundles or private transactions to the public mempool."; `eth_sendPrivateTransaction`: "Note: we do not support `maxBlockNumber`". Sources: https://docs.titanbuilder.xyz/api/eth_sendbundle.md ; https://docs.titanbuilder.xyz/api/eth_sendprivatetransaction.md ; https://docs.titanbuilder.xyz/ (fetched 2026-09-30)
- **UNVERIFIED (no explicit primary statement found)** That a copy of the same signed tx which also reaches the public mempool can still be included (and revert) by any builder/proposer not honouring the private-order-flow revert rule. This follows from the fact that revert protection is a per-builder policy applied to *privately submitted* order flow (Flashbots/Titan docs above) and that the public mempool is served by all builders and by local block production; the Flashbots "Do Not Switch RPCs" warning is the closest primary acknowledgement. Treat as a design assumption: **revert protection does not extend to public-mempool copies.**

---

## 5. Blob transactions

### 5a. Blob fee burn timing

- **VERIFIED** EIP-4844 (Final): "The actual `blob_fee` as calculated via `calc_blob_fee` is deducted from the sender balance before transaction execution and burned, and is not refunded in case of transaction failure." `blob_fee = GAS_PER_BLOB * len(tx.blob_versioned_hashes) * get_base_fee_per_blob_gas(header)`; inclusion validity `assert tx.max_fee_per_blob_gas >= get_base_fee_per_blob_gas(block.header)`. The blob fee is therefore charged (and burned) **only when the transaction is included in a block** — a pending or dropped blob tx costs nothing on-chain. Source: https://eips.ethereum.org/EIPS/eip-4844 (fetched 2026-09-30)

### 5b. Blob count limits on mainnet as of 2026-09-30

- **VERIFIED** Mainnet blob schedule (geth `params/config.go` `MainnetChainConfig`): `CancunTime 1710338135`, `PragueTime 1746612311`, `OsakaTime 1764798551`, `BPO1Time 1765290071`, `BPO2Time 1767747671`; `BlobScheduleConfig{ Cancun: DefaultCancunBlobConfig, Prague: DefaultPragueBlobConfig, BPO1: DefaultBPO1BlobConfig, BPO2: DefaultBPO2BlobConfig }` with
  - Cancun: Target 3, Max 6, UpdateFraction 3338477
  - Prague: Target 6, Max 9, UpdateFraction 5007716
  - BPO1: Target 10, Max 15, UpdateFraction 8346193
  - BPO2: **Target 14, Max 21, UpdateFraction 11684671**
  `BPO3Time/BPO4Time/BPO5Time/AmsterdamTime` are not set for mainnet; `BogotaTime: nil`. Source: https://raw.githubusercontent.com/ethereum/go-ethereum/master/params/config.go (fetched 2026-09-30)
- **VERIFIED (cross-check)** reth `MAINNET` spec: `blob_params: BlobScheduleBlobParams::default().with_scheduled([(MAINNET_BPO1_TIMESTAMP, BlobParams::bpo1()), (MAINNET_BPO2_TIMESTAMP, BlobParams::bpo2())])`; Bpo1 "(target: 10, max: 15, fraction: 8346193)", Bpo2 "(target: 14, max: 21, fraction: 11684671)"; timestamps Osaka 1764798551, Bpo1 1765290071, Bpo2 1767747671. Source: https://raw.githubusercontent.com/paradigmxyz/reth/main/crates/chainspec/src/spec.rs (fetched 2026-09-30)
- **Current mainnet values (VERIFIED via both client configs): latest BPO fork = BPO2 (activated at timestamp 1767747671, i.e. 2026-01-07); per-block target 14 blobs, max 21 blobs; per-tx max 6 blobs.**
- **VERIFIED** BPO mechanism: EIP-7892 (Final, Informational) — "BPO hardforks are defined as protocol upgrades that modify only blob-related parameters through configuration, without requiring any client-side code changes." Source: https://eips.ethereum.org/EIPS/eip-7892 (fetched 2026-09-30)
- **VERIFIED** EIP-7691 (Final): Pectra/Prague values target 6 / max 9 (786,432 / 1,179,648 blob gas), update fraction 5,007,716. Source: https://eips.ethereum.org/EIPS/eip-7691 (fetched 2026-09-30)
- **VERIFIED** Per-transaction blob limit: EIP-7594 (Final) introduces "a limit of 6 blobs per transaction" which clients "enforce ... when validating blob transactions at submission time, when received from the network, and during block production and processing." Source: https://eips.ethereum.org/EIPS/eip-7594 (fetched 2026-09-30)
- **UNVERIFIED** BPO3 mainnet parameters/date: web search indicates BPO3 test configs use target/max 21/32 (execution-specs PR #3633 reference) and that "developers are holding BPO3 and BPO4 pending a telemetry review", but no primary source with a mainnet BPO3 timestamp was found, and neither geth nor reth mainnet configs contain one as of 2026-09-30.

### 5c. Can frame transactions carry blobs?

- **VERIFIED — yes.** EIP-8141 payload: `[chain_id, nonce, sender, frames, signatures, fees, blob_versioned_hashes]` with `fees = [max_priority_fee_per_gas, max_fee_per_gas, max_fee_per_blob_gas]`. "When `blob_versioned_hashes` is non-empty, the transaction is a blob-carrying transaction and follows EIP-4844." "The transaction is only valid for inclusion in a block if `tx.fees.max_fee_per_blob_gas >= blob_base_fee` of that block." "The per-transaction blob limit of EIP-7594 applies unchanged." On the wire "its EIP-2718 `TransactionPayload` is wrapped per EIP-7594" in `PooledTransactions`. Refund formula: "charged_fee = gas_used * effective_gas_price + blob_gas * blob_base_fee; payer_refund = max_cost - charged_fee." Source: https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md (fetched 2026-09-30)
- **VERIFIED** geth has a (closed, devnet-branch) PR #35816 "support blob-carrying frame transactions" (2026-09-28); Nethermind PR #13561 pins "the blob announcement predicate to CarriesBlobs" (merged 2026-09-18). Sources: https://github.com/ethereum/go-ethereum/pull/35816 ; https://github.com/NethermindEth/nethermind/pull/13561
- **VERIFIED** For inclusion-list purposes, "frame transactions with a non-empty `blob_versioned_hashes` list are not candidates for either profile" (EIP-8369 as quoted in Nethermind PR #13590). Source: https://github.com/NethermindEth/nethermind/pull/13590 (fetched 2026-09-30; second-hand quote of EIP-8369 — the EIP itself was not fetched → EIP-8369 wording UNVERIFIED)

---

## Consolidated list of UNVERIFIED items

1. Nethermind: whether a literal "one pending frame tx per sender" gate is enforced in its pool (only per-payer exposure, verify-gas and keyed-nonce bounds were confirmed).
2. Nethermind: whether same-nonce cross-type (blob vs non-blob) replacement is blocked.
3. geth: the exact reorg "reinject" code path in `legacypool.reset()` was not quoted this run.
4. That public-mempool copies of a privately submitted tx can still land and revert — no explicit builder statement found; inferred.
5. BPO3/BPO4 mainnet parameters and dates — not present in any mainnet client config; only secondary reports.
6. EIP-8369 blob-carve-out wording — quoted second-hand via a Nethermind PR, not from the EIP.
