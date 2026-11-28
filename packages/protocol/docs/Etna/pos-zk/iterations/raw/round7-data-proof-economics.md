# Round 7 — the D-11 data path, proof soundness and economics in a v1 with no forced inclusion and no aggregation

**Reviewer angle.** The D-11 data path (carried / referenced publication, proving deadline), proof
soundness and single-backend disclosure, the withdrawal-root exit, the fee vault, and the reward pool
and treasury — in the smaller v1 of D-16. Targets: `spec/04-l1-integration.html` (DA-07..DA-10,
L1-05/06/08/09, L1-10..L1-13, MSG-01..MSG-04), `spec/05-proof-statement.html` (PRF-01..PRF-14) and
`spec/07-economics-slashing.html`; cross-checked against `spec/01-system-model.html`,
`spec/02-consensus.html`, `spec/03-membership-staking.html`, `spec/06-recovery-exceptions.html`,
`spec/08-migration-upgrades.html`, `spec/09-parameters.html`, `spec/10-assurance.html`, the rule
index and the course under `learn/`. Read first: `iterations/07-freeze.md` and `DEFERRED.md`.

**Snapshot.** `296f44b54` (branch `etna-pos-zk`). The working tree is `94a12a698`, two commits later;
`git diff 296f44b54 HEAD` touches only `iterations/07-freeze.md` and residue text in spec/04/spec/05
(tombstone wording), so every finding below was checked against the named snapshot's rules.

**Method.** The specification is the authority; in-text notes, pills, "deferred" markers and repair
citations are claims, not evidence. The four D-16 deferrals (FI-10..FI-14 + CONS-01(v), MEM-13/CONS-16,
GOV-04/REC-02..REC-04, PRF-15/L1-14) are **not** reported as defects: each is tombstoned where it lives
(FI-10..FI-14 and L1-14 on 04, REC-02..REC-04 on 06, GOV-04 on 08, MEM-13 on 03, the parameter rows in
09, the index, assurance and the register). What is reported is (a) live rules that still treat a
deferred mechanism as live or read a tombstoned name, and (b) v1-core defects in my angle.

**Fault-model key.** Inside = reachable by any account inside the stated assumptions without a
cryptographic break, malicious governance, key compromise or code bug. Outside = needs ≥ 1/3 Byzantine
stake, a stall, a bad upgrade or an implementation bug.

**Counts: 2 High, 5 Medium, 3 Low.** One High is reachable inside the fault model
(R7-DPE-05, the pool); R7-DPE-01 is a spec-integrity/implementability blocker rather than an attack.

---

## R7-DPE-01 — High — forced inclusion is still live in spec/07 and in a live system-model rule: the closed offence catalogue still contains a slashable "forced-inclusion breach", its bounty, and the publication-economics rule that frames it, all defined by D-16 tombstones.

**Rule / missing rule.** `spec/07` **ECON-04(1)** ("Only the offences of the table below may consume
bonded stake") still lists the table row **"Forced-inclusion breach — a signed proposal whose block, at
its own anchored L1 view A, omits a published, unproven record that is due at A
(`record.l1BlockNumber + FI_INCLUSION_DELAY ≤ A`) …"** with a collateral-consuming penalty against
`SlashBase` and the offender "the signer of the omitting block's proposal". **ECON-04(3)** still calls
this "the one exception" to the no-omission rule and cites `FI-10`; **(5)** repeats it; **(6)** is a full
live clause ("The narrow forced-inclusion breach (D-12)") whose predicate is "the due point of
FI-10/FI-11 and CONS-01(v)", whose evidence interval is `ECON-07(4)`, and whose conclusion is a slash.
**ECON-05(5)** and **ECON-06(5)** route the reporter bounty to "every offence of ECON-04's closed
catalogue, including the narrow forced-inclusion breach". **ECON-13** is still titled "the economics of
the forced-inclusion deadline" and its (1)/(3)/(4) define the due point, the breach and its penalty.
**ECON-02(5)(a)** repeats the D-12 breach in the pool's own custody clause. `spec/01` **ROLE-04(b)(i)**
still promises the user right: "the protocol then owes the narrow forced-inclusion obligation of
FI-10 – FI-14: once a record is due, a batch must resolve it by the capped FIFO prefix …" with a
post-D-16-free decision note. Every one of those references points at a rule that says "not normative in
v1; MUST NOT be implemented" (`FI-10`–`FI-14`), a clause that is a tombstone (`CONS-01(v)`), a
guest clause that is a tombstone (`PRF-04(vi)`) or a withdrawn parameter (`FI_INCLUSION_DELAY`, row
(withdrawn) in 09). **Missing rule:** spec/07 (ECON-04 clause (1)'s catalogue, clause (3)'s exception,
clause (5), clause (6) and its table row; ECON-05(5); ECON-06(5); ECON-13 (1)(3)(4) and its title) and
`spec/01` ROLE-04(b)(i) must be swept to say what `FI-REMOVED-01` and `spec/10` LIVE-04 already say:
there is no omission offence in v1 and publishing data imposes no obligation.

**Assumptions.** The D-16 rollback is authoritative (07-freeze.md, DEFERRED.md §1); `FI-REMOVED-01` and
`spec/10` LIVE-04 are the disclosure of record; ECON-04(1) makes the catalogue closed and exhaustive.

**Attack trace (two directions, neither needing an adversary).**
1. **Implement the catalogue as written.** The offence predicate needs the due set, the capped FIFO
   prefix and the includability discharge of FI-10..FI-13 and the per-block obligation of CONS-01(v),
   every one of which "MUST NOT be implemented". An implementer must therefore either revive a deferred
   mechanism (contradicting the tombstones) or invent the predicate — and the failure mode ECON-04's own
   closing note forbids ("an open-ended 'misconduct' clause lets an implementer invent a discretionary
   slash"). With the predicate invented, an honest proposer that omits published-but-unrequired data can
   be slashed, and the treasury and the reporter bounty of ECON-06(5) are paid out of that stake.
2. **Drop the offence.** Then the catalogue's row is dead, ECON-06(5)'s bounty and ECON-13(4)'s whole
   clause describe an offence that does not exist, and the user-facing promise in ROLE-04(b)(i) is false.
   This is the state the *rest* of the snapshot already asserts: `spec/10` LIVE-04 says "there is no due
   set, prefix, deadline discharge or omission offence (`CONS-01`, `ECON-04`)" — citing ECON-04 as
   agreeing, while ECON-04 clause (6) stands.

**Inside/outside the fault model.** Not applicable as an attack: it is a specification contradiction
that needs no assumption failure. Its *consequence* if direction 1 is implemented is a loss of stake
outside any defined rule.

**Attacker resources and cost.** None; in direction 1, one L1 evidence transaction plus L1 gas (bounty
and treasury split funded by the slashed stake).

**Requirement / decision affected.** D-16 and DEFERRED.md §1; FI-REMOVED-01; 07-freeze.md's disclosure
that v1 has "any inclusion obligation" absent; ECON-04(1)(3)(5)(6); ECON-05(5); ECON-06(5); ECON-13;
ECON-02(5)(a); spec/01 ROLE-04(b)(i); R13.

**Evidence.** `spec/07-economics-slashing.html` ECON-04 lines 417–425 (clause 3), 459–464 (offence table
row), 471–479 (clause 5), 480–530 (clause 6); ECON-05 line 643–647; ECON-02 line 150–152; ECON-13 lines
1050, 1052, 1078, 1087; `spec/01-system-model.html` ROLE-04 lines 528–537, 550–552;
`spec/04-l1-integration.html` FI-REMOVED-01 (tombstone text), FI-10..FI-14; `spec/10-assurance.html`
LIVE-04 lines 243–245; `DEFERRED.md` §1.

---

## R7-DPE-02 — Medium — aggregation is still live in the allocation policy and in the parameter register: ECON-02 requires a recorded `AGG_PROVER_PPM` share for an object that "MUST NOT be implemented", and the live `K_PROOF_BACKENDS` row names L1-14(3) and the aggregation public input as its enforcement.

**Rule / missing rule.** `spec/07` **ECON-02(5)(e)** still says the proving share "funds all off-chain
proving work, **including the aggregation of the one proof object per batch** (clause 5(e), D-13)" and
still mandates: "the recorded allocation policy MUST also fix the share `AGG_PROVER_PPM` of
`ProvingShare(e)` assigned to the aggregation that produced the epoch's proof objects … The aggregator's
inner-proof count is bounded by `M_AGG_MAX` … the per-purpose required counts are `K_SETTLE_BACKENDS`
(= 1) for settlement and `K_PROOF_BACKENDS` for a withdrawal root: those counts are enforced inside the
one accepted object (`L1-14(3)`, `PRF-15(5)`) … Where the aggregator and the batch prover are distinct
parties, the split is applied at the L1-11 prover-reward payout or settles privately between them", with
the honest-limit note keyed to an unpaid aggregator. `spec/09`'s row `K_PROOF_BACKENDS` (a **live**
parameter, consumed by the shipped L1-13) still reads: "the required count for an epoch-boundary
withdrawal root L1-13(1) **and L1-14(3)** (D-13): **the count is enforced by the Inbox over the
aggregation public input**, so L1 still performs one verification per purpose; fixed by S1's measured
aggregation cost". **Missing rule:** ECON-02(5)(a)/(e) must be restated for a v1 with no aggregation
object (the proving share funds ordinary and attach proofs; `AGG_PROVER_PPM`, `M_AGG_MAX`,
`K_SETTLE_BACKENDS` are withdrawn), and the `K_PROOF_BACKENDS` row must name L1-13(3)'s per-attestation
family count instead of L1-14(3).

**Assumptions.** D-16 defers aggregation; `L1-14` is a tombstone ("not normative in v1; MUST NOT be
implemented … no aggregation route may be registered and no bitmap, route-set hash or aggregation count
exists"); `PRF-15` is a tombstone; 09's own rows for `AGG_PROVER_PPM`, `M_AGG_MAX`, `K_SETTLE_BACKENDS`
and `T_AGG_ROTATE_MAX` are "(withdrawn) … MUST NOT be used"; L1-09 says "in v1 there MUST NOT be an
aggregation route".

**Attack trace (activation, no adversary).** The allocation policy is "written by the activation
transaction" and ECON-02(5)(e) still requires it to fix `AGG_PROVER_PPM` — a parameter 09 says MUST NOT
be used. An implementer cannot satisfy both: recording the share is unlawful per 09, and omitting it is
non-conforming per ECON-02. The same conflict appears at the k-row: an implementer following 09 will
look for a bitmap/route-set object that L1-14 forbids and L1-08 no longer passes. No funds move; the
defect is that a shipped mechanism's funding rule and one of its live parameters describe a mechanism
the same snapshot forbids.

**Inside/outside the fault model.** Not applicable (rule/register contradiction).

**Attacker resources and cost.** None.

**Requirement / decision affected.** D-16 and DEFERRED.md §4; ECON-02(5)(a)(e); 09 `K_PROOF_BACKENDS`
row; L1-14/PRF-15 tombstones; L1-09; L1-13(1)(3); R13.

**Evidence.** `spec/07-economics-slashing.html` ECON-02 lines 155, 214–215 (the aggregation paragraph and
the aggregator-split sentence); `spec/09-parameters.html` lines 190–195 (`K_SETTLE_BACKENDS`,
`K_PROOF_BACKENDS`, `N_PROOF_BACKENDS`, `M_AGG_MAX`, `AGG_PROVER_PPM`, `T_AGG_ROTATE_MAX`);
`spec/04-l1-integration.html` L1-14 (tombstone), L1-09, L1-13(1)(3); `DEFERRED.md` §4.

---

## R7-DPE-03 — Medium — live rules still promise the deferred governance stall resolution: ROLE-04 tells interfaces and users that a provisional confirmation "can be replaced by the stall-resolution rules of REC-02/GOV-04", and MEM-15(5) reasons about "a completed recovery" restoring a checkpoint.

**Rule / missing rule.** `spec/01` **ROLE-04(b)(iii)** (live): "any display of a confirmation above the
last L1-accepted checkpoint must say that the confirmation is provisional and **can be replaced by the
stall-resolution rules of REC-02 / GOV-04**"; **ROLE-04(f)** (live): a halt "is resolved, if at all, by
participants resuming under HALT-02 or by the timelocked, resume-only stall resolution of REC-02 /
GOV-04, whose execution depends on governance liveness. … **the stall resolution may discard the blocks
that carry it**". `spec/03` **MEM-15(5)** (live, the shipped exit guarantee) still says the path "does
not apply to a checkpoint above the **recovery floor** (REC-01, REC-02): **a completed recovery restores
that same checkpoint**, so a proof already executed against it stays backed (REC-02, replay row) and a
proof against a **discarded checkpoint** is simply re-made against the restored one"; MEM-15(3)'s note
still cites REC-04 as "what separates a discarded branch". `REC-01` states that "in v1 no protocol path
replaces [history above the checkpoint]", `REC-02`/`REC-04` are tombstones, and `DA-09(3)`, `MSG-03`
and REC-02's tombstone all say v1 has no recovery path and a stall is cleared only by a future protocol
update. **Missing rule:** ROLE-04(b)(iii)/(f) and MEM-15(3)/(5) must state the v1 position (nothing
replaces a provisional confirmation; a stall halts until a future update) or defer the reference.

**Assumptions.** D-16 defers the governance stall resolution; REC-02/REC-04/GOV-04 are tombstones;
REC-01's boundary is the only v1 rule about history above the checkpoint.

**Attack trace (user-facing, no adversary).** An interface implemented from ROLE-04(b)(iii) tells a user
that its confirmation above the checkpoint "can be replaced by the stall-resolution rules" — a mechanism
that does not exist in v1 and whose absence is the round's central disclosure. Conversely an interface
implemented from REC-02/DA-09(3)/MSG-03 tells the user the opposite. One of the two conforming readings
is wrong, and the user cannot tell whether a stalled chain can be resumed inside the protocol.

**Inside/outside the fault model.** Not applicable (live-rule/tombstone contradiction; disclosure
correctness, no fund loss).

**Attacker resources and cost.** None.

**Requirement / decision affected.** D-16; REC-01; REC-02/REC-04/GOV-04 tombstones; DA-09(3); MSG-03;
07-freeze.md ("any recovery path of any kind" disclosed as absent); R13.

**Evidence.** `spec/01-system-model.html` ROLE-04 lines 556–562, 565–574;
`spec/03-membership-staking.html` MEM-15 clauses (3) note and (5) (text above); `spec/06` REC-01,
REC-02, REC-04; `spec/04` DA-09(3); `spec/08` GOV-04.

---

## R7-DPE-04 — Low — the learning course still teaches the deferred mechanisms as live: heartbeat eligibility (two pages), the governance restart, and the narrow forced-inclusion obligation.

**Rule / missing rule.** The course is the artifact the freeze says must be re-synced. Visible (not
comment) text still promises: `learn/04-staking-and-epochs.html` — "To be selected into a future set
version, a validator must post a periodic liveness attestation — a heartbeat" (L50), the heartbeat key
and window (L122–143, L190), the cost/benefit of heartbeats (L312–315);
`learn/10-economics.html` — "selection into a future set version requires a heartbeat on L1" (L123),
"No free place in a set: staying selectable costs a periodic Ethereum heartbeat transaction" (L272–273),
heartbeat-based exclusions (L255, L285, L314–315); `learn/08-when-things-go-wrong.html` — "the recovery
generation advances … The restart advances the recovery generation" (L96, L130, L138, L291, L507) and
heartbeat answers (L151, L160, L459, L511, L528, L547–548); `learn/09-censorship-and-the-bridge.html` —
"forced-inclusion obligation over data published to L1" and "(FI-10 – FI-14)" (L37, L50, L112);
`learn/glossary.html` — "Forced inclusion: The narrow obligation …" (L129), heartbeat definitions
(L132, L151, L166, L219–235) and "stall resolution" (L199); `learn/limitations.html` — FI-10–FI-14
(L178), "advances the recovery generation" (L124), the queued timelock (L250);
`learn/index.html` — the restart/generation summary (L61–63) and "a narrow, proof-enforced inclusion
obligation" (L78); `learn/06-data-and-proof-together.html` — "starts a new recovery generation" and
"begins below the retired height" (L270, L283). Pages `01-what-is-etna.html`, `02-life-of-a-transaction.html`,
`05-the-proof.html` and `07-timing.html` are re-synced and correct. **Missing rule:** the same sweep the
index and assurance pages received.

**Assumptions.** DEFERRED.md §§1–3; MEM-13 and GOV-04 tombstones; FI-REMOVED-01 and LIVE-04.

**Attack trace.** None (documentation); a reader learns a v1 that does not exist and cannot reconcile it
with the specification.

**Inside/outside the fault model.** Not applicable.

**Requirement / decision affected.** D-16; 07-freeze.md ("the course teaches what the specification now
says"); R13/user-facing disclosure.

**Evidence.** The files and visible-text line numbers above; compare `learn/01`, `learn/02`,
`learn/05`, `learn/07` (re-synced).

---

## R7-DPE-05 — High — the reward pool still has no liability term: `pool_before(e)` includes ETH already frozen for earlier epochs, so the same inflow is allocated to every epoch with an open claim and "one inflow is never allocated twice" remains false.

**Rule / missing rule.** `spec/07` **ECON-02(5)(a)** (unchanged in v1): the pool's outflows are exactly
two, "disjoint draws on the same balance", and "**No inflow may be assigned twice**:
`Alloc(e) + ProvingShare(e) ≤ pool_before(e)`, checked at the (5)(d) freeze". **(5)(e)**:
`Alloc(e) = floor(ALLOC_VAL_PPM · pool_before(e) / 1e6)`,
`ProvingShare(e) = floor(ALLOC_PRV_PPM · pool_before(e) / 1e6)`. **(5)(c)**: a claim "pays the entry's
recorded owner, never the caller", opens only after `evidenceClose(e)` **and never closes**. **Missing
rule:** `pool_before(e)` must be the pool's free balance — realised balance minus frozen-but-unclaimed
allocations of earlier epochs — or the freeze must be refused while earlier liabilities are outstanding.
There is no reservation, liability or free-balance term anywhere in `spec/07` or `spec/03` (grep for
`pool_before`, "unclaimed", "liability": only the formula and the failure-mode sentence).

**Assumptions.** D-8 (fees fund security); A-ECO-1 (the realised pool is the security budget); rational
inaction (dust, a contract or lost key that cannot call `claimValidatorReward`, or a validator that
simply does not claim).

**Attack trace (no adversary required).**
1. One sweep delivers `B` ETH to the pool.
2. Epoch 1 freezes at `pool_before(1) = B` with `ALLOC_VAL_PPM = 600,000`, `ALLOC_PRV_PPM = 400,000`:
   `Alloc(1) = 0.6B`, `ProvingShare(1) = 0.4B`; the per-epoch check holds.
3. Nobody claims epoch 1 and nobody makes the permissionless proving-share transfer; the balance is
   still `B`.
4. Epoch 2 freezes at `pool_before(2) = B` and fixes the same `0.6B / 0.4B`. The per-epoch check holds
   again; total promises are `2.0B` against `B` of inflow.
5. Claims for one epoch revert against an empty pool; the other epoch's claimants are paid from ETH the
   same rule already assigned elsewhere. `Σ payout ≤ Alloc ≤ pool_before` held in both epochs and is
   false globally.
6. Independent ordering lever: the proving-share transfer is permissionless and unrestricted while
   validator claims open only at `evidenceClose(e)`, so a non-validator can move `ProvingShare(e)`
   first and leave the epoch's validators short even if they claim promptly.

**Inside/outside the fault model.** **Inside**, non-adversarial: any epoch left unclaimed triggers it and
no assumption has to fail.

**Attacker resources and cost.** None.

**Requirement / decision affected.** ECON-02(5)(a)(c)(d)(e); A-ECO-1; D-8; R11. This is round-6 finding
**R6-DPE-02 re-broken in v1**: D-15/D-16 removed the recovery-completion draw (the third horn) but added
no liability term, so the main horn is unchanged and the pool is now v1's only security budget.

**Evidence.** `spec/07-economics-slashing.html` ECON-02 lines 147–155, 165–171, 196–204, 214–215;
`spec/09-parameters.html` lines 130–131, 1208, 1217.

---

## R7-DPE-06 — Medium — on the referenced path there is still no derivation source for `daMode`: L1-05 row 17 requires a tx-derived value, but the accepting transaction carries neither the payload nor the blobs.

**Rule / missing rule.** `spec/04` **L1-05 row 17**: "`daMode` … 1 = CALLDATA, 2 = BLOB, 3 =
CALLDATA_AND_BLOB; **derived from which arguments/blobs are present**, not from a submitter field", and
the table preamble says tx-derived values are recomputed from the transaction and "MUST ignore any
submitter-supplied copy". On the referenced path the accepting transaction carries neither the payload
nor the blobs (**DA-08(2)**) and the contract takes the versioned hashes from the record (**DA-08(3)**);
**DA-08(1)** requires the record's `daMode` to equal the statement's, and the ABI comment still reads
"`uint8 daMode; // must equal the derived mode, else DataModeMismatch()`" (`LandInput`). **Missing
rule:** the referenced-path source for `daMode` — necessarily the record, i.e. a value the submitter
selects by choosing the record, requiring an explicit exception to "ignore any submitter-supplied copy".

**Assumptions.** DA-02/DA-03(0) fix the commitment construction per mode and `daMode` is bound into
`statementHash` (PRF-02); the referenced path is a shipped v1 path (D-11).

**Attack trace (implementability, no adversary).** An implementation that follows row 17 literally
derives `daMode = CALLDATA` on a referenced landing (the accepting transaction carries only calldata and
no blobs), which contradicts the record's `daMode = BLOB` and reverts every referenced landing — the
batch is unlandable although L1-04 promises any valid pair is landable. An implementation that instead
takes the mode from the record silently violates the row and its preamble. Two conforming readings
produce different acceptance sets for the same transaction.

**Inside/outside the fault model.** Not applicable (specification gap; liveness/R13). Round-6 finding
**R6-DPE-08 re-broken**: text unchanged.

**Attacker resources and cost.** None.

**Requirement / decision affected.** D-11's referenced path; L1-04; L1-05 row 17 and the row preamble;
DA-08(1)(2); R13.

**Evidence.** `spec/04-l1-integration.html` L1-05 row 17 (line 150) and the table preamble, row 34
(line 166), DA-08 (lines 654–660), `LandInput` (line 276); `spec/05` PRF-02 `daMode`.

---

## R7-DPE-07 — Medium — the zero-outstanding-balance sweep: PRF-06 F3 excludes the caller's Bridge fee from `X(h)` on the ground that it is consumed in the same call, but the no-op sweep consumes nothing; the rule never states that path's `msg.value` treatment.

**Rule / missing rule.** `spec/07` **ECON-02(7)(b)**: the sweep entry point "MUST require `msg.value` to
equal exactly the canonical fee the preserved Bridge charges for that one message … so no caller can …
make an honest block unprovable by overpaying", and "a sweep when the outstanding recorded fee balance
is zero is a no-op — it moves nothing and MUST NOT block anything, even when a forced credit is
present". `spec/05` **PRF-06 F3**: "`X(h)` [is] the ETH credited to the vault over block h by any route
other than the fee credit of (F1) **and the Bridge fee a sweep caller supplies under clause 7(b)**; that
Bridge fee **is credited and consumed inside the same sweep call**", checked by
`balance(h) − balance(h−1) == ΔfeeCredits + X(h) − V(h)`. **Missing rule:** the `msg.value` treatment on
the zero-balance path (reject or refund) and the classification of a sweep-supplied fee that no message
consumes.

**Assumptions.** Zero fee arrivals in the block, or an already-swept vault — the "zero arrivals" case the
funding path explicitly contemplates (ECON-02(7)(d)(ii)).

**Attack trace.** Any account calls `sweep{value: canonicalFee}()` in a block whose outstanding fee
balance is zero. The vault credits the fee, emits no message (`V(h) = 0`) and does not move
`feeCredits`. An implementation that classifies the credit as the excluded Bridge fee leaves it
unaccounted: `balance(h) − balance(h−1) = fee ≠ 0 + X(0) − 0`, so F3 fails, the batch is unprovable and
a certified block can never settle — a halt for the price of one L2 transaction, the class the same
paragraph's exact-fee guard was written to prevent. An implementation that classifies it as `X` keeps
the identity but strands the caller's ETH forever, because the sweep moves only `feeCredits − feeSwept`.

**Inside/outside the fault model.** **Inside** (any account, no stake); the outcome depends on an
implementation choice the specification does not fix.

**Attacker resources and cost.** One L2 transaction.

**Requirement / decision affected.** D-8's funding path; PRF-06 F1–F4; ECON-02(7)(a)(b); the paragraph's
own "a forced credit cannot halt settlement". Round-6 finding **R6-DPE-04 re-broken**: text unchanged.

**Evidence.** `spec/07` ECON-02(7)(b) lines 262–269; `spec/05` PRF-06 F1–F4.

---

## R7-DPE-08 — Medium — the withdrawal root's k−1 attach proofs have no funding rule, and in a v1 with no recovery at all the exit they gate is the only protection left.

**Rule / missing rule.** `spec/04` **L1-13(3)**: any account MAY call
`attestWithdrawalRoot(height, programImageId, proof)`; the accepting route counts as the first family
attestation, each further call verifies one more proof under another family, and "when k distinct
families have attested, the height MUST be marked a withdrawal root". **L1-13(5)**: "The attach proofs
are paid by whoever submits them and **no funding rule for them exists in this specification** … (Open;
the natural funding source is the proving share of ECON-02, which is owned elsewhere)". **MEM-15(2a)**
makes that root the gate on the shipped exit guarantee, and D-16 removes every recovery path, so
"the exit of L1-13(3) is what remains available" (PRF-10's note). **Missing rule:** a funding rule for
the k−1 proofs, or an explicit statement that the exit's liveness is conditional on volunteer/altruist
proving and that a user must arrange it — and a check that ECON-02's two outflows can reach it at all.

**Assumptions.** D-16 ships the exit as the substitute for recovery; A-GOV-1 and the route inventory are
launch gates; L1-13(5)'s Open item is disclosed.

**Attack trace (liveness, no adversary).** A root is a public good: once k families attest, every signal
at or below the root becomes releasable, so the k−1 attestations are paid for by whoever wants their own
withdrawal first and by nobody afterwards. With k ≥ 2 and no reward, a rational prover produces none;
the signals of users who cannot pay a prover wait. Because no other path exists in v1, a chain that halts
with unsettled history above the checkpoint leaves those users with no in-protocol remedy.

**Inside/outside the fault model.** Inside as an economic-liveness property (no adversary needed); the
k-family availability half is disclosed at L1-13(5). The rule is disclosed as Open, which is why this is
recorded as Medium rather than High: the defect is that a *shipped* guarantee (MEM-15 via D-16) rests on
an unfunded item with no registered payer.

**Attacker resources and cost.** None.

**Requirement / decision affected.** D-16's shipped exit; MEM-15(2a); L1-13(3)(4)(5); ECON-02(5)(a)(e)
and its closed two-outflow pool; PRF-14(4)(d); R11.

**Evidence.** `spec/04` L1-13(3)(4)(5) (lines 441ff), L1-08 `attestWithdrawalRoot`;
`spec/03` MEM-15(1)(2a); `spec/05` PRF-10 note, PRF-14(4)(d); `spec/07` ECON-02(5)(a)(e).

---

## R7-DPE-09 — Low — L1-08 still requires two errors whose stated conditions no longer exist: `NotEpochBoundary` (the pre-D-16 root-formation restriction) and `InsufficientFamiliesForRoot` (the aggregation-era count check).

**Rule / missing rule.** `spec/04` **L1-08**: "every custom error listed MUST be raised on the stated
condition", and the list still contains `error NotEpochBoundary(uint64 height, uint64 expectedBoundaryHeight)`
and `error InsufficientFamiliesForRoot(uint8 attested, uint8 required); // L1-13(1),(3)`. **L1-13(1)**
now explicitly widens the formation point ("nothing in this rule may hold an exit for a new epoch: …
any already-accepted checkpoint, and in particular the latest one, is attestable"), and **L1-13(3)**
takes one proof per call and marks the root when the k-th family attests — there is no count argument
and no boundary requirement. **Missing rule:** delete the two errors and their conditions, or state the
conditions that remain.

**Assumptions.** L1-13 is the shipped exit rule; `attestWithdrawalRoot` takes `(height, programImageId,
proof)` with no count.

**Attack trace.** An implementer following L1-08 reverts attestations for non-boundary checkpoints with
`NotEpochBoundary`, which is exactly the exit-during-stall case L1-13(3) requires to work (the latest
accepted checkpoint is generally not an epoch boundary); or invents a count check that L1-13 does not
have. Either way the interface sketch and the rule disagree.

**Inside/outside the fault model.** Not applicable (interface/spec inconsistency).

**Requirement / decision affected.** L1-13(1)(3); L1-08; R13.

**Evidence.** `spec/04-l1-integration.html` L1-08 error list (`NotEpochBoundary`,
`InsufficientFamiliesForRoot`), L1-13(1)(3), L1-08 `attestWithdrawalRoot` signature.

---

## R7-DPE-10 — Low — MIG-02 still budgets and initialises the forced-inclusion publication clock and promises a permissionless prune, but the v1 interface exposes no prune entry point and the FI rules are tombstones.

**Rule / missing rule.** `spec/08` **MIG-02** slot 277 is "publication clock, packed — `nextSeq` +
**`dueHead` (the FIFO head the capped prefix drains from) + `dueTail` + `dueCount` + `pruneCursor`**",
slot 276 is "the append-only register order the capped FIFO prefix drains, so the due set is a prefix of
one sequence", and the migration writes "pruning after `PUB_RECORD_RETENTION` is a permissionless
advance of `pruneCursor`"; the genesis record initialises all five to zero "so the first post-activation
batch faces an empty due set". `spec/09`'s `PUB_RECORD_RETENTION` row repeats that pruning "is a
permissionless, objective reclamation of the register's entry slot". But `spec/04` **L1-08** exposes
exactly the acceptance surface, the veto/root surface and nothing else — no prune function — while
`FI-10`–`FI-14` are tombstones and no v1 rule reads the due set. **Missing rule:** either a prune entry
point (and its authority) in L1-08, or the removal of the prune promise and the FI-era cursors from
MIG-02/09 and a statement that the register grows monotonically.

**Assumptions.** L1-08's "exactly the acceptance surface" plus "no additional state-changing entry point
that accepts a batch or writes a checkpoint" (a prune is not forbidden but is not provided); DA-09(1)
permits pruning after retention and treats a pruned record as absent.

**Attack trace.** Unbounded, permissionless publication records accumulate in Inbox storage with no
specified reclamation path, while the migration budget prices three slots of FI-era cursor state that no
v1 rule reads. An implementer cannot tell whether to build the prune (09 and MIG-02 say it exists) or
omit it (L1-08 does not list it).

**Inside/outside the fault model.** Not applicable (storage/register inconsistency); the griefing cost of
spam falls on the publisher.

**Requirement / decision affected.** D-16; DA-07/DA-09; L1-08; MIG-02 slots 275–277; 09
`PUB_RECORD_RETENTION`; R13.

**Evidence.** `spec/08-migration-upgrades.html` MIG-02 lines 281–283, 328–353, 426–435;
`spec/09-parameters.html` lines 179–180; `spec/04` L1-08, DA-07(2), DA-09(1), FI-10..FI-14 tombstones.

---

## Checked and holds (not re-listed as findings)

1. **The referenced-blob binding is as strong as the carried one.** DA-07(5) keeps the element-wise
   `_blobVersionedHashes[i] == blobhash(_blobIndexStart + i)` check, the length equality, the non-zero
   range check and the "no third form" rule, so the recorded hashes are the publication transaction's own
   consensus-verified blob entries; DA-08(3) keeps the EIP-4844 point-evaluation call with the recorded
   versioned hash in place of `BLOBHASH`, and DA-08(3)/PRF-07 keep the precompile-less variant rejected as
   unsound. Only same-transaction equality and availability are lost, and both are disclosed (DA-08(4),
   DA-05, DA-09). I re-attacked zero/short/long/empty hash lists, blobs outside the range,
   `blobIndexStart` arithmetic and the record-identity recomputation: each is rejected.
2. **The proving deadline's consequence is coherent.** DA-09(1) fixes `deadlineBlock` at publication,
   keeps `T_PROVE_DEADLINE` inside blob retention and usable
   (`≥ T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + margin`), and DA-09(2) makes a missed deadline a
   liveness event with the re-publication escape, never an admission gate on the range (L1-04). DA-09(3)
   now states the honest residual: if nobody re-publishes, settlement stalls and v1 has no replacement
   path. The withdrawn `FI_INCLUSION_DELAY < T_PROVE_DEADLINE` relation is correctly retired in 09.
3. **The censorship gap is disclosed.** FI-REMOVED-01 is explicit ("a proposer that excludes a
   transaction — published or not — is not in breach", "R10 is not satisfied in v1"), and the same
   statement appears in `spec/10` LIVE-04, REC-01/REC-02/REC-03 tombstones, DA-09(3), MSG-03, PRF-09,
   the index, the register and DEFERRED.md §1. The only places that still promise an inclusion obligation
   are the residues in R7-DPE-01 and R7-DPE-04.
4. **Single-backend settlement soundness is disclosed**, and the withdrawal-root policy is not overstated:
   PRF-09 ("settlement soundness is the soundness of the weakest approved backend … a bridge-theft-class
   failure"), PRF-14(4)(b), L1-13(6) and the course's "No aggregation" section all say it, and the
   withdrawal-root conjunctive k-family requirement is stated as an exception, not a repair.
5. **The k-family requirement is enforceable at one verification per attestation.** L1-13(3) verifies one
   proof per call against the *recorded* statementHash under a route whose image is in the epoch's
   accepted set and whose family has not already attested (`FamilyAlreadyAttested`), L1-09 records the
   accepting route's `backendFamily` as the first attestation and says a family is live per epoch via
   MIG-05, and L1-14's count has no v1 counterpart. The only trust residue is the registration honesty
   of family tags (A-GOV-1), which is disclosed — plus the stale register row in R7-DPE-02.
6. **Fee-vault reconciliation F1–F4 is exact** for the ordinary block, a forced credit/donation, a
   canonical sweep in the same block as the block's own fee credits (before or after them), and the
   carried sweep; the Bridge fee cancels, a forced credit never enters `feeCredits` and is never swept,
   and the balance identity reduces to the ordinary predicate. The only combination I can break is the
   zero-balance no-op sweep (R7-DPE-07).
7. **The withdrawal root + veto still fail closed**, and the tombstone sweep of the exit path is good:
   MSG-03 now measures `WITHDRAWAL_DELAY` from the root record's `l1BlockNumber`, states the
   attestable-latest-checkpoint property and discloses the stall consequence; MSG-04's veto is
   rule-triggered, one-shot, `T_VETO`-bounded and non-extendable; the register tombstones L1-14,
   PRF-15, the FI set, `K_SETTLE_BACKENDS`, `M_AGG_MAX`, `AGG_PROVER_PPM`, `T_AGG_ROTATE_MAX`, the
   heartbeat set and the stall-resolution parameters, each with a MUST-NOT-USE reason.
8. **Treasury and bounty rules are self-consistent in themselves:** D-9's no-burn destination,
   `REPORTER_BOUNTY(id) < charge(id)` (self-reporting never profitable), the `BOUNTY_GAS_FLOOR`
   disclosure and the withdrawn recovery-bond destinations are as before. The only treasury-relevant
   defect is that the bounty is still advertised for the non-existent forced-inclusion offence
   (R7-DPE-01).

**Scope note.** I did not audit the deferred mechanisms themselves (per the round's instruction) and did
not re-derive the consensus, membership or migration angles; the residues above are those visible from
the data/proof/economics pages and their direct cross-references.

---

## Fault-model summary

- **Inside the claimed fault model:** R7-DPE-05 (pool double-allocation; no adversary, no assumption
  failure) and R7-DPE-07 (permissionless no-op sweep, conditional on the implementation's classification
  of the unconsumed fee). R7-DPE-08 is an economic-liveness property, inside but disclosed as Open.
- **Not applicable (spec/interface contradictions needing no adversary):** R7-DPE-01, -02, -03, -04,
  -06, -09, -10.
- **No Critical found in the v1 core**: the D-11 binding, the proving deadline, the single-proof
  settlement policy, the k-attestation root, the fee vault and the veto all hold as written.

**One-line verdict for synthesis.** The v1 core's data path, proof policy and fee accounting survive
re-attack — the referenced binding is as strong as the carried one, the deadline has a coherent and
disclosed consequence, single-backend soundness and the censorship gap are disclosed, and the exit is
attestable from L1 state — but the snapshot is **not implementable as written**: spec/07 still defines a
slashable forced-inclusion offence and an aggregation funding policy over rules that MUST NOT be
implemented (ECON-04/05/06/13, ECON-02(5)(e)), two live rules still promise the deferred stall
resolution, the referenced path has no `daMode` derivation, the pool allocates one inflow to every open
epoch, the zero-balance sweep path is unstated, and the exit's k−1 attestations have no payer.
