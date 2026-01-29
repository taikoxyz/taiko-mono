# Preconfirmation Lookahead (L1): Design, Flow, and Review

This document explains how Taiko’s L1 **preconfirmation lookahead** works, focusing on
`packages/protocol/contracts/layer1/preconf/impl/LookaheadStore.sol`, and how it composes with
the URC registry, slashing, and the L1 `Inbox`.

---

## 1. What problem the lookahead solves

Preconfirmation requires the protocol to decide **who is allowed to propose** (submit a Taiko L2
proposal to the L1 `Inbox`) at any given time, and to make that decision:

- **Ethereum-aligned**: eligibility is derived from the Ethereum beacon proposer schedule.
- **Economically secured**: eligible parties have collateral in the URC and can be slashed.
- **Efficient**: the schedule cannot be stored unbounded on-chain.

The “lookahead” is the mechanism that makes the future proposer schedule available and slashable,
without storing the full schedule in contract storage.

---

## 2. Terminology and actors

### Epochs and slots

The preconfirmation system reuses Ethereum consensus timing:

- `SECONDS_IN_SLOT = 12`
- `SECONDS_IN_EPOCH = 32 * 12 = 384`
- “Epoch timestamp” means the **start timestamp** of a beacon epoch.

`LibPreconfUtils.getEpochTimestamp()` derives the current epoch boundary from the chain’s beacon
genesis timestamp (per chain id).

### URC operators (opt-in preconfers)

An **operator** registers a set of BLS keys in the URC (`IRegistry`) and deposits collateral.
For each “slasher” contract, the operator opts in with an **ECDSA committer** address.

In this system:

- The **preconf committer** (URC slasher commitment for `preconfSlasher`) is the on-chain address
  allowed to call `Inbox.propose`.
- The **lookahead poster committer** (URC slasher commitment for `lookaheadSlasher`) is the key
  that authorizes (via signature) posting the lookahead commitment.

These may be the same address, but they do not have to be.

### Fallback preconfer (whitelist)

If there is no opted-in operator eligible for a window (or if the assigned operator is
blacklisted), the expected proposer becomes a **fallback preconfer** selected from
`PreconfWhitelist`. Whitelisted preconfers are _not_ URC-slashed by this system.

### Blacklist overseers

`LookaheadStore` inherits `Blacklist`, allowing a set of overseers to blacklist URC operators by
their `registrationRoot` for subjective faults. Blacklisting affects both:

- who is chosen as proposer (fallback instead of blacklisted operator), and
- who is considered eligible to appear in posted lookaheads.

---

## 3. Data model (what gets posted / stored)

### Lookahead slots (`ILookaheadStore.LookaheadSlot`)

A lookahead is an **array of sparse entries** (only slots with opted-in operators), where each
entry contains:

- `committer`: the operator’s **preconf committer** address (used as proposer identity)
- `timestamp`: the beacon slot timestamp (must be within the target epoch and aligned to 12s)
- `registrationRoot`: URC registration root of the operator
- `validatorLeafIndex`: which key (leaf) inside the operator registration corresponds to the slot

`validatorLeafIndex` exists to support later slashing evidence: it allows challengers to prove
that a specific beacon validator key was (or was not) correctly mapped to an operator.

### On-chain storage: only the hash

`LookaheadStore` keeps only a **hash** of the lookahead slots for an epoch:

- `bytes26 lookaheadHash` = `bytes26(keccak256(abi.encode(epochTimestamp, lookaheadSlots)))`
- stored in a ring buffer mapping `epochTimestamp % lookaheadBufferSize => LookaheadHash`

The `LookaheadHash` struct packs `uint48 epochTimestamp + bytes26 hash` into one storage slot.
The full `lookaheadSlots` array is emitted in `LookaheadPosted` and is provided as calldata later
by proposers and slashers.

---

## 4. Proposer selection: “submission windows” and sparse schedules

`LookaheadStore` does _not_ assign one proposer per slot. Instead, each opted-in operator’s beacon
slot timestamp acts as a **deadline** for that operator’s entire preconfirmation/proposal window.

Windows are computed as:

- For the `i`-th entry in `currLookahead`:
  - `windowEnd = currLookahead[i].timestamp`
  - `windowStart = (i == 0) ? (epochStart - 1 slot) : currLookahead[i - 1].timestamp`
- The proposer is the entry’s `committer`, unless that operator is currently blacklisted (then
  fallback).

This design intentionally assigns “empty” beacon slots (slots where no opted-in operator exists)
to the **next** opted-in operator, allowing _advance proposals_:

Example (same epoch):

```
[ x  x  x  Pa  y  y  y  Pb  z  z  z ]
          ^               ^
        slot(Pa)        slot(Pb)
```

- `Pa` may propose during `x` (advance), deadline `slot(Pa)`
- `Pb` may propose during `y` (advance), deadline `slot(Pb)`

### Cross-epoch advance proposals

When the current epoch’s lookahead has ended (no more opted-in operators in the epoch), the first
opted-in operator of the **next** epoch may propose “in advance” during the tail of the current
epoch, using the same window logic:

```
curr epoch: [ ...  Pa   y  y  y ]
next epoch: [  z  z  z  Pb  v  v  v ]
                      ^
                   slot(Pb)
```

If the next epoch has no lookahead entries, the tail is handled by the fallback preconfer.

### Fully empty lookahead

If there is no stored lookahead for the current epoch (or it is explicitly empty), the proposer
is always the fallback preconfer for the current epoch.

---

## 5. How `Inbox.propose` uses the lookahead

`Inbox.propose(bytes _lookahead, bytes _data)` forwards `_lookahead` to the configured proposer
checker:

- If the chain is in a permissionless mode (forced inclusion delay exceeded), `Inbox` bypasses
  proposer checking.
- Otherwise, it calls `IProposerChecker.checkProposer(msg.sender, _lookahead)` and stores the
  returned `endOfSubmissionWindowTimestamp` into the proposal.

When preconfirmation is enabled, the proposer checker is `LookaheadStore`.

---

## 6. The `LookaheadData` payload (what the proposer must provide)

`LookaheadStore.checkProposer` expects `_lookaheadData` to decode as:

- `slotIndex`: index into `currLookahead` identifying the proposer’s slot entry, or
  `type(uint256).max` if the proposer is from the next epoch (cross-epoch case).
- `currLookahead`: the current epoch’s lookahead slots (must match stored hash).
- `nextLookahead`: the next epoch’s lookahead slots (required in certain cases; see below).
- `registrationRoot`: URC registration root of the _lookahead poster_ (only used when posting).
- `commitmentSignature`: signature authorizing the lookahead commitment for posting; must be empty
  for whitelisted fallback preconfers.

`currLookahead` is always used for validation, but `nextLookahead` is intentionally optional for
the common case to save gas.

**Blacklist snapshot note**

The interface (`ILookaheadStore.LookaheadData`) specifies that `nextLookahead` must take into
account blacklist status as of _one slot before the current epoch start_. This is a protocol-level
detail: the on-chain blacklist does not store full historical state, so the system needs a stable
snapshot point to keep lookahead posting and slashing rules deterministic.

---

## 7. `LookaheadStore.checkProposer`: full on-chain flow

At a high level, `checkProposer` does four things:

1. **Derive expected proposer + window** from the provided lookahead arrays and current epoch.
2. **Verify** `msg.sender` (the proposer) matches the expected proposer and is within the window.
3. **Validate** that the provided `currLookahead` matches the stored hash for the current epoch.
4. **Ensure the next epoch lookahead exists**:
   - If it already exists, optionally validate `nextLookahead` (cross-epoch/fallback only).
   - If it does not exist, post it (subject to who is proposing and whether a signature is
     provided), **except in the first slot of the epoch**, where posting is explicitly skipped to
     allow the off-chain builder time to construct the lookahead.

### When is `nextLookahead` required?

`nextLookahead` must be provided when:

- the proposer is **cross-epoch** (`slotIndex == type(uint256).max`) because the proposer window
  depends on the first entry of `nextLookahead`, and/or
- the proposer is the **fallback preconfer** and needs to post/validate the next epoch lookahead.

If `nextLookahead` is already stored and the proposer is a normal same-epoch opted-in operator,
`nextLookahead` can be empty as a gas optimization.

**Slot‑0 exemption**

In the first slot of the epoch (i.e., when `block.timestamp == epochStart`), the contract does
**not** require the next‑epoch lookahead to be posted. This avoids reverting proposals when the
off‑chain builder hasn’t yet produced the lookahead.

---

## 8. How a lookahead is posted (and what is validated)

Lookaheads are posted only via `checkProposer` when the next epoch entry is missing.

### 8.0 Off-chain lookahead construction (overview)

The contract does not compute the lookahead on-chain. Instead, an off-chain builder constructs the
`LookaheadSlot[]` for a target epoch by:

1. Deriving the target epoch start timestamp (an epoch boundary).
2. Reading the **beacon proposer lookahead** for that epoch (from consensus data). On-chain
   challenges later prove correctness against EIP-4788 beacon block roots (see `LibEIP4788` and
   `LookaheadSlasher`).
3. For each beacon slot in the target epoch, mapping the beacon proposer validator to a URC
   operator (if the validator belongs to any URC registration root) and filtering to operators
   that meet:
   - URC opt-in + collateral requirements at the reference time, and
   - blacklist policy.
4. Emitting a sparse array: only slots with eligible operators are included; empty slots are
   represented implicitly by the gaps between entries.

The produced array is then:

- hashed and stored by `LookaheadStore` (only the hash is kept in storage), and
- used as the commitment payload for slashing (so challengers can prove omissions or incorrect
  mappings).

### 8.1 Slot formatting rules

In `_updateLookahead`, each entry must satisfy:

- strictly increasing timestamps
- timestamps aligned to 12 seconds relative to the epoch start:
  `(_slotTimestamp - epochTimestamp) % 12 == 0`
- timestamps within the epoch (`epochTimestamp <= ts < epochTimestamp + 384`)

### 8.2 Operator validity rules (URC + protocol policy)

For each `LookaheadSlot.registrationRoot`, `_validateLookaheadOperator` enforces:

- operator registered **before** the reference timestamp
- operator not unregistered / slashed as of the reference timestamp
- operator had sufficient historical collateral at the reference timestamp
- operator opted in to the `preconfSlasher` **before** the reference timestamp and not opted out
- operator passes lookahead-specific blacklist eligibility checks

Additionally, it checks:

- `validatorLeafIndex < operatorData.numKeys`
- `LookaheadSlot.committer` matches the URC slasher commitment committer for `preconfSlasher`

### 8.3 Poster authorization (signature vs fallback)

If the next lookahead is posted by a URC operator:

- the poster must provide a `commitmentSignature`
- the signature is verified against the operator’s URC slasher commitment for `lookaheadSlasher`
  (using `ECDSA.recover(keccak256(abi.encode(commitment)), signature)`).

If the next lookahead is posted by the fallback preconfer:

- `commitmentSignature` must be empty
- no URC signature / slashing attribution is enforced.

---

## 9. How slashing ties in (security backstop)

Because `LookaheadStore` stores only a hash, correctness of the posted lookahead is enforced via
**slashing challenges**, not by the store itself.

- The lookahead commitment payload is the ABI encoding of the `LookaheadSlot[]`.
- `LookaheadSlasher` verifies the commitment corresponds to the stored lookahead hash for the
  epoch, then compares “preconf lookahead” vs “beacon lookahead” using EIP-4788 beacon roots and
  URC registration proofs.
- `UnifiedSlasher` is the URC entrypoint that routes lookahead vs preconf slashing by
  `commitmentType`.

This means the on-chain store enforces _format and URC eligibility_, while challengers enforce
_completeness and correctness_ (e.g., “missing operator” or “wrong operator for slot”).

---

## 10. Review: is it properly implemented? security issues / logic bugs?

This section focuses on `LookaheadStore.sol` correctness and how it impacts protocol security and
liveness.

### 10.1 First-slot behavior: explicitly skip posting next lookahead

The contract intentionally **skips posting** the next-epoch lookahead in the first slot of the
current epoch, because the off-chain builder may not have the lookahead ready yet. This is handled
by checking `isLookaheadRequired()` and **early‑returning** in `_handleNextEpochLookahead` when the
next lookahead is missing and slot‑0 exemption applies.

### 10.2 Likely bug: blacklist eligibility check can treat some blacklisted operators as valid

In `_validateLookaheadOperator`, blacklist eligibility is currently:

- allow if `blacklistedAt == 0 || blacklistedAt > referenceTimestamp`
- OR allow if `unBlacklistedAt != 0 && unBlacklistedAt < referenceTimestamp`

The second condition does **not** ensure that `unBlacklistedAt` is the most recent blacklist
transition (i.e., that the operator is unblacklisted as of the reference time).

A plausible timeline:

1. operator is blacklisted at `t1`
2. operator is unblacklisted at `t2` (so `unBlacklistedAt = t2`)
3. operator is blacklisted again at `t3` (so `blacklistedAt = t3`, and the operator is currently blacklisted)
4. `t3 < referenceTimestamp` and `t2 < referenceTimestamp`

Under the current logic:

- `blacklistedAt > referenceTimestamp` is false, but
- `unBlacklistedAt < referenceTimestamp` is true,

so the operator is treated as eligible, despite being blacklisted before the reference timestamp.

**Impact**

- Can distort which operators are accepted into posted lookaheads.
- Can distort “operator validity” checks that are reused by the slashing path (`isLookaheadOperatorValid`),
  potentially making posters slashable for “missing” an operator that should have been excluded,
  or allowing inclusion of operators that should be excluded.

**Suggested fix (high-level)**

- Define eligibility in terms of the operator’s blacklist state _at the reference timestamp_,
  which requires comparing `blacklistedAt` and `unBlacklistedAt` (not only checking that
  `unBlacklistedAt` is old enough).

### 10.3 Not a bug, but an explicit trust assumption: fallback lookahead posting is not slashable

If the fallback preconfer posts a next epoch lookahead (no signature), the lookahead is not
attributed to a URC-committer signature and therefore is not directly slashable via the URC
lookahead slashing flow.

**Impact**

- Correctness of lookahead posting is economically enforced only for URC operators; fallback
  correctness is governance/whitelist-trust based.

### 10.4 Minor: `getProposerContext` is “current-chain-time” dependent

`getProposerContext` calls `_determineProposerContext`, which, when falling back, calls
`PreconfWhitelist.getOperatorForCurrentEpoch()` (derived from `block.timestamp`), not from the
provided `_epochTimestamp`. This is fine for “what would happen now?”, but the interface comment
could be read as “query arbitrary epoch”.

### 10.5 Hardening consideration: lookahead poster signature format is not domain-separated

Lookahead posting validates a signature via:

- `ECDSA.recover(keccak256(abi.encode(commitment)), signature)`

This is a “raw” ECDSA signature over an ABI-encoded struct. It can be acceptable if the committer
key is dedicated to this protocol, but it is not EIP-191/EIP-712 domain separated (e.g., chain id,
contract address, epoch).

**Impact**

- Not an immediate on-chain vulnerability by itself, but it increases the blast radius of key
  reuse and makes signatures less self-describing for off-chain tooling.

**Possible improvement**

- Switch to EIP-712 typed data with an explicit domain (including chain id and a verifying
  contract), or use an agreed EIP-191 prefixing scheme consistently across the protocol.

---

## 11. Opportunities for gas optimization (while staying readable)

These are micro-optimizations; the dominant costs are calldata decoding, URC reads, and signature
verification.

1. **Reduce repeated `getLookaheadStoreConfig()` calls** by caching the returned struct (or the
   specific fields) in local variables within functions that call it multiple times.
2. **Single-slot write for `LookaheadHash`**: `_setLookaheadHash` writes two packed fields
   separately. Assigning the full struct in one statement can avoid an extra read-modify-write of
   the packed slot.
3. **Avoid unnecessary next-epoch work**: same-epoch proposers already early-return when the next
   lookahead exists. The same “skip work” pattern can be applied to the “not required” window to
   avoid wasted gas and avoid liveness issues.

---

## 12. Opportunities to improve code quality and readability

1. **Clarify naming for reference timestamps**: variables like `prevEpochTimestamp` in
   `_validateLookaheadOperator` are easy to misread; consider renaming to `referenceTimestamp` or
   `eligibilityTimestamp`.
2. **Consolidate / remove unused custom errors** in `LookaheadStore.sol` (several `Poster*` and
   `SlasherIsNot*` errors are declared but never used).
3. **Document the interval convention** explicitly once (windows are `(start, end]`) and reference
   it, since off-by-one behavior is intentional and security relevant.
4. **Make the “slotIndex sentinel” explicit** (e.g., a named constant) to reduce cognitive load
   and prevent mistakes in off-chain encoders.
