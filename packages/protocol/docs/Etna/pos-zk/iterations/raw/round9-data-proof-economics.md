# Round 9 — data path, proof soundness and economics: confirmation

**Reviewer angle.** Confirm the data path and economics end to end: the referenced-path `daMode` and the
statement-relative challenge index across DA-03/DA-07/DA-08/L1-05/PRF-02/PRF-07; the epoch freeze's
trigger, ascending cascade and first-claim backstop; the reservation release and the exact pool identity;
the fee-vault reconciliation (PRF-06 F1–F4); and D-8/D-9. Targets: `spec/04-l1-integration.html`,
`spec/05-proof-statement.html`, `spec/07-economics-slashing.html`, cross-checked against `spec/03`,
`spec/08`, `spec/09`, the index and `learn/`.

**Snapshot.** `3b4096a77` (branch `etna-pos-zk`); the working tree is at the same commit
(`git diff --stat 3b4096a77 HEAD` is empty), so the rules read are the frozen snapshot's.

**Method.** The specification is the authority; repair citations and closing notes are claims, not
evidence. The four D-16 deferrals are not reported as defects. Every charged item was re-derived from the
rule text rather than accepted from its closing note.

**Result: no findings. 0 Critical, 0 High, 0 Medium, 0 Low.** I attacked each charged item, including the
cases the round-8 repairs were introduced for, and found nothing that meets the finding bar. Two
dependencies I examined are disclosed Open items and are recorded below as explicit non-findings with
reasons. This is a clean report.

---

## 1. The referenced-path `daMode` and the challenge index are coherent and path-independent

**Rule chain.** L1-05 row 17 (carried: derived from the arguments and blobs the transaction carries;
referenced: "the mode is the referenced record's stored `daMode` … immutable L1 state the contract loads
after recomputing the record's identity from its own content — and the contract MUST use that value as the
statement's `daMode`, rejecting a submitter-supplied copy that differs with `DataModeMismatch`"), with the
table preamble naming row 17 as the single exception to the tx-derived rule and §2.1 row 17 repeating it;
PRF-02's journal comment ("derived from this tx; on the referenced path, read from the referenced record
and checked equal to the statement — L1-05 row 17, DA-08(1)"). L1-05 row 18 and §2.1 row 18 define
`challengeZ` "per blob, at its ordinal position `j` in the statement's bound ordered blob list", with
`z_i = H("TAIKO_ETNA_CHALLENGE", l2ChainId, statementCoreHash, dataCommitment, blobHashesHash, uint16(j))`;
DA-03's preamble defines `j = i − blobIndexStart` and says it "is the index the challenge transcript of
(iii) uses, on the carried and the referenced path alike"; DA-03(iii) states the same; DA-07(3) stores the
ordered versioned-hash list "in the statement's blob order, so a blob's ordinal position in that list — the
`j` of DA-03(iii) — is recoverable from the record alone … the publication transaction's absolute
`blobIndexStart` is not a statement input"; PRF-07(b)(ii) uses `uint16(j)` with the same recovery note.

**Why the same `z_i` results on both paths.** Row 24 fixes `blobHashesHash` as "keccak256 over the
ordered versioned hashes the statement binds: read with BLOBHASH for this transaction's blob range when the
transaction carries the blobs, or read from the referenced publication record when it does not", with the
carried-and-referenced path requiring element-wise agreement; DA-08(1) requires the record's
`blobHashesHash` to equal the journal's. So for one statement the ordered list is one object on both
paths, `j` is its position, and every input to the challenge — `l2ChainId`, `statementCoreHash`,
`dataCommitment`, `blobHashesHash`, `uint16(j)` — is statement-level or the ordinal. The precompile pairing
is the `j`-th list element on both paths (the transaction's blob at `blobIndexStart + j`, or the record's
`j`-th hash). Two records of the same data therefore derive the same challenges for the same statement.
I checked that no absolute index enters the transcript: `blobIndexStart` appears only in `LandInput`, in
DA-03(i)'s range check and in DA-03's definition `j = i − blobIndexStart`; the journal has no such field.

**Cases re-attacked.** Referenced landing of a BLOB record; carried landing with `blobIndexStart > 0`;
carried-and-referenced (both sources agree element-wise); two records of the same data; a record whose
stored order is the statement order. No divergence found.

## 2. The freeze trigger, cascade and backstop make `Alloc(e)`/`ProvingShare(e)` independent of caller timing

**Rule chain.** ECON-02(5)(d): "An epoch e becomes freezable exactly when `evidenceClose(e)` has passed and
MUST NOT be frozen before then; a call that would freeze it earlier MUST revert"; `freezeEpoch(uint64
epoch)` is permissionless; "every call that can change the pool's balance or fix a later epoch's amounts —
an inflow credit, a validator claim, a proving-share transfer, or the freeze of a later epoch — MUST first
execute the freeze of every freezable epoch not yet frozen, **in ascending epoch order**, before applying
its own effect"; (5)(c) makes the first claim execute the freeze as its first step; (5)(b) gates the
participation write at the close ("a set bit … whose `evidenceClose(e)` has already passed … MUST be
recorded in the epoch's late-participation record instead, which no freeze, no payout and no denominator
ever reads"); `reservedBefore(e)` is a stored running total captured at the freeze; 09:131/137–138
register the trigger, the cascade and the term owners.

**Timing-independence argument (re-derived).** Between e's close and e's freeze the free balance can change
only by an inflow credit, and every inflow credit must cascade first, so e freezes against the pre-inflow
balance — the free balance at its close. A later epoch cannot freeze first: the ascending cascade freezes
every freezable earlier epoch before a later freeze, and closes are monotone in e (`t_root(e)` increases
with e; `W_EVIDENCE` is one registered value), so nothing earlier is left unfrozen. A claim and a
proving-share transfer discharge a reservation against the same balance, so they leave `free` unchanged
and cannot dilute a pending epoch. Denial by inaction is impossible where a claim exists (any participant's
first claim executes the freeze; claims are permissionless and pay the owner), and where none exists no
allocation has been promised. The single exception is a forced credit (a direct ETH transfer), which can
only raise the balance; the rule discloses it as a donation that "raises every participant's allocation
alike and is never a dilution, a denial or a caller's capture" — a donor can only give value away, and by
definition cannot reduce any other epoch's amount.

**Cases re-attacked.** A donation before and after the close; an inflow arriving in the same block as a
claim; a proving-share transfer front-running claims (and the reverse); two closes passing during a
pool-touching drought (both freeze in the cascade, each on the unchanged balance, earlier first); an epoch
with an empty `P(e)`; a call for a not-yet-freezable epoch (reverts); a skipped epoch (no promise, then
frozen by the next pool-touching call). In each case the epoch's amounts are the close-time amounts and no
branch dilutes, inflates or denies them.

## 3. The reservation release is reachable and the identity is still exact

**Rule chain.** ECON-02(5)(a)/(5)(d): a claim reduces its epoch's outstanding by exactly the ETH paid;
"the claim that brings `claimedCount(e)` to `participantCount(e)` MUST, in the same call, release the
remaining `Alloc(e) − paid(e)` to the free balance"; an empty `P(e)` releases the whole allocation at the
freeze; the proving-share transfer reduces the un-transferred share to zero; "the epoch leaves
`reserved_before` when its outstanding amount reaches zero"; the staking contract "MUST maintain the live
reserved total as stored state … and MUST NOT compute `reserved_before(e)` or the decomposition view by
iterating the set of epochs"; 09:135–138 register the record and the derived terms.

**Exactness re-derived step by step.** Freeze: `outstanding(e) = Alloc + PS`, `free' = pool_before −
reserved_before − Alloc − PS ≥ 0` by the checked bound. Claim X: balance −X, outstanding(e) −X. Last claim:
balance −X, outstanding(e) −(X + R) where `R = Alloc − paid`, free +R. Proving-share transfer: balance
−PS, outstanding(e) −PS. Inflow: balance +Y, free +Y. Empty set: outstanding(e) = PS only, free +Alloc.
Every step preserves `pool_balance = free + Σ_e outstanding(e)` and therefore `balance ≥ Σ outstanding`, so
any discharge is payable in any order. The dust release makes the release event reachable
(`participantCount` counts the canonical signer indices of `P(e)`, each of which has a resolvable entry —
PRF-04(ii)'s bitmap has no bit outside the set — so every counted index can claim, including a zero-payout
claim, which is still a claim "paid"), and no unclaimed allotment is ever re-allocated. No double promise.

## 4. Fee-vault reconciliation (PRF-06 F1–F4), including the zero-balance no-op sweep

ECON-02(7)(b): the entry point requires exactly the canonical Bridge fee for a sweep that moves a non-zero
balance, and "a sweep when the outstanding recorded fee balance is zero is a no-op that MUST require
`msg.value == 0` and MUST revert on any nonzero amount, including the canonical fee". F3's exclusion of
"the Bridge fee a sweep caller supplies" therefore always has its premise ("credited and consumed inside
the same sweep call") true; a forced credit never enters `feeCredits` and is never swept;
`balance(h) − balance(h−1) == ΔfeeCredits + X(h) − V(h)` holds for the ordinary block, the sweep block
(before or after the block's own fee credits), the donation/forced-credit case and the zero-balance call
(nothing moves, no counter changes). Exact; round-7 R7-DPE-07 remains closed.

## 5. D-8 and D-9

D-8: one sweep, protocol-constructed, no destination argument, the Bridge fee additional and not a
deduction, credit only on bridge authentication, an empty pool pays nothing, a failed bridge stops rewards
without creating a receivable. D-9: every debited amount goes to the fixed treasury address with no burn,
the reporter bounty and keeper fee strictly bounded below the charge, self-reporting never profitable, and
the pool is never collateral, never stake, never slashable (INV-A–INV-D).

## 6. Absence disclosure and the tombstone sweep

I scanned all eleven specification pages for every tombstoned name (FI-10..FI-14 and the FI parameters,
`forcedBoundary`, PRF-15, L1-14, `familyBitmap`, `routeSetHash`, `K_SETTLE_BACKENDS`, `AGG_PROVER_PPM`,
`M_AGG_MAX`, `T_AGG_ROTATE_MAX`, MEM-13, CONS-16, the heartbeat names, GOV-04, REC-02..REC-04,
`resumeHeight`, `T_STALL_GOV`/`T_GOV_RESUME`) and read every hit that did not carry its own tombstone
marker on the same line. All are tombstones, MUST-NOT-USE register rows, "deferred by D-16" clauses or
deferral notes; spec/04, spec/05, spec/07, spec/09 and the index contain no live read. The course teaches
the v1 exit (withdrawal root of k distinct-family attestations, the funded proving market, retrievable
data) and no deferred mechanism in the present tense. CONS-12 states the generation-scoped safety
invariant and does not read the deferred stall-resolution rules.

## Considered and dismissed (not findings, with reasons)

1. **`t_observed(e)` remains an Open anchor (ECON-07(1)).** `evidenceClose(e)` is what the freeze, the
   claim gate and the participation cutoff read, and ECON-07 says "the commit-anchored close remains the
   only enforceable condition" until the production/landing anchor is fixed by a recorded decision before
   launch. The consequence (empty evidence intervals after a halt longer than `W_evidence`, and epochs
   whose heights are produced after their close) is disclosed there as "a defect, not a tuning choice — and
   it MUST be closed before launch", with INV-03's premise and the wedge scenario stated. This is a
   pre-existing, explicitly gated Open item, not a round-9 rule defect: the freeze mechanism consumes
   `evidenceClose(e)` exactly as ECON-07 owns it. Launch gate, not a finding.
2. **The cascade's gas bound after a long pool-touching drought.** If no pool-touching call occurs for many
   epochs, the first such call must freeze the whole backlog in one transaction, which could exceed the
   block gas limit. The backlog is permissionlessly drainable one epoch at a time through
   `freezeEpoch(e)`, the Bridge release stays retriable (MSG-02), and the state requires an economic
   drought (no inflows, claims, transfers or freezes) rather than an adversary. Worth an implementation
   note; not a defect in the rules, and it changes no amount (each epoch still freezes on its close-time
   balance).

## Implementability and build verdict

I would build on this specification. The data path is fully derivable from L1 state on both paths with one
transcript; the reward pool's allocation, reservation and release are exact, bounded in gas and independent
of caller ordering for every case I could construct; the fee vault is exact including the no-op sweep; and
D-8/D-9 are intact. What remains is what the specification itself marks as remaining: unmeasured parameter
values and the disclosed Open items (route and family inventory, the proving-market assumption of
MEM-15(2b) with its falsifier, the `t_observed` anchor, S1's cost measurements) — all launch gates rather
than rule defects.
