# Increment 04 round 5 — quotations and counts

**Reviewer:** independent adversarial reviewer, increment 4 round 5, angle quotations-and-counts. **Snapshot:** 930b1edee, extracted with git archive; comparison done on stripped-tag, whitespace-normalised text.

**Counts: Critical 0 · High 0 · Medium 0 · Low 1.**

The known quotation is verbatim, every count inside the FI rules matches the thing it counts, and PRF-04(vi) enforces the current predicate (four discharge conditions, seven byte classes, the index-order check, the re-pinned turn). The single Low is the design delta's transcription of CONS-01(v), which claims to read the clause in full but still carries the pre-round-5 text (common prefix 95 of 5451 characters).

---

## F1 — Low: the delta's CONS-01(v) reads-in-full transcription is stale by one revision

**Severity: Low.** Rationale: the delta is the design record a reader uses to reconcile the rule with the design, and its quotation claim is now false — it reproduces the round-3/4 clause body (starting "For every block h of the range, at every pre-state of h: …"), while the current CONS-01(v) begins "For every block h of the range, at every state h's own execution reaches — every pre-state of h and, when h is the range's last block, the state its body ends in: …" and carries the S-02 re-pinned turn and the four discharge grounds. No rule is affected; the normative text is self-contained and correct.

**File + rule id.** increments/04-forced-inclusion-design.md, the FI-11(4)/CONS-01(v) section (the same predicate is the per-block clause CONS-01(v) … CONS-01(v) reads, in full:) versus spec/02-consensus.html CONS-01(v).

**Assumptions.** None. **Attack trace.** None (documentation). **Fault-model verdict.** N/A. **Attacker cost.** None.

**Requirement affected.** GEN-03 / the delta's transcription fidelity.

**Measurement.** Normalised whitespace, stripped markdown backticks: the delta's quoted span is 5451 characters; the current CONS-01(v) body is longer; the two texts share a common prefix of exactly 95 characters, after which the delta continues with the old "at every pre-state of h" wording while the rule continues with "at every state h's own execution reaches". The delta contains no later transcription of the new clause (the phrase "at every state h's own execution reaches" does not occur in the delta).

**Suggested repair.** Re-transcribe the current clause in the delta, or label the quotation as the round-N text it reproduces.

**Evidence.** delta section quoted above; spec/02 CONS-01(v); normalised comparison (5451 chars, common prefix 95).

---

## Quotation audit (every claim of in full, verbatim, word for word or exactly on rule text)

1. **FI-11(4) quoting CONS-01(v) — "CONS-01(v) reads, in full:" — PASS, verified verbatim.** After stripping tags and normalising whitespace, the quoted span is **6394 characters** and is a **contiguous substring of the current CONS-01(v)** starting at the clause body; the rule's lead-in title sentence ("(v) Forced-data inclusion — the per-block order and non-omission duty, scoped to the transaction's turn.") is outside the quotation, and immediately after the quotation end ("… no new slashable offence attaches to it.") the rule continues with its review notes, not with further normative text. So the quote is the clause body, in full, and nothing normative is omitted.
2. **The delta's transcription of CONS-01(v) — FAILS (F1): 5451 characters, common prefix 95.**
3. **spec/02 "quoted verbatim from the specification at pinned commit 709fd12b" (the CometBFT rule).** The source document is not in this snapshot, so the comparison cannot be made here; the claim is not falsified, only unverifiable from the artifact under review.
4. **The delta's Appendix A claims of text kept verbatim from the preserved commit (7917ba264).** Same limitation: the preserved source is not in the snapshot, so those claims were not re-verified here; the live rules they describe were checked on their own terms instead.
5. **Other in-full occurrences** (spec/01:27, spec/02:14, spec/index 122/351/699) are statements that a rule or parameter is stated in full by its owning page — a register convention, not a quotation of one clause by another — and the index's "stated in full on exactly one page" claim is consistent with the rule-per-page layout I verified in earlier rounds.

## Count audit (every count or enumeration stated inside a rule)

- **Resolution modes: three** — FI-13(1) (exactly one of the following three modes), FI-13(1)(b), FI-13(5), FI-11(2)(4) and PRF-04(vi) all say three (executed, void, dead), and no clause says four or two. PASS.
- **Void limbs: three** — FI-13(1)(b) says one of these three limbs (over-bound; contains a byte-invalid transaction; every transaction discharged) and explicitly keeps the limbs as alternatives within one mode; the seven classes live inside the second limb, so three limbs and seven classes are not in conflict. PASS.
- **Byte classes: seven (A)-(G)** — FI-13(1)(b) enumerates (A) decode failure against the claimed frame sequence, (B) chain-id mismatch, (C) unrecoverable signature, (D) intrinsic-gas shortfall, (E) maxFeePerGas below the registered FI_MIN_EXEC_FEE_CAP, and the clause and CONS-01(v) reference (F) maxPriorityFeePerGas above the transaction's own maxFeePerGas and (G) a create transaction whose initcode exceeds the EIP-3860 cap. PRF-04(vi) names the same seven and labels them (A)-(G). PASS.
- **Discharge conditions: four** — FI-13(1)(a), CONS-01(v) and PRF-04(vi) each list nonce inequality, balance below gasLimit x maxFeePerGas + value, the sender having code at that pre-state (EIP-3607), and no block of the range at or after the turn having had room (the same remaining gas the per-block duty reads). PRF-04(vi) says a claimed discharge that fails **any one of these four conditions**. PASS. The old two-condition phrasing survives only inside the correction note that records its removal (the note quotes the removed phrase "either condition is invalid" as a leftover of the two-condition form), which is a historical annotation, not a live requirement.
- **Byte-decidable predicate requirements: five** — (2)(ii) intrinsic-gas floor, (2)(iv) signature recovery, (2)(vi) fee floor, (2)(vii) fee-market well-formedness, (2)(viii) initcode cap; PRF-04(vi) names exactly these five alongside the classes. PASS.
- **Falsifiers: eight** — F-FI-1 through F-FI-8 all exist in the snapshot and spec/10 states eight falsifiers; F-FI-7 (fee schedule) and F-FI-8 (residual outside the enumeration) are the two new ones and both are referenced by the rules they qualify. PASS.
- **FI-12's counts** (the cap, the two counts R and W, the two claims) are unchanged by the round-4 repairs and still match the walk: R = min(d(A) - c, FI_MAX_PER_BATCH) is the window the walk must resolve, W the live prefix whose gas the capacity condition bounds, and the per-block duty defers to the cap in positions per batch. PASS.

## PRF-04(vi) against the current predicate

The guest clause names the four discharge conditions with the same wording as FI-13(1)(a) and requires the guest to recompute the turn's pre-state from the batch's own execution, never from a witness-supplied position; it pins the turn by position in all the cases CONS-01(v) now states (before the transaction's own position when it appears; before the record's next appearing transaction when it does not; and the re-pinned tail case — the state immediately after the record's last earlier appearing transaction, or the pre-state before the last block's body when no earlier transaction appears — with the no-room ground read from the same remaining gas the per-block duty reads); it names the same seven byte classes and the same five predicate requirements; it keeps the index-order check (each exactly once, in increasing transaction index) for the transactions that appear, matching FI-13(1)(a), while a discharged transaction does not appear and cannot violate the order; and it rests on no claim the rules no longer make — the credit-ordering edge is stated as the disclosed residual F-FI-3, and the EIP-3607 and no-room grounds are in the discharge set, not denied. **PASS on all five points of the charge.**

## Verdict

**Clean at the bar: Critical 0, High 0, Medium 0, Low 1.** The known quotation is verbatim (6394 characters, contiguous substring, nothing normative outside it), every count inside the rules matches what it counts, and the guest clause mirrors the current predicate exactly. **Safe to ship:** yes — F1 is a delta re-transcription (or a label), not a rule edit; it can ride any copy edit.
