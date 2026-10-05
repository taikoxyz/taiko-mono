# Iteration 02 — round 2 raw report (angle E)

**Reviewer angle:** compliance with the fixed decisions D1–D7, plus an economics spot-check.
**Frozen snapshot:** `5e4129913e2540ac42c5c8b5034b64cdc3a5c8f1` (round-2 snapshot; round-1 fixes are in place and their italic "(review round 1, finding X)" notes are treated as claims, not evidence).
**Material read:** `README.md`, `DECISIONS.md`, `01-requirements-and-threat-model.md`, `04-architecture-decision.md`, `spec/index.html` and `spec/01`–`spec/10`, plus the baseline sources in `packages/protocol/contracts` at the same revision.
**Method:** rule-by-rule reading against D1–D7 and R1–R14; every load-bearing citation was re-checked in the sources (layout files, `SignalService.sol`, `Inbox.sol`), not accepted from the prose. This report deliberately does not re-list round-1 findings.

---

## Verdicts on the assigned questions

**(a) D5 — no path that advances a checkpoint without data and a valid proof in the same L1 transaction.**
**Refuted.** Two specified paths do exactly that: (i) the legacy `prove()` path, which stays callable in migration states `SHASTA_ACTIVE`/`FROZEN`/`DRAINED` and advances the preserved L1 SignalService checkpoint from a proposal whose data was published in an earlier `propose()` transaction; and (ii) `activateEtna(B*, S*)` (T3), which adopts the checkpoint that path produced as the new chain's genesis. Neither is declared as an exception, and `INV-02` asserts there is none (E-R2-01). REC-02 (Mode B) is clean on D5 as far as it is specified — its invocation transaction "does not accept any batch" and its new checkpoint is the existing L1 checkpoint — and FI-01–FI-05 create no batch record (`L1-02` is explicit that the design contains no announce/intent/commit function).

**(b) D3 — preserved addresses, MIG-02 sufficiency, MSG-01 field split.**
Addresses: yes — MIG-06 lists every D3 surface (L1/L2 SignalService, Bridge, ERC20/721/1155 vault) plus the Inbox and Anchor as in-place proxy upgrades, and the immutables are properties of the implementation, not the proxy. MSG-01's field split: yes — the frozen `CheckpointRecord` is `{blockHash, stateRoot}` keyed by `blockNumber` in `_checkpoints[VERSION]` (`SignalService.sol:24-29, 174-184`; `SignalService_Layout.sol:254`), and MSG-01 adds nothing to it; the extra fields go to the Inbox. **But MIG-02 is not sufficient**: its self-declared "complete change list" budgets 6 Inbox slots and omits the state that L1-07, L1-11, FI-01/FI-05 and L1-09 require, and T3 does not write a legal L1-07 genesis record (E-R2-03).

**(c) D7 — TAIKO-only staking and collateral.**
Holds. MEM-01/ECON-01(1) accept only the existing TAIKO ERC-20; no ETH is collateral; ECON-01(2) rejects `balanceOf`/`getVotes`; the legacy gwei bond ledger is not converted, not counting as stake, and explicitly not slashable (MIG-03(3)). ETH-denominated validator rewards are conforming: D7 fixes the *staking* asset, not the reward asset. The amended reward design is **not** internally consistent: it promises a participation-conditioned validator payout that no rule implements (E-R2-05), its "single-currency ETH" identity also pays TAIKO reporter bounties and double-counts subsidy payouts (E-R2-10), and its slashed-stake destination menu contains an option that contradicts its own bounty bound (E-R2-06). No surviving *silent* token-appreciation assumption was found: ECON-02(2) bans it, ECON-12 makes `ρ_capital` price-dependent explicitly, and A-ECO-1 is stated as an assumption — this part is honest.

**(d) Economics spot-check.** Minimum stake: dimensionally closed and explicitly unmeasured (ECON-09(1),(4)); no price term. Evidence windows: anchored to the offence epoch's own set root and covering the whole pipeline (ECON-07(1),(4)) — correct in structure, but the anchor value `t_root(e)` is not storable/derivable from L1 (E-R2-07). Reporter bounty strictly below the penalty: the *bound* is right, the *menu* contradicts it (E-R2-06). Churn limit: exists but is contradicted by the rule that owns exit effectiveness (E-R2-08). Participation-conditioned rewards: promised, unimplementable (E-R2-05). Activation fairness: disclosed honestly ("FIFO is not a proof of fairness under adversarial L1 ordering", MEM-03(2)(a)) and rate-limited; no finding.

**(e) R2 — no ordinary operation requires DAO intervention.** Confirmed for the DAO. After `ETNA_ACTIVE` no rule reads DAO-changeable runtime state (GOV-01), the T1–T3 transitions are one-time upgrades, `commitSet()` and `slash()` and `applyCorrelated()` are permissionless, and the route-retirement bar is an upgrade action (allowed by "DAO governs upgrades only"). The *non-DAO* residual privilege is different: SYS-02(g)/SYS-04(c) admit that the reserved L2 checkpoint writer (golden-touch) is a discretion surface and that "R1/R2 ... are not yet satisfied" by that lever; it is disclosed and marked Open (MIG-04), so it is recorded here rather than counted as a new finding.

---

## Findings

### E-R2-01 — D5 is broken by the migration path: legacy `prove()` advances a checkpoint from data published in a different L1 transaction, and T3 adopts it as genesis

**Severity:** Critical — a fixed decision (D5) and R9/`INV-02` are false as written, by construction, not by an assumption failure.

**Exact rule(s):** `spec/08-migration-upgrades.html` T1 ("`prove()` is unchanged"), T2 ("`prove()` reverts `MigrationDrained()` permanently (unless T2b)"), MIG-03(1) ("`prove()` reverts unless `migrationState` is `SHASTA_ACTIVE`, `FROZEN` or `DRAINED`"), T3 ("(B*, S*, H*) is written to Inbox slots 259–260"), MIG-01 ("B* the L2 block number of the last checkpoint written into the preserved L1 SignalService by a successful `Inbox.prove()`"); against `spec/index.html` D5, `spec/04-l1-integration.html` L1-01/L1-02/L1-03, `spec/06-recovery-exceptions.html` REC-01(e)/HALT-04, and `spec/10-assurance.html` INV-02.

**Preconditions:** the migration bundle T1 has executed (`migrationState = FROZEN`), or T2 has executed (`DRAINED`); at least one Shasta proposal exists that was proposed before the freeze (`_coreState.nextProposalId > 0`, a T1 guard) and is still provable. T3 then requires only the stored checkpoint equality.

**Counterexample (state trace, no attacker needed):**
1. Before the freeze, account A calls `propose(lookahead, data)` — the batch data (blobs) is published and `_proposalHashes[ring]` records a commitment; no proof is required and none is verified (`Inbox.sol:270-290`).
2. T1 freezes `propose()` but explicitly leaves `prove()` callable.
3. Any account calls the legacy `prove(_data, _proof)` (`Inbox.sol:321-400`). `_data` here is the encoded `ProveInput` commitment — it carries **no batch payload** — and the function writes the L1 SignalService checkpoint from claimed values (`Inbox.sol:364-370`) in a transaction that contains the proof but not the batch data.
4. T3 `activateEtna(B*, S*)` succeeds because the equality `signalService.getCheckpoint(B*).blockHash == _coreState.lastFinalizedBlockHash` holds. The new chain's genesis checkpoint is therefore a checkpoint produced by a data-first path whose data lives in an earlier transaction.
5. Alternatively: the whole Shasta chain can keep draining via `prove()` in `FROZEN`/`DRAINED` for up to `DRAIN_DEADLINE` = 21,600 L1 blocks (`spec/08` §"Numbers on this page"), each accepted checkpoint advancing from data-first proposals. `MIG-03(2)` concedes the only limit is "data availability (A-DA-2, A-DA-3)" — i.e. the June-2026 blob-expiry class the project set out to delete can still strand a pending proposal during the window (it is voided, so no checkpoint, but the D5 breach is in the accepted ones).

**Inside/outside the fault model:** inside — it is the specified normal behaviour of the migration, and needs no assumption to fail. (The authors may have intended "the Shasta rule set is a different protocol, not a mode of this design"; that carve-out is nowhere stated, and GEN-02 makes a design element that conflicts with a fixed decision "a defect, not a tradeoff". `INV-02`'s "No recovery, outage, degraded mode, **governance action** or operator procedure may create an exception" makes the contradiction explicit.)

**Attacker resources and cost:** none — this is not an attack; the only requirement is that the legacy path exists when the bundle runs.

**Harm; requirement / decision:** D5 and R9 (atomicity) are not satisfied as claimed by README/index/INV-02; the new chain's genesis is permanently anchored to a batch whose data and proof were not in the same L1 transaction, which is the exact provenance gap D5 exists to remove; if such a proposal's blobs had expired (A-DA-3) the checkpoint could never have been produced at all, and T3's guard would simply fail into the DRAINED stall.

**Evidence:** quoted rule texts above; `Inbox.sol:270-290, 321-400` at the frozen revision; the round-1 adjudication itself notes "MIG-03(1) One settlement path at a time" but never reconciles it with D5/INV-02. Fix candidates (one sentence each, not required by the brief): (i) declare states 0–2 governed by the Shasta rule set and explicitly outside D5's scope, with the user's acknowledgement; or (ii) make T2/T3 impossible while an unproven proposal exists and void them explicitly with disclosure — either way the unconditional D5/INV-02 claim must be corrected.

---

### E-R2-02 — the statement's public-input vector is defined twice, differently: L1-05's 21-row binding list ≠ PRF-02's journal

**Severity:** Critical — the two normative definitions of what the proof proves cannot both be satisfied; one resolution makes every proof unverifiable, the other leaves contract-used values attacker-chosen (unbound `feeRecipient` redirects forced-inclusion fees), and the round-1 fix that unified the quorum predicate did not unify the input vector.

**Exact rule(s):** `spec/04-l1-integration.html` L1-05 ("The statement the proof is checked against MUST bind every value in the table below ... The canonical byte encoding of these values into the guest's public-input vector ... are fixed on PRF-02 and PRF-07 ... The contract hashes the whole vector ... into `statementHash`") rows 1–21; L1-08's `LandInput` carries `finalityCommitment`, `feeRecipient`, `daMode`; against `spec/05-proof-statement.html` PRF-02 ("The guest commits to **exactly** the following journal", annotated "exact list, order is normative").

**Preconditions:** any first batch; the mismatch is structural.

**Counterexample / worked diff (verified by exhaustively grepping both pages):**
- In L1-05 only, absent from PRF-02's journal: `previousCheckpointHash` (row 2), `firstBlockTimestamp`/`lastBlockTimestamp` (row 8), `finalityCommitment` (row 15), `daMode` (row 17), `feeRecipient` (row 21). The strings `feeRecipient`, `firstBlockTimestamp`, `previousCheckpointHash`, `daMode`, `finalityCommitment` do not occur anywhere in `05-proof-statement.html`.
- In PRF-02's journal only, absent from L1-05's table: `domain`, `l1ChainId`, `configHash`, `blobHashesHash` (`l2ChainId` appears only inside DA-03's challenge formula, not as a table row).
- L1-05 row 21 says `feeRecipient` "receives the forced-inclusion fees (L1-11)" and is "proof-bound to the header of block `firstBlockHeight`" — but no PRF rule binds it (PRF-04, PRF-06 and PRF-02 never mention it), and L1-11 pays `sum of feeHeld[r] for r in coveredRequestIds` straight to `feeRecipient`.

Consequence A (implement L1-05 literally): the contract hashes ≥5 values the guest never committed to, so the verifier's `statementHash` cannot match any proof → no batch lands → R9/D5 fail operationally and the chain halts with a finalized prefix it can never settle. Consequence B (implement PRF-02 literally): the contract's vector equals the journal, and `feeRecipient` is no longer bound by anything the proof checks. Then any lander may set `_input.feeRecipient` to itself and collect every covered request's escrowed fee that L1-11 was required to pay to the batch's L2 proposer; `firstBlockTimestamp` (the forced-inclusion dueness input T) is likewise taken from an unbound field, and `finalityCommitment` stops being bound at all.

**Inside/outside the fault model:** inside — consequence B needs no assumption failure; a lander (any account, L1-04) simply chooses the field. This is the same failure class the round-1 CS-09 fix declared a protocol defect for the quorum predicate ("splits chain acceptance from L1 acceptance"), one level up: it splits the *statement*.

**Attacker resources and cost:** one L1 transaction (`land`, gas only) under consequence B; zero under consequence A.

**Harm; requirement / decision:** R13 (implementable without inventing rules), R9/D5 (the "valid proof" must exist and bind the batch), R11 (fee/payout correctness), possibly INV-02 and the bridge's authentication anchor. Loss of funds: forced-inclusion fees paid to the wrong party.

**Evidence:** PRF-02 journal block and L1-05 table as quoted; grep counts in both HTML files; `Inbox.sol` interface sketch (`LandInput.feeRecipient`, `finalityCommitment`) in L1-08; L1-11 payout identity. This is a new finding relative to round 1 (the round-1 ledger's PRF-04/PRF-02 edits concerned signature fields and the epoch array, not the vector contents).

---

### E-R2-03 — MIG-02's "complete change list" does not budget the Inbox state that L1-07/L1-11/FI-01/L1-09 require, and T3 cannot write a legal L1-07 genesis record

**Severity:** High — the migration's storage-layout constraint is the only thing that keeps D3's in-place upgrade safe, and it is demonstrably incomplete while declaring itself complete; the first post-migration batch's predecessor binding has no defined value.

**Exact rule(s):** `spec/08-migration-upgrades.html` MIG-02 ("The complete change list is the table below; any change not in it requires a new decision recorded in the decision log", 6 new Inbox slots 258–263, "If an implementer needs more Inbox state than the 37 remaining slots, the answer is a decision-log entry"); T3's effect ("(B*, S*, H*) is written to Inbox slots 259–260"); MIG-01 ("read once at T3, written to Inbox slots 258–260"); against `spec/04-l1-integration.html` L1-06/L1-07/L1-08/L1-11 and `spec/03-membership-staking.html` MEM-09.

**Preconditions:** building the migration implementation from this specification.

**Counterexample (missing declarations and fields):**
- L1-07 requires "one checkpoint record per landed height", 7 fields each, readable by height, plus `checkpointAt(uint64)`/`lastCheckpoint()` (L1-08) and L1-05 row 2's `previousCheckpointHash` "over the stored record at `lastLandedHeight`". No slot is budgeted for the checkpoint map, and no budget line names it.
- L1-11 requires two segregated ledgers (`forcedInclusionEscrow`, `proverReward`), per-request `feeHeld[r]`, `consumed[r]`, `refunded[r]`, and `REWARD_QUOTE`; FI-01 requires a queue storing `requester`, `eligibleAtL1Timestamp`, `payloadHash`, **`bytes txData` "stored in L1 STATE"**, `id`, plus FI-05's fee state. None is in the change list.
- L1-09 requires "Routes MUST live in the Inbox's own storage" (routeVersion → (imageId, verifier)), and L1-08 exposes `activeVerifierRoute()`. Not budgeted.
- `lastLandedHeight` itself is not named; slot 263's `lastAcceptedL2Block` is the only candidate.
- T3 writes only `(B*, S*, H*)` (slots 259–260 plus `genesisL2BlockNumber` in 258). An L1-07 record needs `epoch`, `setRoot`, `dataCommitment` and `l1BlockNumber` as well, and L1-07 says "`blockHash`, `stateRoot`, `setRoot` and `dataCommitment` MUST be non-zero; a record that fails any of these MUST NOT be written." The genesis has no data commitment, so **no legal genesis record exists**; the first `land()` therefore cannot compute L1-05 row 2's `previousCheckpointHash` from "the stored record at `lastLandedHeight`" without the implementer inventing the missing fields — and inventing a non-zero `dataCommitment` for a batch that has no data is precisely what D5/DA-01 forbid.

**Inside/outside the fault model:** inside — structural.

**Attacker resources and cost:** none.

**Harm; requirement / decision:** R3 ("preserve D3 shared-contract addresses with a concrete migration plan") and R13; D3 is conditional on this plan (`spec/01` "No claim that the D3 addresses remain compatible by themselves. Preservation is conditional on exact storage-layout discipline (MIG-02)"). An implementer who follows MIG-02 literally cannot deploy the specified design; one who follows the design violates MIG-02's "complete change list" rule. In addition, the unbudgeted forced-inclusion `txData` queue is the exact state whose absence caused the round-1 B R1-07/C R1-10/R1-11 accounting disputes.

**Evidence:** MIG-02 table and rule text; layout files `MainnetInbox_Layout.sol:21-26` (first free slot 258, gap 258–300); L1-07's field list and MUSTs; T3; MIG-01. (The 37 remaining gap slots are numerically sufficient for the missing mapping bases — the defect is the plan's completeness and the genesis record's undefined fields, not the slot arithmetic.)

---

### E-R2-04 — who may add a verifier route is undetermined, and the two pages that own the acceptance policy describe different policy spaces

**Severity:** High — a rule that decides which proof systems may accept batches is left to be invented; one available reading lets any account install a verifier, which is a bridge-theft-class outcome.

**Exact rule(s):** `spec/04-l1-integration.html` L1-09 ("A batch may be proven by any route whose (programImageId, verifier) pair is registered for the batch's epoch and not retired ... whether the policy is 'one backend active' or 'either backend verifies' is fixed by PRF-09, and `land(data, proof)` MUST implement that policy literally ... Enabling a new route is additive and MUST NOT be rejectable by any account (L1-04) ... Routes MUST live in the Inbox's own storage"); `spec/05-proof-statement.html` PRF-09 ("the protocol chooses between (a) any single accepted backend, and (b) two independent backends for every batch ... **Open** (resolved by the launch decision)"); `spec/08-migration-upgrades.html` MIG-04 ("the accepted program-image set is Inbox slot 261 and changes only by upgrade (MIG-05)"); MIG-05 (registry semantics).

**Preconditions:** any implementation of `land()`.

**Counterexample / inconsistency matrix:**
- PRF-09's options {any single backend | two backends required} are not L1-09's options {one backend active | either verifies}. Under PRF-09(b) ("two independent backends for every batch") L1-09 provides no implementation branch at all ("with an either-verifies policy ...; with a single-route policy ...") — neither branch verifies two proofs. Under PRF-09(a) the correct behaviour is "either verifies", but L1-09's "single-route policy" branch ("call exactly the one route the policy designates") has no designation rule in MIG-05's per-epoch *set*.
- MIG-04 says the accepted set "changes only by upgrade"; L1-09 says enabling "MUST NOT be rejectable by any account", which reads as a runtime permitting rule. If the literal reading is taken — any account may register `(programImageId, verifier)` — then a route whose `verifier` is an attacker contract returning `abi.encode(true)` satisfies L1-03 step (5), and any batch can be landed with arbitrary state roots: complete loss of the proof system, bridge theft (`MSG-03` withdrawals authenticate against whatever checkpoint lands).
- PRF-09 is Open, so even the benign reading leaves `land()` unimplementable until a launch decision is made; the specification's own failure-mode text for PRF-09 says exactly this ("an unstated policy leaves an implementer to decide whether one or two proofs are required").

**Inside/outside the fault model:** inside — the attacker needs no cryptographic break; only the literal reading of a normative sentence.

**Attacker resources and cost:** one L1 transaction to register a route plus one `land()` transaction (gas only) under the literal reading.

**Harm; requirement / decision:** R13; R5/R9 (acceptance only on a valid proof); R11/user funds through the preserved bridge; the honest-naming and D5 obligations are unaffected but the security budget collapses.

**Evidence:** rule quotations above (L1-08's sketch exposes only `activeVerifierRoute()`, singular, and no registration function, so the registration path is not even sketched); MIG-04's verifier rows; MIG-05's epoch-gated registry. Round-1 B R1-14 fixed retirement ("not an ordinary operation") but left enabling unowned.

---

### E-R2-05 — validator rewards are promised twice and implemented nowhere: no per-signer input, no claim path, no ledger term

**Severity:** High — the reward half of the security budget (A-ECO-1's deterrence and ECON-12's Budget) has no normative implementation, and the two rules that promise it point at each other.

**Exact rule(s):** `spec/07-economics-slashing.html` ECON-02(5) ("Payment happens in the L1 acceptance transaction from the L1-committed reward pool; the allocation of inflow between role classes and the exact claim interface are **L1-11** and are not restated here ... a payout to a validator is conditioned on attested participation in the epoch for which it is paid ... Among participating entries of a class, a period's payout is pro rata to effective stake"); `spec/01-system-model.html` ROLE-01(d) ("Paid only from the L1-committed reward pool in the same L1 transaction that accepts a batch (**L1-11**)"); `spec/04-l1-integration.html` L1-11 (two ledgers only: forced-inclusion escrow and `proverReward`; the only payout is `rewardPaid = min(REWARD_QUOTE, proverReward_before + msg.value)`); L1-10 ("The reward of L1-11 MUST be paid to `msg.sender`"); L1-05 rows 1–21 and PRF-02 (no signer bitmap, no per-epoch participation data — only `finalityCommitment`, a hash, and only for the batch's head block); L1-08 (no reward-claim function); `spec/10-assurance.html` INV-04 ("reward claiming" is listed as an ordinary operation reachable by any address).

**Preconditions:** a validator that participated in epoch e expects payment; a launch that relies on ECON-12's Budget_ETH(n) to fund n validators.

**Counterexample / worked gap:**
1. `land()` is called by the prover/lander. The only payment primitive in L1-11 is `rewardPaid` to `msg.sender`. The conservation identity `proverReward_after = proverReward_before + msg.value − rewardPaid` has no term for validator payouts; paying validators from the same pool either breaks the identity or drains the prover ledger.
2. To pay per-signer pro rata, L1 must see who signed. The journal cannot carry it: its finality field is `finalityCommitment = keccak(..., bitmapHash, signatureSetHash)` — a hash — and it covers only the head block's certificate, not "that epoch's duties ... as recorded in the epoch's certificates" (ECON-02(5)(b)); the epoch's certificates for other heights never reach L1.
3. There is no `claimReward`/`withdrawRewards` in L1-08's "acceptance surface" and no other rule creates one. So a validator has no transaction it can send that pays it.
4. The coherence story for an exhausted subsidy is also unsupported: ECON-02(4) and ECON-12(2) say "the validator count is reduced through the objective exit path of MEM-05", but MEM-05's exit is owner-initiated only (`requestExit()` is owner-only, MEM-03/05). No rule reduces the count; the protocol under-pays and waits for voluntary exits.

**Inside/outside the fault model:** inside — structural; no attacker required. (An attacker can also exploit it: with no participation-conditioned payout implemented, offline validators are indistinguishable at the payment layer.)

**Attacker resources and cost:** none for the structural defect.

**Harm; requirement / decision:** R11 (rewards/payouts must be specified), R13, R2-adjacent (INV-04 lists reward claiming as permissionless and objective), ECON-02/ECON-12 internal consistency; the deterrence relation A-ECO-1 and the security budget are unverifiable if the payout the budget funds does not exist.

**Evidence:** quotations above; PRF-02 journal; L1-05 rows 15 and 21; L1-08 sketch; the round-1 fix for ECO-10/ECO-15 added the participation *condition* but not the payment *mechanism*.

---

### E-R2-06 — ECON-06's pure REPORTER_BOUNTY destination is mathematically incompatible with its own strict bounty bound, reopening the self-report attack the round-1 fix claims to close

**Severity:** High — a permitted configuration makes the offender whole, so the penalty becomes an accounting entry; the round-1 ECO-06 fix is not closed by the rule that carries it.

**Exact rule(s):** `spec/07-economics-slashing.html` ECON-06(2) ("Exactly one of: TREASURY, BURN, **REPORTER_BOUNTY**, or a fixed integer split of the three") and ECON-06(5) ("Whatever destination is recorded, the total paid to reporting submitters for one applied offence identity id — including a submitter controlled by, or affiliated with, the offender — MUST satisfy `REPORTER_BOUNTY(id) < c(f(e,c)) · SlashBase(v,e) ≤ P(v,e)`"); `spec/04-l1-integration.html` L1-11/ECON-05 for the payout amount; `spec/09-parameters.html` registers `REPORTER_BOUNTY` in TAIKO with that same bound.

**Preconditions:** the human decision required by ECON-06(1) selects the pure `REPORTER_BOUNTY` option; the offender (or an affiliate) is the first submitter of its own evidence.

**Counterexample:**
1. Offender v equivocates at epoch e; evidence is public and first-come (ECON-04(4)).
2. Under pure `REPORTER_BOUNTY`, "the destination of every debited amount" is the reporting submitter, so the amount paid is the full debit `charge = min(P(v,e), bonded, remaining_exposure)`.
3. `P(v,e) = min(SlashBase·(IMM_FRAC(c) + c(f)), SlashBase) ≥ c(f)·SlashBase` for every `IMM_FRAC ≥ 0` and every `c(f) ≤ 1` (if `IMM_FRAC + c > 1` the min is `SlashBase ≥ c·SlashBase`). Therefore `REPORTER_BOUNTY(id) = charge ≥ c(f)·SlashBase`, violating ECON-06(5)'s strict "<" for the realised f (indeed for every f).
4. v self-reports (directly or via an affiliate), receives the whole penalty back, and is out only L1 gas — the exact round-1 ECO-06 attack, re-enabled by an option the same rule offers.

Note the rule cannot be rescued by paying "only part" under the pure option: ECON-06(1) says "leave the amount in the ledger ... is not a conforming default", so the remainder would have no destination — the split option is the only conforming way to pay less than the whole amount, and the pure option must be deleted or defined as a split with `reporterPpm < 1_000_000` and `reporterPpm · P < c·SlashBase`.

**Inside/outside the fault model:** inside — the offender is a listed offender and the submission is a normal `slash()` call; cost is gas only.

**Attacker resources and cost:** one L1 transaction (gas).

**Harm; requirement / decision:** R11 (objective penalties with real collateral), A-ECO-1 (deterrence); ECON-06/ECON-05 internal consistency. The round-1 entry "D ECO-06 ... Fixed: reporter bounty is strictly less than the correlated penalty" is not closed while the menu permits the contradictory option.

**Evidence:** quoted clauses; ECON-06(5)'s chain of inequalities; ECON-05(2)'s `P(v,e)`; PARAM-02's `REPORTER_BOUNTY(id)` row.

---

### E-R2-07 — the evidence window's anchor `t_root(e)` is defined but never stored or derivable on L1, so the admissibility test of ECON-07 cannot be implemented as written

**Severity:** High — the window that makes late evidence collectable (and the withdrawal gate that depends on it) rests on a timestamp no rule requires the staking contract to persist.

**Exact rule(s):** `spec/07-economics-slashing.html` ECON-07(1) ("`evidenceClose(e) = t_root(e) + W_evidence(e)` and `t_root(e)` is the timestamp of the L1 block at which the commitment of epoch e's own set root became an Ethereum-final L1 fact"), ECON-07(2),(5), ECON-04's deadline column ("inclusion block's timestamp ≤ evidenceClose(epoch_of(H))"); `spec/03-membership-staking.html` MEM-09(2) (the per-epoch mapping stores `epoch → (setRoot, totalVotingPower)` only); `spec/02-consensus.html` CONS-10(6) (the commitSet block number `N` is carried in the **L2 header** field `set_version_commit`, not in L1 storage); `spec/04-l1-integration.html` L1-12/SYS-02's 256-block `blockhash` window (`L1_FACT_MAX_AGE`).

**Preconditions:** a `slash()` call for an offence at any epoch whose set-root commitment is more than 256 L1 blocks old (i.e. every realistic case).

**Counterexample / worked gap:**
- `slash()` must evaluate `block.timestamp ≤ t_root(e) + W_evidence(e)` (ECON-04's checker) and `applyCorrelated` must evaluate `corrApplyAt(e,c) = evidenceClose(e) + CORR_DELAY`. Both need `t_root(e)`.
- L1 state contains no `t_root(e)`: MEM-09(2)'s entry is `(setRoot, totalVotingPower)`; the only L1-visible coordinate of the commit is `N(k)` (the commitSet block number) and that is in the L2 header, which the L1 contract cannot read.
- If the implementer stores `block.timestamp` at commitSet time, they have *invented* the anchor: under the literal reading ("the block at which the commitment **became** an Ethereum-final L1 fact") the correct timestamp is ~2 Ethereum epochs later than the commitSet block, so the window closes up to ~13 minutes early, and evidence that the rule says is admissible reverts `EvidenceWindowClosed`. If the implementer instead uses the header-carried `N(k)`, the L1 contract has no timestamp for it. Either way the admissible interval is decided by an unstated choice, in the direction that lets an offender escape.

**Inside/outside the fault model:** inside — structural; no attacker required. A well-resourced offender can additionally exploit a shortened window by delaying publication of its own equivocation.

**Attacker resources and cost:** none for the structural defect; timing only for the exploitation.

**Harm; requirement / decision:** R11 (objective evidence and exit delays), R13; ECON-07's non-empty-window guarantee and MEM-06's withdrawal-race defence both depend on the window being computable.

**Evidence:** grep of all ten pages: `t_root` occurs only in ECON-07; MEM-09's mapping definition; CONS-10(6); the round-1 fix ECO-04/05 re-anchored the window to the offence epoch but did not add the anchor to any stored object.

---

### E-R2-08 — CHURN_LIMIT versus MEM-05(2): two rules give different conditions for the same exit transition

**Severity:** Medium — an implementer must choose which rule wins; choosing MEM-05(2) voids the round-1 ECO-07 churn cap, choosing ECON-03(6) contradicts the rule that owns exit timing.

**Exact rule(s):** `spec/07-economics-slashing.html` ECON-03(6) ("the L1 staking contract MUST NOT make more than `CHURN_LIMIT · TotalVP(e)` of effective stake inactive at any single epoch e. Exits beyond the cap are neither cancelled nor penalised; they are deferred to later epochs"), against `spec/03-membership-staking.html` MEM-05(2) ("Exit becomes effective at the first set version whose snapshot point is at or after the exit request transaction's L1 block; from that version the entry's effStake = 0") and §2.1 lifecycle row 4 ("automatic at the first set snapshot at or after the request block"). ECON-03(1) makes MEM-05 the owner of `D_withdraw`, and MEM-05(3) lists the withdrawal conditions without any churn-deferral term.

**Preconditions:** a coordinated exit that would exceed `CHURN_LIMIT · TotalVP(e)` at one epoch boundary (the ECO-07 scenario: end of subsidy, price move, operators exiting together).

**Counterexample:** N operators call `requestExit()` in one L1 block. ECON-03(6) requires the contract to defer all but `CHURN_LIMIT` worth to later epochs; MEM-05(2) requires each exit to become effective at the first snapshot at or after the request. Both are normative; neither is marked as subordinate; GEN-03's "one rule, one place" is violated because the transition is stated in three places (MEM-05(2), the lifecycle table, ECON-03(6)). An implementer following the owning rule (MEM-05) reproduces round-1 ECO-07 exactly: a one-step drop of the stake that deters attack.

**Inside/outside the fault model:** inside for the coordinated-exit case (which ECON-03(6) itself names; it need not be an attack — the end of a subsidy is a scheduled event).

**Attacker resources and cost:** the capital to run many validators (or to be many operators), plus the pre-existing right to exit.

**Harm; requirement / decision:** R11 (objective exit rules and the deterrence relation), ECON-09(2)/A-ECO-1; the amendment that closed ECO-07 is not wired into the rule that determines exit effectiveness.

**Evidence:** the three rule texts above; the round-1 disposition "D ECO-07 ... Fixed: per-epoch churn limit added" points only at ECON-03(6).

---

### E-R2-09 — SYS-02 §3.1 and MIG-06 give opposite instructions for the L2 SignalService's immutable checkpoint writer

**Severity:** Medium — an internal contradiction about a preserved contract's wiring (D3-adjacent), touching the one lever the specification admits leaves R1/R2 unsatisfied.

**Exact rule(s):** `spec/01-system-model.html` §3.1 table row 2 ("The preserved address (D3) must be repointed by a layout-safe in-place upgrade (MIG-02) to a write path that is not a single privileged address. No replacement deployment (MIG-06)."); against `spec/08-migration-upgrades.html` MIG-06 ("A re-deployed SignalService implementation must be constructed with the same `_authorizedSyncer`, `_remoteSignalService` and `VERSION` values as the implementation it replaces"; L2 `_authorizedSyncer` = the Anchor proxy) and MSG-01 (L1 side: "MUST be the Inbox and MUST remain immutable for the lifetime of the deployment").

**Preconditions:** building the migration bundle for the L2 SignalService.

**Counterexample:** the specification instructs the implementer both to keep `_authorizedSyncer` = Anchor (MIG-06) and to repoint the writer to something that is "not a single privileged address" (SYS-02 §3.1). Since `_authorizedSyncer` is `internal immutable` (`SignalService.sol:37`), "repointing" is only possible by deploying a new implementation with a different constructor argument — which MIG-06 forbids by name. SYS-02(g)/MIG-04 then say the privilege is retained and Open; §3.1 says it is removed. The reader cannot tell whether the L2 checkpoint writer is the Anchor or a new rule-checked path.

**Inside/outside the fault model:** inside — structural (the ambiguity is in the plan, not in the runtime).

**Attacker resources and cost:** n/a.

**Harm; requirement / decision:** R2/R1 (the retained-writer item is the only admitted R1/R2 gap), R3/D3 clarity; R13 (the migration implementer must invent which instruction to follow).

**Evidence:** `SignalService.sol:35-37, 174-184`; `SignalService_Layout.sol:254`; the three rule texts; MIG-04's golden-touch row and MIG-06's table.

---

### E-R2-10 — ECON-02(1)'s "single-currency (ETH) and evaluable" identity pays TAIKO bounties and double-counts subsidy payouts

**Severity:** Medium — an accounting identity that the round-1 fix claims is single-currency is not; it cannot be evaluated without a TAIKO price, which ECON-10(5) forbids as a constant.

**Exact rule(s):** `spec/07-economics-slashing.html` ECON-02(1) ("the sum of everything the protocol pays to **validators, provers, reporters** and any other role MUST satisfy `rewards_ETH(period) ≤ F_exec_L2 + F_priority_L2 + POOL_TOPUP − C_L1_data − C_L1_verify − C_bridge_ops − D_subsidy`", with the claim "the budget identity below is single-currency (ETH) and evaluable"); ECON-06(2)/(5) and `spec/09-parameters.html` (`REPORTER_BOUNTY(id) | TAIKO`); ECON-02(1) again for `D_subsidy` ("the amount moved out of the pool's inflow into the pre-funded ... subsidy account ... **or paid out of it**").

**Preconditions:** any period in which a reporter bounty is paid, or a subsidy payout occurs.

**Counterexample:**
- A reporter bounty is denominated and paid in TAIKO out of slashed stake (ECON-06 table and PARAM-02 unit "TAIKO"). It is a payment "to ... reporters", so it belongs to the LHS of an inequality whose RHS is ETH terms. Comparing them requires a TAIKO/ETH price; ECON-10(5) forbids any price constant and ECON-02(2) forbids assuming appreciation. The identity is therefore not "evaluable" as claimed. If the bounty is instead excluded from the LHS, the LHS no longer means "everything the protocol pays".
- `D_subsidy` counts "paid out of it" as a subtraction from the period's fee-funded capacity, while the same payout is also a reward on the LHS ("everything the protocol pays"). The same ETH is counted on both sides, so the identity is stricter than intended by the payout amount; an implementer who follows it literally under-pays by the subsidy amount, and one who does not has to invent the reconciliation.

**Inside/outside the fault model:** inside — structural accounting; no attacker needed.

**Attacker resources and cost:** none.

**Harm; requirement / decision:** R11/R13; ECON-12's Budget and the "fee-only region" test inherit the error; the round-1 claim that "rewards in ETH remove the mixed-currency sum" is only half true (validator/prover rewards yes, reporter bounties no).

**Evidence:** the quoted identity and term definitions; PARAM-02's `REPORTER_BOUNTY` and `D_subsidy` rows; ECON-10(5).

---

### E-R2-11 — citation and registration defects left after the round-1 parameter cleanup

**Severity:** Low — clarity/citation defects; no security consequence by themselves, but they are the same class the round-1 review closed elsewhere (alias and duplicate-formulation defects) and they weaken reviewability of the parameter register.

**Exact rule(s) and defects:**
(a) `spec/09-parameters.html` PARAM-02 registers "Correlated penalty | fraction of stake | `min(m · f, 1)` with m chosen so the penalty saturates when the implicated fraction reaches the one-third safety threshold | ECON-05; the Ethereum form uses m = 3", while `spec/07` ECON-05(1) fixes `c(f) = min((f/F_SAT)^CORR_Q, 1)`, `F_SAT = 1/3`, `CORR_Q ∈ {1,2}`. The two formulations agree only for `CORR_Q = 1`; the table's form cannot express the quadratic form and restates a rule that ECON-05 alone owns (GEN-03).
(b) ECON-09(3) requires "the resulting count `n = S_total / S_min` [to] lie inside the **consensus set-size window**, which is a consensus-rule output" — no rule in `spec/02` or elsewhere defines any set-size window (grep of all pages finds only narrative uses of "set size").
(c) Alias drift survives the round-1 cleanup: MEM-03(3) names `D_activation` while PARAM-02 registers `ACTIVATION_DELAY`; MEM-05/ECON-03 use `D_withdraw` while PARAM-02 registers `D_WITHDRAW`; `D` and `D_MAX` (HALT-03) vs PARAM-02's `D_MAX` are consistent, but the round-1 text explicitly declared the *other* aliases deprecated (`T_proof_bound`, `A_max`, `WS_max`) and these two were missed.
(d) REC-02's Mode B invoker bond and the REC-02 "late proofs" currency are unspecified ("by posting a bond") — Mode B is not selected, so this is a Low completeness note only.

**Inside/outside the fault model:** inside (specification quality).

**Attacker resources and cost:** none.

**Harm; requirement / decision:** R13/R14 reviewability; PARAM-01's "every protocol parameter appears in the table with its identifier and derivation" is weakened by (c).

**Evidence:** the quoted rows and rule texts; grep results for "set-size" (no hit in `02-consensus.html`) and for `D_activation`/`ACTIVATION_DELAY` across the pages.

---

## Explicitly checked and deliberately not reported as findings

- **REC-02 / Mode B and D5.** Recovery is invoked by an L1 transaction that carries no batch and writes no checkpoint; the new checkpoint is the existing L1 checkpoint; new batches still land data+proof together. D5 holds. REC-03's blocker is recorded, not waived. No finding.
- **D3 addresses.** MIG-06 preserves all five D3 surfaces at their recorded addresses in place, on both chains; verifiers, the staking contract and the reward path are new deployments referenced by address (allowed — D3 names only the five surfaces). No finding beyond E-R2-03/E-R2-09.
- **MSG-01's field split.** The frozen `SignalService` layout and ABI are unchanged (two-field `CheckpointRecord` at `_checkpoints[VERSION][blockNumber]`; immutable `_authorizedSyncer`); epoch/setRoot/dataCommitment/l1BlockNumber live in the Inbox's own record. No finding beyond E-R2-03.
- **D7.** TAIKO-only staking/collateral confirmed (MEM-01, ECON-01(1); no ETH collateral; legacy gwei bonds not stake and not slashable; rewards in ETH are conforming). No finding.
- **Explicit D5 carve-outs that do exist and are fine:** FI-01's `requestForcedInclusion` publishes user calldata with no proof, but it creates no batch record and cannot be a precondition for `land()`; `L1-02` bans announce/intent/commit functions and the design contains none; `DA-04`/L1-11 create no off-chain shortcut. No finding.
- **R2 (DAO).** No ordinary operation reads a DAO-changeable value; `commitSet`, `slash`, `applyCorrelated`, (and `land`) are permissionless; T1–T3 are one-time upgrades; route retirement is an upgrade. The residual privileged *L2 checkpoint writer* is not the DAO, is disclosed in SYS-02(g)/SYS-04(c) and marked Open in MIG-04 — recorded here as a known gap, not re-reported.
- **Activation fairness.** MEM-03(2) discloses the adversarial-L1-ordering caveat and states the protection (delayed, never denied); ECON-09(5) repeats it without claiming fairness. Disclosure is adequate; no finding.
- **Subsidy / token appreciation.** ECON-02(2) forbids appreciation assumptions; ECON-12 makes `ρ_capital` price-dependent and states the reflexivity honestly; no hard-coded market datum exists (ECON-10(5)). No silent appreciation assumption found; the accounting issues are E-R2-10.

## Coverage limitations of this report

- This was a rules-as-written review of the specification pages plus the baseline sources they cite; no code was compiled or executed, and the blob-binding cryptanalysis (Q-A3) is out of this angle.
- Parameter *values* are unmeasured by design and were not treated as findings; only the identities, bounds and cross-references were checked.
- The learn site (R14) was not audited.
