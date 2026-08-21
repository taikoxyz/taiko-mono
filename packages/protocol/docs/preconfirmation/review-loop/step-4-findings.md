# Review Loop — Step 4 (Round 14): Confirmation Pass over v15 → **LOOP CLOSED**

**Method.** Fourth (confirmation) *challenge-then-respond* review loop over
[`../redesign-proposal.md`](../redesign-proposal.md) at v15. Five diverse-lens adversaries — each
tasked *first* with adversarially **verifying the v15 round-13 fixes against the deployed
`Bridge.sol` / `IBridge.sol` / `SignalService.sol` / `LibForcedInclusion.sol` /
`IForcedInclusionStore.sol`**, then hunting for any new critical/important defect and for
regressions introduced by the v15 edits; each finding through an adversarial refuter; synthesis
decided loop closure.

## DECISION: **LOOP CLOSED**

**Zero findings survived; zero gating.** No confirmed CRITICAL or IMPORTANT (high) design defect
remains. The loop's severity converged **monotonically**:

| Round | New critical/important | Outcome |
| --- | :---: | --- |
| 11 (step-1) | **3 IMPORTANT** | fixed → v12 |
| 12 (step-2) | **2 IMPORTANT** | fixed → v13 merge + v14 (corroborated by the Codex bot) |
| 13 (step-3) | **0** (3 medium + 3 note) | fixed → v15 |
| 14 (step-4) | **0** | **loop closed** |

Three internal rounds plus two external review bots (Codex corroborating r12-1; DeepSeek on the
checker) and this confirmatory pass all agree: **3 → 2 → 0 → 0 → closed.**

---

## v15 FINAL-1/2/3 fixes — verified to HOLD against the real code

- **FINAL-1 (§6.4/§6.5/§13-S.16 — L1-authoritative `msgHash` + `NEW`-guard) — HOLDS.** Grounded
  in `Bridge.sol`: `hashMessage` is `pure` (`keccak256(abi.encode("TAIKO_MESSAGE", _message))`)
  and cheaply on-chain-computable; `sendMessage` overwrites `message_.from = msg.sender`,
  `message_.id = nextMessageId++`, `message_.srcChainId = block.chainid` **before** computing the
  hash, so a griefer **cannot** reproduce a victim's `msgHash` — the third-party cancel-grief is
  closed, only the caller's own locked message is cancellable. The `NEW`-guard is genuinely
  load-bearing: `_updateMessageStatus` reverts *only* on same-status writes, so without the guard
  a `DONE → FAILED` overwrite would be unblocked (the latent theft horn) — the guard closes it.
  `processMessage`/`recallMessage` both check `Status.NEW`; `FAILED`⊥`DONE` is a true terminal
  exclusion; `SignalService` is append-only. The added L1-computed-`msgHash` is correctly declared
  new required state (additive to the deployed `{feeInGwei, blobSlice}` struct); the atomic
  `sendMessage`+enqueue is a sound, constructible path; the proving-resumption-conditional recall
  is correct (`recallMessage → _proveSignalReceived` needs a synced L2 checkpoint).
- **FINAL-2 (§6.7 — `T_exp_eff = min(tolled T_exp, blob_slot+retention)`) — HOLDS.** A single-valued
  cutoff with a strict-before / at-after partition at one instant is overlap-free by construction
  for both the normal and the pre-computed-proof case (the blob-expiry term forecloses a proof
  that stays *verifiable* after blob expiry). Forced-only/DEFAULT interaction is coherent; the
  `min()` preserves the seal-deadline↔`T_exp` ordering under lockstep `H_toll_max` tolling (a
  same-instant partition, invariant to where the tolled seal deadline sits). No new edge.
- **FINAL-3 (§8/§10.4 — challenge horizon tolls on shared `H_toll_max`) — HOLDS.** The equivocator
  can no longer run out an untolled clock; no honest-ex-holder harm (withdrawals already frozen
  during the attested window); no griefer exploit (tolling requires an independent outage
  attestation a holder can never self-label); I3's proof-free floor still fires when `H_toll_max`
  exhausts.

**FINAL-4/5/6 doc items — internally consistent** (§6.8↔§9 mode-scope; the §7 normative
descendant-tolling predicate matches `inv_no_seal_fault_behind_blocking` exactly; Appendix A #34
annotated as superseded). **Cross-artifact sanity — clean:** Appendix A #35–#39 coherent, the
r10/r10H lines distinct, version stamped v15, no numbering/reference regression, 24 mutants all
present and caught.

---

## For the record (non-gating; does NOT block closure)

- **NOTE — checker-fidelity follow-up (tracked, §13-T.10):** `simulation/model_checker.py`'s
  `safety_settle_late` action carries no `s.outage` guard and the withdrawal-freeze is unmodelled,
  so `inv_withdraw_gated` is exercised only outage-free; the v15 §8/§10.4 challenge-horizon toll
  (which prevents the outage-escape) is **normative in the proposal** (which governs per the
  header's normative-precedence rule) but not yet mirrored in the checker. Explicitly non-gating —
  no safety result depends on it; recorded here, in the step-3 findings, and in Appendix B's
  "r13 checker note". The RESULTS.md / docstring version strings were synced to v15 in this
  revision.

---

## Loop closure summary

The internal challenge-then-respond review loop the user requested has **run to closure**: it
began at round 11 (the first internal round after the rounds 1–10 external reviews), iterated
through rounds 12–14 plus two external bots, and each round's fixes were verified by the next
round against the deployed contracts. The severity of *newly discovered* defects fell
monotonically to zero and stayed there across a dedicated confirmation pass. No critical or
important design defect remains in v15.

Full per-round records: [`round9-consolidated-review.md`](round9-consolidated-review.md) (rounds
1–9), [`round10-anarchy-content-review.md`](round10-anarchy-content-review.md) (round 10, owner),
[`step-1-findings.md`](step-1-findings.md) (round 11), [`step-2-findings.md`](step-2-findings.md)
(round 12 + Codex/DeepSeek), [`step-3-findings.md`](step-3-findings.md) (round 13), and this file
(round 14). Residual pre-implementation work is the enumerated §13-S Phase-A spec and §13-T
tuning items — the design record is converged; those are the implementation-phase deliverables.

---

_Round-14 confirmation conducted 2026-08-21 by a five-lens challenge-then-respond agent workflow
over `redesign-proposal.md` v15, grounded in the deployed Bridge / SignalService / ForcedInclusion
/ Anchor contracts. Empty survivor set; loop closed._
