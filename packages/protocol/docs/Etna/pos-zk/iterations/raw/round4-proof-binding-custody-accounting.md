# Round 4 — raw adversarial review: proof soundness, data binding, custody and accounting under the new economics

**Reviewer.** Fresh independent adversarial reviewer, round 4, assigned angle: proof soundness, data binding, custody and accounting under the new economics (D-7/D-8/D-9/D-10).
**Snapshot reviewed.** Working tree at commit `fe7373a1310900ffd66c72e63d682ce81359d6e0` (clean apart from the other round-4 raw files), i.e. change order 04 applied in place.
**Pages attacked.** `spec/05-proof-statement.html` (PRF-01..13), `spec/04-l1-integration.html` (L1-01..12, DA-01..06, MSG-01..03, FI-*), `spec/07-economics-slashing.html` (ECON-01..12), cross-read with `spec/03-membership-staking.html` (MEM-01..12), `spec/06-recovery-exceptions.html` (REC-01..03), `spec/09-parameters.html`, `spec/10-assurance.html`, and the preserved baseline contracts actually named by the rules (`packages/protocol/contracts/shared/bridge/Bridge.sol`).
**Method.** Rules judged as written. In-text `(D-n)` / `(review round N, finding X)` italics are treated as claims, not evidence. Citation convention: `NN:line` = `spec/NN-*.html`; `DECISIONS.md:line`; `Bridge.sol:line` = the preserved L1/L2 bridge implementation in this repository, which the rules claim to reuse via D3.
**Counts: Critical 0 · High 3 · Medium 5 · Low 1.**

**Headline.** The new economics is where the round's un-reviewed surface is, and three things do not close: (i) the D-8 sweep's **L1 leg is not specified at all** — the preserved Bridge's own delivery rules decide custody through message fields the specification never names, and one of them (`destOwner`) is a refund address the Bridge pays instead of the destination; (ii) `configHash`, the value D-7 leans on to stop an alternative configuration from settling, **has no defined preimage and its inputs are not in PRF-03's witness**, so the binding is vacuous as written; (iii) the **"recorded allocation policy"** that fixes both `Alloc(e)` and the proving share is referenced five times as an authority and defined nowhere, and ECON-02(5)(d)'s pool identity has no term for the proving-share outflow, so the same inflow can be allocated twice. The journal↔L1-05 field list itself still agrees field for field after the new fields; the failures are in the *derivations* the rows assert.

---

## Findings

### R4-PB-01 — High — the D-8 sweep's L1 leg is unspecified, and the preserved Bridge's own rules pay the swept ETH to a message field the specification never names

**One-line rationale.** ECON-02 clause 7 and L1-11 require the L2 fee vault to send the swept ETH "through the preserved Bridge" to "the single reward pool account", but no rule states how the credit happens on L1 and no rule binds the `Message` fields the Bridge actually reads; the Bridge refunds `_message.value` to the caller-chosen `destOwner` and marks the message `DONE` whenever the message data is not the `onMessageInvocation` selector, so both a naive conforming implementation (uncredited / retriable / recalled) and any implementation that leaves a message field caller-influenced (theft of the swept revenue) are reachable.

**Exact rule / missing rule.**
- `07:218-267` (ECON-02 clause 7): (b) "an L2→L1 bridge message whose destination is exactly the single reward pool account of clause 5(a) … The destination is a protocol constant recorded before launch, never a parameter the caller supplies"; "The sweep credits nothing by assertion: the L1 release credits the pool only when the preserved Bridge has authenticated the message (MSG-02)".
- `04:353-378` (L1-11): "the pool is credited only when the preserved Bridge authenticates the message (MSG-02)"; "the caller chooses only *when*, never *where* or *how much is credited to whom*".
- `04:631-647` (MSG-02) documents the frozen signal slot, the message hash `keccak256(abi.encode("TAIKO_MESSAGE", message))` and the five statuses — it does **not** define the destination-side invocation, its selector, or the fields that decide where the value goes.
- Preserved Bridge, which D3 keeps in place: `Bridge.sol:217-255` (`sendMessage` keeps caller-supplied `srcOwner`, `destOwner`, `to`, `data`, `fee`, `value`, `gasLimit`; only `id`, `from = msg.sender`, `srcChainId` are set by the contract), `Bridge.sol:242` (`value + fee == msg.value`), `Bridge.sol:344-349` and `701-715` (`_unableToInvokeMessageCall` is true when `data.length >= 4` and the selector is not `IMessageInvocable.onMessageInvocation`; the value is then **refunded to `destOwner`** and the message is marked `DONE`), `Bridge.sol:400` (`_message.destOwner.sendEtherAndVerify(refundAmount, …)`), `Bridge.sol:566-597` (`_invokeMessageCall` is a raw `call` to `to` with `data` and `value`), `Bridge.sol:286-298` (on recall, value goes to `from` if it implements `IRecallableSender`, otherwise to `srcOwner`), `Bridge.sol:329-331` and `367-398` (a relayer may process only when `gasLimit != 0`; the relayer is paid from `fee`, so `fee == 0` leaves the message for `destOwner` to self-process).
- `05:217-232` (PRF-03) and the whole specification tree contain the string `onMessageInvocation`: **zero occurrences**. No rule says how the staking contract authenticates the Bridge caller before crediting the pool, nor that the pool accounting must be updated by that call rather than by `address(this).balance`.

**Assumptions and preconditions.** The sweep exists (a clause-7 rule), any account may call it (`07:235-237`), and the L2 fee vault holds ETH. The reward pool is an account of the L1 staking contract. No assumption failure and no Byzantine stake is needed for the funding-failure variant; the theft variant additionally needs an implementation that does not fix every `Message` field as a constant — which the rules permit, because they never say who builds the `Message` or which fields are constants.

**Concrete attack trace (theft variant, callers build the message).**
1. An attacker calls the vault's permissionless sweep. The vault moves its balance to the Bridge and the caller (or a caller-supplied builder) submits `sendMessage` with `to = pool`, `destOwner = attacker`, `srcOwner = attacker` and `data` set to any ≥4-byte value that is **not** `onMessageInvocation` (e.g. empty is a separate case; a custom `creditPool()` selector is the natural mistake).
2. On L1, `processMessage` computes `_unableToInvokeMessageCall = true`, sets `status = DONE`, `refundAmount = _message.value`, and sends the whole swept amount to `destOwner` = the attacker (`Bridge.sol:344-349,400`). The pool is never credited. The message is `DONE`, so no retry and no recall is possible (`Bridge.sol:337` requires `NEW` for a recall; `604-605` refuses a repeated status write): the loss is final.
3. The same outcome is reachable without malice: any implementation whose message carries a selector other than the hook (or an empty-`data` message to a pool contract with no `receive()`, which reverts into `RETRIABLE`) either pays a non-pool `destOwner` or never funds the pool. In the `RETRIABLE` case the ETH sits in the Bridge until someone calls `retryMessage(..., true)` to reach `FAILED` and `recallMessage` on L2; no rule requires that loop, assigns it, or pays for it.

**Inside/outside the claimed fault model.** Inside the action model: the rule deliberately makes the sweep caller permissionless and says the caller "chooses only when"; the `destOwner`/`data` dependency is a property of the preserved contract the rule orders the designer to use, not an assumption failure. The funding-failure variant needs no adversary at all.

**Attacker resources and cost.** One L2 sweep transaction plus one L1 `processMessage` transaction (permissionless relaying); no stake, no bond. Benefit: the whole swept amount (bounded by the L2 fee revenue of the period).

**Harm and the exact requirement or fixed decision affected.** Loss of the protocol's security budget and the falsity of "the caller chooses only *when*, never *where*" as written (`04:373-375`); the D-8 funding path is not implementable from the rules alone (R13); `07:242-243`'s claim that the release "credits the pool only when the preserved Bridge has authenticated the message" names no authentication of the credit itself, so the pool could equally be credited by a call that no Bridge context authenticates. Affects D-8, R13, L1-11, ECON-02 clause 7, MSG-02.

**Evidence.** `07:218-267`; `04:353-378`, `04:631-647`; `Bridge.sol:217-255, 242, 286-298, 329-331, 344-349, 367-400, 566-597, 701-715`; grep of the whole specification tree for `onMessageInvocation`: 0 matches. **Sub-point (fee accounting).** `07:240-242` says "the Bridge's message fee is charged against the swept amount", but the preserved rule is `value + fee == msg.value` (`Bridge.sol:242`): the fee is an *additional* ETH amount supplied by the sender, so either the vault must send `value = balance − fee` (unstated, and the vault cannot know the fee without computing it) or the caller pays the fee out of pocket (contradicting "the caller chooses only when"). The same clause's "L1 release cost is part of C_bridge_ops" does not say who pays the relayer that must process the message, and with `fee == 0` a relayer is unpaid (`Bridge.sol:367-398`), so the sweep can sit `NEW` indefinitely with no failure status and no rule-legal remedy.

---

### R4-PB-02 — High — `configHash` has no specified preimage and its inputs are not in the witness: the anti-configuration-substitution binding and the D-7 recovery-parameter binding are vacuous

**One-line rationale.** PRF-04(viii) requires the guest to hash "the configuration values it reads from the witness (epoch schedule, quorum predicate, DA-mode rules, parameter version and the recovery parameters)" to the journal's `configHash`, but no rule anywhere defines the encoding of that hash or the exact value list, PRF-03's witness enumeration does not contain those values, and L1-05 row 23 makes the contract read a *stored* value — so the natural implementation echoes the public input, exactly the "the caller passed it" binding PRF-13 forbids.

**Exact rule / missing rule.**
- `05:106-111` (journal field): "`configHash`; // consensus-relevant config commitment: binds the exact configuration under which the batch was certified and executed (epoch schedule and L, quorum predicate, DA-mode rules, parameter version and the recovery parameters)".
- `05:177-188` (PRF-02(5)): "`configHash` and `recoveryGeneration` are read by the L1 contract from its own storage … and are never supplied by the prover".
- `05:273-283` (PRF-04(viii)): "It MUST likewise bind `configHash`: the configuration values **it reads from the witness** … MUST hash to the journal's `configHash`, so a proof made under a different configuration cannot stand as this batch's."
- `05:217-232` (PRF-03): the witness contents are exactly (a)–(f); no configuration value is listed, and no `configHash` preimage appears in PRF-04's clause list.
- `04:156` (L1-05 row 23): provenance "**L1-derived (Inbox storage) → public input**"; "Commitment to the consensus-relevant configuration the guest applied (epoch schedule, quorum form, limits)". No construction is given on this page either.
- Missing rule: the canonical `abi.encode` preimage (domain tag, field list and types, ordering, the parameter-version encoding), where the guest obtains each value, and which of PRF-02/PRF-04/L1-05 owns the derivation. A grep of `spec/` for `configHash` returns ten occurrences and no construction.

**Assumptions and preconditions.** A verifier route is registered for the batch's epoch (L1-09); the prover controls the journal it produces; the guest program follows PRF-04 as written. No attacker and no assumption failure are needed.

**Concrete attack trace / worked reading.**
1. A recovery, or any consensus-relevant configuration change (a new epoch length, a changed quorum form, new recovery parameters), is deployed by upgrade; the Inbox's stored `configHash` changes to `C2`.
2. A prover that holds a certificate and execution evidence accepted under the old configuration `C1` runs the guest. Because the preimage is undefined and the guest has no way to derive `C2` from L1, the only implementable behaviour is to take `configHash` from the (attacker-chosen) journal, or from a host hint, and echo it. The journal then carries `C2` while the evidence is `C1`-shaped.
3. The contract derives `C2` from storage, hashes the same vector, the statement hash matches, the verifier returns true, and the checkpoint advances. The one value that exists to make "a proof made under a different configuration cannot stand" TRUE has certified nothing.
4. The mirror failure: two backends that each invent a different preimage produce different journals for the same batch, so a proof is not portable and, depending on the mismatch, no honest proof verifies (R7's "both backends realise the same statement", PRF-09).

**Inside/outside the claimed fault model.** Inside: structural, no adversary and no assumption failure required. The load-bearing claim "execution validity alone is never sufficient" (PRF-02(6)) is exactly what the gap weakens, because the configuration and (with R4A-01) the generation are the only inputs that distinguish a pre-recovery proof from a post-recovery one.

**Attacker resources and cost.** One landing transaction if the attacker already holds a proof; otherwise the ordinary cost of one proof. No stake.

**Harm and the exact requirement or fixed decision affected.** R7 ("complete proof statement"), R8 (public values bound to the proof), R13 (implementable without inventing rules), PRF-13 (bindings cryptographically enforced), PRF-09 (one byte-identical statement across backends), PRF-02's "single authoritative public-input vector" claim, and D-7's requirement that the statement carry "the configuration under which the batch was certified". The `recoveryGeneration` half of PRF-02(5) is separately attacked by the concurrent consensus review (R4A-01); this finding is the `configHash` half and is not the same defect.

**Evidence.** `05:106-111, 177-188, 273-283, 217-232`; `04:156, 195`; grep `configHash` in `spec/`: 10 matches, none a preimage; grep in `spec/03-membership-staking.html`/`spec/02-consensus.html`: 0 matches.

---

### R4-PB-03 — High — "the recorded allocation policy" is defined nowhere, and ECON-02(5)(d)'s pool identity omits the proving-share outflow, so one inflow can be allocated twice

**One-line rationale.** The rule that fixes `Alloc(e)` and the proving share is cited as an existing authority in five places but is never defined, while the pool's conservation equation counts only validator payouts as outflows; an implementation must invent the split, the ordering and the reconciliation, and the identity as written is false whenever the policy assigns any proving share.

**Exact rule / missing rule.**
- `07:167-205` (ECON-02(5)(d)): "`pool_after(e) = pool_before(e) + inflow(e) − Σ_{v ∈ P(e)} payout(v,e)`", "`Σ_v payout(v,e) ≤ Alloc(e) ≤ pool_before(e)`", "Alloc(e) MUST be fixed before the epoch's first claim and MUST NOT exceed the pool's realised net inflow for the period".
- `07:206-211` (ECON-02(5)(e)): "The mechanism that moves L2 fee revenue to the L1 pool is clause 7, and **the allocation policy is recorded with it**." Clause 7 (`07:218-267`) contains no allocation policy.
- `04:353-355` (L1-11): the prover ledger's inflow (ii) is, "where the recorded allocation policy assigns a proving share of the reward pool of ECON-02 clause 5(a), exactly that share, credited by a permissionless transfer that debits the pool in the same transaction"; `04:369-376`: "the only credit this ledger may receive from the pool is the proving share of the recorded allocation policy, debited from the pool in the same transaction".
- `09:121, 1016` register `Alloc(e)` against "the recorded allocation policy" and give no owner for the policy itself.
- Missing rules: (a) what the allocation policy is, where it is recorded, who fixes it and by what procedure it changes; (b) whether `Alloc(e)` is gross or net of the proving share; (c) who may trigger the pool→Inbox transfer, how much it may move per call, and that it is once per allocation; (d) the reconciliation between the proving share and the validator payout identity.

**Assumptions and preconditions.** The recorded policy assigns a non-zero proving share (the only specified way for the Inbox's prover ledger to receive pool funds besides `msg.value`, so a launch with any prover reward at all). Landing is permissionless; claims open after `evidenceClose(e)`.

**Concrete attack trace / worked counterexample.**
1. A period's sweep delivers `inflow(e) = 100 ETH`. The (undefined) policy assigns `Alloc(e) = 100 ETH` to the epoch's validators and "a proving share" of 20%.
2. A permissionless caller — the rule says "a permissionless transfer" with no gate — calls the pool→Inbox transfer for 20 ETH. The pool now holds 80.
3. If the validator claim's implementation evaluates `pool_before(e)` at the pre-transfer balance, the identity `Σ payout ≤ Alloc ≤ pool_before` passes numerically for claims up to 100 while only 80 exists: the last 20 ETH of claims revert (validators unpaid) or the contract pays out other epochs' funds. If it evaluates `pool_before(e)` at claim time, `Alloc(e) = 100 > pool_before(e) = 80` and **every** claim reverts, permanently until a later sweep arrives. Either way the same 100 ETH inflow has been promised twice, and the resolution (reserve the share, net `Alloc`, forbid the transfer until claims close, or order them) is left to the implementer.
4. A repeat-call variant: because no rule makes the transfer one-shot, an implementation that recomputes "the proving share of the pool" per call lets a caller move the share repeatedly into the Inbox ledger, where it can only leave to a lander holding a valid proof — a griefing drain that strands validator payouts; the safe one-shot form is an invention, not a rule.

**Inside/outside the claimed fault model.** Inside: no attacker is required for step 3 — the ordering is unspecified and either resolution is a live implementation choice; step 4 needs only the permissionless caller the rule creates. No assumption failure.

**Attacker resources and cost.** One L1 transaction for the transfer or the first claim; no stake, no bond. Benefit: up to `Alloc(e)` of ETH per epoch diverted from validators, or a denial of their claims.

**Harm and the exact requirement or fixed decision affected.** D-8's "single reward pool" and the funding identity; ECON-02(1) (`rewards_ETH ≤ F_exec + F_priority + POOL_TOPUP − …`), ECON-02(5)(d)'s checked identity, L1-11's "one reward-related ledger … MUST NOT be presented as a second destination"; R11 (objective reward/collateral accounting); R13. The same un-owned policy also fixes the split between the two security budgets, so it is not a cosmetic gap.

**Evidence.** `07:142-217` (esp. 167-211), `07:218-267`, `07:990, 1016`, `04:353-378`, `09:121`; grep "allocation policy"/"proving share" across `spec/`: 8 matches, no definition.

---

### R4-PB-04 — Medium — the reporter-bounty bound still cannot be satisfied by the constant split ECON-06(2) mandates; the register now states the impossibility but the rule page still requires the mechanism

**One-line rationale.** ECON-06(2) fixes a single deployment-wide `reporterBountyPpm < 1_000_000` whose shares sum to 1,000,000 ppm, while ECON-06(5) requires the total bounty for an identity to be strictly below `c(f(e,c))·SlashBase(v,e)` "for every offence class and every realised f"; 09-parameter's own row now says no constant split can satisfy that, so the normative pages contradict the register, and the first bound (unnecessary for D-9's stated purpose) makes the lawful bounty smaller than the gas cost of reporting for every small implicated fraction.

**Exact rule / missing rule.**
- `07:484-500` (ECON-06(2)): "Interface sketch (not compiled): `treasury()` … and `reporterBountyPpm() returns (uint16)` with `reporterBountyPpm < 1_000_000`, and `slashDestination()` … the shares sum to 1_000_000 ppm with the remainder to the treasury".
- `07:514-534` (ECON-06(5)): "`REPORTER_BOUNTY(id) < c(f(e,c)) · SlashBase(v,e) ≤ P(v,e)`" and "`REPORTER_BOUNTY(id) < charge(id) ≤ IMM_FRAC(c)·SlashBase(v,e) + c(f(e,c))·SlashBase(v,e)`"; "it must hold for every offence class and every realised `f`".
- `07:428-440` (ECON-05(2)): `c(f) = min((f/F_SAT)^CORR_Q, 1)`, `f = Σ_{v∈O} SlashBase(v,e) / TotalVP(e)`.
- `09:122`: "for a fixed integer split with a constant `reporterPpm > 0` … the required bound is against `c(f) · SlashBase(v,e)`, which can be arbitrarily smaller — so **no constant split satisfies the bound for every realised `f`**", tagged "derived bound, unmeasured value / **Open**"; `10:244` discloses the same in LIM-01. The defect class is round 3's R3-CE-04; D-9's rewrite kept the mandated ppm interface and the over-strong first bound, so it is still live.
- Missing rule: either delete the first inequality (self-reporting non-profitability follows from `< charge(id)` alone, which a ppm split satisfies by construction) or replace the interface with a per-identity cap computed from the realised correlated component, and state when the payment is made so the cap is computable (the immediate component is debited at `slash()`, but `f` is not final until `evidenceClose(e)`).

**Assumptions and preconditions.** One offender not yet at the `SlashBase` cap; `CORR_Q` either value; a report submitted inside the evidence window. No attacker needs to act — the arithmetic is the defect.

**Concrete derivation / worked numbers.** For a single offender with `SlashBase = b` in a set of `N` equal entries, `f = 1/N` and `c = min((3/N)^Q, 1)`. With `N = 10,000` and `Q = 2`, `c ≈ 9·10^-8`; with `Q = 1`, `c ≈ 3·10^-4`. A constant split pays `ppm · charge` with `charge ≥ IMM_FRAC · b`, so the first bound requires `ppm < c / (IMM_FRAC + c)` — at `IMM_FRAC = 0.05` this is ≈ 2·10^-5 (≈ 20 ppm) at `Q = 1` and ≈ 2·10^-6 (≈ 2 ppm) at `Q = 2`. On any `b` for which the penalty is worth enforcing, the lawful bounty is far below the L1 gas of submitting evidence, so the "detection is self-enforcing" claim of `07:504` fails precisely for single-validator equivocation in a large set. The second inequality alone leaves self-reporting strictly unprofitable for every offence class and every stake size (`offender pays charge, receives < charge, plus gas`), which is what D-9 requires.

**Inside/outside the claimed fault model.** Inside (structural; no adversary, and the register already concedes the arithmetic).

**Attacker resources and cost.** Not an attack; the harm is that the sanctioned detection incentive is unusable in the regime the penalty exists for, and that two normative documents contradict each other.

**Harm and the exact requirement or fixed decision affected.** D-9's "reporter bounty … strictly less than the total penalty so that self-reporting is never profitable" is satisfiable only through the second inequality, while the text as written demands the unsatisfiable first; R11 (objective misconduct evidence and payouts), ECON-06(2)/(5), ECON-05(6) (the deterrence claim), `10:244`. Medium because the hard decision is reachable by deleting the first bound; the rule as written is not.

**Evidence.** `07:421-471, 473-550`; `09:122`; `10:244`; `iterations/raw/round3-compliance-economics.md:240-284` (R3-CE-04, same defect class, still recorded Open).

---

### R4-PB-05 — Medium — L1-05 row 18's Fiat–Shamir transcript ("rows 1–17") contradicts DA-03(iii)/PRF-07(b)(ii)'s "whole public-input vector", and after D-7 the excluded set includes `blobHashesHash` and all four new fields

**One-line rationale.** The blob binding's soundness argument names `blobHashesHash` as a transcript input and PRF-07 says the challenge is derived from the whole journal, while L1-05 row 18 tells the contract to recompute `z_i` "from rows 1–17 (excluding the challenges)" — a subset that, after rows 21–31 were added, omits `blobHashesHash` (row 24), `configHash` (23), `signerBitmap` (25), `domain` (26), rows 27–30 and `recoveryGeneration` (31), so contract-side and guest-side `z_i` cannot agree unless one of the two normative texts is ignored.

**Exact rule / missing rule.**
- `04:152` (L1-05 row 18): "`z_i = …`, **recomputed by the contract from rows 1–17 (excluding the challenges)** per DA-03(iii)".
- `04:454-458` (DA-03(iii), the owner rule for the formula): "`statementCoreHash` the hash of the **whole PRF-02 public-input vector** except the two challenge fields … so the transcript covers `daMode`, `feeRecipient`, `configHash`, `blobHashesHash`, `signerBitmap` and every other input".
- `05:326-332` (PRF-07(b)(ii)): the same full-vector definition; `05:344-347` (b)(v): the guest recomputes `dataCommitment` and requires `p_D(z_i) = y_i`.
- Missing rule: one statement of the transcript, and the removal of the stale parenthetical (it was written when the table ended at row 19).

**Assumptions and preconditions.** Blob path (`daMode = 2` or `3`), which is the path for the data volumes the design targets; the blob path is an implementation gate, but the construction is normative for both backends (PRF-09).

**Concrete trace / reading.**
1. An implementer follows row 18 literally and computes `statementCoreHash` over rows 1–17 only. The guest follows PRF-07(b)(ii) and hashes the whole journal. The two `z_i` differ, the contract's KZG opening check runs at a different point than the guest's in-guest evaluation, and **every honest blob-path batch fails to land** (`BlobOpeningFailed`, or a verification failure): a liveness break with the calldata path as the only fallback.
2. The reverse reading (contract over the whole vector) leaves row 18 false and, worse, leaves the status of the excluded fields undefined: a field that is outside the transcript is not committed by the challenge derivation, so the "the challenge moves whenever the committed bytes move" argument of `04:458-460` must be re-derived from `dataCommitment` alone — which it survives, but the rule text no longer says which fields are in and which are out of the transcript the argument uses.

**Inside/outside the claimed fault model.** Inside (structural; no adversary needed).

**Attacker resources and cost.** None for the defect; the exploit version would require an implementation that follows one text while the reviewer's argument assumes the other.

**Harm and the exact requirement or fixed decision affected.** R8 (public data bound to the proof), R9/D5 liveness of the blob path, R13, DA-03(iii), PRF-07(b), PRF-09 (two backends, one statement). Medium: the owner rule DA-03(iii) is correct, so a careful implementer resolves it; but two normative statements on one page cannot both be implemented.

**Evidence.** `04:152, 454-460`; `05:326-332, 344-347`; `09:59-65` (blob capacity targets).

---

### R4-PB-06 — Medium — `setVersion` and `setVersionBlock` are declared L1-derived "from the staking contract", but MEM-09(2)'s stored per-epoch tuple does not contain them

**One-line rationale.** L1-05 rows 27–28 and PRF-02(4) require the Inbox to read the set version `k` and `N(k)` from the staking contract's own state, while MEM-09(2) fixes that state as `epoch → (setRoot, totalVotingPower, rootCommittedAt)` — no version and no snapshot block — so the derivation the R3A-04 fix relies on must be invented, and the wrong invention accepts a submitter/witness value for the pair the opening block's `set_version_commit` is supposed to be checked against.

**Exact rule / missing rule.**
- `04:160-161` (L1-05 rows 27–28): "`setVersion` … Read by the contract from the staking contract's own state, never from the submitter"; "`setVersionBlock` … `N(setVersion(epoch))`, the L1 block number of the `commitSet()` call whose state produced that mapping entry (MEM-09(2)); **read from the staking contract, never submitter-supplied**".
- `03:469-473` (MEM-09(2)): "The L1 staking contract stores the append-only mapping `epoch → (setRoot, totalVotingPower, rootCommittedAt)`. `mapping[e]` is the validator set of epoch `e`: `setRoot` is `R_k` for the version `k` **recorded by the same L1 transaction** (`setVersion(e)`) …" — the version is asserted to be recorded, but the tuple that the rule declares is the mapping's contents does not carry it, and no rule says where `N(k)` lives.
- `05:176` (PRF-02(4)): "`setVersion`, `setVersionBlock`, `anchorSetRoot` and `anchorSetTotalVotingPower` are read by the L1 contract from the staking contract's per-epoch mapping … and are never supplied by the prover".
- `04:199-200` (§2.1): the same claim repeated as a reconciliation line.
- Missing rule: the storage that makes `(setVersion(e), N(setVersion(e)))` L1-derived (a per-version record, or the pair appended to the per-epoch entry), and the amendment of MEM-09(2)'s declared tuple.

**Assumptions and preconditions.** Any batch that opens an epoch (the anchor case of PRF-05(ii)); the epoch's entry exists. No adversary is needed.

**Concrete trace / reading.** An implementer must satisfy rows 27–28. Two options exist and only one is safe: (a) extend the staking contract with a `k → (N(k), root, total)` record and an `epoch → k` field — a storage change the specification does not describe and MEM-09(2)'s tuple text contradicts; or (b) accept the pair from `LandInput` and check it in-guest against the opening header's `set_version_commit` — which is witness-internal (the header is authenticated by the head certificate, but nothing L1-pinned ties `(k, N(k))` to the root the contract read from `mapping[e]`). Under (b), the header-chain check that review round 3's R3A-04 fix added verifies a value against itself, and the journal's `setVersion`/`setVersionBlock` are effectively caller-chosen — a PRF-13 failure at the exact point the fix was meant to close.

**Inside/outside the claimed fault model.** Inside: structural; a permissionless lander benefits.

**Attacker resources and cost.** One landing transaction; no stake.

**Harm and the exact requirement or fixed decision affected.** R13 (an implementer must invent the storage/derivation), PRF-13, PRF-02(4), L1-05 rows 27–28, MEM-09(2); the L1-05 half of round-3 finding R3A-04 is therefore not closed (its journal half is: the fields exist and §2.1 maps them).

**Evidence.** `04:160-161, 199-200`; `05:176`; `03:448-504` (esp. 450, 469-473, 662); grep `setVersion` in `03`: the only storage description is the three-field tuple.

---

### R4-PB-07 — Medium — the correlated penalty's collection and its bounty recipient are unowned; for a small implicated fraction no lawful bounty covers the call, so the component ECON-05 designates as the deterrent can go uncollected

**One-line rationale.** ECON-05(5) makes the correlated component applicable by a permissionless `applyCorrelated(e, c)` call, ECON-06(3)/(5) imply a bounty is dispatched when that call runs, but no rule names the caller's reward or its recipient, and the bounty is bounded strictly below the very amount the call collects (`c(f)·SlashBase`), so for a small offender the call costs more gas than any conforming payment.

**Exact rule / missing rule.**
- `07:447-453` (ECON-05(5)): "the correlated component is computed once at `corrApplyAt(e,c) = evidenceClose(e) + CORR_DELAY` and debited by a permissionless `applyCorrelated(e, c)` call; until then the amount is locked against the exposure accounting of MEM-06".
- `07:505-507` (ECON-06(3)): "Pending correlated amounts are dispatched only when `applyCorrelated()` debits them (ECON-05 clause 5); a bounty is paid once per applied offence identity".
- `07:529-531` (ECON-06(5)): "The bound applies to the total of every bounty paid for that identity, including any bounty dispatched when `applyCorrelated()` runs (clause 3)", where the bound is `< c(f(e,c))·SlashBase(v,e)`.
- `07:484-493` (ECON-06(2)) names `reporterSink` in the destination interface but never ties it to the correlated dispatch; `03:336-360` (MEM-06) defines the exposure the pending amount blocks, and the only stated way to clear it is the `applyCorrelated` debit (`07:670-673`, `03:296-298`).
- Missing rules: the recipient of the correlated-dispatch bounty (the original reporter? the caller? a sink?), what happens if the call is never made, and who is obliged or paid to make it.

**Assumptions and preconditions.** A proven offence with an applied identity (so a pending correlated amount exists); `CORR_Q` and `IMM_FRAC` at any values; a rational offender with `charge ≈ bonded` in the small-`f` regime. No Byzantine threshold is crossed; the offenders here are exactly the below-threshold Byzantine validators the penalty targets.

**Concrete attack trace.**
1. Validator `v` equivocates once in a large set; the immediate component is debited at `slash()` and `v`'s pending correlated amount is locked. `f(e,c) = SlashBase/TotalVP` is small, so `c(f)·SlashBase` is tiny (see R4-PB-04's arithmetic: ≈ 9·10^-8·b at `N = 10,000`, `Q = 2`).
2. Nobody calls `applyCorrelated`: the offender will not (the charge plus gas exceeds the residual value it would unlock when `charge ≈ bonded`), and a rational third party will not because the maximum lawful bounty is strictly below `c(f)·SlashBase`, which is below the L1 gas of the call.
3. The correlated component is never debited: the treasury never receives it, the bounty is never paid, and the rule "the correlated component is the deterrent" (`09:137`, ECON-05(6)) is enforced only as a permanent lock on an untransferable bonded balance — the protocol's own accounting shows the stake still bonded and never collects the charge. The exposure state has no rule-legal terminator other than the call nobody is paid to make.
4. For a large `f` the bounty becomes worth collecting, which is exactly backwards: collection is incentivised only after the attack has already passed the safety threshold.

**Inside/outside the claimed fault model.** Inside: an offender simply omits a permissionless call; omission is neither observable nor punishable under ECON-04's closed catalogue. No assumption failure.

**Attacker resources and cost.** Zero; the benefit is the uncollected charge (up to `SlashBase` per epoch per offender) at the cost of the offender's own locked residual, which it abandons only when the charge approaches the balance.

**Harm and the exact requirement or fixed decision affected.** ECON-05(2)'s confiscation-at-`F_SAT` claim and ECON-05(6)'s premise ("confiscation is possible only while … the exposure accounting of MEM-06 is enforced"), ECON-06's treasury destination and bounty rule, R11 (objective penalties and payouts), R13 (an implementer must invent the recipient). Medium rather than High because the bonded balance is non-transferable, so the offender's *economic* loss largely survives as a lockup; what fails is the protocol's collection and its destination.

**Evidence.** `07:421-471, 473-550, 670-673`; `03:296-298, 336-360`; `09:122, 137`; grep `applyCorrelated` in `spec/`: 5 matches, none naming a payer or a recipient.

---

### R4-PB-08 — Medium — the normative L2 fee-routing rule has no enforcement point: a proposer can divert its block's fees with no invalidation, no offence and no proof check

**One-line rationale.** ECON-02(7)(a) makes it a MUST that both fee components route to the vault, but the rule's only stated consequence of diversion is that the diverted amount "is not collected revenue"; the closed offence catalogue has no diversion offence, the proposal-validity conditions do not include it, and the proof statement's execution check does not verify the fee policy, so the security budget's *collection* rule is unenforced.

**Exact rule / missing rule.**
- `07:219-228` (ECON-02(7)(a)): "The L2 fee policy **MUST** route both components to this vault; a component that is destroyed, paid to a block beneficiary, or otherwise diverted is not collected revenue, **MUST NOT** be counted in clause 1, and **MUST NOT** be promised as a reward."
- `07:348-382` (ECON-04): the offence catalogue is closed and contains equivocation, the same-`(H,R)` lock pair, and invalid evidence only; "Behaviour not listed, however suspicious, consumes nothing."
- `05:296-306` (PRF-06): the guest executes blocks "under the L2 execution rules" and checks state roots; no rule makes the fee policy part of the guest's block-validity predicate.
- `02-consensus.html` CONS-01 (proposal validity) is not amended for the fee policy; no rule states who checks the routing or what happens to a block that diverts.
- Missing rule: the enforcement point (proposal-validity condition, execution-rule check in the guest, and/or an objectively provable offence) and the consequence for a diverting proposer.

**Assumptions and preconditions.** A proposer is selected (ordinary operation). The fee routing is visible in the block's state transition; the diversion is detectable by anyone re-executing, but no rule converts detection into rejection or penalty.

**Concrete attack trace.**
1. A proposer (or a coalition of proposers over its slots) routes the block's base and priority fees to itself instead of the vault — the block otherwise satisfies CONS-01's stated conditions and its execution is valid.
2. Honest validators have no rule to reject it; the certificate forms; the proof verifies the executed transition (the guest checks the transactions root and the state root, not the destination of the fees).
3. The vault receives less; the pool's inflow falls; `Alloc(e)` and the proving share fall with it, and no penalty applies to the proposer. Under D-8 this is the protocol's only funding path, so a majority-of-slots coalition can drive the security budget toward zero while the honest statement "security is funded from L2 fees" remains nominally true.
4. A single diversion is undetectable in the accepting transaction: L1-07's checkpoint record carries no fee data, and no event or evidence object is specified for the routing.

**Inside/outside the claimed fault model.** Inside: proposers are permissionless and the offence catalogue deliberately punishes only objectively provable acts; no assumption failure is required for a proposer to act in its own interest.

**Attacker resources and cost.** One slot's block production; no stake beyond the ordinary validator bond, and no penalty is specified.

**Harm and the exact requirement or fixed decision affected.** D-8 (security funded from L2 fees), ECON-02(1)/(7)(a), R11's deterrence; R13. Medium: the honest consequence is stated, but a normative MUST with no enforcement, no evidence object and no owning rule is an implementable-rule gap at the funding path's source.

**Evidence.** `07:219-228, 348-382`; `05:296-306`; `02-consensus.html` CONS-01; grep "fee" in the offence catalogue: no row.

---

### R4-PB-09 — Low — ECON-06(1) says the treasury is "recorded in DECISIONS.md and in the launch record", but D-9 records no address and no rule defines the launch record

**One-line rationale.** The penalty destination is a fixed address by rule, and the rule's own provenance is false in this snapshot: `DECISIONS.md` D-9 names no treasury address, and "the launch record" is used in `07:476-480` and `04:220` without a definition or a rule requiring the entry.

**Exact rule / missing rule.** `07:474-483` (ECON-06(1)): "The treasury is **one fixed address**, recorded in `DECISIONS.md` and in the launch record before it can receive anything (today the repository records `TAIKO_FOUNDATION_TREASURY` `0x363e…3Da` as a hard-coded non-voting holder … and the launch record MUST name exactly one address)". The only decision entry (D-9, `DECISIONS.md:286-290`) says "The penalty destination is the protocol treasury" and records no address; `04:220` requires the vault address to be "recorded before launch" without saying where or by which rule.
**Assumptions / preconditions.** None; structural.
**Attack trace.** N/A (citation/registration defect). The concrete harm is that two of the deployment's fixed constants (the treasury and the fee vault) have no rule-level registration point, so the "fixed address" claim rests on an unversioned document.
**Inside/outside.** N/A. **Resources/cost.** None.
**Harm and the exact requirement or fixed decision affected.** R13/GEN-03 registration discipline; ECON-06(1); D-9's "recorded before it can receive anything". Low: no attacker and no economic consequence if an implementer records the addresses anyway.
**Evidence.** `07:474-483`; `DECISIONS.md:286-290`; `04:219-221`.

---

## Checked and holding (not findings)

1. **Journal ↔ L1-05 field-for-field agreement after the new fields.** Extracted mechanically: the PRF-02 journal block (`05:73-152`) has 30 fields; L1-05 has 30 rows (1–19, 21–31), of which row 2 is the single L1-local value that is not a public input and row 20 is vacant and not reused; the reverse list (`04:205`) names all 30. The two new D-7 fields (`configHash` row 23, `recoveryGeneration` row 31) and the epoch-transition fields (rows 27–30) each have a row and a §2.1 line. The *lists* agree; the failures are in the derivations (R4-PB-02, R4-PB-06) and the transcript subset (R4-PB-05).
2. **`recoveryGeneration` is bound to the proof by `statementHash`.** The contract derives it from its own storage, hashes the whole vector, and passes only the hash to the verifier; a stale-generation proof produces a different statement and cannot verify. The mechanism holds; the substance (the generation is in no signed consensus object) is the concurrent consensus review's R4A-01 and was not re-listed here.
3. **D5 in the recovery path.** REC-02's "D5 is unchanged" row (`06:369`) plus L1-01/L1-02/L1-03: recovery accepts no data, advances no checkpoint, and the sweep is not a batch — its release requires a checkpoint from an accepted data+proof transaction (MSG-03). No data-first path was found in any mode. Holds.
4. **The calldata path.** DA-02's contract-computed `keccak256(_data)` commitment and PRF-07(a)'s in-guest recomputation are an equality, not a probabilistic argument; a submitter-supplied value is ignored or rejected. Holds.
5. **The blob fixed-point argument.** Re-derived with the 30-field journal: `z_i` depends on `dataCommitment = f(keccak(D))` and `blobHashesHash`; the precompile pins `p_B(z_i) = y_i` and `kzg_to_versioned_hash(commitment_i) = vh_i`; the guest pins `p_D(z_i) = y_i` and recomputes `dataCommitment` over all published bytes. The joint event `p_D(z(D)) = p_B(z(D))` is a hash fixed point with the stated `q·2^-243` bound. Holds under the named premises (KZG binding, ROM Fiat–Shamir, canonical field elements, EIP-4844 evaluation-form/bit-reversal convention, in-guest recomputation) — subject to R4-PB-05's transcript-subset contradiction, which is a text defect, not a re-break of the argument.
6. **L1-11's prover-ledger identity.** `rewardPaid = min(REWARD_QUOTE, proverReward_before + msg.value)`; the subtraction cannot underflow; the ledger has one debit path and no second payout route; `REWARD_QUOTE` is now registered (`09:110`). No underflow, double-pay or evasion found in the identity itself (its interaction with the pool is R4-PB-03).
7. **ECON-01 INV-A..D.** One ledger, one asset; ETH rewards are correctly excluded from the stake invariants; `a = min(requested, b(v))`, no debt outside the ledger, per-epoch `SlashBase` retention. Internally consistent.
8. **The "no receivable" claim.** `04:375-378` and `07:244-258`: an unarrived sweep is not a balance, not a receivable and not a promise; the arrival identity counts only ETH that has arrived, and the collection-side inequality is an upper bound. Checked: no rule turns the L2 vault balance into a claim on L1, and the period identity errs conservative. Holds (the funding consequence is the concurrent review's R4-MB-06).
9. **The ETH recovery bond vs D7.** The bond is an anti-spam deposit, not validator stake or slashable consensus collateral, and D-7's own instruction says "ETH-bonded"; the asset choice is conforming. The schedule and custody issues are R4-MB-04/R4-LIV-05/R4A-04 and were not re-listed.
10. **Treasury split mechanics.** ECON-06(2) has no BURN option or share, the remainder goes to the treasury, `reporterPpm < 1_000_000` cannot pay the whole debit, and the destination does not change `P(v,e)`. Holds mechanically (the arithmetic issue is R4-PB-04/R3-CE-04).
11. **Recovery bond destination.** ECON-06(6) and REC-02 agree: full return to the poster on completion, whole debit to the treasury on cancellation, nothing to a reporter, not counted in `rewards_ETH`. Holds.

## Limits of this review

I did not re-prove KZG binding, the ROM, or the Ed25519/header-chain implementation; I did not audit the learning site or the migration slot arithmetic (other angles own those); I did not re-list the round-3 findings recorded open in `iterations/03-round.md` (R3-PRF-04 feeRecipient/timestamp in-guest binding, R3-PRF-05 blob padding, R3-PRF-06 blob range/hybrid equality, R3-PRF-07 exposure cap) or the round-4 sibling findings in `iterations/raw/round4-*.md` (generation tautology, completion entry point, trigger clock, bond schedule, concurrent invocations, empty-pool bootstrap, stale Mode A text), each of which I read and confirmed is a different defect from the ones reported above. All line numbers are from `fe7373a13`; quotes are verbatim modulo whitespace.

## Brief answers

- **Can the fee path be griefed, double-counted, or made to create a receivable?** A receivable, no (checked, holds). Double-counted, yes: the pool identity omits the proving-share outflow and the allocation policy is undefined (R4-PB-03). Griefed and stolen, yes: the L1 leg's custody is decided by unnamed Bridge message fields (R4-PB-01), the collection rule has no enforcement point (R4-PB-08), and the proof-side binding that should have scoped the configuration is vacuous (R4-PB-02).
- **Treasury destination with a bounty strictly below the penalty: is self-reporting unprofitable for every offence and stake size?** Yes, through `REPORTER_BOUNTY(id) < charge(id)` alone, for every class and every stake size. The *first* bound (`< c(f)·SlashBase`) is not jointly satisfiable with the constant ppm split ECON-06(2) mandates (R4-PB-04), and taking it seriously makes the bounty smaller than the gas cost of reporting in the large-set/small-offender case — the case the penalty targets.
- **The ETH recovery bond.** Asset conforming to D-7; return/slash destinations are stated and agree with ECON-06(6); the custody, schedule and concurrency defects are the siblings' findings and were not re-listed.
- **Journal vs L1-05.** Field-for-field agreement holds (30/30, row 2 local, row 20 vacant); the derivations for `configHash` and `(setVersion, setVersionBlock)` are missing (R4-PB-02, R4-PB-06) and row 18's transcript subset contradicts DA-03(iii) (R4-PB-05).
- **Accounting identities.** No underflow or double-pay found in ECON-01 INV-A..D or L1-11; the pool identity (ECON-02(5)(d)) is the one identity that is incomplete, and the correlated penalty's debit is the one collection step with no owner (R4-PB-03, R4-PB-07).
