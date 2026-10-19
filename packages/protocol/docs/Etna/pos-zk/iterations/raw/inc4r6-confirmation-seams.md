# Increment 04 round 6 — confirmation: seams, quotations and counts

**Reviewer:** independent adversarial reviewer, increment 4 round 6 (confirmation), angle confirmation-seams. **Snapshot:** e6f650541, extracted with git archive; every comparison stripped tags and normalised whitespace before measuring.

**Counts: Critical 0 · High 0 · Medium 0 · Low 1.**

Every quotation measures whole, every count inside the rules matches the thing it counts, the no-room ground is the turn's block alone in all normative carriers, and the Open convention is stated and applied. The single Low is a surviving wide form of the no-room ground in the course glossary — a carrier the round's repair list said was fixed.

---

## F1 — Low: the course glossary still states the WIDE no-room ground twice ("no block of the range at or after the turn had room")

**Severity: Low.** Rationale: the rules now scope the no-room discharge to the turn's block alone, with the sentence that a later block's room neither rescues nor condemns a transaction whose turn has passed. The glossary's Forceable and Resolution entries still say the wider form, so a reader of the course carriers learns a discharge ground the rules no longer state, and the round-6 repair list (item f: "the three course pages carrying the wide no-room form, and the glossary") is not closed.

**File + rule id.** learn/glossary.html, entries "Forceable (transaction)" and "Resolution (executed, void, dead)": "... or no block of the range at or after the turn had room to carry it — the remaining gas at that turn was below the gas limit the transaction declares ..." and "... or, at that turn, no block of the range at or after the turn had room to carry it, judged on the same remaining gas the per-block duty reads ...". The rules say the turn's block alone: FI-13(1)(a), CONS-01(v), FI-11(4)'s quotation and PRF-04(vi) ("the remaining gas, at that turn, of the block in which the turn lies was below the gas limit t declares").

**Assumptions.** None. **Attack trace.** None (course wording). A reader implementing from the glossary could make a proof reject a discharge that the rules allow, or accept one they forbid, in the one case where a later block of the range had room and the turn's block did not.

**Fault-model verdict.** N/A (carrier wording). **Attacker cost.** None.

**Requirement affected.** Course-to-rule consistency for the no-room ground; closure of round-6 item (f).

**Suggested repair.** Reword both glossary sentences to the turn's block at the turn, and add the rule's sentence that a later block's room neither rescues nor condemns.

**Evidence.** learn/glossary.html lines quoted above; FI-13(1)(a); CONS-01(v); FI-11(4); PRF-04(vi); grep of spec/** for the wide forms returns nothing.

---

## Quotation audit (measured, not read)

1. **FI-11(4) quoting CONS-01(v), "CONS-01(v) reads, in full:" — PASS, verbatim and complete.** Stripped-tag, whitespace-normalised: the quoted span is **6499 characters** and the CONS-01(v) clause body (from "For every block h of the range" to the first review note) is also **6499 characters**, and the quote is a contiguous substring of the clause. The lengths are equal, so nothing normative is omitted and nothing extra is quoted. (This is the same measurement that reported 6394 characters in round 5; the clause grew by the round-5 repairs and both sides grew together.)
2. **The design delta's transcription of CONS-01(v) — PASS.** With markdown normalisation (line-leading blockquote markers, backticks and emphasis removed) the delta's span matches the clause; the only divergences I measured were formatting artefacts, each identified at its position: bold markers around "is at its turn at that state and forceable there" (prefix 275), italic markers around "executable" (prefix 2174), and underscore-bearing identifiers such as FI_MIN_EXEC_FEE_CAP being altered by an over-aggressive emphasis strip (prefix 2490). Neither divergence is a text difference, so the round-5 F1 is closed. Measured with blockquote and backtick stripping only, the delta's span is 6504-6538 characters depending on the emphasis handling, i.e. the clause body plus its formatting markers.
3. **spec/02's CometBFT quotation at pinned commit 709fd12b and the delta's Appendix A "kept verbatim" claims** are against a source that is not in this snapshot; still not falsified, still not verifiable from the artifact, and reported as such rather than counted.
4. **Other "in full" occurrences** (spec/01, spec/02's page statement, spec/index's register convention) are statements that an owner page states a rule or parameter in full — not one clause quoting another — and the index's "exactly one page" convention matches the layout.

## Count audit (each against the thing it counts)

- **Resolution modes:** three, in FI-13(1), FI-13(1)(b), FI-13(5), FI-11(2)(4) and PRF-04(vi). PASS.
- **Void limbs:** three (over-bound; byte-invalid transaction; every transaction discharged), with the classes nested in the second limb. PASS.
- **Byte classes:** seven (A)-(G); the "(A)-(G)" enumeration is referenced consistently in spec/02, spec/04, spec/05 and spec/09, and PRF-04(vi) names all seven. PASS.
- **Discharge conditions:** four — nonce, balance, EIP-3607 sender-has-code, no-room at the turn — and PRF-04(vi) states "any one of these four conditions". PASS.
- **Byte-decidable predicate requirements:** five — (2)(ii) intrinsic gas, (2)(iv) signature recovery, (2)(vi) fee floor, (2)(vii) fee-market form, (2)(viii) initcode cap — named by PRF-04(vi) and CONS-01(v). PASS.
- **Falsifiers:** F-FI-1 through F-FI-8, and spec/10 says "eight falsifiers". PASS.
- **FI parameter set:** the live names including FI_MIN_EXEC_FEE_CAP appear in spec/02, spec/04, spec/05 and spec/09 consistently; the withdrawn spelling FI_PREFIX_CAP stays a name tombstone. PASS.

## The no-room ground in every carrier

Narrow (the turn's block alone) in FI-13(1)(a) ("no block of the range at or after the turn had room" does not appear; the clause reads the turn's block), CONS-01(v), FI-11(4)'s quotation, PRF-04(vi), spec/09 and the index; the delta explicitly lists the superseded forms and says they MUST NOT be restored. The wide form survives only in the two course-glossary sentences of F1. The repair's substantive half — that a later block's room neither rescues nor condemns a transaction whose turn has passed — is stated in the rules.

## Open falsifier convention

The convention is stated and applied where a reader needs it: spec/10's assurance rows separate "Open (carried and sharpened)" rows from "Live, conditional, and not a latency guarantee" rows, F-FI-7 and F-FI-8 are carried as the two new Opens with their falsifiers named at the rules they qualify (FI-13(1)(b)(E)'s fee-schedule premise and the residual outside the enumeration), and the delta's corrections record the superseded forms with a MUST-NOT-RESTORE instruction. I found no place where an Open is presented as a guarantee or a disclosed limit as an operative requirement.

## Verdict

**Clean at the bar: Critical 0, High 0, Medium 0, Low 1.** This is the second consecutive round with no Critical and no High on my angle; every quotation measured whole (FI-11(4) at 6499 = 6499 characters; the delta's transcription whole modulo formatting), every count matches, the no-room ground is uniform in the rules, and the Open convention is distinguishable from the live guarantees in the text. **Safe to ship:** yes. F1 is a two-sentence glossary copy edit and does not hold the increment.
