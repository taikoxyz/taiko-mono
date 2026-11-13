# Round 2 — adversarial review, angle A: consensus safety, hidden certificates, reconfiguration

**Reviewer:** fresh independent adversarial reviewer (round 2, angle A).
**Frozen snapshot under review:** 5e4129913e2540ac42c5c8b5034b64cdc3a5c8f1 (the round-1 fixes, applied in place).
**Round-1 baseline for diffing:** dfcf067a5b91a1b0bacd4470f5f5054d1f861a24 — I diffed every spec page between the
two commits to isolate exactly what the round-1 amendments changed, and re-attacked the changed rules first. Italic
"(review round 1, finding X)" notes were treated as claims.
**Scope:** spec/02-consensus.html (CONS-01..15), spec/03-membership-staking.html (MEM-01..12),
spec/06-recovery-exceptions.html, with the supporting rules they consume (spec/04-l1-integration.html L1-01..08/FI-02,
spec/05-proof-statement.html PRF-02..05, spec/09-parameters.html, spec/10-assurance.html).
**Verdict up front:** the amendments do close several round-1 findings (see section "Checked and actually closed"), but
the two load-bearing round-1 fixes in this angle — the epoch-to-set binding via the append-only L1 mapping (CS-01/B R1-03)
and the epoch-boundary header commitments (CS-08) — introduce new Critical/High defects of exactly the same class, and the
amendment's own proof-side enforcement of the handoff is bypassable.

**Counts (this report): Critical 1, High 6, Medium 4, Low 1.** All Critical/High findings are inside the claimed fault
model unless explicitly stated otherwise (R2A-03/R2A-05 are specification defects whose enabled shortcut is inside it).

---

## R2A-01 — Critical — the one-epoch lookahead is gated on the L1-accepted L2 head, which under D5+D6 lags by up to the whole epoch; every epoch boundary is then a guaranteed production halt, violating D6/R4/D1

**Severity (one line):** the gate added to close round-1 CS-01 consumes the entire one-epoch commitment window with the
proving pipeline that the fixed decision D6 declares normal, so the L2 stops producing at every boundary — a
fixed-decision violation that needs no adversary at all.

**Exact rule / missing rule.**
- spec/03-membership-staking.html **MEM-09(1)**: "A call MUST revert if the epoch's entry already exists (append-only; no
  overwrite), and MUST revert unless the immediately preceding epoch has already begun, **derived by the contract from the
  Inbox's last accepted L2 height** and the L1-committed schedule; this bounds the append to the one-epoch lookahead of
  CONS-13(3) ... If the Inbox cannot accept a batch in epoch e, the entry for e+1 cannot be appended, and the epoch boundary
  halts (CONS-13(5)) ..."
- **MEM-09(5)**: "mapping[e] must be Ethereum-final before any block of epoch e may be finalized; a validator must not
  produce the first block of epoch e unless mapping[e] is already Ethereum-final."
- spec/02-consensus.html **CONS-13(3)**: "The one-epoch window gives the commitment transaction the whole of epoch e — by
  construction of L, the D1 cadence and the D6 envelope, roughly 30 minutes — to be included and finalized".
- Under **D5** (L1-01) the Inbox's last accepted height advances only when a land(data, proof) transaction is accepted, so
  it lags the produced L2 head by the end-to-end pipeline: proving latency **plus** witness generation, queueing and L1
  inclusion (the spec/09 glossary explicitly excludes these from "proving latency"), **plus** the L1 finality of the
  appending transaction itself. spec/09 PARAM-02 fixes T_PROOF_ENVELOPE = 1800 s, E_EPOCH = 1800 s, and Ethereum finality
  depth = approx. 2 epochs (approx. 768 s).

**Assumptions / preconditions.** None beyond the specification's own numbers: D1 (2 s), D5, D6 (30 min is normal), L = 900
(= 1800 s). No Byzantine stake, no key compromise, no implementation bug is needed.

**Concrete worked counterexample (normal operation, no attacker).**
Let T_e be the wall time at which block h_first(e) is produced, LAG the end-to-end pipeline lag in seconds, and F = approx.
768 s the Ethereum finality depth of an L1 transaction.
1. The gate for epoch e+1 opens when the *accepted* height reaches h_first(e), i.e. at T_e + LAG (a steady pipeline with
   lag LAG accepts at time t the block produced at t-LAG; the lag in heights is approx. LAG/2 blocks, independent of the
   batch size K, by Little's law).
2. The entry for e+1 may then be appended; MEM-09(5) forbids *producing* any block of e+1 until that entry is
   **Ethereum-final**, i.e. until T_e + LAG + F.
3. The boundary is due at T_e + 1800 s. Slack = 1800 - LAG - F.
4. At the D6 envelope (LAG = approx. 1800 s from proving alone, before witness, queueing and inclusion), slack is -768 s:
   **the L2 produces nothing for approx. 12.8 min at every epoch boundary**, and each epoch takes approx. 2568 s of wall
   time instead of 1800 s (approx. 30 percent throughput loss, with a hard 2 s-cadence stop at the boundary). The halt
   threshold is LAG >= 1032 s (approx. 17.2 min), well inside D6's "a few minutes to 30 minutes is normal".
5. The stall is per-boundary and does not compound (while halted, proofs catch the accepted height up and the entry becomes
   final), but it recurs at *every* boundary for as long as the proving pipeline is inside the envelope D6 declares normal.

**Attacker variant, sub-threshold and cheap (inside the fault model).** An actor that can delay acceptance of *one* batch of
epoch e — by censoring the proof transaction on L1 for approx. 20 min (T-7), by withholding the witness for the
epoch-opening batch (T-12), or by a prover cartel refusing that batch (T-9) — pushes LAG above 17.2 min and forces the
halt, without stake, without a validator slot and without violating A-L1-1 (which bounds inclusion delay by nothing). It
can also *time* the resulting snapshot (see R2A-09). Cost: L1 fees or one withheld proof. No slashing exposure: a prover is
never slashable for lateness (WH-01; ECON-04(5): "a prover that is slow inside the D6 envelope" is not an offence, and the
halt threshold is inside the envelope).

**Inside or outside the claimed fault model.** Inside. The no-adversary variant is normal operation; the attacker variant
uses only T-7/T-9/T-12, all in the threat model, and A-L1-1 supplies no numeric inclusion bound.

**Harm and requirement / fixed decision affected.** D6 is broken in terms of its own text ("L2 keeps producing 2 s blocks
and reaching the selected mode's PoS confirmation throughout" a 30-minute proof); R4 (2 s cadence under stated operating
assumptions), R6 (conditional liveness — LIVE-01(L6) is the exact premise that fails, and it fails because the design's own
gate makes it unsatisfiable, not because an external assumption failed), D1. CONS-13(3)'s "the whole of epoch e" budget
claim is false as written.

**Disclosure check (required before counting this).** MEM-09(5) does say validators "hold the current epoch open or halt"
when the append is not yet permitted, and LIVE-01(L6)/CONS-13(5) list the missing entry as a liveness end-condition. That
discloses *that the gate can block*. It does not disclose that under the fixed D6 envelope the gate blocks **always and by
construction**, and it does not retract CONS-13(3)'s assertion that the window is a full epoch; LIVE-01 presents L6 as an
assumption that may fail rather than a premise the design itself falsifies at the target operating point. A disclosed
limitation that violates a fixed decision is still a finding, and D6 is a fixed decision.

**Evidence.** MEM-09(1)/(5), CONS-13(3)/(5), L1-01, L1-06, PARAM-02 (T_PROOF_ENVELOPE, E_EPOCH, finality depth), the
spec/09 glossary entry for "Proving latency", R4/D6 in README.md and 01-requirements-and-threat-model.md.
**Construction note:** MEM-09(1)'s gate is new in the round-1 snapshot (it is the CS-01 fix); CONS-13(3)'s budget sentence
predates it and was not adjusted, so the fix and the claim now contradict each other.

**Fix direction (for the fixer, not a requirement of this finding).** Either (a) make the append gate independent of the
L1-accepted L2 height (e.g., keyed to the L1-committed schedule plus the Inbox's accepted *epoch* observed one epoch
earlier), or (b) move to a **two-epoch** lookahead: append the entry for e+2 during epoch e. Both also fix R2A-02.

---

## R2A-02 — High — CONS-10(1) requires every header of epoch e to carry the epoch-(e+1) set root, but MEM-09(1)'s one-epoch lookahead means that root does not exist until late in e; the field is unsatisfiable and its value is left to the implementer

**Severity (one line):** a normative header field is demanded for blocks produced before the L1 fact it must commit to has
been created, so no correct value exists; two honest implementations will hash different headers.

**Exact rule / missing rule.**
- **CONS-10(1)**: "Every block header carries two set commitments, validators_hash, the commitment to the set of
  epoch_of(H), and next_validators_hash, the commitment to the set of epoch_of(H)+1. Both are the L1-committed
  validator-set root of MEM-08: ... next_validators_hash = R_{setVersion(epoch_of(H)+1)}."
- **CONS-13(3)/MEM-09(1)**: the entry for epoch e+1 is appended **during epoch e** (that is what "one-epoch lookahead"
  means, and the gate forbids appending it earlier because the entry's "immediately preceding epoch" is e).
- Therefore, for every header of epoch e produced before that append lands, setVersion(e+1) is *undefined* (MEM-09(2): the
  version is the one recorded by the epoch's entry), and R_{setVersion(e+1)} does not exist in L1 state or anywhere else.
  The entry cannot land at the start of e either: the gate needs the Inbox to have accepted a height in epoch e, which is
  produced after h_first(e) and settled a pipeline-lag later.
- No rule says what such a header carries, and **PRF-03(c)** requires the guest to check that "each header's
  validators_hash and next_validators_hash — both MUST be the single canonical MEM-08 root of the set they commit to" — a
  check that cannot be satisfied for those headers against any L1 fact (the journal carries only the batch epoch's root,
  PRF-02). **CONS-10(4)** then uses the field for epoch-change authentication ("require the new header's validators_hash to
  equal its predecessor's next_validators_hash").
- Genesis makes it acute and provable: **CONS-14(1)** records only the epoch-0 entry in the activation transaction, while
  **CONS-14(3)** asserts "every header of epoch 0 carries validators_hash = set_root(0) and next_validators_hash =
  set_root(1), and a verifier checks both against L1". set_root(1) cannot exist at activation, because its entry can only
  be appended after epoch 0 has begun *and* the Inbox has accepted a height in epoch 0.

**Assumptions / preconditions.** None. This is a contradiction between CONS-10(1)/(3), CONS-14(3), MEM-09(1) and PRF-03(c).

**Concrete failure trace.**
1. Two honest clients implement next_validators_hash for pre-append headers differently: client X writes zero (mirroring
   CONS-10(6)'s zero-for-absent convention for the transition fields), client Y writes the most recent root it knows,
   client Z refuses to produce blocks until the value exists.
2. X and Y hash the same logical block differently, so the header hash, the block hash, the certificate's block_id and the
   batch's prevBlockHash chain diverge: two internally valid histories exist, and the guest rejects the other client's
   headers in PRF-04(v)/PRF-03(c). Z stalls production for the pipeline lag at the start of every epoch (a second route to
   R2A-01's halt, this one *mandatory* rather than incidental).
3. A light client cannot recompute the expected header value from L1 facts alone at all: the value rule depends on a
   future L1 transaction, so the header is not a pure function of the block's own content and the epoch schedule.

**Inside or outside the claimed fault model.** Inside: rules alone, no adversary. CONS-09(5)(iii) lists "the interaction
with next_validators_hash authentication when e+1's set root was committed during e" as something the F1 argument does not
cover — but that is an admission that the handoff argument is incomplete, not a disclosure that the CONS-10(1) value rule
is unsatisfiable for most headers of every epoch; the rule is stated unconditionally and is referenced by PRF-03(c) as a
MUST.

**Attacker resources and cost.** None; the harm is an unsatisfiable rule and a client-split surface (F3 today, a consensus
split if two clients are deployed).

**Harm and requirement affected.** R13 (implementable without inventing rules), R7 (complete statement), CONS-10's
authentication procedure, and it compounds R2A-01. Also R5/F1: the boundary authentication the handoff needs is not
well-defined.

**Evidence.** CONS-10(1)/(3)/(4), CONS-13(3), MEM-09(1)/(2), CONS-14(1)/(3), PRF-02 (closed journal), PRF-03(c),
CONS-09(5)(iii).

---

## R2A-03 — High — the round-1 boundary checks in PRF-05 are conditioned on the *head* being the first block of its epoch, so the prover can always skip them by choosing a batch range whose head is not the boundary block

**Severity (one line):** the amendment that was supposed to make the epoch handoff checkable in the proof attaches both new
checks to a condition the prover controls and can trivially falsify, so the "forbidden shortcut" of CONS-09(5)(i) remains
undetectable at L1 acceptance.

**Exact rule / missing rule.**
- **PRF-05(ii)**: "if the batch's head is the first block of its epoch, the head header MUST carry the epoch_anchor field
  of CONS-10(6) and the guest MUST recompute it from the anchor certificate it verifies ...", closing with "the
  epoch-boundary evidence is checked by the batch on each side of the boundary and may not be skipped".
- **PRF-05(iii)**: "when the batch's head opens its epoch, the head header's set_version_commit field MUST equal ...".
- A batch that opens epoch e+1 must start at h_first(e+1) (L1-06 contiguity from the checkpoint at h_last(e); PRF-05
  forbids spanning, so the split is at the boundary). Its **head** is h_first(e+1) + k - 1 for a batch of length k, which
  is the first block of the epoch only when k = 1. Nothing fixes k = 1: PRF-05 only requires that a boundary-crossing
  range be split, and L1-04 lets any account land any contiguous range from lastLandedHeight+1 — so the **prover chooses
  k**.
- No L1 rule supplies the missing check: L1-05's binding list (rows 1-21) contains no epoch_anchor, cert_hash or
  set_version_commit row, and PRF-02's journal has no field for them.

**Assumptions / preconditions.** A prover (permissionless, L1-04) that chooses a batch length k > 1 for the batch opening
an epoch. No stake, no validator key, no consensus fault.

**Concrete attack trace.**
1. Epoch e closes at h_last(e); the checkpoint is landed there. The prover builds the next batch as
   [h_first(e+1), h_first(e+1)+31] (the placeholder K = 32).
2. Its first (boundary) block carries an epoch_anchor that has never been recomputed against any real certificate, and a
   set_version_commit that does not recompute from the L1 mapping entry.
3. PRF-05(ii)/(iii) do not apply, because the head is not the first block of its epoch; no other guest rule recomputes
   either field (PRF-03(c) checks validators_hash/next_validators_hash, and PRF-04(v) only hashes the header chain back to
   prevBlockHash). The proof verifies, L1 accepts, the batch settles.
4. An implementation that ignores epoch_anchor entirely — the CONS-09(5)(i) shortcut whose adoption "removes the entire
   safety argument of CONS-09(4)" — therefore produces proofs indistinguishable from correct ones at L1. The handoff is
   enforced only by the validators' own duty (CONS-09(2)), which the amendment claimed the proof now backs.

**Inside or outside the claimed fault model.** The gap is a specification defect (R13/R7). The shortcut it leaves open is
inside the fault model exactly as CONS-09's own failure mode states: a proposer (T-3) plus a fresh epoch-e+1 set creates a
boundary fork in which no validator of the old set misbehaved.

**Attacker resources and cost.** Zero extra stake; a batch-range choice and (for the shortcut) an implementation that does
not check the field.

**Harm and requirement affected.** R7 (the statement does not bind the epoch transition), R13, CONS-09(5)(i)'s "forbidden
shortcut" is unenforced, F1. The round-1 CS-08 disposition ("the epoch-boundary checks now name the CONS-10(6) objects") is
not delivered: the checks are conditional on a prover-chosen property.

**Evidence.** PRF-05(ii)/(iii) text; PRF-02 journal list; L1-05 rows 1-21; L1-04; L1-06; CONS-09(5)(i); CONS-10(6).

---

## R2A-04 — High — set_version_commit has no public input: PRF-05(iii) says the guest recomputes it "against the same public input", but neither the closed journal (PRF-02) nor the L1 binding list (L1-05) carries (setVersion, N)

**Severity (one line):** the CS-08 fix added a header field and a guest check whose required public input was never added,
so the check is unimplementable and the transition tuple is unbound in the proof — the CS-05 class survives for the value
CS-08 introduced.

**Exact rule / missing rule.**
- **CONS-10(6)**: set_version_commit = keccak256(abi.encode("TAIKO_ETNA_SETVERSION_V1", chainId, epoch, set_version, N))
  where (set_version, N) is the L1 mapping entry's pair.
- **PRF-05(iii)**: "the head header's set_version_commit field MUST equal the CONS-10(6) commitment to the L1 mapping
  entry (set_version(e), N(set_version(e))) of the batch's epoch e, **recomputed by the guest against the same public
  input**".
- **PRF-02** opens "The guest commits to exactly the following journal" and lists: domain, l1ChainId, l2ChainId,
  prevHeight, prevBlockHash, prevStateRoot, epoch, validatorSetRoot, totalVotingPower, quorumThreshold, configHash,
  firstHeight, lastHeight, headBlockHash, postStateRoot, dataCommitment, blobHashesHash, challengeZ, evaluationsY,
  forcedInclusionCommitment. There is **no** setVersion, no N and no transition-tuple field.
- **L1-05** is likewise a closed provenance table of 21 rows; none carries (setVersion(e), N(k)).

**Assumptions / preconditions.** None — it is a missing rule. Round-1 CS-05 raised the same class for the *epoch set root*
(closed by adding journal row validatorSetRoot / L1-05 row 10); this is a new, different value introduced by the CS-08 fix,
and it was not given a row.

**Concrete failure trace.**
1. An implementer follows PRF-02 ("exactly the following journal") and L1-05 (closed list): there is nothing to recompute
   set_version_commit against, so the check in PRF-05(iii) is dropped (or made vacuous by comparing the field to itself
   from the witness).
2. With the check dropped, setVersion monotonicity (MEM-09(3): "a first block that commits a lower version than its
   predecessor is invalid") has no proof-side enforcement, and the header's transition commitment is decorative. The L1
   could compute the pair, but L1-05 does not bind it into statementHash, so the contract is told not to use it.
3. An implementer who instead satisfies the text must extend a "closed" journal and a "closed" L1 provenance table — a
   normative change to PRF-02 and L1-05 made unilaterally — exactly the R13 failure the review is meant to prevent.

**Inside or outside the claimed fault model.** Inside: rules alone. Harm is a false completeness claim in the proof
statement plus an implementer-invented rule.

**Attacker resources and cost.** None for the defect; a prover landing a batch with an arbitrary transition commitment
once an implementation drops the check.

**Harm and requirement affected.** R13, R7 (the statement does not bind the epoch->version->root chain it claims to bind),
CONS-10(6), MEM-09(2)/(3), F1.

**Evidence.** PRF-02 journal list; L1-05 table; PRF-05(iii); CONS-10(6); MEM-09(2)/(3); round-1 CS-08 disposition in
iterations/01-round.md.

---

## R2A-05 — High — the epoch_anchor's closing-epoch certificate is never anchored to L1: the guest verifies it against a witness-supplied set, so a prover can fabricate the previous epoch's set and certificate

**Severity (one line):** even when PRF-05(ii) does run, the only L1-pinned fact it uses is hash(B_anchor); the
certificate's set root is checked only against a witness set, so the "epoch-e finalization" the anchor claims to prove is
not established by the proof.

**Exact rule / missing rule.**
- **PRF-05(ii)**: "the guest MUST recompute it from the anchor certificate it verifies — including the cert_hash of the
  closing epoch's commit certificate for B_anchor".
- **PRF-02** carries exactly one set root: validatorSetRoot for the batch's epoch. There is no public input for the
  closing epoch's root (nor for its total power).
- **PRF-03** describes the witness: (a) "the epoch's validator entries" (the batch's epoch), (d) "the epoch-boundary
  evidence required by PRF-05". Nothing requires the closing-epoch set to be checked against an L1 fact.
- The L1-pinned parent header *does* contain the closing root: prevBlockHash is L1-derived (L1-05 row 4) and CONS-10(3)
  requires the last block of epoch e to carry validators_hash = set_root(e). But no rule tells the guest to compare
  cert.set_root to that field, and PRF-04(v)/PRF-03(c) only hash the chain and check the batch's own headers.

**Assumptions / preconditions.** A prover (permissionless) and any batch whose head opens an epoch (or any implementation
that performs the check). The closing certificate is supplied in the witness.

**Concrete worked counterexample.**
1. Prover generates a fresh Ed25519 key set S' with arbitrary weights w'_i >= 1, computes the MEM-08 root R' and total W'.
2. It signs a PRECOMMIT for B_anchor at (h_last(e), R) with > 2/3 of S', assembles
   cert' = (chain_id, e, h_last(e), R, B_anchor, R', signers, signatures), and computes cert_hash'.
3. It sets the first block of epoch e+1's
   epoch_anchor = keccak256(abi.encode("TAIKO_ETNA_ANCHOR_V1", chainId, h_last(e), hash(B_anchor), cert_hash')).
4. The guest's checks all pass: signatures verify under the witness set S'; s > 2/3 W'; the recomputed MEM-08 root of S'
   equals cert'.set_root = R'; cert_hash' and epoch_anchor recompute. hash(B_anchor) is L1-pinned, and the fabricated
   certificate claims exactly that block — so nothing contradicts it. No L1 public input compares R' to mapping[e].
5. The proof is accepted; the L1 (land) has no rule to check the anchor, and PRF-05's claim that the guest verifies the
   epoch-e commit certificate is, in substance, false: the guest verifies *a* certificate under *a* witness-chosen set.

**Why this is not a fork (stated honestly).** The batch's parent is pinned by prevBlockHash (L1-05 row 4) and the batch's
head certificate is verified under the batch epoch's **L1-derived** root, so a fabricated closing set cannot change the
settled chain. The harm is that the claimed proof-side handoff guarantee is not delivered: a light client, an L2 verifier,
or any consumer of the proof cannot conclude from it that the boundary was anchored to the real previous epoch's set, and
the CONS-09(5)(i) shortcut is invisible at L1 acceptance.

**Inside or outside the claimed fault model.** Inside for a permissionless prover; the defect is a proof-statement
completeness gap (R7), same class as round-1 CS-05 which the fixes were meant to close.

**Attacker resources and cost.** One key generation, one proof. Zero stake.

**Harm and requirement affected.** R7 (complete proof statement, both backends), R5/F1 (the cross-epoch component is
claimed to be proof-checked and is not), CONS-09(2), CONS-10(6). A one-line fix exists: require the guest to check
cert.set_root against the L1-pinned parent header's validators_hash (or add the closing epoch root as a public input).

**Evidence.** PRF-05(ii), PRF-02 journal, PRF-03(a)/(d), PRF-04(v), CONS-10(3), L1-05 rows 4/10, CONS-09(5)(i).

---

## R2A-06 — High — the round-1 churn cap (ECON-03(6)) contradicts MEM-05(2) and the validator lifecycle: exits become effective at the first snapshot with no churn logic anywhere in the set computation

**Severity (one line):** the ECO-07 fix was written into the economics page while the membership rules that compute the set
still guarantee immediate, unlimited exit effectiveness, so either the cap is inert (the one-step security drop ECO-07 was
about remains) or the MEM rules are wrong — an implementer must choose.

**Exact rules.**
- spec/07-economics-slashing.html **ECON-03(6)** (new, review round 1, finding ECO-07): "CHURN_LIMIT is the maximum
  fraction of an epoch's voting power that may leave the set at one epoch boundary: the L1 staking contract MUST NOT make
  more than CHURN_LIMIT * TotalVP(e) of effective stake inactive at any single epoch e. Exits beyond the cap are neither
  cancelled nor penalised; they are deferred to later epochs in the objective request order of MEM-05 ..."
- spec/03-membership-staking.html **MEM-05(2)**: "Exit becomes effective at the first set version whose snapshot point is
  at or after the exit request transaction's L1 block; from that version the entry's effStake = 0 and it appears in no
  later set root (MEM-09). It cannot be cancelled after that point."
- **MEM-03 section 2.1 lifecycle transition 4**: "exit-requested -> unbonding | automatic at the first set snapshot at or
  after the request block".
- **MEM-02(1)** defines effStake_k(v) = LedgerState(N(k)).active[v] with "has not had an exit become effective (MEM-05)" —
  no churn term. **MEM-08/MEM-09** contain no churn logic and MEM-09(1) fixes the snapshot contents as "the ledger state
  at the moment of the call".
- The spec/09 register confirms the gap: CHURN_LIMIT is registered to ECON-03 only, and no rule wires it into commitSet(),
  effStake or the lifecycle.

**Assumptions / preconditions.** None; it is a rule conflict. (No adversary needed.)

**Concrete failure trace.**
1. A large fraction of voting power calls requestExit() in one L1 block (a price move, the end of a subsidy, or a
   coordinated attacker with borrowed stake).
2. If the implementer follows MEM-05(2)/MEM-03 transition 4 (the rules that define the set), every exit becomes effective
   at the next snapshot: the set loses that stake in one boundary, exactly the one-step deterrence drop ECO-07's fix was
   supposed to prevent; the round-1 High finding is open again.
3. If the implementer follows ECON-03(6), it must defer exits in commitSet() — but that contradicts MEM-05(2)'s normative
   "first set version" statement and the lifecycle table, changes the moment D_withdraw starts running (MEM-05(3)), and is
   not accounted for in MEM-09(1) ("the caller chooses nothing — not the entries") or in the exit-requested -> unbonding
   transition.

**Inside or outside the claimed fault model.** Inside: reconfiguration safety under a coordinated exit, no assumption
failure required.

**Attacker resources and cost.** The stake to be exited (slashable while unbonding) plus L1 gas; the attack is a
*withdrawal of honest weight*, not a slashable offence.

**Harm and requirement affected.** R11 (collateral and exits must be objective and consistent), the A-ECO-1 deterrence
relation, R13 (two rules for one transition), reconfiguration safety (a super-threshold share can become sub-threshold in
one epoch).

**Evidence.** ECON-03(6); MEM-05(2); MEM-03 section 2.1 transition 4; MEM-02(1); MEM-08/MEM-09; spec/09 register rows for
CHURN_LIMIT and ACTIVATION_RATE_LIMIT; round-1 ECO-07 disposition in iterations/01-round.md.

---

## R2A-07 — Medium — there is no canonical commit certificate for a block, so epoch_anchor/cert_hash is not a function of public facts and correct validators can disagree about one header

**Severity (one line):** every quorum subset of signers yields a different but equally valid certificate, hence a different
cert_hash and a different epoch_anchor; the header field's value rule is underspecified and two honest validators holding
different valid certificates will disagree about the same block.

**Exact rule.** **CONS-10(6)**: cert_hash = keccak256(abi.encode("TAIKO_ETNA_CERT_V1", ..., set_root, signers,
signatures)) over exactly the certificate's fields, with the signer bitmap and the signature list; **CONS-09(1)**: the
first block of e+1 commits to cert_hash(e) of B_anchor's certificate. CONS-05 accepts *any* certificate whose quorum
holds: for one (H,R,B) there are C(n, quorum)-many valid certificates (different signer subsets), each with a different
cert_hash, hence a different epoch_anchor, hence a different block hash for the first block of e+1.

**Assumptions / preconditions.** Two correct validators obtain different valid certificates for B_anchor (trivially true:
certificates are aggregates of gossiped signatures, and there is no canonical-selection rule).
**Worked case.** Validator V1 holds certificate A (signers 1..700); validator V2 holds certificate B (signers 2..701), both
valid. The proposer builds the block with A. V2 recomputes epoch_anchor from B and — following CONS-10(6) ("a header whose
epoch_anchor does not recompute from the certificate it presents is invalid") and CONS-09(2) — cannot accept the header,
even though A exists and is valid. V2 prevotes NIL while V1 prevotes the block; the round is lost and the boundary churns,
or (if V2 never obtains A) the boundary stalls. No validator misbehaved and nothing is slashable.

**Inside or outside the claimed fault model.** Inside (liveness/reviewability); no safety break, because CONS-02 permits
one vote per (H,R) and only one of the competing headers can gather > 2/3.

**Attacker resources and cost.** None; a liveness/churn surface. A malicious proposer can weaponise it by anchoring an
obscure valid certificate.

**Harm and requirement affected.** R13 (the field's value rule is not a function of the state alone), CONS-09(2), F1;
reviewability of the handoff.

**Evidence.** CONS-05, CONS-09(1)/(2), CONS-10(6); the absence of any canonical-certificate rule in the CONS-11 evidence
definition or in the object table.

---

## R2A-08 — Medium — CONS-03 demands that the L1 Inbox "evaluate exactly 3*s > 2*W over the same authenticated s", but no binding carries s or the signer set, so the Inbox cannot evaluate the predicate

**Severity (one line):** a normative claim about where the quorum predicate is checked is not implementable as written,
because the L1 contract never sees the signers; an implementer trying to satisfy it must invent an s binding.

**Exact rules.**
- **CONS-03**: "the L2 client, the zkVM guest and the L1 Inbox MUST each evaluate exactly 3 * s > 2 * W over the same
  authenticated s and W, with checked arithmetic."
- **L1-05 row 12**: "... quorum is the single predicate checked_mul(3, s) > checked_mul(2, W) ... with checked arithmetic
  evaluated identically by the L2 client, the zkVM guest and this contract."
- But **L1-05** binds (via statementHash) validatorSetTotalPower and quorumThreshold = checked_mul(2, W) only; s, the
  signer bitmap and the signatures are witness data checked inside the guest (**PRF-04(i)-(iv)**; the journal carries only
  finalityCommitment = keccak256(... bitmapHash, signatureSetHash), L1-05 row 15). The contract has no s and no signer
  set, so it cannot evaluate the comparison; it can only supply 2*W.

**Assumptions / preconditions.** None. Not an attack; a rule-consistency defect.
**Failure trace.** An implementer takes CONS-03/L1-05 row 12 literally and adds a submitter-supplied s to the statement so
the contract can compare 3s > 2W; that value is not bound to any authenticated signer set in the journal (the bitmap is
inside finalityCommitment, which the contract cannot open), so the contract-side check would be meaningless — worse than
not having it. An implementer who reads row 12's second half correctly (the contract supplies 2*W, the guest does the
comparison) produces a design that violates the literal MUST in CONS-03 and row 12.
**Inside/outside the fault model.** Specification defect (R13); the misleading contract-side check is a false assurance.
**Harm and requirement affected.** R7/R13; reviewability of the quorum rule (which CONS-03 itself calls a protocol defect
when it diverges).
**Evidence.** CONS-03; L1-05 rows 11/12/15; PRF-04(i)-(iv); PRF-02 journal.

---

## R2A-09 — Medium — "the caller chooses nothing" is false about *when*: the first commitSet() caller after the gate opens picks the snapshot moment, hence the set's composition

**Severity (one line):** the round-1 CS-01 fix removed the node-local view and the caller-chosen *content*, but the caller
still chooses the *time*, and the ledger state — which entries are exit-effective, activated, slashed or re-keyed — is
time-varying; whoever wins the L1 race (or controls when the gate opens, see R2A-01) selects among reachable sets.

**Exact rule.** **MEM-09(1)**: "The caller chooses nothing — not the epoch, not the entries, not the total, not the block's
position in the block"; gate: the call reverts unless the immediately preceding epoch has begun (per the Inbox's accepted
height). Compare **MEM-02(1)** effStake_k(v) = LedgerState(N(k)).active[v] and **MEM-05(2)**/**MEM-07(3)**, which make
exit-effectiveness and key rotations functions of the snapshot block N(k).

**Assumptions / preconditions.** The adversary can be the first caller once the gate opens (L1 priority ordering, T-1/T-6)
and/or can move the gate (R2A-01's variant).

**Concrete case.**
1. Honest validator H lands requestExit() in L1 block b. Per MEM-05(2) its stake leaves at the *first* snapshot at/after
   b — but that snapshot is whoever calls commitSet() next.
2. An adversary that is the first caller can choose to call in block b (H still in the e+1 root) or after b (H out of it),
   i.e. it decides whether a given honest share participates in epoch e+1; the same lever applies to an activation that
   has just crossed D_activation, a pending slash, or a key rotation (MEM-07(3)).
3. If the adversary can additionally delay the gate (censor/slow the epoch-opening proof, R2A-01), the window in which it
   may choose widens to minutes, capturing ledger changes that a prompt snapshot would not include.

**Inside or outside the claimed fault model.** Inside (T-1/T-6 ordering, T-7/T-9 delay); no safety break — all nodes read
the same L1 entry once written (A-CONS-4 holds) — but the composition bias is real and undisclosed. This is the residual
of round-1 CS-01's own "permissionless snapshot timing" note, which the fix bounded on the early side only (it now forbids
pre-committing far-future sets, which was the critical part) and left unbounded on the late side.

**Attacker resources and cost.** L1 gas plus being first (priority fee), or the cost of the R2A-01 delay. No stake.
**Harm and requirement affected.** R1/R5 (the set is a security input chosen by timing rather than rules), A-CONS-1's
premise ("the stake that counts toward quorum" should be rule-determined), R13.
**Evidence.** MEM-09(1), MEM-02(1), MEM-05(2), MEM-07(3); round-1 CS-01 note in
iterations/raw/round1-consensus-safety-reconfiguration.md.

---

## R2A-10 — High — CONS-04(1) says a lock is "never cleared at a height or an epoch boundary" while CONS-04(2) allows unlocking only at the *same* height: as written, a lock can never be released, and WH-04's "locks carry across the boundary" is a textual assertion rather than a mechanism

**Severity (one line):** the lock rule — premise P2 of INV-01 and one of the three mechanisms WH-04 says protects against
the reveal-later schedule — is stated in a form that is impossible to implement literally and whose cross-height semantics
the implementer must invent; the two readings differ on liveness and on F1's premise P5.

**Exact rule.**
- **CONS-04(1)**: "a validator's lock is a persistent local pair (locked_value, locked_round) ... it survives restart and
  is never cleared at a height or an epoch boundary (CONS-09)."
- **CONS-04(2)**: "At (H,R), unlock happens only against a PoLC at (H, p) for a value different from locked_value with
  locked_round < p < R — strictly later, same height, different value. A PoLC at the same round, at an earlier round, at
  another height, or for the value already locked does not unlock."
- **CONS-04 Prevote step (b)**: "if still locked on a block, sign PREVOTE for the locked value".
- **CONS-09(3)**: "Lock state (CONS-04) is NOT reset at the epoch boundary. A validator locked at any height retains that
  lock and its obligations indefinitely." **WH-04**: "At an epoch boundary the new set must carry forward the closing
  epoch's lock (CONS-09) ... A stakeholder that rotates keys or changes its stake cannot thereby escape a lock it
  established in the previous epoch." **INV-01(P5)** depends on it.

**Assumptions / preconditions.** None; the text alone.
**Worked inconsistency.** Every honest validator that precommits a block becomes locked on it (CONS-04 lock rule). At the
next height H+1, under the literal reading the lock is still (locked_value, locked_round) from H and the only unlock
condition is a PoLC "at (H, p)" — a *past* height cannot produce new PoLCs, so the lock is permanent. Relevant obligations
then conflict: CONS-04's prevote step tells the validator to prevote locked_value (a block hash from height H) at H+1,
which is not a valid vote for any block at H+1 and can never contribute to quorum; CONS-01(iii) tells it to build on the
block finalized at H, which is locked_value if the lock target was finalized, so the two rules happen to agree in the happy
path — but a validator locked on a *non-finalized* value at H (the reveal-later scenario the rule exists for) is forbidden
by (2) from ever unlocking and by the prevote rule from voting anything valid again. If a third of the set ever reaches
that state, the chain never finalizes another height. The literal reading therefore cannot be what any implementation
does; implementations will use the standard per-height lock state, which contradicts "never cleared at a height boundary"
and means the *carry-over* asserted by CONS-09(3)/WH-04 is not what protects the boundary. (For validators present in both
epochs the parent rule CONS-01(iii) already forces them onto B_anchor; for validators absent from e+1 the lock is vacuous;
for new validators the anchor check is supposed to substitute.)

**Inside or outside the claimed fault model.** Inside: the ambiguity is reachable with no adversary; the harmful reading is
a liveness failure (halting after the first locked height), the benign reading is a normal CometBFT reset. The safety
argument itself does not need cross-height locks, so this is not a fork — but F1's premise P5 and WH-04's claim are not
implemented by any state transition rule, and R13 is broken.

**Attacker resources and cost.** None for the defect. Under the literal implementation, any validator that locks on a
value that is not finalized (reachable under a T-1 partition) contributes to a permanent halt.
**Harm and requirement affected.** R13, R5/F1 (INV-01 premise P5), R6 (a permanent halt from a rule, not from a failed
assumption).
**Evidence.** CONS-04(1)/(2), CONS-04's quoted CometBFT rule (whose Proof of Safety is a same-height argument),
CONS-09(3), WH-04, INV-01(P5). Round 1 did not raise this (its lock discussion was CS-07's evidentiary narrowing).

---

## R2A-11 — Medium — L1-04 forbids the unsettled-depth cap as an admission condition; L1-06 (new in the round-1 fix) makes it one, with a typed revert

**Severity (one line):** two normative L1 rules now flatly contradict each other about whether land may reject a valid
extension on backpressure grounds, and L1-04 calls its own failure mode a Mode A violation.

**Exact rules.**
- **L1-04** (Mode A obligation): "Structural bounds are permitted and MUST be exactly these: the range must be contiguous
  ...; the batch must be non-empty; and every loop ... must be bounded ... **Backpressure on production — the
  consensus-enforced unsettled-depth cap of HALT-03 and DA-06 — MUST NOT be implemented as an admission condition on
  land(data, proof).**"
- **L1-06** (amended by round-1 C R1-03, new text): "It MUST also reject any batch whose unsettled depth lastBlockHeight -
  lastLandedHeight exceeds D_MAX (UnsettledDepthExceeded()), which is the contract-side half of the backpressure rule
  HALT-03 ...".
- HALT-03 now requires both halves ("validators refuse locally, and the L1 contract rejects a batch that exceeds it"), so
  the spec/06 fix and L1-04 cannot both be satisfied.

**Assumptions / preconditions.** None.
**Failure trace.** An implementer must choose: drop the L1-side cap -> HALT-03's "objectively detectable" claim fails;
keep it -> L1-04's Mode A admission rule is violated. The concrete harm in the second case is bounded (the depth shrinks
as batches land, so a settled range is not permanently unacceptable — the round-1 C R1-03 motivation), but the rules as
written disagree, and L1-04 is the rule that carries the Mode A obligation.
**Inside/outside the fault model.** Specification defect (R13); the "permanently unacceptable" failure L1-04 names is not
demonstrated by this report.
**Harm and requirement affected.** R9 (settlement admission integrity), Mode A/D2 obligations, R13.
**Evidence.** L1-04, L1-06, HALT-03; diff of spec/04-l1-integration.html between dfcf067 and 5e41299 (L1-06's depth
rejection is new; L1-04's prohibition predates it).

---

## R2A-12 — Low — CONS-10(6) writes its domain tags as string literals while GEN-05 requires a right-padded bytes32 tag, and cert_hash's field types are not restated

**Severity (one line):** notation/citation defect in a consensus-critical hash preimage:
abi.encode("TAIKO_ETNA_ANCHOR_V1", ...) is Solidity's dynamic-string encoding, not the right-padded ASCII tag GEN-05 fixes,
and MEM-08's own table shows the bytes32 form the spec intends.

**Exact rule.** **GEN-05**: "Every protocol hash is keccak256 over a single canonical abi.encode of typed fields ... with a
right-padded ASCII domain tag and the chain id as the first two fields." **CONS-10(6)** writes
keccak256(abi.encode("TAIKO_ETNA_ANCHOR_V1", chainId, ...)), ...("TAIKO_ETNA_CERT_V1", ...),
...("TAIKO_ETNA_SETVERSION_V1", ...), and describes them as "single canonical GEN-05 abi.encodes with their own
right-padded ASCII domain tag". The two readings produce different preimages (32-byte word vs offset+length+data) and
therefore different header hashes. The object table (abi.encode("TAIKO_ETNA_PROPOSAL_V1", ...) etc.) uses the same
shorthand, so the fix is a convention statement, not a rewrite; but CONS-10(6) is the one place where the encoding is the
*value rule* for a header field, and it is the place CS-08 was about.
**Assumptions / preconditions.** None. **Failure trace:** two implementers disagree on the tag encoding -> different
epoch_anchor/cert_hash -> different first block of e+1 -> the boundary rejects valid blocks (or accepts an anchor whose
commitment it cannot check), exactly CS-08's failure trace, one level down.
**Inside/outside the fault model.** Specification defect (R13); no adversary.
**Harm and requirement.** R13, CONS-10(6), GEN-05.
**Evidence.** GEN-05; CONS-10(6) and the wire-format table; MEM-08's DOMAIN_SET_LEAF row (the correct style); the
field-type list of cert_hash (block_id kind's width, signature ordering) is inferable from the object table but not
restated in the value rule.

---

## Checked and actually closed (so they are not re-listed)

These round-1 items were re-tested against the amended text and the original attack no longer succeeds; recording this is
part of the verdict, not an endorsement of the rest.

- **CS-09 / the quorum predicate.** CONS-03, L1-05 row 12 and PRF-04(iii) now all state exactly
  checked_mul(3, s) > checked_mul(2, W), with quorumThreshold explicitly defined as the right-hand product 2*W and the
  floor(2W/3)+1 form deleted. The one-predicate requirement is met in all three texts (subject to R2A-08's observation
  that the L1 contract cannot evaluate the comparison itself). No off-by-one remains.
- **CS-04 / B R1-05 (two set encodings).** MEM-08 is the single owner; CONS-10(1)/(2) and PRF-02(3)/PRF-05(iv) all defer to
  the MEM-08 Merkle root with the same leaf/interior/key tags and the promoted-odd-node rule. I found no residual second
  encoding of the set itself.
- **CS-02 / leader selection.** pos = uint256(keccak256(abi.encode(DOMAIN_PROPOSER, chainId, epoch, H, R))) mod W is a
  pure function of committed inputs; nothing attacker-controlled enters the hash, so there is no grinding, and the
  half-open cumulative-weight intervals partition [0, W). The modulo bias bound (<= W/2^256) is correct, and the fairness
  claim is honestly labelled Assumed (an expectation, not a per-window bound). No finding.
- **CS-01's core (the epoch-to-set-root identity).** L1 resolves epoch -> (setRoot, totalVotingPower) from an append-only
  mapping (MEM-09(2), L1-05 row 10, PRF-02); the header field is compared against it; the epoch is recomputed from the
  L1-committed schedule. A proposer or prover can no longer name the root. The residual is the *timing* of the snapshot
  (R2A-09), not the identity of the root.
- **CS-07's narrowing propagated.** ECON-04's lock row and CONS-09(4)(a)/CONS-12 now state that only same-(height, round)
  conflicting pairs are objectively slashable and that "at least one third is punishable" is Assumed. I found no remaining
  place in spec/07 or spec/10 that restores the claim as a deterrent guarantee.
- **CS-03 (blob binding)** was re-attacked only to the extent it touches L1-05's binding list; the challenge derivation now
  includes dataCommitment and blobHashesHash, so the field-list hole is closed at the contract side. The grinding
  re-attack belongs to the proof angle and is not claimed here.
- **CS-06 (epoch length)** is fixed at L = 900 in CONS-13(1) and PARAM-02, with EPOCH_LEN_L2 corrected. No second value
  found.

## Verdict for the parent

The round-1 fixes in this angle are directionally right but two of them created new defects of the same class they closed:

- **R2A-01 (Critical, inside the fault model)** is my strongest attack and my answer to "can a sub-threshold actor halt the
  chain cheaply": **yes — and worse, the chain halts by itself.** MEM-09(1)'s append gate is keyed to the Inbox's last
  accepted L2 height; under D5/D6 that height lags by up to the whole 30-minute envelope, so the one-epoch lookahead
  (CONS-13(3)) is consumed by the pipeline plus approx. 12.8 min of Ethereum finality, and MEM-09(5) forbids producing any
  block of the next epoch until the entry is final. Every boundary therefore stops the 2 s cadence for >= 12.8 min at the
  D6 operating point, and a ~17-minute delay of one epoch-opening batch (T-7/T-9/T-12, no stake) guarantees it. D6/R4/D1
  are broken.
- **R2A-02 (High)** is the same root cause seen from the header rule: CONS-10(1) demands a value for next_validators_hash
  that does not exist until later in the epoch, so the field is unsatisfiable and implementer-invented (CONS-14(3) makes
  it provable at genesis).
- **R2A-03/R2A-04/R2A-05 (High)** show that the CS-08 amendment does not deliver its proof-side guarantee: the new
  boundary checks are conditioned on a prover-chosen property, set_version_commit has no public input to be recomputed
  against, and the epoch_anchor's closing certificate is verified against a witness-supplied set.
- **R2A-06 (High)** shows the ECO-07 churn cap was added to the economics page but is contradicted by the membership rules
  that actually compute the set; the reconfiguration-safety concern it was meant to fix is not implemented.
- **R2A-10 (High)** shows the lock rule is impossible as written and F1's premise P5 / WH-04's third mechanism is a
  textual assertion, not a rule.
- No *new* two-conflicting-finalized-histories attack inside the fault model was found: within an epoch the quorum/lock
  argument is intact, and the cross-epoch argument still reduces to two same-height epoch-e certificates (case (a)), which
  needs >= 1/3. The cross-epoch component remains F1/Assumed, as the spec itself states.

**Counts: Critical 1, High 6, Medium 4, Low 1.** Critical/High inside the fault model: R2A-01 (Critical, no adversary
needed), R2A-02, R2A-06, R2A-10 (no adversary needed); R2A-03, R2A-04, R2A-05 (specification defects whose enabled shortcut
is inside the fault model per CONS-09's own failure mode).
