# Round 6 — data binding, proof soundness and economics after D-11 and D-13

**Reviewer angle:** data binding, proof soundness and economics after D-11 (data-first publication) and
D-13 (one proof object = n-of-m aggregation). Targets: `spec/04-l1-integration.html`,
`spec/05-proof-statement.html`, `spec/07-economics-slashing.html`; cross-checked against
`spec/02-consensus.html`, `spec/08-migration-upgrades.html`, `spec/09-parameters.html` and
`DECISIONS.md` D-11–D-15.

**Snapshot:** `7917ba264` (branch `etna-pos-zk`). The working tree is `a483083ab`, whose only
delta from the named snapshot is the addition of `iterations/06-freeze.md` (`git diff --stat
7917ba264 HEAD` shows one file, 18 lines); the specification pages reviewed are the named snapshot's.

**Method:** the specification is the authority; in-text notes, pills and repair citations are claims,
not evidence. `iterations/raw/round5t-proof-data-economics.md` (the previous round on this angle) was
read first; what it records as repaired is re-attacked, what it records as open is re-broken, and
nothing it records as fixed is re-listed without a working re-break.

**Fault-model key.** Inside = reachable by any account inside the stated assumptions (A-CONS-1
< 1/3 Byzantine stake, A-CONS-2, A-CONS-5, A-DA-2, A-L1-1, A-GOV-1, A-CRYPTO-3) without a
cryptographic break, a malicious governance action or an implementation bug. Outside = needs ≥ 1/3
Byzantine stake, a settlement stall / liveness-assumption failure, a bad upgrade, a key compromise or
a code bug.

**Counts: 3 High, 4 Medium, 3 Low.** Five are reachable inside the fault model (R6-DPE-01, -02, -04,
-05, -06); R6-DPE-07's exploitable trigger needs a settlement stall; R6-DPE-03 is conditional on
control of the batch's header gas limits; -08/-09/-10 are rule gaps that need no adversary.

---

## R6-DPE-01 — High — the guest's lower bound on the settled frontier is waived by an unparseable exception, so a compliant proof can leave every due record unresolved (D-12's narrow forced inclusion is defeated, or the clause is dead text).

**Rule / missing rule.** `spec/04` **FI-11(5)**: "require that the proof-bound settled frontier `c'`
satisfies `c' ≥ min(d(A), c + FI_MAX_PER_BATCH)` **unless the window is shorter and `c' ≤ nextSeq(A)`**,
where `nextSeq(A)` is the register's next position at `A` … and that every position in `[c, c')` holds
a record at `A` which is included in the batch or discharged as void under FI-13".
`spec/05` **PRF-04(vi)** carries the same sentence with `cap(batch)`. The exception's antecedent has
no referent: "the window" is the required prefix `[c, min(d(A), c + cap))`, which is "shorter" exactly
when `d(A) − c < cap` — the ordinary steady state. **Missing rule:** the lower bound must be stated
unconditionally (or the exception must name the case it relaxes), and FI-11's own normative sentence —
"From its due point on, no accepted batch may leave a record inside the required prefix unresolved" —
must be the operative one.

**Assumptions.** D-12's capped FIFO prefix; `FI_MAX_PER_BATCH ≥ 2` (unmeasured, and every registered
relation admits it); the guest clause is the only enforcement point (FI-11: "enforced by the guest, in
the clause PRF-04(vi)").

**Attack trace (literal reading).**
1. `FI_MAX_PER_BATCH = C ≥ 2`. A user publishes one record `p` (DA-07). After `FI_INCLUSION_DELAY` it
   is due at every admitted view `A`, so `d(A) − c = 1 < C`: the required window is "shorter".
2. Any prover lands an otherwise valid batch with `c' = c`. The lower bound is waived by the exception;
   the surviving requirement is "every position in `[c, c')` holds a record at `A` included or void",
   which the empty range satisfies vacuously. `c' = c` passes `ForcedFrontierRegression` and
   `ForcedFrontierBeyondRegister`, and the `forcedBoundary` commitment recomputes.
3. `p` is never resolved. Every later batch repeats step 2. FI-14 forbids only *lowering* the frontier
   and *skipping except by include-or-void under FI-13* — neither is done, because the frontier does not
   move at all. FI-12(iii)'s "the frontier advances by `min(pending, cap) ≥ 1` whenever a record is
   pending" has no enforcing clause left.
4. Narrow forced inclusion is dead for the life of the deployment: a censoring producer need only never
   advance the frontier, which is precisely the escape FI-12's failure mode names ("a cap that can be
   shrunk by the submitter … is a censorship escape").

Under the alternative reading (the exception exists for `c + cap > nextSeq(A)`, which cannot arise
because `d(A) ≤ nextSeq(A)` by construction) the clause is inoperative dead text; either way the
binding sentence of the obligation is defective, and which behaviour an implementer produces is
undetermined.

**Inside/outside the fault model.** **Inside** under the operative reading: any lander/prover, no stake,
no validator role, no assumption failure. The clause's ambiguity itself needs no adversary.

**Attacker resources and cost.** One valid batch and its proof; the landing gas is recoverable through
L1-11's landing reward, which L1-10 pays to `msg.sender`.

**Requirement / decision affected.** D-12 ("Inclusion is a capped FIFO prefix of the due set, so a
backlog drains over successive batches instead of halting the chain — the failure mode that produced
review round 1's critical finding … must not return"; "it does not give the protocol a pause or a
discretion"); FI-10's exclusion deadline; FI-12 claim (iii); R10 in its narrowed form; R13.

**Evidence.** `spec/04-l1-integration.html` FI-11 (line 720, clauses (3) and (5) and the "Exclusion
deadline" paragraph), FI-10 (718), FI-12 (722), FI-14 (726), L1-05 row 36 (116–167);
`spec/05-proof-statement.html` PRF-04(vi) (273).

---

## R6-DPE-02 — High — the reward pool still has no liability term: `pool_before(e)` re-counts ETH already frozen for earlier epochs, so one inflow is allocated to every open epoch and the "one inflow is never allocated twice" sentence is false.

**Rule / missing rule.** `spec/07` **ECON-02(5)(a)**: "Its outflows are exactly **two** … **No inflow may
be assigned twice**: `Alloc(e) + ProvingShare(e) ≤ pool_before(e)`, checked at the (5)(d) freeze."
**(5)(e)**: `Alloc(e) = floor(ALLOC_VAL_PPM · pool_before(e) / 1e6)`,
`ProvingShare(e) = floor(ALLOC_PRV_PPM · pool_before(e) / 1e6)`, `ALLOC_VAL_PPM + ALLOC_PRV_PPM ≤ 1e6`.
**(5)(c)**: a claim "pays the entry's recorded owner, never the caller", claims open only after
`evidenceClose(e)` and never close. **Missing rule:** `pool_before(e)` must be the pool's *free*
balance — realised balance minus frozen-but-unclaimed `Alloc` and `ProvingShare` of earlier epochs —
or the freeze must be refused while earlier liabilities are outstanding. No reservation, liability or
solvency term exists in `spec/07` or `spec/03` (grep: no "unclaimed", "liability", "reserved" in the
pool's accounting).

**Assumptions.** D-8 (L2 fees fund security); A-ECO-1 ("the realised pool" is the security budget);
rational inaction (a dust-sized allocation, an owner contract that cannot call `claimValidatorReward`,
or simply a validator that does not claim, since the claim pays the owner and never the caller).

**Attack trace (no adversary required).**
1. One sweep delivers `B` ETH to the pool (ECON-02(7)).
2. Epoch 1 freezes at `pool_before(1) = B` with `ALLOC_VAL_PPM = 600,000`,
   `ALLOC_PRV_PPM = 400,000`: `Alloc(1) = 0.6B`, `ProvingShare(1) = 0.4B`. The per-epoch check holds.
3. Nobody claims epoch 1 (the owner must claim; the caller is paid nothing) and nobody makes the
   permissionless proving-share transfer. The balance is still `B`.
4. Epoch 2 freezes at `pool_before(2) = B` and fixes `Alloc(2) = 0.6B`, `ProvingShare(2) = 0.4B`. The
   per-epoch check holds again. Total promises: `2.0B` against `B` of inflow.
5. Whichever claims/transfers execute last revert against an empty pool; the earlier ones are paid from
   ETH the same rule already assigned to another epoch. The per-epoch identity
   `Σ payout ≤ Alloc ≤ pool_before` held in both epochs and is false globally.
6. Independent ordering lever: the proving-share transfer is permissionless and unrestricted, while
   validator claims open only at `evidenceClose(e)`; a party that is not a validator of `e` can move
   `ProvingShare(e)` first and leave the epoch's validators with a short pool even if they claim
   promptly.

**Inside/outside the fault model.** **Inside**, non-adversarial (a rational-inaction property plus one
permissionless ordering choice); no assumption has to fail.

**Attacker resources and cost.** None; any validator set that does not claim promptly triggers it.

**Requirement / decision affected.** ECON-02's funding identity and A-ECO-1; D-8; R11 (objective
rewards). This is round-5 finding **R5T-PDE-05 re-broken**: D-15 withdrew the completion reward and its
share (removing the third-outflow horn) but added no liability term, so the main horn — the same inflow
frozen into every epoch's allocation — is unchanged.

**Evidence.** `spec/07-economics-slashing.html` ECON-02 lines 155 (two outflows), 196–204 (the identity
and the per-epoch check), 215–230 (the policy, the two shares and the freeze); `spec/09-parameters.html`
row `Alloc(e)` (line 1208).

---

## R6-DPE-03 — Medium — `cap(batch)` is computed from the batch's own header gas limits, which the producer chooses, and the MUST that is supposed to stop shrinking is conditioned on the very window the shrunken cap empties.

**Rule / missing rule.** `spec/04` **FI-12**: "`batchGasCapacity` [is] the sum of the gas limits of the
batch's own headers, which the guest reads while verifying the header chain … `cap(batch) =
min(FI_MAX_PER_BATCH, floor(batchGasCapacity / itemGasBound))`. **When the window is non-empty** the batch
MUST have `batchGasCapacity ≥ FI_MAX_PER_BATCH × itemGasBound`, so a submitter cannot shrink its batch to
shrink the obligation." The antecedent is circular: "the window" is `[c, min(d(A), c + cap(batch)))`,
whose emptiness is what the shrunken cap causes. **Missing rule:** the antecedent must be stated on the
register (`d(A) > c`), and the prefix must be defined once — FI-11(3) writes
`[c, min(d(A), c + FI_MAX_PER_BATCH))` while PRF-04(vi)(1) writes `[c, min(d(A), c + cap(batch)))`.

**Assumptions.** FI-13's per-record bound `itemGasBound`; the Open premise of FI-12 claim (ii). No
registered rule ties an L2 header's gas limit to the registered `L2_BLOCK_GAS_LIMIT` (`spec/09` row calls
it "the value committed through PARAM-04's per-epoch configuration", and PRF-02(5) merely commits it);
F-FI-1 covers only a *schedule* that cannot produce a `MAX_BATCH_BLOCKS`-block batch at that limit, not a
producer who chooses not to.

**Attack trace.**
1. A batch is produced (its blocks proposed by whoever holds the slots, its range selected by whoever
   lands it) whose headers' gas limits sum to less than `itemGasBound`.
2. `cap(batch) = 0`; the required prefix is `[c, min(d(A), c + 0)) = ∅`; the obligation is vacuous even
   with records pending. Under the circular reading of the MUST its antecedent is false, so no clause
   rejects the batch.
3. FI-12's "Nothing a producer chooses enters the capacity test" is therefore false — `batchGasCapacity`
   is exactly what the producer chooses — and claim (iii) ("the frontier advances by `min(pending, cap) ≥ 1`
   whenever a record is pending") is not entailed.

**Inside/outside the fault model.** **Inside but conditional**: it needs control of the batch's header gas
limits, which the preserved L2 header rules may bound (an Ethereum-style ±1/1024-per-block adjustment)
and honest proposers restore. The rule defect itself — a load-bearing MUST with a circular antecedent and
two divergent prefix definitions — needs no adversary.

**Attacker resources and cost.** None beyond ordinary block production and one landing transaction.

**Requirement / decision affected.** D-12's cap; FI-11(3), FI-12, PRF-04(vi)(1)–(2); R13.

**Evidence.** `spec/04-l1-integration.html` FI-12 (722, "The cap is computed from the batch's own
contents" and "Nothing a producer chooses enters the capacity test"), FI-11(3) and (5) (720), FI-13 (724);
`spec/05-proof-statement.html` PRF-04(vi)(1)–(2) (273); `spec/09-parameters.html` rows `FI_MAX_PER_BATCH`
(181), `FI_RECORD_GAS_MAX` (184), `L2_BLOCK_GAS_LIMIT` (185), FI capacity relation (186).

---

## R6-DPE-04 — Medium — the zero-outstanding-balance sweep is a no-op that consumes nothing, but F3 excludes any "Bridge fee a sweep caller supplies" from `X(h)`; the rule never says whether that fee is refunded, so one permissionless L2 transaction can make an honest block unprovable (or strand the caller's ETH).

**Rule / missing rule.** `spec/07` **ECON-02(7)(b)**: the sweep "MUST require `msg.value` to equal exactly
the canonical fee the preserved Bridge charges for that one message … so no caller can … make an honest
block unprovable by overpaying", and "a sweep when the outstanding recorded fee balance is zero is a
no-op — it moves nothing and MUST NOT block anything, even when a forced credit is present".
`spec/05` **PRF-06 F3**: "Write `X(h)` for the ETH credited to the vault over block `h` by any route other
than the fee credit of (F1) **and the Bridge fee a sweep caller supplies under clause 7(b)**; that Bridge
fee **is credited and consumed inside the same sweep call**, so it is neither fee revenue nor a forced
credit", checked by `balance(h) − balance(h−1) == (feeCredits(h) − feeCredits(h−1)) + X(h) − V(h)`.
**Missing rule:** the `msg.value` treatment on the zero-balance path (reject, or refund), and the
classification of a sweep-supplied fee that no message consumes.

**Assumptions.** Zero fee arrivals in the block, or an already-swept vault (the "zero arrivals" case the
funding path explicitly contemplates: ECON-02(7)(d)(ii)).

**Attack trace.**
1. Block `h` has `feeCredits = feeSwept` (nothing outstanding). Any account calls
   `sweep{value: canonicalFee}()`. The vault credits the fee, emits no bridge message (V(h) = 0) and does
   not move `feeCredits`.
2. F3's exclusion of the sweep-supplied fee rests on "credited and consumed inside the same sweep call" —
   false here, because no message is emitted and nothing is consumed.
3. An implementation that classifies the credit as the excluded Bridge fee leaves it unaccounted:
   `balance(h) − balance(h−1) = fee ≠ ΔfeeCredits(0) + X(0) − V(0) = 0`. F3 fails, the batch is
   unprovable, and a certified block can never settle: a halt of the range for the price of one L2
   transaction — exactly the "honest block unprovable" class this paragraph's exact-fee guard was written
   to prevent, arriving through the path the guard does not cover.
4. An implementation that classifies it as `X` keeps the identity but leaves the caller's ETH in the
   vault permanently: the sweep moves exactly `feeCredits − feeSwept`, so a forced credit is never
   recoverable.

**Inside/outside the fault model.** **Inside** (any account, no stake); the concrete outcome depends on an
implementation choice the specification does not fix, which is itself the defect.

**Attacker resources and cost.** One L2 transaction (the canonical message fee plus gas).

**Requirement / decision affected.** D-8's funding path; PRF-06 F1–F4; ECON-02(7)(a)(b); the invariant
stated in the same paragraph, "a forced credit cannot halt settlement".

**Evidence.** `spec/07-economics-slashing.html` ECON-02(7)(b) lines 263–269 (exact-fee guard, no-op
sweep, "MUST NOT hold accumulated fee revenue that no rule-legal call can move");
`spec/05-proof-statement.html` PRF-06 F1–F4 (296–304).

---

## R6-DPE-05 — Medium — the aggregation bitmap's canonical length is fixed by the *current* family registry, not by the epoch's accepted route set that the object already commits, so an additive family registration invalidates every in-flight aggregation object.

**Rule / missing rule.** `spec/04` **L1-14(2)**: the contract MUST require the `familyBitmap` to be
canonical — "**length fixed by the L1-09 family registry**, no bit outside the families live for the
epoch, the reserved aggregation tag unset". `spec/05` **PRF-15(3)** repeats: "The bitmap's length is fixed
by the registry". `spec/04` **L1-09** makes the family index "append-only and never re-used or
re-ordered", and a family is live for an epoch when it has a route accepted for that epoch (MIG-05).
**Missing rule:** the length (and the live-bit set) must be fixed by the batch epoch's accepted route
set — which `routeSetHash` already pins — or by a registered maximum, not by the current registry.

**Assumptions.** Route and family registration is an upgrade (L1-09) and may add a *new* family tag
without retiring anything; L1-09's retirement bar covers retiring an image, not adding a family;
L1-13(7) protects "an already-landed boundary checkpoint" from a raised `k`, but not from a length change.

**Attack trace (governance timing, no adversary).** An epoch's batches are certified and settlement
objects are produced against the family index at that time. An additive upgrade registers a new route
with a new family tag before those batches land. The canonical bitmap length grows by one; every
in-flight aggregation object (settlement or `attestWithdrawalRoot`) is now `MalformedFamilyBitmap` and
cannot land. Settlement of a certified-but-unsettled range stops until the whole aggregation proof is
re-produced, and a pending boundary checkpoint that could only be designated by an already-produced
attach proof is stranded — the exact outcome L1-09's preservation intent exists to prevent.

**Inside/outside the fault model.** Not adversarial: a registry-timing/liveness defect requiring no
assumption failure (an honest upgrade triggers it). No fund loss.

**Attacker resources and cost.** None.

**Requirement / decision affected.** L1-09's preservation intent; L1-13(7); L1-14(2); PRF-15(3); R5/R6
liveness; D-13 ("one verification per purpose"). Round-5 finding **R5T-PDE-08 re-broken**: the snapshot's
text is unchanged.

**Evidence.** `spec/04-l1-integration.html` L1-14(2) (452), L1-09 (428), L1-13(3)(7) (441);
`spec/05-proof-statement.html` PRF-15(3) (528).

---

## R6-DPE-06 — Medium — the aggregation split `AGG_PROVER_PPM` has no enforceable on-chain path, and no rule funds the withdrawal-root attach proof that D-15's exit protection depends on.

**Rule / missing rule.** `spec/07` **ECON-02(5)(e)**: "Where the aggregator and the batch prover are
distinct parties, the split is applied at the **L1-11 prover-reward payout** or settles privately between
them; the specification creates no second payout path". `spec/04` **L1-10**: "The reward of L1-11 MUST be
paid to `msg.sender` … the protocol MUST NOT attempt to attribute it to any address named inside the
proof." **L1-11**: the ledger "MUST be debited only by the `rewardPaid` of a successful `land(data, proof)`
and by nothing else". `spec/05` **PRF-15(3)**: the aggregation public input carries `statementHash`,
`routeSetHash` and `familyBitmap` — no payout address. **Missing rule:** either an enforceable payment
path for the aggregator and for the attach proof, or a statement that only the private arrangement exists
and the on-chain policy is inert.

**Assumptions.** D-13 ("Cost moves to the prover"; `AGG_PROVER_PPM` is the registered funding);
L1-13(3)/(5) make the withdrawal root depend on an aggregation proof produced by whoever submits
`attestWithdrawalRoot`; D-15 ("Users are protected by the existing exit guarantee").

**Attack trace.**
1. The aggregator produces the aggregation object; a searcher sees it in the mempool and lands it first
   (L1-10 explicitly accepts this). `msg.sender` receives the whole proving share; there is no on-chain
   way to pay the aggregator, so aggregation beyond degenerate self-aggregation has no payer.
2. For a boundary checkpoint whose settlement proof attested fewer than `k` families, the attach proof is
   unpaid ("no funding rule for it exists in this specification", L1-13(5)); an unpaid, gas-costing,
   `k`-inner-proof object is a public good, so the exit path is only as live as private altruism.
3. ECON-02's pool is closed at two outflows and L1-11's ledger has one debit, so neither can pay it
   without a rule change — while D-15 cites the exit guarantee as the protection that makes a slower
   fallback tolerable.

**Inside/outside the fault model.** **Inside** (economic; front-running needs no stake). The attach-proof
half is disclosed as Open in L1-13(5); it is recorded here because ECON-02(5)(e)'s claimed on-chain
funding path does not exist, which is a fixed-decision (D-13) mismatch rather than a disclosure.

**Attacker resources and cost.** One landing transaction's gas; the reward pays it back (L1-11).

**Requirement / decision affected.** D-13; L1-13(5) exit-path liveness; ECON-02(5)(a)(e) vs L1-10/L1-11;
D-15. Round-5 finding **R5T-PDE-09 re-broken**: unchanged.

**Evidence.** `spec/07-economics-slashing.html` ECON-02 (5)(a) (155), (5)(e) (215–230);
`spec/04-l1-integration.html` L1-10 (463), L1-11 (476), L1-13(3)(5) (441);
`spec/05-proof-statement.html` PRF-15(3) (528).

---

## R6-DPE-07 — High — the expiry/prune frontier advance is still simultaneously mandated and forbidden, and the horn that honours the prohibition makes a pruned register position permanently unprovable.

**Rule / missing rule.** `spec/04` **FI-10** ("Expiry and discard"): a record past its DA-09 deadline
"MUST be discarded from the due set by an objective, permissionless advance of the frontier … and no proof
may be required to include it". **L1-08** still declares
`pruneExpiredPublications(uint32 _maxRecords) returns (uint64 settledFrontier_)` and the
`ForcedFrontierAdvanced` event is still documented as "advanced by an accepted batch **or by the objective
expiry prune**" (363). Against that, **FI-14**: "there MUST NOT exist a function that … **skips a prefix
element except by include-or-void under FI-13**"; and **FI-13**: "No other ground discharges a record, at
any layer … and not the record's own age **while it is still live**" — the void predicate is only
non-includability, never expiry. **Missing rule:** exactly one of the two is authoritative, and the
interaction with DA-09(1)'s pruning ("a pruned record is treated as absent") and FI-11(5)'s "a position
with no record at `A` is neither included nor void and MUST make the proof invalid" must be stated.

**Assumptions.** DA-09(1) permits pruning after `PUB_RECORD_RETENTION ≥ T_PROVE_DEADLINE`; MIG-02 budgets
a `pruneCursor` slot (283, 327); the guest derives `c` from the predecessor's settlement record and
`c'` from the claim.

**Attack trace (horn A — implement the prune).** A due, includable record is not included for
`T_PROVE_DEADLINE` L1 blocks (a settlement stall, or ≥ 1/3). Any account calls
`pruneExpiredPublications`: the frontier advances past a record that was includable, with no proof and no
FI-13 predicate — the enforcement point of the obligation moves from the proof (FI-11: "the enforcement
point is the proof, not `land`") to an unauthenticated L1 call that FI-14 says must not exist; the user
re-publishes and pays again.
**Attack trace (horn B — implement FI-14).** The frontier may not advance past the dead record, and an
expired record is neither includable-mandatory (FI-10: "no proof may be required to include it") nor void
(FI-13). When the record is pruned for storage, its position holds no record at `A`, so FI-11(5)
invalidates every proof that would have to cross it: settlement of everything at or after that position is
permanently impossible — a halt created by a permitted storage-reclamation call, releasable only by the
governance stall resolution.

**Inside/outside the fault model.** The contradiction needs no adversary. Horn A's censorship use and
horn B's trigger both need a record to die unresolved, i.e. a stall or ≥ 1/3 (outside the strict model) —
as round 5 also recorded for this finding; the primary enforcement (proof invalidity) is unaffected.

**Attacker resources and cost.** Horn A: one L1 transaction plus the ability to keep the record
unincluded for its deadline. Horn B: none — it is the default behaviour of a conforming implementation.

**Requirement / decision affected.** D-12 (enforcement point = the proof; no suppression of forced data);
FI-13's "at any layer"; FI-14's "MUST NOT exist"; DA-09(1); FI-11(5); R13. Round-5 finding
**R5T-PDE-04 re-broken**: unchanged.

**Evidence.** `spec/04-l1-integration.html` FI-10 (718), FI-13 (724), FI-14 (726), L1-08 (256, lines
318–319 and 362–364), DA-09 (698); `spec/08-migration-upgrades.html` MIG-02 lines 283, 327.

---

## R6-DPE-08 — Low — on the referenced path there is still no derivation source for `daMode`, which is load-bearing for the commitment construction.

**Rule / missing rule.** `spec/04` **L1-05 row 17**: "`daMode` … 1 = CALLDATA, 2 = BLOB, 3 =
CALLDATA_AND_BLOB; **derived from which arguments/blobs are present**, not from a submitter field", and the
table's preamble says tx-derived values are recomputed from the transaction "and MUST ignore any
submitter-supplied copy". On the referenced path the accepting transaction carries neither the payload nor
the blobs (DA-08(2)); **DA-08(1)** still requires the record's `daMode` to equal the statement's, and
**DA-08(2)** derives only the binding source (`dataBindingSource`) from `blobhash` and the record.
**Missing rule:** the referenced-path source for `daMode` (necessarily the record, i.e. a value the
submitter selects by choosing the record, requiring an explicit exception to "ignore any submitter-supplied
copy").

**Assumptions.** DA-02/DA-03(0) fix the commitment construction per mode; the journal carries `daMode` as
a public input (PRF-02).

**Attack trace.** No soundness break is available — the value is proof-bound and cross-checked against the
record — but an honest landed batch is unlandable if the contract derives a mode no argument supports, or
the contract silently violates the tx-derived rule by taking it from the record. The `LandInput` comment
"must equal the derived mode, else `DataModeMismatch()`" leaves the derivation undefined. R13 issue.

**Inside/outside the fault model.** Not applicable (specification gap; liveness/R13).

**Requirement / decision affected.** R13; DA-08(1); D-11's referenced path. Round-5 finding
**R5T-PDE-11 re-broken**: unchanged.

**Evidence.** `spec/04-l1-integration.html` L1-05 row 17 and preamble (116), row 34 (166), DA-08 (689),
`LandInput` (276); `spec/05-proof-statement.html` PRF-02 `daMode` field (56).

---

## R6-DPE-09 — Low — the family tag → bitmap-index mapping is not committed to the aggregation program, so PRF-15(4)'s "set a bit if and only if verified" cannot be a structural property of the program.

**Rule / missing rule.** `spec/05` **PRF-15(4)**: the program "MUST set a family bit **if and only if** at
least one inner proof under a route of that family verified successfully against the same
`statementHash` … the code MUST be written so that this is a structural property rather than a checked
assertion". **PRF-15(3)** fixes the public input to "at least" the domain tag and chain ids,
`statementHash`, `routeSetHash` and `familyBitmap`; `routeSetHash` commits the epoch's ordered route set
(L1-09's route triple carries the family tag), while the *bit index* is "the i-th family tag registered"
in the Inbox's global append-only family index (L1-09) — not derivable from an epoch's route set.
**Missing rule:** the mapping (or the full index) must be a committed input the program can verify, or the
bit positions must be defined by something the program can compute from `routeSetHash`.

**Assumptions.** The bitmap is the only object L1 counts (L1-14(2)–(4)); the program is trusted for the
bitmap's truthfulness (disclosed).

**Attack trace.** No count increase is available — the program knows how many distinct families it
verified, and L1 counts bits intersected with live families — so the security property is preserved. The
defect is that the program cannot know *which* bit names which family without a witness-supplied mapping
that no rule authenticates; a mis-wired mapping misattributes families while preserving the count, and
"iff" is then an assertion the program cannot structurally make.

**Inside/outside the fault model.** Outside as stated (needs a defective image or a bad registration).

**Requirement / decision affected.** D-13 ("must not be able to claim a family it did not verify"); PRF-15(3)(4);
L1-09.

**Evidence.** `spec/05-proof-statement.html` PRF-15(3)(4) (528); `spec/04-l1-integration.html` L1-09 (428),
L1-14(2)–(4) (452).

---

## R6-DPE-10 — Low — the landing path never ties `blobCount` to `blobVersionedHashes.length`, so if the journal's hash list is taken from calldata the trailing entries are a bound-but-unopened field of the transcript.

**Rule / missing rule.** `spec/04` **DA-03** preamble: "let `n = blobCount` and let blob index `i` range
over `[blobIndexStart, blobIndexStart + n)`; the Inbox MUST perform (i) and (ii) for every `i`", and
**DA-03(i)** compares `blobhash(i)` with `_input.blobVersionedHashes[i − blobIndexStart]`. `LandInput`
carries both fields (281–284). `spec/04` **DA-07(5)** *does* state the length equality for publication
("the Inbox MUST require `_blobVersionedHashes.length == _blobCount`"); no rule states it for `land`.
**Missing rule:** on the carried path, `blobCount == _input.blobVersionedHashes.length` (and, for the
referenced path, that the array is exactly the record's ordered list), or an explicit statement that the
list is read from `BLOBHASH`/the record over the range.

**Assumptions.** Row 24 defines `blobHashesHash` as "read with BLOBHASH for this transaction's blob range
… or from the referenced publication record", which is the canonical reading and closes the gap; the
finding is that an implementation reading the calldata array instead — which DA-03(i) requires it to
compare against — binds entries it never opens.

**Attack trace.** No soundness break is demonstrated: with the canonical reading the unopened tail cannot
exist, and with the calldata reading the tail is a free transcript field (a grinding surface already
covered by the q·2⁻²⁴³ bound) rather than a break of the KZG binding. The defect is implementer-facing
(R13): two conforming readings produce different statements for the same transaction.

**Inside/outside the fault model.** Not applicable (specification gap).

**Requirement / decision affected.** R13; DA-03(0)(i); L1-05 row 24; D-2/D-11 binding argument.

**Evidence.** `spec/04-l1-integration.html` DA-03 preamble and (i) (547–562), `LandInput` (281–284),
L1-05 row 24 (167 area), DA-07(5) (678).

---

## Checked and holds (not re-listed as findings)

1. **Referenced-blob content binding (D-11).** `publish`'s element-wise check (DA-07(5)) closes round-5
   R5T-PDE-02: the recorded hash list is now the publication transaction's own `BLOBHASH` entries, so
   premise (6) of the DA-03/DA-08 argument ("the ones consensus checked against the published blob sidecars")
   is established rather than assumed, and the referenced path keeps the full on-chain precompile opening
   (DA-08(3)) plus the in-guest evaluation; the content binding is therefore as strong as the carried one.
   What remains weaker is same-transaction equality/availability, which is disclosed (DA-05, DA-08(4),
   DA-09). Re-attacked the variants: zero-hash, fewer-hashes, more-hashes, empty list, blobs outside the
   range, `blobIndexStart` arithmetic — each is rejected by DA-07(5) or by the range-length equality, and
   the precompile-less variant is still correctly rejected as unsound (DA-08(3), PRF-07).
2. **The frontier's upper bound (round-5 R5T-PDE-03).** L1-05 row 36 now rejects
   `settledAfter > nextSeq(A)` (`ForcedFrontierBeyondRegister`) and PRF-04(vi) requires every position in
   `[c, c')` to hold a record at `A` included or void. `nextSeq(A)` is computable on L1, not only in the
   guest: the register stores each record's `l1BlockNumber` and is monotone in sequence (DA-07(2)), so the
   contract's bounded binary search gives the count at `A` exactly as it gives `d(A)`. The one proof can
   no longer write the frontier past the register. (The lower bound is R6-DPE-01, above.)
3. **Aggregation bitmap enforceability (D-13).** A submitter cannot claim an unregistered or non-live
   family: L1-14(2) recomputes `routeSetHash` from its own registry for the epoch, fixes the length, rejects
   bits outside the epoch's live families and the reserved aggregation tag, and counts the set bits itself;
   L1-14(3) applies the per-purpose counts; the bitmap's truthfulness is the disclosed trust in the
   aggregation image (L1-14(4), PRF-15(5), PRF-14(4)(e)). Nothing in the submission path (a caller-supplied
   count, a bitmap outside the proof, a second route) can inflate the count.
4. **Fee-vault reconciliation (PRF-06 F1–F4).** Exact for the ordinary block, a donation/forced credit, a
   canonical sweep in the same block as the block's own fee credits (before or after them), and the carried
   sweep: the Bridge fee cancels in F2/F3 because it is credited and consumed in the same call, a forced
   credit never enters `feeCredits` and is never swept, and the balance identity reduces to the ordinary
   predicate. The only combination I can break is the zero-outstanding-balance no-op sweep (R6-DPE-04), and
   the withdrawn `REC_REWARD` leaves no residual term in any of F1–F4.
5. **Withdrawal root plus veto under a k-family outage (L1-13, MSG-04, MSG-03).** The system fails closed
   and the failure is disclosed rather than papered over: with fewer than `k` live families no new root
   forms and releases above the last root wait indefinitely (L1-13(5)); a root is never formed from an
   ordinary checkpoint; the veto is rule-triggered by an on-chain-verified contradiction, one-shot,
   bounded by `T_VETO`, non-extendable, and only delays (MSG-04); an unavailable family cannot cancel a
   root, release value, or shorten an exit. What is *not* resisted is the exit path's economic liveness —
   R6-DPE-06. `W_ROOT_WAIT_MAX` is correctly stated as conditional on `k` families operating.
6. **DA-06/DA-09 clock separation and the mandated relation.** `FI_INCLUSION_DELAY < T_PROVE_DEADLINE`
   is now registered (FI-10, DA-09(1), 09 rows 183/189), so the due point precedes the record's death and
   the narrow rule is not structurally vacuous; the remaining conjunction
   `FI_INCLUSION_DELAY + (drain horizon) < T_PROVE_DEADLINE` is correctly left Open with F-FI-2.
7. **Whole-blob commitment and the round-1 prefix attack.** DA-03(0) still requires the full
   131,072-byte string of every blob (including the unused remainder) in both paths, PRF-06's
   decode-and-root check binds the executed payload to `dataCommitment`, and the challenge transcript
   includes `dataCommitment` and `blobHashesHash`; the fixed-point argument is unchanged by the
   referenced path. The only landing-side gap is the length tie of R6-DPE-10.

---

## Fault-model summary

- **Inside the claimed fault model:** R6-DPE-01 (any prover, under the operative reading of the clause),
  R6-DPE-02 (economic, no adversary), R6-DPE-04 (any account, one L2 transaction, conditional on the
  implementation's classification), R6-DPE-05 and R6-DPE-06 (rule/economic, no stake).
- **Outside / conditional:** R6-DPE-07's exploitable horns need a stall or ≥ 1/3; R6-DPE-03 is conditional
  on control of the batch's header gas limits; R6-DPE-09 needs a defective aggregation image or a bad
  registration.
- **Not applicable (rule gaps needing no adversary):** R6-DPE-08, R6-DPE-10, and the ambiguities inside
  R6-DPE-01/-03/-04.

**One-line verdict for synthesis.** The referenced-blob binding survives re-attack and `publish`'s
element-wise `BLOBHASH` check closes the provenance gap; the aggregation bitmap is unclaimable except for
its length timing; the fee-vault reconciliation is exact except for the zero-balance no-op sweep; but the
D-12 obligation's guest lower bound is waived by an exception with no referent, the reward pool still
allocates the same inflow to every open epoch (the round-5 liability finding, unrepaired), the expiry
prune remains simultaneously mandated and forbidden, and the k-family exit path is disclosed but unfunded.
