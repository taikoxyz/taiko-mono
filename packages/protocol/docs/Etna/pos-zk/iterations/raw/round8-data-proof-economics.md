# Round 8 — the data path, proof soundness and economics: final pass

**Reviewer angle.** The D-11 data path (carried / referenced publication, proving deadline), proof
soundness and the single-proof settlement policy, the k-attestation withdrawal root and its funding, the
reward pool's free-balance decomposition, the fee-vault reconciliation, and D-8/D-9 — on the complete v1
core of D-16. Targets: `spec/04-l1-integration.html` (DA-07..DA-10, L1-05/06/07/08/09/11, MSG-02),
`spec/05-proof-statement.html` (PRF-01..PRF-14) and `spec/07-economics-slashing.html`; cross-checked
against `spec/03` MEM-15, `spec/08` MIG-02, `spec/09`, `spec/10`, the index and `learn/`. Read first:
`iterations/08-freeze.md`, `DEFERRED.md`, and the four `iterations/raw/round7-*.md` reports.

**Snapshot.** `fb67df660` (branch `etna-pos-zk`). The working tree is `71b4996f1`; `git diff --stat
fb67df660 HEAD` shows only `iterations/08-freeze.md`, so the rules reviewed are the frozen snapshot's.

**Method.** The specification is the authority; repair citations, pills and closing notes are claims, not
evidence. The four D-16 deferrals are not reported as defects; I checked that their absence is disclosed
and that no live rule reads a tombstoned name. Round-7 findings are re-attacked, and two that the freeze
records as closed are shown below to be open.

**Fault-model key.** Inside = reachable by any account inside the stated assumptions without a
cryptographic break, malicious governance, key compromise or code bug. Outside = needs ≥ 1/3 Byzantine
stake, a stall, a bad upgrade or an implementation bug.

**Counts: 0 Critical, 0 High, 3 Medium, 3 Low.** No finding is inside the fault model as an attack; the
three Mediums are implementability/register gaps and the three Lows are a dead release condition, an
interface-completeness gap and a disclosure/consistency gap. The v1 core itself survives this pass: the
referenced binding, the proving deadline, the single-proof settlement disclosure, the k-attestation root
and its funding, the pool's exactness invariant, the fee vault and D-8/D-9 all hold as written (see
"Checked and holds").

---

## R8-DPE-01 — Medium — the referenced path still has no derivation source for `daMode`: L1-05 row 17 demands a tx-derived value, but the accepting transaction carries neither the payload nor the blobs (round-7 R7-DPE-06, not closed).

**Rule / missing rule.** `spec/04` **L1-05 row 17**: "`daMode` … 1 = CALLDATA, 2 = BLOB, 3 =
CALLDATA_AND_BLOB; **derived from which arguments/blobs are present**, not from a submitter field", and
the table preamble requires tx-derived values to be recomputed from the transaction and to "ignore any
submitter-supplied copy". On the referenced path the accepting transaction carries neither `_data`
payload nor blobs (**DA-08(2)**) — the hashes come from the record (**DA-08(3)**) — and **DA-08(1)**
requires the record's `daMode` to equal the statement's. `LandInput` still says "`uint8 daMode; // must
equal the derived mode, else DataModeMismatch()`". **Missing rule:** the referenced-path source for
`daMode` (necessarily the record — a value the submitter selects by choosing the record, which needs an
explicit exception to "ignore any submitter-supplied copy"). Secondary, same class: DA-03's blob index
`i` ranges over `[blobIndexStart, blobIndexStart + n)` and DA-03(iii) derives `z_i` with `uint16(i)`,
but DA-07(3)'s record identity does not commit `blobIndexStart`, so on the referenced path the absolute
index is not recoverable from the record and the convention the contract must use is unstated.

**Assumptions.** D-11's referenced path is shipped; the record's `daMode` is a publisher claim
(DA-07(4)); `daMode` is a journal/public input (PRF-02).

**Attack trace (implementability, no adversary).**
1. Implement row 17 literally: no blobs are present in a referenced landing, so the derived mode is
   CALLDATA, and the check against a record with `daMode = BLOB` reverts every referenced landing —
   although L1-04 promises any valid `(data, proof)` pair can land.
2. Or take the mode from the record: the row and its preamble are then violated (the record is chosen by
   the submitter), and two conforming implementations disagree about what the contract "derives".
3. The challenge-index limb: a contract iterating the record's list positionally and a prover deriving
   `z_i` from the publication transaction's absolute blob index produce different transcripts for the
   same record, so the proof fails against that Inbox although both sides followed the text.

**Fault-model verdict.** Not applicable: a specification gap (liveness/R13), no adversary and no
assumption failure. The freeze records all round-7 Mediums as closed; this text is unchanged from
`296f44b54` (`git diff` shows no edit to row 17, DA-08 or `LandInput`).

**Attacker resources and cost.** None. The cost is a conforming implementation being unable to ship the
referenced path without inventing a rule.

**Requirement / decision affected.** D-11's referenced path; L1-04; L1-05 row 17 and its preamble;
DA-03(iii); DA-08(1)(2); R13.

**Evidence.** `spec/04-l1-integration.html` L1-05 row 17, the table preamble, DA-03 preamble and (iii),
DA-08 (1)(2)(3), `LandInput`; `spec/05` PRF-02 `daMode` field.

---

## R8-DPE-02 — Medium — the (5)(d) epoch freeze has no specified trigger or entry point, and `Alloc(e)` is computed from the pool balance at the freeze transaction, so the epoch's reward is a function of when (and whether) someone calls it, not of L1 state alone.

**Rule / missing rule.** `spec/07` **ECON-02(5)(c)**: "Claims for epoch e open only after
`evidenceClose(e)` ( ECON-07 ), when the epoch's allocation is fixed and its participant set and
participating stake are frozen (5)(d)". **(5)(d)**: "the staking contract MUST compute and store both at
the freeze … the freeze MUST write the epoch's fixed amounts, its outstanding reservation and `frozenAt`
in one step". **(5)(e)**: "`Alloc(e) = floor(ALLOC_VAL_PPM · free_before(e) / 1_000_000)` … computed from
the pool's free balance and fixed at the freeze of (5)(d)", and "`Alloc(e)` MUST be fixed before the
epoch's first claim". **Missing rule:** who or what performs the freeze, whether it is permissionless, and
by when it must happen — a whole-spec grep for `freeze` finds no epoch-freeze entry point (only MIG-02's
migration `freeze()`). Because L1 cannot read a past balance, `pool_before(e)` can only be the balance
at the freeze transaction, so the amount is fixed at the caller's chosen instant; and
`free_before(e) = pool_before(e) − reserved_before(e)` also depends on which *later* epochs have already
frozen, since their reservations are subtracted first.

**Assumptions.** `evidenceClose(e)` is a time predicate ( ECON-07(1)); the freeze is a state transition
the contract must be told to perform; `P(e)` is defined by participation bits written at or before
`evidenceClose(e)`, so a late freeze must still exclude later bits (storage/timestamps an implementer must
invent).

**Attack trace (ordering/timing, no cryptographic assumption).**
1. **No trigger.** An implementation must invent the entry point. If it is not permissionless, a single
   actor gates every epoch's reward — discretion that R11's objective-reward requirement forbids.
2. **Dilution race.** Epoch e's close passes; its freeze is not called. Epoch e+1's close passes and
   anyone calls `freeze(e+1)` first, reserving `Alloc(e+1) + ProvingShare(e+1)` from the common balance.
   When `freeze(e)` finally executes, `Alloc(e)` is computed on the reduced `free_before(e)`, so e's
   validators are paid less than they would have been, through no fault or choice of their own.
3. **Inflation.** Holding `freeze(e)` until a sweep arrives raises `pool_before(e)` and therefore
   `Alloc(e)`; the first mover among e's participants captures the difference for the whole epoch.
4. **Denial by inaction.** If no one calls it, epoch e has no allocation at all: its participants are
   never paid (no claim exists), and the ETH stays free for later epochs.

**Fault-model verdict.** Inside as an ordering property — any account can call a permissionless freeze,
and the dilution/inflation branches need no assumption failure. It does not break the pool's exactness
invariant (no ETH is promised twice); it makes the *amount* allocated to an epoch depend on an
unspecified race, which is why it is a defect rather than a disclosure.

**Attacker resources and cost.** One L1 transaction for the freeze, plus the opportunity cost of
delaying one's own claim. A validator of a later epoch is the natural diluter; a validator of e is the
natural early-freezer.

**Requirement / decision affected.** R11 (objective rewards); D-8; ECON-02(5)(c)(d)(e); ECON-07(1);
PARAM-01 (the trigger and its timing are unregistered); R13.

**Evidence.** `spec/07` ECON-02 lines 165–171, 172–215, 220; ECON-07(1); `spec/09` rows `Alloc(e)`,
`allocRecord[e]`, `reserved_before(e)`, `free_before(e)`; whole-spec grep for `freeze` (only MIG-02's
migration `freeze()`).

---

## R8-DPE-03 — Medium — the attestation reward and the landing/attestation split of the proving share are not registered in 09, although ECON-02(5)(e), L1-11 and L1-11's own closing note require or claim they are.

**Rule / missing rule.** `spec/07` **ECON-02(5)(e)** now funds the attach proofs: "the recorded allocation
policy MUST name withdrawal-root attestations among the proving work the share covers … **The split of the
share between landing work and attestation work is fixed by that recorded policy and is unmeasured (09)**."
`spec/04` **L1-11**: "The attestation reward … is fixed by the recorded allocation policy of ECON-02
clause 5 that funds withdrawal-root attestations", with the identity `ledger_after = ledger_before −
attestRewardPaid`; its closing note says "the new attestation reward is **registered as unmeasured**".
**Missing rule:** a PARAM-01 row for the attestation reward (name, unit, owner, derivation) and a row for
the split. 09 registers `REWARD_QUOTE` for landing (line 118) and the pool terms, but a grep for
`attest` in 09 returns only the deferred heartbeat/aggregation rows and the `K_PROOF_BACKENDS` row, and
nothing for the split; PARAM-03's unmeasured table covers only "who pays for the attach proof" as an Open
willingness-to-pay item.

**Assumptions.** PARAM-01: "Every parameter has exactly one registered spelling … registered with unit,
owner, derivation and tag", and "a value L1 hashes that the guest never committed to" class of mismatch is
the register's to prevent; the allocation policy "is recorded in the L1 staking contract's storage as one
policy record, written by the activation transaction" (ECON-02(5)(e)).

**Attack trace (register, no adversary).** The activation transaction must write the policy record; two of
the quantities the policy must fix have no registered name, so the policy record, the client and the
evidence for L1-11's `attestRewardPaid` cannot reference the same object — the exact R13 failure the
register exists to prevent. The claim in L1-11's closing note ("registered as unmeasured") is unsupported
by 09.

**Fault-model verdict.** Not applicable (register completeness). No funds move.

**Attacker resources and cost.** None.

**Requirement / decision affected.** PARAM-01/PARAM-03; R13; D-8; L1-13(5); L1-11.

**Evidence.** `spec/07` ECON-02(5)(e) line 220; `spec/04` L1-11 lines 447–473; `spec/09` lines 118,
131–136, 196, 256 (grep `attest`, `split`, `proving share`).

---

## R8-DPE-04 — Low — the pool reservation's release condition is unreachable under floor payouts: the epoch's rounding remainder is permanently reserved and the epoch never leaves `reserved_before`.

**Rule / missing rule.** `spec/07` **ECON-02(5)(a)**: "the epoch leaves `reserved_before` when its
outstanding amount reaches zero". **(5)(d)**: `outstanding(e) = (Alloc(e) − Σ payout(v,e)) +
unTransferredProvingShare(e)`, `payout(v,e) = floor(Alloc(e) · effStake(v,e) / PS(e))`, with
`Σ_v payout(v,e) ≤ Alloc(e)`. Floor division leaves a remainder of up to `|P(e)| − 1` wei that no claim
can pay (each `(epoch,index)` is claimable once, at a fixed amount), so after every legitimate claim the
epoch's outstanding is the dust, never zero. **Missing rule:** release of the rounding remainder (e.g.,
when the epoch's claim set is exhausted), or a statement that the dust stays reserved by design.

**Assumptions.** ECON-02(5)(c)'s once-per-index claim and its "paid from the epoch's own fixed allocation
only"; the required checked view `pool_balance = free + Σ_e outstanding(e)`.

**Attack trace.** None adversarial. Consequence: the release event the rule names is dead text; the set
over which `reserved_before(e)` and the decomposition view are taken grows by one epoch forever, so any
implementation that computes them by iterating the per-epoch records (as the definition literally reads)
becomes uncallable over time, and a bounded implementation needs a running total plus a dust rule no rule
states. Exactness is unaffected: the dust is never re-promised, so no ETH is allocated twice.

**Fault-model verdict.** Not applicable (normative condition that cannot occur; R13).

**Attacker resources and cost.** None.

**Requirement / decision affected.** ECON-02(5)(a)(d); the checked decomposition; R13.

**Evidence.** `spec/07` ECON-02(5)(a) line 155, (5)(d) lines 196–213; `spec/09` rows `outstanding(e)`,
`reserved_before(e)`, `free_before(e)`.

---

## R8-DPE-05 — Low — round-7 exit-and-boundary F8 is not closed: L1-08 still exposes no per-family attestation view, so no caller can discover which attestations are missing.

**Rule / missing rule.** `spec/04` **L1-08**'s withdrawal surface is unchanged: `attestWithdrawalRoot(uint64
_height, bytes32 _programImageId, bytes calldata _proof)` and `withdrawRootAt(uint64 _height) returns
(bool designated, uint8 familyCount, bytes32 statementHash)`. **L1-13(3)** requires the call to reject a
second attestation from an already-attesting family (`FamilyAlreadyAttested`) and records each family.
**Missing rule:** a view returning the attesting families (or a per-family boolean) for a height. Without
it a contract or a prover deciding which proof to produce or buy cannot enumerate what is missing; the only
recourse is to simulate one call per candidate route and absorb `FamilyAlreadyAttested` reverts, and
`WithdrawalRootAttested` serves off-chain indexers only.

**Assumptions.** Round-7 report `round7-exit-and-boundary.md` F8 (Low) is the same defect; 08-freeze.md
records all six round-7 Lows as closed, but the interface text is unchanged.

**Attack trace.** None (delivery friction on the exit path). A user or their agent cannot tell how many
further attestations are needed for their own signal beyond the raw count, nor which families.

**Fault-model verdict.** Not applicable (interface completeness; no safety effect).

**Attacker resources and cost.** None.

**Requirement / decision affected.** L1-08's completeness; L1-13(3); STATUS-11; D-16's exit.

**Evidence.** `spec/04` L1-08 withdrawal surface and error list; L1-13(3); `iterations/raw/round7-exit-and-boundary.md` F8.

---

## R8-DPE-06 — Low — the two payout paths out of the single L1-11 ledger are unranked draws on one balance, the policy's mandated split is unenforced, and the attestation race is undisclosed.

**Rule / missing rule.** `spec/04` **L1-11**: `rewardPaid = min(REWARD_QUOTE, proverReward_before +
msg.value)` on landing and `attestRewardPaid ≤ ledger_before` on attestation, both debits of the same
ledger; `spec/07` **ECON-02(5)(e)** says "the split of the share between landing work and attestation work
is fixed by that recorded policy". **Missing rule:** any bound tying either cumulative payout to that
split, and an L1-10-style disclosure for the attestation path. L1-10 openly accepts that a proof seen in
the mempool can be landed first and "the mitigation available to provers is private orderflow or
bundling"; there is no analogous statement that a copied attach proof can be submitted first, and unlike
the landing race the loser's retry reverts with `FamilyAlreadyAttested`, so the work is lost without even
a gas-refund attempt.

**Assumptions.** Both rewards are best-effort and never gate (L1-11, L1-13(5)); the recorded policy is
unmeasured for the split (ECON-02(5)(e)); REWARD_QUOTE is registered (09:118) and the attestation quote is
not (R8-DPE-03).

**Attack trace.** A burst of valid attestations (each real proving work) can consume the ledger before a
batch lands; the batch still lands with `rewardPaid = 0`. Conversely a landing searcher takes the balance
an attach prover expected, and the attach prover whose proof is copied loses the reward with no way to
resubmit for that height. No promise is broken (both paths are explicitly best-effort), which is why this
is a Low disclosure/consistency finding rather than a defect in the conservation identity.

**Fault-model verdict.** Inside as a same-block ordering property (any account), but bounded by the
ledger and disclosed as best-effort; no soundness or solvency consequence.

**Attacker resources and cost.** One landing transaction's gas (front-running a mempool proof), or one
valid attestation's proving cost for the legitimate submitter.

**Requirement / decision affected.** D-8; L1-11's two identities; ECON-02(5)(e); L1-13(5); R11; the
disclosure duty L1-10 discharges for landing.

**Evidence.** `spec/04` L1-10 and L1-11 lines 442–473; `spec/07` ECON-02(5)(e) line 220;
`spec/09` line 118 (`REWARD_QUOTE`), line 256 (attach-proof willingness to pay, Open).

---

## Checked and holds

1. **The referenced binding is as strong as the carried one.** DA-07(5) keeps the element-wise
   `_blobVersionedHashes[i] == blobhash(_blobIndexStart + i)` check, the length equality, the non-zero
   range check and the "no third form" rule, so the recorded hashes are the publication transaction's own
   consensus-verified blob entries; DA-08(3) keeps the EIP-4844 point-evaluation call with the recorded
   versioned hash, and the precompile-less variant stays rejected as unsound; DA-08(1) binds the record's
   range, mode, commitment and hash list to the statement, and PRF-07 keeps the whole-blob commitment and
   the decode-and-root check. Only same-transaction equality/availability is lost, and it is disclosed
   (DA-08(4), DA-05, DA-09). Re-attacked: zero / short / long / empty hash lists, blobs outside the
   range, record-identity recomputation, re-orged publication transactions (DA-08(5)) — each rejected.
2. **The proving deadline's consequence is coherent and disclosed.** DA-09(1) fixes `deadlineBlock` at
   publication, keeps `T_PROVE_DEADLINE` inside blob retention and usable; DA-09(2) makes expiry a
   re-publication escape and never an admission gate on the range; DA-09(3) states plainly that if nobody
   re-publishes, settlement stalls and v1 has no replacement path. The withdrawn
   `FI_INCLUSION_DELAY < T_PROVE_DEADLINE` relation is correctly retired in 09.
3. **Single-proof settlement and its weakest-backend consequence are disclosed.** PRF-09: "settlement
   soundness is the soundness of the weakest approved backend … a bridge-theft-class failure", with the
   deferral named; repeated at PRF-14(4)(b), L1-13(6) and `learn/05-the-proof.html`. The withdrawal-root
   policy is stated as an exception, not a repair.
4. **The k-family count is enforced on L1 and the attestation work is funded.** L1-13(3) verifies one
   proof per call against the *recorded* statementHash under a route whose image is in the epoch's accepted
   set and whose family has not already attested (`FamilyAlreadyAttested`), L1-09 records the accepting
   route's `backendFamily` as the first attestation, and the family tag is the unit of distinctness
   (registration honesty remains A-GOV-1, disclosed). The funding is now real: ECON-02(5)(e) names
   withdrawal-root attestations among the work the proving share covers, L1-11 admits `attestRewardPaid`
   as the ledger's second and only other debit, payment is best-effort and never gates, and MEM-15(2b)
   records the funded-proving-market assumption with its falsifier. R7-DPE-08/F1 is closed — apart from
   the unregistered rate (R8-DPE-03) and the unranked ledger (R8-DPE-06).
5. **The pool's free-balance decomposition is exact, no ETH is promised twice, and claim/transfer ordering
   is genuinely independent.** `Alloc(e)` and `ProvingShare(e)` are taken on
   `free_before(e) = pool_before(e) − reserved_before(e)`; the freeze reserves both; a claim reduces its
   epoch's outstanding by exactly the ETH paid and a permissionless transfer zeroes the un-transferred
   share, so `balance = free + Σ outstanding` is preserved by every discharge and every inflow, and
   `balance ≥ Σ outstanding` always holds, so any discharge is payable whichever order it executes in.
   Re-derived for: two epochs freezing in either order, delayed claims, unclaimed allocations, a delayed
   proving-share transfer, an empty participant set (allocation released at the freeze), and a sweep
   arriving between freezes — no double promise. The two residual gaps are the freeze *trigger*
   (R8-DPE-02) and the unreachable dust release (R8-DPE-04).
6. **Fee-vault reconciliation (PRF-06 F1–F4) is exact, including the zero-balance no-op sweep.**
   ECON-02(7)(b) now requires `msg.value == 0` for a zero-outstanding-balance call and reverts on any
   nonzero amount, so the F3 exclusion of "the Bridge fee a sweep caller supplies" always has its premise
   ("credited and consumed inside the same sweep call") true; a forced credit still never enters
   `feeCredits`, is never swept, and is absorbed as `X(h)`; the balance identity reduces to the ordinary
   predicate for an ordinary block, and holds for a sweep block before or after the block's own fee
   credits, with or without a forced credit. Round-7 R7-DPE-07 is closed.
7. **D-8 and D-9 are intact.** The fee path is unchanged (vault counters, protocol-constructed sweep, no
   destination argument, bridge-authenticated credit; an empty pool pays nothing; a failed bridge stops
   rewards rather than creating a claim); slashed stake still goes to the treasury with no burn and
   `REPORTER_BOUNTY(id) < charge(id)` (self-reporting never profitable); the withdrawn recovery-bond
   destinations are tombstones, and the pool remains never collateral, never slashable (INV-A–INV-D).
8. **Absence disclosure and the tombstone sweep hold in the pages I own.** In spec/04, spec/05, spec/07
   every remaining mention of FI-10..FI-14, `forcedBoundary`, `FI_INCLUSION_DELAY`, PRF-15, L1-14,
   `familyBitmap`, `routeSetHash`, `K_SETTLE_BACKENDS`, `AGG_PROVER_PPM`, `M_AGG_MAX`,
   `T_AGG_ROTATE_MAX`, MEM-13, CONS-16, GOV-04, REC-02..REC-04 and the withdrawn FI/aggregation/
   heartbeat parameters is a tombstone, a MUST-NOT-USE register row, a "deferred by D-16" clause, or a
   closing note. The forced-inclusion offence (ECON-04 clause (3)/(5)/(6) and its table row) and ECON-13's
   due-point/breach clauses are now tombstones; `NotEpochBoundary` and `InsufficientFamiliesForRoot` are
   deleted; the `K_PROOF_BACKENDS` row now names per-attestation L1 enforcement; MIG-02 states that the
   publication register grows without bound because v1 has no prune entry point; and the course teaches no
   deferred mechanism in the present tense (only the corrected negations remain). Spot checks of
   spec/01 ROLE-04, spec/02 CONS-01(v)/CONS-16, spec/03 MEM-13/MEM-15(2a)(2b), spec/06, spec/08, spec/09,
   spec/10 and the index found no live read of a tombstoned rule or parameter.

**Scope note.** I did not re-audit the consensus, membership or migration angles; the freeze's claim that
all round-7 findings are closed is confirmed for every round-7 finding in my scope except R7-DPE-06
(→ R8-DPE-01) and round-7 exit-and-boundary F8 (→ R8-DPE-05), both still visible in the frozen text.

---

## Fault-model summary and implementability verdict

- **Inside the claimed fault model:** R8-DPE-02 (freeze ordering/timing; any account, no assumption
  failure) and R8-DPE-06 (same-block ledger ordering, bounded and best-effort). Neither is a soundness,
  solvency or fund-loss path.
- **Critical/High inside the fault model:** none. I found no way to break the D-11 binding, forge a
  statement under the single-backend policy without a backend defect (disclosed), double-promise pool ETH,
  make an honest fee-vault block unprovable, or bypass the k-attestation count.
- **Implementable as written?** Almost: the core is implementable, but three gaps require an implementer
  to invent a rule — the referenced-path `daMode` (R8-DPE-01), the (5)(d) freeze trigger (R8-DPE-02) and
  the unregistered attestation reward/split (R8-DPE-03) — and two round-7 items recorded as closed are
  still open (R8-DPE-01, R8-DPE-05). All five are textual fixes; no mechanism needs redesign.
