# Taiko Based Preconfirmation Redesign — Perpetual Auction with Commit → Publish → Seal Epochs

> **Deliverable 2 of the preconfirmation redesign effort. Draft v11, 2026-08-21** — revised after
> adversarial review rounds 1–7 (eleven reviewer passes:
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
> 5–6, in [`simulation/RESULTS.md`](simulation/RESULTS.md) and the PR thread. **v7** folded in
> the owner-approved self-review simplification round: a single present-at-`D+κ` acceptance
> rule, a deadline-only seal (the `d` deferral removed), `H_force` retired into the seal
> deadline, one ETH account per tenure with a seniority waterfall, and an attempt to restore
> Total Anarchy's discretionary content via atomic proof-carrying proposals
> ([Appendix A](#appendix-a--divergence-from-the-brief-owner-to-confirm) #24–28). **v8** is the
> owner-mandated **post-simplification regression audit**: every finding from all six review
> rounds was re-checked against the v7 changes. The four structural simplifications (#24–27)
> hold every prior closure; the anarchy-content restoration (#28) **re-opened round-2 finding
> 6's empty-front-running horn and is reverted** — anarchy is forced-only/empty again, with the
> repair path recorded in §13-T for a future revision. **v9** responds to round 7
> ([r7 DeepSeek on v8](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5358215959)):
> a normative **maximum tenure duration `T_max`** replaces the Sybil-resettable `K_empty` as the
> binding idleness/censorship bound (#29), slice availability is judged **at the single decision**
> (first inclusions and re-posts alike), the cascade charge is collateralized as a recovery-class
> liability, and the model checker now covers **proving outages**. **Round-8 hardening
> (2026-08-21)** — a DeepSeek pass on the verification artifact plus an independent multi-agent
> adversarial + monopoly self-review — changed **no mechanism**: the sweep confirmed no
> fund-freeze/theft, no reachable invalid state, and no *harmful* monopoly (the auction is
> highest-bidder-wins by design — an accepted, now-stated economic property, not a bug — because
> censorship is priced independently of the seat, forced content always flows, and `T_max`
> re-prices occupancy). It landed model-checker rigor (deadlock-freedom scoping, a
> path-independent seal-immutability edge check, debit-solvency) and a set of doc-precision
> corrections (discretionary-vs-forced content tail, the cancellation floor's general
> no-valid-seal trigger, one-epoch equivocation exposure, capped recovery rate, `T_max`
> occupancy semantics); dispositions in [Appendix B](#appendix-b--review-dispositions). **v10
> (2026-08-21)** responds to **round 9** — two independent reviews, an adversarial security pass
> and a comparative implementation-readiness pass, merged (with dispositions) into
> [`review-loop/round9-consolidated-review.md`](review-loop/round9-consolidated-review.md).
> v10 pins the mechanisms round 9 showed were load-bearing but unspecified: the **availability
> certificate** that makes the `D+κ` presence decision L1-evaluable (§5.2), the **EBC acceptance
> predicate** (a malformed or unsigned submission is inert and never consumes the one-shot —
> §5.1), **L1-direct slashing of double-EBC equivocation** plus an **adjudication-latency-sized
> `L_safety` and a funded accuser reward** for the L2-evidence variant (§8, §11.2), a
> **mechanical seal-expiry/cancellation cutoff** replacing the unobservable "no valid seal
> possible" gate (§6.7), **attested-outage tolling and charge socialization** so a systemic
> proving outage neither slashes nor bankrupts honest holders (§6.7, §10.4), the
> **forced-snapshot membership rule** and the `F_delay ≥ E + margin` constraint (§6.5), the
> **bridge terminal-cancellation handshake** so a voided forced bridge message can always
> recall its source principal (§6.4), an **L1-legible `K_empty`** (§5.4), the
> `freshness_ceiling ≥ D_anchor + Γc + κ + R + margin` parameter invariant (§6.6), min-span
> censorship pricing (§11.5), and narrowed wording for the `T_max`, "chain keeps moving", and
> "hard preconfirmation" claims. **v11 (2026-08-21)** responds to **round 10**
> ([r10 adversarial comment](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5365112264)):
> a HIGH design blocker — Appendix C sourced `timestamp`/`gasLimit`/anchor from EBC-committed
> content, leaving **no canonical header source for any epoch that resolves without an
> accepted EBC** (unowned epochs, missed commits, cancellation re-resolutions), so a
> range-only implementation would hand the first-landed sealer a retrospective
> timestamp/anchor option over two valid-looking forced-only outcomes (breaking I6/I7 and the
> anarchy→assigned handoff), while an EBC-requiring circuit would make the forced-only seal
> unconstructible. v11 closes it with the normative **default derivation rule** (§6.8): every
> no-EBC resolution's block sequence is a pure function of
> `(chainId, epoch, index, canonical parent, forced snapshot)` — deterministic timestamps,
> epoch-deterministic anchor, inherited gas limit, deterministic partitioning — plus the
> **clock-capacity invariant** (forced block count ≤ `E` per epoch, deterministic spill), an
> explicit default-derivation branch in the seal circuit, Appendix C updates, and the
> `ANARCHY(forced) → ASSIGNED(content)` conformance-vector obligation (§13-S.18).
> Design only — mechanisms, invariants, incentives, parameters.
> Baseline: [`status-quo.md`](status-quo.md); owner decisions: its §6 and
> [Appendix A](#appendix-a--divergence-from-the-brief-owner-to-confirm).
>
> **Normative precedence** (round 9, B6): sections §0–§13 and the appendices of *this document*
> are the normative design record. The README, the learning deck (`slides/`), the model
> checker, and the review reports are derived artifacts; where any of them disagrees with this
> document, this document governs, and the divergence is a documentation bug to fix, never an
> alternative reading to implement.
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
  nothing after `D + κ` can change it (fixed at `D + κ` as a pure function of canonical L1
  history; materialized on-chain per §3.1/§5.2 — v10). There is no second grace: maturity, settlement,
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
  recovery-only mode (no new *discretionary* content, no fees) until the lag clears. All
  retention, collateral, and prover sizing is dimensioned against `K`, and — corollary — **the
  *discretionary*-content-bearing unsealed tail can never exceed ≈ `K + S` epochs**. (Recovery-
  only mode stops discretionary content only; forced content still flows — I6 — so the
  *forced-only* decided-unsealed count can exceed `K + S` during a long proving-outage stall,
  but that tail is self-funding — each forced-only seal is paid at or above its proving cost by
  its own forced fees (§6.5), its data is on L1 by construction, and it drains via the rung-1
  fast path or re-queues intact rather than being voided at any tenure's expense. Only the
  *discretionary* tail is value-at-risk collateral, and it is what `K + S` bounds — §6.7.)
- **I6 — Forced inclusions are censorship-proof against the seat.** A non-empty forced
  snapshot makes the epoch's minimum valid outcome the deterministic forced-only epoch,
  constructible and provable by anyone from L1 data alone; empty is then invalid.
  "Deterministic" is discharged by the **default derivation rule** (§6.8, v11): when no
  accepted EBC exists, every header and execution input of the forced-only outcome is a pure
  function of `(chainId, epoch, index, canonical parent, forced snapshot)` — no field is left
  to the sealer's, sender's, or L1 builder's choice.
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
commit     by T_N + E + Γc               EBC commits its blob-slice hashes; valid only if every
                                         referenced slice commitment is on L1 at the decision (D+κ) — v9
parent final at T_N + E + Γc + κ         SINGLE decision (I2): content-or-empty, fixed by canonical
                                         L1 history at this instant, irreversible
resolve    within R of the decision      availability certificate (§5.2, v10): permissionless SSZ
                                         commitment-inclusion proofs materialize the CONTENT branch
                                         on L1; no certificate within R materializes EMPTY
seal       due by T_N + S·E (tolled)     one proof-carrying seal finalizes the epoch; valid from
                                         the moment the epoch is the openEpoch with its decision
                                         final — early seals welcome (v7: no deferral lower bound)
```

There is exactly **one** finality decision per epoch, at `T_N + E + Γc + κ` (≈ 7 slots into the
successor's epoch). Publication is not a separate later deadline: the EBC is valid only if the
blob slices it references are already on L1 by the decision — **first inclusions and
byte-identical re-posts alike** (v9, r7-2; the `κ` grace is *not* re-post-only: a slice or EBC
whose *first* landing falls anywhere in `(D, D+κ]` is exactly as valid as one landed by `D` —
§3.1, §5.2). The decision's *outcome* is a pure function of canonical L1 history at `D+κ`; its
*on-chain materialization* is the §5.2 availability certificate (CONTENT) or the `R`-window
timeout (EMPTY) — the same computed-state-materialized-on-read discipline I2 already applies to
faults. This removes v6-draft's second `Γb`-based decision (the audit-flagged inconsistency).

| Param | Meaning | Initial | Notes |
| --- | --- | --- | --- |
| `S` | seal deadline (epochs past `T_N`, tolled) | 4 | v7: deadline-only — replaces v6's `[T_N+d·E, T_N+(d+s)·E)` window (`d,s = 2,2`; same end time). Proving latency needs a deadline, not a ban on early seals: I1 fixes the outcome and I7 makes it sender-free, so sealing early is always valid and strictly shrinks the unsealed tail. §10.1 |
| `q` | auction transition delay (epochs) | 2 | current + next final |
| `Γc` | EBC deadline past boundary | 4 slots | lowered v6 (r4c-3) to shrink the successor's last-look exposure |
| `κ` | reorg / inclusion grace | 3 slots | single-grace lifecycle §3.1, I2 — covers first landings and byte-identical re-posts alike (v10 wording fix); parent-final at `Γc+κ = 7 slots` (~22% of the successor epoch), not 27 |
| `R` | availability-resolution window past the decision | 16 slots | v10 (r9-A1): window in which the permissionless availability certificate (§5.2) must land; must be ≪ the EIP-4788 root-buffer span (8191 slots) with margin; a certificate after `R` is rejected (artifact-set closure) |
| `F_delay` | forced-inclusion delay (submission → due) | 576 s (current deployment) | v10 (r9-C1): consensus constraint `F_delay ≥ E + F_margin` where `F_margin` covers the snapshot-fix lead time (§6.5); an item is *due* at `submission + F_delay` and belongs to the snapshot of the epoch containing its due time |
| `Λ` | equivocation adjudication-latency ceiling | 2 epochs (target) | v10 (r9-B1): normative ceiling on L2-evidence safety-verdict settlement; `L_safety ≥ Λ ×` per-epoch MEV bound (§8, §11.2); ceiling itself Phase-A-blocking (§13-S.4) |
| `D_anchor` | minimum committed-anchor depth | 32 slots (1 epoch) | the EBC-committed anchor must be ≥ this deep at commit time; sized for L1 reorg safety, not "minimum useful" (v5, r4a-C2/H8) — raised from v4's 4 |
| `K` / `K'` | global lag cap / exit | 8 / 4 epochs | recovery-only mode (I5) |
| `K_empty` | max consecutive epochs **without an accepted content-bearing EBC** | 16 | v10 (r9-A3): redefined on the L1-legible form — absent, explicit-empty, or forced-only EBCs all count; nuisance bound only, `T_max` is the binding bound (§5.4) |
| `H_cancel` | published-unsealed expiry-cancellation horizon | 10 days | disaster floor (data loss *or* permanent proving outage — §6.7); **mechanical cutoff** (v10, r9-F2): seals valid strictly before `T_exp`, cancellation at/after it, no overlap; attested-outage tolling of `T_exp` bounded by `H_toll_max` (§6.7). + margin < blob retention (~18 d) for epoch **and forced-queue** data |
| `H_toll_max` | total attested-outage tolling cap on `T_exp` | 20 days | v10 (r9-F5/A6): bounds how long attested outages can defer expiry so I3's proof-free exit always eventually fires; per-window attestations auto-expire (§10.4) |
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
**Presence means presence of an *accepted* artifact, and acceptance is a normative predicate**
(v10, r9-A2): a submission is accepted only if it is (i) well-formed for its artifact type,
(ii) carries a valid signature by the tenure's *registered* commitment keys (§2) for exactly
that `(chain id, tenure id, epoch, role)` binding, and (iii) targets an unconsumed one-shot.
**A submission failing (i) or (ii) is inert — a no-op that consumes nothing**: it cannot burn
the one-shot, cannot fault the holder, and cannot displace a later valid artifact. The one-shot
is consumed only by the **first accepted** artifact; byte-identical re-lands of it are no-ops;
and a second *distinct accepted* artifact is not merely "invalid" — it is **irrefutable
on-chain equivocation evidence** recorded against the tenure and slashed L1-directly (§8).
Without this predicate, "first-landed wins" would let a griefer burn every honest holder's
one-shot with one unsigned transaction per epoch — the round-9 A2 attack; with it, only the
holder's own keys can consume or equivocate its slots. So the honest submission budget for
every deadline artifact is the full `D + κ` span (`Γc + κ = 7` slots for the EBC — G3), while
the moment the world learns the outcome is unchanged (`D + κ` was already the earliest a
successor could rely on the artifact set, since a reorged copy may reappear until then). At
`D + κ` a single transition fires and is irreversible: present ⇒ accepted, absent ⇒ certificate
settled + parent outcome fixed + `L_slash` debitable. There is no "pending, then a second κ": maturity,
settlement, parent-state irreversibility, and artifact-set closure coincide, so a byte-identical
artifact arriving after `D + κ` is rejected (it cannot revive content or clear a settled slash),
and I4's `Γc + κ` finality bound is exact rather than `2κ`-loose. **Fixed-at vs
materialized-at** (v10, r9-A1): "fires at `D + κ`" means the transition's outcome is a pure
function of canonical L1 history at `D + κ` — nothing later can change *which* branch is taken.
Its on-chain *materialization* follows I2's computed-state discipline: for the EBC's
slice-availability component, a permissionless **availability certificate** within the `R`
window (§5.2) materializes CONTENT and the `R`-timeout materializes EMPTY; for pure
artifact-presence components, any dependent read computes and materializes directly. An
observer with L1 access knows the outcome with certainty at `D + κ`; only the contract-legible
record may lag by ≤ `R`, and every dependent on-chain path reads through the materialization,
never around it. Withdrawal gating counts
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
     recovery obligations **plus its worst-case cancellation-cascade charge** (bounded by the
     ≤ `K + S`-epoch cancellable tail — §6.7; v9, r7-6), at indexed cost caps; pays fault-paid
     resolutions of *this tenure's* faults (§7.3) and the cascade charge. Both are
     **recovery-class liabilities**: if the tranche is somehow exhausted, the residual falls to
     the shared pool (§7.3) and **never** to the safety tranche — theft deterrence is not
     spendable on liveness debts.
  2. **Safety tranche `L_safety`** — the equivocation/MEV-theft slash (I9), value-fixed in ETH
     from tenure start and sized to **`Λ ×` the per-epoch extractable-MEV bound** (v10, r9-B1:
     the exposure window for the L2-evidence equivocation variant is the adjudication latency
     `Λ`, not one epoch; the double-EBC variant settles L1-directly with no latency — §8,
     §11.2). Renewal at the `T_max` re-auction requires topping the tranche up to the
     *then-current* sizing, so a value-fixed tranche cannot silently erode below the MEV it
     deters across a multi-week tenure sequence.
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
    (v7 waterfall above), sized to exceed **`Λ ×` per-epoch extractable MEV** (v10; `Λ` = the
    normative adjudication-latency ceiling, §3 table — one epoch only if verdicts settle that
    fast, which §13-S.4 must pin, not assume). It backs the equivocation/safety slash (the only fault that lets
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
- **Maximum tenure duration `T_max` (v9; r7-1/r7-4).** Every tenure **expires** after at most
  `T_max` epochs (a governance constant on the order of weeks; value is §13-T tuning, existence
  is normative and Phase-A — §13-S.13) and the seat **re-auctions**: the incumbent may rebid on
  equal terms (topping up to the then-current reservation *and* safety sizing — v10), transitions
  keep the `q` delay, and the already-assigned tail is honored — but no
  tenure holds the seat past `T_max` without winning it again. **Precise claim (v10, r9-F1):
  `T_max` is the objective tenure-renewal / re-pricing bound** — a pure function of
  on-chain state (no demand oracle, no Sybil predicate) that caps how long any *tenure* — idle,
  censoring, or griefing — holds the seat without re-winning it at auction, and hard-caps a
  Sybil-griefing tenure's runway (§11.2). It is **not** an actor-level censorship bound: the
  same economic actor may re-win indefinitely, and the protocol's *transaction-inclusion*
  liveness floor is carried by the **forced queue** (I6, §6.5) — always, independently of who
  holds the seat — not by seat turnover. Expiry is not a fault: no slash, ordinary
  quit-equivalent fee treatment. (Divergence from the brief's unbounded perpetual seat:
  Appendix A #29.)
  - **What `T_max` does and does not bound** (self-review, monopoly review). It bounds
    *recurring, re-priced occupancy of a tenure-id* — no id squats the seat for free past
    `T_max`; every renewal is re-priced at the perpetual auction against honest bidders. It does
    **not** promise a well-capitalized actor cannot *keep re-winning*: this design is
    highest-bidder-wins, and durable highest-bidder control is an **accepted economic
    property**, not a bug. That is not a *harmful* monopoly, because the seat confers no durable
    power to deny a determined user — censoring a specific user's content is priced *separately
    and independently of the seat* (the publication corridor, §11.5), forced content **always
    flows** regardless of who holds the seat (I6, §5.4), and recovery is permissionless (§6.3).
    The incumbent's realized-MEV information edge in each re-auction is the one genuine
    incumbency advantage, flagged for calibration in §13-T.2. "Permissionless" here means *open
    entry, no gatekeeper* (Phase B), not *no economic winner*.
- **Termination** on: settled fault certificate, bond below reservation, `K_empty` consecutive
  epochs without an accepted content-bearing EBC (the L1-legible form — §5.4; fee-continuation
  above; no slash), or **tenure expiry at `T_max`** (re-auction, not a fault).
- **One canonical liability ledger** (r3b-F8b): the L1 bond contract is the sole ledger;
  L2 verdicts and every transport only *instruct* it; idempotency (the logical-id
  consumed-set) is enforced exclusively there, at execution.

---

## 5. The per-epoch pipeline: commit → publish → seal

### 5.1 Commit — the epoch-boundary commitment (EBC), over already-published data (v6)

One-shot per (tenure, epoch), due `T_N + E + Γc` (4 slots; accepted until `+κ` under §3.1's
present-at-`D+κ` rule, so the honest budget is the full 7 slots), **acceptance-gated by §3.1's
predicate** (v10, r9-A2: only a well-formed artifact validly signed by the tenure's registered
commitment keys for this epoch is *accepted*; anything else is an inert no-op that does not
consume the one-shot; a second distinct *accepted* EBC is L1-direct equivocation evidence —
§8), binding the full ordered content,
EOP tip, committed L1 origin (I1), and the **hashes of its blob slices** — the holder normally
streams its data to L1 *during* its own sequencing epoch and the EBC references it, rather than
promising to publish later; availability is judged **at the single decision**, not at the
boundary (v9, §5.2). Consequence (r4c-3): the epoch's **content-or-empty outcome is
decided by the EBC alone**, at `T_N + E + Γc + κ = 7 slots` into the successor's epoch, versus
~27 slots under a separate late-publication deadline. Missing EBC ⇒ EMPTY-PENDING + certificate,
and the epoch's empty/forced-only outcome derives by the **default rule** (§6.8, v11 — no EBC
field is needed to construct or prove it). Explicit empty EBC: valid, unslashed,
counted against `K_empty`, invalid when the forced snapshot is non-empty (I6 — the epoch then
also derives by the default rule, the invalid EBC contributing nothing). The committed
anchor must be ≥ `D_anchor` (32 slots) deep and satisfy the freshness-and-advancement floor of
§6.6; because the origin is committed *content*, no L1 reorg of the EBC's inclusion changes what
the epoch derives to (I1).

### 5.2 Publish — availability is part of EBC validity, fault-only fill (v6; r3a-F1/F2, r4b-H2)

Publication is **not a separate deadline**: the holder streams blob slices to L1 during its own
epoch, the EBC references them, and **the EBC is valid only if every referenced byte is on L1
at the single decision `D + κ`** (§3.1's present-at-`D+κ` rule applies to slices exactly as to
the EBC — **first inclusions and byte-identical re-posts alike**; v9, r7-2 — evaluated on L1
as *commitment inclusion* plus the seal's byte binding, per the availability-certificate
mechanism below; v10). So the epoch's
content-or-empty outcome is one decision at `Γc + κ`: valid EBC with all referenced bytes
present ⇒ content; otherwise ⇒ empty. "Nothing new can be introduced" means nothing outside
the EBC's committed hashes — never "nothing after the boundary": a slice delayed past `T_N + E`
still lands validly any time before `D + κ`, from **any** data holder (P2P gossip spreads the
slices during the epoch), so the last-produced slice has ≥ `Γc + κ = 7` slots of inclusion
budget and earlier slices up to `32 + 7`. Censoring an honest holder's content therefore
requires suppressing *every referenced slice from every data holder for its full span* — with
the honest caveat (v10, r9-A5) that the *binding* span is the weakest link's, ≥ 7 slots for the
last-produced slice, priced as such in §11.5. This preserves the r4b-H2 rebuttal
(a third party cannot fault an honest holder — filling only helps) and defines **one**
irreversible decision rather than two.

**How the decision is evaluated on L1 — the availability certificate (v10, r9-A1; normative,
Phase-A-blocking §13-S.15).** "Every referenced byte is on L1" is not literally evaluable by an
L1 contract — contracts cannot read blob data, and EIP-4788 exposes beacon-block *roots* while
blob KZG commitments live in the beacon-block *body*. The check the protocol actually performs
is **commitment inclusion**, in two halves that together bind bytes to the decision:

1. **On L1 (the decision half):** the EBC references its slices by **blob KZG commitment**. A
   permissionless, sender-free **availability certificate (AC)** transaction proves, for every
   referenced commitment, an SSZ generalized-index Merkle proof (SHA-256, verified against an
   EIP-4788 beacon root) that the commitment is a member of `blob_kzg_commitments` in a
   canonical beacon block **at or before slot `D + κ`**. The AC is accepted only within the
   `R`-slot resolution window after the decision (§3 table; `R` sized well inside EIP-4788's
   8191-slot root buffer, so the proof is always constructible while the window is open).
   First accepted AC wins; re-lands are no-ops; an AC after `R` is rejected (artifact-set
   closure, §3.1). **CONTENT materializes iff an AC is accepted; if the `R` window closes with
   no AC, EMPTY materializes by timeout** — absence never needs proving, exactly as fault
   maturity under I2. The AC needs no private witness: it is constructible by *anyone* running
   a beacon node from public data, so the holder, any preconf recipient, or any altruistic
   party can submit it, and censoring it means censoring a small, arbitrarily-fee-bumpable
   calldata transaction from every possible sender for `R` slots (priced in §11.5).
2. **In the seal circuit (the bytes half):** the seal proof opens each KZG commitment and
   proves the derivation consumed exactly the committed bytes. The AC establishes *the
   commitments were on L1 by the decision*; the seal establishes *the bytes are what the
   commitments commit to* — neither half alone claims "bytes on L1", together they do.

**Cost attribution (r9-A1's unspecified-payer point):** EMPTY costs nothing — it is a timeout,
never a transaction anyone is saddled with. The CONTENT-side AC is paid by its submitter — in
the honest case the holder, whose per-epoch content already depends on it (KB-scale SSZ
branches through the SHA-256 precompile; a bounded, budgetable per-epoch overhead accounted in
§10.2, ~225 epoch decisions/day chain-wide at worst). No third party's unrelated transaction
(a withdrawal, a successor's EBC, a poke) ever carries a parent epoch's resolution cost: reads
that depend on the parent's outcome read the materialized AC record or the closed `R` window —
a storage read, not a proof verification. **Successor consequence:** the parent's outcome is
*information-final* at `D + κ` (any beacon-node observer knows it with certainty) and
*contract-legible* at AC acceptance or `R`-timeout, ≤ `R` slots later; the successor's
soft→hard preconf upgrade (below) keys off the information-final instant, and any on-chain
path that needs the parent's outcome keys off the materialization, which the successor itself
can accelerate by submitting the AC.

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
equivocation-slashable) preconfs once its parent is final. **What "hard" promises — and does
not** (v10, r9-F4): a hard preconf is a commitment whose *equivocation* is objectively provable
and slashed for `L_safety` — a **deterrence** guarantee sized against the equivocator's own
extractable gain over the `Λ` exposure window, **not a compensation guarantee**: user
restitution is out of scope (§12), the aggregate economic reliance users place behind an
epoch's promises is neither metered nor capped by the protocol, and an L1 reorg deeper than
`κ` can still revert even sealed state (§1). Applications valuing a promise above the
deterrence it carries must price that residual themselves; the design deliberately does not
imply the slash makes anyone whole. The predecessor's residual "last-look"
shrinks from ~84% of the successor epoch to ~22%, and — critically — a predecessor that
*published on time* (data referenced by its EBC) has **no** last-look at all: its outcome is
locked by its own EBC, not by a later choice. The remaining ~7-slot soft window is the honest,
bounded characteristic of deferred publication, stated here rather than left open; driving it to
zero (predecessor ends sequencing `Γc+κ` early, ~22% duty-cycle cost) stays a §13-T lever.
Stated for completeness (v8 audit, re: r4c-3): under §3.1's present-at-`D+κ` acceptance rule a
holder may also *deliberately* withhold its ready EBC until slot 7 — its content-or-empty
optionality spans the same 7 slots the successor already treats as provisional, so the
successor's exposure is unchanged; the rule moves inclusion risk off honest holders without
giving strategic ones anything the soft window had not already priced.
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

**v10 (r9-A3) — the counter is now defined on what L1 can actually see.** v9 defined `K_empty`
over *post-derivation output* ("no non-system content from an address outside the tenure's
registered key set") — but that predicate lives inside derivation and proofs, and the
explicit-empty epoch's seal is **proof-free** (I7), so no artifact would ever carry the count
to L1: as written it was not mechanically implementable, and an idle holder could evade it by
never submitting a content proof at all. The normative counter is therefore the **L1-legible
form**: `K_empty` counts **every consecutive epoch with no accepted content-bearing EBC** — the
EBC is absent, explicit-empty, or references only the forced snapshot — a pure function of the
L1 record spine (§3), incremented at each epoch's decision and computable by the termination
path directly. **Two honest consequences.** (1) It is *stuffing-evadable*: a holder can commit
a self-dealing slice each epoch to look busy, at the recurring cost of real blob fees plus its
own per-epoch protocol fee — L1 cannot see *whose* content a blob carries without a proof. (2)
It remains *Sybil-resettable* in spirit — fresh-address linkage is undecidable. Both are why
`K_empty` is a **nuisance bound** (it still terminates lazy idlers cheaply and keeps the
fee-continuation economics) and **not** the binding idleness/censorship guarantee; the binding,
objective bound is the **maximum tenure duration `T_max`** (§4), which needs no content
predicate at all. Consequences: sybil forced-inclusion traffic cannot reset the
counter (F7); a holder cannot squat behind forced-only seals paying only bounties (F10 — a holder
sealing its own assigned forced-only epoch earns no recovery compensation); idling to termination
pays quit-equivalent fees (§4, F6). Forced content always flows (I6). Forced-only fee income to a
single tenure is capped at `K_empty · a_forced`, excess to treasury (r4a-M13).

**Resolved in v9** (r4c-9 → r7-1): the caveat this section used to carry — that a rigorous
censorship bound needs a **maximum tenure duration** because on-chain state cannot distinguish
censored demand from no demand — is no longer a deferred decision. `T_max` is normative in §4
as the tenure-renewal / re-pricing bound (v10 wording, r9-F1), with `K_empty` as the faster
nuisance path against lazy idlers only — and the *transaction-inclusion* censorship floor is
carried by the forced queue (I6), not by either counter.

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
  disaster path) are **voided with their queue fees refundable on L1** — a voided
  inclusion never burns user value (r3a-F3.1).
- **Bridge terminal-cancellation handshake (v10, r9-cB1; normative, Phase-A-blocking
  §13-S.16).** The queue-fee refund alone is not principal safety: a voided forced item that
  carried a bridge message leaves the *source-side principal* locked in the message's `NEW`
  state, and today's `recallMessage` unlocks it only against a proof of a *destination-side*
  `FAILED` signal — which a never-executed destination transaction never creates. The design
  therefore requires the bridge to accept a second, equivalent recall predicate: **a canonical
  proof that the forced item carrying `msgHash` reached the terminal `refunded` state (and is
  not `consumed`) in the L1 forced-queue lifecycle (§6.5's nullifier)**. Because the refund
  transition atomically kills every live containing commitment and every seal proof rejects a
  `refunded` item, "refunded on L1" and "executed on the destination" are **mutually exclusive
  by construction** — the recall can never double-spend against a later execution, and the
  exclusion is an explicit conformance-test obligation (§13-S.16). This is a required change to
  the Bridge contract surface, named here rather than assumed.
- **Every forced item has one canonical lifecycle nullifier** (r4c-6): each item advances
  `queued → snapshotted → {consumed | refunded}` on L1, and **the beneficiary/payer is stored
  at enqueue time**. Every seal proof takes the item's status as a public input and **rejects a
  `refunded` (or already-`consumed`) item**; a refund transition **atomically kills every live
  containing commitment** (snapshot slot, EBC reference). So the expiry refund and any later
  L2/bridge execution of the same item are mutually exclusive by construction — closing the
  "retain the blob, let a snapshot commit, then also claim the refund" double-spend. The current
  forced queue stores only fee + blob slice; this lifecycle+nullifier is new required state
  (§13-S).
- **Snapshot membership is a normative due-time rule, and the delay parameter is
  consensus-constrained** (v10, r9-C1). Epoch `N`'s forced snapshot contains **exactly the
  queued items whose *due time* (`submission + F_delay`) falls in `[T_N, T_N + E)`**, in queue
  order — *not* "everything queued when the snapshot is fixed": with any `F_delay > E` an item
  submitted late in epoch `N−1` is due only in `N+1`, and a "queue-everything" snapshotter
  would include items a due-time-checking seal circuit must reject, making the forced-only
  seal unbuildable and stalling the epoch to cancellation — a client/circuit consensus fork
  hiding in an unpinned membership rule. Two consensus constraints follow: **`F_delay ≥ E +
  F_margin`** (where `F_margin` covers the lead time between snapshot fixing and `T_N`), so
  every due item is already queued when the snapshot is fixed; and **the snapshot's item set
  (as an ordered commitment) is a public input of every seal proof consuming it**, so client
  and circuit agree byte-for-byte or the proof does not verify. The current deployment's
  `forcedInclusionDelay` (576 s = 1.5 E) already satisfies the inequality; the *rule* — not
  the value — is what was missing, and configs (Hoodi, devnets) must be audited against it
  (§13-S.17).
- **§6.5 forced fees are priced from L1-measurable upper bounds, not unmeasurable zk-gas**
  (r4a-H10, r4b-H6): L1 cannot measure zk-gas at `saveForcedInclusion`, so the fee is
  `a + b·bytes + c·declared_gas`, where `bytes` and `declared_gas` are L1-observable at
  submission and `a`, `b`, `c` are **conservative governance constants that upper-bound the
  worst-case circuit cost per byte and per declared-gas** (the worst circuit/byte and
  circuit/gas ratios are a bounded, named quantity — §13-S.5, alongside the parse-time caps
  that make the ratios finite). `a` (the per-item base) makes a griefer's cost scale with the
  *count* of items, not their size, so tiny-item floods (r4a-H10) pay for the sealing overhead
  they impose. Each snapshot admits items up to a per-snapshot bound; overflow spills
  deterministically to the next epoch. **The bound is double-dimensioned (v11, r10):** it caps
  zk-gas *and* the deterministic partition's block count (`≤ B_max ≤ E` blocks — §6.8's
  clock-capacity invariant), so a default-derived forced-only epoch always fits its
  one-second-per-block timestamp budget. Fees are paid to the **consuming epoch's sealer** (a
  state-recorded payee — I8). By construction the minimum forced-only seal is funded at or above
  its proving cost; a residual (a workload whose true circuit cost still exceeds the conservative
  bound) is closed by settling the shortfall from the recovery pool (§7.3). **The bounded
  worst-case circuit/byte and circuit/gas ratios are a Phase-A precondition, not a follow-up**
  (v9, r7-5): §13-S.5 is [Phase A]-blocking, and forced-fee acceptance does not go live until
  the finalized ratios back the constants — before that the funding claim is explicitly "to be
  proven", not "by construction" (conceding r4b-H6's precision point).
- **§6.6 epoch-native identity + anchor freshness/advancement floor** (r3a-F5, r3b-F1, r4b-M7):
  backed by [Appendix C](#appendix-c--l2-header-inputs-and-their-sources). The EBC-committed
  anchor must (a) be ≥ `D_anchor` (32 slots) deep — reorg safety; (b) not lag the epoch's own
  `T_N` by more than a governance **freshness ceiling**, where the parameter setter
  **mechanically enforces `freshness_ceiling ≥ D_anchor + Γc + κ + R + margin`** (v10, r9-C2:
  with a ceiling below that sum no valid EBC could exist at all — every epoch would resolve
  EMPTY and slash its holder for a governance bug; the interdependence is a checked invariant
  in the setter, not calibration folklore — §13-T.3) — so a holder cannot fake "serving" on
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
- **`H_cancel` (10 days) — the disaster floor, with a mechanical cutoff** (v10, r9-F2/B4).
  v9 gated cancellation on "no valid seal is possible for the full horizon" — but *possibility*
  is not an L1-observable predicate (L1 sees that no seal was *accepted*, never that none
  *could exist*), and leaving seal and cancel simultaneously enabled after the horizon would
  let L1 transaction ordering choose whether content survives — breaking I7's
  sender/order-independence exactly where it matters most. The rule is therefore **mechanical
  and overlap-free**: each decided epoch has an expiry instant `T_exp = ` (its
  decision-final instant) `+ H_cancel` **on the tolled clock** (I4 ancestor tolling, plus the
  bounded attested-outage tolling below). **Seals are valid strictly before `T_exp`;
  cancellation is enabled at and after `T_exp`; no L1 block can accept both.** Stated plainly:
  unsealed content **expires** at `T_exp` even if a valid proof privately existed a moment
  earlier — expiry is a deadline outcome, not an impossibility oracle, and the two disaster
  realizations (data genuinely unavailable; a proving outage that never lifts) are simply the
  two reasons the deadline can be reached. From `T_exp`, anyone may **cancel**: the epoch
  re-resolves empty/forced-only from whatever L1 data survives, and later **committed,
  unsealed** epochs that chained to it re-resolve in the same deterministic cascade.
  **Attribution is split, not blanket** (v10, r9-F5/C3): a cancellation reached with **no
  attested systemic outage covering the horizon** is tenure-attributable — the causing tenure
  is charged for the recovery/cascade it forced, not merely one `L_slash` (r4b-M8) — while
  cascade work whose horizon ran **inside attested-outage windows** (§10.4 rung 3) is a
  **systemic cost, charged to the shared residual pool / treasury (§7.3), never to the
  open epoch's holder**: a holder that published every byte and could not buy a proof anywhere
  did not "cause" anything, and certificate forgiveness for those windows follows §10.4's
  bounded rules (independent attestation only — a holder can never self-label withholding as
  an outage). **Attested-outage tolling of `T_exp` is bounded by `H_toll_max`** (§3 table):
  attestation windows pause the expiry clock so honest tenures are not cancelled-and-charged
  mid-outage, but the total pause is capped so a genuinely permanent outage still exits
  through cancellation — I3's proof-free floor is deferred, never removed. Re-queued forced
  snapshots preserve their original queue order (r4b-M8). **The charge is collateralized, not
  merely stated** (v9, r7-6): where tenure-attributable, it is a recovery-class liability
  drawn from the causing tenure's recovery tranche,
  whose admission sizing includes the worst-case cascade over the ≤ `K + S`-epoch cancellable
  tail (§4); overflow falls to the shared residual pool, never the safety tranche.
  **Worst-case cadence under a permanent outage, stated honestly** (v10, r9-A4): a
  CONTENT-decided tail exits at **one cascade per `H_cancel` horizon** (plus any exhausted
  tolling) — the cascade clears the then-cancellable tail in one step, re-queued forced
  snapshots land in fresh epochs that again need proof-carrying forced-only seals, and if the
  outage persists those epochs wait out their own horizons in turn, until blob expiry
  (~18 days) voids the items with full refunds (§6.4) and bridge principals recall through the
  terminal-cancellation handshake. "The chain keeps moving" under a permanent outage therefore
  means the §10.4 four-guarantee split, not normal service. Bounds, as
  v4:

1. **Sealed state is untouchable** (immutability corollary, §0): the cascade operates only on
   the unsealed tail — it cannot revert finalized L2 history, ever.
2. **The cascade is structurally shallow**: recovery-only mode (I5) stops new *discretionary*
   content epochs once the lag exceeds `K`, so the committed-*discretionary*-content unsealed
   tail — the only **value-at-risk** thing cancellable — never exceeds ≈ `K + S` epochs (~77
   min of chain), not 14 days. A "publish a 14-day tail then cancel it all" attack cannot
   arise: that tail stops growing at `K`. (A *forced-only* decided-unsealed tail can be longer,
   but it is not value-at-risk in a cascade: its data is on L1 by construction and outlives
   `H_cancel` (§6.4), its re-seal is forced-fee-funded (§6.5), and bound 4 re-queues it intact
   rather than voiding it — so it drains, it does not cascade. A cascade deep enough to
   destroy value requires blobs to vanish within retention: a systemic L1/DA disaster, not a
   single-tenure-attributable act — a holder cannot selectively delete its own on-L1 blob.)
3. What *is* lost in a cancellation is the unsealed preconf-layer view of those ≤ `K + S`
   epochs — exactly the exposure preconfirmations always carry against their bond, here
   reachable only after ≥ 10 days of continuously flagged failure.
4. Forced snapshots of cancelled epochs re-queue at the front (data intact — retention outlasts
   `H_cancel`); voiding + refunds only per §6.4 above.

### 6.8 The default derivation — canonical headers when no EBC exists (v11, r10)

Appendix C sources `timestamp`, `gasLimit`, and the anchor from **committed content** — but an
epoch can resolve with **no accepted EBC at all**: an unowned (anarchy) epoch, a missed-commit
epoch, an invalid-EBC epoch (including explicit-empty against a non-empty snapshot), and a
§6.7 cancellation re-resolution. Round 10 showed that leaving those fields undefined there is
a consensus-critical hole with two failure horns: a *range-only* implementation ("any
timestamp in `[T_N, T_N+E)`") lets competing permissionless sealers construct **two different
valid-looking forced-only outcomes** — the first-landed seal becomes a retrospective option
over timestamp-sensitive state (auctions, liquidations, quota clocks, EIP-4396 fee inheritance,
timestamp-gated forks), breaking I6's determinism, I7's sender-independence, and the
anarchy→assigned handoff a successor precomputes against — while an *EBC-requiring* circuit
makes the forced-only transition unconstructible and stalls `openEpoch`. The default rule
closes both horns:

- **One pure function.** For any epoch `N` resolving without an accepted EBC, the L2 block
  sequence is a pure function of `(chainId, N, intraEpochIndex, canonical parent chain,
  forced snapshot)` — every header and execution input, with **no field left to the forced
  sender, the sealer, or L1 inclusion timing**:
  - **Empty outcome** (snapshot empty): **zero L2 blocks**. The epoch advances `openEpoch`
    with no chain extension; the next content-bearing epoch's parent is unchanged.
  - **Forced-only outcome** (snapshot non-empty): the snapshot's items in queue order,
    partitioned into blocks by a **deterministic greedy rule** under the consensus per-block
    caps (a new block exactly when the running cap is exceeded); block `i` (0-based) takes
    **`t_i = max(T_N, parent.timestamp + 1) + i`**; `coinbase` = the epoch-deterministic
    address (the existing forced rule); `gasLimit` = the parent's, drift zero; every other
    field per its Appendix C class (**P**/**E**/**X**).
  - **Anchor** (the field §9's anarchy bridge cadence depends on): epoch-deterministic — the
    canonical L1 block at slot `slot(T_N) − D_anchor`, which satisfies §6.6's depth (exactly
    `D_anchor`), freshness (lag `D_anchor` < ceiling by the §6.6 setter invariant), and
    advancement (strictly increasing per epoch) by construction, and is verified by the same
    §6.6 machinery as a committed anchor. Bridge messages carried as forced items therefore
    keep executing against fresh L1 state through arbitrarily long anarchy.
- **Clock-capacity invariant.** Timestamps are integer seconds, strictly increasing, and
  every epoch-`N` block must satisfy `t < T_N + E` — so at most `E` (= 384) blocks fit in an
  epoch. By induction every parent entering epoch `N` has `parent.timestamp ≤ T_N − 1`
  (content epochs by the circuit-enforced `[T_N, T_N+E)` bound; default epochs by this very
  rule), so `t_i = T_N + i` and the bound holds **iff the block count ≤ E**. The §6.5
  per-snapshot bound is therefore also a **block-count budget**: snapshot admission must cap
  items such that the deterministic partition emits ≤ `B_max ≤ E` blocks, with overflow
  **spilling deterministically to the next epoch** (§6.5's existing spill rule) — mirroring
  the deployed protocol's forced-inclusion cap and deterministic timestamp overwrite, which
  exist for exactly this reason.
- **The circuit has an explicit default branch.** The seal proof takes a derivation-mode
  public input — `EBC` or `DEFAULT` — and the `DEFAULT` branch requires *no* EBC artifact:
  it verifies the block sequence against the snapshot commitment and the rule above. A
  forced-only seal is therefore always constructible by anyone from L1 data alone (I6), and
  a `DEFAULT`-mode seal for an epoch that *has* an accepted EBC is invalid (the decision
  record pins the mode — no mode-choice race).
- **Consequences.** Exactly **one** valid post-state exists per (parent, snapshot, epoch);
  competing sealers race to land *the same bytes*, so first-inclusion is a gas race, never a
  state lottery — I7 restored where round 10 broke it. And because the snapshot is fixed
  before `T_N`, the parent chain is final per I4, and the rule is closed-form, **the
  successor can compute the exact parent header/state root at the parent's decision** — hard
  preconfs, fee accrual, and slashable successor duties key on that computable header, not
  merely on the EMPTY/forced-only class, which is the round-10 item-2 requirement satisfied
  without any new tolling rule. Conformance vectors for the `ANARCHY(forced) →
  ASSIGNED(content)` handoff are a Phase-A obligation (§13-S.18).

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
   tenure's worst-case `K` outstanding recovery obligations plus its worst-case
   cancellation-cascade charge** (v9, r7-6). A tenure's deliberate fault is
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

A sustained L1 gas spike raises the payout with the cost **up to the indexed cap** instead of
starving recovery; the cap is an absolute ETH ceiling (not merely a capped multiple of an
uncapped base — hence "worst-case obligation" is finite and the admission solvency invariant is
statable), and the per-tenure recovery tranche is sized to `K ×` that **cap**, so any spike up
to the cap is paid from the faulter's own account, whenever it occurs. Beyond the cap, recovery
is under-compensated *by design* and the faulter's own epochs degrade to a bounded cancellation
stall (never a subsidy drawn from other tenants' deposits) — the "never spills onto other
tenures" guarantee is about *whose* collateral pays, and it holds. The cap value is §13-T.5.
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
- **Two equivocation variants, two adjudication paths** (v10, r9-B1). (a) **Double-EBC —
  L1-direct, zero latency.** A second *distinct accepted* EBC for the same (tenure, epoch)
  (§3.1's predicate: validly signed by the tenure's registered keys) is complete equivocation
  evidence already sitting in L1 records: the safety certificate **settles at the same `D+κ`
  decision with no L2 proof at all**, terminating the tenure immediately. No adjudication
  latency exists for this variant. (b) **Preconf-vs-record — L2-evidence.** A signed preconf
  commitment conflicting with the epoch's sealed/derived record needs the L2 adjudication
  path (proof against an anchored record). This variant's settlement latency is bounded by the
  normative **adjudication-latency ceiling `Λ`** (§3 table; the ceiling's exact derivation —
  anchor depth, proof time, bridge/verdict transport — is Phase-A-blocking §13-S.4), and
  `L_safety ≥ Λ ×` the per-epoch-MEV bound (§4), so an equivocator streaming faults while the
  first certificate settles nets at most what the bond covers. There is deliberately **no
  accusation-time seat suspension** in the base design (an unbonded accusation would be a free
  denial lever); a *bonded*-accusation suspension (accuser stakes, false accusation forfeits)
  is a §13-T.12 option if calibration finds `Λ ×` sizing too capital-heavy.
- **The safety path is funded, with a precommitted payee** (v10, r9-B2). Producing the L2
  equivocation proof costs real proving work, and v9 named no reward — a decoration tranche
  that rational actors would never enforce. Normative rule: on settlement of a safety
  certificate, **≥ 80% of the `L_safety` debit is burned and the remainder pays the accuser**,
  whose payout address is a **public input of the adjudication proof** (I8 — copying the proof
  from the mempool cannot redirect it); for the L1-direct double-EBC variant the same split
  pays the recorder of the second EBC's evidence transaction via its pre-registered
  beneficiary. Burn-dominance keeps self-slashing unprofitable (a holder "accusing" itself
  recovers < 20% of its own bond); the accuser share makes enforcement a funded, competitive
  job like every liveness lane (I8, §7.3).
- **Every in-flight verdict has a bounded deadline** (v10, r9-B3): an opened adjudication that
  does not settle within its bounded window (`Λ`-derived, §13-S.4) is **dismissed with
  prejudice against the accusation** — the withdrawal gate treats it as resolved, so a
  slow/bogus accusation extends an honest ex-holder's lockup by at most the bounded window
  beyond the ≥ 2-week floor, never indefinitely.
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
  certificates, no unsealed assigned epochs, no in-flight verdicts **within their bounded
  deadlines (time-expired verdicts count as resolved — v10, r9-B3)**, no active
  attested-outage freeze — then the floor delay. A holder that missed an obligation faults
  *itself* by trying to withdraw; poke-censorship cannot buy an exit.

---

## 9. Total Anarchy

Unowned epochs resolve EMPTY-PENDING and are sealed permissionlessly as empty or forced-only
(I6/I7); **no discretionary content**; recovery lane fully open; recovery compensation (§7.3,
paid from the faulter's recovery tranche) remains payable. G5 reframing (r3a-F9) as before: in
Phase B this is a **censorship-resistant fallback that anyone can exit by out-bidding the
reserve floor**; in Phase A it is **DAO-recoverable**, with the DAO fast-path SLA of §10.3.
Bridge flow during anarchy = forced-only cadence — viable precisely because §6.8's default
derivation gives every unowned forced-only epoch an **advancing, epoch-deterministic anchor**
(v11; without it, no EBC would mean no fresh L1 state root on L2 and bridge messages could not
verify their signals); queue data retention per §6.4 keeps long
outages refund-safe rather than value-destroying. **Worst-case bridge settlement for a voided
forced item is `H_cancel` + one forced-only bridge cadence** (r4a-M14) **while proving is
available**; under a *permanent proving outage* the honest bound is different (v10, r9-A4):
re-queued forced items loop through fresh horizons until blob expiry (~18 days + any exhausted
`H_toll_max` tolling) voids them with refunds, and the *source principal* of a bridged message
then returns via the **terminal-cancellation recall** (§6.4) — which is **user-initiated**, so
the end-to-end bound is ≈ blob retention + tolling + the user's own recall latency. A
depositor can make an informed decision from these two bounds, and no value is burned — only
delayed.

> **v8 note — why the v7 anarchy-content restoration was reverted.** v7 briefly restored the
> brief's FCFS anarchy content via atomic proof-carrying proposals (propose ≡ seal). The
> post-simplification regression audit found this **re-opens round-2 finding 6's
> empty-front-running horn**: a proof-free empty seal is valid (and cheap) from the moment the
> epoch is resolvable, while a proof-carrying proposal needs ~10–15 minutes of proving — so any
> actor can resolve the epoch empty before any content proposal can physically exist, and a
> griefer can torch every proposer's proving work at near-zero cost. The v3–v6 rule
> ("no discretionary anarchy content", accepted by that reviewer as *resolved by subtraction*)
> is therefore restored. The atomicity half of the idea remains sound — it satisfies r2-6's
> only-proven-content-locks invariant — and the missing half (a deterministic `S`-epoch
> empty-wait so pure-empty resolution is valid only after the window in which a proven
> transition could have landed) is recorded as §13-T.9 for the owner to revisit deliberately,
> not as part of a simplification round.

---

## 10. Bootstrap, parameters, emergency brake

§10.1 proving budget, §10.2 economic table — as v3, plus:

- **§10.2 additions**: the shared residual (recovery) pool, **pre-funded from a small
  admission tithe on per-tenure ETH deposits — not from fee flow** (v10 consistency fix,
  r9-B6: §7.3 is normative — fee-funded wording here was a stale v3 remnant; fee flow stops in
  recovery-only mode, exactly when the pool matters); indexed recovery
  rates (§7.3); poke bounty (§8); the per-epoch availability-certificate gas budget (§5.2);
  no price feeds anywhere (§4).
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
   can no longer reach for it. **What tolls, and for whom** (v10, r9-A6/F5 — the v9 "never
   covers the holder(s) whose epochs drove the stall" rule was ill-defined under a systemic
   outage, where nobody "drove" it): while an attested window is active, **maturation of
   proof-dependent duties tolls** — seal deadlines, and the expiry clocks `T_exp` up to
   `H_toll_max` (§6.7) — for every epoch **whose data availability is already established**
   (accepted AC, §5.2). Duties that need no prover — the EBC, slice publication, the AC itself
   — **never toll**: a holder that fails those during an outage faulted on its own, and *that*
   is the precise, well-defined replacement for "drove the stall". Forgiveness of in-window
   proof-dependent certificates is bounded to the attested window; without an attestation, no
   tolling — which is why **Phase A pre-commits an attestation SLA** (a published maximum
   response time from observable outage onset to DAO attestation, alongside §10.3's allowlist
   SLA), so "the DAO was slow to attest" has an owner and a deadline instead of a slashed
   backlog of honest holders (§13-S.7).

Bounded duration, auto-expiry, backlog cap, and queued-verdict replay before any release —
as v3.

**Four separate liveness guarantees — never summarized as one** (v10, r9-F3/A4). "The chain
keeps moving" conflates four different claims; the design makes exactly these, separately:

1. **Epoch-counter progress (unconditional):** `openEpoch` always eventually advances — via
   content seal, forced-only seal, empty seal, or expiry cancellation (I3; checker-verified
   deadlock-freedom). Under a permanent proving outage the worst-case cadence is one cascade
   per `H_cancel` horizon (§6.7).
2. **Forced-queue settlement (conditional on proving):** forced items *execute* only through
   proof-carrying forced-only seals. Under a permanent outage they are **not executed** — they
   re-queue, then void at blob expiry with full refunds and recallable bridge principals
   (§6.4, §9). The unconditional guarantee is *refund*, not *execution*.
3. **Discretionary throughput (conditional on a serving holder and proving):** anarchy and
   recovery-only mode deliberately carry none; a proving outage finalizes none.
4. **Bridge completion (conditional, bounded):** normal path per §9; permanent-outage path =
   refund + user-initiated terminal-cancellation recall, bounded by blob retention + tolling +
   recall latency (§9).

---

## 11. Game-theory analysis (v6 deltas)

- **11.1 Squat economics**: idle-to-termination now pays quit-equivalent fees (§4);
  forced-only squatting counts against `K_empty` and is fee-capped (§5.4); silent stall
  unchanged (certificate + debit + termination per miss).
- **11.2 Undercollateralization / TAIKO-shorting** (r4a-C1/H11, r4b-H3): defeated by the split
  bond (I9) — the *theft* fault (equivocation) is slashed in ETH, value-fixed from tenure start,
  so `MEV(ETH) − L_safety(ETH)` no longer moves with the TAIKO price and no short or price shock
  cheapens it. **`L_safety` is sized against the adjudication window, honestly: `Λ ×`
  per-epoch MEV** (v10, r9-B1 — v9 claimed "one epoch is the exposure" while conceding two
  sentences later that slower adjudication widens it; both could not stand). The structure
  that keeps `Λ` small: an equivocation is provable the instant each
  epoch's one-shot EBC lands at its `D+κ` decision (§3.1) — sequentially, ~one epoch apart —
  a settled safety certificate *terminates* the tenure (§4), and a holder cannot
  accumulate an `≈K+S`-deep tail of simultaneously-equivocable epochs against a single bond
  (that depth is a liveness/cancellation quantity, and the seal carries zero derivation inputs
  so it cannot batch-reorder a tail — I1). What bounds the residual stream: the **double-EBC
  variant settles L1-directly at `D+κ` with zero adjudication latency** (§8 — the cheapest
  equivocation to detect is now also the fastest to kill), while the preconf-vs-record variant
  keeps sequencing until its L2-evidence certificate settles — there is no accusation-time
  suspension — so its exposure is genuinely `Λ` epochs of MEV, covered because `L_safety ≥ Λ ×`
  the per-epoch bound and `Λ` is a normative ceiling (§13-S.4), not a hope. Erosion direction
  stated: `L_safety` is value-fixed at tenure start while per-epoch MEV can grow across a
  multi-week tenure; the `T_max` re-auction is the mandatory re-pricing point (top-up to
  current sizing — §4), bounding the drift window to one tenure length. Only *griefing*
  deterrence (`L_live` in TAIKO) carries the price residual — and
  (v9, r7-4) **the TAIKO slash is not the whole price of a fault**: every missed obligation also
  drains the faulter's **ETH recovery tranche at indexed cost** (the fault-paid recovery it
  forces, §7.3) — an ETH-denominated, oracle-free floor per fault that a TAIKO decline cannot
  cheapen. A sustained Sybil-griefing campaign therefore pays, per cycle: the ETH recovery
  drain + the ≥80%-burned `L_live` + the seat (termination) + a fresh fully-funded ETH account
  and `q`-epoch delay to re-enter + the auction price against honest bidders — and `T_max` (§4)
  hard-caps any single tenure's runway. The residual is `L_live`'s *marginal* contribution to
  that stack, a §13-T sizing question, not a free denial-of-service lever. **Honesty on the ETH
  floor** (self-review, re: r7-4): the ETH recovery drain is *largest* for a content/forced-only
  miss (a real proof-carrying seal must be recovered) and *smallest* for the cheapest griefing
  fault — a missed commit on a no-forced-snapshot epoch resolves to a plain **empty** seal,
  whose proof-free recovery earns only "a small indexed amount" (§7.3). For that fault the
  binding deterrents are the ≥80%-burned `L_live`, **termination**, and the `q`-delay +
  fresh-account + auction re-admission cost under the `T_max` runway cap — the ETH drain is a
  floor, not the main cost. This is the honest form of r7-4: TAIKO denomination is retained per
  the owner's directive, `T_max` caps the campaign, and `L_live`-vs-re-admission sizing is
  §13-T.2.
- **11.3 Recovery-lane seal-race** (r4a-H7): rebutted as a griefing cost, not a halt. Competing
  seals for the same `openEpoch` all target one advance; the first valid one advances it and the
  losers simply revert, wasting the *racers'* own gas — the chain still advances one seal per L1
  block, and honest recoverers are reimbursed at cost (§7.3), so a cartel spends to crowd a
  lane that advances regardless. A fastest-prover actor may come to win most recovery races and
  so concentrate recovery *income* (self-review, grief-05) — but income is capped at indexed
  cost (no extraction) and this creates **no censorship lever**: recovery is permissionless and
  non-exclusive, so an actor that *declines* a targeted holder's epoch merely lets any other
  party seal it and collect. It is not the separate prover *market* G4 avoids (that is about
  finalization not needing one; the lane is a fault-only fallback). Optional bond-priority
  ordering is a §13-T tuning lever, not a
  structural need.
- **11.5 Censorship, remodeled** (r3a-F1/F4, r3b-F6) — **and priced at the weakest link**
  (v10, r9-A5/B3): the corridor is the **minimum** over the epoch's *mandatory* artifacts, not
  their aggregate — `C_cen = min(C_slice(span_i) over every slice i, C_EBC(Γc+κ), C_AC(R),
  C_seal(S·E))`. The long spans are real: early blob slices enjoy up to `32+7` slots with
  every data holder a potential includer (first inclusions and re-posts alike — v9, §5.2), and
  the seal has its multi-epoch window. But the **last-produced slice has only the ≥ 7-slot
  post-boundary tail and few data holders**, and the EBC (7 slots) and AC (`R` slots) are
  single small artifacts — so suppressing *one* blob transaction for 7 consecutive slots, or
  the EBC/AC corridor, faults an honest holder, and §13-T.6's quantification must price
  *those* spans. Three mitigations keep the weakest link defensible: the EBC and AC are tiny,
  **sender-free, any-party-submittable** calldata transactions with unbounded priority fees
  (suppressing them means a full builder/proposer coalition against every possible sender for
  the whole span — the most expensive kind of censorship per byte); holders should end
  sequencing with margin (`Γpre`, §13-T.1) and gossip tail slices aggressively so the tail
  slice's holder set and effective span grow; and the graduation criteria require the measured
  7-slot-suppression cost to exceed plausible seat-capture gains before Phase B (§13-T.6).
  Targeted censorship of
  one holder is priced by that min-span corridor rule (`gain ≪ C_cen`); **systemic** censorship that
  stalls `openEpoch` is handled by the **degradation ladder** (§10.4) — the seal deadline's
  matured fault opens fault-paid permissionless resolution of the oldest epoch (v7), and only
  an *attested* proof-outage (never age alone) can
  reach a global freeze/forgiveness, so a builder cartel cannot convert censorship into either a
  chain-wide halt or self-forgiveness. The design deliberately excludes a self-attested "I was
  censored" toll (r3a-F4): mempool non-inclusion is not mechanically decidable, and an
  unfalsifiable attestation is a free deadline-extension lever. Residual: short targeted
  censorship that outlasts a holder's whole submission span can still cost an honest holder one
  `L_slash`; the corridor keeps it unprofitable and κ-grace resubmission keeps it rare. Stated
  plainly. Second residual (self-review, cen-02): the forced path's per-item base fee `a` (§6.5)
  guarantees inclusion but is not free, so a *sub-`a`-value* user cannot cheaply self-rescue via
  forced inclusion, and a competitor could suppress a rival app's small-value user base for
  ~`a` marginal cost — an aggregate that no single user's corridor prices. This violates no
  invariant (I6 never promised free inclusion) but is a real economics decision — accept /
  app-relayer aggregation / size-tiered `a` — tracked as §13-T.9.
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
   outage mode; read-time maturity/materialization points enumerated (I2). **Extended in v10
   (r9-B1/B2/B3):** derive and pin the adjudication-latency ceiling `Λ` (anchor depth + proof
   time + verdict transport, with congestion margin), the bounded per-verdict deadline and its
   dismissed-on-timeout rule, and the accuser-reward split's exact parameters (≥ 80% burn
   floor, payee-as-public-input wiring per I8). `L_safety ≥ Λ ×` per-epoch-MEV is not sizable
   until this closes — it blocks any bond-parameter freeze.
5. **[Phase A]** Parse-time resource-bound constants finalized and made **consensus-exact across
   client and circuit** (circuit canonical), with degrade-without-allocation semantics
   (I1; r3b-F4, r4a-C4, r4b-M9). Includes the bounded worst-case circuit/byte and circuit/gas
   ratios that back the forced-fee upper bound (§6.5).
6. **[Phase A]** Append-only record-spine retention and compaction design + storage-cost account
   (§3; r3b-F3).
7. **[Phase B]** Permissionless proof-system-outage predicate for the attested freeze/
   forgiveness, or the finding that none exists so Phase B keeps a DAO attestation (§10.4).
8. **[Phase B]** Phase-A DAO fast-path SLA definition (§10.3).
9. **[Phase A]** Senior per-tenure ETH recovery-tranche sizing + solvency invariant wired to
   admission — **including the worst-case cancellation-cascade charge over the ≤ `K + S`-epoch
   cancellable tail** (§4, §6.7, §7.3; r4a-H6/r4b-H5/r4c-5, r7-6).
10. **[Phase A]** Forced-item lifecycle nullifier (`queued→snapshotted→consumed|refunded`) in
    proof public inputs; refund atomically kills live commitments (§6.5, r4c-6).
11. **[Phase A]** Verdict incarnation + finalized-origin binding so orphan-fork verdicts fail
    post-reorg (§8, r4c-8).
12. **[Phase A]** Precommitted-payee binding (proof public input / pre-registration) for every
    permissionless reward (I8, §5.2, §8; r4c-4). For the **fill** reward specifically, the
    registration must commit to the slice **bytes** (the withheld witness), not to the slice
    **hash** — the hash is public from the EBC at commit time, so a registration over the hash
    would be speculatively front-runnable and would reintroduce the copy-the-slice race the
    precommitment is meant to close (self-review, fund-03).
13. **[Phase A]** Maximum-tenure-duration `T_max` mechanism spec (v9, r7-1): expiry +
    re-auction transition semantics (incumbent rebid, `q`-delay, assigned-tail honoring),
    interaction with the future-epoch-reservation gate (§4) and `K_empty`'s nuisance role
    (§5.4). Existence is normative; only the value is §13-T tuning.
14. **[Phase B]** Phase-A→B graduation criteria: **existence is normative** (Phase A is
    training wheels with a defined, objective exit — not an indefinite DAO-gatekept regime);
    only the specific thresholds are §13-T.7 tuning. Anchors the §10.3 "criteria are objective"
    claim in the same existence-normative form as `T_max` (self-review, mono-04). **Extended
    in v10 (r9-F9): Phase A is a *bounded pilot*, normatively** — it ships with a published
    review/sunset date, explicit rollback conditions, and a **tested rollback path to the
    whitelist** (existence normative; procedure is implementation work), so "training wheels"
    cannot become the permanent operating mode by default.
15. **[Phase A]** **Availability-certificate specification** (v10, r9-A1; §5.2): exact SSZ
    generalized-index proof format for `blob_kzg_commitments` membership against EIP-4788
    roots, the `R`-window acceptance rule and its beacon-reorg semantics inside `κ`, gas
    budget at stressed base fees, AC record layout in the spine, and the seal circuit's
    KZG-opening binding of bytes to the certified commitments. Blocks implementation of the
    decision path — nothing about §3's timeline is buildable without it.
16. **[Phase A]** **Bridge terminal-cancellation handshake** (v10, r9-cB1; §6.4): the
    source-side recall predicate over the forced item's terminal `refunded && !consumed` L1
    state, its signal-service proof format, and the executed-vs-recalled mutual-exclusion
    conformance tests (double-spend exclusion). A required Bridge-contract change.
17. **[Phase A]** **Forced-snapshot membership rule** (v10, r9-C1; §6.5): the due-time
    predicate (`due ∈ [T_N, T_N+E)`), the `F_delay ≥ E + F_margin` consensus constraint, the
    snapshot commitment as a seal-proof public input, and an audit of every deployed config's
    `forcedInclusionDelay` against the constraint.
18. **[Phase A]** **Default-derivation completion + handoff conformance vectors** (v11, r10;
    §6.8): the exact default rule for every fork-specific field at implementation
    granularity (with §13-S.3), the derivation-mode public input (`EBC`/`DEFAULT`) and its
    decision-record pinning, the double-dimensioned snapshot bound (`B_max ≤ E` blocks) and
    its deterministic spill, and an `ANARCHY(forced) → ASSIGNED(content)` conformance-vector
    suite: competing min/max-timestamp seal candidates (both must be invalid except the one
    default outcome), maximum forced block count, late sealing, EIP-4396 fee inheritance and
    timestamp-gated fork boundaries across the handoff, asserting exactly one valid parent
    exists and no honest successor certificate can mature.

**13-T — Tuning (gates Phase B)**:

1. `Γc` residual soft-preconf window (`Γc + κ`, now ~7 slots) vs `Γpre` early-cutoff to
   drive it to zero at a duty-cycle cost (r4c-3; round-2 §13.1).
2. **`T_max` value calibration** (existence is normative — §4, §13-S.13): tenure length vs.
   re-auction churn, incumbency advantage, and `L_live` sizing relative to re-admission cost
   (r7-4's griefing-economics residual). **v10 (r9-F8): graduation requires an *empirical
   lower bound* on the cheapest-fault re-entry cost** — measured under stressed TAIKO price
   and thin-auction assumptions — not only a nominal `L_live` value.
3. `K`, `K'`, `K_empty`, `H_cancel`, `H_toll_max`, `R`, `D_anchor` calibration and threshold
   gaming; the `freshness_ceiling ≥ D_anchor + Γc + κ + R + margin` setter invariant (§6.6,
   v10 r9-C2) belongs to this set as a *checked* constraint, not a tuned value.
4. Bridge-liveness SLA under long forced-only-cadence runs.
5. Recovery insurance pool sizing; indexed-rate caps.
6. Censorship-corridor quantification against real builder-market data — **priced at the
   min-span (v10, r9-A5/B3): the 7-slot tail slice and the EBC/AC corridors**, with the
   graduation requirement that measured suppression cost exceed plausible seat-capture gain.
7. Phase A→B objective criteria (existence anchored in §13-S.14). **v10 (r9-F1/F6): the
   criteria must include concentration metrics** — seat-share per economic actor, maximum
   consecutive epochs served, bid competitiveness (distinct qualifying bidders per auction),
   and forced-path usage rates — so "open contestability" vs "operator diversity" is decided
   on published data, not narrative.
8. Client migration sequencing.
9. **Forced-inclusion fee floor `a` vs. small-value users** (self-review, cen-02): the
   per-item base `a` (§6.5) that stops tiny-item floods also prices a *sub-`a`-value* user's
   lone transaction out of the guaranteed forced path, so a competitor could suppress a rival
   app's small-value user base for near-`a` marginal cost without any single user's censorship
   corridor (§11.5) pricing it. I6 never promised free inclusion, so this breaks no invariant,
   but it is a real economics decision: whether to (a) accept it (small users rely on the
   seat's normal service, which `T_max` + the corridor keep honest), (b) make **app-relayer
   aggregation** first-class so one forced item can batch many users and amortize `a`, or
   (c) add a size-tiered `a`. Owner decision; interacts with §6.5 and §13-T.6.
10. **Wire `model_checker.py` into CI** so a future doc/checker edit cannot silently invalidate
    the checked invariants (the self-test + bounded run already exit non-zero on any violation
    or halt — "CI-safe"). Accepted in principle rounds 5–6, now tracked here rather than only
    in PR replies (self-review coverage audit).
11. **Anarchy discretionary content, revisited deliberately** (v8; §9 note): atomic
   propose≡seal proposals satisfy r2-6's only-proven-content-locks invariant, but restoring
   them requires the missing ordering half — a deterministic `S`-epoch **empty-wait** (pure
   empty resolution of an unowned epoch valid only after the window in which a proven
   transition could have landed; forced-only outcomes unaffected — I6 already invalidates
   empty), plus its lag/`K` interaction (`S < K` keeps dead-anarchy lag constant at `S`) and
   the FCFS/builder-ordering analysis. Only if the owner wants anarchy content badly enough to
   pay this complexity.
12. **Bonded-accusation seat suspension** (v10, r9-B1 option 3): an accuser-staked,
    forfeit-on-false suspension of an accused tenure's sequencing during preconf-vs-record
    adjudication, as an alternative to carrying the full `Λ ×` MEV exposure in `L_safety`.
    Adopt only if §13-S.4's `Λ` derivation makes the base sizing impractically capital-heavy.
13. **Cross-artifact consistency checks** (v10, r9-B6): a lint step (alongside §13-T.10's CI
    wiring) that greps proposal / §3 parameter table / README / deck / checker constants for
    the normative values and fails on drift, enforcing the header's normative-precedence rule
    mechanically.

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
single admission solvency invariant (§4, §7.3). **28.** **Total Anarchy content restoration —
attempted in v7, reverted in v8.** The atomic propose≡seal path closed r2-6's unproven-content
horn, but the post-simplification regression audit showed it **re-opens r2-6's
empty-front-running horn** (a cheap proof-free empty seal beats any ~10–15-minute
proof-carrying proposal; near-zero-cost censorship of anarchy content). Anarchy returns to
forced-only/empty — the brief's divergence stands — and the repair path (a deterministic
`S`-epoch empty-wait) is recorded as §13-T.9 for a deliberate future revision (§9 v8 note).
New in **v9**: **29.** **maximum tenure duration `T_max`** — the seat is no longer unbounded:
every tenure expires after ≤ `T_max` epochs and re-auctions (incumbent may rebid; expiry is not
a fault). This diverges from the brief's "winner persists unless quit/outbid" perpetual seat,
in exchange for the only objective, Sybil-proof tenure-renewal bound (r7-1) and a hard cap
on griefing-tenure runway (r7-4); `K_empty` is demoted to a nuisance bound (§4, §5.4).
New in **v10** (round 9): **30.** the **availability certificate** — the `D+κ` presence
decision is evaluated as *commitment inclusion* (EIP-4788 + SSZ proofs) materialized by a
permissionless AC within an `R`-slot window, EMPTY by timeout; the brief's implicit
"L1 checks the bytes" is not literally implementable (§5.2, §13-S.15). **31.** `L_safety` is
sized to **`Λ ×` per-epoch MEV** (the adjudication-latency ceiling), the double-EBC
equivocation variant is **L1-directly slashed with zero latency**, and the safety slash now
carries a **funded accuser reward** (≥ 80% burn, remainder to a precommitted payee) — the v9
"one epoch is the exposure" claim was internally inconsistent (§8, §11.2). **32.** `K_empty`
is redefined on the **L1-legible** "no accepted content-bearing EBC" form (the
post-derivation form had no on-chain computation path) and is stuffing-evadable — stated, not
hidden (§5.4). **33.** expiry cancellation is a **mechanical deadline** (`T_exp`; seals
strictly before, cancellation at/after, no overlap) rather than an unobservable "no valid
seal possible" predicate, with attested-outage tolling bounded by `H_toll_max` and
**systemic-outage cascade costs socialized to the pool instead of charged to honest holders**
(§6.7). **34.** the bridge gains a **terminal-cancellation recall predicate** (proof of the
forced item's `refunded && !consumed` L1 terminal state unlocks source-principal recall) — a
required Bridge change the design previously hand-waved as "the bridge's own
unprocessed-message path" (§6.4, §13-S.16).
New in **v11** (round 10): **35.** the **default derivation rule** — when an epoch resolves
without an accepted EBC, its headers are not "whatever fits the range" but one pure function
of `(chainId, epoch, index, canonical parent, forced snapshot)` (§6.8): deterministic
timestamps (`t_i = max(T_N, parent.timestamp+1)+i`), an epoch-deterministic advancing anchor,
inherited gas limit, deterministic partitioning under a block-count budget `≤ E` with spill,
and an explicit `DEFAULT` circuit branch. The brief's manifest-driven header model simply had
no answer for holderless epochs; this is the missing half of I6's "deterministic forced-only
outcome".

## Appendix B — Review dispositions

Rounds 1–2: see v2/v3 changelogs (all accepted; superseded details updated in place).

**Round 3a ("MiniMax", [5354204450](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5354204450) — 3 critical, 7 high, 5 medium):**

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

**Round 7 (DeepSeek on v8 — 1 critical, 3 high, 2 medium; resolved in v9):**

| # | Finding | v9 response |
| --- | --- | --- |
| 1 (crit) | `K_empty`'s non-Sybil predicate is not on-chain decidable ⇒ anti-idle bound vacuous | Accepted, their fix adopted: **`T_max` maximum tenure duration is normative** (§4, §13-S.13); `K_empty` restated in its computable, Sybil-resettable form and demoted to a nuisance bound (§5.4); every bounded-idleness/censorship claim now rests on `T_max` |
| 2 (high) | Availability budget is the 32-slot stream, not the claimed `32+κ`; late inclusion has no path | Accepted as a spec ambiguity, resolved beyond their option (a): **availability is judged at the single decision `D+κ`** — first inclusions and byte-identical re-posts alike, from any data holder; "nothing new" means nothing outside the committed hashes, never nothing-after-the-boundary (§3, §5.1, §5.2, §11.5) |
| 3 (high) | Checker's 0-halts assumes sealing is always possible (no proving/data model) | Accepted, the stronger option taken: the model gains an adversarial **proving-outage mode** (proof-carrying seals disabled while active, adversary may never end it); **zero halts still hold — the cancellation floor is the designed exit**; RESULTS.md scopes the claim explicitly |
| 4 (high) | TAIKO `L_live` ⇒ cheap sustained griefing under a TAIKO decline | Partially rebutted: the TAIKO slash was never the whole fault price — every miss also drains the faulter's **ETH recovery tranche at indexed cost**, an oracle-free ETH floor per fault (§11.2). Partially accepted: `T_max` caps any griefing tenure's runway; `L_live`-vs-re-admission sizing is §13-T.2. Denomination unchanged per the owner's bond-token directive |
| 5 (med) | Forced-fee ratio bounds still an assertion | Accepted as emphasis: §13-S.5 was already [Phase A]-blocking; §6.5 now states the finalized ratios are a **precondition for enabling forced-fee acceptance**, not a follow-up |
| 6 (med) | Cascade charge's seniority/sufficiency unspecified | Accepted: the charge is a **recovery-class liability**, admission-sized into the recovery tranche (worst case over the ≤ `K+S` cancellable tail), overflowing only to the shared pool, never the safety tranche (§4, §6.7, §7.3, §13-S.9) |

**Round 8 (DeepSeek on v9 — verification-artifact + doc-consistency; and an independent
multi-agent adversarial + monopoly self-review). No mechanism changes.** DeepSeek attacked the
model checker's rigor and doc staleness (like rounds 5–6); the self-review ran three adversarial
attackers (fund-freeze/theft, invalid-state/halt, permissionlessness→monopoly) plus
comment-coverage and slide-sync audits, with every security finding put through an adversarial
verifier prompted to refute it. **No finding survived as a confirmed exploit** — each was
already-closed, a misreading, or an accepted/deferred property. Dispositions:

| # | Finding | v9 response (no mechanism change) |
| --- | --- | --- |
| r8-W1 | Checker liveness is existential (deadlock-freedom), not livelock-freedom under a fully unfair scheduler | Accepted, scoped precisely: the claim is now **deadlock-freedom** (from every reachable state an exit path always exists — no terminal-avoiding trap), standard + outage-robust; unconditional livelock-freedom is inherent-to-permissionless-liveness out of scope, supplied at the protocol layer by the permissionlessness of the advancing action (weak fairness). RESULTS.md + `main()` reworded |
| r8-W2 | `inv_seal_immutable` could be masked by state dedup | Accepted: added **`edge_seal_immutable`**, a path-independent edge invariant (dedup cannot hide a re-open); new `reopen_sealed` mutant catches it |
| r8-W3 | Debit-conservation ignored zero-reserve debits | Accepted: removed the silent zero-floor so **every** debit is checked, and `inv_bond_nonneg` now surfaces under-collateralization directly; `RESERVE0` sized to the abstract worst case; new `undersized_reserve` mutant catches it |
| r8-W4 | Stale v6/v7 text (README "v6"; slide 20 "sub-`H_force`"/"awaits max-tenure decision"; slide numbers) | Accepted: README + deck synced to v9; slide residuals, seal-window, κ-caption, cascade-sizing, and "atomic-with-proving" wording corrected |
| r8-S1 | Mutation self-test brittle to incidental violations | Accepted: `explore(stop_on_inv=...)` early-exits only on the *expected* invariant |
| self-review fund-01 (crit) | Aggregate equivocation across the ≤`K+S` tail steals `(K+S)×` the bond | **Refuted** (misreading): equivocation is provable at each EBC's `D+κ` and the first settled safety cert *terminates* the tenure, so exposure is ~1 epoch, not the tail; seal carries zero derivation inputs (can't batch-reorder). Clarified in §11.2; adjudication-latency ceiling → §13-S.4 |
| self-review invalid-01 (high) | The ≤`K+S` cancellable-tail bound is false | **Refuted** (misreading) with a real wording fix: "content tail" → "**discretionary**-content tail" (forced content always flows, is self-funding, re-queues not voided; a value-destroying cascade needs a systemic-DA disaster). §0-I5, §6.7 reworded |
| self-review fund-02 (high) | Fixed recovery deposit vs gas-unbounded obligations spills onto the shared pool | **Refuted** (misreading): compensation is a **capped rate** (absolute ceiling), deposit sized to `K×`cap; above-cap is designed graceful degradation on the faulter's own epochs, never a cross-tenant subsidy. §7.3 wording tightened |
| self-review mono-01/03 (high/med) | `T_max` doesn't stop a whale re-winning ⇒ monopoly | **Refuted** (misreading): `T_max` bounds re-priced occupancy of a *tenure-id*; durable highest-bidder control is an **accepted** property (not harmful — censorship priced separately, forced flow, permissionless recovery). Stated in §4 |
| self-review halt-01 (high) | Permanent proving outage on a data-present forced epoch = permanent halt | **Refuted** (already-closed by I3) with a wording fix: §6.7's cancellation floor now triggers on "**no valid seal possible** — data-loss *or* permanent proving outage", not an impossible data-availability oracle |
| self-review fund-03 (med) | Fill reward front-runnable | **Refuted** (already-closed by I8's "bound before the witness is disclosed") + a Phase-A precision item: bind to slice **bytes**, not the public hash (§13-S.12) |
| self-review fund-04 / invalid-02 (med) | Bridge-refund freeze / re-queue loop | **Refuted** (misreading): the Taiko bridge refund is `recallMessage` (proof-gated, not timeout-based); forced-queue retention is `H_cancel`+margin, not raw blob life |
| self-review cen-02 (med) | Forced-fee floor `a` prices small users out of the censorship-proof path | **Owner decision** (no invariant broken): tracked §13-T.9 (accept / app-relayer aggregation / size-tiered `a`) |
| self-review mono-04 (med) | Phase-A DAO allowlist = de-facto gatekeeper | **Out of scope, stated** (accepted training-wheels property); Phase A→B exit made existence-normative (§13-S.14) |
| self-review grief-05 (low) | Recovery-lane income concentrates on the fastest prover | Accepted as texture: income is cost-capped and confers **no censorship lever** (permissionless, non-exclusive recovery); stated in §11.3 |
| coverage r7-#4 residual | ETH-recovery floor is weakest for the cheapest (empty-seal) fault | Accepted: §11.2 now states the floor is small there; the binding deterrents are the ≥80% burn, termination, and `T_max` re-admission cost |
| coverage / tooling | Wire the checker into CI | Now tracked §13-T.10 (was only in PR replies) |

**Round 9 (two independent reviews — an adversarial security pass and a comparative
implementation-readiness pass; resolved in v10).** The two reports are merged, finding by
finding and with full dispositions, in
[`review-loop/round9-consolidated-review.md`](review-loop/round9-consolidated-review.md);
the summary:

| # | Finding (severity) | v10 response |
| --- | --- | --- |
| r9-A1 (high) | The `D+κ` "bytes on L1" decision has no specified L1 evaluation mechanism; the two obvious implementations diverge on security | Accepted: **availability certificate** — commitment-inclusion via EIP-4788 + SSZ proofs, permissionless, `R`-window, EMPTY by timeout, cost attribution stated; seal circuit binds bytes to commitments (§3, §3.1, §5.2, §13-S.15) |
| r9-A2 (high) | Unspecified EBC acceptance predicate lets a griefer burn the one-shot with unsigned submissions and slash every honest holder | Accepted: normative acceptance predicate — only registered-key-signed artifacts accepted; non-conforming submissions inert; one-shot consumed only by the first accepted artifact; second distinct accepted EBC = equivocation evidence (§3.1, §5.1) |
| r9-B1 (high) / r9-cB2 | "One epoch is the exposure" contradicts the design's own adjudication latency; no seat suspension | Accepted: `L_safety ≥ Λ ×` per-epoch MEV with `Λ` a normative Phase-A ceiling; double-EBC variant slashed L1-directly at `D+κ` (zero latency); `T_max` re-auction top-up; bonded-accusation suspension kept as §13-T.12 option (§4, §8, §11.2, §13-S.4) |
| r9-B2 (med-high) | Safety adjudication has no funded, precommitted-payee enforcement path | Accepted: ≥ 80% burn / remainder to accuser, payee as proof public input (I8); evidence recorder paid on the L1-direct variant (§8) |
| r9-B3 (low) | Withdrawal gate's "in-flight verdicts" unbounded | Accepted: bounded per-verdict deadline, dismissed-on-timeout, gate treats expired verdicts as resolved (§8) |
| r9-A3 (med) | `K_empty` (post-derivation form) has no on-chain computation path | Accepted: redefined on the L1-legible "no accepted content-bearing EBC" form; stuffing-evadability stated; `T_max` remains the binding bound (§3 table, §5.4) |
| r9-A4 (med) / r9-F3 | Outage "chain keeps moving" overstated; rate and bridge bounds missing | Accepted: one-cascade-per-`H_cancel` cadence stated; four-guarantee liveness split; permanent-outage bridge bound restated (§6.7, §9, §10.4) |
| r9-A5 (med) / r9-cB3 | Censorship corridor priced on aggregate span, not the 7-slot weakest link (tail slice, EBC) | Accepted: min-span corridor pricing with mitigations and a graduation cost test (§5.2, §11.5, §13-T.6) |
| r9-A6 (low) / r9-F5 / r9-C3 | Systemic outage slashes/charges honest holders; "drove the stall" ill-defined | Accepted: attested-outage tolling of proof-dependent duties (data-established epochs only), bounded by `H_toll_max`; systemic cascade costs socialized to the pool; attestation SLA pre-committed (§6.7, §10.4) |
| r9-C1 (med) | Forced-snapshot membership rule and `forcedInclusionDelay` unpinned — client/circuit fork risk | Accepted: due-time membership rule, `F_delay ≥ E + F_margin`, snapshot as seal public input, config audit (§3 table, §6.5, §13-S.17) |
| r9-C2 (low-med) | `freshness_ceiling` vs `D_anchor` interdependence unchecked — a bad setting slashes everyone | Accepted: setter-enforced `freshness_ceiling ≥ D_anchor + Γc + κ + R + margin` (§6.6, §13-T.3) |
| r9-cB1 (high) | Voided forced bridge message strands source principal (`recallMessage` needs a destination `FAILED` signal that never exists) | Accepted: bridge terminal-cancellation handshake — recall against the item's `refunded && !consumed` terminal state; double-spend exclusion by nullifier construction (§6.4, §9, §13-S.16) |
| r9-F1 (high) / r9-cF6 | `T_max` mislabeled a censorship bound; admission ≠ sequencing decentralization | Accepted: renamed the tenure-renewal/re-pricing bound; inclusion floor carried by the forced queue; concentration metrics added to graduation criteria (§4, §5.4, §13-T.7) |
| r9-F2 (high) / r9-cB4 | Cancellation predicate unobservable; seal-vs-cancel ordering choice | Accepted: mechanical `T_exp` cutoff — seals strictly before, cancellation at/after, no overlap; expiry-not-impossibility stated plainly (§3 table, §6.7) |
| r9-F4 (high) | "Hard" preconf implies more than the bond delivers | Accepted: "hard" defined as deterrence-only — no restitution, aggregate reliance uncapped, deep-reorg residual (§5.2) |
| r9-F7/F8/F9 (med) | Cost benchmarks, cheapest-fault re-entry floor, Phase-A sunset | Accepted into the gates: §13-T.2 empirical re-entry bound, §13-S.14 bounded-pilot + tested rollback, §10.2 AC gas budget |
| r9-B6 (high, consistency) | Artifacts disagree (κ re-post-only vs first-inclusions; `H_cancel` scope; pool funding) | Accepted: all three fixed in place; normative-precedence rule added to the header; consistency lint tracked §13-T.13 |
| r9-B5 / r9-D1–D7 (checker validity) | Decision deadline unmodeled, untyped seals, boolean forced queue, global lag, outage-mutant baseline invalid, `RESERVE0` self-fulfilling, no throughput report | Accepted: checker upgraded and re-run — see [`simulation/RESULTS.md`](simulation/RESULTS.md) (v10 revision note) |
| r9-B7 | Implementation spec itself missing | Acknowledged as the definition of §13-S: v10 closes the *mechanism* gaps (S.15–S.17 added); the executable Phase-A spec remains the implementation-phase deliverable, per the staged-adoption recommendation both reports make |

**Round 10 ([adversarial comment on v10](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5365112264) — 1 high design blocker + 2 explicit non-findings; resolved in v11):**

| # | Finding | v11 response |
| --- | --- | --- |
| r10-1 (high) | **No canonical L2 clock/header for no-EBC epochs**: Appendix C sourced `timestamp`/`gasLimit`/anchor from EBC-committed content, so an unowned (or missed-commit / cancelled) forced-only epoch had no defined header source — a range-only implementation gives the first-landed sealer a retrospective timestamp/anchor option over two valid-looking outcomes (breaking I6/I7, poisoning the anarchy→assigned handoff, EIP-4396 fee state, and timestamp-sensitive apps), while an EBC-requiring circuit stalls `openEpoch`; and no clock-capacity invariant bounded block count against the 384-second timestamp budget | Accepted in full, all four closure items adopted: **§6.8 default derivation rule** (one pure function of `(chainId, epoch, index, canonical parent, forced snapshot)`; empty ⇒ zero blocks; `t_i = max(T_N, parent.timestamp+1)+i` with the `< T_N+E` bound proven by induction + the block-count budget; epoch-deterministic advancing anchor at `slot(T_N) − D_anchor`; inherited gasLimit; deterministic partitioning); **clock-capacity invariant** with the §6.5 snapshot bound double-dimensioned (`B_max ≤ E`, deterministic spill); **`DEFAULT` circuit branch** pinned by the decision record (no mode race, no unconstructibility); exact-parent-header computability at the decision stated as what successor hard preconfs/duties key on (no new tolling needed); `ANARCHY(forced)→ASSIGNED(content)` conformance vectors §13-S.18; I6/§5.1/§9/App-C updated (new source class **D**) |
| r10-2 (non-finding, confirmed) | v10 does not allow discretionary content during Total Anarchy | Confirmed — §9 unchanged |
| r10-3 (non-finding, confirmed) | No permanent lockout/inevitable slash from a maximal legal predecessor timestamp: `lastTimestamp_N ≤ T_(N+1)−1` keeps `T_(N+1)` legal | Confirmed — and now guaranteed structurally by §6.8's induction (every parent entering epoch `N` has timestamp `≤ T_N − 1`) |

## Appendix C — L2 header inputs and their sources

Backing for §6.6's claim (r3a-F5). Source classes: **P** = parent chain state, **E** =
epoch schedule (known before `T_N`), **C** = committed content (EBC-bound), **X** = execution
result, and — v11 (r10) — **D** = the §6.8 **default derivation rule** (a pure function of
`(chainId, epoch, index, canonical parent, forced snapshot)`), which supplies every
**C**-class field whenever an epoch resolves without an accepted EBC (unowned, missed-commit,
invalid-EBC, cancellation re-resolution). None may be an L1-inclusion-time observation.

| Header / execution input | Today (Shasta) | v5 source | Inclusion-independence |
| --- | --- | --- | --- |
| `number` | parent + 1 | **P** | — |
| `parentHash` | parent | **P** | — |
| `timestamp` | manifest, bounded by proposal L1 time | **C**, bounded by `[T_N, T_N+E)`; **no EBC ⇒ D**: `t_i = max(T_N, parent.timestamp+1)+i` (§6.8) | **E** bounds replace inclusion-time bounds; default rule r10 |
| `extraData` | basefeeSharingPctg + **proposalId** | basefeeSharingPctg (**E**) + **(epoch, intra-epoch index)** (**E/C**) | proposalId eliminated — the round-1 F6 fix |
| `coinbase` | manifest; forced ⇒ proposal.proposer | **C**; forced ⇒ epoch-deterministic address (**E**); **no EBC ⇒ D** (same address) | tx-sender dependence eliminated |
| `gasLimit` | manifest, drift-bounded | **C**, drift-bounded vs parent (**P**); **no EBC ⇒ D**: parent's, drift zero (§6.8) | — |
| `difficulty` | zk-gas used (Unzen) | **X** | — |
| `mixHash` | `keccak(parentDifficulty, number)` | **P** | already deterministic |
| `baseFee` | EIP-4396 from parent timing | **P** | — |
| anchor tx params (`anchorBlockNumber/Hash/StateRoot`) | holder-chosen recent L1 block | **C** — **committed inside the EBC**; ≥ `D_anchor` (32) deep, within the freshness ceiling, advancing (§6.6); **no EBC ⇒ D**: the canonical L1 block at slot `slot(T_N) − D_anchor` (§6.8) | content-addressed ⇒ inclusion-independent; reorg-safe by depth; > κ ⇒ exceptional joint rewind; default rule r10 |
| forced-inclusion prefix | dequeued at proposal inclusion | per-epoch snapshot fixed before `T_N` (**E**), membership = items due in `[T_N, T_N+E)` under `F_delay ≥ E + F_margin` (§6.5, v10) | round-1 F7 fix; membership rule r9-C1 |
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
