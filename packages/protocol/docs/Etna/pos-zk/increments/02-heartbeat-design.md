# Increment 02 — Heartbeat eligibility (D-14): design delta

**Status: APPLIED — increment 02 was implemented in commits `e135656f4`, `75b960652` and
`cea431c37`.** **MEM-13** (L1 heartbeat eligibility) is live as specified here. **CONS-16** was
**not** revived: D-17 keeps the L1-time-keyed rotation deferred and tombstoned, so the CONS-16 rule
text in §3 below is the gated proposal, not the shipped rule. This document remains the design record
the implementation and its adversarial review round were built from.

**Scope.** This increment revives **MEM-13** (L1 heartbeat eligibility) as a live rule. It does
**not** revive **CONS-16** (the L1-time-keyed rotation that consumes it): consistent with D-17, the
rotation stays deferred and tombstoned, and the rule text in §3 is a *specified but gated* proposal
only. The increment also decides the pre-signing horizon and lists every other artifact that must move
with it.

**Bases.**

- Preserved rule text at `7917ba264`: MEM-13 (`spec/03-membership-staking.html`) and CONS-16
  (`spec/02-consensus.html`). The revival is a re-derivation against the converged v1, not a revert of
  the tombstone: the tombstone text is *not* restored, and nothing here reads a deferred mechanism.
- [DECISIONS.md](../DECISIONS.md) D-14 (no rule removes weight), D-8, D-9, D-11, D-15, D-16.
- [CONVERGENCE.md](../CONVERGENCE.md), [PLAN.md](../PLAN.md) Phase 2 ("revive the deferred mechanisms,
  one at a time … none returns by reverting a tombstone").
- Findings: `R5T-C-2` (round-5 Critical, replay), `R6-D12-06` (round-6 Medium, the rotation's stale
  inference and the pre-signed inventory), `R5T-H-1` (round-5 High, the rotation's finality gate), and
  the round-6 "Checked, and holds" note that the window/sequence payload is replay-proof.
- Current v1 rules the revival must fit: MEM-02, MEM-03, MEM-05, MEM-06, MEM-07, MEM-08, MEM-09,
  MEM-14, MEM-15, CONS-03, CONS-08, CONS-09, CONS-10, CONS-12, CONS-13, L1-05/L1-06/L1-07, REC-01,
  ECON-02(5).

---

## 0. What this increment decides

| # | Decision | Where |
|---|---|---|
| 1 | **MEM-13 is revived as a live rule**: eligibility for a set version requires the last accepted heartbeat to have named the window derived from the L1-side schedule — `I*(e) = floor(L1_first(max(e − LOOKAHEAD_EPOCHS, e_0)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW`, the window containing the epoch start at which the version became coverable, or the one before it, all on an L1 block-height grid *(F1 realisation: the commit point's own window is withdrawn)*; ineligible entries are excluded from the committed roster, never decayed or slashed; the ECDSA heartbeat key is registered at bonding and is not a consensus key; anyone may carry and a relayer may batch; the payload binds a domain tag, chain id, the entry, a window index, a sequence number **and a recent L1 block hash**; eligibility is recorded as the **start of the named window**; non-current, already-recorded, non-advancing, duplicate and stale-anchor heartbeats are rejected. | §2 |
| 2 | **The pre-signing horizon is bounded, not closed to zero**: the payload binds `(hbAnchorBlock, hbAnchor = blockhash(hbAnchorBlock))` and acceptance requires the anchor block to be at most `HEARTBEAT_ANCHOR_AGE` L1 blocks old. Full closure (a per-window in-window challenge) is rejected on cost: it adds one permissionless transaction per window *and* makes a single censored transaction exclude the entire roster. | §5 |
| 3 | **CONS-16 is revived in text with a hard gate**: the R6-D12-06 race is closed by the resumed-epoch rule (§3.3); every REC-02/generation/mutual-exclusion clause is deleted because v1 has no recovery path; and its precondition is carried as an explicit Open — sharpened: the *closing height itself* has no L1 referent, so the rule MUST NOT be implemented until the gate is closed. | §3, §9 |
| 4 | **Consequence of the gate, stated plainly**: MEM-13 alone changes the composition of set versions the chain can reach; a chain stalled inside an epoch whose committed roster cannot form quorum still does not resume by rule (that needs CONS-16, or the deferred governance path). | §3.5, §6 |
| 5 | **Falsifiers**: F8 carried and sharpened (heartbeat censorship can *raise* an adversary's share of future versions); **F9 new** (the bounded pre-signing residual, `HEARTBEAT_ANCHOR_AGE`); **F7 carried, sharpened** (the rotation's precondition and the `h_close` referent). Declared non-fix: a declaration of presence is not proof of participation — a cohort that keeps heartbeating keeps its weight. | §6 |
| 6 | **The increment does not reopen a v1 decision**: boundary, exit, D-8/D-9, D-11 and no-weight-removal are untouched; the only conditional touch is REC-01(a)'s wording, and only if the rotation's gate is ever closed. | §8 |

---

## 1. What blocked the mechanism, and what this delta does about each blocker

**(a) R5T-C-2 — one signature was a permanent credential.** The preserved repair (payload bound to a
window index and a strictly increasing sequence; the recorded instant is the named window's start;
acceptance only in the current, unrecorded window) was checked by round 6 against the replay trace and
holds. DEFERRED.md's blocker is that the **fixed payload has never had a fresh review on its own
terms**. This delta re-states the whole payload as the normative surface (§2.2–§2.3), adds the
freshness term (§5), and maps every replay vector to the check that rejects it (Appendix B). The review
round owns the fresh review; nothing in this document claims it as already passed.

**(b) The pre-signing horizon.** The preserved text called the residual "finite and deliberate". It is
finite in the letter and unbounded in practice: the number of windows a key can pre-sign is chosen by
the signer and can exceed the deployment's lifetime, at the cost of one offline signing session. That
is a permanent credential in pre-minted form, and it defeats the exact attack D-14 was commissioned
for (a cohort that goes silent). §5 bounds it.

**(c) The dependency on the deferred stall resolution.** DEFERRED.md §2 also records that the mechanism
"depends on the stall-resolution path that is itself deferred". That dependency is removed here in the
only honest way available: every CONS-16 clause that named REC-02, the recovery generation,
`resumeHeight` or the mutual-exclusion rule is **deleted**, not left dormant, and the rotation is
specified as a non-recovery transition that reads no deferred name (§3.8). What remains is the
rotation's own precondition, which no deletion can remove (§3.5).

**(d) R6-D12-06 — the rotation could resume under the roster that stalled it.** `T_ROTATE ≥
HEARTBEAT_WINDOW` bounds how long the chain has been stalled, not how recently the cohort attested;
with a pre-signed inventory (or a key that simply stays online) the resumed version could carry the
same roster. §3.3 fixes the resumed-epoch rule so that a cohort that *stops signing* is provably
ineligible for the version the rotation consumes; a cohort that keeps signing is a declared non-fix
(§6.3), because no L1 rule can distinguish it from an online validator.

**(e) R5T-H-1 — the rotation consumed an entry that might not be final.** The revived rule registers
`T_ROTATE_DELAY ≥ L1_FINALITY + T_L1_include(p) + margin` and makes finality of `mapping[e_r]` a
condition of completion, not an assertion (§3.2–§3.3).

---

## 2. Revived MEM-13 — exact rule text

> **Review corrections (increment 02, first review round).** The rule text below is the text that
> shipped, but it is not the text as first drafted: this delta is a historical record, and the clauses
> the review round corrected are marked here rather than silently rewritten as if they had always said
> this. (1) Heartbeat-key **retirement is permanent**, not a status at acceptance: a retired key is
> invalid whenever the signature was produced and MUST NOT be re-bound to any entry (MEM-13(1),
> MEM-07(1), MEM-07(6); R-INCR2-04). (2) The promise that a `HEARTBEAT_WINDOW` change **never re-labels
> a window that has begun** is **withdrawn** as false of a global tumbling grid: a change re-grids
> evaluation from the block in which it takes effect (MEM-13(2); 09's `HEARTBEAT_WINDOW` row;
> R-INCR2-01). (3) Acceptance compares the **absolute instant** `hbWindow · HEARTBEAT_WINDOW >
> lastHeartbeatAt(v)`, strictly greater, and the stored window index — grid-relative — is **never
> compared across grids** (MEM-13(2a)(d), (2b)); the compared quantity is an L1 block height, item (5)
> below. (4) The coverage argument at (2a) shows that a change
> can shorten or lengthen coverage but can never open a gap, lower a record, or by itself empty the
> roster (MEM-13(3), (6)). Two further review corrections are recorded in the clauses below: the
> heartbeat key MUST be **non-zero** at bonding and at rotation, so `ecrecover`'s `address(0)` failure
> return can never satisfy acceptance (R-INCR2-02), and there is **one live entry per bonding address**,
> an identifier-uniqueness condition and **not a stake cap** (R-INCR2-03). (5) The heartbeat grid is
> measured in **L1 block height, not wall-clock seconds**: window `w` is the half-open interval of L1
> block numbers `[w · HEARTBEAT_WINDOW, (w+1) · HEARTBEAT_WINDOW)`, `hbWindowOf(n) = floor(n /
> HEARTBEAT_WINDOW)` for an L1 block number `n`, acceptance requires the named window to be the
> current block's window ((2a)(b)), and `lastHeartbeatAt(v)` is that window's **start block**, never a
> carrier's `block.timestamp` or `block.number`. The eligibility instant is **derived, not written**:
> `I*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW` with `C(e) = max(e −
> LOOKAHEAD_EPOCHS, e_0)` and `L1_first(C(e)) = L1_0 + (C(e) − e_0) · EPOCH_LEN_L1`, computed inside
> `commitSet()` from the activation record and the epoch, so it needs no writer, keeper or oracle,
> reads no past block's timestamp, and is identical for two calls in the same block. This supersedes
> the wall-clock readings this document first drafted at clauses (2), (2a)(b), (2b), (3), (6) and the
> `t_root(e)` predicate: eligibility is `lastHeartbeatSeq(v) > 0` **and** `lastHeartbeatAt(v) ≥
> I*(e) − HEARTBEAT_WINDOW` — an entry with no accepted heartbeat is ineligible regardless of the
> arithmetic — that is, the named window is the window containing `I*(e)`, the one before it, or any
> later window, and the old reading — the window containing the commit point — is withdrawn. Two
> consequences are carried openly rather than hidden: the window's **wall-clock duration now varies
> with L1 block time**, so the duty is one attestation per `HEARTBEAT_WINDOW` L1 blocks and not per
> fixed duration (an unmeasured operational cost, no value invented), and clause (6) carries an
> **Open** on a `HEARTBEAT_WINDOW` change that lands in flight, with its falsifier, which §6.2 and §9
> repeat. *(F1 realisation: the unit change is what makes the caller-independent instant realisable
> from L1 state.)*
>
> **(6) Second review round (R2-DI-01, R2-DI-02).** The eligibility predicate gains the guard
> `lastHeartbeatSeq(v) > 0`: a never-attested entry (`lastHeartbeatAt(v) = 0`) is ineligible regardless
> of the arithmetic, so a low-height L1 cannot admit it before its first accepted heartbeat
> (MEM-13(3); R2-DI-01). The change-timing Open is re-sized as a **contiguous run** of versions — every
> version evaluated before the entry re-attests whose evaluation instant falls in `(A + W', A + W_old]`,
> about `(W_old − W') / EPOCH_LEN_L1` of them when a backlog is drained in a single block — and names
> the sole remaining caller influence on `I*(e)`: an append caller's ordering relative to a *pending*
> `HEARTBEAT_WINDOW` change selects the old or the new value for that version, bounded to the pending
> change and of F8's ordering class (MEM-13(6); R2-DI-02). The corrected clauses carry their
> (R2-DI-01)/(R2-DI-02) markers rather than being silently rewritten.
>
> **(7) Third review round (R3-LT-01) — the launch transition.** The rule text below now carries the launch transition the earlier review rounds' text did not: for exactly the two epochs whose clamp resolves to `e_0` (`e_0 + 1` and `e_0 + 2`), the instant is shifted forward by two full heartbeat windows — `w*(e) = floor(L1_0 / HEARTBEAT_WINDOW) + 2` and `I*(e) = (floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW` — so the counting window the predicate's one-window slack admits, `[(floor(L1_0 / HEARTBEAT_WINDOW) + 1) · HEARTBEAT_WINDOW, (floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW)`, starts at or after `L1_0` and keeps the full length `HEARTBEAT_WINDOW` whichever block of its window `L1_0` falls in, and the entries for those two epochs MUST NOT be appended before that window closes (the gate applies to every appender alike and names no entry or caller); from `e_0 + 3` the clamp advances and the unshifted definition resumes. The guard recorded at (6) stays load-bearing in the same reading: `lastHeartbeatSeq(v) > 0` is required, and an entry with no accepted heartbeat is ineligible regardless of the arithmetic. The transition's disclosed cost is part of the correction: the first two filtered appends are gated by up to two heartbeat windows rather than one, and the missing-entry halt of `CONS-13(5)` gains up to one full window, so its total is up to two windows in blocks and is unbounded in wall clock because the register bounds `HEARTBEAT_WINDOW` only from below. The clauses below carry the (R3-LT-01) marker rather than being silently rewritten.
>
> **(8) Fourth review round (R4-LT-01, R4 F1).** Two corrections. (i) The definition of `L1_first(C(e))` said the reference block was **in the future when the entry is appended**; that is false for a late or refilled lowest-missing append, and read as a precondition it would revert the very refill `CONS-13(5)`'s halt recovery depends on. The clause now reads "at or before every block in which the append may be made — a late or refilled lowest-missing append only moves it further into the past, which broadens eligibility and excludes no one", mirroring `MEM-13`(3) (R4 F1). (ii) The disclosed launch-halt cost said the halt "is up to one full window longer"; because the gate opens strictly after the first L1-side epoch boundary (`EPOCH_LEN_L1 < HEARTBEAT_WINDOW`), the halt is guaranteed whenever the L2 keeps pace and is now sized absolutely — `2 · HEARTBEAT_WINDOW − (L1_0 mod HEARTBEAT_WINDOW) − EPOCH_LEN_L1` blocks plus Ethereum finality, between `HEARTBEAT_WINDOW − EPOCH_LEN_L1 + 1` and `2 · HEARTBEAT_WINDOW − EPOCH_LEN_L1` blocks — with the possible second-boundary halt and second recovery cycle named; the disclosed upper bound of up to two windows in blocks and unbounded wall clock is unchanged (R4-LT-01). The corrected clauses carry their `(R4-LT-01)`/`(R4 F1)` markers rather than being silently rewritten.

> Normative text below. It replaces the tombstone in `spec/03-membership-staking.html`; it is written
> as the rule will read in the specification, with identifiers that the register and index must match.

### MEM-13 — L1 heartbeat eligibility (no rule removes weight)

**(1) The heartbeat key.** Each entry registers an **ECDSA (secp256k1) heartbeat key on L1 at bonding
time**, distinct from its Ed25519 consensus vote key (MEM-07): L1 has no Ed25519 precompile and
`ecrecover` is cheap, so L1-side liveness evidence must be ECDSA. Both keys bind to the same entry.
The entry's owner address alone may set or rotate the heartbeat key, and rotation is **forward-only**:
the rotation transaction's L1 block is stored with the entry, a heartbeat signed under a retired key
is invalid **whenever the signature was produced**, retirement is **permanent** — a key that has ever
been retired MUST NOT be re-bound to any entry, including the entry it was retired from (MEM-07(6)'s
one-shot-identity principle) — and a heartbeat key MUST NOT be bound to two entries. **The heartbeat
key MUST be non-zero at bonding and at rotation:** `address(0)` is the value `ecrecover` returns for
any signature it cannot recover, so a zero key is a signature wildcard rather than a key; a bond or
rotation naming `address(0)` MUST be rejected — a rejected bond creates no entry, and a rejected
rotation leaves the entry's stored key, its rotation block and every heartbeat record exactly as they
were.
Rotating the heartbeat key **does not reset** `lastHeartbeatAt(v)`, `lastHeartbeatWindow(v)` or
`lastHeartbeatSeq(v)`: a rotation is not a freshness reset. The heartbeat key is **not a consensus
key** — it cannot vote, it never appears in a set root or in a `(pubkey, effStake)` leaf (MEM-08), it
can never move stake, request or cancel an exit, rotate the consensus key, or trigger or excuse a
slash. Its only power is to attest the entry's liveness for clause (3).

**(2) The signed payload: one window, one sequence, one recent L1 block.** A heartbeat is the entry's
heartbeat key's signature over one canonical `abi.encode` preimage (GEN-05) binding, in order: the
**versioned domain tag** `DOMAIN_HEARTBEAT` (right-padded ASCII `"ETNA_HEARTBEAT_V2"`), the **chain
id**, the **validator entry** `v` (the entry identifier the ledger uses — the bonding address of
MEM-03(1), which carries **at most one live entry** so `v` names exactly one entry; an
identifier-uniqueness condition, **not a stake cap**), the **window index** `hbWindow` the signature
is for, the entry's **heartbeat sequence number** `hbSeq` (a strictly increasing per-entry nonce,
`hbSeq ≥ 1`), the **anchor block number**
`hbAnchorBlock` (an L1 block number), and the **anchor block hash** `hbAnchor`:

~~~
keccak256(abi.encode(DOMAIN_HEARTBEAT, chainId, v, hbWindow, hbSeq, hbAnchorBlock, hbAnchor))
~~~

The tag version is bumped from the preserved draft's `V1` because the preimage gains the anchor pair;
no V1 implementation ever existed, so the bump costs nothing and keeps cross-version replay
structurally impossible. **The identifier is unique without touching the preimage:** the one-live-entry
rule for bonding addresses was chosen over adding a new entry id to the payload, which would have
changed the preimage layout, forced a `V2`→`V3` tag bump and rippled through the register (R-INCR2-03).
**Anyone may submit a heartbeat**, and a relayer MAY batch many signatures in
one transaction: validity depends only on the payload, the signature and the entry's registered key
`heartbeatKey(v)`, never on `msg.sender` — the signature is the entry's own act, the carrying
transaction is not. `HEARTBEAT_BATCH_CAP` bounds the signatures one batching transaction may carry;
it is `unmeasured` and is not a condition on eligibility. `HEARTBEAT_MIN_INTERVAL` is a registered
**operational cadence bound the contract does not enforce** (see clause (6)): the once-per-window rule
of (2a)(d) already admits at most one heartbeat per entry per window, so an enforced interval would be
dominated by the window rule and could only make eligibility harder to attain. **Windows** are
tumbling, non-overlapping intervals of `HEARTBEAT_WINDOW` **L1 blocks**, on the same L1-block clock as
the L1-side epoch schedule of CONS-13(1): at a block that evaluates the parameter with value `W`,
window `w` is the half-open interval of L1 block numbers `[w · W, (w+1) · W)`, and
`hbWindowOf(n) = floor(n / W)` is the window containing the L1 block number `n`. Acceptance requires
the window the signature names to be the window that contains the including L1 block ((2a)(b)), so no
wall-clock conversion or past-block read is involved. A change to `HEARTBEAT_WINDOW` **re-grids the
windows for blocks from the block in which it takes effect**: it *does* re-label intervals that have
begun, and it MUST NOT be described as never re-labelling a window that has begun. What the rule
guarantees instead is that the re-labelling cannot touch a record: `lastHeartbeatAt(v)` is an absolute
L1 block number and the guard of (2a)(d) compares block heights, never window indices, so a change can
neither reject a legitimate advance nor lower a recorded value. *(F1 realisation: this clause first
derived the window from the run-time-visible `block.timestamp`; the grid is measured in L1 block
height because the evaluation instant of clause (3) is a block number derived from the activation
record — an L1 contract cannot read a past block's `block.timestamp`, and a wall-clock grid would
need one stored per epoch.)*

**(2a) Acceptance: current window, advancing sequence, strictly advancing recorded height, fresh
anchor.** The staking contract verifies the signature with `ecrecover` and MUST accept a heartbeat
only if **all** of the
following hold:

- (a) the recovered key is exactly `heartbeatKey(v)` — which is **non-zero** (clause (1)), so the
  `address(0)` that `ecrecover` returns for a malformed or unrecognisable signature can never satisfy
  this check — `v` is a registered entry, and the key is not retired, retirement being permanent
  (clause (1));
- (b) `hbWindow = hbWindowOf(block.number)` — **the window the signature names is the window that
  contains the including L1 block**; a heartbeat whose window is in the past or in the future MUST be
  rejected *(F1 realisation: acceptance reads the carrier's block number, so the named window is a
  block-height interval and no wall-clock conversion or past-block read is involved)*;
- (c) `hbSeq > lastHeartbeatSeq(v)` — a duplicate, a replay or an out-of-order submission MUST be
  rejected;
- (d) if `lastHeartbeatSeq(v) > 0`, then `hbWindow · HEARTBEAT_WINDOW > lastHeartbeatAt(v)`, with
  `HEARTBEAT_WINDOW` the value in force at the including block — **the start L1 block number of the
  window the signature names, exactly the value (2b) would record, MUST be strictly later than the
  block height already recorded**, so a heartbeat that would not advance the record MUST be rejected
  and at most one heartbeat per entry per window is recorded; the comparison is on **absolute L1 block
  heights, never window indices**, so it is unaffected by a change to `HEARTBEAT_WINDOW`;
- (e) `hbAnchorBlock < block.number`, `block.number − hbAnchorBlock ≤ HEARTBEAT_ANCHOR_AGE`,
  `blockhash(hbAnchorBlock) = hbAnchor`, and `hbAnchor ≠ 0` — **the anchor must be a real L1 block
  no older than `HEARTBEAT_ANCHOR_AGE` blocks**; a stale anchor, a future anchor block, an anchor
  that names no block, or an anchor whose hash does not match MUST be rejected.

**A grid change can shorten or lengthen coverage, but it can never open a gap.** Every record is an
absolute L1 block number. For a record `lastHeartbeatAt(v) = A` and a current window length
`HEARTBEAT_WINDOW = W`, coverage under the old record lasts exactly to `A + W`: the entry stays
eligible for every version with `I*(e) ≤ A + W` (clause (3)). The first boundary of the new grid
strictly after `A`, call it `B`, satisfies `A < B ≤ A + W`, so an **attestation opportunity always
exists at or before the last block height the old record covers** — the window named at `B` has start
`B > A` and passes (2a)(d). A change can therefore lengthen coverage (a larger `W`) or shorten it (a
smaller `W`), but it can never open a gap, can never lower a recorded height, and can never empty the
eligible roster by itself; an entry that fails to re-attest is excluded by the ordinary duty of (2c)
alone. This is the coverage argument the specification carries at MEM-13(3)/(6) and in 09's
`HEARTBEAT_WINDOW` row (R-INCR2-01).

A rejected heartbeat writes nothing: it advances no recorded value, it is not an attestation for any
purpose, and it is never evidence of anything. The checks are per signature; a batching transaction
that carries any signature failing them MUST revert and record no heartbeat at all, so a partial batch
cannot be recorded.

**(2b) The recorded eligibility instant is derived from the payload, is monotone, and cannot be
advanced by replay.** On acceptance the contract MUST record `lastHeartbeatAt(v) = hbWindow ·
HEARTBEAT_WINDOW` — **the start L1 block number of the window the signature names**, the recorded
eligibility point, whose unit is L1 blocks everywhere it is read — together with
`lastHeartbeatWindow(v) = hbWindow` and `lastHeartbeatSeq(v) = hbSeq`. The recorded point is a
pure function of the signed payload and is **never** the `block.timestamp` or `block.number` of the
including transaction, so a signature cannot be made fresh by submitting it later, by batching it with
others, by paying more gas, or by any other property of the carrier. The recorded point is
**monotone**: acceptance requires the named window's start block to be strictly later than the value
already recorded ((2a)(d)), so `lastHeartbeatAt(v)` strictly increases on every acceptance and never
decreases, whatever value `HEARTBEAT_WINDOW` takes; the stored index `lastHeartbeatWindow(v)` is the
label that window had under the grid in force when it was accepted, so unlike the instant it is
**grid-relative**, it may be numerically lower than a previously stored index after a change to
`HEARTBEAT_WINDOW`, it **MUST NOT be compared across grids**, and no rule may read it as a recency
test. An entry with no accepted heartbeat has `lastHeartbeatAt(v) =
0`, `lastHeartbeatWindow(v)` unset and `lastHeartbeatSeq(v) = 0`, and is ineligible until its
first accepted heartbeat. It **cannot be advanced by replay**: resubmitting an accepted signature, or
any signature naming a window that is not current or whose start block is not strictly later than the
recorded block height, is rejected and writes nothing; replaying with a different anchor is impossible
because the anchor is inside the signed preimage. *(F1 realisation: the record is an L1 block number —
the window's start height — not a clock time; this clause first called it an instant and allowed no
comparison with a timestamp.)*

**(2c) What the window and the anchor buy, and the residual.** Because the signed message names exactly
one window, is accepted only inside that window, and binds an L1 block that must be no more than
`HEARTBEAT_ANCHOR_AGE` blocks old at acceptance, a heartbeat is a **per-window credential that cannot
be pre-minted**: (i) a captured signature cannot be replayed in any later window; (ii) a signature
naming a future window cannot be recorded before that window begins; and (iii) a signature cannot be
produced materially before the window it names, because the anchor block it binds must exist and be
recent. A key that stops signing therefore remains eligible only for versions whose evaluation window
`w*(e)` is the window it last named or the one immediately after it, and the pre-signing residual
below can extend that by one further window; after that it is ineligible at every evaluation instant.
*(F1 realisation: coverage is stated against the fixed evaluation instant of clause (3), not against
the commit's own window; the window, the anchor age and the coverage bound are all L1 block counts, so
the argument never converts through `L1_BLOCK_INTERVAL`.)*
**Residual, stated honestly:** the bound is not zero. A signature made in the last
`HEARTBEAT_ANCHOR_AGE` blocks of a window can name the following window and be submitted early in
it, so an absent key can retain coverage across one window boundary by up to `HEARTBEAT_ANCHOR_AGE`
blocks. This is the named falsifier **F9** (clause (7)). No rule requires the key to have been online
at the moment of inclusion: the mechanism attests that a fresh signature was produced, not that a node
was running when the carrier landed.

**(3) Eligibility, and exclusion instead of decay.** Entry `v` is **eligible** for set version `k` —
the version committed for epoch `e` — if and only if `lastHeartbeatSeq(v) > 0` **and**
`lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW`, where `I*(e)` is the version's **evaluation
instant**: let `C(e) = max(e − LOOKAHEAD_EPOCHS, e_0)` be
the L1-side epoch in which the version's entry first becomes coverable — the two-epoch lookahead of
CONS-13(3), and the activation epoch `e_0` for the first entry after activation, `e = e_0 + 1` — let
`L1_first(C(e)) = L1_0 + (C(e) − e_0) · EPOCH_LEN_L1` be the first L1 block of that epoch — a block
*number* fixed once by the schedule the activation transaction records (CONS-13(1), CONS-14(1)) and at
or before every block in which the append may be made — a late or refilled lowest-missing append only
moves it further into the past, which broadens eligibility and excludes no one — so it is computed from
L1 state by arithmetic and never read from a past block *(R4 F1: the false
in-the-future-when-the-entry-is-appended claim is replaced by the invariant the rule relies on, so the
sentence cannot be read as a precondition that reverts a late lowest-missing refill — the append that
clears a missing-entry boundary halt.)* — let `w*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW)` be the heartbeat window
containing that L1 block on the block-height grid of clause (2), and let
`I*(e) = w*(e) · HEARTBEAT_WINDOW` be that window's **start L1 block number**. **Launch transition (added by the R3-LT-01 correction; the review-corrections block above records it).** For exactly the two epochs whose clamp resolves to `e_0` — `e = e_0 + 1` and `e = e_0 + 2`, the first two filtered versions — with `q = floor(L1_0 / HEARTBEAT_WINDOW)`, `w*(e) = q + 2` and `I*(e) = (q + 2) · HEARTBEAT_WINDOW`. The second window is what the guarantee needs: the predicate's one-window slack admits the counting window `[(q + 1) · HEARTBEAT_WINDOW, (q + 2) · HEARTBEAT_WINDOW)`, which starts at or after `L1_0` and keeps the full length `HEARTBEAT_WINDOW` whichever block of its window `L1_0` falls in, so a prepared entry cannot win a one-block race and fix the first two filtered rosters; the entries for those two epochs MUST NOT be appended before that counting window closes — the gate applies to every appender alike and names no entry or caller — and from `e_0 + 3` the clamp advances and the unshifted definition above applies unchanged, a lower later threshold admitting, never excluding. Coverage is preserved for the shifted epochs for the same reason it holds everywhere else: a heartbeat accepted in the counting window records `lastHeartbeatAt(v) = (q + 1) · HEARTBEAT_WINDOW`, so `lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW` holds with equality. **The cost is disclosed:** the first two filtered appends are gated by up to two heartbeat windows
rather than one; and because the gate opens at `(q + 2) · HEARTBEAT_WINDOW` while the first L1-side
epoch boundary is `L1_0 + EPOCH_LEN_L1` and `EPOCH_LEN_L1 < HEARTBEAT_WINDOW`, the append for
`e_0 + 1` can never be made before its epoch is entered: the missing-entry halt of `CONS-13(5)` is
**guaranteed whenever the L2 keeps pace**, and it runs `2 · HEARTBEAT_WINDOW − (L1_0 mod
HEARTBEAT_WINDOW) − EPOCH_LEN_L1` blocks before the append — between `HEARTBEAT_WINDOW −
EPOCH_LEN_L1 + 1` and `2 · HEARTBEAT_WINDOW − EPOCH_LEN_L1` blocks — plus Ethereum finality. The
gate can pass the second boundary as well, whenever `2 · (HEARTBEAT_WINDOW − EPOCH_LEN_L1) > (L1_0
mod HEARTBEAT_WINDOW)`, and the finality lag can make the entry for `e_0 + 2` late in most
alignments, so the launch may need two recovery cycles rather than one; the disclosed upper bound
stays up to two windows in blocks and unbounded in wall clock because the register bounds
`HEARTBEAT_WINDOW` only from below. *(R4-LT-01: the halt is stated as guaranteed and sized
absolutely in blocks, replacing the relative "one full window longer" comparison.)* **The instant is
derived, not written.** `commitSet()` computes `w*(e)` and `I*(e)` inside the call by integer
arithmetic over `(L1_0, e_0, EPOCH_LEN_L1, e, HEARTBEAT_WINDOW)` — the activation record, the epoch
the append targets and the parameter value in force at the evaluating block, all L1 state — so no
per-epoch record, no writer, no keeper, no oracle and no past-block read is needed; no transaction can
write the value, the mechanism adds no storage at all, and it is caller-independent by construction:
two calls in one block compute the same instant. **An entry with no accepted heartbeat is ineligible
regardless of the arithmetic**: `lastHeartbeatSeq(v) = 0` fails the guard even though
`lastHeartbeatAt(v) = 0` would satisfy the inequality whenever `I*(e) ≤ HEARTBEAT_WINDOW`, so a
never-attested entry cannot enter a roster on a low-height L1, exactly as (2b) requires
*(R2-DI-01: the predicate carries the non-zero-sequence guard (2a)(d) already uses, so the unguarded
low-height admission is closed.)*. With the recorded value of (2b) and an unchanged
window grid, the predicate is equivalently the requirement that **the last accepted heartbeat named
`w*(e)`, the window immediately before it, or any later window** — every named window whose start
height is at or after `(w*(e) − 1) · HEARTBEAT_WINDOW` — because records are monotone. *(F1 repair:
the predicate is keyed to the derived evaluation instant `I*(e)`, not to `t_root(e)` or the commit's
own window, which this clause first drafted.)*
Across a change to `HEARTBEAT_WINDOW` the predicate stays the absolute one written above and reads
block heights, not indices: a change re-grids evaluation from the block in which it takes effect and
never edits, re-derives or re-interprets a recorded value (clauses (2a)(d) and (6)); the change-timing
residual is the Open in clause (6). The predicate is
evaluated **inside that call, from L1 state at `N(k)`**; the caller chooses nothing and there is no
second evaluation instant — the one bounded exception is an append ordered against a *pending* change
to `HEARTBEAT_WINDOW`, which selects whether the version is evaluated under the old or the new value,
the sole remaining caller influence on `I*(e)`, bounded to the pending change and of F8's ordering
class (clause (6)) *(R2-DI-02: the caller-independence claim names its one bounded exception instead
of denying it)* — and timing the append can only let in entries that have attested since, never
remove one that was eligible when the entry first became coverable. **A later window
cannot reach back:** a signature naming a window later than `w*(e)` cannot be
accepted before that window begins ((2a)(b)), so it cannot be recorded in time to affect `R_k`; if it
is accepted later, it can change only versions whose own evaluation instant lies in that later window. A
signature for a later window MUST NOT retroactively make an entry eligible for an earlier set version,
and no rule may re-open, amend or re-derive a committed `R_k`. *(F1 realisation: the window is found by
integer division on the L1 block-height grid from the activation record, so the instant is computed from
L1 state at `N(k)` and nothing is written per epoch.)*

An entry that is `active` (MEM-02(1)) but not eligible is **excluded from `R_k`, from
`TotalVP_k` and from `n_k`**: it is *not selected*, and it is never decayed, discounted, zeroed or
removed from the ledger. Its effective stake is unchanged, and the next version whose evaluation
window is the window named by a heartbeat the entry has since had accepted, or the window immediately
after it, includes it again with exactly that stake. **If no active
entry is eligible, `commitSet()` MUST revert and MUST NOT append an empty or otherwise invalid
version** (MEM-08(5): `n = 0` is an invalid set, never published). The append obligation is missed and
is restored by a later successful call under MEM-09(1)'s lowest-missing rule; the boundary
consequences are MEM-09(5)'s and are not softened here.

**(4) No rule removes weight.** This rule changes no stake, no weight and no standing. It performs
**no confiscation and no slashing**: D-7, D-8 and D-9 are untouched. Exclusion is not an exit, not a
lapse and not an offence — it creates no evidence, charges no penalty and is never proof of
misbehaviour: not signing, not being reachable and not answering are still non-evidence (CONS-11,
WH-02). An excluded entry keeps its whole bonded balance, its owner, its position, its exit,
cancel-exit and consensus-key rotation rights (MEM-05, MEM-07) and its full slashable exposure for
every epoch in which it was committed: `SlashBase(v, e)` is fixed per epoch and is never restated
(MEM-06(1)). **Re-attesting restores eligibility** at the first version whose evaluation window is the window the
new heartbeat names or the one immediately after it, with no re-entry, no new bond and no penalty; the restored entry must keep signing to
stay eligible ((2c)). The only paths by which a validator's weight changes are its owner's own exit
(MEM-05) and a slashing for an offence (MEM-06); no liveness rule reduces it. The per-epoch
participation accumulator of ECON-02(5) is **unchanged** and remains the reward condition; it is no
longer read for liveness (it never was in v1) and no parameter of it moves.

**(5) Safety and liveness.** **Safety:** because no rule removes weight *within* a set version, a
coalition below one third cannot gain share by rule and `A-CONS-1`'s per-set-version framing stands
unchanged; the withdrawn decay's post-shrink transfer question (F5) does not arise. Exclusion moves an
entry out of a *future* roster only, never re-weights a committed one, and every height is still judged
under exactly one immutable root (MEM-09(3), (4)). **Across versions, selection changes composition,
and that is a real power:** an adversary able to prevent an honest entry's heartbeat from being
accepted throughout the window immediately before a version's evaluation instant removes that entry
from that version and thereby raises its own share of its `TotalVP`; timing the append cannot do this
— `I*(e)` is derived from the L1-side schedule on the block-height grid, so the append's block,
timestamp and position change nothing — but suppressing the entry's own L1 heartbeat for a full window
still can, which is the F8 falsifier and is not repaired by this rule. **Liveness:** a cohort that
stops signing is ineligible for every set version whose evaluation window is later than the last window
it named by more than one ((2c)), the pre-signing residual allowing one further window; from then on
the remaining eligible weight becomes the whole
of `W'` for the versions committed afterwards, so the quorum predicate `3·s > 2·W'` of CONS-03
becomes reachable by the entries that keep heartbeating. **This is a statement about versions committed
from then on.** A version already committed is unchanged, so a chain stalled inside an epoch whose
committed roster cannot form quorum **does not resume by this rule alone**; it resumes through
CONS-16's rotation (subject to that rule's gate) or a later protocol update. The heartbeat is
affirmative and L1-local: it does not depend on any batch landing, so a settlement stall does not
freeze the eligibility evidence. CONS-16's rotation consumes only versions the contract committed from
this predicate.

**(6) Registered relations, and the sizing that is owed.** The parameters are registered in 09 and
every term is `unmeasured`. `HEARTBEAT_WINDOW ≥ EPOCH_LEN_L1 + ceil(T_L1_include(p) /
L1_BLOCK_INTERVAL) + margin`, **every term a count of L1 blocks** — the unit of the grid: an entry
that submits one heartbeat per L1-side epoch is not excluded by inclusion jitter, an operator that
signs once per L1-side epoch has a signing occasion in every heartbeat window, and clause (3)'s
one-window slack means such an entry is eligible at every evaluation instant. *(F1 realisation: the
relation is blocks-to-blocks and reads no block-time assumption; `L1_BLOCK_INTERVAL` enters only to
convert the inclusion-time target `T_L1_include(p)` into blocks, exactly as in the
`HEARTBEAT_ANCHOR_AGE` relation below.)* `HEARTBEAT_ANCHOR_AGE ≥
ceil(T_L1_include(p) / L1_BLOCK_INTERVAL) + margin` **and** `HEARTBEAT_ANCHOR_AGE ≤ 256` (the
`blockhash` availability window): an honest signer's anchor must not age out before its carrier lands,
and the term must remain verifiable on L1. `HEARTBEAT_BATCH_CAP ≥ 1` MUST be small enough that a
full batch fits one L1 block at the measured per-signature cost. `HEARTBEAT_MIN_INTERVAL` is
registered as a **non-normative operational cadence bound**: the contract does not read it, because
(2a)(d) already bounds an entry to one accepted heartbeat per window and an enforced interval could
only make eligibility unattainable; if the review prefers an enforced bound, it must add a stored
acceptance timestamp, which buys nothing this rule needs. The window index, the sequence number, the
anchor block number and the anchor hash are **record contents** — fields of the signed payload and
stored records — not tunables, not proof public inputs and not values any submitter or prover chooses.
Evaluation uses the parameter value in force at the block in which it is made: a change to
`HEARTBEAT_WINDOW` re-grids the windows for blocks from the block in which it takes effect, and a
change to `HEARTBEAT_ANCHOR_AGE` changes the freshness bound for acceptances from that block onward;
neither may edit, re-derive or re-interpret a recorded `lastHeartbeatAt(v)`, `lastHeartbeatWindow(v)`
or `lastHeartbeatSeq(v)`; a version's evaluation instant `I*(e)` is recomputed inside the evaluating
call from the L1-side schedule and the value in force at that block (clause (3)), so a change re-grids
evaluation from the block in which it takes effect and can never lower a recorded height. **Open —
change timing against an instant in flight.** Because the instant is derived at evaluation time, a
change to `HEARTBEAT_WINDOW` that lands after the first boundary of the new grid strictly following
some active entry's record `A`, and before the append that evaluates an epoch whose coverable start
precedes the change, can exclude that entry: the affected set is not one version — every version
evaluated before the entry re-attests whose evaluation instant falls in `(A + W', A + W_old]`, where
`W_old` is the old value and `W'` the new one, excludes it, so a backlog drained in a single block
loses a **contiguous run** of versions, about `(W_old − W') / EPOCH_LEN_L1` of them and bounded by the
backlog actually drained before the incumbent's re-attestation. The rule neither delays the new value
nor freezes a per-epoch grid. **The pending change is also the one remaining caller influence on
`I*(e)`:** while a change is pending, an append caller's ordering relative to it selects whether the
version is evaluated under `W_old` or `W_new`; this is binary, it is bounded to the pending change, it
cannot name an arbitrary instant, and it needs the ordering control of F8's class rather than a new
capability. Falsifier: such a change, at such a block, excluding such an entry from such a run of
versions, or an append ordered at a pending change selecting the grid that excludes it *(R2-DI-02:
the residual is sized as the contiguous run a drained backlog loses, and the sole remaining caller
influence on the instant — a pending change's ordering selection between two grids — is named and
bounded to F8's class; the Open stays an Open, not a guarantee.)*. What would
close it: a registered delay making a new value effective only from a future L1-side epoch boundary,
or a per-epoch frozen grid — neither is registered, the first adds a parameter and the second needs
the per-epoch write this realisation removes. *(F1 realisation: this is the one consequence of deriving
the instant instead of writing it; it is disclosed, not hidden, and §6.2 and §9 repeat it.)* The
rotation's own bounds are `T_ROTATE >
T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY` and `T_ROTATE_DELAY ≥ L1_FINALITY +
T_L1_include(p) + margin` (CONS-16(1)–(2)); the completion's resumed-epoch condition is CONS-16(3)'s
and is the only bound on how long the restart set may lag the invocation.

**(7) Honest costs, the named falsifiers, and the declared non-fix.** **Honest costs:** (a) a periodic
L1 transaction per validator per window, paid by the validator or by whoever relays it, plus the
relayer's need to know a recent L1 block hash at signing time — signing fully offline for long periods
is no longer possible; (b) a second key per validator, its registration, rotation and custody, and the
retirement rule; (c) an operational lapse becomes an *outage* — the validator loses its slots in future
set versions until it re-attests and the next boundary passes — while taking no stake (MEM-15 still
lets value at or below the latest accepted checkpoint exit with no L2 liveness); (d) a signature must
name the window the carrying transaction lands in and must bind an anchor no older than
`HEARTBEAT_ANCHOR_AGE` blocks, so an operator that signs close to a boundary, or whose inclusion
slips past the anchor age, must re-sign — at worst one commit point, never a penalty; (e) if no active
entry is eligible in a window in which the append is due, `commitSet()` reverts (clause (3)), the
append deadline is missed, and the boundary halt of MEM-09(5) becomes reachable until a later append
succeeds; (f) a cohort that keeps signing but withholds L2 participation keeps its weight (see the
non-fix); (g) the window is a count of L1 blocks, so its wall-clock duration varies with L1 block
time: a validator's duty is one attestation per `HEARTBEAT_WINDOW` L1 blocks, not per fixed duration,
and the cadence expressed in seconds is variable and `unmeasured` — an honest consequence stated
rather than a value invented. **Falsifier F8, Open (carried, sharpened):** an adversary able to
censor, delay past the window, or price out honest entries' L1 heartbeat transactions throughout the
window immediately before a version's evaluation instant excludes honest validators from that future
version at no slashable cost, and because exclusion changes future composition it can *raise* the
adversary's share of those versions. The protocol does not attempt to detect or resist this. The
premise it leans on is `A-L1-1`; F8 is Open because this specification neither bounds
single-transaction L1 censorship nor measures the honest heartbeat's gas profile against it. What would
close it: a measured and defensible L1 censorship bound at the honest heartbeat gas profile, or a
mechanism by which exclusion requires more than withholding one L1 transaction per entry per window.
**Falsifier F9, Open (new):** the pre-signing horizon is *bounded, not closed* ((2c)) — a signature
made within `HEARTBEAT_ANCHOR_AGE` blocks before the window it names can be accepted in that window,
so an entry can be absent for up to that many L1 blocks around a window boundary without losing
coverage, and a boundary halt caused by an all-ineligible append window (cost (e)) is reachable through
the same term. What would close it: an L1 value that cannot exist before the named window begins, at
the price of one permissionless transaction per window and a single-transaction censorship surface for
the whole roster (rejected in §5, recorded as the alternative). **Declared non-fix — presence is not
participation:** a heartbeat is a declaration of L1 presence, not proof that the entry voted,
proposed, or held data. An entry (or cohort) that keeps heartbeating but withholds L2 participation
keeps its weight, stays in future versions and can still stall them; no L1 rule can distinguish it from
an online validator whose messages are withheld by the network, and no rule of D-14 removes weight.
This mechanism changes **who is selectable**, never what a committed version requires.

> **Reviewer note (the round-5 Critical does not return).** The failure mode clause is: an eligibility
> instant taken from the including transaction let one captured signature be replayed in every later
> window, so a silent cohort stayed eligible for ever. The revived rule breaks every link of that
> trace: the payload binds the named window, the sequence and the anchor (so one signature is not a
> credential); acceptance requires the named window to be current and the named instant to strictly
> advance the recorded one (so a replay is rejected, not merely detectable); the recorded value is the
> named window's **start L1 block**, never the carrier's time (so submission time cannot refresh it);
> and the rotation's resumed version is drawn from an evaluation window after the last window the
> cohort could have named (so a pre-signed inventory cannot hold the roster — if it is not refreshed).

---

## 3. Revived CONS-16 — exact rule text (specified, gated)

> Normative text below. It replaces the tombstone in `spec/02-consensus.html`. It **MUST NOT be
> implemented while clause (5)'s gate is open**; the gate is the increment's one unresolved item (§9).

### CONS-16 — L1-time-keyed rotation: consuming an eligible set version when an epoch stalls

This rule is the **reachability half** of MEM-13: an entry is eligible for the set version committed
for an epoch only if `lastHeartbeatSeq(v) > 0` **and** `lastHeartbeatAt(v) ≥ I*(e) −
HEARTBEAT_WINDOW`, on the L1 block-height grid — clause (3)'s derived evaluation instant, not the
commit point's own window — and an ineligible entry is excluded from the root rather than decayed.
*(F1 realisation: this sentence first keyed eligibility to the commit point's window. R2-DI-01: the
sentence carries the predicate's non-zero-sequence guard.)* Eligibility therefore changes only
*future* set versions and leaves committed versions intact, so without a way to leave an
epoch whose committed set cannot form a quorum the chain keeps that set for ever. This rule is that
way. It is **not a recovery path**: it discards no produced block, restores no checkpoint, writes no
`resumeHeight`, increments no generation and voids no certificate; nothing at or below the latest
L1-accepted checkpoint changes (REC-01).

**(1) What L1 can see, and the trigger.** A *production stall* is observable on L1 only through the
stored clock of L1-07: `block.timestamp − lastAcceptedBatchTime ≥ T_ROTATE`, where
`lastAcceptedBatchTime` is the checkpoint record's stored acceptance timestamp and `T_ROTATE` is a
registered parameter strictly greater than `T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY`,
so no normal proving or settlement pipeline can open one. The trigger carries **no** inference about
how recently the committed cohort attested: `T_ROTATE` bounds the stall, not the cohort's last
heartbeat (this deletes the round-6 finding R6-D12-06 inference from the trigger; the exclusion of a
cohort that stops signing is established at clause (3), from the derived evaluation instant and the
invocation block, not from `T_ROTATE`). *(F1 realisation: the instant is a block number derived from
the activation record.)* L1 can see neither which validators are online nor where the L2 tip is; the
rotation is therefore restricted to heights no validator has produced, and its precondition is clause
(5).

**(2) Invocation, delay, cancellation.** While the trigger of (1) holds and the L1-side clock of
CONS-13(1) is past `L1_first(e+1)`, any account MAY invoke a rotation against the current
L1-accepted checkpoint. The invocation is objective, takes no argument that influences the outcome, and
records the checkpoint height `H_inv` and the invocation timestamp `T_inv`. It is **cancelled by
progress**: if a valid batch extending the checkpoint recorded at invocation is accepted on L1 after
the invocation and before completion, the rotation MUST revert at completion. No earlier than
`T_ROTATE_DELAY` after the invocation, and only while that progress test does not hold, the
**completion step** — callable by any account — performs (3) and (4). `T_ROTATE_DELAY ≥ L1_FINALITY +
T_L1_include(p) + margin` is registered, so the entry clause (3) consumes is an Ethereum-final L1 fact
at completion (this closes round-5 finding R5T-H-1). At most one rotation invocation may be pending at
a time; the pending invocation needs its own L1 record.

**(3) The resumed epoch, and the restart roster (the R6-D12-06 fix).** A rotation may complete only
against an epoch `e_r` satisfying **all** of:

- (a) `mapping[e_r]` exists and is an Ethereum-final L1 fact at completion, and the L1-side clock has
  reached `L1_first(e_r)`;
- (b) `e_r` is the **lowest** epoch satisfying (a) whose derived evaluation instant lies at or after
  the third window following the invocation block's window: `w*(e_r) ≥ hbWindowOf(N_inv) + 3`, where
  `N_inv` is the L1 block number in which the invocation lands and every term is an L1 block count.

The bound in (b) is derived, not invented: an accepted heartbeat is valid only in the window it names
and only with an anchor block at most `HEARTBEAT_ANCHOR_AGE` blocks old (MEM-13(2a), (2c)), so an
entry whose heartbeat key stops signing at or before the invocation can have named at most the
invocation window `hbWindowOf(N_inv)` or, through the pre-signing residual, the window immediately
after it, and eligibility extends one window beyond the window named (MEM-13(2c)); it therefore cannot
be eligible for a set version whose evaluation window is `hbWindowOf(N_inv) + 3` or later.
*(F1 realisation: the bound is re-derived on the L1 block-height grid; the time-grid version this
clause first drafted compared `t_root(e_r)` with a converted anchor age and no longer type-checks
against MEM-13's `hbWindowOf`, which takes an L1 block number.)* The roster of `setVersion(e_r)` is therefore drawn from entries that attested **after the
invocation**, and the restart set is exactly the immutable version the staking contract committed at
its own commit point from MEM-13(3)'s predicate. The invoker chooses nothing: `e_r` is a function of
`N_inv` (the invocation block), the L1-side schedule and L1 state. If no such `e_r` exists yet, completion MUST revert and MAY be retried later.
Entries that keep heartbeating remain eligible and may remain in `setVersion(e_r)` — this is intended:
the rule excludes the cohort that **stops signing**, and it does not and cannot exclude a cohort that
keeps attesting while withholding L2 votes (clause (7)).

**(4) Effect: the closing height and the boundary amendment.** A completed rotation closes the stalled
epoch `e` at the **closing height** `h_close(e)` — the highest height any validator has produced in
`e`, and never a height any batch has claimed or landed — and it re-partitions **only heights above
`h_close(e)`**. The epoch-boundary record of CONS-13(2) records, for each epoch `e'` in
`[e+1, e_r]`, the first height it governs: `h_first(e') = h_close(e) + 1`, so the epochs strictly
between `e+1` and `e_r` govern **no height at all** and `e_r` begins at `h_close(e)+1`;
`h_first(e_r+1)` becomes `h_close(e) + L + 1`, and every later boundary is the default schedule
shifted by `h_last(e) − h_close(e)`. The sequence `h_first(e')` stays non-decreasing in `e'`,
every epoch before `e+1` keeps the boundary it had, and no boundary that has governed a produced
height is ever changed. The rotation discards no produced block, retires no height, writes no
`resumeHeight`, changes no generation and voids no certificate, so L1-06's contiguity equality is
untouched; the parent of the first block of `e_r` is the block at `h_close(e)`, and CONS-09(1)'s
anchor duty applies with `h_close(e)` in place of `h_last(e)`. **`h_close(e)` is an L2 fact**:
L1 state does not contain it, and clause (5) states exactly what that costs.

**(5) The precondition, and the referent L1 cannot supply — Open (the gate).** A rotation is legal
only if **(i)** no height of epoch `e` above `h_close(e)` has been finalized by any validator, and
**(ii)** `h_close(e)` is in fact the highest height any validator produced. L1 state carries neither
the L2 tip nor the highest produced height: `lastLandedHeight` is a lower bound only, and the
completion transaction cannot compute `h_close` from L1 state. The completion record's
`h_close` is therefore a **claim by the completer**, pinned only from below by L1 (`h_close(e) ≥
lastLandedHeight`), and a false claim re-judges a produced height: a block at a re-partitioned height
committed its set version in its header (CONS-10) and its certificate remains valid forever
(CONS-08(3)), so re-partitioning it makes the certificate unverifiable against the boundary record,
strands value above the latest accepted checkpoint, and turns the rotation into a history-replacing
transition of the class REC-01(a) forbids. **Therefore, until an L1 fact supplies the referent,
CONS-16 MUST NOT be implemented** — by any client, contract, parameter, interface, migration script or
later text. This is the direct successor of the preserved clause (5)'s falsifier **F7**, sharpened: the
old text said the *precondition* could not be enforced from L1; the referent for `h_close` is missing
as well, so the rotation cannot even be made deterministic by a completer who intends to obey it. What
would close the gate: (a) a stored last-finalized marker written by a rule L1 can verify — noted as not
constructible in v1, because a proof can attest that a height *is* finalized but cannot prove that no
higher height is, and a per-height marker duty is neither enforceable nor affordable; (b) a composite
transition whose proof carries the head batch — the same absence problem for "highest"; (c) the
governed, timelocked stall resolution (D-15/REC-02), whose revival would reopen a v1 decision and is
out of scope for this increment. **Falsifier F7 stands, carried and sharpened.**

**(6) No discretion; funding Open.** Once the gate of (5) is closed, the invoker chooses nothing: the
closing height is a function of L1 state and of the referent (5) fixes, `e_r` is the lowest epoch
satisfying (3), and the resumed set is `setVersion(e_r)` exactly as the staking contract already
fixed it (MEM-08, MEM-09). No operator, DAO or invoker selects a checkpoint, a validator set or a
configuration value, and HALT-04 is unaffected. Whether a completed rotation is paid from the
fee-funded pool is **Open** and must be decided with the funding rules of 07; if it is not paid, the
honest consequence is that nobody may be willing to invoke it, so the bound it provides is conditional
on someone acting — disclosed, not asserted.

**(7) Not a rollback, and not a cure by itself.** A rotation discards nothing produced, restores no
checkpoint, moves no history downward, changes no generation and grants no client the right to change
history; a node that has not seen the completion record continues under the rules it holds (CONS-15).
It is also not sufficient on its own: the resumed epoch's roster was drawn from the entries eligible at
its set version's commit point, so a cohort that **keeps heartbeating** and withholds its L2 votes
afterwards keeps its share of the resumed set and can stall it again — a declaration of presence is not
proof of participation, and no rule of this specification removes weight. The next boundary is what
excludes a cohort that stops attesting, and it draws from the layer MEM-13 defines; eligibility is a
validator's own affirmative L1 act and does not depend on any batch landing. The falsifier that
remains is F8: if the honest majority's L1 heartbeats can be censored, honest validators are excluded
too — and can be excluded *selectively*.

**(8) What this rule does not read.** In a v1 with no recovery path of any kind, the rotation reads no
recovery rule, no `resumeHeight`, no recovery generation and no queued-entry record; the preserved
clauses that excluded a rotation while a REC-02 entry was queued, and that scoped the rotation against
the generation, are **deleted**, not retained as dormant text, because no v1 rule may read a deferred
mechanism (this is the same discipline the round-8 repair applied to the core). The boundary record and
pending-rotation record storage that the rotation needs are owned by 04 and 08 and are **not added by
this document** (see §7).

---

## 4. The epoch/boundary interaction, in full

The revival has to be read against the converged set-commitment machinery, not the machinery of the
preserved snapshot. The interaction is:

1. **The evaluation instant is derived inside the commit call.** `commitSet()` takes no arguments,
   may be called by anyone, and appends exactly one entry — the lowest epoch in the L1-committed
   schedule without one — in steady state the entry for `e+2` during L1-side epoch `e` (MEM-09(1),
   CONS-13(1), (3)). MEM-13(3) is evaluated inside that call, from L1 state at `N(k)`, against
   `I*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW` derived from the activation
   record — not against `t_root(e)` and not against the call's own window. The caller chooses
   nothing; the roster is the active entries that are eligible at that derived instant.
   *(F1 realisation: the commit point is where the predicate is evaluated, not what it reads.)*
2. **Two-epoch lookahead means exclusion lands two epochs later.** A heartbeat accepted in the
   version's evaluation window `w*(e)`, or the window immediately before it, is what makes an entry
   eligible for the version governing `e`; a heartbeat missed there excludes it from that version,
   and the *next* version that can include it is the one whose own evaluation window its record
   covers. No rule re-evaluates or amends a committed version (MEM-09(2), (4)).
3. **The L1 clock runs during an L2 stall.** `commitSet()` is keyed to the L1-side schedule, never to
   L2 progress (MEM-09(1), CONS-13(3)), so during a production stall the staking contract keeps
   appending entries — including entries whose rosters were filtered by MEM-13 against fresh
   heartbeats. Those entries are Ethereum-final and immutable before the L2 can consume them. This is
   what makes a restart set available at all.
4. **The L2 cannot skip an epoch.** The boundary record assigns heights to epochs by the default
   schedule (`h_first(e) = H_genesis + (e − e_0)·L`, CONS-13(2)); entering `e+1` requires reaching
   `h_first(e+1) = h_last(e)+1`, which requires producing every height of `e` under `e`'s
   committed roster. So exclusion in *later* committed versions is inert while the chain is stuck
   inside an epoch whose roster cannot form quorum — the gap CONS-16 exists to bridge, and the reason
   MEM-13 without CONS-16 cannot resume a quorum-loss halt.
5. **A boundary halt is different and MEM-13 already helps there.** When the halt is caused by a
   missing or not-yet-final `mapping[e+1]` at the moment of entry (MEM-09(5), CONS-13(5)), the
   resumption rule of HALT-02 consumes the *newly appended* entry once it is final; that entry's
   roster was filtered by MEM-13 at its own (later) commit point. A cohort that stopped signing is
   therefore excluded at a boundary-halt resume without any rotation.
6. **What the rotation changes, if its gate is closed.** It changes which immutable committed version
   the *next produced height* is judged under, by amending only the first heights of the epochs from
   `e+1` to `e_r` (CONS-16(4)). It never edits an entry, never re-draws a root, never changes a
   generation and never lowers a settled height. Every height is still judged under exactly one
   immutable root, and the epoch → set version → set root chain remains an L1 fact end to end
   (MEM-09(2), L1-05).
7. **The resumed version's roster is fixed before completion and cannot be chosen.** `e_r` is the
   lowest qualifying epoch; its entry was appended two L1-side epochs before it governs anything
   (CONS-13(3)); completion only waits for it to become final. The rotation therefore cannot "pick a
   favourable set", which is what keeps the transition objective.

---

## 5. The pre-signing horizon: decision

### 5.1 The residual under the preserved design, stated without softening

The preserved text (MEM-13(2c)) discloses that a validator may sign, in one sitting, a batch of
payloads naming consecutive future windows and hand them to a relayer. It calls this "finite and
deliberate", with a horizon "exactly the number of windows actually signed and no more". Both
statements are true and neither is a bound: the number of windows is chosen by the signer, the window
grid is deterministic and public, and signing ten years of windows offline is one signing session. The
practical consequence is that the mechanism's liveness claim — a cohort that stops participating is
excluded at the next boundary — fails for a cohort that plans ahead at near-zero cost, which is the
exact ransom posture D-14 exists for. A residual whose size is chosen by the adversary is not a
disclosed bound; it is an open horizon.

### 5.2 The options

- **(i) Keep it as a disclosed bound with a named falsifier.** Cheapest: no new rule, no new
  parameter. But the "bound" is not a bound, and the mechanism's headline property would have to be
  weakened to "a cohort that stops signing *and did not pre-sign* is excluded", which is close to
  vacuous against a competent adversary.
- **(ii) Close it with a per-window L1 challenge.** The contract stores a challenge for window `w`
  that can only be created inside `w` (e.g., the first call in the window records
  `blockhash(block.number − 1)`), and every heartbeat in `w` must bind it. This closes the horizon
  to zero. Cost: **one permissionless L1 transaction per window** *and* a new single-transaction
  censorship surface — if no challenge is posted in a window, **no entry is eligible for any version
  whose evaluation window is that window or the one before it**, so one censored transaction per
  window halts the roster instead of one censored transaction per validator. *(F1 realisation:
  eligibility is keyed to the derived evaluation window, not to versions committed in the window.)* That trades a bounded pre-signing residual for a strictly worse
  liveness dependency, and it requires new global state to hold the per-window challenge.
- **(iii) Bound it with an L1-block freshness term (chosen).** The payload binds
  `(hbAnchorBlock, hbAnchor = blockhash(hbAnchorBlock))`; acceptance requires the anchor block to be
  at most `HEARTBEAT_ANCHOR_AGE` L1 blocks old (MEM-13(2), (2a)(e)). No new transaction, no new
  global state (the check reads `blockhash` at submission), no new actor, no new censorship surface;
  the signature must be produced within `HEARTBEAT_ANCHOR_AGE` blocks of submission, so a key that
  is not signing cannot be covered by an inventory that was minted earlier.

### 5.3 What (iii) buys, exactly, and what it leaves

**Buys.** A signature can no longer be pre-minted for an arbitrarily distant window. To be eligible in
window `w`, the entry needs a signature over an anchor block no older than `HEARTBEAT_ANCHOR_AGE`
blocks at acceptance; the anchor block must exist before the signature is produced; therefore the key
must produce a fresh signature within `HEARTBEAT_ANCHOR_AGE` L1 blocks of each submission, i.e.
essentially once per window. A key that stops signing remains eligible only for versions whose
evaluation window is the window it last named or the one immediately after it, the pre-signing
residual (F9) extending that by one further window. With `HEARTBEAT_ANCHOR_AGE` calibrated in the low tens of
blocks (relation in MEM-13(6)) and a window of at least one L1-side epoch, that is less than one
window: "excluded at the next boundary" becomes true to within a bounded, measured term.

**Leaves.** (1) The bound is not zero: within the anchor age, a signature for the next window can be
produced at the tail of the current one (F9). (2) A key holder that automates signing within the age
bound is indistinguishable from an online validator — which is the point: the mechanism tests signing
liveness, not node liveness. (3) The anchor check adds a per-signature gas term and a re-sign case when
inclusion slips past the age bound; both are `unmeasured`.

**Why (iii) over (ii), in one line.** It removes the attacker-chosen horizon — the property that
decides whether the mechanism works at all — at the cost of two payload fields and one check, and
rejects the only full closure because that closure buys the remaining `HEARTBEAT_ANCHOR_AGE` blocks
with a chain-wide, one-transaction-per-window liveness dependency that is worse than the residual it
removes.

**Consistency with R6-D12-06.** The R6 finding's missing rule was "an explicit assumption … or a
definition of `e_r` whose `t_root` is strictly later than `max(invocation, last-attested-window-end)
+ HEARTBEAT_WINDOW`". CONS-16(3)(b) implements the second form with the anchor bound folded in. It
depends on the pre-signing bound: without it, no finite `t_root` bound can exclude a pre-signed
cohort, and the finding's only remaining repair would have been an assumption the mechanism cannot
enforce.

---

## 6. Honest costs, falsifiers, and what the mechanism does not fix

### 6.1 Costs (summary; the rule text carries them at MEM-13(7))

1. A periodic L1 transaction per validator per window, paid by the validator or a relayer; the
   relayer's cost is not reimbursed by any v1 rule (Open, §9).
2. A second key per validator: registration at bonding, rotation, custody, retirement; a compromised
   heartbeat key can only cost the entry its future slots, never stake (it cannot vote, exit or
   slash).
3. An operational lapse becomes an outage: an entry that misses a window loses its slots in the
   versions judged against later windows once its coverage ends; re-attesting restores it at the
   first version whose evaluation window it names or the one after it.
4. Boundary and inclusion jitter now cost a re-sign, because acceptance requires the named window and
   a fresh anchor.
5. If no active entry is eligible when an append is due, `commitSet()` reverts, the append deadline
   is missed, and the MEM-09(5) boundary halt becomes reachable until a later append succeeds.
6. An entry that keeps heartbeating keeps its weight — the declared non-fix below — so the mechanism
   can change *who is selectable* without ever being able to compel participation.
7. The window is a count of L1 blocks, so its wall-clock duration varies with L1 block time and the
   attestation duty is one per `HEARTBEAT_WINDOW` L1 blocks rather than per fixed duration; the
   cadence expressed in seconds is variable and `unmeasured`.

### 6.2 Falsifiers

| ID | Statement | Status | What would close it |
|---|---|---|---|
| **F8** | An adversary able to censor, delay past the window, or price out honest entries' L1 heartbeats excludes honest validators from future set versions at no slashable cost, and can *raise* its own share of those versions' `TotalVP`. | Open (carried, sharpened) | A measured L1 censorship bound at the honest heartbeat gas profile, or a mechanism by which exclusion requires more than withholding one L1 transaction per entry per window. |
| **F9** | The pre-signing horizon is bounded, not closed: a signature made within `HEARTBEAT_ANCHOR_AGE` blocks before the window it names is accepted in it, so an entry can be absent for up to that term around a boundary; the same term makes the all-ineligible append window of §6.1(5) reachable. | Open (new) | An L1 value that cannot exist before the named window begins (a per-window challenge), rejected in §5.2(ii) on the cost of a chain-wide censorship surface. |
| **Change timing (MEM-13(6) Open)** | A change to `HEARTBEAT_WINDOW` that lands after the first boundary of the new grid strictly following some active entry's record `A`, and before the append that evaluates an epoch whose coverable start precedes the change, can exclude that entry from one or more versions although the cadence of the old grid would have kept it eligible: the affected versions are a **contiguous run** — every version evaluated before the entry re-attests whose evaluation instant falls in `(A + W', A + W_old]`, about `(W_old − W') / EPOCH_LEN_L1` of them when a backlog is drained in a single block — and, while the change is pending, an append caller's ordering relative to it selects whether the version is evaluated under the old or the new value, the sole remaining caller influence on `I*(e)`, bounded to the pending change and of F8's ordering class. Falsifier: such a change, at such a block, excluding such an entry from such a run of versions, or an append ordered at a pending change selecting the grid that excludes it. | Open (new) | A registered delay making a new value effective only from a future L1-side epoch boundary, or a per-epoch frozen grid — neither is registered, the first adds a parameter and the second needs the per-epoch write this realisation removes. |
| **F7** | The rotation's precondition (no finalized height above `h_close`) and its `h_close` referent are not L1-verifiable; a false `h_close` re-judges a produced height, makes its certificate unverifiable and strands value above the checkpoint. | Open (carried, sharpened) | A stored last-finalized marker / composite transition L1 can verify, or the governed stall resolution (deferred; out of scope). Until then CONS-16 MUST NOT be implemented. |

### 6.3 What the mechanism does NOT fix (state this wherever it is summarised)

1. **A declaration of presence is not proof of participation.** A cohort that keeps heartbeating but
   withholds L2 votes (or whose votes are withheld by the network) keeps its weight, stays in future
   versions and can stall them. No L1 rule can distinguish it; the mechanism changes who is
   *selectable*, never what a committed version requires, and no rule removes weight (D-14).
2. **The committed version is not repaired.** A chain already stalled inside an unreachable epoch
   stays stalled unless CONS-16's gate is closed or the cohort returns. MEM-13 alone resumes nothing
   there; it changes the versions the chain can reach, and (at a boundary halt) the version it
   resumes into.
3. **It does not punish.** No slashing, no decay, no confiscation, no evidence of misbehaviour; an
   operational lapse costs slots, not stake.
4. **It does not fix the inclusion or recovery gaps.** v1 still has no inclusion obligation, and this
   increment adds no recovery path of any kind; F8 is not repaired, and the exit (MEM-15) remains the
   user protection during any halt.
5. **It does not make the eligible set reachable by itself.** The quorum predicate is computed over
   the committed version's `TotalVP`; if the honest-and-eligible weight is still below the
   predicate, the version cannot finalize, and the next commit point is the next attempt.

---

## 7. What the increment changes outside the revived rules (listed, not made)

Every item below is a required change for the increment to be consistent; **none has been made**. Line
anchors refer to the converged snapshot this delta was written against.

### 7.1 Register rows — `spec/09-parameters.html`

- **Un-withdraw and restate** rows 213–222: `HEARTBEAT_WINDOW`, `HEARTBEAT_MIN_INTERVAL`,
  `HEARTBEAT_BATCH_CAP`, `heartbeatKey(v)`, `lastHeartbeatAt(v)`, `lastHeartbeatWindow(v)`,
  `lastHeartbeatSeq(v)`, `hbWindow`, `hbSeq`, `DOMAIN_HEARTBEAT` — each with unit, derivation,
  tag and an owner link to the revived MEM-13. `HEARTBEAT_WINDOW` is the window length in L1 blocks and
  `lastHeartbeatAt(v)` is the start L1 block number of the named window, so the evaluation instant is
  pure integer arithmetic over stored L1 state *(F1 realisation: window indices are grid-relative
  labels; the recorded height is the record)*. The MUST-NOT-USE reason is replaced by the revived
  statement; `DOMAIN_HEARTBEAT` registers `"ETNA_HEARTBEAT_V2"`.
- **Un-withdraw rows 210–211** (`T_ROTATE`, `T_ROTATE_DELAY`) with the registered relations of
  MEM-13(6)/CONS-16(1)–(2), and an owner link to the revived CONS-16 — annotated that CONS-16 is
  **gated** by its clause (5), so the parameters are *specified but not implementable* until the gate
  closes.
- **New rows**: `HEARTBEAT_ANCHOR_AGE` (L1 blocks; derivation and the `≤ 256` bound);
  `hbAnchorBlock`, `hbAnchor` (payload record contents, not tunables); `lastHeartbeatAcceptedAt(v)`
  only if the review chooses to enforce `HEARTBEAT_MIN_INTERVAL` (the delta recommends it does not).
- **Row 33** (the "L1 heartbeat (eligibility attestation) — deferred by D-16" glossary entry) →
  restated as live.
- **Row 96** (change-order note) and **rows 263/267** (withdrawn measurement rows and the deferred-set
  note) → reinstated measurement line for the heartbeat (per-window gas, per-signature `ecrecover`
  and anchor-check cost, batch fitting one block) and the note reworded: three mechanisms remain
  deferred.
- The D-14 tombstones `T_INACTIVE`, `D_LAPSE_MAX`, `lastObserved(v)` (rows 207–208, 212) **stay
  withdrawn**: no rule removes weight, and `lastObserved(v)` stays retired as the liveness record
  because the record is now `lastHeartbeatAt(v)`.

### 7.2 `spec/03-membership-staking.html`

- **MEM-13** (lines 526–529): tombstone replaced by §2's rule.
- **MEM-03(1)** (line ~113 and clause text): bonding registers the ECDSA heartbeat key (owner-only,
  forward-only) alongside the Ed25519 consensus key; delete the "no heartbeat key is registered"
  sentence. **MEM-03(3), (4)** (lines ~134, ~155, ~161): "no liveness predicate and no exclusion" and
  "an entry that activates but never signs a vote is not lapsed and cannot be lapsed" become: it is not
  lapsed and no stake is touched, but it is not *selected* into versions whose evaluation windows its
  record does not cover; exclusion is a selection filter, not a lapse. *(F1 realisation: selection is
  keyed to the derived evaluation window, not to the commit point's own window.)*
- **MEM-02** (lines ~86, ~89): "every active entry is in the root" → "every active **and eligible**
  entry"; "no liveness rule reduces a validator's weight, and v1 has no liveness rule at all" → "no
  liveness rule reduces weight; MEM-13 excludes from future rosters only".
- **MEM-05(1)–(2)**: one sentence — heartbeat eligibility is an independent filter on *future*
  versions; it does not change exit effectiveness, the churn cap's order, the entry's exposure for
  committed epochs, or any withdrawal condition; an exit-requested entry that stops heartbeating is
  simply absent from future rosters while remaining fully slashable for committed epochs.
- **MEM-07(1)** (and the key-surface clauses): the heartbeat key's separate binding, rotation and
  retirement rule; a retired heartbeat key is invalid; heartbeat-key rotation never resets the
  eligibility records; the heartbeat key never appears in a set root (MEM-08).
- **MEM-08**: unchanged in substance; add one sentence that eligibility is not a leaf field and an
  excluded entry is simply absent from `R_k` and `TotalVP_k`.
- **MEM-09(1)** (and (2)): replace the two "the heartbeat eligibility of MEM-13 is deferred by D-16,
  so no liveness test filters the roster" sentences with the eligibility filter and the empty-roster
  revert rule; the rest of the append gate is unchanged. The stored `setVersionBlock(e)`/`t_root(e)`
  tuple remains exactly as it is — the derived instant reads only the activation record, so MEM-13
  adds no field and no per-epoch record, and no journal, proof or storage shape changes.
  *(F1 realisation: the predicate no longer reads `t_root(e)` at all.)*
- **MEM-14**: `n_k` counts eligible entries; the admission bound and its consequences are unchanged.
- **MEM-15(5)**: one sentence that the exit path reads no membership record and that exclusion neither
  gates nor accelerates withdrawal.
- **Parameter roster at the end of 03** (rows 686–697): un-withdraw the heartbeat set and
  `T_ROTATE`/`T_ROTATE_DELAY`; add `HEARTBEAT_ANCHOR_AGE`; keep the decay tombstones.
- **The D-16 disclosure paragraph** (row ~707 (vii)): rewritten to state the revived mechanism, the
  F8/F9 falsifiers and the CONS-16 gate rather than "membership has no liveness gate".

### 7.3 `spec/02-consensus.html`

- **CONS-16** (line ~505): tombstone replaced by §3's rule.
- **CONS-13(2)** (~line 440): delete the sentence "the heartbeat eligibility of MEM-13 is deferred by
  D-16, so no liveness gate filters the roster and the committed roster is the active bonded set";
  replace with the MEM-13(3) predicate. **CONS-13(5)** (~line 496): the D-16 rotation sentences are
  replaced by the gated CONS-16 reference and the halt consequence as it stands while the gate is open.
- **M7** (page intro line ~16, note line ~510, modifications row ~541): restated as revived, with the
  gate and the carried F7/F8/F9.
- No change to CONS-03, CONS-08, CONS-09, CONS-10, CONS-12: the increment must show (and the review
  must check) that the rotation, *within its gate*, does not weaken them — CONS-16(4) and (8) are
  written to that end.

### 7.4 `spec/index.html`

- **Rule-index rows**: `MEM-13` (~line 429) and `CONS-16` (~line 416) become live descriptions
  (CONS-16 annotated with its gate); `LIVE-05` (~line 529) and `LIM-01` (~line 530) lose "no v1 rule
  time-bounds them" and gain the revival, the residual bound and the rollback condition.
- **Parameter map**: the heartbeat set and `T_ROTATE`/`T_ROTATE_DELAY` (~lines 538, 559) become
  live; add `HEARTBEAT_ANCHOR_AGE`. The narrative deferral lists (~lines 43, 93, 119, 357) drop
  heartbeat eligibility from the deferred four; the line ~586 prohibition ("no artifact may claim …
  that forced inclusion, heartbeat eligibility or aggregation exist in v1") is reworded for the new
  status (heartbeat live; forced inclusion and aggregation not).
- Any "four mechanisms are deferred" statement in the front matter is reworded to three, with a link
  to the increment.

### 7.5 `spec/10-assurance.html`

- `LIVE-05` (rule text ~lines 312–332) and the assurance rows ~349–361: rows 352–357 (F5, F6, F7, F8,
  the operational-lapse cost) are rewritten from "Deferred by D-16" to the revived mechanism, the
  bounded exclusion, the F8/F9 falsifiers and the F7 gate, with the MEM-13(6) change-timing Open and
  the variable wall-clock cadence of the L1-block window added to the register; row 359's "no v1 rule can exclude it or
  re-partition the stuck epoch" is updated for the gated rotation.
- LIM-01 rows, the rejected-alternatives row ~406 ("Per-validator L1 liveness attestations") and the
  D-16 applied note ~427 are updated to record the revival and the gate.
- The "no recovery path of any kind" statements stay **true** (this increment adds none) and must be
  re-read for consistency with the gated rotation language.

### 7.6 `spec/06-recovery-exceptions.html` — the one boundary-adjacent touch

- Lines ~24, ~35, ~46, ~124, ~129, ~377, ~461: the statements that heartbeat eligibility is deferred
  and that the heartbeat route "would have" made a stall recoverable are rewritten: eligibility is
  live (increment 02); the rotation that consumes it is specified but gated; a recovery-free v1 still
  has no history-replacing path, and the rotation is **not** one.
- **REC-01(a) wording, conditional**: the clause "no function that discards state above it exists
  either" remains literally true while CONS-16's gate is open, so **nothing in REC-01 changes in this
  increment**. If and when the gate is closed, REC-01(a) gains a named qualification: a boundary
  amendment under CONS-16 is permitted only for heights no validator produced, per that rule's
  precondition — the guarantee class is unchanged (at or below the checkpoint untouched; above it,
  provisional), and the qualification must not be written before the referent exists. This is listed
  so the review round sees exactly where the increment would touch a v1 decision and can reject the
  rotation instead.

### 7.7 Other specification pages

- `spec/04-l1-integration.html`: L1-05/L1-06/L1-07 are unchanged in substance — the Inbox still
  resolves the epoch from its own schedule and reads `mapping[e]`, and MEM-13 adds no journal field
  or public input. Add one sentence that the eligibility filter lives inside the staking contract's
  `commitSet()`, so no proof statement, witness or Inbox storage shape changes. If the rotation's
  gate is ever closed, 04 owns the epoch-resolution and contiguity amendments the boundary record
  needs (CONS-16(8)).
- `spec/05-proof-statement.html`: **no change**; PRF-02/PRF-04 are unaffected (the roster is already
  an L1-derived input, and eligibility changes only its contents). The review round should record
  this as a checked non-change.
- `spec/01-system-model.html`: ROLE-01/ROLE-04 (validator duties and user rights) gain one sentence
  that eligibility is an owner-keyed L1 duty with no stake effect and no user-facing gate; the
  assumptions table is unchanged (F8 leans on A-L1-1, already listed).
- `spec/08-migration-upgrades.html`: lines ~37, ~807, ~866 — the deferral lists and the stall
  disclosure table are updated to "heartbeat eligibility revived (increment 02); the rotation is
  specified but gated; three mechanisms remain deferred". See §7.11 for the budget rows.

### 7.8 `DEFERRED.md`

- §2 is rewritten from a deferral to a **revival record**: what was revived (MEM-13 live; CONS-16
  specified and gated), the decisions of §0, the disposition of the two blockers (payload re-reviewed
  by the increment's review round; horizon bounded by `HEARTBEAT_ANCHOR_AGE`), the residual (F7/F9),
  and the new revive criterion for CONS-16 (an L1-verifiable `h_close` referent). The header line
  "Four mechanisms are deferred" becomes three, and the cross-cutting items (Phase B measurements,
  learning-site sync) are updated to note that a revival is a specification change like any other.
- `CONVERGENCE.md` and `iterations/*freeze*` are **historical records and are not edited**; the live
  list is DEFERRED.md. The increment's own record is this file.

### 7.9 `DECISIONS.md`

- Append a new entry (next free number, D-17): "Heartbeat eligibility revived; the pre-signing horizon
  is bounded by an L1-block freshness term; CONS-16 is revived in text and gated on its `h_close`
  referent." The log's rule is that decisions are appended and never silently edited, so D-14/D-16 stay
  as written and the new entry records what changed.

### 7.10 Course pages (`learn/`)

The learning site must be re-synced on **any** change to a live rule, so all of these are re-checked;
the ones that must change:

- `learn/04-staking-and-epochs.html` — the primary page: §4 "Membership has no liveness gate" (line
  ~132), the key/rotation material (~217) and the summaries (~287, ~313) become the heartbeat
  mechanism: the ECDSA key, the window, the anchor, exclusion-not-decay, re-attestation, and the F8/F9
  falsifiers; "rotation is not a recovery path" stays true and gains the CONS-16 gate.
- `learn/08-when-things-go-wrong.html` — lines ~133, ~237, ~259, ~442–466: the halt page must teach
  the eligibility-exclusion path, the boundary-halt resume that already benefits, and the gated
  rotation; the "no recovery path" statements stay.
- `learn/07-timing.html` — lines ~173, ~263, ~280, ~308: add the eligibility delay (the derived
  evaluation instant → two-epoch lookahead → the epoch it governs) and the rotation's wait when
  gated/unGated. *(F1 realisation: the delay starts from the derived instant, not the commit point.)*
- `learn/10-economics.html` — lines ~121, ~274: "being in the set is not a duty a validator renews"
  becomes "the L1 liveness duty is what renews selectability; rewards still require a landed
  participation bit, and silence still costs no stake".
- `learn/glossary.html` — lines ~121, ~152–157, ~211: effective stake ("no rule reduces it" stays;
  add "exclusion from future versions is not a reduction"), validator, status labels, and a new
  heartbeat entry.
- `learn/01-what-is-etna.html`, `02-life-of-a-transaction.html`, `05-the-proof.html`,
  `06-data-and-proof-together.html`, `09-censorship-and-the-bridge.html`, `index.html`,
  `limitations.html` — audit pass: every "no liveness gate"/"no rule can exclude" sentence must be
  reconciled with the revival and the gate; no "recovery path" statement changes.
- The course's own index/limitations pages must state the residual (a cohort that keeps heartbeating
  keeps its weight; the rotation is gated).

### 7.11 Migration budget

- **New staking-contract state (outside the Inbox slot budget).** MEM-09(2) already records the
  staking contract as a new deployment whose epoch mapping is new-contract state of the class MIG-02
  places outside the frozen Inbox budget. The heartbeat adds, per entry: `heartbeatKey(v)` and its
  rotation block; `lastHeartbeatAt(v)`, `lastHeartbeatWindow(v)`, `lastHeartbeatSeq(v)`
  (packable into one slot; `lastHeartbeatAt(v)` is an L1 block number, not a timestamp, so the F1
  realisation changes the record's unit and not the state shape). **No new global state** is needed for
  the anchor check (`blockhash` is read at submission) and none for the derived instant (it is
  computed from the activation record, not stored per epoch), and **no Inbox, SignalService, Bridge or
  vault slot is touched**; no proof public input, journal field or config-hash preimage element is
  added.
- **Interface change.** The bonding interface (MEM-03(1)) gains the heartbeat key (or a
  `setHeartbeatKey` call before activation). The migration's interface/churn tables in 08 that
  enumerate what a bonding call carries must include it, and the migration announcement must state
  that validators have an L1 signing duty from T3 onward (runbook item).
- **Conditional, if CONS-16's gate is ever closed**: the boundary-record amendment storage (per-epoch
  first-height overrides / the closing record) and the pending-rotation record. These are owned by 04
  and 08 and are **not** budgeted by this increment; they are the reason the rotation is gated rather
  than shipped.
- **Phase B / PARAM-03**: the heartbeat measurement line (per-signature `ecrecover` + anchor check
  gas, batch fit in one L1 block, relayer cost, and the L1 inclusion quantile at that gas profile) is
  reinstated; `HEARTBEAT_ANCHOR_AGE`'s calibration depends on the same measurement.

---

## 8. Why the increment does not reopen a v1 decision

- **The boundary (REC-01).** Nothing at or below the latest L1-accepted checkpoint is read, written,
  re-judged or delayed by MEM-13; the rule changes only which active entries a *future* set version
  selects, which is set-version composition, not history. CONS-16 is the only rule that would touch
  the provisional range above the checkpoint, and it is gated; **while the gate is open, REC-01's text
  is literally unchanged** and no qualification is needed. The exact place a qualification would go,
  and the reason it must not be written before the referent exists, are listed at §7.6.
- **The exit (MEM-15).** The exit path is untouched: MEM-15 reads stored signals and stored
  checkpoints, not membership (MEM-15(1), (2), (5)); no rule here gates, delays, accelerates or
  conditions a withdrawal, and no heartbeat duty falls on users. MEM-13(4) and MEM-15's "what it does
  not touch" clause state the non-interaction; MEM-15 remains the user protection during any halt,
  including a halt this increment cannot clear.
- **D-8 / D-9.** No fee, reward, penalty or destination is introduced or moved: the heartbeat's gas is
  paid by whoever relays it and no v1 rule reimburses it (Open, §9); exclusion is not a slash, creates
  no evidence and moves no TAIKO; D-9's treasury destination and D-8's funding path are untouched.
- **D-11.** No publication, blob, deadline or data-binding rule is read or changed. Eligibility reads
  only the staking contract's own records and an L1 block hash; the rotation, if ever revived, reads
  no publication state. The June-2026 expiry class and the proving deadline are unaffected.
- **No rule removes weight (D-14).** MEM-13(4) restates it and the rule performs no decay, discount,
  zeroing, confiscation or exit; `A-CONS-1`'s per-set-version framing stands because a committed
  version's weights are immutable. CONS-16 revives only the reachability half, and it changes which
  committed version governs unproduced heights, never a weight within one.
- **D-15 / D-16.** No recovery path returns: no permissionless recovery, no governance stall
  resolution, no generation increment, no checkpoint restore, no history discard. This increment
  *follows* PLAN.md Phase 2's rule — the mechanism is re-derived and re-reviewed, not un-tombstoned by
  reverting text — and it leaves the other three deferred mechanisms untouched.

---

## 9. What this increment could not decide (for the review round and the owner)

1. **CONS-16's gate (the headline).** Whether the rotation may ship with F7 open. This delta's
   recommendation is **no**: the `h_close` referent has no L1 fact behind it in v1, a wrong value
   re-judges a produced height, and closing it needs either new machinery (a last-finalized marker
   that cannot prove absence) or the deferred governance path (which would reopen D-15). If the review
   agrees, MEM-13 ships alone and v1 keeps the disclosed consequence that a quorum-loss halt inside an
   epoch is cleared only by the cohort returning or by a future protocol update. If the owner wants
   the rotation anyway, clause (5) must be rewritten to say what L1 fact pins `h_close`, and REC-01(a)
   gains the §7.6 qualification.
2. **`HEARTBEAT_ANCHOR_AGE` calibration.** Relation given in MEM-13(6), value unmeasured; it trades
   the F9 residual against the re-sign rate and the `blockhash` bound. Phase B measures its inputs.
3. **`HEARTBEAT_WINDOW` calibration** and whether a window should equal one L1-side epoch.
4. **`HEARTBEAT_MIN_INTERVAL`.** Recommendation: register it as non-normative (it is dominated by the
   once-per-window rule) or drop the name; an enforced interval needs a stored acceptance timestamp and
   buys nothing. The task's register list includes it, so it is revived as non-normative pending the
   review's call.
5. **Who pays for heartbeats and for a rotation.** Not decided; no v1 rule reimburses a relayer, and
   CONS-16(6)'s funding question is carried Open. A fee-funded line would be an ECON-02 change and is
   out of scope here.
6. **The heartbeat key's post-retirement reuse rule.** Proposed: a retired heartbeat key is invalid
   forever for that entry; the review should confirm this is not stricter than needed (it costs a
   validator that rotates twice nothing, and it removes an attribution ambiguity).
7. **`DOMAIN_HEARTBEAT`'s version.** This delta registers `"ETNA_HEARTBEAT_V2"` because the preimage
   gains the anchor pair; if the review prefers to keep `V1` (no released implementation exists),
   nothing else changes.
8. **Migration runbook.** Whether existing entries must produce a heartbeat before activation at T3
   (proposed: the key is registered with bonding and the normal window applies from the first set
   version committed after activation; the announcement must say so).
9. **A `HEARTBEAT_WINDOW` change landing in flight (MEM-13(6), Open).** Because `I*(e)` is derived at
   evaluation time, a change to `HEARTBEAT_WINDOW` that lands after the first boundary of the new grid
   strictly following an active entry's record `A`, and before an append whose epoch's coverable start
   precedes the change, can exclude that entry from one or more versions although the cadence of the old
   grid would have kept it eligible: the affected versions are a **contiguous run** — every version
   evaluated before the entry re-attests whose evaluation instant falls in `(A + W', A + W_old]`
   (`W_old` the old value, `W'` the new), about `(W_old − W') / EPOCH_LEN_L1` of them when a backlog is
   drained in a single block — and, while the change is pending, an append caller's ordering relative to
   it selects whether the version is evaluated under the old or the new value, the sole remaining caller
   influence on `I*(e)`, bounded to the pending change and of F8's ordering class. Falsifier: such a
   change, at such a block, excluding such an entry from such a run of versions, or an append ordered at
   a pending change selecting the grid that excludes it. This is not a reason to write the instant per
   epoch; closing it would take a registered delay making a new value effective only from a future
   L1-side epoch boundary, or a per-epoch frozen grid, and neither is registered.

---

## Appendix A — Clause-by-clause difference from the preserved text (`7917ba264`)

| Clause | Preserved | Revived | Why |
|---|---|---|---|
| MEM-13(1) | ECDSA key at bonding, owner-only forward-only rotation, not a consensus key | Kept, plus: rotation does not reset the eligibility records | Closes the "rotate to refresh freshness" corner |
| MEM-13(2) | tag, chain id, entry, window, sequence | tag, chain id, entry, window, sequence **+ hbAnchorBlock, hbAnchor**; tag V1 → V2 | Bounds pre-signing (§5); the tag version is part of the domain separation |
| MEM-13(2a) | key/entry/retired; window current; seq advances; window not recorded; batch atomic | Kept, plus (e) anchor real/past/within `HEARTBEAT_ANCHOR_AGE` | The freshness term, with its own rejection rule |
| MEM-13(2b) | instant = named window start; monotone; not carrier time | Kept; the instant is read as the named window's **start L1 block number** | The round-6 repair was right; the grid is measured in L1 blocks (F1 realisation) |
| MEM-13(2c) | pre-signing "finite and deliberate", horizon = windows signed | Pre-signing bounded to `HEARTBEAT_ANCHOR_AGE` L1 blocks; residual named F9 | The horizon was adversary-chosen |
| MEM-13(3) | predicate at the commit point; exclusion from root/TotalVP/n | Predicate keyed to the derived instant `I*(e)` on the L1 block-height grid — with the launch transition shifting it two heartbeat windows for the two clamped epochs (`e_0 + 1`, `e_0 + 2`) — plus the empty-roster revert rule | The commit's own window is caller-influenced and a past timestamp is unreadable; `n = 0` is an invalid set |
| MEM-13(4) | no rule removes weight | Kept unchanged | D-14's property |
| MEM-13(5) | safety per set version; liveness "excluded at the next boundary" | Kept, plus: the claim is about versions committed from then on; exclusion can raise an adversary's share (F8); a stalled committed version is not repaired by this rule | The old claim silently assumed the chain could reach the next boundary |
| MEM-13(6) | window sizing; `T_ROTATE ≥ HEARTBEAT_WINDOW` | Kept; `HEARTBEAT_ANCHOR_AGE` relation; `T_ROTATE` relation restated; the stale-inference sentence deleted; sizing, change semantics and the change-timing Open stated in L1 blocks | R6-D12-06; F1 realisation |
| MEM-13(7) | costs (a)–(e); F8 | Kept; costs (e)/(f) added (all-ineligible append; declared non-fix); cost (g) added (the L1-block window's variable wall-clock duration); F9 added | Honest cost accounting for the new rule |
| CONS-16(1) | trigger + "cohort already ineligible because `T_ROTATE ≥ HEARTBEAT_WINDOW`" | Trigger kept; the inference deleted (exclusion is established at (3)) | R6-D12-06 |
| CONS-16(2) | invoke/delay/cancel; mutual exclusion with REC-02 | Kept minus REC-02; `T_ROTATE_DELAY` relation registered | R5T-H-1; v1 has no REC-02 |
| CONS-16(3) | `e_r` = lowest final epoch with `t_root ≥ T_inv` | `e_r` = lowest final epoch with `w*(e_r) ≥ hbWindowOf(N_inv) + 3` (F1 realisation: on the L1 block-height grid, `N_inv` the invocation block) | Excludes a cohort that stopped signing |
| CONS-16(4) | boundary amendment, no generation | Kept; `h_close` explicitly named as an L2 fact | Feeds the gate |
| CONS-16(5) | precondition Open, F7; h_close described as produced-tip | Precondition Open **and** the `h_close` referent missing; hard gate | The preserved text asserted a referent L1 does not have |
| CONS-16(6)(7) | no discretion; funding Open; not a rollback; not a cure | Kept, with the F8/non-fix restatement | D-14 honest limits |
| CONS-16(8) | — | New: reads no deferred name; no client-side enforcement | D-16 discipline |

*(F1 realisation, applied after this table was written: the heartbeat window is an interval of L1 block
numbers, `lastHeartbeatAt(v)` is the start block of the window a signature names, and MEM-13(3)'s
predicate is keyed to the derived instant `I*(e)` rather than the commit point or `t_root(e)`. The
rows above read accordingly; the preserved-text column is unchanged.)*

## Appendix B — Replay and pre-signing vectors against the revived rule

| Vector | Rejected by |
|---|---|
| Resubmit a captured signature in a later window | (2a)(b) current-window check |
| Resubmit the same signature in the same window | (2a)(d) window-already-recorded |
| Replay with a lower/equal sequence | (2a)(c) |
| Cross-chain replay | chain id in the preimage |
| Cross-entry replay | entry id in the preimage |
| Replay under a different domain (heartbeat vs set leaf vs vote) | `DOMAIN_HEARTBEAT` tag |
| Hoard a signature naming a future window | (2a)(b): cannot be accepted before that window begins |
| Refresh an old signature by re-submitting it later | (2b): the recorded instant is the named window's start, never the carrier's time |
| Pre-mint an inventory of future windows | (2a)(e): the anchor must exist and be ≤ `HEARTBEAT_ANCHOR_AGE` blocks old, so each signature must be produced near its submission |
| Reuse a signature with a different anchor | the anchor is inside the signed preimage |
| Use a rotated-away heartbeat key | (2a)(a): retired key invalid |
| Bypass by partial batch | (2a) atomicity: any failing signature reverts the batch |
| Rotate the heartbeat key to reset freshness | (1): rotation does not reset `lastHeartbeatAt/Window/Seq` |
| Stay eligible while silent for arbitrarily many windows | (2c) + CONS-16(3)(b): coverage ends within `HEARTBEAT_ANCHOR_AGE` blocks of the last signature; the resumed version is drawn after it |
