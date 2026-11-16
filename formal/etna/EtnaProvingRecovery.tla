------------------------- MODULE EtnaProvingRecovery -------------------------
EXTENDS EtnaProvingProgress
CONSTANT Program
VARIABLES pc, receipts
recoveryVars == <<r,seen,stage,producedCount,pc,receipts>>

\* A bounded input script, not another acceptance/proving engine.
Common == <<"ProduceOld1","ProduceOld2","CaptureShort","HistoryOn",
  "AvailableA","AvailableB","CompleteShortA","CompleteShortB","PublishShort">>
OldTask == <<"CaptureOld","CompleteOldA","CompleteOldB","PublishOld">>
Ordinary == <<"TickOne","LandShort","TickTwo","FinalizeOne","PublishSettledAnchor">>
Missing == <<"HistoryOff","UnavailableA","UnavailableB">>
FreshTask == <<"CaptureFresh","PublishFresh">>
LateResources == <<"AttemptAbsentA","AttemptAbsentB","HistoryOnLate",
  "AvailableALate","AvailableBLate">>
FreshEnd == <<"CompleteFreshA","CompleteFreshB","TickFive","LandFresh">>
Script == Common \o (IF Program="OldOutstanding" THEN OldTask ELSE <<>>)
 \o Ordinary \o (IF Program="FreshAbsent" THEN Missing ELSE <<>>)
 \o <<"Recover","ProduceFresh">>
 \o (IF Program="OldOutstanding" THEN <<"AttemptOldLand">>
     ELSE FreshTask \o (IF Program="FreshAbsent" THEN LateResources ELSE <<>>) \o FreshEnd)

\* Deliberately literal expected identities, independent of Cut/Anchor/Statement.
OriginCut == <<"Cut",0,1>>
RecoveryAnchor == [id |-> <<1,1,3>>,generation |-> 1,checkpoint |-> 1,
                   reference |-> 3,cut |-> <<"Cut",0,1>>]
SettledRecord == [present |-> TRUE,generation |-> 0,parent |-> 0,
                  cut |-> <<"Cut",0,1>>,includedAt |-> 1]
FreshData == <<<<"Payload",<<"Cut",1,2>>>>>>
FreshCuts == <<<<"Cut",0,1>>,<<"Cut",1,2>>>>
FreshStatement == <<1,1,2,<<"Ref",4>>,
                    <<<<"Payload",<<"Cut",1,2>>>>>>,
                    <<<<"Cut",0,1>>,<<"Cut",1,2>>>>,3>>
ExpectedFresh == [present |-> TRUE,generation |-> 1,parent |-> 1,terminal |-> 2,
 reference |-> 4,dependency |-> 3,data |-> FreshData,cuts |-> FreshCuts,
 statement |-> FreshStatement]
OldData == <<<<"Payload",<<"Cut",0,1>>>>,<<"Payload",<<"Cut",0,2>>>>>>
OldCuts == <<<<"Cut",0,0>>,<<"Cut",0,1>>,<<"Cut",0,2>>>>
OldStatement == <<0,0,2,<<"Ref",0>>,
 <<<<"Payload",<<"Cut",0,1>>>>,<<"Payload",<<"Cut",0,2>>>>>>,
 <<<<"Cut",0,0>>,<<"Cut",0,1>>,<<"Cut",0,2>>>>,0>>
ExpectedOld == [present |-> TRUE,generation |-> 0,parent |-> 0,terminal |-> 2,
 reference |-> 0,dependency |-> 0,data |-> OldData,cuts |-> OldCuts,
 statement |-> OldStatement]

\* The only operational dispatch: each branch invokes an unchanged M07 action.
Do(label) == CASE label \in {"ProduceOld1","ProduceOld2"} -> Produce(InitialAnchor)
 [] label="CaptureShort" -> Capture(0,0,1,0)
 [] label \in {"HistoryOn","HistoryOnLate"} -> History(TRUE)
 [] label \in {"AvailableA","AvailableALate"} -> Availability("A",TRUE)
 [] label \in {"AvailableB","AvailableBLate"} -> Availability("B",TRUE)
 [] label="CompleteShortA" -> Complete(0,"A",0)
 [] label="CompleteShortB" -> Complete(0,"B",0)
 [] label="PublishShort" -> Publish(0,TRUE)
 [] label="CaptureOld" -> Capture(1,0,2,0)
 [] label \in {"CompleteOldA","CompleteFreshA","AttemptAbsentA"} -> Complete(1,"A",1)
 [] label \in {"CompleteOldB","CompleteFreshB","AttemptAbsentB"} -> Complete(1,"B",1)
 [] label \in {"PublishOld","PublishFresh"} -> Publish(1,TRUE)
 [] label \in {"TickOne","TickTwo","TickFive"} -> Tick
 [] label="LandShort" -> Land(0)
 [] label="FinalizeOne" -> Finalize(1)
 [] label="PublishSettledAnchor" -> PublishAnchor
 [] label="HistoryOff" -> History(FALSE)
 [] label="UnavailableA" -> Availability("A",FALSE)
 [] label="UnavailableB" -> Availability("B",FALSE)
 [] label="Recover" -> Recover
 [] label="ProduceFresh" -> Produce(RecoveryAnchor)
 [] label="CaptureFresh" -> Capture(1,1,2,4)
 [] label \in {"LandFresh","AttemptOldLand"} -> Land(1)

RecoveryInit == Init /\ pc=0 /\ receipts = <<>>
RecoveryStep ==
 /\ pc<Len(Script)
 /\ LET label==Script[pc+1]
        enabled==ENABLED Do(label)
    IN /\ IF enabled THEN Do(label) ELSE UNCHANGED <<r,seen,producedCount>>
       /\ receipts'=Append(receipts,[ordinal |-> pc+1,action |-> label,
            enabled |-> enabled,executed |-> enabled,before |-> r,after |-> r',
            beforeProduced |-> producedCount,afterProduced |-> producedCount'])
 /\ pc'=pc+1
 /\ UNCHANGED stage
RecoveryNext == IF pc<Len(Script) THEN RecoveryStep ELSE UNCHANGED recoveryVars
RecoverySpec == RecoveryInit /\ [][RecoveryNext]_recoveryVars

ReceiptSet == {receipts[i]:i \in 1..Len(receipts)}
RecoveryReceiptAudit ==
 /\ Program \in {"FreshPresent","FreshAbsent","OldOutstanding"}
 /\ pc \in 0..Len(Script) /\ Len(receipts)=pc /\ stage=0
 /\ \A i \in 1..Len(receipts):
      /\ receipts[i].ordinal=i /\ receipts[i].action=Script[i]
      /\ receipts[i].executed=receipts[i].enabled
      /\ (i>1 => receipts[i].before=receipts[i-1].after
                   /\ receipts[i].beforeProduced=receipts[i-1].afterProduced)
 /\ (pc>0 => r=receipts[pc].after /\ producedCount=receipts[pc].afterProduced)
RecoveryEnabledAudit == \A q \in ReceiptSet:
 /\ q.enabled=~(q.action \in {"AttemptAbsentA","AttemptAbsentB","AttemptOldLand"})
 /\ (~q.executed => q.before=q.after /\ q.beforeProduced=q.afterProduced)

RecoveryOrdinaryAudit ==
 /\ \A q \in ReceiptSet:q.action="LandShort" =>
       q.before.now=1 /\ q.before.included=0 /\ q.after.included=1
       /\ q.after.records[1]=SettledRecord
 /\ \A q \in ReceiptSet:q.action="FinalizeOne" =>
       q.before.now=2 /\ q.before.included=1 /\ q.after.finalized=1
       /\ q.after.finalizedBlock=1 /\ q.after.records[1]=SettledRecord
 /\ \A q \in ReceiptSet:q.action="PublishSettledAnchor" =>
       [id |-> <<0,1,1>>,generation |-> 0,checkpoint |-> 1,
        reference |-> 1,cut |-> <<"Cut",0,1>>] \in q.after.anchors
 /\ \A f \in seen.finalizations:f.kind="Ordinary" =>
       f.height=1 /\ f.cut= <<"Cut",0,1>> /\ f.block=1 /\ f.at=2 /\ f.generation=0

RecoveryOriginAudit == \A q \in ReceiptSet:q.action="Recover" =>
 /\ q.before.generation=0 /\ q.before.now=2 /\ q.before.included=1 /\ q.before.head=2
 /\ q.before.finalized=1 /\ q.before.finalizedBlock=1
 /\ q.before.records[1]=SettledRecord /\ q.before.canonical[2]= <<"Cut",0,2>>
 /\ q.after.generation=1 /\ q.after.head=1 /\ q.after.start=1 /\ q.after.included=1
 /\ q.after.now=4 /\ q.after.dependency=3 /\ q.after.finalized=1 /\ q.after.finalizedBlock=3
 /\ q.after.parentAnchor=RecoveryAnchor /\ q.after.anchors=q.before.anchors \cup {RecoveryAnchor}
 /\ q.after.records=q.before.records /\ q.after.canonical=q.before.canonical
 /\ q.after.jobs=q.before.jobs /\ q.after.proofs=q.before.proofs
 /\ q.after.published=q.before.published /\ q.afterProduced=q.beforeProduced

RecoveryResourceAudit ==
 /\ \A q \in ReceiptSet:q.action="Recover" =>
       q.before.privateHistory=q.after.privateHistory /\ q.before.available=q.after.available
       /\ q.after.privateHistory=(Program#"FreshAbsent")
       /\ q.after.available=[b \in {"A","B"} |-> Program#"FreshAbsent"]
 /\ \A q \in ReceiptSet:
       (Program="FreshAbsent" /\ q.action \in {"CaptureFresh","PublishFresh","AttemptAbsentA","AttemptAbsentB"}) =>
        /\ ~q.before.privateHistory /\ ~q.after.privateHistory
        /\ q.before.available=[b \in {"A","B"} |-> FALSE]
        /\ q.after.available=[b \in {"A","B"} |-> FALSE]
        /\ ~q.before.proofs[<<1,"A">>].present /\ ~q.after.proofs[<<1,"A">>].present
        /\ ~q.before.proofs[<<1,"B">>].present /\ ~q.after.proofs[<<1,"B">>].present
 /\ \A q \in ReceiptSet:q.action="HistoryOnLate" =>
       ~q.before.privateHistory /\ q.after.privateHistory /\ q.before.available=q.after.available
 /\ \A q \in ReceiptSet:q.action="AvailableALate" =>
       q.before.privateHistory /\ ~q.before.available["A"] /\ q.after.available["A"]
       /\ ~q.before.available["B"] /\ ~q.after.available["B"]
 /\ \A q \in ReceiptSet:q.action="AvailableBLate" =>
       q.before.privateHistory /\ q.before.available["A"] /\ q.after.available["A"]
       /\ ~q.before.available["B"] /\ q.after.available["B"]

RecoveryFreshAudit ==
 /\ \A q \in ReceiptSet:q.action="ProduceFresh" =>
       q.before.generation=1 /\ q.before.head=1 /\ q.before.canonical[2]= <<"Cut",0,2>>
       /\ q.after.head=2 /\ q.after.canonical[1]= <<"Cut",0,1>>
       /\ q.after.canonical[2]= <<"Cut",1,2>> /\ q.after.parentAnchor=RecoveryAnchor
 /\ \A q \in ReceiptSet:q.action="CaptureFresh" =>
       ~q.before.jobs[1].present /\ q.before.now=4 /\ q.before.start=1
       /\ q.after.jobs[1]=ExpectedFresh /\ q.after.jobs[0]=q.before.jobs[0]
 /\ \A q \in ReceiptSet:q.action="LandFresh" =>
       /\ q.before.now=5 /\ q.before.generation=1 /\ q.before.included=1
       /\ q.before.jobs[1]=ExpectedFresh /\ q.before.published[1]=FreshData
       /\ q.before.proofs[<<1,"A">>].statement=FreshStatement
       /\ q.before.proofs[<<1,"B">>].statement=FreshStatement
       /\ q.after.included=2 /\ q.after.records[1]=SettledRecord
       /\ q.after.records[2]=[present |-> TRUE,generation |-> 1,parent |-> 1,
                              cut |-> <<"Cut",1,2>>,includedAt |-> 5]

\* Literal premises, not a second Ready implementation. Result is actual ENABLED Land.
RecoveryGenerationAudit ==
 /\ \A l \in seen.lands:l.currentGeneration=seen.jobInputs[l.job].generation
 /\ \A q \in ReceiptSet:q.action="AttemptOldLand" =>
       /\ q.before.jobs[1]=ExpectedOld
       /\ q.before.now=4 /\ q.before.generation=1 /\ q.before.start=1
       /\ q.before.included=1 /\ q.before.head=2
       /\ q.before.records[0].present /\ q.before.records[1]=SettledRecord
       /\ q.before.jobs[1].cuts[2]=q.before.records[1].cut
       /\ q.before.jobs[1].reference<q.before.now
       /\ q.before.now-q.before.jobs[1].reference<=5
       /\ q.before.jobs[1].reference-q.before.jobs[1].dependency<=5
       /\ q.before.published[1]=OldData /\ Len(q.before.published[1])=2
       /\ q.before.proofs[<<1,"A">>].present /\ q.before.proofs[<<1,"B">>].present
       /\ q.before.proofs[<<1,"A">>].statement=OldStatement
       /\ q.before.proofs[<<1,"B">>].statement=OldStatement
       /\ ~q.enabled /\ ~q.executed /\ q.after=q.before

RecoveryAudits == RecoveryReceiptAudit /\ RecoveryEnabledAudit /\ RecoveryOrdinaryAudit
 /\ RecoveryOriginAudit /\ RecoveryResourceAudit /\ RecoveryFreshAudit /\ RecoveryGenerationAudit
RecoveryCompleted ==
 /\ pc=Len(Script) /\ RecoveryAudits /\ producedCount=3
 /\ Cardinality(seen.recoveries)=1 /\ Cardinality(seen.blocks)=3
 /\ Cardinality(seen.finalizations)=3 /\ r.records[1]=SettledRecord
 /\ r.start=1 /\ r.generation=1 /\ r.head=2 /\ r.dependency=3
 /\ r.finalized=1 /\ r.finalizedBlock=3 /\ r.parentAnchor=RecoveryAnchor
 /\ IF Program="OldOutstanding" THEN
       /\ receipts[pc].action="AttemptOldLand" /\ ~receipts[pc].executed
       /\ r.now=4 /\ r.included=1 /\ Cardinality(seen.lands)=1 /\ r.jobs[1]=ExpectedOld
     ELSE
       /\ receipts[pc].action="LandFresh" /\ receipts[pc].executed
       /\ r.now=5 /\ r.included=2 /\ Cardinality(seen.lands)=2 /\ r.jobs[1]=ExpectedFresh
FreshPresentNotReached == ~(Program="FreshPresent" /\ RecoveryCompleted)
FreshAbsentNotReached == ~(Program="FreshAbsent" /\ RecoveryCompleted)
OldOutstandingNotReached == ~(Program="OldOutstanding" /\ RecoveryCompleted)
=============================================================================
