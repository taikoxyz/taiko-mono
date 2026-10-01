# EIP-8141 Frame Transaction — Validity Semantics Model

Prepared 2026-09-30 from the CURRENT spec text. Every claim is tagged **VERIFIED** (fetched primary source, URL given, fetched 2026-09-30) or **UNVERIFIED**. Quotes are verbatim from the raw markdown at `https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md` unless another source is named. Local copies of everything fetched are in this directory (`eip-8141-raw.md`, `eip-8250-raw.md`, `eip-8081-raw.md`, `magicians-thread.txt`, `es-osaka.py`).

Fetch-failure record: the GitHub REST API (`api.github.com`) returned HTTP 403 through the session proxy for `ethereum/EIPs` (repo not attached), and the github MCP `list_commits` / `pull_request_read` tools were refused for the same reason. Commit history was instead obtained by fetching the GitHub commits HTML page; PR states came from the github MCP `search_pull_requests` tool (which worked) plus WebFetch of each PR page. `gh` CLI is not installed in this container.

---

## 1. Metadata

| Field | Value | Status |
|---|---|---|
| EIP | 8141, "Frame Transaction" | VERIFIED — raw md front matter |
| Status | `Draft` | VERIFIED — raw md front matter; eips.ethereum.org page shows "Draft Standards Track: Core", no last-call deadline (https://eips.ethereum.org/EIPS/eip-8141) |
| Type / Category | Standards Track / Core | VERIFIED |
| Created | 2026-01-29 | VERIFIED |
| Requires | `1559, 2718, 2780, 3529, 3607, 4844, 7594, 7702, 7708, 7778, 7825, 7976, 8037` | VERIFIED (raw md, 2026-09-30) |
| discussions-to | https://ethereum-magicians.org/t/frame-transaction/27617 | VERIFIED |
| Authors | Vitalik Buterin, lightclient, Felix Lange, Yoav Weiss, Alex Forshtat, Dror Tirosh, Shahaf Nacson, Derek Chiang, Toni Wahrstätter, Stavros Vlachakis | VERIFIED |
| Last commit to `EIPS/eip-8141.md` | `5c0236f` "Update EIP-8141: replace 7623 with 7976", lightclient, 2026-09-29; preceded by `857622a` "bound producer-side re-execution of an unapproving validation prefix" (2026-09-29), `b75cbe6` (2026-09-01), `7d1c8bf` (2026-08-24), `3ceef8d` (2026-08-21), `7d1f885`, `b6b6f1c`, `b3e8cad` (2026-08-20), `0603514`, `ead1a36` (2026-08-18) | VERIFIED — https://github.com/ethereum/EIPs/commits/master/EIPS/eip-8141.md (fetched 2026-09-30) |
| Fork inclusion | EIP-8081 "Hardfork Meta - Hegotá" (status Draft) lists under **"EIPs Scheduled for Inclusion"**: `EIP-8141: Frame Transaction`; and under **"Considered for Inclusion"**: `EIP-8250: Keyed Nonces for Frame Transactions` | VERIFIED — https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8081.md (fetched 2026-09-30). PR #12251 "Update EIP-8081: SFI EIP-8141" merged 2026-08-27 (github MCP search). |
| Tx type | `FRAME_TX_TYPE = 0x06` | VERIFIED |

Other constants (VERIFIED, Constants table): `FRAME_TX_INTRINSIC_COST = 12000`, `FRAME_TX_PER_FRAME_COST = 475`, `ENTRY_POINT = address(0xaa)`, `EXPIRY_VERIFIER = address(0x8141)`, `EXPIRY_DATA_LENGTH = 8`, `MAX_FRAMES = 64`; imported `TX_MAX_GAS_LIMIT = 16,777,216` (EIP-7825), `TX_VALUE_COST = 6,000`, `CPSB = 1,530`, `STATE_BYTES_PER_NEW_ACCOUNT = 120`, `GAS_PER_BLOB = 131,072`.

---

## 2. Envelope and frames

### 2.1 Payload (VERIFIED, "Payload Encoding")

```
[chain_id, nonce, sender, frames, signatures, fees, blob_versioned_hashes]

frames = [[mode, flags, target, limits, value, data], ...]
limits = [execution, state]
signatures = [[scheme, signer, msg, signature], ...]
fees = [max_priority_fee_per_gas, max_fee_per_gas, max_fee_per_blob_gas]
```

Outer fields (quoted): "`nonce` -- nonce of the sender to prevent replays." / "`sender` -- the address of the intended sender of the transaction." / "`max_fee_per_blob_gas` -- ... Must be `0` if `blob_versioned_hashes` is empty." / "`blob_versioned_hashes` -- list of EIP-4844 blob versioned hashes."

Note: there is **no transaction-level gas limit field and no outer signature over the envelope** — gas is the sum of per-frame limits; authentication lives entirely in `signatures` + frame execution. (VERIFIED: the payload list above; Security Considerations: "Because a frame transaction carries no outer signature over the whole envelope".)

### 2.2 Frame object (VERIFIED, "Frame object")

- "`mode` -- the mode specifies the specific execution semantics the frame will execute with."
- "`flags` -- specifies optional frame / mode features."
- "`target` -- the destination or `to` address for the frame." (may be `None` → resolves to `tx.sender`)
- "`limits` -- list of gas limits for the frame: `execution` -- the maximum execution gas ... `state` -- the maximum state gas ([EIP-8037])"
- "`value` -- the amount in wei that should transferred from the `sender` as part of the frame execution."
- "`data` -- the calldata provided to the top level call frame."

Flags (VERIFIED):

| Flag bits | Meaning | Valid with |
|---|---|---|
| 0-1 | Approval scope | Any mode |
| 2 | Atomic batch (`ATOMIC_BATCH_FLAG = 0x4`) | `DEFAULT`, `SENDER` |
| 3.. | reserved | No mode |

"If a flag is not valid under the current mode, the transaction is invalid."

### 2.3 Modes (VERIFIED)

| mode | Name | Summary (quoted) |
|---|---|---|
| 0 | `DEFAULT` | "Execute frame as `ENTRY_POINT`" — `caller = ENTRY_POINT`; may call `APPROVE` (approval-scope flags are "Valid with: Any mode"); may do state writes; `value` must be 0 |
| 1 | `VERIFY` | "Frame identifies as transaction validation" — `caller = ENTRY_POINT`; executed "as a `STATICCALL`"; "Only `APPROVE` can modify the state or transaction context"; **failure = tx invalid**; `value` must be 0; cannot carry `ATOMIC_BATCH_FLAG` |
| 2 | `SENDER` | "Execute frame as `sender`" — requires `sender_approved == true` else "the transaction is invalid"; `caller = tx.sender`; only mode allowed to carry non-zero `value` (`assert frame.mode == SENDER or frame.value == 0`) |

Expiry is NOT a mode: it is a `VERIFY` frame with `target == EXPIRY_VERIFIER` (see §5).

### 2.4 Signature entries (VERIFIED, "Transaction Signatures", "Signature Validation")

| scheme | Name | encoding | gas |
|---|---|---|---|
| 0x0 | `ARBITRARY` | arbitrary bytes | 100 |
| 0x1 | `SECP256K1` | `v (1) || r (32) || s (32)` | 2800 |
| 0x2 | `P256` | `r || s || qx || qy` | 6700 |
| 0x3..255 | reserved | | |

- "For `SECP256K1` and `P256`, the `signer` is a 20-byte Ethereum address. If absent, `tx.sender` is used". "For `ARBITRARY`, `signer` MUST be empty."
- `msg`: "if `len(msg) == 0`, the signature is signed over `compute_sig_hash(tx)`"; "if `len(msg) == 32`, the signature is signed the explicit 32-byte digest `msg`"; "The explicit 32-byte zero digest is invalid."
- "For `P256`, the signer address must be `keccak256(qx || qy)[12:]`."
- `compute_sig_hash`: signatures with empty `msg` have their raw bytes elided, then `keccak(bytes([FRAME_TX_TYPE]) + rlp(tx))`.
- "Every protocol-validated signature in this list must validate successfully before any frame is executed. If any signature is malformed, or any protocol-validated signature is invalid, the whole transaction is invalid."
- SECP256K1 canonicality: `v <= 1`, `0 < r < N`, low-s. P256: low-s enforced by protocol even though P256VERIFY accepts high-s.

### 2.5 APPROVE (`0xaa`) (VERIFIED)

Stack: `offset, length, scope`. Scopes: `APPROVE_NONE 0x0`, `APPROVE_PAYMENT 0x1`, `APPROVE_EXECUTION 0x2`, `APPROVE_EXECUTION_AND_PAYMENT 0x3`; `APPROVE_SCOPE_MASK = 0x3`.

Who may call: "If `ADDRESS != resolved_target`, revert." and "Ensure that `scope` is one of the caller's allowed scopes in `frame.flags`, otherwise revert." Rationale: "Because `DELEGATECALL` preserves `ADDRESS`, code executed via `DELEGATECALL` from the resolved target may also execute `APPROVE` successfully." APPROVE is *not* restricted to `VERIFY` mode by the text; static constraint: "if frame.flags & APPROVE_EXECUTION: assert frame.target is None or frame.target == tx.sender".

Effects (quoted):
- `APPROVE_EXECUTION`: "If `sender_approved == true`, revert ... If `resolved_target != tx.sender`, revert ... Set `sender_approved = true`." **No nonce change.**
- `APPROVE_PAYMENT`: "If `payer` was already set, revert ... If `resolved_target` has insufficient balance, revert ... If `sender_approved == false`, revert ... Immediately before incrementing the sender's nonce, if `tx.sender` does not exist ..., charge `STATE_BYTES_PER_NEW_ACCOUNT * CPSB` from the current frame's `state_gas_left` ... Increment the sender's nonce, set `payer = resolved_target`, and collect the transaction's `max_cost` from `payer`."
- `APPROVE_EXECUTION_AND_PAYMENT`: "If `sender_approved` or `payer` was already set, revert ... If `resolved_target` != `tx.sender`, revert ... Set `sender_approved = true`, increment the sender's nonce, set `payer = resolved_target`, and collect the transaction's `max_cost` from `payer`."

Consequences: a payment-scoped APPROVE requires the sender to already be (or simultaneously be) execution-approved; therefore a paymaster (`pay` frame, flags `0x1`) must come *after* the sender's `only_verify`. Each of `sender_approved` and `payer` can be set only once, so at most two approving frames exist per tx (thread post #135, VERIFIED as discussion).

### 2.6 Introspection indices (VERIFIED)

`TXPARAM (0xb0)`, gas 2: `0x00` tx type, `0x01` nonce, `0x02` sender, `0x03` max_priority_fee_per_gas, `0x04` max_fee_per_gas, `0x05` max_fee_per_blob_gas, `0x06` "max cost (basefee=max, all gas used, includes blob cost at `blob_base_fee`, intrinsic cost, and signature verification cost)", `0x07` `len(blob_versioned_hashes)`, `0x08` `compute_sig_hash(tx)`, `0x09` `len(frames)`, `0x0A` current frame index, `0x0B` `len(signatures)`, `0x0C` `state_gas_left` of current frame. Undefined → exceptional halt; any of these opcodes outside a frame tx → exceptional halt.

`FRAMEDATALOAD (0xb1)`: stack `offset, frameIndex`, gas 3, CALLDATALOAD semantics on chosen frame's `data`; OOB index → halt. `FRAMEDATACOPY (0xb2)`: `memOffset, dataOffset, length, frameIndex`.

`FRAMEPARAM (0xb3)`, gas 2, stack `frameIndex` (top), `param`: `0x00` resolved_target, `0x01` limits.execution, `0x02` mode, `0x03` flags, `0x04` len(data), `0x05` status (halt if current/future; 0 fail, 1 success, 2 skipped), `0x06` allowed_scope, `0x07` atomic_batch bit, `0x08` value, `0x09` limits.state, `0x0A` gas_used.execution, `0x0B` gas_used.state (both halt if current/future).

`SIGPARAM (0xb4)`, gas 2, stack `signatureIndex` (top), `param`: `0x00` resolved_signer (halt for ARBITRARY), `0x01` scheme, `0x02` msg, `0x03` len(signature) (ARBITRARY only; halt otherwise). `SIGDATACOPY (0xb5)`: copies raw bytes, ARBITRARY only.

EIP-8250 (Draft) would add `TXPARAM 0x0D` pre-state legacy nonce, `0x0E` len(nonce_keys), `0x0F` nonce_keys_hash, `0x10` nonce_keys[0] (VERIFIED from eip-8250 raw md).

---

## 3. Validity vs revert

Terminology used by the spec: "invalid" / `invalid_transaction()` = not includable; Rationale: "Intrinsic gas is state-independent and decides validity. ... After approval the transaction is still included and pays for the gas consumed, while a failed `VERIFY` frame invalidates the transaction as usual." (VERIFIED, "Intrinsic cost decomposition").

General rule that an invalid tx makes the *block* invalid: EIP-8141 does not restate it. It is the standard execution rule — execution-specs `check_transaction` docstring: "Check if the transaction is includable in the block. Raises InvalidBlock: If the transaction is not includable." and "if sender_account.nonce > Uint(tx.nonce): raise NonceMismatchError('nonce too low')" (VERIFIED for existing tx types: https://raw.githubusercontent.com/ethereum/execution-specs/master/src/ethereum/forks/osaka/fork.py, fetched 2026-09-30). Application of that rule to type-0x06 is the obvious reading of `invalid_transaction()` but is **UNVERIFIED** as a quoted 8141 line.

| # | Condition | INVALID or REVERT | Who pays | When checked | Spec quote / ref |
|---|---|---|---|---|---|
| 1 | Static constraint violated (field ranges, `len(frames)` not in 1..64, bad `sender` length, bad blob hash version, `max_fee_per_blob_gas != 0` with no blobs, unknown sig scheme, bad `signer`/`msg` lengths, zero 32-byte `msg`, `mode >= 3`, `flags >= 8`, bad target length, `value != 0` on non-SENDER, `APPROVE_EXECUTION` flag with target ≠ sender, `ATOMIC_BATCH_FLAG` on VERIFY/last frame/before VERIFY, approval-scope flag on a batch frame, gas > `TX_MAX_GAS_LIMIT`) | INVALID | nobody | Stateless, before any state access ("Constraints") | "Some validity constraints can be determined statically" |
| 2 | Flag not valid for mode | INVALID | nobody | static | "If a flag is not valid under the current mode, the transaction is invalid." |
| 3 | Expiry verifier frame malformed (`flags != 0`, `value != 0`, `limits.state != 0`, `len(data) != 8`) or >1 expiry frame | INVALID | nobody | static | "An expiry verifier frame is invalid unless all of the following hold ... A transaction can contain at most one expiry verifier frame." |
| 4 | `tx.nonce != state[tx.sender].nonce` | INVALID | nobody | "To begin processing", step 1, before sig validation and before any frame | "1. Ensure `tx.nonce == state[tx.sender].nonce`" |
| 5 | Any protocol-validated signature (SECP256K1/P256) fails, or any entry malformed | INVALID | nobody | step 3, before any frame | "If any signature is malformed, or any protocol-validated signature is invalid, the whole transaction is invalid." |
| 6 | `VERIFY` frame reverts or halts exceptionally (incl. OOG on `limits.execution`, insufficient `state_gas_left` in APPROVE, expiry check failing, cold-access charge unaffordable) | INVALID | nobody | during that frame | "If the frame fails by reverting or halting exceptionally, the transaction is invalid. This unrolls any effects of `APPROVE`." |
| 7 | `SENDER` frame reached while `sender_approved == false` | INVALID | nobody | at that frame's entry | "`sender_approved` must be `true`. If not, the transaction is invalid." |
| 8 | End of tx with `payer == None` | INVALID | nobody | after all frames | "After executing all frames, verify that `payer` has been set ... If it is not, the whole transaction is invalid." |
| 9 | Blob-carrying tx with `max_fee_per_blob_gas < blob_base_fee` | INVALID (not includable in that block) | nobody | block inclusion | "The transaction is only valid for inclusion in a block if `tx.fees.max_fee_per_blob_gas >= blob_base_fee` of that block." |
| 10 | Worst-case gas does not fit remaining block execution/state capacity | not includable | nobody | block building/validation | "A frame transaction may be included in a block only if its worst case fits the remaining capacity of **each** dimension" |
| 11 | `DEFAULT` or `SENDER` frame reverts or halts (OOG, insufficient value balance, missing state gas) | REVERT of that frame only; tx included | payer (max_cost escrowed at APPROVE, refund at settlement) | during frame | "If a frame's execution reverts, its state changes and approval context (`payer`, `sender_approved`) are discarded." ; "A charge that exhausts either pool halts the current call frame rather than changing the transaction's static validity." |
| 12 | Frame inside atomic batch fails | batch unrolled to pre-batch state; remaining frames skipped (status 2); tx included | payer | during batch | "When a frame in the batch fails, the state must be rolled back ... All remaining frames in the atomic batch are skipped." |
| 13 | `APPROVE` in a non-VERIFY frame, then that frame reverts | approval context (incl. nonce increment & escrow) discarded with the frame; tx continues; if `payer` never set → INVALID (#8) | see #8 | frame end | same quote as #11 |
| 14 | Redundant/conflicting APPROVE (second payer, second execution approval, wrong scope, `ADDRESS != resolved_target`) | REVERT of the current *call frame* (not tx) — in a VERIFY frame that revert propagates to #6 | — | during APPROVE | "If `payer` was already set, revert the current call frame." (thread #3 by fjl: "Redundant/conflicting approvals do not invalidate the transaction.") |
| 15 | `SENDER` frame with `value` > sender balance | REVERT of frame, "consuming the gas charged so far" | payer | frame entry | "if the caller does not have sufficient balance to transfer `frame.value`, the frame reverts" |

Key structural facts:
- Once a payment-scoped APPROVE has succeeded in a *successful VERIFY frame*, nothing later (revert, batch unroll, OOG) can un-include the tx — unless a **later VERIFY frame** fails, which invalidates the whole tx (hence mempool rule 8: "There must not be `VERIFY` frame after validation prefix"). VERIFIED.
- The tx pays nothing unless included: "A frame transaction is charged nothing until one of its frames approves payment" (VERIFIED, "Replacement and Eviction").

---

## 4. Nonce semantics

VERIFIED quotes, in execution order:

1. Check, before anything else: "To begin processing a frame transaction: 1. Ensure `tx.nonce == state[tx.sender].nonce`" — i.e. exact equality against the sender's account nonce in the pre-state *at the transaction's position in the block*. Failure → transaction invalid (see §3 row 4). Note `tx.sender` is an explicit field, so the check needs no signature recovery ("Explicit Sender State-Read Amplification ... the nonce check required before execution").
2. Increment, inside `APPROVE` with a payment scope only: "Increment the sender's nonce, set `payer = resolved_target`, and collect the transaction's `max_cost` from `payer`." `APPROVE_EXECUTION` alone does **not** touch the nonce.
3. The increment is `+1` on the *current* account nonce (not `tx.nonce + 1`). EIP-8250 makes this explicit: "`increment_account_nonce(sender)` increments the sender's current account nonce; it does not set the account nonce to `tx.nonce_seq + 1`. This preserves EIP-8141 behavior if an earlier frame in the same transaction has already changed the sender's legacy nonce, for example by account deployment or by executing `CREATE` or `CREATE2` at `tx.sender`." (VERIFIED, eip-8250 raw md). So a `deploy` frame that creates the sender account (nonce → 1 by EIP-161) followed by `self_verify` leaves the sender at nonce 2 after a tx with `tx.nonce = 0`. This is an inference from the two texts; UNVERIFIED as an explicit 8141 sentence.
4. Rollback: if the frame that executed the payment APPROVE reverts, the increment is discarded ("its state changes and approval context ... are discarded"; for VERIFY: "This unrolls any effects of `APPROVE`" and the tx is invalid). A batch failure never rolls it back because approval scope flags are statically disallowed on batch frames: "Unrolling a failed batch therefore never rolls back the sender nonce increment or the `max_cost` collection".
5. Exactly-once: "The sender's nonce is consumed exactly once per transaction when payment is approved, so two pending transactions sharing it are alternatives, of which at most one can ever be included." (Mempool, "Replacement and Eviction").
6. Gas: the increment "has no additional execution-gas cost ... already covered by the frame transaction's intrinsic cost"; if it creates the sender account, `STATE_BYTES_PER_NEW_ACCOUNT * CPSB = 183,600` state gas is charged from the approving frame's `state_gas_left`, and "If the pool cannot cover the charge, halt the current call frame exceptionally without applying any approval effects."
7. `TXPARAM(0x01)` returns `tx.nonce` (the envelope field, not live state).
8. EIP-3607 is *not* applied to frame txs: "Do not apply the restriction put in place by [EIP-3607] to frame transactions. Specifically, `SENDER` frames originate calls where `tx.sender` is a contract account."

EIP-8250 (Draft, created 2026-04-16, requires 7623, 8037, 8141; "Considered for Inclusion" in Hegotá per EIP-8081) would replace `nonce` with `(nonce_keys, nonce_seq)`: `nonce_keys == [0]` aliases the account nonce; non-zero keys live in `NONCE_MANAGER = 0x...8250` storage at `keccak256(pad32(sender) || key)`; validity `assert tx.nonce_seq == current_nonce_seq(tx.sender, nonce_key)` for every key, "at the same stage as EIP-8141's existing nonce check, before any frame executes"; consumption on "the unique successful payment-scoped `APPROVE`"; first use of a key costs `STATE_BYTES_PER_STORAGE_SET * CPSB = 97,920` state gas; mempool identity becomes `(sender, nonce_keys, nonce_seq)` but "This EIP preserves EIP-8141's limit of one pending frame transaction per sender in the public mempool." (all VERIFIED from eip-8250 raw md).

---

## 5. Expiry semantics

Current spec (VERIFIED, "Expiry Verifier Frame"):
- Mechanism: a **canonical contract at `EXPIRY_VERIFIER = address(0x8141)`**, invoked by an ordinary `VERIFY`-mode frame. It is neither a mode nor a transaction field: "A `VERIFY` frame whose `frame.target` equals `EXPIRY_VERIFIER` is an **expiry verifier frame**. It calls the expiry verifier contract deployed at `EXPIRY_VERIFIER` with `frame.data` as calldata. The calldata is interpreted as an 8-byte unsigned big-endian expiry timestamp. The call reverts unless `block.timestamp <= expiry_timestamp`."
- Static validity: "`frame.flags == 0`", "`frame.value == 0`", "`frame.limits.state == 0`", "`len(frame.data) == EXPIRY_DATA_LENGTH`" (8); "A transaction can contain at most one expiry verifier frame."
- Installation: "At activation, clients must install the following expiry verifier contract runtime code at `EXPIRY_VERIFIER`" — bytecode `0x60083614600a575f5ffd5b5f3560c01c4211601657005b5f5ffd`.
- Effect of failure: because it is a VERIFY frame, revert ⇒ **transaction invalid** (§3 row 6), pays nothing. On success "the frame succeeds with no return data and no logs. The frame consumes gas according to normal EVM execution rules."
- Client optimization: "Clients may omit the explicit EVM execution and directly perform the expiry check above, provided the externally observable result is identical".
- **No `valid_after` / not-before bound exists in the current text.** Only an upper bound (`block.timestamp <= expiry`). VERIFIED by absence in raw md (grep of `valid_after` returns nothing).
- Mempool: "An `expiry_verify` frame MAY appear only as first frame in the frame list" and is skipped when matching prefix shapes; "A node MUST drop a frame transaction from the public mempool if it contains an `expiry_verify` frame whose deadline is less than the node's view of the current block timestamp at any point." `TIMESTAMP` is banned in the validation prefix "Except in an expiry verifier frame executing the canonical runtime code at `EXPIRY_VERIFIER`."
- Eviction ordering uses the deadline: "then transactions with the nearest expiry deadline".

Pending changes (VERIFIED via github MCP search + PR pages, 2026-09-30):
- **PR #12252** "add valid_after to the expiry verifier frame" (nerolation, opened 2026-08-27): **OPEN, draft, not merged.** Proposes 16-byte calldata `valid_after || expiry_timestamp`, check `valid_after <= block.timestamp <= expiry_timestamp`, and mempool dropping of not-yet-valid txs. https://github.com/ethereum/EIPs/pull/12252
- **PR #12198** "make the expiry frame a new mode" (nerolation, opened 2026-08-19): **CLOSED without merge on 2026-09-29**; lightclient: "Closing as I think we discussed previously and the general consensus was to keep as canonical verifier." https://github.com/ethereum/EIPs/pull/12198
- **PR #12387** "deploy frames expiry verifier as standard contract" (lightclient, opened 2026-09-28): **OPEN, draft.** Would deploy the verifier as an ordinary contract instead of enshrining code at fork activation; semantics unchanged. https://github.com/ethereum/EIPs/pull/12387
- PR #12203 "state that installing the expiry verifier leaves the nonce" — closed 2026-08-24 (not merged per search; UNVERIFIED whether merged: search returned `state: closed` with no `merged_at`).

---

## 6. VERIFY frame restrictions

Consensus-level (VERIFIED, "Behavior"):
- "Execute the frame as a `STATICCALL`, disallowing state manipulation. Only `APPROVE` can modify the state or transaction context in `VERIFY`."
- "If the frame fails by reverting or halting exceptionally, the transaction is invalid."
- `caller = ENTRY_POINT` (`ORIGIN` returns `ENTRY_POINT`, cold); `value` must be 0; cannot be in an atomic batch.
- Storage **reads** are allowed at consensus level (STATICCALL permits SLOAD); state gas in VERIFY only through APPROVE creating the sender account.
- There is **no consensus `MAX_VERIFY_GAS`**; the frame's `limits.execution` bounds it, capped overall by `TX_MAX_GAS_LIMIT`.

Public-mempool level only (VERIFIED, "Mempool" — explicitly "not consensus"; "Transactions outside these rules may be accepted into a local or private mempool, but must not be propagated through the public mempool"):
- `MAX_VERIFY_GAS = 100_000`: "The sum of `limits.execution` values across the validation prefix, plus the intrinsic cost of validating `tx.signatures`, must not exceed `MAX_VERIFY_GAS`." `MAX_VERIFY_STATE_GAS = 500_000` on summed `limits.state`.
- Banned opcodes in the validation prefix: GASPRICE, BLOCKHASH, COINBASE, TIMESTAMP (except canonical expiry verifier), NUMBER, PREVRANDAO, GASLIMIT, BASEFEE, BLOBBASEFEE, SLOTNUM, GAS (except immediately before `*CALL`), CREATE/CREATE2/SETDELEGATE (except first `deploy` frame), INVALID, SELFDESTRUCT, BALANCE, SELFBALANCE, SSTORE (except sender storage in `deploy`).
- "`SLOAD` can be used only to access `tx.sender` storage, including when reached transitively via `CALL*` or `DELEGATECALL`." Reject if "execution reads storage outside `tx.sender`".
- `CALL*`/`EXTCODE*` only to existing non-delegated contracts or precompiles.
- Reject if "a frame in the validation prefix reverts" or "a `self_verify`, `only_verify`, or `pay` frame exits without its required `APPROVE`".

---

## 7. Pool rules

All VERIFIED from "Mempool" (policy, non-consensus):
- Recognized validation prefixes: `[self_verify]`, `[deploy, self_verify]`, `[only_verify, pay]`, `[deploy, only_verify, pay]` (optionally preceded by `expiry_verify`). `self_verify` = VERIFY flags `0x3` targeting sender; `only_verify` = VERIFY `0x2`; `pay` = VERIFY `0x1`; `deploy` = DEFAULT `0x0`, must be first.
- "7. A node should keep at most one pending frame transaction per sender in the public mempool. A new transaction from the same sender MAY replace the existing one only if it uses the same nonce and satisfies the replacement rules below."
- "Pending frame transactions are identified by `(sender, nonce)`."
- Replacement: "should only be accepted and propagated if it increases both `max_fee_per_gas` and `max_priority_fee_per_gas` by at least a node-configured minimum increment (10% is the conventional default)"; blob txs also follow blob-pool `max_fee_per_blob_gas` conventions; "A replacement may name a different payer".
- Payer exposure: "A node must not hold pending frame transactions whose summed maximum costs exceed the payer's balance" (per payer, `reserved_pending_cost`); canonical paymaster identified by exact runtime-code match; non-canonical paymaster limited to `MAX_PENDING_TXS_USING_NON_CANONICAL_PAYMASTER = 1` pending tx.
- Eviction order: "first transactions already invalid against the current head, then transactions with the nearest expiry deadline, then transactions with the lowest effective priority fee."
- Producer-side bound (added by commit 857622a, 2026-09-29): "A block producer SHOULD bound the unpaid validation work it spends on any one pending frame transaction: after a bounded number of consecutive block-building attempts in which the transaction's validation prefix fails to approve, the producer MAY evict it ... A build-time failure to approve MAY be transient rather than permanent, for example a payer funded by an earlier transaction in the same block, a prefix reading state that a preceding transaction changes ... so the bound SHOULD permit more than one attempt before eviction."
- Revalidation on new head: re-simulate "at least transactions for the same sender, transactions whose recorded sender storage slots changed, ... transactions whose payer's balance or code changed."
- Security Considerations: "it can be assumed that handling of frame transactions imposes similar restrictions as EIP-7702 on mempool relay, i.e. only a single transaction can be pending for an account that uses frame transactions."

---

## 8. Gas and blob accounting

VERIFIED, "Gas Accounting":
- Two dimensions per frame, no reservoir: "`frame.limits.execution` bounds a frame's execution gas and `frame.limits.state` bounds its state gas. The reservoir model ... does not apply within frame transactions."
- Intrinsic: `frame_tx_intrinsic_gas = FRAME_TX_INTRINSIC_COST + len(frames)*FRAME_TX_PER_FRAME_COST + frame_data_cost + signature_data_cost + signature_verification_cost + value_transfer_cost`; "derivable from the transaction fields alone, with no state access". Calldata floor per EIP-7976 (`TOTAL_COST_FLOOR_PER_TOKEN = 16`).
- `max_gas = max(standard_gas_limit, calldata_floor_gas + sum(limits.state))`; `max_cost = max_gas * max_fee_per_gas + blob_gas * blob_base_fee`; collected from `payer` at APPROVE; `payer_refund = max_cost - charged_fee` returned "After execution ... to the payer. This is the `resolved_target` that called `APPROVE(APPROVE_PAYMENT)` or `APPROVE(APPROVE_EXECUTION_AND_PAYMENT)`."
- Who pays: only `payer`; every frame (including frames before the paying one, e.g. `deploy`, `only_verify`, and the `expiry_verify` frame) is charged to the single payer at settlement. Unused frame gas is refunded but "None of this gas becomes available to a subsequent frame."
- OOG in VERIFY: exceptional halt ⇒ tx invalid, nobody pays (§3 row 6). OOG in SENDER/DEFAULT: "When a frame halts exceptionally, perform the same state-gas restoration, but consume its entire execution-gas pool." Tx included, payer charged.
- Frame-entry cold/warm access is charged inside the frame's `limits.execution`; "If `gas_left` cannot cover the charge, the frame halts exceptionally" (fatal for VERIFY frames; "A frame whose `limits.execution` cannot cover the entry access charge halts exceptionally before the default code is evaluated — which, for a `VERIFY` frame, invalidates the transaction.").
- Block reservation: `execution_reservation = max(intrinsic + Σ limits.execution, calldata_floor_gas)`, `state_reservation = Σ limits.state`, each must fit the remaining block capacity of its dimension.
- Blobs (VERIFIED, "Blob handling"): "the payer is also the blob-fee payer"; "The transaction is only valid for inclusion in a block if `tx.fees.max_fee_per_blob_gas >= blob_base_fee` of that block. `max_fee_per_blob_gas` is used only for this inclusion check. The payer is charged `blob_gas * blob_base_fee`; no additional blob fee is collected or refunded." Blob cost is part of `max_cost` escrowed at APPROVE. **If the tx is invalid, no payer is ever set and nothing — including blob fee — is charged** (follows from "charged nothing until one of its frames approves payment" and "This unrolls any effects of `APPROVE`"). Blobs are optional; `BLOBHASH` works in every frame; gossip uses the EIP-7594 wrapper.

---

## 9. Same-nonce race answer

**Setup:** two frame txs T1, T2, same `sender` G and same `nonce = n`; T1 included first in block B.

**Answer (VERIFIED by the quoted lines below): T2 is INVALID — never includable after T1, and pays nothing. It is not "included-and-reverted".**

Decisive spec lines:
1. "To begin processing a frame transaction: 1. Ensure `tx.nonce == state[tx.sender].nonce`". This runs before signature validation and before any frame. After T1's payment `APPROVE` ("Increment the sender's nonce, set `payer = resolved_target`, and collect the transaction's `max_cost` from `payer`"), `state[G].nonce == n + 1`, so T2 (`nonce = n`) fails step 1.
2. "The sender's nonce is consumed exactly once per transaction when payment is approved, so two pending transactions sharing it are alternatives, of which at most one can ever be included."
3. Nothing is charged for a tx that never reaches APPROVE: "A frame transaction is charged nothing until one of its frames approves payment". Since T2 fails before any frame runs, no `payer` exists and no gas, blob fee, or intrinsic cost is collected from anyone.

**T2 in the same block B after T1:** identical outcome. The nonce check reads the sender's account nonce at T2's position in block execution order, which already reflects T1's increment. (EIP-8250 states the ordering principle explicitly for its delta: "Stateful validity is evaluated against the transaction's actual pre-state within block execution order. Therefore, two frame transactions whose selected key sets overlap for the same sender are valid in one block only if each transaction's `nonce_seq` equals the current sequence of every selected key at its position in block execution order." — VERIFIED from eip-8250; the same is implicit in 8141's step-1 wording.) T2 is invalid in B.

**If the builder includes T2 anyway:** EIP-8141 does not add a special block-level rule; the ordinary Ethereum rule applies — a block containing a non-includable transaction is invalid. Execution-specs (`check_transaction`): "Check if the transaction is includable in the block. Raises InvalidBlock: If the transaction is not includable." with `NonceMismatchError("nonce too low")` (VERIFIED for existing types in osaka `fork.py`). The 8141 text uses the same vocabulary ("`invalid_transaction()`", "the whole transaction is invalid") and its Rationale states "Intrinsic gas is state-independent and decides validity. ... a failed `VERIFY` frame invalidates the transaction as usual." Therefore the whole block B is invalid, T2 earns the builder nothing, and honest validators reject B. Marked **UNVERIFIED as a quoted 8141 sentence** (the EIP relies on the inherited block-validity rule rather than restating it).

**Subtleties that matter for the research question:**
- The same "INVALID, pays nothing" outcome applies to *any* failure before or during the payment APPROVE: bad signature, expiry passed, VERIFY revert/OOG, or a later VERIFY frame failing. All of these leave no on-chain trace and charge no one — the cost is borne by the builder/validator as wasted simulation, which is exactly the DoS surface the mempool section polices and why the "bound producer-side re-execution" rule (commit 857622a) was added.
- Conversely, once the payment APPROVE has succeeded inside a successful VERIFY frame and no VERIFY frame follows, T1 is irrevocably included even if every SENDER frame reverts; the nonce stays incremented ("Unrolling a failed batch therefore never rolls back the sender nonce increment").
- A replacement transaction (same `(sender, nonce)`, higher fees) is the only mempool-sanctioned way to race a pending frame tx; the loser becomes permanently invalid the moment the winner's APPROVE executes.
- Under EIP-8250 (Considered for Inclusion, not scheduled), T1 and T2 with disjoint *non-zero* nonce-key sets would both be includable; with overlapping keys (or key `[0]`), the same "second one is invalid" rule holds. EIP-8250 Security Considerations: "A 'send another transaction with the same legacy nonce' cancellation strategy does not invalidate a pending non-zero-key frame transaction."

---

## 10. Open spec issues (affecting validity semantics)

From the magicians thread (169 posts, last 2026-09-29; VERIFIED via https://ethereum-magicians.org/t/frame-transaction/27617.json and posts.json, fetched 2026-09-30) and open PRs (github MCP search, 2026-09-30):

1. **Expiry `valid_after`** — PR #12252 open (see §5). Would add a not-before bound and change expiry calldata to 16 bytes. Not merged.
2. **Expiry verifier as deployed contract** — PR #12387 open (lightclient, 2026-09-28). Removes fork-time enshrinement; semantics same.
3. **Early rejection and payer revalidation** — PR #12321 open (sm-stack, 2026-09-11): check encoding/static constraints/prefix structure *before* signature verification; balance-only revalidation for shared payers; evict txs whose empty-code payer acquires code; forbid EIP-7702 delegation on the deploy frame's resolved target. Mempool-only.
4. **`MAX_VERIFY_GAS` as shared floor** — PR #12301 open (updated 2026-09-29). Mempool-only.
5. **Co-signer-funded value legs** — PR #12214 open (2026-08-20). Would change who can fund `value`.
6. **Sender-keyed authority read** — PR #12340 open (updated 2026-09-27).
7. **Paymaster admission by egress property** — PR #12328 open; **withdrawal delay pinned to reorg depth** — PR #12330 open; **canonical paymaster bytecode** — PR #12041 open.
8. **Opcode/frame-mode registry** — PR #12253 open (updated 2026-09-29).
9. **Signature-byte padding griefing of the payer** (thread #167 brettf, 2026-08-13; #168–#170 matt agrees "committing to the length is probably best we can do"): raw bytes of empty-`msg` `ARBITRARY` entries are elided from `compute_sig_hash` but billed as calldata, so a relay/builder can pad them and inflate `gas_used`. No PR merged yet; a fix would change `compute_sig_hash` (and hence what is "valid").
10. **"Guarantor"/fail-but-pay mode** (thread #166 alex-forshtat, 2026-08-05): request for a way to have "validation failed, state changes reverted, gas fee still paid" (cf. EIP-7906 POST_TX). Not in spec: today any VERIFY failure is invalid-and-unpaid. Directly relevant to the race question — a future change here could turn the same-nonce loser into "included-and-charged".
11. **Async-execution incompatibility** (thread #53 pdobacz, #54, #79 DanielVF): VERIFY frames must run against live state; proposals to fix `[Deploy] VERIFY [VERIFY]` at the head with a consensus gas cap. Thread notes Monad/Base/Tempo objections. Would make MAX_VERIFY_GAS-style limits consensus rather than policy.
12. **`TXPARAM(0x00)` halts outside frame txs** (thread #174 pdobacz, 2026-09-29): no in-EVM way to detect a frame tx except `ORIGIN == ENTRY_POINT` (only in VERIFY/DEFAULT); question whether to relax.
13. **State-gas reservation semantics inside a frame** (thread #172 aelowsson, #173 AnkushinDaniil): byte-denominated limits / unified `max_fee` per EIP-7999; contracts reserving gas by passing less gas behave differently under 8141 vs 8037 reservoir.
14. **Implicit cap of 2 VERIFY frames** (thread #135) — noted but not stated as a static constraint in the spec; a third VERIFY frame would necessarily fail to APPROVE and invalidate the tx (still true in current text: APPROVE reverts if scope already set, and a VERIFY frame that "exits without its required APPROVE" is only a mempool rule; at consensus a VERIFY frame that simply returns without APPROVE is fine).
15. **Keyed nonces** — EIP-8250, Draft, "Considered for Inclusion" (not scheduled) in Hegotá; would change the nonce field, the identity `(sender, nonce_keys, nonce_seq)`, and concurrent-inclusion semantics.

---

## 11. Sources (all fetched 2026-09-30)

- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md — full spec text (1472 lines); primary source for all quotes.
- https://eips.ethereum.org/EIPS/eip-8141 — rendered page; Status Draft confirmed.
- https://github.com/ethereum/EIPs/commits/master/EIPS/eip-8141.md — commit history (latest 5c0236f, 2026-09-29).
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8250.md — EIP-8250 Keyed Nonces (Draft, created 2026-04-16).
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8081.md — Hegotá meta EIP: 8141 Scheduled for Inclusion; 8250 Considered for Inclusion.
- https://ethereum-magicians.org/t/frame-transaction/27617 (+ `.json` and `/posts.json`) — discussion thread, 169 posts through 2026-09-29.
- https://github.com/ethereum/EIPs/pull/12252 — valid_after (open, draft).
- https://github.com/ethereum/EIPs/pull/12198 — expiry as mode (closed unmerged 2026-09-29).
- https://github.com/ethereum/EIPs/pull/12387 — deploy expiry verifier as standard contract (open, draft).
- https://github.com/ethereum/EIPs/pull/12321 — early rejection / payer revalidation (open).
- GitHub search (github MCP `search_pull_requests`, repo ethereum/EIPs, queries "8141 in:title is:open", "8141 expiry", "8141 is:merged") — list of open/merged PRs: open #12214, #12387, #12321, #12330, #12236, #12301, #12340, #12041, #12252, #12253, #12328, #12322; merged #12395, #12213, #12276, #12226, #12209, #12157, #12212, #12211, #12167, #12187, #12113, #12109, #12061, #12026, #12062, #12121, #12066, #12007, #12001, #12251 (EIP-8081 SFI).
- https://raw.githubusercontent.com/ethereum/execution-specs/master/src/ethereum/forks/osaka/fork.py — `check_transaction` raises `InvalidBlock` / `NonceMismatchError` for non-includable txs (general block-validity rule).
- Web search (secondary, not relied on for claims): ethdaily.io "Frame Transactions Hegotá Headliner"; used only to locate EIP-8081.

Unverified items are listed explicitly in §3 (block-invalidity inheritance not restated in 8141), §4 item 3 (deploy-then-approve nonce arithmetic is an inference from 8141 + 8250 text), and §5 (merge state of PR #12203).
