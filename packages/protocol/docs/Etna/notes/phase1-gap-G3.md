# G3: How does forced-inclusion timing interact with a preconfirmed chain? Due-ness is evaluated at landing (block.timestamp ≥ saveTs + 576 s), due entries (≤10, one block each, timestamp = lowerBound, coinbase = proposer) are prepended before the proposer's source, and both proposers request u16::MAX inclusions (draining not-yet-due ones early). No summary explains how the preconfer reserves those heights, whether the IsForcedInclusion flag on gossiped blocks is ever checked against the queue, what happens when an entry becomes due mid-epoch after blocks were preconfirmed, or what the real censorship bound is now that permissionlessInclusionMultiplier is dead code and the queue can be voided by init3.

All paths are relative to `/home/user/taiko-mono`. `Inbox.sol` = `packages/protocol/contracts/layer1/core/impl/Inbox.sol`; `Derivation.md` = `packages/protocol/docs/Derivation.md`; Go = `packages/taiko-client`; Rust = `packages/taiko-client-rs/crates`.

## Short answer

1. **The preconfer does not reserve heights, and nothing in this repo does.** Both in-repo proposers build their manifest from the L2 txpool (never from preconfirmed blocks) and never read the forced-inclusion queue before proposing; the only queue read in either client is the Rust proposer's client-side "permissionless" precheck. The preconf block-building API accepts an `IsForcedInclusion` flag from its (external) caller and does nothing with it except log it, write it into the block's `L1Origin`, and re-gossip it. No production code in the monorepo ever sets it to `true`.
2. **The flag is never checked against the queue** in either driver. Gossip validation (`ValidateExecutionPayload`) checks timestamp, fee recipient, gas, base fee, extra data, tx-list shape and anchor tx only.
3. **When a proposal lands, forced sources are derived first, at the heights the preconfer already used.** Both drivers reconcile the derived blocks against existing blocks by an 8-byte payload-args ID computed from parent, timestamp, fee recipient, mix hash, tx-list hash and extra data. A forced block (timestamp = lower bound, coinbase = L1 proposer, user txs) will not match a block the preconfer built at that height, so the whole preconfirmed suffix is reorged out. Because both proposers send `numForcedInclusions = u16::MAX`, this happens whenever the queue is non-empty at landing, due or not — including entries saved in the same L1 block as the proposal. "Due mid-epoch" changes nothing on the client side: due-ness only raises the contract's *minimum* (`UnprocessedForcedInclusionIsDue`), and `u16::MAX` always satisfies it.
4. **The real bound is conditional, not hard.** An entry is guaranteed to be consumed by the first proposal that lands at L1 time ≥ save + 576 s *if* it is among the first 10 queue entries (else one more proposal per 10 entries, each in a distinct L1 block), but only a whitelisted operator for the current epoch can call `propose`; `permissionlessInclusionMultiplier` is stored, validated and never read; `isOldestForcedInclusionDue` is never called; the owner voided the queue once via `init3`; and an entry whose blob expires before any proposal lands derives to an empty default block. There is no unconditional inclusion deadline.

Docs/code and Go/Rust discrepancies are listed in §6.

## 1. The on-chain timing rule

**Clock starts at save.** `saveForcedInclusion` (Inbox.sol:431-443) calls `LibForcedInclusion.saveForcedInclusion` (LibForcedInclusion.sol:42-72), which stamps the slice via `LibBlobs.validateBlobReference` (LibBlobs.sol:37-55):

```solidity
        return BlobSlice({
            blobHashes: blobHashes,
            offset: _blobReference.offset,
            timestamp: uint48(block.timestamp)
        });
```
(LibBlobs.sol:50-54) and enqueues at `$.queue[$.tail++] = inclusion;` (LibForcedInclusion.sol:64). Saving reverts until proposal 1 exists (Inbox.sol:432-433).

**Due-ness is evaluated at landing, only over the first 10 entries.** `_consumeForcedInclusions` (Inbox.sol:637-675):

```solidity
            uint256 available = tail - head;
            uint256 dueToProcess;
            uint256 maxToInspect = available.min(MAX_FORCED_INCLUSIONS_PER_PROPOSAL);
            for (uint256 i; i < maxToInspect; ++i) {
                IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[head + i];
                uint256 timestamp = inclusion.blobSlice.timestamp;
                if (timestamp == 0 || block.timestamp < timestamp + uint256(_forcedInclusionDelay))
                {
                    break;
                }
                ++dueToProcess;
            }
            require(
                _numForcedInclusionsRequested >= dueToProcess, UnprocessedForcedInclusionIsDue()
            );

            uint256 toProcess = _numForcedInclusionsRequested.min(available)
                .min(MAX_FORCED_INCLUSIONS_PER_PROPOSAL);
```
(Inbox.sol:650-667). `MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10` with the rationale "Must be < 12 to avoid derived block timestamps drifting into the future when proposals happen every L1 slot (Derivation enforces 1s block times)" (Inbox.sol:62-65). Mainnet: `forcedInclusionDelay: 576 seconds` commented "1.5 epochs. Makes sure the proposer is not surprised by a forced inclusion landing on their window." (MainnetInbox.sol:46-47); an epoch is `12 * 32 = 384 s` (packages/protocol/contracts/layer1/preconf/libs/LibPreconfConstants.sol:19-20). The delay is a `uint16` (IInbox.sol:41), so ≤ 65,535 s.

**Order and payout.** Forced sources fill `sources[0..toProcess)` with `isForcedInclusion = true` (Inbox.sol:703-706: `_sources[i] = IInbox.DerivationSource(true, inclusion.blobSlice);`), head advances (`$.head = head_;` :719), fees go to `msg.sender` (:710), and the proposer's own blob is appended last: `result.sources[result.sources.length - 1] = DerivationSource(false, LibBlobs.validateBlobReference(_input.blobReference));` (:598-599). Consumption runs *before* the proposer gate: `_proposerChecker.checkProposer(msg.sender, _lookahead)` (:601-603, preceded by the comment "Permissionless proposing is temporarily disabled."). `PreconfWhitelist.checkProposer` requires `operator == _proposer` for the current epoch and returns `endOfSubmissionWindowTimestamp_ = 0` (packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol:127-141; Derivation.md:29 "`0` for whitelisted preconfirmations"). One `propose` per L1 block (Inbox.sol:590).

**What a forced source derives to.** Exactly one block or it is defaulted (Derivation.md:166; Rust `validate_forced_inclusion_manifest`, crates/driver/src/derivation/pipeline/shasta/pipeline/mod.rs:147-160; Go source_fetcher.go:135-146). All metadata is overwritten before validation (Derivation.md:198-212): timestamp = lower bound, coinbase = `proposal.proposer`, anchor and gas limit inherited from the parent, transactions user-supplied. `lowerBound = max(parent.metadata.timestamp + 1, proposal.timestamp - TIMESTAMP_MAX_OFFSET, SHASTA_FORK_TIME)` (Derivation.md:223; mainnet `TIMESTAMP_MAX_OFFSET = 6144`, :371). Implemented in Rust `apply_inherited_metadata` (crates/driver/src/derivation/pipeline/shasta/validation.rs:234-255: `block.timestamp = lower_bound; block.coinbase = input.proposer; block.anchor_block_number = input.anchor_block_number; block.gas_limit = parent_gas_limit; parent_ts = lower_bound;`) and Go `ApplyInheritedMetadata` (driver/chain_syncer/event/derivation/source_fetcher.go:466-491), invoked for forced sources before validation (Go driver/chain_syncer/event/syncer.go:328-336; Rust pipeline/payload.rs:300-302 `if is_forced_inclusion || manifest_is_default(...) { state.apply_inherited_metadata(...) }`). Forced sources are exempt from the "anchor must advance" rule (Derivation.md:236; validation.rs:181; source_fetcher.go:407). Coinbase for forced blocks is always `proposal.proposer` (Derivation.md:246).

## 2. Both proposers request `u16::MAX`, so due-ness is irrelevant to them

Go: `// We try to include all the forced inclusions in the source manifest. NumForcedInclusions: math.MaxUint16,` (proposer/transaction_builder/blob.go:117-118). Rust: `// Include all forced inclusions in the source manifest. numForcedInclusions: u16::MAX,` (crates/proposer/src/transaction_builder.rs:181-182; asserted at :365). The Go client previously sent `0` (packages/taiko-client/CHANGELOG.md:70).

Consequence, confirmed by tests: with 12 entries queued one second earlier and `numForcedInclusions = type(uint16).max`, the proposal carries 11 sources and head moves from 0 to 10 (test/layer1/core/inbox/InboxPropose.t.sol:268-294, `test_propose_capsForcedInclusionProcessingToMaxForcedInclusionsPerProposal`); `test_propose_processesForcedInclusionBeforeDue` asserts consumption while `block.timestamp < inclusionTimestamp + forcedInclusionDelay` (:232-266, assertion at :257-261). So the 576 s delay is a floor on the *obligation*, not a minimum age: any entry in the first ten at landing time is consumed by the next proposal, including one saved in the same L1 block (the contract only requires `block.number > _lastProposalBlockId` between proposals, Inbox.sol:590, and reads `tail` at :648). The "proposer is not surprised" intent in MainnetInbox.sol:46 is therefore voluntarily discarded by both clients.

## 3. How the preconfer "reserves" heights: it does not

**The in-repo proposers never look at the queue or at preconfirmed blocks.**
- Go pulls tx lists from the pool (`p.rpc.GetPoolContent(` proposer/proposer.go:188, inside `fetchPoolContent` :169-200) and builds manifest blocks with `Timestamp: l1Head.Time + uint64(i)`, `Coinbase: b.l2SuggestedFeeRecipient`, `AnchorBlockNumber: anchorBlockNumber` (blob.go:60-94). Gating is "am I the current epoch operator" (proposer.go:393-416).
- Rust: `EngineBuildContext::from_chain_heads` uses `timestamp: l1_head.header.timestamp` (crates/proposer/src/proposer.rs:73-91); `fetch_pool_content` calls `tx_pool_content_with_min_tip` (:329-338) with `tx_list: None` and `is_forced_inclusion: false` in the engine build (:495-501); manifest blocks use `timestamp + index` and `self.l2_suggested_fee_recipient` (transaction_builder.rs:118-150).
- Queue reads: Go has none outside generated bindings (grep `GetForcedInclusion`/`ForcedInclusionState` in `packages/taiko-client` → only `bindings/`). Rust has exactly one, `forced_inclusion_allows_permissionless` (proposer.rs:291-325), used by `precheck_current_preconf_operator` (:272-288) — a client-side rule the contract does not honor (see §5).

**The block-build API only plumbs the flag.**
- Go `POST /preconfBlocks`: `IsForcedInclusion *bool` in the request (driver/preconf_blocks/api.go:49), read at :144, logged at :157, placed in the envelope `envelopes = []*preconf.Envelope{{Payload: executablePayload, Signature: nil, IsForcedInclusion: isForcedInclusion}}` (:200), and written into `L1Origin{... IsForcedInclusion: envelope.IsForcedInclusion, BuildPayloadArgsID: payloadID}` (driver/chain_syncer/event/blocks_inserter/common.go:772-781). The only pre-insert checks are the lookahead window (`CheckLookaheadHandover`, api.go:160-166 / server.go:1082-1111) and `ValidateExecutionPayload` (server.go:956-996), which checks timestamp ≠ 0, fee recipient, gas limit, base fee, extra data, single tx list, size, zlib/RLP decode, and the anchor tx — nothing about the queue.
- Rust: `BuildPreconfBlockRequest { executable_data, end_of_sequencing, is_forced_inclusion }` (crates/whitelist-preconfirmation-driver/src/api/service/handlers.rs:69), logged (:38-53, :76), passed to `driver_payload_from_request` (:106) → `build_driver_payload(..., is_forced_inclusion.unwrap_or(false), ...)` (api/service/payload_build.rs:33-42) → `PayloadAttributesInput { ... is_forced_inclusion, ... }` (payload.rs:18-33). The importer path is identical (importer/cache_import.rs:30).
- Gossip encodes it as `flags1 |= 0x01` (codec.rs:203) and decodes `(flags1 & 0x01 != 0).then_some(true)` (:258); it is re-emitted from the stored `L1Origin` when serving block requests (Go server.go:619, :726, :1029, :1385; Rust importer/ingress.rs:271) and logged on receipt (Go server.go:315; Rust network/runtime.rs:1397). Go's `Envelope.IsForcedInclusion` doc says only "signals that the block was sequenced via the forced-inclusion path" (pkg/preconf/payload.go:15-17).
- The only places the flag is `true` in the monorepo are tests (Go driver/preconf_blocks/util_test.go:23, cache_test.go:106, server_test.go:235; Rust codec.rs:353 inside `#[cfg(test)]` at :344). The producer that would set it (the external preconfirmation sequencer) is not in this repository, so whether *it* reads the queue cannot be answered from the code.
- taiko-geth (module cache `/root/go/pkg/mod/github.com/taikoxyz/taiko-geth@v1.18.1-0.20260924044618-8e98046bfd6a`) only declares `IsForcedInclusion bool ... rlp:"optional"` on `L1Origin` (core/rawdb/taiko_l1_origin.go:46) and marshals it (gen_taiko_l1_origin.go:34, :70-71); no consumer.

So: the flag is never checked against the queue, and nothing reserves heights.

## 4. What happens when an entry is (or becomes) consumable after blocks were preconfirmed

At landing the derived chain for the proposal is `[FI block 0][FI block 1]...[proposer blocks]`, each FI block at height `parent+1+i` with timestamp `max(parent.ts+1, T_land − 6144, fork)` (validation.rs:126-140; source_fetcher.go:331-344), coinbase = the L1 `msg.sender`, and the user's transactions.

**Reconciliation is by payload-args ID, so a forced block never matches a preconfirmed block at that height.**
- Go: `InsertBlocksWithManifest` calls `isKnownCanonicalProposal` on the first block (blocks_inserter/inserter.go:169-176), which re-derives every block and calls `isKnownCanonicalBlock` (common.go:216-290, :293). The ID is `miner.BuildPayloadArgs{Parent, Timestamp, FeeRecipient, Random, Withdrawals, Version, TxListHash, Extra}` (common.go:322-331), and a mismatch is rejected: `if l1Origin.BuildPayloadArgsID != [8]byte{} && !bytes.Equal(l1Origin.BuildPayloadArgsID[:], id[:]) { logUnknown("payload ID mismatch..."); return nil, false, nil }` (:438-450). On `!isKnown` the inserter falls through to `createPayloadAndSetHead` for every derived block (inserter.go:228-236) and then `latestSeenProposal.PreconfChainReorged = true` (:275).
- Rust: `detect_known_canonical_proposal` derives each block with the segment's `forced_inclusion` flag and "Any mismatch immediately aborts the fast-path and falls back to fresh payloads" (pipeline/payload.rs:588-660, esp. :623-635); `verify_canonical_block` compares `origin.build_payload_args_id != derived_block.payload.l1_origin.build_payload_args_id` (:700-706). The normal path then applies the derived payloads (pipeline/mod.rs:523-528 and payload.rs:400-412).

Therefore, if the preconfer produced blocks `N+1..N+k` and the landing proposal consumes ≥1 forced entry, derived block `N+1` is the forced block (different coinbase, timestamp and tx list) → payload-ID mismatch → the entire preconfirmed suffix is discarded and rebuilt from L1; the proposer's own transactions land shifted by the number of forced blocks with `l1Head.Time + i` timestamps. The Rust event syncer additionally drops any later preconf payload whose number is `<= head_l1_origin` (`is_stale_preconf`, crates/driver/src/sync/event.rs:395-397, applied at :1239-1253 → `PreconfSubmissionOutcome::Stale`, surfaced to the API caller as "preconfirmation block ... is stale", handlers.rs:112-117).

**"Becomes due mid-epoch" specifically.** Due-ness never triggers anything on the client side: it only sets `dueToProcess` and the revert `UnprocessedForcedInclusionIsDue` (Inbox.sol:662-664; tests InboxPropose.t.sol:111-230), which `u16::MAX` always satisfies. What actually matters is *presence* in the first ten queue slots at landing, and that includes entries saved after the preconfirmed blocks were built. Could a preconfer pre-build the forced block? All inputs except the `proposal.timestamp − 6144` term of the lower bound are known before landing (parent, proposer address, parent anchor/gas limit, the blob content, next proposal id), so it is predictable in steady state — but it would also have to predict the exact set of entries present at landing, which a same-slot `saveForcedInclusion` can change. No code in the repo attempts this.

**Blob expiry.** If no proposal lands before the entry's blob leaves the retention window, both drivers derive the forced source as an empty default block rather than stalling: Go returns the default payload on `rpc.ErrInvalidBlobBytes` (source_fetcher.go:61-66) and on every decode failure (:88-146); Rust defaults on `ManifestFetcherError::Invalid | EmptyBlobSidecars` and retries only transient errors (pipeline/mod.rs:162-200). `init3`'s NatSpec confirms this is why the June 2026 queue was voided: "their blobs have expired from the blob retention window and can no longer be derived" (Inbox.sol:248-252).

## 5. The real censorship bound

Let an entry be saved at `t_s` and sit at 0-based position `p` (from head) when a proposal lands.

- *Conditional guarantee:* any proposal landing at `block.timestamp ≥ t_s + 576` must consume it if `p < 10` (Inbox.sol:652-664); otherwise at least `⌈(p+1)/10⌉` proposals are needed, each in a distinct L1 block (:590), i.e. ≥ 12 s apart. Because the clients send `u16::MAX`, in practice it is consumed by the *first* proposal after save subject to the same position rule.
- *No unconditional guarantee:* only the current-epoch whitelisted operator can propose (Inbox.sol:601-603; PreconfWhitelist.sol:136-138), and the test `test_propose_RevertWhen_NonProposerEvenIfForcedInclusionTooOld` asserts a non-operator reverts even after `forcedInclusionDelay * permissionlessInclusionMultiplier` (InboxPropose.t.sol:296-320). `permissionlessInclusionMultiplier` is only assigned, stored and echoed (Inbox.sol:121, :172, :546) and validated `> 1` (LibInboxSetup.sol:41-44); it is never read in `propose`. The stub where it was meant to plug in is visible: `_dequeueAndProcessForcedInclusions` returns `oldestTimestamp_` (:683-684, :713) which `_consumeForcedInclusions` discards (`(, head) = ...`, :671), and its NatSpec still promises "and whether permissionless proposals are allowed" (:635-636). `LibForcedInclusion.isOldestForcedInclusionDue` (LibForcedInclusion.sol:152-170) has no caller. The Rust proposer's `forced_inclusion_is_permissionless` (`l1_timestamp > delay*multiplier + oldest`, proposer.rs:669-683) lets it *attempt* a proposal (:274-278) that the contract will reject.
- *Owner override:* `init3` sets `$.head = tail` and emits `ForcedInclusionsVoided(head, tail)` (Inbox.sol:253-258); fees stay in the contract (:251-252). It is `reinitializer(3)`, so this exact function is one-shot, but it demonstrates the owner can void the queue by upgrade.
- *Net:* inclusion time ≤ `t_s + 576 s + (wait for the next whitelisted-operator proposal) + 12 s × (⌈(p+1)/10⌉ − 1)`, with the middle term unbounded by the protocol, and zero if the queue is voided or the blob expires first. The repo's own analysis reaches the same conclusion (packages/protocol/docs/Etna/00-current-protocol-summary.md:120, :425-426; 01-threat-model.md:102 TH7).

## 6. Discrepancies

**Docs/comments vs code**
- MainnetInbox.sol:46 ("proposer is not surprised by a forced inclusion landing on their window") describes the *mandatory* rule only; both clients' `u16::MAX` (blob.go:118; transaction_builder.rs:182) consume entries at any age.
- IInbox.sol:47-48 and Inbox.sol:119-121 describe `permissionlessInclusionMultiplier` as determining "when ... proposing becomes permissionless"; no enforcement exists (Inbox.sol:601-603 comment).
- Inbox.sol:635-636 NatSpec claims the result carries "whether permissionless proposals are allowed"; `ConsumptionResult` has only `sources` (:48-50).
- Derivation.md:88 correctly states the must-request rule; it says nothing about preconfirmation interaction (no "preconf" occurrences besides :29).

**Go vs Rust**
- Permissionless precheck exists only in Rust (proposer.rs:272-288); Go is operator-only (proposer.go:393-416).
- `L1Origin.IsForcedInclusion` on *derived* blocks: Rust sets it from the source flag (`is_forced_inclusion: position.is_forced_inclusion()`, payload.rs:521) and ORs with any preconf value (`origin.is_forced_inclusion |= existing.is_forced_inclusion;`, :560). Go's derivation path builds `L1Origin{BlockID, L2BlockHash, L1BlockHeight, L1BlockHash}` without the flag (common.go:543-548) and, for known-canonical proposals, copies whatever the preconfer said (`l1Origin.IsForcedInclusion = originalL1Origin.IsForcedInclusion`, :593). So on a Go node a forced block derived from L1 carries `IsForcedInclusion = false`, on a Rust node `true`.

**Not answerable from the code:** what the external preconfirmation sequencer (the caller of `/preconfBlocks`) does with the queue — it is not in the monorepo; and whether any taiko-geth logic beyond storage consumes `IsForcedInclusion` (only the struct/marshal code was found in the module cache).

## Claims index

| # | Claim | Evidence |
|---|-------|----------|
| 1 | Forced entry timestamp = `block.timestamp` at save | packages/protocol/contracts/layer1/core/libs/LibBlobs.sol:37-55 (:53); LibForcedInclusion.sol:51, :64; Inbox.sol:431-443 |
| 2 | Due iff `block.timestamp >= ts + delay`; only first `min(available,10)` inspected; contiguous prefix counted | Inbox.sol:650-661 |
| 3 | Proposer must request ≥ `dueToProcess` else `UnprocessedForcedInclusionIsDue`; processes `min(requested, available, 10)` | Inbox.sol:662-667, :831 |
| 4 | `MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10`, "< 12 ... 1s block times" | Inbox.sol:62-65 |
| 5 | Forced sources first with `isForcedInclusion=true`; proposer's source last; fees to `msg.sender`; head advanced | Inbox.sol:598-599, :669-673, :703-706, :710, :716-719 |
| 6 | Consumption precedes `checkProposer`; "Permissionless proposing is temporarily disabled." | Inbox.sol:595-603 |
| 7 | `checkProposer` requires current-epoch operator; returns 0 window | packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol:127-141; Derivation.md:29 |
| 8 | One propose per L1 block | Inbox.sol:588-590 |
| 9 | Mainnet delay 576 s "1.5 epochs", multiplier 160 | packages/protocol/contracts/layer1/mainnet/MainnetInbox.sol:46-51; LibPreconfConstants.sol:19-20 |
| 10 | Delay is `uint16` | packages/protocol/contracts/layer1/core/iface/IInbox.sol:41 |
| 11 | Forced source must be exactly one block | Derivation.md:166; crates/driver/src/derivation/pipeline/shasta/pipeline/mod.rs:147-160; driver/chain_syncer/event/derivation/source_fetcher.go:135-146 |
| 12 | Forced block metadata overwritten: timestamp = lower bound, coinbase = proposer, anchor/gasLimit inherited | Derivation.md:198-212, :246; validation.rs:234-255; source_fetcher.go:466-491; syncer.go:328-336; pipeline/payload.rs:300-302 |
| 13 | Lower bound formula and mainnet `TIMESTAMP_MAX_OFFSET = 6144` | Derivation.md:223, :371; validation.rs:126-140; source_fetcher.go:331-344 |
| 14 | Forced sources exempt from anchor-advance rule | Derivation.md:236; validation.rs:181; source_fetcher.go:407 |
| 15 | Go proposer sends `math.MaxUint16` | packages/taiko-client/proposer/transaction_builder/blob.go:117-118 |
| 16 | Rust proposer sends `u16::MAX` | crates/proposer/src/transaction_builder.rs:181-182, :365 |
| 17 | Go client previously sent 0 | packages/taiko-client/CHANGELOG.md:70 |
| 18 | `u16::MAX` with 12 fresh entries → 11 sources, head 10 | packages/protocol/test/layer1/core/inbox/InboxPropose.t.sol:268-294 |
| 19 | Entries consumed before due | InboxPropose.t.sol:232-266 |
| 20 | Non-operator reverts even past delay×multiplier | InboxPropose.t.sol:296-320 |
| 21 | Go proposer builds from txpool, `l1Head.Time + i`, suggested fee recipient; operator gating | proposer/proposer.go:169-200 (:188), :393-416; blob.go:60-94 |
| 22 | Rust proposer builds from txpool, `l1_head.timestamp`, `tx_list: None`, `is_forced_inclusion: false` | crates/proposer/src/proposer.rs:73-91, :329-338, :495-501; transaction_builder.rs:118-150 |
| 23 | Only queue read in either client is Rust permissionless precheck; Go none outside bindings | proposer.rs:272-288, :291-325, :669-683; grep of packages/taiko-client (bindings only) |
| 24 | Go `/preconfBlocks` takes flag from request, logs, envelopes, stores in L1Origin | driver/preconf_blocks/api.go:49, :144, :157, :200; blocks_inserter/common.go:772-781 |
| 25 | Go pre-insert checks: lookahead window and `ValidateExecutionPayload` only | api.go:160-166; server.go:1082-1111, :956-996 |
| 26 | Rust API takes flag, logs, passes to payload attributes | handlers.rs:38-53, :69, :76, :106; payload_build.rs:33-42; payload.rs:18-33; cache_import.rs:30 |
| 27 | Flag wire encoding `flags1 & 0x01`; re-emitted from L1Origin; logged on receipt | codec.rs:203, :258; server.go:315, :619, :726, :1029, :1385; ingress.rs:271; runtime.rs:1397; pkg/preconf/payload.go:15-17 |
| 28 | Flag set `true` only in tests | util_test.go:23; cache_test.go:106; server_test.go:235; codec.rs:344 (`#[cfg(test)]`), :353 |
| 29 | taiko-geth only stores/marshals the field | /root/go/pkg/mod/github.com/taikoxyz/taiko-geth@v1.18.1-0.20260924044618-8e98046bfd6a/core/rawdb/taiko_l1_origin.go:46; gen_taiko_l1_origin.go:34, :70-71 |
| 30 | Go known-canonical check by payload-args ID; mismatch → not known → re-derive and `PreconfChainReorged = true` | blocks_inserter/common.go:216-290, :293, :322-331, :438-450; inserter.go:169-176, :228-236, :275 |
| 31 | Rust canonical detection aborts on any mismatch; payload-ID comparison | pipeline/payload.rs:588-660, :700-706; pipeline/mod.rs:523-528 |
| 32 | Rust drops preconf payloads `<= head_l1_origin` as stale; surfaced to API | crates/driver/src/sync/event.rs:395-397, :1239-1253; handlers.rs:112-117 |
| 33 | Undecodable/expired forced blob → default block, not stall | source_fetcher.go:61-66, :88-146; pipeline/mod.rs:162-200; Inbox.sol:248-252 |
| 34 | `permissionlessInclusionMultiplier` only assigned/stored/echoed/validated | Inbox.sol:121, :172, :546; LibInboxSetup.sol:41-44 |
| 35 | Discarded `oldestTimestamp_` and stale NatSpec | Inbox.sol:635-636, :671, :683-684, :713; :48-50 |
| 36 | `isOldestForcedInclusionDue` never called | LibForcedInclusion.sol:152-170 (no references in contracts) |
| 37 | `init3` voids queue (`$.head = tail`), fees retained | Inbox.sol:246-258 |
| 38 | Repo analysis docs reach same dead-code conclusion | packages/protocol/docs/Etna/00-current-protocol-summary.md:120, :425-426; 01-threat-model.md:102 |
| 39 | Go derivation path builds L1Origin without the flag; known-canonical path copies preconfer's value | common.go:543-548, :593 |
| 40 | Rust derivation sets flag from source and ORs with existing | pipeline/payload.rs:521, :560 |
| 41 | Derivation.md has no preconfirmation/forced-inclusion interaction text | grep: only :29 mentions preconfer |
