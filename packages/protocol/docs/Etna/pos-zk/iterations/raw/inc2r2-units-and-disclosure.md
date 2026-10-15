# Increment 2 re-review — units and disclosures after the grid change

**Angle.** Units and disclosures after the L1 block-height grid change: every heartbeat quantity's unit in
the register, index, migration, interface and assurance pages; no page still stating the withdrawn reading
(the window containing the commit point, or `t_root(e)`); the new MEM-13(6) Open and the wall-clock
variability cost carried where falsifiers and limits are collected; the migration claim still exact; and
no disclosure promising more than the rules deliver.

**Snapshot.** `7a995f179`; working tree at the same commit. Read first: all four `inc2-*` round-1
reports, the current `spec/03` MEM-13, the updated `increments/02-heartbeat-design.md` (now marked
APPLIED), `DEFERRED.md` and D-17.

**Result: 0 Critical, 0 High, 1 Medium, 1 Low. No attack found.** The unit work of the grid change is
essentially complete — the register, index, migration, interface, assurance and course all state the new
units, and the new Open and the wall-clock cost are carried in the assurance, the index, the owning rule
and the course. The two findings are stale-text leftovers of the *withdrawn* reading in four artifacts the
propagation commits did not touch. Neither is inside the fault model; **the increment is safe to ship**,
with INC2R2-UD-01 worth fixing before the announcement text is used.

---

## INC2R2-UD-01 — Medium — two artifacts still state the withdrawn, caller-dependent reading of the eligibility window: `spec/01` ROLE-01 (normative rule text) and `spec/08`'s T3 migration announcement both say the eligible window is the one containing the version's **commit point**, which MEM-13(3) explicitly replaced with the derived instant `I*(e)`.

**File + rule id.** `spec/01-system-model.html` **ROLE-01** (line 378): "it must have an accepted
heartbeat — signed by its registered ECDSA heartbeat key, **naming the heartbeat window containing a set
version's commit point** and binding an L1 anchor no older than `HEARTBEAT_ANCHOR_AGE` blocks — or it is
not selected into that version". `spec/08-migration-upgrades.html` line 504 (MIG-03 / T3 runbook): "an
entry with no accepted heartbeat is not selected into **set versions whose commit points fall in
heartbeat windows** it did not attest for". The owner rule, `spec/03` **MEM-13(3)**, states the opposite:
eligibility is `lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW` with
`I*(e) = floor(L1_first(max(e − LOOKAHEAD_EPOCHS, e_0)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW`, "computed
inside `commitSet()` from the activation record and the epoch, **not the window containing the commit's
own timestamp**", and the delta records the old predicate — "the `t_root(e)` predicate … the window
containing the commit point — is withdrawn" (`increments/02`, lines 110–112).

**Assumptions.** MEM-13 is the owner of the predicate (GEN-03); 01 and 08 are description/runbook pages
that must agree with it; the round-1 F1 repair made the instant caller-independent, so the commit block,
its timestamp and its position cannot select the roster.

**Attack trace (implementer/operator-facing, no adversary).**
1. An implementer who reads ROLE-01 alone derives the predicate "the named window must contain the
   version's commit block" — caller-dependent, the exact defect F1 repaired — and a contract built to it
   would take a different roster than MEM-13(3) for the same L1 state (01 is normative text, so the two
   readings cannot both be followed).
2. An operator who plans against the T3 announcement's wording paces attestations against the commit
   point's window; the actual evaluation window is derived from the L1-side schedule two epochs ahead
   (`L1_first(C(e))`), so an attestation timed to the wrong window leaves the entry out of a version it
   could have covered — the operational lapse the mechanism's honest-costs clause (g) warns about.

**Fault-model verdict.** Not applicable: a specification-internal contradiction and a stale runbook
sentence; no rule mis-executes as written, no funds at risk. Both artifacts were skipped by the
grid-propagation commits (`1730a9b5c`, `7a995f179`), which touched the delta, 02, 03, 08 (two lines
elsewhere), 09, 10, the index and the course.

**Attacker cost.** None.

**Requirement affected.** GEN-03 (one rule, one place); the increment's F1 repair; MEM-13(3); ROLE-01;
MIG-03/MEM-03(1) runbook accuracy.

**Evidence.** `spec/01-system-model.html` line 378; `spec/08-migration-upgrades.html` line 504;
`spec/03-membership-staking.html` MEM-13(3) (line 541) and MEM-13(6) (line 545);
`increments/02-heartbeat-design.md` lines 36, 110–112, 291, 806–809; `git diff --stat 1730a9b5c~1 7a995f179`.

---

## INC2R2-UD-02 — Low — the live register and the decision record still carry the withdrawn reading, and DEFERRED.md §2 does not carry the new MEM-13(6) Open or the height-grid cost.

**File + rule id.** `DEFERRED.md` §2, "What was revived" (lines 30–33): "a set version's roster is the
active entries that posted a heartbeat inside **the heartbeat window containing that version's commit
point** … and is restored by re-attesting **at a later commit point**". `DECISIONS.md` **D-17** (lines
576–577, 585): "Eligibility for a set version requires an accepted heartbeat inside the heartbeat window
containing that version's commit point … and re-attesting restores eligibility at the next commit point."
Both are the pre-repair model: the shipped predicate is the derived `I*(e)` and re-attestation restores
eligibility for the version whose evaluation window is the window the new heartbeat names or the one
immediately after it — "including for an append that is still pending, because `I*(e)` does not move"
(MEM-13(4)). `DEFERRED.md` §2 also lists F7/F8/F9 but not the new MEM-13(6) change-timing Open, nor the
wall-clock variability cost, both of which the assurance (lines 354, 356), the index (line 428), the
owning rule and the course now carry.

**Assumptions.** `DEFERRED.md` is the live register of record for the revival; `DECISIONS.md` is
append-only, so the correction belongs in a reviewed addendum to D-17 or a new entry, not a silent edit;
the grid-propagation commits did not include either file.

**Attack trace.** A reader of the register/decision record learns the caller-dependent model and a
restoration rule ("at the next commit point") that is narrower than the shipped one; the register is the
artifact the increment's own design delta points to for "what was revived".

**Fault-model verdict.** Not applicable (register/record staleness; no rule reads either text).

**Attacker cost.** None.

**Requirement affected.** D-17; DEFERRED.md as the live register; the increment's disclosure duty.

**Evidence.** `DEFERRED.md` lines 25–51; `DECISIONS.md` lines 565–600 (D-17); `spec/03` MEM-13(3)/(4)
(lines 541, 543); `spec/10-assurance.html` lines 354–356; `spec/index.html` line 428.

---

## Verified and holds

1. **Every heartbeat quantity states the right unit in the register.** `spec/09`: `HEARTBEAT_WINDOW` —
   "L1 blocks", with `[w·W, (w+1)·W)`, `hbWindowOf(n) = floor(n/W)`, the blocks-to-blocks relation and the
   change semantics (line 213); `HEARTBEAT_MIN_INTERVAL` — "seconds", non-normative, "the contract does
   not enforce" and "it is not part of the L1 block-height grid because no rule reads it" (line 214);
   `HEARTBEAT_ANCHOR_AGE` — "L1 blocks", with
   `≥ ceil(T_L1_include(p)/L1_BLOCK_INTERVAL) + margin` and `≤ 256` (line 216); `lastHeartbeatAt(v)` —
   "L1 block number … the start L1 block number of the window the signature names … never the including
   transaction's `block.timestamp` or `block.number`", unit "L1 blocks on the height grid" (line 218);
   `lastHeartbeatWindow(v)` — "window index … grid-relative, not monotone across a parameter change …
   MUST NOT be compared across grids and is not a recency test" (line 219); `hbWindow` — "window index …
   on the L1 block-height grid … acceptance requires `hbWindow = hbWindowOf(block.number)`" (line 221);
   `hbAnchorBlock` — "L1 block number … a real, past block no older than `HEARTBEAT_ANCHOR_AGE`" (line
   224); `hbAnchor` — "L1 block hash … `blockhash(hbAnchorBlock)` and non-zero" (line 225);
   `heartbeatKey(v)` and `DOMAIN_HEARTBEAT` unchanged in kind (lines 217, 223). The change-order note
   (line 96) states the grid and the new rows; the measurement row reinstates the heartbeat line (line
   266). The same units appear in the index parameter map (line 558: "`HEARTBEAT_WINDOW` and
   `lastHeartbeatAt(v)` are L1 block counts … derived from the activation record … reads no past block's
   timestamp"), the migration budget (`spec/08` line 374: "`lastHeartbeatAt(v)` is an L1 block number,
   not a timestamp, and the derived evaluation instant is computed from the activation record rather than
   stored"), the interface rows (`spec/03` lines 113, 124, 125: the bonding key, the forward-only
   non-resetting rotation, and `heartbeat(v, hbWindow, hbSeq, hbAnchorBlock, hbAnchor, signature)`
   recording `hbWindow · HEARTBEAT_WINDOW`), and the assurance (lines 355–356: "`HEARTBEAT_WINDOW` (in L1
   blocks …)" and the height-grid cost row). `HEARTBEAT_MIN_INTERVAL` is stated as non-normative and
   unread in MEM-13(2)/(6), the 09 row, the index map and the course; no rule reads it.
2. **No page other than the four in the two findings states the withdrawn reading.** The scan for
   "commit point" near heartbeat and for `t_root(e)` finds: the delta, which explicitly withdraws the
   old predicate (lines 110–112, 291, 806–809); `spec/02`'s M7 row (line 541), which states the fixed
   evaluation window and the `h_close` gate; `spec/03` MEM-13(2c)/(3)/(6)/(7)(g) and the D-16 disclosure
   paragraph (line 729); `spec/09` line 213 ("not the window containing the commit's own timestamp");
   `spec/10` lines 354–356; the index (lines 428, 558); and the course (`learn/04` lines 145–151, 199–202;
   `learn/07` lines 77–83; `learn/08` lines 462, 474; `learn/10` lines 121, 307; `learn/glossary` lines
   129, 215; `learn/limitations` lines 150–166, 327). `spec/04` and `spec/05` are untouched by the
   increment and carry no heartbeat predicate.
3. **The new MEM-13(6) Open and the wall-clock variability cost are carried where falsifiers and limits
   are collected.** `spec/10-assurance.html` line 354 is a dedicated row: "Open (MEM-13(6)). Because the
   evaluation instant is derived at evaluation time, a change to `HEARTBEAT_WINDOW` that lands after the
   first boundary of the new grid strictly following some active entry's record … can exclude that entry
   from that one version … Falsifier: such a change, at such a block, excluding such an entry from such a
   version. What would close it: a registered delay … or a per-epoch frozen grid — neither is registered";
   line 356 is the height-grid cost row ("the duty is one attestation per `HEARTBEAT_WINDOW` L1 blocks,
   not per fixed duration … the cadence expressed in seconds is variable and `unmeasured`"), alongside
   F8 (line 353) and F9 (line 355). The index's MEM-13 row carries the change-timing Open explicitly
   ("the change-timing Open of MEM-13(6) is carried with them") and F9's second consequence; MEM-13(6)
   itself states the Open with its falsifier and MEM-13(7)(g) the cost; the course carries both
   (`learn/04` lines 185–186, 196–202; `learn/limitations` lines 162–166); the delta carries them at
   lines 411, 718. The only collection point that lacks them is `DEFERRED.md` §2 (INC2R2-UD-02).
4. **The migration claim is still exactly true.** `spec/08` line 374: the heartbeat adds per-entry
   staking state only ("`heartbeatKey(v)` with its rotation block and `lastHeartbeatAt(v)`,
   `lastHeartbeatWindow(v)` and `lastHeartbeatSeq(v)` (packable into one slot)"), with "`lastHeartbeatAt(v)`
   … an L1 block number, not a timestamp, and the derived evaluation instant is computed from the
   activation record rather than stored"; "no new global state is needed for the anchor check
   (`blockhash` is read at submission), no Inbox, SignalService, Bridge or vault slot is touched, and no
   proof public input, journal field or config-hash preimage element is added", and MEM-13(3) confirms the
   realisation "adds no storage at all". `spec/05` is untouched by the increment; `spec/04` carries only
   the earlier prose sentence that the filter lives in `commitSet()`; the bonding interface (MEM-03(1))
   and the T3 announcement clause carry the signing duty.
5. **No disclosure promises more than the rules deliver.** The claims I checked are qualified exactly as
   the rules require: eligibility is stated with the one-window slack and "with an unchanged window grid"
   (MEM-13(3)); restoration is stated for a pending append because `I*(e)` does not move (MEM-13(4));
   the change-timing case is an Open with its falsifier, not a repaired guarantee (MEM-13(6), 10:354);
   the all-ineligible append and the `MEM-09(5)` halt are stated rather than hidden (MEM-13(3)/(7)(e),
   10:355, index 428); F8's declared non-fix is repeated wherever the mechanism is summarised; and the
   real-time cadence is explicitly variable and unmeasured (MEM-13(7)(g), 10:356, `learn/04`, `learn/10`).

**Noted, not a finding.** `spec/09`'s `HEARTBEAT_WINDOW` row says "the change alone cannot empty the
roster" in its incumbent-re-attestation sentence (line 213). In context it means "cannot permanently lock
out re-attestation", which is the R-INCR2-01 repair; but at face value it sits close to MEM-13(6)'s Open,
under which a change can catch every active entry and produce the all-ineligible append that
MEM-13(3)'s revert rule handles. A three-word qualification ("cannot permanently empty the roster")
would remove the ambiguity; I did not file it because the mechanism and the rule text are correct and the
Open is carried everywhere else.

## Ship decision

**No Critical and no High: the increment is clean at the convergence bar and safe to ship** from the
units/disclosure angle. INC2R2-UD-01 (a normative page and the T3 runbook text stating the repaired-away
window) is worth fixing before the announcement text is used; INC2R2-UD-02 is a register/record catch-up
that can ride with it. Both are text-only.
