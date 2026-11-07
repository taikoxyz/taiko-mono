# Iteration 02 — round 2 raw report (angle B)

**Reviewer angle:** proof soundness and the blob-binding re-attack — spec/05-proof-statement.html PRF-07 and spec/04-l1-integration.html DA-03 as amended (whole-blob commitment, per-blob Fiat–Shamir challenge, on-chain KZG opening, in-guest EIP-4844 evaluation), plus PRF-02/04/05/08 and a stake-custody/accounting spot-check (ECON-01/03/06/07/08).
**Frozen snapshot:** `5e4129913e2540ac42c5c8b5034b64cdc3a5c8f1`.
**Method.** The round-1 italic "(review round 1, finding X)" notes are treated as claims, not evidence. Each amended rule was re-attacked as written; every load-bearing citation below was re-read in the frozen file (line numbers are from the frozen snapshot). No round-1 finding is re-listed unless the amendment that claims to close it does not, which is stated explicitly. The blob-path fixed point was attacked directly (search over the published blob, over the executed payload, over the per-blob index, over extra/unbound blobs, over the unused remainder, and multi-blob/hybrid combinations); the result is recorded in "Verdicts" before the findings.

---

## Verdicts on the assigned questions

### (1) Does the amended fixed-point argument hold, and does the rule close round-1 R1-01?

**The rule survives the re-attack; the written argument does not establish it.** This distinction matters, because PRF-07 and DA-03 carry a `Proven` pill for the blob path (PRF-07 lines 246–274; DA-03 lines 435–467).

What the amendment actually does, in the order it does it:

1. `dataCommitment` is recomputed by the guest over the whole committed byte string and is a Fiat–Shamir transcript input (PRF-07(b)(0)/(v), lines 218–245; DA-03(0)/(iii)/(v), lines 396–404, 421–428, 433). This kills the *round-1* linear solve in the direction round 1 used it: the executed payload `D` can no longer be adapted after `z` is known, because `z` depends on `f(D)`.
2. `blobHashesHash = keccak256(ordered versioned hashes)` — i.e. the commitments of the **published** blobs — is also a transcript input (DA-03(iii), lines 423–425; CS-03's fix). This is the step that closes the direction the round-1 report did *not* name: the attacker's genuinely free object is the published blob `B`, and `z` moves when `B`'s commitment moves.

The residual attack requires one of exactly two breaks:

- **Fix `z`, then change `p_B`.** `z = H("TAIKO_ETNA_CHALLENGE", l2ChainId, statementCoreHash, dataCommitment, blobHashesHash, i) mod p`. To keep `z` while changing the blob's polynomial, the attacker must keep `blobHashesHash`, hence every versioned hash, hence (by `kzg_to_versioned_hash`) the commitment; finding `B' ≠ B` with `commit(B') = commit(B)` is a KZG-binding break (a non-zero polynomial vanishing at the secret `τ`). The commitment map `B ↦ [p_B(τ)]₁` has a 4095-dimensional kernel *mathematically* but the kernel is computationally inaccessible without breaking KZG binding; that is exactly premise (1) of DA-03's premises list.
- **Fix `z` without fixing the commitment** by colliding `blobHashesHash` (keccak preimage/collision, ≈2^128 birthday / 2^256 preimage) or the versioned hash (sha256).

Absent one of those, the attacker must brute-force a fixed point of `B ↦ p_B(Z(f(W), h(B), i))`, and in the random-oracle model each candidate succeeds with probability at most `4095/|F| ≈ 2^-243` (the difference polynomial has degree ≤ 4095 and `z` is uniform and independent of it given the candidate). I found no cheaper route: grinding is still per-fresh-blob, the index `uint16(i)` and the whole ordered versioned-hash list are inside the hash, and the unused remainder is inside `dataCommitment` (so padding moves `z` too). Multi-blob batches give one condition per blob, i.e. strictly more work. Hybrid mode adds the contract-computed `keccak(_data)` binding on top. The "constant blob" trick (publish a constant polynomial so the precompile opening is satisfiable for any `z, y`) does not help: the *guest's* check `p_W(z) = y` is the binding side and the attacker still has to land `y` on the value of a polynomial at a point derived from the blob's own commitment.

**But the argument as written is a non-sequitur, and it will not close the gate it is attached to.** DA-03's "Why this is sound" (lines 435–447) and PRF-07's "Why (b) is sound" (lines 247–269) do this:

- they frame the experiment as a search over **candidate payloads `D`** ("the prover searches over candidate payloads and wins only when a hash output lands on a root of (p_D − p_B)");
- they then assert `D` is **not free** ("`D` is not a free variable: the executed payload is bound to the certified header chain ... so a prover cannot vary `D` after the certificate is signed without invalidating it");
- they dispose of the actually-free object in one sentence: "the precompile pins the published blob polynomial `p_B`".

That last sentence is false: the precompile pins `p_B` to the *versioned hash in the attacker's own transaction*. The prover authors the blob, its commitment, the versioned hash, `blobHashesHash`, `y_i` and the proof. The load-bearing fact is not "`D` is pinned" but "`z` depends on the published blob's versioned hashes, and moving the blob to satisfy the opening moves `z`". PRF-13 (lines 292–300) requires exactly this kind of binding to be *derived*, and it is, but the write-up never says so. A reader who accepts the text's reasoning would conclude the binding follows from the certificate pinning `D` alone — and if the executed-payload identity ever fails (finding P-R2-01), the text offers no protection at all. **Recommendation:** restate the argument over the published blob, name KZG binding as the step that keeps `z` fixed while `p_B` is varied, and state the per-trial bound over blob candidates, not payload candidates.

### (2) Does the "D equals certified chain" binding close the remaining freedom?

It closes the freedom round 1 used — the certified head hash, the parent-hash chain back to `prevBlockHash` and the execution check pin the *history* the guest must execute (PRF-04(v), PRF-06). It does **not** pin the mapping from the committed blob bytes to the block bodies that get executed:

- PRF-03 lists the executed transaction data (e) and "the blob field elements used by PRF-07" (f) as **separate witness elements** (lines 121–135), and PRF-11 says every host-read value is an unverified assertion;
- PRF-06 checks only that each block's *post-state commitment* equals the header's state root; it never requires the guest to decode the executed blocks from the committed payload, and never requires a header's `transactions_root` to be checked against the transactions it executes (lines 196–206);
- PRF-07(b)(v) (line 244–245) presupposes the identity ("the full blob byte strings it executed") rather than enforcing it as a check.

An implementation that takes the block bodies from one witness stream and the committed bytes from another passes every listed check with `B := W` (the published blob equals the byte string the guest hashes; `p_B = p_W` identically, so no fixed point is needed), while the published data is *not* the data that was executed. See P-R2-01.

### (3) Cheaper attacks that were checked and are closed

- **Prefix / partial-blob commitment** (round-1 R1-01's premise): closed by DA-03(0) plus the guest recomputation over all 4096 elements; the free-suffix solve is dead because the suffix is inside `dataCommitment`.
- **Zero-padding of the unused remainder**: the remainder is explicitly committed (DA-03(0)), and it enters `z` through `dataCommitment`, so padding cannot be chosen after the challenge.
- **Per-blob index grinding** (`uint16(i)`, `blobIndexStart`): each index produces a fresh independent challenge; it does not reduce the per-trial success probability, and a blob outside the contract's declared range is not opened at all (which is a defect of a different kind — P-R2-05).
- **Multi-blob / hybrid substitution**: each blob is checked separately at its own challenge; the hybrid's calldata component is bound by the contract's own `keccak(_data)`; a prover must satisfy every condition.
- **Calldata path**: `dataCommitment = keccak256(abi.encode(... keccak(_data)))` computed by the contract, and the guest recomputes; the binding is an equality, no probabilistic argument (DA-02, lines 374–392). It shares only the statement-level defects P-R2-04/P-R2-07 below.
- **Blob-substitution across transactions**: closed by `BLOBHASH` being transaction-scoped (DA-03(i)).

### (4) PRF-04, PRF-05, PRF-08, and accounting

- **PRF-04 (signature/stake checks).** The checks are internally consistent and agree with CONS-03/CONS-05: reconstructed vote bytes, `type = PRECOMMIT`, `validator_index` = bitmap position, distinct signers, `3s > 2W` with checked arithmetic, `W` = total of the authenticated entries, head-hash/chain checks. Two defects: check (vi) is not implementable from the journal (P-R2-02), and the reconstruction never binds `chain_id` to the journal's `l2ChainId` (P-R2-11).
- **PRF-05 vs CONS-10(6) (epoch/boundary).** The rule that review round 1 CS-08 added is mis-scoped and under-input; see P-R2-03.
- **PRF-08 (one certificate per batch).** The argument holds for a fixed epoch: given CONS-01(iii) (a validator precommits only a child of a block it finalized), CONS-05 and the lock rule, a head certificate implies the finalized ancestor chain, and the premises are named honestly. Two caveats, neither a separate finding: (a) it says nothing about the epoch-opening anchor, so for the batch that opens an epoch the "head certificate alone" is *not* by itself evidence of the handoff — that evidence is PRF-05(ii)'s, which is broken (P-R2-03); (b) "no ancestor certificate is verified" is true but means the whole batch inherits the head's premises, which is exactly the A-CONS-1 dependence PRF-08 states.
- **Stake custody/accounting.** MEM-01/ECON-01 (one asset, one ledger, INV-A..D) are consistent as far as stated; ECON-06's destination is a disclosed Open human decision and is not counted; ECON-07/ECON-03 have the defects P-R2-08/P-R2-09/P-R2-10.

---

## Findings

### P-R2-01 — the blob proof never binds the committed payload to the block bodies it executes; an implementation that follows PRF-03's witness list can publish arbitrary data and still land

**Severity: High.** The whole point of the round-1 fix (R1-01) is that the published data and the executed data are one object; the amended check list does not contain the check that makes them one, so the guarantee survives only if the implementer adds a rule the specification does not state (R13), and the failure mode is the Critical-class break of R8/INV-02 that round 1 identified.

**Exact rule / missing rule.** `spec/05-proof-statement.html` PRF-03(e)/(f) (lines 131–133) lists the executed transaction data and the blob field elements as **separate** witness elements; PRF-06 (lines 196–206) checks only post-state commitments and never requires the executed blocks to be *decoded from* the committed payload nor a header's `transactions_root` to be checked against the executed transactions; PRF-07(b)(v) (lines 243–245) asserts the identity ("the full blob byte strings it executed") instead of specifying a check; PRF-11 (lines 332–346) classifies every host-read value as an unverified assertion. Compare the calldata path, where the contract itself hashes `_data` (DA-02) and the guest recomputes the same hash, so the identity is a hash equality and needs no extra rule.

**Assumptions / preconditions.** Blob path selected (`daMode` derived, L1-05 row 17); prover permissionless (L1-04); no crypto assumption is broken; the prover controls its own witness and its own L1 transaction.

**Concrete attack (worked).**
1. Honest validators finalize the head block `H` of a batch; the real batch data is `T` (the block bodies). The attacker builds the honest execution witness from `T` and takes the transaction data from witness element (e), exactly as PRF-03 lists it.
2. The attacker picks any byte string `W` (e.g. 131,072 zero bytes modified in one field element) and publishes it as the transaction's blob `B := W`; it commits `blobHashesHash` over `kzg_to_versioned_hash(commit(B))` and claims `dataCommitment = f(W)` under DA-03(0).
3. The guest computes `p_W` from the blob field elements handed to it as witness element (f) — the same bytes it "executed" for the purposes of (v) — evaluates `p_W(z_i)` and compares to `y_i = p_{B}(z_i)`; since `B = W`, the equality holds for every `z_i`, with no fixed-point search at all. The executed block bodies come from (e) and the state roots match the certified headers.
4. `land(data, proof)` passes: `blobhash(i) == vh_i`, the precompile opens `p_B` at the contract-derived `z_i`, the guest's journal matches. The checkpoint is written with `dataCommitment = f(W)`.
5. Result: the accepting transaction's blob sidecars are not the batch's data; the real data exists only in the prover's witness. `INV-02(b)` ("a valid proof binding execution to **exactly that data**") is false, `DA-04` ("the guest MUST NOT be able to execute a batch whose payload it received only through a private witness") is violated, and R8 fails.

**Inside/outside the fault model.** Inside. It needs no assumption failure, no stake and no validator key; it is a property of any implementation whose guest takes the executed bodies from a stream other than the committed bytes, which is what PRF-03's own witness list invites. If (v) is read as forbidding that, then the defect is that the specification does not say *how* (v) is checked — i.e. there is no testable link between the decoded payload, the executed bodies and the headers. (The missing `transactions_root` check is also a completeness gap in PRF-01(W2), which claims the proof shows "executing the batch's blocks ... yields the claimed successor state root"; the state-root check makes forging bodies hard, but the claim is not listed as a check.)

**Attacker resources and cost.** One batch of honest proving work plus one type-3 blob transaction; no bond, no stake, no validator cooperation.

**Harm; requirement / decision.** R8 (public data bound to the proof), R7/R13 (complete statement; no invented rules), INV-02, DA-01/DA-03(0)/DA-04; the spirit of D5 (data and proof in one transaction) is satisfied only formally. Fix: one normative sentence — "the guest MUST obtain the block bodies it executes by decoding the committed byte string, and MUST reject unless each block's `transactions_root` equals the root of the bodies it executed" — plus a conformance test.

**Evidence.** PRF-03, PRF-06, PRF-07(b)(v), PRF-11 as quoted (frozen file, line numbers above); DA-02's contrast; DA-03(0)(v).

---

### P-R2-02 — PRF-04(vi)'s forced-inclusion check has no public inputs: the journal carries a hash, not the due set, so the check the round-1 C R1-02 fix rests on cannot be implemented

**Severity: High.** A security-relevant verification rule that the specification says is proof-bound cannot be run by any implementation of the stated journal; an implementer must either invent unbounded public inputs or trust a witness, and the L1 backstop cannot see the block contents.

**Exact rule.** `spec/05-proof-statement.html` PRF-04(vi) (lines 172–183) requires the guest to "recompute ... the capped FIFO prefix `DueCap(T)` ... from the L1-stored queue (the queue head, the eligibility timestamps and the consumed set are L1 state, supplied as public inputs or derived from values the contract reads)", to require that the batch's first block "contains exactly those requests", and that `forcedInclusionCommitment` is the canonical hash of that ordered list. PRF-02's journal (lines 57–89) contains **only** `forcedInclusionCommitment` (`bytes32`); there is no queue head, no eligibility map, no consumed set, and no list of covered `(id, payloadHash)` pairs. `spec/04-l1-integration.html` FI-01 (lines 512–531) stores `id`, `requester`, `eligibleAtL1Timestamp`, `payloadHash`, `txData` in L1 state, and FI-02(b) (lines 534–550) has the contract compute `DueCap(T)` and `setEquals(coveredIds, DueCap(T))` — but `coveredRequestIds` is a submitter input (L1-08, line 225) and the contract has no access to the block bodies.

**Assumptions / preconditions.** Any blob- or calldata-path batch that covers forced inclusions; the queue is arbitrarily long (the scan bound `MAX_FORCED_INCLUSIONS_PER_BATCH` bounds the *result*, not the state needed to decide it); request ids exist only in L1 state — the block contains `_txData`, not the id.

**Concrete attack / counterexample.**
1. A quorum certifies a block whose first block omits the due requests (CONS-01(v) calls such a block invalid, but the proof is the only mechanism that can make that objective at L1).
2. The lander supplies `coveredRequestIds = DueCap(T)` (it can read L1 state); the Inbox's `setEquals(coveredIds, DueCap(T))` passes, the escrow pays `Σ feeHeld[r]` to `feeRecipient`, and the requests are marked consumed.
3. The guest is supposed to reject step 1 by checking the block contains exactly those requests — but it has no request list, no payload hashes and no queue; the only related value in its journal is a hash it cannot preimage. It either skips the check (the R1-02 attack) or the implementer must add public inputs that PRF-02 says do not exist ("The guest commits to **exactly** the following journal").
4. The censored user's transaction is never executed, the request is consumed, the fee is paid and the queue drains — the exact outcome the round-1 C R1-02 fix claims to prevent.

**Inside/outside the fault model.** The *rule defect* is inside (structural, no attacker). The end-to-end theft/censorship trace requires a quorum to certify an invalid block (a >1/3-Byzantine, i.e. F2, condition) — but the fix exists precisely because the specification claimed the proof makes the omission objectively checkable, and as written it does not.

**Attacker resources and cost.** For the theft trace: a Byzantine quorum plus one landing transaction; the users' fees are the take. For the defect: none.

**Harm; requirement / decision.** R10 (forced inclusion must be a real remedy), R7/R13 (complete statement), R11 (fee accounting), INV-02's proof-binding claim; the L1 backstop consumes and pays for inclusions that were never made. Fix: add the bounded FI witness/public-input set to the journal (the ordered `(id, payloadHash)` list plus the queue-prefix evidence sufficient to recompute `DueCap(T)`), or move the content check into a rule the contract can enforce.

**Evidence.** PRF-04(vi), PRF-02, FI-01, FI-02(b), L1-08 `coveredRequestIds`; the round-1 C R1-02 disposition in `iterations/01-round.md` line 67.

---

### P-R2-03 — PRF-05(ii)/(iii): the epoch-anchor check is triggered by the wrong block and cannot be verified against L1 at all

**Severity: High.** The CS-08 fix (round 1) added the CONS-10(6) names but left both the trigger and the inputs wrong, so the rule that is supposed to make the epoch handoff provable either never runs for the batches that open an epoch or runs against a witness-supplied set root (PRF-03/PRF-13 violation).

**Exact rule.** `spec/05-proof-statement.html` PRF-05(ii)/(iii) (line 190): "if the batch's **head** is the first block of its epoch, the head header MUST carry the `epoch_anchor` field ... and the guest MUST recompute it from the anchor certificate it verifies — including the `cert_hash` of the closing epoch's commit certificate for `B_anchor`"; and "when the batch's **head** opens its epoch, the head header's `set_version_commit` field MUST equal the CONS-10(6) commitment ... recomputed by the guest against the same public input". `head` is defined by PRF-02 as `lastHeight` ("head height", line 79). CONS-10(6) (lines 310–335) puts both fields on "the first block of epoch `e+1`". The mandated batching alignment (PRF-05 opening; L1-06 `lastLandedHeight + 1`) makes the batch that opens an epoch start at `h_first(e+1)` and extend for several blocks — so its **head** is not the epoch's first block, and the condition is false exactly when the check is needed.

**Assumptions / preconditions.** A batch whose `firstHeight = h_first(e+1)` (or any batch containing an epoch-opening block) — the normal case at an epoch boundary; more than one block per batch.

**Concrete defect trace.**
1. Batch `[h_first(e+1), h_first(e+1)+31]` is the batch that opens epoch `e+1` (a multi-block batch, the normal case).
2. PRF-05(ii) tests "the batch's head is the first block of its epoch" → `lastHeight = h_first+31` is not the first block → the anchor check is not required.
3. Consequently `epoch_anchor` on the epoch-opening header (inside the batch range) and `set_version_commit` are never recomputed by the guest; the settled batch inherits no verified statement about the handoff. PRF-05's own sentence "the epoch-boundary evidence is checked by the batch on each side of the boundary and may not be skipped" is therefore false for one of the two sides.
4. Even for a single-block batch where the trigger fires, the guest cannot verify the anchor certificate against L1: the certificate is signed under the **closing** epoch `e`'s set, while PRF-02's journal carries exactly one `epoch`/`validatorSetRoot`/`totalVotingPower` — the batch's own epoch `e+1` (PRF-02(2)/(3), lines 98–113). PRF-05(iii) requires set commitments to be "supplied as a public input rather than as a witness"; no such input exists for epoch `e`. An implementer must either add an unregistered public input or take `set_root(e)`/`W(e)` from the witness, which is precisely what PRF-03 forbids ("No witness element may define the authoritative validator set").

**Inside/outside the fault model.** The *defect* is inside (rule as written). The *exploit* is not available under A-CONS-1: a header with a bogus `epoch_anchor` requires more than two thirds of the epoch's set to sign an invalid block (CONS-09(2), CONS-01(v)), i.e. an F2 condition. So the harm inside the model is that L1 settlement does not verify the handoff it claims to verify, and the rule cannot be implemented as written; the claimed closure of round-1 CS-08/R1-04 is incomplete. (Round 1's R1-04 was "fixed" by forbidding boundary-spanning batches; that closes the intermediate-epoch array problem but not the two-set problem on the opening side.)

**Attacker resources and cost.** To exploit: >2/3 of the epoch's set (F2). Otherwise none.

**Harm; requirement / decision.** R5/R7/R13; CONS-09's handoff (F1) is not enforced by the proof; INV-01's (P5) premise is weaker than stated. Fix: trigger on `firstHeight = h_first(epoch)` (the block that carries the fields), and add the closing epoch's `(setRoot, totalVotingPower)` to the journal (or to a clearly bounded epoch-transition input set) so the anchor certificate is L1-authenticated.

**Evidence.** PRF-05(ii)/(iii) as quoted; PRF-02's journal and its "one epoch" invariant; CONS-10(6); CONS-09(1)–(2); PRF-03/PRF-13.

---

### P-R2-04 — the batch payload's byte-level framing, which the whole DA binding is a commitment to, is defined nowhere (and PRF-09 requires two backends to agree on it)

**Severity: High.** The specification asserts the framing is fixed and points at PRF-07, which does not contain it; "the data the proof binds" is therefore not a function of the published bytes, and RISC Zero and SP1 cannot be guaranteed to implement the same statement (PRF-09).

**Exact rule.** `spec/04-l1-integration.html` DA-02, line 388: "The byte-level layout of `_data` — how L2 blocks serialise into the batch payload — is fixed once, on `PRF-07`". PRF-07 (lines 208–274) defines only the *commitment* over the byte string; it never says how blocks serialise into it. A grep of `spec/` finds no `RLP`, no `serialise/serialize`, and no other framing rule (0 hits in PRF-07 and in the whole spec directory). PRF-09 (lines 304–316) requires both backends to implement "this statement with a byte-identical journal".

**Assumptions / preconditions.** Any batch; both backends; any independent re-prover (A-DA-4) that must reconstruct the executed payload from L1 data.

**Concrete consequence (three ways it bites).**
1. **Non-injectivity.** If the decoder tolerates trailing bytes, two distinct published byte strings decode to the same blocks; the prover chooses among them, changing `dataCommitment` and hence `z`. If the decoder is ambiguous in the other direction (one byte string, two decodes), two implementations execute different block sequences from the same published data and the proof's `D` is not a function of the published bytes at all.
2. **Backend divergence.** PRF-09's portability claim ("a batch's proof is portable between backends") has no chance of holding for the decode step; a divergence between the RISC Zero and SP1 guests is a batch that lands under one image and not the other.
3. **Re-proving.** A-DA-4 and the archive duty (DA-05) assume an independent party can reconstruct the witness from public data; without a normative framing, "the payload" is implementation-defined.

**Inside/outside the fault model.** Inside; structural; no attacker needed.

**Attacker resources and cost.** None beyond the ambiguity itself; an attacker exploits non-injectivity at the cost of ordinary proving.

**Harm; requirement / decision.** R7/R13 (implementable without inventing rules), R8 (data bound to the proof), R14-adjacent (both backends), A-DA-4. Fix: move the framing rule into a normative slot (a new PRF rule or an explicit `_data` layout), including block separators, length fields and padding rules, and make DA-02 reference the real owner.

**Evidence.** DA-02 line 388; the whole PRF-07 text; the grep result (no framing rule anywhere in `spec/`); PRF-09.

---

### P-R2-05 — "the whole published byte string" is not well-defined for blobs: the committed blob set is a submitter-chosen range, extra published blobs are neither committed nor rejected, and the guest cannot see the transaction's blob count

**Severity: Medium.** An implementer must invent the rule and two readings exist in the same rule; under the range reading, bytes published in the accepting transaction are outside every commitment, so DA-01's "the canonical copy is the accepting transaction itself" has no unique meaning.

**Exact rule.** DA-03(0) (line 396): the committed object is "the concatenation, in blob index order, of the full 131,072-byte string of **every blob in the transaction**". DA-03's preamble and (i)/(v) (lines 394, 406–411, 433) instead iterate over the submitter-declared range `[blobIndexStart, blobIndexStart + n)`, and L1-08's `LandInput` carries `blobIndexStart` and `blobCount` (lines 219–220). `blobHashesHash` is a single `bytes32` in the journal (PRF-02 line 85); there is no blob count, no per-index versioned hash list, and no `BLOBHASH` inside the guest, so the guest cannot determine the transaction's blob count at all — it can only be told.

**Assumptions / preconditions.** Blob or hybrid path; a transaction carrying more blobs than the declared range (EIP-7691 allows up to 9 per block).

**Concrete trace.** Submit a type-3 transaction with three blobs; set `blobIndexStart = 0`, `blobCount = 2`; publish the batch payload in blobs 0–1 and arbitrary bytes in blob 2. The contract loops over {0,1}, the precompile opens those, and `dataCommitment = f(blob_0 || blob_1)`. Blob 2's bytes are in the accepting transaction, are retained by archives under DA-05 ("full blob sidecars"), and are in no commitment and no check. A consumer following DA-03(0) literally hashes all three blobs and cannot reproduce `dataCommitment`; a consumer following the range reading can — and neither L1 state nor the `BatchLanded`/`CheckpointAdvanced` events record `daMode`, `blobIndexStart` or `blobCount` (L1-07 fields, lines 175–183), so the range must be brute-forced from the transaction.

**Inside/outside the fault model.** Inside; cheap; no assumption fails.

**Attacker resources and cost.** Blob gas for the unbound blob(s); no stake. (There is no direct profit; this is an ambiguity/auditability and canonical-DA defect, which is why it is Medium and not High.)

**Harm; requirement / decision.** R8, DA-01, DA-03(0), DA-05's archive definition; an implementer must choose between two contradictory statements, and under one of them the batch's canonical bytes are not determined by its accepting transaction.

**Evidence.** DA-03(0) vs DA-03 preamble/(i)/(v) and L1-08's range fields; PRF-02 line 85; L1-07 checkpoint fields.

---

### P-R2-06 — the "Proven" blob-path argument is stated over the wrong variable and treats the attacker's own blob as pinned

**Severity: Medium.** The *rule* survives my re-attack, but the argument attached to it does not establish it: it searches over the pinned quantity and declares the free quantity pinned, so the `Proven` pill for PRF-07/DA-03 is not supported by the text, and Q-A3 is not closed by it.

**Exact rule.** DA-03 "Why this is sound" (lines 435–447); PRF-07 "Why (b) is sound" (lines 247–269); the `Proven` pills at PRF-07 line 270 and DA-03 line 466.

**Assumptions / preconditions.** None; this is a defect in the reviewability and correctness of the security argument (the rule's conclusion is, on my analysis, correct under KZG binding + ROM).

**Worked counterexample to the argument (not to the rule).** The text's experiment is "the prover searches over candidate payloads `D`... for any fixed candidate the probability is at most 4095/|F|". But the same text says `D` is pinned by the certificate; a pinned variable is not searched. The attacker's free variable is the published blob `B`; the text says "the precompile pins the published blob polynomial `p_B`", which is false — `B`'s commitment and versioned hash are authored by the attacker's transaction. If one takes the text at face value and removes the certificate-pinning assumption (e.g. via P-R2-01), the text implies the binding is unconditional, which it is not.

**Inside/outside the fault model.** Inside (documentation/argument defect); consequence is that reviewers cannot tell which premise is load-bearing, and the implementation gate (F2/Q-A3) is anchored to an argument that does not address the attacker's actual freedom.

**Attacker resources and cost.** n/a.

**Harm; requirement / decision.** R7's evidence tag ("Proven"), R13; Q-A3 remains open on the text as written. Fix: restate as in "Verdicts" §1 — free variable `B`, `z` moves with `blobHashesHash`, KZG binding keeps `z` fixed only at the cost of a binding break; bound over blob candidates.

**Evidence.** DA-03 lines 438–447 and PRF-07 lines 247–269 as quoted; DA-03 premise (1) KZG binding.

---

### P-R2-07 — PRF-07 says the journal records which data path was proven; no journal field does, and a transcript input has no binding row

**Severity: Medium.** PRF-02 is declared exact and L1-05 is declared the whole bound vector, and they disagree on exactly the fields the blob-path verifier needs; the general mismatch is a separate round-2 finding (independently reached), so what is counted here is the blob-path-specific half.

**Exact rule.** PRF-07 line 209: "Exactly one of the following holds, and the journal records which." PRF-02's journal has no `daMode` (or other path selector); L1-05 row 17 defines `daMode` as a bound value and L1-08 passes it. DA-03(iii)/L1-05 row 18 put `blobHashesHash` in the challenge derivation, but `blobHashesHash` is not one of L1-05's 21 rows (it appears only inside row 18's formula text); PRF-02 lists it as a journal field. `challengeY[i]` (row 19) vs `evaluationsY[]` (PRF-02) differ in name, and PRF-02's list lacks `previousCheckpointHash`, the timestamps, `finalityCommitment` and `feeRecipient`, all of which L1-05 requires to be bound.

**Assumptions / preconditions.** Any batch; the mismatch is structural and is the same defect class as the round-1 R1-06 item 5, whose disposition ("one definition — the commitment covers the same bytes...") does not address the vector.

**Concrete consequence.** An implementer must reconcile two "exact" lists. Implementing L1-05 literally makes the contract hash ≥5 values the guest never committed to, so the verifier's `statementHash` cannot match any proof (no batch lands); implementing PRF-02 literally drops those bindings, and the most concrete casualty for this angle is `daMode`: a calldata-path journal (empty challenge arrays) is then indistinguishable from a blob-path journal in the proof, and the path selector's binding depends on the implementer's resolution.

**Inside/outside the fault model.** Inside; structural.

**Attacker resources and cost.** n/a (defect).

**Harm; requirement / decision.** R7/R13; the verifier cannot be written as specified; PRF-07's own sentence is unsupported. Fix: one canonical statement vector, stated once (extend PRF-02 or L1-05 and make the other a reference), including the path selector and `blobHashesHash`.

**Evidence.** PRF-07 line 209; PRF-02 lines 57–89; L1-05 rows 16–19 and 21; L1-08 `LandInput`.

---

### P-R2-08 — the evidence window and the unsettled-depth cap are mutually unsatisfiable: ECON-07's "must not be empty" interval can close before the omission offence is even constructible

**Severity: High.** ECON-07's own standard — "a parameterisation under which the interval can be empty ... is a defect, not a tuning choice" — is violated by two other normative formulas; the omission offence (the forced-inclusion backstop, R10) becomes unpunishable whenever the backlog is deep, and closing it by raising `W_evidence` breaks the ECON-07(2) inequality instead.

**Exact rules.** `spec/07-economics-slashing.html` ECON-07(1) `evidenceClose(e) = t_root(e) + W_evidence(e)`; ECON-07(2) `W_evidence + T_process + CORR_DELAY + M_ev < D_withdraw`; ECON-07(4) requires `W_evidence(e) ≥ 2·E_epoch + T_PROOF_MAX_PERMITTED + T_L1_include(p) + T_L1_final + T_detect + T_evidence_submit` and requires the interval `[t_offence, evidenceClose(e)]` to contain the whole pipeline "for every admissible offence". ECON-04's omission row (lines 253–263) says the window "opens at the L1 acceptance of the batch carrying `B`". `spec/06-recovery-exceptions.html` HALT-03 (lines 92–118) and `spec/09-parameters.html` (line 97) define `D_MAX = floor((RETENTION_WINDOW − T_PROOF_MAX_PERMITTED − T_SETTLE_PIPELINE) / L2_BLOCK_INTERVAL)` and require validators to refuse a block at depth `> D_MAX − MARGIN_V`. `spec/03-membership-staking.html` MEM-05(4) defines `D_withdraw` with the same single-pipeline terms and no backlog term.

**Worked counterexample (no assumption fails, data is available).**
1. Data availability holds (A-DA-2/A-CONS-5): blobs are retrievable for `RETENTION_WINDOW ≈ 4096 epochs ≈ 18 days` (DA-05), which is why `D_MAX` may be that deep.
2. With `L2_BLOCK_INTERVAL = 2 s`, `D_MAX ≈ (18 d)/2 s ≈ 7.8×10^5` L2 blocks ≈ 18 days of L2 history. The cap permits settlement to lag production by that much; the retention window is sized for exactly that (DA-06).
3. An offence at `h_last(e)` (the last block of epoch `e`) becomes evidenced only when its batch is accepted on L1 (ECON-04 row), which can be up to `D_MAX` blocks later, i.e. of the order of days.
4. `W_evidence` is bounded below by `2·E_epoch + T_PROOF_MAX + … ≈ 1.5 h + pipeline` (`E_epoch = 1800 s`) and above by ECON-07(2) with `D_withdraw ≈ T_PROOF_MAX + T_detect + T_evidence_submit + T_L1_include + T_L1_final + T_process + M` ≈ hours. Neither bound contains the backlog term, so for a deep backlog the interval is empty: the offence is unpunishable by construction, which ECON-07(4) forbids. No value of `W_evidence` satisfies both inequalities, because ECON-07(4) needs ≈`D_MAX·2 s` while ECON-07(2) caps it at ≈`D_withdraw`.
5. Aggravating inconsistency: the same quantity is capped twice in different units and with unregistered parameters — DA-06's `MAX_UNSETTLED_AGE` in **L1 blocks** with `RETRIEVABILITY_WINDOW` in **L1 block numbers** and an `ARCHIVE_REQUIREMENT`, versus HALT-03/PARAM-01's `D_MAX` in **L2 blocks** with `RETENTION_WINDOW` in **seconds**; `MAX_UNSETTLED_AGE`, `ARCHIVE_REQUIREMENT` and `RETRIEVABILITY_WINDOW` do not appear in PARAM-01 at all, while `RETENTION_WINDOW` does.

**Inside/outside the fault model.** Inside: normal operation, data available, no Byzantine behaviour needed.

**Attacker resources and cost.** A proposer that omits a due forced inclusion when the backlog is deep pays nothing; the defence (slashing) is time-barred before the evidence exists. Cost: zero beyond the omitted inclusion itself.

**Harm; requirement / decision.** R11 (objective misconduct evidence and collateral) and R10's deterrent half; ECON-07(2)/(4) and ECON-04's deadline cannot all hold. Fix: make the window's lower bound and `D_withdraw` include the maximum settlement lag permitted by the cap (or bound the cap by the window), reconcile the two caps' units and register both parameters.

**Evidence.** ECON-07, ECON-04 omission row, HALT-03, PARAM-01/PARAM-02 `D_MAX`/`RETENTION_WINDOW`, MEM-05(4), DA-05/DA-06.

---

### P-R2-09 — MEM-06(2)'s exposure cap contradicts MEM-05(3)'s all-windows-closed withdrawal gate; under the cap reading a multi-epoch offender escapes part of its penalty

**Severity: Medium.** The two rules give different conditions for the same transition and the specification says both are normative; one reading (the exposure-cap rule's own words, "at any moment") permits a withdrawal that ECON-08(5)(a) certifies is unreachable. (This is the residual of round-1 R1-10, which the round-1 disposition table never resolved.)

**Exact rules.** `spec/03-membership-staking.html` MEM-06(2) (lines 325–329): "At any moment the owner may withdraw at most `bonded(v) − max_exposure(v)`", with `max_exposure(v) = max{SlashBase(v,e) : e open}`. MEM-05(3) (lines 279–281): the owner may withdraw **only when all three hold**: (a) `D_withdraw` elapsed, (b) the evidence window closed **for every epoch the entry was in**, (c) no unsettled exposure. ECON-07(5) repeats the strict gate; ECON-08(5)(a) claims the state "withdrawn stake exposed to a still-open epoch" is unreachable "by construction".

**Concrete trace (cap reading).**
1. Offender equivocates at epochs `e1` and `e2` (both windows open), each with `SlashBase = SB`. MEM-06(2) caps withdrawal at `bonded − max(SB, SB) = bonded − SB`.
2. The offender withdraws `bonded − SB` while both offences are still chargeable (ECON-08(3): the total charge for the two epochs is bounded per epoch, so `2·SB` is chargeable).
3. The remaining balance is `SB`; the second slash is applied as `min(requested, b(v))` and the remainder is recorded as unapplied and not collected (ECON-01 INV-C, ECON-05 clause 3). Half the intended penalty escapes.
4. ECON-08(5)(a)'s "unreachable by construction" is false under this reading; the correct reading (MEM-05(3) governs) makes MEM-06(2)'s "at any moment" clause vacuous, so the two rules cannot both be implemented as written.

**Inside/outside the fault model.** Inside; no assumption failure; the attacker is the offender itself.

**Attacker resources and cost.** One bond; the gain is the escaped part of the correlated penalty (up to `(n−1)·SlashBase` for `n` open epochs).

**Harm; requirement / decision.** R11 (collateral that actually backs the offence), INV-03's "exiting after an offence does not escape the penalty"; the withdrawal-race defence that MEM-06(3) claims is jointly necessary fails. Fix: state which clause governs (the strict gate), or replace `max` with the sum of open exposures and make MEM-06(2) explicitly subordinate to MEM-05(3).

**Evidence.** MEM-06(2)/(3), MEM-05(3), ECON-07(5), ECON-08(3)/(5), ECON-01 INV-C; round-1 R1-10 (raw report) with no disposition row.

---

### P-R2-10 — ECON-03(6)'s per-epoch churn cap has no mechanism in the exit rule it defers to

**Severity: Medium.** The rule that owns exit effectiveness fixes a different condition, and the ledger hook the cap would need ("current ledger state" at `commitSet`) is not defined to consider it; an implementer must invent which exits are deferred. (Independently reached; it is the same class as the compliance angle's churn finding, recorded here for completeness of the assigned ECON-03 check.)

**Exact rules.** `spec/07-economics-slashing.html` ECON-03(6) (lines 192–204): the L1 staking contract "MUST NOT make more than `CHURN_LIMIT · TotalVP(e)` of effective stake inactive at any single epoch `e`"; exits beyond the cap are "deferred to later epochs in the objective request order of MEM-05". `spec/03-membership-staking.html` MEM-05(2) (lines 277–278): "Exit becomes effective at the **first** set version whose snapshot point is at or after the exit request transaction's L1 block ... It cannot be cancelled after that point." MEM-09(1) fixes `commitSet()`'s contents as "the ledger state at the moment of the call" and gives the cap no input.

**Concrete consequence.** With the churn cap binding, "the first set version at or after the request" and "deferred by the cap" are different rules; the cap's own ordering is "the objective request order of MEM-05", but MEM-05 defines no global request order across entries and MEM-09(1) gives `commitSet()` nothing to read. An implementer chooses: implement MEM-05(2) verbatim (the round-1 ECO-07 churn cap is inert, and a coordinated exit drops the deterrence level in one step) or invent the deferral mechanics (which entries, how the cap is metered, how `withdraw()` behaves for deferred entries).

**Inside/outside the fault model.** Inside; structural.

**Attacker resources and cost.** For the inert-cap reading: a coalition of exiting operators, cost = the stake it withdraws (which is the attack the cap exists to slow).

**Harm; requirement / decision.** R11 (exits and collateral), A-ECO-1's deterrence relation; R13. Fix: name ECON-03(6) in MEM-05(2) as the governing condition and specify the deferral state and ordering.

**Evidence.** ECON-03(6), MEM-05(2), MEM-09(1); round-1 ECO-07 disposition ("per-epoch churn limit added") which added the rule but not the mechanism.

---

### P-R2-11 — the certificate/vote checks never bind `chain_id` to the journal

**Severity: Low.** A replay-domain field that CONS-01 requires for proposals is not required for certificates or votes; the round-1 R1-17 fix added `type` and `validator_index` but not `chain_id`.

**Exact rules.** PRF-04(i) (lines 143–153) binds `type = PRECOMMIT`, `validator_index`, `block_id`, and the certificate's epoch/height/round, but not `chain_id`; CONS-05 (lines 165–168) validates a certificate under `epoch = epoch_of(H)`, the L1 set root and quorum, and never requires `certificate.chain_id == l2ChainId`; the signed bytes do include `chain_id` (CONS-02 encoding table), and CONS-01(i) checks `P.chain_id` only for proposals. PRF-02 has `l2ChainId` (L1: config), so the value exists; no rule says the reconstruction must use it.

**Concrete consequence.** An implementer who reconstructs the vote bytes with the certificate's own `chain_id` (which is witness-supplied) rather than the journal's L1-derived `l2ChainId` would accept signatures made on a sibling chain with the same keys; threat T-14 (replay across domains) is not closed by a rule. Practical exploitability is low because the set root itself commits to `chainId` (MEM-08 leaves include it), which is why this is Low and not higher. Secondary wording defect in the same sentence: "the certificate's epoch, height and round equal to those of the head block" — no header field carries a round (CONS-10(1)), so the intended comparison is undefined.

**Inside/outside the fault model.** Inside (rule completeness).

**Attacker resources and cost.** Requires keys valid on a sibling chain under the same L1 staking state; not demonstrated.

**Harm; requirement / decision.** R7/R13, A-CRYPTO-2/T-14. Fix: add `certificate.chain_id == l2ChainId` (and use `l2ChainId` in the reconstruction) to PRF-04(i)/CONS-05; drop or define the round comparison.

**Evidence.** PRF-04(i), CONS-05, CONS-02 encoding table, CONS-01(i), PRF-02.

---

### P-R2-12 — the learning page still teaches the coefficient-form blob interpretation and the obsolete challenge derivation

**Severity: Medium.** R14 requires the learning site to match the specification; the lesson that is supposed to explain the round-1 R1-02 fix states the defect that was fixed.

**Exact rule.** `learn/08-atomic-data-and-proof.html` line 69: "The guest independently interprets the blob bytes it actually executed as **4096 coefficients**, rejects any non-canonical chunk, evaluates its own polynomial at `z`..." — against `spec/04-l1-integration.html` DA-03(iv) (line 430) and `spec/05-proof-statement.html` PRF-07(b)(iv) (lines 237–242), which make the EIP-4844 **evaluation-form / bit-reversed** interpretation normative. The same page (lines 60–63) describes `z` as "hashing all the other public inputs", which is neither DA-03(iii)'s per-blob derivation nor its field list (`domain`, `l2ChainId`, `statementCoreHash`, `dataCommitment`, `blobHashesHash`, `uint16(i)`).

**Concrete consequence.** A reader implementing the lesson produces a guest whose polynomial differs from the committed one, so every honest blob-path proof fails — the exact failure mode round-1 R1-02 identified; and the page's own claim that this is "about 2^-243 per attempt" is attached to the wrong polynomial.

**Inside/outside the fault model.** Inside; documentation.

**Attacker resources and cost.** n/a.

**Harm; requirement / decision.** R14 (learning site consistent with the specification), R7-adjacent. Fix: update the lesson to the evaluation-form convention and the full per-blob transcript.

**Evidence.** learn/08 line 69 and lines 60–63; DA-03(iv); PRF-07(b)(iv); DA-03(iii).

---

## Checked and deliberately not counted

- **Disclosed implementation gates** — the blob path's status as an implementation gate, the unmeasured in-guest Lagrange cost (F2, PARAM-03), the calldata fallback, the 2 s cadence (F3) and the prover-fleet inputs (F4) are disclosed with their consequences; none violates D1–D7 or R1–R14 *by being disclosed*, so they are not findings. P-R2-06 is about the argument's validity, not about the gate.
- **Named cryptographic premises** — KZG binding and the random-oracle model for Fiat–Shamir are named in DA-03's premises list; my re-attack uses them the same way and finds the construction sound under them (subject to P-R2-01/P-R2-04).
- **PRF-08's honesty** — the rule states its premises and its failure behaviour; the only gap (the epoch-opening anchor) is counted in P-R2-03.
- **ECON-06's slashed-stake destination** — explicitly Open with its consequence stated; not counted.
- **Overlap with the round-2 compliance/economics report** — the general PRF-02-vs-L1-05 mismatch (my P-R2-07 covers only the blob-path half, but I independently reached the same general conclusion from the blob angle) and the churn-cap/MEM-05 conflict (my P-R2-10) are matters the judge should merge rather than double-count. P-R2-01/P-R2-02/P-R2-03/P-R2-04/P-R2-05/P-R2-06/P-R2-08/P-R2-09/P-R2-11/P-R2-12 were reached from this angle's own reading.

## Counts

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 5 (P-R2-01, P-R2-02, P-R2-03, P-R2-04, P-R2-08) |
| Medium | 6 (P-R2-05, P-R2-06, P-R2-07, P-R2-09, P-R2-10, P-R2-12) |
| Low | 1 (P-R2-11) |

**Fault-model status.** P-R2-01, P-R2-04, P-R2-08 need no assumption failure and are inside the fault model end to end. P-R2-02's rule defect is inside; its end-to-end theft/censorship trace needs a Byzantine quorum (>1/3), i.e. F2 — but the rule exists to make that trace objectively checkable and cannot run. P-R2-03's defect is inside; its exploit needs >2/3 of an epoch's set (F2). P-R2-05/P-R2-06/P-R2-07/P-R2-09/P-R2-10/P-R2-11/P-R2-12 are inside (structural, no attacker or no assumption failure). No Critical was found in this angle: the round-1 blob attack is closed in substance, and the two cheap attacks that remain (P-R2-01, P-R2-02) are rule-level gaps whose end-to-end exploitation depends on the implementer's reading or on a Byzantine quorum, hence High.
