# Alternatives to "Nonce as a Lock" for zero-cost same-action races under EIP-8141

Date: 2026-09-30. Every external claim is tagged **VERIFIED** (primary source fetched on 2026-09-30, URL given, quotes verbatim) or **UNVERIFIED** (inference, estimate, or not confirmable from a primary source). Gas figures are estimates unless they are spec constants.

Inputs read in full: `ft-spec-model.md`, `ft-client-behaviour.md`, `ft-taiko-inbox-facts.md` (all in this directory), and `packages/protocol/docs/Etna/inputs/nonce-as-a-lock.txt` (315 lines). EIP-8141 was re-fetched today from `https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md` (Status `Draft`; local copy `eip-8141-raw.md`, 1472 lines). Additional primary sources fetched today: EIP-7702 (raw, saved as `eip-7702-raw.md`), EIP-8250, EIP-3607, EIP-8038, ERC-7562, the magicians thread copy (`magicians-thread.txt`), and the Taiko `Inbox.sol` / `IInbox.sol` at HEAD `61d8f18`. No fetch failed in this run.

Goal restated: when several parties race to submit the same protocol action (propose a batch; prove a batch; in Etna, propose-with-proof), at most one transaction is valid and every other is **invalid** (never included in a valid block, and therefore charged nothing, including blob fees) rather than **included-and-reverted** (charged execution gas plus a burned blob fee).

---

## 0. The spec facts every construction stands on

| # | Fact | Status / source |
|---|---|---|
| F1 | A `VERIFY` frame is a `STATICCALL` whose failure invalidates the whole transaction: "Execute the frame as a `STATICCALL`, disallowing state manipulation. Only `APPROVE` can modify the state or transaction context in `VERIFY`. If the frame fails by reverting or halting exceptionally, the transaction is invalid. This unrolls any effects of `APPROVE`." | VERIFIED — eip-8141.md (raw, 2026-09-30), "Behavior" |
| F2 | Storage **reads** in `VERIFY` are legal at consensus (STATICCALL permits `SLOAD`/`CALL*` to views); nothing in the consensus text restricts which accounts a `VERIFY` frame may read. The restriction exists only in the **public-mempool policy**: "`SLOAD` can be used only to access `tx.sender` storage, including when reached transitively via `CALL*` or `DELEGATECALL`." and a node must reject if "execution reads storage outside `tx.sender`"; "Any dependency on third-party mutable state outside these categories must result in rejection by the public mempool." | VERIFIED — eip-8141.md "Banned Opcodes", "Policy Summary" |
| F3 | The mempool section is explicitly non-consensus: "Transactions outside these rules may be accepted into a local or private mempool, but must not be propagated through the public mempool." The policy "is inspired by ERC-7562, but removes staking and reputation entirely. Any behavior that ERC-7562 would admit only for a staked or reputable third party is rejected here for the public mempool." | VERIFIED — eip-8141.md "Mempool" |
| F4 | A `VERIFY` frame **after** the paying frame is consensus-legal (no static constraint forbids it; only `ATOMIC_BATCH_FLAG` interacts with `VERIFY`: `assert frame.mode != VERIFY` and `assert tx.frames[i + 1].mode != VERIFY`) but is a public-mempool reject: structural rule "8. There must not be `VERIFY` frame after validation prefix." with the stated reason "There must not be any `VERIFY` frame after these prefixes, otherwise their revert would make entire transaction invalid." | VERIFIED — eip-8141.md "Constraints", "Structural Rules" |
| F5 | `FRAMEPARAM (0xb3)` param `0x05` = "`status` (exceptional halt if current/future)"; "The `status` field (0x05) returns `0` for failure, `1` for success, or `2` for a frame skipped due to a failed atomic batch." Gas 2. | VERIFIED — eip-8141.md "FRAMEPARAM Instruction" |
| F6 | Nothing is charged before payment approval: "A frame transaction is charged nothing until one of its frames approves payment, so a validation prefix that does not approve consumes its validation work with no fee every time a block producer offers it." Producer policy: "A block producer SHOULD bound the unpaid validation work ... A build-time failure to approve MAY be transient rather than permanent, for example ... a prefix reading state that a preceding transaction changes ..., so the bound SHOULD permit more than one attempt before eviction." | VERIFIED — eip-8141.md "Replacement and Eviction" |
| F7 | Public-pool revalidation on a new head re-simulates only tracked dependencies: "This includes at least transactions for the same sender, transactions whose recorded sender storage slots changed, transactions that reference a canonical paymaster instance whose balance, code, or delayed-withdrawal state changed, and transactions whose payer's balance or code changed." | VERIFIED — eip-8141.md "Revalidation" |
| F8 | Nonce: "1. Ensure `tx.nonce == state[tx.sender].nonce`" before any frame; increment only in a payment-scoped `APPROVE`; "two pending transactions sharing it are alternatives, of which at most one can ever be included." One pending frame tx per sender in the public pool (SHOULD). | VERIFIED — ft-spec-model.md §4/§7 quoting eip-8141.md (2026-09-30) |
| F9 | Expiry: canonical contract at `0x8141`, `VERIFY` frame, "The call reverts unless `block.timestamp <= expiry_timestamp`"; only an upper bound (no `valid_after`; PR #12252 open/draft); nodes "MUST drop ... whose deadline is less than the node's view of the current block timestamp." | VERIFIED — eip-8141.md "Expiry Verifier Frame"; ft-spec-model.md §5 |
| F10 | Blob fee under EIP-4844 "is deducted from the sender balance before transaction execution and burned, and is not refunded in case of transaction failure." In a frame tx the blob cost is part of `max_cost` escrowed at APPROVE, so an invalid frame tx pays no blob fee. | VERIFIED — ft-client-behaviour.md §5a (EIP-4844) and ft-spec-model.md §8 |
| F11 | Cold account access rises to 3,000 under EIP-8038 (Review; cold SLOAD stays 2,100, warm 100). | VERIFIED — https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8038.md (2026-09-30) |
| F12 | Taiko today: `require(block.number > _lastProposalBlockId, CannotProposeInCurrentBlock())` (Inbox.sol:590); `getCoreState()` is a public view (Inbox.sol:551-553); `prove` rejects re-proofs with `LastProposalAlreadyFinalized` / `ParentBlockHashMismatch` (Inbox.sol:346, 805) — all **reverts**, i.e. the loser lands and pays. | VERIFIED — packages/protocol/contracts/layer1/core/impl/Inbox.sol at HEAD 61d8f18 |
| F13 | The block-level consequence of including an invalid tx (block invalid) is inherited from the general rule (execution-specs `check_transaction` raises `InvalidBlock`), not restated in EIP-8141. | VERIFIED for existing types; UNVERIFIED as a quoted 8141 sentence (ft-spec-model.md §3) |

Two consequences drive everything below:

- **(C1)** "Invalid, pays nothing" is reachable from exactly three places in a frame tx: the pre-frame nonce/signature checks (F8), any `VERIFY` frame failure (F1), and expiry (F9). Everything that happens in a `SENDER`/`DEFAULT` frame is a *revert*, paid by the payer.
- **(C2)** The public mempool admits a `VERIFY`-based lock only if it depends on transaction fields, the expiry timestamp, and `tx.sender`'s own nonce/code/storage (F2, F3). Any lock that reads a *shared* fact (a claim slot, a counter, the Inbox's `nextProposalId`) is consensus-valid but public-pool-ineligible, and can only travel privately to builders.

The baseline design (the PDF) is the unique construction that gets both consensus invalidity **and** public-pool eligibility, because the shared fact it reads is the sender nonce of a shared sender `G` (category 3 of the Policy Summary). Every alternative below trades one of those two properties for something else.

---

## 1. Baseline for comparison: nonce as a lock (the PDF)

Structure (VERIFIED as consistent with spec: PDF §1.1, ft-spec-model.md §9): `sender = G`, `nonce = nonce(G)`, frames `[expiry_verify 0x8141][only_verify G (flags 2)][pay P (flags 1)][SENDER Inbox.proposeFor(P, packedInput)]`, signatures `[ARBITRARY "", SECP256K1 P]`.

- Loser is INVALID by F8 (nonce mismatch at step 1, before any frame); same block or later block alike. Pays nothing (F6).
- Winner cost: PDF estimates +13.5k gas (~+18%) over a type-3 tx (UNVERIFIED).
- Known limitations (PDF §3, all consistent with the spec): (L1) exclusivity is per nonce not per block, so `n+1` landing after `n` in the same L1 block **reverts** at `CannotProposeInCurrentBlock` and pays; (L2) single-seat squatting (distant expiry, zero tip, high `max_fee`, replacement needs +10% / +100% with blobs — VERIFIED in ft-client-behaviour.md §1); (L3) **any revert of the SENDER frame burns the nonce** (a "wasted slot") so every other-triggerable revert on the propose path is a lever; (L4) G hard-codes a Draft spec; (L5) only one pending `(G, n)` per public-pool node, so no pipelining.

---

## 2. Alternative A1 — a protocol-level "claim" VERIFY frame that reads state

**Idea.** Drop the shared sender. Each proposer `P` uses its own nonce. A `VERIFY` frame reads the shared claim ("does proposal id `N` already exist?") and reverts if the claim is taken, so the loser is invalid by F1.

**Transaction structure sketch** (sender `P`, an EOA; the claim lives in the Inbox itself, which already exposes it):

```
sender = P, nonce = nonce(P)
0  VERIFY  flags 0  target 0x8141            data uint64be(T_S)             expiry_verify (optional)
1  VERIFY  flags 0  target CLAIM_VERIFIER    data (N, INBOX)                claim check
2  VERIFY  flags 3  target P (null)          data ""                        self_verify (default code, P's sig)
3  SENDER  flags 0  target Inbox             data propose(lookahead, input) user_op
signatures = [[SECP256K1, P, "", sig_P]]
```

`CLAIM_VERIFIER` is a tiny stateless contract: `STATICCALL Inbox.getCoreState()` (Inbox.sol:551, VERIFIED public view), `require(nextProposalId == N)`, and — because at consensus `NUMBER` is not banned — `require(lastProposalBlockId != NUMBER)` so a second proposal in the same L1 block is invalid rather than reverting at Inbox.sol:590. Alternatively fold the check into frame 2 by giving `P` a 7702 delegation or a smart-account; the trace rule is the same.

**Can VERIFY frames read state?** Yes at consensus (F2: STATICCALL; only writes are excluded). The consensus text places no cap on `VERIFY` gas either (bounded only by the frame's `limits.execution` and `TX_MAX_GAS_LIMIT`; ft-spec-model.md §6).

**Is consensus-level invalidity achieved?** Yes. Frame 1 executes against the live pre-state *at the transaction's position in the block*, so once the winner's `SENDER` frame has bumped `nextProposalId` (Inbox.sol:284), every later transaction pinned to `N` fails frame 1 and is invalid (F1); a block containing it is invalid (F13). No `payer` is ever set, so nothing is charged (F6). This is not merely pool-level dropping.

**Is pool validity re-evaluated after each block?** In the **public** pool the question is moot: the prefix reads Inbox storage, which is "storage outside `tx.sender`" (F2), and the frame shape `[expiry][VERIFY flags 0 → helper][self_verify]` is not one of the four recognized prefixes; both are rejects. In a **private/builder** pool, the spec only says a producer re-simulates the prefix on every build attempt and may evict after a bounded number of failures, explicitly naming "a prefix reading state that a preceding transaction changes" as a transient case (F6). So the claim is re-checked at build time, which is what matters, but per-head dependency tracking on Inbox slots is builder policy (UNVERIFIED for any builder; no builder documents frame-tx handling yet, ft-client-behaviour.md §2).

**Loser INVALID vs REVERT.** INVALID (F1) for: claim taken in an earlier block; claim taken earlier in the same block; same-block second proposal (via the `NUMBER` check); expired (F9). Still a **revert** (pays) for anything frame 1 does not pin: ring buffer full (`NotEnoughCapacity`), FI-fee push failure, a future Inbox revert. Each can be added to `CLAIM_VERIFIER` as another read, at ~2,100 gas per cold slot (F11).

**Cost.** Winner: +1 frame (475 gas, `FRAME_TX_PER_FRAME_COST`) + cold access to `CLAIM_VERIFIER` (3,000 under EIP-8038) + STATICCALL into the Inbox (cold 3,000) + two cold SLOADs (`_coreState` occupies slots 252-253, ft-taiko-inbox-facts.md) 4,200; but the `SENDER` frame then finds the Inbox and those slots warm ("the journal of such touches is shared across frames", VERIFIED eip-8141.md "Cross-frame interactions"), saving roughly the same 7,200. Net ≈ +4k gas over a plain frame tx (estimate, UNVERIFIED). Loser: 0.

**Latency.** None; single transaction, same slot.

**Failure modes.** (i) No public-mempool path at all: if builders do not run a private lane that accepts state-reading prefixes, the construction has no route. (ii) Builder simulation is unpaid (F6) — a builder must bound it locally; the read is cheap (~10k) so the DoS surface is small but real. (iii) Spec drift: the async-execution camp proposes fixing `[Deploy] VERIFY [VERIFY]` at the head with a consensus gas cap (thread #53/#79, ft-spec-model.md §10.11); a consensus restriction on *which* state `VERIFY` may read would kill this design. (iv) L1 reorgs: the claim check is re-evaluated in the new chain, so a reorg that un-mines the winner simply makes the loser valid again (a feature, not a bug).

**Squatting / griefing.** None: there is no shared resource to squat; `P`'s own nonce is the only sequence, and `P` can hold as many private variants as it likes. Griefing is limited to making the winner's `SENDER` frame revert (the un-pinned reverts above), which costs the winner gas but burns no shared lock.

**EIP changes needed.** None for consensus. For public-pool propagation it would need a *policy* change in EIP-8141's mempool section (an "associated storage" or "read-only registry allowlist" concept like ERC-7562 STO-021/STO-031, which 8141 explicitly removed: "removes staking and reputation entirely", F3). ERC-7562 (status Review, VERIFIED https://raw.githubusercontent.com/ethereum/ERCs/master/ERCS/erc-7562.md) allows staked entities to read any storage; 8141 does not.

**Verdict.** The strongest *targeted* zero-cost construction without a shared sender; private-only; it directly removes L1, L2, L3, L5 of the baseline. It does not remove the need for the Inbox's one-per-block rule but makes it costless.

---

## 3. Alternative A2 — a shared sequence-number contract without the sender nonce

**Idea.** A contract `S` holds `seq`; each proposer passes `expectedSeq` in calldata; a `VERIFY` frame checks `S.seq == expectedSeq` (or derives the expectation from `FRAMEDATALOAD` of the `SENDER` frame's calldata so the two cannot disagree); the `SENDER` frame's action bumps `seq`.

**Transaction structure sketch.**

```
sender = P
0  VERIFY  flags 0  target S          data ""      S reads its own seq, compares with FRAMEDATALOAD(2, off)
1  VERIFY  flags 3  target P (null)                self_verify
2  SENDER  flags 0  target Inbox      propose(...) -> Inbox calls S.bump() (or S == Inbox and seq == nextProposalId)
```

**What breaks.** Exactly F2: `S.seq` is storage outside `tx.sender`, so the public pool rejects it, and the shape is not a recognized prefix. There is **no way to bind a frame transaction to a global sequence without either (a) the sender nonce or (b) a storage read**: every `TXPARAM`/`FRAMEPARAM`/`SIGPARAM` value is a function of the transaction's own fields (VERIFIED, the full index list in ft-spec-model.md §2.6), so a `VERIFY` frame that compares `TXPARAM(0x01)` (the envelope nonce) to a calldata sequence number is just re-deriving the nonce check, and comparing two calldata fields to each other proves nothing about chain state. Two sub-variants:

- **A2a `S ≠ Inbox`, own counter.** Strictly dominated by A1: same mempool status, plus an extra `SSTORE` to `S.seq` in the `SENDER` frame (~2,900 gas warm-slot write today; EIP-8038 `STORAGE_WRITE` 10,000 for new bytes only, VERIFIED F11) and a second trust root. Its only use is when the sequence must *not* equal the proposal id — e.g. one counter per proving lane, where the Inbox has no natural counter (see §7).
- **A2b make `S` the sender.** Then `S`'s nonce is the sequence and this *is* the baseline. The account nonce is free (the increment "has no additional execution-gas cost", VERIFIED ft-spec-model.md §4.6) whereas a storage counter is not, so there is no reason to prefer the counter.

**Loser INVALID vs REVERT, cost, latency, squatting, EIP changes.** As A1. One property worth stating because it is the main improvement over the baseline that both A1 and A2 share: **the lock is consumed only by a successful action** (the counter/claim moves in the `SENDER` frame), so a reverting `SENDER` frame does *not* burn the lock; it burns only the reverting proposer's own gas. The baseline's L3 ("any revert burns the nonce, wasting the slot") disappears.

**Verdict.** Not a separate design; A1 with a redundant counter. Keep only as the per-lane variant for roles that have no natural on-chain sequence.

---

## 4. Alternative A3 — commit-reveal with frames

**Idea.** Block `k`: `P` sends a cheap commit `C` (no blobs) claiming slot/proposal `N` in a registry `R`. Block `k+m`: `P` sends the real proposal (blobs, proof) whose `VERIFY` frame checks `R.claim[N] == P`.

**Transaction structure sketch.** Commit: any tx type, `R.claim(N)` with first-writer-wins (`require(claim[N] == 0)`); losers of the commit race land-and-revert. Reveal: as A1 with `CLAIM_VERIFIER` reading `R.claim[N] == P` (so a non-winner's reveal is invalid, F1) — or, if `R`'s claim is instead enforced *inside* the Inbox (`proposeFor` requires `claim[N] == msg.sender`), an ordinary type-3 tx that can no longer lose a race, only go stale.

**Does it remove the race or move it?** It **moves** it to the commit phase, where it is cheaper (a commit is ~21k base + one cold SSTORE, no blob fee; loser pays ≈ 25-45k gas, estimate UNVERIFIED) but still a land-and-revert race unless the commit itself is a frame tx locked by one of the other constructions (A1/baseline), in which case the commit-reveal adds nothing except latency. What it does remove is the *expensive* loss: no loser ever pays a blob fee, because blobs travel only in the uncontested reveal. This is the cheapest "no blob-fee tail risk" design that works **today, without frames**.

**Cost.** Winner: two transactions (+ ~45k gas commit, estimate) and two signatures. Loser: one cheap reverted commit, or nothing if the commit is frame-locked.

**Latency.** +`m` L1 slots, `m ≥ 1` (commit must be *in* a block before the reveal can be validated against it). For a based rollup proposing every slot this means the commit for slot `S` must land in `S-1`: the design degenerates into a per-slot **lookahead election**, which Taiko already has in `PreconfWhitelist.checkProposer` (one operator per epoch, VERIFIED ft-taiko-inbox-facts.md §g) and which the PDF explicitly rejected as its goal ("there is no advance exclusivity").

**Failure modes.** Free option: the committer may not reveal (slot wasted) → needs a bond and slashing → a preconf-slashing system. Reorg of the commit block invalidates the reveal (fine, F1) but wastes the slot. If the reveal is not frame-locked and the winner's reveal reverts for another reason, it pays.

**Squatting / griefing.** High: commits are cheap, so anyone can squat future slots unless committing costs a bond; that is precisely the griefing surface that turned Taiko's earlier designs into whitelists.

**EIP changes.** None. Works with or without frames.

**Verdict.** Not recommended for the propose race: it converts a same-slot auction into an election, adds ≥ 1 slot of latency, and needs bonding. Its one virtue (blob fees never at risk) is obtained more cheaply by A1/A7 for private flow and by the baseline for public flow. It *is* the right shape for a different problem — reserving a proving assignment minutes ahead (see §11).

---

## 5. Alternative A4 — expiry-only (no shared nonce)

**Idea.** Every proposal is a frame tx from `P`'s own nonce with a tight expiry frame; a proposal that misses its slot becomes invalid instead of landing late.

**Transaction structure sketch.** `[expiry_verify 0x8141 uint64be(T_S)][self_verify P][SENDER Inbox.propose(... deadline = 0 ...)]`. Public-pool eligible (prefix `[expiry_verify][self_verify]`, VERIFIED recognized shape).

**What losers pay.** Two cases, and they differ:

- **Cross-slot loser (stale):** a tx that did not land in slot `S` is invalid from the first block with `block.timestamp > T_S` (F9); it pays nothing. Today the same tx lands in `S+1` and reverts with `DeadlineExceeded` (Inbox.sol:765, VERIFIED) paying gas **and** blob fee (F10). Strict improvement, and free.
- **Same-slot loser:** both `A` and `B` are valid for slot `S`; the builder includes both (it is paid for both); the second **reverts** at `CannotProposeInCurrentBlock` (Inbox.sol:590) **before** its expiry has passed and pays execution gas plus the blob fee. Expiry does nothing here. Do losers "land and revert before expiry"? Yes — expiry is only an upper bound on `block.timestamp` (F9), and both txs are inside it.

**Cost.** Winner: +475 (frame) + ~3,200 (cold `0x8141`) gas. Same-slot loser: full cost (PDF: 30,944 gas + blob fee, UNVERIFIED figure).

**Latency.** None.

**Failure modes.** Nodes drop expired txs only when the deadline "is less than the node's view of the current block timestamp" (strict `<`, F9), i.e. one slot late; harmless. No `valid_after` (PR #12252 open), so a tx signed early can land in `S-1` (PDF §1.1 timestamp note).

**Squatting / griefing.** None of the baseline's (no shared sender). Builder incentive is the problem: a builder *gains* by including both variants, so it will.

**EIP changes.** None.

**Verdict.** A floor, not a solution: adopt it in every design (it is free and public-pool safe) but it never removes the same-slot loss.

---

## 6. Alternative A5 — multiple gate contracts / per-role nonces

**Idea.** Instead of one `G`, deploy `G_propose`, `G_prove`, or lane gates (`G_even`/`G_odd` by proposal-id parity; `G_lane[i]` per proving lane), each with its own nonce; the Inbox trusts a set (`isGate[addr]`).

**Transaction structure.** Identical to the baseline per gate; the only pins that change are `TXPARAM(0x02) == address(this)` (already per-gate) and, for parity gates, `require((expectedProposalId & 1) == LANE)`.

**What it fixes and what it does not.**

- **Per-role gates (propose vs prove).** Fully independent: the actions do not conflict, so a prover's revert can never burn a proposer's nonce and vice versa; each role gets the baseline's public-pool zero-cost race. This is the correct baseline extension whenever the baseline is used for more than one role.
- **Parity / lane gates for proposals.** They remove L5 (pipelining): a proposer can hold `n` on `G_even` and `n+1` on `G_odd` in the public pool simultaneously because the "one pending per sender" rule is per **sender address** (F8; VERIFIED "A node should keep at most one pending frame transaction per sender"). They do **not** fix L1: with the Inbox's one-per-block rule, `n+1` landing after `n` in the same block still reverts at Inbox.sol:590 and now burns `G_odd`'s nonce (L3 moved, not removed). Fixing L1 requires the Inbox to allow `K` proposals per block (a ring-buffer spam bound of `K` per block instead of 1), which is an Inbox change, and even then `n+1`'s `parentProposalHash` must be known when signing, which forces it to be signed *after* `n` is seen.
- **Squatting** is multiplied: every gate is an independent single seat, each squattable with the PDF's zero-tip/distant-expiry variant; the `MIN_TIP` pin must be enforced per gate, and the +10%/+100% replacement rules (VERIFIED ft-client-behaviour.md §1) apply per gate.
- **EIP-8250 keyed nonces** (Draft, "Considered for Inclusion" only, VERIFIED ft-spec-model.md §1) would give one `G` a nonce key per lane (`nonce_keys`, `nonce_seq`; consumption "on the unique successful payment-scoped `APPROVE` that sets `payer`"; two txs with disjoint non-zero keys includable in one block, VERIFIED https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8250.md 2026-09-30). But 8250 "preserves EIP-8141's limit of one pending frame transaction per sender" in the public pool, so lanes on one `G` would **not** propagate concurrently; and the first use of each key costs `STATE_BYTES_PER_STORAGE_SET * CPSB = 97,920` state gas. Separate gate *contracts* are therefore better than keys until the mempool guidance changes — and they need no EIP.

**Cost.** Deploy `k` gates (one-off); per tx unchanged. Inbox: `mapping(address => bool) isGate` read (one cold SLOAD, 2,100) instead of an immutable compare.

**Latency.** None; parity gates *reduce* effective latency by allowing pipelined submission.

**Failure modes.** Same as the baseline per gate (L3, L4); more root-of-trust surface (each gate's code is a separate audit item; a bug in any gate lets anyone call `proposeFor`/`proveFor` with that gate's identity).

**EIP changes.** None (contracts only). 8250 optional and not needed.

**Verdict.** Mandatory if the baseline is used for more than one role; useful for pipelining; does not address L1/L3.

---

## 7. Alternative A6 — non-frame alternatives (for comparison)

### 7a. EIP-7702 delegated accounts sharing a nonce — impossible

- The transaction sender of every non-frame type must be an EOA or a 7702-delegated EOA: EIP-3607 (Final): "Any transaction where `tx.sender` has a `CODEHASH != EMPTYCODEHASH` MUST be rejected as invalid" (VERIFIED https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-3607.md); EIP-7702 (Final) only relaxes it for "EOAs whose code is a valid delegation indicator ... Accounts with any other code values may not originate transactions." (VERIFIED eip-7702-raw.md "Transaction origination"). EIP-8141 is the *only* type that lifts it: "Do not apply the restriction put in place by EIP-3607 to frame transactions." (VERIFIED).
- Therefore the gating nonce of a non-frame tx is always the nonce of a key-holding account, and validity requires that key's signature. "Sharing a nonce" between proposers means sharing a private key, which also shares the balance and the delegated code's authority; the delegated code runs only *after* the nonce check and cannot intercept it.
- The authorization tuples do carry nonces ("6. Verify the nonce of `authority` is equal to `nonce`." / "9. Increase the nonce of `authority` by one."), so one might try a shared **authority** whose delegation is re-set each proposal; but a failed tuple does not invalidate the tx: "If any step above fails, immediately stop processing the tuple and continue to the next tuple in the list." (VERIFIED eip-7702-raw.md). The loser lands and pays. Also "the authors recommend that clients do not accept more than one pending transaction for any EOA with a non-zero delegation indicator." (VERIFIED), and geth's blob pool enforces exactly that for delegated senders (VERIFIED ft-client-behaviour.md §1b).
- Conclusion: no consensus-level invalidity is reachable with 7702; VERIFIED by the quotes above.

### 7b. Private builder revert protection — policy only

- Flashbots Protect: "Transactions are only included in the block if they do not revert. Users do not pay fees for failed transactions." Titan: `revertingTxHashes` / `droppingTxHashes`; "We will never unbundle a bundle, and will never broadcast any bundles or private transactions to the public mempool." (VERIFIED ft-client-behaviour.md §4c.)
- Loser cost 0 **if** the builder honours it; zero latency; no contract changes. But: it covers only the builders you submit to; a copy that reaches the public mempool can be included by any other builder or a local proposer and reverts there (UNVERIFIED inference, ft-client-behaviour.md unverified item 4; Flashbots' "Do Not Switch RPCs" warning is the closest primary acknowledgement); a builder that includes a reverting tx pays no protocol penalty. Under ePBS the builder's bid is still paid at the CL for an empty slot (VERIFIED ft-client-behaviour.md §4b), which changes nothing about revert protection.
- The crucial comparison with the frame constructions: under A1/A7 a builder that *does* include the loser produces an **EL-invalid** payload (F1, F13), so the protection does not depend on the builder's honesty, and public-mempool leaks cannot land. That is the whole delta between "policy" and "consensus".

### 7c. Today's Taiko conditional-propose guard

- Pre-Shasta: `ProverSet.proposeBlocksV2Conditionally` with `require(taiko.lastProposedIn() != block.number, NOT_FIRST_PROPOSAL())`, opt-in via `--revertProtection` (PR #18570, merged 2024-12-16, VERIFIED ft-taiko-inbox-facts.md). Shasta: in-Inbox `CannotProposeInCurrentBlock` (PR #20186, Inbox.sol:590, VERIFIED).
- Loser lands and **reverts**, paying execution gas (PDF: 30,944, UNVERIFIED) plus the burned blob fee (F10). The guard bounds *damage* (the loser's revert is early and cheap in execution) and ring-buffer spam; it does not make anything invalid. Combined with 7b it is the status quo the PDF measures against ("0.002 losers per proposal" in the guard era, UNVERIFIED).

---

## 8. Alternative A7 (added) — the trailing status `VERIFY` frame ("assert-after")

**Idea.** Use F4 + F5 directly: put a `VERIFY` frame **after** the `SENDER` frame that reads the `SENDER` frame's `status` with `FRAMEPARAM(0x05, i)` and reverts unless it is `1`. By F1 the whole transaction is then invalid whenever the action reverted — for *any* reason — and by F6 nobody pays. No shared sender, no storage read, no gate contract, no Inbox change.

**Transaction structure sketch.**

```
sender = P (EOA, own nonce)
0  VERIFY  flags 0  target 0x8141           uint64be(T_S)                  expiry_verify (optional, public-pool shape)
1  VERIFY  flags 3  target P (null)          ""                             self_verify (default code, sig_P)
2  SENDER  flags 0  target Inbox  [exec, state] propose(lookahead, input)   user_op  (msg.sender == P, ORIGIN == P)
3  VERIFY  flags 0  target STATUS_VERIFIER   ""   [~600, 0]                 require(FRAMEPARAM(0x05, 2) == 1)
signatures = [[SECP256K1, P, "", sig_P]]
```

`STATUS_VERIFIER` is a ~15-byte stateless contract (`PUSH1 2 PUSH1 5 FRAMEPARAM PUSH1 1 EQ PUSH1 ok JUMPI 0 0 REVERT ok: STOP`). It is the same for every action (propose, prove, propose-with-proof) and for every protocol; it reads nothing but the transaction. A variant can additionally pin the *outcome* (e.g. `STATICCALL Inbox.getCoreState()` and `require(nextProposalId == N + 1)`) to defend against an action that "succeeds" but did something other than what `P` signed for; that variant reads state (A1 rules apply) and is only needed if the Inbox can succeed in an unintended way.

**Loser INVALID vs REVERT.** INVALID (F1, "If the frame fails by reverting or halting exceptionally, the transaction is invalid. This unrolls any effects of `APPROVE`.") for every case in which frame 2 reverted or halted: same-slot loser (`CannotProposeInCurrentBlock`), stale parent, ring buffer full, FI due, FI-fee push failure, bad proof (`verifyProof` reverting), OOG in frame 2, anything future. The spec's own words for why the public pool bans this shape are the statement of the property we want: "otherwise their revert would make entire transaction invalid" (F4). At consensus the check is on the live outcome at the tx's position in the block, so a builder cannot include two competing proposals: the second's frame 2 reverts and its frame 3 invalidates it. Includes the loser anyway → block invalid (F13).

**Cost.** Winner: +1 frame (475) + cold access to `STATUS_VERIFIER` (3,000 under EIP-8038, F11) + ~20 gas execution ≈ +3.5k (estimate). No `G`, no `proposeFor`, no calldata pins: the frame tx is otherwise the minimal `[self_verify][user_op]` shape. Loser: 0, always — also for blob-carrying and proof-carrying variants (blob cost is inside `max_cost`, never escrowed because `payer` is never set; F6/F10).

**Latency.** None.

**Where it can travel.** Private/direct-to-builder only: structural rule 8 rejects it from the public mempool (F4). The protection therefore *requires* a builder lane that accepts post-prefix `VERIFY` frames, but its *safety* does not depend on the builder: a dishonest or careless builder cannot land the loser. Exactly the "revert protection with consensus teeth" that 7b lacks. EIP-8141 co-author derek describes this use explicitly for private pools: "if private pools want to use atomically batched VERIFY frames to enable use cases like revert protection, they are free to do so." (VERIFIED magicians-thread.txt #147, 2026-05-05; that post is about batched VERIFY, which the current text still forbids — `assert frame.mode != VERIFY` for batch members — but a plain trailing `VERIFY` after a non-batched `SENDER` frame needs no batching.)

**Failure modes.**
- (i) **Unpaid simulation is the full transaction**, not a ≤100k prefix: a builder must execute frame 2 (up to `TX_MAX_GAS_LIMIT = 16,777,216`, VERIFIED constant) to learn validity. That is the same cost profile as simulating a revert-protected bundle today, which builders already do, and under ePBS the builder simulates its own payload anyway; but it is why this can never be public-pool flow, and a builder must rate-limit it per sender/payer.
- (ii) **Spec drift, the real risk.** Two live discussions could remove it at consensus: the async-execution proposal to fix `VERIFY` frames to the head of the frame list with a consensus gas cap (thread #53/#79, ft-spec-model.md §10.11), and the "guarantor / fail-but-pay" request (thread #166 alex-forshtat, 2026-08-05: a mode for "validation failed, state changes reverted, gas fee still paid", VERIFIED magicians-thread.txt) which, if adopted as the *default* for late `VERIFY` frames, would turn this loser into included-and-charged. Neither is in the text today; both must be tracked (ft-spec-model.md §10.10-11).
- (iii) The trailing frame cannot distinguish "reverted because someone else won" from "reverted because my own tx was wrong" — both are free, so a buggy client can spam builders at zero cost. Builder-side reputation handles this exactly as it handles bundle spam today.
- (iv) A `SENDER` frame that *succeeds* but does the wrong thing is not caught unless the outcome-pinning variant is used.

**Squatting / griefing.** None against other proposers: no shared resource; `P`'s nonce is private; a griefer can only make the winner's own action revert, and then the winner pays nothing either. The baseline's L1, L2, L3, L5 all vanish; L4 (spec drift) remains and is arguably larger because the construction relies on a shape the mempool section calls out as undesirable.

**Combination with the baseline.** `G`-sender + trailing status `VERIFY` gives a `(G, n)` tx whose reverted `SENDER` frame no longer burns `n` (tx invalid → nonce not consumed, F1) — this removes L3 for the private path while keeping `(G, n)` identity so it competes with public-pool variants for the same seat. The cost is that the combined tx is itself private-only.

**EIP changes.** None for consensus. Public-pool admission would need a policy exception ("a trailing `VERIFY` frame that reads only `FRAMEPARAM`/`TXPARAM` and has `limits.execution ≤ X` is allowed") — small, but it defeats the reason for rule 8 (bounded unpaid simulation), so it is unlikely to be accepted.

**Verdict.** The most general and the cheapest zero-cost-loser construction; private-only; highest sensitivity to spec drift.

---

## 9. Comparison table

| | Baseline: nonce as a lock | A1 claim VERIFY (state read) | A2 seq counter | A3 commit-reveal | A4 expiry-only | A5 multi-gate / per-role | A6a 7702 shared nonce | A6b builder revert protection | A6c Taiko guard today | A7 trailing status VERIFY |
|---|---|---|---|---|---|---|---|---|---|---|
| Loser outcome, same slot | INVALID (nonce) | INVALID (VERIFY) | INVALID (VERIFY) | commit: REVERT (cheap); reveal: no race | REVERT | INVALID per gate | REVERT | dropped (policy) or REVERT on leak | REVERT | INVALID (VERIFY) |
| Loser outcome, stale/late | INVALID | INVALID | INVALID | INVALID if frame-locked | INVALID (expiry) | INVALID | REVERT | policy | REVERT (`DeadlineExceeded`) | INVALID |
| Winner's own revert (bad proof, FI, ring buffer) | REVERT, **burns shared nonce** | REVERT, pays, lock intact (unless pinned) | same as A1 | REVERT, pays | REVERT, pays | REVERT, burns that gate's nonce | REVERT | policy | REVERT | **INVALID, pays nothing** |
| Consensus-level guarantee | yes | yes | yes | only if frame-locked | only for stale | yes | no | no | no | yes |
| Public-mempool eligible | **yes** | no (F2) | no (F2) | commit yes; reveal no if frame-locked | yes | yes | n/a | n/a | yes | no (F4) |
| Winner overhead (est., UNVERIFIED) | +13.5k (PDF) | ≈ +4k net | ≈ +7k | +45k + 2nd tx | +3.7k | as baseline | 0 | 0 | 0 | ≈ +3.5k |
| Loser cost | 0 | 0 | 0 | ~25-45k (commit) | full gas + blob | 0 | full | 0 or full | full | 0 |
| Latency | 0 | 0 | 0 | ≥ +1 slot | 0 | 0 | 0 | 0 | 0 | 0 |
| `n+1` same block (L1) | REVERT, burns nonce | INVALID (with NUMBER pin) | as A1 | n/a | REVERT | REVERT, burns lane nonce | — | — | REVERT | INVALID |
| Squatting exposure | single seat (needs MIN_TIP) | none | none | high (needs bond) | none | k seats | — | — | none | none |
| Pipelining (sign `n`,`n+1` ahead) | no (one pending per sender) | yes | yes | yes | yes | yes (per gate) | — | — | yes | yes |
| Contract changes | G + Inbox `proposeFor` + FI/fee/checker changes | tiny helper; Inbox unchanged | helper + counter | registry + bond | none | k gates + Inbox set | — | — | none | tiny helper; **Inbox unchanged** |
| Needs EIP change | no | policy only for public pool | policy only | no | no | no (8250 optional) | impossible | no | no | policy only for public pool |
| Spec-drift sensitivity | G hard-codes Draft (8250, expiry PRs) | consensus VERIFY read cap | as A1 | low | low | as baseline | — | — | — | **high** (VERIFY-after-payer, fail-but-pay) |
| Depends on builder honesty for safety | no | no | no | no | no (but builder profits from loser) | no | — | **yes** | yes | no |

---

## 10. Recommendation ranking

1. **A7 trailing status `VERIFY`** — for every participant that submits directly to builders (which the PDF says serious proposers do). It gives zero-cost losing for *every* revert, for propose, prove and propose-with-proof alike, with no shared resource, no `G`, no Inbox change and the smallest overhead. Its safety does not depend on the builder; only its *availability* does. Track the two spec threads that could remove it.
2. **A1 claim `VERIFY` in the prefix** — same audience, slightly more expensive, catches only what it pins, but survives a future consensus rule against `VERIFY` frames after payment. Use it as the fallback shape for A7, or combine (claim check in the prefix, status check trailing).
3. **Baseline nonce as a lock (+ A5 per-role gates, + A4 expiry)** — the only construction whose zero-cost race propagates through the **public** mempool. Keep it for public-pool participants and as censorship-resistance fallback; accept L1-L3, and require per-role gates so a prover can never burn a proposer's seat. Do not adopt the PDF's Inbox changes (`proposeFor`, FI rule, pull-fees, open checker) *only* for this; they are needed by the baseline because of L3, and L3 does not exist in A7/A1.
4. **A4 expiry frame** — adopt everywhere, it is free; it fixes only the stale case.
5. **A5 parity/lane gates** — only as an extension of 3 when pipelining is worth the extra seats.
6. **A6b builder revert protection** — status quo; keep as belt-and-braces.
7. **A3 commit-reveal** — not for the propose race; see §11 for proving assignments.
8. **A6a 7702 shared nonce** — impossible; **A6c** — status quo to be replaced.

The decisive structural fact: **public-pool eligibility and revert-proofness are mutually exclusive under the current mempool policy** (C2 + F4). The baseline chooses eligibility; A1/A7 choose revert-proofness. A rollup that must serve both audiences needs both shapes on the same seat, which is possible because a `(G, n)` tx with a trailing `VERIFY` and a plain `(G, n)` tx are alternatives for the same nonce.

---

## 11. How this changes Etna's design for propose-with-proof races (R7) and role competition

R7 (Etna README, VERIFIED `packages/protocol/docs/Etna/README.md:33`): "The design has a single L1 transaction type (or frame) that carries both batch data and proof". Under R7 the racing transaction carries blobs **and** a ZK proof; losing it is the most expensive loss the protocol has, and — because proving "takes minutes" — several provers can plausibly hold valid proofs for the same segment at once. The alternatives change the design in five concrete ways:

1. **Proof reverts must not burn a shared seat.** With the baseline, `proposeFor` reverting inside `verifyProof` (a wrong or stale proof) consumes `n` without producing a proposal: whoever can outbid the honest tip for one slot can waste that slot at gas cost, every slot (PDF §3 "reverts that can still burn the nonce" lists only the ring buffer and `n+1`, because the PDF's action has no proof). R7 adds proof validity as an other-triggerable revert only if `G` cannot check it — and `G` cannot (no state reads, no proof verification in ~14k gas). **A7 removes the lever entirely**: a bad-proof tx is invalid and free, and the seat is untouched. So for R7 the direct-to-builder path should be A7 (optionally A7-on-`G`), not the plain baseline.

2. **One-proposal-per-block is no longer a cost lever, but it is still a spam bound.** Under A1/A7 a second proposal in the same block is invalid, not reverted, so `CannotProposeInCurrentBlock` costs nobody anything and can stay as the ring-buffer bound (PR #20186's purpose). Under the baseline it must stay for the same reason and additionally hurts pre-signers (L1). If Etna wants `K > 1` proof-carrying proposals per L1 block (e.g. several provers landing different segments), replace the rule by a per-block counter `≤ K`; with A7 that is safe, with the baseline it needs `K` parity gates and still burns lanes on ordering collisions.

3. **Provers can race at zero cost — by which mechanism depends on the audience.** Today a losing `prove` reverts with `LastProposalAlreadyFinalized` or `ParentBlockHashMismatch` (Inbox.sol:805, 346, VERIFIED) and pays for proof calldata. (a) Direct-to-builder provers: A7 on the prover's own nonce, no gate — the losing proof is invalid and free, and a prover can keep several candidate segments in flight (own nonce, private variants). (b) Public-pool provers: a dedicated `G_prove` (A5) gives the baseline's guarantee, at the price of a squattable seat and of L3 (a reverting proof burns `G_prove`'s nonce; a griefer who outbids can waste proving seats). Recommendation: provers use A7; expose `G_prove` only if a public-pool proving path is a hard requirement.

4. **Multiple gates for multiple roles: yes, but only where a gate is used at all.** If the baseline is retained for the public path, never share one `G` between propose and prove (A5 per-role gates, zero cost, no EIP). For the private path, gates are unnecessary: A7 uses the actor's own nonce, and the Inbox keeps `msg.sender == P` (the `SENDER` frame's caller is `tx.sender`, VERIFIED), so **none of the PDF's Inbox changes (`proposeFor`, `_proposalGate`, FI-by-due-time, pull fees, opened checker, `expectedProposalId`) are required by A7**. Two of them remain independently desirable for R7 because they remove other-triggerable *reverts* that, even at zero cost, waste the winner's slot: FI-by-due-time (so a stuffed FI queue cannot push a proof-carrying proposal over its gas limit) and pull-based FI fees. `expectedProposalId` is still useful as an outcome pin in the A7 outcome-checking variant.

5. **Bridging the proving window and role competition.** R7 asks how preconfirmed blocks bridge the minutes-long proving window. Commit-reveal (A3) is the wrong tool for the same-slot race but the right tool for *assigning* proving work minutes ahead: a cheap bonded commit ("I will deliver the proof for segment `[a, b]` by slot `S`"), then an uncontested reveal. With A7 the reveal itself is revert-proof, so a prover that misses its window loses only its commit bond, never a blob fee. Role competition (proposer vs. prover vs. forced-inclusion submitter) then reduces to: proposers race per slot (A7/baseline), provers reserve by commit (A3) and deliver via A7, and forced inclusions are consumed by due time so they cannot be weaponised against either.

Net effect on the Etna spec: keep the PDF's `G` as the **public-mempool** race primitive (with per-role gates, expiry, MIN_TIP), but make the **primary** R7 path a plain frame tx from the actor's own key with an expiry frame in front and a status `VERIFY` frame behind. That path needs no new Inbox trust root, tolerates proof reverts for free, allows pipelined and multi-segment submissions, and is one 15-byte helper contract away from deployable on a frames devnet — while carrying the explicit, documented risk that the frame-transaction working group may later forbid or re-price post-payment `VERIFY` frames, in which case A1 (claim check in the prefix) is the drop-in replacement.

---

## 12. UNVERIFIED items in this document

1. All gas *estimates* (A1 ≈ +4k net, A2 ≈ +7k, A3 ≈ +45k/25-45k, A4 ≈ +3.7k, A7 ≈ +3.5k) and the PDF's 30,944 / 75,594 / +13.5k figures — not simulated; only `FRAME_TX_PER_FRAME_COST = 475`, EIP-8038 cold access 3,000, cold SLOAD 2,100, `TX_MAX_GAS_LIMIT = 16,777,216`, and `KEYED_NONCE_FIRST_USE_STATE_GAS = 97,920` are spec constants.
2. That including an invalid frame tx makes the block invalid is inherited from the general rule, not restated in EIP-8141 (F13).
3. Whether any builder today (or on a frames devnet) accepts state-reading or post-prefix `VERIFY` frames in a private lane, and how it tracks their dependencies across heads — no builder documents frame-tx handling as of 2026-09-30.
4. That a public-mempool copy of a privately submitted tx can land and revert (inference; ft-client-behaviour.md item 4).
5. The behaviour of the EOA *default code* when a `VERIFY` frame with flags `0` targets an EOA — avoided by using a dedicated helper contract in A1/A7.
6. The `STATUS_VERIFIER` bytecode sketch is illustrative and not assembled or tested (Foundry/revm cannot execute `0xb3`; only EELS/hive/devnet can).
7. Whether the `NUMBER`-based same-block pin in A1 is acceptable to any private pool (consensus-legal; policy-banned in the public prefix).

## 13. Sources (all fetched or read 2026-09-30)

- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md — Frame Transaction (Draft); local copy `eip-8141-raw.md`; quotes from "Constraints", "Behavior", "Cross-frame interactions", "FRAMEPARAM Instruction", "Validation Prefix", "Policy Summary", "Structural Rules", "Banned Opcodes", "Replacement and Eviction", "Revalidation", "Transaction origination", "Security Considerations".
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7702.md — Set Code for EOAs (Final); local copy `eip-7702-raw.md`.
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8250.md — Keyed Nonces for Frame Transactions (Draft).
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-3607.md — Reject transactions from senders with deployed code (Final).
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8038.md — State-access gas cost update (Review).
- https://raw.githubusercontent.com/ethereum/ERCs/master/ERCS/erc-7562.md — Account Abstraction Validation Scope Rules (Review).
- https://ethereum-magicians.org/t/frame-transaction/27617 — thread; local copy `magicians-thread.txt` (#147 derek 2026-05-05; #166 alex-forshtat 2026-08-05; #53/#79 async execution).
- `ft-spec-model.md`, `ft-client-behaviour.md`, `ft-taiko-inbox-facts.md` (this directory) — for EIP-4844 blob-fee burn, client replacement rules, EIP-7732/ePBS, Flashbots/Titan docs, EIP-8081 fork inclusion, and the Taiko PR history (#18570, #20186, #19488).
- packages/protocol/contracts/layer1/core/impl/Inbox.sol and iface/IInbox.sol (HEAD 61d8f18) — `propose`, `prove`, `_validateCommitment`, `getCoreState`, error list.
- packages/protocol/docs/Etna/README.md — requirement R7.
- packages/protocol/docs/Etna/inputs/nonce-as-a-lock.txt — the baseline design.
