# Round 5T — proof soundness, data binding and economics under D-11/D-13

**Reviewer angle:** proof soundness, data binding and economics under D-11 (data-first publication) and
D-13 (one proof object = n-of-m aggregation). Target pages: `spec/04-l1-integration.html`,
`spec/05-proof-statement.html`, `spec/07-economics-slashing.html`; cross-checked against
`spec/01-system-model.html` (SYS-02), `spec/02-consensus.html` (CONS-01(v)), `spec/06-recovery-exceptions.html`
(REC-02), `spec/08-migration-upgrades.html` (MIG-02), `spec/09-parameters.html`.

**Snapshot:** 7759eb269, branch `etna-pos-zk`. **Method:** the specification is the authority; every claim
below is quoted from a registered rule or a page's normative text; in-text notes and pills are treated as
claims, not evidence.

**Fault-model key used for the verdicts.** Inside = reachable by any account inside the stated assumptions
(A-CONS-1 < 1/3 Byzantine stake, A-CONS-2, A-CONS-5, A-DA-2, A-L1-1, A-GOV-1, A-CRYPTO-3) without a
cryptographic break, a malicious governance action, or an implementation bug (F1/F2/F3 of
`spec/01-system-model.html` §Assumptions, lines 653–668). Outside = needs ≥ 1/3 Byzantine stake, a zkVM
soundness break, malicious governance, a key compromise or a code bug.

**Counts: 1 Critical, 5 High, 5 Medium, 2 Low.** Six findings are reachable inside the fault model
(`R5T-PDE-01`, `-02`, `-03`, `-05`, `-09`, and `-07` as a delay); the rest are rule/config defects that need
no assumption failure to exist, and two (`-04`'s exploitable horn, `-13`) need a stall, ≥1/3 or a bad upgrade.

---

## R5T-PDE-01 — Critical — the per-batch work cap counts *records*, while the obligation requires *every transaction a record carries*; one permissionless publication can make every batch non-compliant and halt the chain.

**Rule / missing rule.** `spec/04` **FI-12** fixes the cap as
`cap(batch) = min(FI_MAX_PER_BATCH, floor(batchGasCapacity / FI_RECORD_GAS_MAX))` and the
registered relation (FI-12, `spec/09` row "FI capacity relation") as
`FI_MAX_PER_BATCH × FI_RECORD_GAS_MAX ≤ MAX_BATCH_BLOCKS × L2_BLOCK_GAS_LIMIT`, i.e. it accounts
**one per-transaction gas bound per record**. But **FI-11(4)** requires the batch's execution to contain
"each required record's **transactions**, each at most once and in sequence order", and **PRF-04(vi)**
(`spec/05`) restates the same plural obligation. The forced-data record is the D-11 **publication record**
(FI-10: "The forced-data record *is* the publication record of DA-07"), whose published byte string is
"a batch's data — the whole committed byte string of PRF-07(0)" (**DA-07(1)**), i.e. the ordered frames
`be32(len(body_h)) || body_h` of a whole L2 block range (**PRF-07(0)**) — a container of arbitrarily many
transactions. `spec/09` registers `FI_ITEM_MAX_BYTES` as exactly that record byte string and requires it to
"leave room in the blob-quantisation bound for at least one item plus the batch's own blocks". **FI-13**
makes one transaction per-record notion explicit ("**A record's transaction** is *includable* … its gas limit
… does not exceed `FI_RECORD_GAS_MAX`") without ever bounding the number of transactions in a record.
**Missing rule:** the cap and the capacity relation must be stated over the **total gas of all transactions a
record carries**, or a forced-data record must be defined to carry exactly one transaction (and DA-07's
publication record accordingly re-scoped).

**Assumptions.** Permissionless publication (DA-07(1)); FI-12 claim (ii) that "a compliant batch always
exists"; L2 block gas limit `L2_BLOCK_GAS_LIMIT`.

**Attack trace.**
1. Attacker publishes one record (one permissionless type-3 transaction, DA-07) whose payload decodes under
   the PRF-07(0) framing to `k` transactions — e.g. `k = FI_MAX_PER_BATCH + 1` minimal signed transfers,
   from its own funded accounts, nonces in order, each with gas limit `G` at or just below
   `FI_RECORD_GAS_MAX` (per FI-13 each is individually includable in any block whose gas limit ≥ `G`).
2. The record becomes due after `FI_INCLUSION_DELAY` (FI-10) and enters the required FIFO prefix.
3. Every compliant batch must contain all `k` transactions (FI-11(4)/PRF-04(vi)); it cannot void any of
   them, because each is includable (FI-13 admits no other ground).
4. But `k × G > FI_MAX_PER_BATCH × FI_RECORD_GAS_MAX ≥` the batch's total gas capacity allowed by
   `MAX_BATCH_BLOCKS × L2_BLOCK_GAS_LIMIT`; no batch of at most `MAX_BATCH_BLOCKS` blocks can hold them.
5. No valid batch exists ⇒ acceptance stops ⇒ the chain halts with no rule to recover (a record cannot be
   voided on capacity grounds; FI-13's void requires *non-includability*, which is per-transaction and per-block).
   With `FI_MAX_PER_BATCH = 1` and `G` near the registered bound, **two** transactions suffice.

**Inside/outside the fault model.** **Inside.** Any account; no stake, no validator role, no assumption has to
fail. This is the round-1 critical class that **D-12** says "must not return", arriving through record *content*
rather than record *count*.

**Attacker resources and cost.** One L1 type-3 transaction (blob fee + gas, orders of magnitude below any
bond) plus `k` funded L2 accounts holding only enough ETH to satisfy FI-13's balance condition. No bond, no
TAIKO, no persistent infrastructure.

**Requirement / decision affected.** D-12 ("Inclusion is a capped FIFO prefix of the due set, so a backlog
drains over successive batches instead of halting the chain — the failure mode that produced review round 1's
critical finding … must not return"); R6 (conditional liveness with exact end conditions); R10 in its narrowed
form; FI-12 claims (1)–(2) and the named falsifier F-FI-1, which does not cover record content.

**Evidence.** `spec/04-l1-integration.html` FI-10 (record = DA-07 publication record), FI-11(4), FI-12, FI-13;
`spec/05-proof-statement.html` PRF-04(vi), PRF-07(0); `spec/09-parameters.html` rows `FI_ITEM_MAX_BYTES`,
`FI_RECORD_GAS_MAX`, `FI_MAX_PER_BATCH`, FI capacity relation.

---

## R5T-PDE-02 — High — the referenced path's versioned hashes are never required to equal the publication transaction's `BLOBHASH` values; the availability premise (6) of the D-11 binding argument is asserted, not checked.

**Rule / missing rule.** **DA-07(2)** says a publication writes "the blob range's ordered versioned hashes
**read with BLOBHASH in that transaction**", but the only enforced check in **DA-07(5)** is
"the Inbox MUST require `blobhash(i) != 0` for every index in it" — no element-wise equality — and the
normative interface sketch **L1-08** declares
`publish(..., bytes32[] calldata _blobVersionedHashes)`, i.e. the hashes are an ABI argument the
implementation may simply store. Contrast the carried landing path, which does state the equality:
**DA-03(i)** `require(vh != 0 && vh == _input.blobVersionedHashes[i - blobIndexStart], BlobHashMismatch(i))`.
**Missing rule:** `publish` MUST require `_blobVersionedHashes[i] == blobhash(_blobIndexStart + i)`
element-wise (or MUST read them with `BLOBHASH` and ignore the argument).

**Assumptions.** DA-03/DA-08's referenced binding is sound **given premise (6)**: "the publication record of
DA-07 is immutable, its identity is recomputed by the Inbox from its stored content, and its recorded versioned
hashes are **the ones consensus checked against the published blob sidecars**" (DA-03, Premises). This finding
is that (6) is not established by any check.

**Attack trace.**
1. Publisher commits off-chain to a polynomial `P` (its payload), obtains `C = commit(P)` and
   `V = kzg_to_versioned_hash(C)`.
2. Publisher calls `publish(range, daMode, dataCommitment = f(keccak(P)), ..., _blobVersionedHashes = [V])`
   while the transaction carries *unrelated* blobs at the claimed indices. Only `blobhash(i) != 0` is
   checked, so the record is written with `V` although no L1 blob hashes to `V`.
3. A prover lands a batch referencing the record. DA-08(1) checks the record's fields against the statement;
   DA-08(3) runs the precompile with the **recorded** `V`, and the precompile only checks
   `kzg_to_versioned_hash(C) == V` plus the opening — both are satisfiable with the publisher's off-chain
   `C`. The guest evaluates `p_P(z) = y` over the payload it holds in witness.
4. The batch is accepted. **No L1 transaction anywhere contains `P`.** DA-01(b)'s canonical location is
   fictitious, DA-04's prohibition ("the guest MUST NOT be able to execute a batch whose payload it received
   only through a private witness while the corresponding public data is absent") is defeated, and the
   withheld-data window D-11 exists to close is re-opened silently.

**Inside/outside the fault model.** **Inside** as a rule gap (publisher and prover are permissionless; no
stake). If an implementation follows the L1-08 ABI rather than DA-07(2)'s description, the consequence is a
soundness-adjacent R8/DA-04 breach reachable **without** ≥ 1/3 — which would make it Critical; it is graded
High because DA-07(2) does describe the BLOBHASH provenance and a conforming implementation that reads
`BLOBHASH` closes it. The defect is that this load-bearing check is nowhere stated as a check.

**Attacker resources and cost.** One type-3 transaction (which must carry *some* blobs to pass (5)), plus a
normal proving run. Cheaper than publishing the real data.

**Requirement / decision affected.** R8 ("Public data bound to the proof"); DA-01, DA-04, DA-05; D-11's
premise that the data is on L1 before the proof; premise (6) of DA-03/DA-08.

**Evidence.** `spec/04` DA-07(1)(2)(5), DA-08(1)(3), DA-03(i), DA-03 "Premises" (6), L1-08 interface sketch
(lines 306–309) and comment at line 285 for the contrast.

---

## R5T-PDE-03 — High — the proof-bound settled frontier `settledAfter` has no upper bound, so one proof can write the frontier past the whole register and permanently disable forced inclusion.

**Rule / missing rule.** **L1-05 row 36**: "`settledAfter` is claimed and proof-bound, and the contract MUST
reject a value below `settledFrontier`" — regression only; there is no upper bound, and
`ForcedFrontierRegression(settledAfter, settledFrontier)` is the only error. **PRF-04(vi)/FI-11(5)** require
only `c' ≥ min(d(A), c + cap(batch))` and "every record in `[c, c')` is included in the batch or discharged as
void under FI-13". **Missing rule:** `settledAfter ≤ nextSeq(A)` (the register's next position at the anchored
view), plus an explicit statement that a record index with no record at `A` cannot be resolved and blocks the
frontier.

**Assumptions.** The register (`publicationOrder`, `nextSeq`) is readable from the anchored L1 state proofs
that FI-11(2)/PRF-04(vi) already require; D-12's "upper bound on exclusion".

**Attack trace.**
1. A prover lands one batch with `settledAfter = 2^64 − 1` (any value above the successor count; the contract
   accepts it because it only rejects values **below** `settledFrontier`).
2. The guest must confirm every record in `[c, c')` was included or void. For sequence positions at or above
   `nextSeq(A)` there is no record: there is no transaction to include and FI-13's predicate has nothing to
   evaluate. The specification never says the guest must reject this case; an implementation that treats an
   absent record as "nothing required" (the same reading that makes "void" work for an already-consumed nonce)
   accepts the proof.
3. `settledCount = 2^64 − 1` is written in the settlement record. Every future publication has
   `sequence < c'`, so it is already behind the frontier: the FIFO prefix is empty at every future batch,
   the obligation never fires again, and FI-14 forbids any function that lowers the frontier. Forced inclusion
   is dead for the life of the deployment, from one proof.

**Inside/outside the fault model.** **Inside.** Any account may land (L1-04); the prover needs no stake and no
assumption failure. (The alternative "safe" reading — the guest rejects any frontier beyond `nextSeq` — is an
implementer's invention, which is itself the R13 defect.)

**Attacker resources and cost.** One valid batch and its proof — a cost the attacker recovers through L1-11's
landing reward and, more importantly, pays once.

**Requirement / decision affected.** D-12 (narrow forced inclusion must bound exclusion in v1); FI-10, FI-11(5),
L1-05 row 36; R13 (160/160 rules stated once).

**Evidence.** `spec/04` L1-05 row 36, FI-10, FI-11(5), L1-08 errors (`ForcedFrontierRegression` only),
interface line 295; `spec/05` PRF-04(vi).

---

## R5T-PDE-04 — High — FI-10's "expiry and discard" and FI-13's "no other ground discharges a record, at any layer" are mutually exclusive, and the interface sketch mandates the function FI-14 forbids.

**Rule / missing rule.** **FI-10** ("Expiry and discard"): "A record whose DA-09 deadline has passed without a
proof is dead: it MUST be discarded from the due set by an objective, permissionless advance of the frontier —
no judgement, key, vote or DAO action is used — and **no proof may be required to include it**." **L1-08**
declares `pruneExpiredPublications(uint32 _maxRecords) external returns (uint64 settledFrontier_)` and the
event `ForcedFrontierAdvanced(..., settledFrontier, ...)` documented as "advanced by an accepted batch **or by
the objective expiry prune**". Against that, **FI-14** ("No discretion"): "there MUST NOT exist a function that
clears the register, rewrites a record's `l1BlockNumber` or identity, **lowers the settlement frontier, skips a
prefix element except by include-or-void under FI-13**, extends a record's due point …"; and **FI-13**: "No
other ground discharges a record, at any layer: not a proposer's claim, not a validator's vote, not a DAO or
operator action, not a recovery, and **not the record's own age** while it is still live." **Missing rule:**
exactly one of the two must be authoritative, and the spec must say which: either age *is* a discharge ground
(and FI-13/FI-14 are amended, with the consequences below), or it is not (and FI-10's discard clause,
`pruneExpiredPublications`'s frontier advance, and DA-09(2)'s "discarded and re-published" consequence for the
due set are inoperative).

**Assumptions.** FI-13's void predicate; FI-14's prohibition; DA-09(1)'s deadline; the mandatory ABI of L1-08.

**Attack trace (horn A — implement the mandated prune).** A due record is not included for
`T_PROVE_DEADLINE` blocks (a settlement stall, an availability failure, or a ≥ 1/3 coalition that stalls
certification — note that a *sub-quorum* coalition cannot omit a due record, because CONS-01(v) makes an
omitting block invalid). Any account then calls `pruneExpiredPublications`: the frontier advances past a
record that was includable and was never included or voided, with **no proof and no FI-13 predicate**. The user
re-publishes, pays again, and the cycle repeats. The enforcement point of the obligation is thereby moved from
the proof (FI-11: "the enforcement point is the proof, not `land`") to an unauthenticated L1 call, and D-12's
"it does not give the protocol a pause or a discretion" is broken by a permissionless-but-suppressing lever.
**Horn B — implement FI-14.** Every record in the prefix must be included or voided under FI-13, and an expired
record is neither; the frontier cannot advance past it. Worse, `PUB_RECORD_RETENTION` permits the entry to be
pruned after its deadline ("a pruned record is treated as absent", DA-09(1); `spec/09` `PUB_RECORD_RETENTION`
row, `spec/08` MIG-02 slot 277 `pruneCursor`), while FI-11(2) still requires the guest to "verify every record
of the required prefix" against the anchored state — a record that no longer exists cannot be verified, so no
proof can advance the prefix: a permanent halt created by a permissionless storage-reclamation call.

**Inside/outside the fault model.** The rule conflict is a specification defect (no adversary needed). Horn A's
*censorship* use needs a stall (F1) or ≥ 1/3 (F2) to keep a due record unincluded, so the exploitable half is
outside the strict < 1/3 model; the proof-free resolution of a due record is available to any account inside it.

**Attacker resources and cost.** Horn A: one L1 transaction (the prune), plus the ability to keep the chain
from landing a batch for `T_PROVE_DEADLINE` (a stall, i.e. a liveness-assumption failure, or a ≥ 1/3 coalition).
Horn B: none — it is the default behaviour of a conforming implementation.

**Requirement / decision affected.** D-12 (enforcement point = the proof; no suppression of forced data);
FI-13's "at any layer"; FI-14's "MUST NOT exist"; DA-09(2)'s discard-and-re-publish consequence.

**Evidence.** `spec/04` FI-10, FI-13, FI-14, L1-08 (interface lines 314–319, event line 362–364);
`spec/09` `PUB_RECORD_RETENTION`; `spec/08` MIG-02 slot 277.

---

## R5T-PDE-05 — High — the reward pool has no liability accounting: `pool_before(e)` re-counts ETH already frozen for earlier epochs, and `REC_REWARD` is drawn from the realised balance with no reserve, so the same inflow is allocated twice and the "one inflow is never allocated twice" claim is false.

**Rule / missing rule.** **ECON-02(5)(a)**: "Its outflows are exactly three … **No inflow may be assigned
twice**: `Alloc(e) + ProvingShare(e) ≤ pool_before(e)`, checked at the (5)(d) freeze, and the completion
reward is computed from the pool's realised balance at the completion transaction and paid only while that
balance covers it, **so it cannot draw an inflow already frozen into an epoch allocation**."
**ECON-02(5)(e)**: `Alloc(e) = floor(ALLOC_VAL_PPM · pool_before(e) / 1e6)`,
`ProvingShare(e) = floor(ALLOC_PRV_PPM · pool_before(e) / 1e6)`.
**ECON-02(5)(d)**: `pool_after(e) = pool_before(e) + inflow(e) − Σ_v payout(v,e) − ProvingShare(e) − REC_REWARD(e)`.
**ECON-02(5)(f)**: `REC_REWARD = min(REC_REWARD_CAP, floor(ALLOC_REC_PPM · pool_now / 1e6))`, `pool_now` =
"the pool's realised balance when the completion transaction executes".
**ECON-02(5)(c)**: a claim "pays the entry's recorded owner, never the caller" — so no third party has any
incentive to claim, and unclaimed allocations stay in the pool indefinitely (claims open only after
`evidenceClose(e)` and never close). **Missing rule:** `pool_before(e)` must be the pool's *free* balance —
realised balance minus frozen-but-unclaimed `Alloc`/`ProvingShare` of earlier epochs — and `REC_REWARD` must
be bounded by that free balance; alternatively the freeze must be refused while earlier liabilities are
outstanding. No reservation, liability or solvency term exists anywhere in `spec/07` or `spec/03`.

**Assumptions.** D-8 (L2 fees fund security); the security budget A-ECO-1 is the realised pool.

**Attack trace (no adversary required).**
1. Epoch 1 freezes at `pool_before = 100` with `ALLOC_VAL_PPM = 900,000`: `Alloc(1) = 90`.
2. Nobody claims during epoch 1 (the owner must claim; the caller is paid nothing). The 90 stays in the pool.
3. Epoch 2 freezes at `pool_before = 100` again (nothing was paid out) and fixes `Alloc(2) = 90`.
4. Both epochs' participants claim: 180 is owed against 100. The per-epoch check
   `Σ payout ≤ Alloc ≤ pool_before` held for each epoch and is false globally; the later claims revert or the
   pool cannot honour a frozen allocation (the pool may not go negative). The same mechanism books the same
   inflow into every epoch's security budget, so A-ECO-1's "realised inflow" is overstated by the number of
   unclaimed epochs.
5. Independently, (5)(a)'s claim that `REC_REWARD` "cannot draw an inflow already frozen into an epoch
   allocation" has no mechanism: `REC_REWARD` is a fraction of `pool_now`, and both `Alloc(e)` and
   `ProvingShare(e)` are computed and left in the same undifferentiated balance (the proving-share transfer is
   permissionless, so it too may be delayed indefinitely). A completed recovery can therefore consume the ETH
   those two outflows were computed against, ahead of the validator claims that open only at
   `evidenceClose(e)`.

**Inside/outside the fault model.** Inside but not adversarial: the failure is a rational-inaction/incentive
property (claims pay the owner, not the caller) plus a missing accounting rule.

**Attacker resources and cost.** None; any validator set that does not claim promptly triggers it.

**Requirement / decision affected.** D-8 (L2 fees fund security), ECON-02's funding identity, A-ECO-1,
R11 (objective rewards/collateral/exits).

**Evidence.** `spec/07-economics-slashing.html` ECON-02 (5)(a)(c)(d)(e)(f) (lines 146–230).

---

## R5T-PDE-06 — High — no registered relation ties the forced-inclusion due delay to the record's proving deadline, so the v1 forced-inclusion rule can be configured to be structurally vacuous.

**Rule / missing rule.** **FI-10**: a record is *due* at view `A` iff
`record.l1BlockNumber + FI_INCLUSION_DELAY ≤ A`. **DA-09(1)**: a record is `DISCARDED` at
`deadlineBlock = l1BlockNumber + T_PROVE_DEADLINE`, and it is discarded from the due set by FI-10's expiry
clause. `spec/09` registers `FI_INCLUSION_DELAY` with only "≥ the SYS-02 finality requirement" and
`T_PROVE_DEADLINE` with only the two proof-pipeline inequalities
(`T_PROVE_DEADLINE ≥ T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + margin` and
`T_PROVE_DEADLINE + T_SETTLE_PIPELINE ≤` blob retention). Neither page states
`FI_INCLUSION_DELAY < T_PROVE_DEADLINE`, nor the stronger
`FI_INCLUSION_DELAY + (drain horizon) < T_PROVE_DEADLINE` needed for F-FI-2's stated latency claim.
**Missing rule:** the registered relation between the due point and the record's life (and between the due
point and the anchor's advance, see R5T-PDE-07).

**Assumptions.** D-12 requires narrow forced inclusion to ship in v1 and to bound exclusion; every FI value is
an unmeasured placeholder that Phase B will fix.

**Attack trace (configuration, not adversary).** Set `FI_INCLUSION_DELAY ≥ T_PROVE_DEADLINE` (permitted by
every rule as written). Every record is `DISCARDED` before it can ever be due: `d(A)` counts no record, the
required prefix is always empty, and the only thing that ever removes a record is the proof-free expiry prune
(R5T-PDE-04). R10's narrowed form is then satisfied on paper and delivers nothing; conversely, a deadline only
slightly above the delay leaves no window in which a backlog can be drained, and F-FI-2's "latency guarantee
only while arrival does not exceed drain" is empty because there is no drain window at all.

**Inside/outside the fault model.** Not adversarial — a parameter relation the spec fails to register (R13).

**Attacker resources and cost.** None.

**Requirement / decision affected.** D-12 ("narrow forced inclusion ships in v1"; "bounds the time a censoring
proposer can keep a user's transaction out of the chain while the chain otherwise runs"); R10; R13.

**Evidence.** `spec/04` FI-10, DA-09(1)(2); `spec/09` rows `FI_INCLUSION_DELAY`, `T_PROVE_DEADLINE`;
FI-12 F-FI-2.

---

## R5T-PDE-07 — Medium — the anchored view `A` is only required to be Ethereum-final and non-decreasing; no rule requires it to advance, so FI-10's claim that the due set is a function of Ethereum-final L1 state alone is false and the exclusion bound is conditional on honest proposers refreshing the anchor.

**Rule / missing rule.** **FI-10**: "so the due set is a function of Ethereum-final L1 state alone".
**L1-05 row 36**: `anchoredL1Block` is claimed and proof-bound to the batch's SYS-02 anchor step; the contract
"MUST reject a view that is not Ethereum-final at landing … or that is older than the predecessor's recorded
`anchoredL1Block`". **SYS-02(c)** requires a consumed L1 fact to be Ethereum-final *for the voter at vote
time* — finality, not freshness. **FI-11**: "no stale-view escape" is defined only as regression.
**Missing rule:** a freshness requirement on the consumed anchor (e.g. the latest Ethereum-final L1 block the
proposer can establish, or at least an advance of at least one final block per N L2 blocks).

**Attack trace.** A proposer builds a block whose SYS-02 anchor re-uses an old but still-final L1 block;
validators have no ground to reject it (SYS-02 is satisfied and L1-05 row 36 only forbids regression), so it is
certified. `d(A)` then does not grow, records published after `A − FI_INCLUSION_DELAY` are never due, and no
batch is obliged to include them — the forced-inclusion clock is under the control of the parties it judges.
A full freeze needs every proposer slot (an honest proposer could keep refreshing `A`), so a < 1/3 coalition
can only *slow* the clock; the unconditional claim of FI-10 remains false, and the bound D-12 promises holds
only by assumption about honest proposer behaviour that no rule states.

**Inside/outside the fault model.** Delay: inside. Full freeze: outside for a < 1/3 coalition (needs all
slots). The defect is the missing rule, not the trace's multiplicity.

**Attacker resources and cost.** One proposer slot per stalled interval (or a lazy client that carries the
anchor forward).

**Requirement / decision affected.** D-12's upper bound; FI-10's stated invariant; DA-10.

**Evidence.** `spec/04` FI-10, FI-11 ("L1-side checks that are not gates"), L1-05 row 36; `spec/01` SYS-02(c).

---

## R5T-PDE-08 — Medium — the aggregation bitmap's canonical length is fixed by the *current* family registry, not by the batch epoch's route set, so an additive route registration invalidates in-flight aggregation objects for already-certified unsettled ranges.

**Rule / missing rule.** **L1-14(2)**: the contract MUST require the `familyBitmap` to be canonical —
"**length fixed by the L1-09 family registry**, no bit outside the families live for the epoch, the reserved
aggregation tag unset". **L1-09**: the family index is append-only ("the i-th family tag registered gets index
i, indices are append-only and never re-used or re-ordered"); registration is an upgrade; "A new image MUST
accept every history that the previous image accepted" and retiring an image "MUST NOT be executed while any
PoS-finalized-but-unsettled range could be proved only under the retired image". **L1-13(7)**: "an upgrade that
raises `k` applies only to batches landed after it and MUST NOT block the designation of an already-landed
boundary checkpoint". **Missing rule:** the bitmap length (and the live-bit set) must be fixed by the batch
epoch's accepted route set — which `routeSetHash` already pins — rather than by the current registry.

**Attack trace (governance timing, no adversary).** A family is registered (an additive upgrade) after an
epoch's batches were certified but before they are landed/attested. The canonical bitmap length grows by one;
the in-flight aggregation object, correct for that epoch's route set and length, is now
`MalformedFamilyBitmap` and cannot land at all — settlement of an already-certified unsettled range stops
until the whole aggregation proof is re-produced, the exact stranding L1-09's retirement bar exists to prevent.
The same applies to `attestWithdrawalRoot`.

**Inside/outside the fault model.** Not adversarial; a rule/registry-timing defect (liveness, no fund loss).

**Attacker resources and cost.** None (an honest upgrade triggers it).

**Requirement / decision affected.** L1-09's preservation intent, L1-13(7), R5/R6 liveness, D-13's "one
verification per purpose".

**Evidence.** `spec/04` L1-14(2), L1-09 ("Backend families", "Retiring an image"), L1-13(7);
`spec/05` PRF-15(3).

---

## R5T-PDE-09 — Medium — the registered aggregation funding `AGG_PROVER_PPM` cannot be applied on-chain as ECON-02(5)(e) states, because L1-10/L1-11 pay the whole reward to `msg.sender` and forbid attribution to any other address.

**Rule / missing rule.** **ECON-02(5)(e)**: "Where the aggregator and the batch prover are distinct parties,
the split is applied at the **L1-11 prover-reward payout** or settles privately between them".
**L1-10**: "The reward of L1-11 MUST be paid to `msg.sender` … the protocol MUST NOT attempt to attribute it
to any address named inside the proof." **L1-11**: the ledger "MUST be debited only by the `rewardPaid` of a
successful `land(data, proof)` and by nothing else". **PRF-15(3)**: the aggregation public input carries
`statementHash`, `routeSetHash` and `familyBitmap` — no payout address, so the Inbox cannot even name an
aggregator. **ECON-02(5)(a)**: the pool's outflows are "exactly three", so the staking contract cannot pay the
aggregator directly either. **Missing rule:** either an enforceable aggregation-payment path, or an explicit
statement that only the private arrangement exists and the on-chain policy is inert.

**Attack trace.** The aggregator produces the aggregation object; a searcher sees the proof in the mempool and
lands it first (L1-10 explicitly accepts this); `msg.sender` receives the whole proving share, and there is no
on-chain way for the aggregator to be paid. Aggregation is therefore not performed for the settlement object
beyond the degenerate self-aggregation by whoever lands, and withdrawal roots (which need `k` distinct
families) have no payer — the exit-path liveness gap L1-13(5) discloses then has *no* conforming on-chain
remedy even though ECON-02(5)(e) claims one.

**Inside/outside the fault model.** Inside (economic; front-running needs no stake).

**Attacker resources and cost.** One landing transaction's gas; the reward pays it back (L1-11).

**Requirement / decision affected.** D-13 ("Cost moves to the prover"; `AGG_PROVER_PPM` is the registered
funding), L1-13(5) exit-path liveness, ECON-02(5)(e) vs L1-10/L1-11.

**Evidence.** `spec/07` ECON-02 (5)(a)(e); `spec/04` L1-10, L1-11, L1-13(5); `spec/05` PRF-15(3)(6).

---

## R5T-PDE-10 — Medium — DA-09(1) mandates a mutable status on a record that MIG-02 declares immutable and whose consumed-ness must be recorded "never by mutating the record"; the two pages disagree about the referenceability authority.

**Rule / missing rule.** **DA-09(1)**: the record "MUST carry … a status that is one of `PUBLISHED`,
`PROVEN` or `DISCARDED`: `PUBLISHED` when written, `PROVEN` when a batch referencing it is accepted, and
`DISCARDED` at `deadlineBlock` if it is still `PUBLISHED`". **DA-07(3)**: "a record is immutable once
written". **MIG-02** (`spec/08`, slots 275–277, and lines 316–337): the entry holds the DA-07(2)/(3) field set
(hashes commitment, range, mode, commitment, block, sequence, per-record deadline) "and **is immutable** once
written: whether it was consumed is recorded in L1-09's side mapping with the accepted statement, **never by
mutating the record**". **Missing rule:** which object the referenceability predicate reads (the immutable
deadline plus the side mapping, or a status field), and where the status lives if it exists. This matters
because premise (6) of the DA-03/DA-08 referenced-binding argument asserts the record's immutability; the
content-derived identity check neutralises a mutated hash, but the specification's own storage budget and
premise are contradicted by its own rule.

**Attack trace.** No soundness break demonstrated: the identity `publicationId` is recomputed from the stored
field set and the deadline is fixed at publication, so a mutated status cannot make a dead record referenceable
or change the bound bytes. The defect is implementer-facing (two sources of truth for `PublicationExpired` /
`PROVEN`), plus a false premise in a soundness argument.

**Inside/outside the fault model.** Not applicable (specification inconsistency).

**Requirement / decision affected.** D-11 premise (6); MIG-02 storage budget; DA-09(1)(2); R13.

**Evidence.** `spec/04` DA-07(3), DA-09(1); `spec/08` MIG-02 slots 275–277 and the D-11 budget paragraph.

---

## R5T-PDE-11 — Medium — on the referenced path there is no `daMode` derivation source: L1-05 row 17 makes it tx-derived, while the referenced transaction carries a reference rather than the payload or blobs.

**Rule / missing rule.** **L1-05 row 17**: "`daMode` … 1 = CALLDATA, 2 = BLOB, 3 = CALLDATA_AND_BLOB;
**derived from which arguments/blobs are present**, not from a submitter field", and the rule's preamble says
tx-derived values "the contract recomputes from the transaction's calldata and blobs and MUST ignore any
submitter-supplied copy". **L1-01/DA-08(2)**: on the referenced path the accepting transaction carries a
reference and no blobs. **DA-08(1)**: the record's `daMode` must equal the statement's. **L1-05 row 34**
explicitly derives `dataBindingSource` "from the transaction's own blobs and the referenced record" — row 17
says nothing about the record. **Missing rule:** the referenced-path source for `daMode` (necessarily the
record, i.e. a value the submitter selected by choosing the record, so the "MUST ignore any submitter-supplied
copy" clause needs an explicit exception).

**Attack trace.** No soundness break (the value is proof-bound and cross-checked against the record), but an
honest landed batch is unlandable if the contract derives a mode that no argument supports, or the contract
takes the mode from the record and silently violates the tx-derived rule. `daMode` is load-bearing for the
commitment construction (DA-02/DA-03(0)), so an implementer must invent the rule.

**Inside/outside the fault model.** Not applicable (specification gap; liveness / R13).

**Requirement / decision affected.** R13; DA-08(1); D-11's referenced path.

**Evidence.** `spec/04` L1-05 row 17 and preamble, row 34, DA-08(1)(2), L1-01.

---

## R5T-PDE-12 — Low — PRF-06 F1's fee routing is a normative change to EVM fee semantics that is never reconciled with the journal's `feeRecipient`, which is declared load-bearing but receives nothing.

**Rule / missing rule.** **ECON-02(7)(a)**: the L2 fee policy "MUST route both components" (execution base fee
and priority fee) to the vault, and a component "destroyed, paid to a block beneficiary, or otherwise diverted
is not collected revenue". **PRF-06 F1** makes any such diversion unprovable, and **ECON-04** makes it a
slashable offence. **L1-05 row 21 / PRF-02**: `feeRecipient` is "the L2 proposer payout address committed by
the header", and PRF-02 says every journal field is present "because each is load-bearing". No rule states that
the L2 header's beneficiary is the vault (or that the priority fee is redirected to it), and the header field
that would carry the proposer's payout is bound yet pays nothing after D-6 removed the forced-inclusion fee.
**Missing rule:** the reconciliation between the header's beneficiary, the journal's `feeRecipient`, and the
fee policy that F1 enforces (or deletion of the vestigial field).

**Attack trace.** None (no adversary); a mis-implemented L2 fee policy makes every honest block unprovable
and every proposer slashable, so the ambiguity is worth one line in the specification.

**Inside/outside the fault model.** Not applicable.

**Requirement / decision affected.** D-8; PRF-06; ECON-04 fee-diversion offence; R13.

**Evidence.** `spec/07` ECON-02(7)(a); `spec/05` PRF-06 F1; `spec/04` L1-05 row 21; `spec/05` PRF-02.

---

## R5T-PDE-13 — Low — nothing pins the in-circuit verification routine used for a route to that route's registered `verifier` address; the required equivalence is asserted by the aggregation program's code.

**Rule / missing rule.** **PRF-15(4)**: the aggregation program "MUST verify it against the verification
algorithm of that route's registered verifier and registered program image — never against a witness-supplied
verifier, image id or verification key, and never against a route outside `routeSetHash`".
**L1-09**: a route is `(programImageId : bytes32, verifier : address, backendFamily : bytes32)`, and
`routeSetHash` commits the ordered registered route set. The zkVM program cannot call the L1 `verifier`
address, so the correspondence between the registered address/algorithm and the routine the program executes is
a property of the aggregation image's code; no registered object (family tag, image id, verifier address) is
specified as the algorithm selector. **Missing rule:** the registered selector that binds a route to the
in-circuit verification routine (and the audit duty for it).

**Attack trace.** None beyond the already-disclosed trust in the aggregation image
(PRF-15(5), L1-14(4), L1-13(6)): a mis-registered route or a mis-wired routine sets a family bit that L1 counts.
Bounded by A-GOV-1 and image audit; recorded because D-13's "must not be able to claim a family it did not
verify" is only as strong as this unpinned correspondence.

**Inside/outside the fault model.** Outside as stated (requires a bad upgrade or a code defect).

**Requirement / decision affected.** D-13; PRF-15(4); L1-09.

**Evidence.** `spec/05` PRF-15(4)(5); `spec/04` L1-09, L1-14(4).

---

## Checked and holds (not re-listed as findings)

1. **Referenced blob content binding (D-11).** As a *content* binding it is as strong as the carried one: the
   precompile is correctly identified as not transaction-scoped, the recorded versioned hash is the
   commitment's identity, the on-chain opening plus the in-guest evaluation reproduce the whole fixed-point
   argument, and the precompile-less variant is correctly rejected as unsound. What is lost is exactly
   same-transaction equality and same-transaction availability, and both are disclosed. The only gap found is
   the *provenance* of the recorded hashes at publication (R5T-PDE-02), not the opening.
2. **PRF-04(vi) vs FI-11.** Clause (vi) recomputes what FI-11 fixes: the anchored view `A`, the guest-derived
   `c` and `d(A)`, the batch-computed cap, the FIFO prefix `[c, min(d(A), c+cap))`, the per-record transaction
   inclusion/void predicate, the lower bound on `c'`, and the `forcedBoundary` commitment. No divergence
   found; the missing piece is the *upper* bound on `c'` (R5T-PDE-03), which neither rule states.
3. **Family bitmap enforceability (D-13).** A prover cannot claim a family it did not verify through any input
   it controls: the bitmap is an output of the registered aggregation image and is bound by the proof's public
   input; the Inbox recomputes `routeSetHash` from its own epoch registry, rejects non-canonical lengths,
   non-live bits and the reserved tag, and derives the count itself. The residual — a defective or malicious
   aggregation image can set any bit, and L1 cannot tell — is disclosed exactly as D-13 requires
   (L1-14(4), PRF-15(5), L1-13(6)); it does not violate a hard requirement as written.
4. **PRF-06 F1–F4.** Exact for an ordinary block, a donation/forced credit, a canonical sweep in the same block
   as forced data, and every intra-block ordering (sweep before or after the block's fee credits): the forced
   credit never enters `feeCredits` and is never swept; the Bridge fee is additional ETH and cancels; the
   balance identity holds. F3 leaves `X(h)`'s computation to the guest, but F1/F2 carry the load, so the
   looseness is not exploitable.
5. **DA-06/DA-09 clock separation.** The three objects (`D_MAX` in L2 blocks, `T_PROVE_DEADLINE` in L1 blocks
   per record, `FI_MAX_PER_BATCH` as a work bound) are correctly separated and forbidden from being combined;
   DA-09(2)(3)'s consequence for a missed deadline (record dead, range still landable by carry or fresh record)
   matches L1-04's no-expiry rule. The incoherence is at the FI expiry bridge (R5T-PDE-04) and in the missing
   due-delay/deadline relation (R5T-PDE-06), not in DA-06/DA-09 themselves.
6. **DA-03's challenge and whole-blob commitment.** The round-1 prefix attack stays closed: the challenge is
   derived on-chain from a transcript that includes `dataCommitment` and `blobHashesHash`, the commitment
   covers every byte of every blob, and the |F|-bias correction is arithmetically right.

---

## Fault-model summary

- **Inside the claimed fault model:** R5T-PDE-01 (permissionless halt), R5T-PDE-02 (permissionless
  publisher/prover; conditional on the implementation reading the hashes from calldata),
  R5T-PDE-03 (any prover), R5T-PDE-05 and R5T-PDE-09 (economic, no stake needed), R5T-PDE-07 (delay).
- **Outside:** R5T-PDE-04's exploitable horn (needs a stall or ≥ 1/3), R5T-PDE-13 (bad upgrade/code defect).
- **Not applicable (rule/config defects):** R5T-PDE-06, R5T-PDE-08, R5T-PDE-10, R5T-PDE-11, R5T-PDE-12.

**One-line verdict for synthesis.** The D-11 content binding survives adversarial re-attack, but the D-11
*record* is not the object the D-12 forced-inclusion rules believe it is, and the D-12 obligation's work bound,
expiry ground, frontier bound and clock relations are all either contradictory or missing; the single reward
pool is also allocated per epoch without a liability term. The referenced-binding content argument, the
aggregation bitmap's non-claimability and the F1–F4 fee reconciliation were re-attacked and hold.
