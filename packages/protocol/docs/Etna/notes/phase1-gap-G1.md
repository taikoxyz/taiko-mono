# G1: Who turns preconfirmed L2 blocks into the L1 proposal, and how? Neither in-repo proposer consumes preconf blocks (Go and Rust proposers read only the L2 txpool and stamp blocks l1Head.time+i), and both Rust and Go defer handover/parent choice/EOS to an external sequencer ('Catalyst'). No summary states how the operator assembles the DerivationSourceManifest from its gossiped chain, picks anchorBlockNumber per block, reserves heights for forced inclusions, or decides when to land (one propose per L1 block, ≤768 blocks/source, timestamps must stay within [landing.ts − 6144 s, landing.ts]).

All paths are relative to `/home/user/taiko-mono/`. Line numbers are from the checked-out tree read on 2026-09-30.

## Short answer

**Nobody in this repository.** The component that converts the operator's preconfirmed chain into a `DerivationSourceManifest` and calls `Inbox.propose` is entirely external to the monorepo. The repository contains:

1. Two txpool-fed proposers (Go, Rust) that build fresh blocks from the mempool and cannot even express per-block anchor numbers or real block timestamps (§1).
2. Two "preconfirmation block servers" (Go `driver/preconf_blocks`, Rust `whitelist-preconfirmation-driver`) that are **passive HTTP/WS services**: they accept a fully formed block (including the anchor transaction) from an authenticated external caller, execute it, sign it, and gossip it (§2).
3. Three source-code comments naming the external caller "Catalyst"; no README, spec, interface document, config or CLI flag names it, its repository, or its algorithm (§3).

Everything the question asks for (manifest assembly, per-block `anchorBlockNumber`, forced-inclusion height reservation, landing timing) is therefore an **implicit contract** that can only be reconstructed by inverting the derivation and canonical-match rules the node applies when the proposal lands (§4). That inversion is written out below, but it is a *reconstruction of what the external component must do*, not a description of what it does.

## 1. The in-repo proposers do not consume preconfirmed blocks

### 1.1 Go proposer (`packages/taiko-client/proposer/`)

- Input is the L2 txpool only: `preBuiltTxList, err := p.rpc.GetPoolContent(p.ctx, p.proposerAddress, uint32(l2Head.GasLimit), rpc.BlockMaxTxListBytes, []common.Address{}, p.MaxTxListsPerEpoch, minTip)` (`proposer/proposer.go:188-196`). `MaxTxListsPerEpoch` defaults to 1 (`cmd/flags/proposer.go:56-62`), so the default manifest holds one block.
- The only entry point is `ProposeTxLists(ctx, txLists []types.Transactions)` (`proposer.go:275-278`) → `txBuilder.Build(ctx, proposalTxLists)` whose signature is `Build(ctx context.Context, txBatch []types.Transactions)` (`proposer/transaction_builder/blob.go:49-52`). There is no parameter for per-block timestamps, anchors, coinbase, or parent hash.
- Manifest fields are synthesised from L1/L2 heads at build time: `anchorBlockNumber := l1Head.Number.Uint64()` (`blob.go:65`), `gasLimit := l2Head.GasLimit` minus `consensus.AnchorV3V4GasLimit` (`blob.go:72-75`), and per block `Timestamp: l1Head.Time + uint64(i), Coinbase: b.l2SuggestedFeeRecipient, AnchorBlockNumber: anchorBlockNumber, GasLimit: gasLimit, Transactions: txs` (`blob.go:87-93`).
- Propose input: `Deadline: common.Big0`, `BlobStartIndex: 0`, `NumForcedInclusions: math.MaxUint16` with the comment "We try to include all the forced inclusions in the source manifest" (`blob.go:110-119`).
- Landing timing: a timer (`--epoch.interval`, else random 12-120 s, `proposer.go:348-363`); the "one propose per L1 block" rule is handled reactively: `if state.LastProposalBlockId.Cmp(l1Head.Number) >= 0 { ... p.rpc.WaitL1Header(ctx, l1Head.Number+1) }` (`proposer.go:312-316`). Block cap: `if len(proposalTxLists) > manifest.ProposalMaxBlocks` (192) with the comment "Proposer intentionally keeps the stricter Shasta cap. It is below the Unzen derivation-source cap" (`proposer.go:318-326`; `bindings/manifest/manifest.go:17-20`).
- Preconf awareness is limited to the operator gate: `shouldPropose` compares the whitelist's current operator to `p.proposerAddress` (`proposer.go:393-416`); `GetPreconfWhiteListOperator` returns `opInfo.SequencerAddress` (`pkg/rpc/methods.go:916-935`). `grep -n "preconf\|p2p\|gossip" proposer/*.go proposer/transaction_builder/*.go` returns only these lines.

### 1.2 Rust proposer (`packages/taiko-client-rs/crates/proposer/`)

- `EngineBuildContext { anchor_block_number, parent_block_number, timestamp, gas_limit }` is one snapshot for the whole proposal (`proposer/src/proposer.rs:55-64`); `from_chain_heads` sets `anchor_block_number: l1_head.header.number` and `timestamp: l1_head.header.timestamp` (`proposer.rs:73-95`, lines 87 and 89).
- Pool mode: `tx_pool_content_with_min_tip(... max_transactions_lists: 1 ...)` (`proposer.rs:329-373`, line 351).
- Engine mode: builds one block through `engine_forkchoiceUpdated` with `tx_list: None` ("let the node select transactions from its mempool", `proposer.rs:440-517`, line 495), anchor = L1 latest (`:463`), timestamp = L1 head timestamp (`:467`), then extracts the payload's transactions with `.skip(1) // Skip anchor transaction` (`proposer.rs:522-600`, line 576). This is a fresh block built on the local L2 head, not a gossiped preconfirmed block.
- Builder: `build(&self, txs_lists: TransactionLists, ctx: EngineBuildContext)` (`proposer/src/transaction_builder.rs:101-105`); cap `if txs_lists.len() > DERIVATION_SOURCE_MAX_BLOCKS` (192) (`:110-117`); per block `timestamp: block_timestamp` where `let block_timestamp = timestamp + index as u64;` (`:131`), same `anchor_block_number` for every block (`:144`). The builder's own comment admits the timing coupling: "blocks whose index exceeds the proposal's actual L1 inclusion delay trip the driver's upper bound (timestamp <= inclusion timestamp), which cannot be known at build time" (`:125-130`).
- Propose input `deadline: U48::ZERO ... numForcedInclusions: u16::MAX` (`transaction_builder.rs:177-184`).
- Landing timing: fixed interval with `interval.set_missed_tick_behavior(MissedTickBehavior::Delay)` and the comment "the inbox accepts at most one proposal per L1 block, so burst ticks only revert" (`proposer.rs:173-177`). Operator gate `precheck_current_preconf_operator` (`:272-288`) plus the client-side "forced inclusion is permissionless" bypass (`:291-325`, `:669-683`).

### 1.3 Repo-wide check

Excluding tests, the only sites that construct a `DerivationSourceManifest`/`BlockManifest` for **submission** are `blob.go:55,87` and `transaction_builder.rs:120,141`; the remaining hits are the drivers' *decoding/default* paths (`driver/chain_syncer/event/syncer.go:350`; `crates/driver/src/derivation/pipeline/shasta/pipeline/mod.rs:151,699,759`). No code path reads gossiped envelopes, `L1Origin` rows, or the unsafe head to build a manifest.

## 2. The in-repo "preconf drivers" are servers for an external block builder

### 2.1 Go (`packages/taiko-client/driver/preconf_blocks/`)

- Routes: `POST /preconfBlocks`, `GET /status`, `GET /ws`, `GET /healthz` (`server.go:261-267`), JWT-protected (`cmd/flags/driver.go:39-44`), enabled by `--preconfirmation.serverPort` (`:33-38`).
- Request body: `ExecutableData{ParentHash, FeeRecipient, Number, GasLimit, Timestamp, Transactions (RLP then zlib), ExtraData, BaseFeePerGas}` plus `EndOfSequencing *bool`, `IsForcedInclusion *bool` (`api.go:30-49`). **The caller supplies everything**, including `ExtraData` (which encodes the proposal id, see §4.2) and the compressed tx list whose first element must be the anchor transaction: `return errors.New("empty transactions list, missing anchor transaction")` (`server.go:990`), `s.anchorValidator.ValidateAnchorTx(txs[0])` (`:993`).
- `ValidateAnchorTx` checks only recipient, golden-touch sender and method name (`prover/anchor_tx_validator/anchor_tx_validator.go:44-77`). Nothing checks the anchor's `anchorBlockNumber` against L1 head, `MAX_ANCHOR_OFFSET`, or monotonicity at preconf time.
- The node records the preconf block with `L1BlockHeight: nil, L1BlockHash: common.Hash{}` and `IsForcedInclusion: envelope.IsForcedInclusion` (`driver/chain_syncer/event/blocks_inserter/common.go:772-779`): the anchor block number lives only inside the anchor tx calldata the external caller built.
- Slot gating on the build API only: `CheckLookaheadHandover(s.rpc.L1Beacon.CurrentSlot())` (`api.go:163`; `server.go:1082-1110`), which allows the current operator in slots `[0, 32-handoverSkipSlots)` and the next operator in `[24, 32)` (`lookahead.go:70-100`, `threshold := w.slotsPerEpoch - handoverSkipSlots` at `:72`; default 8, `driver/driver.go:37`, `cmd/flags/driver.go:52-58`).
- Handover: Go has its own loop that, on becoming sequencer, requests the previous operator's EOS block over P2P (`driver.go:381-443`, `PublishL2EndOfSequencingRequest` at `:424-427`) and pushes `{currentEpoch, endOfSequencing:true}` on `/ws` (`server.go:1611-1625`; `api.go:298-307`). EOS itself is just a flag on the request (`api.go:48`, `:301`).
- Insert → sign block hash → `SetL1OriginSignature` → build envelope → cache → `PublishL2Payload` (`api.go:203`, `:244-282`).

### 2.2 Rust (`packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/`)

- Same request shape: `BuildPreconfBlockRequest { executable_data, end_of_sequencing, is_forced_inclusion }`, `ExecutableData { parent_hash, fee_recipient, block_number, gas_limit, timestamp, transactions, extra_data, base_fee_per_gas }` (`src/api/types.rs:7-40`).
- `build_preconf_block` (`src/api/service/handlers.rs:60-231`): `ensure_node_signer_whitelisted()` (`:98`), `validate_request_payload` (`:101`, → `validate_execution_payload_for_preconf`, `payload_build.rs:88-99`), which requires the first tx to be an anchor (`src/importer/validation.rs:72-88`) validated by `validate_anchor_transaction` = recipient, chain id, golden-touch sender, `anchorV4` selector only (`crates/protocol/src/shasta/anchor.rs:249-291`); then `submit_preconfirmation_payload(PreconfPayload::new(driver_payload, data.parent_hash))` (`:109`), sign, publish, and on EOS `record_end_of_sequencing(epoch, block_hash)` (`:202-225`).
- The driver payload is built with `l1_block_height: None ... anchor_transaction: None` (`src/payload.rs:14-40`, lines 31 and 36): again, the anchor number is opaque to the node.
- **No slot/window check at all** on the Rust build API (`grep -n "slot\|handover\|lookahead" handlers.rs` matches only the EOS epoch derivation at `:202-220`). The crate states why: "Rust whitelist driver lacks lookahead-aware logic and must rely on a coarser time-based heuristic" (`src/api/service/mod.rs:49-53`, `HAND_OVER_WINDOW_SLOTS = 8`, used only for shutdown safety).
- Handover ownership is explicitly external: "This node only ever *serves* EOS requests; it never publishes one. ... Here Catalyst owns handover and supplies the build `parent_hash` explicitly, so this driver has no handover loop and never needs to request EOS blocks — it only answers peers that do." (`src/importer/mod.rs:174-184`).

## 3. What the repo says about the external component

- The string "Catalyst" occurs in exactly three source comments: `whitelist-preconfirmation-driver/src/importer/mod.rs:182` ("Catalyst owns handover and supplies the build `parent_hash`"), `src/cache.rs:104` ("The Catalyst sync gate only opens when the reported value equals the execution head"), and `src/api/service/tests.rs:134` ("the Catalyst sync gate compares the reported value"). The only other hit, `CHANGELOG.md:76`, is an unrelated website ecosystem entry.
- No README, AGENTS.md, docs page, config struct, CLI flag, or protocol document names the sequencer software, its repository, or its proposal algorithm (`grep -rniE "catalyst|taiko-preconf|preconf-avs|external sequencer"` over the tree, excluding `node_modules`, finds nothing else). `packages/protocol/docs/Derivation.md` describes only what a node does with a landed proposal; it never mentions who builds it.
- `taiko-client-rs/docs/agents/whitelist-preconfirmation-invariants.md:143` states only that "Protocol contracts define proposer/lookahead assumptions that preconf clients must honor."

So the question "how does the operator assemble the manifest" cannot be answered from the code; what *can* be derived is the set of constraints the external component must satisfy for its preconfirmed blocks to survive the landing.

## 4. The implicit contract the external component must satisfy (reconstructed)

### 4.1 Per-block `anchorBlockNumber` is fixed at preconf time, inside the anchor tx

At preconf time the caller builds the `anchorV4` transaction itself (§2). At landing, the Go driver rebuilds every block from the manifest: `anchorBlockID = new(big.Int).SetUint64(blockInfo.AnchorBlockNumber)` (`blocks_inserter/common.go:478`), fetches that L1 header for `Hash()`/`Root` (`:492-498`), and calls `anchorConstructor.AssembleAnchorV4Tx(ctx, parent, anchorBlockID, anchorBlockHeaderHash, anchorBlockHeaderRoot, meta.GetEventData().EndOfSubmissionWindowTimestamp, blockID, baseFee)` (`:508-517`). The preconfirmed block is kept only if `block.Transactions()[0].Hash() == anchorTx.Hash()` (`common.go:361`), so the manifest's `anchorBlockNumber` for block *i* **must equal** the number the sequencer anchored to when it built block *i*. Neither node validates that number at preconf time (§2), so bounds are enforced only on landing: `anchorBlockNumber < parentAnchorBlockNumber`, `> originBlockNumber` (= landing block − 1, `Inbox.sol:609-616`), or `< originBlockNumber − MAX_ANCHOR_OFFSET` (128 Hoodi / 512 mainnet) invalidate the whole source (`driver/chain_syncer/event/derivation/source_fetcher.go:347-402`; `Derivation.md:226-236`; `bindings/manifest/manifest.go:21-24`), and a non-forced source whose anchors never advance past the parent's is also defaulted (`source_fetcher.go:404-417`).

### 4.2 Every other header field must be replayed byte-for-byte

`isKnownCanonicalBlock` compares parent hash, anchor tx hash, coinbase, mixDigest, number, `GasLimit == meta.GasLimit + AnchorV3V4GasLimit`, `Time == meta.Timestamp`, `Extra == meta.ExtraData`, base fee, and the `BuildPayloadArgsID` (`common.go:293-454`; mismatch logs at `:361,369,418,422,426,440`). Therefore the manifest's `coinbase`, `gasLimit` (parent limit minus 1,000,000), `timestamp`, and `transactions` per block must be exactly what the sequencer used. `ExtraData` is derived on landing as `EncodeShastaExtraData(basefeeSharingPctg, proposalId)` (`common.go:523`), so the sequencer must **predict the proposal id** its blocks will land under when it fills `extraData` at preconf time (the Go API only checks the parent's id is not older than the last seen event, `api.go:118-140`; the Rust proposer's engine mode shows the expected rule `parent id + 1`, `proposer.rs:689-697`). If any block fails, the derived block replaces it and `PreconfChainReorged = true` (`blocks_inserter/inserter.go:169-206`, `:275`).

### 4.3 Timestamps

Landing requires every block in `[max(parent.ts + 1, proposal.ts − TIMESTAMP_MAX_OFFSET, SHASTA_FORK_TIME), proposal.ts]` where `proposal.ts = block.timestamp` of the landing L1 block (`Inbox.sol:611`; `source_fetcher.go:284-345`; `Derivation.md:218-224`; `TIMESTAMP_MAX_OFFSET = 12 × 512 = 6144 s` mainnet, `manifest.go:25-28`, `Derivation.md:362-373`). Since preconf blocks carry real timestamps chosen by the sequencer, the external component must land each source within 6144 s of its oldest block and never after a block it preconfirmed with a future timestamp. Neither in-repo proposer models this (they stamp `l1Head.time + i`).

### 4.4 Forced inclusions

- On L1, `propose` first consumes the contiguous due prefix of the queue: `block.timestamp < timestamp + _forcedInclusionDelay` breaks the count (`Inbox.sol:650-658`), `require(_numForcedInclusionsRequested >= dueToProcess, UnprocessedForcedInclusionIsDue())` (`:662-664`), `toProcess = min(requested, available, 10)` (`:666-667`, `MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10` at `:65`), forced sources first, the proposer's blob slice last (`:595-599`).
- Each forced source derives to exactly one block (`source_fetcher.go:129-142`; `Derivation.md:166`) whose `timestamp`, `coinbase`, `anchorBlockNumber`, `gasLimit` are overwritten by the protocol (lower bound, `proposal.proposer`, parent's anchor, parent's gas limit; `Derivation.md:198-212`), with the driver keying on `Sources[i].IsForcedInclusion` (`syncer.go:289`).
- At preconf time the only hook is the `isForcedInclusion` flag on the build request (`api.go:49`; `types.rs:15`), which the node stores in `L1Origin` (`common.go:778`) and gossips; **no node code checks that a flagged preconf block corresponds to a queued forced inclusion or has the protocol-forced field values.** Hence "reserving heights" means: the external component must predict, for its intended landing block, how many queue entries will be due (a function of the landing L1 timestamp), build those heights as single-tx blocks with `coinbase = proposer`, parent anchor, parent gas limit, and `timestamp = lower bound` (which itself depends on the landing timestamp unless `parent.ts + 1` dominates), then place its own blocks after them. Both in-repo proposers simply request `0xffff` (§1) and never build such blocks.

### 4.5 When to land

- One `propose` per L1 block: `require(block.number > _lastProposalBlockId, CannotProposeInCurrentBlock())` (`Inbox.sol:590`).
- Per-source cap 192 pre-Unzen / 768 post-Unzen, selected by the landing block's timestamp (`pkg/rpc/engine_unzen.go:25-31`; `source_fetcher.go:143-152`; `Derivation.md:163-165`); both proposers self-cap at 192 (§1).
- Epoch gate uses the **landing** block's epoch: `checkProposer` requires `operator == _getOperatorForEpoch(epochStartTimestamp(0))` (`PreconfWhitelist.sol:127-141`, line 136). Nothing in the repo lands an operator's blocks after its epoch ends, so the external component must land before the boundary; Go's build window `[0,24)` for the current operator vs. `[24,32)` for the next (§2.1) is the only in-repo notion of "handover", and it is enforced only on the local build API, never on gossip receipt or on L1.
- `deadline` is unused (`0`, §1; `Inbox.sol:764-766`).

## 5. Go vs Rust, docs vs code

| Topic | Go | Rust | Docs |
| --- | --- | --- | --- |
| Proposer input | txpool via `GetPoolContent` (`proposer.go:188-196`) | txpool (`proposer.rs:329-373`) or one engine-built block (`:522-600`) | `Derivation.md` silent on proposers |
| Per-block anchor in manifest | one value for all blocks (`blob.go:65,90`) | one value for all blocks (`transaction_builder.rs:106,144`) | per-block field validated (`Derivation.md:226-236`) |
| Timestamps | `l1Head.Time + i` (`blob.go:88`) | `ctx.timestamp + index` (`:131`) | must fit `[lower, landing.ts]` (`:218-224`) |
| Build-API slot gating | yes (`api.go:163`; `server.go:1082-1110`) | none (`handlers.rs`) | n/a |
| Handover / EOS request | in-repo loop (`driver.go:381-443`) | "Catalyst owns handover" (`importer/mod.rs:174-184`) | n/a |
| Who assembles the landed manifest from preconf blocks | nobody | nobody | not described |

The prior synthesis (`packages/protocol/docs/Etna/00-current-protocol-summary.md:304-305`, `:351`) already records that the proposers never read preconfirmed blocks and that Rust defers handover to Catalyst; it does not (and cannot from this tree) describe the external assembly algorithm.

## 6. What is missing from the repository

1. The external sequencer/proposer ("Catalyst") source, interface spec, or design doc: how it selects `parent_hash`, anchor L1 block, timestamps, extraData proposal id, EOS placement, forced-inclusion heights, and landing time.
2. Any in-repo path from gossiped/unsafe blocks to `Inbox.propose`: no builder accepts per-block `{timestamp, anchorBlockNumber, coinbase, gasLimit}` (`blob.go:49-52`; `transaction_builder.rs:101-108`).
3. Any preconf-time validation of anchor block number, timestamp bounds, forced-inclusion correctness, or proposal-id prediction (§2, §4); these are enforced only retroactively on landing.
4. Any L1 or node-level linkage between gossiped blocks and the landed proposal; landing replaces conflicting preconfirmed blocks unconditionally (`inserter.go:275`).

A permissionless successor therefore has to specify the off-chain assembler outright (or eliminate it, e.g. by making preconfirmations carry the manifest data that landing will replay), because the current codebase only pins down its *output constraints*, not the component.

## Claims index

| # | Claim | Evidence |
| --- | --- | --- |
| 1 | Go proposer reads only the L2 txpool | `packages/taiko-client/proposer/proposer.go:188-196` |
| 2 | Go `MaxTxListsPerEpoch` default 1 | `packages/taiko-client/cmd/flags/proposer.go:56-62` |
| 3 | Go builder accepts only `[]types.Transactions` | `packages/taiko-client/proposer/proposer.go:275-278`; `packages/taiko-client/proposer/transaction_builder/blob.go:49-52` |
| 4 | Go manifest: anchor = L1 head, timestamp = `l1Head.Time + i`, coinbase = flag, gasLimit = parent − anchor gas | `blob.go:65,72-75,87-93` |
| 5 | Go propose input: deadline 0, `NumForcedInclusions = MaxUint16` | `blob.go:110-119` |
| 6 | Go one-per-L1-block handling via `WaitL1Header` | `proposer.go:312-316` |
| 7 | Go self-cap 192 blocks | `proposer.go:318-326`; `packages/taiko-client/bindings/manifest/manifest.go:17-20` |
| 8 | Go proposer timer 12-120 s random / `--epoch.interval` | `proposer.go:348-363`; `cmd/flags/proposer.go:28-34` |
| 9 | Go operator gate compares `sequencerAddress` to proposer address | `proposer.go:393-416`; `packages/taiko-client/pkg/rpc/methods.go:916-935` |
| 10 | Rust `EngineBuildContext` is one snapshot per proposal; anchor/timestamp from L1 head | `packages/taiko-client-rs/crates/proposer/src/proposer.rs:55-64,73-95` (87, 89) |
| 11 | Rust pool mode `max_transactions_lists: 1` | `proposer.rs:329-373` (351) |
| 12 | Rust engine mode builds one fresh block (`tx_list: None`, anchor L1 latest, skip anchor tx) | `proposer.rs:440-517` (463, 467, 495), `:522-600` (576) |
| 13 | Rust builder signature and 192 cap | `packages/taiko-client-rs/crates/proposer/src/transaction_builder.rs:101-108,110-117` |
| 14 | Rust per-block timestamp `timestamp + index`, same anchor for all; comment on inclusion-delay coupling | `transaction_builder.rs:125-131,144` |
| 15 | Rust propose input `numForcedInclusions: u16::MAX` | `transaction_builder.rs:177-184` |
| 16 | Rust interval loop, "at most one proposal per L1 block" | `proposer.rs:173-177` |
| 17 | Rust operator gate and forced-inclusion permissionless bypass | `proposer.rs:272-288,291-325,669-683` |
| 18 | Only non-test manifest construction sites are the two proposers | `blob.go:55,87`; `transaction_builder.rs:120,141`; decoding-side hits `packages/taiko-client/driver/chain_syncer/event/syncer.go:350`, `packages/taiko-client-rs/crates/driver/src/derivation/pipeline/shasta/pipeline/mod.rs:151,699,759` |
| 19 | Go preconf server routes and flags | `packages/taiko-client/driver/preconf_blocks/server.go:261-267`; `packages/taiko-client/cmd/flags/driver.go:33-58` |
| 20 | Go build request body supplied by caller incl. extraData, EOS and forced flags | `packages/taiko-client/driver/preconf_blocks/api.go:30-49` |
| 21 | Go requires caller-built anchor tx; validator checks only recipient/sender/method | `server.go:990,993`; `packages/taiko-client/prover/anchor_tx_validator/anchor_tx_validator.go:44-77` |
| 22 | Go preconf L1Origin has `L1BlockHeight: nil`, stores forced flag | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:772-779` |
| 23 | Go build-API slot gating; window split; default 8 skip slots | `api.go:163`; `server.go:1082-1110`; `packages/taiko-client/driver/preconf_blocks/lookahead.go:70-100` (72); `packages/taiko-client/driver/driver.go:37` |
| 24 | Go handover loop requests EOS over P2P; `/ws` push | `driver.go:381-443`; `server.go:1611-1625`; `api.go:298-307` |
| 25 | Go insert → sign → gossip flow | `api.go:203,244-282` |
| 26 | Rust request types | `packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/src/api/types.rs:7-40` |
| 27 | Rust `build_preconf_block` flow | `.../src/api/service/handlers.rs:60-231` (98, 101, 109, 202-225); `.../src/api/service/payload_build.rs:30-47,88-99` |
| 28 | Rust preconf validation requires anchor tx; `validate_anchor_transaction` checks only recipient/chain/sender/selector | `.../src/importer/validation.rs:72-88`; `packages/taiko-client-rs/crates/protocol/src/shasta/anchor.rs:249-291` |
| 29 | Rust driver payload `l1_block_height: None`, `anchor_transaction: None` | `.../src/payload.rs:14-40` (31, 36) |
| 30 | Rust build API has no slot gating; "lacks lookahead-aware logic" | `handlers.rs` (grep); `.../src/api/service/mod.rs:49-53` |
| 31 | "Catalyst owns handover and supplies the build parent_hash" | `.../src/importer/mod.rs:174-184` |
| 32 | Only three "Catalyst" mentions in source; none in docs/config | `importer/mod.rs:182`; `.../src/cache.rs:104`; `.../src/api/service/tests.rs:134`; unrelated `CHANGELOG.md:76` |
| 33 | Rust invariants doc defers to protocol contracts for proposer assumptions | `packages/taiko-client-rs/docs/agents/whitelist-preconfirmation-invariants.md:143` |
| 34 | Landing rebuilds anchor tx from manifest `anchorBlockNumber` + L1 header | `blocks_inserter/common.go:478,492-498,508-517` |
| 35 | Canonical-match compares anchor tx hash, coinbase, gas limit, timestamp, extraData, payload id | `common.go:293-454` (361, 369, 418, 422, 426, 440) |
| 36 | ExtraData derived from `basefeeSharingPctg` + proposal id | `common.go:523`; parent-id check `api.go:118-140`; expected `parent+1` `proposer.rs:689-697` |
| 37 | Match keeps blocks and only updates L1Origin; mismatch inserts and sets `PreconfChainReorged` | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/inserter.go:169-206,275` |
| 38 | Anchor validation rules (monotonic, ≤ origin, ≥ origin − MAX_ANCHOR_OFFSET, must advance for non-forced) | `packages/taiko-client/driver/chain_syncer/event/derivation/source_fetcher.go:347-417`; `packages/protocol/docs/Derivation.md:226-236`; `manifest.go:21-24` |
| 39 | Timestamp rule and `TIMESTAMP_MAX_OFFSET = 6144 s` mainnet | `source_fetcher.go:284-345`; `Derivation.md:218-224,362-373`; `manifest.go:25-28`; `packages/protocol/contracts/layer1/core/impl/Inbox.sol:611` |
| 40 | Forced inclusion consumption: due prefix, `>= dueToProcess`, ≤ 10, forced first | `Inbox.sol:65,590-599,650-671` |
| 41 | Forced source = exactly one block; protocol overwrites its fields; driver keys on flag | `source_fetcher.go:129-142`; `Derivation.md:166,198-212`; `syncer.go:289` |
| 42 | One propose per L1 block; `originBlockNumber = block.number − 1`; `deadline` check | `Inbox.sol:590,609-621,764-766` |
| 43 | Block cap 192/768 keyed on landing timestamp | `packages/taiko-client/pkg/rpc/engine_unzen.go:25-31`; `source_fetcher.go:143-152`; `Derivation.md:163-165` |
| 44 | Epoch gate evaluated at the landing block | `packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol:127-141` (136) |
| 45 | Prior summary already records proposers never read preconf blocks and Rust defers to Catalyst | `packages/protocol/docs/Etna/00-current-protocol-summary.md:304-305,351` |
