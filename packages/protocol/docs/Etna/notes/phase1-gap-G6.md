# G6: Which preconf-block validity rules are enforced by the execution engine at engine_newPayload, given the drivers check only shape + anchor sender/recipient/selector? Specifically: timestamp > parent and ≤ now, gas-limit band, EIP-4396 base fee, anchor tx first with exactly 1,000,000 gas, treatment of invalid user txs (skip vs reject), Unzen difficulty, and whether a reverted anchor tx invalidates the block. Also: neither client rejects a block whose engine-built hash differs from the operator-signed BlockHash (Rust only purges the envelope).

## Sources and scope

- Repository: `/home/user/taiko-mono` at commit `7c0e9740980fc897d9ecab355f5bfec9ec047940`.
- Execution engine (Go side): the taiko-geth pinned by the root `go.mod:308` — `replace github.com/ethereum/go-ethereum v1.15.5 => github.com/taikoxyz/taiko-geth v1.18.1-0.20260924044618-8e98046bfd6a`. All `taiko-geth/...` citations below are relative to `/root/go/pkg/mod/github.com/taikoxyz/taiko-geth@v1.18.1-0.20260924044618-8e98046bfd6a/`.
- P2P layer (Go side): `/root/go/pkg/mod/github.com/taikoxyz/optimism@v0.0.0-20260420065638-5490c5186828/` (op-node fork).
- **Not readable in this session: alethia-reth.** `packages/taiko-client-rs/Cargo.toml:77-82` pins `taikoxyz/alethia-reth` at rev `0fb47d966f290c032e0ce88bdc8877121768d253`, but the crate is not in the cargo cache (`~/.cargo` holds only `bin`/`env`), `gh` is not installed, and the GitHub tool denies access to any repo other than `taikoxyz/taiko-mono`. Every EE rule below is therefore established from taiko-geth. taiko-geth's own comments claim parity with "the Rust reference" (e.g. `taiko-geth/core/state_processor.go:189`, `taiko-geth/consensus/taiko/consensus.go:259-263`); that parity is **unverified** here.

## 0. What the driver actually asks the EE to do (both clients)

Neither driver submits the operator's payload to `engine_newPayload` directly. Both make the EE **build** the block from attributes, then feed the EE's own `getPayload` output back into `newPayload`:

- Go: `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:761-786` calls `createExecutionPayloadsAndSetHead` with `Timestamp`, `SuggestedFeeRecipient`, `GasLimit`, `MixHash`, `ExtraData`, `BaseFee`, `ParentHash` and the decompressed tx list; `createExecutionPayloads` (`common.go:126-212`) does `ForkchoiceUpdate(parent, attributes)` (168-181) → `GetPayload` (184-187) → `NewPayload(payload)` (203-209), requiring `VALID`. The `L1Origin` is written with `L1BlockHeight: nil` (`common.go:772-781`).
- Rust: `crates/whitelist-preconfirmation-driver/src/payload.rs:14-40` (`build_driver_payload`) forwards `fee_recipient, timestamp, prev_randao, gas_limit, tx_list, extra_data, base_fee_per_gas, block_number` and sets `l1_block_height: None` (line 31); `crates/driver/src/sync/engine.rs:168-229` (`apply_payload_internal`) does `forkchoice_updated_v2(parent, Some(attrs))` (175-184) → `get_payload_v2` (199) → `submit_payload_to_engine` (210-219), which is `new_payload_v2` (387-388, only `VALID` accepted per `293-308`) → promotion `forkchoice_updated_v2` (390-392) → read-back hash check (394-395).
- On the EE side the build happens inside `engine_forkchoiceUpdated`: `taiko-geth/eth/catalyst/api.go:378-399` calls `Miner().SealBlockWith(parent, timestamp, parentBlockTime, BlockMetadata, BaseFeePerGas, Withdrawals)` and returns `InvalidPayloadAttributes` on any build error (396-399). The `newPayload` call then runs the normal import path: `api.go:1064` `InsertBlockWithoutSetHead` → `core/blockchain.go:2709` `insertChain` → `blockchain.go:1872` `engine.VerifyHeaders` (Taiko `verifyHeader`, `consensus/taiko/consensus.go:153-245`) → `core/blockchain_insert.go:131` `ValidateBody` → `blockchain.go:2211` `processor.Process`.

So "what the EE enforces at newPayload" has two layers: **build-time rules** (`sealBlockWith` + `FinalizeAndAssemble`) that decide whether a block exists at all, and **import-time rules** (`verifyHeader` + `Process`) that decide whether `newPayload` returns `VALID`.

## 1. Timestamp

**> parent — enforced (strictly, post-Shasta), but only at import.**
- Build: `taiko-geth/miner/worker.go:253-264` — for Taiko, `if parent.Time > timestamp { return error }`; equality is allowed ("block.timestamp == parent.timestamp is allowed in Taiko protocol", line 254).
- `engine_newPayload` pre-check: `taiko-geth/eth/catalyst/api.go:1037-1043` — `if block.Time() < parent.Time() { invalid }`, again allowing equality.
- Header verification during `insertChain`: `taiko-geth/consensus/taiko/consensus.go:159-169`:
  ```go
  if t.chainConfig.IsShasta(header.Time) {
      if header.Time <= parent.Time { return ErrOlderBlockTime }
  } else {
      if header.Time < parent.Time { return ErrOlderBlockTime }
  }
  ```
  Net: a Shasta preconf block with `timestamp == parent.timestamp` is *built* by fcU but *rejected* by `newPayload` (`INVALID`), which the drivers surface as an error (`common.go:207-209`; `engine.rs:304-306`).

**≤ now — NOT enforced for preconf blocks.**
- `taiko-geth/consensus/taiko/consensus.go:239-242`:
  ```go
  if l1Origin != nil && !l1Origin.IsPreconfBlock() && header.Time > uint64(unixNow) {
      return consensus.ErrFutureBlock
  }
  ```
  `IsPreconfBlock()` is `L1BlockHeight == nil || == 0` (`taiko-geth/core/rawdb/taiko_l1_origin.go:66-68`), and both drivers write a nil/None `L1BlockHeight` for preconf blocks (`common.go:775`; `payload.rs:31`). The build path has no wall-clock check at all (`worker.go:250-265`).
- Drivers only require `timestamp != 0` (`packages/taiko-client/driver/preconf_blocks/server.go:957-959`; `crates/whitelist-preconfirmation-driver/src/importer/validation.rs:25-29`).

## 2. Gas-limit band — NOT enforced by the EE

- Build: `taiko-geth/miner/taiko_worker.go:254` `env.header.GasLimit = blkMeta.GasLimit` — whatever the envelope says, unconditionally (it overwrites the `CalcGasLimit` default from `worker.go:270`).
- Import: `consensus.go:185-193` only checks `header.GasLimit > params.MaxGasLimit` (2^63-1, `taiko-geth/params/protocol_params.go:28`) and `GasUsed <= GasLimit`. `misc.VerifyGaslimit` (the ±1/1024 band) is called only from `consensus/misc/eip1559/eip1559.go:39`, `consensus/clique/clique.go:353`, `consensus/ethash/consensus.go:258` — never from the Taiko engine. No `BLOCK_GAS_LIMIT_MAX_CHANGE`/`MIN_BLOCK_GAS_LIMIT` constants exist in taiko-geth (grep, no hits).
- The ±200 ppm band and `[10M, 45M]` bounds in `packages/protocol/docs/Derivation.md:249-263, 372-374` are derivation-time rules on L1 proposals, not EE rules, and are not applied to preconf envelopes by either driver: Go checks only `GasLimit != 0` (`server.go:963-965`), Rust only `gas_limit != 0` (`validation.rs:35-39`).

## 3. EIP-4396 base fee — enforced; the envelope's value is ignored

- Build: `taiko-geth/miner/taiko_worker.go:230-232`
  ```go
  if w.chainConfig.IsShasta(timestamp) {
      baseFeePerGas = misc.CalcEIP4396BaseFee(w.chainConfig, parent, parentBlockTime)
  }
  ```
  `parentBlockTime = parent.Time - grandparent.Time` is computed by the EE (`api.go:382-387`). The formula is `taiko-geth/consensus/misc/taiko_eip4396.go:45-90` (target = min(gasTarget·parentBlockTime/2, 95% of gasLimit), lines 50-54), clamped by `clampEIP4396BaseFeeShasta` (93-108) to `[0.005 gwei (0.01 gwei on mainnet), 1 gwei]` (18-22); a genesis parent yields `ShastaInitialBaseFee = 25_000_000` (46-49; `params/protocol_params.go:136`).
- Import: `consensus.go:200-203` (BaseFee non-nil) and `210-227`: for Shasta headers with `Number > 1` and a known grandparent, `misc.VerifyEIP4396Header` (`taiko_eip4396.go:25-42`) recomputes and requires equality. If the grandparent is unknown the check is skipped with a debug log (219-225).
- Docs agree: `Derivation.md:315` and `353-361`.
- Drivers only require non-zero (`server.go:966-969`; `validation.rs:41-45`). A wrong envelope `baseFeePerGas` therefore does not fail validation: the EE silently builds with the correct value, and the result is a signed-hash/built-hash mismatch (§8).
- Related header shape rule at import: Shasta `extraData` must be exactly 7 bytes (`consensus.go:210-213`; `params/protocol_params.go:142`); drivers only require non-empty (`server.go:970-972`; `validation.rs:47-49`).

## 4. Anchor tx first, exactly 1,000,000 gas — enforced at build time (fcU), not re-checked at import

- `sealBlockWith` rejects an empty tx list (`taiko_worker.go:225-228`), marks `txs[0]` as anchor (`271-276`), and if committing tx 0 fails returns `"anchor transaction failed"` (`311-313`) → fcU `InvalidPayloadAttributes` (`api.go:396-399`).
- `FinalizeAndAssemble` (`consensus.go:355-364`) calls `ValidateAnchorTx(body.Transactions[0], header)` and returns `ErrAnchorTxNotFound` unless all of `consensus.go:432-489` hold: `DynamicFeeTxType` (433-436); `To == taikoL2Address` (438-441; address derived from chain ID at 61-74); Shasta selector `anchorV4((uint48,bytes32,bytes32))` (45-47, 443-447); `Value == 0` (460-463); **`tx.Gas() == AnchorV3V4GasLimit = 1_000_000`** (49, 465-469); `GasFeeCap == header.BaseFee` (477-480); recovered sender == `GoldenTouchAccount` (36, 482-488).
- The contract itself only checks the sender: `packages/protocol/contracts/layer2/core/Anchor.sol:86-89` (`onlyValidSender` → `msg.sender == GOLDEN_TOUCH_ADDRESS`) on `anchorV4` (124-128); `ANCHOR_GAS_LIMIT = 1_000_000` at `Anchor.sol:39-40` is annotated "(must be enforced)" and `Derivation.md:342-345` says "enforced by the Taiko node software" — consistent with the build-time check above.
- Import path (`Process`): only `MarkAsAnchor()` on index 0 (`taiko-geth/core/state_processor.go:113-118`); `ValidateAnchorTx` has exactly one caller (`consensus.go:357`), so `newPayload` does not re-verify gas/value/feeCap/selector. What "anchor" changes during execution: balance check skipped (`core/state_transition.go:305-309`), fee-cap-vs-basefee check skipped (361-362), basefee not routed to treasury/coinbase (596), no gas refund (705-707). Nonce is still checked (`SkipNonceChecks: false` at 195; 331-344), so a wrong-nonce anchor fails the build.
- Driver checks are weaker: Go `packages/taiko-client/prover/anchor_tx_validator/anchor_tx_validator.go:44-76` checks recipient, golden-touch sender, and that the selector is any of `anchor/anchorV2/anchorV3/anchorV4` (69-73) — no gas, value, or fee-cap; Rust `crates/protocol/src/shasta/anchor.rs:249-291` checks recipient, chain id (265-268), sender, and `anchorV4` selector only (280-288) — no gas, value, or fee-cap.

## 5. Invalid user txs — skipped at build, would be rejected at import

- Build (`taiko_worker.go:271-334`): blob txs skipped (277-281); txs whose sender cannot be recovered skipped (282-286); any `commitTransaction` error for `i > 0` skipped with `continue` (314-316); under Unzen a zk-gas overflow truncates the rest of the block (300-310). `commitTransaction` errors only on `core.ApplyTransaction` errors (`worker.go:376-391, 422-435`), i.e. pre-check failures such as nonce, non-EOA sender, fee-cap below base fee, insufficient balance (`state_transition.go:328-380`).
- Import (`state_processor.go:140-158`): any `ApplyTransactionWithEVM` error makes the whole block invalid (`return nil, fmt.Errorf("could not apply tx ...")`, 157); the only exception is Unzen zk-gas truncation (144-155), which is then caught by the body-length invariant (190-195).
- Because the driver submits the EE's own build, the body already omits skipped txs and `newPayload` succeeds. An operator who includes invalid txs in the envelope does not get rejected; the divergence (if the operator's signed hash was computed over a different body) only shows up as §8.

## 6. Unzen difficulty — enforced by recomputation

- Build: zk-gas meter attached for Unzen (`taiko_worker.go:262-269`); `env.header.Difficulty = BlockZkGasUsed()` (336-339). Pre-Unzen difficulty is forced to 0 (`consensus.go:301, 316-318`); Unzen headers get empty `requestsHash`, zero blob-gas fields (326-333), and blob txs are rejected (380-385).
- Import: pre-Unzen `Difficulty` must be 0 (`consensus.go:176-180`); Unzen requires `verifyUnzenHeaderFields` (181-183, 247-280: empty requests hash, **zero** parent beacon root, zero blob gas). `Process` re-meters zk gas and requires `header.Difficulty == recomputed` (`state_processor.go:196-201`), rejects blob txs (90-98) and a body longer than the truncation point (190-195).
- Wire: `getPayloadV2.blockValue` carries the difficulty (`taiko-geth/beacon/engine/types.go:443-448`); the txHash-only `newPayload` path uses `params.HeaderDifficultyOrZero()` (`api.go:951`, Unzen fields 961-971), as does `ExecutableDataToBlock` (`types.go:374`). Go driver: `packages/taiko-client/pkg/rpc/engine_unzen.go:43-62` copies `blockValue` into `HeaderDifficulty` when `IsUnzen`; Rust: `engine.rs:253-256, 273-277`.
- The envelope's own `HeaderDifficulty` is never used to build: Go only logs it (`common.go:672`); Rust validates its presence/absence against Unzen activation (`validation.rs:106-131`, called from `importer/ingress.rs:145-149`) but does not forward it (`payload.rs:14-40`).

## 7. A reverted anchor tx does NOT invalidate the block

- Build: `applyTransaction` reverts state only when `core.ApplyTransaction` returns an error (`worker.go:427-431`); an EVM revert is `result.Err`, not `err`, so the receipt is created with `Status = ReceiptStatusFailed` (`state_processor.go:315-320`) and the tx is appended (`worker.go:386-387`). Neither `sealBlockWith`, `FinalizeAndAssemble`, nor `Process` inspects receipt status (grep for `ReceiptStatusFailed|receipt.Status` in `miner/`, `consensus/taiko/`, `eth/catalyst/`: no hits).
- Evidence from production: `packages/protocol/script/layer1/proposals/Proposal0010.md:15, 21` — "the first 7 proposals had reverted anchor transactions" on mainnet; those blocks were canonical and required a prover-side exception rather than being invalid.
- The contract's `require(_blockState.ancestorsHash == oldAncestorsHash, AncestorsHashMismatch())` (`Anchor.sol:173-179`) can revert, but the EE treats that like any other failed tx.

## 8. Signed BlockHash vs engine-built hash — no rejection in either client

- What is signed: the op-node fork verifies the wire signature over the raw SSZ envelope bytes (`optimism/op-node/p2p/gossip.go:364-369`; `signer.go:25-27`), which embed the operator's `BlockHash`; Rust: `crates/whitelist-preconfirmation-driver/src/codec.rs:56-68` (`keccak256(domain || chain_id || keccak256(payload_bytes))`). The gossip validator only sanity-checks fields (`gossip.go:378-395`); `CheckBlockHash` exists only in the OP block validator (`gossip.go:695`), not in `BuildPreconfBlocksValidator` (318-414), and could not work anyway because `Transactions[0]` is a compressed list, not RLP txs.
- Go: `common.go:655-794` uses `envelope.Payload.BlockHash` only for logging and canonical/head checks (684-711); it builds from attributes (761-786) and returns the header of the EE's `payload.BlockHash` (793). `inserter.go:296-318` just logs the inserted header; `server.go:1462-1496` never compares. A same-height block with a different hash is logged and imported anyway (`server.go:1449-1459`).
- Rust: `engine.rs:355-365, 394-395` compares the EE's `getPayload` hash with the canonical read-back — not with the envelope hash. `cache_import.rs:186-207`: on `Inserted { block_hash }` != envelope hash it only `warn!`s, `remove_recent` (purges the envelope so it is not re-served) and still `record_inserted_block` (208); same purge-only handling for `AlreadyMaterialized` (208-224). Every import goes through this path (`ingress.rs:79` caches; `runner.rs:210` → `maybe_import_from_cache` → `try_import_cached`).
- Consequence: the operator signature commits to the SSZ envelope (parent, timestamp, coinbase, prevRandao, gasLimit, extraData, compressed tx list, plus the operator's claimed `baseFeePerGas`, `stateRoot`, `BlockHash`, …), but the block nodes execute is whatever the EE builds from the attribute subset in §0 with EE-recomputed base fee, difficulty and post-state. Any of `baseFeePerGas`, `stateRoot`, `receiptsRoot`, `gasUsed`, `logsBloom`, `BlockHash` in the envelope can be wrong without the block being rejected.

## Full local validity predicate for a preconf block (driver + EE, as implemented)

| Rule | Go driver | Rust driver | EE (taiko-geth) |
| --- | --- | --- | --- |
| timestamp != 0 | `server.go:957` | `validation.rs:25` | — |
| timestamp > parent (Shasta strict) | — | — | `consensus.go:161-164` at import; build allows `==` (`worker.go:261-263`) |
| timestamp ≤ now | — | — | **skipped** for preconf (`consensus.go:240`) |
| gasLimit | `!= 0` (`server.go:963`) | `!= 0` (`validation.rs:35`) | `≤ 2^63-1`, `gasUsed ≤ gasLimit` (`consensus.go:186-193`); no band |
| baseFee | `!= 0` (`server.go:967`) | `!= 0` (`validation.rs:41`) | recomputed EIP-4396 + clamp (`taiko_worker.go:230-232`, `taiko_eip4396.go:45-108`); verified at import (`consensus.go:210-227`) |
| extraData | non-empty (`server.go:970`) | non-empty (`validation.rs:47`) | exactly 7 bytes for Shasta (`consensus.go:211-213`) |
| tx list | 1 entry, zlib+RLP, ≤ blob-size cap (`server.go:973-988`) | 1 entry, size-limited codec (`validation.rs:51-72`) | build skips invalid/blob txs (`taiko_worker.go:277-316`) |
| anchor tx | to/sender/any-anchor-selector (`anchor_tx_validator.go:45-73`) | to/chainId/sender/`anchorV4` (`anchor.rs:254-288`) | type, to, `anchorV4`, value 0, **gas == 1e6**, feeCap == baseFee, sender (`consensus.go:432-489`) at build only |
| reverted anchor | — | — | accepted (`state_processor.go:315-320`; no status check) |
| difficulty | — | Unzen presence check (`validation.rs:106-131`) | 0 pre-Unzen / recomputed zk gas under Unzen (`consensus.go:176-183`, `state_processor.go:196-201`) |
| signed hash == built hash | not checked | purge only (`cache_import.rs:186-207`) | n/a (EE never sees the envelope hash) |

## Go vs Rust, docs vs code

- Go's anchor validator accepts `anchor`/`anchorV2`/`anchorV3`/`anchorV4` (`anchor_tx_validator.go:70`); Rust accepts only `anchorV4` and additionally checks the chain id (`anchor.rs:265-268, 286-288`). Neither checks the 1,000,000 gas limit; only the EE does, at build time.
- Rust validates `header_difficulty` presence vs Unzen (`validation.rs:106-131`); Go does not.
- Rust maps `newPayload` `ACCEPTED`/`SYNCING` to distinct errors and only `INVALID` to `InvalidBlock` (`engine.rs:293-308`); Go treats every non-`VALID` status the same (`common.go:207-209`).
- Rust detects and purges on signed/built hash mismatch (`cache_import.rs:186-207`); Go does not detect it at all.
- Docs vs code: `Derivation.md:344` ("Exactly 1,000,000 gas (enforced by the Taiko node software)") matches `consensus.go:465-469` but only on the build path; `Derivation.md:249-263` gas-limit band is enforced in derivation, not by the EE or the preconf drivers; `Derivation.md:353-361` base-fee text matches `taiko_eip4396.go`.

## What could not be verified

- alethia-reth (Rust EE) behaviour at rev `0fb47d966f290c032e0ce88bdc8877121768d253` (`Cargo.toml:77-82`): not readable in this session (see "Sources and scope"). The Rust driver targets an EE over the Engine API, so if the Rust driver is paired with taiko-geth the rules above apply verbatim; if paired with alethia-reth, the timestamp/gas/base-fee/anchor/difficulty checks must be confirmed there.

## Claims index

1. Go driver builds via fcU(attrs) → getPayload → newPayload, requires VALID — `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:126-212, 761-793`.
2. Go driver writes `L1BlockHeight: nil` for preconf blocks — `common.go:772-781`.
3. Rust driver forwards only fee_recipient/timestamp/prev_randao/gas_limit/tx_list/extra_data/base_fee/block_number, `l1_block_height: None` — `packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/src/payload.rs:14-40`.
4. Rust driver fcU(attrs) → getPayloadV2 → newPayloadV2 → fcU → read-back — `packages/taiko-client-rs/crates/driver/src/sync/engine.rs:168-229, 378-398`; only VALID accepted — `engine.rs:293-308`.
5. EE builds the block inside fcU via `SealBlockWith`, errors → `InvalidPayloadAttributes` — `taiko-geth/eth/catalyst/api.go:378-399`; parentBlockTime computed by EE — `api.go:382-387`.
6. newPayload import path: `api.go:1064` → `core/blockchain.go:2701-2711` → `blockchain.go:1872` (VerifyHeaders) → `core/blockchain_insert.go:131` (ValidateBody) → `blockchain.go:2211` (Process).
7. Build allows timestamp == parent, rejects < parent — `taiko-geth/miner/worker.go:253-264`.
8. newPayload pre-check allows == parent — `taiko-geth/eth/catalyst/api.go:1037-1043`.
9. Shasta header verification requires timestamp strictly > parent — `taiko-geth/consensus/taiko/consensus.go:159-169`.
10. Future-timestamp check skipped for preconf blocks — `consensus.go:239-242`; `IsPreconfBlock` = nil/zero L1BlockHeight — `taiko-geth/core/rawdb/taiko_l1_origin.go:66-68`.
11. Drivers only require timestamp != 0 — `packages/taiko-client/driver/preconf_blocks/server.go:957-959`; `packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/src/importer/validation.rs:25-29`.
12. Build sets header.GasLimit = envelope gas limit unconditionally — `taiko-geth/miner/taiko_worker.go:254`.
13. Import gas checks: ≤ 2^63-1 and gasUsed ≤ gasLimit only — `consensus.go:185-193`; `taiko-geth/params/protocol_params.go:28`.
14. `VerifyGaslimit` not used by the Taiko engine — `taiko-geth/consensus/misc/eip1559/eip1559.go:39`, `consensus/clique/clique.go:353`, `consensus/ethash/consensus.go:258` are its only callers.
15. Gas-limit band is a derivation rule — `packages/protocol/docs/Derivation.md:249-263, 372-374`; drivers only require != 0 — `server.go:963-965`; `validation.rs:35-39`.
16. Build overrides base fee with EIP-4396 — `taiko_worker.go:230-232`; formula/clamp/initial fee — `taiko-geth/consensus/misc/taiko_eip4396.go:14-22, 45-108`; `params/protocol_params.go:136`.
17. Import verifies EIP-4396 base fee when Number > 1 and grandparent known — `consensus.go:200-203, 210-227`; `taiko_eip4396.go:25-42`.
18. Docs on base fee — `Derivation.md:315, 353-361`.
19. Drivers only require base fee != 0 — `server.go:966-969`; `validation.rs:41-45`.
20. Shasta extraData must be 7 bytes at import — `consensus.go:210-213`; `params/protocol_params.go:142`; drivers only non-empty — `server.go:970-972`; `validation.rs:47-49`.
21. Empty tx list rejected at build — `taiko_worker.go:225-228`; tx 0 marked anchor, failure aborts build — `taiko_worker.go:271-276, 311-313`.
22. `FinalizeAndAssemble` validates the first tx as anchor — `consensus.go:355-364`; anchor rules incl. gas == 1,000,000 and feeCap == baseFee — `consensus.go:36, 45-49, 432-489`.
23. `ValidateAnchorTx` has one caller (build only) — `consensus.go:357`; import only marks index 0 — `taiko-geth/core/state_processor.go:113-118`.
24. Anchor execution semantics: balance check skipped — `taiko-geth/core/state_transition.go:305-309`; fee-cap check skipped — `361-362`; basefee not distributed — `596`; no refund — `705-707`; nonce still checked — `195, 331-344`.
25. Contract checks only sender; ANCHOR_GAS_LIMIT "must be enforced" — `packages/protocol/contracts/layer2/core/Anchor.sol:37-40, 86-89, 124-128`; docs — `Derivation.md:342-345`.
26. Go anchor validator: recipient/sender/any-anchor-selector — `packages/taiko-client/prover/anchor_tx_validator/anchor_tx_validator.go:44-76`.
27. Rust anchor validator: recipient/chain id/sender/anchorV4 — `packages/taiko-client-rs/crates/protocol/src/shasta/anchor.rs:249-291`.
28. Build skips blob txs, unrecoverable senders, failing non-anchor txs; zk-gas overflow truncates — `taiko_worker.go:277-286, 300-316`; build errors are pre-check errors — `worker.go:376-391, 422-435`; `state_transition.go:328-380`.
29. Import rejects any failing tx except zk-gas truncation, and checks body length — `state_processor.go:140-158, 186-195`.
30. Unzen build: zk meter, difficulty = zk gas — `taiko_worker.go:262-269, 336-339`; pre-Unzen difficulty 0 — `consensus.go:301, 316-318`; Unzen header fields — `consensus.go:326-333`; blob txs rejected — `consensus.go:380-385`.
31. Unzen import: difficulty 0 pre-Unzen — `consensus.go:176-180`; `verifyUnzenHeaderFields` — `consensus.go:181-183, 247-280`; recomputed zk gas must equal difficulty — `state_processor.go:196-201`; blob txs rejected — `state_processor.go:90-98`.
32. blockValue carries difficulty; newPayload uses HeaderDifficultyOrZero — `taiko-geth/beacon/engine/types.go:443-448, 374`; `api.go:951, 961-971`.
33. Go maps blockValue → HeaderDifficulty — `packages/taiko-client/pkg/rpc/engine_unzen.go:43-62`; Rust — `engine.rs:253-256, 273-277`.
34. Envelope HeaderDifficulty only logged (Go) — `common.go:672`; presence-validated but not forwarded (Rust) — `validation.rs:106-131`, `importer/ingress.rs:145-149`, `payload.rs:14-40`.
35. Reverted tx produces a failed receipt, still included — `state_processor.go:315-320`; `worker.go:382-391, 427-431`; no receipt-status check in miner/consensus/catalyst (grep).
36. Mainnet had 7 proposals with reverted anchorV4 that remained canonical — `packages/protocol/script/layer1/proposals/Proposal0010.md:15, 21`.
37. Signature covers SSZ envelope bytes — `optimism/op-node/p2p/gossip.go:364-369`, `signer.go:25-27`; Rust — `crates/whitelist-preconfirmation-driver/src/codec.rs:56-68`.
38. Preconf gossip validator does not recompute the block hash — `gossip.go:318-414` (checks at 378-395); `CheckBlockHash` only at `gossip.go:695` (OP validator).
39. Go never compares built hash with envelope hash — `common.go:684-711, 761-793`; `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/inserter.go:296-318`; `server.go:1449-1459, 1462-1496`.
40. Rust read-back check compares EE hash with EE hash — `engine.rs:355-365, 394-395`; mismatch with envelope only purges and still records — `crates/whitelist-preconfirmation-driver/src/importer/cache_import.rs:186-224`; all imports go via cache — `ingress.rs:79`, `runner.rs:210`, `cache_import.rs:43, 66`.
41. Rust newPayload status mapping — `engine.rs:293-308`; Go any non-VALID is an error — `common.go:207-209`.
42. alethia-reth pinned but unreadable here — `packages/taiko-client-rs/Cargo.toml:77-82`; taiko-geth's "Rust reference" parity comments — `state_processor.go:189`, `consensus.go:259-263`.
43. taiko-geth version — `/home/user/taiko-mono/go.mod:308`.
