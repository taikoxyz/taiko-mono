# Iteration 03 — raw review, round 3

**Angle B — proof soundness, data binding, stake custody, accounting.**
**Frozen snapshot reviewed:** `3b0821f2fbbc21427ed2dee2575db4ad32deecc3` (2026-10-05).
**Reviewer:** fresh independent adversarial reviewer, round 3, angle B. I did not write this material.
**Method.** I read the rules as written. In-text *"(review round N, finding X)"* italics are treated as
claims, not evidence; where a fix is claimed I re-derived the attack from the rule text. I worked from
`spec/05-proof-statement.html` (PRF-01..13), `spec/04-l1-integration.html` (L1, DA, MSG),
`spec/07-economics-slashing.html` (ECON-01..12), and cross-checked `spec/02-consensus.html` (CONS-03/06/
09/10/13), `spec/03-membership-staking.html` (MEM-01..12), `spec/09-parameters.html` (PARAM-01/03),
`spec/06-recovery-exceptions.html` (HALT-01..04), `spec/index.html` (GEN-05/06, rules index) and the
round-1/round-2 ledgers and raw reports. I also diffed the current text against the round-2 base
`f67458b45` to distinguish newly introduced text from pre-existing text (used only for attribution, not
as evidence).

**Result: NOT CONVERGED on this angle.** Three High, four Medium, one Low. One finding is a defect
*introduced* by the round-3 fix (the canonical payload framing of PRF-07(0)); one is a defect in a
mechanism added by the round-2 fix and carried forward (the validator payout identity of
ECON-02(5)(d)); one is a round-2 High that the round-3 change order does not list, so it is still open
(P-R2-03); two are round-2 Mediums whose text is unchanged (P-R2-05, P-R2-09).

| Severity | Count | Inside the fault model |
|----------|-------|------------------------|
| Critical | 0 | — |
| High | 3 | R3-PRF-01's end-to-end exploit needs F2 (>2/3 of an epoch's set); R3-PRF-02 and R3-PRF-03 need no assumption failure or Byzantine stake |
| Medium | 4 | 4 (structural; no attacker needed beyond a permissionless lander) |
| Low | 1 | 1 |

---

## Findings

### R3-PRF-01 — High — the epoch-boundary evidence of PRF-05 has no public inputs, and its trigger is keyed to the head block, so the CONS-09 handoff is never actually verified

**One-line rationale.** PRF-05(ii)/(iii) require the guest to recompute `epoch_anchor` and
`set_version_commit` "against the same public input", but the closing epoch's set root/total and the
pair `(set_version(e), N(set_version(e)))` exist in neither PRF-02's journal nor L1-05's table, and
both checks fire only when the batch *head* is the boundary block, so a normal multi-block batch at a
boundary checks neither side.

**Exact rule / missing rule.**
`spec/05-proof-statement.html:223` (PRF-05): "(ii) the head header's `validators_hash` equals the
epoch's set root, and if the batch's head is the last block of its epoch, that header's
`next_validators_hash` commits to the next epoch's set (CONS-10); if the batch's head is the first block
of its epoch, the head header MUST carry the `epoch_anchor` field of CONS-10(6) and the guest MUST
recompute it from the anchor certificate it verifies — including the `cert_hash` of the closing epoch's
commit certificate for `B_anchor` … the epoch-boundary evidence is checked by the batch on each side of
the boundary and may not be skipped; (iii) … when the batch's head opens its epoch, the head header's
`set_version_commit` field MUST equal the CONS-10(6) commitment to the L1 mapping entry
`(set_version(e), N(set_version(e)))` … recomputed by the guest against the same public input".
`spec/02-consensus.html:327-350` (CONS-10(6)) owns the encodings; `spec/02-consensus.html:257-296`
(CONS-09) is the handoff argument, whose clause (5)(i) says the argument requires implementations to
execute the anchor duty.
Missing: (a) the closing epoch's `(setRoot, totalVotingPower)` needed to authenticate `B_anchor`'s
certificate; (b) the next epoch's set root needed to check the closing batch's `next_validators_hash`;
(c) `(setVersion, N)`; and (d) a trigger that fires on the block carrying the fields, not on the batch
head. None of (a)–(c) is in PRF-02's journal (`05:65-117`) or L1-05's rows 1–26 (`04:135-159`), and
L1-05 forbids hashing values absent from the journal (`04:117-132`); §2.1's reverse mapping
(`04:195`) enumerates exactly the journal fields.

**Assumptions and preconditions.** A batch must not span an epoch boundary (PRF-05), so exactly one
batch per epoch touches the opening side and one touches the closing side. `BATCH_BLOCKS` K = 32
(`09:105`) is the placeholder batch length, so a batch that opens epoch `e` normally has head
`h_first(e)+31 \ne h_first(e)`; the anchor branch is conditioned on "the batch's head is the first block
of its epoch" and therefore does not run. On the closing side, the head of the batch ending at
`h_last(e)` does trigger the `next_validators_hash` branch — but there is no L1-pinned input for
`set_root(e+1)` to check it against.

**Attack trace / worked counterexample.**
1. Epoch `e` ends at `h_last(e)`; the batch ending there has head `h_last(e)`. The guest is required
   to check `next_validators_hash = set_root(e+1)`; the journal carries only `set_root(e)`. An
   implementer must either skip the check or accept a witness-supplied root (PRF-03: "No witness element
   may define the authoritative validator set", `05:174-176`; PRF-13, `05:326-334`).
2. The next batch is built over `[h_first(e+1), h_first(e+1)+31]`. Its head is not the first block, so
   PRF-05(ii)'s anchor branch does not fire and PRF-05(iii) is vacuous for `set_version_commit`; the
   `epoch_anchor` field inside the batch range is never recomputed, contradicting PRF-05's own
   "checked by the batch on each side of the boundary and may not be skipped".
3. Even for a single-block batch that does trigger the branch, the guest can only verify `B_anchor`'s
   certificate against a set root that is either witness-supplied (self-referential: `cert_hash` itself
   commits to `set_root`, so a fabricated set and signatures pass) or absent. `set_version_commit`
   cannot be recomputed at all because `(setVersion, N)` is not a public input.
4. Result: the settled batch's proof carries no verified statement about the handoff; CONS-09(5)(i)'s
   forbidden shortcut ("a value that is never recomputed") is not detectable at settlement, and a light
   client cannot conclude from the proof that the epoch was anchored to the real previous set.

**Inside/outside the claimed fault model.** The rule defect is inside: no attacker is needed to show the
check cannot be implemented as written, and the statement L1 verifies is weaker than PRF-01/R7 claim.
The *end-to-end* exploit (a bogus `epoch_anchor` inside a settled batch) requires a real quorum of the
next epoch's L1-pinned set to certify the batch head, i.e. an F2 condition; a fabricated anchor alone is
harmless because the head certificate is still checked under the L1 root.

**Attacker resources and cost.** None for the defect. For the full exploit: >2/3 of epoch `e+1`'s
voting power plus one L1 landing transaction (≈ one `land` call), i.e. outside A-CONS-1.

**Harm and exact requirement/decision affected.** Settlement verifies no epoch-handoff statement; R5
(CONS-09's handoff, falsifier F1), R7 (complete proof statement), R8 (public data bound to the proof),
R13 (implementable without inventing rules); CONS-09(4)–(5), CONS-10(6), MEM-09(1)–(2), PRF-02's
"single authoritative public-input vector" claim, PRF-03, PRF-13.

**Evidence.** `spec/05-proof-statement.html:223`; journal `05:65-117`; `05:170-179`; `05:326-334`;
`spec/04-l1-integration.html:117-132,135-159,163-195`; `spec/02-consensus.html:257-296,327-350`;
`spec/03-membership-staking.html:450-506,402-427`; `spec/09-parameters.html:97,105`.
Attribution: this text is unchanged from the round-2 base `f67458b45` (verified: the `set_version_commit`
sentence and the "each side of the boundary" sentence are byte-identical), and the round-3 change order
(`iterations/03-change-order.md` §3) lists only P-R2-01/P-R2-04, E-R2-02's residue, R2-LIV-07/08 and
R2-LIV-09. The round-2 ledger recorded this as an **Open** High; it remains open. *(The round-3 consensus
angle independently reports the same defect as R3A-04; recorded here because the journal-vs-L1-05
completeness question is this angle's; the parent should merge, not double-count.)*

---

### R3-PRF-02 — High — `finalityCommitment` is declared proof-bound and "re-derived in-guest … (PRF-04)", but PRF-04 contains no such clause, so the contract's only finality-evidence commitment is prover-chosen

**One-line rationale.** PRF-02 and L1-05 row 15 both point at PRF-04 for the in-guest derivation of
`finalityCommitment`; PRF-04's clauses (i)–(v) never mention it (clause (vi) was the forced-inclusion
check removed by D-6), so the value is "the caller passed it" — exactly what PRF-13 forbids.

**Exact rule / missing rule.** `spec/05-proof-statement.html:100-103`: "`bytes32 finalityCommitment;
// commits the head certificate's round, bitmap hash and signature-set hash; re-derived in-guest from
the witness (PRF-04), and the only commitment to the finality evidence the contract hashes (L1: claimed,
proof-bound)`". `spec/04-l1-integration.html:149` (L1-05 row 15): "…; the guest re-derives it from the
witness (PRF-04)". `spec/05-proof-statement.html:183-220` (PRF-04) checks signatures, distinct signers,
`3s > 2W`, `W`, head hash and the header chain — no derivation of `finalityCommitment`.
`spec/04-l1-integration.html:253` shows it is supplied by the caller (`LandInput.finalityCommitment`).
Missing: the clause "the guest recomputes
`keccak256(abi.encode("TAIKO_ETNA_FIN", chainId, epoch, lastHeight, headBlockHash, round, bitmapHash,
signatureSetHash))` from the witness certificate and requires it to equal the journal value" (the
encoding exists only as prose on L1-05 row 15).

**Assumptions and preconditions.** The L1 contract hashes the whole journal into `statementHash` and
gives only that hash and the opaque proof to the verifier route (`04:129-132`). The guest produces the
journal; for the proof to verify, the guest's journal must match the contract's vector. A guest that
takes `finalityCommitment` from a host hint and echoes it satisfies the hash check for any value.

**Attack trace / worked counterexample.**
1. A prover lands the batch with `_input.finalityCommitment = bytes32(0)` (or any value).
2. The guest program (as specified) verifies PRF-04(i)–(v) against the witness certificate and emits the
   journal with the hint value; no clause compares the field to the certificate.
3. The contract hashes the vector including the supplied value and the verifier accepts; the checkpoint
   is written (`04:77-85`).
4. Nothing on L1 consumes or stores the field: L1-07's `Checkpoint` has no such field
   (`04:213-229`) and `BatchLanded` does not emit it (`04:282-286`). Two proofs for the same batch with
   different `finalityCommitment` values are both valid (proof malleability), and the claimed binding of
   the certificate's `round`/`bitmapHash`/`signatureSetHash` is not enforced anywhere.

**Inside/outside the claimed fault model.** Inside: structural, no attacker and no assumption failure
required. The harm is statement integrity, not immediate fund loss, because no current consumer reads
the field — but PRF-13 and R7's "complete proof statement" claim are violated as written, and any future
L1 consumer (the field's stated purpose is the contract-side finality evidence) inherits an
attacker-chosen input.

**Attacker resources and cost.** One landing transaction; no stake, no Byzantine validator.

**Harm and exact requirement/decision affected.** R7 (complete proof statement), R8 (public data bound
to the proof), PRF-13; PRF-02's claim that the journal is the single authoritative public-input vector;
L1-05 row 15.

**Evidence.** `spec/05-proof-statement.html:100-103,183-220,216,326-334`; `spec/04-l1-integration.html:
149,183,253,213-229,282-286`; grep of the whole spec tree: the strings "re-derive"/"re-derives"
appear for this field only in `05:101` and `04:149`, and PRF-04 never contains the identifier. The
defect pre-dates round 3 and was never listed as closed (round 2's related findings were about the
L1-05/PRF-02 vector *mismatch*, now fixed, and about the contract having no `s`, a different defect).

---

### R3-PRF-03 — High — ECON-02(5)(d)'s validator payout identity is not computable from the state the specification defines and `P(e)` is never frozen: the first claimant takes the whole epoch allocation

**One-line rationale.** `P(e) = {v : participated[e][v]}` is written incrementally by every
`land(data, proof)` for epoch `e` and is never frozen at `evidenceClose(e)` or anywhere else, while
the payout formula divides by `Σ_{u∈P(e)} effStake(u,e)`; the denominator is read from mutable state at
claim time, so the first claim after the window opens sees the smallest denominator and can take
`Alloc(e)` in full.

**Exact rule / missing rule.** `spec/07-economics-slashing.html:142-182` (ECON-02 clause 5):
(b) "After verification, `land(data, proof)` MUST write that bitmap into the staking contract's
per-epoch participation accumulator — `participated[e][index] = true` for every set bit, for every epoch
the batch's heights cover — and nothing else may set it";
(c) "Claims for epoch `e` open only after `evidenceClose(e)` … when the epoch's allocation is fixed";
(d) "`pool_after(e) = pool_before(e) + inflow(e) − Σ_{v ∈ P(e)} payout(v,e)`;
`payout(v,e) = floor( Alloc(e) · effStake(v,e) / Σ_{u ∈ P(e)} effStake(u,e) )`;
`Σ_v payout(v,e) ≤ Alloc(e) ≤ pool_before(e)`".
Missing: (i) the moment/rule at which `P(e)` and `Σ_{u∈P(e)} effStake(u,e)` are frozen; (ii) where
the staking contract obtains `(epoch, index) → entry` and `effStake(v,e)` (MEM-09(2) stores only
`epoch → (setRoot, totalVotingPower, rootCommittedAt)`, `spec/03-membership-staking.html:471-483`;
MEM-06(1)'s `SlashBase(v,e)` is per entry, not per index); (iii) an accumulated participating-stake
total; (iv) consistency of the key: clause 5(b) indexes `participated` by signer *index*, clause 5(d)
by entry *v*.

**Assumptions and preconditions.** `Alloc(e) > 0` (funding is an Open item, ECON-02 clause 7, but the
identity is normative for when it exists). At least one participant's bitmap bit is recorded before
another participant's. Landing is permissionless and has no deadline (L1-04); the two-epoch lookahead
puts the epoch's last batches' landing close to `evidenceClose(e) = t_root(e) + W_EVIDENCE`
(`spec/07-economics-slashing.html:445-468`), so the race is reachable in ordinary operation and
guaranteed under a prover outage (F1), where L1-04 still requires late batches to be accepted.

**Worked counterexample.** `Alloc(e) = 100 ETH`; validators A and B each have `effStake = 1` in
epoch `e`'s set and each sign a head certificate, in two different batches, both of which the guest
verifies (PRF-04(ii)–(iii)). A's batch lands first; B's batch lands later.
1. At `evidenceClose(e)`, `participated[e][]` records A only (or A and some others; the point is that
   it is not complete). A (or any address) calls `claimValidatorReward(e, indexA)`.
2. The implementation computes `P(e) = {A}`, so `payout(A,e) = floor(100 · 1 / 1) = 100 ETH` and pays
   A's owner. `Σ payout = 100 ≤ Alloc = 100 ≤ pool_before`: the stated identities hold numerically.
3. B's batch lands; B's claim computes `floor(100 · 1 / 2) = 50` against a pool that no longer holds the
   allocation, so B is paid 0 (or the claim reverts, contradicting "any address may claim" and the
   payout identity itself).
4. The same happens whenever the first claim precedes any epoch-`e` batch: the first claimant always
   receives `Alloc(e)`; the pro-rata identity in clause 5(d) is not an identity at all.

**Inside/outside the claimed fault model.** Inside: no Byzantine stake, no assumption failure, no
consensus violation. The attacker is a validator that (or whose ally) submits one L1 transaction at a
moment L1-04 guarantees it may choose; the loss falls on the other participating validators.

**Attacker resources and cost.** One entry at `S_min` (a validator) plus one L1 claim transaction; the
benefit is up to `Alloc(e)` of ETH per epoch (bounded by that epoch's allocation, so not a pool drain
beyond `Alloc(e)`).

**Harm and exact requirement/decision affected.** R11 (objective rewards/collateral rules), ECON-02
clause 5(b)–(d)'s pro-rata guarantee and A-ECO-1's operator economics; PARAM-01's `Alloc(e)` row
(`09:115`); the round-2 fix E-R2-05 claimed to make the reward mechanism implementable, but the
mechanism as amended cannot compute its own denominator from the L1 state the specification defines.
Fix: freeze `P(e)` and the participating stake before claims open (e.g., at `evidenceClose(e)`, with
all epoch-`e` batches' bits required to be in, or a defined reconciliation for late ones), state the
`(epoch,index) → (entry, effStake)` witness the contract verifies against the stored root, and state
whether late participation is excluded or accrued.

**Evidence.** `spec/07-economics-slashing.html:142-182` (esp. 151-174), `07:186-197` (funding Open),
`07:445-468` (window), `07:522-525` (withdrawal gates); `spec/03-membership-staking.html:450-506`
(MEM-09(2) stored tuple), `03:338-360` (MEM-06(1)); `spec/04-l1-integration.html:77-85` (L1-03 step 6
writes the bitmap and pays), `04:98-110` (L1-04: no deadlines, late batches accepted).

---

### R3-PRF-04 — Medium — `feeRecipient` and the two block timestamps are declared "claimed → proof-bound" but no rule states the guest check; the timestamps' "timestamp-monotonicity" check does not exist

**One-line rationale.** PRF-02 annotates `feeRecipient` ("proof-bound", "a lander MUST NOT be able to
choose it") and `firstBlockTimestamp`/`lastBlockTimestamp` ("the header-chain and timestamp-monotonicity
checks read"), and L1-05 row 8 says "a claimed value that does not match the header chain makes the proof
invalid" — but no PRF rule performs either comparison, so the lander supplies both and PRF-13 is
violated for them.

**Exact rule / missing rule.** `spec/05-proof-statement.html:108-116`;
`spec/04-l1-integration.html:142` (row 8), `04:154` (row 21: "because any account may land (L1-04) a
lander MUST NOT be able to substitute its own address"), `04:176,188` (reconciliation rows).
Missing: the in-guest checks ("the guest derives `feeRecipient` from the header of `firstHeight` and
rejects a mismatch"; "the guest requires the journal's two timestamps to equal the header timestamps of
`firstHeight`/`lastHeight`, and applies the timestamp-monotonicity rule"). A grep of the whole spec
tree finds "timestamp-monotonicity" only in this journal comment, i.e. the rule it names is not stated
anywhere.

**Assumptions and preconditions.** Same journal mechanics as R3-PRF-02. Nothing consumes `feeRecipient`
today (L1-10 pays the lander, `04:330-341`; L1-11 has no such ledger), so the present harm is proof
integrity, not payment redirection. If the field is ever re-used for a payout, the lander choosing it is
a direct loss.

**Attack trace.** A lander sets `_input.feeRecipient` to itself and `firstBlockTimestamp`/
`lastBlockTimestamp` to arbitrary `uint64` values; the guest echoes them (no clause constrains them);
the contract hashes the vector and the proof verifies. The checkpoint and event carry no such fields, so
the misstatement is invisible at settlement. Any future rule that pays `feeRecipient` or reasons about
the batch's time span reads a lander-chosen value.

**Inside/outside the claimed fault model.** Inside (structural; no attacker, no assumption failure).

**Attacker resources and cost.** One landing transaction.

**Harm and requirement affected.** R7/R8, PRF-13; L1-05 row 21's own justification is false as written.
Severity Medium because no current consumer pays out on the field; the defect is the unstated binding.

**Evidence.** `05:108-116`; `04:142,154,176,188`; grep result: "timestamp-monotonicity" occurs exactly
once in `spec/` (the journal comment) and "feeRecipient" occurs in PRF-02 only.

---

### R3-PRF-05 — Medium — the new canonical framing mandates zero padding on the blob path and simultaneously forbids trailing bytes, and no rule requires the guest to check the padding is zero

**One-line rationale.** PRF-07(0) says "the blob concatenation MUST be `P` followed by zero padding to
the end of the last blob" and, two sentences later, "trailing bytes are not tolerated, so the decode is
injective and `P` is a function of the published bytes"; the only honest reading that keeps blob
batches landable (padding sanctioned) also admits non-zero padding, because the guest check that the
padding is zero is never stated.

**Exact rule / missing rule.** `spec/05-proof-statement.html:242` (PRF-07(0)); the calldata-path
sentence "`_data` MUST be exactly `P`" is on the same line. Missing: a scoped statement of the
no-trailing-bytes rule ("after removing the blob path's zero padding") and the matching guest check
("the guest MUST reject a batch unless every byte after the last frame is zero"), together with the
blob-path frame-count rule (the journal fixes the count, but the padding's length is not in the
journal; it is implied by the blob count the contract knows).

**Assumptions and preconditions.** Blob path (`daMode = 2` or `3`). `P` is a sequence of self-delimiting
frames; an honest `P` almost never fills an integer number of 131,072-byte blobs, so padding exists on
essentially every blob batch. The blob path is an implementation gate (F2/Q-A3), but the framing rule is
normative for both backends and for the calldata path's decode discipline (PRF-09, `05:338-361`).

**Attack trace / readings.**
- Reading A (literal "trailing bytes are not tolerated" applied to the whole committed region): every
  honest blob payload whose `P` does not end exactly at the last blob boundary is invalid; the guest
  rejects honest batches (liveness).
- Reading B (padding sanctioned, as the mode-specific sentence requires): a lander publishes
  `B = P || g` with `g \ne 0`; the guest decodes `P` from the front, checks each header's
  `transactions_root` (PRF-06), recomputes `dataCommitment` over all of `B` (DA-03(0)/(v)) and passes.
  The accepting transaction now publishes bytes that were never executed, so PRF-01's W3 ("the data it
  executed is the data the accepting L1 transaction publishes", `05:41-45`) is false for that batch,
  and PRF-07(0)'s injectivity claim is false: two distinct published strings (`P||0^k` and
  `P||g`) decode to the same `P`. A third party following PRF-07(0)'s decoder rejects the batch's
  published bytes while L1 accepted it (DA-01/INV-02 audit failure).

**Inside/outside the claimed fault model.** Inside: a permissionless lander (L1-04) can produce Reading
B's state with one transaction and blob fees; Reading A needs no attacker at all.

**Attacker resources and cost.** Reading B: L1 calldata/blob cost of the batch plus one `land` call;
no stake.

**Harm and requirement affected.** R7/R8 (data bound to the proof; canonical framing), DA-01/INV-02
("one canonical answer to what is the batch"), PRF-09 (both backends implement one statement — the
zero-padding check is part of that statement or it is not). Introduced by the round-3 P-R2-04 fix: the
"trailing bytes are not tolerated" and "zero padding" sentences are both new in this revision
(verified absent from `f67458b45`).

**Evidence.** `spec/05-proof-statement.html:242,252-280`; `spec/04-l1-integration.html:406-414,
442,478-481`; `spec/10-assurance.html:37-52` (INV-02); `iterations/03-change-order.md` §3 (P-R2-04
"including … padding rules").

---

### R3-PRF-06 — Medium — "every blob in the transaction" versus the submitter-chosen blob range, and the hybrid path's two published copies are never required to be equal inside the guest

**One-line rationale.** DA-03(0) defines the committed object as the concatenation of "every blob in the
transaction", while DA-03's preamble and (i) define a submitter-chosen sub-range
`[blobIndexStart, blobIndexStart + n)`; under the range reading, blobs published in the accepting
transaction outside the range are neither committed nor rejected, and under the hybrid path the guest is
never required to decode both published copies and require them equal.

**Exact rule / missing rule.** `spec/04-l1-integration.html:404` (preamble: "let `n = blobCount` and
let blob index `i` range over `[blobIndexStart, blobIndexStart + n)`"), `04:406-414` (0):
"For `daMode = BLOB` the committed object is the concatenation, in blob index order, of the full
131,072-byte string of every blob in the transaction"; `04:416-421` (i) checks only the declared range;
`04:478-481` (hybrid: "`_data || blob_0 || … || blob_{n-1}`"); `spec/05-proof-statement.html:242`
("in `CALLDATA_AND_BLOB` both published copies MUST encode the same payload"). Missing: a rule that the
range is the whole transaction (`blobIndexStart = 0`, `n` = the transaction's blob count, with a typed
revert otherwise) or, if a range is intended, a rule on what happens to the uncommitted blobs; and a
guest check "decode `P` from each published copy and reject unless they are byte-identical".

**Assumptions and preconditions.** `daMode = 2` or `3`; the blob path is an implementation gate, but
the commitment construction and the statement are normative (PRF-09). `LandInput` carries
`blobIndexStart`/`blobCount` (`04:260-261`) and DA-03's (i) loop is bounded by them.

**Attack trace.** A lander attaches the batch's real blobs plus one extra blob to the transaction and
declares `blobIndexStart = 0, blobCount = n`; (i) checks `blobhash(0..n-1)`, the extra published blob is
untouched, `blobHashesHash` covers only the declared range, and the proof verifies. The accepting
transaction now contains data that is not part of "the whole published byte string" the checkpoint's
`dataCommitment` covers (`04:213-229`), so the canonical data object of the batch is ambiguous. In
hybrid mode, a lander can make `_data` and the blob concatenation encode *different* `P`s: the guest
decodes one (the rules never say which, because PRF-03(e) speaks of "the committed payload bytes",
singular, while the hybrid commitment binds two strings) and never compares them; one of the two
published objects is then unexecuted data in the canonical transaction.

**Inside/outside the claimed fault model.** Inside (structural; no attacker beyond a permissionless
lander paying L1 fees; no assumption failure).

**Attacker resources and cost.** One `land` call plus the blob/calldata fees for the extra data.

**Harm and requirement affected.** R8, DA-01 ("MUST NOT define a second canonical location"), INV-02;
PRF-09's one-statement requirement. Re-raises round-2 P-R2-05 (Medium), which the round-2 ledger's High
condensation dropped and the round-3 change order does not mention; the "every blob" sentence is
unchanged from `f67458b45`.

**Evidence.** `spec/04-l1-integration.html:404,406-421,442,478-481,260-261`;
`spec/05-proof-statement.html:170-173,242`; `iterations/raw/round2-proof-blob-binding.md` P-R2-05
(same defect, still open).

---

### R3-PRF-07 — Medium — MEM-06(2)'s exposure cap (`max`, not `sum`) contradicts the all-windows-closed withdrawal gate; under the cap reading a multi-epoch offender withdraws the surplus and escapes part of its penalty

**One-line rationale.** MEM-05(3)(b) and ECON-07(5) forbid any withdrawal while an epoch's evidence
window is open, while MEM-06(2) says the owner "may withdraw at most `bonded(v) − max_exposure(v)`" —
and `max` over open epochs is smaller than the sum, so an offender exposed in two epochs can withdraw
the difference and be slashed on a remainder, the exact race MEM-06(3) claims to defeat.

**Exact rule / missing rule.** `spec/03-membership-staking.html:343-346` (MEM-06(2)); `03:296-298`
(MEM-05(3): "may withdraw only when … (b) the evidence window `W_evidence` has closed for every epoch
the entry was in"); `spec/07-economics-slashing.html:522-525` (ECON-07(5)); `03:347-351` (MEM-06(3)'s
three-part defence, whose clause (ii) claims "withdrawal is capped by the exposure of every open epoch").
Missing: one rule — either delete the `bonded − max_exposure` sentence and keep the gate, or state the
retention as `min(bonded, Σ_{e open} SlashBase(v,e))` and reconcile it with the gate.

**Assumptions and preconditions.** The entry is in two epochs `e1,e2` with open windows and
`SlashBase(v,e1) = SlashBase(v,e2) = 100`, `bonded = 200`; a slash for each is admissible inside its
window. No Byzantine stake is needed: the "attacker" is one misbehaving validator using the looser rule.

**Worked counterexample.** `max_exposure = 100`, so under MEM-06(2) the owner withdraws 100, leaving
`bonded = 100`. Evidence for `e1` charges `min(P1, bonded, remaining) = 100`; evidence for `e2` then
charges `min(100, 0, 100) = 0`. Total penalty 100 where the design intends up to 200 (one SlashBase per
epoch, MEM-06(2): "Slashing is bounded by the bonded balance"), so half the penalty is evaded by a
single withdrawal. Under MEM-05(3)(b) the withdrawal is impossible, so the two rules cannot both be
right.

**Inside/outside the claimed fault model.** Inside: a single Byzantine validator (the class slashing
exists for), no threshold, no assumption failure.

**Attacker resources and cost.** One validator entry plus the L1 withdrawal and offence transactions;
benefit = the withdrawn surplus (up to `Σ SlashBase − max SlashBase`).

**Harm and requirement affected.** R11 (collateral and exits), MEM-06(2)/(3), MEM-05(3)(b), ECON-07(5);
A-ECO-1's deterrence claim. Severity Medium because MEM-05(3)(b) (and ECON-07(5)) already state the safe
gate twice, so an implementer following the life-cycle rule is safe; the defect is the contradictory
sentence an implementer may instead implement.

**Evidence.** `spec/03-membership-staking.html:296-298,338-360`; `spec/07-economics-slashing.html:
522-525`; text unchanged from `f67458b45`; re-raises round-2 P-R2-09 (Medium), unaddressed by the
round-3 change order.

---

### R3-PRF-08 — Low — residual parameter/definition registration defects on the acceptance path

**One-line rationale.** Normative quantities are used but not registered, and two aliases survive the
round-2 alias cleanup, which contradicts PARAM-01 and GEN-03/GEN-07.

**Exact defects.**
1. `REWARD_QUOTE` is used normatively by L1-11 (`spec/04-l1-integration.html:347,351,359`; also
   `04:624`, `spec/08-migration-upgrades.html:273`) but does not appear in PARAM-01's table
   (`spec/09-parameters.html:91-136`), which claims "Every protocol parameter appears in the table below"
   (`09:15-20`). No unit, derivation or tag is registered.
2. `MAX_BATCH_BLOCKS` is an admission bound in L1-05 row 7 (`04:141`) and appears in the unmeasured
   register (`04:622`) but is not in `09`; `09:105` registers `BATCH_BLOCKS` (K) = 32 instead, and no
   rule states whether `MAX_BATCH_BLOCKS = BATCH_BLOCKS` or how the `BatchTooLong` bound
   (`04:301`) relates to K.
3. `nSigners` in the `signerBitmap` encoding (`05:104-107`, `04:158`) is undefined. If an implementer
   reads it as the number of signers rather than the set size, the bitmap length is a function of the
   very bits it encodes and cannot address a signer at an index ≥ 8·|signers|; the two backends can
   disagree on the journal length.
4. `remaining_exposure(v,e)` in ECON-05(3) (`07:350`) is used but defined nowhere (MEM-06(2) defines
   `max_exposure`; ECON-01(4) defines the per-epoch cap).
5. Alias pairs survive the round-2 cleanup: ECON-07 and MEM-05 use `W_evidence` (14 occurrences
   in `07`) while PARAM-01 registers `W_EVIDENCE` (8 occurrences in `09:108-109`), and ECON-07(2)/
   MEM-05(4) use `T_process` while `09:108` writes `T_PROCESS` in the same inequality. ECON-03(1)'s
   alias resolution ("clients, parameters and migration text MUST use `D_WITHDRAW`") covers only
   `D_WITHDRAW`/`D_withdraw`.

**Inside/outside.** Inside, structural.

**Harm and requirement affected.** R13 (implementable without inventing rules), PARAM-01's discipline,
GEN-03/GEN-07. Severity Low: no attacker; the defects are registration/citation, except item 3, which
can produce a journal-encoding mismatch (treated as Low only because a careful implementer resolves it
from MEM-08's set size).

**Evidence.** as cited inline.

---

## Checked and holding (not findings)

These were re-attacked and did not break; listed so the parent can see the coverage, not as evidence for
the defects above.

1. **Round-1/blob fixed-point argument (post-journal-change).** I re-derived the binding chain with the
   two real variables (executed blob bytes `W`, published blob bytes `B`): the contract binds
   `blobhash(i)` (BLOBHASH, tx-scoped) and the precompile binds `p_B(z_i) = y_i` with
   `kzg_to_versioned_hash(commitment_i) = vh_i`; the guest checks `p_W(z_i) = y_i` and recomputes
   `dataCommitment` over all of `W`; `z_i = H("TAIKO_ETNA_CHALLENGE", l2ChainId, statementCoreHash,
   dataCommitment, blobHashesHash, uint16(i)) mod p` and both `dataCommitment` (from `keccak(W)`) and
   `blobHashesHash` (from `B`) move the challenge, so a cheating prover needs `p_B(z(B)) = p_W(z(B))`,
   a hash fixed point costing ≈ `q·2^-243`. I found no cheaper route (choosing `B` after `z` is
   impossible because `z` depends on `B` through `blobHashesHash`; choosing `W`'s free padding is the
   same fixed point). Holds under the named premises (KZG binding, ROM Fiat–Shamir, canonical field
   elements, EIP-4844 evaluation-form/bit-reversal convention, in-guest recomputation).
2. **Calldata path.** `dataCommitment = H("TAIKO_ETNA_DATA", chainid, first, last, daMode,
   keccak(_data))` computed by the contract and recomputed in-guest over the executed bytes is an
   equality, not a probabilistic argument; the submitter-supplied value is ignored/rejected (DA-02,
   `04:384-402`). Holds.
3. **P-R2-01 fix.** "The executed block bodies are decoded from the committed payload … whose decoded
   transactions do not reproduce that root invalidates the proof" is present and normative (PRF-06,
   `05:229-239`) and reinforced by PRF-03(e) (`05:170-173`). Holds for the calldata path; the blob-path
   caveats are R3-PRF-05/06.
4. **Journal ↔ L1-05 reconciliation (E-R2-02).** I mapped all 25 journal fields against rows 1–26:
   row 2 is L1-local and correctly not a public input, row 20 is vacant and not reused, row 8 carries
   two journal fields, and every other field maps one-to-one with the same provenance
   (`04:135-195`). No mismatch found. The defect is not a mismatch but the *absence* of the boundary
   values (R3-PRF-01).
5. **Quorum predicate.** One form, `checked_mul(3, s) > checked_mul(2, W)`, in CONS-03, PRF-04(iii)
   (`05:200-213`) and L1-05 row 12 (`04:146`); no floor/threshold form survives. Holds. (Whether the
   L1 contract can evaluate it without `s` is a separate issue reported by the round-3 consensus angle;
   I did not re-list it.)
6. **L1-11 reward identity.** Checked arithmetic, `rewardPaid = min(REWARD_QUOTE, before + msg.value)`,
   no unchecked subtraction, one debit path, no second payout route out of the prover ledger
   (`04:343-360`). No underflow or double-pay found.
7. **ECON-01 INV-A..D.** One asset, one ledger, no ETH collateral, no delegation, per-epoch
   `SlashBase` retention, `a = min(requested, b(v))` and no debt outside the ledger (`07:36-78`).
   Internally consistent; the reward/validator pool is correctly excluded.
8. **Evidence-window amendment (E-R2-07 / R2A-01 consequence).** `t_root(e)` is the stored
   `rootCommittedAt` of the per-epoch mapping (MEM-09(2), `03:471-483`), `evidenceClose(e) =
   t_root(e) + W_EVIDENCE`, and the `3·E_EPOCH` anchor skew is correctly re-derived for the two-epoch
   lookahead (commit in `e−2`; offence as late as `h_last(e)`) — `07:445-521`, `09:108-109`. The
   `W + T_PROCESS + CORR_DELAY + M_ev < D_WITHDRAW` form is right; all inputs are tagged unmeasured.
   Holds.
9. **D-6 removals on this angle.** No `forcedInclusionCommitment` in PRF-02; L1-05 row 20 vacant and
   explicitly not reusable; no `TAIKO_ETNA_FI` domain tag; L1-03's step list has no forced-inclusion
   consumption write; L1-11 has no forced-inclusion ledger (`04:81,152,160,591`). Holds.
10. **PRF-08 (one certificate per batch).** Holds for a fixed epoch under the stated premises; the
    epoch-opening caveat is R3-PRF-01.

## Limits of this review

I did not re-prove KZG binding or the pairing precompile, did not audit the learning site, and did not
verify the migration slot arithmetic or the address preservation (other angles own those). I did not
search for a Critical in the guest's Ed25519/header-chain implementation (out of scope for a
documentation review). Where I relied on line numbers they are from the frozen snapshot; all quotes are
verbatim except whitespace normalisation.
