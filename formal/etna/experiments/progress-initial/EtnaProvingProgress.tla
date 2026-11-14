------------------------- MODULE EtnaProvingProgress -------------------------
EXTENDS Naturals, Integers, FiniteSets, Sequences, TLC
CONSTANTS MaxHead, MaxProduces, MaxTime, U, BlobCapacity, RefWindow, AncestryBudget,
          Prefix, CreditIncluded, CreditProved, CheckGeneration,
          AllowReferenceRewrite, AllowGenerationRewrite, CheckFullData,
          CheckBackendBinding, CorrectActualParent, CandidateAnchorGuard
Jobs == 0..1
Heights == 0..MaxHead
Gens == 0..1
Backends == {"A","B"}
ProofKeys == Jobs \X Backends
Genesis == <<"Cut",0,0>>
EmptyProof == [present |-> FALSE, statement |-> <<>>]
EmptyJob == [present |-> FALSE,generation |-> 0,parent |-> 0,terminal |-> 0,
             reference |-> 0,dependency |-> 0,data |-> <<>>,cuts |-> <<>>,statement |-> <<>>]
GenesisRecord == [present |-> TRUE,generation |-> 0,parent |-> 0,cut |-> Genesis,includedAt |-> 0]
AbsentRecord == [present |-> FALSE,generation |-> 0,parent |-> 0,cut |-> Genesis,includedAt |-> 0]
Anchor(g,h,t,cut) == [id |-> <<g,h,t>>,generation |-> g,checkpoint |-> h,reference |-> t,cut |-> cut]
InitialAnchor == Anchor(0,0,0,Genesis)
VARIABLES r, seen, stage, producedCount
vars == <<r,seen,stage,producedCount>>
Init ==
 /\ stage=0 /\ producedCount=0
 /\ r=[head |-> 0,generation |-> 0,now |-> 0,included |-> 0,finalized |-> 0,
       start |-> 0,dependency |-> 0,parentAnchor |-> InitialAnchor,
       anchors |-> {InitialAnchor},jobs |-> [j \in Jobs |-> EmptyJob],
       privateHistory |-> FALSE,available |-> [b \in Backends |-> FALSE],
       proofs |-> [p \in ProofKeys |-> EmptyProof],published |-> [j \in Jobs |-> <<>>],
       records |-> [h \in Heights |-> IF h=0 THEN GenesisRecord ELSE AbsentRecord],
       canonical |-> [h \in Heights |-> Genesis]]
 /\ seen=[blocks |-> {},jobInputs |-> [j \in Jobs |-> EmptyJob],
       proofInputs |-> [p \in ProofKeys |-> <<>>],lands |-> {},
       expectedRecords |-> [h \in Heights |-> IF h=0 THEN GenesisRecord ELSE AbsentRecord],
       finalizations |-> {[height |-> 0,cut |-> Genesis,at |-> 0]},
       anchors |-> {InitialAnchor},applied |-> [h \in Heights |-> 0],recoveries |-> {}]

Cut(g,h) == <<"Cut",g,h>>
Data(p,h) == [i \in 1..(h-p) |-> <<"Payload",r.canonical[p+i]>>]
Cuts(p,h) == [i \in 1..(h-p+1) |-> r.canonical[p+i-1]]
Statement(g,p,h,t,data,cuts,dep) == <<g,p,h,<<"Ref",t>>,data,cuts,dep>>
Produce(a) ==
 /\ producedCount<MaxProduces /\ r.head<MaxHead /\ a \in r.anchors
 /\ a.generation=r.generation /\ a.reference<=r.now /\ r.now-a.reference<=RefWindow
 /\ LET completed=={0} \cup {r.jobs[j].terminal : j \in {x \in Jobs :
          r.proofs[<<x,"A">>].present /\ r.proofs[<<x,"B">>].present}}
        proved==CHOOSE h \in completed : \A x \in completed:h>=x
        credit==IF CreditIncluded THEN r.included ELSE IF CreditProved THEN proved ELSE a.checkpoint
        used==IF CandidateAnchorGuard THEN credit ELSE r.parentAnchor.checkpoint
        h==r.head+1
    IN /\ h-used<=U
       /\ r'=[r EXCEPT !.head=h,!.canonical[h]=Cut(r.generation,h),!.parentAnchor=a]
       /\ seen'=[seen EXCEPT !.blocks=@ \cup {[generation |-> r.generation,
              height |-> r'.head,parentHeight |-> r.head,parentCut |-> r.canonical[r.head],
              outputCut |-> r'.canonical[h],inputAnchor |-> a,selected |-> r'.parentAnchor,
              beforeAnchor |-> r.parentAnchor,at |-> r.now]}]
       /\ producedCount'=producedCount+1
Capture(j,p,h,t) ==
 /\ j \in Jobs /\ ~r.jobs[j].present /\ t=r.now
 /\ p \in r.start..r.included /\ h \in (r.included+1)..r.head
 /\ r.records[p].present /\ (r.records[p].generation=r.generation \/ p=r.start)
 /\ LET job==[present |-> TRUE,generation |-> r.generation,parent |-> p,terminal |-> h,
               reference |-> t,dependency |-> r.dependency,data |-> Data(p,h),cuts |-> Cuts(p,h),
               statement |-> Statement(r.generation,p,h,t,Data(p,h),Cuts(p,h),r.dependency)]
    IN /\ r'=[r EXCEPT !.jobs[j]=job]
       /\ seen'=[seen EXCEPT !.jobInputs[j]=[present |-> TRUE,generation |-> r.generation,
              parent |-> p,terminal |-> h,reference |-> t,dependency |-> r.dependency,
              data |-> [i \in 1..(h-p) |-> <<"Payload",r.canonical[p+i]>>],
              cuts |-> [i \in 1..(h-p+1) |-> r.canonical[p+i-1]],
              statement |-> <<r.generation,p,h,<<"Ref",t>>,
                   [i \in 1..(h-p) |-> <<"Payload",r.canonical[p+i]>>],
                   [i \in 1..(h-p+1) |-> r.canonical[p+i-1]],r.dependency>>]]
 /\ UNCHANGED producedCount
History(v) == /\ v \in BOOLEAN /\ r'=[r EXCEPT !.privateHistory=v] /\ UNCHANGED <<seen,producedCount>>
Availability(b,v) == /\ b \in Backends /\ v \in BOOLEAN /\ r'=[r EXCEPT !.available[b]=v]
                     /\ UNCHANGED <<seen,producedCount>>
Complete(target,b,source) ==
 /\ target \in Jobs /\ source \in Jobs /\ b \in Backends
 /\ r.jobs[target].present /\ r.jobs[source].present /\ r.privateHistory /\ r.available[b]
 /\ r.jobs[source].reference-r.jobs[source].dependency<=AncestryBudget
 /\ r'=[r EXCEPT !.proofs[<<target,b>>]=[present |-> TRUE,statement |-> r.jobs[source].statement]]
 /\ seen'=[seen EXCEPT !.proofInputs[<<target,b>>]=seen.jobInputs[source].statement]
 /\ UNCHANGED producedCount
Suffix(j) == [i \in 1..(r.jobs[j].terminal-r.included) |->
                    r.jobs[j].data[r.included-r.jobs[j].parent+i]]
Publish(j,full) ==
 /\ j \in Jobs /\ r.jobs[j].present /\ full \in BOOLEAN
 /\ r'=[r EXCEPT !.published[j]=IF full THEN r.jobs[j].data ELSE Suffix(j)]
 /\ UNCHANGED <<seen,producedCount>>
Ready(j) == LET x==r.jobs[j] IN
 /\ x.present /\ x.parent<=r.included /\ r.included<x.terminal
 /\ (~CheckGeneration \/ x.generation=r.generation)
 /\ x.reference<=r.now /\ r.now-x.reference<=RefWindow /\ x.reference-x.dependency<=AncestryBudget
 /\ r.records[x.parent].present /\ x.cuts[r.included-x.parent+1]=r.records[r.included].cut
 /\ r.proofs[<<j,"A">>].present /\ r.proofs[<<j,"B">>].present
 /\ (~CheckBackendBinding \/ (r.proofs[<<j,"A">>].statement=x.statement /\ r.proofs[<<j,"B">>].statement=x.statement))
 /\ r.published[j]=(IF CheckFullData THEN x.data ELSE Suffix(j))
 /\ Len(r.published[j])<=BlobCapacity
Land(j) ==
 /\ j \in Jobs /\ Ready(j)
 /\ LET x==r.jobs[j]
        rec==[present |-> TRUE,generation |-> r.generation,
               parent |-> IF CorrectActualParent THEN r.included ELSE x.parent,
               cut |-> x.cuts[Len(x.cuts)],includedAt |-> r.now]
    IN /\ r'=[r EXCEPT !.included=x.terminal,!.records[x.terminal]=rec]
       /\ seen'=[seen EXCEPT !.lands=@ \cup {[job |-> j,currentGeneration |-> r.generation,
              beforeC |-> r.included,afterC |-> r'.included,record |-> r'.records[x.terminal],
              beforeHead |-> r.head,afterHead |-> r'.head,beforeAnchor |-> r.parentAnchor,
              published |-> r.published[j],proofA |-> r.proofs[<<j,"A">>].statement,
              proofB |-> r.proofs[<<j,"B">>].statement,at |-> r.now]},
              !.expectedRecords[x.terminal]=[present |-> TRUE,generation |-> r.generation,
                     parent |-> r.included,cut |-> seen.jobInputs[j].cuts[Len(seen.jobInputs[j].cuts)],includedAt |-> r.now],
              !.applied=[h \in Heights |-> seen.applied[h]+(IF r.included<h /\ h<=x.terminal THEN 1 ELSE 0)]]
 /\ UNCHANGED producedCount
Finalize(h) ==
 /\ h \in r.finalized..r.included /\ r.records[h].present /\ r.records[h].includedAt<r.now
 /\ r'=[r EXCEPT !.finalized=h]
 /\ seen'=[seen EXCEPT !.finalizations=@ \cup {[height |-> h,cut |-> seen.expectedRecords[h].cut,at |-> r.now]}]
 /\ UNCHANGED producedCount
PublishAnchor ==
 /\ LET h==r.finalized
    IN /\ r'=[r EXCEPT !.anchors=@ \cup {Anchor(r.generation,h,r.now,r.records[h].cut)}]
       /\ seen'=[seen EXCEPT !.anchors=@ \cup {[id |-> <<r.generation,h,r.now>>,
                 generation |-> r.generation,checkpoint |-> h,reference |-> r.now,
                 cut |-> seen.expectedRecords[h].cut]}]
 /\ UNCHANGED producedCount
Tick == /\ r.now<MaxTime /\ r'=[r EXCEPT !.now=@+1] /\ UNCHANGED <<seen,producedCount>>
Recover ==
 /\ r.generation=0
 /\ LET a==Anchor(1,r.included,r.now,r.records[r.included].cut)
    IN /\ r'=[r EXCEPT !.generation=1,!.head=r.included,!.start=r.included,
              !.dependency=r.now,!.finalized=r.included,!.parentAnchor=a,!.anchors=@ \cup {a}]
       /\ seen'=[seen EXCEPT !.anchors=@ \cup {[id |-> <<1,r.included,r.now>>,generation |-> 1,
                  checkpoint |-> r.included,reference |-> r.now,cut |-> seen.expectedRecords[r.included].cut]},
              !.finalizations=@ \cup {[height |-> r.included,cut |-> seen.expectedRecords[r.included].cut,at |-> r.now]},
              !.recoveries=@ \cup {[generation |-> 1,height |-> r.included,
                  cut |-> seen.expectedRecords[r.included].cut,oldAvailable |-> r.available,
                  newAvailable |-> r'.available,oldHistory |-> r.privateHistory,newHistory |-> r'.privateHistory]}]
 /\ UNCHANGED producedCount
Rewrite(j,which) ==
 /\ j \in Jobs /\ r.jobs[j].present
 /\ r.proofs[<<j,"A">>].present /\ r.proofs[<<j,"B">>].present
 /\ r.proofs[<<j,"A">>].statement=r.jobs[j].statement /\ r.proofs[<<j,"B">>].statement=r.jobs[j].statement
 /\ IF which="Reference" THEN AllowReferenceRewrite /\ r.now>r.jobs[j].reference
                             /\ r'=[r EXCEPT !.jobs[j].reference=r.now]
       ELSE AllowGenerationRewrite /\ r.generation>r.jobs[j].generation
                             /\ r'=[r EXCEPT !.jobs[j].generation=r.generation]
 /\ UNCHANGED <<seen,producedCount>>
AllActions == (\E a \in r.anchors:Produce(a))
 \/ (\E j \in Jobs,p \in Heights,h \in Heights,t \in 0..MaxTime:Capture(j,p,h,t))
 \/ (\E v \in BOOLEAN:History(v)) \/ (\E b \in Backends,v \in BOOLEAN:Availability(b,v))
 \/ (\E j \in Jobs,b \in Backends,k \in Jobs:Complete(j,b,k))
 \/ (\E j \in Jobs,full \in BOOLEAN:Publish(j,full)) \/ (\E j \in Jobs:Land(j))
 \/ (\E h \in Heights:Finalize(h)) \/ PublishAnchor \/ Tick \/ Recover
 \/ (\E j \in Jobs,which \in {"Reference","Generation"}:Rewrite(j,which))
Setup ==
 /\ CASE stage=0 -> Produce(InitialAnchor)
       [] stage=1 -> Produce(InitialAnchor)
       [] stage=2 -> Capture(0,0,IF Prefix="OneJob" THEN 2 ELSE 1,0)
       [] stage=3 -> Capture(1,0,2,0)
 /\ stage'=stage+1
Next == IF stage<(IF Prefix="OneJob" THEN 3 ELSE 4) THEN Setup ELSE AllActions /\ UNCHANGED stage
ProgressSpec == Init /\ [][Next]_vars

\* Independent raw input/event assertions; these do not enable any action.
ExpectedParent(b) == IF b.parentHeight=0 THEN Genesis
                     ELSE IF b.generation=0 THEN Cut(0,b.parentHeight)
                     ELSE IF \E q \in seen.recoveries:q.height=b.parentHeight
                       THEN (CHOOSE q \in seen.recoveries:q.height=b.parentHeight).cut
                       ELSE Cut(1,b.parentHeight)
PipelineTypeOK == /\ r.head \in 0..MaxHead /\ r.included \in 0..r.head
                  /\ r.finalized \in 0..r.included /\ producedCount \in 0..MaxProduces
ProducedBlockInputsExact == \A b \in seen.blocks:
    b.height=b.parentHeight+1 /\ b.parentCut=ExpectedParent(b)
    /\ b.outputCut= <<"Cut",b.generation,b.height>> /\ b.selected=b.inputAnchor
ProducedAnchorsCorrect == \A b \in seen.blocks:
    b.height-b.selected.checkpoint<=U /\ b.selected.generation=b.generation
    /\ b.selected \in seen.anchors /\ b.selected.reference<=b.at
    /\ (\E f \in seen.finalizations:f.height=b.selected.checkpoint /\ f.cut=b.selected.cut /\ f.at<=b.at)
JobInputsImmutable == r.jobs=seen.jobInputs
BackendResultsMatchRequest == \A p \in ProofKeys:r.proofs[p].present => r.proofs[p].statement=seen.proofInputs[p]
LandingStatementCorrect == \A l \in seen.lands : LET x==seen.jobInputs[l.job] IN
    l.currentGeneration=x.generation /\ l.beforeC>=x.parent /\ l.afterC=x.terminal
    /\ l.published=x.data /\ Len(l.published)=x.terminal-x.parent /\ Len(l.published)<=BlobCapacity
    /\ l.proofA=x.statement /\ l.proofB=x.statement
    /\ l.at>=x.reference /\ l.at-x.reference<=RefWindow /\ x.reference-x.dependency<=AncestryBudget
    /\ l.beforeHead=l.afterHead
ActualLandingParentAndSuffix ==
 /\ \A l \in seen.lands:l.record.parent=l.beforeC /\ l.record.cut=seen.jobInputs[l.job].cuts[Len(seen.jobInputs[l.job].cuts)]
 /\ \A h \in 1..MaxHead:seen.applied[h]=(IF h<=r.included THEN 1 ELSE 0)
CheckpointRecordsPreserved == r.records=seen.expectedRecords
AnchorRecordsAuthenticated == r.anchors=seen.anchors /\
    (\A a \in r.anchors: \E f \in seen.finalizations:f.height=a.checkpoint /\ f.cut=a.cut /\ f.at<=a.reference)
RecoveryResourcesPreserved == \A q \in seen.recoveries:q.oldAvailable=q.newAvailable /\ q.oldHistory=q.newHistory
OracleReady(j) == LET x==seen.jobInputs[j] IN
    x.present /\ x.generation=r.generation /\ x.parent<=r.included /\ r.included<x.terminal
    /\ r.records[x.parent].present /\ x.cuts[r.included-x.parent+1]=seen.expectedRecords[r.included].cut
    /\ x.reference<=r.now /\ r.now-x.reference<=RefWindow /\ x.reference-x.dependency<=AncestryBudget
    /\ r.published[j]=x.data /\ Len(x.data)<=BlobCapacity
    /\ r.proofs[<<j,"A">>].present /\ r.proofs[<<j,"B">>].present
    /\ r.proofs[<<j,"A">>].statement=x.statement /\ r.proofs[<<j,"B">>].statement=x.statement
ReadyLandingEnabled == \A j \in Jobs:OracleReady(j) => ENABLED Land(j)
FinalizedCandidateEnabled == \A a \in seen.anchors:
    (producedCount<MaxProduces /\ r.head<MaxHead /\ a.generation=r.generation
     /\ a.reference<=r.now /\ r.now-a.reference<=RefWindow /\ r.head+1-a.checkpoint<=U)
       => ENABLED Produce(a)
PauseNotReached == r.head-r.parentAnchor.checkpoint#U
LandWhilePausedNotReached == \A l \in seen.lands:l.beforeHead-l.beforeAnchor.checkpoint#U
IncludedStillPausedNotReached == ~(r.included>r.parentAnchor.checkpoint /\ r.finalized=0
                                    /\ r.head-r.parentAnchor.checkpoint=U)
FinalizedAdoptResumeNotReached == \A b \in seen.blocks:
    ~(b.height=3 /\ b.beforeAnchor.checkpoint=0 /\ b.selected.checkpoint>0)
OverlapUnchangedJobNotReached == \A l \in seen.lands:seen.jobInputs[l.job].parent=l.beforeC
FreshReferenceOldAncestryNotReached == \A j \in Jobs:LET x==seen.jobInputs[j] IN
    ~(x.present /\ x.reference=r.now /\ x.reference-x.dependency>AncestryBudget)
=============================================================================
