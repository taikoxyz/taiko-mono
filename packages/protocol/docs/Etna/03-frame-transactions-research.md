# 03. Frame Transactions as a mutual-exclusion primitive

Prepared 2026-09-30 for the Etna project. Every external fact below is tagged **VERIFIED** (primary source fetched on 2026-09-30, URL given) or **UNVERIFIED**. Every design claim is tagged **proven** (with the argument or quote), **assumed** (the assumption is named), or **open** (what would resolve it). Quotes marked `[8141 L###]` are verbatim from `https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md` as re-fetched on 2026-09-30 for this document (1472 lines, md5 `284f4d79ea303353412f58eb73d09421`, byte-identical to the copies used by the phase-2 inputs).

Inputs synthesized (all read in full): `packages/protocol/docs/Etna/inputs/nonce-as-a-lock.txt` (the user-provided "Nonce as a Lock" PDF, 7 pages), and the phase-2 working notes `ft-spec-model.md`, `ft-client-behaviour.md`, `ft-taiko-inbox-facts.md`, `ft-analysis-nonce-lock.md`, `ft-alternatives.md`.

Fetch-failure record for this document: none. (The phase-2 inputs record that `api.github.com` returned HTTP 403 through the session proxy and that `gh` is not installed; PR states were obtained from the PR HTML pages and the GitHub MCP search tool instead.)

---

## 0. Verdict

**Possible, without EIP changes.** Under the EIP-8141 text as of 2026-09-30, a frame transaction whose `sender` is a shared, non-upgradeable gate contract G and whose `nonce` is G's account nonce gives a consensus-level mutual-exclusion primitive: of any set of transactions sharing `(G, n)`, at most one can ever be included, and every other is *invalid* (not includable in any valid block, charged nothing, including its blob fee) rather than *included-and-reverted*, because the nonce check is the first step of frame-transaction processing, before any signature or frame is evaluated, and nothing is charged until a payment-scoped `APPROVE` executes. Confidence: **high** on the consensus semantics (every load-bearing step is a verbatim spec line and needs no EIP change); **medium** on the operational path (EIP-8141 is a Draft scheduled for Hegotá with no shipped client mempool, an open PR would move the expiry verifier address that G pins, and the mechanism fixes only *who pays*, not *whether the slot is used*: any revert of the winner's action after payment approval still burns the shared nonce for everyone). The primitive is therefore adoptable for Etna, but not as the PDF's single mechanism: Section 8 recommends a two-shape gate design in which the shared-nonce transaction is the public-mempool shape and a trailing status `VERIFY` frame on the actor's own nonce is the direct-to-builder shape.

---

## 1. Question and method

**Question.** Etna needs a "propose-with-proof" action (requirement R7: "a single L1 transaction type (or frame) that carries both batch data and proof", `packages/protocol/docs/Etna/README.md`, read 2026-09-30) that several parties may race to submit in the same L1 slot. Today the loser of such a race lands, reverts at the Inbox, and pays execution gas plus a burned blob fee. The PDF "Nonce as a Lock" claims EIP-8141 Frame Transactions can make the loser *invalid* instead, at zero cost. This document answers: is that possible under the current spec, with what caveats, with what alternatives, and what should Etna adopt.

**Method.** (1) Re-fetch EIP-8141, EIP-8081 (Hegotá meta), EIP-8250, and the relevant EIP PRs from primary sources on 2026-09-30 and build a validity model from verbatim text (Section 3). (2) Check client and builder behaviour (geth, reth, Nethermind pools; flashbots builder/relay; consensus-specs Gloas for ePBS) from their repositories. (3) Check the Taiko-side facts against `Inbox.sol` at HEAD `61d8f18`. (4) Falsify the PDF claim by claim (Section 4). (5) Enumerate alternative constructions and compare (Section 5). (6) Work a concrete example (Section 6). (7) Tag every assumption (Section 7) and derive consequences for Etna (Section 8). Nothing in this document was taken from memory; where a fact could not be fetched, it is marked UNVERIFIED.

---

## 2. EIP-8141 at the time of writing

All fetched 2026-09-30.

| Field | Value | Source |
|---|---|---|
| Number, title | EIP-8141, "Frame Transaction" | VERIFIED — raw md front matter, https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md |
| Status | `Draft`; rendered page shows "Draft Standards Track: Core", no last-call deadline | VERIFIED — https://eips.ethereum.org/EIPS/eip-8141 |
| Type / category | Standards Track / Core | VERIFIED — raw md |
| Created | 2026-01-29 | VERIFIED — raw md |
| Requires | 1559, 2718, 2780, 3529, 3607, 4844, 7594, 7702, 7708, 7778, 7825, 7976, 8037 | VERIFIED — raw md |
| Authors | Vitalik Buterin, lightclient, Felix Lange, Yoav Weiss, Alex Forshtat, Dror Tirosh, Shahaf Nacson, Derek Chiang, Toni Wahrstätter, Stavros Vlachakis | VERIFIED — raw md |
| discussions-to | https://ethereum-magicians.org/t/frame-transaction/27617 (169 posts through 2026-09-29) | VERIFIED — raw md; thread JSON fetched by phase-2 |
| Transaction type | `FRAME_TX_TYPE = 0x06` | VERIFIED — raw md |
| Last commits | `5c0236f` "replace 7623 with 7976" (lightclient, 2026-09-29); `857622a` "bound producer-side re-execution of an unapproving validation prefix" (AnkushinDaniil, 2026-09-29); `b75cbe6` "Remove a redundant check for frame's state gas limit" (raxhvl, 2026-09-01); `7d1c8bf` (2026-08-24); `3ceef8d` (2026-08-21) | VERIFIED — https://github.com/ethereum/EIPs/commits/master/EIPS/eip-8141.md |
| Target fork | EIP-8081 "Hardfork Meta - Hegotá" (Draft) lists EIP-8141 under **Scheduled for Inclusion** (with EIP-7805 FOCIL); EIP-8250 "Keyed Nonces for Frame Transactions" under **Considered for Inclusion** | VERIFIED — https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8081.md |
| Preceding fork | Glamsterdam (ePBS EIP-7732, EIP-8038, EIP-2780 per phase-2 roadmap) is scheduled on Sepolia 2026-10-06; "Hoodi and mainnet activation dates have not yet been decided" | VERIFIED — https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement |

Note: the PDF pins commit `b75cbe6115`. Two later commits exist (both 2026-09-29); neither changes the semantics G depends on (proven: the commit titles concern producer-side eviction policy and the calldata-floor EIP reference; the diff of the nonce, APPROVE, VERIFY and expiry sections was not separately verified, so "no semantic change" is **assumed** from the titles and from the byte-identical text used by all phase-2 analysts on the same day).

**Open PRs that touch this design** (states fetched 2026-09-30 from the PR pages):

| PR | Title | State | Effect on G |
|---|---|---|---|
| ethereum/EIPs#12252 | "add valid_after to the expiry verifier frame" (nerolation, opened 2026-08-27) | **open, draft** | 16-byte `valid_after || expiry` calldata; adds the not-before bound the PDF wants. https://github.com/ethereum/EIPs/pull/12252 |
| ethereum/EIPs#12387 | "deploy frames expiry verifier as standard contract" (lightclient, opened 2026-09-28) | **open, draft** | changes `EXPIRY_VERIFIER` from `address(0x8141)` to `0x81413f0cF12e9b6a49B1D0439E081c577D57FfFf` (diff fetched by phase-2). A G that pins `0x8141` fails closed on every transaction. https://github.com/ethereum/EIPs/pull/12387 |
| ethereum/EIPs#12198 | "make the expiry frame a new mode" (nerolation) | **closed unmerged 2026-09-29**; lightclient: "Closing as I think we discussed previously and the general consensus was to keep as canonical verifier." | threat listed by the PDF is withdrawn. https://github.com/ethereum/EIPs/pull/12198 |
| ethereum/EIPs#12253 | opcode/frame-mode registry (AnkushinDaniil, opened 2026-08-27) | open | keeps EIP-8141's own opcodes ("SIGDATACOPY keeps 0xB5 because it is a base-8141 opcode and the family core") but renumbers the dependent EIP-8266 opcode `RECENTROOTREFLOAD` from `0xB5` to `0xB6` ("Registry-conformant allocation supersedes any per-draft byte a dependent EIP previously specified"); no effect on a G that uses only 8141 opcodes, but it is the vehicle by which numbering could still change before Final. https://github.com/ethereum/EIPs/pull/12253 (corrected after skeptic review, 2026-09-30) |
| ethereum/EIPs#12321 | early rejection / payer revalidation (sm-stack, 2026-09-11) | open | mempool-only. https://github.com/ethereum/EIPs/pull/12321 |
| others open (mempool/paymaster policy) | #12214, #12301, #12328, #12330, #12340, #12041, #12236, #12322 | open | none touch consensus nonce/VERIFY semantics (per titles; UNVERIFIED by diff) |

**Client implementation status** (VERIFIED 2026-09-30, from `ft-client-behaviour.md` sources): geth — PR #35666 open draft "Still WIP" against master; devnet branch `frames-devnet-0` accepts type 6 in the legacy pool with no frame-specific pool logic; PR #35814 (one-pending-per-sender, revalidation) **closed unmerged 2026-09-29**. reth — PR #27154 open draft, no frame logic in `crates/transaction-pool` on `main` (code search: 0 hits). Nethermind — most complete; devnet branch `eip8141-frame-txs-devnet7`, per-payer exposure (#12617 merged); PR #13058 ("frame-tx MAX_VERIFY_GAS 300k -> spec 100k") was **closed without merge on 2026-09-02**, the author keeping `FrameTxMaxVerifyGas` at a configurable 300,000 default ("100000 is the spec's floor for public-mempool acceptance, not a ceiling"), so Nethermind does not enforce the spec's 100k literally; literal one-pending-per-sender gate UNVERIFIED. (Corrected after skeptic review, 2026-09-30.) ethereumjs — nothing found. EELS — PR #3047 merged 2026-08-13 into `eips/amsterdam/eip-8141` (state transition only, no mempool).

---

## 3. Validity model of a frame transaction

Terminology: "INVALID" means the transaction is not includable (`invalid_transaction()` in the spec; the block that contains it is invalid under the inherited execution rule); "REVERT" means the transaction is included and the payer is charged for what was consumed.

### 3.1 Condition table

| # | Condition | INVALID or REVERT | When checked | Who pays | Evidence |
|---|---|---|---|---|---|
| 1 | Static constraint violated (`len(frames)` not in 1..64, bad field lengths, `mode >= 3`, `flags >= 8`, `value != 0` on a non-`SENDER` frame, `APPROVE_EXECUTION` flag on a frame whose target is not the sender, `ATOMIC_BATCH_FLAG` on a `VERIFY` frame, gas over `TX_MAX_GAS_LIMIT`, malformed expiry frame, more than one expiry frame) | INVALID | statically, before any state access | nobody | VERIFIED, "Constraints" section; "If a flag is not valid under the current mode, the transaction is invalid." |
| 2 | `tx.nonce != state[tx.sender].nonce` | INVALID | step 1 of processing, before signatures and before any frame | nobody | VERIFIED [8141 L390-392]: "To begin processing a frame transaction: 1. Ensure `tx.nonce == state[tx.sender].nonce`" |
| 3 | Any protocol-validated (`SECP256K1`/`P256`) signature invalid or any entry malformed | INVALID | step 3, before any frame | nobody | VERIFIED: "If any signature is malformed, or any protocol-validated signature is invalid, the whole transaction is invalid." |
| 4 | A `VERIFY` frame reverts or halts exceptionally (including OOG on its `limits.execution`, the entry cold-access charge not covered, the expiry check failing, an `APPROVE` reverting inside it) | INVALID | during that frame | nobody | VERIFIED [8141 L423-425]: "Execute the frame as a `STATICCALL`, disallowing state manipulation. Only `APPROVE` can modify the state or transaction context in `VERIFY`. If the frame fails by reverting or halting exceptionally, the transaction is invalid. This unrolls any effects of `APPROVE`." |
| 5 | A `SENDER` frame is reached with `sender_approved == false` | INVALID | at that frame's entry | nobody | VERIFIED [8141 L407-409]: "If mode is `SENDER`: `sender_approved` must be `true`. If not, the transaction is invalid." |
| 6 | End of transaction with `payer == None` | INVALID | after all frames | nobody | VERIFIED [8141 L434]: "After executing all frames, verify that `payer` has been set (i.e. `payer != None`). If it is not, the whole transaction is invalid." |
| 7 | Blob-carrying transaction with `max_fee_per_blob_gas < blob_base_fee` | not includable in that block | block inclusion | nobody | VERIFIED [8141 L655]: "The transaction is only valid for inclusion in a block if `tx.fees.max_fee_per_blob_gas >= blob_base_fee` of that block." |
| 8 | Worst-case gas does not fit the block's remaining execution or state capacity | not includable | block building/validation | nobody | VERIFIED: "A frame transaction may be included in a block only if its worst case fits the remaining capacity of **each** dimension" |
| 9 | A `DEFAULT` or `SENDER` frame reverts or halts (OOG, state-gas exhaustion, insufficient balance for `value`) | REVERT of that frame; transaction included | during frame | payer (`max_cost` escrowed at APPROVE; unused gas refunded at settlement) | VERIFIED [8141 L421]: "If a frame's execution reverts, its state changes and approval context (`payer`, `sender_approved`) are discarded."; [L1218]: "After approval the transaction is still included and pays for the gas consumed, while a failed `VERIFY` frame invalidates the transaction as usual." |
| 10 | A frame inside an atomic batch fails | batch unrolled, later batch frames skipped (status 2); transaction included | during batch | payer | VERIFIED [8141 L1176]: "Unrolling a failed batch therefore never rolls back the sender nonce increment or the `max_cost` collection" |
| 11 | Redundant or conflicting `APPROVE` (second payer, second execution approval, `ADDRESS != resolved_target`, scope not in flags) | REVERT of the current *call frame*; in a `VERIFY` frame that propagates to row 4 (INVALID) | during APPROVE | see row 4 / 9 | VERIFIED [8141 L700-720]: "If `ADDRESS != resolved_target`, revert." "If `payer` was already set, revert the current call frame." |
| 12 | A `VERIFY` frame *after* the paying frame fails | INVALID (row 4 applies regardless of position) | during that frame | nobody | VERIFIED: consensus text places no positional restriction; the public mempool rejects the shape [8141 L965] "8. There must not be `VERIFY` frame after validation prefix." with the reason [L950] "otherwise their revert would make entire transaction invalid." |

Structural consequence (proven from rows 2, 4, 6, 9): "invalid, pays nothing" is reachable from exactly three places, the pre-frame nonce/signature checks, any `VERIFY` frame failure, and the expiry frame (which is a `VERIFY` frame). Everything that happens in a `SENDER`/`DEFAULT` frame is a paid revert.

### 3.2 Nonce semantics

Proven from verbatim text:

1. Check: exact equality against the sender's account nonce in the pre-state at the transaction's position in the block, as step 1 [8141 L392]. Because `sender` is an explicit envelope field, no signature recovery precedes the check.
2. Increment: only inside a payment-scoped `APPROVE` [8141 L717]: "Increment the sender's nonce, set `payer = resolved_target`, and collect the transaction's `max_cost` from `payer`." `APPROVE_EXECUTION` alone does not touch the nonce [L709-711].
3. Ordering: `APPROVE_PAYMENT` requires `sender_approved == true` [L715] ("If `sender_approved == false`, revert the current call frame."), so the sender's `only_verify` frame must precede the payer's `pay` frame.
4. Rollback: if the `VERIFY` frame that executed the payment `APPROVE` fails, the increment is unrolled and the transaction is invalid (row 4). A later `SENDER` revert or batch unroll never rolls it back (rows 9, 10).
5. Exactly-once: [8141 L1096] "Pending frame transactions are identified by `(sender, nonce)`. The sender's nonce is consumed exactly once per transaction when payment is approved, so two pending transactions sharing it are alternatives, of which at most one can ever be included."
6. Contract senders: [8141 L1112-1114] "Do not apply the restriction put in place by [EIP-3607] to frame transactions. Specifically, `SENDER` frames originate calls where `tx.sender` is a contract account. Validation logic for other transaction types remains unchanged". So G can be the sender of a frame transaction and of nothing else.
7. Block invalidity: EIP-8141 never restates that an invalid transaction makes the block invalid. That is the inherited execution rule (execution-specs `check_transaction`: "Check if the transaction is includable in the block. Raises InvalidBlock" with `NonceMismatchError("nonce too low")`, VERIFIED for existing types from https://raw.githubusercontent.com/ethereum/execution-specs/master/src/ethereum/forks/osaka/fork.py). Application to type 0x06 is the only coherent reading of `invalid_transaction()` and of [L1218] "Intrinsic gas is state-independent and decides validity", but is **UNVERIFIED as a quoted 8141 sentence**. The EELS branch `eips/amsterdam/eip-8141` would settle it (open item, Section 9).
8. EIP-8250 (Draft, Considered for Inclusion) would replace `nonce` with `(nonce_keys, nonce_seq)`; `nonce_keys == [0]` aliases the account nonce; "This EIP preserves EIP-8141's limit of one pending frame transaction per sender in the public mempool." (VERIFIED https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8250.md).

### 3.3 Expiry semantics

VERIFIED [8141 L323]: "A `VERIFY` frame whose `frame.target` equals `EXPIRY_VERIFIER` is an **expiry verifier frame**. It calls the expiry verifier contract deployed at `EXPIRY_VERIFIER` with `frame.data` as calldata. The calldata is interpreted as an 8-byte unsigned big-endian expiry timestamp. The call reverts unless `block.timestamp <= expiry_timestamp`." Constants: `EXPIRY_VERIFIER = address(0x8141)`, `EXPIRY_DATA_LENGTH = 8`. Static rules: `flags == 0`, `value == 0`, `limits.state == 0`, `len(data) == 8`, at most one such frame. Clients install the canonical runtime code `0x60083614600a575f5ffd5b5f3560c01c4211601657005b5f5ffd` at activation.

- Failure is a `VERIFY` failure: INVALID, nobody pays (proven, row 4).
- **Upper bound only.** No `valid_after` exists in the current text (grep of the re-fetched file: zero hits). PR #12252 (open draft) would add it.
- Mempool: [8141 L971] "An `expiry_verify` frame MAY appear only as first frame in the frame list."; [L973] "A node MUST drop a frame transaction from the public mempool if it contains an `expiry_verify` frame whose deadline is less than the node's view of the current block timestamp at any point." Eviction order [L1102] prefers "transactions with the nearest expiry deadline" after already-invalid ones.
- **Pending change:** PR #12387 (open draft, 2026-09-28) would move the verifier to an ordinary deployed contract at `0x81413f0cF12e9b6a49B1D0439E081c577D57FfFf`; semantics unchanged, address changed.

### 3.4 VERIFY restrictions

Consensus-level (VERIFIED [8141 L423-425]): executed as a `STATICCALL`; `caller = ENTRY_POINT`; `value` must be 0; cannot be in an atomic batch; failure invalidates the transaction. Storage **reads** of any account are legal at consensus (STATICCALL permits `SLOAD` and view `CALL`s). There is no consensus gas cap on `VERIFY` beyond the frame's own `limits.execution` and `TX_MAX_GAS_LIMIT = 16,777,216`.

Public-mempool policy only (VERIFIED, "Mempool"; [8141 L864] "Transactions outside these rules may be accepted into a local or private mempool, but must not be propagated through the public mempool."): `MAX_VERIFY_GAS = 100_000` summed over the validation prefix plus signature-validation intrinsic; banned opcodes in the prefix include `TIMESTAMP` (except the canonical expiry verifier), `NUMBER`, `BASEFEE`, `BLOBBASEFEE`, `BALANCE`, `GASPRICE`, `CREATE*`, `SSTORE` (except `deploy`); [L1030] "`SLOAD` can be used only to access `tx.sender` storage, including when reached transitively via `CALL*` or `DELEGATECALL`."; recognized prefixes `[self_verify]`, `[deploy, self_verify]`, `[only_verify, pay]`, `[deploy, only_verify, pay]`, each optionally preceded by `expiry_verify`; no `VERIFY` frame after the prefix [L965].

This split is the single most important fact for Section 5: **a `VERIFY`-based lock that reads shared state, or that sits after the paying frame, is consensus-valid but public-pool-ineligible.** The only shared fact a public-pool-eligible prefix may depend on is `tx.sender`'s own nonce, code and storage, which is exactly why the PDF makes the shared thing the *sender*.

### 3.5 Blob fees

VERIFIED [8141 L653-655]: "the payer is also the blob-fee payer"; "The payer is charged `blob_gas * blob_base_fee`; no additional blob fee is collected or refunded." Blob cost is part of `max_cost = max_gas * max_fee_per_gas + blob_gas * blob_base_fee`, which is "collect[ed] ... from `payer`" only at the payment `APPROVE` [L717]. [8141 L1104] "A frame transaction is charged nothing until one of its frames approves payment". Therefore an invalid frame transaction has no payer and pays no blob fee (proven). Contrast EIP-4844 (Final): the blob fee "is deducted from the sender balance before transaction execution and burned, and is not refunded in case of transaction failure" (VERIFIED https://eips.ethereum.org/EIPS/eip-4844), which is why today's reverted type-3 loser burns its blob fee. Frame transactions may carry blobs: "When `blob_versioned_hashes` is non-empty, the transaction is a blob-carrying transaction and follows EIP-4844." The EIP-7594 per-transaction limit of 6 blobs applies unchanged (VERIFIED). Mainnet blob parameters today: BPO2, target 14 / max 21 per block (VERIFIED from geth and reth mainnet chain specs).

---

## 4. The nonce-as-lock hypothesis, claim by claim

Legend: **HOLDS** / **CAVEAT** (holds with a named qualification) / **FAILS** / **UNDETERMINED**. Line numbers `txt:N` refer to `nonce-as-a-lock.txt`.

| # | PDF claim | Verdict | Evidence |
|---|---|---|---|
| 1 | Every proposal can use a shared gate contract G as `sender` and share G's nonce (txt:8-9, 13) | HOLDS | proven: [8141 L1112] contract senders allowed for frame txs; one account nonce per sender [L392, L717]. |
| 2 | EIP-8141 checks `tx.nonce == nonce(G)` before executing any frame and increments at payment approval (txt:14-15) | HOLDS | proven: [8141 L390-392] step 1; [L717] increment in `APPROVE_PAYMENT`. |
| 3 | At most one tx sharing `(G, n)` can be included; losers are invalid and pay neither execution gas nor blob fees (txt:15-16) | HOLDS | proven: [8141 L1096] "alternatives, of which at most one can ever be included"; [L1104] charged nothing before approval; [L655] blob fee from `payer` only. |
| 4 | The loser is "includable in no valid block" (txt:10) | CAVEAT | proven for the transaction (row 2 of Section 3.1); the *block*-invalidity consequence is inherited, not restated in 8141 (Section 3.2 item 7, UNVERIFIED as an 8141 sentence). |
| 5 | Expiry: first frame targets `0x8141`, requires `block.timestamp <= expiry`, upper bound only, no not-before (txt:17-19) | CAVEAT | proven today [8141 L323, L971]; no `valid_after` (grep). Caveat: PR #12387 (open draft) would change the address; PR #12252 (open draft) would add `valid_after` and change the data length to 16. A G v1 that pins `0x8141` fails closed under #12387. |
| 6 | G checks only shape via introspection and calls `APPROVE(APPROVE_EXECUTION)` (txt:20-21) | HOLDS | proven: TXPARAM/FRAMEPARAM/SIGPARAM/FRAMEDATALOAD expose every field G reads (Section 2.6 of `ft-spec-model.md`, VERIFIED); [8141 L702-711] only code with `ADDRESS == resolved_target == tx.sender` can grant execution approval. |
| 7 | G's transaction is valid for the public mempool (txt:21-22) | CAVEAT | proven as *policy conformance*: prefix `[expiry_verify, only_verify, pay]` is recognized, G's opcodes are not banned, P as an empty-code payer is "not a paymaster". Caveat: no shipped client implements the 8141 mempool section (Section 2); "valid for the public mempool" is a statement about a policy no node yet runs. |
| 8 | The Inbox stays plain Solidity; `proposeFor` trusts G alone; no new opcodes (txt:23-24) | HOLDS | proven: the four `msg.sender` uses on the propose path are exactly `Inbox.sol:596/603/606/615` (VERIFIED at HEAD 61d8f18); inside the `SENDER` frame `caller = tx.sender = G` [8141 L409-410]. |
| 9 | Exclusivity is per nonce, not per block; builder still picks by tip (txt:25-26) | HOLDS | proven: identity is `(sender, nonce)` [L1096]; the spec does not constrain the builder's choice among alternatives. |
| 10 | Frame layout: `[expiry 0x8141 [3200,0]] [only_verify G flags 2 [5000,0]] [pay P flags 1 [3500,0]] [SENDER Inbox proposeFor(P, packed) 68 bytes]` (txt:33-76) | CAVEAT | proven as legal (static rules, recognized shapes, EOA default code [8141 L664-671] selects signature index 1 when only the payment bit is set). Caveat: whether G's ~45 checks fit in 4,900 gas is UNVERIFIED (no bytecode exists); gas figures for frames 0 and 2 (cold access 3,000 under EIP-8038, VERIFIED https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8038.md) are arithmetic. |
| 11 | Signatures `[[ARBITRARY,"","",""],[SECP256K1,P,"",sig_P]]`; index 0 is a zero-length placeholder; G pins its length to 0 to prevent padding (txt:77-82) | HOLDS | proven: `ARBITRARY` requires empty signer and passes any raw bytes; [8141 L1446] "When an `ARBITRARY` signature has empty `msg`, its raw bytes are elided from the canonical signature hash and can therefore be changed without changing `TXPARAM(0x08)`"; SIGPARAM `0x03` returns `len(signature)` for ARBITRARY, so G can pin it. A padded variant fails G and is invalid, so nobody pays for it. |
| 12 | P's empty-`msg` signature binds the whole transaction (txt:84-85) | HOLDS | proven: [8141 L1466] "A signature with an empty `msg` commits to this, because it is verified over `compute_sig_hash(tx)`, which covers the full frame list". |
| 13 | `0x8141` is not pre-warmed; cold access is charged to the frame's own limit (txt:86-87) | HOLDS | proven: [8141 L440] "Being a frame target does not warm an address: a `resolved_target`'s warm/cold access is charged at frame entry within the frame's own `limits.execution`." |
| 14 | P must be a plain EOA without 7702 delegation (txt:88-89) | CAVEAT | proven that a delegated P runs its delegate instead of the default code [8141 L419-420]; the tx is then *invalid* (payer never set or OOG in a VERIFY frame), not reverted, so nobody pays. Caveat: a P that deliberately delegates to code that calls `APPROVE(1)` can pass; it can only hurt itself. |
| 15 | VERIFY part ~14k gas, under `MAX_VERIFY_GAS = 100k` (txt:89) | HOLDS | arithmetic: 3,200 + 5,000 + 3,500 + (100 + 2,800) = 14,600 < 100,000 (policy constant, VERIFIED). |
| 16 | Timestamp bounds for L2 derivation; a tx signed before the S−1 block can land in S−1 (txt:90-95) | UNDETERMINED (Taiko side) / HOLDS (8141 side) | proven that there is no not-before bound; Taiko derivation rules ("default manifest containing only the anchor", "1 s per forced inclusion") live outside the contract files checked (UNVERIFIED). |
| 17 | G must be written in standalone Yul `verbatim`, Huff, or raw bytecode; Foundry/revm cannot run it (txt:98-100) | CAVEAT | Yul docs (VERIFIED https://docs.soliditylang.org/en/latest/yul.html): "`verbatim` can be used to generate arbitrary opcodes or even opcodes unknown to the Solidity compiler"; no EIP-8141 PR in upstream `bluealloy/revm` (web search only, UNVERIFIED); EELS branch exists. |
| 18 | "in a non-frame tx the first TXPARAM halts exceptionally, so plain calls always fail" (txt:103-104) | HOLDS | proven: [8141 L733] "Executing any of them in the context of any other transaction type results in an exceptional halt." |
| 19 | Each individual G pin (frame count 4, frame index 1, 2 signatures, MIN_TIP on `max_priority_fee`, ≥1 blob, modes/flags/targets of frames 0-3, sig schemes/msg/signer, calldata length 68, selector, `_proposer == P`, packed `deadline == 0`, blob range, `numForcedInclusions == 0`) is expressible (txt:105-147) | HOLDS | proven: each maps to a listed TXPARAM/FRAMEPARAM/SIGPARAM index or FRAMEDATALOAD; the packed layout matches `LibCodec` (15 bytes big-endian: deadline 6, blobStartIndex 2, numBlobs 2, offset 3, numForcedInclusions 2; VERIFIED at HEAD). SIGPARAM `0x02` returns `msg`, and the spec reserves the zero value for the empty-msg case. |
| 20 | Stack-order trap: index on top for FRAMEPARAM/SIGPARAM, offset on top for FRAMEDATALOAD, `offset, length, scope` top-down for APPROVE; Yul `verbatim` puts the leftmost argument on top (txt:166-170) | HOLDS | proven: [8141 L760-765, L797, L825, L679-685] stack tables; Yul docs: "the arguments are arranged on the stack with the leftmost argument on the top". |
| 21 | Invariant 1: the Inbox sees `msg.sender == G` iff a frame tx's VERIFY ran G's code and every check passed (txt:176-178) | CAVEAT | proven from [8141 L407-410] (SENDER caller = G only if `sender_approved`), [L702-711] (only `ADDRESS == tx.sender` can approve execution; DELEGATECALL preserves ADDRESS but G makes none), [L1112-1114] (no other tx type can have a contract sender). Caveats: (i) "every check passed" must include the pay frame; (ii) rests on G's bytecode containing no CALL/DELEGATECALL/CREATE/SELFDESTRUCT, an audit obligation on code that does not yet exist. |
| 22 | Invariant 3: the Inbox never reads `tx.origin`; ORIGIN is G in the SENDER frame (txt:180-181) | HOLDS | proven: [8141 L413] "The `ORIGIN` opcode returns frame's `caller` throughout all call depths."; `grep tx.origin` over the Inbox, preconf and EssentialContract sources returns nothing (VERIFIED). |
| 23 | Inbox changes: `proposeFor`, `_proposalGate`, `_directProposeDisabled`; `propose` has no `whenNotPaused`; four `msg.sender` replacements; `Proposal`/`Proposed` unchanged (txt:184-208) | HOLDS (as a proposal) | VERIFIED: none of these exist at HEAD; `propose` has only `nonReentrant`; the four lines are exact; `proposer` is a plain `address` field/topic. |
| 24 | FI rule today is `min(requested, available, 10)` regardless of due status; clients send `0xffff`; the design needs `min(max(requested, due), available, 10)` (txt:210-213) | HOLDS (mechanism) | VERIFIED: `Inbox.sol:666-667`; Go and Rust proposers send `math.MaxUint16` / `u16::MAX`; the floor check `requested >= dueToProcess` (`Inbox.sol:662-664`) means that under the *current* rule G's `numForcedInclusions == 0` pin reverts whenever any FI is due, so the rule change is mandatory for the design. Gas figures 76,485 / 100,517 / 218,805 UNVERIFIED. |
| 25 | Pull-based FI fees are required because `sendEtherAndVerify` forwards all gas and a P that rejects ETH burns the nonce (txt:215-219) | CAVEAT | VERIFIED: push via `call(gasleft(), ...)`, revert on failure (`Inbox.sol:710`, `LibAddress.sol:52-62`). Caveat: on the G path the recipient is P, whose pay frame ran the default code, which only runs for an empty code hash; so the only P that can pass VERIFY *and* reject ETH is one that chose a delegate that approves payment and rejects ETH: self-inflicted. Pull fees remain good hygiene, not a protection for *other* proposers. Storage claim (`__gap` at slot 258, 43 → 42, `reinitializer(4)`) VERIFIED. |
| 26 | `expectedProposalId` needed; clients never derive the id from the nonce (txt:221-225) | HOLDS | proven: a reverted SENDER frame consumes the nonce without a proposal (row 9); field absent today (VERIFIED); precedent PR #19488 (id binding worked, hash binding did not; VERIFIED). |
| 27 | Open the checker: `_proposerChecker` is immutable but points to an EIP-1967 proxy (txt:226-227) | CAVEAT | VERIFIED: immutable, wired to the `PreconfWhitelist` proxy (upgraded twice per deployment log); on-chain `getConfig().proposerChecker` not read (UNVERIFIED). Caveat that matters: **today's checker admits one operator per epoch**, so the same-slot race between different proposers that the design solves cannot occur until the checker is opened; opening it is a permissionless-proposing change with its own consequences. |
| 28 | No bond threshold on the G path; mainnet `minBond` is 0; spam bounded by one proposal per block (txt:228-231) | CAVEAT | VERIFIED: `MainnetInbox.minBond = 0` now; PR #20186 merged 2025-09-19. "Since activation" UNVERIFIED (shallow clone). |
| 29 | Race steps 1-6 (txt:235-253): both read n, both sign expiry `T_S`, both enter the public pool and go to builders; replacement needs +10% (1559) / +100% (blob caps); winner increments; loser dropped on revalidation, pays nothing; a builder forcing the loser in produces an EL-invalid payload while its bid is still paid | CAVEAT | proven for the consensus steps. Caveats: (a) a single public-pool node holds **one** `(G, n)` tx (rule 7 [8141 L1091]); A and B coexist across the network only as a replacement chain, and which one a node keeps depends on arrival order and fee gaps, not only on tip (10% and 100% bumps VERIFIED in geth, reth, Nethermind type-3 pools; whether blob-carrying frame txs will live in geth's blobpool or legacypool is UNVERIFIED); (b) under ePBS (Gloas) an EL-invalid payload never enters the store and the builder's bid is paid if the beacon block gathers ≥ 60% same-slot attestation weight (VERIFIED from consensus-specs `master` gloas beacon-chain.md and fork-choice.md), so the *honest winner also does not land*: the design guarantees nobody pays, not that the slot is used; (c) an L1 reorg that un-mines the winner re-opens the race and the loser may then land and pay (Nethermind re-adds reorged txs, VERIFIED; geth reinject path not quoted, UNVERIFIED). |
| 30 | If nobody lands, every variant becomes invalid once `T_S` passes; nodes drop them one slot late; nobody pays (txt:252-253) | CAVEAT | proven at consensus (expiry frame reverts, row 4). Caveat: while the head is still block S−1 the expired variant is not yet droppable under a literal reading of [L973], so a resubmission for S+1 with the same `(G, n)` is a *replacement* needing the fee bumps on nodes still holding the old one, unless "the node's view of the current block timestamp" means the next block's expected timestamp (UNDETERMINED from the spec). |
| 31 | Cost: same-block loser 30,944 gas + blob fee today, 0 with the design; winner about +13.5k gas (+18%) (txt:257-268) | CAVEAT | proven structure (0 for the loser). Winner overhead re-derived from spec constants (intrinsic 12,000 + 4 × 475 + data/signature bytes + 100 + 2,800 ≈ 18.8k; plus cold accesses to `0x8141`, P and, unlike a type-3 tx, to the Inbox) gives ≈ +13k on the post-EIP-2780/8038 schedule; the 75,594 baseline and exact figures UNVERIFIED. The extra cold access to the Inbox is a cost the PDF's list omits. |
| 32 | Break-even at 0.4-0.5 losers per proposal; 0.002 observed in 2025; blob fees 34%/38% of spend in congested windows (txt:269-275) | UNDETERMINED | on-chain sampling not reproduced; arithmetic 13.5k / 30.9k ≈ 0.44 is consistent. |
| 33 | Limitation: `n+1` landing after `n` in the same block reverts at `CannotProposeInCurrentBlock` and pays (txt:277-279) | HOLDS | proven: after `n`'s pay frame `state[G].nonce == n+1`, so the `n+1` tx is valid; `Inbox.sol:588-590` reverts the SENDER frame; row 9: included, P pays, nonce → n+2. Note it burns `n+1` for everyone, not only the pre-signer's money. |
| 34 | "one pending per sender" is only a SHOULD and no client implements it (txt:279-280) | CAVEAT | VERIFIED: [8141 L1091] "should"; geth PR #35814 closed unmerged; reth has no frame pool logic; Nethermind's literal gate UNVERIFIED. |
| 35 | Squatting: G cannot read TIMESTAMP so cannot bound how far ahead the expiry is; MIN_TIP is the countermeasure (txt:281-287) | CAVEAT | TIMESTAMP is banned only by *policy* [L1007-1008]; at consensus a VERIFY frame may read it, so a G that does is valid but confined to private submission (the PDF blurs policy and consensus). Replacement thresholds and eviction order VERIFIED; an unfunded squatter is evicted by the producer bound [L1104] (`APPROVE(1)` reverts on insufficient balance); MIN_TIP converts squatting from free to "pay MIN_TIP per slot" but the squatter's landed junk still consumes `n` and the L2 slot. |
| 36 | After the §1.3 changes the only third-party-triggerable reverts are a full ring buffer and `n+1` in the same block (txt:288-290) | CAVEAT | VERIFIED as a derivation from the full revert inventory at HEAD (`CannotProposeInCurrentBlock`, `NotEnoughCapacity`, `UnprocessedForcedInclusionIsDue`, `ETH_TRANSFER_FAILED`, `InvalidProposer` ×2, `DeadlineExceeded`, `InsufficientBond`). **Omitted levers:** (a) SENDER-frame OOG when third parties enqueue up to 10 FIs (permissionless `saveForcedInclusion`, ≥ 0.001 ETH each) that become due under the very rule change the design requires; `MIN_EXEC` must cover the 10-FI worst case; (b) state-gas exhaustion of `limits.state` on first-lap ring-buffer writes (new failure class under EIP-8037); (c) `InvalidProposer` timing at an epoch boundary while the checker is still epoch-based; (d) the direct `propose` path during the transition (claim 38). |
| 37 | G is tied to a Draft spec; #12198, #12252, or EIP-8250 would make G fail closed (txt:293-297) | CAVEAT (list is stale) | #12198 closed unmerged 2026-09-29 (threat gone); #12252 open draft (8-byte data would become statically invalid, so old G txs fail closed as stated); EIP-8250 CFI only (`nonce_keys == [0]` alias might keep a G v1 alive, UNVERIFIED); **new: #12387 open draft changes `EXPIRY_VERIFIER`'s address, a direct break of G v1's pin**; #12253 registry. "Versioned per fork" is the right mitigation and implies a DAO upgrade cycle per spec change until Final. |
| 38 | Direct propose keeps a governance switch; the Inbox's same-block revert arbitrates between paths; the zero-cost guarantee holds only within the G path (txt:298-305) | HOLDS | proven: `CannotProposeInCurrentBlock` is path-agnostic; a direct `propose` landing first makes the G-path winner revert (row 9: included, P pays, nonce burned). This is a further third-party burn lever for as long as direct propose is enabled. |

Summary of the falsification: **no claim FAILS.** Every consensus-level claim HOLDS on verbatim text. The CAVEATs cluster in three places: (1) everything about the public mempool is policy with no shipped implementation; (2) the Draft-pin list is stale, and PR #12387 is a new, direct break of G v1; (3) the nonce-burn inventory misses SENDER-frame OOG/state-gas exhaustion driven by FI stuffing, and the direct-propose path during transition. The one thing the design structurally cannot deliver is "the slot is not wasted."

---

## 5. Alternative constructions

The spec split of Section 3.4 implies (proven): **public-pool eligibility and revert-proofness are mutually exclusive under the current mempool policy.** A lock that makes the loser invalid must live in a `VERIFY` frame or in the nonce check; a public-pool prefix may read only the sender's own nonce/code/storage and may not be followed by a `VERIFY` frame. The baseline (nonce as a lock) is the unique construction that achieves consensus invalidity *and* public-pool eligibility, by making the shared fact the sender's nonce. Every alternative trades one of the two.

**A1: claim `VERIFY` frame reading Inbox state (prefix).** Sender is the proposer P on its own nonce; a `VERIFY` frame `STATICCALL`s `Inbox.getCoreState()` (a public view, VERIFIED `Inbox.sol:551-553`) and reverts unless `nextProposalId == N` (and, since `NUMBER` is not banned at consensus, `lastProposalBlockId != NUMBER`). Loser INVALID by row 4; same-block second proposal INVALID rather than reverted. Reads storage outside `tx.sender`, so **private/direct-to-builder only** [L1030]. Winner overhead ≈ +4k net (the SENDER frame then finds the Inbox warm, "the journal of such touches is shared across frames", VERIFIED; estimate UNVERIFIED). No shared resource, so no squatting, no nonce burn, pipelining allowed. Risk: the async-execution camp proposes a consensus cap on what `VERIFY` may read (magicians thread #53/#79, VERIFIED as discussion).

**A2: shared sequence counter contract (not the sender nonce).** Strictly dominated: every TXPARAM/FRAMEPARAM/SIGPARAM value is a function of the transaction's own fields (VERIFIED index tables), so binding to a global sequence needs either the sender nonce (= baseline) or a storage read (= A1 plus an extra SSTORE). Keep only as a per-lane variant for roles without a natural on-chain counter.

**A3: commit-reveal.** Cheap commit claims proposal `N` in a registry; the blob/proof-carrying reveal is checked against the claim. Moves the race to the commit phase (still land-and-revert unless the commit is itself frame-locked), adds ≥ 1 L1 slot of latency, needs a bond against free options, and degenerates into a per-slot election, which is what Etna's R5 and the PDF's "no advance exclusivity" reject for proposing. Right shape for *assigning proving work minutes ahead* (Section 8).

**A4: expiry-only.** `[expiry_verify][self_verify P][SENDER Inbox.propose]` on P's own nonce; public-pool eligible; free (+475 + ~3,200 gas). Fixes the *stale* case (today: lands in S+1 and reverts with `DeadlineExceeded`, `Inbox.sol:765`, paying gas and blob fee; with expiry: invalid, free). Does nothing for the same-slot loser, which reverts at `CannotProposeInCurrentBlock` inside its window; a builder is paid for both and will include both. A floor to adopt everywhere, never a solution.

**A5: multiple gates / per-role nonces.** `G_propose`, `G_prove`, or lane gates `G_even/G_odd`; the Inbox trusts a set. Per-role gates are mandatory if the baseline is used for more than one role (a prover's revert must never burn a proposer's seat). Lane gates allow pipelining (one pending per *sender address*) but do not fix the same-block `n+1` revert (it now burns the lane's nonce) and multiply the squattable seats. EIP-8250 keyed nonces would give one G a key per lane but "preserves EIP-8141's limit of one pending frame transaction per sender in the public mempool" (VERIFIED) and costs 97,920 state gas on first key use; separate gate contracts are better and need no EIP.

**A6a: EIP-7702 delegated accounts sharing a nonce.** Impossible: EIP-3607 (Final) "Any transaction where `tx.sender` has a `CODEHASH != EMPTYCODEHASH` MUST be rejected as invalid" (VERIFIED https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-3607.md); EIP-7702 (Final) relaxes it only for delegation indicators, and a failed authorization tuple does not invalidate the transaction ("immediately stop processing the tuple and continue to the next tuple in the list", VERIFIED). Sharing a nonce means sharing a key. No consensus-level invalidity is reachable.

**A6b: builder revert protection (status quo).** Flashbots Protect: "Transactions are only included in the block if they do not revert. Users do not pay fees for failed transactions." Titan: `revertingTxHashes`/`droppingTxHashes`, "will never broadcast any bundles or private transactions to the public mempool" (VERIFIED). Zero cost *if* the builder honours it; no consensus teeth; public-mempool copies can still land (inferred, UNVERIFIED); no protocol penalty for a builder that includes a reverting transaction.

**A6c: Taiko's guard today.** Pre-Shasta `proposeBlocksV2Conditionally` with `NOT_FIRST_PROPOSAL` (PR #18570, merged 2024-12-16) and Shasta's in-Inbox `CannotProposeInCurrentBlock` (PR #20186, merged 2025-09-19), both VERIFIED. Loser lands and reverts, paying gas plus the burned blob fee.

**A7: trailing status `VERIFY` frame ("assert-after").** Sender P on its own nonce; after the `SENDER` frame, a `VERIFY` frame targets a ~15-byte stateless contract that executes `FRAMEPARAM(0x05, i)` and reverts unless the `SENDER` frame's status is 1 ([8141 L816] "The `status` field (0x05) returns `0` for failure, `1` for success, or `2` for a frame skipped due to a failed atomic batch."). By row 4 the whole transaction is then invalid whenever the action reverted, *for any reason*: same-slot loss, stale parent, ring buffer full, FI due, bad proof, OOG. No shared sender, no gate, no Inbox change, ≈ +3.5k gas (estimate). The spec's own reason for banning the shape in the public pool states the property: [8141 L950] "There must not be any `VERIFY` frame after these prefixes, otherwise their revert would make entire transaction invalid." Hence **private/direct-to-builder only**, but its *safety* does not depend on the builder: a builder that includes the loser produces an invalid payload. Risks: unpaid builder simulation is the whole transaction (same profile as today's revert-protected bundles); spec drift, specifically the async-execution proposal to fix `VERIFY` frames at the head with a consensus gas cap, and the "guarantor / fail-but-pay" request (thread #166, 2026-08-05, VERIFIED as discussion) which, if adopted as the default for late `VERIFY` frames, would turn this loser into included-and-charged. Combination with the baseline: a `(G, n)` transaction with a trailing status `VERIFY` no longer burns `n` on a SENDER revert (tx invalid, nonce not consumed), at the price of being private-only.

### Comparison table

| | Baseline: nonce as lock | A1 claim VERIFY | A3 commit-reveal | A4 expiry-only | A5 multi-gate | A6a 7702 | A6b builder policy | A6c Taiko today | A7 trailing status VERIFY |
|---|---|---|---|---|---|---|---|---|---|
| Same-slot loser | INVALID (nonce) | INVALID (VERIFY) | commit: REVERT (cheap) | REVERT | INVALID per gate | REVERT | dropped (policy) / REVERT on leak | REVERT | INVALID (VERIFY) |
| Stale loser | INVALID | INVALID | INVALID if frame-locked | INVALID | INVALID | REVERT | policy | REVERT | INVALID |
| Winner's own revert (bad proof, FI, ring buffer) | REVERT, **burns shared nonce** | REVERT, pays, lock intact | REVERT, pays | REVERT, pays | REVERT, burns lane nonce | REVERT | policy | REVERT | **INVALID, pays nothing** |
| Consensus guarantee | yes | yes | only if frame-locked | stale only | yes | no | no | no | yes |
| Public-mempool eligible | **yes** | no | commit yes | yes | yes | n/a | n/a | yes | no |
| Winner overhead (est., UNVERIFIED) | +13.5k | ≈ +4k | +45k + 2nd tx | ≈ +3.7k | as baseline | 0 | 0 | 0 | ≈ +3.5k |
| Loser cost | 0 | 0 | ~25-45k | full + blob | 0 | full | 0 or full | full | 0 |
| Latency | 0 | 0 | ≥ +1 slot | 0 | 0 | 0 | 0 | 0 | 0 |
| `n+1` same block | REVERT, burns nonce | INVALID (NUMBER pin) | n/a | REVERT | REVERT, burns lane | — | — | REVERT | INVALID |
| Squatting | single seat (needs MIN_TIP) | none | high (needs bond) | none | k seats | — | — | none | none |
| Pipelining | no | yes | yes | yes | per gate | — | — | yes | yes |
| Contract changes | G + `proposeFor` + FI/fee/checker/expectedProposalId | tiny helper | registry + bond | none | k gates + set | — | — | none | tiny helper, Inbox unchanged |
| EIP change needed | no | policy only (public pool) | no | no | no | impossible | no | no | policy only (public pool) |
| Spec-drift sensitivity | G pins a Draft (#12387, #12252, 8250) | VERIFY read cap | low | low | as baseline | — | — | — | **high** (VERIFY-after-payer, fail-but-pay) |
| Safety depends on builder honesty | no | no | no | no (but builder profits from loser) | no | — | **yes** | yes | no |

---

## 6. Worked example

Concrete values are illustrative; spec constants are VERIFIED; byte-composition gas estimates are UNVERIFIED.

Setup: G deployed by CREATE2; `nonce(G) = n = 4242` after block N−1 (slot S−1, timestamp `T_S − 12`). Proposers A and B are plain EOAs `P_A`, `P_B`, each holding at least `max_cost`. Each signs the transaction below with `expiry = T_S`, 2 blobs (`blob_gas = 262,144`), A with tip 3 gwei / max fee 40 gwei, B with tip 2 gwei / max fee 40 gwei; both tips are at or above G's `MIN_TIP`.

```
FrameTx (type 0x06)
  chain_id  = 1
  nonce     = 4242                      # == state[G].nonce
  sender    = G                         # the shared gate contract
  frames    = [
    # 0  expiry_verify
    [mode=VERIFY, flags=0, target=0x8141,   limits=[3200, 0],       value=0, data=be64(T_S)],
    # 1  only_verify  (target null -> resolves to tx.sender = G; G's fallback pins the shape, APPROVE(2))
    [mode=VERIFY, flags=2, target=null,     limits=[5000, 0],       value=0, data=""],
    # 2  pay  (P_x has empty code -> EOA default code reads signature[1], APPROVE(1): nonce++, payer = P_x)
    [mode=VERIFY, flags=1, target=P_x,      limits=[3500, 0],       value=0, data=""],
    # 3  user_op  (caller = G; msg.sender == G at the Inbox)
    [mode=SENDER, flags=0, target=INBOX,    limits=[300000, 200000], value=0,
       data=proposeFor(P_x, packed)]       # 4 + 32 + 32 = 68 bytes
  ]
  signatures = [
    [scheme=ARBITRARY,  signer="",  msg="", signature=""],        # zero-length placeholder; G pins len == 0
    [scheme=SECP256K1,  signer=P_x, msg="", signature=sig_x]      # over compute_sig_hash(tx): binds every frame
  ]
  fees = [max_priority_fee_per_gas, max_fee_per_gas, max_fee_per_blob_gas]
  blob_versioned_hashes = [h0, h1]

packed (bytes32, big-endian, left-aligned):
  deadline=0 (6) | blobStartIndex=0 (2) | numBlobs=2 (2) | offset=0 (3) | numForcedInclusions=0 (2) | expectedProposalId=90001 (6)
```

`max_gas` ≈ intrinsic (≈ 18,840) + Σ`limits.execution` (311,700) + Σ`limits.state` (200,000) ≈ 530,540; `max_cost` ≈ 530,540 × 40 gwei + 262,144 × `blob_base_fee`, escrowed from `P_x` only if frame 2's `APPROVE` runs.

What every node does on receipt (policy): static checks; signature 1 recovers to `P_x`; simulate frame 0 (ok while head timestamp ≤ `T_S`), frame 1 (G's pins pass, `APPROVE(2)`), frame 2 (default code, `APPROVE(1)`: balance ok, nonce increments in simulation, payer = `P_x`); stop. Unpaid simulation ≤ 14,600 gas-equivalents. Admission: one `(G, 4242)` per node; B (2 gwei) cannot replace A (3 gwei); a node that saw B first keeps B unless A's caps are ≥ 2× B's under the blob convention. Both also submit directly to builders.

**Scenario (i): A lands, B loses.** Block N (slot S): the builder holds both and picks A. Execution of A: step 1 `4242 == state[G].nonce` ✓; signatures ✓; frame 0: `T_S ≤ T_S` ✓ (≈ 3,051 of 3,200 gas); frame 1: G's pins ✓ → `sender_approved = true`; frame 2: cold access to `P_A` 3,000, default code → `APPROVE(1)`: **`state[G].nonce → 4243`**, `payer = P_A`, `max_cost` escrowed; frame 3: `caller = G`, cold Inbox access 3,000, `proposeFor` succeeds, `Proposed` emitted, `lastProposalBlockId = N`. Settlement: `P_A` pays `gas_used × effective_gas_price + 262,144 × blob_base_fee`; unused gas refunded. If the builder had appended B after A, B fails step 1 (`4242 ≠ 4243`) and the block is invalid (see iii). After N is canonical, every node re-simulates same-sender transactions [L1108], B fails step 1 and is evicted first in the eviction order [L1102]. In slot S+1, B reads `nonce(G) = 4243`, drops A's L2 blocks, re-signs with `nonce = 4243`, `expiry = T_{S+1}`. If A had *also* pre-signed 4243 and got it into block N right after 4242, that second transaction is valid (nonce matches) and reverts at `CannotProposeInCurrentBlock`: A pays ≈ 30k gas plus the full blob fee and nonce 4243 is burned for everyone.

**Scenario (ii): nobody lands before expiry.** No block with timestamp ≤ `T_S` includes a `(G, 4242)` transaction; `state[G].nonce` stays 4242; nobody was charged (no `APPROVE` executed on-chain). In block N′ (timestamp `T_S + 12`) either transaction, if attempted, fails frame 0 → invalid. Pool: nodes MUST drop when the deadline "is less than the node's view of the current block timestamp"; literally, the variants stay pooled until N′ is the head (one slot late). A resubmission for S+1 with the same `(G, 4242)` sent *before* N′ is seen is a *replacement* on nodes still holding the old variant (needs +10% / +100%); direct-to-builder submission sidesteps this. Everyone competes for 4242 again.

**Scenario (iii): a malicious builder includes B after A.** Candidate block `[..., A, ..., B]`: A executes as in (i), nonce → 4243; B fails step 1 → invalid transaction → invalid payload (inherited rule, Section 3.2 item 7). Under ePBS (Gloas; VERIFIED from consensus-specs): the builder's bid is recorded at `process_execution_payload_bid`; at reveal, `verify_execution_payload_envelope` asserts `execution_engine.verify_and_notify_new_payload(...)`, which fails, so the envelope never enters the store and the slot is Empty; the bid is still paid if the beacon block gathered ≥ 60% same-slot attestation weight. Under MEV-Boost the relay's `ValidateBuilderSubmissionV3` executes the block and rejects it (VERIFIED from flashbots/builder); under optimistic relaying the slot is missed and builder collateral refunds the proposer. Including B *before* A is simply "B wins": legal.

**Who pays what:**

| Scenario | A (`P_A`) | B (`P_B`) | Builder | Network / L2 |
|---|---|---|---|---|
| (i) A lands, B loses | ≈ 84k gas execution (est.) + Inbox state gas + 262,144 blob gas × `blob_base_fee`; refund of unused escrow | **0 gas, 0 blob gas, 0 wei** | tip from A | B's 256 KiB of blobs gossiped for nothing (bounded by one pending per sender per node); L2 slot used |
| (i′) A also pre-signed 4243, landed right after 4242 | additionally ≈ 30k gas + full blob fee for the reverted second tx | 0 | tips from both | nonce 4243 burned; one L2 slot wasted |
| (ii) nobody lands | 0 | 0 | 0 | ≤ ~15k gas of unpaid simulation per variant per build attempt; L2 slot wasted |
| (iii) builder forces B in after A | 0 (A's tx did not land; it remains valid until `T_S`, usually expires, A re-signs) | 0 | pays its bid (ePBS, on 60% quorum) and gets nothing; or rejected by the relay (MEV-Boost) | L2 slot wasted |

---

## 7. Assumptions the verdict depends on

Tags: **spec-guaranteed** (verbatim EIP-8141 consensus text as of 2026-09-30) / **client-policy** (the non-consensus Mempool section, or observed client code) / **builder-policy** / **open**.

1. The nonce check is step 1, before signatures and frames; failure is invalid; nobody charged. **spec-guaranteed** [L392, L1104].
2. The nonce increments exactly once, inside the payment-scoped `APPROVE`; a later `SENDER` revert never rolls it back. **spec-guaranteed** [L717, L421, L1176].
3. An invalid frame transaction makes the containing block invalid. **open** as an 8141 sentence; **spec-guaranteed** by the general execution rule for existing types; the only coherent reading of `invalid_transaction()`.
4. Blob fee is part of `max_cost`, collected from `payer` at `APPROVE`; an invalid tx has no payer. **spec-guaranteed** [L653-655, L717, L1104].
5. `EXPIRY_VERIFIER = address(0x8141)`, 8-byte calldata, upper bound only. **spec-guaranteed today; open going forward** (PR #12387 address; PR #12252 calldata).
6. Opcode numbers `0xaa`, `0xb0-0xb5` and the introspection index tables. **spec-guaranteed today; open until Final** (PR #12253 registry; EIP-8250 adds TXPARAM indices and changes `nonce`).
7. Only code executing with `ADDRESS == tx.sender` (or delegatecalled by it) can grant execution approval; G's bytecode contains no CALL/DELEGATECALL/CREATE/SELFDESTRUCT. First half **spec-guaranteed** [L702-711]; second half an **open** audit obligation on bytecode that does not yet exist.
8. Non-frame transaction types cannot have a contract sender. **spec-guaranteed** [L1112-1114].
9. The EOA default code approves payment only for a `SECP256K1` signature at index 1 by the target with empty `msg`. **spec-guaranteed** [L664-671].
10. Cold account access 3,000 (EIP-8038) and value-less-call intrinsic 15,000 (EIP-2780), both active before Hegotá. **spec-guaranteed** by the EIP texts (Status Review); fork placement Glamsterdam SFI per the phase-2 roadmap; mainnet date **open** (Sepolia 2026-10-06; mainnet undecided).
11. Public-pool nodes keep at most one pending `(G, n)` per node and treat a second as a replacement (+10% 1559 / +100% blob caps). **client-policy** ([L1091] is "should"; blob bump VERIFIED only in type-3 pools; no shipped type-0x06 pool anywhere).
12. Nodes drop expired variants when the head timestamp exceeds the deadline; whether "the node's view of the current block timestamp" is the head or the next block. **client-policy / open**.
13. Nodes revalidate same-sender transactions on every new head and evict stale-nonce ones. **client-policy** ([L1106-1108]; VERIFIED in geth, reth, Nethermind for existing types).
14. Builders pick among same-nonce alternatives by tip and do not deliberately waste slots. **builder-policy**; "nobody pays" does not depend on it; "the slot is used" does.
15. Under ePBS an EL-invalid payload is rejected while the bid is paid on a 60% attestation quorum. **spec-guaranteed** (consensus-specs gloas `master`, VERIFIED); that ePBS is the builder market at 8141 activation: **open**.
16. Revert protection for private flow is per-builder policy and does not cover public-mempool copies. **builder-policy** (Flashbots/Titan docs VERIFIED; public-copy leakage inferred, UNVERIFIED).
17. The Taiko-side changes (`proposeFor`, due-FI processing, pull fees, `expectedProposalId`, opened checker, no bond check on the G path) ship in one upgrade. **open** (none exist at HEAD 61d8f18); without the due-FI change G's `numForcedInclusions == 0` pin reverts on every due FI.
18. `MIN_EXEC` / `limits.execution` and `limits.state` cover the 10-due-FI worst case and first-lap ring-buffer writes under EIP-8037/8038 pricing. **open** (not measured on a Glamsterdam schedule); failure mode is a nonce burn paid by P.
19. P is a plain EOA at landing time. **spec-guaranteed** consequence (a delegated P cannot pass frame 2 unless its delegate approves payment); a deliberately delegating P can only hurt itself.
20. Third parties cannot alter a signed variant except the elided `ARBITRARY` bytes, which G pins to length 0. **spec-guaranteed** [L1446, L1466].
21. G can be authored (standalone Yul `verbatim`, Huff, raw bytecode) and tested only on EELS/hive/devnet. **open** (upstream revm/Foundry/solc support UNVERIFIED).
22. A same-slot race between *different* proposers can occur at all. **open**: today's `PreconfWhitelist` admits one operator per epoch; the design presupposes opening the checker (Etna R1 requires it anyway).
23. A reorg that un-mines the winner re-opens the race; the loser may then land and pay. **client-policy** (Nethermind re-adds, VERIFIED; geth reinject UNVERIFIED).

**Client implementations that exist today** (VERIFIED 2026-09-30): none shipped. EELS has a merged state-transition implementation on a feature branch (execution-specs PR #3047, 2026-08-13). Nethermind has the most complete devnet branch (`eip8141-frame-txs-devnet7`, per-payer exposure merged; `MAX_VERIFY_GAS` kept at a configurable 300k rather than the spec's 100k, PR #13058 closed unmerged). geth has an open WIP draft (#35666) and a `frames-devnet-0` branch with no frame-specific pool policy (the policy PR #35814 was closed unmerged on 2026-09-29). reth has an open DNM draft (#27154) and no frame logic in its pool on `main`. ethereumjs has nothing. No builder documents frame-transaction handling.

---

## 8. Consequences for Etna: propose-with-proof races (R7) and role competition

**What Etna should adopt.** A two-shape gate design on one seat:

1. **Public-mempool shape: the shared-nonce transaction** (Section 6 structure) with per-role gates (`G_propose`, later `G_prove` only if a public-pool proving path is a hard requirement), an expiry frame in front, and `MIN_TIP` pinned. It is the only construction whose zero-cost race propagates through the public mempool and therefore the only censorship-resistant fallback that does not depend on any builder. Proven: Section 3.4 split; Section 4 claims 1-3, 7.
2. **Direct-to-builder shape: the actor's own nonce with an expiry frame in front and a trailing status `VERIFY` frame behind** (A7), optionally with a claim `VERIFY` in the prefix (A1) as the drop-in replacement if post-payment `VERIFY` frames are ever forbidden. This is the *primary* R7 path: a propose-with-proof transaction that reverts for *any* reason (bad or stale proof, same-slot loss, ring buffer, FI stuffing, OOG) is invalid and free, the seat is untouched, pipelining and multi-segment submission are allowed, and the Inbox needs no new trust root (`msg.sender == P` inside the `SENDER` frame). Proven: Section 5 A7, [8141 L816, L950, L423-425].
3. Both shapes on the same seat are compatible: a `(G, n)` transaction with a trailing `VERIFY` and a plain `(G, n)` transaction are alternatives for the same nonce, so a builder-submitted variant and a public-pool variant compete for one `n` (proven from [L1096]).

**Why not the PDF's single mechanism for R7.** Under R7 the racing transaction carries blobs *and* a ZK proof, and several provers can plausibly hold valid proofs for the same segment. With the plain baseline, `proposeFor` reverting inside proof verification consumes `n` without producing a proposal: whoever outbids the honest tip for one slot can waste that slot at gas cost, every slot, and G cannot check proof validity in a ~14k-gas prefix that may read nothing but the transaction (proven: Section 3.1 row 9; Section 4 claim 36). R7 therefore adds a third-party-triggerable nonce burn that the PDF's action did not have. A7 removes the lever entirely.

**What Etna must NOT rely on.**
- Not on the public-mempool rules being implemented: no shipped client enforces one-pending-per-sender, revalidation, or `MAX_VERIFY_GAS` for type 0x06 (Section 2). Treat every mempool property as unavailable until a client ships it.
- Not on "the slot is used": an ePBS builder can pay its bid and reveal an invalid payload; `n+1` in the same block or any residual `SENDER` revert burns the nonce for everyone (Section 4 claims 29, 33, 36). The primitive fixes *who pays*, never *whether the L2 slot advances*.
- Not on G's pins surviving spec changes: `0x8141` (PR #12387), 8-byte expiry data (PR #12252), the `nonce` field (EIP-8250), opcode numbers (PR #12253) are all in motion. G is versioned per fork, never deployed on a persistent network before the spec is Final, and every pin has a documented fail-closed behaviour and a fallback path (direct `propose` with a governance switch).
- Not on builder revert protection as a *safety* property; it is an availability property. The consensus teeth come from A7/A1 (an included loser makes the payload invalid), not from the builder's promise.
- Not on `TIMESTAMP`/`NUMBER`/Inbox-storage reads in the public-pool prefix (policy-banned) and not on their absence at consensus (allowed): keep the two shapes' opcode sets separate.
- Not on the nonce as the proposal id: clients never derive `expectedProposalId` from `nonce(G)` (a reverted `SENDER` frame, an L1 reorg, or the direct path decouple them; proven Section 4 claim 26).

**What degrades if Frame Transactions slip** (Hegotá date undecided; only Glamsterdam has a Sepolia date). Every zero-cost property disappears together, because all three "invalid, pays nothing" entry points are frame-specific. The fallback is A6c + A6b + A4-without-frames: the Inbox's one-per-block revert, private revert-protected builder submission, and a `deadline` in `ProposeInput` (already present, `Inbox.sol:765`). Losers pay execution gas plus the burned blob fee (EIP-4844), stale proposals land and revert with `DeadlineExceeded`, and the design's economics revert to today's 0.002-losers-per-proposal regime (UNVERIFIED figure). Nothing in the Inbox interface needs to change between the two regimes if Etna keeps `propose`/`proposeWithProof` callable directly by P and adds `proposeFor` for the gate as a *second* entry point behind a governance switch, exactly as the PDF proposes. Two of the PDF's Inbox changes remain desirable with or without frames because they remove other-triggerable reverts that waste the winner's slot even at zero cost: forced inclusions processed by due time, and pull-based FI fees.

**Recommended gate design and its load-bearing pins.**

*Inbox side (both regimes):* `proposeFor(address _proposer, bytes32 _packedInput)` gated on `msg.sender == _proposalGate` (immutable, `0` = disabled) with a static 32-byte input (no dynamic `bytes`: `LibCodec.decodeProposeInput` has no length check and `unpack*` are bare `mload`s, VERIFIED, so a dynamic layout would need six extra pins); `_buildProposal(_proposer, ...)` replacing the four `msg.sender` uses; `expectedProposalId` (uint48) appended to `ProposeInput` (15 → 21 bytes, fits one word); optional `expectedParentProposalHash`; forced inclusions consumed as `min(max(requested, due), available, 10)`; FI fees pull-based (`mapping` at slot 258, `__gap` 43 → 42, `reinitializer(4)`); no bond check on the gate path (mainnet `minBond` is 0 and a bond revert would be a burn lever); `_directProposeDisabled` governance switch; ring-buffer bound kept as the per-block spam bound (with A7 it costs nobody anything).

*Gate G (public-pool shape), load-bearing pins, each of which, if missing, lets a third party either forge `msg.sender == G` or burn the nonce at will:*
1. `TXPARAM(0x09) == 4` and `TXPARAM(0x0A) == 1`: exactly four frames and G is frame 1. Execution approval is transaction-scoped [L1464], so an unpinned frame count authorizes every later `SENDER` frame.
2. Frame 3 is the *only* `SENDER` frame, `target == INBOX`, `flags == 0`, `value == 0`, `len(data) == 68`, selector `proposeFor(address,bytes32)`.
3. `framedataload(3, 4) == FRAMEPARAM(0x00, 2) == SIGPARAM(0x00, 1)`: `_proposer` is the payer and the signer.
4. `TXPARAM(0x0B) == 2`; signature 0 is `ARBITRARY` with `SIGPARAM(0x03, 0) == 0` (no padding malleability, [L1446]); signature 1 is `SECP256K1` with empty `msg` (binds the full frame list, [L1466]).
5. Frame 0 is `VERIFY` targeting `EXPIRY_VERIFIER` (mode and target only; data length is enforced statically); frame 2 is `VERIFY` with flags `1` (pay).
6. In the packed word: `deadline == 0` (a past deadline is a self-serve burn) and `numForcedInclusions == 0` (with due-time processing in the Inbox; without it this pin reverts on every due FI).
7. `TXPARAM(0x03) >= MIN_TIP` (anti-squatting: every poolable variant is a real bid); `max_fee` uncapped.
8. `numBlobs >= 1` and `start + n <= TXPARAM(0x07)` (guardrails against the proposer's own OOG; not security pins).
9. G's bytecode contains no `CALL`/`DELEGATECALL`/`STATICCALL`/`CREATE*`/`SELFDESTRUCT` and no `SLOAD`/`TIMESTAMP`/`NUMBER` (public-pool eligibility and the `msg.sender == G` invariant); written in standalone Yul `verbatim` or Huff with the stack-order convention `(index, param)` / `(offset, frameIndex)` and differential-tested against EELS.
10. `MIN_EXEC` sized for the 10-due-FI worst case and `MIN_STATE` for first-lap ring-buffer writes under EIP-8037/8038 (open item 18).

*Status verifier (direct-to-builder shape):* a ~15-byte stateless contract, `FRAMEPARAM(0x05, i) == 1` or revert, placed as the last frame; optionally an outcome pin (`STATICCALL Inbox.getCoreState()` and `nextProposalId == expected + 1`). No pins beyond its own bytecode; it reads nothing but the transaction.

*Role competition.* Proposers race per slot via the two shapes. Provers deliver via A7 on their own nonce (a losing or bad proof is invalid and free; several candidate segments can be in flight); if a public-pool proving path is required, a separate `G_prove` so a proof revert can never burn a proposer's seat (A5). Proving *assignments* minutes ahead use a cheap bonded commit (A3) whose reveal is revert-proof under A7, so a prover that misses its window loses only its commit bond, never a blob fee. Forced inclusions are consumed by due time so they cannot be weaponised against either role. All timing is in seconds and L1 block numbers (R5): the expiry frame carries a timestamp, not a slot.

---

## 9. Open questions that only the EIP authors or a devnet can resolve

1. **Block invalidity for type 0x06.** Confirm on the EELS branch `eips/amsterdam/eip-8141` that a nonce-mismatched or VERIFY-failed frame transaction raises `InvalidBlock` (Section 3.2 item 7). Expected yes; not quoted in the EIP.
2. **Will post-payment `VERIFY` frames stay consensus-legal?** The async-execution proposal (thread #53/#79) and the "guarantor / fail-but-pay" request (thread #166) could remove or re-price A7. An explicit statement from the authors would decide whether A7 or A1 is Etna's primary direct-to-builder shape.
3. **Will a consensus cap or read restriction be placed on `VERIFY` frames?** Decides A1's future.
4. **`EXPIRY_VERIFIER` address and calldata.** Merge decisions on PR #12387 (address) and PR #12252 (`valid_after`, 16 bytes) fix G v1's two most fragile pins and whether a not-before bound will exist.
5. **EIP-8250 and G.** Whether `nonce_keys == [0]` keeps a G that reads `TXPARAM(0x01)` working unchanged, and whether the mempool guidance will ever allow more than one pending transaction per sender (which would make lane keys useful).
6. **"The node's view of the current block timestamp."** Head timestamp or next-slot timestamp for the expiry drop rule; decides whether a same-nonce resubmission for S+1 is a replacement (Section 4 claim 30).
7. **Which pool holds blob-carrying frame transactions** in geth (legacypool at 10% or blobpool at 100%), and whether any client will enforce one-pending-per-sender for type 0x06 (geth's PR was closed).
8. **Builder lanes.** Whether any builder will accept state-reading prefixes or trailing `VERIFY` frames privately, and how it bounds the unpaid simulation of a full propose-with-proof transaction (`TX_MAX_GAS_LIMIT` = 16,777,216).
9. **Actual gas.** G's bytecode size and gas, the +13.5k winner overhead, and the 30,944 loser cost need a frames devnet on a Glamsterdam schedule (EIP-2780, EIP-8038, EIP-8037 state gas). Nothing in Foundry or upstream revm can run `0xaa`/`0xb0-0xb5` today (UNVERIFIED by code inspection).
10. **Hegotá timing.** Mainnet dates for Glamsterdam and Hegotá are undecided; the degraded regime of Section 8 applies until then.
11. **Signature-byte padding fix.** Whether `compute_sig_hash` will be changed to commit to `ARBITRARY` signature lengths (thread #167-#170); if so, G's `SIGPARAM(0x03, 0) == 0` pin becomes redundant rather than load-bearing.

---

## 10. Sources

All fetched or read on 2026-09-30 unless noted.

Primary EIP and spec sources:
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md — EIP-8141 Frame Transaction (Draft); re-fetched for this document; md5 `284f4d79ea303353412f58eb73d09421`; all `[8141 L###]` quotes.
- https://eips.ethereum.org/EIPS/eip-8141 — rendered page; "Draft Standards Track: Core".
- https://github.com/ethereum/EIPs/commits/master/EIPS/eip-8141.md — commit history (`5c0236f`, `857622a`, `b75cbe6`, `7d1c8bf`, `3ceef8d`).
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8081.md — Hardfork Meta Hegotá (Draft): EIP-8141 Scheduled for Inclusion; EIP-8250 Considered for Inclusion.
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8250.md and https://eips.ethereum.org/EIPS/eip-8250 — Keyed Nonces for Frame Transactions (Draft).
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8038.md — State-access gas cost update (Review); `COLD_ACCOUNT_ACCESS` 3,000.
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-2780.md — Reduce intrinsic transaction gas (Review).
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7702.md — Set Code for EOAs (Final).
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-3607.md — Reject transactions from senders with deployed code (Final).
- https://eips.ethereum.org/EIPS/eip-4844 — Shard Blob Transactions (Final); blob fee burned, not refunded.
- https://eips.ethereum.org/EIPS/eip-7594 — PeerDAS (Final); 6 blobs per transaction.
- https://eips.ethereum.org/EIPS/eip-7691 , https://eips.ethereum.org/EIPS/eip-7892 — blob schedule / BPO forks (Final).
- https://eips.ethereum.org/EIPS/eip-7732 — ePBS (Review).
- https://raw.githubusercontent.com/ethereum/ERCs/master/ERCS/erc-7562.md — AA validation scope rules (Review).
- https://raw.githubusercontent.com/ethereum/execution-specs/master/src/ethereum/forks/osaka/fork.py — `check_transaction` raises `InvalidBlock` / `NonceMismatchError`.
- https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/gloas/beacon-chain.md and https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/gloas/fork-choice.md — ePBS bid, payment quorum, payload validity.
- https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement — Sepolia 2026-10-06; mainnet undecided.
- https://ethereum-magicians.org/t/frame-transaction/27617 (and `.json`, `/posts.json`) — discussion thread, 169 posts through 2026-09-29 (#53, #79, #135, #147, #166, #167-#170, #172-#174).
- https://docs.soliditylang.org/en/latest/yul.html — `verbatim` stack order.

EIP pull requests:
- https://github.com/ethereum/EIPs/pull/12252 — valid_after (open draft, 2026-08-27).
- https://github.com/ethereum/EIPs/pull/12387 and https://patch-diff.githubusercontent.com/raw/ethereum/EIPs/pull/12387.diff — deploy expiry verifier as standard contract (open draft, 2026-09-28).
- https://github.com/ethereum/EIPs/pull/12198 — expiry as a new mode (closed unmerged 2026-09-29).
- https://github.com/ethereum/EIPs/pull/12253 — opcode/frame-mode registry (open).
- https://github.com/ethereum/EIPs/pull/12321 — early rejection / payer revalidation (open).
- GitHub MCP `search_pull_requests` over `ethereum/EIPs` — open #12214, #12387, #12321, #12330, #12236, #12301, #12340, #12041, #12252, #12253, #12328, #12322; merged #12251 (EIP-8081 SFI) and others.

Client and builder sources:
- https://raw.githubusercontent.com/ethereum/go-ethereum/master/core/txpool/legacypool/legacypool.go , .../legacypool/list.go , .../blobpool/config.go , .../blobpool/blobpool.go , .../txpool/reserver.go , https://raw.githubusercontent.com/ethereum/go-ethereum/master/params/config.go — geth pool rules, blob schedule.
- https://github.com/ethereum/go-ethereum/pull/35666 , https://github.com/ethereum/go-ethereum/pull/35814 , https://github.com/ethereum/go-ethereum/pull/35816 , https://raw.githubusercontent.com/ethereum/go-ethereum/frames-devnet-0/core/txpool/legacypool/legacypool.go — geth frame-tx status.
- https://raw.githubusercontent.com/paradigmxyz/reth/main/crates/transaction-pool/src/config.rs , .../pool/txpool.rs , https://raw.githubusercontent.com/paradigmxyz/reth/main/crates/chainspec/src/spec.rs , https://github.com/paradigmxyz/reth/pull/27154 , https://github.com/paradigmxyz/reth/pull/27528 — reth.
- https://raw.githubusercontent.com/NethermindEth/nethermind/master/src/Nethermind/Nethermind.TxPool/Comparison/CompareReplacedTxByFee.cs , .../CompareReplacedBlobTx.cs , .../TxPool.cs , https://github.com/NethermindEth/nethermind/pull/12617 , /13283 , /13044 , /13561 , /13590 — Nethermind.
- https://github.com/ethereum/execution-specs/pull/3047 — EELS frame-tx implementation (merged 2026-08-13 to `eips/amsterdam/eip-8141`).
- https://raw.githubusercontent.com/flashbots/builder/main/eth/block-validation/api.go , https://raw.githubusercontent.com/flashbots/builder/main/README.md , https://raw.githubusercontent.com/flashbots/mev-boost-relay/main/README.md , https://raw.githubusercontent.com/michaelneuder/optimistic-relay-documentation/main/towards-epbs.md — MEV-Boost validation and payment.
- https://docs.flashbots.net/flashbots-protect/overview , https://docs.flashbots.net/flashbots-protect/quick-start , https://docs.flashbots.net/flashbots-auction/advanced/rpc-endpoint , https://docs.titanbuilder.xyz/ , https://docs.titanbuilder.xyz/api/eth_sendbundle.md , https://docs.titanbuilder.xyz/api/eth_sendprivatetransaction.md — revert protection.
- Web search only (titles, not fetched): https://github.com/Soubhik-10/revm/pull/26 , https://github.com/alloy-rs/alloy/pull/4067 .

Taiko sources (repository at HEAD `61d8f18`):
- packages/protocol/docs/Etna/inputs/nonce-as-a-lock.txt — the PDF under test.
- packages/protocol/docs/Etna/README.md — requirements R1-R7.
- packages/protocol/contracts/layer1/core/impl/Inbox.sol ; core/libs/LibCodec.sol , LibForcedInclusion.sol , LibBlobs.sol , LibBonds.sol , LibPackUnpack.sol , LibInboxSetup.sol ; core/iface/IInbox.sol , IProposerChecker.sol ; layer1/preconf/impl/PreconfWhitelist.sol ; layer1/mainnet/MainnetInbox.sol , MainnetInbox_Layout.sol , LibL1Addrs.sol ; layer1/devnet/DevnetInbox.sol ; shared/libs/LibAddress.sol ; shared/common/EssentialContract.sol ; script/layer1/core/DeployShastaContracts.s.sol , DeployShastaMainnet.s.sol ; deployments/mainnet-contract-logs-L1.md ; packages/taiko-client/proposer/transaction_builder/blob.go ; packages/taiko-client-rs/crates/proposer/src/transaction_builder.rs .
- https://github.com/taikoxyz/taiko-mono/pull/18570 , https://github.com/taikoxyz/taiko-mono/pull/20186 , https://github.com/taikoxyz/taiko-mono/pull/19488 — conditional propose; one proposal per block; expected-id precedent.

Phase-2 working notes synthesized (same directory as this file): `ft-spec-model.md`, `ft-client-behaviour.md`, `ft-taiko-inbox-facts.md`, `ft-analysis-nonce-lock.md`, `ft-alternatives.md`, `roadmap-glamsterdam.md`, `roadmap-hegota.md`.

### Consolidated UNVERIFIED list
1. That an invalid type-0x06 transaction invalidates the containing block: inherited rule, not restated in EIP-8141.
2. All gas figures (30,944; 75,594; 76,485; 100,517; 218,805; +13.5k / +18%; G's 120-150 bytes and ≤ 4,900 gas; A1/A7 overhead estimates).
3. On-chain sampling figures (0.002 losers per proposal; 34% / 38% blob-fee share).
4. Absence of EIP-8141 support in upstream revm/Foundry and of `0xaa`/`0xb0-0xb5` builtins in released solc (search/docs only).
5. Which geth sub-pool will hold blob-carrying frame transactions (10% vs 100% bump).
6. Nethermind's literal one-pending-per-sender enforcement; geth's reorg reinject code path.
7. That public-mempool copies of privately submitted transactions can land and revert (inferred from builder docs).
8. Taiko derivation rules (default-manifest fallback; 1 s per forced inclusion); on-chain `getConfig().proposerChecker`; `minBond == 0` "since activation".
9. EIP-8250's `nonce_keys == [0]` alias keeping a G v1 working.
10. That commits `857622a` and `5c0236f` (2026-09-29) changed no G-relevant semantics (from titles; diff not separately checked).
11. Mainnet activation dates of Glamsterdam and Hegotá (undecided per the EF blog).
12. EIP-8369 blob carve-out wording (quoted second-hand via a Nethermind PR).

---

## Erratum (2026-10-01)

Claims 10, 19 and 31, the worked example in §6 and the pin list in §8 describe the PDF's call `proposeFor(address, bytes32 packed)`, a Shasta proposal whose data lives in blobs, so the gate's `SENDER` frame carries exactly 68 bytes. Etna's landing is not that call: `landFor(address _rewardTo, LandInput _in)` carries a proof and a certificate in calldata, so its data is dynamic. The design page (`design/frame-transactions.html`) therefore pins the selector, the `_rewardTo` word and a length bound (`LAND_CALLDATA_MAX`) instead of `len(data) == 68`; the gate reads only that fixed prefix and the rest is covered by the actor's signature over the transaction. The nonce-as-lock conclusions are unchanged by this. The same page now also states the cost a shape-1 transaction pays when a direct or shape-2 landing consumes its parent first: the transaction stays valid, frame 3 reverts at the inbox's first check, the nonce is burned and the actor pays that gas (§3.1 rows 9 and 10 and §3.2 item 4 state the rule: a `SENDER` revert never rolls back the nonce increment; the earlier design wording "invalid (shape 1)" was wrong). Raised by the review posted from PR #22188 on 2026-10-01.

---

## 11. Verification record

This document was produced by a research sub-agent and then independently re-verified by a skeptic sub-agent instructed to refute it (report: [`notes/03.verify.md`](notes/03.verify.md), 2026-09-30). The skeptic re-fetched EIP-8141 (byte-identical, md5 `284f4d79ea303353412f58eb73d09421`), every cited client and PR source, and 19 Taiko `file:line` citations at HEAD `61d8f18`. Result: 100 statements checked, 2 wrong, 4 unverifiable, the rest correct. The two errors (Nethermind PR #13058 status; the PR #12253 quote) were in the client/PR status inventory, did not bear on the verdict, and have been corrected in place above (marked "corrected after skeptic review"). The skeptic's conclusion: "No HOLDS claim in Section 4 should be downgraded to FAILS; none needs to become UNDETERMINED." The architect's own reading of the spec sections on nonce checking (L390-392), `APPROVE` (L700-727) and the mempool policy (L1083-1108) agrees.
