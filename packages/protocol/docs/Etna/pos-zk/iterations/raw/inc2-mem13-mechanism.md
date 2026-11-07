# Increment 2 — raw adversarial review: the revived MEM-13 heartbeat mechanism

**Reviewer:** r6-gov-generations (task-25), independent adversarial reviewer.
**Snapshot:** `cea431c37` (branch `etna-pos-zk`), working tree clean; the snapshot commit is the increment's
own implementation commit. **Angle:** the revived mechanism itself — `spec/03` MEM-13 and `spec/02`'s
CONS-13/M7 — against the design delta `increments/02-heartbeat-design.md`, D-17 and the converged v1.
**Method:** the specification is the authority; the delta's claims and its Appendix B replay table are
claims, not evidence. Citations: `NN:line` = `spec/NN-*.html`; `delta §n` = the design delta.

**Counts: Critical 0 · High 1 · Medium 1 · Low 2.**
**Verdict: the heart of the revival holds** — the payload binding is replay-proof and window-bound, the
recorded instant cannot be advanced by carrier timing, the pre-signing horizon is genuinely bounded by
`HEARTBEAT_ANCHOR_AGE`, exclusion is not a weight change, and CONS-16/`T_ROTATE`/`T_ROTATE_DELAY` stay
tombstoned and unread. **But the increment is not safe to ship as written**: a rule-sanctioned change to
`HEARTBEAT_WINDOW` breaks the window-index guard (R-INCR2-01) and the missing non-zero key check turns a
zero heartbeat key into a signature wildcard (R-INCR2-02). Both are one-clause fixes.

---

## Finding R-INCR2-01 — High: a change to `HEARTBEAT_WINDOW` re-labels the window grid, locks every incumbent out of attesting, and can empty the roster into a boundary halt

**Severity: High.** One-line rationale: the rule defines windows by a *global* function of the current
parameter (`hbWindowOf(t) = floor(t / HEARTBEAT_WINDOW)`) while acceptance compares a freshly computed window
**index** against the stored `lastHeartbeatWindow(v)` index from the previous grid — so after an increase in
`HEARTBEAT_WINDOW` every entry that already has a record fails `(2a)(d)` for a period that scales with the
chain's age (in practice indefinitely), its eligibility then ages out, and with no new entrants the eligible
roster empties, `commitSet()` reverts, and the boundary halt of MEM-09(5) becomes reachable with no v1
recovery path (CONS-16 is a tombstone); the register's promise that a change "never re-labels a window that
has begun" is false of the rule's own grid, and a decrease can even *lower* the recorded instant that (2b)
declares monotone.

**File + rule id.**
- `03:530-532` (**MEM-13(2)**): "Windows are tumbling, non-overlapping intervals … window w is the half-open
  interval `[w · HEARTBEAT_WINDOW, (w+1) · HEARTBEAT_WINDOW)` and **`hbWindowOf(t) = floor(t / HEARTBEAT_WINDOW)`**
  … A change to `HEARTBEAT_WINDOW` applies only to windows that begin after it takes effect and **never
  re-labels a window that has begun**."
- `03:535` (**2a)(b)**): "`hbWindow = hbWindowOf(block.timestamp)`" — the named window must be the current
  one, computed under the parameter in force.
- `03:537` (**2a)(d)**): "if `lastHeartbeatSeq(v) > 0`, then **`hbWindow > lastHeartbeatWindow(v)`**" — an
  **index** comparison against a value recorded under the old grid.
- `03:540` (**2b**): "`lastHeartbeatWindow(v) = hbWindow` … The recorded value is monotone: accepted windows
  strictly increase ((2a)(d)) and **the window grid is increasing**, so `lastHeartbeatAt(v)` never decreases
  and is never edited downward."
- `03:546` (**MEM-13(6)**): "Evaluation uses the parameter value in force at the block in which it is made; a
  change to `HEARTBEAT_WINDOW` … applies only to windows that begin after it takes effect and MUST NOT edit,
  re-derive or re-interpret a recorded `lastHeartbeatAt(v)`, `lastHeartbeatWindow(v)` or
  `lastHeartbeatSeq(v)`." `09:213` repeats the never-re-labels claim in the register.
- **Missing rule:** either (i) `HEARTBEAT_WINDOW` MUST NOT be changed after activation, or (ii) the
  window-recency guard must be stated in absolute terms — `hbWindow · HEARTBEAT_WINDOW > lastHeartbeatAt(v)`
  (equivalently a stored window start) — or (iii) the grid must be defined piecewise by the parameter version
  in force at each instant, with that version stored in the record. As written, none of the three holds.

**Assumptions.** No adversary is required. The change is a rule-sanctioned parameter update (the register
row and (6) explicitly define change semantics); the chain has been running long enough that the recorded
window index is large (any chain older than a few windows).

**Concrete attack / failure trace.**
1. The chain has run for time `T` under `HEARTBEAT_WINDOW = W_old`; an incumbent entry's record is
   `lastHeartbeatWindow(v) = i_old ≈ T / W_old`, `lastHeartbeatAt(v) = i_old · W_old`.
2. An upgrade sets `W_new > W_old` (e.g. one L1-side epoch to two), with the records preserved as (6)
   requires. The grid is re-labelled: at the same instant, `floor(t / W_new) < i_old` for as long as
   `t < i_old · W_new`, i.e. for roughly `(T / W_old) · (W_new − W_old)` — for a year-old chain and a
   doubling, about another year.
3. Every heartbeat the incumbent signs names the current (new-grid) window, so (2a)(d) rejects it. The
   incumbent cannot clear the record — (2b) forbids editing it and (1) says a key rotation does not reset it —
   so it cannot re-attest at all.
4. Its eligibility nonetheless survives for up to `W_new` (the predicate is `lastHeartbeatAt ≥ t_root − W_new`,
   and `W_new` is larger). Once `t_root > lastHeartbeatAt + W_new` — at most one new window later — the
   incumbent is ineligible for every commit point, and (2a)(b) will not let it sign a heartbeat for any
   *past* window that would restore it. There is no repair short of exiting and re-bonding as a new entry.
5. If no entry without a record exists, the eligible roster is empty: `03:542-543` (MEM-13(3)) makes
   `commitSet()` revert rather than append an empty version, the append deadline is missed, and the boundary
   halt of MEM-09(5) is reached — a halt v1 cannot clear, because the rotation that would re-partition the
   epoch is deliberately a tombstone (`02:505-510`, M7 `02:541`).
6. If new entrants do exist, they are exempt from (2a)(d) (the guard is `lastHeartbeatSeq(v) > 0`), so they
   attest immediately and become the entire eligible roster while every incumbent is locked out — a
   **composition takeover with no censorship and no adversary**, which F8 (heartbeat censorship) does not
   describe.
7. The decrease direction is the mirror defect: with `W_new < W_old`, the new index can exceed the old while
   the new recorded start `hbWindow · W_new` is *below* the stored `lastHeartbeatAt(v)` (e.g. an old record
   at start 200 under `W_old = 100`, a change to `W_new = 60` at that instant, and an accepted heartbeat
   naming new window 3 → recorded start 180). An accepted heartbeat then lowers the recorded instant and
   *reduces* the entry's coverage, contradicting (2b)'s "never decreases" and (6)'s "MUST NOT edit or
   re-derive".

**Inside / outside the claimed fault model.** Inside: no assumption fails, no adversary is required, and no
cryptographic primitive is touched. The trigger is a parameter change the rule itself provides for; the
consequence is a liveness failure the converged v1 explicitly cannot repair.

**Attacker cost.** None for the liveness failure (it follows from the change alone). For the composition
takeover in step 6, the cost of one new bond (`S_min` TAIKO, refundable through MEM-05) — no censorship
budget, which is strictly cheaper than F8's one-transaction-per-entry-per-window.

**Requirement affected.** The revived rule's own invariants ((2)'s never-re-labels promise, (2b)'s
monotonicity, (6)'s no-re-interpretation); MEM-09(5)/HALT-01 and the disclosed "no in-protocol way to clear a
boundary halt" position; D-14's framing that exclusion is a *future-version selection filter* whose effects
are bounded and described; the increment's claim that the mechanism's costs are the ones in (7).
**Evidence.** `03:530-532`, `03:535`, `03:537`, `03:540`, `03:542-543`, `03:546`; `09:213`; `02:441`,
`02:505-510`, `02:541`; `10:321-322`, `10:352`; delta §2, §5, §6.3(5).

---

## Finding R-INCR2-02 — Medium: nothing rejects a zero (or unusable) heartbeat key, and `ecrecover`'s zero return then makes every malformed signature valid with an attacker-chosen sequence

**Severity: Medium.** One-line rationale: acceptance is an equality test against the stored key
("the recovered key is exactly `heartbeatKey(v)`"), `ecrecover` returns `address(0)` for any signature it
cannot recover, and no rule forbids registering or rotating the heartbeat key to the zero address — so an
entry whose key is zero accepts any garbage signature, and because the attacker chooses the payload it can
write `hbSeq = type(uint256).max`; (2a)(c) then rejects every future signature by the honest key and no rule
resets the sequence, so the entry is permanently ineligible and only a new bond recovers it.

**File + rule id.** `03:529` (MEM-13(1): "Each entry registers an ECDSA (secp256k1) heartbeat key on L1 at
bonding time" — no non-zero condition); `03:534` (2a)(a): "the recovered key is exactly `heartbeatKey(v)`, v
is a registered entry, and the key is not retired"); `03:536` (2a)(c)); `03:528-529` ("Rotating the heartbeat
key does not reset `lastHeartbeatAt(v)`, `lastHeartbeatWindow(v)` or `lastHeartbeatSeq(v)`"); the interface
rows `03:111` (`bond(uint256 amount, bytes32 ed25519PubKey, address heartbeatKey)`) and `03:124`
(`rotateHeartbeatKey(address newHeartbeatKey)`) — neither rejects zero; `03:385` (MEM-07(1) restatement);
`09:217` (`heartbeatKey(v)` register row — no non-zero condition). **Missing rule:** reject
`heartbeatKey == address(0)` at bonding and at rotation, and state it in MEM-03(1)/MEM-07/MEM-13(1) and the
register row.

**Assumptions.** One active entry has a zero heartbeat key. That arises from an owner mistake, a bonding
interface that omits the argument (it is an `address` parameter with no stated validity condition), or an
owner deliberately opting out of the heartbeat duty — all reachable without any protocol failure.

**Concrete attack trace.**
1. Entry `v` has `heartbeatKey(v) = address(0)`.
2. Any account calls `heartbeat(v, hbWindow = hbWindowOf(block.timestamp), hbSeq = 2^256 − 1,
   hbAnchorBlock = block.number − 1, hbAnchor = blockhash(block.number − 1), signature = any malformed
   signature)`.
3. `ecrecover` returns `address(0) = heartbeatKey(v)`, so (2a)(a) passes. (2a)(b) passes (the named window is
   the current one); (2a)(c) passes (any `hbSeq > 0`); (2a)(d) is vacuous on the first record because its
   guard is `lastHeartbeatSeq(v) > 0`; (2a)(e) passes with a real, fresh anchor.
4. `lastHeartbeatSeq(v) = 2^256 − 1` is recorded. The honest key can never satisfy (2a)(c) again, and (1)
   states that rotating the heartbeat key does not reset the sequence, so the entry can never attest again:
   it is excluded from every set version committed after its last covered window. The same call could instead
   simply mark the entry eligible — i.e. the owner's opt-out is overridden by anyone.
5. Consequence: a silent, permanent removal of that entry's weight from all *future* versions' `TotalVP`
   (the F8 harm) for the price of one L1 transaction, without censoring anything — a cheaper path to the same
   effect F8 describes, available whenever a zero key exists.

**Inside / outside the claimed fault model.** Inside (requires a zero key on the victim; no assumption
failure, no cryptographic break — the exploit *uses* `ecrecover`'s documented failure return).
**Attacker cost.** One L1 transaction (plus gas for the garbage signature); no stake, no censorship budget.
**Requirement affected.** MEM-13(1)/(2a)(a)/(2a)(c); D-14's exclusion semantics (permanent exclusion of an
entry that never had a fair attestation); F8's statement that excluding an entry requires preventing its own
heartbeat; D-9/ECON-11 (no compensation for the lost slots).
**Evidence.** `03:111`, `03:124`, `03:385`, `03:528-529`, `03:534`, `03:536-538`; `09:217`; delta §2(a),
§9.6.

---

## Finding R-INCR2-03 — Low: the signed payload identifies the entry by its bonding address, and no rule makes that identifier unique

**Severity: Low.** One-line rationale: MEM-13(2) binds `v` = "the entry identifier the ledger uses — the
bonding address of MEM-03(1)", but nothing forbids one address from holding two entries (MEM-03(1)/MEM-14(2)
admit any account up to `N_MAX`, and MEM-10(1) refuses only per-address *stake* caps), so for two entries of
one address the payload cannot say which entry attested: either the key/records collide (and one bond's
registration overwrites the other's, or `MUST NOT be bound to two entries` rejects the second bond while
MEM-03(1) requires bonding to register a key) or the payload cannot distinguish them and one signature can be
recorded for each entry.
**File + rule id.** `03:530-531` (payload binds `v`); `03:136` (MEM-03(1): "Any L1 account may create an
entry by bonding…"); `03:253` (MEM-14(2): the only admission conditions are `amount ≥ S_min` and
`n < N_MAX`); `03:555` (MEM-10(1): no per-address cap); `03:529` ("a heartbeat key MUST NOT be bound to two
entries"); `03:711` (`heartbeatKey(v)` row). **Missing rule:** a unique per-entry identifier in the preimage
(e.g. the activation queue key of MEM-03(2)) or an explicit one-active-entry-per-address rule.
**Assumptions.** An owner bonds twice from one address; no adversary is needed.
**Attack trace / failure trace.** Address X calls `bond` twice; entries A and B share `v = X`. Reading one
(records keyed by `v`): a heartbeat for A also sets B's eligibility, and B's key registration overwrites A's
(or is rejected, leaving B without any key path), so the per-entry duty of MEM-13(1) is not realisable for
both entries. Reading two (records keyed by an internal entry index): the signed payload binds only X, so one
signature is admissible for both A and B — the same `(hbWindow, hbSeq, anchor)` can be recorded once per
entry, letting a two-entry owner satisfy two heartbeat duties with one signature, and making the (2a)(a)
key-equality check resolvable only by trying every entry of X. Neither behaviour is stated; the fix is a
unique entry identifier.
**Inside / outside.** Inside (specification ambiguity; self-inflicted by a two-bond owner; no safety or fund
impact — the two entries are the same principal). **Attacker cost.** None. **Requirement affected.** MEM-13(1)
(one key per entry), MEM-13(2) (the payload's binding), MEM-03(1)/MEM-14(2) (admission), D-14's per-entry
semantics. **Evidence.** `03:136`, `03:253`, `03:529-531`, `03:555`, `03:711`.

---

## Finding R-INCR2-04 — Low: retirement is "invalid at the block of acceptance", so rotating away from a key and back re-binds it; the spec does not settle permanence

**Severity: Low.** One-line rationale: the rule invalidates "a heartbeat signed under a key that was retired
**at the block of acceptance**" — a status-at-acceptance test, which permits an owner to re-bind an old key
and thereby re-validate signatures made with it; the delta flags this exact question as open (delta §9.6,
"a retired heartbeat key is invalid forever … the review should confirm"), and the implemented text does not
answer it, so a reviewer/implementer cannot tell whether `rotateHeartbeatKey(A)` after `rotateHeartbeatKey(B)`
re-arms A.
**File + rule id.** `03:529` (MEM-13(1)); `03:385` (MEM-07(1)); `03:124` (`rotateHeartbeatKey` row);
delta §9.6.
**Assumptions.** An owner rotates `A → B → A` (or an upgrade replays an old registration); a pre-minted
signature by A exists. No protocol failure is needed.
**Attack trace / failure trace.** The exposure is bounded by the anchor rule: a signature by A can only be
accepted within `HEARTBEAT_ANCHOR_AGE` blocks of its bound anchor (2a)(e), so re-binding A cannot resurrect an
unbounded credential, and any pre-minted payload that names a still-future window can only be used for its
window and only while its anchor is fresh — F9's horizon. The defect is therefore the unresolved
specification question, not an exploit: an owner who retired a key *because it was compromised* has no rule
telling it that re-binding that key is possible, and an implementer does not know whether to keep a permanent
retired-key set (which `MUST NOT be bound to two entries` would need anyway) or only the current key.
**Inside / outside.** Inside (specification completeness; no adversary required; bounded by F9).
**Attacker cost.** None beyond F9's ordinary costs.
**Requirement affected.** MEM-13(1) key lifecycle; delta §9.6; the review-round mandate to close the two
blockers in DEFERRED.md §2. **Evidence.** `03:529`, `03:385`, `03:124`, `03:538`; delta §5, §9.6.

---

## Checked, and holds (the angle's verification list)

- **Replay-proof and window-bound across submissions, re-submissions, batched relays, and epoch boundaries.**
  The preimage binds `DOMAIN_HEARTBEAT ("ETNA_HEARTBEAT_V2")`, chain id, entry, window index, sequence and the
  anchor pair (`03:530-531`); acceptance requires the *current* window (2a)(b), an advancing sequence (2a)(c)
  and, once a record exists, a strictly later window (2a)(d). A replay of an old payload fails (b); a replay
  within the same window fails (d); a future-window payload fails (b) until its window arrives; a different
  chain, entry, window, sequence or anchor changes the signed digest. Cross-version replay is structurally
  impossible by the V2 tag bump. Batch atomicity ("a batch carrying any signature that fails an acceptance
  check reverts and records no heartbeat", `09:215`) prevents partial acceptance. The signature is the
  entry's own act and the carrier is irrelevant, so no carrier can substitute, re-attribute or duplicate an
  attestation. The only batching grief I could construct — front-running a public batch with one of its own
  signatures, causing the batch to revert on (2a)(d) — costs the relayer gas and *records a valid heartbeat
  for the stolen entry*, so it cannot exclude anyone and is a standard private-orderflow concern.
- **The recorded instant cannot be advanced by the carrier's timing.** `lastHeartbeatAt(v) = hbWindow ·
  HEARTBEAT_WINDOW` (2b), a function of the payload, never of `block.timestamp` or `msg.sender`; submitting
  early or late in a window is irrelevant, and a heartbeat cannot be carried into a later window (2a)(b).
  Verified with the one exception in R-INCR2-01 (a `HEARTBEAT_WINDOW` decrease after a record exists).
- **The pre-signing horizon is bounded by `HEARTBEAT_ANCHOR_AGE`, and F9 is the right residual.** Acceptance
  requires `hbAnchorBlock < block.number`, `block.number − hbAnchorBlock ≤ HEARTBEAT_ANCHOR_AGE ≤ 256` and
  `blockhash(hbAnchorBlock) = hbAnchor ≠ 0` (2a)(e), `09:216`), so a signature can only be accepted within
  `HEARTBEAT_ANCHOR_AGE` blocks of a block that exists, which defeats the pre-minted-inventory attack the
  round-5 Critical relied on. The remaining gap — a key can stop signing within the last
  `HEARTBEAT_ANCHOR_AGE` blocks of a window and still be covered through the *next* window it was able to
  name — is exactly F9 (`03:547`), correctly labelled Open and correctly traded against the rejected
  per-window challenge (which would add one transaction per window and make one censored transaction exclude
  the whole roster). Clause (2c)'s coverage sentence is accurate when "the window in which it last signed" is
  read as the window it named; the mechanism's one-window coverage is by design.
- **Exclusion is not a weight change (D-14 survives).** MEM-13(4) (`03:544`) restates it; the only paths
  that reduce or remove weight remain the owner's exit (MEM-05) and a slashing (MEM-06); MEM-02/MEM-06/MEM-08
  are unchanged, `SlashBase` is untouched by exclusion, and no rule slashes, decays, discounts or zeroes an
  ineligible entry. A committed version's root, total and count are immutable (MEM-09(3),(4)), eligibility is
  evaluated once inside `commitSet()` from L1 state with no caller input (`03:125`), and re-attesting
  restores eligibility at the next commit point. **No path lets a coalition raise its share inside a
  committed version** — eligibility changes only future composition, which is disclosed as such
  (`02:441`, `03:545`, `10:214`, `10:321-322`).
- **The empty-roster revert cannot be triggered adversarially except by making *all* entries ineligible.**
  `commitSet()` reverts only when no active entry passes the predicate (`03:542-543`); an adversary cannot
  make a specific entry ineligible, because eligibility requires a positive act by that entry's own key and a
  carrier can only submit signatures the entry produced. The reachable routes are: (i) censoring every
  active entry's heartbeat — F8, one L1 transaction per entry per window, disclosed; (ii) the
  `HEARTBEAT_WINDOW` change trap — R-INCR2-01, *not* disclosed; (iii) a deployment where every key is zero —
  R-INCR2-02, also not disclosed. The revert itself is correctly specified: it refuses an empty version, the
  append is restored by a later successful call under MEM-09(1)'s lowest-missing rule, and the boundary halt
  it can reach is disclosed (`03:547`(e), `10:321-322`, `06:475`).
- **The ECDSA key lifecycle has no forging path beyond R-INCR2-02, and no unbounded resurrection.**
  Owner-only registration and rotation, forward-only effective from the rotation transaction's L1 block,
  `MUST NOT be bound to two entries`, no reset of the records, no appearance in a set root or in the proof
  statement (spec/05 is unchanged; no journal field or public input is added), and no power beyond the
  clause-(3) attestation (`03:529`, `03:385`, `03:111-125`, `04:2`). ECDSA malleability does not forge a
  different key; a signature by a non-registered or retired key fails (2a)(a); a signature with a zero
  recovered key fails (2a)(a) unless the stored key is itself zero (R-INCR2-02); re-binding a retired key is
  bounded by the anchor horizon (R-INCR2-04).
- **CONS-16, `T_ROTATE` and `T_ROTATE_DELAY` stay tombstoned and unread.** `02:16` states CONS-01–CONS-15 in
  full and CONS-16 as a tombstone; `02:505-510` and M7 `02:506-510`, `02:541` keep the rotation deferred with
  the `h_close` referent named as the blocker (F7); MEM-13(5)/(6) (`03:545-546`) say the rotation is not
  implemented and "its own T_ROTATE/T_ROTATE_DELAY relations stay withdrawn from the register with the other
  tombstones"; `09:210-211` keep both rows withdrawn ("increment 02: still withdrawn"); no live rule on
  either page reads them. CONS-13(2) (`02:441`) now says the roster is "the ledger entries active **and
  eligible** at that point … filtered by the heartbeat predicate of MEM-13(3), evaluated once inside that
  call and never re-evaluated" — consistent with MEM-09(1)/(5) and with the two-epoch lookahead.
- **The halt story is consistent after the revival.** Every place that said membership has no liveness gate
  is updated (I found no stale occurrence in the spec; the two remaining course lines say the gate exists and
  does not compel participation): exclusion filters *future* versions only, the committed roster is immutable,
  a boundary halt can now be resolved by a *later* append whose filtered set is reachable, and a quorum stall
  inside a committed epoch still ends only when the cohort returns — with CONS-16 gated (`06:130`, `06:141`,
  `06:475`, `10:36-39`, `10:214`, `10:310-322`, `10:348-353`, `index.html:428`).
- **Register, index and course.** `09:33` restates the mechanism as live with the V2 payload, the exclusion
  semantics and the six acceptance checks; `09:213-224` register `HEARTBEAT_WINDOW`, `HEARTBEAT_MIN_INTERVAL`
  (non-normative), `HEARTBEAT_BATCH_CAP`, `HEARTBEAT_ANCHOR_AGE`, the record fields and the domain tag;
  `09:212` retires `lastObserved(v)`; `index.html:428` and `index.html:558` carry the live row and the
  parameter map; `learn/limitations.html:149`, `:275` teach the gate and its non-compulsion.

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 1 | R-INCR2-01 (`HEARTBEAT_WINDOW` changes re-label the grid: incumbents are locked out of attesting, the roster can empty into a boundary halt, and a decrease breaks (2b)'s monotonicity) |
| Medium | 1 | R-INCR2-02 (no non-zero key check; a zero heartbeat key makes `ecrecover` failures valid and lets an attacker burn the sequence permanently) |
| Low | 2 | R-INCR2-03 (the entry identifier is a non-unique bonding address) · R-INCR2-04 (retired-key permanence is unsettled) |

**Strongest attack:** R-INCR2-01. It needs no adversary, no assumption failure and no cryptographic break:
the rule itself defines a global window grid and an index-based recency guard while explicitly providing for
parameter changes. Raising `HEARTBEAT_WINDOW` makes every incumbent's next heartbeat fail (2a)(d) for a
period proportional to the chain's age, ages its eligibility out, and — if no new entry exists — empties the
eligible roster so `commitSet()` reverts and the chain reaches the boundary halt that v1 deliberately cannot
clear (CONS-16 is a tombstone). Any new entrant is exempt from (2a)(d) and can take the roster over with one
bond. The fix is one clause: state the recency guard in absolute terms (compare `hbWindow · HEARTBEAT_WINDOW`
against the stored `lastHeartbeatAt(v)`), or define the grid piecewise with the parameter version stored, or
forbid the change after activation.

**Is the increment safe to ship?** **Not as written.** Fix R-INCR2-01 (High) and R-INCR2-02 (Medium) first;
both are small, local changes — one comparison and one registration check — and neither reopens the delta's
design or a converged v1 decision. R-INCR2-03 and R-INCR2-04 are Low and can be settled in the same pass
(a unique entry identifier or an explicit one-entry-per-address rule; an explicit "a retired key is invalid
forever, and never re-bindable" sentence, which also answers delta §9.6). With those four fixed, the
mechanism itself is sound on everything I attacked: the payload is replay-proof and window-bound, the
recorded instant is payload-derived, the pre-signing horizon is bounded and F9 is the honest residual,
exclusion is a pure selection filter that leaves committed versions and stake untouched, the empty-roster
revert is not adversarially reachable except through F8, and the rotation's tombstone is respected.
