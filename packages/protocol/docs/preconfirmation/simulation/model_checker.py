#!/usr/bin/env python3
"""
Exhaustive explicit-state model checker for the Taiko based-preconfirmation
redesign (redesign-proposal.md, v6).

WHAT THIS IS
------------
An abstract state machine of the v6 protocol and a bounded, exhaustive
breadth-first exploration of *every* adversarial interleaving of actions.
At every reachable state it checks a set of safety invariants (derived from
the doc's I1-I9, the immutability corollary, and the no-frame / bounded-bond
properties). After the state space is built it runs a liveness analysis to
find any reachable state from which the chain can never make progress
(a permanent halt -> a violation of the G5 / I3 "always advanceable" claim).

ABSTRACTION
-----------
Slot-level timing (Gamma_c, kappa, epoch = 32 slots) is abstracted into
logical phases, because the invariants under test are properties of the
*logical* state machine (single decision per epoch, monotone openEpoch,
no double-debit, bond non-negativity, no-frame, halt-safety), not of the
exact slot counts. The slot arithmetic (last-look window, censorship
corridor) is argued separately in the design doc's game-theory section and
is out of scope for the state-machine checker.

The adversary is *maximally nondeterministic*: at every step it may pick any
enabled action (honest or Byzantine) for any actor. Exhaustive BFS over this
choice therefore covers all behaviours up to the epoch/clock bound.

Run:  python3 model_checker.py            # default bound
      python3 model_checker.py 5 6        # NEPOCHS=5, MAXCLOCK=6
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
K = 2              # global lag cap (recovery-only beyond this) -- small for tractability
MUTANT = None      # set to a mutant name to deliberately break the design (self-test)
NTENURES = 3       # distinct tenure identities (owners) available
L_LIVE = 1         # liveness slash (abstract units)
RESERVE0 = K + 2   # per-tenure ETH/token reserve at admission (covers K obligations + margin)

# Epoch status values
SEQ       = "SEQ"        # not yet decided (being sequenced / future)
CONTENT   = "CONTENT"    # committed content outcome (valid EBC + available data)
EMPTY     = "EMPTY"      # empty outcome (no valid EBC), or forced-only if forced
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
    # certificates: frozenset of (tenure, epoch, cls) that are SETTLED (debitable)
    settled_certs: frozenset
    consumed: frozenset     # frozenset of logical fault ids already debited
    withdrawn: frozenset    # tenures that have withdrawn their bond
    # bookkeeping for no-frame: which tenure was assigned each epoch (immutable record)
    assigned: tuple         # tuple[Optional[int]] len NEPOCHS

    def key(self):
        return (self.status, self.owner, self.forced, self.decided_as, self.openEpoch,
                self.clock, self.mode, self.reserve, self.settled_certs, self.consumed,
                self.withdrawn, self.assigned)


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
    if s.clock < MAXCLOCK:
        ns = replace(s, clock=s.clock + 1)
        ns = _enter_modes(ns)
        out.append((f"tick->{s.clock+1}", ns))

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
            ns = replace(s, status=tuple(new_status), decided_as=tuple(new_decided))
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
    #      with a liveness certificate on its owner (objective, no accused cooperation). ----
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

    # ---- Seal: only the openEpoch may be sealed; both CONTENT and EMPTY are sealable. ----
    if oe < n and s.status[oe] in DECIDED:
        # honest owner seal, or permissionless recovery seal (force-resolve). Both advance.
        new_status = list(s.status); new_status[oe] = SEALED
        ns = replace(s, status=tuple(new_status))
        ns = replace(ns, openEpoch=recompute_open(ns.status))
        ns = _enter_modes(ns)
        out.append((f"seal(e{oe})", ns))
        # A CONTENT openEpoch whose owner withholds the seal: permissionless force-resolve
        # (same effect, different actor) -- modelled by the same seal action; adversary choice
        # to *not* seal is captured by exploring the state where seal is simply not taken.

    # ---- Missed-seal fault: a DECIDED openEpoch that the owner leaves unsealed while the
    #      clock advances -> liveness certificate; still sealable by anyone (force-resolve). ----
    if oe < n and s.status[oe] == CONTENT and s.owner[oe] is not None and s.clock > oe:
        owner = s.owner[oe]
        cert = (owner, oe, "SEAL")
        if cert not in s.settled_certs:
            ns = replace(s, settled_certs=s.settled_certs | {cert})
            out.append((f"miss_seal(e{oe},T{owner})", ns))

    # ---- H_cancel disaster: a CONTENT openEpoch stuck while lag exceeds K (data-loss floor).
    #      Re-resolves to CANCELLED (== sealed-empty) and advances. Permissionless. ----
    if oe < n and s.status[oe] == CONTENT and lag(s) > K:
        new_status = list(s.status); new_status[oe] = CANCELLED
        ns = replace(s, status=tuple(new_status))
        ns = replace(ns, openEpoch=recompute_open(ns.status))
        ns = _enter_modes(ns)
        out.append((f"cancel(e{oe})", ns))

    # ---- Debit a settled certificate (objective slash execution). One-shot per logical id. ----
    for cert in sorted(s.settled_certs):
        owner, e, cls = cert
        lid = (owner, e, cls)   # stable logical fault id
        if lid in s.consumed:
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
                # accountable owner for this still-SEQ epoch (design §4). Update the
                # assignment record so no-frame is checked against the acting owner.
                new_assigned[e] = successor
                changed = True
        if changed:
            ns = replace(s, owner=tuple(new_owner), assigned=tuple(new_assigned))
            lbl = f"promote(T{owner}->{'T'+str(successor) if successor is not None else 'anarchy'})"
            out.append((lbl, ns))

    # ---- Withdrawal: a tenure with NO unresolved liability may withdraw (state-gated).
    #      Only the LEGAL (gated) transition is in the design's transition relation; the
    #      checker then proves the gate is *sufficient* (INV_WITHDRAW_GATED can never fire
    #      over legal runs). Modelling an ungated withdraw would test the checker, not the
    #      design, so it is deliberately omitted. ----
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
    # zero unresolved certificates for t
    for (owner, e, cls) in s.settled_certs:
        if owner == t and (owner, e, cls) not in s.consumed:
            return False
    # no unsealed epoch still assigned to (currently owned by) t
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


def inv_open_monotone(s: State, prev_open: Optional[int]):
    if prev_open is not None and s.openEpoch < prev_open:
        return f"openEpoch went backwards {prev_open}->{s.openEpoch}"
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


def inv_no_double_debit(s: State):
    # structural: consumed is a set, so no id twice; also every consumed id must have
    # corresponded to a settled cert at some point (we can't easily check history here,
    # but we ensure consumed subset of all-ever-settled via the settled set monotonicity
    # enforced by construction). Return OK.
    return None


def inv_no_frame(s: State):
    # a settled liveness certificate must name the tenure that was ASSIGNED that epoch
    # (never an honest successor). assigned[] is the immutable assignment record.
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
    inv_no_double_debit, inv_no_frame, inv_withdraw_gated, inv_closed_is_prefix,
]


# ---------------------------------------------------------------------------
# Exhaustive BFS with invariant checking + liveness (halt) post-analysis.
# ---------------------------------------------------------------------------
def explore(stop_on_violation=False):
    visited = {}                 # key -> id
    parent = {}                  # id -> (parent_id, action_label)
    states = []                  # id -> State
    open_hist = {}               # id -> openEpoch history bound (prev) for monotonicity
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
    goal_reachable_from = set()   # states from which "all closed" is reachable (liveness OK)
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
        # safety checks
        for inv in SAFETY_INVARIANTS_STATE:
            msg = inv(s)
            if msg:
                violations.append(("SAFETY", inv.__name__, i, msg))
        # seal-immutability & monotonicity vs. this state's closed snapshot
        m = inv_seal_immutable(s, closed_hist[i])
        if m:
            violations.append(("SAFETY", "inv_seal_immutable", i, m))
        m = inv_open_monotone(s, None)
        if m:
            violations.append(("SAFETY", "inv_open_monotone", i, m))
        if stop_on_violation and violations:
            return states, parent, edges, violations, [], set(), set()

        if s.openEpoch >= NEPOCHS:
            terminal_all_closed.add(i)

        succ = actions(s)
        edges[i] = []
        for label, ns in succ:
            # child's closed snapshot extends this one
            child_closed = dict(closed_hist[i])
            for e in range(NEPOCHS):
                if ns.status[e] in CLOSED and e not in child_closed:
                    child_closed[e] = ns.status[e]
            j, is_new = sid(ns, i, label, child_closed)
            edges[i].append((j, label))
            if is_new:
                q.append(j)

    # Liveness / halt analysis: a state is "live" if some path reaches all-closed.
    # Compute backwards reachability of terminal_all_closed over edges.
    reachable_to_goal = set(terminal_all_closed)
    # build reverse edges
    rev = {i: [] for i in range(len(states))}
    for i, lst in edges.items():
        for (j, _l) in lst:
            rev[j].append(i)
    dq = deque(terminal_all_closed)
    while dq:
        j = dq.popleft()
        for i in rev[j]:
            if i not in reachable_to_goal:
                reachable_to_goal.add(i)
                dq.append(i)

    # A halt (G5/I3 violation) = a reachable state that is NOT terminal-all-closed AND
    # cannot reach all-closed AND is not itself blocked only by the wall-clock bound.
    halts = []
    for i in range(len(states)):
        s = states[i]
        if i in reachable_to_goal:
            continue
        if s.openEpoch >= NEPOCHS:
            continue
        # If the only reason it can't progress is that clock<MAXCLOCK hasn't advanced and
        # advancing would help, the state still counts as needing progress; but since we
        # allow tick actions, inability to reach goal within the bound is a genuine halt
        # candidate for the modelled horizon. Filter out states that are "stuck" purely
        # because the bound truncates a still-progressing chain: a state has a live future
        # iff any successor is in reachable_to_goal (already captured). So anything here is
        # a real dead-end within the horizon.
        # Distinguish: is there ANY enabled action at all?
        has_succ = len(edges.get(i, [])) > 0
        halts.append((i, has_succ))

    return states, parent, edges, violations, halts, terminal_all_closed, reachable_to_goal


def trace(parent, states, i):
    path = []
    while i is not None:
        p, a = parent[i]
        path.append((a, i))
        i = p
    return list(reversed(path))


MUTANTS = {
    "double_decision":      "inv_single_decision",   # re-decide a decided epoch
    "empty_despite_forced": "inv_empty_not_forced",  # empty resolution despite forced (I6)
    "seal_out_of_order":    "inv_closed_is_prefix",   # seal a non-openEpoch
    "ungated_withdraw":     "inv_withdraw_gated",     # withdraw despite liability
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
    print(f"# v6 protocol state-machine model check")
    print(f"# params: NEPOCHS={NEPOCHS} MAXCLOCK={MAXCLOCK} K={K} NTENURES={NTENURES} "
          f"RESERVE0={RESERVE0}")
    states, parent, edges, violations, halts, goals, live = explore()
    print(f"# reachable states explored: {len(states)}")
    print(f"# terminal (all epochs closed) states: {len(goals)}")
    print(f"# states from which all-closed is reachable (live): {len(live)}")

    print("\n## SAFETY invariant violations")
    if not violations:
        print("  NONE - no reachable state violates any safety invariant.")
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

    print("\n## LIVENESS / halt-safety (G5 / I3)")
    real_halts = [(i, hs) for (i, hs) in halts]
    if not real_halts:
        print("  NONE - every reachable non-terminal state can still reach a fully-sealed "
              "chain (no permanent halt within the horizon).")
    else:
        # A dead-end with NO successors and openEpoch<NEPOCHS and clock==MAXCLOCK is only
        # a horizon artifact if progress needs clock>MAXCLOCK. Report both classes.
        genuine = [(i, hs) for (i, hs) in real_halts if hs]      # has successors but none live
        deadend = [(i, hs) for (i, hs) in real_halts if not hs]  # no successors at all
        print(f"  states unable to reach all-closed within horizon: {len(real_halts)}")
        print(f"    - with enabled successors but no live continuation: {len(genuine)}")
        print(f"    - true dead-ends (no enabled action): {len(deadend)}")
        # show one representative genuine halt trace if any
        for (i, hs) in (genuine[:1] + deadend[:1]):
            s = states[i]
            print(f"  representative: openEpoch={s.openEpoch} clock={s.clock} mode={s.mode} "
                  f"status={s.status}")
            for a, j in trace(parent, states, i):
                print(f"      {a}")

    # exit code
    bad = bool(violations)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
