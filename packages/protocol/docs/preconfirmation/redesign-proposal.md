# Taiko Based Preconfirmation Redesign — Perpetual Auction with Commit → Publish → Seal Epochs

> **Deliverable 2 of the preconfirmation redesign effort. Draft v4, 2026-08-20** — revised after
> three adversarial review rounds, the third comprising two independent passes
> ([r1](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5353544928),
> [r2](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5353904484),
> [r3a "MiniMax"](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354204450),
> [r3b "DeepSeek"](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354253289));
> dispositions in [Appendix B](#appendix-b--review-dispositions). Design only — mechanisms,
> invariants, incentives, parameters. Baseline: [`status-quo.md`](status-quo.md); owner
> decisions: its §6 and [Appendix A](#appendix-a--divergence-from-the-brief-owner-to-confirm).
>
> Prior art (post-whitelist URC design, post-Shasta slashing design, PR #22019) is consciously
> not followed; #22019 is implementation reference only, per the redesign brief.

---

## 0. Core invariants (normative)

- **I1 — Total, bounded derivation; outcome invariant under seal timing.** Derivation maps
  *any* committed + published bytes to a unique, bounded-cost L2 block sequence. Bounded-cost
  includes **parse time** (r3b): hard caps on decompressed size, RLP element count/depth,
  transaction count and per-item size — enforced *before allocation*, in client and proof
  circuit alike; exceeding any cap (or the per-epoch zk-gas cap) degrades deterministically to
  default content without materializing the oversized object. (Shasta's existing degradation
  covers manifest validity but **not** these resource bounds — they are new, required work.)
  And crucially: **derivation takes no input from the seal's L1 inclusion** — where an L1
  origin reference is needed at all, it is the **EBC's inclusion block**; all timing/anchor
  bounds are epoch-relative (`T_N`). A committed epoch therefore has exactly one canonical
  outcome, provable by anyone holding the data, **regardless of when the seal lands** — late
  sealing can never select a degraded or different outcome (r3b's default-settlement theft is
  impossible by construction, not by deadline).
- **I2 — No fault requires the accused; liability exists from maturity, not from recording.**
  Liveness faults are objective L1 facts. A fault is **matured** the moment its
  deadline-plus-grace passes with the artifact absent — as *computed state*, independent of
  any transaction. Recording (permissionless, poke-bounty-paid) merely materializes a
  certificate; **every protocol transition that depends on fault status — sealing an
  EMPTY-PENDING epoch, withdrawal, assignment, promotion — evaluates maturity directly at
  read time and materializes the certificate atomically if absent** (r3b: a sealed-over,
  never-poked fault can never clear a withdrawal gate). Certificates keep the κ lifecycle:
  *pending* at maturity, *settled* at `+κ` unless a byte-identical resubmission landed,
  debited exactly at settlement.
- **I3 — Single open epoch, always advanceable.** One canonical `openEpoch`; only a valid
  seal advances it; at every moment a permissionless action exists that can eventually advance
  it (content seal, forced-only seal, empty seal, or the bounded expiry cancellation).
  Unproven material never blocks any of these.
- **I4 — Successor-safe parent.** Epoch N's outcome (content-with-DA or empty) is irreversible
  within `Γb + κ` of its boundary, and every later deadline measures from the moment its
  prerequisite became irreversible (automatic tolling), never from wall-clock while blocked.
- **I5 — Bounded global backlog.** `openEpoch` lagging by more than `K` epochs triggers
  recovery-only mode (no new discretionary content, no fees) until the lag clears. All
  retention, collateral, and prover sizing is dimensioned against `K`, and — corollary — **the
  content-bearing unsealed tail can never exceed ≈ `K + d + s` epochs**.
- **I6 — Forced inclusions are censorship-proof against the seat.** A non-empty forced
  snapshot makes the epoch's minimum valid outcome the deterministic forced-only epoch,
  constructible and provable by anyone from L1 data alone; empty is then invalid.
- **I7 — Only proven transitions lock state; outcomes are sender-free.** Canonical state
  changes only through proof-carrying seals or the deterministic proof-free resolutions (valid
  empty seal; expiry cancellation), all pure functions of on-chain state. Who sends a
  transaction never affects what the outcome is.
- **I8 — Payees are state, not senders.** Every payment the protocol makes (compensation,
  refund, reward) goes to an address determined by a pure function of on-chain state — never
  to "whoever claimed first". (v4, closing the escrow-capture class.)
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
sequencing [T_N ─────────────── T_N+E)   preconfs stream over P2P; blob slices may stream to L1
commit     by T_N + E + Γc               EBC: one-shot content commitment (small tx)
publish    by T_N + E + Γb               remaining blob slices; OPEN TO ANYONE from the boundary
irreversible at deciding artifact + κ    observed → pending → irreversible (I2 lifecycle)
seal       [T_N + d·E, T_N + (d+s)·E)    one proof-carrying seal finalizes the epoch
```

| Param | Meaning | Initial | Notes |
| --- | --- | --- | --- |
| `d`, `s` | seal deferral / window (epochs) | 2, 2 | §10.1 |
| `q` | auction transition delay (epochs) | 2 | current + next final |
| `Γc` | EBC deadline past boundary | 8 slots | |
| `Γb` | publication deadline past boundary | 24 slots | open fill from the boundary — no holder-exclusive window (v4, §5.2) |
| `κ` | reorg grace | 3 slots | certificate lifecycle §3.1 |
| `D_anchor` | minimum anchor depth at sequencing | 4 slots | anchors reference only L1 blocks ≥ `D_anchor` deep, so κ-reorgs cannot invalidate committed content (v4, r3a-F5) |
| `K` / `K'` | global lag cap / exit | 8 / 4 epochs | recovery-only mode (I5) |
| `K_empty` | max consecutive epochs **without discretionary content** (empty *or* forced-only) | 16 | redefined in v4 (r3a-F7/F10); termination §4 |
| `H_cancel` | published-unsealed cancellation horizon | 10 days | + processing margin < L1 blob retention (~18 d) for epoch **and forced-queue** data (v4) |

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
monotone — resubmission shifts *when*, never *what*. A missed-deadline **certificate** is
*pending* from record, *settled* at `record + κ` if no byte-identical resubmission landed, and
**debits `L_slash` exactly at settlement** — an honest holder whose artifact was momentarily
reorged is never debited, and a reorg-gamed pending state resolves in `κ` slots either way.
Withdrawal gating counts pending **and** settled-unresolved certificates (§8.4). Reorgs deeper
than `κ` are an exceptional L1-consensus event: all records are L1 state, so `openEpoch`,
certificates, and artifacts rewind together; semantics specified as a blocking item (§13-S).

---

## 4. The perpetual auction (L1)

As v3 (bid = TAIKO bond + ETH fee rate + prepaid ETH; ≥10% increment; reserve floor;
`q`-delayed transitions with current+next final; funding rule as automatic quit notice;
reservation = `K·L_slash +` safety reserve), with v4 changes:

- **No oracles, anywhere** (owner decision, 2026-08-20): the protocol contains **no price
  feeds** — not for TAIKO, not for gas. The design assumes ETH's value is stable-to-increasing
  (owner assumption); the TAIKO reservation is denominated and enforced purely **in TAIKO**,
  with amounts set conservatively by governance and adjustable only **prospectively**
  (timelocked; never retroactively against an existing tenure). The residual — a deep TAIKO
  price decline eroding the *value* of deterrence until governance raises the parameter — is
  accepted and stated, monitored off-chain, and listed in §11.7's simulation scenarios.
  (Supersedes v4-draft's rate-limited ETH-value floor and r3a-F11's oracle specification;
  r3b-F8a's revalue-at-debit becomes moot: debits are token-denominated against a
  token-denominated reservation and always sufficient in token terms.)
- **Idle exit pays like a quit** (r3a-F6): a tenure terminated via `K_empty` (or that stops
  committing content) keeps its **fee clock running to the epoch a proper quit notice issued
  at first idleness would have reached** (`q` epochs beyond). Idling is never a cheaper exit
  than quitting; promotion of the highest standby (not a reserve-floor re-auction) fills the
  seat where one exists.
- **Termination** on: settled fault certificate, bond below reservation, or `K_empty`
  no-discretionary-content epochs (fee-continuation above; no slash — but see §5.4).
- **One canonical liability ledger** (r3b-F8b): the L1 bond contract is the sole ledger;
  L2 verdicts and every transport only *instruct* it; idempotency (the logical-id
  consumed-set) is enforced exclusively there, at execution.

---

## 5. The per-epoch pipeline: commit → publish → seal

### 5.1 Commit — the epoch-boundary commitment (EBC)

As v3: one-shot per (tenure, epoch), due `T_N + E + Γc`, binds full ordered content + slice
list + EOP tip; postable from EOP onward. Missing EBC ⇒ EMPTY-PENDING + certificate. Explicit
empty EBC: valid, unslashed, counted against `K_empty`, invalid when the forced snapshot is
non-empty (I6). One v4 addition: content may only anchor L1 blocks ≥ `D_anchor` deep at
sequencing time, making committed content immune to κ-reorgs of its own inputs (r3a-F5).

### 5.2 Publish — open fill, no escrow, no exclusivity (v4; r3a-F1/F2)

Remaining blob slices are due by `T_N + E + Γb` (24 slots) and are **postable by anyone from
the boundary** — no holder-exclusive window, and **no publication payment to anyone**:

- v3's publication escrow created a first-claimer prize — front-runnable by anyone who
  obtained the bytes from P2P streaming, washable by the holder's own sybil, and in tension
  with I7. v4 deletes it (I8). The holder publishes because it must (missed publication is a
  fault); a **successor fills because it protects its own parent** — it holds the data
  precisely when it built on it, and filling costs it bounded gas to avoid an empty parent it
  does not want. That structural incentive, not a bounty, is the mechanism; round-2 F10's "no
  incentive" concern is answered by naming it, and round-3's escrow attacks (front-run, wash,
  self-fill) have nothing left to capture.
- Removing exclusivity also removes round-3 F1's "exclusive right-of-way": there is no window
  in which fillers are forbidden, so censoring publication means censoring **every data
  holder** for the whole `32 + 24`-slot streaming + fill span — priced in §11.5, which now
  models publication (the chunkier, harder-to-include artifact) as the binding censorship
  target, not the seal.
- **Missing publication at `Γb`** (nobody — holder or filler — posted matching data) ⇒ the
  epoch flips EMPTY-PENDING + certificate on the holder. Successor exposure stays `Γb + κ ≈
  5.4 min`, provisional-on-P2P, auto-tolled (I4).

### 5.3 Sequencing and preconfirmations

As v3 (P2P envelopes + signed commitments binding tenure/epoch/index/hashes/deadline/EOP;
tenure-registry gossip validation; EOS handover; `handoverSkipSlots` retired).

### 5.4 Epochs without discretionary content are bounded (r3a-F6/F7/F10)

`K_empty` counts **every consecutive epoch in which the holder sequenced no discretionary
content** — explicit-empty *and* forced-only alike. Consequences: sybil forced-inclusion
traffic cannot reset the counter (F7); a holder cannot squat behind forced-only seals paying
only bounties (F10 — additionally, a holder sealing its own assigned forced-only epoch is
performing its duty and earns no recovery compensation; compensation exists only for
recovering *another* tenure's fault); and idling to termination pays quit-equivalent fees
(§4, F6). Forced content itself always flows (I6).

### 5.5 Seal

As v3: within `W_N` on the tolled clock, one proof-carrying seal finalizes the epoch's
canonical outcome (unique and always provable — I1); acceptance = finality; precomputable
proofs (§6.6); one small retryable transaction.

---

## 6. The epoch state machine

§6.1 single `openEpoch`, §6.2 lifecycle, §6.3 unbounded permissionless recovery lane, §6.4
empty and forced-only seals, §6.5 forced snapshots, §6.6 epoch-native identity — all as v3,
with these v4 clarifications:

- **§6.4/§6.5 (r3a-F13)**: the forced-only seal's data source is the forced-inclusion
  queue's own L1 blob data; forced-queue retention duty runs to `H_cancel` + margin like epoch
  data. Snapshot items whose blobs have genuinely expired (reachable only through the §6.7
  disaster path) are **voided with their queue fees refundable on L1**, and bridged messages
  they carried remain refundable through the bridge's own unprocessed-message path — a voided
  inclusion never burns user value (r3a-F3.1).
- **§6.5 forced snapshots are zk-gas-capped, and their fees follow the work** (r3b-F5): each
  epoch's snapshot admits forced items up to a **per-snapshot zk-gas cap** (not merely a count
  cap); overflow spills deterministically to the next epoch's snapshot. Each item's dynamic
  queue fee is paid to **the sealer of the epoch that consumes it** (a deterministic,
  state-recorded payee — I8), and the fee formula includes a component proportional to the
  item's zk-gas so that, by construction, the minimum forced-only seal is always funded at or
  above its proving cost — forced-inclusion spam raises the recoverer's payment with the
  burden instead of starving the fallback.
- **§6.6 (r3a-F5, r3b-F1)**: the claim "no L1-inclusion-time inputs in L2 execution" is now backed
  by [Appendix C](#appendix-c--l2-header-inputs-and-their-sources) — an enumeration of every
  L2 header/execution input, its source class, and why each is independent of L1 inclusion
  order, packing, and κ-reorgs (anchors via `D_anchor`). Deeper-than-κ reorgs rewind L1 records
  and L2 derivation together (§3.1) — no unilateral L2 design survives arbitrary L1 rewrites,
  and this one fails *closed* along the exceptional path.

### 6.7 Expiry cancellation — bounded disaster floor (r3a-F3)

If a PUBLISHED epoch is unsealed for `H_cancel`, anyone may cancel it: it re-resolves
empty/forced-only, and later **committed, unsealed** epochs that chained to it re-resolve in
the same deterministic cascade. v4 makes the bounds explicit, which v3 left implicit:

1. **Sealed state is untouchable** (immutability corollary, §0): the cascade operates only on
   the unsealed tail — it cannot revert finalized L2 history, ever.
2. **The cascade is structurally shallow**: recovery-only mode (I5) stops new content epochs
   once the lag exceeds `K`, so the committed-content unsealed tail — the only thing
   cancellable — never exceeds ≈ `K + d + s` epochs (~77 min of chain), not 14 days. A
   "publish a 14-day tail then cancel it all" attack cannot arise: the tail stops growing at
   `K`.
3. What *is* lost in a cancellation is the unsealed preconf-layer view of those ≤ `K + d + s`
   epochs — exactly the exposure preconfirmations always carry against their bond, here
   reachable only after ≥ 10 days of continuously flagged failure.
4. Forced snapshots of cancelled epochs re-queue at the front (data intact — retention outlasts
   `H_cancel`); voiding + refunds only per §6.4 above.

---

## 7. Backlog, tolling, bounds

As v3: universal descendant tolling (§7.1, I4); global lag cap + recovery-only mode (§7.2,
I5); retention (§7.4). One v4 change:

### 7.3 Recovery compensation (r3a-F14)

Compensation for recovering **another tenure's** fault is **indexed, not fixed**: a capped
multiple of prevailing L1 costs (base fee + blob base fee) plus the zk-proving component,
paid in ETH from the faulted tenure's seized prepaid ETH first, then from a **recovery
insurance pool** pre-funded by a small cut of every epoch fee. A sustained L1 gas spike
therefore raises the payout with the cost instead of starving recovery. Deterrence stays
burn-based: the TAIKO slash is ≥ 80% burned; empty/forced-only recovery earns a small indexed
amount; a tenure sealing its own epochs earns nothing (§5.4).

---

## 8. Faults, collateral, adjudication

As v3 (L1-mechanical liveness certificates; L2-with-proofs adjudication for content faults +
distributions; stable fault ids; safety supersession + clawback; ETH-floor-valued
reservation), with v4 refinements:

- **Certificate lifecycle** per §3.1: pending → settled(+κ) → debit at settlement. Recording
  functions are permissionless; a small **poke bounty** from the debited `L_slash` pays the
  recorder (round-2 §13.7, resolved).
- **Withdrawal gate** (§8.4): zero pending *and* zero unresolved-settled certificates, no
  unsealed assigned epochs, no in-flight verdicts, no active emergency/recovery-only mode —
  then the floor delay. Pending states self-resolve in `κ`, so gating on them cannot be used
  to freeze an honest exit.

---

## 9. Total Anarchy

As v3 — unowned epochs resolve EMPTY-PENDING and are sealed permissionlessly as empty or
forced-only (I6/I7); no discretionary content; recovery lane fully open; escrowed recovery
claims remain claimable — with the G5 reframing (r3a-F9) now explicit in §1: in Phase B
this is a **censorship-resistant fallback that anyone can exit by out-bidding the reserve
floor**; in Phase A it is **DAO-recoverable**, with the DAO fast-path SLA of §10.3. Bridge
flow during anarchy = forced-only cadence; queue data retention per §6.4 keeps long outages
refund-safe rather than value-destroying.

---

## 10. Bootstrap, parameters, emergency brake

§10.1 proving budget, §10.2 economic table — as v3, plus:

- **§10.2 additions**: recovery insurance pool cut (small % of epoch fees); indexed recovery
  rates (§7.3); poke bounty (§8); no price feeds anywhere (§4).
- **§10.3 Phase A SLA** (r3a-F9): the DAO pre-commits to a published fast path for allowlist
  expansion during anarchy (acting within `N_days`), and Phase A→B criteria are objective
  (§13-T).

### 10.4 Emergency brake — suspension and forgiveness are now different powers (r3b-F6)

r3b showed the v3 brake was self-serving: `openEpoch` age is exactly the state a seal-
withholding holder creates, so an age-triggered brake that forgives outage-window certificates
would let the accused erase its own liability. v4 splits the brake:

- **Suspension** (automatic, objective): when `openEpoch` age crosses the threshold, *future*
  deadline maturation pauses (no new faults accrue to anyone while the system is objectively
  stuck) and withdrawals freeze. Suspension **never erases anything**: faults matured before
  it stand, debited as normal.
- **Forgiveness** (attested, bounded): cancelling in-suspension certificates requires an
  independent outage attestation (in Phase A, the DAO; a permissionless proof-system-outage
  predicate is a §13-S design item), applies only to faults that matured **during** the
  attested window, and **never** to the holder(s) whose unsealed epochs drove the age
  trigger.
- Bounded duration, auto-expiry, backlog cap, and queued-verdict replay before any release —
  as v3.

---

## 11. Game-theory analysis (v4 deltas)

- **11.1 Squat economics**: idle-to-termination now pays quit-equivalent fees (§4);
  forced-only squatting counts against `K_empty` (§5.4); silent stall unchanged (certificate +
  debit + termination per miss).
- **11.5 Censorship, remodeled** (r3a-F1/F4, r3b-F6): the binding target is **publication**
  (blob payloads, `32 + 24` slot span, every data holder a potential includer since fill is
  open), then the seal (1 small tx, `32·s` residual slots). Targeted censorship of one
  holder's artifacts is priced by the corridor rule (`gain ≪ C_cen(span)`); **systemic**
  censorship that stalls `openEpoch` trips the brake's *suspension* — future deadlines pause,
  so a builder cartel cannot keep converting censorship into fresh slashes — while
  already-matured faults are erased only through the *attested-forgiveness* path, never by the
  age trigger alone (§10.4: otherwise a seal-withholding holder could forgive itself). What
  the design deliberately does **not** include is a self-attested "I was censored" toll
  (r3a-F4's option): mempool non-inclusion is not mechanically decidable on-chain, and an
  unfalsifiable attestation would hand every holder a free deadline-extension lever.
  Residual: short targeted censorship below the suspension threshold can still cost an honest
  holder one `L_slash`; the corridor keeps that unprofitable for the attacker, κ-grace
  resubmission keeps it rare, and attested forgiveness exists for verified systemic events.
  Stated plainly.
- **11.6 Escrow-capture class**: eliminated by construction (no publication payment; payees
  are state — I8).
- **11.7 Simulation plan additions**: publication-censorship spans, sybil forced-inclusion
  floods against `K_empty`, cancellation-cascade depth under recovery-only mode, brake-trigger
  boundary gaming, insurance-pool solvency under gas spikes.

---

## 12. Explicitly out of scope (v1 implementation)

Unchanged: per-transaction fair exchange; user restitution; multi-seat; based-validator
alignment; automated bond scaling.

---

## 13. Open issues

**13-S — Structural (blocking implementation)** (r3a-F15's split):

1. Deep-reorg (> κ) rewind semantics: precise joint rewind of records, certificates,
   `openEpoch`, and derivation (§3.1).
2. Cancellation-cascade determinism proof, including in-flight verdicts and re-queued
   snapshots (§6.7).
3. Appendix C completion to implementation granularity: every header/execution input signed
   off as inclusion-independent, with the EBC-inclusion-block origin rule (§6.6, I1).
4. Certificate lifecycle ↔ bridge verdict-queue interaction across forks and emergency mode;
   read-time maturity evaluation points enumerated (I2).
5. Parse-time resource bounds (decompression, RLP, tx sizes) specified for client **and**
   proof circuit, with degrade-without-allocation semantics (I1; r3b-F4).
6. Append-only record-spine retention and compaction design + storage-cost account (§3;
   r3b-F3).
7. Permissionless proof-system-outage predicate for brake forgiveness, or the finding that
   none exists (Phase A: DAO attestation) (§10.4; r3b-F6).
8. Phase-A DAO fast-path SLA definition (§10.3).

**13-T — Tuning (gates Phase B)**:

1. `Γb + κ` provisional successor window vs `Γpre` early-sequencing-cutoff trade (round-2
   §13.1, still open).
2. `K`, `K'`, `K_empty`, `H_cancel`, `D_anchor` calibration and threshold gaming.
3. Bridge-liveness SLA under long forced-only-cadence runs.
4. Recovery insurance pool sizing; indexed-rate caps.
5. Censorship-corridor quantification against real builder-market data.
6. Phase A→B objective criteria.
7. Client migration sequencing.

---

## Appendix A — Divergence from the brief (owner to confirm)

Items 1–8 as v3 (s = 2; termination on first settled fault; recovery claims in anarchy;
EBC-structural "same proposals"; allowlist replaces proof gate; boundary commit/publish;
content-free anarchy; L1-native liveness execution). New in v4: **9.** no publication payment
(successor self-protection replaces the escrow; I8); **10.** `K_empty` counts forced-only
epochs; idle exits pay quit-equivalent fees; **11.** **no oracles anywhere** (owner directive,
2026-08-20): ETH assumed stable-to-increasing; all bond/fee parameters TAIKO/ETH-denominated
as governance constants, adjusted prospectively only; the TAIKO-price-decline residual is
accepted and monitored off-chain; **12.** forced-inclusion fees follow the sealing work and
include a zk-gas-proportional component (§6.5).

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
| 8 (med) | (a) reservation not revalued at fault time; (b) no single liability ledger | (a) Moot under the no-oracle owner directive: debits and reservations are both TAIKO-denominated, so debits are always sufficient in token terms; the value-erosion residual is stated in §4. (b) Accepted: the L1 bond contract is the sole liability ledger; L2 verdicts instruct; idempotency enforced only there (§4) |

## Appendix C — L2 header inputs and their sources

Backing for §6.6's claim (r3a-F5). Source classes: **P** = parent chain state, **E** =
epoch schedule (known before `T_N`), **C** = committed content (EBC-bound), **X** = execution
result. None may be an L1-inclusion-time observation.

| Header / execution input | Today (Shasta) | v4 source | Inclusion-independence |
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
| anchor tx params (`anchorBlockNumber/Hash/StateRoot`) | holder-chosen recent L1 block | **C**, constrained: ≥ `D_anchor` deep at sequencing, epoch-relative freshness floor (**E**) | κ-reorg-immune by depth; > κ ⇒ exceptional joint rewind |
| forced-inclusion prefix | dequeued at proposal inclusion | per-epoch snapshot fixed before `T_N` (**E**) | round-1 F7 fix |
| `stateRoot`, `receiptsRoot`, `logsBloom`, `gasUsed`, blob-gas fields | execution | **X** | — |

**Derivation-origin rule (r3b-F1):** where derivation needs any L1 origin reference at all,
it is the **EBC's L1 inclusion block** — fixed at commit time, within `Γc + κ` of the epoch
boundary. The seal's L1 inclusion (block, timestamp, sender) contributes **nothing** to
derivation, so seal timing — normal, tolled, recovered, or years late in the recovery lane —
cannot change the outcome, and the legacy `TIMESTAMP_MAX_OFFSET` / `MAX_ANCHOR_OFFSET`
inclusion-relative bounds are fully replaced by the epoch-relative bounds above.

Completion to implementation granularity (every fork-specific field, genesis edges) is
blocking item §13-S.3.
