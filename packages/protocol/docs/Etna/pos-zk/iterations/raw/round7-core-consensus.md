# Round 7 — raw adversarial review: the core consensus mechanism in a recovery-free v1

**Reviewer:** r6-gov-generations (task-9), fresh independent adversarial reviewer, round 7.
**Snapshot reviewed:** the frozen specification content at `296f44b54` (branch `etna-pos-zk`).
**Tree note (verified):** while this review ran, the tree advanced to `6297031b2` ("round-7 rollback-consistency
report and in-flight repair edits"). The intervening commits changed only `07-freeze.md`,
`iterations/raw/round7-rollback-consistency.md`, `spec/04-l1-integration.html` (8 lines) and
`spec/05-proof-statement.html` (33 lines). `spec/02`, `spec/03` and `spec/07` are byte-identical to
`296f44b54`, so every finding below holds at the current HEAD as well as at the named snapshot.
**Method:** rules judged as written. Italic in-text notes and "closes review round N" tags are claims, not
evidence. Citation: `NN:line` = `spec/NN-*.html` line; `D-n` = `DECISIONS.md`; `DEFERRED.md` = the
deferred-work register; `R7-RB-nn` = `iterations/raw/round7-rollback-consistency.md` (the parallel
rollback-angle review, cross-referenced rather than duplicated).

**Counts: Critical 1 · High 1 · Medium 1 · Low 1.**
**Every Critical and High is inside the claimed fault model: none needs a broken assumption, a Byzantine
coalition, L1 censorship, or a malicious DAO.**

**Headline.** The *core mechanism* survives: with the recovery path gone, the frozen recovery generation is
vacuous but **coherent** — I re-derived CONS-04, CONS-05, CONS-08, CONS-12 and CONS-15 with a generation that
never advances and found no acceptance path, lock rule, conflict predicate or halt trigger that is broken,
unreachable or exploitable by it; the only damage is normative text that still stages the deferred mechanism
as live (R7-CC-02). The halt is genuinely terminal and that is disclosed (LIVE-01/LIVE-05/LIM-01), though
MEM-13's tombstone gives the wrong *reason* for it (R7-CC-03). The one serious, fund-affecting defect is not
in my two pages at all: **spec/07 still defines the narrow forced-inclusion breach as a live, slashable
offence with a reporter bounty, predicated on four D-16 tombstones and a withdrawn parameter, in a page with
zero occurrences of "D-16"** (R7-CC-01). Because of that contradiction, v1 is **not implementable as written**
without choosing which normative page to violate.

---

## Finding R7-CC-01 — Critical: spec/07 still defines a slashable offence for breaching the deferred forced-inclusion obligation, so an honest proposer can be slashed for exercising a behaviour v1 declares lawful

**Severity: Critical.** One-line rationale: ECON-04 clause (6) remains fully normative and attaches
ECON-05's penalty, ECON-06's treasury split and the clause (5) reporter bounty to "the narrow
forced-inclusion breach" of a tombstoned obligation, while CONS-01(v) and FI-REMOVED-01 state that v1
imposes no inclusion duty and that "**no validity condition, offence, deterrence or guarantee may be derived
from it**" — a live slash for a duty the same specification says does not exist is loss of funds for a
correct validator, and its predicate cannot even be evaluated because `FI_INCLUSION_DELAY` is withdrawn and
"MUST NOT be used".

**Exact rule / missing rule.**
- `07:480-530` (**ECON-04 clause (6)**): "**The narrow forced-inclusion breach (D-12)** … a record is due at
  the batch's anchored L1 view `A` iff `record.l1BlockNumber + FI_INCLUSION_DELAY ≤ A` (FI-10). The breach is
  a signed proposal whose block, judged at its own anchored view `A`, does not carry the required capped FIFO
  prefix of the due set: the due set, the prefix, the cap, the includability discharge and the guest's check
  are fixed by **FI-10–FI-13** and **PRF-04(vi)**, and the per-block obligation is **CONS-01(v)**. … The
  penalty is ECON-05's ordinary charge, the destination is ECON-06's split …, and the incentive to report it
  is the **reporter bounty of ECON-06 clause (5)** … The offender is the signer of the omitting block's
  proposal at `(H,R)`."
- `07:1050-1090` (**ECON-13**): the same offence restated with its economics ("(4) The breach, its penalty
  and the incentive to report it … commits the forced-inclusion breach of ECON-04 clause (6)").
- Against it: `02:72` (**CONS-01(v)**, D-16 tombstone): "v1 imposes **no inclusion obligation of any kind**,
  and a proposer that excludes a transaction **is not in breach of any rule of this specification** … it
  MUST NOT be implemented … and **no validity condition, offence, deterrence or guarantee may be derived from
  it**." `04:677` (**FI-REMOVED-01**): "What v1 guarantees: nothing, by rule." `05:48`: "PRF-04(vi) … is a
  tombstone." `09:181-189`: every FI parameter, including `FI_INCLUSION_DELAY`/`FI_ANCHOR_MAX_AGE`, is
  "(withdrawn) … **MUST NOT be used**."
- **Verification of the sweep:** `spec/07-economics-slashing.html` contains **zero** occurrences of "D-16"
  (grep, whole page), and nine non-tombstone references to `FI-10` plus the live ECON-13 text. This is the
  same page-level gap `R7-RB-04` reports as High; I confirm the rule text independently and rate it
  **Critical** because the consequence is a *slash on a correct validator* (loss of funds), not a broken
  disclosure, and because the offence is the only one in the catalogue that punishes an act v1 explicitly
  declares lawful.
- **Missing rule:** clause (6) and ECON-13(1)–(4) must be tombstoned with the rest of D-12, the bounty
  linkage to ECON-06(5) removed, and the offence catalogue closed to the offences that survive (equivocation,
  fee diversion, and ECON-04's other live rows).

**Assumptions.** None beyond the rules: the offender is a correct proposer following CONS-01's validity
predicate (which no longer contains clause (v)); the reporter is any party (ECON-08's evidence path and the
ECON-06(5) bounty make reporting profitable); no assumption failure is needed.

**Concrete attack trace.**
1. A user publishes their transaction's data to L1 under D-11 (permissionless, `04:642-651`, ECON-13(1)).
2. An honest proposer builds a block. Under CONS-01 as written, forced-data inclusion is **not** a validity
   condition (`02:66`, `02:72`), so the proposer may omit the record, and it is "not in breach of any rule".
3. A reporter assembles evidence under ECON-04(6) — the recorded publication, the anchored view `A`, and the
   signed committed payload that omits the prefix — and submits it.
4. ECON-05's ordinary charge is applied against `SlashBase` of the proposer; the slashed stake goes to the
   treasury (ECON-06), and the reporter is paid the clause (5) bounty.
5. Result: a proposer that complied with the *live* validity predicate loses stake for an obligation that
   `02:72` says does not exist, and the same page pair tells an implementer both "do not derive an offence
   from this" and "the offender's stake is charged".
6. Implementation consequence in the other direction: the offence's due point needs
   `FI_INCLUSION_DELAY`, a withdrawn parameter that "MUST NOT be used" (`09:183`). An implementer
   cannot evaluate the offence faithfully; either it invents a value (the false-slashing surface above) or it
   drops the offence (leaving the catalogue's own text false). Both outcomes are v1 defects.

**Inside / outside the claimed fault model.** **Inside.** No cryptographic break, no Byzantine stake, no L1
censorship, no governance action. Both the slashing contract path (ECON-05/06) and the evidence path exist as
live rules; the only actor needed is a reporter with the public record and the block's signed payload.

**Attacker resources and cost.** Gas for one evidence submission; the bounty is the incentive. The victim's
cost is its slashed stake.

**Requirement / fixed decision affected.** **D-16** ("narrow forced inclusion … deferred", and its tombstones
"MUST NOT be implemented"); CONS-01(v)'s explicit prohibition on deriving an offence; FI-REMOVED-01;
ECON-04's own completeness claim ("a protocol-level penalty requires objective, self-contained, on-chain
verifiable evidence" — here it is evidence of an act the protocol permits); ECON-06(5)/ECON-08.

**Evidence.** `07:480-530`, `07:1050-1090`, `07:644` (catalogue summary), `07:780` (deterrence claim);
`02:66`, `02:72`, `02:76-78`; `04:677`; `05:48`; `09:181-189`; `DEFERRED.md` §1; `R7-RB-04` (same
defect, rated High there — see the severity note above).

---

## Finding R7-CC-02 — High: spec/02's core consensus rules still stage the deferred stall resolution as a live transition, including the halt rule's "only sanctioned replacement" and the safety invariant's conditional guarantee

**Severity: High.** One-line rationale: the D-16 sweep did not reach the normative core — CONS-15 still states
that the only sanctioned way history above the last accepted checkpoint may be replaced **is** the timelocked
stall resolution of REC-02/GOV-04, CONS-12 grounds its guarantee above the checkpoint on that mechanism, and
ten more clauses describe behaviour "after an executed stall resolution" — while `REC-01`, `HALT-01`,
`LIVE-01`, `INV-01` and `DEFERRED.md` state that v1 has **no** replacement path and that those rule ids are
tombstones which "MUST NOT be implemented"; the clauses therefore have no implementable precondition, and the
specification gives two contradictory answers about whether provisional history is replaceable.

**Exact rules (all in `spec/02-consensus.html`, my angle's page; line numbers at `296f44b54` = current
HEAD).**
- `02:492-496` (**CONS-15**): "the only sanctioned way history above the last L1-accepted checkpoint may be
  replaced is the timelocked, resume-only stall resolution of **REC-02/GOV-04**, which executes on L1 under
  its own trigger, timelock and void-on-progress rules, restores the L1-accepted checkpoint …" and
  `02:505-507`: "replacing history above the last accepted checkpoint is the business of the timelocked stall
  resolution of **REC-02** and of nothing else."
- `02:420-425` (**CONS-12**): "Above the last accepted checkpoint the invariant is **conditional on the
  stall-resolution rules**: … the timelocked, resume-only action of **REC-02** may discard that history by
  incrementing the generation"; and "after an executed stall resolution, the ordinary link … (**REC-04**(1))".
- `02:254-258` (**CONS-08(4)**): "the canonical status of the history above the last accepted checkpoint is
  governed by the stall-resolution rules (**REC-02**), and a certificate voided there remains admissible".
- `02:195-196` (**CONS-05** note): "replacement of unsettled history above the last accepted checkpoint
  remains the separate, rule-bound L1 path of **REC-02**."
- `02:363` (**CONS-10(7)**): "**Only the executed stall resolution of REC-02 increments it**; no upgrade,
  operator, client or rotation may change it."
- `02:467` (**CONS-13(5)**): "the timelocked, resume-only stall resolution of REC-02 may discard unsettled
  history under its own trigger and timelock."
- `02:71` (**CONS-01(iii)**), `02:73` (**CONS-01(vii)**: "the executed stall resolution of REC-02"),
  `02:76` (the objectively decidable offence set includes "a proposal … **under a superseded recovery
  generation**"), `02:100` (**CONS-02**, the whole "store across an executed stall resolution" paragraph),
  `02:147-148` and `02:156` (**CONS-04(1)(a)/(2)**: "An executed stall resolution increments the
  generation (REC-02) … the generation change is the single mechanism that releases those locks"),
  `02:179-180` (**CONS-05** validity/void clause), `02:183-184` (**CONS-05(ii)/(iii)**),
  `02:272`/`02:277` (**CONS-09(1)/(2)**), `02:368`/`02:372` (**CONS-11** re-signing across a resolution).
  Counted: 18 occurrences of `REC-02` and 8 of `REC-04` on the page, of which 13 and 6 carry no tombstone
  marker.
- `03:350` (**MEM-15(5)**, my other page): "does not apply to a checkpoint above the recovery floor
  (**REC-01, REC-02**): a completed recovery restores that same checkpoint, so a proof already executed
  against it stays backed (**REC-02**, replay row) and a proof against a discarded checkpoint is simply
  re-made against the restored one."
- Against them: `06:39-92` (**REC-01**): "in v1 no protocol path replaces it … no function that discards
  state above it exists either"; `06:115-127` (**HALT-01**): "v1 has no recovery path of any kind, so there
  is no stall-resolution action to invoke"; `10:64-71` (**INV-01**): "in v1 no protocol path replaces it";
  `10:169-175` (**LIVE-01**); `REC-02`/`REC-03`/`REC-04` are tombstones `06:391-441`; `DEFERRED.md` §3.
- **Missing rule:** delete the recovery contingency from CONS-01(iii)/(vii), CONS-02, CONS-04(1)(a)/(2),
  CONS-05, CONS-08(4), CONS-09(1)/(2), CONS-10(7), CONS-11, CONS-12, CONS-13(5), CONS-15 and MEM-15(5) — or
  state explicitly that they are dormant text with no v1 effect (the tombstone pattern used elsewhere).

**Assumptions.** None. No adversary is required for the defect; it is a contradiction in normative text.

**Concrete trace (why this is not cosmetic).**
1. An implementer working from spec/02 — the page that states CONS-01–CONS-16 "in full" (`02:16`) — reads
   CONS-15 and implements a halt path whose recovery is "the timelocked stall resolution of REC-02/GOV-04",
   and CONS-12/CONS-05 tell it that history above the checkpoint may be discarded by that action. Both are
   transitions the tombstone says MUST NOT be implemented: the implementer must either implement a forbidden
   mechanism or violate the normative clauses it is reading. Either choice is a conformance failure.
2. A reviewer or interface checking the guarantee class gets two answers: spec/02 says provisional history is
   replaceable by REC-02 (and that this is "the only sanctioned way"); REC-01/INV-01/LIM-01/LIVE-01 say v1 has
   no replacement path at all and the halt persists. The user-facing consequence is the one D-16 was meant to
   settle: whether a PoS confirmation above the checkpoint can ever be replaced. In v1 it cannot — but the
   consensus page still promises that it can.
3. The *structural* deletions are justified by the deferred mechanism: CONS-04(2) withdrew the retired-height
   lock carve-out "as redundant", on the stated ground that "the generation change is the single mechanism
   that releases those locks" (`02:156`). With GOV-04 deferred the generation can never change (`06:63-64`,
   `09:171`, `04:163`: "in v1 the counter stays at its initial value"), so that justification is false; the
   deletion is still *correct* for v1 (nothing is discarded, so no carve-out is needed), but any future
   revival of a discard must reinstate the carve-out **and** the anchor-generation rule that round 6 found
   missing (`round6-gov-generations.md` G-3). A reviver reading CONS-04(2) would believe the generation
   handles it.
4. `02:76` also keeps "a proposal … under a superseded recovery generation" inside the *objectively decidable
   offence set* of CONS-01, i.e. a slashable scope defined by a concept that no v1 rule can produce.

**Inside / outside the claimed fault model.** Inside (specification contradiction; no assumption failure, no
attacker). It is an implementation and disclosure defect, not a safety break: I could not construct an attack
from it, because the stale clauses describe a transition that cannot occur.

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** **D-16** (the deferral and its "MUST NOT be implemented"
tombstones); REC-01's boundary and its v1 restatement; INV-01; HALT-01; the DEFERRED register's claim that
"no rule still reads a tombstoned mechanism". Overlaps `R7-RB-06` (Medium there); I rate it High because the
contradiction sits in the **halt rule** and in the **safety invariant's guarantee statement**, not only in
contingency phrasing.

**Evidence.** `02:16`, `02:66-78`, `02:100`, `02:147-156`, `02:179-196`, `02:254-258`, `02:272-277`,
`02:363`, `02:368-372`, `02:420-425`, `02:467`, `02:492-507`; `03:350`; `06:39-92`, `06:96-136`,
`06:225-253`, `06:391-441`; `10:36-101`, `10:153-200`; `09:171`; `04:163`; `DEFERRED.md` §3.

---

## Finding R7-CC-03 — Medium: the terminal-halt disclosure gives a reason that MEM-05/MEM-09 contradict, and never names the barrier that actually makes the halt permanent

**Severity: Medium.** One-line rationale: the one place the offline-cohort residual is explained says the
stopped cohort's "committed weight stays in **every** set version and nothing can draw a reachable set
around it" (`03:527`), but MEM-05(2) removes an exiting entry from later set versions and MEM-09(1) redraws
each version from the entries active at its snapshot — so later versions genuinely can be reachable; what
actually bricks the chain is that the next height's epoch has an **immutable, already-committed** roster and
the fixed height schedule gives the chain no way to skip to a later, reachable version. That barrier is stated
nowhere, so the disclosed reason is falsifiable by a reader and the true one is missing.

**Exact rule / missing rule.**
- `03:527` (**MEM-13 tombstone**): "a cohort that stops participating halts production until a future
  protocol update, because its committed weight stays in every set version and nothing can draw a reachable
  set around it." The same reason is repeated in `02:510-522` (CONS-16 tombstone: "a later set version has
  the same roster as the stalled one") and `DEFERRED.md` §2.
- Against it: `03:290-292` (**MEM-05(2)**): "Exit becomes effective at the first set version whose snapshot
  point is at or after the exit request … from that version the entry's `effStake = 0` and it appears in no
  later set root (MEM-09)." `03:467-474` (**MEM-09(1)**): each version commits "exactly the ledger entries
  that are **active** … at that same instant"; an entry "not yet activated, exited effectively, or slashed
  below the set" is absent. `03:504-507` (**MEM-09(4)**): an epoch's mapping "is never edited" once written.
  `02:446-450` (**CONS-13(2)**): the height schedule is the "fixed default schedule"; `02:510-522`
  (**CONS-16**) defers the only rule that could re-partition or close an epoch early.
- **Missing rule:** state the real barrier — *the epoch that contains the next unfinalised height has an
  immutable committed roster (MEM-09(4), CONS-08(2)) and every height must be judged under that epoch's set
  (CONS-13(2)); because no rule re-partitions a height (CONS-16 deferred) and no batch may skip a height
  (L1-06, CONS-01(iii)), a roster that cannot reach `3s > 2W` bricks the chain permanently even though later
  set versions may be reachable* — and stop claiming that the cohort's weight stays in every version.

**Assumptions.** A cohort holding ≥ 1/3 of one epoch's committed weight stops while remaining bonded. No
adversary; no assumption failure beyond the liveness assumption that failed.

**Failure trace (and the corrected outcome).**
1. The cohort stops. Quorum for any height is `3s > 2W` over the *epoch's* committed set (CONS-03,
   CONS-08(2)); with ≥ 1/3 offline, no height can be certified, so finality halts at the last certified height
   `H_f` (HALT-01(b)).
2. The checkpoint can still advance to `H_f` — `land` is permissionless and needs only an existing
   certificate plus a proof and the data (`04:98-109`, MEM-15(3)) — so the exit set grows to `H_f` and
   MEM-15 exits work there, including during the halt, because a root for the latest accepted checkpoint is
   attested from L1 state alone (`03:347`, `04:412-418`).
3. The next height `H_f+1` lies in epoch `E = epoch_of(H_f+1)`. `mapping[E]` is immutable and was committed
   before `E` began (MEM-09(1),(4)), and it contains the cohort (they were active then). No rule can move
   `H_f+1` to another epoch (the rotation is a tombstone), and no batch may skip it (L1-06; CONS-01(iii)).
   Later versions — including ones an exit request or new stake would make reachable — can never be consumed,
   because the chain cannot reach them. The halt is therefore permanent, exactly as LIVE-01/LIVE-05/LIM-01
   say, but for the reason in the missing rule, not the one stated.
4. The stated reason is checkable and false: an exit request removes an entry from future versions
   (MEM-05(2)), so a reader who believes the tombstone's explanation can conclude that L1-side churn unsticks
   the chain. It cannot, and no rule says why.

**Inside / outside.** Inside (disclosure accuracy; no adversary, no funds at risk beyond the disclosed ones).
**Cost:** none. **Affected:** D-16's disclosed residual; MEM-13/CONS-16 tombstones; LIVE-05's escapability
table; DEFERRED.md §2. **Evidence:** `03:290-292`, `03:467-474`, `03:504-507`, `03:527`; `02:446-450`,
`02:510-522`; `04:412-418`; `10:296-306`; `DEFERRED.md` §2.

---

## Finding R7-CC-04 — Low: the register still bounds the exit wait by an epoch that the D-16 exit no longer waits for

**Severity: Low.** One-line rationale: `L1-13`'s D-16 exit deliberately stops requiring an epoch boundary —
"Any account MAY then call `attestWithdrawalRoot(height, …)` … It MUST NOT require a new L2 block, a new
batch, a new checkpoint, **an epoch boundary** or any settlement progress" (`04:415`) — but the registered
bound `W_ROOT_WAIT_MAX = E_EPOCH + T_PROOF_MAX_PERMITTED` still carries the `E_EPOCH` term and the
`K_PROOF_BACKENDS` row still describes the root as an "**epoch-boundary** withdrawal root" enforced
"over the **aggregation public input**" (`09:191`), citing tombstoned `L1-14(3)`.
**Exact rule / missing rule:** `09:191`, `09:196`; `04:417` (L1-13(5)) repeats the same formula. Missing
rule: re-derive the bound without `E_EPOCH` (the wait is the slowest of the k−1 further attestations plus
L1 inclusion) and re-word the row to "any accepted checkpoint". **Assumptions:** none. **Consequence:** the
only registered exit-wait bound overstates the delay and mixes in a term that no longer gates the path; the
error is in the safe direction (it under-promises), which is why this is Low rather than higher.
**Inside/outside:** inside (register accuracy). **Affected:** D-16's exit guarantee, L1-13(1)/(3)/(5),
PARAM-01. Overlaps `R7-RB-07` (which covers the aggregation-public-input half of the same row); the
epoch-boundary and `E_EPOCH` halves are not covered there. **Evidence:** `09:191`, `09:196`; `04:413-418`.

---

## Answers to the four questions this review was charged with

**1. With no recovery path, does the signed recovery generation still do the work it was introduced for, or is
it vacuous while some rule depends on it?**
It is **vacuous but coherent**, and no rule *depends* on it advancing. The generation is now a constant: no
v1 rule increments it (`06:63-64`, `09:171`, `04:163` "in v1 the counter stays at its initial value"),
GOV-04/REC-02 are tombstones, and the value is L1-derived into the journal and checked three ways by the guest
(`05:192`, `05:268`, `02:84-86`, `02:179`). What it still does in v1 it does trivially and correctly:
it scopes the signing-uniqueness store per `(chain_id, height, type, g)` (`02:94-101`) — with one generation
this is the ordinary CometBFT per-`(H,R)` rule; it scopes locks per `(height, generation)` (`02:144-148`);
it is part of the conflict predicate, where "a pair whose generations differ is not a conflict"
(`02:368-378`) is a no-op; and it is part of certificate validity (`02:179-180`). The rules that were
*justified* by its ability to change — the withdrawal of the retired-height lock carve-out (`02:156`), the
"store across an executed stall resolution" (`02:100`), the "conditional on the stall-resolution rules" framing
of CONS-12 (`02:424`) — now rest on a mechanism that cannot run: this is the substance of R7-CC-02, and it is
a revival hazard rather than a v1 break. I found **no acceptance path, lock rule or conflict predicate that is
satisfiable by a stale generation**, because there is only one generation to be current; the generation is
therefore safe to keep as a constant (and the specification may keep it for forward compatibility), but its
increment language must go.

**2. Are CONS-04 locks, CONS-05 certificates, CONS-08 validity, CONS-12 uniqueness and CONS-15 halting
coherent when no generation change ever occurs?**
**Yes** — verified rule by rule. *CONS-04*: locks are per height and per generation; with `g` fixed they are
plain per-height locks, released by (a) the commit of the locked value or (b) a strictly later same-height
PoLC (`02:147-156`); the generation-change release and the retired-height carve-out are dead but not needed,
and the clause that forbids the competing cross-height reading is unaffected. *CONS-05*: certificate validity
checks a constant; the halt sentence "a conflicting finalized block at H → halt" no longer has round 6's
generation-qualifier ambiguity, because the situation it guarded against (a second, still-valid certificate at
a produced height) cannot arise. *CONS-08*: epoch-scoped, forever-valid judgement is untouched; the only stale
part is the sentence assigning canonical status above the checkpoint to the stall-resolution rules
(`02:254-258`, in R7-CC-02). *CONS-12*: the generation-scoped invariant collapses to "at most one block per
height receives a valid certificate", i.e. the unconditional form the rule deliberately deleted — v1 is
strictly stronger than the text claims, which is safe, and the rule's conditionality is stale. *CONS-15*: the
halt triggers are coherent (two conflicting certificates, a conflicting certificate under the current
generation, a missing/ambiguous set commitment, a corrupt sign-state store, the depth cap, contradictions of
the epoch rule) and they are what remains when no replacement path exists; only the "only sanctioned
replacement" sentence is stale. Two consequences should be stated explicitly in v1 because they are now
unconditional: a state with two valid conflicting certificates is **terminal** (no rule can adjudicate it),
and a lock at an unresolved height persists for the life of the halt — both are consistent with HALT-01/02 and
LIVE-01.

**3. Does the absence of any history-replacement path leave a state the design cannot exit, and is that
disclosed?**
Yes, and mostly yes. The undeexitable states are (i) a settlement stall (no proof/data can be produced) and
(ii) a quorum loss in an epoch whose committed roster is unreachable — in both cases the chain halts at the
last certified height forever, the checkpoint can still advance to that height, and no rule replaces anything
above it. This is disclosed repeatedly and clearly: `06:39-92` (REC-01: no path replaces history in v1),
`06:115-130` (HALT-01: no recovery path, clearing a stall needs a future update), `10:169-196` (LIVE-01:
"the halt persists … clearing requires a future protocol update whose procedure is not specified"),
`10:287-306` (LIVE-05's escapability table: "no production-time bound" for all four halt classes),
`10:323-326` (LIM-01), `07-freeze.md` lines 9-11. The two gaps are R7-CC-02 (spec/02 still promises a
replacement) and R7-CC-03 (the halt's permanence is explained by a falsifiable reason). One further honest
statement is owed: because batches cannot skip a height and no rule re-partitions an epoch, an epoch whose
committed set cannot form a quorum is a **permanent brick**, not merely an unbounded delay.

**4. What exactly happens to production, funds and users when a third of the validators stop, now that MEM-13
no longer exists?**
- *Production.* Quorum is `3s > 2W` over the *epoch's* committed set (`02:104-119`), so with a third
  offline no height can be certified; correct validators halt (`06:102-103`, HALT-01(b)) at the last certified
  height. No rule excludes the stopped entries, removes weight, rotates the set, or closes the epoch
  (`03:527`, `02:510-522`), and no later set version can be consumed because the height schedule is fixed and
  the next height's epoch is immutable (R7-CC-03). Production does not resume unless the cohort returns, or
  unless the epoch containing the next height happens to have been committed before the cohort was in it —
  which is not the case for a cohort that goes offline while bonded.
- *Funds (users).* Value at or below the last L1-accepted checkpoint remains withdrawable on L1 with no new L2
  block, no quorum and no validator: MEM-15(1) plus clause (2a) (`03:345-347`) and `04:412-418`, where a
  root is k distinct-family attestations of the checkpoint's **existing** statement, permissionless and needing
  no settlement progress; the delay runs from the root's own `l1BlockNumber`. The bound on that exit is the
  k-family availability (`04:417`, L1-13(5)): with fewer than k live families no root forms and the exit is
  unbounded. The checkpoint can still advance over already-certified heights while production is halted
  (MEM-15(3)), which grows the exit set to the last certified height. Value **above** that checkpoint — L2
  balances and messages not yet covered — has no L1-provable claim and is frozen for as long as the halt lasts
  (`03:349`, MEM-15(4); `10:298-302`), and if the brick is permanent it is frozen permanently; the disclosed
  position is that v1 never replays it.
- *Funds (validators).* Non-participation is not an offence: the catalogue has no liveness offence
  (ECON-04 minus the tombstoned clause (6)), "halting is a correct outcome" (`06:109`), and no rule removes
  weight (`03:527`, `10:294`). A stopping cohort therefore keeps its stake, can request exit and withdraw
  after `D_WITHDRAW` once the evidence window closes and no exposure remains (`03:286-306`, MEM-05/MEM-06),
  and pays only the opportunity cost of unearned rewards. The protocol's cost is a chain that a third of the
  stake can halt permanently at no slashable cost — a liveness exposure LIM-01's Liveness row and
  ECON-10/LIVE-05 disclose in substance ("no rule removes or re-weights any member"), though the *asymmetry*
  (the cohort can exit with its stake while the users above the checkpoint cannot) is never stated in one
  place.
- *Disclosure verdict.* LIVE-01, LIVE-05 and LIM-01 state the outcome honestly; MEM-13's tombstone states the
  wrong reason (R7-CC-03); spec/02 and MEM-15(5) still stage a replacement path (R7-CC-02).

## Is v1 implementable as written?

**Not as written — but the blockers are contradictions, not missing mechanism.** The core is implementable and
I found no unresolved security-relevant choice in it: sequencing and quorum (CONS-01–CONS-03, CONS-06,
CONS-07), locks (CONS-04), commit (CONS-05), epochs and authentication (CONS-08–CONS-10, CONS-13, CONS-14),
equivocation (CONS-11), uniqueness (CONS-12), halting (CONS-15), membership and set snapshots (MEM-01–MEM-12,
MEM-14, MEM-15), publication and the proving deadline (DA-01–DA-09), single-backend settlement (PRF-* minus
PRF-15), k-attestation withdrawal roots (L1-13), the veto (MSG-04) and the migration (MIG-*) are each
internally consistent at the level I attacked them. Two things must be fixed before an implementer can follow
the text without choosing which page to violate: (a) **R7-CC-01** — the live forced-inclusion offence in
spec/07 contradicts the tombstones and makes a correct proposer slashable, and its predicate needs a withdrawn
parameter; (b) **R7-CC-02** — spec/02's recovery-staging clauses have no implementable precondition and
contradict REC-01/INV-01 about whether history above the checkpoint can be replaced. R7-CC-03 and R7-CC-04 are
disclosure/register corrections. With those four addressed, I would call the core implementable as written.

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 1 | R7-CC-01 (a live slashable offense for the deferred forced-inclusion duty; honest proposers can be slashed) |
| High | 1 | R7-CC-02 (spec/02 still stages the deferred stall resolution as live, incl. CONS-15's "only sanctioned replacement" and CONS-12's guarantee) |
| Medium | 1 | R7-CC-03 (the permanent-halt disclosure gives a reason MEM-05/MEM-09 contradict; the real epoch barrier is unstated) |
| Low | 1 | R7-CC-04 (`W_ROOT_WAIT_MAX` and the "epoch-boundary root" wording are stale after the D-16 exit widening) |

**Strongest attack:** R7-CC-01. A user publishes their data (permissionless, D-11); an honest proposer omits
it, which `02:66`/`02:72` says is not a breach of any v1 rule; a reporter submits the signed omitting
proposal plus the recorded publication under ECON-04(6) and collects the ECON-06(5) bounty while the
proposer's stake is charged. The offence is still fully normative in a page with zero D-16 mentions, it is
predicated on CONS-01(v), FI-10–FI-13 and PRF-04(vi) — all tombstones that "MUST NOT be implemented" — and
its due point needs `FI_INCLUSION_DELAY`, which the register says MUST NOT be used. A specification cannot
both forbid an offence and define it; whichever way an implementer resolves it, v1 is wrong.

**Inside the fault model?** Yes for both Critical/High: R7-CC-01 needs one reporter, one published record and
one honest proposer's signed payload; R7-CC-02 needs no actor at all (it is normative text contradicting the
tombstones). Neither requires a broken assumption, Byzantine stake, L1 censorship or a DAO action.

**Checked, and holds (not re-listed):** the generation's five rules are coherent with a frozen generation and
no acceptance path can be satisfied by a stale one (Q1/Q2 above); REC-01/HALT-01/HALT-02/LIVE-01/LIVE-05/LIM-01
disclose the absence of a recovery path, the halt persistence and the exit guarantee accurately; MEM-15(1)
with clause (2a) plus L1-13(3) makes the exit independent of settlement progress, which resolves round 5's
exit contradiction for the settled class; the FI/L1-14/PRF-15/MEM-13/CONS-16 tombstones themselves are
correctly worded and correctly forbidden; the parallel report `round7-rollback-consistency.md` covers the
remaining page-level sweep defects (spec/01, the configHash preimage, the course, the register/index rows I
cross-reference in R7-CC-04), and I did not duplicate them.
