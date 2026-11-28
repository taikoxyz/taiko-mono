---------------------------- MODULE EtnaRegistry ----------------------------
EXTENDS Naturals, Integers, FiniteSets, TLC

\* Bounded projection of pinned Etna SPEC 4.1/4.4 and START-10-5.
\* Atomic successful contract calls; failed calls transfer nothing. Cryptographic
\* evidence/DAO authorization/ERC20 behavior are input premises, not proved here.
CONSTANTS SlotCount, MaxIssued, MaxNow, MaxTopupCallsPerId, RegistrationAmounts, TopupAmount, ForfeitDenominator, FixedRegistrationBlocks, PreparedWorkflow,
          CheckIssued, CheckActivationExit, CheckConfirmCoverage, CheckWithdrawDelay,
          KeepConfirmationClock, KeepUsedKeys, KeepForfeitFlags, ClearOnlyOwnedSlot,
          PayOnce, EffectiveOnlySnapshot, CorrectDepositWrite, RejectWithoutMutation, CorrectForfeitSplit, CorrectAdmissionSlot
ASSUME /\ SlotCount \in 1..2 /\ MaxIssued \in 1..3 /\ MaxNow >= 4
       /\ RegistrationAmounts \subseteq 1..4 /\ RegistrationAmounts # {}
       /\ MaxTopupCallsPerId \in 0..2 /\ TopupAmount \in 1..2 /\ ForfeitDenominator \in 1..2
IDs == 0..MaxIssued
Keys == 0..(MaxIssued - 1)
Slots == 0..(SlotCount - 1)
Times == 1..MaxNow
Never == MaxNow + 3
Min(a,b) == IF a <= b THEN a ELSE b
Max(a,b) == IF a >= b THEN a ELSE b
ZeroMap == [i \in IDs |-> 0]
RawBond == [issued |-> FALSE, withdrawn |-> FALSE, key |-> 0, owner |-> 0,
            eff |-> 0, pending |-> 0, active |-> 0, exit |-> 0, confirmed |-> 0,
            holds |-> FALSE, slot |-> 0, ready |-> 0]
EmptySlot == [occupied |-> FALSE, id |-> 0]
EmptyReceipt == [present |-> FALSE, id |-> 0, amount |-> 0, beforeEff |-> 0,
                 beforePending |-> 0, at |-> 0, first |-> 0, caller |-> 0,
                 beforeSlots |-> [s \in Slots |-> EmptySlot],
                 afterSlots |-> [s \in Slots |-> EmptySlot], ownsSlot |-> FALSE,
                 slot |-> 0, wasActive |-> FALSE, hadPendingDisplacement |-> FALSE,
                 forfeitedThenHistoricalSlash |-> FALSE]
VARIABLES r, audit, event, setup
vars == <<r, audit, event, setup>>
Balance(b) == b.eff + b.pending
SlotBalance(s) == IF r.slots[s].occupied THEN Balance(r.bonds[r.slots[s].id]) ELSE 0
MinimumSlot == CHOOSE s \in Slots : \A t \in Slots :
                 SlotBalance(s) < SlotBalance(t) \/ (SlotBalance(s) = SlotBalance(t) /\ (IF CorrectAdmissionSlot THEN s <= t ELSE s >= t))
CanRegister(k,a) == r.nextId < MaxIssued /\ ~r.usedKey[k] /\ a >= 1 /\ a > SlotBalance(MinimumSlot)
\* Observation-only decision oracle: raw slot values and permanent issued-key
\* history, independent of CanRegister/MinimumSlot/SlotBalance.
ExpectedAcceptance(k,a) == LET values==[s \in Slots |-> IF r.slots[s].occupied
        THEN r.bonds[r.slots[s].id].eff+r.bonds[r.slots[s].id].pending ELSE 0]
    IN Cardinality(audit.issued)<MaxIssued /\ k \notin audit.keyEver /\ a>=1
       /\ (\E s \in Slots : \A t \in Slots : values[s]<=values[t] /\ a>values[s])
SnapshotEntry(s, includePending) ==
    LET b == r.bonds[r.slots[s].id]
    IN [id |-> r.slots[s].id, eff |-> b.eff + (IF includePending THEN b.pending ELSE 0),
        active |-> b.active, exit |-> b.exit]
CapturedSnapshot(includePending) == {SnapshotEntry(s,includePending) : s \in {t \in Slots : r.slots[t].occupied}}
Members(entries,s) == {e.id : e \in {x \in entries : x.eff > 0 /\ x.active <= s /\ s < x.exit}}
Powers(entries,s) == [i \in IDs |-> IF i \in Members(entries,s)
                         THEN (CHOOSE e \in entries : e.id = i).eff ELSE 0]
Init ==
 /\ setup=0
 /\ r = [bonds |-> [i \in IDs |-> RawBond], slots |-> [s \in Slots |-> EmptySlot],
         now |-> 1, nextId |-> 0, usedKey |-> [k \in Keys |-> FALSE],
         forfeit |-> [k \in Keys |-> FALSE], calls |-> ZeroMap, vault |-> 0,
         initialized |-> FALSE, generation |-> 0, activeSnapshot |-> 0,
         members |-> {}, powers |-> ZeroMap, snapshots |-> [t \in Times |-> {}]]
 /\ audit = [initial |-> ZeroMap, topups |-> ZeroMap, activated |-> ZeroMap,
             effLost |-> ZeroMap, pendingLost |-> ZeroMap,
             withdrawnEff |-> ZeroMap, withdrawnPending |-> ZeroMap,
             paid |-> ZeroMap, sunk |-> ZeroMap, issued |-> {}, keyEver |-> {},
             keyAtIssue |-> [i \in IDs |-> 0], ownerAtIssue |-> [i \in IDs |-> 0],
             firstConfirm |-> ZeroMap, exitMin |-> ZeroMap, forfeitEver |-> {},
             badRejectedMutation |-> FALSE, badRegistrationDecision |-> FALSE, activationAfterExit |-> FALSE, badConfirmation |-> FALSE, badWithdrawal |-> FALSE,
             rawSnapshots |-> [t \in Times |-> {}], wasActive |-> {}, pendingDisplaced |-> {},
             historicalSlashAfterForfeit |-> {}, activationCount |-> ZeroMap,
             lastWithdrawal |-> EmptyReceipt,
             lastRegistration |-> [present |-> FALSE, accepted |-> FALSE, amount |-> 0,
               key |-> 0, keyAvailable |-> TRUE, fresh |-> TRUE, selected |-> 0,
               values |-> [s \in Slots |-> 0], oldPresent |-> FALSE, at |-> 0,
               oldBefore |-> RawBond, oldAfter |-> RawBond, newBond |-> RawBond],
             lastForfeit |-> [present |-> FALSE, eff |-> 0, pending |-> 0,
               afterEff |-> 0, afterPending |-> 0, penalty |-> 0]]
 /\ event = [kind |-> "None", id |-> 0, equality |-> FALSE]
Register(k,a) ==
 /\ k \in Keys /\ a \in RegistrationAmounts
 /\ (~FixedRegistrationBlocks \/ r.now = 1+2*r.nextId)
 /\ IF CanRegister(k,a)
       THEN LET i == r.nextId
                s == MinimumSlot
                occupied == r.slots[s].occupied
                old == r.slots[s].id
                oldBond == r.bonds[old]
                displaced == IF occupied THEN [r.bonds EXCEPT
                         ![old].holds = FALSE, ![old].exit = Min(@, r.now)] ELSE r.bonds
                b == [issued |-> TRUE, withdrawn |-> FALSE, key |-> k, owner |-> 1,
                      eff |-> IF CorrectDepositWrite THEN a ELSE a+1, pending |-> 0,
                      active |-> r.now+1, exit |-> Never, confirmed |-> 0,
                      holds |-> TRUE, slot |-> s, ready |-> 0]
            IN /\ r' = [r EXCEPT !.bonds = [displaced EXCEPT ![i] = b],
                         !.slots[s] = [occupied |-> TRUE, id |-> i],
                         !.nextId = @+1, !.usedKey[k] = TRUE, !.vault = @+a]
               /\ audit' = [audit EXCEPT !.initial[i] = a,
                      !.issued = @ \cup {i}, !.keyEver = @ \cup {k},
                      !.keyAtIssue[i] = k, !.ownerAtIssue[i] = 1,
                      !.badRegistrationDecision=@ \/ ~ExpectedAcceptance(k,a),
                      !.lastRegistration=[present |-> TRUE, accepted |-> TRUE, amount |-> a,
                        key |-> k, keyAvailable |-> k \notin audit.keyEver,
                        fresh |-> Cardinality(audit.issued)<MaxIssued,
                        selected |-> r'.bonds[i].slot,
                        values |-> [t \in Slots |-> IF r.slots[t].occupied
                             THEN r.bonds[r.slots[t].id].eff+r.bonds[r.slots[t].id].pending ELSE 0],
                        oldPresent |-> occupied, at |-> r.now, oldBefore |-> oldBond,
                        oldAfter |-> r'.bonds[old], newBond |-> r'.bonds[i]],
                      !.exitMin = [j \in IDs |-> IF j=i THEN Never
                            ELSE IF occupied /\ j=old THEN Min(audit.exitMin[j], r.now) ELSE audit.exitMin[j]],
                      !.pendingDisplaced = IF occupied /\ oldBond.pending > 0
                                              THEN @ \cup {old} ELSE @]
               /\ event' = [kind |-> "Registered", id |-> i, equality |-> FALSE]
       ELSE /\ r' = IF RejectWithoutMutation THEN r
                         ELSE IF PreparedWorkflow /\ r.bonds[0].issued
                                /\ ~r.bonds[0].withdrawn /\ ~r.bonds[0].holds
                                /\ 0 \notin r.members /\ Balance(r.bonds[0])>0
                           THEN [r EXCEPT !.bonds[0].withdrawn=TRUE]
                           ELSE [r EXCEPT !.usedKey[k] = TRUE]
            /\ audit'=[audit EXCEPT !.badRegistrationDecision=@ \/ ExpectedAcceptance(k,a),
                         !.badRejectedMutation=@ \/ (r'#r)]
            /\ event' = [kind |-> "Rejected", id |-> 0, equality |-> FALSE]
Topup(i) ==
 /\ i \in IDs
 /\ LET b == r.bonds[i]
    IN /\ b.issued /\ ~b.withdrawn /\ b.owner = 1 /\ r.now >= b.active
       /\ b.eff > 0 /\ b.pending = 0 /\ b.exit = Never
       \* Explicit external workload bound, not a protocol top-up restriction.
       /\ r.calls[i] < MaxTopupCallsPerId
       /\ r' = [r EXCEPT !.bonds[i].pending = TopupAmount, !.bonds[i].ready = r.now+1,
                        !.calls[i] = @+1, !.vault = @+TopupAmount]
       /\ audit' = [audit EXCEPT !.topups[i] = @+TopupAmount]
       /\ event' = [kind |-> "ToppedUp", id |-> i, equality |-> FALSE]
Activate(i) ==
 /\ i \in IDs
 /\ LET b == r.bonds[i]
    IN /\ b.issued /\ ~b.withdrawn /\ b.pending > 0 /\ r.now >= b.ready
       /\ (CheckActivationExit => b.exit = Never)
       /\ r' = [r EXCEPT !.bonds[i].eff = @+b.pending, !.bonds[i].pending = 0,
                        !.bonds[i].ready = 0]
       /\ audit' = [audit EXCEPT !.activated[i] = @+b.pending,
                       !.activationCount[i] = @+1,
                       !.activationAfterExit = @ \/ b.exit # Never]
       /\ event' = [kind |-> "Activated", id |-> i, equality |-> r.now=b.ready]
RequestExit(i) ==
 /\ i \in IDs
 /\ LET b == r.bonds[i]
        e == Max(r.now+1,b.active+1)
    IN /\ b.issued /\ ~b.withdrawn /\ b.owner = 1 /\ b.exit = Never
       /\ r' = [r EXCEPT !.bonds[i].exit = e]
       /\ audit' = [audit EXCEPT !.exitMin[i] = Min(@,e)]
       /\ event' = [kind |-> "ExitRequested", id |-> i, equality |-> FALSE]
Confirm(i) ==
 /\ r.initialized /\ i \in IDs
 /\ LET b == r.bonds[i]
    IN /\ (CheckIssued => b.issued) /\ ~b.withdrawn /\ b.exit # Never
       /\ (CheckConfirmCoverage => r.activeSnapshot >= b.exit)
       /\ r' = [r EXCEPT !.bonds[i].confirmed =
                    IF KeepConfirmationClock /\ b.confirmed > 0 THEN b.confirmed ELSE r.now]
       /\ audit' = [audit EXCEPT !.firstConfirm[i] = IF @ = 0 THEN r.now ELSE @,
                      !.badConfirmation = @ \/ r.activeSnapshot < b.exit \/ ~b.issued]
       /\ event' = [kind |-> "Confirmed", id |-> i, equality |-> r.activeSnapshot=b.exit]
Withdraw(i,caller) ==
 /\ i \in IDs /\ caller \in {1,2}
 /\ LET b == r.bonds[i]
        amount == IF PayOnce THEN Balance(b) ELSE 2*Balance(b)
        afterSlots == IF b.holds \/ ~ClearOnlyOwnedSlot
                        THEN [r.slots EXCEPT ![b.slot] = EmptySlot] ELSE r.slots
    IN /\ b.issued /\ ~b.withdrawn /\ b.confirmed > 0
       /\ (CheckWithdrawDelay => r.now >= b.confirmed+1)
       /\ (Balance(b) = 0 \/ caller=b.owner)
       /\ r.vault >= amount
       /\ r' = [r EXCEPT !.bonds[i].eff=0, !.bonds[i].pending=0, !.bonds[i].ready=0,
                    !.bonds[i].owner=0, !.bonds[i].confirmed=0, !.bonds[i].holds=FALSE,
                    !.bonds[i].withdrawn=TRUE, !.slots=afterSlots, !.vault=@-amount,
                    !.usedKey[b.key]=IF KeepUsedKeys THEN @ ELSE FALSE,
                    !.forfeit[b.key]=IF KeepForfeitFlags THEN @ ELSE FALSE]
       /\ audit' = [audit EXCEPT !.paid[i]=@+amount,
                    !.withdrawnEff[i]=@+b.eff, !.withdrawnPending[i]=@+b.pending,
                    !.badWithdrawal=@ \/ r.now<audit.firstConfirm[i]+1
                        \/ audit.firstConfirm[i]=0 \/ (Balance(b)>0 /\ caller#b.owner),
                    !.lastWithdrawal=[present |-> TRUE, id |-> i, amount |-> amount,
                        beforeEff |-> b.eff, beforePending |-> b.pending, at |-> r.now,
                        first |-> audit.firstConfirm[i], caller |-> caller,
                        beforeSlots |-> r.slots, afterSlots |-> r'.slots,
                        ownsSlot |-> b.holds, slot |-> b.slot,
                        wasActive |-> i \in audit.wasActive,
                        hadPendingDisplacement |-> i \in audit.pendingDisplaced,
                        forfeitedThenHistoricalSlash |-> i \in audit.historicalSlashAfterForfeit]]
       /\ event' = [kind |-> "Withdrawn", id |-> i, equality |-> r.now=b.confirmed+1]
Forfeit(i) ==
 /\ r.initialized /\ i \in IDs
 /\ LET b == r.bonds[i]
        penalty == (Balance(b)+ForfeitDenominator-1) \div ForfeitDenominator
        effPenalty == IF CorrectForfeitSplit THEN Min(b.eff,penalty)
                      ELSE Max(0,penalty-b.pending)
        pendingPenalty == penalty-effPenalty
    IN /\ b.issued /\ ~b.withdrawn /\ ~r.forfeit[b.key] /\ Balance(b)>0
       /\ r' = [r EXCEPT !.bonds[i].eff=@-effPenalty,
                 !.bonds[i].pending=@-pendingPenalty,
                 !.bonds[i].ready=IF b.pending=pendingPenalty THEN 0 ELSE @,
                 !.bonds[i].exit=Min(@,r.now),
                 !.forfeit[b.key]=TRUE, !.vault=@-penalty]
       /\ audit' = [audit EXCEPT !.sunk[i]=@+penalty, !.effLost[i]=@+effPenalty,
                    !.pendingLost[i]=@+pendingPenalty, !.exitMin[i]=Min(@,r.now),
                    !.forfeitEver=@ \cup {b.key},
                    !.lastForfeit=[present |-> TRUE, eff |-> b.eff, pending |-> b.pending,
                       afterEff |-> r'.bonds[i].eff, afterPending |-> r'.bonds[i].pending,
                       penalty |-> penalty]]
       /\ event' = [kind |-> "Forfeited", id |-> i, equality |-> FALSE]
Slash(i,evidenceGeneration) ==
 /\ r.initialized /\ i \in IDs /\ evidenceGeneration \in 0..r.generation
 /\ LET b == r.bonds[i]
    IN /\ b.issued /\ ~b.withdrawn /\ Balance(b)>0
       /\ r' = [r EXCEPT !.bonds[i].eff=0, !.bonds[i].pending=0, !.bonds[i].ready=0,
                    !.bonds[i].exit=Min(@,r.now), !.vault=@-Balance(b)]
       /\ audit' = [audit EXCEPT !.sunk[i]=@+Balance(b),
                    !.effLost[i]=@+b.eff, !.pendingLost[i]=@+b.pending,
                    !.exitMin[i]=Min(@,r.now),
                    !.historicalSlashAfterForfeit=IF evidenceGeneration<r.generation
                         /\ b.key \in audit.forfeitEver THEN @ \cup {i} ELSE @]
       /\ event' = [kind |-> "Slashed", id |-> i, equality |-> FALSE]
OrdinaryRecover(i) ==
 /\ r.initialized /\ r.generation=0 /\ i \in IDs /\ r.bonds[i].issued
 /\ r' = [r EXCEPT !.generation=1,
                 !.bonds[i].exit=IF r.bonds[i].withdrawn THEN @ ELSE Min(@,r.now)]
 /\ audit' = [audit EXCEPT !.exitMin[i]=IF r.bonds[i].withdrawn THEN @ ELSE Min(@,r.now)]
 /\ event' = [kind |-> "Recovered", id |-> i, equality |-> FALSE]
Tick ==
 /\ r.now < MaxNow
 /\ r' = [r EXCEPT !.snapshots[r.now]=CapturedSnapshot(~EffectiveOnlySnapshot), !.now=@+1]
 /\ audit' = [audit EXCEPT !.rawSnapshots[r.now]={
      [id |-> r.slots[s].id, eff |-> r.bonds[r.slots[s].id].eff,
       active |-> r.bonds[r.slots[s].id].active, exit |-> r.bonds[r.slots[s].id].exit]
      : s \in {slot \in Slots:r.slots[slot].occupied}}]
 /\ event' = [kind |-> "Tick", id |-> 0, equality |-> FALSE]
SelectSnapshot(s,initializing) ==
 /\ s \in Times /\ s < r.now
 /\ (IF initializing THEN ~r.initialized ELSE r.initialized /\ s >= r.activeSnapshot)
 /\ Members(r.snapshots[s],s) # {}
 /\ r' = [r EXCEPT !.initialized=TRUE, !.activeSnapshot=s,
                    !.members=Members(r.snapshots[s],s), !.powers=Powers(r.snapshots[s],s)]
 /\ audit' = [audit EXCEPT !.wasActive=@ \cup Members(r.snapshots[s],s)]
 /\ event' = [kind |-> IF initializing THEN "Initialized" ELSE "Landed", id |-> 0, equality |-> FALSE]
AllActions == Tick \/ (\E k \in Keys, a \in RegistrationAmounts : Register(k,a))
        \/ (\E i \in IDs : Topup(i) \/ Activate(i) \/ RequestExit(i) \/ Confirm(i)
               \/ Forfeit(i) \/ OrdinaryRecover(i) \/ (\E caller \in {1,2}: Withdraw(i,caller))
               \/ (\E g \in 0..1: Slash(i,g)))
        \/ (\E s \in Times : SelectSnapshot(s,TRUE) \/ SelectSnapshot(s,FALSE))
\* Optional source-valid external workload: execute each listed real operation,
\* checking safety after every step, then enable every selected action normally.
SetupNext == /\ IF SlotCount=2
                   THEN CASE setup=0 -> Register(0,1)
                          [] setup=1 -> Register(1,1)
                          [] setup=2 -> Tick
                          [] setup=3 -> Tick
                          [] setup=4 -> SelectSnapshot(2,TRUE)
                          [] setup=5 -> Tick
                   ELSE CASE setup=0 -> Register(0,1)
                        [] setup=1 -> Tick
                        [] setup=2 -> Topup(0)
                        [] setup=3 -> Tick
                        [] setup=4 -> SelectSnapshot(2,TRUE)
                        [] setup=5 -> Register(1,3)
             /\ setup'=setup+1
Next == IF PreparedWorkflow /\ setup<6 THEN SetupNext
        ELSE AllActions /\ UNCHANGED setup
RegistrySpec == Init /\ [][Next]_vars

\* Observation-only assertions below never consult mutant switches and never
\* enable actions. Amount histories use accepted caller amounts and actual cash.
RECURSIVE Sum(_)
Sum(f) == IF DOMAIN f={} THEN 0 ELSE LET i==CHOOSE x \in DOMAIN f: TRUE IN f[i]+Sum([x \in (DOMAIN f)\{i}|->f[x]])
RegistryTypeOK == /\ r.now \in Times /\ r.nextId \in 0..MaxIssued
                  /\ r.vault >= 0 /\ r.generation \in 0..1
                  /\ \A i \in IDs : r.bonds[i].eff>=0 /\ r.bonds[i].pending>=0
RejectedCallsAtomic == ~audit.badRejectedMutation
WithdrawnRecordsClean == \A i \in IDs : r.bonds[i].withdrawn =>
    (r.bonds[i].issued /\ r.bonds[i].eff=0 /\ r.bonds[i].pending=0
     /\ r.bonds[i].owner=0 /\ r.bonds[i].confirmed=0 /\ r.bonds[i].ready=0
     /\ ~r.bonds[i].holds)
RegistrationDecisionCorrect == LET q==audit.lastRegistration
    lowest==CHOOSE s \in Slots : \A t \in Slots : q.values[s]<q.values[t]
                                      \/ (q.values[s]=q.values[t] /\ s<=t)
    expectedAcceptance==q.fresh /\ q.keyAvailable /\ q.amount>=1 /\ q.amount>q.values[lowest]
    IN ~audit.badRegistrationDecision /\ (~q.present \/ (q.accepted=expectedAcceptance /\ (q.accepted =>
         (q.selected=lowest /\ q.newBond.issued /\ q.newBond.key=q.key
          /\ q.newBond.owner=1 /\ q.newBond.pending=0 /\ q.newBond.eff=q.amount
          /\ q.newBond.active=q.at+1 /\ q.newBond.exit=Never /\ q.newBond.confirmed=0))))
DisplacementPreservesBond == LET q==audit.lastRegistration IN
    ~(q.present /\ q.accepted /\ q.oldPresent) \/
      q.oldAfter=[q.oldBefore EXCEPT !.holds=FALSE, !.exit=IF @<q.at THEN @ ELSE q.at]
TopupReadinessConsistent == \A i \in IDs : r.bonds[i].pending=0 => r.bonds[i].ready=0
ForfeitDeductionCorrect == LET f==audit.lastForfeit IN ~f.present \/
    (f.penalty*ForfeitDenominator >= f.eff+f.pending
     /\ (f.penalty-1)*ForfeitDenominator < f.eff+f.pending
     /\ f.afterEff=(IF f.penalty<f.eff THEN f.eff-f.penalty ELSE 0)
     /\ f.afterPending=f.pending-(IF f.penalty>f.eff THEN f.penalty-f.eff ELSE 0))
ExternalConservation == Sum(audit.initial)+Sum(audit.topups)=r.vault+Sum(audit.paid)+Sum(audit.sunk)
PerBondConservation == \A i \in IDs : audit.initial[i]+audit.topups[i]
    =Balance(r.bonds[i])+audit.paid[i]+audit.sunk[i]
VaultBacksPrincipal == r.vault=Sum([i \in IDs |-> Balance(r.bonds[i])])
PrincipalAllocation == /\ ~audit.activationAfterExit
 /\ \A i \in IDs : /\ r.bonds[i].eff=audit.initial[i]+audit.activated[i]-audit.effLost[i]-audit.withdrawnEff[i]
                     /\ r.bonds[i].pending=audit.topups[i]-audit.activated[i]-audit.pendingLost[i]-audit.withdrawnPending[i]
IssuedIdentityPermanent == /\ {i \in IDs:r.bonds[i].issued}=audit.issued
 /\ audit.issued=0..(r.nextId-1)
 /\ \A i \in audit.issued : /\ r.bonds[i].key=audit.keyAtIssue[i]
       /\ (r.bonds[i].withdrawn \/ r.bonds[i].owner=audit.ownerAtIssue[i])
       /\ \A j \in audit.issued : i=j \/ audit.keyAtIssue[i]#audit.keyAtIssue[j]
UnissuedStorageUntouched == \A i \in IDs\audit.issued : r.bonds[i]=RawBond
SlotsAreInverse ==
 /\ \A s \in Slots : r.slots[s].occupied => LET i==r.slots[s].id IN
       r.bonds[i].issued /\ ~r.bonds[i].withdrawn /\ r.bonds[i].holds /\ r.bonds[i].slot=s
 /\ \A i \in IDs : r.bonds[i].holds => r.slots[r.bonds[i].slot]=[occupied |-> TRUE,id |-> i]
WithdrawalPreservesOtherSlots == LET w==audit.lastWithdrawal IN ~w.present \/
    (\A s \in Slots : (s#w.slot \/ ~w.ownsSlot) => w.afterSlots[s]=w.beforeSlots[s])
LifetimeKeysPermanent == {k \in Keys:r.usedKey[k]}=audit.keyEver
LifetimeForfeitPermanent == {k \in Keys:r.forfeit[k]}=audit.forfeitEver
ExitOnlyEarlier == \A i \in audit.issued:r.bonds[i].exit=audit.exitMin[i]
ConfirmationClockStable == \A i \in audit.issued : ~r.bonds[i].withdrawn => r.bonds[i].confirmed=audit.firstConfirm[i]
ConfirmationCovered == ~audit.badConfirmation
WithdrawalAuthorizedAndDelayed == ~audit.badWithdrawal
HistoricalSnapshotsExact == \A s \in Times : s<r.now => r.snapshots[s]=audit.rawSnapshots[s]
ExpectedMembers(s) == {i \in IDs : \E e \in audit.rawSnapshots[s] :
    e.id=i /\ e.eff>0 /\ e.active<=s /\ e.exit>s}
ExpectedPowers(s) == [i \in IDs |-> IF i \in ExpectedMembers(s)
    THEN (CHOOSE e \in audit.rawSnapshots[s] : e.id=i).eff ELSE 0]
ActualCommitteeMatchesSnapshot == ~r.initialized \/
    (r.activeSnapshot<r.now /\ r.members=ExpectedMembers(r.activeSnapshot)
     /\ r.powers=ExpectedPowers(r.activeSnapshot) /\ r.members#{})
NoWithdrawnActiveMember == \A i \in r.members : ~r.bonds[i].withdrawn
PendingRetirementNotReached == LET w==audit.lastWithdrawal IN
    ~(w.present /\ w.id=0 /\ w.slot=0 /\ w.hadPendingDisplacement /\ w.amount>0
      /\ ~w.ownsSlot /\ w.afterSlots[0].occupied /\ w.afterSlots[0].id#0)
ActiveRetirementNotReached == LET w==audit.lastWithdrawal IN
    ~(w.present /\ w.id=0 /\ w.wasActive /\ ~w.ownsSlot /\ w.amount>0
      /\ w.afterSlots[0].occupied /\ w.afterSlots[0].id#0)
MaturityEqualityNotReached == ~(event.kind="Activated" /\ event.equality)
ConfirmationEqualityNotReached == ~(event.kind="Confirmed" /\ event.equality)
PublicZeroAfterForfeitSlashNotReached == LET w==audit.lastWithdrawal IN
    ~(w.present /\ w.amount=0 /\ w.caller=2 /\ w.forfeitedThenHistoricalSlash
       /\ r.forfeit[r.bonds[w.id].key] /\ r.usedKey[r.bonds[w.id].key])
RepeatedActivationNotReached == \A i \in IDs : audit.activationCount[i]<2
=============================================================================
