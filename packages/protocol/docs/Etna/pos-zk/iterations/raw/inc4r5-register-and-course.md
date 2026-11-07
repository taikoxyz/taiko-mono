# Increment 4 round 5 — the register, the disclosures and the course

**Angle.** Every live FI name registered with a unit, an owner rule and a tag; `FI_MIN_EXEC_FEE_CAP` and
the class list carried in the register and the index; F-FI-1…F-FI-8 accurate, carried everywhere
falsifiers are collected and each still Open; the course teaching the shipped rule throughout (four
set-aside grounds, dead-first live-only void, the credit route and its honest limit, the
not-a-latency headline with its condition, the falsifier list through F-FI-8) with no review identifiers,
no "free balance", no "void individually" and no stale record-level phrasing; the migration budget exact
and the settlement pair riding the checkpoint record; and no disclosure promising more than the rules
deliver. Round charge: verify every "in full"/"verbatim" quote claim by stripped-tag normalised comparison
and every count or enumeration against the thing it counts.

**Snapshot.** `930b1edee`; working tree at the same commit. Read first: all `inc4r3-*`/`inc4r4-*`
reports, then spec/02 CONS-01(v), spec/04 DA-07/FI-10–FI-14/L1-08, spec/05 PRF-04(vi), spec/09, spec/10,
the index, DEFERRED.md, D-18's addenda, the delta's RC-5…RC-8, and the course.

**Result: 0 Critical, 0 High, 2 Low — a CLEAN round at the bar; the increment is safe to ship** after one
two-line index/register sweep. The quote claims are both 100% verbatim; the class, mode, limb, discharge
and relation counts all match what they count; the course is swept; the register's fee-floor row is
complete. The two Lows are summary enumerations that the round-4/5 additions did not reach: the FI set
lists omit `FI_MIN_EXEC_FEE_CAP`, and the index's LIM-01 range stops at F-FI-7.

---

## Round charge 1 — the "in full"/"verbatim" quote claims, measured

Method: strip HTML tags and entities, markdown blockquote markers (`>`), code spans and emphasis, normalise
whitespace and rule-id spacing (`FI-13 (1)(a)` → `FI-13(1)(a)`), then measure the longest verbatim prefix
of the source clause present in the quoting text.

1. **`spec/04-l1-integration.html` FI-11(4), "CONS-01(v) reads, in full:" — TRUE, 10 178 / 10 178
   characters (100%).** The quote reproduces CONS-01(v) from "For every block h of the range" to the
   clause's closing review note verbatim.
2. **The delta §2, "`CONS-01(v)` reads, in full:" — TRUE, 10 178 / 10 178 characters (100%).** The delta's
   line-400 note records that this quotation was repaired this round (it previously stopped at the
   R4R4-NR-01 note and restated the rest outside the quote), and the current copy matches the clause
   exactly.
3. **The delta's change-list row "FI-10 'One register' … kept verbatim" — a provenance descriptor, not a
   clause-to-clause quotation, and its substantive claim holds; noted, not filed.** Against the pinned
   `7917ba264`, the sentence matches through "The forced-data record is the publication record of DA-07:"
   and then diverges: preserved "one register, one identity, no separate queue and no 'forced' flag";
   revived "the same one register, the same identity, the same entry point, and no 'forced' flag", plus an
   added "no register, no queue, no escrow, no bond and no fee" sentence. The identity/no-flag property is
   kept; the wording is not. The row is a difference-table disposition ("kept", as opposed to re-derived),
   so I do not grade it as a false quotation — flagging it here because the charge asked for every such
   claim to be measured.

## Round charge 2 — counts and enumerations against what they count

- **Three modes** (executed, void, dead) — `FI-13(1)` states "exactly one of the following three modes"
  and lists three ✓; the index 459 and 10:35/259/420 say three ✓.
- **Three limbs of void** — `FI-13(1)(b)` says "one of these three limbs" and lists over-bound,
  byte-invalid, all-discharged ✓.
- **Seven byte classes (A)–(G)** — `FI-13(1)(b)` enumerates A–G without a number; the index 459 says
  "the seven classes" and lists all seven (decode failure, chain-id mismatch, unrecoverable signature,
  intrinsic-gas shortfall, fee cap below `FI_MIN_EXEC_FEE_CAP`, `maxPriorityFeePerGas > maxFeePerGas`,
  oversized initcode) ✓. "The fifth byte class (E)" is a positional label and correct ✓.
- **Four discharge conditions** — FI-13(1)(a) lists nonce, balance, sender-with-code (EIP-3607) and
  no-room ✓; PRF-04(vi) names all four ("MUST accept the discharge only if one of the following holds at
  that turn: … nonce …; or … balance …; or the sender has code …; or no block of the range at or after the
  turn had room") ✓; the index 459 lists four ✓; the course says "the other three set-aside grounds"
  after the nonce ✓.
- **Six registered FI relations** — 09:200 lists six and its note accounts for them as four added plus one
  strengthened (the sixth preserved) ✓; the index's "the four envelope relations" refers to the four added
  ✓.
- **Eight falsifiers F-FI-1…F-FI-8** — the delta §6.1 has eight rows with F-FI-7 and F-FI-8 "Open"
  (lines 1011–1012); 10:286 ("F-FI-1…F-FI-8") and 10:353 (all eight, each described); 09:46 (F-FI-1,
  F-FI-3, F-FI-4, F-FI-6, F-FI-7, F-FI-8 plus F-FI-2/F-FI-5 as the headline conditions); DEFERRED.md
  109–140 ("falsifiers F-FI-1–F-FI-8"); D-18 781–815 ("the set runs to F-FI-8"); the course learn/11
  211–269 and limitations 220 ✓. **The index's LIM-01 row is the one exception (INC4R5-RC-02).**

## INC4R5-RC-01 — Low — the FI family's two set enumerations omit the new `FI_MIN_EXEC_FEE_CAP`, although the register row, the measurement line, the index's FI-13 row and the assurance page all carry it.

**File + rule id.** `spec/09-parameters.html` line 96 (change-order note): "No longer withdrawn: the
forced-inclusion set (`FI_MAX_PER_BATCH`, `FI_ITEM_MAX_BYTES`, `FI_INCLUSION_DELAY`, `FI_RECORD_GAS_MAX`,
`FI_MAX_TX_PER_RECORD`, `FI_ANCHOR_MAX_AGE`, `L2_BLOCK_GAS_LIMIT`) and the capacity relations are live
again … **with the new `FI_MIN_DRAIN`** and the four envelope relations" — two new names exist now, and
only one is listed. `spec/index.html` line 553 (parameter map): "The forced-inclusion set
(`FI_MAX_PER_BATCH` — positions per batch, `FI_MIN_DRAIN`, `FI_ITEM_MAX_BYTES`, `FI_INCLUSION_DELAY`,
`FI_RECORD_GAS_MAX`, `FI_MAX_TX_PER_RECORD`, `FI_ANCHOR_MAX_AGE`, `L2_BLOCK_GAS_LIMIT`) and the
registered relations" — eight names, no fee cap. `FI_MIN_EXEC_FEE_CAP` appears in the index only at line
459 (the FI-13 row) and in `spec/09` only at lines 46, 194, 195 and 267; the register row itself is
complete: "wei per gas (the unit of a transaction's declared `maxFeePerGas`) … not forceable under
FI-13(2)(vi) and … the byte-invalid void ground of FI-13(1)(b)(E) … Open premise (F-FI-7) … unmeasured
(Open premise: F-FI-7)", with owner rules and the measurement clause at 267.

**Assumptions.** The change-order note and the parameter map are the register's and the index's
enumerations of the live parameter names; a live parameter must appear in them (the standing rule that the
register and the index move with the specification).

**Attack trace (reader/implementer-facing).** An auditor enumerating the live FI parameters from 09's
change-order note or the index's parameter map would not see the fee floor, would not know it is
unmeasured with an Open premise, and could conclude the family has no fee dimension — the exact dimension
whose absence was review round 4's Critical F1. The rule text, the row, the measurement line and the
assurance page are correct, so a correct implementation is unaffected.

**Fault-model verdict.** Not applicable: a register/index summary omission; no rule, proof check or fund
path reads either list.

**Attacker cost.** None.

**Requirement affected.** PARAM-01 registrations and the FI-10–FI-14 registration; FI-13(1)(b)(E)/
(2)(vi); F-FI-7's Open status as registered.

**Evidence.** `spec/09-parameters.html` 96 and 195 (row) and 267 (measurement);
`spec/index.html` 553 and 459; `spec/10-assurance.html` 286, 353. Fix: add `FI_MIN_EXEC_FEE_CAP` (with
"the new" applying to both names) to 09:96's and the index 553's set lists.

## INC4R5-RC-02 — Low — the index's LIM-01 row stops at F-FI-7 and omits F-FI-8, which every other falsifier collection carries.

**File + rule id.** `spec/index.html` line 528 (LIM-01): "including the live inclusion obligation's limits
and the **F-FI-1…F-FI-7** falsifiers (F-FI-2, F-FI-4 and F-FI-7 open, not fixed; F-FI-7 is the fee floor's
Open schedule premise …)". D-18 mandates the wider range — "therefore runs **F-FI-1–F-FI-8** wherever it is
enumerated (the `FI_MIN_EXEC_FEE_CAP` row of 09, FI-13, LIVE-04 and LIM-01 of 10, and DEFERRED.md §1)" —
and `spec/10` line 286 ("F-FI-1…F-FI-8") and line 353 (all eight), `DEFERRED.md` 109–140, the delta's
§6.1 rows and the course (learn/11 260–269, limitations 220) all carry F-FI-8 as Open. The index mentions
F-FI-8 only in its FI-13 row (459).

**Assumptions.** The index's LIM-01 row is one of the collections the falsifiers must be carried in (it
names the range and the open subset); D-18's wording names 10's LIM-01/LIVE-04 and DEFERRED §1 but the
standing rule extends the same currency to the index.

**Attack trace (reader-facing).** A reader of the index's limitations register believes the enumeration
residual was closed or never existed; the same reader is told in 10 and the course that an execution-
validity rule outside the seven classes is carried Open as F-FI-8. The index is the artifact a reviewer
uses to enumerate what is disclosed, so the gap is a disclosure debt, not a rule issue.

**Fault-model verdict.** Not applicable (index summary; all normative carriers are correct).

**Attacker cost.** None.

**Requirement affected.** LIM-01's content; D-18's F-FI-8 mandate; the index's role as the
falsifier enumeration.

**Evidence.** `spec/index.html` 528 vs 459; `spec/10-assurance.html` 286, 353; `DEFERRED.md` 139–140;
`DECISIONS.md` 807–815; delta §6.1 F-FI-8 row (1012); `learn/11` 260–269. Fix: "F-FI-1…F-FI-8", and add
F-FI-8 to the open subset with its one-line meaning.

## Verified (the angle's checklist)

1. **Every live FI name is registered with a unit, an owner rule and a tag.** 09:189–200: `FI_MAX_PER_BATCH`
   (positions per batch), `FI_MIN_DRAIN` (positions per accepted batch), `FI_ITEM_MAX_BYTES` (bytes; the
   PRF-07(0) batch payload, pinning S-03), `FI_INCLUSION_DELAY` (L1 blocks), `FI_RECORD_GAS_MAX` (gas; now
   carrying the intrinsic-gas floor of class (D)), `L2_BLOCK_GAS_LIMIT` (gas per L2 block; anchored view,
   no preimage), `FI_MIN_EXEC_FEE_CAP` (**wei per gas**, owner FI-13(1)(b)(E)/(2)(vi), tag
   "unmeasured (Open premise: F-FI-7)"), the FI capacity relation, `FI_MAX_TX_PER_RECORD`, the FI
   registered-relations row and `FI_ANCHOR_MAX_AGE` (three relations, F-FI-6) — each tagged, each naming
   its owner clause, with `FI_PREFIX_CAP` still the withdrawn spelling only. No row invented.
2. **F-FI-1…F-FI-8 accurate, carried and Open.** F-FI-1 (capacity + gas-limit schedule premise), F-FI-2
   (arrivals over the drain; "open and not fixed"; the guarantee's condition), F-FI-3 (the credit-ordering
   edge, nonce-vs-balance asymmetry, a credit never discharges), F-FI-4 (expiry, not inclusion), F-FI-5
   (non-censoring L1 + honest or rational producer), F-FI-6 (deliberate delay past the anchor envelope),
   F-FI-7 (the fee floor's schedule premise) and F-FI-8 (the enumeration residual) — all eight stated as
   the delta defines them and carried in 10 (35, 260, 286, 353), 09 (46, 195, 267), DEFERRED (60–140),
   D-18 (665–677, 781–815), the delta (§6.1, Appendix B) and the course; the only gap is the index range
   (RC-02).
3. **The course teaches the shipped rule throughout.** The four set-aside grounds are enumerated (nonce,
   balance, sender-with-code, no-room — learn/11 385–388); dead-first and the live-only void limbs
   (learn/11 75–102, 175, 202, 244–248, 308–310, 332); the block-validity order rule (learn/11 192;
   learn/09 124); the credit route with its honest limit — a credit before the turn rescues and the
   transaction must run, one after cannot, a credit never sets aside, only the nonce is out of a
   producer's reach, the balance can be moved by anyone, no producer can put code at another account's
   address, and the room ground is the one ground a producer's own blocks reach (learn/11 120–130, 380–395;
   learn/01 168–171; learn/limitations 199–203); the not-a-latency headline with both conditions
   (learn/11 204–218, 284–285; learn/limitations 53–58; learn/09 51–53); F-FI-7 and F-FI-8 (learn/11
   253–269; learn/limitations 220). Hygiene: **no review identifiers** in `learn/` (the `M-01`/`T-02`
   matches are `LIM-01`/`HALT-02`), **no "free balance"**, **no "void individually"**, **no record-level
   "all/none" phrasing**, no stale `DISCARDED` status. Round 4's SD-01 and SD-02 are closed.
4. **The migration budget is exact and the settlement pair still rides the checkpoint record.**
   08:273 — the checkpoints map holds "the ten L1-07 fields … the four packed `uint64` fields —
   `l1BlockNumber`, `lastAcceptedBatchTime`, `settledCount` and `anchoredL1Block` — complete one 32-byte
   word, so the pair consumes no gap slot and no per-height mapping is added"; the arithmetic is unchanged:
   15 declaration slots (258–269, 275–277) of 43 sourced (258–300), 28 free (270–274, 278–300).
5. **No disclosure promises more than the rules deliver.** The guarantee is stated as exclusion per unit
   of the censor's L1 spending, conditional on an honest or rational producer and arrivals within the
   forceable drain; the fee floor's premise is Open as F-FI-7 and the enumeration residual as F-FI-8, both
   stated rather than denied; the no-room ground is disclosed as the one producer-reachable ground
   (FI-13(3), the course) rather than smoothed over; the credit-ordering edge is the disclosed residual
   F-FI-3; the deadline remains "an upper bound on how long a record may remain outstanding, not a promise
   that it is included before it"; and no FI state gates an exit.

## Ship decision

**Clean at the bar: 0 Critical, 0 High.** The quote claims are verbatim complete (10 178/10 178 in both
carriers), the counts all match their referents, the register's fee-floor row and the class list are
complete, the course is fully swept, the migration budget is unchanged, and no summary overstates the
mechanism. **The increment is safe to ship.** The two Lows are a two-line sweep — add
`FI_MIN_EXEC_FEE_CAP` to the 09 change-order note and the index parameter map, and extend the index's
LIM-01 range to F-FI-8 — with no rule, proof or fund path depending on either.
