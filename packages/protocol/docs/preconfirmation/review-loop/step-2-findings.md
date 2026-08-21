# Review Loop — Step 2 (Round 12): Verify v12 Fixes + Hunt New → Fixes in v14

**Method.** Second internal *challenge-then-respond* review loop over
[`../redesign-proposal.md`](../redesign-proposal.md) at v12 (head `d1f5193de`). Six independent
diverse-lens reviewers — two of them tasked *first* with adversarially **verifying the round-11
v12 fixes actually hold** against the real `Bridge.sol` / `Anchor.sol` / `SignalService.sol`,
then hunting for new defects; each finding put through an adversarial refuter; synthesis
deduplicated and ranked.

**Result.** 16 raw findings → 13 survived refutation → after dedup: **2 IMPORTANT
(loop-gating)** + **3 non-gating (low/note)** + refuted. The headline: **the round-11 v12 F1
bridge-recall fix does NOT hold** — verified against the deployed contract, it reopens the
cross-chain double-spend. **This was independently corroborated by the Codex review bot**, which
flagged the same `model_checker.py`/design defect (P1) on the PR at the same time. F2, F3, and
N1–N5 all **verified as holding**. **The loop does not terminate at step 2**; v14 fixes both
gating findings and the lesser items, and step 3 re-reviews.

---

## v12 fix verification (round-11 F1/F2/F3, N1–N5)

| Fix | Verdict | Note |
| --- | --- | --- |
| **F1** — §6.4 recall re-keyed on destination fate | **DOES NOT HOLD** | the "not-`DONE`" snapshot is non-terminal; reopens recall-then-deliver double-spend + a freeze horn → **R12-1** |
| **F2** — §6.8 mode pinned on materialized decision | HOLDS | commit-then-withhold seals in DEFAULT immediately; no un-sealable/un-materializable residual; pre-AC race closed |
| **F3** — default anchor `max(prev, F(N))`; §6.6(c) non-decreasing for holderless | HOLDS | total, ≥`D_anchor` deep, within freshness ceiling, non-decreasing; owned epochs keep strict advancement (minor wording residual R12-5) |
| **N1** — `H_cancel ≥ S·E+κ+margin` invariant; shared `H_toll_max` lockstep | HOLDS | seal-before-`T_exp` ordering preserved (unrelated upper-coupling residual R12-3) |
| **N2** — withdrawal gate on the equivocation-challenge horizon | HOLDS | one per-tenure horizon ≥ `Λ+margin`; serial re-open closed; watchtower-dependence stated |
| **N3** — intra-tenure MEV-spike limit of the `L_safety` match | HOLDS | "matched at the sizing epoch, re-matched each `T_max`"; spike residual + levers named |
| **N4** — §3.1 AC-censorship "may differ"; successor hard-upgrade on contract-legible instant | HOLDS | orphaned soft preconf under a parent-flip never slashable |
| **N5** — consumption-vs-evidence predicate; I6 eventual-not-timely | HOLDS | disambiguated; stale nullifier attribution in derived artifacts → R12-4 |

---

## GATING findings (IMPORTANT) — must be fixed before the loop can close

### R12-1 — §6.4 F1 re-fix is incomplete: the non-terminal "not-`DONE`" recall predicate reopens the cross-chain double-spend (and freezes the principal under the outage it serves)
**Severity: IMPORTANT (fund theft / bridge insolvency; gated behind a proving-outage disaster) · CONFIRMED · §6.4, §9, §10.4 guarantee 4, §13-S.16; corroborated by Codex P1**

Grounded against the live contracts, the v12 fix trades a *terminal* predicate for a
*non-terminal snapshot* and loses the exclusion it claims. The deployed `recallMessage`
releases the source principal only against a proof of the terminal destination `FAILED` signal
— `FAILED` and `DONE` are disjoint terminal states, so recall provably forecloses future
delivery. v12 replaces that with "`msgHash` not-`DONE` on a finalized/sealed destination Bridge"
+ carrier `refunded`. But `IBridge.Status = {NEW, RETRIABLE, DONE, FAILED, RECALLED}`, so a
never-processed message reads `NEW` (= not-`DONE`) at *any* finalized destination root;
`processMessage` is permissionless and checks only destination-`NEW` + the **permanent** source
`sendMessage` signal (append-only SignalService — never retracted); and `recallMessage` sets
only source→`RECALLED`, emitting nothing to the destination. So the attacker-chosen
**recall-then-deliver** order is fully open: outage voids the forced carrier → `refunded`;
recall proves destination not-`DONE` → L1 principal released; L2 resumes and anyone calls
`processMessage` → `DONE` → value paid on L2. Principal returned on L1 **and** value delivered
on L2 for one deposit = **bridge insolvency** (direct theft if `srcOwner == recipient`). v12's
rationale reasons only about the mirror deliver-then-recall order. Worse, the predicate cannot
be simultaneously **sound** and **live**: a *stale* destination root admits the double-spend; a
*fresh* destination root is unconstructible during a permanent proving outage (no L2 state
finalizes on L1), so the source principal is **frozen**, falsifying §9's refund bound and
§10.4's "no value is burned."

**Fix (v14):** restore genuine terminal cross-chain exclusion. Add a **destination-side
transition** that, on an L1→L2-synced proof of the forced carrier's terminal `refunded`/void
state, marks the message `FAILED` (or a new positive `CANCELLED` terminal) and emits
`signalForFailedMessage(msgHash)`; source-side recall then uses the existing, unchanged
`FAILED`-signal path, restoring `FAILED`⊥`DONE` mutual exclusion instead of a TOCTOU read. Store
`msgHash` in the forced-item nullifier at snapshot time (while the blob is retained) so the
binding is constructible. Because the destination marking still needs L2 to resume, **restate
§9/§10.4's bridge-refund guarantee as conditional on eventual proving resumption**. Update
Appendix B r9-cB1/r11-F1 and §13-S.16.

### R12-2 — §10.4 rung-3 attested-outage toll is scoped to "accepted AC," leaving forced-only/DEFAULT epochs' proof-carrying seal duties un-tolled during a systemic outage
**Severity: IMPORTANT (secondary; bounded honest-holder liveness slash) · CONFIRMED (spec gap) · §10.4 rung 3, §6.7, §5.2, §6.8 mode-pin, I5**

§10.4 rung 3 tolls proof-dependent seal deadlines/`T_exp` during an attested outage only "for
every epoch whose data availability is already established (**accepted AC**, §5.2)." But §5.2's
AC certifies only the EBC's referenced *discretionary* blob slices; a forced-only/DEFAULT epoch
(non-empty forced snapshot, no discretionary content, materialized DEFAULT per §6.8) has its
data on L1 by construction — but via the **forced-queue snapshot nullifier (§6.5), not an AC**.
The toll predicate never mentions that path, yet a forced-only seal is proof-carrying and
impossible during the outage. So during a prolonged attested outage a forced-only epoch's seal
deadline does **not** toll while its seal is genuinely un-producible — breaking the design's own
promise (§6.7) that "a holder that published every byte and could not buy a proof did not cause
anything" and the r9-A6 goal. *Caveat (honest):* the concrete slash is contingent on the
under-specified owned-forced-only missed-seal-vs-recovery-lane interaction; the toll-predicate
gap is the confirmed defect.

**Fix (v14):** broaden the §10.4 rung-3 / §6.7 toll predicate from "established by accepted AC"
to "established by accepted AC **OR** the forced-queue snapshot nullifier
(`queued→snapshotted`)," so proof-carrying forced-only/DEFAULT seals toll exactly like content
seals during attested outages; and state explicitly whether an owned forced-only epoch carries a
missed-seal duty during an outage at all.

---

## NON-GATING findings (fixed in v14, but do not gate)

- **R12-3 (LOW) — no upper coupling of `H_cancel + H_toll_max` (30 d) to blob retention
  (~18 d).** N1 added only the lower bound; under a long attested outage a CONTENT epoch tolls
  `T_exp` past its own blobs' expiry — a bounded ~18→30 d stall, neither EBC-sealable nor yet
  cancellable, self-resolving at `H_toll_max`. **Fix:** setter invariant
  make a CONTENT epoch cancellable once its blobs provably expire on L1 (the additive
  `H_cancel + H_toll_max ≤ blob_retention` bound is *infeasible* against the defaults — 10 d +
  20 d > ~18 d — since `H_toll_max` must stay large for long outages, so the blob-expiry cutoff
  is the mechanism, per DeepSeek W#4 / r12-DS4).
- **R12-4 (NOTE) — stale attributions in derived artifacts.** RESULTS.md still calls the
  consumed-xor-refunded nullifier "the §6.4 bridge-handshake nullifier"; Appendix B r9-cB1 still
  describes the abandoned v10 `refunded && !consumed` recall predicate; RESULTS.md carried
  unresolved merge markers (the in-progress v13 merge). **Fix:** relabel as "seal-vs-refund
  exclusion nullifier (§6.5)"; sync r9-cB1 to the R12-1 destination-fate predicate; resolve the
  merge.
- **R12-5 (NOTE) — the default-outcome input tuple omits the finalized L1 chain that `F(N)`
  reads.** `(chainId, epoch, index, canonical parent chain, forced snapshot)` does not list the
  finalized canonical L1 chain that `F(N)` reads; determinism is unaffected (finalized depth ≥
  `D_anchor`), a premise-completeness nit. **Fix:** add "the finalized canonical L1 chain up to
  slot ≤ `slot(T_N) − D_anchor`" to the input set.

## Correctly refuted (audit trail)
- **SR-3 (single-incident MEV sharpening of N3)** — refuted: the drift window is bounded to one
  tenure and the double-EBC variant settles L1-directly at zero latency; N3's disposition stands.

## Related: Codex review-bot findings (independent, same session)
The Codex bot posted three P1 comments on `model_checker.py` at commit `d1f5193de`, all
**checker-fidelity** gaps that corroborate the design findings above:
1. **AC-resolution branch (line 539)** — the checker sets CONTENT immediately for an accepted
   EBC; it should model *unresolved → {AC within R ⇒ CONTENT | timeout ⇒ EMPTY/forced-only}*
   (validates F2's commit-then-withhold). → v14 checker task.
2. **Withdrawal-challenge horizon (line 886)** — the checker gates withdrawal on the
   EBC-acceptance window, not the v12 N2 equivocation-challenge horizon, and has no delayed
   L2-evidence settlement action to expose a late safety cert. → v14 checker task.
3. **Strict descendant tolling (line 414)** — a decided-but-unclosed EMPTY/VOID ancestor should
   toll descendants until it *closes* (only `openEpoch` seals); the checker's effectively-open
   tolling is a documented deviation. → v14 checker task (weigh the horizon-artifact trade-off).

Codex #1 is the design-side of R12-1; #2/#3 are checker-fidelity gaps introduced by the v12
N2/decision changes not being mirrored into the committed checker.

---

## Disposition — how v14 addressed the findings

All findings fixed in **v14** (on top of the v13 conflict-merge that unioned the anarchy
content). Per-finding text is in the proposal's v14 changelog, Appendix A #38, and the
Appendix B round-12 table; summary:

| Finding | v14 change | Sections |
| --- | --- | --- |
| **R12-1** (gating) | §6.4 recall re-based on a **terminal destination-side `FAILED` mark** (L1→L2-synced proof of the carrier's `refunded` state marks the message `FAILED`; `FAILED`⊥`DONE` forecloses delivery, closing both orderings), `msgHash` stored in the nullifier, refund guarantee stated conditional on eventual proving resumption | §6.4, §9, §10.4, §6.5, §13-S.16, App. B |
| **R12-2** (gating) | attested-outage toll broadened to "accepted AC **OR** forced-queue snapshot nullifier"; owned forced-only missed-seal duty pinned | §10.4, §6.7 |
| **R12-3** | cancel-on-blob-expiry for CONTENT epochs (the additive `H_cancel + H_toll_max ≤ blob_retention` bound is infeasible against the defaults — DeepSeek W#4) | §6.7, §13-T.3 |
| **R12-4** | nullifier relabeled "seal-vs-refund exclusion nullifier"; r9-cB1/r11-F1 synced to the terminal-`FAILED` mechanism; RESULTS.md attribution updated | §6.5, App. B, RESULTS.md |
| **R12-5** | I1's default-outcome tuple lists the finalized L1 chain `F(N)` reads | I1 |
| **Codex ×3** (checker fidelity) | AC-resolution branch + mode consequence; challenge-horizon withdrawal gate + delayed-safety-settlement action; machine-checked no-descendant-seal-fault-while-lower-unclosed | `model_checker.py`, RESULTS.md — **separate follow-up commit** after the v14 design commit (not in the design diff; DeepSeek W#2) |

**Loop status after step 2: NOT terminated at review time** (R12-1 + R12-2 gating). v14 resolves
them; **step 3** re-reviews over v14 — with particular attention to the re-worked §6.4 bridge
recall (does the terminal `FAILED` mark truly close both orderings against the deployed Bridge?)
and the broadened outage-toll predicate.

---

_Round-12 review conducted 2026-08-21 by a six-lens challenge-then-respond agent workflow over
`redesign-proposal.md` v12 @ `d1f5193de`, grounded in the deployed `Bridge.sol` /
`SignalService.sol` / `Anchor.sol`; dispositions refer to v14. Raw per-agent findings and
verdicts archived in the workflow journal. Independently corroborated by the Codex review bot._
