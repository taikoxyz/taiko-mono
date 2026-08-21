#!/usr/bin/env python3
"""
Exhaustive explicit-state model checker for the Taiko based-preconfirmation
redesign (redesign-proposal.md, v10 D1-D7 checker-validity upgrade + v11
anarchy proposal phase).

WHAT THIS IS
------------
An abstract state machine of the v10/v11 protocol and a bounded, exhaustive
breadth-first exploration of *every* adversarial interleaving of actions.
At every reachable state it checks a set of safety invariants (derived from
the doc's I1-I9, the immutability corollary, and the no-frame / bounded-bond
properties), and at every *transition* it checks a set of edge invariants
(monotone openEpoch, monotone evidence, debit conservation, read-time fault
materialization, decision deadline, typed seals, expiry cutoff, equivocation
settlement, anarchy-phase empty/proposal cutoffs). After the state space is
built it runs a liveness analysis
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

Design rules that need care in the abstraction:

* v10 decision deadline (round-9 finding D1/B5): the design has exactly ONE
  finality decision per epoch, fixed irreversibly at D+kappa = T_N + E +
  Gamma_c + kappa (~7 slots into the successor's epoch; sections 3, 3.1).
  Earlier checker versions left `decide`/`miss_commit` un-deadlined -- an
  epoch could linger undecided to the horizon, a relation the protocol does
  not contain. The model now maps the decision instant into its coarse
  clock as a WINDOW: epoch e is decidable only while clock <= e + 1 (the
  D+kappa instant falls a fraction into wall-clock epoch e+1, so the tick
  from e+1 to e+2 is the first clock event strictly after the outcome is
  fixed; deciding at clock e or e+1 preserves every handover interleaving
  the un-deadlined model reached). When a tick moves the clock past an
  undecided epoch's window the epoch AUTO-RESOLVES inside that tick --
  EMPTY (or the deterministic forced-only CONTENT when its forced snapshot
  is non-empty, per I6: empty is then invalid) -- and, if owned, the
  owner's LIVENESS certificate settles atomically (I2: the resolving read
  materializes the certificate; this is "parent outcome fixed at D+kappa",
  the design's single-decision rule). No decide action may fire past the
  window; `edge_decision_deadline` checks both directions on every edge.

* I2 (read-time fault materialization): liveness faults are objective L1
  facts; certificates are *computed*, never dependent on a poke. The model
  materializes the seal-fault certificate deterministically inside the
  `tick` action: an epoch that is the openEpoch, DECIDED, owned, and has
  spent S_TICKS tolled ticks unsealed has objectively missed its (tolled)
  seal deadline, and the certificate is settled at that moment and never
  erased. S_TICKS (round-9 finding D5) parameterizes the deadline: default
  1 tick (conservative -- the deadline matures at the first opportunity, so
  every late-seal/withdraw ordering is explored at the smallest bound);
  S_TICKS=2 is supported via --sticks to check the semantics are not an
  artifact of the 1-tick collapse. Deadlines *toll* while an epoch is
  blocked behind ancestors whose resolution has real latency (design
  section 7.1 / I4): the per-epoch `openAge` counter advances only while
  the epoch is DECIDED and *effectively open* -- every ancestor is closed
  or is a VOID/EMPTY epoch whose closure is one of I7's deterministic,
  zero-latency proof-free resolutions. A backlogged descendant is never
  blamed while a CONTENT ancestor (a genuine proving/expiry latency) is
  unsealed; a prefix of proof-free closures, clearable by anyone in the
  same L1 block, is not a genuine block -- under the strict "only as the
  openEpoch" reading an adversary could defer every descendant deadline
  forever by declining a free permissionless transaction (the round-8 W1
  unfair-scheduler residual, resolved by weak fairness at the protocol
  layer), which in a bounded model would manufacture liveness artifacts at
  every horizon.

* Section 6.7 expiry cancellation, v10 mechanical cutoff (round-9 findings
  F2/B4, checker finding B5): each decided epoch has its own expiry T_exp =
  decision-final + H_cancel on the TOLLED clock. The model tracks a
  per-epoch tolled open-age (`openAge[e]` = ticks spent DECIDED, unsealed
  and effectively open, per the tolling rule above) and enables
  cancellation of the openEpoch only when its own openAge exceeds
  CANCEL_LAG -- replacing the earlier global-lag enablement, which let one
  epoch's backlog age a different epoch into cancellability (not a
  property of per-epoch T_exp). The v10 no-overlap
  rule is enforced: seals are valid strictly before T_exp, cancellation at
  and after it -- once openAge[e] > CANCEL_LAG the proof-carrying seal for
  e is DISABLED, so no L1 ordering race between seal and cancel exists
  (`edge_no_seal_after_expiry`). CANCEL_LAG deliberately collapses the
  10-day H_cancel to 1 tolled tick so the disaster lane -- including CHAINS
  of per-epoch expiries under a permanent proving outage -- is reachable in
  tiny bounds. Because expiry is per-epoch and tolled, a chain consumes
  CANCEL_LAG+1 fresh ticks per cancelled epoch (the model-scale image of
  the design's honest "one cascade per H_cancel" cadence, r9-A4), so
  liveness-meaningful horizons need MAXCLOCK >= NEPOCHS*CANCEL_LAG + 3
  (main() warns below that).

* Section 6.7 cancellation cascade with an ORDERED forced queue (round-9
  finding D3): forced work is no longer a per-epoch boolean but ordered
  item identities (one per originally-forced epoch; id = the epoch it was
  originally due in, so ascending id == original queue order). A cancel
  voids every committed-CONTENT unsealed descendant and re-queues the
  cancelled/voided epochs' live items to the earliest still-SEQ epoch
  PRESERVING original queue order (design 6.7 / r4b-M8: "re-queued
  snapshots preserve original queue order"); `inv_forced_order` checks the
  global live queue stays in original order and no closed/voided epoch
  retains a live item. Items reach exactly one terminal state -- consumed
  by their epoch's proof-carrying seal, or REFUNDED (design 6.4: expired
  snapshots void with fees refundable; modeled explicitly, round-9 B5)
  when a cancellation finds no still-SEQ epoch inside the bound to re-queue
  into. The liveness goal now requires every forced item terminal, not
  merely all epochs closed -- the old "flags stranded on cancelled epochs"
  horizon artifact is gone, replaced by the modeled refund.

* v10 EBC one-shot + L1-direct equivocation (round-9 finding D4; design
  3.1, 5.1, 8): a decide by an owned seat consumes that (tenure, epoch)'s
  commit one-shot (`committed[e]` records the consumer). The adversary
  action `equivocate` models a SECOND DISTINCT accepted commit artifact,
  possible only while the acceptance window is open (same clock window as
  the decision; after D+kappa the artifact set is closed, 3.1). Per the
  one-shot rule the decision NEVER changes (first accepted artifact wins);
  the action atomically settles an L1-direct SAFETY certificate against
  the tenure (design 8 variant (a): double-EBC equivocation needs no L2
  adjudication, zero latency) and terminates the tenure -- its still-SEQ
  epochs promote to a successor or drop to anarchy exactly as for other
  terminations. `single_decision` (no flip), `edge_evidence_monotone`
  (sticky evidence) and the new `edge_equivocation_settles` (certificate +
  termination are atomic) check the three design claims.

* v11 anarchy proposal phase (design section 9, round 10): unowned epochs
  carry discretionary content again, via a TWO-SIDED mechanical cutoff that
  closes BOTH horns of round-2 finding 6 (the v7 one-sided restoration was
  reverted in v8 for re-opening the empty-front-running horn). `anarchy_propose`
  lets ANY actor seal an unowned openEpoch with content in ONE atomic step
  (propose == seal == finality; horn 1 -- unproven content never locks state,
  and unowned discretionary content never exists unsealed, checked by
  `inv_anarchy_content_sealed`). It is proof-carrying (impossible during a
  proving outage) and discretionary (disabled in recovery-only mode, I5). The
  proposal is valid STRICTLY BEFORE the epoch's cutoff (`_anarchy_cutoff`:
  min(e + W_ANARCHY, first owned epoch after e), collapsed while recovery-only
  mode is active); the unowned epoch's proof-free EMPTY resolution is valid
  AT/AFTER the cutoff (horn 2 -- a cheap empty never front-runs the protected
  proposal window). The two sides are path-independent edge invariants
  (`edge_empty_respects_phase`, `edge_proposal_respects_phase`), and the
  ownership truncation term models design rule 9.1-2/9.1-5 (an owned successor
  must never sequence on an undetermined parent). Forced-only CONTENT for
  unowned epochs stays enabled in BOTH regimes (I6 cadence untouched). Composed
  onto the r9-D1 decision deadline: because the anarchy proposal is born SEALED
  (adapted to v10's typed seals -- it consumes the forced snapshot into
  fconsumed and clears the closed epoch's per-epoch bookkeeping, exactly like
  seal_content), and because for W_ANARCHY <= 2 the cutoff never exceeds e+2
  (the window-closing tick's auto-resolution clock), a window-close EMPTY
  auto-resolve always lands at/after the cutoff and proposals only ever fire at
  clock e or e+1 (inside the decision window). W_ANARCHY = 0 disables the lane
  and recovers the pre-anarchy v10 model BIT-FOR-BIT (a checked property).

* v9 proving-outage mode (round-7 finding 3): the adversary may start and
  end a PROVING OUTAGE at any time, any number of times -- and may simply
  never end it. While the outage is active, NO proof-carrying seal is
  possible -- and v10 types the seals (round-9 finding D2): `seal_content`
  is the proof-carrying closure of a CONTENT-decided epoch (discretionary
  AND forced-only: per I7/section 10.4 guarantee 2, forced-only seals are
  proof-carrying, so a proving outage stops forced execution too -- forced
  items then exit through cancellation re-queue and finally the refund
  path), while `seal_empty` is the proof-free closure of an EMPTY-decided
  epoch (I7's deterministic resolution) and stays available during the
  outage, as do void closures and the expiry cancellation. `edge_typed_seal`
  checks that a proof-free-typed closure never closes a CONTENT-decided
  epoch (I1: the content outcome exists only through its proof). The
  liveness question the checker answers is round 7's: even under an
  adversarially timed, possibly-permanent proving outage, can the chain
  always still reach full finalization -- now including every forced item
  reaching a terminal state? (Answer: yes -- the expiry floor plus the
  modeled refund is that exit.) Fault maturation is NOT paused during the
  modelled outage (the design's attested-freeze forgiveness, section 10.4
  rung 3, is governance and out of model), which is the conservative
  direction: strictly more adversarial states are explored.

The adversary is *maximally nondeterministic*: at every step it may pick any
enabled action (honest or Byzantine) for any actor. Exhaustive BFS over this
choice therefore covers all behaviours up to the epoch/clock bound.

Run:  python3 model_checker.py                # default bound (2x6, W_ANARCHY=1, ~40 s)
      python3 model_checker.py 3 6            # clean NEPOCHS=3 bound -- needs a large
                                              # memory/time budget (>11M states; fails
                                              # loudly at the cap, never silently)
      W_ANARCHY=0 python3 model_checker.py    # disable the anarchy lane -> pre-anarchy v10
      python3 model_checker.py 2 6 0          # same, via 3rd positional arg
      python3 model_checker.py --w-anarchy 0  # same, via flag
      python3 model_checker.py 2 7 --sticks 2 --cancel-lag 2
                                              # seal deadline = 2 tolled ticks, expiry
                                              # scaled with it
      python3 model_checker.py --mutate       # invariant self-test (21 mutants)

Choose MAXCLOCK >= NEPOCHS-1 (deciding epoch e requires clock >= e) and, for
liveness conclusions, MAXCLOCK >= NEPOCHS*CANCEL_LAG + 3: per-epoch
tolled expiry serializes cancellation chains (an epoch decided at its
window-closing tick still needs CANCEL_LAG+1 fresh ticks to its expiry),
so smaller horizons leave late-decided content un-exitable within the
bound and report (artifact) outage-robust halts -- main() warns.
Exit code is non-zero on any safety violation, any halt, any truncated
exploration, or a failed RESERVE0 sufficiency check.
"""

from __future__ import annotations
import sys
from collections import deque
from dataclasses import dataclass, field
from typing import NamedTuple, Optional

# ---------------------------------------------------------------------------
# Parameters of the abstract model (small by design; exhaustive within them).
# ---------------------------------------------------------------------------
NEPOCHS = 2        # number of epochs modelled (indices 0..NEPOCHS-1)
MAXCLOCK = 6       # wall-clock epochs the environment may advance to. Default changed
                   # 3x4 -> 2x6 in the v10 revision, honestly: the per-epoch tolled
                   # expiry (r9-B5) serializes cancellation chains -- an epoch decided
                   # as late as its window-closing tick still needs its OWN CANCEL_LAG+1
                   # tolled ticks before its expiry cancel, and each CONTENT ancestor
                   # can defer a successor's tolled clock by up to CANCEL_LAG valid-seal
                   # ticks -- so the artifact-free liveness floor is
                   # NEPOCHS*CANCEL_LAG + 3 (3x4/3x5 report outage-robust horizon
                   # artifacts: the model-scale image of the design's "one cascade per
                   # H_cancel" worst-case cadence, r9-A4, surfacing in the tool). The
                   # clean NEPOCHS=3 bound (3x6) exceeds a 15 GB / ~20-minute budget in
                   # this v10 model (stopped past 11.2M discovered states with the
                   # frontier still growing; the below-floor 3x5 likewise passed 9.6M --
                   # the checker fails LOUDLY at its cap rather than truncating
                   # silently, and no partial numbers are reported), so the shipped
                   # default is the largest bound that completes cleanly on commodity
                   # hardware: 2x6 (~35 s). Run `3 6` on bigger hardware for the
                   # fully-clean NEPOCHS=3 result (RESULTS.md states the gap).
K = 2              # global lag cap (recovery-only beyond this) -- design value 8, scaled
                   # down so recovery-only mode is reachable within tiny bounds; the
                   # recovery-exit threshold K' (design 4) scales to 0 here (_enter_modes)
CANCEL_LAG = 1     # per-epoch expiry threshold (r9-B5): cancellation of the openEpoch is
                   # enabled only when THAT epoch's own tolled open-age (ticks spent
                   # decided-and-unsealed as the openEpoch) exceeds CANCEL_LAG -- the
                   # model of the design's per-epoch mechanical expiry T_exp =
                   # decision-final + H_cancel on the tolled clock (v10 section 6.7,
                   # r9-F2/B4), replacing the earlier global-lag enablement (which let
                   # a backlog age a DIFFERENT epoch into cancellability). The design's
                   # 10-day H_cancel is deliberately collapsed to 1 tolled tick so the
                   # disaster lane -- including CHAINS of per-epoch expiries under a
                   # permanent proving outage -- is reachable within bounded horizons.
                   # This OVER-approximates cancellation availability: safety-
                   # conservative (the cascade is exercised more, not less); the real
                   # H_cancel delay is a timing parameter argued in the design doc, not
                   # checked here. Must be >= S_TICKS or the missed-seal-then-late-seal
                   # orderings become unreachable (seals are disabled at/after expiry).
S_TICKS = 1        # tolled ticks an owned, DECIDED openEpoch may survive unsealed before
                   # the missed-seal certificate materializes (r9-D5). Default 1:
                   # conservative -- the fault matures at the first opportunity, so every
                   # late-seal / seal-then-withdraw ordering exists at the smallest
                   # bound. --sticks 2 delays maturation by one tick (a coarse image of
                   # the design's S=4-epoch seal deadline being longer than one epoch)
                   # to show the semantics are parameterized, not baked in.
MUTANT = None      # set to a mutant name to deliberately break the design (self-test)
NTENURES = 3       # distinct tenure identities (owners) available
L_LIVE = 1         # liveness slash (abstract units)
W_ANARCHY = 1      # v11 anarchy proposal-phase length in model ticks (design W_a, section 9;
                   # design value = S = 4 epochs, scaled down like K/CANCEL_LAG so both sides
                   # of the two-sided cutoff are exercised within tiny bounds). An UNOWNED
                   # epoch e's proposal cutoff is min(e + W_ANARCHY, first owned epoch after e),
                   # collapsed to the current clock while recovery-only mode is active (design
                   # 9.1 I5): discretionary `anarchy_propose` (atomic content seal) is valid
                   # STRICTLY BEFORE the cutoff, the proof-free EMPTY resolution AT/AFTER it.
                   # The composition with the v10 decision deadline (r9-D1) is consistent for
                   # W_ANARCHY <= 2: the cutoff never exceeds e+2 (the window-closing tick's
                   # auto-resolution clock), so a window-close EMPTY auto-resolve always lands
                   # AT/AFTER the cutoff, and proposals only ever fire at clock e or e+1 (inside
                   # the decision window). W_ANARCHY = 0 disables the lane entirely (cutoff == e,
                   # so `anarchy_propose` is never enabled and EMPTY is never phase-gated) and
                   # reproduces the pre-anarchy v10 model BIT-FOR-BIT (a checked property; see
                   # RESULTS.md / the `W_ANARCHY=0` run). Settable via `--w-anarchy N`, a 3rd
                   # positional arg, or the `W_ANARCHY` environment variable.
# Per-tenure reserve at admission. The design (section 7.3) SIZES the recovery tranche to a
# tenure's worst-case obligations (the solvency invariant), so a correctly-admitted tenure's
# reserve is never driven negative by its own debits. The abstract worst case is now THREE
# debits per owned epoch (a missed-seal SEAL cert, a later CANCEL cert, and -- new in v10,
# r9-D4 -- an L1-direct equivocation SAFETY cert on the same epoch) across all NEPOCHS
# epochs a single tenure can be the acting owner of -> 3*NEPOCHS, plus a margin. (The
# design splits these across the recovery tranche and the ETH safety tranche of the single
# account, section 4; one abstract reserve stands in for the whole waterfall.) If a run
# ever drives a reserve below zero, `inv_bond_nonneg` fires: the checker detecting
# UNDER-collateralization, the design's solvency property (round-8 finding W3). And the
# sizing is no longer only a formula: after exploration the checker computes the OBSERVED
# maximum cumulative debit per tenure across all reachable states and asserts RESERVE0
# covers it, printing the slack (r9-D7) -- the admission-sizing assumption is a checked
# bound, not an input.
RESERVE0 = 3 * NEPOCHS + 1

# Epoch status values
SEQ       = "SEQ"        # not yet decided (being sequenced / future)
CONTENT   = "CONTENT"    # committed content outcome (valid EBC + available data)
EMPTY     = "EMPTY"      # empty outcome (no valid EBC)
VOID      = "VOID"       # commitment voided by an ancestor's cancellation cascade (6.7);
                         # closes as CANCELLED when it becomes the openEpoch
SEALED    = "SEALED"     # finalized by a proof-carrying (or empty) seal
CANCELLED = "CANCELLED"  # expiry-cancellation resolution (data lost) -> treated as sealed-empty

DECIDED = (CONTENT, EMPTY)
CLOSED  = (SEALED, CANCELLED)

# Modes
NORMAL, RECOVERY_ONLY, FROZEN = "NORMAL", "RECOVERY_ONLY", "FROZEN"

# Commitment lineage tags (6.7 cascade bookkeeping; see State.cgen)
CUR, STALE = "CUR", "STALE"


def replace(s, **kw):
    # dataclasses.replace-compatible shim over NamedTuple._replace (much faster).
    return s._replace(**kw)


def _age_sat():
    # openAge saturation point: past max(S_TICKS, CANCEL_LAG+1) every age-dependent
    # predicate (seal-deadline maturity, expiry) has already switched, so higher counts
    # are behaviourally identical -- saturating merges them and bounds the state space.
    return max(S_TICKS, CANCEL_LAG + 1)


class State(NamedTuple):
    # (a NamedTuple: the state object IS its own hash key -- no duplicate key tuple --
    # and _replace is C-implemented, which matters at multi-million-state bounds)
    # per-epoch status and owner tenure (None == anarchy / unowned)
    status: tuple           # tuple[str] len NEPOCHS
    owner: tuple            # tuple[Optional[int]] len NEPOCHS
    # ordered forced queue (r9-D3): per-epoch tuple of live forced-item ids, in queue
    # order. Item ids are assigned at init (id == the epoch the item was originally due
    # in), so ascending id == original global queue order. Items leave a queue only into
    # a terminal set (fconsumed / frefunded) or by order-preserving re-queue (cancel).
    fqueue: tuple           # tuple[tuple[int, ...]] len NEPOCHS
    decided_as: tuple       # tuple[Optional[str]] the first decision recorded (to catch
                            # flips while the epoch is live; cleared at closure -- a closed
                            # epoch's record is read by no invariant and would only split
                            # behaviourally-identical states)
    openEpoch: int          # lowest index not in CLOSED (== NEPOCHS when all closed)
    clock: int              # wall-clock epoch (environment)
    mode: str
    # tenures: reserve remaining
    reserve: tuple          # tuple[int] len NTENURES
    # certificates: frozenset of (tenure, epoch, cls) that are SETTLED (debitable).
    # By I2 these are *computed* facts: materialized deterministically (tick/cancel/
    # miss_commit/equivocate), sticky forever, never dependent on a poke.
    settled_certs: frozenset
    consumed: frozenset     # frozenset of logical fault ids already debited
    withdrawn: frozenset    # tenures that have withdrawn their bond
    # bookkeeping for no-frame: the ACTING assignment record -- which tenure currently
    # holds each epoch's duty. Updated only when a duty legitimately transfers
    # (promotion of still-SEQ epochs); the design's immutable tenure binding is the
    # original assignment, which the model does not need separately.
    assigned: tuple         # tuple[Optional[int]] len NEPOCHS
    # cancellation-cascade lineage (6.7): cgen[e] tags the lineage a CONTENT commitment
    # was made against -- CUR (current lineage), STALE (an ancestor's cancellation has
    # since changed the lineage: every cancel re-tags all live commitments STALE, the
    # per-epoch image of the earlier global generation counter -- equivalent for every
    # checked property, and bounded), or None (not committed / closed). Cleared on
    # closure: a closed epoch's lineage tag is dead state.
    cgen: tuple             # tuple[Optional[str]] len NEPOCHS -- None | CUR | STALE
    # v9: proving-outage flag (round-7 finding 3). While True, proof-carrying (CONTENT)
    # seals are impossible; proof-free resolutions remain available.
    outage: bool
    # v10 per-epoch tolled open-age (r9-B5): ticks epoch e has spent as the DECIDED,
    # unsealed openEpoch. Drives the S_TICKS seal-deadline maturation and the per-epoch
    # expiry (T_exp) predicate; saturates at _age_sat(); reset to 0 on closure (a closed
    # epoch's age is dead state -- resetting merges otherwise-identical futures).
    openAge: tuple          # tuple[int] len NEPOCHS
    # v10 commit one-shot record (r9-D4, design 3.1/5.1): committed[e] = the tenure whose
    # ACCEPTED commit artifact consumed the (tenure, epoch) one-shot (None: resolved with
    # no accepted artifact -- missed commit, window auto-resolution, or anarchy). Cleared
    # once the acceptance window closes (the record is dead past D+kappa: artifact-set
    # closure, 3.1) so it does not split states that share every future.
    committed: tuple        # tuple[Optional[int]] len NEPOCHS
    # v10 forced-item terminal states (r9-D3/B5; design 6.5's nullifier lifecycle
    # queued -> snapshotted -> {consumed | refunded}). Disjoint by construction and by
    # `inv_forced_order`; both sticky (edge_evidence_monotone).
    fconsumed: frozenset    # item ids consumed by a proof-carrying seal
    frefunded: frozenset    # item ids refunded via the void path (design 6.4)

    def key(self):
        return self


def initial_states():
    """Curated-but-broad set of initial owner/forced configurations. Exhaustive BFS from
    each covers *all behaviours* of that configuration; the configurations are chosen to
    span every structurally-distinct scenario: single owner, handover, multi-handover,
    anarchy in each position, and forced-snapshot items in each position (incl. all-forced
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
    # Forced-item scenarios: none, all, and each single position, plus alternating.
    # An originally-forced epoch e starts with the single ordered item id e in its
    # snapshot (r9-D3: item ids replace the boolean flags; one item per originally-forced
    # epoch suffices to expose every ordering behaviour of the re-queue cascade).
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
            fqueue=tuple(((i,) if forced[i] else ()) for i in range(NEPOCHS)),
            decided_as=tuple(None for _ in range(NEPOCHS)),
            openEpoch=0,
            clock=0,
            mode=NORMAL,
            reserve=tuple(RESERVE0 for _ in range(NTENURES)),
            settled_certs=frozenset(),
            consumed=frozenset(),
            withdrawn=frozenset(),
            assigned=owners,
            cgen=tuple(None for _ in range(NEPOCHS)),
            outage=False,
            openAge=tuple(0 for _ in range(NEPOCHS)),
            committed=tuple(None for _ in range(NEPOCHS)),
            fconsumed=frozenset(),
            frefunded=frozenset(),
        )
        inits.append(st)
    return inits


def recompute_open(status):
    for i, s in enumerate(status):
        if s not in CLOSED:
            return i
    return len(status)


def _effectively_open(status, e):
    # Epoch e's tolled clock runs iff no ancestor is SEQ (undecided) or CONTENT (a real
    # proving/expiry latency): a prefix of CLOSED epochs plus VOID/EMPTY epochs -- whose
    # closures are I7's deterministic, zero-latency proof-free resolutions -- is not a
    # genuine block (see the tick comment). The openEpoch itself trivially qualifies.
    for a in range(e):
        if status[a] == SEQ or status[a] == CONTENT:
            return False
    return True


def _anarchy_cutoff(s: State, e: int) -> int:
    """v11 proposal cutoff for UNOWNED epoch e (design 9.1: T_prop = min(D + W_a*E, T_F),
    with recovery-only mode collapsing pending phases -- I5). Model form: the epoch's
    schedule index anchors the decision (deciding e requires clock >= e), so the cutoff is
    min(e + W_ANARCHY, index of the first owned epoch after e) -- the second term is design
    rule 9.1-2/9.1-5 (an owned successor must never sequence on an undetermined parent).
    While the mode is not NORMAL the phase collapses to the current clock (resolutions
    enabled now, proposals not). Used identically by the enabling conditions and by the
    phase edge invariants, always on the transition's PRE-state, so the checks are
    path-independent and promotion-driven owner changes can never produce a false positive.
    W_ANARCHY = 0 yields cutoff == e (proposals, which need clock < cutoff <= e while a
    decision needs clock >= e, are then never enabled; EMPTY, which needs clock >= cutoff ==
    e, is never gated) -- the pre-anarchy model, recovered bit-for-bit."""
    if s.mode != NORMAL:
        return s.clock
    cut = e + W_ANARCHY
    for f in range(e + 1, NEPOCHS):
        if s.owner[f] is not None:
            cut = min(cut, f)
            break
    return cut


def lag(s: State) -> int:
    return max(0, s.clock - s.openEpoch)


def actions(s: State):
    """Yield (label, next_state) for every enabled action from s.
    Actions are Byzantine-inclusive: the adversary may choose any of them."""
    out = []
    n = NEPOCHS
    oe = s.openEpoch

    # ---- Environment: advance wall clock ----
    # Three deterministic sub-effects ride on the tick (all of them computed L1 facts,
    # I2 -- never dependent on a poke):
    # (1) Decision-window closure (r9-D1/B5): any epoch still SEQ whose decision window
    #     closes with this tick auto-resolves -- forced-only CONTENT if its snapshot is
    #     non-empty (I6: empty is then invalid; the forced-only outcome is constructible
    #     by anyone from L1 data), else EMPTY -- and an owned epoch's owner is charged a
    #     LIVENESS certificate atomically (missing EBC => certificate, design 5.1). This
    #     models "parent outcome fixed at D+kappa": the decision phase is irreversible
    #     and DEADLINED, exactly one resolution per epoch, on time.
    # (2) Tolled open-age (r9-B5): every DECIDED, unsealed, EFFECTIVELY-OPEN epoch (the
    #     openEpoch, or one blocked only by proof-free-closeable VOID/EMPTY ancestors --
    #     see the accrual comment below) accrues one tick of its per-epoch tolled age
    #     (saturated at _age_sat()); an epoch behind a SEQ or CONTENT ancestor accrues
    #     nothing (design 7.1 / I4 tolling).
    # (3) Missed-seal maturation (I2, r9-D5): when such an epoch's tolled age reaches
    #     S_TICKS while DECIDED, owned and unsealed, the owner has objectively missed
    #     the (tolled) seal deadline for BOTH outcomes (proof-carrying content seal, and
    #     the proof-free explicit-empty seal) and the SEAL certificate settles here --
    #     sticky, so the seal-then-withdraw bypass is structurally impossible.
    #     Carve-out: an epoch that resolved through a missed commit already carries that
    #     owner's LIVENESS certificate; its closure is the recovery lane's job (paid
    #     from the faulter), not a second distinct fault.
    if s.clock < MAXCLOCK:
        nc = s.clock + 1
        certs = s.settled_certs
        new_status = list(s.status)
        new_decided = list(s.decided_as)
        new_cgen = list(s.cgen)
        new_committed = list(s.committed)
        # (1) window closure
        if MUTANT != "late_decide":
            for e in range(n):
                if new_status[e] == SEQ and e + 1 < nc:
                    if s.fqueue[e]:
                        new_status[e] = CONTENT   # forced-only (I6); permissionless
                        new_decided[e] = CONTENT
                        new_cgen[e] = CUR         # materialized against the current lineage
                    else:
                        new_status[e] = EMPTY
                        new_decided[e] = EMPTY
                    if s.owner[e] is not None:
                        certs = certs | {(s.owner[e], e, "LIVENESS")}
        # acceptance-window closure (3.1 artifact-set closure): the one-shot record of an
        # epoch whose window closed is dead -- no second artifact can ever be accepted --
        # so it is cleared to merge behaviourally-identical states.
        for e in range(n):
            if e + 1 < nc:
                new_committed[e] = None
        # (2)+(3) tolled age and seal-deadline maturation (pre-tick status: an epoch
        # auto-resolved by THIS tick starts its tolled clock afterwards). An epoch
        # accrues age iff it is DECIDED, unsealed, and EFFECTIVELY OPEN -- every
        # ancestor is closed, or is a VOID/EMPTY epoch whose closure is one of I7's
        # DETERMINISTIC proof-free resolutions (zero-latency, permissionless, clearable
        # by anyone -- the owner included -- in the same L1 block). Waiting behind such
        # a prefix is not a genuine block in I4's sense, so it does not toll; waiting
        # behind a SEQ or CONTENT ancestor (an undecided outcome, or a proof/expiry
        # whose latency is real) does. The strict "only as the openEpoch" reading would
        # let an adversary defer every descendant deadline forever by declining a free
        # transaction -- the round-8 W1 unfair-scheduler livelock, which weak fairness
        # resolves at the protocol layer and which, in a bounded model, would otherwise
        # manufacture horizon artifacts at EVERY bound. A backlogged descendant is still
        # never blamed while a CONTENT ancestor is unsealed (the round-6 closure).
        new_age = list(s.openAge)
        for e in range(n):
            if s.status[e] in DECIDED and _effectively_open(s.status, e):
                new_age[e] = min(s.openAge[e] + 1, _age_sat())
                if new_age[e] >= S_TICKS and s.owner[e] is not None \
                        and (s.owner[e], e, "LIVENESS") not in s.settled_certs:
                    if MUTANT != "no_materialize":
                        certs = certs | {(s.owner[e], e, "SEAL")}
        ns = replace(s, clock=nc, settled_certs=certs, status=tuple(new_status),
                     decided_as=tuple(new_decided), cgen=tuple(new_cgen),
                     committed=tuple(new_committed), openAge=tuple(new_age))
        ns = _enter_modes(ns)
        out.append((f"tick->{nc}", ns))

    # ---- Environment: proving outage (v9, round-7 finding 3). The adversary may start or
    #      end an outage at any time, any number of times -- or never end it. ----
    if not s.outage:
        out.append(("outage_start", replace(s, outage=True)))
    else:
        out.append(("outage_end", replace(s, outage=False)))

    # ---- Decision on an epoch that is still SEQ and inside its decision window ----
    # An epoch may be decided once (single decision), and -- v10, r9-D1 -- only while its
    # decision window is open: e <= clock <= e+1 (the D+kappa instant falls inside coarse
    # clock e+1; the tick past it auto-resolves, above). Models the commit decision.
    for e in range(n):
        if s.status[e] != SEQ:
            continue
        if e > s.clock:
            continue
        if s.clock > e + 1 and MUTANT != "late_decide":
            continue   # decision window closed (r9-D1); mutant re-enables late decides
        # In RECOVERY_ONLY / FROZEN no *new content* may be committed: only EMPTY/forced-only.
        content_allowed = (s.mode == NORMAL)
        # If forced snapshot non-empty -> EMPTY is invalid (I6): must be CONTENT (forced-only).
        # Forced-only content is allowed even in recovery-only mode (it is not discretionary).
        options = []
        if s.fqueue[e]:
            options.append(CONTENT)  # forced-only content (valid in both phase regimes -- v11)
        else:
            # v11 (design 9.1): an UNOWNED epoch's proof-free EMPTY resolution is valid only
            # AT/AFTER its proposal cutoff -- the empty side of the two-sided rule that closes
            # round-2 finding 6's empty-front-running horn (horn 2). Owned epochs are ungated
            # (an explicit-empty EBC is the holder's own choice, phase-free). W_ANARCHY=0
            # collapses the cutoff to e, so empty_ok is always true (deciding needs clock>=e)
            # and this branch reduces to the pre-anarchy `options.append(EMPTY)` exactly.
            empty_ok = (s.owner[e] is not None) or (s.clock >= _anarchy_cutoff(s, e))
            if MUTANT == "anarchy_empty_in_phase":
                empty_ok = True   # BUG: proof-free empty valid inside the phase (horn 2)
            if empty_ok:
                options.append(EMPTY)
            if content_allowed and s.owner[e] is not None:
                options.append(CONTENT)  # discretionary content, only if owned & normal mode
        if MUTANT == "empty_despite_forced" and s.fqueue[e] and EMPTY not in options:
            options = options + [EMPTY]   # BUG: allow empty despite forced snapshot (breaks I6)
        for dec in options:
            new_status = list(s.status); new_status[e] = dec
            new_decided = list(s.decided_as); new_decided[e] = dec
            new_cgen = list(s.cgen)
            new_committed = list(s.committed)
            if dec == CONTENT:
                new_cgen[e] = CUR     # commitment is made against the current lineage (6.7)
            if s.owner[e] is not None:
                # the owner's ACCEPTED artifact (content or explicit-empty EBC) consumes
                # the (tenure, epoch) commit one-shot (3.1/5.1; r9-D4). Anarchy epochs
                # resolve permissionlessly with no artifact -> no one-shot consumed.
                new_committed[e] = s.owner[e]
            ns = replace(s, status=tuple(new_status), decided_as=tuple(new_decided),
                         cgen=tuple(new_cgen), committed=tuple(new_committed))
            out.append((f"decide(e{e}={dec}{'/forced' if s.fqueue[e] else ''})", ns))

    # MUTANT: re-decide an already-decided (not yet closed) epoch to the opposite outcome.
    if MUTANT == "double_decision":
        for e in range(n):
            if s.status[e] in DECIDED:
                flip = EMPTY if s.status[e] == CONTENT else CONTENT
                new_status = list(s.status); new_status[e] = flip
                ns = replace(s, status=tuple(new_status))  # decided_as keeps original -> flip
                out.append((f"REDECIDE(e{e}->{flip})", ns))

    # ---- Missed-commit fault: an owned SEQ epoch past its boundary (and still inside its
    #      decision window) resolves EMPTY with a liveness certificate on its owner
    #      (objective, no accused cooperation). The EMPTY resolution and the certificate
    #      are atomic (I2: the resolving read materializes the certificate). Within the
    #      coarse window this is the adversary realizing the D+kappa miss early; the
    #      window-closing tick realizes it deterministically for whatever is left. ----
    for e in range(n):
        if s.status[e] == SEQ and e <= s.clock <= e + 1 and s.owner[e] is not None \
                and not s.fqueue[e]:
            owner = s.owner[e]
            new_status = list(s.status); new_status[e] = EMPTY
            new_decided = list(s.decided_as); new_decided[e] = EMPTY
            cert = (owner, e, "LIVENESS")
            ns = replace(s, status=tuple(new_status), decided_as=tuple(new_decided),
                         settled_certs=s.settled_certs | {cert})
            out.append((f"miss_commit(e{e},T{owner})", ns))

    # ---- Anarchy proposal (v11, design section 9, round 10): ANY actor may seal an UNOWNED
    #      openEpoch with discretionary content in ONE atomic proof-carrying step
    #      (propose == seal == finality; round-2 finding 6 horn 1 -- unproven content never
    #      locks state, and unowned discretionary content never exists unsealed, checked by
    #      inv_anarchy_content_sealed). Valid STRICTLY inside the epoch's proposal phase:
    #      clock in [oe, cutoff) with cutoff = _anarchy_cutoff (the two-sided min that also
    #      truncates at an owned successor's start), NORMAL mode only (discretionary content,
    #      I5), and never during a proving outage (the proposal carries a proof). There is no
    #      owner, no bond, no duty and no certificate in this lane, so no commit one-shot is
    #      consumed (committed[oe] stays None -> no equivocation surface). A forced snapshot
    #      does NOT block it: the proposal content includes the forced prefix by construction
    #      (I6), so its atomic born-sealed closure consumes those forced items exactly as
    #      seal_content does (nullifier -> fconsumed). The composition with the r9-D1 decision
    #      deadline is consistent for W_ANARCHY <= 2 (cutoff <= oe+2, so a proposal only ever
    #      fires at clock oe or oe+1, inside the decision window). W_ANARCHY=0 makes cutoff==oe
    #      (proposals need clock < cutoff <= oe while the openEpoch needs clock >= oe), so this
    #      action is never enabled -- the pre-anarchy model, recovered exactly. ----
    if oe < n and s.status[oe] == SEQ and s.owner[oe] is None and oe <= s.clock \
            and not s.outage and s.mode == NORMAL:
        in_phase = s.clock < _anarchy_cutoff(s, oe)
        if MUTANT == "anarchy_propose_after_close":
            in_phase = True   # BUG: proposal accepted at/after the cutoff (flips a determined outcome)
        if MUTANT == "anarchy_ignores_ownership":
            in_phase = s.clock < oe + W_ANARCHY   # BUG: cutoff ignores the owned-successor truncation
        if in_phase:
            if MUTANT == "nonatomic_anarchy_propose":
                # BUG (horn 1): the proposal locks decided-but-UNSEALED unowned content --
                # sittable in the cancellable value-at-risk tail, unproven. Left CONTENT, not
                # born sealed, so inv_anarchy_content_sealed fires.
                new_status = list(s.status); new_status[oe] = CONTENT
                new_decided = list(s.decided_as); new_decided[oe] = CONTENT
                new_cgen = list(s.cgen); new_cgen[oe] = CUR   # unsealed content, current lineage
                ns = replace(s, status=tuple(new_status), decided_as=tuple(new_decided),
                             cgen=tuple(new_cgen))
            else:
                # atomic: born SEALED (propose == seal). Consumes the forced snapshot items and
                # clears the closed epoch's dead per-epoch bookkeeping (openAge/cgen/decided).
                new_status = list(s.status); new_status[oe] = SEALED
                new_fq = list(s.fqueue); items = new_fq[oe]; new_fq[oe] = ()
                new_age = list(s.openAge); new_age[oe] = 0
                new_cgen = list(s.cgen); new_cgen[oe] = None   # closed epoch's tag is dead
                new_dec = list(s.decided_as); new_dec[oe] = None  # closed record is dead
                ns = replace(s, status=tuple(new_status), fqueue=tuple(new_fq),
                             fconsumed=s.fconsumed | set(items), openAge=tuple(new_age),
                             cgen=tuple(new_cgen), decided_as=tuple(new_dec))
                ns = replace(ns, openEpoch=recompute_open(ns.status))
            ns = _enter_modes(ns)
            out.append((f"anarchy_propose(e{oe}{'/forced' if s.fqueue[oe] else ''})", ns))

    # ---- Equivocation (v10, r9-D4; design 3.1/5.1/8 variant (a)): a SECOND DISTINCT
    #      accepted commit artifact by the tenure that already consumed the (tenure,
    #      epoch) one-shot, possible only while the acceptance window is still open
    #      (after D+kappa the artifact set is closed -- 3.1). One-shot semantics: the
    #      decision NEVER changes (first accepted artifact won); the second artifact is
    #      irrefutable L1-direct equivocation evidence -- a SAFETY certificate settles
    #      atomically (no L2 adjudication, zero latency) and the tenure terminates
    #      immediately: its still-SEQ epochs promote to a successor or drop to anarchy
    #      exactly as for other terminations (design 8: "terminating the tenure
    #      immediately"). ----
    for e in range(n):
        t = s.committed[e]
        if t is None:
            continue
        if s.clock > e + 1:
            continue   # acceptance window closed: artifact-set closure (3.1)
        if (t, e, "SAFETY") in s.settled_certs:
            continue   # evidence already settled: the record is one-shot too
        certs = s.settled_certs
        if MUTANT != "equivocation_no_cert":
            certs = certs | {(t, e, "SAFETY")}   # L1-direct, atomic (design 8)
        new_status = list(s.status)
        if MUTANT == "equivocation_flips_decision" \
                and s.status[e] == CONTENT and not s.fqueue[e]:
            new_status[e] = EMPTY   # BUG: the second artifact replaces the decision
        # immediate termination: reassign the equivocator's still-SEQ epochs (same
        # promotion logic as the standard termination path below).
        successor = _pick_successor(certs, s.withdrawn, t)
        new_owner = list(s.owner)
        new_assigned = list(s.assigned)
        for e2 in range(n):
            if new_owner[e2] == t and new_status[e2] == SEQ:
                new_owner[e2] = successor
                new_assigned[e2] = successor
        ns = replace(s, status=tuple(new_status), settled_certs=certs,
                     owner=tuple(new_owner), assigned=tuple(new_assigned))
        out.append((f"equivocate(T{t},e{e})", ns))

    # MUTANT: seal a decided epoch that is NOT the openEpoch (out-of-order seal).
    if MUTANT == "seal_out_of_order":
        for e in range(n):
            if e != oe and s.status[e] in DECIDED:
                new_status = list(s.status); new_status[e] = SEALED
                ns = replace(s, status=tuple(new_status))
                ns = replace(ns, openEpoch=recompute_open(ns.status))
                out.append((f"SEAL_OOO(e{e})", ns))

    # MUTANT: re-open an already-CLOSED epoch (violates the immutability corollary). Tests
    # the path-independent edge_seal_immutable (round-8 W2).
    if MUTANT == "reopen_sealed":
        for e in range(n):
            if s.status[e] in CLOSED:
                new_status = list(s.status); new_status[e] = CONTENT
                ns = replace(s, status=tuple(new_status))
                ns = replace(ns, openEpoch=recompute_open(ns.status))
                out.append((f"REOPEN(e{e})", ns))

    # ---- Typed seals (v10, r9-D2): only the openEpoch may be sealed, and the closure is
    #      TYPED by the decided outcome it consumes.
    #      * seal_content -- the proof-carrying seal of a CONTENT-decided epoch
    #        (discretionary AND forced-only content: I7 / design 10.4 guarantee 2 --
    #        forced execution is proof-carrying). IMPOSSIBLE during a proving outage,
    #        and -- v10 6.7 mechanical cutoff -- valid strictly BEFORE the epoch's
    #        expiry: once openAge exceeds CANCEL_LAG the seal is disabled, so seal and
    #        cancellation are never simultaneously enabled (no L1-ordering race).
    #        Consumes the epoch's forced snapshot items (nullifier -> consumed).
    #      * seal_empty -- the proof-free deterministic closure of an EMPTY-decided
    #        epoch (I7). Available during an outage; an EMPTY epoch has no expiry (its
    #        proof-free seal IS the deterministic exit -- no cancellation competes).
    #      Both honest-owner and permissionless recovery seals advance; a late seal does
    #      NOT erase a matured certificate: certs are sticky (I2). Withholding the seal
    #      is captured by simply not taking the action; the missed deadline then
    #      materializes a certificate inside a later tick (above). ----
    if oe < n and s.status[oe] == CONTENT:
        sealable = not s.outage                       # proof-carrying: needs a prover (v9)
        if MUTANT != "seal_after_expiry":
            sealable = sealable and s.openAge[oe] <= CANCEL_LAG   # strictly before T_exp
        # (BUG seal_after_expiry: the expiry cutoff is ignored -- seal and cancel become
        # simultaneously enabled after T_exp, the overlap r9-F2 closed.)
        if sealable:
            new_status = list(s.status); new_status[oe] = SEALED
            certs = s.settled_certs
            if MUTANT == "seal_erases_cert":
                certs = frozenset(c for c in certs if c[1] != oe)   # BUG: seal destroys evidence
            new_fq = list(s.fqueue)
            items = new_fq[oe]; new_fq[oe] = ()
            new_age = list(s.openAge); new_age[oe] = 0
            new_cgen = list(s.cgen); new_cgen[oe] = None   # closed epoch's tag is dead
            new_dec = list(s.decided_as); new_dec[oe] = None  # ditto its decision record
            ns = replace(s, status=tuple(new_status), settled_certs=certs,
                         fqueue=tuple(new_fq), fconsumed=s.fconsumed | set(items),
                         openAge=tuple(new_age), cgen=tuple(new_cgen),
                         decided_as=tuple(new_dec))
            ns = replace(ns, openEpoch=recompute_open(ns.status))
            ns = _enter_modes(ns)
            out.append((f"seal_content(e{oe})", ns))
    if oe < n and s.status[oe] == EMPTY:
        sealable = True                               # proof-free (I7): outage-immune
        if MUTANT == "outage_blocks_empty":
            sealable = not s.outage                   # BUG: outage blocks everything
        if sealable:
            new_status = list(s.status); new_status[oe] = SEALED
            certs = s.settled_certs
            if MUTANT == "seal_erases_cert":
                certs = frozenset(c for c in certs if c[1] != oe)   # BUG: seal destroys evidence
            new_age = list(s.openAge); new_age[oe] = 0
            new_dec = list(s.decided_as); new_dec[oe] = None  # closed record is dead
            ns = replace(s, status=tuple(new_status), settled_certs=certs,
                         openAge=tuple(new_age), decided_as=tuple(new_dec))
            ns = replace(ns, openEpoch=recompute_open(ns.status))
            ns = _enter_modes(ns)
            out.append((f"seal_empty(e{oe})", ns))
    # MUTANT: the proof-free empty-typed closure claims a CONTENT-decided epoch -- e.g.
    # during an outage, when the proof-carrying seal is impossible (breaks I1: content
    # exists only through its proof). Kept off expired epochs so the counterexample is
    # attributed to edge_typed_seal alone, not the expiry cutoff.
    if MUTANT == "empty_seal_steals_content" and oe < n and s.status[oe] == CONTENT \
            and s.openAge[oe] <= CANCEL_LAG:
        new_status = list(s.status); new_status[oe] = SEALED
        new_fq = list(s.fqueue)
        items = new_fq[oe]; new_fq[oe] = ()
        new_age = list(s.openAge); new_age[oe] = 0
        new_dec = list(s.decided_as); new_dec[oe] = None
        ns = replace(s, status=tuple(new_status), fqueue=tuple(new_fq),
                     fconsumed=s.fconsumed | set(items), openAge=tuple(new_age),
                     decided_as=tuple(new_dec))
        ns = replace(ns, openEpoch=recompute_open(ns.status))
        ns = _enter_modes(ns)
        out.append((f"seal_empty(e{oe},STEAL)", ns))

    # ---- Close a voided openEpoch as CANCELLED (permissionless, always enabled):
    #      the deferred, in-order closure step of the 6.7 cascade. ----
    if oe < n and s.status[oe] == VOID:
        new_status = list(s.status); new_status[oe] = CANCELLED
        new_cgen = list(s.cgen); new_cgen[oe] = None   # closed epoch's tag is dead
        new_dec = list(s.decided_as); new_dec[oe] = None
        ns = replace(s, status=tuple(new_status), cgen=tuple(new_cgen),
                     decided_as=tuple(new_dec))
        ns = replace(ns, openEpoch=recompute_open(ns.status))
        ns = _enter_modes(ns)
        out.append((f"close_void(e{oe})", ns))

    # ---- Expiry cancellation (v10 6.7 mechanical cutoff): a CONTENT openEpoch whose OWN
    #      tolled open-age has passed its expiry (openAge > CANCEL_LAG -- the per-epoch
    #      T_exp, r9-B5/F2). Re-resolves to CANCELLED (== sealed-empty) and advances.
    #      Permissionless; the proof-carrying seal is already disabled at this age (no
    #      overlap). Cascade (6.7): every committed-CONTENT unsealed descendant chained
    #      to it is voided in the same deterministic step (its commitment referenced a
    #      lineage that no longer exists); the live forced items of the cancelled and
    #      voided epochs re-queue -- IN ORIGINAL QUEUE ORDER (r4b-M8; ids ascending) --
    #      into the earliest still-SEQ epoch, or, when the bound holds no future epoch to
    #      re-queue into, take the modeled REFUND exit (design 6.4: expired snapshots
    #      void with fees refundable on L1 -- the unconditional forced-queue guarantee is
    #      refund, not execution, design 10.4 guarantee 2; modeled explicitly per r9-B5
    #      so the liveness goal is honestly reachable with no stranded-flag artifact).
    #      The cancellation-causing tenure is charged (an additional CANCEL-class
    #      certificate, beyond any earlier SEAL cert). ----
    if oe < n and s.status[oe] == CONTENT and s.openAge[oe] > CANCEL_LAG:
        new_status = list(s.status); new_status[oe] = CANCELLED
        new_cgen = list(s.cgen)
        cascaded = []
        if MUTANT != "no_cascade":
            for e2 in range(oe + 1, n):
                if new_status[e2] == CONTENT:
                    new_status[e2] = VOID   # commitment voided; closes (in order) as CANCELLED
                    cascaded.append(e2)
        # lineage change: every commitment still alive after this cancellation was made
        # against a lineage that no longer exists -- re-tag it STALE (the per-epoch form
        # of the old global generation bump). In the healthy cascade all such epochs are
        # VOID; under the no_cascade mutant a CONTENT epoch keeps a STALE tag and
        # inv_content_current_gen fires.
        for e2 in range(n):
            if new_status[e2] in (CONTENT, VOID) and new_cgen[e2] is not None:
                new_cgen[e2] = STALE
        new_cgen[oe] = None   # closing epoch's tag is dead
        new_fq = list(s.fqueue)
        moved = []
        for e2 in [oe] + cascaded:
            moved.extend(new_fq[e2])
            new_fq[e2] = ()
        new_refunded = s.frefunded
        if moved:
            target = next((e2 for e2 in range(n) if new_status[e2] == SEQ), None)
            if target is not None:
                if MUTANT == "requeue_reorders":
                    # BUG: re-queued items appended BEHIND the target's own snapshot --
                    # original queue order broken (r4b-M8 violated).
                    new_fq[target] = tuple(new_fq[target]) + tuple(moved)
                else:
                    # Order-preserving merge: the global live queue stays in original
                    # submission order (ascending ids). A plain "front" concatenation is
                    # order-equivalent whenever decisions happened in epoch order (as
                    # they always do in real time, where decision instants are strictly
                    # increasing); the model's coarse decision windows overlap by one
                    # clock, so the sorted merge states the design's order rule
                    # (r4b-M8) directly rather than through a placement heuristic.
                    new_fq[target] = tuple(sorted(tuple(moved) + tuple(new_fq[target])))
            else:
                new_refunded = new_refunded | set(moved)   # modeled refund exit (r9-B5, 6.4)
        certs = s.settled_certs
        if s.owner[oe] is not None:
            certs = certs | {(s.owner[oe], oe, "CANCEL")}   # charge the causing tenure (6.7)
        new_age = list(s.openAge); new_age[oe] = 0
        new_dec = list(s.decided_as); new_dec[oe] = None
        ns = replace(s, status=tuple(new_status), fqueue=tuple(new_fq),
                     settled_certs=certs, cgen=tuple(new_cgen),
                     frefunded=new_refunded, openAge=tuple(new_age),
                     decided_as=tuple(new_dec))
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
        # No silent zero-floor (round-8 W3): a debit ALWAYS decrements, so every debit is
        # checked by edge_debit_conservation, and a debit that would drive the reserve below
        # zero surfaces as an inv_bond_nonneg violation -- the checker detecting insolvency
        # (reserve sizing insufficient) rather than masking it.
        new_res[owner] = new_res[owner] - amt
        ns = replace(s, reserve=tuple(new_res), consumed=s.consumed | {lid})
        out.append((f"debit({cls},T{owner},e{e})", ns))

    # ---- Auction: promote a standby / drop to anarchy when a tenure terminates. ----
    #      Model: a tenure with a settled cert may be terminated; its still-SEQ owned epochs
    #      become owned by another available tenure, or anarchy if none. (The equivocation
    #      action above already terminates atomically -- L1-direct, zero latency; this lane
    #      covers the liveness-fault terminations.) ----
    terminating = sorted({owner for (owner, e, cls) in s.settled_certs})
    for owner in terminating:
        successor = _pick_successor(s.settled_certs, s.withdrawn, owner)
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
    #      materialized deterministically (tick/cancel/miss_commit/equivocate) and sticky,
    #      the settled_certs set IS the matured set here; a matured-but-undebited fault, an
    #      unsealed owned epoch, or an OPEN ACCEPTANCE WINDOW on a committed epoch (v10 --
    #      the design's withdrawal floor outlasts every challenge window, 8/r9-B3, so an
    #      exit can never complete while a second-artifact liability could still settle)
    #      closes the gate. Only the LEGAL (gated) transition is in the design's transition
    #      relation; the checker then proves the gate is *sufficient* (INV_WITHDRAW_GATED
    #      can never fire over legal runs). ----
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


def _pick_successor(certs, withdrawn, terminating_owner) -> Optional[int]:
    # highest available standby not itself terminating/withdrawn, else anarchy
    bad = {owner for (owner, e, cls) in certs} | set(withdrawn) | {terminating_owner}
    for t in range(NTENURES):
        if t not in bad:
            return t
    return None  # anarchy


def _withdraw_gate_open(s: State, t: int) -> bool:
    # zero unresolved certificates for t (settled_certs is the computed matured set -- I2)
    for (owner, e, cls) in s.settled_certs:
        if owner == t and (owner, e, cls) not in s.consumed:
            return False
    for e in range(NEPOCHS):
        # no unsealed epoch still assigned to (currently owned by) t -- VOID included
        if s.owner[e] == t and s.status[e] not in CLOSED:
            return False
        # v10 (r9-D4 support): no committed epoch of t whose acceptance window is still
        # open -- the design's >= 2-week withdrawal floor outlasts every D+kappa window
        # and bounded verdict deadline (8, r9-B3), so an exit cannot complete while a
        # second accepted artifact could still settle an equivocation certificate.
        if s.committed[e] == t and s.clock <= e + 1:
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
        # a decided epoch's recorded decision must match its (pre-seal) outcome lineage.
        # This is also the invariant that guards the v10 one-shot rule (r9-D4): an
        # equivocation -- a second accepted commit artifact -- must NEVER flip the
        # decision; the first accepted artifact won.
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
        if s.fqueue[e] and s.status[e] == EMPTY:
            return f"epoch {e} resolved EMPTY despite non-empty forced snapshot (I6)"
    return None


def inv_forced_order(s: State):
    # v10 (r9-D3; design 6.7 / r4b-M8): forced items are an ORDERED queue. (a) The global
    # live queue -- the concatenation of per-epoch snapshots in epoch order -- must stay in
    # original submission order (ascending item ids: cascade re-queue preserves order, and
    # consumption in openEpoch order then respects queue order by construction); (b) no
    # closed or voided epoch may retain a live item (a seal consumes its snapshot; a
    # cancel re-queues or refunds it -- the nullifier lifecycle, 6.5); (c) live and
    # terminal are disjoint, and the two terminal states are mutually exclusive (the
    # consumed-xor-refunded exclusion the bridge handshake relies on, 6.4 / 13-S.16).
    prev = -1
    for e in range(NEPOCHS):
        if (s.status[e] in CLOSED or s.status[e] == VOID) and s.fqueue[e]:
            return f"epoch {e} is {s.status[e]} but still holds live forced items {s.fqueue[e]}"
        for i in s.fqueue[e]:
            if i <= prev:
                return (f"forced-queue order broken: item {i} queued after item {prev} "
                        f"(epoch {e}) -- original order not preserved")
            prev = i
            if i in s.fconsumed or i in s.frefunded:
                return f"forced item {i} is live in epoch {e} but already terminal"
    both = s.fconsumed & s.frefunded
    if both:
        return f"forced item(s) {sorted(both)} both consumed and refunded (nullifier broken)"
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
            if s.cgen[e] != CUR:
                return (f"epoch {e} CONTENT with lineage tag {s.cgen[e]} "
                        f"(not current): cascade failed to void it")
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


def inv_anarchy_content_sealed(s: State):
    # v11 (design section 9, r10-5/I5): unowned DISCRETIONARY content exists only born-sealed
    # (propose == seal is one atomic step), so it can never sit in the cancellable
    # value-at-risk tail or lock the chain unproven (round-2 finding 6, horn 1). An unowned
    # CONTENT epoch is legitimate only in its forced-only form (the recovery lane's job), for
    # which the forced snapshot -- fqueue[e] -- is non-empty; a non-forced unowned CONTENT
    # epoch means a proposal was allowed to land decided-but-unsealed.
    for e in range(NEPOCHS):
        if s.owner[e] is None and s.status[e] == CONTENT and not s.fqueue[e]:
            return (f"epoch {e} carries unowned discretionary CONTENT unsealed "
                    f"(anarchy proposal was not atomic)")
    return None


SAFETY_INVARIANTS_STATE = [
    inv_single_decision, inv_empty_not_forced, inv_bond_nonneg,
    inv_content_current_gen, inv_no_frame, inv_withdraw_gated, inv_closed_is_prefix,
    inv_open_monotone, inv_forced_order, inv_anarchy_content_sealed,
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
    # (a seal or any other action must not erase evidence -- the SAFETY certificate of an
    # equivocation included, r9-D4), a consumed (debited) fault id can never be
    # un-consumed, and a forced item's terminal state (consumed/refunded nullifier, 6.5)
    # is sticky.
    if not ns.settled_certs >= s.settled_certs:
        gone = s.settled_certs - ns.settled_certs
        return f"evidence erased on {label}: {sorted(gone)}"
    if not ns.consumed >= s.consumed:
        return f"consumed set shrank on {label}"
    if not ns.fconsumed >= s.fconsumed or not ns.frefunded >= s.frefunded:
        return f"forced-item terminal state reverted on {label}"
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


def edge_seal_immutable(s: State, ns: State, label: str):
    # Immutability corollary (I3+I7), as a PATH-INDEPENDENT edge invariant (round-8 W2): no
    # single transition may change an already-CLOSED epoch's status. The state-level
    # inv_seal_immutable compares against the first-discovery closed-history and could be
    # masked by state deduplication (State.key() omits closed_hist); this edge check looks
    # only at the direct predecessor->successor pair, so dedup can never hide a re-open.
    for e in range(NEPOCHS):
        if s.status[e] in CLOSED and ns.status[e] != s.status[e]:
            return f"epoch {e} was {s.status[e]} then changed to {ns.status[e]} on {label}"
    return None


def edge_maturity_materialized(s: State, ns: State, label: str):
    # I2 as a transition property: a tick that brings a DECIDED (content OR
    # explicit-empty), owned, effectively-open epoch's tolled age to the S_TICKS seal
    # deadline (r9-D5) must materialize that owner's SEAL certificate in the successor
    # state (unless the epoch already carries the owner's miss-commit LIVENESS cert).
    if not label.startswith("tick"):
        return None
    for e in range(NEPOCHS):
        if s.status[e] in DECIDED and _effectively_open(s.status, e) \
                and s.owner[e] is not None \
                and (s.owner[e], e, "LIVENESS") not in s.settled_certs \
                and s.openAge[e] + 1 >= S_TICKS:
            if (s.owner[e], e, "SEAL") not in ns.settled_certs:
                return (f"missed seal deadline of e{e} (T{s.owner[e]}) not materialized "
                        f"on {label}")
    return None


def edge_decision_deadline(s: State, ns: State, label: str):
    # v10 (r9-D1/B5): the decision phase is DEADLINED and irreversible -- the design's
    # single decision fires at D+kappa, full stop (3.1). (a) No transition may decide an
    # epoch whose decision window (clock <= e+1) has closed; (b) no undecided epoch may
    # survive any transition past its window; (c) the window-closing tick's auto-
    # resolution of an OWNED epoch must settle that owner's LIVENESS certificate
    # atomically (missing EBC => certificate, 5.1 / I2).
    for e in range(NEPOCHS):
        if s.status[e] == SEQ and ns.status[e] != SEQ and s.clock > e + 1:
            return (f"epoch {e} decided at clock {s.clock}, after its decision window "
                    f"closed, on {label}")
        if ns.status[e] == SEQ and ns.clock > e + 1:
            return (f"epoch {e} survived past its decision window undecided (clock "
                    f"{ns.clock}) on {label}")
        if s.status[e] == SEQ and ns.clock > s.clock and e + 1 < ns.clock \
                and s.owner[e] is not None \
                and (s.owner[e], e, "LIVENESS") not in ns.settled_certs:
            return (f"epoch {e} window-close resolution did not settle T{s.owner[e]}'s "
                    f"LIVENESS certificate on {label}")
    return None


def edge_typed_seal(s: State, ns: State, label: str):
    # v10 (r9-D2): seals are TYPED. A proof-free (empty-typed) closure must never close a
    # CONTENT-decided epoch -- the content outcome exists only through its proof (I1; I7
    # lists exactly the valid EMPTY seal and the expiry cancellation as proof-free) --
    # and, symmetrically, a proof-carrying content seal must consume a CONTENT decision.
    oe = s.openEpoch
    if oe < NEPOCHS and label.startswith("seal_empty") and s.status[oe] == CONTENT:
        return (f"proof-free (empty-typed) closure sealed CONTENT-decided epoch {oe} "
                f"on {label} (I1)")
    if oe < NEPOCHS and label.startswith("seal_content") and s.status[oe] != CONTENT:
        return f"proof-carrying content seal on {s.status[oe]} epoch {oe} on {label}"
    return None


def edge_no_seal_after_expiry(s: State, ns: State, label: str):
    # v10 (r9-B5; design 6.7 r9-F2 mechanical cutoff): seals are valid strictly BEFORE
    # the epoch's expiry T_exp; cancellation at/after it; never both. Path-independent
    # form: no transition may close an expired CONTENT openEpoch as SEALED.
    oe = s.openEpoch
    if oe < NEPOCHS and s.status[oe] == CONTENT and s.openAge[oe] > CANCEL_LAG \
            and ns.status[oe] == SEALED:
        return (f"epoch {oe} sealed at/after its expiry (openAge {s.openAge[oe]} > "
                f"CANCEL_LAG {CANCEL_LAG}) on {label} -- seal/cancel overlap (6.7)")
    return None


def edge_equivocation_settles(s: State, ns: State, label: str):
    # v10 (r9-D4; design 8 variant (a)): an equivocation -- a second distinct accepted
    # commit artifact -- must ATOMICALLY settle an L1-direct SAFETY certificate against
    # the equivocating tenure AND terminate it (no still-SEQ epoch may remain assigned
    # to it after the transition).
    if not label.startswith("equivocate(T"):
        return None
    inner = label[len("equivocate(T"):-1]     # "t,e<e>"
    t_str, e_str = inner.split(",e")
    t, e = int(t_str), int(e_str)
    if (t, e, "SAFETY") not in ns.settled_certs:
        return f"{label} settled no L1-direct SAFETY certificate (design 8)"
    for e2 in range(NEPOCHS):
        if ns.status[e2] == SEQ and ns.owner[e2] == t:
            return (f"{label}: equivocating tenure T{t} still owns SEQ epoch {e2} "
                    f"(not terminated)")
    return None


def edge_empty_respects_phase(s: State, ns: State, label: str):
    # v11 two-sided cutoff, EMPTY side (design 9.1; round-2 finding 6 horn 2, r10-1/2): an
    # UNOWNED, non-forced epoch may resolve EMPTY only AT/AFTER its proposal cutoff. A
    # proof-free empty landing inside the phase is exactly the empty-front-running horn that
    # killed the v7 restoration. Identified structurally (unowned non-forced SEQ -> EMPTY;
    # miss_commit requires an owner, so it can never trip this). The cutoff is read on the
    # PRE-state (path-independent); the RESOLUTION clock is the POST-state clock -- for a
    # `decide` the two coincide, and for the r9-D1 window-closing tick (which auto-resolves an
    # undecided unowned epoch to EMPTY as the clock advances) the resolution genuinely happens
    # at the new clock, which for W_ANARCHY <= 2 is always AT/AFTER the cutoff (cutoff <= e+2,
    # the auto-resolution clock), so the tick never false-trips this check.
    for e in range(NEPOCHS):
        if s.status[e] == SEQ and ns.status[e] == EMPTY and s.owner[e] is None \
                and not s.fqueue[e]:
            cut = _anarchy_cutoff(s, e)
            if ns.clock < cut:
                return (f"epoch {e} resolved EMPTY at clock {ns.clock}, inside its anarchy "
                        f"proposal phase (cutoff {cut}) on {label}")
    return None


def edge_proposal_respects_phase(s: State, ns: State, label: str):
    # v11 two-sided cutoff, PROPOSAL side (design 9.1, r10-1/3): an anarchy proposal
    # (structurally: unowned SEQ -> SEALED; no other action in this model produces that step)
    # is valid only for the openEpoch, at/after its boundary, STRICTLY before its cutoff, in
    # NORMAL mode, outside a proving outage. A proposal at/after the cutoff would flip an
    # already-determined outcome; one past an owned successor's start (the truncation term of
    # _anarchy_cutoff) would leave that holder sequencing on an undetermined parent. Read on
    # the PRE-state; a proposal does not advance the clock, so s.clock is the proposal clock.
    for e in range(NEPOCHS):
        if s.status[e] == SEQ and ns.status[e] == SEALED and s.owner[e] is None:
            cut = _anarchy_cutoff(s, e)
            if e != s.openEpoch or s.clock < e or s.clock >= cut \
                    or s.mode != NORMAL or s.outage:
                return (f"anarchy proposal for epoch {e} outside its phase on {label} "
                        f"(clock {s.clock}, cutoff {cut}, openEpoch {s.openEpoch}, "
                        f"mode {s.mode}, outage {s.outage})")
    return None


EDGE_INVARIANTS = [
    edge_open_monotone, edge_evidence_monotone, edge_debit_conservation,
    edge_maturity_materialized, edge_seal_immutable, edge_decision_deadline,
    edge_typed_seal, edge_no_seal_after_expiry, edge_equivocation_settles,
    edge_empty_respects_phase, edge_proposal_respects_phase,
]


# ---------------------------------------------------------------------------
# Exhaustive BFS with invariant checking + liveness (halt) post-analysis.
# ---------------------------------------------------------------------------
@dataclass
class ExploreResult:
    states: list
    parent: dict
    edges: dict
    violations: list
    halts: list = field(default_factory=list)
    goals: set = field(default_factory=set)
    live: int = 0            # number of states from which the goal is reachable (standard)
    robust_live: int = 0     # same over the outage-robust sub-relation
    depth_std: int = -1        # worst-case shortest path to a goal (standard), r9-D6
    depth_robust: int = -1     # same over the outage-robust sub-relation
    truncated: bool = False    # state cap hit -- NEVER a silent condition (fails exit code)
    max_debit: int = 0         # observed max cumulative per-tenure debit (r9-D7)
    max_debit_tenure: Optional[int] = None


def explore(stop_on_violation=False, stop_on_inv=None):
    # stop_on_inv (round-8 S1): when set to an invariant name, the exploration keeps running
    # PAST unrelated violations and early-exits only once the NAMED invariant has fired. This
    # makes the mutation self-test robust: an incidental violation from another invariant can
    # no longer mask (false-MISSED) the invariant a mutant is meant to trip.
    from array import array
    visited = {}                 # key -> id
    parent_id = array("i")       # id -> parent id (-1 for INIT)
    parent_lbl = []              # id -> action label (interned)
    states = []                  # id -> State
    closed_hist = []             # id -> dict(epoch->closed status) snapshot (shared)
    violations = []
    max_debit = 0
    max_debit_tenure = None
    # memory hygiene at multi-million-state bounds: action labels repeat massively
    # (intern them) and closed-history snapshots take few distinct values (share them).
    _label_cache = {}
    _snap_cache = {}

    def _canon_label(lbl):
        r = _label_cache.get(lbl)
        if r is None:
            _label_cache[lbl] = lbl
            r = lbl
        return r

    def _canon_snap(d):
        k = tuple(sorted(d.items()))
        r = _snap_cache.get(k)
        if r is None:
            _snap_cache[k] = d
            r = d
        return r

    def sid(st, prev_id, action, closed_snapshot):
        k = st.key()
        if k in visited:
            return visited[k], False
        i = len(states)
        visited[k] = i
        states.append(st)
        parent_id.append(-1 if prev_id is None else prev_id)
        parent_lbl.append(action)
        closed_hist.append(closed_snapshot)
        return i, True

    q = deque()
    seen_init = set()
    for st in initial_states():
        k = st.key()
        if k in seen_init:
            continue
        seen_init.add(k)
        closed_snap = {e: st.status[e] for e in range(NEPOCHS) if st.status[e] in CLOSED}
        i, is_new = sid(st, None, "INIT", _canon_snap(closed_snap))
        if is_new:
            q.append(i)

    # BFS. Edges are stored CSR-style (flat child array + per-state offsets) -- BFS
    # processes states in id order (FIFO over discovery-ordered ids), so offsets can be
    # built incrementally; this keeps the multi-million-edge graph in flat arrays.
    edge_start = array("l", [0])  # edge_start[i]..edge_start[i+1] index edge_child
    edge_child = array("i")       # flat child ids
    goal_states = set()           # r9-B5 goal: all epochs closed AND all forced work terminal
    STATE_CAP = 14_000_000
    processed = 0

    def _stop():
        if not violations:
            return False
        if stop_on_inv is not None:
            return any(name == stop_on_inv for (_k, name, _i, _m) in violations)
        return stop_on_violation

    while q:
        i = q.popleft()
        processed += 1
        if processed % 200000 == 0:
            print(f"#   ... processed={processed} discovered={len(states)} queue={len(q)}",
                  file=sys.stderr)
        if len(states) > STATE_CAP:
            # NEVER silently truncate: the flag fails the exit code like a violation does.
            # (No liveness analysis on a partial graph -- it would be meaningless.)
            print(f"# STATE CAP {STATE_CAP} hit; exploration TRUNCATED -- results are not "
                  f"exhaustive (increase cap or shrink bound). This run FAILS.",
                  file=sys.stderr)
            return ExploreResult(states, (parent_id, parent_lbl), None, violations,
                                 truncated=True)
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
        if _stop():
            return ExploreResult(states, (parent_id, parent_lbl), None, violations)

        # (r9-D7) observed worst-case cumulative debit per tenure, over ALL reachable
        # states -- the checked counterpart of the RESERVE0 admission-sizing formula.
        if s.consumed:
            per = [0] * NTENURES
            for (o, _e, _c) in s.consumed:
                per[o] += L_LIVE
            for t in range(NTENURES):
                if per[t] > max_debit:
                    max_debit = per[t]
                    max_debit_tenure = t

        # goal (r9-B5): all epochs closed AND every forced item terminal (consumed or
        # refunded == no live snapshot anywhere). All-closed alone is no longer the goal:
        # forced work stranded live at the horizon must surface as a halt, not be waved
        # through.
        if s.openEpoch >= NEPOCHS and not any(s.fqueue):
            goal_states.add(i)

        succ = actions(s)
        assert i == len(edge_start) - 1   # id order == processing order (CSR premise)
        for label, ns in succ:
            label = _canon_label(label)
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
            j, is_new = sid(ns, i, label, _canon_snap(child_closed))
            edge_child.append(j)   # child ids only: labels are checked above, not stored
            if is_new:
                q.append(j)
        edge_start.append(len(edge_child))
        if _stop():
            return ExploreResult(states, (parent_id, parent_lbl), None, violations)

    # Liveness / halt analysis, two passes (v9):
    #
    # (1) STANDARD: a state is "live" if some path reaches the goal (all closed + all
    #     forced work terminal, r9-B5).
    # (2) OUTAGE-ROBUST (round-7 finding 3): the same, over the sub-relation that
    #     EXCLUDES `outage_end` -- i.e. the goal must be reachable even if an active
    #     proving outage never lifts. Without this pass, an exists-path analysis could
    #     always "un-outage" its way to the goal, making the outage model vacuous:
    #     the design's proof-free floor (empty seals, void closure, cancellation with
    #     re-queue and the modeled refund) is exactly what this pass verifies.
    #
    # Both passes are breadth-first from the goal set, so they also yield each state's
    # SHORTEST path length to a goal; the maximum over reachable states is the
    # worst-case forced-march to finalization (r9-D6) -- the model-scale quantification
    # of the design's "one cascade per H_cancel" throughput consequence (r9-A4).
    # Reverse graph, CSR via counting sort over the flat edge arrays (built once,
    # traversed by both passes; flat arrays keep the 10^8-edge graph affordable).
    nstates = len(states)
    nedges = len(edge_child)
    indeg = array("l", bytes(8 * (nstates + 1)))
    for j in edge_child:
        indeg[j] += 1
    rev_start = array("l", bytes(8 * (nstates + 1)))
    acc = 0
    for j in range(nstates):
        rev_start[j] = acc
        acc += indeg[j]
    rev_start[nstates] = acc
    rev_parent = array("i", bytes(4 * nedges))
    cursor = array("l", rev_start[:-1])
    for i in range(nstates):
        for k in range(edge_start[i], edge_start[i + 1]):
            j = edge_child[k]
            rev_parent[cursor[j]] = i
            cursor[j] += 1
    del indeg, cursor

    def _backward(exclude_outage_end=False):
        # `outage_end` is the only action that flips the outage flag off, so the
        # excluded sub-relation is identified structurally (outage True -> False)
        # rather than by stored labels (edges keep child ids only, for memory).
        dist = array("i", bytes(4 * nstates))
        for j in range(nstates):
            dist[j] = -1
        dq = deque(goal_states)
        for j in goal_states:
            dist[j] = 0
        while dq:
            j = dq.popleft()
            dj = dist[j]
            j_outage = states[j].outage
            for k in range(rev_start[j], rev_start[j + 1]):
                i = rev_parent[k]
                if dist[i] < 0:
                    if exclude_outage_end and not j_outage and states[i].outage:
                        continue   # this edge is the excluded outage_end
                    dist[i] = dj + 1
                    dq.append(i)
        return dist

    dist_std = _backward()
    dist_rob = _backward(exclude_outage_end=True)
    depth_std = max(dist_std) if nstates else -1
    depth_rob = max(dist_rob) if nstates else -1

    # A halt (G5/I3 violation) = a reachable, non-goal state that cannot reach the goal
    # -- in the standard relation, or (strictly stronger) in the never-un-outage
    # relation. With MAXCLOCK >= NEPOCHS*CANCEL_LAG+3 these are genuine halt candidates;
    # with a smaller horizon they may be bound artifacts -- main() warns.
    halts = []
    for i in range(nstates):
        if i in goal_states:
            continue
        if dist_std[i] >= 0 and dist_rob[i] >= 0:
            continue
        kind = "standard" if dist_std[i] < 0 else "outage-robust"
        halts.append((i, edge_start[i + 1] > edge_start[i], kind))

    # Scope of the liveness result (round-8 W1). Backward-reachability establishes exactly
    # DEADLOCK-FREEDOM: every reachable state -- every strongly-connected component included --
    # has a path to a fully-finalized terminal, so there is NO reachable "terminal-avoiding
    # trap" (an SCC from which finalization is unreachable). What it does NOT establish, and
    # what NO checker of this model can, is livelock-freedom under a fully *unfair* scheduler:
    # because every action (the tick, the permissionless advancing seal/cancel, even toggling
    # the outage flag) is adversary-selectable, the non-terminal subgraph is full of cycles an
    # adversary could loop in forever by simply declining the advancing action. That residual
    # is inherent to *any* permissionless-liveness property and is resolved at the protocol
    # layer, not in the model: the advancing action is open to every honest party, so under the
    # standard weak-fairness assumption (an always-enabled permissionless action is eventually
    # taken by someone honest) deadlock-freedom upgrades to finalization. RESULTS.md states
    # the claim in exactly these terms rather than the unqualified "no permanent halt".
    n_live = sum(1 for d in dist_std if d >= 0)
    n_rob = sum(1 for d in dist_rob if d >= 0)
    return ExploreResult(states, (parent_id, parent_lbl), None, violations, halts,
                         goal_states, n_live, n_rob,
                         depth_std, depth_rob, False, max_debit, max_debit_tenure)


def trace(parent, states, i):
    parent_id, parent_lbl = parent
    path = []
    while i is not None and i >= 0:
        path.append((parent_lbl[i], i))
        i = parent_id[i]
        if i < 0:
            break
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
    "reopen_sealed":        "edge_seal_immutable",        # re-open a CLOSED epoch (round-8 W2)
    "undersized_reserve":   "inv_bond_nonneg",            # admission under-collateralized (round-8 W3)
    # v10 mutants (round-9):
    "late_decide":          "edge_decision_deadline",     # decisions un-deadlined again (r9-D1):
                                                          # no window auto-resolution, decides
                                                          # allowed past the window
    "empty_seal_steals_content": "edge_typed_seal",       # proof-free closure claims a CONTENT
                                                          # epoch (r9-D2; breaks I1)
    "equivocation_flips_decision": "inv_single_decision", # 2nd accepted EBC replaces the
                                                          # decision (r9-D4; one-shot broken)
    "equivocation_no_cert": "edge_equivocation_settles",  # equivocation settles no SAFETY
                                                          # certificate (r9-D4; design 8)
    "seal_after_expiry":    "edge_no_seal_after_expiry",  # seal stays enabled at/after T_exp
                                                          # (r9-B5; the 6.7 overlap bug)
    "requeue_reorders":     "inv_forced_order",           # cascade re-queue breaks original
                                                          # queue order (r9-D3; r4b-M8)
    # v11 anarchy proposal phase (design section 9, round 10):
    "anarchy_empty_in_phase":      "edge_empty_respects_phase",    # horn 2: empty front-runs the phase
    "anarchy_propose_after_close": "edge_proposal_respects_phase", # late proposal flips a determined outcome
    "nonatomic_anarchy_propose":   "inv_anarchy_content_sealed",   # horn 1: proposal locks unsealed content
    "anarchy_ignores_ownership":   "edge_proposal_respects_phase", # proposal past an owned successor's start
                                                                   # (needs W_ANARCHY=2 so the truncation
                                                                   # term binds; self-test sets it)
    # Liveness mutant -- the bug manifests as a permanent halt (a reachable state from which
    # NO exit path exists), which the deadlock-freedom analysis must catch.
    "outage_blocks_empty":  "LIVENESS_HALT",              # a permanent outage becomes a halt
}


def run_mutation_tests():
    """Self-test: each mutant deliberately breaks the design; the checker MUST catch it.

    v10 validity protocol (r9-B5): for each mutant the harness
      (a) first runs the UNMUTATED baseline at that mutant's bound and requires it CLEAN
          (no violation, no halt, no truncation) -- if the baseline is not clean there,
          the harness FAILS with an explicit error instead of "validating" the mutant at
          a bound where the checker already fires;
      (b) then runs the mutant and requires a counterexample attributed to the EXPECTED
          invariant (the stop_on_inv mechanism -- incidental co-firing of other
          invariants cannot mask or fake the expected one);
      (c) runs the liveness (outage) mutant at a bound whose baseline OUTAGE-ROBUST pass
          is clean, so the halts it produces are attributable to the injected bug alone.
    All mutants run at 2x5 -- the smallest bound whose baseline is FULLY clean under the
    v10 model, outage-robust liveness included (per-epoch tolled expiry needs MAXCLOCK >=
    NEPOCHS*CANCEL_LAG + 3; the old 3x3/3x4 mutant bounds are invalid under v10 --
    their baseline outage-robust passes report horizon artifacts, and the harness would
    refuse them). Every mutant's counterexample is reachable at 2x5, including
    `requeue_reorders` (cancel e0 carrying item 0 into a still-SEQ e1 holding its own
    item 1: the buggy back-placement yields the out-of-order queue (1, 0)) and the
    liveness mutant (an EMPTY epoch plus a never-lifting outage).

    v11 anarchy mutants: `anarchy_empty_in_phase`, `anarchy_propose_after_close` and
    `nonatomic_anarchy_propose` run at the merged default W_ANARCHY=1; `anarchy_ignores_
    ownership` runs at W_ANARCHY=2 so the min(e+W, first-owned) truncation term actually
    binds (an owned epoch at e+1 undercuts e+2). Baseline cleanliness is W_ANARCHY-dependent
    (the phase reshapes the unowned-epoch resolutions), so the baseline-clean check and its
    cache are keyed by (bound, W_ANARCHY)."""
    global MUTANT, NEPOCHS, MAXCLOCK, RESERVE0, W_ANARCHY
    print("# MUTATION SELF-TEST (each injected bug MUST be caught by the named invariant)")
    print("# validity protocol (r9-B5): per-mutant baseline-clean check, then attributed catch")
    MUT_BOUND = (2, 5)

    def mut_w(mut):
        # W_ANARCHY the mutant runs at (v11): the ownership-truncation mutant needs 2, all
        # others the merged default 1.
        return 2 if mut == "anarchy_ignores_ownership" else 1

    baseline_cache = {}

    def baseline_clean(bound, w):
        if (bound, w) in baseline_cache:
            return baseline_cache[(bound, w)]
        global MUTANT, NEPOCHS, MAXCLOCK, RESERVE0, W_ANARCHY
        MUTANT = None
        NEPOCHS, MAXCLOCK = bound
        W_ANARCHY = w
        RESERVE0 = 3 * NEPOCHS + 1
        r = explore()
        clean = (not r.violations) and (not r.halts) and (not r.truncated)
        baseline_cache[(bound, w)] = clean
        print(f"  baseline @ {bound[0]}x{bound[1]} W_ANARCHY={w}: "
              f"{'CLEAN' if clean else 'NOT CLEAN'} ({len(r.states)} states, "
              f"{len(r.violations)} violations, {len(r.halts)} halts"
              f"{', TRUNCATED' if r.truncated else ''})")
        return clean

    all_caught = True
    for mut, expected_inv in MUTANTS.items():
        bound = MUT_BOUND
        w = mut_w(mut)
        if not baseline_clean(bound, w):
            print(f"  mutant '{mut}' @ {bound[0]}x{bound[1]} W_ANARCHY={w}: HARNESS ERROR -- "
                  f"baseline not clean at this bound; a catch here would be unattributable. FAIL.")
            all_caught = False
            continue
        NEPOCHS, MAXCLOCK = bound
        W_ANARCHY = w
        RESERVE0 = 3 * NEPOCHS + 1
        MUTANT = mut
        if expected_inv == "LIVENESS_HALT":
            # liveness mutant: the bug manifests as a permanent halt (a reachable state with
            # no exit path), so run the full exploration and require the halt analysis to
            # fire. The baseline outage-robust pass is clean at this bound (protocol (c)),
            # so every halt is the injected bug's.
            r = explore()
            ok = bool(r.halts) and not r.truncated
            all_caught &= ok
            status = "CAUGHT" if ok else "!! MISSED !!"
            print(f"  mutant '{mut}' @ {bound[0]}x{bound[1]} [baseline clean] -> expect a "
                  f"permanent halt: {status} ({len(r.halts)} halt state(s) found)")
            continue
        if mut == "undersized_reserve":
            # shrink admission collateral below the worst case so a debit drives a reserve
            # negative -> inv_bond_nonneg; restore afterwards.
            RESERVE0 = 0
        # stop_on_inv keeps exploring past incidental violations and exits only once the
        # EXPECTED invariant fires, so an unrelated invariant can't false-MISS the mutant (S1).
        r = explore(stop_on_inv=expected_inv)
        if mut == "undersized_reserve":
            RESERVE0 = 3 * NEPOCHS + 1
        caught = {name for (_k, name, _i, _m) in r.violations}
        ok = expected_inv in caught
        all_caught &= ok
        status = "CAUGHT" if ok else "!! MISSED !!"
        print(f"  mutant '{mut}' @ {bound[0]}x{bound[1]} [baseline clean] -> expect "
              f"{expected_inv}: {status} (invariants tripped: {sorted(caught) or 'none'})")
    MUTANT = None
    W_ANARCHY = 1
    print(f"# mutation self-test: "
          f"{'ALL BUGS CAUGHT (invariants have teeth)' if all_caught else 'SOME MISSED / HARNESS ERROR'}")
    return all_caught


def main():
    global NEPOCHS, MAXCLOCK, RESERVE0, S_TICKS, CANCEL_LAG, W_ANARCHY
    import os
    args = sys.argv[1:]
    if args and args[0] == "--mutate":
        return 0 if run_mutation_tests() else 1
    # v11: W_ANARCHY may be set by env (e.g. `W_ANARCHY=0 python3 model_checker.py`), then
    # overridden by `--w-anarchy N` or a 3rd positional arg below. 0 disables the anarchy
    # lane and reproduces the pre-anarchy v10 model bit-for-bit.
    env_w = os.environ.get("W_ANARCHY")
    if env_w is not None:
        W_ANARCHY = int(env_w)
    pos = []
    i = 0
    while i < len(args):
        if args[i] == "--sticks":
            S_TICKS = int(args[i + 1])
            i += 2
            continue
        if args[i] == "--cancel-lag":
            # scale the per-epoch expiry with a longer seal deadline (keep >= S_TICKS
            # so the matured-fault-then-late-seal orderings stay reachable)
            CANCEL_LAG = int(args[i + 1])
            i += 2
            continue
        if args[i] == "--w-anarchy":
            W_ANARCHY = int(args[i + 1])   # v11 anarchy proposal-phase length (0 disables)
            i += 2
            continue
        pos.append(int(args[i]))
        i += 1
    if len(pos) >= 2:
        NEPOCHS, MAXCLOCK = pos[0], pos[1]
        RESERVE0 = 3 * NEPOCHS + 1   # re-size collateral to the new epoch count (round-8 W3)
    if len(pos) >= 3:
        W_ANARCHY = pos[2]   # 3rd positional arg mirrors the owner's CLI (v11)
    print(f"# v10+v11 protocol state-machine model check "
          f"(D1-D7 checker-validity upgrade + anarchy proposal phase)")
    print(f"# params: NEPOCHS={NEPOCHS} MAXCLOCK={MAXCLOCK} K={K} CANCEL_LAG={CANCEL_LAG} "
          f"S_TICKS={S_TICKS} W_ANARCHY={W_ANARCHY} NTENURES={NTENURES} RESERVE0={RESERVE0}")
    if CANCEL_LAG < S_TICKS:
        print(f"# WARNING: CANCEL_LAG ({CANCEL_LAG}) < S_TICKS ({S_TICKS}): the per-epoch "
              f"expiry disables seals before the seal deadline can even mature, so the "
              f"missed-seal-then-late-seal orderings are unreachable. Use CANCEL_LAG >= "
              f"S_TICKS.")
    if MAXCLOCK < NEPOCHS - 1:
        print(f"# WARNING: MAXCLOCK ({MAXCLOCK}) < NEPOCHS-1 ({NEPOCHS - 1}): tail epochs "
              f"are undecidable within the horizon, so reported halts will include bound "
              f"artifacts. Use MAXCLOCK >= NEPOCHS-1 for meaningful liveness results.")
    elif MAXCLOCK < NEPOCHS * CANCEL_LAG + 3:
        print(f"# WARNING: MAXCLOCK ({MAXCLOCK}) < NEPOCHS*CANCEL_LAG+3 "
              f"({NEPOCHS * CANCEL_LAG + 3}): per-epoch tolled expiry serializes "
              f"cancellation chains -- each CONTENT epoch in an all-forced backlog can "
              f"delay its successor's tolled clock by up to CANCEL_LAG valid-seal "
              f"ticks, and the last epoch still needs CANCEL_LAG+1 fresh ticks to its "
              f"expiry (the design's one-cascade-per-H_cancel cadence, r9-A4) -- so "
              f"the outage-robust pass will report horizon artifacts at this bound. "
              f"Use MAXCLOCK >= {NEPOCHS * CANCEL_LAG + 3} for meaningful liveness "
              f"results.")
    r = explore()
    if r.truncated:
        print(f"# ERROR: exploration truncated at the state cap -- results above are NOT "
              f"exhaustive and this run fails. Raise STATE_CAP or shrink the bound.")
        return 2
    print(f"# reachable states explored: {len(r.states)}")
    print(f"# terminal (all epochs closed AND all forced items terminal) states: "
          f"{len(r.goals)}")
    print(f"# states from which the goal is reachable (live): {r.live}")

    print("\n## SAFETY invariant violations (state + edge)")
    if not r.violations:
        print("  NONE - no reachable state or transition violates any safety invariant.")
    else:
        # de-dup by (invariant, msg-shape)
        seen = set()
        for kind, name, i2, msg in r.violations:
            sig = (name, msg.split("(")[0][:40])
            if sig in seen:
                continue
            seen.add(sig)
            print(f"  [{name}] {msg}")
            for a, j in trace(r.parent, r.states, i2):
                print(f"      {a}")
        print(f"  total raw violations: {len(r.violations)} (distinct shapes: {len(seen)})")

    print("\n## LIVENESS — deadlock-freedom (standard AND outage-robust); round-8 W1 scoping")
    # Precise property (round-8 W1): this is DEADLOCK-freedom — from every reachable state an
    # exit path to full finalization (all epochs closed AND all forced work consumed or
    # refunded — the r9-B5 goal) exists, in the standard relation and in the outage-robust
    # sub-relation (the goal stays reachable even if a proving outage never lifts). It is
    # NOT unconditional livelock-freedom under a fully unfair scheduler — inherent to any
    # permissionless-liveness property and out of scope for the checker; the protocol
    # supplies the missing weak-fairness (the advancing action is permissionless, so an
    # honest party eventually takes it). See RESULTS.md.
    if not r.halts:
        print("  NONE - every reachable non-terminal state can still reach a fully-final "
              "chain with every forced item consumed or refunded, and can do so even if an "
              "active proving outage never lifts (deadlock-freedom; livelock under a fully "
              "unfair scheduler is out of scope — resolved by the permissionlessness of the "
              "advancing action).")
    else:
        std = [h for h in r.halts if h[2] == "standard"]
        rob = [h for h in r.halts if h[2] == "outage-robust"]
        deadend = [h for h in r.halts if not h[1]]
        print(f"  states unable to reach the goal within horizon: {len(r.halts)}")
        print(f"    - standard (no exit path at all): {len(std)}")
        print(f"    - outage-robust only (every exit needs the outage to lift): {len(rob)}")
        print(f"    - true dead-ends (no enabled action): {len(deadend)}")
        for (i2, hs, kind) in r.halts[:2]:
            s = r.states[i2]
            print(f"  representative ({kind}): openEpoch={s.openEpoch} clock={s.clock} "
                  f"mode={s.mode} outage={s.outage} status={s.status} fqueue={s.fqueue}")
            for a, j in trace(r.parent, r.states, i2):
                print(f"      {a}")

    # (r9-D6) worst-case forced-march to finalization: the maximum over reachable states
    # of the SHORTEST path (in transitions) to a goal state. The robust number is the
    # depth of the pure proof-free exit (empty seals, void closures, expiry cancellations
    # with re-queue/refund) -- the model-scale quantification of the design's honest
    # "one cascade per H_cancel" worst-case cadence (r9-A4).
    print("\n## WORST-CASE DEPTH to full finalization (r9-D6)")
    print(f"  standard relation:       {r.depth_std} transitions")
    print(f"  outage-robust relation:  {r.depth_robust} transitions")

    # (r9-D7) RESERVE0 sufficiency: the admission-sizing formula is now a CHECKED bound.
    print("\n## RESERVE0 sufficiency (r9-D7)")
    print(f"  observed max cumulative debit per tenure: {r.max_debit}"
          + (f" (tenure T{r.max_debit_tenure})" if r.max_debit_tenure is not None else ""))
    print(f"  RESERVE0 = {RESERVE0}  ->  slack = {RESERVE0 - r.max_debit}")
    reserve_ok = RESERVE0 >= r.max_debit
    if not reserve_ok:
        print("  INSUFFICIENT: the admission formula does not cover the observed worst "
              "case -- under-collateralization (this also surfaces as inv_bond_nonneg).")

    # exit code: halts fail the run exactly like safety violations do (deadlock-freedom is a
    # headline property; automation must not treat a halting model as passing), and so do a
    # truncated exploration and an insufficient RESERVE0.
    bad = bool(r.violations) or bool(r.halts) or (not reserve_ok)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
