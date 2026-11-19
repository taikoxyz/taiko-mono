---------------------- MODULE EtnaRegistryVacancy ----------------------
EXTENDS Integers, FiniteSets

CONSTANTS MaxTime, CaptureHistory, RecordCalls
ASSUME /\ MaxTime \in 2..8
       /\ CaptureHistory \in BOOLEAN /\ RecordCalls \in BOOLEAN

VARIABLES r, frameOK, last, marks
vars == <<r, frameOK, last, marks>>

Slots == 0..1
Ids == 0..3
Owners == 1..2
Public == 3
DAO == 4
Callers == Owners \cup {Public}
Amounts == {3, 4}
NoExit == 11
Min(x, y) == IF x <= y THEN x ELSE y
Max(x, y) == IF x >= y THEN x ELSE y

EmptyBond == [issued |-> FALSE, withdrawn |-> FALSE, key |-> 0, owner |-> 0,
              eff |-> 0, pending |-> 0, active |-> 0, exit |-> 0, confirmed |-> 0,
              holds |-> FALSE, slot |-> 0, ready |-> 0]
EmptySlot == [occupied |-> FALSE, bond |-> 0]
UnusedKey == [registered |-> FALSE, bond |-> 0]
EmptyEntry == [occupied |-> FALSE, key |-> 0, bond |-> 0, eff |-> 0,
               active |-> 0, exit |-> 0]
EmptyCheckpoint == [at |-> 0, count |-> 0, entries |-> [s \in Slots |-> EmptyEntry]]
Input(kind, bond, actor, key, amount, snapshot, capture) ==
  [kind |-> kind, bond |-> bond, actor |-> actor, key |-> key, amount |-> amount,
   snapshot |-> snapshot, capture |-> capture]
NoCall == [call |-> Input("None", 0, 0, 0, 0, 0, FALSE), accepted |-> FALSE]
Init ==
  /\ r = [now |-> 1, nextId |-> 0, bonds |-> [i \in Ids |-> EmptyBond],
          slots |-> [s \in Slots |-> EmptySlot], keys |-> [k \in Ids |-> UnusedKey],
          forfeits |-> [k \in Ids |-> FALSE], topups |-> [i \in Ids |-> FALSE],
          uses |-> [s \in Slots |-> 0], reuse |-> 0,
          cash |-> [deposited |-> 0, held |-> 0, bounty |-> 0, sink |-> 0, paid |-> 0],
          covered |-> 0, dirty |-> FALSE, checkpoint |-> EmptyCheckpoint,
          sample |-> [snapshot |-> 0, checkpoint |-> EmptyCheckpoint, powers |-> [i \in Ids |-> 0]]]
  /\ frameOK = TRUE /\ last = NoCall
  /\ marks = [holes |-> FALSE, publicSlotZero |-> FALSE, activation |-> [i \in Ids |-> FALSE],
              pendingCapture |-> [i \in Ids |-> FALSE], duplicateReuse |-> FALSE]

Entry(state, s) ==
  LET slot == state.slots[s]
      bond == state.bonds[slot.bond]
  IN IF slot.occupied THEN
       [occupied |-> TRUE, key |-> bond.key, bond |-> slot.bond,
        eff |-> bond.eff, active |-> bond.active, exit |-> bond.exit]
     ELSE EmptyEntry
Entries(state) == [s \in Slots |-> Entry(state, s)]
Close(state) ==
  IF state.dirty THEN
    [at |-> state.now, count |-> Cardinality({s \in Slots : state.slots[s].occupied}),
     entries |-> Entries(state)]
  ELSE state.checkpoint
Selection(cp, t) ==
  [i \in Ids |-> LET eligible == {s \in Slots : LET e == cp.entries[s] IN
             e.occupied /\ e.bond = i /\ e.active <= t /\ t < e.exit /\ e.eff > 0}
     IN IF eligible = {} THEN 0 ELSE cp.entries[CHOOSE s \in eligible : TRUE].eff]

\* The operational action relation below reads no literal observer data.
Vacancies == {s \in Slots : ~r.slots[s].occupied}
Lowest(vacant) == CHOOSE s \in vacant : \A t \in vacant : s <= t
Admits(c) ==
  /\ c.actor \in Owners /\ c.amount \in Amounts /\ r.nextId \in Ids
  /\ c.key \in Ids /\ ~r.keys[c.key].registered
  /\ Vacancies # {}
Balance(b) == b.eff + b.pending
Live(b) == b.issued /\ ~b.withdrawn

CanRun(c) ==
  LET b == r.bonds[c.bond]
  IN CASE c.kind = "Register" -> Admits(c)
       [] c.kind = "Tick" -> r.now < MaxTime /\ (~c.capture \/ r.sample.snapshot = 0)
       [] c.kind = "Land" -> r.covered < c.snapshot /\ c.snapshot < r.now
       [] OTHER -> Live(b) /\
          (CASE c.kind = "TopUp" ->
             /\ c.actor = b.owner /\ b.active <= r.now /\ b.eff > 0
             /\ b.exit = NoExit /\ b.pending = 0 /\ ~r.topups[c.bond]
           [] c.kind = "Activate" ->
             c.actor \in Callers /\ b.pending > 0 /\ b.ready <= r.now /\ b.exit = NoExit
           [] c.kind = "Exit" -> c.actor = b.owner /\ b.exit = NoExit
           [] c.kind = "Slash" -> c.actor \in Callers /\ Balance(b) > 0
           [] c.kind = "Forfeit" ->
             c.actor = DAO /\ c.key = b.key /\ ~r.forfeits[c.key] /\ Balance(b) > 0
           [] c.kind = "Confirm" -> c.actor \in Callers /\ b.exit <= r.covered
           [] c.kind = "Withdraw" ->
             /\ c.actor \in Callers /\ b.confirmed > 0 /\ b.confirmed + 1 <= r.now
             /\ (Balance(b) = 0 \/ c.actor = b.owner)
           [] OTHER -> FALSE)

Register(c) ==
  LET i == r.nextId
      s == Lowest(Vacancies)
      reused == IF r.uses[s] > 0 THEN 1 ELSE 0
  IN [r EXCEPT !.nextId = i + 1, !.slots[s] = [occupied |-> TRUE, bond |-> i],
       !.bonds[i] = [EmptyBond EXCEPT !.issued = TRUE, !.key = c.key, !.owner = c.actor,
            !.eff = c.amount, !.active = r.now + 1, !.exit = NoExit, !.holds = TRUE, !.slot = s],
       !.keys[c.key] = [registered |-> TRUE, bond |-> i], !.uses[s] = @ + 1,
       !.reuse = @ + reused, !.cash.held = @ + c.amount, !.cash.deposited = @ + c.amount]

Refuse(c) == r

Tick(c) ==
  LET cp == Close(r)
      sample == IF c.capture THEN
          [snapshot |-> r.now, checkpoint |-> cp, powers |-> Selection(cp, r.now)]
        ELSE r.sample
  IN [r EXCEPT !.checkpoint = cp, !.sample = sample, !.now = @ + 1, !.dirty = FALSE]

Apply(c) ==
  LET i == c.bond
      b == r.bonds[i]
      principal == Balance(b)
  IN CASE c.kind = "Register" -> Register(c)
       [] c.kind = "Land" -> [r EXCEPT !.covered = c.snapshot]
       [] c.kind = "TopUp" -> [r EXCEPT !.bonds[i].pending = 1, !.bonds[i].ready = r.now + 1,
                          !.topups[i] = TRUE, !.cash.held = @ + 1, !.cash.deposited = @ + 1]
       [] c.kind = "Activate" -> [r EXCEPT !.bonds[i].eff = principal, !.bonds[i].pending = 0,
                                  !.bonds[i].ready = 0]
       [] c.kind = "Exit" -> [r EXCEPT !.bonds[i].exit = Max(r.now, b.active) + 1]
       [] c.kind = "Slash" ->
            LET bounty == principal \div 4
            IN [r EXCEPT !.bonds[i].eff = 0, !.bonds[i].pending = 0, !.bonds[i].ready = 0,
                 !.bonds[i].exit = Min(b.exit, r.now), !.cash.held = @ - principal,
                 !.cash.bounty = @ + bounty, !.cash.sink = @ + principal - bounty]
       [] c.kind = "Forfeit" ->
            LET penalty == (principal + 1) \div 2
                pending == b.pending - Max(0, penalty - b.eff)
            IN [r EXCEPT !.bonds[i].eff = Max(0, b.eff - penalty), !.bonds[i].pending = pending,
                 !.bonds[i].ready = IF pending > 0 THEN b.ready ELSE 0,
                 !.bonds[i].exit = Min(b.exit, r.now), !.forfeits[c.key] = TRUE,
                 !.cash.held = @ - penalty, !.cash.sink = @ + penalty]
       [] c.kind = "Confirm" ->
            IF b.confirmed = 0 THEN [r EXCEPT !.bonds[i].confirmed = r.now] ELSE r
       [] c.kind = "Withdraw" ->
            [r EXCEPT !.bonds[i].withdrawn = TRUE, !.bonds[i].owner = 0, !.bonds[i].eff = 0,
                 !.bonds[i].pending = 0, !.bonds[i].ready = 0, !.bonds[i].confirmed = 0,
                 !.bonds[i].holds = FALSE, !.bonds[i].slot = 0, !.slots[b.slot] = EmptySlot,
                 !.cash.held = @ - principal, !.cash.paid = @ + principal]

Accept(c) ==
  /\ CanRun(c)
  /\ r' = IF c.kind = "Tick" THEN Tick(c)
          ELSE LET updated == Apply(c) IN
               [updated EXCEPT !.dirty = r.dirty \/ Entries(r) # Entries(updated)]
Reject(c) == /\ c.kind = "Register" /\ ~Admits(c) /\ r' = Refuse(c)

RegistrationCalls(keys) ==
  {Input("Register", 0, a, k, x, 0, FALSE) : a \in Owners, k \in keys, x \in Amounts}

\* The finite offer domain keeps omitted fresh-ID/reuse budget calls separate
\* from protocol refusals. Duplicate lifetime keys remain actual offers.
FreshInBudget ==
  LET s == IF r.slots[0].occupied THEN 1 ELSE 0
  IN r.nextId < 4 /\ (r.slots[s].occupied \/ r.uses[s] = 0 \/ r.reuse < 2)
RegistrationKeys == (0..(r.nextId - 1)) \cup (IF FreshInBudget THEN {r.nextId} ELSE {})
RegistrationOffers == RegistrationCalls(RegistrationKeys)
LifecycleOffers ==
  {Input("Tick", 0, 0, 0, 0, 0, cap) : cap \in IF CaptureHistory THEN BOOLEAN ELSE {FALSE}} \cup
  {Input("Land", 0, 0, 0, 0, t, FALSE) : t \in (r.covered + 1)..(r.now - 1)} \cup
  {Input("TopUp", i, r.bonds[i].owner, 0, 0, 0, FALSE) : i \in {j \in Ids : ~r.topups[j]}} \cup
  {Input("Exit", i, r.bonds[i].owner, 0, 0, 0, FALSE) : i \in Ids} \cup
  {Input(k, i, Public, 0, 0, 0, FALSE) : i \in Ids, k \in {"Activate", "Slash", "Confirm"}} \cup
  {Input("Forfeit", i, DAO, r.bonds[i].key, 0, 0, FALSE) : i \in Ids} \cup
  (UNION {{Input("Withdraw", i, a, 0, 0, 0, FALSE) : a \in {r.bonds[i].owner, Public}} : i \in Ids})

\* Literal observer. Slot choice, guards, changed fields, cash and checkpoint
\* equations are evaluated independently of the operational operators above.
FirstHole(p) == IF ~p.slots[0].occupied THEN 0 ELSE IF ~p.slots[1].occupied THEN 1 ELSE 2
LiteralRegistration(p, c) ==
  /\ p.nextId < 4 /\ ~p.keys[c.key].registered
  /\ c.actor \in 1..2 /\ (c.amount = 3 \/ c.amount = 4)
  /\ FirstHole(p) # 2
LiteralRegisterOffered(p, c) ==
  IF p.keys[c.key].registered THEN TRUE
  ELSE
    /\ p.nextId = c.key
    /\ LET s == FirstHole(p)
       IN IF s = 2 THEN TRUE ELSE p.uses[s] = 0 \/ p.reuse < 2

LiteralEligible(p, c) ==
  LET b == p.bonds[c.bond]
  IN CASE c.kind = "Register" -> LiteralRegistration(p, c)
       [] c.kind = "Tick" -> p.now # MaxTime /\ (c.capture => p.sample.snapshot = 0)
       [] c.kind = "Land" -> c.snapshot \in (p.covered + 1)..(p.now - 1)
       [] OTHER ->
          /\ c.bond < p.nextId /\ ~b.withdrawn
          /\ CASE c.kind = "TopUp" ->
                 c.actor = b.owner /\ b.active <= p.now /\ b.eff # 0 /\ b.exit = 11
                 /\ b.pending = 0 /\ ~p.topups[c.bond]
              [] c.kind = "Activate" ->
                 c.actor \in 1..3 /\ b.pending # 0 /\ b.ready <= p.now /\ b.exit = 11
              [] c.kind = "Exit" -> c.actor = b.owner /\ b.exit = 11
              [] c.kind = "Slash" -> c.actor \in 1..3 /\ (b.eff # 0 \/ b.pending # 0)
              [] c.kind = "Forfeit" ->
                 c.actor = 4 /\ c.key = b.key /\ ~p.forfeits[b.key] /\ (b.eff # 0 \/ b.pending # 0)
              [] c.kind = "Confirm" -> c.actor \in 1..3 /\ b.exit \in 1..p.covered
              [] c.kind = "Withdraw" ->
                 c.actor \in 1..3 /\ b.confirmed \in 1..(p.now - 1)
                 /\ (c.actor = b.owner \/ (b.eff = 0 /\ b.pending = 0))

LiteralLeaves(p) ==
  [s \in 0..1 |->
    LET holder == p.slots[s].bond
        b == p.bonds[holder]
    IN IF p.slots[s].occupied
       THEN [occupied |-> TRUE, bond |-> holder, key |-> b.key,
             active |-> b.active, exit |-> b.exit, eff |-> b.eff]
       ELSE [occupied |-> FALSE, bond |-> 0, key |-> 0, active |-> 0, exit |-> 0, eff |-> 0]]

LiteralClose(p, c) ==
  LET leaves == LiteralLeaves(p)
      occupied(s) == IF leaves[s].occupied THEN 1 ELSE 0
      cp == IF p.dirty THEN [at |-> p.now, count |-> occupied(0) + occupied(1), entries |-> leaves]
            ELSE p.checkpoint
      power(s, i) == LET e == cp.entries[s] IN
          IF e.occupied /\ e.bond = i /\ p.now \in e.active..(e.exit - 1) THEN e.eff ELSE 0
  IN [p EXCEPT !.now = p.now + 1, !.dirty = FALSE, !.checkpoint = cp,
                !.sample = IF c.capture THEN [snapshot |-> p.now, checkpoint |-> cp,
                    powers |-> [i \in 0..3 |-> power(0, i) + power(1, i)]] ELSE p.sample]

LiteralEffects(p, c) ==
  LET i == c.bond
      s == FirstHole(p)
      b == p.bonds[i]
      x == b.eff + b.pending
      penalty == (x \div 2) + (x % 2)
      pendingAfter == IF penalty <= b.eff THEN b.pending ELSE x - penalty
      lowered == IF b.exit < p.now THEN b.exit ELSE p.now
  IN CASE c.kind = "Register" ->
       [p EXCEPT !.bonds[p.nextId] = [issued |-> TRUE, withdrawn |-> FALSE, key |-> c.key,
           owner |-> c.actor, eff |-> c.amount, pending |-> 0, active |-> p.now + 1,
           exit |-> 11, confirmed |-> 0, holds |-> TRUE, slot |-> s, ready |-> 0],
         !.slots[s] = [occupied |-> TRUE, bond |-> p.nextId],
         !.keys[c.key] = [registered |-> TRUE, bond |-> p.nextId], !.nextId = p.nextId + 1,
         !.uses[s] = p.uses[s] + 1, !.reuse = p.reuse + (IF p.uses[s] = 0 THEN 0 ELSE 1),
         !.cash.held = p.cash.held + c.amount, !.cash.deposited = p.cash.deposited + c.amount]
     [] c.kind = "Land" -> [p EXCEPT !.covered = c.snapshot]
     [] c.kind = "TopUp" ->
       [p EXCEPT !.bonds[i].pending = 1, !.bonds[i].ready = p.now + 1, !.topups[i] = TRUE,
          !.cash.deposited = p.cash.deposited + 1, !.cash.held = p.cash.held + 1]
     [] c.kind = "Activate" ->
       [p EXCEPT !.bonds[i].eff = x, !.bonds[i].pending = 0, !.bonds[i].ready = 0]
     [] c.kind = "Exit" ->
       [p EXCEPT !.bonds[i].exit = IF p.now < b.active THEN b.active + 1 ELSE p.now + 1]
     [] c.kind = "Slash" ->
       [p EXCEPT !.bonds[i].eff = 0, !.bonds[i].pending = 0, !.bonds[i].ready = 0,
          !.bonds[i].exit = lowered, !.cash.held = p.cash.held - x,
          !.cash.sink = p.cash.sink + x - (x \div 4), !.cash.bounty = p.cash.bounty + (x \div 4)]
     [] c.kind = "Forfeit" ->
       [p EXCEPT !.bonds[i].eff = x - penalty - pendingAfter, !.bonds[i].pending = pendingAfter,
          !.bonds[i].ready = IF pendingAfter = 0 THEN 0 ELSE b.ready, !.bonds[i].exit = lowered,
          !.forfeits[b.key] = TRUE, !.cash.held = p.cash.held - penalty, !.cash.sink = p.cash.sink + penalty]
     [] c.kind = "Confirm" ->
       [p EXCEPT !.bonds[i].confirmed = IF b.confirmed > 0 THEN b.confirmed ELSE p.now]
     [] c.kind = "Withdraw" ->
       [p EXCEPT !.bonds[i] = [issued |-> TRUE, withdrawn |-> TRUE, key |-> b.key, owner |-> 0,
           eff |-> 0, pending |-> 0, active |-> b.active, exit |-> b.exit,
           confirmed |-> 0, holds |-> FALSE, slot |-> 0, ready |-> 0],
         !.slots[b.slot] = [occupied |-> FALSE, bond |-> 0],
         !.cash.held = p.cash.held - x, !.cash.paid = p.cash.paid + x]

LiteralPost(p, c, accepted) ==
  IF ~accepted THEN p
  ELSE IF c.kind = "Tick" THEN LiteralClose(p, c)
  ELSE LET after == LiteralEffects(p, c) IN
       [after EXCEPT !.dirty = p.dirty \/ LiteralLeaves(p) # LiteralLeaves(after)]

FullWithZeroAndPending(p) ==
  /\ p.slots[0].occupied /\ p.slots[1].occupied
  /\ \E s \in Slots :
       LET zero == p.bonds[p.slots[s].bond]
           other == p.bonds[p.slots[1 - s].bond]
       IN zero.eff = 0 /\ zero.pending = 0 /\ other.pending > 0 /\ other.exit # NoExit

ObserveTransition(c, accepted) ==
  /\ frameOK' = (accepted = LiteralEligible(r, c) /\ r' = LiteralPost(r, c, accepted))
  /\ last' = IF RecordCalls \/ ~frameOK' THEN [call |-> c, accepted |-> accepted] ELSE NoCall
  /\ marks' = IF RecordCalls /\ accepted THEN
       [holes |-> marks.holes \/ (c.kind = "Register" /\ r.nextId = 2 /\ FirstHole(r) = 0
                     /\ ~r.slots[1].occupied),
        publicSlotZero |-> marks.publicSlotZero \/
          (c.kind = "Withdraw" /\ c.actor = 3 /\ r.bonds[c.bond].slot = 0
           /\ r.bonds[c.bond].eff = 0 /\ r.bonds[c.bond].pending = 0),
        activation |-> IF c.kind = "Activate" /\ marks.pendingCapture[c.bond]
                      THEN [marks.activation EXCEPT ![c.bond] = TRUE] ELSE marks.activation,
        pendingCapture |-> IF c.kind = "Tick" /\ c.capture THEN
           [i \in Ids |-> r.bonds[i].pending > 0 /\ r'.sample.powers[i] > 0]
           ELSE marks.pendingCapture,
        duplicateReuse |-> c.kind = "Register" /\ last.call.kind = "Register"
          /\ ~last.accepted /\ r.keys[last.call.key].registered
          /\ r.bonds[r.keys[last.call.key].bond].withdrawn]
       ELSE marks

RegisterStep(c, accepted) ==
  /\ c \in RegistrationOffers
  /\ IF accepted THEN Accept(c) ELSE Reject(c)
Next ==
  \/ \E c \in RegistrationOffers, accepted \in BOOLEAN :
       RegisterStep(c, accepted) /\ ObserveTransition(c, accepted)
  \/ \E c \in LifecycleOffers : Accept(c) /\ ObserveTransition(c, TRUE)
Spec == Init /\ [][Next]_vars

FramesExact == frameOK
AdmissionEnabled ==
  \A actor \in 1..2, key \in 0..3, amount \in {3, 4} :
    LET c == Input("Register", 0, actor, key, amount, 0, FALSE)
        offered == LiteralRegisterOffered(r, c)
    IN /\ (ENABLED RegisterStep(c, TRUE)) = (offered /\ LiteralRegistration(r, c))
       /\ (ENABLED RegisterStep(c, FALSE)) = (offered /\ ~LiteralRegistration(r, c))
CashAndLifetime ==
  /\ r.cash.deposited = r.cash.held + r.cash.bounty + r.cash.sink + r.cash.paid
  /\ r.cash.held =
       Balance(r.bonds[0]) + Balance(r.bonds[1]) + Balance(r.bonds[2]) + Balance(r.bonds[3])
  /\ r.reuse <= 2
  /\ \A i \in Ids :
       LET b == r.bonds[i] IN
       /\ b.issued = (i < r.nextId) /\ b.issued = r.keys[i].registered
       /\ b.holds = (b.issued /\ ~b.withdrawn)
       /\ b.issued => (b.key = i /\ r.keys[i].bond = i)
       /\ b.holds => (r.slots[b.slot].occupied /\ r.slots[b.slot].bond = i)
  /\ \A s \in Slots : r.slots[s].occupied =>
       LET b == r.bonds[r.slots[s].bond] IN b.holds /\ b.slot = s

HeldZeroNotReached ==
  ~(last.call.kind = "Register" /\ last.accepted /\ r.nextId = 2 /\ r.slots[0] = [occupied |-> TRUE, bond |-> 0]
    /\ r.slots[1] = [occupied |-> TRUE, bond |-> 1]
    /\ r.bonds[0].eff + r.bonds[0].pending = 0
    /\ r.bonds[1].active = r.bonds[0].exit + 1)
FullRefusalNotReached ==
  ~(IF last = NoCall THEN FALSE ELSE FullWithZeroAndPending(r) /\ ~last.accepted
    /\ last.call.key = r.nextId /\ r.nextId < 4)
TwoHolesNotReached ==
  ~(r.nextId = 2 /\ ~r.slots[0].occupied /\ ~r.slots[1].occupied)
TwoReusesNotReached ==
  ~(marks.holes /\ r.nextId = 4 /\ r.slots[0] = [occupied |-> TRUE, bond |-> 2]
    /\ r.slots[1] = [occupied |-> TRUE, bond |-> 3] /\ r.uses[0] = 2 /\ r.uses[1] = 2
    /\ r.bonds[0].withdrawn /\ r.bonds[1].withdrawn)
FrozenSelectionNotReached ==
  ~(\E i \in Ids : r.sample.powers[i] > 0 /\ r.bonds[i].withdrawn /\ marks.activation[i]
       /\ \E s \in Slots : r.sample.checkpoint.entries[s].occupied
             /\ r.sample.checkpoint.entries[s].bond = i /\ r.slots[s].occupied
             /\ r.slots[s].bond # i)

ZeroPublicReuseNotReached ==
  ~(marks.publicSlotZero /\ last.call.kind = "Register" /\ last.accepted
    /\ r.slots[0].occupied /\ r.slots[0].bond = r.nextId - 1
    /\ r.uses[0] > 1)
PartialForfeitNotReached ==
  ~(last.call.kind = "Forfeit" /\ last.accepted /\ r.bonds[last.call.bond].holds
    /\ r.bonds[last.call.bond].pending > 0 /\ r.bonds[last.call.bond].eff > 0)

DuplicateKeyNotReached ==
  ~marks.duplicateReuse

=========================================================================
