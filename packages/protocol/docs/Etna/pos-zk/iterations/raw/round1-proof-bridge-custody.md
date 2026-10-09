# Round 1 — adversarial review: proof soundness, bridge funds, stake custody, accounting

**Reviewer angle:** proof soundness, bridge funds, stake custody and accounting.
**Snapshot:** working tree at commit `dfcf067a5b91a1b0bacd4470f5f5054d1f861a24` (branch `etna-pos-zk`).
**Primary scope:** `spec/05-proof-statement.html` (PRF-01..13), `spec/04-l1-integration.html` (L1/DA/FI/MSG),
`spec/07-economics-slashing.html` (ECON-01..12); `spec/02-consensus.html`, `spec/03-membership-staking.html`,
`spec/08-migration-upgrades.html`, `spec/09-parameters.html`, `spec/index.html`, `README.md`, `DECISIONS.md`,
`01-requirements-and-threat-model.md` as supporting evidence.
**Method:** each rule attacked as written; every "Proven" tag re-checked against its own premises and against
the other pages it binds to. Claims the design itself discloses are flagged as such and not counted unless they
break a fixed decision or a requirement.

| ID | Sev | One line |
|----|-----|----------|
| R1-01 | **Critical** | Blob data binding is defeated by choosing the executed payload *after* the challenge point; the 2^-243 argument's premise is false. |
| R1-02 | **High** | DA-03(iv) interprets the blob in coefficient form; EIP-4844 commits to the blob in Lagrange/evaluation form. The stated in-guest computation is of a different polynomial. |
| R1-03 | **High** | Nothing binds the claimed epoch to the batch's heights or to a set version; CONS-08(1), L1-05 row 9/10 and PRF-02 disagree, and `configHash` has no defined contents. |
| R1-04 | **High** | A batch may cross epoch boundaries, but the journal carries one set root/total; PRF-05(iii) requires each crossed epoch's L1 value. Intermediate sets can only come from the witness. |
| R1-05 | **High** | Two mutually exclusive definitions of the validator-set commitment (MEM-08 Merkle tree vs CONS-10 flat hash; uint256 vs u64 voting power). |
| R1-06 | **High** | The pure-blob `dataCommitment` is undefined (DA-02 covers daMode 1/3 only); PRF-07(a)/(b)(v) contradict DA-02; the journal and L1-05 disagree on the challenge fields. |
| R1-07 | **High** | FI-03's refund-without-consumption plus L1-11's coverage payout double-pays one fee or underflows the ledger, making batches unlandable. |
| R1-08 | **High** | FI-02(a) and FI-02(b) define "due" with different clocks; a legitimately finalized range can become permanently unlandable (violates L1-04 and Mode A). |
| R1-09 | **High** | The L1→L2 checkpoint writer is still the privileged golden-touch/Anchor path, contradicting SYS-02's "gate is removed"; the anchor payload's validity rule is missing. |
| R1-10 | Medium | MEM-06(2)'s partial withdrawal contradicts MEM-05(3)/ECON-07(5)'s full-window gate, so the exposure retained is a max, not a sum; ECON-08(5)(a) is false. |
| R1-11 | Medium | Offence identity hashes the whole `evidence` blob without an exact-length decoding rule; padded duplicates get distinct ids, so the no-op guarantee is unenforceable. |
| R1-12 | Medium | No rule moves L2 fee revenue into the L1 reward pool, yet rewards are paid from that pool in the accepting transaction. |
| R1-13 | Medium | Parameters DA-05/DA-06/FI-01..05/MSG-03 promise to 09 are absent from 09; EPOCH_LEN_L2 = 300 contradicts CONS-13's L = 900. |
| R1-14 | Medium | L1-09 says "exactly one active route" and then "try each enabled route"; PRF-09 is Open, so the routing rule cannot be implemented as written. |
| R1-15 | Medium | MSG-01 requires the SignalService checkpoint to carry epoch/setRoot/dataCommitment, but MIG-02/MIG-06 freeze that contract's state and its three-field struct. |
| R1-16 | Low | L1-01 mandates `land(bytes,LandInput)`; 08/09 call the same entry point `accept(data,proof)`. |
| R1-17 | Low | PRF-04's per-signature check is shorthand that omits `type = PRECOMMIT` and the `validator_index` binding that CONS-02/CONS-03 require. |

---

## R1-01 — The blob binding can be satisfied with executed data that is not the published blob

**Severity: Critical.** One unprivileged prover, no assumption violated, can anchor a state transition that is not a
function of any public data; this is the bridge-theft/auditability class the whole blob design exists to prevent.

**Exact rule.** `spec/04-l1-integration.html` DA-03 ("Why this is sound"), together with DA-03(iv) and
`spec/05-proof-statement.html` PRF-07(b). Related: PRF-13, DA-04, INV-02, R8, D5.

**Assumptions and preconditions.** Only these: the prover is permissionless (L1-04); the guest receives the batch
payload from the host (PRF-11 explicitly says host-read values are unverified assertions); the blob path is
selectable because `daMode` is derived from which arguments/blobs are present (L1-05 row 17). No crypto
assumption fails; KZG binding and the random-oracle model are used exactly as intended.

**Attack trace.**
1. Attacker fixes a published blob `B` (any 4096 canonical field elements; it need not be a valid payload) and
   computes `vh = kzg_to_versioned_hash(commit(B))`.
2. Attacker computes `dataCommitment`, then `z = H("TAIKO_ETNA_CHALLENGE", chainid, statementCoreHash, i) mod p`
   off-chain — the same deterministic function the Inbox will run — and `y = p_B(z)`. All of this is fixed
   before submission.
3. Attacker now builds the payload `D` it actually wants executed (e.g. a batch whose first transaction emits a
   Bridge withdrawal signal with attacker-chosen fields), requiring `p_D(z) = y`. That is **one linear equation over
   the 4096 field elements of `D`**; it is solved by fixing 4095 of them to the malicious payload's values and
   solving the remaining one (retry with a different free chunk if the solution is not < BLS_MODULUS, ~2 tries on
   average; `z` does not change because only `D`, not `B`, is varied).
4. Attacker runs the honest guest program with `D` supplied through the host/witness, obtains the proof, and submits
   `land` with blob `B`, its commitment, `z`, `y` and the proof, in one transaction.
5. On-chain: `blobhash(i) == vh` holds; the precompile verifies `p_B(z) = y`; the guest verifies `p_D(z) = y`.
   Every check passes. L1 writes a checkpoint whose `stateRoot` is the post-state of `D` while the canonical data
   on Ethereum is `B`.

**Why the stated argument fails.** DA-03 says "the prover cannot choose `z` after choosing its data". True and
irrelevant: the prover chooses `z`'s **dependency** (the commitment) first and its **executed data** afterwards.
The executed bytes enter neither the journal nor `statementCoreHash` — only the versioned hashes do. The probability
bound `4095/|F|` is therefore for the wrong experiment: it bounds the chance that a payload *fixed before* `z`
happens to agree, not the chance that a prover *free after* `z` can construct agreement, which is 1.

**Inside/outside the fault model.** **Inside.** The prover is acting exactly as L1-04/L1-10 permit; PRF-11 already
classifies host-provided guest inputs as untrusted. No assumption failure is required.

**Attacker resources and cost.** One L1 blob transaction, one batch's proving cost, no stake, no validator keys.

**Harm and affected requirements/decisions.** R8 and DA-04/INV-02 are false for the blob path: the accepted
checkpoint is not a function of the data published with it, the executed history is unauditable and unreconstructible,
and any rule checked inside the guest (forced inclusion, bridge signalling) is checked against hidden data. Because
the SignalService anchor is the state root, value can be released on L1 against a state that no third party can
reconstruct. D5's "data and proof in the same transaction" is satisfied only formally.

**Evidence.** DA-03(iii)(iv) define `z` from `statementCoreHash` and `y` as the precompile's accepted evaluation;
DA-03(iv) computes `p_data` from the executed bytes; PRF-07(b)(ii) binds `challengeZ` to the journal. The journal
(PRF-02) contains no field hashing the executed payload, and `statementCoreHash` (L1-05 rows 1–17) contains only
`dataCommitment`, which for the blob path is a function of `vh` values.

**Fix direction (for the disposition round).** The executed bytes must be committed into the Fiat–Shamir transcript
before `z` is fixed, which the L1 contract cannot do for blob contents. The only sound options are (a) recompute the
KZG commitment of the executed data in-guest (exactly the in-guest MSM/pairing work D-2 avoided) or (b) drop the blob
path and make calldata the only DA mode. A linear-only check at a point the prover can adapt to cannot bind content.

---

## R1-02 — The in-guest polynomial interpretation contradicts EIP-4844

**Severity: High.** A central derived construction is factually wrong; implemented literally it either rejects every
honest blob-path batch or (worse, if "fixed" ad hoc) leaves the security argument in R1-01 attached to the wrong object.

**Exact rule.** `spec/04-l1-integration.html` DA-03(iv) ("interpret each 131,072-byte blob as 4096 coefficients
`p(X) = Σ c_j X^j` … Lagrange evaluation over those 4096 coefficients"), tagged Proven/premise (3)(4).

**Assumptions and preconditions.** EIP-4844 as deployed (A-L1-2/A-CRYPTO-3 name the KZG binding "as used by EIP-4844").

**Evidence.** In the EIP-4844/Deneb consensus specification, `Polynomial` is defined as "a polynomial in
**evaluation form**"; "All polynomials (which are always given in Lagrange form)"; and
`blob_to_kzg_commitment(blob) = g1_lincomb(bit_reversal_permutation(KZG_SETUP_G1_LAGRANGE), blob_to_polynomial(blob))`
(ethereum/consensus-specs, `specs/deneb/polynomial-commitments.md`, retrieved 2026-10-05; functions
`blob_to_polynomial`, `blob_to_kzg_commitment`). The 4096 blob scalars are evaluations at the (bit-reversed)
4096th roots of unity, not coefficients of `p(X)`.

**Concrete consequence.** The precompile's `y` is `p_blob(z)` for the Lagrange-form polynomial; DA-03(iv) has the
guest compute `Σ c_j z^j` from the same chunk values. These are different polynomials, so for honest data
`p_data(z) ≠ y` almost always: a literal implementation of PRF-07/DA-03 cannot produce an accepted blob-path proof at
all. If an implementer instead uses Lagrange interpolation, the R1-01 attack still applies (the equation is still
linear in the evaluations), but the specification's stated premises "(3) correct in-guest field arithmetic … exact
Lagrange evaluation" and "(4) canonical field elements" no longer describe what is being checked.

**Inside/outside the fault model.** Inside; this is a specification error, not an assumption failure.

**Harm / requirements.** R7, R8, R13; PRF-07 is tagged Proven on a premise that does not hold; the in-guest cost
study (F2) is scoped against the wrong operation.

**Fix direction.** Restate DA-03(iv) as: interpret the blob as evaluations of `p` at `{ω^{brp(j)}}`, interpolate in
the Lagrange basis (or equivalently use the inverse bit-reversal permutation) to obtain `p_data(z)`, reject any
evaluation `≥ BLS_MODULUS`, and keep the R1-01 fix in mind because the linear structure is unchanged.

---

## R1-03 — The claimed epoch is not bound to the batch's heights or to a set version

**Severity: High.** CONS-08(1) exists precisely so "signers cannot choose which set judges them"; no verification
rule enforces it, and the L1-side check as written (L1-05 row 9) is satisfiable by any epoch that has a stored
commitment. Security-relevant rule left to the implementer (R13).

**Exact rules.** `spec/02-consensus.html` CONS-08(1) ("MUST equal `epoch_of(height)` … otherwise its signers could
choose which set judges them"); `spec/04-l1-integration.html` L1-05 rows 9/10 and 12; `spec/05-proof-statement.html`
PRF-02 (`epoch … (L1: checked vs schedule)`, `configHash … consensus-relevant config commitment`) and PRF-04.

**Assumptions and preconditions.** None beyond normal operation; the attacker need not be a validator in the epoch
whose heights it attacks.

**Concrete trace.**
1. Let the L1 checkpoint be at height `P`. The attacker holds the keys of `>2/3` of some **past** epoch's set
   (long-range attacker, threat T-11; after unbonding, A-CONS-1 does not cover them).
2. It builds a fork of headers `P+1 … P+k` descending from `prevBlockHash`, containing arbitrary transactions.
3. It forms a commit certificate over that fork's head with `epoch = e_old` (the signed vote bytes carry the epoch
   field), signed by its old-set supermajority. The claimed public input `epoch` is `e_old`.
4. L1-05 row 9 checks only that the staking contract has a non-zero commitment for `e_old` — it does. Row 10 reads
   `validatorSetRoot` "for `epoch`" — a root the attacker's set satisfies. PRF-04 verifies the signatures against
   that root; nothing checks `e_old == epoch_of(k)` or that the batch's heights lie inside `e_old`.
5. The batch lands: the attacker has anchored a fork from a checkpoint it did not control under current rules.

**Two further reasons the binding cannot currently be implemented.**
- **Which root is "for epoch `epoch`"?** MEM-09(2) defines `setVersion(e)` as "the highest `k` such that the L1
  block `N(k)` is Ethereum-final **in the L1 view committed by the first L2 block of epoch `e`**" — an L2-derived
  fact. `commitSet()` (MEM-08) takes no arguments and stores roots **per set version k**, not per epoch. No rule tells
  the Inbox how to resolve epoch→version, and L1-05 row 10's wording ("the staking contract's commitment for
  `epoch`") does not match MEM-08/MEM-09's data model.
- **The schedule is not in the statement.** To check `epoch == floor((lastHeight − H_0)/L)` the guest needs `H_0` and
  `L`; `configHash` is described only as a "consensus-relevant config commitment" and no rule says what it commits
  to, so an implementer must invent the contents (or omit the check). CONS-14 stores `H_0`, `L`, `W_0` in the Inbox;
  PRF-02 does not bind them.

**Inside/outside the fault model.** The attacker is T-11, which the threat model explicitly names; it is outside
A-CONS-1 for the attacked epoch but inside the model's capability set. MEM-12's defences (checkpoint anchoring,
freshness) are about nodes, not about this L1 verification path.

**Attacker resources and cost.** Keys of a historical set with `>2/3` power (obtainable by having been large
earlier, or by key retention after exit), plus proving cost.

**Harm.** Two conflicting finalized histories anchored into the preserved SignalService, i.e. the exact failure
Mode A claims cannot occur through rules; the "one certificate per batch" argument (PRF-08) loses its per-epoch
premise. Affects R5, R7, R13, D2, INV-01.

**Fix direction.** Make L1 compute `epoch_of(lastHeight)` from its own activation record and require equality; put
`(H_0, L)` (or a commitment opening) into the journal via `configHash` and have the guest recompute the schedule;
and define the epoch→set-version resolution as an L1-committed value (e.g. the Inbox freezes
`setVersion(e)`/`N(setVersion(e))` when it first lands a batch of epoch `e`, cross-checked against the header field
CONS-10(2)).

---

## R1-04 — A boundary-crossing batch has no public inputs for the intermediate epochs' sets

**Severity: High.** PRF-05(iii) claims each crossed epoch's set commitment is "supplied as a public input rather than
as a witness"; the public-input list cannot carry more than one set.

**Exact rules.** `spec/05-proof-statement.html` PRF-02 (journal has exactly one `epoch`, `validatorSetRoot`,
`totalVotingPower`, `quorumThreshold`) vs PRF-05(i)–(iii) ("For **every** epoch boundary inside the batch …
(iii) **each epoch's** set commitment equals the value the L1 staking contract fixes for that epoch, supplied as a
public input rather than as a witness"), and PRF-03 ("No witness element may define the authoritative validator
set"). PRF-01 explicitly allows batches that cross boundaries.

**Concrete attack/defect trace.**
1. A batch spans epochs `e` and `e+1`. The journal authenticates only the head epoch's set.
2. For the boundary PRF-05(i)/(ii) the guest can check only the internal equality
   `next_validators_hash(last header of e) == validators_hash(first header of e+1)` — a relation between two
   witness-provided header fields.
3. Because there is no public input for `set_root(e+1)` (or for `e` if the head belongs to `e+1`), the equality is
   not tied to L1. An implementer who wants to check it must take the root from the witness, contradicting PRF-03 and
   PRF-13; an implementer who follows PRF-02 literally cannot check it at all.
4. PRF-08's "the certificate of the head implies the whole prefix" is then not a proof about the intermediate set
   transitions, even before the F1/Cons-09 question.

**Inside/outside the fault model.** Inside (a specification defect); a prover exploiting the missing binding needs a
boundary-crossing batch and a fabricated header set commitment, which is only useful in combination with a
certificate for the head under the real head-epoch set — but the claimed binding is absent regardless.

**Harm.** PRF-05's claim is false for boundary-crossing batches; PRF-03/PRF-13 are violated in the only way the rule
permits; R7/R13.

**Fix direction.** Make the journal an array of per-epoch
`(epoch, setVersion, validatorSetRoot, totalVotingPower, quorumThreshold)` for every epoch the batch touches
(adjacent epochs only, so the array is small and bounded by the batch length), and require L1 to derive each element
from staking state.

---

## R1-05 — Two incompatible validator-set commitments are both tagged Proven

**Severity: High.** PRF-03 requires a Merkle inclusion proof against `validatorSetRoot`; CONS-10 requires the header
field to equal a flat hash of a *different* preimage. Both cannot be true; an implementer must silently drop one of
the two bindings.

**Exact rules.** `spec/03-membership-staking.html` MEM-08 (`R_k` = Merkle root over
`keccak256(abi.encode(DOMAIN_SET_LEAF, chainId, k, index, pubkey, effStake))` leaves, promoted odd nodes, root only
over `(pubkey, effStake)`) vs `spec/02-consensus.html` CONS-10(2)
(`set_bytes(e)=abi.encode("TAIKO_ETNA_SET_V1", chain_id, e, n, [(validator_index, consensus_pubkey, voting_power:u64, l1_account:address)])`,
`set_root(e)=keccak256(set_bytes(e))`) and CONS-10(3)–(4) ("the head's `validators_hash` … MUST equal the L1-committed
`set_root(e)`"). PRF-02 field `validatorSetRoot`; PRF-03(a); PRF-05(i)/(iii).

**Worked disagreement.** For a set with `n > 1` the two roots are different values by construction (different
preimages, different tree structure, and `l1_account` is in CONS-10's preimage but explicitly *not* in MEM-08's
"what the root commits to — exactly"). Therefore `validators_hash == L1 set root` (CONS-10) and "recompute the leaf from
`(pubkey, effStake)`, verify its Merkle path to `validatorSetRoot`" (PRF-03) cannot both hold. One of the header
chain binding or the Merkle membership proof necessarily fails; whichever is dropped, the set is authenticated by
only one of the two L1 facts the design claims.

**Second defect in the same area (unit mismatch).** MEM-02(2)/MEM-08 use `effStake` in TAIKO **base units**
(`uint256`, up to 1e27) and PRF-02 types `totalVotingPower` as `uint256`; CONS-10 encodes `voting_power:u64`. A
u64 cannot carry base units, and no rule defines a stake→voting-power **quantization** (the opposite is required:
MEM-01 rejects the gwei-quantized legacy ledger). CONS-06 compounds it: proposer selection
`pos = (H − h_first + R) mod W` with `W` in base units is arithmetically total but the "modest integer W"
counting argument has no meaning, and any truncation silently changes quorum weights.

**Inside/outside.** Inside; a specification inconsistency, not an attack requiring assumptions.

**Harm.** R7/R13; PRF-05's set-transition check is not implementable against both L1 facts; a set-substitution
surface if the implementer keeps the weaker binding.

---

## R1-06 — The pure-blob data commitment is undefined and the data-commitment rules contradict each other

**Severity: High.** L1-05 row 16 is a tx-derived public input the contract must compute "per DA-02 and/or DA-03";
DA-02 enumerates only `daMode ∈ {1,3}` and DA-03 defines no commitment at all for `daMode = 2`.

**Exact rules.** `spec/04-l1-integration.html` DA-02 (formula with `payloadRoot = keccak256(_batchData)` and
`daMode` 1 or 3), DA-03 (no `dataCommitment` definition; hybrid mode defines only `payloadRoot`), L1-05 rows 16/17;
`spec/05-proof-statement.html` PRF-07(a) ("the contract hashes the exact calldata slice … requires
`dataCommitment` to equal that hash"), PRF-07(b)(v) ("the guest also requires `keccak256(executed data) ==
dataCommitment` as in (a)"), PRF-02 (journal `challengeZ` singular, `evaluationsY[]`) vs L1-05 rows 18–19
(`challengeZ[i]`, `challengeY[i]`); 09 glossary ("Data commitment … computed by the L1 contract on the calldata
path, **or by the guest on the blob path**").

**Worked contradiction.**
1. **daMode = 2 (BLOB).** The contract cannot read blob contents; only `BLOBHASH` (32 bytes per blob) is available.
   DA-02's formula needs `_batchData`; DA-03 gives none. L1-05 row 16 therefore has no implementation. Any value the
   implementer invents (e.g. a hash of the versioned hashes) is a commitment to *public inputs*, not to data, and
   cannot make PRF-07(b)(v) true.
2. **PRF-07(a) vs DA-02.** DA-02's `dataCommitment` is
   `keccak256(abi.encode("TAIKO_ETNA_DATA", chainid, first, last, daMode, payloadRoot))`, not `keccak(_batchData)`.
   PRF-07(a) says `dataCommitment` **equals** the calldata hash; the two statements cannot both be normative.
3. **PRF-07(b)(v) vs both.** For a hybrid batch the executed data is `_batchData || blobChunk[0] || …` (DA-03
   "Hybrid mode"), so `keccak256(executed data)` equals neither `dataCommitment` nor `payloadRoot` (which is a
   structured hash over `keccak(_batchData)` and the `vh[]`).
4. **Challenge fields.** PRF-02's journal has one `challengeZ` and an array `evaluationsY[]`; DA-03(iii) and L1-05
   rows 18–19 require one challenge **per blob index** (`z_i = H(tag, chainid, statementCoreHash, i) mod p`), so a
   multi-blob batch cannot be checked against the journal as specified. PRF-07(b)(ii) then gives a **different**
   Fiat–Shamir formula (`challengeZ = H(all other journal fields)`) from DA-03(iii)'s indexed one.
5. **Journal vs table.** PRF-02 is "the exact list, order is normative", but it contains `blobHashesHash` and
   `evaluationsY[]` while L1-05's binding list contains `challengeZ[i]`/`challengeY[i]` and no `blobHashesHash`;
   L1-05 says the contract hashes "the whole vector" into `statementHash` and passes only that to the verifier, so
   the two vectors must be byte-identical for the verifier to bind the journal. As written they are not.

**Inside/outside.** Inside; the highest-risk integration point named by PRF-02 itself.

**Harm.** R7/R8/R13, D5's binding, INV-02; an implementer must invent the data commitment and the challenge
encoding — exactly the class of rule PRF-13 forbids.

---

## R1-07 — Forced-inclusion refund and coverage payout pay the same fee twice (or revert the batch)

**Severity: High.** The forced-inclusion ledger has no conservation rule; the two normative rules that touch it
cannot both be implemented as written, and the failure mode is "the batch cannot land" — which L1-04 forbids as an
admission gate.

**Exact rules.** `spec/04-l1-integration.html` FI-03(b) ("the requester becomes entitled to a refund of the fee it
paid, claimable from the Inbox at any time thereafter, **without removing the request or affecting its coverage
obligation**"), FI-02 (`due = { r : eligibleAtL1Timestamp <= firstBlockTimestamp && !consumed[r] }`,
`setEquals(coveredIds, due)`), FI-05 (no cancellation once eligible; refunds only after the escape threshold),
L1-11 (`forcedInclusion_after = forcedInclusion_before − Σ_{r∈covered} feeHeld[r]`; "each covered request's fee
MUST be paid at most once"; `require(forcedInclusion_after >= 0)`), L1-04 (no attribute of `land` may make a
finalized range permanently unacceptable).

**Attack / defect trace.**
1. Attacker submits `requestForcedInclusion` (paying `feeHeld[r]`), a cheap L1 transaction.
2. After `FORCED_INCLUSION_ESCAPE_THRESHOLD` it calls the refund. FI-03(b) grants the refund **and** keeps the
   request in the queue; no rule zeroes `feeHeld[r]` or marks it refunded, and no rule makes the refund
   claimable only once (L1-08's sketch has a bare `refundForcedInclusionFee(uint64)`).
3. Because the request is never `consumed`, it remains in `due` for **every** subsequent batch. Any batch that
   covers it must subtract `Σ feeHeld[r]` (L1-11) — a fee already paid out.
4. Case (a): the arithmetic credits the request twice → the ledger pays two fees for one deposit (drain of the
   forced-inclusion ledger, which also funds the feeRecipient payout), and repeated refunds drain it further.
   Case (b): the ledger is exact, so `forcedInclusion_after >= 0` fails → `land` reverts for **every** batch whose
   `due` set contains the refunded request, i.e. permanently: the attacker has made the finalized range
   unlandable for the price of one request and its own refund.

**Inside/outside the fault model.** Inside: the attacker is any L1 account (T-13 griefing); no assumption fails.
Even absent an attacker, the spec does not say what an honest implementation must do.

**Harm.** Ledger drain (L1-11's conservation claim) or a permanent settlement halt (Mode A / L1-04 / R9 / FI-03).
R10's censorship remedy is turned into a settlement-stopping tool.

**Fix direction.** State the forced-inclusion ledger's conservation identity; make the refund idempotent and
terminal for the *fee* (zero `feeHeld[r]` and record `refunded[r]`), and state explicitly that covering a refunded
request pays `feeHeld[r] = 0` to the feeRecipient while still consuming the request. Alternatively define the refund
as a lien on the future coverage payment rather than an immediate payout.

---

## R1-08 — The two layers of the forced-inclusion duty use different clocks

**Severity: High.** FI-02 requires exact equality between the L2 validity rule's included set and the L1 backstop's
computed set; the two predicates are different, so a block that honest validators legally finalized can be
permanently unlandable.

**Exact rules.** `spec/04-l1-integration.html` FI-02(a) ("every request that is **eligible and has been observed at
the configured Ethereum finality depth as of the proposal's parent**") vs FI-02(b)
(`r.eligibleAtL1Timestamp <= _input.firstBlockTimestamp`), with `setEquals(coveredIds, due)`; FI-04; L1-04;
`spec/01-system-model.html` SYS-02(f) ("an L1 request may not become due … before the carrying L1 transaction is
Ethereum-final").

**Worked counterexample.**
1. Let `FORCED_INCLUSION_DELAY_SECONDS = D` and Ethereum finality lag `T_final` (09: `L1_FINALITY_DEPTH` ≈ 2
   epochs; the baseline figures in 04/FI-01 record 576 s, i.e. `D < T_final`). Request `r` is included at L1 time
   `t0`; `eligibleAt = t0 + D`.
2. At wall time `t = t0 + D` the request is eligible by timestamp, but the proposal's parent has an L1 view at
   finality depth, i.e. `t − T_final < t0`: the request's inclusion is **not yet observed at finality depth**.
   FI-02(a) therefore permits the proposer to omit it; honest validators accept the proposal.
3. The batch is finalized and later submitted to `land`. L1 computes `due` by timestamp and includes `r`.
   `setEquals` fails → `ForcedInclusionNotCovered`. The head block hash is proof-bound to the finalized block, so
   no other batch can cover the same range. The range is **permanently unlandable** unless the L2 produces a
   different block at the same height, which Mode A forbids.
4. `FORCED_INCLUSION_MAX_DRIFT` only bounds `firstBlockTimestamp` below relative to `block.timestamp`; it cannot
   reconcile the parent's finalized L1 view with the block's own timestamp.

**Inside/outside the fault model.** Inside: no attacker is required; an attacker can also *time* a request to
straddle the finality boundary (T-13/T-7) to force the halt deliberately.

**Harm.** A legitimately finalized range becomes permanently unacceptable — L1-04, FI-02, R9, R10, D2/Mode A, and
HALT-01's "safe halt" is not safe because there is no rule-legal continuation.

**Fix direction.** Define **one** due predicate and use it on both layers: e.g. `due(H) = { r : r observed
Ethereum-final in the parent's L1 view and r.eligibleAtL1Timestamp ≤ timestamp(parent) }`, and make `land` compute
the same set from an L1-committed record of each request's finalized inclusion coordinates rather than from
`firstBlockTimestamp`. Add the missing rule that the L1 predicate is *entailed* by the L2 predicate.

---

## R1-09 — The L1→L2 checkpoint writer is still a privileged sender, and its payload has no validity rule

**Severity: High.** SYS-02 claims the golden-touch gate is removed and MSG-01/SYS-04 claim no single privileged
checkpoint writer; MIG-04 retains the gate for the Anchor, whose key custody is an unresolved precondition (P4).
The L2 SignalService checkpoints authenticate L1→L2 messages, so this is a bridge-minting surface.

**Exact rules.** `spec/01-system-model.html` SYS-02 §3.1 table ("The golden-touch gate is **removed**. L2 state
derives from L1 facts verified at Ethereum-final depth, not from one privileged sender"; "the L2 SignalService …
must be repointed … to a write path that is not a single privileged address") and SYS-04(b); vs
`spec/08-migration-upgrades.html` MIG-04 ("`GOLDEN_TOUCH_ADDRESS` gate … **retained as the reserved system
sender**, with no discretion … That the address is not key-controlled by any single party is a migration
precondition, not a property proven here"), MIG-06 (a re-deployed SignalService keeps the same
`_authorizedSyncer`), P4 (Assumed); `spec/04-l1-integration.html` MSG-01/MSG-03 (preserved checkpoint writer;
L1→L2 release requires the Anchor's observation).

**Preconditions / assumption.** The attack requires P4 to fail, i.e. the golden-touch address (or the Anchor's
`onlyValidSender` path) to be controllable — the spec itself tags this "Assumed", not established. It is named
here as required by review rule 6; the *defect* that does not depend on P4 is the contradiction plus the missing
payload-validity rule ("no discretion" is asserted, not enforced: SYS-02's table says the Anchor's rolling-ancestor
continuity rule "is not inherited implicitly" and no replacement rule is stated anywhere in 04/05).

**Attack trace (contingent on P4 failing).**
1. Holder of the golden-touch key submits the Anchor's system transaction on L2 with an attacker-chosen L1 block
   hash/state root and a monotone `anchorBlockNumber`.
2. The L2 SignalService writes a checkpoint for a fabricated L1 block. Nothing in 04/05 gives validators an
   objective rule to reject the payload (unlike `land`, which verifies a proof), and MIG-06 keeps the same
   authorizedSyncer/write path.
3. The attacker proves an L1→L2 deposit that never happened and the L2 vault mints/releases value; the L1 vault
   still holds the canonical asset.

**Inside/outside.** The retained privilege is a specification defect (inside); the theft step is an F3/assumption
failure (P4) — stated explicitly.

**Harm.** R2, R3/D3, INV-04, SYS-02/SYS-04; bridge-fund loss if P4 fails; a runtime lever that contradicts the
project's own no-privilege claim.

**Fix direction.** Pick one: (a) follow SYS-02 and remove the gate, making Anchor checkpoints a rule-checked
system transaction validated by consensus (state the validity predicate: exact L1 block number, parent linkage,
finality depth, monotone anchor number, and no discretion); or (b) state the retained privilege honestly in
SYS-02/SYS-04/INV-04 and move P4 from "precondition" to a named trust assumption with its consequence.

---

## R1-10 — Partial withdrawal can shrink the stake that later evidence confiscates

**Severity: Medium.** The withdrawal race is defeated only by the conjunction MEM-06(3) declares; as written,
MEM-06(2) permits a partial withdrawal while epochs are still open, and the retained amount is a **max**, not a
**sum**, over the entry's open epochs.

**Exact rules.** `spec/03-membership-staking.html` MEM-05(3) (withdraw only when the delay elapsed, every epoch's
evidence window closed, and no unsettled exposure), MEM-06(2) ("**At any moment** the owner may withdraw at most
`bonded(v) − max_exposure(v)`", `max_exposure = max{SlashBase(v,e) : e open}`); `spec/07-economics-slashing.html`
ECON-07(5) (`withdraw()` reverts while any open epoch's window has not closed or exposure is unsettled),
ECON-08(5)(a) ("the state 'the offender has withdrawn stake exposed to a still-open epoch' [is] unreachable"),
ECON-05(3) (unapplied remainder is not carried as debt).

**Worked trace.**
1. Entry `v` is in epochs `e1` and `e2` with `SlashBase = 100` each, `bonded = 200`. Both windows are open.
2. Under MEM-06(2) the owner withdraws `200 − max(100,100) = 100`, leaving 100.
3. The owner equivocates at both epochs (or evidence for both arrives). Each epoch's charge may be up to
   `SlashBase = 100`; total 200 > 100 held. ECON-05(3) applies `charge = min(P, bonded, remaining_exposure)` and
   does **not** carry the remainder, so half the penalty evaporates.
4. ECON-08(5)(a)'s unreachability claim is false for the other epoch's exposure whenever MEM-06(2) is implemented
   in addition to MEM-05(3).

**Inside/outside.** Inside; an accounting rule conflict, exploitable by a validator that has already decided to
equivocate (A-CONS-1 bounds how *many* such validators exist, not whether one can reduce its own loss).

**Harm.** R11's "collateral/exit delays" and ECON-07/MEM-06's stated guarantee; not safety-critical because
slashing is already bounded by `bonded` and ECON-11 discloses that, but the specific "follow the stake" guarantee
is weakened.

**Fix direction.** Choose one gate and delete the other: either the full-window gate of MEM-05(3)/ECON-07(5)
(remove MEM-06(2)'s "at any moment" partial withdrawal), or retain partial withdrawal but define
`max_exposure = Σ_{e open} SlashBase(v,e)` (or a per-epoch lien schedule) so the retained amount covers the sum of
open charges.

---

## R1-11 — Evidence identity is a hash of the whole blob, so padding creates "distinct" offences

**Severity: Medium.** The no-op rule is the only duplicate protection; it is keyed on
`keccak256(evidence)`, and the spec never requires decoding to consume the input exactly.

**Exact rules.** `spec/07-economics-slashing.html` ECON-04(2) ("`evidence` is exactly one canonical
`abi.encode` … Decoding failure … makes the whole transaction revert"), ECON-04(4)/ECON-08(2)
(`id = (v, epoch, offenceType, keccak256(evidence))`; a second submission of the same id is a no-op),
ECON-06(3) (bounty "paid once per applied offence identity"), ECON-05(3)/ECON-08(3) (per-epoch charge cap).

**Trace.** `abi.decode` in Solidity does not reject trailing bytes. Submit the same two signed messages once;
then submit `evidence || 0x00` (and further paddings). Each is a different `keccak256(evidence)`, hence a different
`id`, hence not a no-op. The per-epoch cap `SlashBase` bounds the additional debit to zero once the cap is
reached, but any bounty keyed on "applied offence identity" can be paid again for what is objectively one offence,
and `applied[id]` grows without bound. If a reporter bond exists (ECON-08(1)), each padded copy is also a distinct
identity for forfeiture purposes.

**Inside/outside.** Inside; a contract-input canonicalisation defect (F3 class), no assumption fails.

**Harm.** ECON-08(2)'s idempotence and ECON-04(4)'s no-op guarantee; possible bounty/ledger leakage; R11.
Severity Medium because the charge cap limits the direct stake loss.

**Fix direction.** Require `evidence.length == expectedLength(offenceType)` before decoding (strict decoding), or
define `id` over the *decoded* payload fields rather than over the raw blob.

---

## R1-12 — The reward pool has no funding path from L2 fees to L1

**Severity: Medium.** Rewards are paid on L1 inside `land` from an "L1-committed reward pool" that no rule ever
funds with L2 fee revenue, and the batch's own fees cannot be there yet (they are inside the state being proven).

**Exact rules.** `spec/04-l1-integration.html` L1-11 ("a prover reward ledger funded by **L2 fee revenue
(ECON-02)** and by any `msg.value` the submitter adds"; `rewardPaid = min(REWARD_QUOTE, proverReward_before +
msg.value)`), L1-11 ("`land` MUST NOT require a non-zero `rewardPaid`"); `spec/07-economics-slashing.html`
ECON-02(1)(5) (`Σ rewards ≤ F_exec_L2 + …`; "Payment happens in the L1 acceptance transaction from the
L1-committed reward pool"); 09's parameter table has no funding-path parameter.

**Trace / defect.** There is no specified message, bridge call, or escrow that moves L2-collected fees to the L1
ledger, and no rule that prior batches' fees are forwarded. Consequence: the pool can only be funded by
`msg.value` from provers (who then pay to land) or by an unstated treasury transfer — an implementer must invent a
value-transfer path, which crosses the bridge surface (D3/D5).

**Inside/outside.** Inside; a missing rule (R13), economics/accounting.

**Harm.** ECON-02's funding identity and R11's "payouts" clause; a prover-reward shortfall is fine by construction
(`rewardPaid = 0`), but the specification cannot claim the identity holds.

---

## R1-13 — Parameters promised to 09 are absent from 09, and the epoch length has two values

**Severity: Medium** (traceability; the epoch-length conflict is a consensus-parameter inconsistency and would be
High if treated as normative).

**Exact rules.** `spec/09-parameters.html` PARAM-01 ("Every protocol parameter appears in the table below …
A parameter with no derivation and no source may not be given a value"), PARAM-03; vs
`spec/04-l1-integration.html` DA-05 ("The design therefore MUST specify, in 09: (a) `RETRIEVABILITY_WINDOW` …
(b) an `ARCHIVE_REQUIREMENT` …"), DA-06 ("all four are fixed in 09"), FI-01 (`FORCED_INCLUSION_DELAY_SECONDS`
"value is fixed in 09"), FI-02 (`FORCED_INCLUSION_MAX_DRIFT`), FI-05 (`MAX_FORCED_INCLUSIONS_PER_BATCH`,
`MAX_FORCED_INCLUSION_BYTES`, `BASE_FEE`, `FEE_DOUBLE_THRESHOLD`, `MAX_FEE`, `CANCELLATION_COST`), L1-05 row 7
(`MAX_BATCH_BLOCKS`), MSG-03 (`WITHDRAWAL_DELAY`), L1-11 (`REWARD_QUOTE`).

**Evidence.** The 09 parameter table and the PARAM-03 register contain **none** of those identifiers (they contain
`L2_BLOCK_INTERVAL`, `EPOCH_LEN_L2/L1`, `TIMEOUT_*`, `L1_FACT_MAX_AGE`, `L1_FINALITY_DEPTH`,
`T_PROOF_ENVELOPE`, `BATCH_BLOCKS`, `D_MAX`, `D_WITHDRAW`, `W_EVIDENCE`, `ACTIVATION_DELAY`,
`MIN_STAKE`, `IMM_FRAC`, `F_SAT`, `CORR_Q`, `CORR_DELAY`, `SUBSIDY_*`, `T_STALL`). Separately,
`EPOCH_LEN_L2 = 300` (≈10 min, "placeholder") in 09 contradicts `CONS-13(1)`'s "Proposed value `L = 900`
heights" (30 min) — a consensus parameter that determines epoch boundaries, set transitions, slashing windows and
the number of boundary crossings per batch.

**Inside/outside.** Inside; GEN-03/PARAM-01 compliance defect (R13).

**Harm.** Reviewers and implementers cannot find the normative values; a batch-spanning/slashing argument built on
one epoch length breaks on the other.

---

## R1-14 — Verifier routing is self-contradictory while PRF-09 is Open

**Severity: Medium.**

**Exact rules.** `spec/04-l1-integration.html` L1-09 ("**Exactly one** *active route* MUST be consulted per
`land` call" … "with an either-verifies policy it MUST try **each** enabled route for the active image");
`spec/05-proof-statement.html` PRF-09 (acceptance policy (a)/(b) — **Open**, "resolved by the launch decision");
PRF-10 (an upgrade "adds a new accepted identity; it must not remove the ability to accept proofs for batches whose
head block was finalized under the previous identity"), MIG-05 (per-epoch accepted image sets).

**Defect.** The number of verifier calls, which contract is called, and whether a proof under either backend is
accepted is not fixed by any normative rule at review time; L1-09 simultaneously mandates single-route and
multi-route behaviour; PRF-10's "additive identity" model requires an epoch-indexed registry (MIG-05 grants Inbox
slot 261), while L1-09's "exactly one active route" has no epoch dimension. An implementer must invent the routing
rule — the exact class PRF-09's own failure-mode note warns about.

**Inside/outside.** Inside; R13 (and R7's "credible on RISC Zero and SP1").

**Fix direction.** Close PRF-09 (choose a policy) and make L1-09 literal for the chosen policy, including the
epoch-indexed accepted-image registry, the retirement rule, and the number of verifier calls per `land`.

---

## R1-15 — MSG-01 requires checkpoint fields the preserved SignalService does not have

**Severity: Medium.** Bridge consumers are told they can tell which consensus and which data produced a root, but
the preserved storage and MIG-02/MIG-06 prevent carrying that information.

**Exact rules.** `spec/04-l1-integration.html` MSG-01 ("MUST carry the epoch, the set commitment and the data
commitment so that a bridge consumer can tell *which* consensus and *which* data produced the root it is proving
against"; "The checkpoint key MUST remain the L2 block number"); `spec/04` L1-07 (those fields live in the
**Inbox's** record); `spec/08-migration-upgrades.html` MIG-02 (SignalService: "No state change. The implementation
is re-deployed with the *same* immutable values … and the same checkpoint semantics"), MIG-06 (same
`_authorizedSyncer`, same `VERSION`); MSG-03 (authentication resolves `_checkpoints[VERSION][blockId]` and
compares only `stateRoot`).

**Defect.** The existing checkpoint struct is three fields (baseline §, `{blockNumber, stateRoot, blockHash}`);
extending it changes the preserved contract's storage/ABI, which MIG-02 forbids and which MSG-02 warns invalidates
cached received signals. As written, the bridge cannot distinguish a root produced by the agreed consensus over the
published data from any other root, and the extra fields exist only in a different contract that the
authentication path does not read.

**Inside/outside.** Inside; an inconsistency in the preserved-surface contract.

**Fix direction.** Either amend MIG-02 to specify the SignalService checkpoint extension (with the cache/version
migration impact stated), or make an Inbox-side lookup part of the authentication path and state that the
SignalService record alone does not carry the distinguishing fields.

---

## R1-16 — Interface name divergence (Low)

**Exact rules.** `spec/04-l1-integration.html` L1-01 ("Its name is `land(bytes calldata _proof, LandInput
calldata _input)`", "MUST expose exactly one function") and L1-08 (sketch with `land`); vs
`spec/08-migration-upgrades.html` MIG-03(1) (`accept(data, proof)`), MIG-05, and 09's glossary. Low: the name is
not security-relevant, but the migration-state gate is specified against a function that L1-01 says must not exist
under that signature.

---

## R1-17 — PRF-04's signature check is shorthand that omits two required bindings (Low)

**Exact rule.** `spec/05-proof-statement.html` PRF-04(i) ("every signature verifies … over the canonical vote
bytes for (domain tag, l2ChainId, epoch, height, round, block id)"); the canonical bytes in
`spec/02-consensus.html` include `type`, `validator_index` and `timestamp`; CONS-02 requires
`validator_index` to be the signer's position and CONS-03 requires `quorum_block` over **PRECOMMIT** votes only.
PRF-04 does not say "recompute the bytes with `type = PRECOMMIT` and the bitmap index", nor that the witness-supplied
"canonical vote bytes" must be reconstructed rather than trusted (PRF-11). Low because the cross-reference to the
canonical encoding resolves it for a careful implementer; it should be explicit.

---

## Answers to the three assigned questions

### Q-A1 — Is the Mode A availability counterexample reachable inside the stated liveness assumptions?

**Verdict: it is a failure OF the stated liveness assumptions, not inside them, and the Mode A selection survives
D2 step 1 on this point.** The counterexample requires A-CONS-5 (correct validators hold and can serve the data they
voted for) and/or A-DA-2 (at least one adequately-resourced prover completes each batch) to fail; D2 step 1 and the
requirements document explicitly permit a safe halt outside those assumptions, and LIM-01/§"Unavailable data for a
finalized block" disclose exactly that outcome ("a halt, possibly permanent, unless a holder returns … never
repaired by rollback"). DA-04's structural claim — no data-first interval exists, so the *pending-batch* variant of
the June 2026 incident cannot recur — is correct as a design statement. Two caveats that do not reopen the
selection but that a disposition round should record: (i) "safe halt" presumes the only stall causes are missing
data/proofs, yet R1-08 manufactures a permanent unlandability from inside the rules (a due-set predicate
mismatch) and R1-07 can make `land` revert on every batch — those are Mode A *rule* defects, not assumption
failures, and they should be fixed rather than disclosed; (ii) R1-01 shows a different, non-liveness failure of the
same "data" guarantee (executed data ≠ published data) that is inside the assumptions, so the availability story
cannot be used as a blanket defence of the data path. On the narrow question asked — is the counterexample
reachable inside the stated assumptions, and does the selection survive D2 step 1 — the answer is no and yes.

### Q-A2 — Is the "one commit certificate per batch" argument (PRF-08) sound for the whole prefix, including across epoch boundaries?

**Verdict: sound within one epoch under INV-01's premises, not sound as stated for the whole prefix.** Within an
epoch the induction is standard Tendermint: a `>2/3` precommit quorum at `H` implies those validators accepted a
proposal whose parent they had finalized (CONS-01(iii)), so the ancestor chain is covered; the guest's header-link
check from `prevBlockHash` supplies the structural part. Across boundaries the argument needs three things the
specification does not deliver: (a) the boundary duty CONS-09(2) (verify the closing epoch's anchor certificate) is
in PRF-08's premise list only implicitly — CONS-09 is tagged ASSUMED-with-argument (F1), so the prefix claim
inherits F1; (b) PRF-05 verifies structure (`next_validators_hash` equality, the `epoch_anchor` field) but never
verifies the anchor certificate, and the journal cannot carry the intermediate epochs' L1 set roots at all
(R1-04), so the step that makes the boundary sound in the argument is not checked by the proof; (c) the epoch that
judges the head is not bound to the head's height (R1-03), so "the head's certificate" is not necessarily a
certificate for the epoch the batch claims to be in. Verdict: fix R1-03/R1-04 and the CONS-09 premise before the
"one certificate per batch" claim can be relied on across boundaries; within an epoch it holds with the stated
premises.

### Q-A3 — Does the blob binding (DA-03) resist a grinding prover and a malicious caller?

**Verdict: no.** (1) The prover does not need to grind: it fixes a published blob `B` (hence `z` and `y`) and
then chooses the executed payload `D` so that `p_D(z) = p_B(z)` — one solvable linear equation, because `D`
enters neither the journal nor `statementCoreHash` (only the versioned hashes do). The `2^-243` bound is for the
wrong experiment (a payload fixed before `z`). (2) The in-guest polynomial is the wrong one anyway: EIP-4844
commits to the blob in Lagrange/evaluation form, while DA-03(iv) tells the guest to interpret the blob as
coefficients and evaluate `Σ c_j z^j`, so the premise "the guest establishes `p_data(z) = y`" is about a different
object than the precompile's `p_blob` (R1-02). (3) The per-blob challenge cannot be expressed in the journal
(PRF-02 has a single `challengeZ`; DA-03/L1-05 define `z_i` per index) and PRF-07(b)(ii) gives a different
Fiat–Shamir formula from DA-03(iii), so multi-blob batches have no consistent check. What *does* hold: `BLOBHASH`
is transaction-scoped, so a caller cannot reference another transaction's blobs (DA-03(i) is sound), and a caller
cannot choose `z` directly (it is contract-derived, DA-03(iii)). Those two properties do not save the binding,
because the prover is the party that chooses the executed data.

---

## Checked and found sound (so the disposition round can skip them)

- Quorum rounding is consistent across L1-05 row 12, PRF-04(iii), CONS-03 and 09: `floor(2W/3)+1 == min{q : 3q > 2W}`,
  strict at `3s = 2W`.
- `BLOBHASH` tx-scoping and the 192-byte `(vh, z, y, commitment, proof)` precompile input/return and gas figure
  match EIP-4844; `evaluationsY`/`challengeY[i]` correctly admits only an accepted evaluation.
- L1-03's verify-before-write ordering, L1-06 monotonicity, L1-10 first-valid-wins and mempool front-running
  disclosure, and L1-12 reorg handling are internally coherent.
- ECON-07's strict inequality `W_evidence + T_process + CORR_DELAY + M_ev < D_withdraw` and ECON-08(5)(b)'s
  ordering argument are correct **provided** R1-10 is resolved in favour of the full-window gate.
- MEM-07's per-epoch key binding (forward-only rotation, retired keys, no retroactive re-judgement) closes the
  obvious key-rotation laundering path.

## Working notes for the judge

- Findings R1-01..R1-09 break guarantees the specification claims ("Proven" rules) or make a finalized range
  unacceptable; R1-01 and R1-08 are the two that are unambiguously inside the fault model with no assumption
  failure; R1-09 is inside as a retained-privilege contradiction and outside only for the theft step (P4).
- R1-01 is the single strongest attack: it defeats D5/R8/DA-04 with a permissionless prover and no assumption
  failure, and it is the reason the D-2 decision ("blob binding without in-guest MSM or pairings") cannot stand as
  recorded.
