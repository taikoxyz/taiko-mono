# G2: What is the canonical, node-agreeable rule for 'who may sequence at time t'? On-chain the operator for epoch E is fixed by block.timestamp of the landing L1 block, the roster and the beacon root of E−2 (zero root silently picks index 0; removal is immediate and reshuffles rand % operatorCount). Off-chain, Go reads [curr,next] via eth_call at 'latest' (refreshed only after slotInEpoch≥2, using the host wall clock for slots) and enforces a 24/8 handover split only on its own build API; Rust accepts every roster member and ignores activeSince/epochs. Is the 8-slot handover window (during which the current operator can still land L1 proposals) intentional, and which L1 block (latest/safe/finalized) is the intended reference for evaluating operator selection?

All paths are relative to `/home/user/taiko-mono`. `PW` = `packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol`, `LPU` = `packages/protocol/contracts/layer1/preconf/libs/LibPreconfUtils.sol`, `LPC` = `packages/protocol/contracts/layer1/preconf/libs/LibPreconfConstants.sol`, `GO` = `packages/taiko-client`, `RS` = `packages/taiko-client-rs/crates`, `OPNODE` = the vendored fork `/root/go/pkg/mod/github.com/taikoxyz/optimism@v0.0.0-20260420065638-5490c5186828/op-node/p2p/gossip.go`.

## Short answer

1. **The only consensus-deterministic rule in the repository is the on-chain one, and it is a function of an L1 *block*, not of a time `t`.** `PreconfWhitelist.checkProposer` computes the epoch from `block.timestamp` of the block in which the `propose` transaction executes, reads the roster from that block's state, and draws randomness from the EIP-4788 root of the first non-missed slot of epoch E−2 (`PW:127-141`, `PW:275-314`, `LPU:23-39`, `LPU:65-75`). It knows nothing about a handover window: it returns `endOfSubmissionWindowTimestamp_ = 0` with the comment "Slashing is not enabled for whitelisted preconfers, so we return 0" (`PW:139-140`), and the word "handover" does not occur anywhere under `packages/protocol/contracts` (grep, empty).

2. **The 8-slot handover window is intentional as a *client-side liveness convention*, not as a protocol rule.** It is an explicit driver flag (`--preconfirmation.handoverSkipSlots`, "Number of slots to reserve for handover at the end of each epoch", default 8, `GO/cmd/flags/driver.go:52-58`; `GO/driver/driver.go:37`, `:88-90`) with changelog history (`GO/CHANGELOG.md:587` "preconf handover skip slots (#19271)", `:368` "update defaultHandoverSkipSlots to 8 (#21136)"). Its purpose is to let the *next* operator start building L2 blocks 8 slots before its epoch. The fact that the *current* operator can still land L1 proposals in those 8 slots is not a decision recorded anywhere; it is the by-product of (a) the contract having no submission window (`PW:139-140`) and (b) neither proposer checking the slot before proposing (`GO/proposer/proposer.go:395-419`; `RS/proposer/src/proposer.rs:272-289`). Nothing in the code or docs says the current operator must stop at slot 24, so "intentional" cannot be claimed for that part; the handoff-reorg window is unaddressed rather than designed.

3. **No L1 block tag (latest/safe/finalized) is designated as the reference anywhere.** On-chain, the reference is the *including* block. Off-chain, every reader uses the node's default `eth_call` tag, which is `latest`: Go passes `bind.CallOpts` with no `BlockNumber` (`GO/pkg/rpc/methods.go:43-50`, `:917-936`, `:939-958`); Rust calls `.call()` with no `.block(...)` on any whitelist read (`RS/whitelist-preconfirmation-driver/src/operator_set.rs:114-149`; `RS/proposer/src/proposer.rs:281-287`; grep for `BlockNumberOrTag`/`.block(` finds no whitelist call pinned to a tag). Safe/finalized are never used for operator selection. So the "intended" reference is unspecified; what the code *does* is "whatever `latest` is on my L1 node at the moment my wall clock says slot s", which is exactly the non-deterministic mixture the question describes.

## 1. The on-chain rule, precisely

### 1.1 Epoch = epoch of the landing block

```solidity
// PW:127-141
function checkProposer(address _proposer, bytes calldata) external view ... returns (uint48 endOfSubmissionWindowTimestamp_) {
    address operator = _getOperatorForEpoch(epochStartTimestamp(0));
    require(operator != address(0), InvalidProposer());
    require(operator == _proposer, InvalidProposer());
    // Slashing is not enabled for whitelisted preconfers, so we return 0
    endOfSubmissionWindowTimestamp_ = 0;
}
```

`epochStartTimestamp(_offset)` (`PW:176-180`) delegates to `LibPreconfUtils.getEpochTimestamp()`, which is `genesis + floor((block.timestamp − genesis)/384)*384 + offset*384` (`LPU:65-75`, `LPC:19-20`). `block.timestamp` is the timestamp of the L1 block that includes the `propose` call, invoked from `Inbox.sol:601-603` (`_proposerChecker.checkProposer(msg.sender, _lookahead)`); the returned 0 is stored as `endOfSubmissionWindowTimestamp` on the proposal (`Inbox.sol:612-616`). The `_lookahead` bytes are ignored by the whitelist (unnamed parameter, `PW:129`). `IProposerChecker` documents the return value as "The timestamp of the last slot where the current preconfer can propose" (`IProposerChecker.sol:13-14`); the whitelist deliberately returns "no limit".

**Consequence:** operator A of epoch E can land proposals in *any* slot of E, including slots 24-31, and nothing else on L1 restricts it (one proposal per L1 block, bond, derivation validity: `Inbox.sol:590-607`).

### 1.2 Selection function

```solidity
// PW:275-307 (abridged)
uint256 delaySeconds = RANDOMNESS_DELAY * SECONDS_IN_EPOCH;          // 2 * 384
uint32 randomnessTs = uint32(ts >= delaySeconds ? ts - delaySeconds : ts);
uint256 _operatorCount = operatorCount;
uint32 _latestActivationEpoch = latestActivationEpoch;
if (_operatorCount == 0) return address(0);
uint256 randomNumber = _getRandomNumber(randomnessTs);
if (_epochTimestamp >= _latestActivationEpoch) {
    // Fast path: This means all operators are active
    return operatorMapping[randomNumber % _operatorCount];
}
// Slow path: filter isOperatorActive(...) into candidates; return candidates[randomNumber % count];
```

- `RANDOMNESS_DELAY = 2` with the rationale "needs to be 2 epochs or more to ensure the randomness seed source is stable across epochs" (`PW:27-30`). So epoch E's seed is the beacon root of E−2; epoch E+1's seed is the beacon root of E−1. Both are in the past at any point in E, which is why `getOperatorForNextEpoch()` (`PW:149-151`) is answerable.
- `_getRandomNumber` = `uint256(LibPreconfUtils.getBeaconBlockRootAtOrAfter(randomnessTs))` (`PW:309-314`). That helper starts at `timestamp + 12` and scans up to 32 slots, returning the first non-zero root, `bytes32(0)` if the timestamp precedes genesis, and `bytes32(0)` if nothing is found (`LPU:12`, `LPU:23-39`). Its own NatSpec says "Caller should verify the returned value is not 0" (`LPU:20`); `PreconfWhitelist` does not (`PW:288-292`), so a zero root yields `0 % count = 0` → `operatorMapping[0]` silently. The unit test only covers "one missed slot then a non-zero root" (`packages/protocol/test/layer1/preconf/whitelist/PreconfWhitelist.t.sol:167-188`), not the all-zero case.
- **Docs vs code:** `IPreconfWhitelist.sol:38-41` says `getOperatorForCurrentEpoch` "Uses the beacon block root of the first block in the *last* epoch" (delay 1); the code uses delay 2 (`PW:30`, `PW:279-281`). The interface NatSpec is stale.

### 1.3 Roster mutations and their timing

- **Add** is delayed: `activeSince = epochStartTimestamp(OPERATOR_CHANGE_DELAY)` with `OPERATOR_CHANGE_DELAY = 2` (`PW:26`, `PW:218`), and `latestActivationEpoch = activeSince` (`PW:228`) forces the slow, active-filtered path for the next two epochs (`PW:289-305`).
- **Remove** is immediate: "IMPORTANT: The operator is removed immediately" (`PW:99`, `PW:106`). `_removeOperator` swaps the last index into the freed slot and decrements `operatorCount` (`PW:254-263`). Because the fast path is `randomNumber % _operatorCount` (`PW:292`), a removal in the middle of epoch E changes both the modulus and the index→address map, so the operator for the *current* epoch (and the already-announced next one) can change at any L1 block. This directly falsifies the Go assumption at `GO/driver/driver.go:493-496` ("a reliable slot past 0 where the operator has no possible way to change").

### 1.4 What is therefore deterministic

For a given L1 block hash B: `operator(B) = F(roster state at B, latestActivationEpoch at B, EIP-4788 root for slot(E(B)−2)+1.. as visible at B)`. This is a pure function of B (the 4788 ring buffer keeps 8191 roots ≈ 27 h, so the E−2 root is always present). It is **not** a function of wall-clock time: two nodes whose L1 `latest` differs by one block containing a `removeOperator`, or that sit on different sides of an L1 reorg, compute different answers for the same `t`.

## 2. Go client behaviour

### 2.1 What it reads and when

- `GetPreconfWhiteListOperator(nil)` / `GetNextPreconfWhiteListOperator(nil)` → `prepCallOpts` builds `&bind.CallOpts{Context: ...}` with no `BlockNumber` (`GO/pkg/rpc/methods.go:43-50`), calls `GetOperatorForCurrentEpoch`/`GetOperatorForNextEpoch` and then `Operators(proposer).SequencerAddress` (`:917-936`, `:939-958`). With go-ethereum bindings an unset `BlockNumber` means `eth_call` at `latest`. The wrapper returns the **sequencer** address, not the proposer address.
- `cacheLookaheadLoop` (`GO/driver/driver.go:385-621`): ticker `SecondsPerSlot/3` (`:391`); `currentEpoch/currentSlot` come from `d.rpc.L1Beacon.CurrentEpoch()/CurrentSlot()` (`:599`, `:602`, `:609-611`), which are pure wall clock: `(time.Now().UTC().Unix() − genesisTime) / SecondsPerSlot` (`GO/pkg/rpc/beaconclient.go:302-312`).
- Refresh gating: the two `eth_call`s are made only when `eth_blockNumber` changed since the last tick (`:453-471`), and the window is rewritten only when `lookahead == nil || slotInEpoch >= 2` (`:497`). `lookahead` is initialised to `&Lookahead{}` (`GO/driver/preconf_blocks/server.go:161`), so it is never nil; hence the operator pair is (re)published only for wall-clock slots 2..31. The in-code comment says "mid-epooch works, so we use slot 16" (`:493-496`) while the code says 2 — an internal comment/code mismatch.

### 2.2 The 24/8 split

`SequencingWindowSplit` (`GO/driver/preconf_blocks/lookahead.go:70-100`): `threshold := slotsPerEpoch − handoverSkipSlots` (`:72`); current operator gets `[E*32, E*32+threshold)` (`:82-88`), next operator gets `[E*32+threshold, (E+1)*32)` (`:89-95`). With `defaultHandoverSkipSlots = 8` (`GO/driver/driver.go:37`, applied when the flag is 0 at `:88-90`) this is slots 0-23 / 24-31. The driver pushes `(curr,next)` for epoch E and `(next, 0)` for E+1 (`:498-546`), then `UpdateLookahead` (`:553-560`).

### 2.3 Where the split is enforced, and where it is not

- **Enforced:** only on the node's own JWT build API: `BuildPreconfBlock` calls `s.CheckLookaheadHandover(s.rpc.L1Beacon.CurrentSlot())` (`GO/driver/preconf_blocks/api.go:161-166`); the check compares the wall-clock slot with `CurrRanges`/`NextRanges` (`GO/driver/preconf_blocks/server.go:1082-1109`) and **allows by default when the lookahead is uninitialised** (`:1086-1089`). The only other caller is `checkHandover` (`GO/driver/driver.go:413`), which merely decides whether to request the EOS block.
- **Not enforced on gossip:** `P2PSequencerAddresses()` returns `[CurrOperator, NextOperator]` (`server.go:1048-1062`) and the op-node fork accepts any block or block-response signed by either address at any slot (`OPNODE:793-800`, `:835-845`). So a Go node accepts A's and B's blocks throughout epoch E.
- **Not enforced on L1 proposing:** `shouldPropose` only asks `GetPreconfWhiteListOperator` at `latest` and compares it with `p.proposerAddress` (`GO/proposer/proposer.go:395-419`); there is no slot check, so the Go proposer keeps proposing through slots 24-31. (Side observation: it compares its *proposer* address to the returned *sequencer* address, which only works when an operator registers the same key for both, `PW:42-48`.)
- EOS requests are answered only if `s.preconfOperatorAddress == s.lookahead.CurrOperator`, with the comment "Only respond if you are the current sequencer, *not* the active sequencer in the slot" (`server.go:669-673`) — the code itself distinguishes "current (on-chain) operator" from "active-in-slot (handover) operator".

## 3. Rust client behaviour

- `OperatorSetPoller::fetch_all_operators_from` reads `operatorCount()`, every `operatorMapping(i)`, every `operators(p).sequencerAddress`, drops zero addresses and stores a `HashSet<Address>` (`RS/whitelist-preconfirmation-driver/src/operator_set.rs:111-155`). It never calls `getOperatorForCurrentEpoch`, never reads `activeSince`, never computes an epoch; all calls use alloy's default block tag (`latest`). It refreshes on a fixed 384 s wall-clock sleep explicitly "**not** aligned to real L1 epoch boundaries" (`:64-101`).
- Gossip: `validate_signer` accepts iff `operator_set.load().contains(&signer)` (`RS/.../network/handler.rs:298-304`), used for both preconf blocks and responses (`:236`, `:266`). Every roster member — including not-yet-active ones (`activeSince` in the future) — is accepted at every slot.
- Build API: refuses only if the node's own signer is not in the set (`RS/.../api/service/handlers.rs:9-18`); no epoch or slot gating.
- `HAND_OVER_WINDOW_SLOTS = 8` exists but is used only in the shutdown heuristic `can_shutdown_for` (`RS/.../api/service/mod.rs:50-53`, `:84-96`), with the slot from wall clock (`RS/rpc/src/beacon.rs:341-348`, `:374-376`). Its comment says "Doubled relative to the Go client's default `handover_slots = 4`" (`mod.rs:50-52`) — stale, Go is 8 (`GO/driver/driver.go:37`).
- The importer states the design stance: "Here Catalyst owns handover ... this driver has no handover loop" (`RS/.../importer/mod.rs:178-185`).
- Rust proposer: `precheck_current_preconf_operator` calls `getOperatorForCurrentEpoch().call()` (default `latest`) and compares with `l1_proposer_address`, with a permissionless bypass when forced-inclusion processing is permissionless (`RS/proposer/src/proposer.rs:272-289`); no slot gating.

**Go vs Rust differences, explicitly:** Go accepts exactly `[curr,next]` (as of its last refresh); Rust accepts the whole roster. Go enforces 24/8 on its build API; Rust enforces nothing (delegates to Catalyst). Both use `latest` and the wall clock. Neither implements the on-chain function locally.

## 4. Third stakeholder: the ejector

The ejector applies the same current/next split with `HANDOVER_SLOTS` **default 4** (`packages/ejector/README.md:31-32`; `packages/ejector/src/config.rs:101`), computed from the wall-clock slot (`packages/ejector/src/monitor.rs:360-363`; `packages/ejector/src/utils/lookahead.rs:29-42`). So three components disagree on the window (Go 8, Rust 8 shutdown-only, ejector 4).

## 5. Answers to the two explicit questions

**Is the 8-slot handover window intentional?** Yes, as a Go-driver convention for *L2 block building*: flag, default constant, changelog, and the `checkHandover`/EOS request machinery all exist for it (`GO/cmd/flags/driver.go:52-58`; `GO/driver/driver.go:37`, `:408-443`; `GO/CHANGELOG.md:368`, `:587`). No, as a rule about *L1 proposing*: nothing in contracts, proposers or docs restricts the current operator during slots 24-31; the contract explicitly opts out of a submission window (`PW:139-140`), and the only in-repo document on the topic already records the overlap as a defect and marks handover "[REMOVED IN ETNA]" (`packages/protocol/docs/Etna/00-current-protocol-summary.md:349-351`; threat W1 in `01-threat-model.md:131`).

**Which L1 block is the intended reference?** Not specified. On-chain it is necessarily the including block. Off-chain, every implementation evaluates at `latest` with no pinning (Go `methods.go:43-50`; Rust `operator_set.rs:114-149`, `proposer.rs:281-287`), and no code path references `safe` or `finalized` for operator selection. If Etna needs a node-agreeable rule, it has to be defined as a function of an L1 block identity (e.g. "the operator for epoch E is `F` evaluated at the last L1 block of epoch E−1 on the canonical chain", or the roster frozen at a specific block), because the current contract makes the answer depend on the roster at the landing block and the code base contains no such pin.

## Claims index

| # | Claim | Evidence |
|---|-------|----------|
| 1 | `checkProposer` selects `_getOperatorForEpoch(epochStartTimestamp(0))`, requires equality with `_proposer`, returns 0 window ("Slashing is not enabled") | `PW:127-141` |
| 2 | `epochStartTimestamp` is derived from `block.timestamp` via `LibPreconfUtils.getEpochTimestamp` | `PW:176-180`; `LPU:58-75`; `LPC:19-20` |
| 3 | Inbox calls `checkProposer(msg.sender, _lookahead)` and stores the returned window | `packages/protocol/contracts/layer1/core/impl/Inbox.sol:601-616` |
| 4 | `IProposerChecker` defines the return as "last slot where the current preconfer can propose" | `packages/protocol/contracts/layer1/core/iface/IProposerChecker.sol:13-21` |
| 5 | The `_lookahead` bytes are ignored by the whitelist | `PW:129` |
| 6 | `RANDOMNESS_DELAY = 2` with stability rationale; randomness ts = E − 2 epochs | `PW:27-30`, `PW:279-281` |
| 7 | Fast path `operatorMapping[randomNumber % _operatorCount]` when `_epochTimestamp >= latestActivationEpoch`; slow path filters `isOperatorActive` | `PW:284-305` |
| 8 | `_getRandomNumber` = `uint256(getBeaconBlockRootAtOrAfter(ts))`, no zero check | `PW:309-314`, `PW:288-292` |
| 9 | `getBeaconBlockRootAtOrAfter` scans ≤32 slots from ts+12, returns 0 on miss or pre-genesis; NatSpec: "Caller should verify the returned value is not 0" | `LPU:12`, `LPU:20`, `LPU:23-39` |
| 10 | Test covers one skipped slot only, not all-zero | `packages/protocol/test/layer1/preconf/whitelist/PreconfWhitelist.t.sol:167-188` |
| 11 | Interface doc says "last epoch" (delay 1); code uses delay 2 | `packages/protocol/contracts/layer1/preconf/iface/IPreconfWhitelist.sol:38-48` vs `PW:30` |
| 12 | Add delayed by `OPERATOR_CHANGE_DELAY = 2`; `latestActivationEpoch` updated | `PW:26`, `PW:218`, `PW:228` |
| 13 | Remove is immediate, swap-and-pop, `operatorCount` decremented | `PW:99`, `PW:106`, `PW:237-266` |
| 14 | No "handover" concept in any contract | grep `handover` over `packages/protocol/contracts` → no matches |
| 15 | Go `prepCallOpts(nil)` builds `CallOpts` without `BlockNumber` (→ `latest`) | `GO/pkg/rpc/methods.go:43-50` |
| 16 | Go wrappers call `GetOperatorForCurrentEpoch/NextEpoch` then `Operators(...).SequencerAddress` | `GO/pkg/rpc/methods.go:917-936`, `:939-958` |
| 17 | Lookahead loop ticker `SecondsPerSlot/3`; epoch/slot from `L1Beacon.CurrentEpoch()/CurrentSlot()` | `GO/driver/driver.go:391`, `:599-611` |
| 18 | `CurrentSlot()` etc. are wall clock (`time.Now()`) | `GO/pkg/rpc/beaconclient.go:302-312` |
| 19 | Operator eth_calls only when `eth_blockNumber` changed; window rewrite only when `slotInEpoch >= 2`; comment says slot 16 | `GO/driver/driver.go:453-471`, `:493-497` |
| 20 | `lookahead` initialised non-nil | `GO/driver/preconf_blocks/server.go:161` |
| 21 | 24/8 split: `threshold = slotsPerEpoch − handoverSkipSlots`; curr `[0,threshold)`, next `[threshold,32)` | `GO/driver/preconf_blocks/lookahead.go:70-100` |
| 22 | Default `handoverSkipSlots = 8`; flag usage text | `GO/driver/driver.go:37`, `:88-90`; `GO/cmd/flags/driver.go:52-58` |
| 23 | Changelog: handover skip slots introduced (#19271), default set to 8 (#21136) | `GO/CHANGELOG.md:587`, `:368` |
| 24 | Split enforced only in `BuildPreconfBlock` via `CheckLookaheadHandover(CurrentSlot())` and in `checkHandover` | `GO/driver/preconf_blocks/api.go:161-166`; `GO/driver/driver.go:413` |
| 25 | `CheckLookaheadHandover` allows by default when uninitialised; checks wall-clock slot vs ranges | `GO/driver/preconf_blocks/server.go:1082-1109` |
| 26 | `P2PSequencerAddresses` returns `[Curr, Next]`; op-node accepts either signer at any slot | `GO/driver/preconf_blocks/server.go:1048-1062`; `OPNODE:793-800`, `:835-845` |
| 27 | Go proposer: operator check at `latest`, no slot check; compares proposer addr to returned sequencer addr | `GO/proposer/proposer.go:395-419`; `PW:42-48` |
| 28 | EOS request answered only by `lookahead.CurrOperator` ("not the active sequencer in the slot") | `GO/driver/preconf_blocks/server.go:669-673` |
| 29 | Rust roster read: `operatorCount`, `operatorMapping`, `operators().sequencerAddress`, zero filtered; no epoch/activeSince; default block tag | `RS/whitelist-preconfirmation-driver/src/operator_set.rs:111-155` |
| 30 | Rust refresh every 384 s wall clock, "not aligned to real L1 epoch boundaries" | `RS/whitelist-preconfirmation-driver/src/operator_set.rs:64-101` |
| 31 | Rust gossip accepts any roster member | `RS/whitelist-preconfirmation-driver/src/network/handler.rs:236`, `:266`, `:298-304` |
| 32 | Rust build API only checks own signer membership | `RS/whitelist-preconfirmation-driver/src/api/service/handlers.rs:9-18` |
| 33 | Rust `HAND_OVER_WINDOW_SLOTS = 8` used only for shutdown; comment claims Go default is 4 | `RS/whitelist-preconfirmation-driver/src/api/service/mod.rs:50-53`, `:84-96` |
| 34 | Rust slot derivation is wall clock | `RS/rpc/src/beacon.rs:341-348`, `:374-376` |
| 35 | "Catalyst owns handover"; Rust driver has no handover loop | `RS/whitelist-preconfirmation-driver/src/importer/mod.rs:178-185` |
| 36 | Rust proposer: `getOperatorForCurrentEpoch().call()` default tag, compares to `l1_proposer_address`, permissionless bypass; no slot check | `RS/proposer/src/proposer.rs:272-289` |
| 37 | No whitelist call pins a block tag in Rust (only unrelated `get_block_by_number` uses) | grep `BlockNumberOrTag|BlockId::|.block(` over the three crates |
| 38 | Ejector uses `HANDOVER_SLOTS` default 4 and wall-clock slot for responsibility | `packages/ejector/README.md:31-32`; `packages/ejector/src/config.rs:101`; `packages/ejector/src/monitor.rs:360-363`; `packages/ejector/src/utils/lookahead.rs:29-42` |
| 39 | Etna summary already records the overlap and marks handover removed; threat model lists "Handoff ambush" | `packages/protocol/docs/Etna/00-current-protocol-summary.md:349-351`; `packages/protocol/docs/Etna/01-threat-model.md:131` |
| 40 | Genesis timestamps per chain; unknown chain → 0 | `LPC:14-17`, `LPC:27-38` |
