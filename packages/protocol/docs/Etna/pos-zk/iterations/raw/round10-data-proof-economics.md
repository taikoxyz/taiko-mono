# Round 10 — data path and economics after the residue: confirmation

**Reviewer angle.** Re-derive the five charged items from the rule text after the round-9 residue:
(1) the referenced-path `daMode` and the statement-relative challenge index; (2) freeze timing
independence under the **new bounded cascade** (`FREEZE_MAX`, bounded-prefix return,
`ceil(p/FREEZE_MAX)` resumable drain, inflow full-set-or-revert, first-claim backstop), including a
drought longer than `FREEZE_MAX` epochs; (3) the reservation release and the exact identity
`balance = free + Σ outstanding` through the bounded form; (4) fee-vault F1–F4 exactness; (5) D-8/D-9.
Targets: `spec/04-l1-integration.html`, `spec/05-proof-statement.html`,
`spec/07-economics-slashing.html`, cross-checked against `spec/02`, `spec/08`, `spec/09`, the index and
`learn/`.

**Snapshot.** `cd8386c2c`; the working tree is `9b6dbdc72`, whose only delta from the snapshot is
`iterations/10-freeze.md` (`git diff --stat cd8386c2c HEAD`), so the rules read are the frozen
snapshot's.

**Method.** Every charged item was re-derived from the rules rather than accepted from its closing
note. The four D-16 deferrals are not reported as defects; their absence and the tombstone sweep were
re-checked.

**Result: no findings. 0 Critical, 0 High, 0 Medium, 0 Low. I found nothing.** The round-9 residue is
real, it is confined to the places claimed, and I could not construct a new defect in the bounded
cascade or in any of the other four items. Details of the re-derivations and the edge cases I attacked
are below, followed by the two items I examined and dismissed with reasons.

---

## 1. The bounded cascade preserves timing independence (the new residue)

**Rule chain.** ECON-02(5)(d): an epoch becomes freezable exactly when `evidenceClose(e)` has passed and
MUST NOT be frozen earlier; `freezeEpoch(uint64 epoch)` is permissionless; "every call that can change
the pool's balance or fix a later epoch's amounts — an inflow credit, a validator claim, a proving-share
transfer, or the freeze of a later epoch — MUST first execute the pending epochs' freezes **in ascending
epoch order, starting from the earliest**, and MUST freeze at most `FREEZE_MAX` epochs in one call";
a call may freeze that bounded prefix and return, MUST NOT freeze out of order or skip; a call whose own
effect needs an epoch frozen "MUST apply that effect only if the epoch is inside the prefix the call can
freeze, and MUST otherwise revert with no effect"; an inflow credit "MUST NOT credit it while any pending
epoch remains: it freezes the whole pending set when that set holds at most `FREEZE_MAX` epochs, and
otherwise the authenticated message MUST revert and stay retriable under MSG-02". The resume path:
`freezeEpoch(e)` freezes the pending epochs from the earliest through `e` and reverts if `e` is not
freezable or already frozen, or if the pending epochs up to and including `e` outnumber `FREEZE_MAX`;
a backlog of `p` drains in `ceil(p/FREEZE_MAX)` calls. `FREEZE_MAX ≥ 1` is stated in the rule,
registered in 09 (line 1244, unmeasured, derivation: measured cost of one freeze at the deployed record
layout over the block gas limit) and in the index parameter map (line 553); the PARAM-03 row is 07:1196.
ECON-02(5)(c) states the first-claim backstop in the same bounded form: the claim executes the cascade as
its first step and MUST NOT pay unless its epoch is frozen at the end of it, otherwise reverting with no
effect.

**Why the close-time-amount property survives the bound.** Only an inflow changes `free`; a claim and a
proving-share transfer discharge a reservation against the same balance, so `free` is unchanged by them.
An inflow can credit only when no epoch is pending, because otherwise the credit call freezes the whole
pending set first (when `p ≤ FREEZE_MAX`) or reverts. Therefore, while an epoch `e` is pending, no
inflow can have credited since `e`'s close (any such credit would have had to freeze `e` first, or
revert), so `e` freezes on the balance it had at `evidenceClose(e)`. The prefix always begins at the
earliest pending epoch and skips nothing, and closes are monotone in `e`, so when `e` freezes every
earlier freezable epoch has already frozen in the same or an earlier call: `reserved_before(e)` is
complete and no later freeze can dilute `e`. The bounded prefix changes only *when* freezes execute, not
*what* they fix; `frozenAt` is the execution time, and the amounts are the close-time amounts.

**Drought longer than `FREEZE_MAX` epochs (attacked explicitly).** With `p > FREEZE_MAX`:
- an inflow credit reverts and stays retriable under MSG-02; no ETH is lost and no arrival is counted by
  an epoch whose close precedes it;
- a claim or transfer for an epoch beyond the call's prefix reverts with no effect — in particular no
  payment is ever made from an unfrozen allocation (5)(c);
- any address can advance the frontier with bounded `freezeEpoch` calls, each freezing at most
  `FREEZE_MAX` earliest pending epochs; a claimant whose epoch is far back in the backlog drains the
  chunks ahead of it, and its own payout is the incentive;
- nothing is stranded by a rule gap: the earliest pending epoch is freezable by definition, the prefix is
  non-empty whenever `p ≥ 1`, and the drain is finite (`ceil(p/FREEZE_MAX)`).
A griefer cannot create the backlog (it grows only as closes pass) and cannot prevent the drain (the
calls are permissionless and each strictly reduces the backlog); the state requires an economic drought
with no pool-touching call at all, and the recovery is bounded and permissionless. This is the disclosed,
recoverable behaviour the residue introduced, not a defect.

**Other edge cases re-attacked.** `p = 0` (a credit passes straight through); `p = 1` and
`p = FREEZE_MAX` (the credit freezes the whole set then credits); `p = FREEZE_MAX + 1` (reverts until
one call drains); a claim inside the prefix and a claim outside it; a transfer inside and outside; drains
interleaved with claims and inflows; an empty-`P(e)` epoch frozen mid-prefix (its allocation release
raises later epochs' base — but the cascade order is fixed, so this is a function of L1 state, not of any
caller's timing); a forced credit (a direct transfer with no cascade) — increase-only, disclosed as a
donation that cannot dilute, deny or be captured. In every case the amounts are the close-time amounts
and the identity below still holds.

## 2. Referenced-path `daMode` and the statement-relative challenge index (unchanged, still coherent)

L1-05 row 17 (carried: derived from the transaction's arguments/blobs; referenced: the record's stored
`daMode`, loaded after the identity recomputation and used as the statement's mode, a differing
submitter copy reverting `DataModeMismatch`), with the table preamble naming row 17 as the one exception;
PRF-02's journal comment ("derived from this tx; on the referenced path, read from the referenced record
and checked equal to the statement"); row 18 and §2.1 row 18 (`z_i = H("TAIKO_ETNA_CHALLENGE", l2ChainId,
statementCoreHash, dataCommitment, blobHashesHash, uint16(j))`, "at its ordinal position `j` in the
statement's bound ordered blob list"); DA-03's preamble and (iii) (`j = i − blobIndexStart`, used "on the
carried and the referenced path alike"); DA-07(3) (the record stores the list in statement order, so `j`
is recoverable from the record alone and the publication transaction's absolute index is not a statement
input); PRF-07(b)(ii) (`uint16(j)`, same recovery note); row 24 with DA-08(1) (the ordered list is one
object on both paths for one statement, element-wise agreement on the carried-and-referenced path). Since
every challenge input is statement-level or the ordinal, the two paths derive the same `z_i`, and two
records of the same data derive the same challenges. No absolute blob index appears in the transcript.

## 3. Reservation release and the exact identity through the bounded form

The release rule and the running total are untouched by the residue: the claim that brings
`claimedCount(e)` to `participantCount(e)` releases the remaining `Alloc(e) − paid(e)` in the same
call; an empty `P(e)` releases the whole allocation at the freeze; the proving-share transfer zeroes the
un-transferred share; the staking contract maintains the live reserved total as stored state and MUST NOT
compute `reserved_before(e)` or the decomposition view by iterating epochs. Re-derived step by step:
freeze (`outstanding(e) = Alloc + PS`, `free` down by both, bound checked); claim (`balance −X`,
`outstanding −X`); last claim (`balance −X`, `outstanding −(X+R)`, `free +R`); proving-share
transfer (`balance −PS`, `outstanding −PS`); inflow (`balance +Y`, `free +Y`); empty-set release
(`outstanding = PS`, `free +Alloc`). Every step preserves `balance = free + Σ outstanding`, hence
`balance ≥ Σ outstanding`, so any discharge is payable in any order. The bounded cascade does not enter the
identity at all: it only schedules when a reservation is created, and a reservation is created only
against `free_before(e)` at that freeze.

## 4. Fee-vault reconciliation (PRF-06 F1–F4)

ECON-02(7)(b) is untouched by the residue: a sweep that moves a non-zero balance requires exactly the
canonical Bridge fee; a zero-outstanding-balance call "is a no-op that MUST require `msg.value == 0` and
MUST revert on any nonzero amount". F3's exclusion of the sweep-supplied Bridge fee therefore always has
its premise (credited and consumed in the same call) true; a forced credit never enters `feeCredits` and
is never swept; `balance(h) − balance(h−1) == ΔfeeCredits + X(h) − V(h)` holds for the ordinary block, the
sweep block before or after the block's own fee credits, a donation/forced credit, and the zero-balance
call (nothing moves, no counter changes). Exact.

## 5. D-8 and D-9

D-8: one sweep, protocol-constructed with no destination argument, the Bridge fee additional and never a
deduction, credit only on bridge authentication, an empty pool pays nothing, a failed bridge stops rewards
without creating a receivable. D-9: every debited amount goes to the fixed treasury address with no burn,
the reporter bounty and the keeper fee strictly below the charge (self-reporting never profitable), and the
pool remains never collateral, never slashable (INV-A–INV-D). Untouched by the residue.

## 6. Residue scope and consistency checks

- `git diff 3b4096a77 cd8386c2c`: `spec/05` is untouched; `spec/04` changes only the attestation-race
  disclosure (L1-11) and the exit-dependency wording (MSG-03); `spec/07` changes only ECON-02(5)(c)/(d)
  (the bounded cascade and the bounded backstop) and the two `FREEZE_MAX` register rows; `spec/02`,
  `spec/08`, `spec/09`, the index and one course page carry the other residue items.
- **CONS-05's certificate tuple now carries `recovery_generation`** (02:41, 178, and `cert_hash` at
  02:344 covers it). This is additive for my pages: L1-05 row 15's `finalityCommitment` preimage (round,
  bitmap hash, signature-set hash) is unchanged and does not claim to cover the whole tuple, and PRF-04(vii)
  recomputes exactly that preimage while PRF-04(viii) binds the generation three ways (journal, every
  contributing signed vote, the signed head header). No contradiction found.
- Tombstone sweep over all eleven pages for every deferred name (FI-10..FI-14 and the FI parameters,
  `forcedBoundary`, PRF-15, L1-14, `familyBitmap`, `routeSetHash`, `K_SETTLE_BACKENDS`,
  `AGG_PROVER_PPM`, `M_AGG_MAX`, `T_AGG_ROTATE_MAX`, MEM-13, CONS-16, the heartbeat names, GOV-04,
  REC-02..REC-04, `resumeHeight`, `T_STALL_GOV`/`T_GOV_RESUME`): spec/04, spec/05 and the index have no
  live reference; the four flagged hits in spec/07 are inside the ECON-04(6) and ECON-13(3) tombstone
  clauses. `FREEZE_MAX` is registered in 09 and the index map.

## Considered and dismissed (not findings, with reasons)

1. **`t_observed(e)` remains an Open anchor (ECON-07(1)).** Unchanged from round 9: the freeze, the
   claim gate and the participation cutoff read `evidenceClose(e)`, ECON-07 states that "the
   commit-anchored close remains the only enforceable condition" until the production/landing anchor is
   fixed by a recorded decision before launch, and the empty-interval consequence (with INV-03's premise
   void and the wedge scenario) is stated there as "a defect, not a tuning choice — and it MUST be closed
   before launch". A disclosed, explicitly gated Open item the residue neither created nor worsened;
   launch gate, not a rule defect.
2. **The bounded cascade's revert-until-drained behaviour in a long drought.** Inflows revert retriable and
   far-back claims/transfers revert with no effect while `p > FREEZE_MAX`; every path resumes after at
   most `ceil(p/FREEZE_MAX)` permissionless `freezeEpoch` calls, no amount changes, no ETH is lost, and
   the backlog can only grow when no pool-touching call occurs at all. Worth an implementation note (the
   drain is a real operational duty for whoever wants to claim or to see an inflow credited); not a
   defect.

## Build verdict

**Clean round: I found nothing, and I would build on this specification as written.** The round-9 residue
is real and confined: the bounded cascade preserves the close-time-amount property in every case I could
construct, including a drought longer than `FREEZE_MAX`; the referenced-path derivations, the reservation
release, the pool identity, the fee vault and D-8/D-9 are unchanged and still exact; the tombstone sweep is
clean; and the CONS-05 tuple change is additive. What remains is what the specification itself marks as
remaining: unmeasured values (including `FREEZE_MAX`) and the disclosed Open items (route/family
inventory, the MEM-15(2b) proving-market assumption with its falsifier, the `t_observed` anchor, S1's
cost measurements) — launch gates rather than rule defects.
