# Review Loop — Step 3 (Round 13): Verify v14 Fixes Against the Deployed Contracts → Fixes in v15

**Method.** Third internal *challenge-then-respond* review loop over
[`../redesign-proposal.md`](../redesign-proposal.md) at v14 (the state squash-merged as
`0f29cae34`). Six independent diverse-lens reviewers — tasked *first* with adversarially
**verifying the round-12 v14 fixes hold against the deployed `Bridge.sol` / `IBridge.sol` /
`SignalService.sol` / `LibForcedInclusion.sol` / `Anchor.sol`**, then hunting new; each finding
put through an adversarial refuter; synthesis deduplicated, ranked, and decided loop
termination.

**Result.** 9 raw findings → 7 survived refutation → after dedup and adversarial verification:
**0 confirmed CRITICAL/IMPORTANT**, 3 MEDIUM + 3 NOTE/LOW. The finder-rated "high" §6.4
`msgHash`-binding finding was **downgraded to MEDIUM** on verification: the v14 terminal-`FAILED`
fix closes the primary double-spend (verified sound against `Bridge.sol`), and the residual is
bounded, disaster-scoped **griefing** (a forced bridge delivery can be cancelled by a mis-declared
`msgHash`), not theft, halt, unrecoverable state, or a client/circuit fork.

**Loop-severity trend (monotone convergence):** round 11 → **3 IMPORTANT**; round 12 → **2
IMPORTANT**; round 13 → **0 IMPORTANT**, medium/note only. The synthesis lead's formal decision
was **LOOP TERMINATES** (no critical/important survives). Nonetheless every medium/note residual
had a clear, sound fix, so v15 closes all of them and a round-14 pass confirms convergence rather
than declaring victory with real must-fixes outstanding.

---

## v14 fix verification (r12-1 … r12-5), grounded in the deployed contracts

| Fix | Verdict | Note |
| --- | --- | --- |
| **r12-1** §6.4 terminal destination-side `FAILED` mark | **HOLDS (primary); PARTIAL (binding)** | recall-then-deliver double-spend closed (`recallMessage` needs terminal `FAILED`; `FAILED`⊥`DONE`; `processMessage` accepts only `NEW`). Residual: the stored-`msgHash` binding sub-claim → **FINAL-1** |
| **r12-2** attested-outage toll broadened to the forced-queue nullifier | **HOLDS** | no honest holder slashed for an un-producible forced-only seal; a malicious holder can only toll a duty it has already made data-available for |
| **r12-3** cancel-on-blob-expiry for CONTENT | **HOLDS (feasibility/griefer-safety); PARTIAL (overlap)** | mechanical, not attacker-triggerable. Residual: reopens a seal/cancel overlap → **FINAL-2** |
| **r12-4** §6.5 nullifier relabel | **HOLDS** | (minor stale-text → FINAL-6) |
| **r12-5** I1 finalized-L1 tuple | **HOLDS** | inclusion-independent at finalized depth |

Model-checker additions faithfully model the design, with two documented non-gating fidelity
caveats (`safety_settle_late` has no outage guard → FINAL-3 checker horn; the false-slash
invariant shares `_effectively_open` → FINAL-5).

---

## Findings and v15 dispositions

### FINAL-1 — §6.4 stored-`msgHash` binding was unverifiable on L1 (medium, must-fix)
**§6.4 / §6.5 / §13-S.16 · CONFIRMED**

`IForcedInclusionStore.ForcedInclusion` stores only `{feeInGwei, blobSlice}` and L1 cannot read
blob contents; the only actor that reads the blob is the seal circuit, which runs on the
*consumed* path, never the *refunded* path §6.4's recall uses. So a `msgHash` "stored at
snapshot" is a submitter **declaration** L1 cannot check — an attacker can declare a *victim's*
pending `msgHash H_v` on a junk-blob forced item; on the ~18-day blob-expiry refund path the
destination mark sets `H_v → FAILED`, foreclosing the victim's legitimate L1→L2 delivery
(`processMessage` needs `NEW`). Bounded griefing/DoS, disaster-scoped (the attacker cannot
summon the outage), **not theft** — the terminal `FAILED`⊥`DONE` exclusion still blocks
recall-then-deliver. A latent theft horn needs a *second* omission (a missing `NEW`-guard
allowing `DONE→FAILED` overwrite).
**v15 fix:** the `msgHash` is made **L1-authoritative** — computed on-chain by
`hashMessage(message)` at enqueue from the calldata `Message` (atomic `sendMessage`+enqueue),
never submitter-declared, so it is content-bound and a submitter can cancel-grief only *its own*
message; the destination `FAILED` mark carries an explicit **`status == NEW` guard**. §13-S.16
restated with content-bound-`msgHash` and `NEW`-guard conformance vectors.

### FINAL-2 — r12-3 blob-expiry cancellation reopened the seal/cancel (I7) overlap (medium)
**§6.7 / §5.2 / I7 · CONFIRMED**

**Verifying** a pre-computed CONTENT seal reads no blob (§5.2: seal verification is SNARK
verification against the AC-recorded commitments; the blob is only the prover's witness), so a
proof computed while blobs were retained stays acceptance-eligible after expiry — r12-3's
"a CONTENT epoch whose blobs are gone can never seal" is true for *computing*, false for
*verifying*. With cancellation enabled at blob-expiry but seals valid until the later tolled
`T_exp`, the interval `[blob_expiry, T_exp)` re-admits the seal-vs-cancel order-race I7 forbids.
**v15 fix:** the effective expiry is single-valued **`T_exp_eff = min(tolled T_exp,
blob_slot+retention)`** — seals valid strictly before it, cancellation at/after, no overlap;
the justification is replaced with the `min()`-cutoff argument (§6.7).

### FINAL-3 — the equivocation-challenge horizon did not toll for the outage that blocks the accuser (medium)
**§8 / §10.4 · CONFIRMED**

§10.4 rung-3's attested-outage toll covered seal deadlines and `T_exp` but not the §8
equivocation-challenge horizon; settling a preconf-vs-record safety cert is proof-dependent, so
an attested outage covering the untolled horizon shuts out an honest watchtower and the
equivocator escapes `L_safety` (the sole ETH theft deterrent). Opportunistic-not-on-demand
(the attacker cannot summon the outage) and narrows an already-conceded watchtower-dependent
residual, hence medium.
**v15 fix:** the challenge horizon joins the seal deadline and `T_exp` on the shared
`H_toll_max` tolled clock; it tolls during attested outages (costless — withdrawals are already
frozen then), preserving the watchtower's full provable window once proving resumes (§8, §10.4).
*Checker follow-up (non-gating):* gate `safety_settle_late` on `not s.outage` and model the
withdrawal-freeze so `inv_withdraw_gated` exercises the outage case.

### FINAL-4 — §6.8 mode enumeration read as exhaustive over the anarchy lane (note)
**§6.8 / §9 · CONFIRMED (doc)** — scoped the `EBC`/`DEFAULT` enumeration to owned + at/after-cutoff
unowned epochs; an in-phase unowned epoch is EMPTY-`PENDING` and seals via the distinct
§9/§13-S.19 anarchy artifact — cross-referenced.

### FINAL-5 — the no-false-slash invariant is checked for the adopted rule, not derived from I4 prose (note)
**§7.1 / I4 · CONFIRMED (doc)** — added the normative §7 descendant-tolling predicate (tolls behind
a genuine SEQ/CONTENT/UNRESOLVED block, not behind a proof-free-closeable EMPTY/VOID prefix);
RESULTS.md wording noted as a checker-doc follow-up.

### FINAL-6 — Appendix A #34 stated the abandoned v10 recall predicate (low)
**Appendix A #34 · CONFIRMED (doc)** — annotated as superseded by #37/#38 (the terminal `FAILED`
mark).

## Correctly refuted (audit trail)
- **Checker LIVENESS-suppresses-SEAL / commit-then-withhold masks `inv_bond_nonneg`** — refuted:
  the AC `UNRESOLVED` branch and typed seals model the withheld-data epoch as forced-only/DEFAULT
  sealable, not stuck; RESERVE0 exercised to its designed worst case.
- **r12-5 added finalized-L1 to I1 but not I6/§6.8/App-C** — refuted: determinism unaffected
  (finalized depth ≥ `D_anchor`), a premise-completeness nit at most.

---

## Disposition — how v15 addressed the findings

All six findings fixed in **v15** (design-doc edits, since this is a design proposal). See the
proposal's v15 changelog, Appendix A #39, and the Appendix B round-13 table.

| Finding | v15 change | Sections |
| --- | --- | --- |
| FINAL-1 | L1-authoritative `hashMessage`-computed `msgHash` + `NEW`-guard | §6.4, §6.5, §13-S.16 |
| FINAL-2 | `T_exp_eff = min(T_exp, blob_slot+retention)` | §6.7 |
| FINAL-3 | challenge horizon tolls on the shared `H_toll_max` clock | §8, §10.4 |
| FINAL-4 | §6.8 mode-scope + §9 anarchy cross-reference | §6.8 |
| FINAL-5 | normative §7 descendant-tolling predicate | §7 |
| FINAL-6 | Appendix A #34 marked superseded | App. A |
| checker note | non-gating fidelity follow-up (documented) | RESULTS.md |

**Loop status after step 3:** round 13 found **0 critical/important** — the loop has effectively
converged (monotone severity decline 3→2→0). v15 closes the residual medium/note items; **step 4
(round 14)** runs one confirmatory pass. If step 4 also finds no critical/important, the loop is
formally closed.

---

_Round-13 review conducted 2026-08-21 by a six-lens challenge-then-respond agent workflow over
`redesign-proposal.md` v14 (merged as `0f29cae34`), grounded in the deployed Bridge / SignalService
/ ForcedInclusion / Anchor contracts; dispositions refer to v15. Raw per-agent findings and
verdicts archived in the workflow journal._
