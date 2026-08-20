#!/usr/bin/env python3
"""
Exhaustive explicit-state model checker for the Taiko based-preconfirmation
redesign (redesign-proposal.md, v9).

WHAT THIS IS
------------
An abstract state machine of the v9 protocol and a bounded, exhaustive
breadth-first exploration of *every* adversarial interleaving of actions.
At every reachable state it checks a set of safety invariants (derived from
the doc's I1-I9, the immutability corollary, and the no-frame / bounded-bond
properties), and at every *transition* it checks a set of edge invariants
(monotone openEpoch, monotone evidence, debit conservation, read-time fault
materialization). After the state space is built it runs a liveness analysis
to find any reachable state from which the chain can never make progress
(a permanent halt -> a violation of the G5 / I3 "always advanceable" claim).
Halts fail the exit code just like safety violations do.

ABSTRACTION
-----------
Slot-level timing (Gamma_c, kappa, epoch = 32 slots) is abstracted into
logical phases, because the invariants under test are properties of the
*logical* state machine (single decision per epoch, monotone openEpoch,
no double-debit, bond non-negativity, no-frame, halt-safety), not of the
exact slot counts. The slot arithmetic (last-look window, censorship
corridor) is argued separately in the design doc's game-theory section and
is out of scope for the state-machine checker.

Two design rules that need care in the abstraction:

* I2 (read-time fault materialization): liveness faults are objective L1
  facts; certificates are *computed*, never dependent on a poke. The model
  therefore materializes the seal-fault certificate deterministically inside
  the `tick` action: an epoch that is the openEpoch, CONTENT-decided, owned,
  and survives a full tick unsealed has objectively missed its (tolled) seal
  deadline, and the certificate is settled at that moment and never erased.
  Deadlines *toll* while an epoch is blocked behind unsealed ancestors
  (design section 7.1): the certificate only ever arises from a tick spent as
  the openEpoch, so a backlogged descendant is never blamed for waiting.

* Section 6.7 cancellation cascade: when the openEpoch is cancelled at
  H_cancel, every committed-CONTENT, unsealed descendant chained to it is
  voided in the same deterministic cascade (its commitment referenced a
  parent lineage that no longer exists). VOID epochs close as CANCELLED, in
  openEpoch order, via a permissionless action. Forced snapshots of the
  cancelled/voided epochs re-queue at the front (the earliest still-SEQ
  epoch). A generation counter `gen` tracks lineage changes: every CONTENT
  commitment records the generation it was made against (`cgen`), and the
  invariant `content_current_gen` requires every live CONTENT commitment to
  be of the current generation -- a stale commitment surviving a cascade
  (the bug this models) is caught immediately.

Anarchy (unowned) epochs carry no discretionary content (design section 9;
the v7 atomic-anarchy action was removed again in v8 after the regression
audit found it re-opened round-2 finding 6's empty-front-running horn):
they resolve EMPTY or forced-only CONTENT like any unowned epoch.

* v9 proving-outage mode (round-7 finding 3): the adversary may start and
  end a PROVING OUTAGE at any time, any number of times -- and may simply
  never end it. While the outage is active, NO proof-carrying seal is
  possible (CONTENT seals are disabled); proof-free actions -- empty seals,
  void closures, and the disaster cancellation -- remain available, exactly
  as in the design (valid empty seals and cancellations are deterministic
  proof-free resolutions, I7). The liveness question the checker then
  answers is the one round 7 asked: even under an adversarially timed,
  possibly-permanent proving outage, can the chain always still reach full
  finalization? (Answer: yes -- the H_cancel floor is the designed exit.)
  Fault maturation is NOT paused during the modelled outage (the design's
  attested-freeze forgiveness, section 10.4 rung 3, is governance and out
  of model), which is the conservative direction: strictly more adversarial
  states are explored.

The adversary is *maximally nondeterministic*: at every step it may pick any
enabled action (honest or Byzantine) for any actor. Exhaustive BFS over this
choice therefore covers all behaviours up to the epoch/clock bound.

Run:  python3 model_checker.py            # default bound
      python3 model_checker.py 5 6        # NEPOCHS=5, MAXCLOCK=6
      python3 model_checker.py --mutate   # invariant self-test

Choose MAXCLOCK >= NEPOCHS-1: deciding epoch e requires clock >= e, so a
smaller horizon leaves the tail epoch undecidable and reports (artifact) halts.
Exit code is non-zero on any safety violation OR any halt.
"""

from __future__ import annotations
import sys
from collections import deque
from dataclasses import dataclass, replace
from typing import Optional

# ---------------------------------------------------------------------------
# Parameters of the abstract model (small by design; exhaustive within them).
# ---------------------------------------------------------------------------
NEPOCHS = 3        # number of epochs modelled (indices 0..NEPOCHS-1)
MAXCLOCK = 4       # wall-clock epochs the environment may advance to
K = 2              # global lag cap (recovery-only beyond this) -- design value 8, scaled
                   # down so recovery-only mode is reachable within tiny bounds; the
                   # recovery-exit threshold K' (design 4) scales to 0 here (_enter_modes)
CANCEL_LAG = 1     # lag at which the disaster cancellation becomes enabled. The design's
                   # H_cancel is a 10-day wall-clock horizon; the model deliberately
                   # collapses it to a small lag so the disaster lane is reachable within
                   # bounded horizons -- including CHAINS of cancellations (a permanent
                   # proving outage over an all-forced backlog cancels through one epoch
                   # per CANCEL_LAG+1 ticks, so the horizon must fit
                   # NEPOCHS*(CANCEL_LAG+1); with CANCEL_LAG=K=2 those chains overran
                   # MAXCLOCK and showed up as pure horizon artifacts in the
                   # outage-robust liveness pass). This OVER-approximates cancellation
                   # availability: safety-conservative (the cascade is exercised more,
                   # not less), and the real H_cancel delay is a timing parameter argued
                   # in the design doc, not checked here. Kept separate from K (round-6
                   # finding W3).
MUTANT = None      # set to a mutant name to deliberately break the design (self-test)
NTENURES = 3       # distinct tenure identities (owners) available
L_LIVE = 1         # liveness slash (abstract units)
RESERVE0 = K + 2   # per-tenure ETH/token reserve at admission (covers K obligations + margin)

# Epoch status values
SEQ       = "SEQ"        # not yet decided (being sequenced / future)
CONTENT   = "CONTENT"    # committed content outcome (valid EBC + available data)
EMPTY     = "EMPTY"      # empty outcome (no valid EBC), or forced-only if forced
VOID      = "VOID"       # commitment voided by an ancestor's cancellation cascade (6.7);
                         # closes as CANCELLED when it becomes the openEpoch
SEALED    = "SEALED"     # finalized by a proof-carrying (or empty) seal
CANCELLED = "CANCELLED"  # H_cancel disaster resolution (data lost) -> treated as sealed-empty

DECIDED = (CONTENT, EMPTY)
CLOSED  = (SEALED, CANCELLED)

# Modes
NORMAL, RECOVERY_ONLY, FROZEN = "NORMAL", "RECOVERY_ONLY", "FROZEN"


@dataclass(frozen=True)
class State:
    # per-epoch status and owner tenure (None == anarchy / unowned)
    status: tuple           # tuple[str] len NEPOCHS
    owner: tuple            # tuple[Optional[int]] len NEPOCHS
    forced: tuple           # tuple[bool] len NEPOCHS  -- forced snapshot non-empty?
    decided_as: tuple       # tuple[Optional[str]] the first decision recorded (to catch flips)
    openEpoch: int          # lowest index not in CLOSED (== NEPOCHS when all closed)
    clock: int              # wall-clock epoch (environment)
    mode: str
    # tenures: reserve remaining, and set of (epoch) obligations still open
    reserve: tuple          # tuple[int] len NTENURES
    # certificates: frozenset of (tenure, epoch, cls) that are SETTLED (debitable).
    # By I2 these are *computed* facts: materialized deterministically (tick/cancel/
    # miss_commit), sticky forever, never dependent on a poke.
    settled_certs: frozenset
    consumed: frozenset     # frozenset of logical fault ids already debited
    withdrawn: frozenset    # tenures that have withdrawn their bond
    # bookkeeping for no-frame: the ACTING assignment record -- which tenure currently
    # holds each epoch's duty. Updated only when a duty legitimately transfers
    # (promotion of still-SEQ epochs); the design's immutable tenure binding is the
    # original assignment, which the model does not need separately.
    assigned: tuple         # tuple[Optional[int]] len NEPOCHS
    # cancellation-cascade lineage (6.7): global generation, bumped at each cancel;
    # cgen[e] = generation a CONTENT commitment was made against (None if not committed)
    gen: int
    cgen: tuple             # tuple[Optional[int]] len NEPOCHS
    # v9: proving-outage flag (round-7 finding 3). While True, proof-carrying (CONTENT)
    # seals are impossible; proof-free resolutions remain available.
    outage: bool

    def key(self):
        return (self.status, self.owner, self.forced, self.decided_as, self.openEpoch,
                self.clock, self.mode, self.reserve, self.settled_certs, self.consumed,
                self.withdrawn, self.assigned, self.gen, self.cgen, self.outage)


def initial_states():
    """Curated-but-broad set of initial owner/forced configurations. Exhaustive BFS from
    each covers *all behaviours* of that configuration; the configurations are chosen to
    span every structurally-distinct scenario: single owner, handover, multi-handover,
    anarchy in each position, and forced-snapshot flags in each position (incl. all-forced
    and none-forced). This is the standard model-checking practice of exhaustive behaviour
    exploration from representative configs, and keeps the state space tractable while
    covering the safety-relevant structure."""
    import itertools
    inits = []
    # Owner scenarios (len NEPOCHS): who is assigned each epoch (None == anarchy).
    owner_scenarios = set()
    owner_scenarios.add(tuple(0 for _ in range(NEPOCHS)))                       # single owner
    owner_scenarios.add(tuple((0 if i == 0 else 1) for i in range(NEPOCHS)))    # handover at 1
    owner_scenarios.add(tuple(min(i, NTENURES - 1) for i in range(NEPOCHS)))    # step handover
    owner_scenarios.add(tuple(None for _ in range(NEPOCHS)))                    # full anarchy
    for pos in range(NEPOCHS):                                                  # anarchy at pos
        owner_scenarios.add(tuple((None if i == pos else 0) for i in range(NEPOCHS)))
    owner_scenarios.add(tuple((0 if i % 2 == 0 else 1) for i in range(NEPOCHS)))  # alternating
    # Forced-flag scenarios: none, all, and each single position, plus alternating.
    forced_scenarios = set()
    forced_scenarios.add(tuple(False for _ in range(NEPOCHS)))
    forced_scenarios.add(tuple(True for _ in range(NEPOCHS)))
    for pos in range(NEPOCHS):
        forced_scenarios.add(tuple((i == pos) for i in range(NEPOCHS)))
    forced_scenarios.add(tuple((i % 2 == 0) for i in range(NEPOCHS)))
    for owners, forced in itertools.product(sorted(owner_scenarios, key=str),
                                            sorted(forced_scenarios, key=str)):
        st = State(
            status=tuple(SEQ for _ in range(NEPOCHS)),
            owner=owners,
            forced=forced,
            decided_as=tuple(None for _ in range(NEPOCHS)),
            openEpoch=0,
            clock=0,
            mode=NORMAL,
            reserve=tuple(RESERVE0 for _ in range(NTENURES)),
            settled_certs=frozenset(),
            consumed=frozenset(),
            withdrawn=frozenset(),
            assigned=owners,
            gen=0,
            cgen=tuple(None for _ in range(NEPOCHS)),
            outage=False,
        )
        inits.append(st)
    return inits


def recompute_open(status):
    for i, s in enumerate(status):
        if s not in CLOSED:
            return i
    return len(status)


def lag(s: State) -> int:
    return max(0, s.clock - s.openEpoch)


def actions(s: State):
    """Yield (label, next_state) for every enabled action from s.
    Actions are Byzantine-inclusive: the adversary may choose any of them."""
    out = []
    n = NEPOCHS
    oe = s.openEpoch

    # ---- Environment: advance wall clock ----
    # I2 read-time materialization: a tick spent as a DECIDED, owned openEpoch without a
    # seal is an objectively missed (tolled) seal deadline -- the seat owes the seal for
    # BOTH outcomes (proof-carrying content seal, and the proof-free explicit-empty /
    # forced-only seal). The certificate is settled deterministically here -- it is a
    # computed L1 fact, not a poke -- and, being part of `settled_certs`, it is sticky: a
    # later seal cannot erase it, so the seal-then-withdraw bypass is structurally
    # impossible. Carve-out: an epoch that resolved EMPTY through a missed commit already
    # carries that owner's LIVENESS certificate; its closure is the recovery lane's job
    # (paid from the faulter), not a second distinct fault.
    if s.clock < MAXCLOCK:
        certs = s.settled_certs
        if oe < n and s.status[oe] in DECIDED and s.owner[oe] is not None \
                and (s.owner[oe], oe, "LIVENESS") not in s.settled_certs:
            if MUTANT != "no_materialize":
                certs = certs | {(s.owner[oe], oe, "SEAL")}
        ns = replace(s, clock=s.clock + 1, settled_certs=certs)
        ns = _enter_modes(ns)
        out.append((f"tick->{s.clock+1}", ns))

    # ---- Environment: proving outage (v9, round-7 finding 3). The adversary may start or
    #      end an outage at any time, any number of times -- or never end it. ----
    if not s.outage:
        out.append(("outage_start", replace(s, outage=True)))
    else:
        out.append(("outage_end", replace(s, outage=False)))

    # ---- Decision on an epoch that is still SEQ and is 'current' enough ----
    # An epoch may be decided once (single decision). We allow deciding any SEQ epoch
    # whose index <= clock (its boundary has passed) -- models the commit decision.
    for e in range(n):
        if s.status[e] != SEQ:
            continue
        if e > s.clock:
            continue
        # In RECOVERY_ONLY / FROZEN no *new content* may be committed: only EMPTY/forced-only.
        content_allowed = (s.mode == NORMAL)
        # If forced snapshot non-empty -> EMPTY is invalid (I6): must be CONTENT (forced-only).
        # Forced-only content is allowed even in recovery-only mode (it is not discretionary).
        options = []
        if s.forced[e]:
            options.append(CONTENT)  # forced-only content
        else:
            options.append(EMPTY)
            if content_allowed and s.owner[e] is not None:
                options.append(CONTENT)  # discretionary content, only if owned & normal mode
        if MUTANT == "empty_despite_forced" and s.forced[e] and EMPTY not in options:
            options = options + [EMPTY]   # BUG: allow empty despite forced snapshot (breaks I6)
        for dec in options:
            new_status = list(s.status); new_status[e] = dec
            new_decided = list(s.decided_as); new_decided[e] = dec
            new_cgen = list(s.cgen)
            if dec == CONTENT:
                new_cgen[e] = s.gen   # commitment is made against the current lineage (6.7)
            ns = replace(s, status=tuple(new_status), decided_as=tuple(new_decided),
                         cgen=tuple(new_cgen))
            out.append((f"decide(e{e}={dec}{'/forced' if s.forced[e] else ''})", ns))

    # MUTANT: re-decide an already-decided (not yet closed) epoch to the opposite outcome.
    if MUTANT == "double_decision":
        for e in range(n):
            if s.status[e] in DECIDED:
                flip = EMPTY if s.status[e] == CONTENT else CONTENT
                new_status = list(s.status); new_status[e] = flip
                ns = replace(s, status=tuple(new_status))  # decided_as keeps original -> flip
                out.append((f"REDECIDE(e{e}->{flip})", ns))

    # ---- Missed-commit fault: an owned SEQ epoch past its boundary resolves EMPTY
    #      with a liveness certificate on its owner (objective, no accused cooperation).
    #      The EMPTY resolution and the certificate are atomic (I2: the resolving read
    #      materializes the certificate). ----
    for e in range(n):
        if s.status[e] == SEQ and e <= s.clock and s.owner[e] is not None and not s.forced[e]:
            owner = s.owner[e]
            new_status = list(s.status); new_status[e] = EMPTY
            new_decided = list(s.decided_as); new_decided[e] = EMPTY
            cert = (owner, e, "LIVENESS")
            ns = replace(s, status=tuple(new_status), decided_as=tuple(new_decided),
                         settled_certs=s.settled_certs | {cert})
            out.append((f"miss_commit(e{e},T{owner})", ns))

    # MUTANT: seal a decided epoch that is NOT the openEpoch (out-of-order seal).
    if MUTANT == "seal_out_of_order":
        for e in range(n):
            if e != oe and s.status[e] in DECIDED:
                new_status = list(s.status); new_status[e] = SEALED
                ns = replace(s, status=tuple(new_status))
                ns = replace(ns, openEpoch=recompute_open(ns.status))
                out.append((f"SEAL_OOO(e{e})", ns))

    # ---- Seal: only the openEpoch may be sealed; both CONTENT and EMPTY are sealable.
    #      v9: a CONTENT seal is proof-carrying and therefore IMPOSSIBLE during a proving
    #      outage; the EMPTY seal is proof-free (I7) and stays available. ----
    if MUTANT == "outage_blocks_empty":
        sealable = not s.outage                                   # BUG: outage blocks everything
    else:
        sealable = (s.status[oe] == EMPTY) if (oe < n and s.outage) else True
    if oe < n and s.status[oe] in DECIDED and sealable:
        # honest owner seal, or permissionless recovery seal (force-resolve). Both advance.
        # A late seal does NOT erase a matured certificate: certs are sticky (I2).
        new_status = list(s.status); new_status[oe] = SEALED
        certs = s.settled_certs
        if MUTANT == "seal_erases_cert":
            certs = frozenset(c for c in certs if c[1] != oe)   # BUG: seal destroys evidence
        ns = replace(s, status=tuple(new_status), settled_certs=certs)
        ns = replace(ns, openEpoch=recompute_open(ns.status))
        ns = _enter_modes(ns)
        out.append((f"seal(e{oe})", ns))
        # The adversary's choice to *withhold* the seal is captured by exploring the state
        # where seal is simply not taken; the resulting missed deadline materializes a
        # certificate inside the next tick (see above).

    # ---- Close a voided openEpoch as CANCELLED (permissionless, always enabled):
    #      the deferred, in-order closure step of the 6.7 cascade. ----
    if oe < n and s.status[oe] == VOID:
        new_status = list(s.status); new_status[oe] = CANCELLED
        ns = replace(s, status=tuple(new_status))
        ns = replace(ns, openEpoch=recompute_open(ns.status))
        ns = _enter_modes(ns)
        out.append((f"close_void(e{oe})", ns))

    # ---- H_cancel disaster: a CONTENT openEpoch stuck while lag exceeds K (data-loss floor).
    #      Re-resolves to CANCELLED (== sealed-empty) and advances. Permissionless.
    #      Cascade (6.7): every committed-CONTENT unsealed descendant chained to it is
    #      voided in the same deterministic step (its commitment referenced a lineage that
    #      no longer exists); forced snapshots of all cancelled/voided epochs re-queue at
    #      the front (earliest still-SEQ epoch); the cancellation-causing tenure is charged
    #      (an additional CANCEL-class certificate, beyond any earlier SEAL cert). ----
    if oe < n and s.status[oe] == CONTENT and lag(s) > CANCEL_LAG:
        new_status = list(s.status); new_status[oe] = CANCELLED
        new_cgen = list(s.cgen)
        cascaded = []
        if MUTANT != "no_cascade":
            for e2 in range(oe + 1, n):
                if new_status[e2] == CONTENT:
                    new_status[e2] = VOID   # commitment voided; closes (in order) as CANCELLED
                    cascaded.append(e2)
        # forced re-queue: collect flags from the cancelled epoch and every voided epoch,
        # move them to the earliest epoch that is still SEQ (design: "re-queue at the
        # front", data intact). If no SEQ epoch remains inside the bounded horizon the
        # flags stay in place (documented horizon artifact; CANCELLED/VOID epochs are not
        # subject to I6, which constrains only EMPTY resolutions).
        new_forced = list(s.forced)
        carry = False
        for e2 in [oe] + cascaded:
            if new_forced[e2]:
                carry = True
        if carry:
            target = next((e2 for e2 in range(n) if new_status[e2] == SEQ), None)
            if target is not None:
                for e2 in [oe] + cascaded:
                    new_forced[e2] = False
                new_forced[target] = True
        certs = s.settled_certs
        if s.owner[oe] is not None:
            certs = certs | {(s.owner[oe], oe, "CANCEL")}   # charge the causing tenure (6.7)
        ns = replace(s, status=tuple(new_status), forced=tuple(new_forced),
                     settled_certs=certs, gen=s.gen + 1, cgen=tuple(new_cgen))
        ns = replace(ns, openEpoch=recompute_open(ns.status))
        ns = _enter_modes(ns)
        out.append((f"cancel(e{oe},cascade={len(cascaded)})", ns))

    # ---- Debit a settled certificate (objective slash execution). One-shot per logical id. ----
    for cert in sorted(s.settled_certs):
        owner, e, cls = cert
        lid = (owner, e, cls)   # stable logical fault id
        if lid in s.consumed:
            if MUTANT == "double_debit":
                # BUG: re-execute a consumed debit (reserve decremented again, no new id)
                new_res = list(s.reserve)
                new_res[owner] = max(0, new_res[owner] - L_LIVE)
                ns = replace(s, reserve=tuple(new_res))
                out.append((f"REDEBIT({cls},T{owner},e{e})", ns))
            continue
        if owner in s.withdrawn:
            # withdrawn tenures have no reserve to debit; skip (should be impossible if gated)
            continue
        amt = L_LIVE
        new_res = list(s.reserve)
        new_res[owner] = max(0, new_res[owner] - amt)   # never negative
        ns = replace(s, reserve=tuple(new_res), consumed=s.consumed | {lid})
        out.append((f"debit({cls},T{owner},e{e})", ns))

    # ---- Auction: promote a standby / drop to anarchy when a tenure terminates. ----
    #      Model: a tenure with a settled cert may be terminated; its still-SEQ owned epochs
    #      become owned by another available tenure, or anarchy if none. ----
    terminating = sorted({owner for (owner, e, cls) in s.settled_certs})
    for owner in terminating:
        successor = _pick_successor(s, owner)
        new_owner = list(s.owner)
        new_assigned = list(s.assigned)
        changed = False
        for e in range(n):
            if new_owner[e] == owner and s.status[e] == SEQ:
                new_owner[e] = successor
                # The duty legitimately transfers: the successor becomes the acting,
                # accountable owner for this still-SEQ epoch (design section 4). Update the
                # assignment record so no-frame is checked against the acting owner.
                new_assigned[e] = successor
                changed = True
        if changed:
            ns = replace(s, owner=tuple(new_owner), assigned=tuple(new_assigned))
            lbl = f"promote(T{owner}->{'T'+str(successor) if successor is not None else 'anarchy'})"
            out.append((lbl, ns))

    # ---- Withdrawal: a tenure with NO unresolved liability may withdraw (state-gated).
    #      I2: the gate reads the *computed matured set* -- and because certificates are
    #      materialized deterministically (tick/cancel/miss_commit) and sticky, the
    #      settled_certs set IS the matured set here; a matured-but-undebited fault or an
    #      unsealed owned epoch closes the gate. Only the LEGAL (gated) transition is in
    #      the design's transition relation; the checker then proves the gate is
    #      *sufficient* (INV_WITHDRAW_GATED can never fire over legal runs). ----
    for t in range(NTENURES):
        if t in s.withdrawn:
            continue
        gate = _withdraw_gate_open(s, t)
        if MUTANT == "ungated_withdraw":
            gate = True   # BUG: ignore the state-gate entirely
        if gate:
            lbl = "withdraw" if _withdraw_gate_open(s, t) else "UNGATED_withdraw"
            ns = replace(s, withdrawn=s.withdrawn | {t})
            out.append((f"{lbl}(T{t})", ns))

    return out


def _pick_successor(s: State, terminating_owner: int) -> Optional[int]:
    # highest available standby not itself terminating/withdrawn, else anarchy
    bad = {owner for (owner, e, cls) in s.settled_certs} | set(s.withdrawn)
    for t in range(NTENURES):
        if t != terminating_owner and t not in bad:
            return t
    return None  # anarchy


def _withdraw_gate_open(s: State, t: int) -> bool:
    # zero unresolved certificates for t (settled_certs is the computed matured set -- I2)
    for (owner, e, cls) in s.settled_certs:
        if owner == t and (owner, e, cls) not in s.consumed:
            return False
    # no unsealed epoch still assigned to (currently owned by) t -- VOID included
    for e in range(NEPOCHS):
        if s.owner[e] == t and s.status[e] not in CLOSED:
            return False
    return True


def _enter_modes(s: State) -> State:
    # global lag cap -> recovery-only; recovery clears when lag <= K' (== 0 here, all sealed-ish)
    if s.mode == FROZEN:
        return s
    if lag(s) > K and s.mode == NORMAL:
        return replace(s, mode=RECOVERY_ONLY)
    if s.mode == RECOVERY_ONLY and lag(s) == 0:
        return replace(s, mode=NORMAL)
    return s


# ---------------------------------------------------------------------------
# Invariants (safety). Each returns None if OK, else a short violation string.
# ---------------------------------------------------------------------------
def inv_single_decision(s: State):
    for e in range(NEPOCHS):
        d = s.decided_as[e]
        st = s.status[e]
        if d is not None and st == SEQ:
            return f"epoch {e} recorded decision {d} but status is SEQ"
        # a decided epoch's recorded decision must match its (pre-seal) outcome lineage
        if st in DECIDED and d is not None and st != d:
            return f"epoch {e} status {st} != recorded decision {d} (flip)"
    return None


def inv_seal_immutable(s: State, hist_closed: dict):
    # once an epoch is SEALED/CANCELLED it must never change status thereafter.
    for e in range(NEPOCHS):
        if e in hist_closed and s.status[e] not in CLOSED:
            return f"epoch {e} was {hist_closed[e]} then reverted to {s.status[e]}"
        if e in hist_closed and s.status[e] != hist_closed[e]:
            # allow SEALED==CANCELLED equivalence? No: both are terminal & distinct records.
            return f"epoch {e} closed as {hist_closed[e]} then changed to {s.status[e]}"
    return None


def inv_open_monotone(s: State):
    # state-level consistency: openEpoch always equals the lowest non-closed epoch.
    # (Monotonicity across transitions is checked by the EDGE invariant below.)
    if s.openEpoch != recompute_open(s.status):
        return f"openEpoch {s.openEpoch} != recomputed {recompute_open(s.status)}"
    return None


def inv_closed_is_prefix(s: State):
    # Seals/cancels happen strictly in openEpoch order, so the CLOSED epochs must form a
    # prefix 0..openEpoch-1: there is never a closed epoch sitting above an open one.
    seen_open = False
    for e in range(NEPOCHS):
        if s.status[e] not in CLOSED:
            seen_open = True
        elif seen_open:
            return f"epoch {e} is {s.status[e]} above an unsealed lower epoch (out-of-order seal)"
    return None


def inv_empty_not_forced(s: State):
    # I6: an epoch may not resolve EMPTY while its forced snapshot is non-empty.
    for e in range(NEPOCHS):
        if s.forced[e] and s.status[e] == EMPTY:
            return f"epoch {e} resolved EMPTY despite non-empty forced snapshot (I6)"
    return None


def inv_bond_nonneg(s: State):
    for t in range(NTENURES):
        if s.reserve[t] < 0:
            return f"tenure {t} reserve negative {s.reserve[t]}"
    return None


def inv_content_current_gen(s: State):
    # 6.7 cascade correctness: every live CONTENT commitment must be of the current
    # lineage generation -- a commitment made before an ancestor's cancellation must have
    # been voided by the cascade, never left CONTENT (and hence sealable).
    for e in range(NEPOCHS):
        if s.status[e] == CONTENT:
            if s.cgen[e] != s.gen:
                return (f"epoch {e} CONTENT of stale generation {s.cgen[e]} "
                        f"(current {s.gen}): cascade failed to void it")
        if s.status[e] == VOID and s.cgen[e] is None:
            return f"epoch {e} VOID but never committed (bookkeeping)"
    return None


def inv_no_frame(s: State):
    # a settled certificate must name the tenure that was ASSIGNED that epoch
    # (never an honest successor). assigned[] is the acting assignment record.
    for (owner, e, cls) in s.settled_certs:
        if s.assigned[e] is not None and owner != s.assigned[e]:
            return f"cert blames T{owner} for epoch {e} assigned to T{s.assigned[e]} (frame)"
    return None


def inv_withdraw_gated(s: State):
    # no withdrawn tenure may still carry residual liability.
    for t in s.withdrawn:
        for (owner, e, cls) in s.settled_certs:
            if owner == t and (owner, e, cls) not in s.consumed:
                return f"tenure {t} withdrew with unresolved cert {(owner,e,cls)}"
        for e in range(NEPOCHS):
            if s.owner[e] == t and s.status[e] not in CLOSED:
                return f"tenure {t} withdrew with unsealed owned epoch {e}"
    return None


SAFETY_INVARIANTS_STATE = [
    inv_single_decision, inv_empty_not_forced, inv_bond_nonneg,
    inv_content_current_gen, inv_no_frame, inv_withdraw_gated, inv_closed_is_prefix,
    inv_open_monotone,
]


# ---------------------------------------------------------------------------
# Edge (transition) invariants: checked on every (state, action, successor).
# ---------------------------------------------------------------------------
def edge_open_monotone(s: State, ns: State, label: str):
    # I3: openEpoch never decreases across any transition.
    if ns.openEpoch < s.openEpoch:
        return f"openEpoch went backwards {s.openEpoch}->{ns.openEpoch} on {label}"
    return None


def edge_evidence_monotone(s: State, ns: State, label: str):
    # I2: certificates are computed L1 facts -- once settled they can never disappear
    # (a seal or any other action must not erase evidence), and a consumed (debited)
    # fault id can never be un-consumed.
    if not ns.settled_certs >= s.settled_certs:
        gone = s.settled_certs - ns.settled_certs
        return f"evidence erased on {label}: {sorted(gone)}"
    if not ns.consumed >= s.consumed:
        return f"consumed set shrank on {label}"
    return None


def edge_debit_conservation(s: State, ns: State, label: str):
    # I2/section 8: a reserve may only decrease by consuming exactly one FRESH logical
    # fault id (one-shot debit); no transition may decrement a reserve twice for the
    # same id or without an id.
    decreased = [t for t in range(NTENURES) if ns.reserve[t] < s.reserve[t]]
    if not decreased:
        return None
    newly = ns.consumed - s.consumed
    if len(decreased) > 1:
        return f"multiple reserves decreased in one step on {label}"
    if len(newly) != 1:
        return (f"reserve of T{decreased[0]} decreased without exactly one freshly "
                f"consumed fault id on {label} (double debit)")
    (owner, e, cls) = next(iter(newly))
    if owner != decreased[0]:
        return f"debit of T{decreased[0]} consumed an id belonging to T{owner} on {label}"
    if (owner, e, cls) in s.consumed:
        return f"fault id {(owner, e, cls)} consumed twice on {label}"
    return None


def edge_maturity_materialized(s: State, ns: State, label: str):
    # I2 as a transition property: a tick spent as a DECIDED (content OR explicit-empty),
    # owned openEpoch must materialize that owner's SEAL certificate in the successor
    # state (unless the epoch already carries the owner's miss-commit LIVENESS cert).
    if not label.startswith("tick"):
        return None
    oe = s.openEpoch
    if oe < NEPOCHS and s.status[oe] in DECIDED and s.owner[oe] is not None \
            and (s.owner[oe], oe, "LIVENESS") not in s.settled_certs:
        if (s.owner[oe], oe, "SEAL") not in ns.settled_certs:
            return (f"missed seal deadline of e{oe} (T{s.owner[oe]}) not materialized "
                    f"on {label}")
    return None


EDGE_INVARIANTS = [
    edge_open_monotone, edge_evidence_monotone, edge_debit_conservation,
    edge_maturity_materialized,
]


# ---------------------------------------------------------------------------
# Exhaustive BFS with invariant checking + liveness (halt) post-analysis.
# ---------------------------------------------------------------------------
def explore(stop_on_violation=False):
    visited = {}                 # key -> id
    parent = {}                  # id -> (parent_id, action_label)
    states = []                  # id -> State
    closed_hist = {}             # id -> dict(epoch->closed status) snapshot
    violations = []

    def sid(st, prev_id, action, closed_snapshot):
        k = st.key()
        if k in visited:
            return visited[k], False
        i = len(states)
        visited[k] = i
        states.append(st)
        parent[i] = (prev_id, action)
        closed_hist[i] = closed_snapshot
        return i, True

    q = deque()
    seen_init = set()
    for st in initial_states():
        k = st.key()
        if k in seen_init:
            continue
        seen_init.add(k)
        closed_snap = {e: st.status[e] for e in range(NEPOCHS) if st.status[e] in CLOSED}
        i, is_new = sid(st, None, "INIT", closed_snap)
        if is_new:
            q.append(i)

    # BFS
    edges = {}                    # id -> list[(child_id, label)]
    terminal_all_closed = set()
    STATE_CAP = 4_000_000
    processed = 0

    while q:
        i = q.popleft()
        processed += 1
        if processed % 200000 == 0:
            print(f"#   ... processed={processed} discovered={len(states)} queue={len(q)}",
                  file=sys.stderr)
        if len(states) > STATE_CAP:
            print(f"# STATE CAP {STATE_CAP} hit; exploration truncated (increase cap or "
                  f"shrink bound).", file=sys.stderr)
            break
        s = states[i]
        # safety checks (state invariants)
        for inv in SAFETY_INVARIANTS_STATE:
            msg = inv(s)
            if msg:
                violations.append(("SAFETY", inv.__name__, i, msg))
        # seal-immutability vs. this state's closed snapshot
        m = inv_seal_immutable(s, closed_hist[i])
        if m:
            violations.append(("SAFETY", "inv_seal_immutable", i, m))
        if stop_on_violation and violations:
            return states, parent, edges, violations, [], set(), set()

        if s.openEpoch >= NEPOCHS:
            terminal_all_closed.add(i)

        succ = actions(s)
        edges[i] = []
        for label, ns in succ:
            # edge (transition) invariants
            for einv in EDGE_INVARIANTS:
                msg = einv(s, ns, label)
                if msg:
                    violations.append(("SAFETY", einv.__name__, i, msg))
            # child's closed snapshot extends this one
            child_closed = dict(closed_hist[i])
            for e in range(NEPOCHS):
                if ns.status[e] in CLOSED and e not in child_closed:
                    child_closed[e] = ns.status[e]
            j, is_new = sid(ns, i, label, child_closed)
            edges[i].append((j, label))
            if is_new:
                q.append(j)
        if stop_on_violation and violations:
            return states, parent, edges, violations, [], set(), set()

    # Liveness / halt analysis, two passes (v9):
    #
    # (1) STANDARD: a state is "live" if some path reaches all-closed.
    # (2) OUTAGE-ROBUST (round-7 finding 3): the same, over the sub-relation that
    #     EXCLUDES `outage_end` -- i.e. the goal must be reachable even if an active
    #     proving outage never lifts. Without this pass, an exists-path analysis could
    #     always "un-outage" its way to the goal, making the outage model vacuous:
    #     the design's proof-free floor (empty seals, void closure, cancellation) is
    #     exactly what this pass verifies.
    def _backward(exclude_label=None):
        rev = {i: [] for i in range(len(states))}
        for i, lst in edges.items():
            for (j, lbl) in lst:
                if exclude_label is not None and lbl == exclude_label:
                    continue
                rev[j].append(i)
        reach = set(terminal_all_closed)
        dq = deque(terminal_all_closed)
        while dq:
            j = dq.popleft()
            for i in rev[j]:
                if i not in reach:
                    reach.add(i)
                    dq.append(i)
        return reach

    reachable_to_goal = _backward()
    robust_to_goal = _backward(exclude_label="outage_end")

    # A halt (G5/I3 violation) = a reachable, non-terminal state that cannot reach
    # all-closed -- in the standard relation, or (strictly stronger) in the
    # never-un-outage relation. With MAXCLOCK >= NEPOCHS-1 these are genuine halt
    # candidates; with a smaller horizon they may be bound artifacts -- main() warns.
    halts = []
    for i in range(len(states)):
        s = states[i]
        if s.openEpoch >= NEPOCHS:
            continue
        if i in reachable_to_goal and i in robust_to_goal:
            continue
        kind = "standard" if i not in reachable_to_goal else "outage-robust"
        halts.append((i, len(edges.get(i, [])) > 0, kind))

    return states, parent, edges, violations, halts, terminal_all_closed, reachable_to_goal


def trace(parent, states, i):
    path = []
    while i is not None:
        p, a = parent[i]
        path.append((a, i))
        i = p
    return list(reversed(path))


MUTANTS = {
    "double_decision":      "inv_single_decision",        # re-decide a decided epoch
    "empty_despite_forced": "inv_empty_not_forced",       # empty resolution despite forced (I6)
    "seal_out_of_order":    "inv_closed_is_prefix",       # seal a non-openEpoch
    "ungated_withdraw":     "inv_withdraw_gated",         # withdraw despite liability
    "no_cascade":           "inv_content_current_gen",    # cancel fails to void descendants (6.7)
    "double_debit":         "edge_debit_conservation",    # re-execute a consumed debit
    "seal_erases_cert":     "edge_evidence_monotone",     # seal destroys matured evidence (I2)
    "no_materialize":       "edge_maturity_materialized", # missed deadline never computed (I2)
    # v9: a liveness mutant -- if an outage wrongly blocked proof-FREE resolutions too,
    # a permanent outage would be a permanent halt; the halt analysis must catch it.
    "outage_blocks_empty":  "LIVENESS_HALT",
}


def run_mutation_tests():
    """Self-test: each mutant deliberately breaks the design; the checker MUST catch it.
    Runs at a tiny bound for speed."""
    global MUTANT, NEPOCHS, MAXCLOCK
    NEPOCHS, MAXCLOCK = 3, 3
    print("# MUTATION SELF-TEST (each injected bug MUST be caught by the named invariant)")
    all_caught = True
    for mut, expected_inv in MUTANTS.items():
        MUTANT = mut
        if expected_inv == "LIVENESS_HALT":
            # liveness mutant: the bug manifests as a permanent halt, so run the full
            # exploration (no early exit) and require the halt analysis to fire.
            _, _, _, _violations, halts, _, _ = explore()
            ok = bool(halts)
            all_caught &= ok
            status = "CAUGHT" if ok else "!! MISSED !!"
            print(f"  mutant '{mut}' -> expect a permanent halt: {status} "
                  f"({len(halts)} halt state(s) found)")
            continue
        _, _, _, violations, _, _, _ = explore(stop_on_violation=True)
        caught = {name for (_k, name, _i, _m) in violations}
        ok = expected_inv in caught
        all_caught &= ok
        status = "CAUGHT" if ok else "!! MISSED !!"
        print(f"  mutant '{mut}' -> expect {expected_inv}: {status} "
              f"(invariants tripped: {sorted(caught) or 'none'})")
    MUTANT = None
    print(f"# mutation self-test: {'ALL BUGS CAUGHT (invariants have teeth)' if all_caught else 'SOME MISSED'}")
    return all_caught


def main():
    global NEPOCHS, MAXCLOCK
    if len(sys.argv) >= 2 and sys.argv[1] == "--mutate":
        return 0 if run_mutation_tests() else 1
    if len(sys.argv) >= 3:
        NEPOCHS = int(sys.argv[1]); MAXCLOCK = int(sys.argv[2])
    print(f"# v9 protocol state-machine model check")
    print(f"# params: NEPOCHS={NEPOCHS} MAXCLOCK={MAXCLOCK} K={K} NTENURES={NTENURES} "
          f"RESERVE0={RESERVE0}")
    if MAXCLOCK < NEPOCHS - 1:
        print(f"# WARNING: MAXCLOCK ({MAXCLOCK}) < NEPOCHS-1 ({NEPOCHS - 1}): tail epochs "
              f"are undecidable within the horizon, so reported halts will include bound "
              f"artifacts. Use MAXCLOCK >= NEPOCHS-1 for meaningful liveness results.")
    states, parent, edges, violations, halts, goals, live = explore()
    print(f"# reachable states explored: {len(states)}")
    print(f"# terminal (all epochs closed) states: {len(goals)}")
    print(f"# states from which all-closed is reachable (live): {len(live)}")

    print("\n## SAFETY invariant violations (state + edge)")
    if not violations:
        print("  NONE - no reachable state or transition violates any safety invariant.")
    else:
        # de-dup by (invariant, msg-shape)
        seen = set()
        for kind, name, i, msg in violations:
            sig = (name, msg.split("(")[0][:40])
            if sig in seen:
                continue
            seen.add(sig)
            print(f"  [{name}] {msg}")
            for a, j in trace(parent, states, i):
                print(f"      {a}")
        print(f"  total raw violations: {len(violations)} (distinct shapes: {len(seen)})")

    print("\n## LIVENESS / halt-safety (G5 / I3) — standard AND outage-robust")
    if not halts:
        print("  NONE - every reachable non-terminal state can still reach a fully-sealed "
              "chain, and can do so even if an active proving outage never lifts.")
    else:
        std = [h for h in halts if h[2] == "standard"]
        rob = [h for h in halts if h[2] == "outage-robust"]
        deadend = [h for h in halts if not h[1]]
        print(f"  states unable to reach all-closed within horizon: {len(halts)}")
        print(f"    - standard (no path at all): {len(std)}")
        print(f"    - outage-robust only (every path needs the outage to lift): {len(rob)}")
        print(f"    - true dead-ends (no enabled action): {len(deadend)}")
        for (i, hs, kind) in halts[:2]:
            s = states[i]
            print(f"  representative ({kind}): openEpoch={s.openEpoch} clock={s.clock} "
                  f"mode={s.mode} outage={s.outage} status={s.status}")
            for a, j in trace(parent, states, i):
                print(f"      {a}")

    # exit code: halts fail the run exactly like safety violations do (G5/I3 is a
    # headline property; automation must not treat a halting model as passing).
    bad = bool(violations) or bool(halts)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
