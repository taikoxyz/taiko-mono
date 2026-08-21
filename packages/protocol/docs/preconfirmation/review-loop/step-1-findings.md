# Review Loop — Step 1 (Round 11): Multi-Agent Adversarial Review of v11 → Fixes in v12

**Method.** First internal *challenge-then-respond* review loop over
[`../redesign-proposal.md`](../redesign-proposal.md) at v11 (head `b58112b0b`). Six independent
diverse-lens adversarial reviewers (liveness/DoS; fund-safety/theft; invalid-state/consensus;
economics/incentives; deep-correctness of the v10/v11 additions; cross-artifact consistency)
each produced their strongest findings; **every finding was then put through an adversarial
verifier prompted to refute it** against the actual text and contracts; a synthesis pass
deduplicated and ranked the survivors. Extra scrutiny was directed at the least-reviewed v10/v11
additions.

**Result.** 23 raw findings → 18 survived refutation → after dedup: **3 IMPORTANT
(loop-gating)** + **5 non-gating clusters** + 5 correctly-refuted. All three IMPORTANT defects
sit in the newest text (the §6.4 bridge handshake and the §6.8 default-derivation rule); none
reached CRITICAL (each gated behind a precondition — a disaster horizon, a self-inflicted
withhold, or an anarchy-onset boundary — and the deployed L2 anchor gate skips rather than
reverts). **The loop does not terminate at step 1**; v12 fixes every gating and non-gating
finding, and step 2 re-reviews.

---

## GATING findings (IMPORTANT) — must be fixed before the loop can close

### F1 — §6.4 terminal-cancellation recall keyed on the forced-item nullifier, not the message's destination fate
**Severity: IMPORTANT (funds) · CONFIRMED · §6.4, §6.5, §13-S.16**

The v10 handshake unlocked the source principal on proof that the *forced item* reached
`refunded && !consumed`. Grounded in `Bridge.sol`, this is wrong two ways off one root cause:
- **Alternate-delivery double-spend.** `processMessage` is permissionless and the source
  `sendMessage` signal exists regardless of the forced path, so the same `msgHash` can be
  delivered normally (destination `→ DONE`) while a redundant forced copy that could not seal
  during an outage voids (`→ refunded`); a nullifier-keyed recall then releases a principal
  already delivered. "Mutually exclusive by construction" held only for execution via *that
  item's own seal*, never alternate delivery of the same message.
- **Binding gap.** L1 stores only fee + blob slice and the nullifier records
  `queued→snapshotted→{consumed|refunded}` + payer, never `msgHash`; the (item ⇒ `msgHash`)
  mapping lives only in the blob, and refund fires at blob expiry (~18 d) *after* the retention
  duty (`H_cancel` + margin) lapses. Nullifier-keyed recall is therefore either unconstructible
  (principal frozen — contradicting "always recall") or, if it drops the binding, lets an
  attacker recall an unrelated locked message against any refunded item.

**Fix (v12):** re-key recall on the **message's destination fate** — a caller-supplied
`msgHash` (held source-side in `NEW`) proven **not-`DONE` on a finalized/sealed destination
Bridge**, conjoined with the carrier's `refunded` terminal state so its own seal can no longer
deliver. Exclusion restated as executed-*anywhere*-vs-recalled; the caller-supplied `msgHash`
dissolves the binding gap. Conformance-test obligation kept in §13-S.16.

### F2 — §6.8 mode-pin makes a commit-then-withhold epoch unsealable → self-triggered ~10-day stall
**Severity: IMPORTANT (liveness) · CONFIRMED · §6.8, §5.1, §5.2, §3.1**

§3.1 accepts an EBC on (i) well-formed + (ii) registered-key signature + (iii) unconsumed
one-shot — availability is *not* required for acceptance. §6.8's body said "a DEFAULT-mode seal
for an epoch that *has an accepted EBC* is invalid." A holder can commit a *valid content* EBC
(accepted), over an epoch with a non-empty forced snapshot, then withhold the blobs: the AC
times out → discretionary content materializes EMPTY, but the forced items must still flow (I6)
→ forced-only, which needs a DEFAULT seal — forbidden by the mode-pin, while the EBC-mode seal
is unconstructible (no AC, bytes never opened). The epoch is unsealable in either mode and
stalls to `T_exp` (~10 days) for one `L_live` + termination — a fresh instance of the r4b-H4
class the ladder and `T_exp` were built to close. (The explicit-empty / invalid-EBC horn was
correctly *refuted* — §5.1/§6.8-intro already route those to DEFAULT.)

**Fix (v12):** pin the derivation mode on the **materialized CONTENT/EMPTY decision** (§5.2),
not on "an accepted EBC exists": CONTENT (accepted AC) ⇒ EBC mode; every EMPTY/forced-only
materialization — absent, invalid, explicit-empty, **and commit-then-withhold** ⇒ DEFAULT mode;
cancellation re-resolutions ⇒ DEFAULT. The pre-AC content-drop race the clause guarded is
handled directly by "no seal of either mode before the availability decision materializes."

### F3 — §6.8 default anchor's "advancement by construction / same §6.6 machinery" is false and non-total
**Severity: IMPORTANT (consistency/liveness) · CONFIRMED · §6.8, §6.6(c), I1, App. C**

With `E = 32` slots and `D_anchor = 32` slots, the v11 default anchor for epoch `N+1` is
`slot(T_{N+1}) − 32 = slot(T_N)`. A content predecessor `N` that fresh-anchors commits
`A_N ∈ [slot(T_N), slot(T_N)+4]`, so §6.6(c)'s **strict**-advancement demand
(`slot(T_N) > A_N`) is false at the boundary; the "by construction / verified by the same §6.6
machinery" claim is provably wrong there, and either reading forks (circuit enforces (c) ⇒
boundary seal unconstructible → stall at exactly the anarchy-onset case §6.8 exists to protect;
circuit exempts default epochs ⇒ the text is false). The naive "block *at* slot
`slot(T_N)−D_anchor`" is also non-total (that slot may be empty). Severity moderated from HIGH
after grounding: `Anchor.sol:182` *skips* rather than reverts a non-advancing checkpoint and
consecutive default epochs catch up +32/epoch — but the internal contradiction in load-bearing
v11 text is unambiguous.

**Fix (v12):** default anchor = `max(previous non-empty epoch's anchor, deepest canonical L1
block whose slot ≤ slot(T_N) − D_anchor)` — total on empty slots, ≥ `D_anchor` deep, and
non-decreasing by construction. §6.6(c)'s *strict* advancement is relaxed to **non-decreasing
for default (holderless) epochs** (no holder to game the value). I1 amended so its "only input
is the EBC's committed content" clause is scoped to the EBC case and agrees with I6 on
default-epoch inputs; App. C class-D anchor row updated. Content→default-boundary and
missed-slot vectors added to §13-S.18.

---

## NON-GATING findings (fixed in v12, but did not gate)

- **N1 (medium) — no setter invariant `H_cancel ≥ S·E + κ + margin`.** The model checker
  already warns `CANCEL_LAG < S_TICKS` disables every seal before it can mature — the same
  halt-everyone-by-misconfiguration class §6.6 closes for `freshness_ceiling` as a mechanical
  setter invariant, yet `H_cancel` stayed a tuned value. **Fix:** setter invariant added (§6.7)
  and moved into the checked-constraint discipline; seal-deadline and `T_exp` tolling pinned to
  share the `H_toll_max` budget in lockstep so their ordering cannot invert (§10.4).
- **N2 (medium/low) — preconf-vs-record accusation↔withdrawal-gate under-specified both ways.**
  Over-accusation: serial re-open (open, wait `Λ` for timeout, re-open) freezes an honest
  ex-holder's withdrawal indefinitely under a "no in-flight verdict" gate. Under-accusation:
  the variant is watchtower-dependent, so with no accuser the gate releases `L_safety`. **Fix:**
  gate on a **single per-tenure equivocation-challenge horizon** (sized ≥ `Λ + margin`, = the
  ≥2-week floor), not "any open verdict"; state watchtower-dependence explicitly; recommend the
  §13-T.12 bonded accusation (§8).
- **N3 (medium) — intra-tenure MEV spike exceeds the value-fixed `L_safety`.** I9 forbids a
  mid-tenure re-size, so a spike above the sizing-epoch bound makes equivocation transiently
  profitable. **Fix:** qualify "match"/"nets at most" to "matched at the sizing epoch,
  re-matched each `T_max`"; name the spike residual and its two §13 closure levers (§8, §11.2).
- **N4 (medium) — AC censorship makes the materialized outcome differ from (not lag) the
  information-final one; successor exposure unspecified.** **Fix:** §3.1 "may lag" → "ordinarily
  lags… may differ under AC censorship"; the successor's **hard**-preconf upgrade keyed on the
  **contract-legible** materialization, so an orphaned soft preconf under a parent-flip is never
  slashable equivocation; folded into the §11.5 residual (§3.1, §5.2).
- **N5 (low, precision) —** "second distinct *accepted* EBC" oxymoron → one-shot *consumption*
  (i+ii+iii) vs *equivocation evidence* (i+ii+byte-distinct) disambiguated (§3.1, §8); §6.7
  "re-resolves empty/forced-only" → "re-resolves empty, forced items re-queue intact"; I6
  "always flows" → "eventual, not timely (out of scope §12)"; RESULTS.md stale "v10" title +
  scope line added noting §6.8/DEFAULT/clock-capacity are header-determinism properties for the
  §13-S.18 vectors, not the state-machine checker.

## Correctly refuted (audit trail)
- **block-count-spill vs due-time membership** — the double-dimensioned `B_max ≤ E` budget with
  deterministic spill is consistent with the due-time snapshot rule; no `>E`-blocks packing.
- **single-epoch-MEV framing** — subsumed by the sharper surviving N3 (intra-tenure drift); the
  single-epoch reading misreads the `Λ×`-per-epoch sizing.
- **explicit-empty/invalid-EBC mode-unconstructibility horn** — §5.1/§6.8-intro route those to
  DEFAULT; only the data-unavailable (commit-then-withhold) horn survived, as F2.
- **clock-capacity vs re-queue-at-front packing `>E` blocks** — `inv_forced_order` +
  deterministic spill keep every epoch ≤ E blocks across cascades.
- **`H_toll_max` (20 d) > blob retention (18 d) falsifies bound 4** — past blob expiry the
  designed outcome is void-with-refund (§9), a different rule from cancellation re-queue;
  tolling defers the exit, it does not extend retention.

---

## Disposition — how v12 addressed the findings

All three IMPORTANT findings and all five non-gating clusters are **fixed in v12**; see the
proposal header changelog, Appendix A #36, and the Appendix B round-11 disposition table for
the per-finding text, and the section anchors above. Summary of where each landed:

| Finding | v12 change | Sections |
| --- | --- | --- |
| F1 | recall re-keyed on the message's destination fate (`msgHash` not-`DONE` + carrier `refunded`) | §6.4, §13-S.16 |
| F2 | derivation mode pinned on the materialized decision; "no seal before availability materializes" | §6.8 |
| F3 | default anchor = `max(prev, deepest ≤ slot(T_N)−D_anchor)`; §6.6(c) non-decreasing for holderless epochs; I1 scoped | §6.6, §6.8, I1, App. C |
| N1 | `H_cancel ≥ S·E + κ + margin` setter invariant; shared `H_toll_max` tolling | §6.7, §10.4 |
| N2 | withdrawal gate on a single equivocation-challenge horizon; watchtower-dependence stated | §8 |
| N3 | "match" qualified to sizing-epoch; spike residual + closure levers named | §8, §11.2 |
| N4 | §3.1 "may differ"; hard-upgrade on contract-legible instant; orphan not slashable | §3.1, §5.2 |
| N5 | consumption-vs-evidence predicate; §6.7 wording; I6 eventual-not-timely; RESULTS.md scope | §3.1, §6.7, §8, I6, RESULTS.md |

**Loop status after step 1: NOT terminated** (three IMPORTANT findings were present). v12
resolves them; **step 2** runs a fresh multi-agent review over v12 — with particular attention
to the just-changed §6.4/§6.8/§8 text — and the loop terminates only when a round yields no
critical/important finding.

---

_Round-11 review conducted 2026-08-21 by a six-lens challenge-then-respond agent workflow over
`redesign-proposal.md` v11 @ `b58112b0b`; dispositions refer to v12. Raw per-agent findings and
verdicts archived in the workflow journal._
