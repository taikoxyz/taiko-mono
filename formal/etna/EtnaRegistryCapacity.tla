---------------------- MODULE EtnaRegistryCapacity ----------------------
EXTENDS Integers

CONSTANTS MaxTime, Penalties, ReporterRecycle, SinkRecycle, Landing, RecordCalls, Probe
ASSUME /\ MaxTime \in 2..7
       /\ {Penalties, ReporterRecycle, SinkRecycle, Landing, RecordCalls} \subseteq BOOLEAN
       /\ Probe \in {"None", "Reporter", "Sink", "Funded", "Stalled", "Progress", "Pending"}

VARIABLES r, last, marks, frameOK
vars == <<r, last, marks, frameOK>>

Slots == 0..1
Ids == 0..2
Supply == 7
Stake == 4
Owner == 1
Public == 2
DAO == 3
NoExit == 11

EmptySlot == [occupied |-> FALSE, bond |-> 0]
EmptyBond == [issued |-> FALSE, withdrawn |-> FALSE, key |-> 0, owner |-> 0,
              eff |-> 0, pending |-> 0, active |-> 0, exit |-> 0, confirmed |-> 0,
              holds |-> FALSE, slot |-> 0, ready |-> 0, topupUsed |-> FALSE,
              forfeited |-> FALSE, sinkPaid |-> 0]
EmptySelection == [at |-> 0, powers |-> [i \in Ids |-> 0]]
Call(kind, bond, actor, key, amount, snapshot) ==
  [kind |-> kind, bond |-> bond, actor |-> actor, key |-> key, amount |-> amount,
   snapshot |-> snapshot]
NoCall == [call |-> Call("None", 0, 0, 0, 0, 0), accepted |-> FALSE]
Profile == [maxTime |-> MaxTime, penalties |-> Penalties, reporter |-> ReporterRecycle,
            sink |-> SinkRecycle, landing |-> Landing, record |-> RecordCalls, probe |-> Probe]
Init ==
  /\ r = [now |-> 1, nextId |-> 0,
          slots |-> [s \in Slots |-> EmptySlot], bonds |-> [i \in Ids |-> EmptyBond],
          cash |-> [liquid |-> Supply, reporter |-> 0, sink |-> 0],
          coverage |-> 0, closed |-> EmptySelection, recoveredAt |-> 0,
          recovery |-> EmptySelection, landedAt |-> 0]
  /\ last = NoCall /\ frameOK = TRUE
  /\ marks = [profile |-> Profile, reporter |-> FALSE, sink |-> FALSE, funded |-> FALSE,
              stallConfirm |-> FALSE, stallWithdraw |-> FALSE, stallFull |-> FALSE,
              early |-> FALSE, released |-> FALSE, unfunded |-> FALSE,
              positiveDenied |-> FALSE, positivePaid |-> FALSE]

Balance(b) == b.eff + b.pending
Live(b) == b.issued /\ ~b.withdrawn
Minimum(x, y) == IF x <= y THEN x ELSE y

\* Operational state and inputs. Observation never affects offered calls.
Holes == {s \in Slots : ~r.slots[s].occupied}
Lowest == CHOOSE s \in Holes : \A t \in Holes : s <= t
Close ==
  [at |-> r.now, powers |-> [i \in Ids |->
    LET b == r.bonds[i] IN
      IF b.holds /\ b.active <= r.now /\ r.now < b.exit THEN b.eff ELSE 0]]
HasMembers(selection) == \E i \in Ids : selection.powers[i] > 0
Maybe(allowed, call) == IF allowed THEN {call} ELSE {}

BondOffers(i) ==
  LET b == r.bonds[i] IN
    IF ~Live(b) THEN {} ELSE
      {Call("Activate", i, Public, 0, 0, 0), Call("Exit", i, Owner, 0, 0, 0),
       Call("Confirm", i, Public, 0, 0, 0), Call("Withdraw", i, Owner, 0, 0, 0),
       Call("Withdraw", i, Public, 0, 0, 0)}
      \cup Maybe(~b.topupUsed, Call("TopUp", i, Owner, 0, 1, 0))
      \cup (IF Penalties /\ r.coverage > 0
            THEN {Call("Slash", i, Public, 0, 0, 0), Call("Forfeit", i, DAO, b.key, 0, 0)}
            ELSE {})
Offers ==
  {Call("Register", 0, Owner, k, Stake, 0) : k \in {key \in Ids : key <= r.nextId}}
  \cup UNION {BondOffers(i) : i \in Ids}
  \cup Maybe(r.now < MaxTime, Call("Tick", 0, 0, 0, 0, 0))
  \cup Maybe(r.coverage = 0 /\ r.closed.at > 0, Call("Start", 0, 0, 0, 0, r.closed.at))
  \cup Maybe(r.coverage > 0 /\ r.recoveredAt = 0, Call("Recover", 0, 0, 0, 0, r.now))
  \cup Maybe(Landing /\ r.recovery.at > 0 /\ r.landedAt = 0,
             Call("Land", 0, 0, 0, 0, r.recovery.at))
  \cup Maybe(ReporterRecycle /\ r.cash.reporter > 0,
             Call("RecycleReporter", 0, 0, 0, r.cash.reporter, 0))
  \cup Maybe(SinkRecycle /\ r.cash.sink > 0, Call("RecycleSink", 0, 0, 0, r.cash.sink, 0))

CanApply(c) ==
  LET b == r.bonds[c.bond] IN
    CASE c.kind = "Register" -> c.key = r.nextId /\ Holes # {} /\ r.cash.liquid >= c.amount
      [] c.kind = "Start" -> HasMembers(r.closed)
      [] c.kind = "Land" -> HasMembers(r.recovery)
      [] c.kind = "TopUp" -> b.eff > 0 /\ b.active <= r.now /\ b.exit = NoExit
                                /\ b.pending = 0 /\ r.cash.liquid >= c.amount
      [] c.kind = "Activate" -> b.pending > 0 /\ b.ready <= r.now /\ b.exit = NoExit
      [] c.kind = "Exit" -> b.exit = NoExit
      [] c.kind = "Slash" -> Balance(b) > 0
      [] c.kind = "Forfeit" -> Balance(b) > 0 /\ ~b.forfeited
      [] c.kind = "Confirm" -> b.exit <= r.coverage
      [] c.kind = "Withdraw" -> b.confirmed > 0 /\ b.confirmed + 1 <= r.now
                                   /\ (Balance(b) = 0 \/ c.actor = b.owner)
      [] OTHER -> TRUE

Register(c) ==
  LET i == r.nextId
      s == Lowest
  IN [r EXCEPT !.nextId = @ + 1, !.slots[s] = [occupied |-> TRUE, bond |-> i],
       !.bonds[i] = [EmptyBond EXCEPT !.issued = TRUE, !.key = c.key, !.owner = c.actor,
                    !.eff = c.amount, !.active = r.now + 1, !.exit = NoExit,
                    !.holds = TRUE, !.slot = s],
       !.cash.liquid = @ - c.amount]

Apply(c) ==
  LET i == c.bond
      b == r.bonds[i]
      principal == Balance(b)
  IN CASE c.kind = "Register" -> Register(c)
       [] c.kind = "Tick" ->
            [r EXCEPT !.now = @ + 1, !.closed = IF r.coverage = 0 THEN Close ELSE @,
                      !.recovery = IF r.recoveredAt = r.now THEN Close ELSE @]
       [] c.kind = "Start" -> [r EXCEPT !.coverage = c.snapshot]
       [] c.kind = "Recover" -> [r EXCEPT !.recoveredAt = c.snapshot]
       [] c.kind = "Land" -> [r EXCEPT !.coverage = c.snapshot, !.landedAt = r.now]
       [] c.kind = "RecycleReporter" ->
            [r EXCEPT !.cash.reporter = @ - c.amount, !.cash.liquid = @ + c.amount]
       [] c.kind = "RecycleSink" ->
            [r EXCEPT !.cash.sink = @ - c.amount, !.cash.liquid = @ + c.amount]
       [] c.kind = "TopUp" ->
            [r EXCEPT !.cash.liquid = @ - c.amount, !.bonds[i].pending = c.amount,
                      !.bonds[i].ready = r.now + 1, !.bonds[i].topupUsed = TRUE]
       [] c.kind = "Activate" ->
            [r EXCEPT !.bonds[i].eff = principal, !.bonds[i].pending = 0, !.bonds[i].ready = 0]
       [] c.kind = "Exit" ->
            [r EXCEPT !.bonds[i].exit = (IF r.now < b.active THEN b.active ELSE r.now) + 1]
       [] c.kind = "Slash" ->
            LET reward == principal \div 4
                toSink == principal - reward
            IN [r EXCEPT !.bonds[i].eff = 0, !.bonds[i].pending = 0, !.bonds[i].ready = 0,
                         !.bonds[i].exit = Minimum(b.exit, r.now), !.bonds[i].sinkPaid = @ + toSink,
                         !.cash.reporter = @ + reward, !.cash.sink = @ + toSink]
       [] c.kind = "Forfeit" ->
            LET penalty == (principal + 1) \div 2
                debitEff == Minimum(penalty, b.eff)
                pending == b.pending - (penalty - debitEff)
            IN [r EXCEPT !.bonds[i].eff = @ - debitEff, !.bonds[i].pending = pending,
                         !.bonds[i].ready = IF pending = 0 THEN 0 ELSE @,
                         !.bonds[i].exit = Minimum(b.exit, r.now), !.bonds[i].forfeited = TRUE,
                         !.bonds[i].sinkPaid = @ + penalty, !.cash.sink = @ + penalty]
       [] c.kind = "Confirm" ->
            IF b.confirmed # 0 THEN r ELSE [r EXCEPT !.bonds[i].confirmed = r.now]
       [] c.kind = "Withdraw" ->
            [r EXCEPT !.cash.liquid = @ + principal, !.slots[b.slot] = EmptySlot,
                      !.bonds[i].withdrawn = TRUE, !.bonds[i].holds = FALSE, !.bonds[i].slot = 0,
                      !.bonds[i].owner = 0, !.bonds[i].eff = 0, !.bonds[i].pending = 0,
                      !.bonds[i].ready = 0, !.bonds[i].confirmed = 0]
       [] OTHER -> r

CoreStep(c, accepted) ==
  /\ c \in Offers
  /\ accepted = CanApply(c)
  /\ r' = IF accepted THEN Apply(c) ELSE r

\* Literal pre-state oracle. It enumerates a fixed superset of the offered
\* calls and computes acceptance and the frame without applying CoreStep.
Potential(p) ==
  {Call("Register", 0, 1, key, 4, 0) : key \in 0..2}
  \cup (UNION {{Call("Activate", i, 2, 0, 0, 0), Call("Exit", i, 1, 0, 0, 0),
                Call("Confirm", i, 2, 0, 0, 0), Call("Withdraw", i, 1, 0, 0, 0),
                Call("Withdraw", i, 2, 0, 0, 0), Call("TopUp", i, 1, 0, 1, 0),
                Call("Slash", i, 2, 0, 0, 0), Call("Forfeit", i, 3, i, 0, 0)}
               : i \in 0..2})
  \cup {Call("Tick", 0, 0, 0, 0, 0), Call("Start", 0, 0, 0, 0, p.closed.at),
        Call("Recover", 0, 0, 0, 0, p.now), Call("Land", 0, 0, 0, 0, p.recovery.at),
        Call("RecycleReporter", 0, 0, 0, p.cash.reporter, 0),
        Call("RecycleSink", 0, 0, 0, p.cash.sink, 0)}
LiteralOffered(p, c) ==
  /\ c \in Potential(p)
  /\ LET b == p.bonds[c.bond] IN
      CASE c.kind = "Register" -> c.key <= p.nextId
        [] c.kind = "Tick" -> p.now # MaxTime
        [] c.kind = "Start" -> p.coverage = 0 /\ p.closed.at # 0
        [] c.kind = "Recover" -> p.closed.at # 0 /\ p.coverage # 0 /\ p.recoveredAt = 0
        [] c.kind = "Land" -> Landing /\ p.recovery.at # 0 /\ p.landedAt = 0
        [] c.kind = "RecycleReporter" -> ReporterRecycle /\ c.amount # 0
        [] c.kind = "RecycleSink" -> SinkRecycle /\ c.amount # 0
        [] OTHER ->
             /\ b.issued /\ ~b.withdrawn
             /\ CASE c.kind = "TopUp" -> ~b.topupUsed
                  [] c.kind \in {"Slash", "Forfeit"} -> Penalties /\ p.coverage # 0
                  [] OTHER -> TRUE

LiteralPower(p, i) ==
  LET holds(s) == p.slots[s] = [occupied |-> TRUE, bond |-> i]
      b == p.bonds[i]
  IN IF (holds(0) \/ holds(1)) /\ p.now \in b.active..(b.exit - 1) THEN b.eff ELSE 0
FirstHole(p) == IF ~p.slots[0].occupied THEN 0 ELSE IF ~p.slots[1].occupied THEN 1 ELSE 2
LiteralAllowed(p, c) ==
  LET b == p.bonds[c.bond]
      principal == b.eff + b.pending
  IN CASE c.kind = "Register" -> c.key = p.nextId /\ p.cash.liquid >= 4 /\ FirstHole(p) < 2
       [] c.kind = "Start" -> p.closed.powers # EmptySelection.powers
       [] c.kind = "Land" -> p.recovery.powers # EmptySelection.powers
       [] c.kind = "TopUp" -> b.active <= p.now /\ b.eff # 0 /\ b.exit = NoExit /\ b.pending = 0 /\ p.cash.liquid # 0
       [] c.kind = "Activate" -> b.ready \in 1..p.now /\ b.pending # 0 /\ b.exit = NoExit
       [] c.kind = "Exit" -> b.exit = NoExit
       [] c.kind = "Slash" -> principal # 0
       [] c.kind = "Forfeit" -> principal # 0 /\ ~b.forfeited
       [] c.kind = "Confirm" -> b.exit \in 1..p.coverage
       [] c.kind = "Withdraw" -> b.confirmed \in 1..(p.now - 1)
                                   /\ (principal = 0 \/ c.actor = 1)
       [] OTHER -> TRUE

LiteralEffects(p, c) ==
  LET i == c.bond
      b == p.bonds[i]
      amount == b.eff + b.pending
      exit == IF p.now < b.exit THEN p.now ELSE b.exit
      cash == p.cash
  IN CASE c.kind = "Register" ->
            LET s == FirstHole(p)
                j == p.nextId
            IN [p EXCEPT !.nextId = j + 1, !.cash.liquid = cash.liquid - 4,
                         !.slots[s] = [occupied |-> TRUE, bond |-> j],
                         !.bonds[j] = [issued |-> TRUE, withdrawn |-> FALSE,
                           key |-> j, owner |-> 1, eff |-> 4, pending |-> 0, active |-> p.now + 1,
                           exit |-> NoExit, confirmed |-> 0, holds |-> TRUE, slot |-> s, ready |-> 0,
                           topupUsed |-> FALSE, forfeited |-> FALSE, sinkPaid |-> 0]]
       [] c.kind = "Tick" ->
            LET closed == [at |-> p.now, powers |-> [j \in 0..2 |-> LiteralPower(p, j)]]
            IN [p EXCEPT !.now = p.now + 1, !.closed = IF p.coverage # 0 THEN p.closed ELSE closed,
                         !.recovery = IF p.now = p.recoveredAt THEN closed ELSE p.recovery]
       [] c.kind = "Start" -> [p EXCEPT !.coverage = p.closed.at]
       [] c.kind = "Recover" -> [p EXCEPT !.recoveredAt = p.now]
       [] c.kind = "Land" -> [p EXCEPT !.coverage = p.recoveredAt, !.landedAt = p.now]
       [] c.kind = "TopUp" ->
            [p EXCEPT !.cash.liquid = cash.liquid - 1, !.bonds[i].pending = 1,
                      !.bonds[i].ready = p.now + 1, !.bonds[i].topupUsed = TRUE]
       [] c.kind = "Activate" ->
            [p EXCEPT !.bonds[i].eff = b.eff + b.pending, !.bonds[i].pending = 0, !.bonds[i].ready = 0]
       [] c.kind = "Exit" ->
            [p EXCEPT !.bonds[i].exit = IF b.active > p.now THEN b.active + 1 ELSE p.now + 1]
       [] c.kind = "Slash" ->
            LET reward == (amount - (amount % 4)) \div 4 IN
              [p EXCEPT !.cash.reporter = cash.reporter + reward,
                        !.cash.sink = cash.sink + amount - reward,
                        !.bonds[i].sinkPaid = b.sinkPaid + amount - reward,
                        !.bonds[i].eff = 0, !.bonds[i].pending = 0, !.bonds[i].ready = 0,
                        !.bonds[i].exit = exit]
       [] c.kind = "Forfeit" ->
            LET penalty == (amount \div 2) + (amount % 2)
                effective == IF penalty < b.eff THEN b.eff - penalty ELSE 0
                pending == amount - penalty - effective
            IN [p EXCEPT !.cash.sink = cash.sink + penalty,
                         !.bonds[i].sinkPaid = b.sinkPaid + penalty,
                         !.bonds[i].eff = effective, !.bonds[i].pending = pending,
                         !.bonds[i].ready = IF pending > 0 THEN b.ready ELSE 0,
                         !.bonds[i].exit = exit, !.bonds[i].forfeited = TRUE]
       [] c.kind = "RecycleReporter" ->
            [p EXCEPT !.cash.liquid = cash.liquid + cash.reporter, !.cash.reporter = 0]
       [] c.kind = "RecycleSink" ->
            [p EXCEPT !.cash.liquid = cash.liquid + cash.sink, !.cash.sink = 0]
       [] c.kind = "Confirm" ->
            [p EXCEPT !.bonds[i].confirmed = IF b.confirmed = 0 THEN p.now ELSE b.confirmed]
       [] c.kind = "Withdraw" ->
            [p EXCEPT !.slots[b.slot] = [occupied |-> FALSE, bond |-> 0],
                      !.cash.liquid = cash.liquid + b.eff + b.pending,
                      !.bonds[i] = [b EXCEPT !.withdrawn = TRUE, !.holds = FALSE, !.slot = 0,
                                    !.owner = 0, !.eff = 0, !.pending = 0, !.ready = 0,
                                    !.confirmed = 0]]
       [] OTHER -> p

OffersExact ==
  \A c \in Potential(r) \cup Offers :
    /\ (ENABLED CoreStep(c, TRUE)) <=> (LiteralOffered(r, c) /\ LiteralAllowed(r, c))
    /\ (ENABLED CoreStep(c, FALSE)) <=> (LiteralOffered(r, c) /\ ~LiteralAllowed(r, c))

Full(p) == p.slots[0].occupied /\ p.slots[1].occupied
CanonicalFull(p) ==
  /\ p.slots[0] = [occupied |-> TRUE, bond |-> 0]
  /\ p.slots[1] = [occupied |-> TRUE, bond |-> 1]
ReporterShape(p) ==
  /\ CanonicalFull(p)
  /\ p.cash = [liquid |-> 0, reporter |-> 0, sink |-> 3]
  /\ p.bonds[0].eff = 0 /\ p.bonds[0].pending = 0 /\ p.bonds[0].sinkPaid = 3
  /\ p.bonds[1].eff = 4 /\ p.bonds[1].pending = 0 /\ p.bonds[1].exit = NoExit
SinkShape(p) ==
  /\ CanonicalFull(p)
  /\ p.cash = [liquid |-> 1, reporter |-> 0, sink |-> 0]
  /\ p.bonds[0].forfeited /\ p.bonds[0].sinkPaid = 2
  /\ p.bonds[0].eff = 2 /\ p.bonds[0].pending = 0 /\ p.bonds[0].exit < NoExit
  /\ p.bonds[1].eff = 4 /\ p.bonds[1].pending = 0 /\ p.bonds[1].exit = NoExit
StalledGap(p) ==
  /\ ReporterShape(p)
  /\ p.closed.at = p.coverage /\ p.coverage < p.bonds[0].exit
  /\ p.bonds[0].exit <= p.recoveredAt /\ p.recoveredAt = p.recovery.at
  /\ p.recovery.powers = [i \in Ids |-> IF i = 1 THEN 4 ELSE 0]
  /\ p.landedAt = 0 /\ p.now >= p.recoveredAt + 3 /\ p.bonds[0].confirmed = 0
CoveredGap(p) ==
  /\ p.closed.at < p.bonds[0].exit /\ p.bonds[0].exit <= p.coverage
  /\ p.coverage = p.recoveredAt /\ p.recoveredAt = p.recovery.at
  /\ p.recovery.powers = [i \in Ids |-> IF i = 1 THEN 4 ELSE 0]
  /\ p.landedAt > p.recoveredAt /\ p.bonds[0].confirmed >= p.landedAt
WitnessFlags(p, q, c, accepted) ==
  CASE Probe = "Reporter" -> [marks EXCEPT !.reporter =
         @ \/ (accepted /\ c.kind = "Register" /\ c.key = 1 /\ p.cash.liquid = 4 /\ ReporterShape(q))]
    [] Probe = "Sink" -> [marks EXCEPT !.sink =
         @ \/ (accepted /\ c.kind = "Register" /\ c.key = 1 /\ p.cash.liquid = 5 /\ SinkShape(q))]
    [] Probe = "Funded" -> [marks EXCEPT !.funded =
         @ \/ (~accepted /\ c.kind = "Register" /\ c.key = p.nextId /\ Full(p) /\ p.cash.liquid >= 4)]
    [] Probe = "Stalled" ->
         LET offer == ~accepted /\ StalledGap(p) IN
           [marks EXCEPT !.stallConfirm = @ \/ (offer /\ c.kind = "Confirm" /\ c.bond = 0),
                         !.stallWithdraw = @ \/ (offer /\ c.kind = "Withdraw" /\ c.bond = 0 /\ c.actor = 2),
                         !.stallFull = @ \/ (offer /\ c.kind = "Register" /\ c.key = p.nextId)]
    [] Probe = "Progress" ->
         LET zeroPublic == c.kind = "Withdraw" /\ c.bond = 0 /\ c.actor = 2
             expected == ReporterShape(p) /\ CoveredGap(p) /\ zeroPublic
         IN [marks EXCEPT
              !.early = @ \/ (expected /\ ~accepted /\ p.now = p.bonds[0].confirmed),
              !.released = @ \/ (expected /\ accepted /\ p.now > p.bonds[0].confirmed),
              !.unfunded = @ \/ (marks.released /\ ~accepted /\ c.kind = "Register"
                                /\ c.key = p.nextId /\ ~p.slots[0].occupied
                                /\ p.slots[1] = [occupied |-> TRUE, bond |-> 1]
                                /\ p.cash = [liquid |-> 0, reporter |-> 0, sink |-> 3])]
    [] Probe = "Pending" ->
         LET mature == /\ CanonicalFull(p) /\ CoveredGap(p) /\ p.now > p.bonds[0].confirmed
                       /\ p.bonds[0].eff = 1 /\ p.bonds[0].pending = 1 /\ p.bonds[0].forfeited
                       /\ c.kind = "Withdraw" /\ c.bond = 0
         IN [marks EXCEPT !.positiveDenied = @ \/ (mature /\ ~accepted /\ c.actor = 2),
                          !.positivePaid = @ \/ (marks.positiveDenied /\ mature /\ accepted /\ c.actor = 1)]
    [] OTHER -> marks

Observe(c, accepted) ==
  /\ frameOK' = (frameOK /\ LiteralOffered(r, c) /\ accepted = LiteralAllowed(r, c)
                 /\ r' = (IF accepted THEN LiteralEffects(r, c) ELSE r))
  /\ last' = IF RecordCalls THEN [call |-> c, accepted |-> accepted] ELSE last
  /\ marks' = WitnessFlags(r, r', c, accepted)

Next == \E c \in Offers, accepted \in BOOLEAN : CoreStep(c, accepted) /\ Observe(c, accepted)
Spec == Init /\ [][Next]_vars
FramesExact == frameOK
WitnessView == <<r, frameOK, marks>>

TotalPrincipal(p) == Balance(p.bonds[0]) + Balance(p.bonds[1]) + Balance(p.bonds[2])
TotalSink(p) == p.bonds[0].sinkPaid + p.bonds[1].sinkPaid + p.bonds[2].sinkPaid
HeldSinkAt(p, i) == IF p.bonds[i].holds THEN p.bonds[i].sinkPaid ELSE 0
HeldSink(p) == HeldSinkAt(p, 0) + HeldSinkAt(p, 1) + HeldSinkAt(p, 2)
SupplyConserved ==
  /\ \A x \in {r.cash.liquid, r.cash.reporter, r.cash.sink} : x \in 0..7
  /\ \A i \in Ids : r.bonds[i].eff \in 0..7 /\ r.bonds[i].pending \in 0..7
  /\ r.cash.liquid + r.cash.reporter + r.cash.sink + TotalPrincipal(r) = Supply
  /\ ~SinkRecycle => TotalSink(r) = r.cash.sink
SlotLifetime ==
  /\ r.nextId \in 0..3
  /\ \A i \in Ids :
       LET b == r.bonds[i] IN
         /\ b.issued = (i < r.nextId)
         /\ b.issued => b.key = i
         /\ b.holds = Live(b)
         /\ IF b.holds THEN r.slots[b.slot] = [occupied |-> TRUE, bond |-> i]
                      ELSE Balance(b) = 0
         /\ b.confirmed > 0 => b.exit <= r.coverage /\ b.confirmed <= r.now
  /\ \A s \in Slots :
       LET entry == r.slots[s] IN
         IF entry.occupied THEN r.bonds[entry.bond].holds /\ r.bonds[entry.bond].slot = s
                           ELSE entry = EmptySlot
CoverageFromLanding ==
  /\ r.coverage = 0 => r.recoveredAt = 0 /\ r.landedAt = 0
  /\ r.coverage > 0 /\ r.landedAt = 0 => r.coverage = r.closed.at
  /\ r.landedAt > 0 => r.coverage = r.recoveredAt /\ r.coverage = r.recovery.at
                          /\ r.landedAt > r.recoveredAt /\ HasMembers(r.recovery)
CapacityBound ==
  /\ Full(r) => \E s \in Slots : Balance(r.bonds[r.slots[s].bond]) < Stake
  /\ ~Penalties => ~Full(r)
  /\ ~SinkRecycle /\ Full(r) => 4 * (TotalPrincipal(r) + HeldSink(r)) > 3 * Supply

ReporterSaturationNotReached == ~marks.reporter
SinkSaturationNotReached == ~marks.sink
FundedFullRefusalNotReached == ~marks.funded
StalledReleaseNotReached == ~(marks.stallConfirm /\ marks.stallWithdraw /\ marks.stallFull)
CoveredReleaseNotReached == ~(marks.early /\ marks.released /\ marks.unfunded)
PendingWithdrawalNotReached == ~(marks.positiveDenied /\ marks.positivePaid)

========================================================================
