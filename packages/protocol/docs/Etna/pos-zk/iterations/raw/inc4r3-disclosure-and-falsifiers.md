# Increment 4 round 3 — disclosures and falsifiers after the rewrite

**Angle.** Confirm the R4R1-M-01 rewrite is real, then attack the disclosures after it: F-FI-3 accurate
for the shipped per-transaction semantics and carried wherever falsifiers are collected (spec/10, the
index, spec/09, DEFERRED.md, D-18, the course); the other falsifiers still accurate and carried; the
register matching the rules (FI-13's row, the void wording, FI_MIN_DRAIN, the units,
`L2_BLOCK_GAS_LIMIT` as a live anchored-view input, the settlement pair and MIG-02's 15/28); the course
teaching the shipped rule everywhere it describes resolution, with no surviving record-level or
"void individually" phrasing and no stale `DISCARDED` status; and no disclosure promising more than the
rules deliver — in particular the not-a-latency-guarantee headline with its conditions.

**Snapshot.** `94255e9df`; working tree at the same commit. Read first: all four `inc4r1-*` reports,
`inc4r2-*`, the current spec/04 FI-13(1)–(5), FI-11(2)(4), FI-12, spec/05 PRF-04(vi), the delta's RC-5,
`spec/09`, `spec/10`, the index and the course.

**Result: 0 Critical, 0 High, 3 Low — a CLEAN round at the bar, and the increment is safe to ship** once
the three copy-edit-grade items are fixed. The rewrite is real and total: the round-1/2 Critical is
closed in the rule, the predicate's two extensions are necessary for totality, decidable and
producer-independent, and F-FI-3 is restated correctly wherever falsifiers are collected. The three Lows
are residual wording the round-2→3 sweep missed ("void individually" in the assurance page and the
glossary, the unqualified over-bound void in four glosses, and the stale "free balance" term).

---

## The rewrite is real and the walk is total (the round-deciding check)

1. **The rule is written where it must be.** `spec/04` **FI-13(1)** now walks per transaction in the
   record's own order with stated precedence; **FI-13(2)** keeps the predicate to the record's bytes,
   registered constants and pre-state and states that ordering "enters the walk of (1) only through the
   sender's own signed transactions, never through a transaction of the producer's"; **FI-13(3)** states
   the anti-void property; **FI-13(4)** the void and mixed cases; **FI-13(5)** totality as a rule
   property. `spec/04` **FI-11(2)(4)**, **FI-12(6)** and `spec/05` **PRF-04(vi)** restate the same
   precedence, and PRF-04(vi) makes the guest recompute each turn's pre-state and reject a claimed
   discharge that fails either condition, an executable transaction that does not appear, and a claimed
   discharge of a transaction that could execute.
2. **The modes partition.** (c) dead is tested first and unconditionally; otherwise live: over-bound
   under (2)(i)–(ii) → (b); contains a transaction that can never execute from the record's own bytes →
   (b); every transaction discharged (including a zero-transaction record) → (b); at least one executes
   and every other executes or is discharged → (a). The only case in no mode is a transaction that can
   execute at its turn and is omitted, which the rule makes the proof invalid — the obligation, not a
   pin. I walked the edge cases: undecodable bytes and over-gas-bound transactions (over-bound limb),
   chain-id mismatch (byte-invalid limb), nonce behind or ahead, balance exactly at the charge (forceable,
   so it must execute), duplicate signed transactions in two records (the second discharges), pruned
   positions (always below `c`, so never in the window), and a live record's bytes always being
   retrievable while it is live (DA-05's registered relation). No hole found.
3. **The two extensions are necessary, not cosmetic.** Without the immutable-half void limb a live record
   containing a chain-id-mismatched transaction would be neither executable (unincludable) nor
   discharged (its nonce/balance may be fine) — the same unresolvable-position halt; without the
   batch-wide turn pre-state a transaction whose nonce the batch consumed elsewhere would be "required to
   appear" and could not be — invalid proofs again. Both are decidable with no producer-set input: the
   chain id is the record's own byte plus the L1-derived `l2ChainId`; the turn pre-state is the state the
   guest already reconstructs while executing the batch (PRF-06), and by FI-13(2)/(3) only the account's
   own signed transactions can move its nonce or balance. Neither opens a producer-steerable void ground:
   a record's bytes are fixed by its publisher (DA-07(3)), a byte-invalid record voids itself and imposes
   no obligation, and no nonce is consumed by it.
4. **Anti-void holds.** A producer cannot manufacture a discharge for someone else's transaction: it
   cannot move a nonce or balance without that account's signature, the environment terms (base fee,
   block gas limit, room, ordering) are removed from the predicate, and omitting an executable
   transaction invalidates the proof. The residual is exactly F-FI-3.

## INC4R3-DF-01 — Low — "void individually" survives in the assurance page and the glossary, and it contradicts the shipped mode structure (a discharged transaction is discharged; void is a position-level mode).

**File + rule id.** `spec/10-assurance.html` line 420 (the increment-04 applied note, a live spec page):
"a position with at least one execution is executed **with its discharged transactions void
individually**". `learn/glossary.html` line 130: "the proof requires every position it passes to be
resolved — executed by walking the record's transactions in the record's own order, running each that can
run at its turn and setting aside each that cannot, with at least one running and **each set-aside
transaction void individually**; or void (over a registered bound, or a live record every one of whose
transactions is set aside at its turn); or dead". `learn/glossary.html` line 148: "with at least one
running; **each set-aside transaction is void individually**. Void: the record is over a registered bound,
or it is live and every one of its transactions is set aside at its turn."

**Assumptions.** FI-13 owns resolution; its modes are position-level and mutually exclusive under the
stated precedence; a mixed position is (a) with its discharged transactions "recorded as discharged"
(FI-13(1)(a)); "void" names mode (b), not a per-transaction outcome.

**Attack trace (reader-facing).** A reader who takes "void individually" as the shipped outcome learns that
a set-aside transaction is *void* — i.e., cancelled — while F-FI-3 says it may become executable later
through the sender's own further signed transactions and the remedy is re-publication; the same glossary
entry then defines Void at the record level two clauses later, so the entry contradicts itself. In
`spec/10` the phrase sits inside the increment's own assurance summary, directly against FI-13(1)(a) —
the page an implementer reads to see what the increment changed.

**Fault-model verdict.** Not applicable: a disclosure error in non-normative summary text; the normative
rule is correct and no mode, event or proof check depends on the phrase.

**Attacker cost.** None.

**Requirement affected.** FI-13(1)(a)/(b); the F-FI-3 disclosure (10:353, delta §6.1, DEFERRED 76–81,
D-18 704–706); the course's own Void definition.

**Evidence.** `spec/10-assurance.html` line 420; `learn/glossary.html` lines 130 and 148;
`spec/04-l1-integration.html` FI-13(1)(a) ("the mixed case is resolved with the executed transactions
recorded as executed and the discharged ones recorded as discharged") and (1)(b) (void, live-only limbs).

## INC4R3-DF-02 — Low — the over-bound void is still paraphrased without the live-only qualifier in the register rows, the index and the course, although RC-5's dead-first precedence makes every record-level limb of void live-only.

**File + rule id.** `spec/09-parameters.html` line 192 (`FI_ITEM_MAX_BYTES`): "A record above it is
**void ... in every batch** and consumes no gas"; line 197 (`FI_MAX_TX_PER_RECORD`): "A record that
decodes to more is **void**". `spec/index.html` line 459: "a live record every one of whose transactions
is discharged being void (**an over-bound record is void as well**)". `learn/11-forced-inclusion.html`
line 237: "**Over a registered bound**, or live with every one of its transactions set aside at its
turn"; line 295: "if none runs, the record is void, and **so is a record over a registered bound**". The
rule is explicit the other way: FI-13(1)(b)'s limbs are all "the record at j is **live at A** and …", and
FI-13(1) says "(c) is tested first and unconditionally, so a record that is dead at A is dead whatever
its size, its contents or its discharge state, and (a) and every limb of (b) never apply to it";
FI-12(6) carries the corrected "a **live** record above the bound is void".

**Assumptions.** The register rows and the index row are descriptive glosses that must agree with the
owner rule; the precedence is normative and was introduced by RC-5 to close the dead/over-bound overlap.

**Attack trace (reader/implementer-facing).** An implementer who follows the register gloss classifies a
**dead** record that is also over-bound as *void* — which is decided from the record's published bytes,
while dead is decided from the stored `l1BlockNumber` alone. At a view where the record's blobs are past
retrievability, that reading asks the guest for bytes it cannot have, so a position the rule resolves for
free becomes unprovable — the same failure class the dead-first precedence exists to prevent — and the
mode label/event counts diverge from FI-13(1). No adversary is needed; no rule reads the gloss.

**Fault-model verdict.** Not applicable: a register/summary inconsistency; the normative rule and
PRF-04(vi) are correct, so a correct implementation is unaffected.

**Attacker cost.** None.

**Requirement affected.** FI-13(1)(b) (live-only limbs), FI-13(1) (partition), FI-12(6), the
`FI_ITEM_MAX_BYTES` and `FI_MAX_TX_PER_RECORD` rows, the index's FI-13 row.

**Evidence.** `spec/09-parameters.html` 192, 197; `spec/index.html` 459; `learn/11` 237, 295;
`spec/04` FI-13(1)(b), FI-13(1) precedence note, FI-12(6); delta RC-5 addendum ("Corrected to 'a **live**
record…' so the clause agrees with (1)(b)"). Secondary: the index's FI-13 row also omits the
immutable-half (byte-invalid) limb from its list of void grounds.

## INC4R3-DF-03 — Low — the course still says "free balance" where the rule and D-18's completed addendum fix the term as BALANCE.

**File + rule id.** `learn/glossary.html` line 131 (`Forceable`): "the sender's **free balance** there
covers the transaction's own declared maximum charge"; line 148: "the account's **free balance** there is
below gas limit × max fee per gas + value"; `learn/11-forced-inclusion.html` lines 97, 100, 212, 236,
249, 301 ("the account's free balance there", "only things that move an account's nonce or free balance",
"spend its free balance", "its nonce or free balance"). `spec/04` FI-13(2)(v) says "the sender's
**balance** at that pre-state is at least `t.gasLimit × t.maxFeePerGas + t.value`", and D-18's completed
addendum is explicit: "The discharge condition is the exact complement of the forceability condition of
FI-13(2)(v) and uses **BALANCE**, not 'free balance' … This corrects the addendum above's 'sender's free
balance' wording to BALANCE."

**Assumptions.** "Free balance" has a specific meaning elsewhere in this specification (the pool's
unreserved balance, `free_before(e)`), so the term is not a neutral synonym for an account's balance.

**Attack trace (reader-facing).** An implementer or executor reading the course could build a
reservation-aware affordability check (or expect one) where the rule tests the account's balance
directly, so the discharge/execute boundary would differ from FI-13(2)(v)/(1)(a) in exactly the
affordability cases that decide whether a transaction is discharged or must execute.

**Fault-model verdict.** Not applicable: terminology drift in course text; the normative predicate is
unambiguous.

**Attacker cost.** None.

**Requirement affected.** FI-13(2)(v), FI-13(1)(a) discharge condition; D-18's completed addendum; the
course's `Forceable` and `Resolution` entries and lesson 11's walk.

**Evidence.** `learn/glossary.html` 131, 148; `learn/11` 97, 100, 212, 236, 249, 301;
`spec/04` FI-13(2)(v); `DECISIONS.md` 715–717 and 732.

## Verified (the angle's checklist)

1. **F-FI-3 is restated accurately for the shipped semantics and carried wherever falsifiers are
   collected.** FI-13(5): "a transaction discharged at its turn may become executable later only through
   the sender's own further signed transactions, and the remedy for a record whose transactions were
   discharged is re-publication". The same statement is in `spec/10` 35, 260 and 353 ("a transaction
   discharged at its turn may become executable later only through the sender's own further signed
   transactions — the sender tops up, or a later nonce reaches it; the remedy … is re-publication;
   R4R1-M-01: discharge is objective and per transaction"), `spec/09` line 46, `DEFERRED.md` 76–81,
   D-18 704–706 and the completed addendum, the delta's §6.1 table (line 752) and its Appendix B row 15
   (line 1075, "discharge is evaluated per batch and only the sender's own further signed transactions
   can change it"), and the course (`learn/11` 210, 236, 291–295; `learn/glossary` 148;
   `learn/limitations` 54, 203–204, 329–331; `learn/09` 51, 297; `learn/01` 168, 225, 253;
   `learn/02` 260; `learn/08` 91, 407, 435, 438; `learn/index` 82). The index carries the range in
   LIM-01 and the semantics in its FI-13 row (459). The superseded sentence "a record voided in this
   batch may become forceable later" survives only as the delta's named prohibition (line 1298, "MUST NOT
   be restored") — the correct place for it.
2. **A discharge is never described as a censoring instrument.** FI-13(3) states exactly why it cannot be
   ("the only things that can move an account's nonce or balance are that account's own signed
   transactions … so a producer cannot manufacture a discharge ground for someone else's transaction"),
   FI-13(5)'s failure-mode line says "discharge is not itself a censoring instrument, because it never
   removes the duty to execute a transaction that can execute at its turn", and D-18 and the course
   repeat it. The void limbs are stated as functions of the record's immutable bytes and the record's own
   clock.
3. **The other falsifiers are accurate and carried.** F-FI-1 (capacity relation + the Open gas-limit
   schedule premise), F-FI-2 (arrivals over the drain — "open and not fixed by increment 04", with the
   guarantee's condition), F-FI-4 (expiry is a discharge, not inclusion), F-FI-5 (non-censoring L1 and at
   least one honest or rational producer) and F-FI-6 (deliberate delay past the anchor-age envelope) all
   read as the delta's §6.1 defines them and appear in `spec/10` 35, 260, 286, 353, the index 397, 526,
   528, `spec/09` 46, 196, 266, `DEFERRED.md` 60–81, D-18 665–677 and 722–733, and the course.
4. **The register matches the rules** apart from DF-02's qualifier: FI_MIN_DRAIN (09:190) still states
   the ratified form and does not claim the floor drives the advance; units are single (positions per
   batch; the per-block duty is order/non-omission only); `L2_BLOCK_GAS_LIMIT` (09:195) is a live
   anchored-view input, "NOT committed through any config preimage and no preimage enumeration changes";
   the settlement pair still rides the checkpoint record's word and MIG-02 is unchanged at 15 declarations
   and 28 free (43 sourced − 15 = 28; 258–269 + 275–277 = 15; 270–274 + 278–300 = 28); the deferral set
   reads three with the ratified membership.
5. **The course teaches the shipped rule in every place it describes resolution** — `learn/05` 200,
   `learn/08` 438, `learn/11` 55, 68, 86, 150–151, 165, 231, 260, 291–295, 309, `learn/glossary` 122,
   130, 148, `learn/index` 82, `learn/limitations` 54 — with no record-level "all/none" phrasing and no
   stale `DISCARDED` status anywhere (grep clean); the residuals are DF-01's "void individually",
   DF-02's missing "live" and DF-03's "free balance".
6. **No disclosure promises more than the rules deliver.** The not-a-latency-guarantee headline with both
   conditions (an honest or rational producer; arrivals within the forceable drain) is stated at every
   summary point (`spec/10` 35, 260, 286, 353; `spec/09` 46; `spec/01` 530, 543, 571; index 397, 526,
   584; `DEFERRED.md` 55–66; D-18 665–677; `learn/01` 168, 225, 253; `learn/02` 260; `learn/08` 124;
   `learn/09` 38, 49, 71; `learn/11` 40, 162–186, 192, 239–241, 285; `learn/glossary` 115, 130;
   `learn/limitations` 54, 191–204, 279–291, 329–341). The new totality claim is scoped to what the rule
   gives ("no published record can pin the frontier or halt settlement") and does not paper over the
   capacity premise (F-FI-1, Open), the landing premise (F-FI-5) or the unbounded wait (F-FI-2). Nothing
   claims execution rather than execution-or-discharge, and no FI state gates an exit.

## Noted, not filed

1. **The turn of a *discharged* (absent) transaction is not pinned to an anchor.** FI-13(1)(a) says the
   turn's pre-state is "after the record's own preceding transactions have executed and after every
   transaction the batch executes before that point", but for a transaction that does not appear, "that
   point" has no payload position; two implementations could anchor it differently (before or after an
   intervening transaction of the same sender). Security-neutral: only the sender's own signed
   transactions can move its nonce or balance, so the anti-void property and the "executable ⇒ must
   execute" duty hold under every reading, and a producer can already achieve the same discharge by
   omitting the sender's intervening transactions (F-FI-3's own residual). A one-clause definition (for
   example: the turn is the pre-state immediately before the record's next transaction that appears in
   the executed payload, or the end of the batch if none does) would remove implementer drift.
2. **The index's FI-13 row omits the immutable-half limb** from its list of void grounds (it names the
   over-bound and all-discharged limbs). A summary omission, not an overpromise; worth one clause beside
   the DF-02 fix.

## Ship decision

**Clean at the bar: 0 Critical, 0 High.** The per-transaction rewrite is real, total and
producer-independent, the round-1/2 Critical is closed in the rule and in PRF-04(vi), F-FI-3 and the
other falsifiers are restated and carried, and the register and course otherwise teach the shipped rule.
**The increment is safe to ship.** The three Lows are copy-edit grade (no rule, event, proof check or
fund path depends on any of them); fixing them with the ship record — or in a confirmation round if the
lead wants a second consecutive clean round on the fixed text — is recommended but not gated on a
mechanism change.
