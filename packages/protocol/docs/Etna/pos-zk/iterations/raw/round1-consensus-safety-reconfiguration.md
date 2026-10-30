# Round 1 — adversarial review: consensus safety, hidden certificates, reconfiguration

Reviewer angle: **consensus safety / hidden certificates / reconfiguration** (independent adversarial).
Snapshot: commit `dfcf067a5b91a1b0bacd4470f5f5054d1f861a24` (branch `etna-pos-zk`); working tree unchanged.
Scope attacked: `spec/02-consensus.html` (CONS-01..15), `spec/03-membership-staking.html` (MEM-01..12),
`spec/06-recovery-exceptions.html` (REC/HALT/WH), with cross-checks into `spec/05-proof-statement.html`
(PRF-02..13), `spec/04-l1-integration.html` (L1-01..07, DA-02/03), `spec/09-parameters.html`
(PARAM-01..03), `spec/index.html` (GEN/STATUS), `01-requirements-and-threat-model.md`,
`04-architecture-decision.md` and `DECISIONS.md`.

Finding IDs are local to this file (prefix `CS-`); the liveness/DA reviewer's file uses `R1-xx`.
Convention used throughout for "inside the fault model": at most <1/3 Byzantine stake (A-CONS-1),
network adversary T-1 (delay/reorder/drop/partition/selective delivery), withholding T-4, Byzantine
leader T-3, permissionless participant actions, and failures of the *stated* liveness assumptions.
Outside: >=1/3 Byzantine, key compromise, zkVM soundness failure, malicious governance.

**Severity summary: Critical 3 (CS-01..CS-03) · High 6 (CS-04..CS-09) · Medium 1 (CS-10) · Low 1 (CS-11).**
All three Critical findings are inside the fault model; CS-01 needs no Byzantine stake at all
(a single leader, or an ordinary network adversary), CS-02 needs one minimum-bond key, CS-03 needs one
permissionless prover transaction.

---

## CS-01 — Critical — The epoch→validator-set mapping is not a deterministic function of L1-committed state; the proposer chooses the set version, and the rule contradicts MEM-09(3)/CONS-13(5)

**Severity: Critical** — one malicious proposer (T-3) with no extra stake selects the validator set that
judges an epoch; two correct nodes can judge the same epoch under two different genuinely L1-committed
roots; the deterministic-agreement assumption that CONS-12/INV-01 list as a safety premise (A-CONS-4)
is false by construction.

**Exact rule / missing rule.**
- `spec/03-membership-staking.html#MEM-09` (2): *"Let `setVersion(e)` be the highest k such that the L1
  block `N(k)` is Ethereum-final in the L1 view committed by the first L2 block of epoch e. Then
  `R_{setVersion(e)}` — read from L1 state at `N(k)` — is the epoch's validator set, and the epoch's
  first block commits `(setVersion(e), N(setVersion(e)))`."*
- `MEM-09` (3): *"A version can never be reverted to, re-used after being superseded, or amended."*
- `MEM-09` (4): a later version *"never governs an epoch that has already started"*.
- `spec/02-consensus.html#CONS-13` (3): the contract must commit `set_root(e+1)` **during** epoch e, and
  *"that commitment MUST be an Ethereum-final L1 fact before any block of epoch e+1 may be finalized"*;
  (5): *"If, when the L2 reaches `h_first(e+1)`, no Ethereum-final commitment for `set_root(e+1)` is
  available, then correct validators MUST NOT propose, prevote or precommit any block at heights >=
  `h_first(e+1)`, MUST NOT continue into epoch e+1 with epoch e's set, and MUST halt."*
- `spec/04-l1-integration.html#L1-05` rows 9–10 make `epoch` and `validatorSetRoot` **L1-derived**
  ("Read from the L1 staking contract's commitment for epoch"; "MUST already hold a non-zero set
  commitment for it (MEM-09)").
- `spec/09-parameters.html` glossary: *"Epoch: A logical interval during which a fixed validator-set
  version is authoritative. Epochs are numbered; **the set for epoch e is fixed before e begins**."*
- **Missing rule:** nothing requires the tuple `(e, k)` — which set version governs which epoch — to be
  an L1-committed object, and no header field carries the L1 view that would make MEM-09(2) checkable.
  `CONS-10`(1) defines exactly two header commitments (`validators_hash`, `next_validators_hash`) and
  neither is `(setVersion(e), N(setVersion(e)))`; MEM-09(2) nonetheless says *"the header field carrying
  this tuple is CONS-10's"*. `SYS-02`(c) commits only the coordinates of an L1 fact a block *consumes*,
  not the finalized-checkpoint coordinate that the "highest final k" judgement needs.

**Assumptions / preconditions.** A-CONS-1 holds; no Byzantine stake is required for the selection
attack (T-3 leader only). The divergence variant needs only normal staggered observation of Ethereum
finality, or T-1 selective delivery of one L1 block. No A-CONS-2 violation is needed for the
proposer-selection variant (the proposer simply commits a genuine but stale finalized view).

**Concrete attack trace (single-leader set substitution).**
1. During epoch e−1 (or e), the staking contract publishes versions `k` and `k+1`; both become
   Ethereum-final. `k+1` is the version CONS-13(3) intends to govern `e+1`; `k` is superseded.
2. The proposer of the first block of epoch e is malicious (or merely self-interested). It constructs
   the block committing `(k, N(k))` and an L1 view (a genuinely finalized L1 checkpoint) at which
   `N(k)` is the highest final set-version block. MEM-09(2) defines `setVersion(e)` *relative to the
   view the block itself commits*, so the committed pair is internally consistent.
3. A validator checking MEM-09(2) must verify "highest k final in the committed view". It cannot
   distinguish this from "highest k final in my view" because no rule or field fixes a view; the only
   further check is MEM-09(3)'s "not lower than its predecessor", which `k` satisfies. The block is
   accepted and signed under `R_k` — a set that has already been superseded.
4. The epoch now runs under `R_k` for any node whose own view agrees with the committed one, and under
   `R_{k+1}` for any node whose view is ahead. There is no L1 object that says which is right, so L1
   cannot adjudicate.
5. The concrete harm: superseded-set selection has a point. A version snapshots the ledger
   (`MEM-08`(4)/`MEM-09`(1)); choosing `k` over `k+1` chooses whether a validator's exit, an
   activation, or a slashing-forced exit is inside the epoch's set (and, with `MEM-03`(2)'s FIFO
   serving, which entries are in it). The leader picks the version whose quorum it prefers.

**Concrete counterexample (two conflicting certificates).**
1. Adversary (T-1) delays delivery of the single L1 block that makes `N(k+1)` final to a subset A of
   validators; group B receives it normally.
2. At `(h_first(e), 0)`: group A computes `setVersion(e)=k`, group B computes `k+1`. `CONS-06`'s
   proposer is computed over different `W`/cumulative sums, so the two groups have different proposers
   at the same `(H,R)`; each group rejects the other's proposal (wrong header set root) and votes for
   its own.
3. If A holds >2/3 of `R_k`'s power and B holds >2/3 of `R_{k+1}`'s power, both produce valid
   certificates at the same height. Both roots are genuinely L1-committed, so `CONS-05`'s validity
   check passes for both; every validator signed exactly one message at one `(H,R)` under the set it
   computed, so **no CONS-11 equivocation pair exists** — nothing is slashable.
4. Precondition: a version transition with large turnover, i.e. A's share of `R_{k+1}` < 1/3 while its
   share of `R_k` > 2/3. Permissionless exit/entry makes large inter-version turnover possible, and the
   adversary can bias it by adding stake that lands in `R_{k+1}` while delaying the L1 view of the
   outgoing validators. Even without step 3 ever firing, steps 1–3 of the previous trace already break
   A-CONS-4 determinism.

**A second, rule-level contradiction (no adversary needed).** If the commitment for the next epoch is
late, MEM-09(2)+(3) *require* `setVersion(e+1) = k` and permit continuing with epoch e's set
(monotonicity is satisfied). CONS-13(5) *forbids* exactly that and requires a halt. Two conforming
implementations diverge; the MEM-09 branch produces heights whose epoch field is `e+1` but whose set
is `R_k`, which no L1 lookup can map (L1-05 row 9 demands a commitment *for that epoch*), so those
certificates can never land — a settlement halt on history that was already PoS-finalized.
The same ambiguity propagates to `MIG-05`, which gates the accepted program-image set on *"the same
L1-committed boundary that fixes the validator-set root for e (MEM-09)"*: if clients disagree on the
boundary, they disagree on which proofs are acceptable.

**Also note (permissionless snapshot timing).** `MEM-09`(1) lets anyone call `commitSet()` at any time.
Because the governing version is "the highest final at the epoch's start", the *content* of the set is
chosen by whichever permissionless caller snapshots last before the boundary, within the range of legal
ledger states. A-CONS-4 requires the transition to be a deterministic function of L1-committed state,
not a function of an actor's timing choice.

**Inside or outside the claimed fault model.** **Inside.** Variant A: T-3 only, zero extra stake.
Variant B (two certificates): T-1 selective delivery + permissionless membership turnover; no
assumption failure beyond A-CONS-2 timing for one L1 block (and A-CONS-2 is a liveness assumption, so
its violation is not even needed to make the *rule* non-deterministic). The unconditional part — that
`setVersion(e)` is defined against a node-local view and that MEM-09(2) contradicts MEM-09(3),
CONS-13(5) and the glossary — requires no adversary at all.

**Attacker resources and cost.** One proposer slot (free, rotation-determined) for variant A; one
targeted L1-block delivery delay plus whatever stake is needed to place the incoming version's
composition for variant B. No token purchase is required for the selection attack.

**Harm and requirement affected.** R5 (consensus safety across set change), R13 (implementable rules),
D2/Mode A (INV-01's unique finalized prefix; CONS-12 premise (c) "the set and its weights are
L1-authenticated … cannot be chosen by a proposer"); A-CONS-4's consequence is exactly
*"set-substitution; certificate judged under the wrong set"*.

**Evidence.** Verbatim citations above; MEM-09(2) vs MEM-09(3) are mutually inconsistent on the
re-use of a superseded version; `CONS-10`(1) has no field for the tuple MEM-09(2) says the header
carries; `L1-05` rows 9–10 require the staking contract to hold a commitment *for an epoch* while
`MEM-08`(4) says the root does not commit to the epoch mapping and MEM-09 says versions are append-only
and epoch-agnostic. The liveness reviewer independently flagged the missing multi-epoch set list
(their cross-cutting note); this finding is the consensus-side root cause.

---

## CS-02 — Critical — Proposer rotation degenerates to one validator because CONS-06's residue is in the same units as MEM-02's base-unit weights

**Severity: Critical** — with the weights the specification itself fixes, the *entire epoch* (every
height, every round) has the same proposer: the lowest-sorted key. That single minimum-bond key can
halt the chain indefinitely (it is the proposer of every round, so a timeout never reaches another
proposer) or capture all ordering. LIVE-01(L2) and CONS-06's rotation claim are false as written.

**Exact rule / missing rule.**
- `spec/02-consensus.html#CONS-06`: `pos(H,R) = ((H - h_first(e)) + R) mod W`; `proposer(H,R)` = the
  unique i with `cum_{i-1} <= pos(H,R) < cum_i`, where `cum_i = w_0 + … + w_i` and `W = sum w_i`.
  The rule adds: *"The count above is exact in those integers and practically meaningful only if W is a
  modest integer; the stake-to-unit mapping, its quantization error and its tag are MEM-02's."*
- `spec/03-membership-staking.html#MEM-02` (2): *"Voting power is exactly the effective stake:
  `VP_k(v) = effStake_k(v)` — one TAIKO base unit is one unit of weight. There is no multiplier …"*
- `MEM-01`: bonded amounts are `uint256` TAIKO **base units** (18 decimals), *"never as a rounded
  integer multiple of gwei"*.
- **Missing rule:** no quantization/normalization of stake into a bounded weight grid. `CONS-03` even
  forbids a second weight vector ("a design with two weight vectors has two different security
  thresholds and is a defect"), and `PARAM-01`'s register contains no weight-unit parameter.

**Concrete computation.** Four entries with 40/30/20/10 TAIKO: `w = [4e19, 3e19, 2e19, 1e19]`,
`W = 1e20`. `L = 900` (CONS-13(1)), so for the whole epoch `H - h_first(e) + R < 900 + R`. Every
such `pos` lies in `[0, w_0) = [0, 4e19)`, i.e. **inside index 0's interval**. Index 1 is reached only
after `R >= 4e19 - 899` rounds at a fixed height; at `T_min = 3 s` (CONS-07(2)) that is
`>= 1.2e20 s ~ 3.8e12 years`. Even the smallest possible bond (`S_min = 1 TAIKO = 1e18`) exceeds 900
by fifteen orders of magnitude, so the degeneracy cannot be avoided by parameter choice under the
stated unit.

**Attack trace.**
1. An attacker generates Ed25519 keys offline and keeps one whose
   `keccak256(abi.encode(DOMAIN_SET_KEY, chainId, pubkey))` is smallest; with k candidate keys among n
   entries it is index 0 with probability ~k/(n+k), and it can re-grind for each new set version.
2. It bonds the minimum (`S_min`) and becomes `v_0` (MEM-08(2) sorts ascending by that hash).
3. It is now the proposer of every `(H,R)` in the epoch. Two ways to monetise:
   (a) **ordering capture** — all block building, all forced-inclusion ordering, all MEV (T-6), for the
   epoch; (b) **unbounded halt** — it simply never proposes. Every correct validator's round timer
   expires (CONS-07(4)) and it advances to `(H,1)`, whose proposer is *again v_0* (pos increments by 1,
   still < w_0). The chain cannot advance at all. Cost: one `S_min` bond plus one key.
4. Honest validators have no rule-legal escape: they cannot vote for a block that was never proposed,
   CONS-06 is a pure function of `(epoch,H,R)`, and no rule allows skipping a proposer or an epoch.

**Inside or outside the claimed fault model.** **Inside.** A single entry with the minimum bond; no
Byzantine stake beyond one sub-threshold validator; the halt is a failure of LIVE-01's (L2) condition
("a correct proposer is eventually selected by rotation when timeouts elapse"), which the design
asserts, not assumes away.

**Attacker resources and cost.** `S_min` TAIKO bonded (slashable but not confiscated for silence —
inactivity is not an offence, ECON-04/WH-02), plus CPU for key grinding. Damage: unbounded halt or full
ordering capture.

**Harm and requirement affected.** R6 (conditional liveness — its own stated condition fails), R1/R5
(leader selection must be stake-weighted; here the leader is stake-independent), D4's honest naming
("PoS-sequenced" with one proposer is single-sequencer), LIVE-01(L2), CONS-06/M6's fairness claim.
R11/no-non-receipt rule also blocks any deterrent against the silent variant.

**Evidence.** CONS-06 formula and MEM-02(2) unit quoted above; the arithmetic is exact integer
arithmetic in the committed integers. Note CONS-06 *anticipates* the need for a modest `W` but
delegates the unit to MEM-02/PARAM-01 and neither fixes one — so this is not a disclosed limitation, it
is a hole between two rules that each assume the other closed it.

---

## CS-03 — Critical — Q-A3: the blob binding's anti-grinding argument is not established as written; the challenge does not bind the versioned hashes, so the published blob can differ from the executed data with certainty

**Severity: Critical** — a permissionless prover can land an accepted batch whose Ethereum-published
blob is not the data the proof executed, breaking D5/R8 (data and proof in one transaction, data bound
to the proof) and the DA basis of the bridge surface. This is the answer to Q-A3: the on-chain caller
path is sound, the grinding resistance is not.

**Exact rule / missing rule.**
- `spec/04-l1-integration.html#DA-03` (iii): *"With `statementCoreHash` the hash of the public inputs
  of L1-05 rows 1–17 excluding rows 18–19 … z_i = uint256(keccak256(abi.encode("TAIKO_ETNA_CHALLENGE",
  chainId, statementCoreHash, uint16(i)))) % BLS_MODULUS."*
- `L1-05` row 18 repeats: challengeZ is *"Fiat–Shamir over statementCoreHash (rows 1–17 excluding the
  challenges) per DA-03(iii)"*. Rows 1–17 are: chainId, previousCheckpointHash, previousHeight,
  previousBlockHash, previousStateRoot, first/lastBlockHeight, first/lastBlockTimestamp, epoch,
  validatorSetRoot, validatorSetTotalPower, quorumThreshold, newBlockHash, newStateRoot,
  finalityCommitment, dataCommitment, daMode. **There is no versioned-hash field.**
- `spec/05-proof-statement.html#PRF-02`'s journal *does* contain
  `bytes32 blobHashesHash; // keccak256 of ordered versioned hashes (L1: from BLOBHASH)`, and
  `PRF-07`(b)(ii) says *"challengeZ = H(all other journal fields)"*.
- `DA-03`'s soundness paragraph asserts the missing link: *"`z_i` is a deterministic function of
  `statementCoreHash`, which contains `dataCommitment`, which **for the blob path contains the
  versioned hashes**"* — false under `DA-02`'s own formula.
- `DA-02`: `dataCommitment = keccak256(abi.encode("TAIKO_ETNA_DATA", chainId, firstBlockHeight,
  lastBlockHeight, daMode, payloadRoot))` with `payloadRoot = dataRoot = keccak256(_batchData)` and the
  inline comment *"1 = CALLDATA, 3 = CALLDATA_AND_BLOB"*. Only the **hybrid** payloadRoot in DA-03's
  closing paragraph includes `vh[0..n-1]`. **`daMode = 2` (BLOB) has no defined payloadRoot at all**,
  and nothing in DA-02 binds the versioned hashes.
- `L1-05` row 16 labels `dataCommitment` *tx-derived* and *"Computed by the contract from this
  transaction per DA-02 (calldata) and/or DA-03 (blobs)"* — impossible for blob data: the EVM cannot read
  blob contents. In the blob path this value can only be a proof-bound journal value supplied by the
  prover.

**Why the grinding argument needs the versioned hashes.** The 2^-243 bound is the statement "if
`p_data != p_blob`, their difference has degree <= 4095 and z is uniform and independent of both, so
equality at z has probability <= 4095/|F|". It requires z to be fixed *after* both polynomials are
fixed. If z depends on the blob commitment (via `blobHashesHash`), the prover must fix the blob before
z; adapting the executed data to a fixed z is then the 2^-243 problem. If z depends only on
`dataCommitment` = commitment to the *executed* data D, the prover fixes D first, learns z, and then
**chooses the published blob to match z** — no probability argument applies.

**Concrete attack trace.**
1. Prover selects real L2 data D (valid blocks, valid state transition) and computes
   `dataCommitment = keccak256(abi.encode("TAIKO_ETNA_DATA", chainId, first, last, 2, keccak256(D)))`.
2. It computes z for blob index i exactly as DA-03(iii)/L1-05 row 18 define it — a function of
   `statementCoreHash` (rows 1–17, no versioned hashes) — before it chooses the blob.
3. It chooses any polynomial `p'` of degree <= 4095 with `p'(z) = p_D(z)`: fix 4095 coefficients
   arbitrarily and solve the constant term
   `c_0 = p_D(z) - sum_{j>=1} c_j z^j mod r`. Success probability **1**.
4. It builds and publishes the blob for `p'`, and submits (data+proof) in one L1 transaction with
   `y = p_D(z)`. Checks that pass: `BLOBHASH(i) == vh(p')` (DA-03(i)); the point-evaluation precompile
   verifies `p'(z) = y` and `kzg_to_versioned_hash(commit(p')) == vh` (DA-03(ii)); the guest proves
   `p_D(z) = y` and `keccak256(D) == dataCommitment` (DA-03(iv), PRF-07(b)(v)).
5. The batch is accepted and its L2 state root is valid, but the blob on Ethereum describes unrelated
   bytes. Anyone reconstructing state/bridge messages from the published DA object gets a different
   chain from the one the proof proves; the protocol's answer to "where is the data?" is a lie.

**Precision note (overlap with the proof/bridge reviewer's file).** The attack is the *literal*
composition of DA-03(iii) + L1-05 row 18 + DA-02's `payloadRoot = keccak(_batchData)` for the
blob path. If an implementer instead defines the pure-blob `dataCommitment` to include
`vh[0..n-1]` (as the hybrid path does and as DA-03's prose silently assumes), then z binds the blob
commitment too and the 2^-243 argument applies — the finding is that the normative text does not say
this, DA-03's soundness paragraph asserts it without a rule, and DA-02's formula contradicts it. A
reviewer attacking the same construction from the encoding side reaches the same conclusion
(`round1-proof-bridge-custody.md` R1-01/R1-05/R1-06); the judge should merge the redundancy.

**What still holds (so the fix is narrow).** The on-chain challenge derivation resists a *malicious
caller*: z is recomputed by the contract, is not a submitter field (L1-05 rows 18–19; DA-03(iii) "MUST
NOT be supplied by the submitter"), the index is in the domain so blobs do not share a challenge,
BLOBHASH is transaction-scoped so no other transaction's blob can be substituted, and the precompile
pins the commitment to the versioned hash. The problem is solely the *set of fields* the challenge
binds. Including the ordered versioned hashes in `statementCoreHash` (and defining `daMode=2`'s
payloadRoot in DA-02) restores the argument.

**Inside or outside the claimed fault model.** **Inside.** One permissionless prover transaction; no
stake, no assumption failure. (A-CRYPTO-1/A-CRYPTO-3 are not the issue: KZG binding and the ROM are
intact; the FS statement is simply under-specified and one of its two normative definitions is
unsound.)

**Attacker resources and cost.** One L1 transaction carrying one blob (<=131 KB) plus proof gas; the
proof itself is honest computation. Cost is the batch's ordinary settlement cost.

**Harm and requirement affected.** D5 (data and proof in the same transaction — the data that lands is
not the data proven), R8 (data bound to the accepted proof), R9, and every downstream consumer of
"the canonical data is the accepting transaction" (DA-01, DA-04, MSG-01).

**Evidence.** The two definitions are quoted verbatim; L1-05 rows 1–17 are listed above and contain no
versioned-hash row; PRF-02's journal shows the field that exists in the encoding but not in the
challenge definition; DA-02's formula shows the versioned hashes enter only the hybrid payloadRoot.
The counterexample computation in step 3 is exact modular arithmetic.

---

## CS-04 — High — CONS-10 and MEM-08 define two different `set_root(e)` objects; the mandated L1 comparison has no single value

**Severity: High** — the object every safety premise is written against ("the L1-committed set root")
is defined twice, incompatibly; an implementer must invent which one is real, and the tempting
resolution (skip the L1 comparison, trust the witness) is precisely the set-substitution hole
CONS-12 premise (c) exists to close.

**Exact rules.**
- `CONS-10`(2): `set_bytes(e) = abi.encode("TAIKO_ETNA_SET_V1", chain_id, e, n, [(validator_index:u32,
  consensus_pubkey:bytes32, voting_power:u64, l1_account:address)])` and `set_root(e) =
  keccak256(set_bytes(e))`.
- `CONS-10`(4): *"take the epoch-e set as a witness, recompute `keccak256(set_bytes(e))`, and require
  equality with (i) the head's `validators_hash` and (ii) the epoch's L1-committed root exposed as a
  public input."*
- `MEM-08` (table): `leaf_i = keccak256(abi.encode(DOMAIN_SET_LEAF, chainId, k, index, pubkey,
  effStake))`; `node = keccak256(abi.encode(DOMAIN_SET_NODE, chainId, k, left, right))`;
  `R_k` = promoted-odd-node **Merkle root**, with `n = 1` giving the single leaf.
- `MEM-08`(4): *"`R_k` commits to the chain id, the set version k, and the ordered list of
  (pubkey, effStake) pairs — and nothing else. In particular it does not commit to … the validators'
  owner addresses."*

These cannot both be true: a single flat `keccak256` over a 4-field list that includes `l1_account`
is not a Merkle root over 2-field leaves. `PRF-03`(a) requires *"Merkle inclusion and ordering proofs
against `validatorSetRoot`"* (MEM-08's construction) and `CONS-05` points at MEM-08, so the flat-hash
reading breaks PRF-03/PRF-04; the Merkle reading breaks CONS-10(4)'s equality check, and a header
`validators_hash` computed with the flat hash will never equal the stored `R_k`.

**Attack / failure trace.**
1. Implementation X follows CONS-10(4): it computes `keccak256(set_bytes)` in the guest and compares it
   with the header and with L1's stored root. If L1 stored MEM-08's Merkle root, every certificate fails
   the comparison — the batch is unprovable — so the practical fix is to drop check (ii).
2. Dropping check (ii) means the set root used to verify signatures is witness-supplied; a prover
   supplies a set it controls, signs with its own keys, and the guest "authenticates" it against the
   witness root (exactly the failure mode `CONS-10`'s own "Failure mode" paragraph names).
3. The alternative (L1 stores the flat hash) makes MEM-08(5)'s `TotalVP_k` recomputation and PRF-03's
   inclusion proofs unimplementable.

**Inside or outside the claimed fault model.** The divergence is a specification defect; the attack in
step 2 is inside the fault model (permissionless prover) and is the classic set-substitution attack
CONS-12(c)/A-CONS-4 forbid.

**Attacker resources and cost.** Zero if an implementer takes the shortcut; otherwise this is
unimplementable rather than exploitable.

**Harm and requirement affected.** R5/R13; CONS-12 premise (c); A-CONS-4; INV-01.

**Evidence.** Verbatim encodings above; the field lists and hash domains are plainly different
(4-tuples with an address vs 2-tuples without).

---

## CS-05 — High — PRF-05's per-epoch set check has no public input; the only encodings leave it to the witness (set substitution) or drop it

**Severity: High** — for any batch crossing an epoch boundary, the rule that must authenticate the
transition's validator set cannot be implemented from the normative journal; the safe reading requires
a new public input (a normative change to two rules), the unsafe reading takes the set from the witness
and re-opens set substitution.

**Exact rule / missing rule.**
- `PRF-05`: *"For every epoch boundary inside the batch the guest checks that: … (iii) each epoch's set
  commitment equals the value the L1 staking contract fixes for that epoch, **supplied as a public input
  rather than as a witness**; (iv) epoch numbers are strictly increasing across the batch."*
- `PRF-02`: *"The guest commits to **exactly** the following journal … `uint64 epoch; bytes32
  validatorSetRoot; uint256 totalVotingPower; uint256 quorumThreshold; …`"* — one quadruple.
- `L1-05` rows 9–12: one `epoch`, one `validatorSetRoot`, one `validatorSetTotalPower`, one
  `quorumThreshold`, all L1-derived.
- `PRF-03`: *"No witness element may define the authoritative validator set."* `PRF-13`: a binding that
  consists only of "the caller passed it" is not a binding.
- **Missing rule:** no per-epoch list in the journal or in L1-05's binding list, and no bound on how
  many boundaries a `MAX_BATCH_BLOCKS` batch can cross (`CONS-13`(1): L = 900, PARAM-02: 300; a batch may
  span any number of them).

**Failure trace.** A batch starting in epoch e and ending in e+1 (or later) must have the guest verify
the set of every epoch it crosses. Under PRF-02/L1-05 the guest has exactly one root, so:
(a) an implementer adds the extra roots to the witness — the guest then verifies a Merkle path to a
root the prover chose, violating PRF-03/PRF-13 and enabling the prover to judge the transition under a
set that never signed it; or (b) the implementer drops PRF-05(iii) for the non-head epochs — the
prover chooses the transition's set; or (c) the implementer stays conformant and multi-epoch batches
are simply unprovable — the batch can never be landed, i.e. finalized history cannot settle.

**Inside or outside the claimed fault model.** The exploit variants are inside (permissionless prover,
T-3-class set substitution); variant (c) is a liveness defect.

**Attacker resources and cost.** One prover.

**Harm and requirement affected.** R5, R8, R13; CONS-08 (a certificate must be judged under its own
epoch's set); CONS-12 premise (c). Note the liveness reviewer independently flagged the same
missing-encoding defect and passed it here.

**Evidence.** PRF-02's "exactly the following journal" and L1-05's closed list, quoted; PRF-05's
"supplied as a public input" requirement has no corresponding field.

---

## CS-06 — High — The epoch length has two normative values: CONS-13 says L = 900, PARAM-02 says EPOCH_LEN_L2 = 300

**Severity: High** — `epoch_of(H)` determines which set judges every vote and certificate, the anchor
heights, and the leader rotation; two conforming implementations with different `L` disagree about all
of them.

**Exact rules.**
- `CONS-13`(1): *"Proposed value `L = 900 heights` … at the D1 cadence of one block per 2 s an epoch is
  30 minutes of L2 history"*; (2) `epoch_of(H) = floor((H - H_0)/L)`, `h_first(e) = H_0 + e*L`,
  `h_last(e) = H_0 + (e+1)*L - 1`.
- `PARAM-02` table (parameter register mandated by `PARAM-01`): *"`EPOCH_LEN_L2` | L2 blocks | **300
  (≈ 10 min) — placeholder** | Chosen so that an epoch contains many consensus rounds … | unmeasured"*.
- The register has no parameter named `L`; `CONS-13`'s 900 never appears in it, and `EPOCH_LEN_L1` is a
  third, formula-only quantity.

**Failure trace.** Implementation A uses `L=900`, implementation B uses `L=300`. At height `H_0+400`,
A says epoch 0 and judges certificates under `set_root(0)`; B says epoch 1 and judges them under
`set_root(1)`; `CONS-08`(1) makes each reject the other's votes as "invalid regardless of their
signatures"; `CONS-06` gives each a different proposer at the same `(H,R)`; `CONS-09`'s anchor heights
differ. Two rule sets, guaranteed by the specification itself (F3-class divergence that the spec must
not make possible under R13/GEN-03).

**Inside or outside the claimed fault model.** Not an attack on an adversary; a specification defect
that produces divergent implementations (fault class F3). It becomes a safety issue the moment the two
clients run on one network.

**Attacker resources and cost.** None.

**Harm and requirement affected.** R5, R13, GEN-03 ("one rule, one place"); every consensus rule keyed
to `epoch_of`.

**Evidence.** Both values quoted verbatim from the two pages.

---

## CS-07 — High — The cross-round fork-accountability claim is not established by the evidence catalogue; a conflict at one height in two rounds can leave nothing slashable

**Severity: High** — the specification repeatedly promises ">=1/3 objectively slashable" from a fork.
Its own evidence rule accepts only *same-(height, round)* pairs, and the cited lemma is explicitly
conditional on the JSets being compilable — which the reveal-later adversary never publishes. The
safety invariant is unaffected (it needs only >=1/3 *faulty*), but R11's objective-evidence guarantee
and the deterrence claim are not established.

**Exact rules.**
- `CONS-11`: *"Validator v equivocates at (H,R) if it produces two signed messages m1 != m2 with
  type(m1) = type(m2) in {PROPOSAL, PREVOTE, PRECOMMIT}; identical chain_id, height = H, round = R …"*
- `ECON-04` lock-rule row: *"the only admissible evidence is a same-(H,R) conflicting signed pair …
  The fork-accountability lemma supplies the teeth: a safety-relevant divergence implies >=1/3
  double-signers, whose double-signatures are themselves CONS-11 evidence."*
- `ROLE-01`(e): *"A lock-rule violation is penalised only in the form in which it is objectively
  provable — a conflicting signed pair at the same (height, round) … the fork-accountability argument
  supplies the teeth, since a safety-relevant divergence implies at least one third double-signing."*
- `CONS-09`(4)(a) and `CONS-12`: two quorums at one height imply the intersection exceeds W/3 and
  *"at least one third of epoch e's power is objectively slashable (CONS-11)"*.
- The cited source (quoted in `research/recovery-and-withholding-raw.md` line 115) reads: *"When a fork
  is detected by the existence of two conflicting commits, the union of the JSets for both commits
  **(if they can be compiled)** must include double-signing by at least 1/3+ of the validator set."*

**Counterexample (worked).** Let C1 finalize B1 at (H, R1) and C2 finalize B2 != B1 at (H, R2) with
R1 < R2. Each signer set exceeds 2W/3, so the intersection exceeds W/3 in power. A validator v in the
intersection precommitted B1 at R1 and B2 at R2. Under CONS-04(2) it may legally unlock if it holds a
PoLC for B2 at a round p with R1 < p < R2; CONS-04(4) requires exactly such a PoLC before precommitting
B2 at R2. Therefore v may be fully compliant. The two certificates alone prove only that >W/3 of the
power signed conflicting precommits at one height **at different rounds** — and CONS-11's predicate
requires the same round, while ECON-04's lock row says a lock violation leaving no same-(H,R) pair
"MUST NOT be slashed". The published lemma's conclusion is reached by compiling the intervening
PoLC/vote evidence; a withholding adversary (T-4) that reveals only the two certificates never
publishes those intermediate messages, so the union of JSets cannot be compiled and no evidence object
exists. The exact scenario the mandatory schedule (WH-04) worries about — a certificate revealed after
an alternative path progressed — is precisely the cross-round case.

**Inside or outside the claimed fault model.** Inside: the adversary is the withholding proposer/quorum
of the mandatory schedule, plus T-4. The safety argument does not depend on slashing, so this is a
deterrence/accountability gap, not a safety break.

**Attacker resources and cost.** An attacker that can create the fork already has >=1/3 Byzantine
stake; the incremental point is that it can avoid confiscation of the intersection's stake by
withholding the intermediate rounds' messages.

**Harm and requirement affected.** R11 (objective misconduct evidence), CONS-09(4)(a), CONS-12,
ROLE-01(e), WH-04's "required conclusion", SPEC's own failure-mode text ("nothing is slashable").

**Evidence.** Quotes above; the intersection computation is CONS-12's own (s1+s2-W > W/3). The
parenthetical "(if they can be compiled)" is the published lemma's own condition, not an invention of
this review. The fix is either to define a new evidence object ("two valid commit certificates for one
height + the PoLC chain") or to weaken the claim to ">=1/3 faulty, only same-round faults provable".

---

## CS-08 — High — The epoch boundary commitments CONS-09 and MEM-09 require are not defined in any header encoding

**Severity: High** — the entire cross-epoch safety argument (F1) rests on two header commitments that
no rule encodes; CONS-09(5)(i) itself says *"a shortcut here removes the entire safety argument"*.

**Exact rule / missing rule.**
- `CONS-09`(1): *"The first block of epoch e+1 MUST carry in its header `epoch_anchor = (h_last(e),
  hash(B_anchor), cert_hash(e))`"* — but `CONS-10`(1) defines exactly two header commitments,
  `validators_hash` and `next_validators_hash`, and `GEN-05` requires *one canonical `abi.encode`* per
  protocol hash. `cert_hash(e)` is never given an encoding either (a commit certificate is defined in
  CONS-05 as an aggregate of signatures, not as a canonical hashable object).
- `MEM-09`(2): the first block commits `(setVersion(e), N(setVersion(e)))`; *"The header field carrying
  this tuple is CONS-10's"* — `CONS-10` has no such field.
- `PRF-05`(ii): the first block commits to the last finalized previous-epoch block *"in its consensus
  evidence"*, again without a field or encoding.

**Failure trace.** An implementer must invent the field, its type, its position in the header, and the
canonical encoding of `cert_hash`. Two implementers will choose differently (e.g. include or exclude
`round`, the bitmap, or the set root in the certificate hash); a new joiner or guest verifying the
boundary then either rejects valid blocks or accepts an anchor whose commitment it cannot check.
CONS-09's own failure-mode text describes the consequence: *"an implementation that lets epoch e+1's set
sign blocks without checking the epoch-e anchor creates a fresh-quorum fork at the boundary in which no
validator of the old set misbehaved; nothing is slashable."*

**Inside or outside the claimed fault model.** The gap is a specification defect (R13); a shortcut
implementation exposing the fresh-quorum fork is inside the fault model (T-3 + a new set).

**Attacker resources and cost.** None for the shortcut; the harm is a boundary fork with no slashable
party.

**Harm and requirement affected.** R13, R5; CONS-09's modified-safety status (F1); GEN-05.

**Evidence.** CONS-10(1)/(2) enumerate the header's commitments and do not contain `epoch_anchor` or
the set-version tuple; CONS-09(1) and MEM-09(2) assert that they do. The two rules name each other's
missing field.

---

## CS-09 — High — The quorum predicate is off by one between the L2 client (CONS-03), the L1 contract (L1-05 row 12) and the guest (PRF-04(iii))

**Severity: High** — CONS-03 explicitly calls a strict/non-strict divergence between client, guest and
Inbox "a defect, because a certificate accepted by the chain would be rejected on L1 or the reverse";
the rules as written contain exactly that defect.

**Exact rules.**
- `CONS-03`: `quorum(Q) <=> checked_mul(3, power(Q)) > checked_mul(2, W)` — admits power = q* where
  `q*` is the minimal integer with `3q > 2W` (i.e. `q* = floor(2W/3)+1`).
- `L1-05` row 12: *"quorumThreshold … `floor(2 * validatorSetTotalPower / 3) + 1`, computed by the
  contract"* — that is `q*`.
- `PRF-04`(iii): *"the sum of the effective stake of the signers … is **strictly greater than**
  quorumThreshold, where the threshold is the minimal integer q with 3q > 2 * totalVotingPower"* — that
  requires `power >= q* + 1`.

**Worked counterexample.** `W = 100`, so `q* = 67`. A certificate with signer power 67 satisfies
CONS-03 (`3*67 = 201 > 200`) and is finalized at L2 with STATUS-04. The guest requires
`power > 67`, i.e. `>= 68`, and rejects it. The batch can never be proven: a legitimately
PoS-finalized block is unprovable, and Mode A forbids discarding it (REC-01/L1-04). The same off-by-one
exists for every W with an exact-threshold quorum.

**Why it matters despite base-unit weights.** With weights in 1e18-scale base units an exact-threshold
sum is rare; the defect becomes routinely reachable the moment CS-02 is fixed by quantizing weights
(which is the only fix for that Critical finding). The two must be fixed together or the fix for one
creates the other.

**Inside or outside the claimed fault model.** Specification defect; its consequence (unprovable
finalized history) needs no adversary.

**Attacker resources and cost.** None.

**Harm and requirement affected.** R9/D5/D6 (settlement of finalized history), CONS-03's own
consistency requirement, R13.

**Evidence.** The three formulae and the arithmetic above.

---

## CS-10 — Medium — The parameters that are supposed to bound the Mode A availability exposure are missing from the register, and two different caps are named for the same job

**Severity: Medium** (reviewability/secondary guarantee; the liveness reviewer's R1-03/R1-05 establish
that the cap is also unenforceable/unobservable, which I do not duplicate).

- `DA-05`: *"The design therefore MUST specify, in 09: (a) a RETRIEVABILITY_WINDOW in L1 block numbers,
  not shorter than the blob-retention window; (b) an ARCHIVE_REQUIREMENT fixing how many independent
  archive nodes must retain …"* — `PARAM-01`/`PARAM-02`'s table contains neither.
- `DA-06` defines the vote rule in terms of `unsettledAge` in **L1 blocks** and the inequality
  `RETRIEVABILITY_WINDOW >= MAX_UNSETTLED_AGE + SETTLEMENT_PIPELINE + EVIDENCE_WINDOW`; none of those
  four names appears in `PARAM-01`'s table, and `HALT-03` instead defines `D_MAX` in **L2 blocks**
  (`PARAM-02`: formula in seconds/L2_BLOCK_INTERVAL, placeholder 3,600 blocks). The two caps are not
  reconciled, and `HALT-03` says `D_MAX` is "derived from the data-retention window and the L2 block
  rate" — which is not a derivation when the L2 block rate is itself a target (D1) rather than a bound.
- Consequence: whether the Mode A availability counterexample is excluded is a claim about
  unstated/unfixed parameters (see Q-A1).

**Inside/outside.** N/A (specification completeness). **Harm:** R13, R6; supports Q-A1's caveat.

---

## CS-11 — Low — CONS-11's evidence predicate does not require the two objects to agree on the `epoch` field it relies on

`CONS-11` says the checker verifies that the objects *"agree on (chain_id, H, R, type,
validator_index)"*, and `CONS-02` separately invalidates a vote whose `epoch` field disagrees with
`epoch_of(H)`. The evidence object is then checked against `set_root(e)` for `e = epoch_of(H)`
(ECON-04). The omission is harmless in effect — an object with a wrong epoch field is invalid as a
vote either way — but the *evidence* rule, which is what a slashing contract implements, should state
that both signed objects are valid votes of the epoch `epoch_of(H)` (or explicitly admit wrong-epoch
objects as evidence). Clarity/citation defect only; no safety impact.

---

# Required explicit answers

## Q-A1 — Is the Mode A availability counterexample reachable inside the stated liveness assumptions, or is it a failure of them? Does the Mode A selection survive D2 step 1?

**It is a failure OF the stated liveness assumptions, and the selection survives D2 step 1 — subject to
one parameter caveat that is currently unverifiable.** The counterexample needs a finalized block whose
data no correct participant can serve. A-CONS-5 is a liveness assumption that says correct validators
*"hold and can serve the block data they voted for, for at least the retention window"*, and A-DA-2
says at least one adequately-resourced prover completes each committed batch's proof within the
envelope. Since quorum is strictly >2/3 and Byzantine stake is <1/3 (A-CONS-1), every quorum contains
correct signers, so the "holders vanish" precondition requires A-CONS-5 to fail (or A-DA-2 / A-L1-1, or
the retention window to elapse before settlement). The assumption table itself names this consequence
("finalized-but-unavailable data; safe halt"), the specification discloses it (LIM-01; the
"Unavailable data for a finalized block" walk-through in 06), and D2 step 1 says a safe halt outside
the stated liveness assumptions is permitted and is not evidence of infeasibility. The lead's D-3
reasoning is therefore correct *as a matter of classification*. The caveat: the mechanism that is
supposed to keep the failure outside the assumptions — HALT-03/DA-06's cap, whose inequality
`RETRIEVABILITY_WINDOW >= MAX_UNSETTLED_AGE + SETTLEMENT_PIPELINE + EVIDENCE_WINDOW` is what makes
"the data is still retrievable when the prover needs it" true — is parameterized by quantities that do
not appear in the parameter register (CS-10) and, per the liveness reviewer's R1-03/R1-05, are
otherwise unobservable/unenforceable. So the honest verdict is: **the counterexample is outside the
stated assumptions by construction, and Mode A is not refuted; but the design cannot currently show
that its own cap keeps it outside, because the bounds are unstated.** That is a defect in the bound,
not in the Mode A selection.

## Q-A2 — Is the "one commit certificate per batch" argument (PRF-08) sound for the whole prefix, including across epoch boundaries?

**Within one epoch, yes, given the named premises.** A head certificate over >2/3 of the epoch's set
implies, via CONS-02/CONS-04 and CONS-01(iii)'s parent-validity rule, that the ancestors are the unique
finalized chain; the header chain in the batch is hash-fixed by the head, so verifying the head's
certificate plus the parent linkage does extend finality to every block of the batch. **Across an epoch
boundary it is not established by the rules as written**, for two independent reasons. (1) The
cross-epoch component is CONS-09, which the specification itself marks ASSUMED-WITH-ARGUMENT/Open
(F1) — so PRF-08's extension inherits that status rather than being "the same reasoning a light client
uses". I reviewed CONS-09's case analysis and it is structurally sound *conditional on* every correct
validator in e+1 verifying the epoch-e anchor certificate (its case (b) correctly reduces a
non-descendant first block to two epoch-e certificates, i.e. case (a)), but the duty is an off-chain
validator obligation that the proof does not check and that CONS-09(5)(i)–(iv) lists as unproven. (2)
Independently of F1, PRF-05(iii) requires per-epoch set authentication that the journal cannot express
(CS-05), and the anchor/set-version commitments it needs have no canonical encoding (CS-08). And the
whole argument rests on the epoch→set mapping being deterministic, which CS-01 shows it is not. So:
sound in-epoch; cross-epoch "sound only if CONS-09 is assumed and the missing encodings are invented
correctly".

## Q-A3 — Does the blob binding (DA-03) resist a grinding prover and a malicious caller?

**The malicious-caller half resists; the grinding half does not, as written.** The caller cannot choose
the challenge (the contract derives z itself, L1-05 rows 18–19 forbid a submitter-supplied value), the
index is inside the Fiat–Shamir domain so blobs do not share a point, BLOBHASH is transaction-scoped so
no other transaction's blob can be substituted, and the EIP-4844 precompile pins
`kzg_to_versioned_hash(commitment) == vh` and verifies the opening. But the anti-grinding argument
requires z to be fixed after *both* the executed data and the published blob are fixed. The two
normative definitions of the challenge disagree about the bound field set: DA-03(iii) and L1-05 row 18
bind only L1-05 rows 1–17, which contain no versioned-hash field, while PRF-02's journal and PRF-07(b)
bind `blobHashesHash` ("all other journal fields"). Under the DA-03/L1-05 reading (which is also the
reading the contract is told to implement), z is independent of the blob, so a prover fixes the
executed data D, learns z, and solves for one coefficient of a degree-4095 polynomial `p'` with
`p'(z) = p_D(z)` — success probability 1, not 2^-243 — then publishes `p'` as the DA blob. The batch
lands with a valid state transition and a published blob that is not the data the proof executed:
D5/R8 broken. Fix: put the ordered versioned hashes into `statementCoreHash` (or define `daMode=2`'s
`payloadRoot` in DA-02 to contain them) and delete the claim that DA-02's blob-path `dataCommitment`
already contains them.

---

# Checked and found sound (no finding)

- **Unpublished certificate cannot invalidate a decision.** CONS-05's local commit is a function of the
  certificate, the node's own DA check and its own finalized prefix; it explicitly forbids "commit only
  if no conflicting certificate exists" and "commit after T"; a node holding a conflicting lock or a
  conflicting finalized block halts rather than adopts. CONS-04's lock plus the >1/3 honest-locked
  argument is the published CometBFT Proof of Safety and is used correctly (quoting is faithful to the
  pinned source). Within a fixed set and a fixed epoch this part is sound.
- **Lock carry-over at the epoch boundary, same-height case.** A conflicting vote at the same height H
  is necessarily in the same epoch (`epoch_of` is a function of height), so the conflicting pair is
  always signed under the same key/set and therefore meets CONS-11's same-(H,R) predicate; key rotation
  (MEM-07(3)) and stake changes (MEM-09(4)) cannot change the set that judges an already-committed
  height. WH-04's "rotate a key or change stake to escape a lock" is answered for same-height conflicts.
  (What is *not* answered is the cross-round accounting claim — CS-07.)
- **No vote-twice escape via rotation/stake/epoch.** CONS-02's durable per-(`chain_id,H,type`) store,
  MEM-07(4) judging a vote against `pk(v,setVersion(e))`, MEM-07(6)'s one-shot keys and MEM-08(2)'s
  unique-key ordering jointly prevent a key or index from being reused to vote twice within an epoch.
- **MEM-12's long-range handling and MEM-11's freshness bound** correctly state the trust requirement
  and refuse a silent checkpoint provider; nothing in my angle contradicts them.
- **Sub-threshold coalition halt.** The obvious route (a >=1/3 cartel refusing to vote) is disclosed
  (LIM-01, CONS-04's "cannot make progress is the honest outcome"). The *undisclosed* route is CS-02:
  one minimum-bond validator is sufficient, which is why CS-02 is a finding and the >=1/3 route is not.

---

# Verdict for the parent

Three Critical findings, all inside the fault model: **CS-01** (the proposer picks the epoch's set
version; the epoch→set rule is view-dependent and contradicts MEM-09(3)/CONS-13(5); two nodes can
judge one epoch under two L1-committed roots), **CS-02** (base-unit weights make the lowest-hash
validator the proposer of every slot; one `S_min` bond halts the chain or captures ordering), and
**CS-03** (Q-A3: the blob challenge does not bind the versioned hashes under DA-03(iii)/L1-05, so a
prover can publish a blob different from the executed data with certainty — D5/R8). The single
strongest attack is CS-02 because it needs no adversary at all beyond the rules themselves and is
checkable by inspection: with `w_i` in TAIKO base units, `pos(H,R) < w_0` for the whole epoch, so the
chain has exactly one proposer.
