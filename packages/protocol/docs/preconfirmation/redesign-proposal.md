# Taiko Based Preconfirmation Redesign — Perpetual Auction with Commit → Publish → Seal Epochs

> **Deliverable 2 of the preconfirmation redesign effort. Draft v7, 2026-08-20** — revised after
> adversarial review rounds 1–6 (ten reviewer passes:
> [r1](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5353544928),
> [r2](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5353904484),
> [r3a MiniMax](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354204450),
> [r3b DeepSeek](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354253289),
> [r4a MiniMax](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354402375),
> [r4b DeepSeek](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354409216),
> [r4c multi-pass](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354577413),
> [r5a DeepSeek / r6 DeepSeek](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5355026969)
> — the round-5a/6 bot edits its comment in place, so this anchor shows the latest round —
> and r5b Codex, a [PR review](https://github.com/taikoxyz/taiko-mono/pull/22034#discussion_r3820964313);
> rounds 5–6 reviewed the verification artifact and documentation consistency rather than the
> mechanisms); dispositions in [Appendix B](#appendix-b--review-dispositions) and, for rounds
> 5–6, in [`simulation/RESULTS.md`](simulation/RESULTS.md) and the PR thread. **v7** folds in
> the owner-approved self-review simplification round: a single present-at-`D+κ` acceptance
> rule, a deadline-only seal (the `d` deferral removed), `H_force` retired into the seal
> deadline, one ETH account per tenure with a seniority waterfall, and Total Anarchy's
> discretionary content restored via atomic proof-carrying proposals
> ([Appendix A](#appendix-a--divergence-from-the-brief-owner-to-confirm) #24–28). Design only —
> mechanisms, invariants, incentives, parameters. Baseline: [`status-quo.md`](status-quo.md);
> owner decisions: its §6 and
> [Appendix A](#appendix-a--divergence-from-the-brief-owner-to-confirm).
>
> Prior art (post-whitelist URC design, post-Shasta slashing design, PR #22019) is consciously
> not followed; #22019 is implementation reference only, per the redesign brief.

---

## 0. Core invariants (normative)

- **I1 — Total, bounded, content-addressed derivation; outcome invariant under all L1
  timing.** Derivation maps *any* committed + published bytes to a unique, bounded-cost L2
  block sequence, and its **only** L1-derived input is the EBC's committed content — never any
  transaction's L1 inclusion block.
  - *Content-addressed origin (r4a-C2, r4b-C1).* The EBC **commits its own L1 origin** (the
    anchor block number/hash/state-root it builds on) inside its signed content. Derivation
    reads that committed origin, not the L1 block that happens to include the EBC transaction.
    Byte-identical resubmission after a reorg therefore preserves the origin exactly (the origin
    is a field of the bytes, not of their placement), so the same committed bytes always have
    exactly one canonical outcome — the "shifts *when*, never *what*" property of §3.1 now holds
    by construction for every derivation input, closing the reorg-race that v4's
    inclusion-block origin left open. Neither the EBC's nor the seal's L1 inclusion (block,
    timestamp, sender, packing) is a derivation input; all remaining bounds are epoch-relative
    to `T_N`.
  - *Bounded parse time (r3b, r4a-C4, r4b-M9).* Consensus constants — `MAX_DECOMPRESSED_SIZE`,
    `MAX_RLP_ELEMENTS`, `MAX_RLP_DEPTH`, `MAX_TX_COUNT_PER_SOURCE`, `MAX_PER_TX_SIZE`
    (§3 table) — cap parsing *before allocation*. **The proof circuit is the canonical
    enforcer; the client MUST enforce byte-for-byte identical caps and identical
    degrade-without-allocation behavior** — not looser, not stricter (a divergence would fork
    the chain; siding with r4b over r4a here). Exceeding any cap, or the per-epoch zk-gas cap,
    degrades deterministically to default content without materializing the oversized object.
    (Shasta's existing degradation covers manifest validity but **not** these resource bounds —
    new, required work; §13-S.5.)
  - Consequence: a committed epoch has exactly one canonical outcome, provable by anyone holding
    the data, **regardless of when or in which L1 block anything lands** — late sealing,
    reorged inclusion, and adversarial packing can none of them select a degraded or different
    outcome.
- **I2 — No fault requires the accused; liability is computed state, materialized on read.**
  Liveness faults are objective L1 facts. A fault is **matured** the moment its
  deadline-plus-grace passes with the artifact absent — a pure function of L1 records
  (assignment + deadline + absence), independent of any transaction. The permissionless
  poke (bounty-paid) is only an *accelerator*: it is never a precondition for liability.
  **Every function that reads fault status — withdrawal, EMPTY-PENDING seal, assignment,
  promotion — computes maturity directly from the records and atomically materializes any
  missing certificate as part of the call** (r4a-C3, r3b). In particular **withdrawal reads
  the computed matured set, not the poked set**: a holder that actually missed an obligation
  materializes its own certificate by attempting to withdraw, and the gate then fails; a
  never-poked fault can never clear the gate. Poke-path censorship therefore cannot buy a
  withdrawal — only censorship of the withdrawal transaction *itself*, which merely forces the
  holder to retry (each retry re-materializes) and is out-waited by the ≥2-week floor.
  **Single grace interval** (r4c-2): the deadline is `D`; a byte-identical artifact may be
  (re)submitted until `D + κ`; at `D + κ` **exactly one atomic transition** fires — the
  artifact is present (→ no fault, parent takes the content outcome) or absent (→ fault
  matured, certificate settled, parent takes the empty outcome, slashability fixed) — and
  nothing after `D + κ` can change it. There is no second grace: maturity, settlement,
  parent-state irreversibility, and accepted-artifact-set closure are the *same* moment, so
  effective finality is `D + κ` (not `D + 2κ`) and I4's `Γc + κ` finality bound holds exactly.
- **I3 — Single open epoch, always advanceable.** One canonical `openEpoch`; only a valid
  seal advances it; at every moment a permissionless action exists that can eventually advance
  it (content seal, forced-only seal, empty seal, or the bounded expiry cancellation).
  Unproven material never blocks any of these.
- **I4 — Successor-safe parent.** Epoch N's outcome (content-with-DA or empty) is irreversible
  within `Γc + κ` of its boundary, and every later deadline measures from the moment its
  prerequisite became irreversible (automatic tolling), never from wall-clock while blocked.
- **I5 — Bounded global backlog.** `openEpoch` lagging by more than `K` epochs triggers
  recovery-only mode (no new discretionary content, no fees) until the lag clears. All
  retention, collateral, and prover sizing is dimensioned against `K`, and — corollary — **the
  content-bearing unsealed tail can never exceed ≈ `K + S` epochs**.
- **I6 — Forced inclusions are censorship-proof against the seat.** A non-empty forced
  snapshot makes the epoch's minimum valid outcome the deterministic forced-only epoch,
  constructible and provable by anyone from L1 data alone; empty is then invalid.
- **I7 — Only proven transitions lock state; outcomes are sender-free.** Canonical state
  changes only through proof-carrying seals or the deterministic proof-free resolutions (valid
  empty seal; expiry cancellation), all pure functions of on-chain state. Who sends a
  transaction never affects what the outcome is.
- **I8 — Payees are precommitted, not first-claimers.** Every payment the protocol makes
  (fill/recovery compensation, refund, poke bounty, forced-item fee) goes to a beneficiary
  **cryptographically bound before the witness is disclosed** — for a proof, the payout address
  is a *public input* of the proof (copying the proof from the mempool cannot change it); for a
  poke or fill, the actor pre-registers its beneficiary and the reward pays that registration,
  not `msg.sender` (r4c-4). A searcher who front-runs a copied proof/poke/slice therefore
  advances the chain but **cannot redirect the reward to itself**, which also removes the
  incentive for rational provers to withhold. Additionally, a reward for completing a *duty*
  exists **only when the duty-holder failed it** and is funded by that faulter (§5.2), so there
  is never an honest party being front-run out of a prize.
- **I9 — Deterrence value is oracle-free.** The design uses **no price feeds** (owner
  directive). Deterrence that must *match* an ETH-denominated gain — the equivocation/MEV-theft
  safety slash — is itself **denominated in ETH**, drawn from the safety tranche of the ETH
  account the design already collects (§4); its value needs no oracle because ETH is the
  numéraire (owner assumption:
  ETH stable-to-increasing). Liveness bonds, which deter *delay* rather than *theft*, stay in
  TAIKO (owner's bond-token choice). No mechanism reads a TAIKO/ETH price. (v5; supersedes
  v4's ETH-value floor and closes r4a-C1 / r4b-H3 without an oracle.)
- **Immutability corollary (I3 + I7):** sealed epochs are final; no mechanism in this design —
  including expiry cancellation — ever modifies sealed state.

---

## 1. Motivation and goals

As before (whitelist trust today; URC/validator path blocked twice over — status quo §1):

- **[G1]** Anyone can become the preconfer via a perpetual on-chain auction.
- **[G2]** Slashing from day one, on objective faults (I2).
- **[G3]** Non-validators can reliably act on L1: multi-slot budgets for every mandatory
  action; multi-epoch window for the seal.
- **[G4]** Sealed epochs finalize immediately; no separate prover market; fast withdrawals.
- **[G5]** (v4, per round 3) Two explicitly different degradation endgames:
  - **Phase B (permissionless)**: every failure ends in a state where the chain keeps moving
    (forced-only + heartbeats at minimum) and **anyone can end the degradation by bidding the
    reserve floor** — anarchy is a censorship-resistant fallback, not a sequencing mode.
  - **Phase A (allowlisted)**: the same mechanics, but auction entry is allowlisted, so the
    endgame is **DAO-recoverable, not permissionless** — the DAO commits to a fast-path SLA
    for growing the allowlist (§10.3). This is the stated, accepted price of the training
    wheels.

**G5 is a liveness guarantee, not a user-fund-safety guarantee** (r4a-M12): it promises the
chain keeps advancing, not that no user transaction is ever reverted. An L1 reorg deeper than
`κ` can revert preconf'd (even sealed) L2 state, exactly as on any L2 anchored to L1; `D_anchor`
is sized (32 slots) to make this improbable, not impossible. Users bear this the way they bear
any L1 reorg.

Out of scope for the v1 implementation: per-transaction fair exchange (epoch-level release
*is* enforced — §5); user restitution; multi-seat; based-validator alignment.

---

## 2. Roles, tenures, identities

Roles: seat holder, standby bidders (bonded, auto-promoted, binding), observers, users,
treasury/DAO, L2 nodes — as v3.

**Tenures**: immutable id binding holder, registered proposer/commitment keys (append-only
history retained for the whole obligation tail), assigned epochs, reserved collateral. Every
artifact binds `(chain id, tenure id, epoch, acting role)`.

**Fault identity**: stable logical id `H(originChainId, tenureId, epoch, faultClass,
position)`; versioned routing (fork/domain, mode, envelope) separately domain-separated;
persistent consumed-set keyed on the logical id, entered only at certificate *settlement*
(I2).

---

## 3. Time structure

`E = 384 s`; epoch `N` = `[T_N, T_N + E)`.

```text
sequencing [T_N ─────────────── T_N+E)   preconfs stream over P2P; blob slices stream to L1 DURING the epoch
commit     by T_N + E + Γc               EBC references its already-posted blobs; valid only if that data is on L1
parent final at T_N + E + Γc + κ         SINGLE atomic decision (I2): content-or-empty, irreversible
seal       due by T_N + S·E (tolled)     one proof-carrying seal finalizes the epoch; valid from
                                         the moment the epoch is the openEpoch with its decision
                                         final — early seals welcome (v7: no deferral lower bound)
```

There is exactly **one** finality decision per epoch, at `T_N + E + Γc + κ` (≈ 7 slots into the
successor's epoch). Publication is not a separate later deadline: the EBC is valid only if the
blob slices it references are already on L1, so data availability is established *at* the EBC and
the only thing the `κ` grace covers is byte-identical re-posting of a slice that was reorged out
in the `[boundary, Γc]` window (§5.2). This removes v6-draft's second `Γb`-based decision (the
audit-flagged inconsistency).

| Param | Meaning | Initial | Notes |
| --- | --- | --- | --- |
| `S` | seal deadline (epochs past `T_N`, tolled) | 4 | v7: deadline-only — replaces v6's `[T_N+d·E, T_N+(d+s)·E)` window (`d,s = 2,2`; same end time). Proving latency needs a deadline, not a ban on early seals: I1 fixes the outcome and I7 makes it sender-free, so sealing early is always valid and strictly shrinks the unsealed tail. §10.1 |
| `q` | auction transition delay (epochs) | 2 | current + next final |
| `Γc` | EBC deadline past boundary | 4 slots | lowered v6 (r4c-3) to shrink the successor's last-look exposure |
| `κ` | reorg grace (also the DA re-post window) | 3 slots | single-grace lifecycle §3.1, I2; parent-final at `Γc+κ = 7 slots` (~22% of the successor epoch), not 27 |
| `D_anchor` | minimum committed-anchor depth | 32 slots (1 epoch) | the EBC-committed anchor must be ≥ this deep at commit time; sized for L1 reorg safety, not "minimum useful" (v5, r4a-C2/H8) — raised from v4's 4 |
| `K` / `K'` | global lag cap / exit | 8 / 4 epochs | recovery-only mode (I5) |
| `K_empty` | max consecutive epochs **without discretionary content** (empty *or* forced-only) | 16 | redefined in v4 (r3a-F7/F10); termination §4 |
| `H_cancel` | published-unsealed **data-loss** cancellation horizon | 10 days | disaster floor only (data genuinely gone); typical stalls resolve at the seal deadline via fault-paid recovery (v7, §6.7). + margin < blob retention (~18 d) for epoch **and forced-queue** data |
| parse-time caps | `MAX_DECOMPRESSED_SIZE` 8 MB, `MAX_RLP_ELEMENTS` 1M, `MAX_RLP_DEPTH` 32, `MAX_TX_COUNT_PER_SOURCE` 100k, `MAX_PER_TX_SIZE` 128 KB | consensus constants | circuit-canonical, client-identical (I1); initial values, §13-S.5 finalizes |
| `L_safety` (ETH) / `L_live` (TAIKO) | safety vs liveness slash | governance | safety in ETH (I9); liveness in TAIKO |

Retention duty (nodes, holder ecosystem, forced-queue data): to `H_cancel` + margin. All
collateral horizons include `κ` and bridge/challenge time.

**The L1 record spine is append-only, not ring-buffered** (r3b): per-epoch records
(assignment, EBC/publication/seal presence + times + actors + mode, certificates) are retained
at least `max(H_cancel, withdrawal floor + challenge horizon + verdict replay, full tenure
obligation tail)` — the current inbox's 3-day proposal ring buffer is *not* a precedent for
them. Paths that depend on a record **fail closed** if it is missing: absence of a record is
never read as absence of a fault. Records are a few storage slots per epoch (~225 epochs/day);
old records beyond the horizon may be compacted behind a commitment, a §13-S design item.

### 3.1 Certificate lifecycle and reorg grace (I2; r3a-F8/F12)

Deadline artifacts are judged at deadline + `κ`; within the grace, resubmission is
**byte-identical only** (EBC one-shot; slices hash-bound; seal deterministic), so outcomes are
monotone — resubmission shifts *when*, never *what*. Because the EBC commits its own origin
(I1), a reorged-and-resubmitted EBC carries the identical origin into whichever L1 block finally
includes it — the derivation outcome does not depend on that block at all, which is what makes
"shifts when, never what" hold for the *origin* and not only the content (r4b-C1).

**One grace, one atomic decision — and one acceptance rule** (r4c-2; v7). Each deadline `D`
(the EBC at `T_N+E+Γc`, and each seal deadline) is judged by **presence at `D + κ`, full stop**:
a *first* submission landing anywhere in `(D, D + κ]` is exactly as valid as one landing by `D`.
One-shot-ness is the only constraint — the first-landed artifact wins, byte-identical re-lands
are no-ops, and any second *distinct* artifact is invalid. So the honest submission budget for
every deadline artifact is the full `D + κ` span (`Γc + κ = 7` slots for the EBC — G3), while
the moment the world learns the outcome is unchanged (`D + κ` was already the earliest a
successor could rely on the artifact set, since a reorged copy may reappear until then). At
`D + κ` a single transition fires and is irreversible: present ⇒ accepted, absent ⇒ certificate
settled + parent outcome fixed + `L_slash` debitable. There is no "pending, then a second κ": maturity,
settlement, parent-state irreversibility, and artifact-set closure coincide, so a byte-identical
artifact arriving after `D + κ` is rejected (it cannot revive content or clear a settled slash),
and I4's `Γc + κ` finality bound is exact rather than `2κ`-loose. Withdrawal gating counts
settled certificates and computes any not-yet-materialized maturity at read time (I2). Reorgs
deeper than `κ` are an exceptional L1-consensus event bound to a finalized origin root + a
certificate *incarnation* number (r4c-8): all records are L1 state, so `openEpoch`, certificates,
and artifacts rewind together and a stale pre-reorg verdict fails the incarnation check even if
its logical id looks unconsumed; joint-rewind semantics are §13-S.1.

---

## 4. The perpetual auction (L1)

As v3 (bid = TAIKO bond + ETH fee rate + ETH deposit; ≥10% increment; reserve floor;
`q`-delayed transitions with current+next final; funding rule as automatic quit notice), with
v4+ changes:

- **One ETH account per tenure, one seniority waterfall (v7).** All ETH a tenure posts lives in
  a **single account** with three seniority tranches, replacing the separately named
  prepaid-ETH balance, safety bond, senior recovery reserve, and pool slice of v5/v6:
  1. **Recovery tranche** (most senior) — sized to the tenure's worst-case `K` outstanding
     recovery obligations at indexed cost caps; pays fault-paid resolutions of *this tenure's*
     faults (§7.3) and the cancellation-cascade charge (§6.7).
  2. **Safety tranche `L_safety`** — the equivocation/MEV-theft slash (I9), value-fixed in ETH
     from tenure start.
  3. **Working tranche** — per-epoch fees, fill-reward funding (§5.2), poke bounties, refunds.
  A debit takes from the tranche that owes it, never above it; **admission requires the account
  to cover tranches 1 + 2 plus a working floor** — one solvency invariant replacing the
  per-object sizing rules — and the shared residual pool (§7.3) is a protocol-level account
  funded by a small admission tithe, not an earmark inside anyone's balance. No amount or
  incentive changes; what changes is that **every wei has exactly one job**, closing the
  double-earmarking ambiguity rounds 4–6 kept probing.

- **Split bond, oracle-free** (I9; r4a-C1, r4b-H3, r4a-H11): the reservation has two parts,
  neither reading a price feed.
  - **Safety bond `L_safety` in ETH** — the safety tranche of the tenure's single ETH account
    (v7 waterfall above), sized to exceed per-epoch extractable MEV. It backs the equivocation/safety slash (the only fault that lets
    a holder *steal* an ETH-denominated gain), so deterrence and gain share the ETH numéraire
    and match without any TAIKO/ETH conversion. A TAIKO price crash cannot cheapen it, and the
    withdraw-after-shorting attack (r4a-H11) evaporates: the debit's *value* is fixed in ETH
    from tenure start, not re-valued at fault time.
  - **Liveness bond `L_live` in TAIKO** (owner's bond-token choice) — backs missed
    commit/publication/seal, which delay the chain but let no one steal MEV. TAIKO-price
    erosion here weakens deterrence against *griefing*, not *theft*; it is bounded by the
    per-fault `L_live` plus termination, adjustable prospectively by governance, and is the
    only residual left to off-chain monitoring (§11.7). This is the narrow, defensible form of
    the "accept the residual" trade — applied to the fault class where value-matching is not
    load-bearing, never to the theft class.
- **Idle exit pays like a quit** (r3a-F6): a tenure terminated via `K_empty` (or that stops
  committing content) keeps its **fee clock running to the epoch a proper quit notice issued
  at first idleness would have reached** (`q` epochs beyond). Idling is never a cheaper exit
  than quitting; promotion of the highest standby (not a reserve-floor re-auction) fills the
  seat where one exists.
- **Future epochs require the *current* reservation** (r4c-7): parameter updates never
  retroactively re-price *already-assigned* epochs, but every *new* epoch assignment — including
  the perpetual incumbent's next one — is gated on the current reservation after its timelock. An
  incumbent who does not top up to a raised reservation is gracefully terminated (its assigned
  tail honored) before more exposure accrues; a no-max-duration tenure can therefore never keep
  serving forever under stale collateral.
- **Termination** on: settled fault certificate, bond below reservation, or `K_empty`
  no-discretionary-content epochs (fee-continuation above; no slash — but see §5.4).
- **One canonical liability ledger** (r3b-F8b): the L1 bond contract is the sole ledger;
  L2 verdicts and every transport only *instruct* it; idempotency (the logical-id
  consumed-set) is enforced exclusively there, at execution.

---

## 5. The per-epoch pipeline: commit → publish → seal

### 5.1 Commit — the epoch-boundary commitment (EBC), over already-published data (v6)

One-shot per (tenure, epoch), due `T_N + E + Γc` (4 slots; accepted until `+κ` under §3.1's
present-at-`D+κ` rule, so the honest budget is the full 7 slots), binding the full ordered
content,
EOP tip, committed L1 origin (I1), and the **hashes of blob slices already posted to L1** — the
holder streams its data to L1 *during* its own sequencing epoch and the EBC references it, rather
than promising to publish later. Consequence (r4c-3): the epoch's **content-or-empty outcome is
decided by the EBC alone**, at `T_N + E + Γc + κ = 7 slots` into the successor's epoch, versus
~27 slots under a separate late-publication deadline. Missing EBC ⇒ EMPTY-PENDING + certificate. Explicit empty EBC: valid, unslashed,
counted against `K_empty`, invalid when the forced snapshot is non-empty (I6). The committed
anchor must be ≥ `D_anchor` (32 slots) deep and satisfy the freshness-and-advancement floor of
§6.6; because the origin is committed *content*, no L1 reorg of the EBC's inclusion changes what
the epoch derives to (I1).

### 5.2 Publish — availability is part of EBC validity, fault-only fill (v6; r3a-F1/F2, r4b-H2)

Publication is **not a separate deadline**: the holder streams blob slices to L1 during its own
epoch, the EBC references them, and **the EBC is valid only if that referenced data is on L1**.
So the epoch's content-or-empty outcome is a single decision at `Γc + κ` (§3): valid EBC with
available data ⇒ content; no valid EBC ⇒ empty. The `κ` grace is the *only* backstop — if a
referenced slice was reorged out in the `[boundary, Γc]` window, any party may re-post the
byte-matching slice within `κ`, keeping the committed outcome alive; nothing new can be
introduced (byte-identical only). This preserves the r4b-H2 rebuttal (a third party cannot fault
an honest holder — it published its own data) and, unlike v6-draft, defines **one** irreversible
decision rather than two.

- **Fill reward exists only in the fault case, funded by the faulter, and the payee is
  precommitted** (I8; r4c-4). A fill reward exists **only** when the holder failed to make its
  own referenced data available, funded from the failing holder's working tranche (§4). The
  reward is
  **not** paid to "whoever submits first": each candidate filler pre-registers a beneficiary
  before disclosing the slice, and the payee is that registration, so a mempool searcher who
  copies the slice cannot capture it (see I8 / §8 for the general precommitted-payee rule that
  also covers seals, recoveries, and pokes). There is no honest party to front-run.

**Successor safety — soft vs hard preconfs** (r4c-3, resolved not deferred). Because parent-final
is now `Γc + κ = 7 slots` into the successor's epoch, the successor sequences its first ~7 slots
as **soft** preconfs (explicitly parent-provisional) and upgrades to **hard** (bond-backed,
equivocation-slashable) preconfs once its parent is final. The predecessor's residual "last-look"
shrinks from ~84% of the successor epoch to ~22%, and — critically — a predecessor that
*published on time* (data referenced by its EBC) has **no** last-look at all: its outcome is
locked by its own EBC, not by a later choice. The remaining ~7-slot soft window is the honest,
bounded characteristic of deferred publication, stated here rather than left open; driving it to
zero (predecessor ends sequencing `Γc+κ` early, ~22% duty-cycle cost) stays a §13-T lever.
- Censoring publication means censoring **every data holder** across the `32`-slot in-epoch
  streaming span plus the `κ`-slot re-post grace — priced in §11.5 as the binding censorship
  target (the chunky artifact), not the seal.
- **No valid EBC-with-available-data by `Γc + κ`** ⇒ epoch resolves EMPTY-PENDING + certificate
  on the holder at that single decision (I2). Successor soft-preconf exposure is exactly this
  `Γc + κ = 7`-slot window.

### 5.3 Sequencing and preconfirmations

As v3 (P2P envelopes + signed commitments binding tenure/epoch/index/hashes/deadline/EOP;
tenure-registry gossip validation; EOS handover; `handoverSkipSlots` retired).

### 5.4 Epochs without discretionary content are bounded (r3a-F6/F7/F10)

`K_empty` counts **every consecutive epoch in which the holder produced no post-derivation,
non-system, non-self third-party content** — explicit-empty *and* forced-only alike, and (r4c-9)
the count is taken **after** derivation on **non-system output that is not the holder's own
Sybil traffic**, so neither malformed garbage (which totalizes to default/empty — I1) nor a
self/no-op transaction resets it. Consequences: sybil forced-inclusion traffic cannot reset the
counter (F7); a holder cannot squat behind forced-only seals paying only bounties (F10 — a holder
sealing its own assigned forced-only epoch earns no recovery compensation); idling to termination
pays quit-equivalent fees (§4, F6). Forced content always flows (I6). Forced-only fee income to a
single tenure is capped at `K_empty · a_forced`, excess to treasury (r4a-M13).

**Honest caveat** (r4c-9): `K_empty` bounds *how long a seat may go without serving anyone but
itself*, but on-chain the protocol cannot fully distinguish "genuine third-party demand exists
and is censored" from "no demand"; a truly rigorous censorship bound needs a **maximum tenure
duration** (or an equivalent non-Sybil liveness signal). v6 records this as a §13-T decision
(tenure cap vs. accepted residual) rather than claiming `K_empty` alone is a complete
censorship-resistance guarantee.

### 5.5 Seal

One proof-carrying seal finalizes the epoch's canonical outcome (unique and always provable —
I1); acceptance = finality; precomputable proofs (§6.6); one small retryable transaction. v7:
the seal has a **deadline only** — due by `T_N + S·E` on the tolled clock, valid from the
moment the epoch is the `openEpoch` with its decision final. Early sealing is always legal
(I1 fixes *what* it seals, I7 makes it sender-free) and strictly good: it shrinks the unsealed
tail and everyone's preconf exposure. Missing the deadline matures the seal fault (I2), which
both funds and opens fault-paid permissionless resolution (§6.7, §7.3).

---

## 6. The epoch state machine

§6.1 single `openEpoch`, §6.2 lifecycle, §6.3 unbounded permissionless recovery lane, §6.4
empty and forced-only seals, §6.5 forced snapshots, §6.6 epoch-native identity — all as v3,
with these v4/v5 clarifications:

- **§6.4/§6.5 (r3a-F13)**: the forced-only seal's data source is the forced-inclusion
  queue's own L1 blob data; forced-queue retention duty runs to `H_cancel` + margin like epoch
  data. Snapshot items whose blobs have genuinely expired (reachable only through the §6.7
  disaster path) are **voided with their queue fees refundable on L1**, and bridged messages
  they carried remain refundable through the bridge's own unprocessed-message path — a voided
  inclusion never burns user value (r3a-F3.1).
- **Every forced item has one canonical lifecycle nullifier** (r4c-6): each item advances
  `queued → snapshotted → {consumed | refunded}` on L1, and **the beneficiary/payer is stored
  at enqueue time**. Every seal proof takes the item's status as a public input and **rejects a
  `refunded` (or already-`consumed`) item**; a refund transition **atomically kills every live
  containing commitment** (snapshot slot, EBC reference). So the expiry refund and any later
  L2/bridge execution of the same item are mutually exclusive by construction — closing the
  "retain the blob, let a snapshot commit, then also claim the refund" double-spend. The current
  forced queue stores only fee + blob slice; this lifecycle+nullifier is new required state
  (§13-S).
- **§6.5 forced fees are priced from L1-measurable upper bounds, not unmeasurable zk-gas**
  (r4a-H10, r4b-H6): L1 cannot measure zk-gas at `saveForcedInclusion`, so the fee is
  `a + b·bytes + c·declared_gas`, where `bytes` and `declared_gas` are L1-observable at
  submission and `a`, `b`, `c` are **conservative governance constants that upper-bound the
  worst-case circuit cost per byte and per declared-gas** (the worst circuit/byte and
  circuit/gas ratios are a bounded, named quantity — §13-S.5, alongside the parse-time caps
  that make the ratios finite). `a` (the per-item base) makes a griefer's cost scale with the
  *count* of items, not their size, so tiny-item floods (r4a-H10) pay for the sealing overhead
  they impose. Each snapshot admits items up to a per-snapshot bound; overflow spills
  deterministically to the next epoch. Fees are paid to the **consuming epoch's sealer** (a
  state-recorded payee — I8). By construction the minimum forced-only seal is funded at or above
  its proving cost; a residual (a workload whose true circuit cost still exceeds the conservative
  bound) is closed by settling the shortfall from the recovery pool (§7.3) and is a named
  §13-S.5 item, not an unbacked "by construction" claim (conceding r4b-H6's precision point).
- **§6.6 epoch-native identity + anchor freshness/advancement floor** (r3a-F5, r3b-F1, r4b-M7):
  backed by [Appendix C](#appendix-c--l2-header-inputs-and-their-sources). The EBC-committed
  anchor must (a) be ≥ `D_anchor` (32 slots) deep — reorg safety; (b) not lag the epoch's own
  `T_N` by more than a governance **freshness ceiling** — so a holder cannot fake "serving" on
  stale L1 state while starving bridge ingestion; and (c) **advance** past the previous
  non-empty epoch's committed anchor — the epoch-relative replacement for Pacaya's
  `MAX_ANCHOR_OFFSET` and its anchor-must-advance rule. Deeper-than-κ reorgs rewind L1 records
  and L2 derivation together (§3.1), failing *closed*; G5 is a liveness guarantee, not a
  user-fund-safety guarantee — a >κ L1 reorg can revert user transactions exactly as on any L2
  (r4a-M12, stated in §1). Raising `D_anchor` 4→32 shrinks that probability at a one-epoch
  L1→L2 latency cost (r4a/r4b concur; exact value is §13-T tuning).

### 6.7 Fault-paid resolution (fast) and expiry cancellation (disaster floor)

A single withheld seal cannot hold users hostage for 10 days (r4a-H5, r4b-H4) — and in v7 the
fast path needs **no horizon of its own**:

- **The seal deadline is the fast path (v7 — replaces v5's separate `H_force`).** Seals are
  permissionless at all times (I7); what a horizon ever gated was *compensation*. That is
  exactly what the seal deadline's matured fault provides: at `T_N + S·E` (tolled) `+ κ`, the
  certificate settles (I2), and from that moment **anyone can seal the epoch from its on-L1
  data and be paid at indexed cost from the faulter's senior reserve tranche** (§7.3). A
  malicious recoverer cannot "sit on" the epoch: recovery is non-exclusive, so any honest party
  seals it and collects. A single-holder stall therefore resolves within ~`κ` of the deadline —
  roughly two epochs *earlier* than v5's `H_force` — and the recovery lane, not `H_cancel`,
  remains the normal exit.
- **`H_cancel` (10 days) — the disaster floor.** Reached only when the data is *genuinely
  unavailable* (nobody, anywhere, holds it), so no seal is possible. Only then may anyone
  **cancel**: the epoch re-resolves empty/forced-only from whatever L1 data survives, and later
  **committed, unsealed** epochs that chained to it re-resolve in the same deterministic cascade.
  The cancellation-causing tenure is charged for the recovery/cascade it forced, not merely one
  `L_slash` (r4b-M8), and re-queued forced snapshots preserve their original queue order so
  message ordering is unchanged (r4b-M8). Bounds, as v4:

1. **Sealed state is untouchable** (immutability corollary, §0): the cascade operates only on
   the unsealed tail — it cannot revert finalized L2 history, ever.
2. **The cascade is structurally shallow**: recovery-only mode (I5) stops new content epochs
   once the lag exceeds `K`, so the committed-content unsealed tail — the only thing
   cancellable — never exceeds ≈ `K + S` epochs (~77 min of chain), not 14 days. A
   "publish a 14-day tail then cancel it all" attack cannot arise: the tail stops growing at
   `K`.
3. What *is* lost in a cancellation is the unsealed preconf-layer view of those ≤ `K + S`
   epochs — exactly the exposure preconfirmations always carry against their bond, here
   reachable only after ≥ 10 days of continuously flagged failure.
4. Forced snapshots of cancelled epochs re-queue at the front (data intact — retention outlasts
   `H_cancel`); voiding + refunds only per §6.4 above.

---

## 7. Backlog, tolling, bounds

As v3: universal descendant tolling (§7.1, I4); global lag cap + recovery-only mode (§7.2,
I5); retention (§7.4). v5 change:

### 7.3 Recovery compensation and a solvent, countercyclical-proof pool (r3a-F14, r4a-H6, r4b-H5)

Compensation for recovering **another tenure's** fault is **indexed, not fixed**: a capped
multiple of prevailing L1 costs (base fee + blob base fee) plus the zk-proving component, paid
in ETH. Funding order and solvency:

1. **The faulted tenure's own recovery tranche** first (r4c-5; the senior slice of its single
   ETH account, §4's waterfall) — collected at bid time and sized to **fully collateralize that
   tenure's worst-case `K` outstanding recovery obligations**. A tenure's deliberate fault is
   thus always paid from *its own* account; it can never spill onto other tenures. This is the
   senior, per-tenure ETH reserve r4c-5 asks for, replacing v5's shared-pool-first waterfall.
2. **A shared residual pool** only for the genuine remainder — an honest fault whose reserve
   was legitimately drawn down by earlier honest recoveries — never for a deliberate
   fault/recovery Sybil pair (that is bounded by rung 1). It is pre-funded from a small slice of
   the per-tenure deposits (not fee flow, which stops in recovery-only mode — r4b-H5), so it
   does not deplete counter-cyclically. **Solvency invariant**: `Σ live per-tenure reserves ≥
   Σ live worst-case obligations`, enforced at tenure admission (r4a-H6); the shared pool is a
   thin buffer above it, not the primary backstop.

Recovery is a **cost-capped competitive job**, not a fixed cross-tenure subsidy: compensation is
capped at indexed cost, and the ≥80% burn is denominated to match — the safety component in ETH
(I9) so a TAIKO decline cannot make a fault/recovery cycle profitable against an ETH-denominated
pool obligation (closing r4c-5's profitability path).

A sustained L1 gas spike raises the payout with the cost instead of starving recovery.
Deterrence stays burn-based: the TAIKO liveness slash is ≥ 80% burned; empty/forced-only
recovery earns a small indexed amount; a tenure sealing its own epochs earns nothing (§5.4).

---

## 8. Faults, collateral, adjudication

As v3 (L1-mechanical liveness certificates; L2-with-proofs adjudication for content faults +
distributions; stable fault ids; safety supersession + clawback), with v4/v5 refinements:

- **Two slash denominations** (I9): safety faults debit `L_safety` in **ETH** (value-matched to
  the ETH-denominated MEV they deter, fixed from tenure start — no oracle, no shorting window);
  liveness faults debit `L_live` in TAIKO. Safety supersedes and claws back any liveness payouts
  before burning.
- **Certificate lifecycle** per §3.1 (single grace): maturity/settlement/parent-irreversibility
  coincide at `D + κ` (I2). Recording is permissionless; the **poke bounty pays a precommitted
  beneficiary, not `msg.sender`** (I8, r4c-4), so a copied poke cannot be redirected; and no read
  of fault status *depends* on a prior poke — the reading function materializes the certificate
  itself.
- **Verdicts are incarnation-bound** (r4c-8): a slashing verdict binds not only the stable
  logical fault id but a **finalized canonical origin root + a certificate incarnation number**.
  A verdict produced on a pre-reorg fork fails the incarnation/origin check on the post-reorg
  canonical chain even if its logical id currently reads unconsumed — closing orphan-fork verdict
  replay after a `>κ` rewind. Idempotency is still enforced only at the single L1 ledger (§4).
- **Withdrawal gate** (§8.4): the gate computes maturity from the records and materializes any
  missing certificate as part of the withdrawal call (I2), then requires zero unresolved
  certificates, no unsealed assigned epochs, no in-flight verdicts, no active attested-outage
  freeze — then the floor delay. A holder that missed an obligation faults *itself* by trying to
  withdraw; poke-censorship cannot buy an exit.

---

## 9. Total Anarchy

Unowned epochs have no bonded seat — and in **v7, per the original brief, they still accept
discretionary content**, through the one shape that cannot create unfunded liabilities:

- **Content lands only as an atomic proof-carrying proposal: propose ≡ seal.** For an unowned
  `openEpoch` whose parent is final, **anyone, first-come-first-served**, may submit a single
  transaction carrying the epoch's full content *and* its validity proof; acceptance seals the
  epoch on the spot (I7). This is exactly the Shasta inbox's existing atomic
  propose+prove+finalize shape (the parked permissionless branch — status quo §5), reused as
  the anarchy lane. There is **no unsealed-content limbo, ever**: an anarchy epoch is either
  sealed-with-content atomically or resolves empty/forced-only — nothing for the recovery lane
  to fund and no path to `H_cancel` cascades, which is precisely why v6 had dropped anarchy
  content and why v7 can restore it.
- **Self-funded, unbonded, unpaid.** The proposer pays its own proving; its motive is its own
  transactions' inclusion and whatever MEV the content carries. No slashing and no protocol
  rewards (nothing is bonded, nothing is promised) — and therefore **no preconfirmations**:
  users get L1-speed inclusion, not sub-slot promises. An FCFS gas race with unbonded MEV
  extraction is the accepted character of the fallback mode, stated plainly.
- **I6 binds anarchy too.** An atomic anarchy proposal is valid **only if it embeds the pending
  forced snapshot**; with no such proposal, the forced-only minimum outcome remains
  constructible and sealable by anyone, funded by the forced-queue fees (§6.5), exactly as in
  v6. Explicit-empty resolutions stay permissionless and unpaid. In recovery-only mode (I5),
  discretionary anarchy proposals pause like all discretionary content; forced-embedding
  proposals do not.

G5 reframing (r3a-F9) as before: in Phase B this is a **censorship-resistant fallback that
anyone can exit by out-bidding the reserve floor**; in Phase A it is **DAO-recoverable**, with
the DAO fast-path SLA of §10.3. Bridge flow during anarchy ≥ forced-only cadence (better
whenever atomic proposals land); queue data retention per §6.4 keeps long outages refund-safe
rather than value-destroying. **Worst-case bridge settlement for a voided forced item is
`H_cancel` + one forced-only bridge cadence** (r4a-M14): a depositor can make an informed
decision from that bound, and no value is burned — only delayed.

---

## 10. Bootstrap, parameters, emergency brake

§10.1 proving budget, §10.2 economic table — as v3, plus:

- **§10.2 additions**: recovery insurance pool cut (small % of epoch fees); indexed recovery
  rates (§7.3); poke bounty (§8); no price feeds anywhere (§4).
- **§10.3 Phase A SLA** (r3a-F9): the DAO pre-commits to a published fast path for allowlist
  expansion during anarchy (acting within `N_days`), and Phase A→B criteria are objective
  (§13-T).

### 10.4 Degradation ladder — a single withheld epoch is never a global halt (r3b-F6, r4b-H4)

r4b showed that even v4's split brake let one seal-withholder freeze *everyone*: the automatic
`openEpoch`-age trigger paused all maturation and froze all withdrawals — a 10-day chain-wide
halt bought for one `L_slash`. v5 replaces the single global trigger with a three-rung ladder
that escalates only as the failure proves genuinely systemic:

1. **The seal deadline — fault-paid resolution of the oldest epoch, nothing global** (§6.7;
   v7 folds v5's separate `H_force` into this rung). A stuck `openEpoch` is attacked directly:
   the moment its seal deadline's fault matures, anyone permissionlessly seals it from its
   on-L1 data, paid at indexed cost from the faulter's recovery tranche. A single withholding
   holder is ejected and its epoch resolved within ~`κ` of the deadline; **no honest tenure's
   deadlines pause and no withdrawals freeze**. This is the normal recovery path and it defuses
   r4b-H4's attack entirely.
2. **Recovery-only mode (I5)** — if lag still exceeds `K` (many epochs failing, not one), new
   discretionary content stops and effort funnels to the lane. Still no global withdrawal
   freeze; honest tenures with no open obligations may still exit.
3. **Attested systemic-outage freeze** — a global pause of maturation *and* withdrawals is
   reserved for a genuine proof-system outage, and requires an **independent attestation** (in
   Phase A, the DAO; a permissionless proof-outage predicate is §13-S.7). It is never triggered
   by `openEpoch` age alone, so a content-withholding holder — who is *not* a proving outage —
   can no longer reach for it. Forgiveness of in-window certificates is bounded to the attested
   window and **never** covers the holder(s) whose epochs drove the stall.

Bounded duration, auto-expiry, backlog cap, and queued-verdict replay before any release —
as v3.

---

## 11. Game-theory analysis (v6 deltas)

- **11.1 Squat economics**: idle-to-termination now pays quit-equivalent fees (§4);
  forced-only squatting counts against `K_empty` and is fee-capped (§5.4); silent stall
  unchanged (certificate + debit + termination per miss).
- **11.2 Undercollateralization / TAIKO-shorting** (r4a-C1/H11, r4b-H3): defeated by the split
  bond (I9) — the *theft* fault (equivocation) is slashed in ETH, value-fixed from tenure start,
  so `MEV(ETH) − L_safety(ETH)` no longer moves with the TAIKO price and no short or price shock
  cheapens it. Only *griefing* deterrence (`L_live` in TAIKO) carries the price residual, and a
  griefer gains delay, not funds.
- **11.3 Recovery-lane seal-race** (r4a-H7): rebutted as a griefing cost, not a halt. Competing
  seals for the same `openEpoch` all target one advance; the first valid one advances it and the
  losers simply revert, wasting the *racers'* own gas — the chain still advances one seal per L1
  block, and honest recoverers are reimbursed at cost (§7.3), so a cartel spends to crowd a
  lane that advances regardless. Optional bond-priority ordering is a §13-T tuning lever, not a
  structural need.
- **11.5 Censorship, remodeled** (r3a-F1/F4, r3b-F6): the binding target is **publication**
  (blob payloads over the `32`-slot in-epoch stream + `κ`-slot re-post grace, every data holder a
  potential includer), then the seal (1 small tx, submittable across the whole multi-epoch span
  to the `S`-epoch deadline). Targeted censorship of
  one holder is priced by the corridor rule (`gain ≪ C_cen(span)`); **systemic** censorship that
  stalls `openEpoch` is handled by the **degradation ladder** (§10.4) — the seal deadline's
  matured fault opens fault-paid permissionless resolution of the oldest epoch (v7), and only
  an *attested* proof-outage (never age alone) can
  reach a global freeze/forgiveness, so a builder cartel cannot convert censorship into either a
  chain-wide halt or self-forgiveness. The design deliberately excludes a self-attested "I was
  censored" toll (r3a-F4): mempool non-inclusion is not mechanically decidable, and an
  unfalsifiable attestation is a free deadline-extension lever. Residual: short targeted
  censorship that outlasts a holder's whole submission span can still cost an honest holder one
  `L_slash`; the corridor keeps it unprofitable and κ-grace resubmission keeps it rare. Stated
  plainly.
- **11.6 Reward-capture / front-running**: eliminated by precommitted payees (I8, r4c-4) — proof
  payout addresses are proof public inputs, poke/fill beneficiaries pre-registered, so a copied
  witness advances the chain but cannot redirect the reward.
- **11.7 Simulation plan additions**: publication-censorship spans, sybil forced-inclusion
  floods against `K_empty`, cancellation-cascade depth under recovery-only mode, brake-trigger
  boundary gaming, insurance-pool solvency under gas spikes.

---

## 12. Explicitly out of scope (v1 implementation)

Unchanged: per-transaction fair exchange; user restitution; multi-seat; based-validator
alignment; automated bond scaling.

---

## 13. Open issues

**13-S — Structural (blocking implementation)**, each tagged with the earliest phase it gates
(r4a-M15):

1. **[Phase A]** Deep-reorg (> κ) rewind semantics: precise joint rewind of records,
   certificates, `openEpoch`, and derivation (§3.1) — a correctness precondition, needed day one.
2. **[Phase A]** Cancellation-cascade determinism proof, including in-flight verdicts and
   re-queued-in-order snapshots (§6.7).
3. **[Phase A]** Appendix C completion to implementation granularity: every header/execution
   input signed off as inclusion-independent, with the **EBC-content-committed origin** rule and
   the anchor freshness/advancement floor (§6.6, I1).
4. **[Phase A]** Certificate lifecycle ↔ bridge verdict-queue interaction across forks and
   outage mode; read-time maturity/materialization points enumerated (I2).
5. **[Phase A]** Parse-time resource-bound constants finalized and made **consensus-exact across
   client and circuit** (circuit canonical), with degrade-without-allocation semantics
   (I1; r3b-F4, r4a-C4, r4b-M9). Includes the bounded worst-case circuit/byte and circuit/gas
   ratios that back the forced-fee upper bound (§6.5).
6. **[Phase A]** Append-only record-spine retention and compaction design + storage-cost account
   (§3; r3b-F3).
7. **[Phase B]** Permissionless proof-system-outage predicate for the attested freeze/
   forgiveness, or the finding that none exists so Phase B keeps a DAO attestation (§10.4).
8. **[Phase B]** Phase-A DAO fast-path SLA definition (§10.3).
9. **[Phase A]** Senior per-tenure ETH recovery reserve sizing + solvency invariant wired to
   admission (§7.3, r4a-H6/r4b-H5/r4c-5).
10. **[Phase A]** Forced-item lifecycle nullifier (`queued→snapshotted→consumed|refunded`) in
    proof public inputs; refund atomically kills live commitments (§6.5, r4c-6).
11. **[Phase A]** Verdict incarnation + finalized-origin binding so orphan-fork verdicts fail
    post-reorg (§8, r4c-8).
12. **[Phase A]** Precommitted-payee binding (proof public input / pre-registration) for every
    permissionless reward (I8, §5.2, §8; r4c-4).
13. **[Phase A]** Anarchy atomic-proposal lane (v7, §9): spec of the propose≡seal path reusing
    the Shasta atomic propose+prove shape, including the forced-snapshot-embedding validity
    rule, its FCFS ordering on L1, and its interaction with recovery-only mode.

**13-T — Tuning (gates Phase B)**:

1. `Γc` residual soft-preconf window (`Γc + κ`, now ~7 slots) vs `Γpre` early-cutoff to
   drive it to zero at a duty-cycle cost (r4c-3; round-2 §13.1).
2. **Maximum tenure duration** vs. accepted incumbency residual — the only complete
   censorship-resistance bound (r4c-9); interacts with §4's future-epoch-reservation gate.
3. `K`, `K'`, `K_empty`, `H_cancel`, `D_anchor` calibration and threshold gaming.
4. Bridge-liveness SLA under long forced-only-cadence runs.
5. Recovery insurance pool sizing; indexed-rate caps.
6. Censorship-corridor quantification against real builder-market data.
7. Phase A→B objective criteria.
8. Client migration sequencing.

---

## Appendix A — Divergence from the brief (owner to confirm)

Items 1–8 as v3. v4: **9.** publication-payment removed then (v5) refined; **10.** `K_empty`
counts forced-only epochs, idle exits pay quit-equivalent fees; **11.** **no oracles anywhere**
(owner directive) — ETH assumed stable-to-increasing; **12.** forced-inclusion fees follow the
sealing work. New/changed in **v5**: **13.** **split bond** (I9) — the safety/equivocation slash
is ETH-denominated (value-matched, oracle-free), the liveness slash stays TAIKO; this is how the
no-oracle directive is honored without leaving the theft class undercollateralized. **14.**
publication fill carries a **fault-only reward** funded by the failing holder (not the v4 zero,
not the v3 always-on escrow). **15.** derivation origin is the **EBC's committed content**, not
its L1 inclusion block. **16.** a **degradation ladder** (`H_force` → recovery-only → attested
freeze) replaces the single global brake so one withheld epoch is never a chain-wide halt.
**17.** recovery pool pre-funded from per-tenure ETH deposits with a solvency invariant. New in
**v6**: **18.** EBC references **already-posted** blobs (publication folded into EBC validity, no
separate publish deadline) and `Γc` is lowered to 4, so the parent's content-or-empty outcome is
a single decision at `Γc+κ = 7` slots and the successor's soft-preconf window shrinks from ~84%
to ~22% of its epoch; **19.** **single-grace** certificate lifecycle
(maturity = settlement = irreversibility at `D+κ`, not `D+2κ`); **20.** **precommitted payees**
for every permissionless reward; **21.** senior **per-tenure ETH recovery reserve** (deliberate
faults never touch the shared pool); **22.** forced-item **lifecycle nullifier** + **verdict
incarnation**; **23.** future-epoch assignment gated on the **current** reservation (no perpetual
grandfathering). New in **v7** (owner-approved self-review round): **24.** **one acceptance
rule** — presence at `D+κ` decides every deadline artifact; a first submission inside
`(D, D+κ]` is valid (one-shot-ness is the only constraint), widening the honest budget to the
full 7 slots with finality timing unchanged (§3.1). **25.** the seal is **deadline-only**
(`S = 4` epochs, tolled) — the brief's `[T+384d, T+384(d+s))` window form is replaced by its
end time alone; early seals are valid and strictly beneficial (owner-approved divergence, §5.5).
**26.** **`H_force` retired**: fault-paid permissionless resolution attaches at the seal
deadline itself, making recovery ~2 epochs faster with one fewer horizon (§6.7, §10.4).
**27.** **one ETH account per tenure** with a recovery/safety/working seniority waterfall and a
single admission solvency invariant (§4, §7.3). **28.** **Total Anarchy content restored** per
the brief — discretionary anarchy content lands FCFS as an **atomic proof-carrying proposal**
(propose ≡ seal, the Shasta atomic shape), unbonded and unpaid, forced-snapshot-embedding
required; this reverses v3–v6's forced-only-anarchy divergence now that atomicity removes the
unfunded-liveness objection (§9).

## Appendix B — Review dispositions

Rounds 1–2: see v2/v3 changelogs (all accepted; superseded details updated in place).

**Round 3a ("MiniMax", [5354204450](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354204450) — 3 critical, 7 high, 5 medium):

| # | Finding | v4 response |
| --- | --- | --- |
| 1 (crit) | `Γb_h` censorship-buyable; publication censorship unmodeled | `Γb_h` **removed** — open fill from the boundary; publication modeled as the binding censorship target (§5.2, §11.5). Note: `Γb_h` never restricted the *holder* (only fillers), but the point is moot once it is gone |
| 2 (crit) | Publication escrow front-runnable / washable / vs I7 | Escrow **deleted**; no publication payment to anyone; successor self-protection is the named incentive; new invariant **I8** (payees are state) (§5.2) |
| 3 (crit) | `H_cancel` cascade reverts history / breaks bridge | Partially a v3 spec-gap, partially rebutted: cancellation **never touches sealed state** (now the immutability corollary), and recovery-only mode bounds the cancellable content tail to ≈ `K+d+s` epochs (~77 min), not 14 days. Made explicit; forced snapshots re-queue; expired items void **with refunds** via queue-fee and bridge unprocessed-message paths; `H_cancel` 14→10 d for retention margin incl. forced-queue data (§6.7, §6.4) |
| 4 (high) | Missed-seal fault under L1 censorship | Partially adopted: brake's objective `openEpoch`-age trigger handles systemic censorship cause-agnostically (deadline suspension + certificate forgiveness); corridor economics price targeted censorship. **Rejected**: mempool-based auto-toll and self-attested censorship (not mechanically decidable; free extension lever). Residual stated (§11.5) |
| 5 (high) | Precomputability vs L1-origin inputs | Adopted: `D_anchor` minimum anchor depth makes committed content κ-reorg-immune; **Appendix C** enumerates every header/execution input with its source and inclusion-independence argument; > κ reorgs rewind L1 and L2 together (fail-closed) (§5.1, §6.6, App. C) |
| 6 (high) | `K_empty` termination = cheap exit | Adopted (their option b): idle exit keeps the fee clock running to the quit-notice-equivalent epoch; standby promotion, not reserve re-auction, fills the seat (§4) |
| 7 (high) | Forced-inclusion self-eating resets `K_empty` | Adopted (their option c, corrected for v3 mechanics — there is no separate "consume" call, but forced-only epochs did reset the counter): `K_empty` counts **all** no-discretionary-content epochs (§5.4) |
| 8 (high) | Certificate/high-watermark race with κ | Adopted: pending → settled(+κ) → debit-at-settlement lifecycle; gate counts pending + unresolved settled; pending self-resolves in κ so it cannot freeze honest exits (§3.1, §8) |
| 9 (high) | Anarchy = permanent halt; G5 conflated | Adopted: G5 rewritten as two distinct endgames (Phase B: exit-by-bidding censorship-resistant fallback; Phase A: DAO-recoverable with fast-path SLA) (§1, §9, §10.3) |
| 10 (high) | Forced-only self-recycling tax | Substantially closed by F7's `K_empty` redefinition + clarification: a holder sealing its own assigned epochs earns no recovery compensation — bounties exist only for recovering another tenure's fault (§5.4) |
| 11 (med) | ETH-floor oracle centralization | Superseded by the owner's no-oracle directive: the ETH-value floor is **removed entirely**; reservations are TAIKO-denominated governance constants, prospective-only; residual stated (§4, App. A #11) |
| 12 (med) | L1-mechanical false positives on reorg | Same fix as F8: debit only at settlement (§3.1) |
| 13 (med) | Forced-only data source/retention | Adopted: source = forced-queue L1 blob data; retention duty to `H_cancel` + margin; void-with-refund path (§6.4) |
| 14 (med) | Fixed recovery rate starved by gas spikes | Adopted: cost-indexed capped rates + fee-funded recovery insurance pool (§7.3) |
| 15 (med) | §13 mixes structural and tuning | Adopted: §13 split into 13-S (blocking) and 13-T (Phase-B gating) |

**Round 3b ("DeepSeek", [5354253289](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354253289) — 1 critical, 5 high, 2 medium):**

| # | Finding | v4 response |
| --- | --- | --- |
| 1 (crit) | Derivation bounds reference seal-inclusion time ⇒ late-seal default-settlement theft; recovery crosses `TIMESTAMP_MAX_OFFSET`/`MAX_ANCHOR_OFFSET` | Accepted as a spec-explicitness failure, resolved the reviewer's way (option a/b combined): **the seal carries zero derivation inputs**; where an L1 origin is needed it is the **EBC's inclusion block**; all bounds are epoch-relative to `T_N`. The canonical outcome is invariant under seal timing — stated in I1 — so withholding the seal can never select a degraded outcome, and tolled/late recovery proofs never expire. (v1 §6.2 already specified epoch-relative bounds; v3 compressed the statement into ambiguity — conceded) |
| 2 (high) | Liability is poke-dependent; seal-over-fault + censored pokes ⇒ withdrawal bypass | Accepted: I2 restated — **liability exists from maturity as computed state**; every dependent transition (EMPTY-PENDING seal, withdrawal, assignment) evaluates maturity at read time and materializes certificates atomically; pokes are an accelerator, never a dependency (§0-I2) |
| 3 (high) | Record spine has no retention spec; 3-day ring buffer precedent | Accepted: append-only record spine, retention ≥ `max(H_cancel, withdrawal floor + challenge + verdict replay, tenure tail)`, fail-closed on missing records, storage cost accounted, compaction as §13-S.6 (§3) |
| 4 (high) | Decompression/RLP bombs precede any zk-gas cap; I1 "bounded-cost" overclaimed | Accepted, including the overclaim: Shasta's degradation covers manifest validity, **not** parse-time resources. I1 now mandates pre-allocation caps (decompressed size, RLP count/depth, tx count/size) in client and circuit, degrade-without-allocation; §13-S.5 carries the spec work (§0-I1) |
| 5 (high) | Forced-inclusion spam makes the forced-only fallback economically unprovable | Accepted: per-snapshot **zk-gas cap** with deterministic spill; forced fees flow to the consuming epoch's sealer (I8-conform payee); fee formula includes a zk-gas-proportional component ⇒ the fallback is always funded at/above proving cost (§6.5) |
| 6 (high) | Age-triggered brake forgiveness is self-triggerable by the faulted holder | Accepted: brake split — automatic age trigger **suspends only** (future maturation pauses, withdrawals freeze, nothing erased); **forgiveness** requires an independent outage attestation, covers only in-window faults, and never the holder(s) who drove the age (§10.4; §11.5 adjusted accordingly) |
| 7 (med) | Escrow per-slice accounting / partial-fill griefing | Superseded: the publication escrow was deleted in this same revision (r3a-F2); there is no publication payment to account for (§5.2) |
| 8 (med) | (a) reservation not revalued at fault time; (b) no single liability ledger | (a) v5: safety slash is ETH-denominated and value-fixed from tenure start (I9), so revaluation is unnecessary for the theft class; liveness residual stated (§4). (b) Accepted: the L1 bond contract is the sole liability ledger (§4) |

**Round 4a ("MiniMax", [5354402375](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354402375)) and 4b ("DeepSeek", [5354409216](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354409216)) — merged (the two passes overlap on every critical):**

| Finding (round·#) | v5 response |
| --- | --- |
| **4a-C1 / 4b-H3 / 4a-H11** No-oracle TAIKO bond ⇒ shorting / undercollateralization / withdraw-after-shock | Accepted, resolved oracle-free: **split bond (I9)** — equivocation/theft slashed in **ETH** (`L_safety`, value-fixed from tenure start), liveness in TAIKO. `MEV(ETH) − L_safety(ETH)` no longer tracks TAIKO price; shorting/withdraw-shock windows close. Honors both owner directives (no oracle; TAIKO bond token) by applying ETH only to the fault class where value-matching is load-bearing (§4, §11.2) |
| **4a-C2 / 4b-C1** EBC-inclusion-block origin still inclusion-time-dependent; byte-identical resubmission conflict | Accepted fully (their option a): origin = **EBC's committed content** (the EBC commits its own anchor origin), never the inclusion block. Reorged resubmission carries the identical origin, so outcome is invariant under inclusion (I1, §3.1, App. C) |
| **4a-C3** I2 read-time materialization ambiguous ⇒ withdrawal-by-decay | Accepted: I2 states the reading function *itself* materializes the certificate; withdrawal reads the computed matured set, so a missed holder faults itself by withdrawing; poke-censorship cannot buy an exit (§0-I2, §8) |
| **4a-C4 / 4b-M9** Parse-time caps unnamed; client-vs-circuit divergence | Accepted; sided with 4b over 4a: constants **named** (§3 table) and **consensus-exact, circuit-canonical, client-identical** — not "looser client" (§0-I1, §13-S.5) |
| **4b-H2** Payment-free publication assumes a cooperative, not competing, successor | Accepted the incentive gap, rebutted the fault: a backup filler cannot fault an honest uncensored holder (holder publishes itself). Added a **fault-only fill reward** funded by the failing holder (I8-conform), giving a positive fill incentive without an honest party to front-run (§5.2) |
| **4b-H4** Self-triggered global suspension = 10-day halt for one `L_slash` | Accepted: **degradation ladder** replaces the single trigger — `H_force` force-resolves the oldest epoch permissionlessly (no global pause), recovery-only mode for many-epoch lag, and a global freeze only under **attested systemic proof outage** (never `openEpoch` age alone) (§10.4, §6.7) |
| **4a-H5** 10-day preconf limbo | Resolved by `H_force` (§6.7): a single stall resolves in ~one window via the paid permissionless lane; 10 days is only the genuine data-loss disaster path |
| **4a-H6 / 4b-H5** Insurance pool countercyclically empty / no solvency invariant | Accepted: pool **pre-funded from per-tenure ETH deposits** (not fee flow), with a solvency invariant wired to tenure admission (§7.3, §13-S.9) |
| **4a-H10 / 4b-H6** Forced-only "always funded" rests on unmeasurable zk-gas / tiny-item floods | Accepted: fee = `a + b·bytes + c·declared_gas` from L1-measurable quantities with conservative worst-ratio constants; `a` base makes cost scale with item *count*; residual shortfall settled from the pool; worst-ratio bound is a named §13-S.5 item (§6.5) |
| **4a-H7** Recovery-lane seal-race DoS | Rebutted as griefing-cost, not halt: losing seals revert wasting the racers' gas; the chain advances one seal/block regardless; honest recoverers reimbursed at cost. Bond-priority ordering noted as optional tuning (§11.3) |
| **4a-H8 / 4a-C2** `D_anchor=4` too shallow | Accepted: `D_anchor` raised 4→32 slots; combined with content-committed origin, committed content is reorg-safe (§3 table, §6.6) |
| **4a-H9** Provisional window is `Γb+κ` "at least", not exact | Accepted as a clarification: with content-committed origin the EBC reorg no longer extends it; the window is `≥ Γb+κ`, measured from the latest irreversible prerequisite (I4) |
| **4a-H10 base component / 4b-M7** anchor freshness/advancement floor unspecified | Accepted: §6.6 now specifies the freshness ceiling + advancement rule (epoch-relative `MAX_ANCHOR_OFFSET` replacement) so stale-anchor fake-serving is invalid |
| **4b-H6 precision** "by construction" funding overclaim | Conceded: funding guarantee is "upper-bound + pool-settled shortfall", not unconditional; worst-ratio is §13-S.5 |
| **4a-M12** G5 is liveness, not user-fund-safety | Accepted, stated in §1: >κ L1 reorgs can revert user txs as on any L2; `D_anchor` reduces probability |
| **4a-M13** Forced-only Sybil profit center | Accepted: per-tenure forced-only fee **capped** at `K_empty·a_forced`, excess to treasury (§5.4) |
| **4a-M14** Bridge refund worst-case delay unstated | Accepted: worst case = `H_cancel` + forced-only bridge cadence, stated for informed deposit decisions (§9) |
| **4a-M15** §13-S unprioritized | Accepted: each §13-S item tagged [Phase A]/[Phase B] |
| **4b-M8** Cascade charges one `L_slash`; re-queue ordering | Accepted: cancellation-causing tenure charged for the cascade it forces; re-queue preserves original order (§6.7) |

**Round 4c (multi-pass v4 review, [5354577413](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354577413) — 5 high, 5 medium; reviewed v4, resolved in v6):**

| # | Finding | v6 response |
| --- | --- | --- |
| 1 (high) | EBC inclusion still an attacker-influenced derivation input | **Already resolved in v5** and the reviewer proposes exactly that fix: origin = EBC **committed content**, EBC inclusion authenticates availability only, contributes zero derivation inputs (I1, App. C). Restated crisply in v6 |
| 2 (high) | Certificate lifecycle applies `κ` twice ⇒ `D+2κ` finality / parent-flip | **Accepted — real bug.** Collapsed to a **single grace**: maturity = settlement = parent-irreversibility = artifact-set-closure at `D+κ`, one atomic transition; post-`D+κ` artifacts rejected; I4's `Γb+κ` bound now exact (§0-I2, §3.1) |
| 3 (high) | Predecessor 27/32-slot last-look over successor | Accepted, materially reduced: EBC references already-posted blobs and `Γc`/`Γb` lowered to 4/8 ⇒ parent-final at `Γc+κ = 7` slots (~22%, not 84%); an on-time predecessor has **no** last-look; successor soft/hard preconf boundary defined; driving to zero via `Γpre` is §13-T (§5.1, §5.2) |
| 4 (high) | I8 payees still first-claimer / front-runnable | **Accepted.** Payees **precommitted** — proof payout address is a proof public input; poke/fill beneficiaries pre-registered; copied witnesses can't redirect rewards (I8, §5.2, §8) |
| 5 (high) | Shared recovery insurance Sybil-drainable | Accepted: **senior per-tenure ETH reserve** sized to each tenure's own worst-case `K` obligations pays deliberate faults first; shared pool is a thin residual only; ETH-denominated so a TAIKO decline can't make the cycle profitable (§7.3) |
| 6 (med) | Forced-item refund races a live snapshot | Accepted: per-item **lifecycle nullifier** (`queued→snapshotted→consumed\|refunded`) in seal proof public inputs; refund atomically kills live commitments; beneficiary stored at enqueue (§6.5, §13-S.10) |
| 7 (med) | Prospective-only reservation grandfathers a perpetual incumbent | Accepted: already-assigned epochs keep their terms, but every **future** assignment requires the current reservation after timelock; top-up-or-graceful-terminate (§4) |
| 8 (med) | Orphan-fork verdict replay after consumed-set rewind | Accepted: verdicts bind a **finalized origin root + certificate incarnation**, not just the logical id, so a pre-reorg verdict fails post-reorg (§8, §13-S.11) |
| 9 (med) | `K_empty` resettable with garbage or a self/no-op tx | Accepted: count **post-derivation, non-system, non-self** output; and stated honestly that a complete censorship bound needs a **max tenure duration** — a §13-T decision, not a claim `K_empty` alone suffices (§5.4, §13-T.2) |
| 10 (med) | v4 not self-contained; stale v3 escrow / ETH-floor refs | Accepted: stale "escrowed recovery claims" and ETH-floor language removed/reconciled; funding is now the single senior-reserve waterfall (§7.3, §9) |

**Rounds 5–6 (r5a DeepSeek, r5b Codex, r6 DeepSeek — links in the header):** these rounds
attacked the **verification artifact** (`simulation/model_checker.py`) and documentation
consistency rather than the mechanism design. All findings were accepted and fixed: real
cross-transition invariant checking (monotone `openEpoch`, debit conservation), faithful
modelling of the §6.7 cancellation cascade and of I2 read-time fault materialization for both
content and explicit-empty seal duties, halt-failing exit codes, the explicit
`CANCEL_LAG`/horizon abstraction note, exhaustiveness wording scoped to the curated initial
configurations, and the round-count/deliverable-numbering reconciliation across the PR docs.
Dispositions and re-run results: [`simulation/RESULTS.md`](simulation/RESULTS.md) (revision
notes) and the PR thread replies.

## Appendix C — L2 header inputs and their sources

Backing for §6.6's claim (r3a-F5). Source classes: **P** = parent chain state, **E** =
epoch schedule (known before `T_N`), **C** = committed content (EBC-bound), **X** = execution
result. None may be an L1-inclusion-time observation.

| Header / execution input | Today (Shasta) | v5 source | Inclusion-independence |
| --- | --- | --- | --- |
| `number` | parent + 1 | **P** | — |
| `parentHash` | parent | **P** | — |
| `timestamp` | manifest, bounded by proposal L1 time | **C**, bounded by `[T_N, T_N+E)` | **E** bounds replace inclusion-time bounds |
| `extraData` | basefeeSharingPctg + **proposalId** | basefeeSharingPctg (**E**) + **(epoch, intra-epoch index)** (**E/C**) | proposalId eliminated — the round-1 F6 fix |
| `coinbase` | manifest; forced ⇒ proposal.proposer | **C**; forced ⇒ epoch-deterministic address (**E**) | tx-sender dependence eliminated |
| `gasLimit` | manifest, drift-bounded | **C**, drift-bounded vs parent (**P**) | — |
| `difficulty` | zk-gas used (Unzen) | **X** | — |
| `mixHash` | `keccak(parentDifficulty, number)` | **P** | already deterministic |
| `baseFee` | EIP-4396 from parent timing | **P** | — |
| anchor tx params (`anchorBlockNumber/Hash/StateRoot`) | holder-chosen recent L1 block | **C** — **committed inside the EBC**; ≥ `D_anchor` (32) deep, within the freshness ceiling, advancing (§6.6) | content-addressed ⇒ inclusion-independent; reorg-safe by depth; > κ ⇒ exceptional joint rewind |
| forced-inclusion prefix | dequeued at proposal inclusion | per-epoch snapshot fixed before `T_N` (**E**) | round-1 F7 fix |
| `stateRoot`, `receiptsRoot`, `logsBloom`, `gasUsed`, blob-gas fields | execution | **X** | — |

**Derivation-origin rule (r4a-C2, r4b-C1):** the only L1 origin derivation reads is the anchor
**committed inside the EBC content** — not the L1 block that includes the EBC transaction, and
not the seal's inclusion. Since the origin is a content field, byte-identical resubmission after
any reorg carries it unchanged, so the derived outcome is invariant under the inclusion of every
transaction. Seal timing — normal, tolled, recovered, or years late in the recovery lane —
cannot change the outcome, and the legacy `TIMESTAMP_MAX_OFFSET` / `MAX_ANCHOR_OFFSET`
inclusion-relative bounds are fully replaced by the epoch-relative bounds above.

Completion to implementation granularity (every fork-specific field, genesis edges) is
blocking item §13-S.3.
