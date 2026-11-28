-------------------- MODULE EtnaRegistryRetirementProduct --------------------
EXTENDS EtnaRegistry, Sequences
CONSTANTS RetirementPrograms, OmitAttempt
ASSUME /\ RetirementPrograms # {} /\ RetirementPrograms \subseteq 1..6
       /\ OmitAttempt \in {0,10,21}
VARIABLES retirementProgram, retirementIndex, retirementReceipts
RetirementLocal == <<retirementProgram,retirementIndex,retirementReceipts>>
RetirementVars == <<vars,RetirementLocal>>
RC(name,a,b) == <<name,a,b>>
A1 == RC("Activate",1,0)
R0 == RC("Recover",0,0)
F0 == RC("Forfeit",0,0)
RetirementOrders == <<<<A1,R0,F0>>,<<A1,F0,R0>>,<<R0,A1,F0>>,
                      <<R0,F0,A1>>,<<F0,A1,R0>>,<<F0,R0,A1>>>>
RetirementCalls ==
 <<RC("Register",0,1),RC("Register",1,1),RC("Tick",0,0),
   RC("Tick",0,0),RC("Select",2,TRUE),RC("Topup",0,0),
   RC("Topup",1,0),RC("Tick",0,0),RC("Register",2,2),
   RC("Register",2,4),RC("Activate",0,0)>>
 \o RetirementOrders[retirementProgram]
 \o <<RC("Slash",0,0),RC("Tick",0,0),RC("Select",4,FALSE),
      RC("Confirm",0,0),RC("Tick",0,0),RC("Select",5,FALSE),
      RC("Withdraw",0,2)>>
RetirementCall(e) == CASE
    e[1]="Register" -> Register(e[2],e[3])
 [] e[1]="Tick" -> Tick
 [] e[1]="Select" -> SelectSnapshot(e[2],e[3])
 [] e[1]="Topup" -> Topup(e[2])
 [] e[1]="Activate" -> Activate(e[2])
 [] e[1]="Recover" -> OrdinaryRecover(e[2])
 [] e[1]="Forfeit" -> Forfeit(e[2])
 [] e[1]="Slash" -> Slash(e[2],e[3])
 [] e[1]="Confirm" -> Confirm(e[2])
 [] e[1]="Withdraw" -> Withdraw(e[2],e[3])
RetirementRaw == [state |-> r,journal |-> audit,lastEvent |-> event,setupValue |-> setup]
RetirementInit == /\ Init /\ retirementProgram \in RetirementPrograms
 /\ retirementIndex=1 /\ retirementReceipts= <<>>
\* Only the named omission control suppresses a call. Expected outcomes are
\* observers below and NEVER constrain actual action execution or acceptance.
RetirementStep ==
 /\ retirementIndex<=21
 /\ UNCHANGED <<setup,retirementProgram>>
 /\ LET e==RetirementCalls[retirementIndex]
        enabled==ENABLED RetirementCall(e)
        executed==enabled /\ retirementIndex#OmitAttempt
    IN /\ IF executed THEN RetirementCall(e) ELSE UNCHANGED <<r,audit,event>>
       /\ retirementReceipts'=Append(retirementReceipts,
           [attempt |-> retirementIndex,call |-> e,enabled |-> enabled,
            executed |-> executed,before |-> RetirementRaw,after |-> RetirementRaw'])
 /\ retirementIndex'=retirementIndex+1
RetirementNext == RetirementStep
RetirementSpec == RetirementInit /\ [][RetirementNext]_RetirementVars

\* Entirely literal operational-state oracle for the six NORMAL schedules.
\* These records do not invoke inherited getters, oracles, actions or journals.
LiteralEmptyBond == [issued |-> FALSE,withdrawn |-> FALSE,key |-> 0,owner |-> 0,
 eff |-> 0,pending |-> 0,active |-> 0,exit |-> 0,confirmed |-> 0,
 holds |-> FALSE,slot |-> 0,ready |-> 0]
LiteralEmptySlot == [occupied |-> FALSE,id |-> 0]
LiteralEntry(i,e,a,x) == [id |-> i,eff |-> e,active |-> a,exit |-> x]
LiteralEarly == {LiteralEntry(0,1,2,9),LiteralEntry(1,1,2,9)}
LiteralLate == {LiteralEntry(1,3,2,9),LiteralEntry(2,4,5,9)}
\* Direct row positions in the six independently enumerated permutations.
ActivationRows == <<12,12,13,14,13,14>>
RecoveryRows == <<13,14,12,12,14,13>>
ForfeitRows == <<14,13,14,13,12,12>>
LiteralState(n) ==
 LET activated==n>=ActivationRows[retirementProgram]
     recovered==n>=RecoveryRows[retirementProgram]
     forfeited==n>=ForfeitRows[retirementProgram]
     b0==IF n=0 THEN LiteralEmptyBond ELSE
       [issued |-> TRUE,withdrawn |-> n=21,key |-> 0,
        owner |-> IF n=21 THEN 0 ELSE 1,
        eff |-> IF forfeited THEN 0 ELSE 1,
        pending |-> IF n<6 \/ n>=15 THEN 0 ELSE IF forfeited THEN 1 ELSE 2,
        active |-> 2,exit |-> IF n>=10 THEN 4 ELSE 9,
        confirmed |-> IF n>=18 /\ n<21 THEN 5 ELSE 0,
        holds |-> n<10,slot |-> 0,ready |-> IF n>=6 /\ n<15 THEN 4 ELSE 0]
     b1==IF n<2 THEN LiteralEmptyBond ELSE
       [issued |-> TRUE,withdrawn |-> FALSE,key |-> 1,owner |-> 1,
        eff |-> IF activated THEN 3 ELSE 1,
        pending |-> IF n>=7 /\ ~activated THEN 2 ELSE 0,
        active |-> 2,exit |-> 9,confirmed |-> 0,holds |-> TRUE,slot |-> 1,
        ready |-> IF n>=7 /\ ~activated THEN 4 ELSE 0]
     b2==IF n<10 THEN LiteralEmptyBond ELSE
       [issued |-> TRUE,withdrawn |-> FALSE,key |-> 2,owner |-> 1,
        eff |-> 4,pending |-> 0,active |-> 5,exit |-> 9,confirmed |-> 0,
        holds |-> TRUE,slot |-> 0,ready |-> 0]
 IN [bonds |-> [i \in 0..3 |-> CASE i=0 -> b0 [] i=1 -> b1 [] i=2 -> b2
                                     [] OTHER -> LiteralEmptyBond],
     slots |-> [s \in 0..1 |-> IF s=0
        THEN IF n=0 THEN LiteralEmptySlot ELSE [occupied |-> TRUE,id |-> IF n<10 THEN 0 ELSE 2]
        ELSE IF n<2 THEN LiteralEmptySlot ELSE [occupied |-> TRUE,id |-> 1]],
     now |-> CASE n<3 -> 1 [] n<4 -> 2 [] n<8 -> 3 [] n<16 -> 4 [] n<19 -> 5 [] OTHER -> 6,
     nextId |-> CASE n=0 -> 0 [] n=1 -> 1 [] n<10 -> 2 [] OTHER -> 3,
     usedKey |-> [k \in 0..2 |-> CASE k=0 -> n>=1 [] k=1 -> n>=2 [] OTHER -> n>=10],
     forfeit |-> [k \in 0..2 |-> k=0 /\ forfeited],
     calls |-> [i \in 0..3 |-> IF (i=0 /\ n>=6) \/ (i=1 /\ n>=7) THEN 1 ELSE 0],
     vault |-> (IF n>=1 THEN 1 ELSE 0)+(IF n>=2 THEN 1 ELSE 0)
               +(IF n>=6 THEN 2 ELSE 0)+(IF n>=7 THEN 2 ELSE 0)
               +(IF n>=10 THEN 4 ELSE 0)-(IF forfeited THEN 2 ELSE 0)-(IF n>=15 THEN 1 ELSE 0),
     initialized |-> n>=5,generation |-> IF recovered THEN 1 ELSE 0,
     activeSnapshot |-> CASE n<5 -> 0 [] n<17 -> 2 [] n<20 -> 4 [] OTHER -> 5,
     members |-> CASE n<5 -> {} [] n<17 -> {0,1} [] n<20 -> {1} [] OTHER -> {1,2},
     powers |-> [i \in 0..3 |-> CASE n<5 -> 0
        [] n<17 -> IF i \in {0,1} THEN 1 ELSE 0
        [] n<20 -> IF i=1 THEN 3 ELSE 0
        [] OTHER -> CASE i=1 -> 3 [] i=2 -> 4 [] OTHER -> 0],
     snapshots |-> [t \in 1..6 |-> CASE
          t=1 /\ n>=3 -> LiteralEarly
       [] t=2 /\ n>=4 -> LiteralEarly
       [] t=3 /\ n>=8 -> LiteralEarly
       [] t=4 /\ n>=16 -> LiteralLate
       [] t=5 /\ n>=19 -> LiteralLate
       [] OTHER -> {}]]

RetirementReceiptAudit ==
 /\ setup=0 /\ retirementIndex=Len(retirementReceipts)+1
 /\ \A i \in 1..Len(retirementReceipts): LET q==retirementReceipts[i] IN
      /\ q.attempt=i /\ q.call=RetirementCalls[i]
      /\ q.executed=(q.enabled /\ i#OmitAttempt)
      /\ i>1 => q.before=retirementReceipts[i-1].after
      /\ ~q.executed => q.after=q.before
 /\ Len(retirementReceipts)>0 => RetirementRaw=retirementReceipts[Len(retirementReceipts)].after
\* Dedicated first audit for the occupied-slot effective-only source fault.
\* In particular, the enabled Register is executed; acceptance is raw r change.
RegistryRawAdmissionAudit == Len(retirementReceipts)>=9 =>
 LET q==retirementReceipts[9] IN
 /\ q.enabled /\ q.executed /\ q.before.state=LiteralState(8)
 /\ q.after.state=q.before.state /\ q.after.state.nextId=2
 /\ ~q.after.state.usedKey[2] /\ q.after.state.vault=6
 /\ q.after.lastEvent=[kind |-> "Rejected",id |-> 0,equality |-> FALSE]
RetirementLiteralAudit == OmitAttempt=0 =>
 /\ r=LiteralState(Len(retirementReceipts))
 /\ \A i \in 1..Len(retirementReceipts): LET q==retirementReceipts[i] IN
      /\ q.before.state=LiteralState(i-1) /\ q.after.state=LiteralState(i)
      /\ q.enabled=(i#11) /\ q.executed=(i#11)
\* Cash is reconstructed from actual before/after vault movement, not audit sums.
RetirementDeposits == {1,2,6,7,10}
CashIn(i) == LET q==retirementReceipts[i] IN
 IF i \in RetirementDeposits THEN q.after.state.vault-q.before.state.vault ELSE 0
CashSink(i) == LET q==retirementReceipts[i] IN
 IF q.call[1] \in {"Forfeit","Slash"} THEN q.before.state.vault-q.after.state.vault ELSE 0
CashPaid(i) == LET q==retirementReceipts[i] IN
 IF q.call[1]="Withdraw" THEN q.before.state.vault-q.after.state.vault ELSE 0
RECURSIVE LiteralTotal(_)
LiteralTotal(f) == IF DOMAIN f={} THEN 0 ELSE
 LET k==CHOOSE x \in DOMAIN f:TRUE IN f[k]+LiteralTotal([j \in (DOMAIN f)\{k}|->f[j]])
RetirementCash == [deposited |-> LiteralTotal([i \in 1..Len(retirementReceipts)|->CashIn(i)]),
 sunk |-> LiteralTotal([i \in 1..Len(retirementReceipts)|->CashSink(i)]),
 paid |-> LiteralTotal([i \in 1..Len(retirementReceipts)|->CashPaid(i)])]
RetirementCashAudit == /\ RetirementCash.deposited=r.vault+RetirementCash.sunk+RetirementCash.paid
 /\ \A i \in 1..Len(retirementReceipts): CashIn(i)>=0 /\ CashSink(i)>=0 /\ CashPaid(i)>=0
RetirementComplete ==
 /\ OmitAttempt=0 /\ retirementIndex=22 /\ Len(retirementReceipts)=21
 /\ RetirementReceiptAudit /\ RegistryRawAdmissionAudit /\ RetirementLiteralAudit
 /\ RetirementCash=[deposited |-> 10,sunk |-> 3,paid |-> 0]
 /\ r=LiteralState(21)
 /\ retirementReceipts[11].enabled=FALSE
 /\ retirementReceipts[15].before.state.generation=1
 /\ retirementReceipts[15].before.state.bonds[0].pending=1
 /\ retirementReceipts[18].before.state.activeSnapshot=4
 /\ retirementReceipts[21].enabled /\ retirementReceipts[21].executed
 /\ retirementReceipts[21].before.state.bonds[0].confirmed=5
 /\ retirementReceipts[21].before.state.bonds[0].owner=1
 /\ retirementReceipts[21].after.state.bonds[0].owner=0
RetirementTerminalAudit == (OmitAttempt=0 /\ retirementIndex=22) => RetirementComplete
RetirementCompleteNotReached == ~RetirementComplete
\* Omission endpoints are separate positive partial-history witnesses. Neither
\* mode uses the full literal invariant or receives complete-history credit.
RetirementPartialReplacement ==
 /\ OmitAttempt=10 /\ retirementIndex=22 /\ Len(retirementReceipts)=21
 /\ \A i \in 1..21 : retirementReceipts[i].enabled /\ retirementReceipts[i].executed=(i#10)
 /\ retirementReceipts[10].enabled /\ ~retirementReceipts[10].executed
 /\ retirementReceipts[10].after=retirementReceipts[10].before
 /\ retirementReceipts[11].enabled /\ retirementReceipts[11].executed
 /\ retirementReceipts[11].after.state.bonds[0].eff=3
 /\ retirementReceipts[11].after.state.bonds[0].pending=0
 /\ retirementReceipts[21].executed /\ r.bonds[0].withdrawn
 /\ r.bonds[2]=LiteralEmptyBond /\ r.nextId=2 /\ ~r.usedKey[2]
 /\ r.slots[0]=LiteralEmptySlot /\ r.slots[1]=[occupied |-> TRUE,id |-> 1]
 /\ r.members={1} /\ r.powers=[i \in 0..3 |-> IF i=1 THEN 3 ELSE 0]
 /\ RetirementCash=[deposited |-> 6,sunk |-> 3,paid |-> 0] /\ r.vault=3
 /\ r.generation=1 /\ r.usedKey[0] /\ r.forfeit[0]
RetirementPartialWithdrawal ==
 /\ OmitAttempt=21 /\ retirementIndex=22 /\ Len(retirementReceipts)=21
 /\ \A i \in 1..21 : retirementReceipts[i].enabled=(i#11)
      /\ retirementReceipts[i].executed=(i \notin {11,21})
 /\ retirementReceipts[21].enabled /\ ~retirementReceipts[21].executed
 /\ retirementReceipts[21].after=retirementReceipts[21].before
 /\ r=LiteralState(20) /\ ~r.bonds[0].withdrawn
 /\ r.bonds[0].eff=0 /\ r.bonds[0].pending=0 /\ r.bonds[0].owner=1
 /\ r.bonds[0].confirmed=5 /\ r.now=6
 /\ RetirementCash=[deposited |-> 10,sunk |-> 3,paid |-> 0]
RetirementPartialTerminalAudit == retirementIndex=22 =>
 (CASE OmitAttempt=10 -> RetirementPartialReplacement
    [] OmitAttempt=21 -> RetirementPartialWithdrawal [] OTHER -> RetirementComplete)
RetirementPartialNotReached == ~(RetirementPartialReplacement \/ RetirementPartialWithdrawal)
=============================================================================
