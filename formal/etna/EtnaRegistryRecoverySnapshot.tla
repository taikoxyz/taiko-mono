---------------- MODULE EtnaRegistryRecoverySnapshot ----------------
EXTENDS Integers, Sequences, FiniteSets

CONSTANT Route
ASSUME Route \in {"main", "closed-hole"}

VARIABLES s, receipt, marks
vars == <<s, receipt, marks>>
Ids == 0..3
Slots == 0..1
NoExit == 11
Min(x, y) == IF x <= y THEN x ELSE y
Max(x, y) == IF x >= y THEN x ELSE y
EmptyEntry == [key |-> -1, eff |-> 0, active |-> 0, exit |-> 0]
EmptyBond == [issued |-> FALSE, withdrawn |-> FALSE, key |-> -1, owner |-> 0,
              eff |-> 0, pending |-> 0, ready |-> 0, active |-> 0, exit |-> 0,
              confirmed |-> 0, holds |-> FALSE, slot |-> -1]
EmptySnapshot == [at |-> 0, checkpointAt |-> 0, width |-> 2,
                  entries |-> <<EmptyEntry, EmptyEntry>>]
EmptyOrigin == [at |-> 0, entries |-> <<>>, members |-> <<>>]

\* Rank is an explicit symbolic order, later mapped to public set-key vectors.
SetRank(key) == CASE key = 0 -> 3 [] key = 1 -> 1 [] OTHER -> 2
Entry(state, slot) ==
  LET id == state.slots[slot + 1]
  IN IF id = -1 THEN EmptyEntry
     ELSE LET b == state.bonds[id + 1]
          IN [key |-> b.key, eff |-> b.eff, active |-> b.active, exit |-> b.exit]
Entries(state) == <<Entry(state, 0), Entry(state, 1)>>
Eligible(e, at) == e.key # -1 /\ e.active <= at /\ at < e.exit /\ e.eff >= 4
Select(entries, at) ==
  LET candidates == {e \in {entries[1], entries[2]} : Eligible(e, at)}
      best == IF candidates = {} THEN EmptyEntry
              ELSE CHOOSE e \in candidates : \A other \in candidates :
                e.eff > other.eff \/ (e.eff = other.eff /\ SetRank(e.key) <= SetRank(other.key))
  IN IF candidates = {} THEN <<>>
     ELSE <<[key |-> best.key, eff |-> best.eff, power |-> best.eff \div 2]>>
Snapshot(state) == [at |-> state.now, checkpointAt |-> state.entryChangedAt,
                    width |-> 2, entries |-> Entries(state)]

Init ==
  /\ s = [now |-> 1, nextId |-> 0, slots |-> <<-1, -1>>,
          bonds |-> [i \in 1..4 |-> EmptyBond], keys |-> <<FALSE, FALSE, FALSE>>,
          entryChangedAt |-> 0, snapshots |-> [i \in 1..8 |-> EmptySnapshot],
          closed |-> [i \in 1..8 |-> FALSE], activeSnapshot |-> 0,
          generation |-> 0, recoveryAt |-> 0, origin |-> EmptyOrigin]
  /\ receipt = [kind |-> "init", args |-> <<>>, accepted |-> TRUE]
  /\ marks = [invalid |-> <<FALSE, FALSE, FALSE>>, badLand |-> FALSE,
              transientHole |-> FALSE, closedHole |-> FALSE,
              order |-> <<>>, atomic |-> TRUE]

Finish(next, kind, args, accepted, nextMarks) ==
  /\ s' = next
  /\ receipt' = [kind |-> kind, args |-> args, accepted |-> accepted]
  /\ marks' = nextMarks

Changed(before, after) ==
  IF Entries(before) = Entries(after) THEN after
  ELSE [after EXCEPT !.entryChangedAt = before.now]

Registration(id) ==
  LET slot == IF s.slots[1] = -1 THEN 0 ELSE 1
      fresh == [EmptyBond EXCEPT !.issued = TRUE, !.key = id, !.owner = id + 1,
                  !.eff = 4, !.active = s.now + 1, !.exit = NoExit,
                  !.holds = TRUE, !.slot = slot]
      next == [s EXCEPT !.nextId = id + 1, !.slots[slot + 1] = id,
                       !.bonds[id + 1] = fresh, !.keys[id + 1] = TRUE]
      offered == (s.now = 1 /\ id = s.nextId /\ id \in 0..1)
                 \/ (id = 2 /\ s.nextId = 2 /\ s.bonds[1].withdrawn /\
                     s.now = (IF Route = "main" THEN 5 ELSE 6))
  IN /\ offered /\ ~s.keys[id + 1] /\ s.slots[slot + 1] = -1
     /\ Finish(Changed(s, next), "register", <<id, id + 1, id, 4>>, TRUE, marks)

RequestExit ==
  LET b == s.bonds[1]
      next == [s EXCEPT !.bonds[1].exit = Max(s.now, b.active) + 1]
  IN /\ s.now = 2 /\ b.issued /\ b.exit = NoExit
     /\ Finish(Changed(s, next), "exit", <<0, 1>>, TRUE, marks)

TerminalLand ==
  /\ s.now = 4 /\ s.closed[3] /\ s.activeSnapshot = 0
  /\ Finish([s EXCEPT !.activeSnapshot = 3], "terminal-land", <<3>>, TRUE, marks)

Confirm ==
  /\ s.now = 4 /\ s.activeSnapshot >= s.bonds[1].exit /\ s.bonds[1].confirmed = 0
  /\ Finish([s EXCEPT !.bonds[1].confirmed = s.now], "confirm", <<0, 4>>, TRUE, marks)

Withdraw ==
  LET b == s.bonds[1]
      next == [s EXCEPT !.slots[b.slot + 1] = -1,
          !.bonds[1] = [b EXCEPT !.withdrawn = TRUE, !.owner = 0, !.eff = 0,
             !.pending = 0, !.ready = 0, !.confirmed = 0, !.holds = FALSE, !.slot = -1]]
  IN /\ s.now = 5 /\ b.confirmed = 4 /\ ~b.withdrawn
     /\ Finish(Changed(s, next), "withdraw", <<0, 1>>, TRUE,
          [marks EXCEPT !.transientHole = TRUE])

TopUp(id, amount) ==
  LET b == s.bonds[id + 1]
      offered == (id = 2 /\ amount = 1 /\
                    s.now = (IF Route = "main" THEN 6 ELSE 7))
                 \/ (Route = "main" /\ id = 1 /\ amount = 2 /\ s.now = 7)
      next == [s EXCEPT !.bonds[id + 1].pending = amount,
                       !.bonds[id + 1].ready = s.now + 1]
  IN /\ offered /\ b.issued /\ ~b.withdrawn /\ b.active <= s.now
     /\ b.exit = NoExit /\ b.pending = 0 /\ b.eff = 4
     /\ Finish(next, "topup", <<id, id + 1, amount>>, TRUE, marks)

Activate(id) ==
  LET b == s.bonds[id + 1]
      next == [s EXCEPT !.bonds[id + 1].eff = b.eff + b.pending,
                       !.bonds[id + 1].pending = 0, !.bonds[id + 1].ready = 0]
      ordered == IF id = 2 /\ s.now = 7 THEN Append(marks.order, "activate") ELSE marks.order
  IN /\ id \in {1, 2} /\ b.pending > 0 /\ b.ready <= s.now /\ b.exit = NoExit
     /\ ~s.closed[s.now]
     /\ Finish(Changed(s, next), "activate", <<id, 4>>, TRUE,
               [marks EXCEPT !.order = ordered])

Lists == << <<[bond |-> 0, key |-> 0]>>,
            <<[bond |-> 1, key |-> 1], [bond |-> 3, key |-> 3]>>,
            <<[bond |-> 0, key |-> 2]>>,
            <<[bond |-> 1, key |-> 1], [bond |-> 0, key |-> 0]>> >>
ValidList(list) ==
  /\ \A j \in 1..Len(list) :
       /\ list[j].bond \in Ids
       /\ s.bonds[list[j].bond + 1].issued
       /\ s.bonds[list[j].bond + 1].key = list[j].key
  /\ \A j \in 2..Len(list) : list[j - 1].bond < list[j].bond
\* Bond identity remains authoritative after its slot is released and reused.
ExitTarget(state, id) == id
Forced(list) ==
  LET targets == {ExitTarget(s, list[j].bond) : j \in 1..Len(list)}
      next == [s EXCEPT !.bonds = [i \in 1..4 |->
                  IF i - 1 \in targets THEN [s.bonds[i] EXCEPT !.exit = Min(@, s.now)]
                  ELSE s.bonds[i]],
                       !.generation = 1, !.recoveryAt = s.now]
  IN Changed(s, next)

Recover(index) ==
  LET list == Lists[index]
      valid == ValidList(list)
      next == IF valid THEN Forced(list) ELSE s
      nextMarks == IF index = 1 THEN [marks EXCEPT !.order = Append(@, "recover")]
                   ELSE [marks EXCEPT !.invalid[index - 1] = TRUE,
                          !.atomic = @ /\ next = s]
  IN /\ s.now = 7 /\ ~s.closed[7] /\ index \in 1..4
     /\ IF index = 1 THEN s.generation = 0 ELSE ~marks.invalid[index - 1]
     /\ Finish(next, "recover", <<index, list>>, valid, nextMarks)

ReadyToClose ==
  CASE s.now = 1 -> s.nextId = 2
    [] s.now = 2 -> s.bonds[1].exit = 3
    [] s.now = 3 -> TRUE
    [] s.now = 4 -> s.bonds[1].confirmed = 4
    [] s.now = 5 -> s.bonds[1].withdrawn /\ (Route = "closed-hole" \/ s.nextId = 3)
    [] s.now = 6 -> IF Route = "main" THEN s.bonds[3].pending = 1 ELSE s.nextId = 3
    [] s.now = 7 -> /\ s.generation = 1 /\ marks.invalid = <<TRUE, TRUE, TRUE>>
                       /\ IF Route = "main" THEN s.bonds[3].eff = 5 /\ s.bonds[2].pending = 2
                          ELSE s.bonds[3].pending = 1
    [] OTHER -> IF Route = "main" THEN s.bonds[2].eff = 6 ELSE s.bonds[3].eff = 5

Close ==
  LET cp == Snapshot(s)
      origin == IF s.recoveryAt = s.now THEN
                  [at |-> s.now, entries |-> cp.entries, members |-> Select(cp.entries, s.now)]
                ELSE s.origin
      next == [s EXCEPT !.snapshots[s.now] = cp, !.closed[s.now] = TRUE, !.origin = origin]
  IN /\ s.now \in 1..8 /\ ~s.closed[s.now] /\ ReadyToClose
     /\ Finish(next, "close", <<s.now>>, TRUE,
          [marks EXCEPT !.closedHole = @ \/ (s.now = 5 /\ cp.entries[1] = EmptyEntry)])

Tick ==
  /\ s.now < 8 /\ s.closed[s.now]
  /\ Finish([s EXCEPT !.now = @ + 1], "tick", <<>>, TRUE, marks)

Land(snapshot) ==
  LET valid == snapshot = 7
      next == IF valid THEN [s EXCEPT !.activeSnapshot = snapshot] ELSE s
  IN /\ s.now = 8 /\ s.origin.at = 7 /\ snapshot \in {7, 8}
     /\ IF valid THEN s.activeSnapshot = 3 ELSE ~marks.badLand
     /\ Finish(next, "land", <<snapshot>>, valid,
          IF valid THEN marks ELSE [marks EXCEPT !.badLand = TRUE, !.atomic = @ /\ next = s])

Next == /\ s.now \in 1..8
        /\ \/ \E id \in 0..2 : Registration(id)
           \/ RequestExit \/ TerminalLand \/ Confirm \/ Withdraw
           \/ \E id \in {1, 2}, amount \in {1, 2} : TopUp(id, amount)
           \/ \E id \in {1, 2} : Activate(id)
           \/ \E index \in 1..4 : Recover(index)
           \/ Close \/ Tick
           \/ \E snapshot \in {7, 8} : Land(snapshot)

LifetimeAndSlots ==
  /\ s.nextId \in 0..3 /\ Len(s.slots) = 2 /\ Len(s.bonds) = 4
  /\ \A i \in Ids :
       /\ s.bonds[i + 1].issued = (i < s.nextId)
       /\ s.bonds[i + 1].holds = (i \in {s.slots[1], s.slots[2]})
       /\ s.bonds[i + 1].withdrawn =>
             s.bonds[i + 1].issued /\ ~s.bonds[i + 1].holds /\ s.bonds[i + 1].eff = 0
  /\ s.slots[1] # s.slots[2] \/ s.slots[1] = -1
  /\ \A slot \in Slots : s.slots[slot + 1] # -1 =>
       /\ s.bonds[s.slots[slot + 1] + 1].slot = slot
       /\ s.bonds[s.slots[slot + 1] + 1].owner = s.slots[slot + 1] + 1
OldIdentitySafe ==
  /\ s.bonds[1].withdrawn => s.bonds[1].key = 0 /\ s.bonds[1].exit = 3 /\ s.keys[1]
  /\ s.bonds[2].issued => s.bonds[2].exit = NoExit
  /\ s.bonds[3].issued => s.bonds[3].exit = NoExit
FinalOrigin == s.origin.at # 0 =>
  /\ s.origin.at = 7 /\ s.closed[7] /\ s.origin.entries = s.snapshots[7].entries
  /\ s.origin.members = Select(s.snapshots[7].entries, 7) /\ s.origin.members # <<>>
SnapshotsFrozen == \A t \in 1..8 : s.closed[t] =>
  /\ s.snapshots[t].at = t /\ s.snapshots[t].width = 2
  /\ s.snapshots[t].checkpointAt <= t
LandUsesTerminal == s.activeSnapshot \in {0, 3, 7}
FramesExact == marks.atomic

Done == s.now = 8 /\ s.closed[8] /\ s.activeSnapshot = 7 /\ marks.badLand
        /\ marks.invalid = <<TRUE, TRUE, TRUE>> /\ marks.transientHole
NoSmoke == s.nextId # 2
NoProgress == ~Done
NoRecoverFirst == ~(Done /\ marks.order = <<"recover", "activate">>)
NoActivateFirst == ~(Done /\ marks.order = <<"activate", "recover">>)
NoClosedHole == ~marks.closedHole

Spec == Init /\ [][Next]_vars
======================================================================
