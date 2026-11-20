--------------------- MODULE EtnaProvingAsyncProduct ---------------------
EXTENDS EtnaProvingProgress
CONSTANT Witness
ASSUME /\ MaxHead=3 /\ MaxProduces=3 /\ MaxTime=2 /\ U=2
       /\ RefWindow=1 /\ AncestryBudget=1 /\ BlobCapacity \in {1,2}
       /\ Prefix="TwoJobs" /\ ResourceProfile="Variable"
       /\ PastReference /\ PastFinalization /\ BlockEndCheckpoint
       /\ CheckGeneration /\ CheckFullData /\ CheckBackendBinding
       /\ CorrectActualParent /\ CandidateAnchorGuard
       /\ ~CreditIncluded /\ ~CreditProved
       /\ ~AllowReferenceRewrite /\ ~AllowGenerationRewrite
       /\ Witness \in {"None","Retry","Cached","Short","Suffix","Budget","Resume"}

\* Literal fixture derived before execution, independent of inherited constructors.
LC(h) == <<"Cut",0,h>>
LP(h) == <<"Payload",<<"Cut",0,h>>>>
LA(h,t) == [id |-> <<0,h,t>>,generation |-> 0,checkpoint |-> h,
            reference |-> t,cut |-> <<"Cut",0,h>>]
LEmptyJob == [present |-> FALSE,generation |-> 0,parent |-> 0,terminal |-> 0,
 reference |-> 0,dependency |-> 0,data |-> <<>>,cuts |-> <<>>,statement |-> <<>>]
LEmptyProof == [present |-> FALSE,statement |-> <<>>]
LRecord(h,p,t) == [present |-> TRUE,generation |-> 0,parent |-> p,
                   cut |-> <<"Cut",0,h>>,includedAt |-> t]
LAbsent == [present |-> FALSE,generation |-> 0,parent |-> 0,
             cut |-> <<"Cut",0,0>>,includedAt |-> 0]
LData(j) == IF j=0 THEN <<LP(1)>> ELSE <<LP(1),LP(2)>>
LCuts(j) == IF j=0 THEN <<LC(0),LC(1)>> ELSE <<LC(0),LC(1),LC(2)>>
LStatement(j) == <<0,0,j+1,<<"Ref",0>>,LData(j),LCuts(j),0>>
LJob(j) == [present |-> TRUE,generation |-> 0,parent |-> 0,terminal |-> j+1,
 reference |-> 0,dependency |-> 0,data |-> LData(j),cuts |-> LCuts(j),statement |-> LStatement(j)]
LJobs(n) == [j \in 0..1 |-> IF n>=j+3 THEN LJob(j) ELSE LEmptyJob]
LRecords == [h \in 0..3 |-> IF h=0 THEN LRecord(0,0,0) ELSE LAbsent]
LBlock(h) == [generation |-> 0,height |-> h,parentHeight |-> h-1,
 parentCut |-> LC(h-1),outputCut |-> LC(h),inputAnchor |-> LA(0,0),
 selected |-> LA(0,0),beforeAnchor |-> LA(0,0),at |-> 0]
LSetupState(n) ==
 [head |-> IF n<2 THEN n ELSE 2,generation |-> 0,now |-> 0,included |-> 0,
  finalized |-> 0,finalizedBlock |-> 0,start |-> 0,dependency |-> 0,
  parentAnchor |-> LA(0,0),anchors |-> {LA(0,0)},jobs |-> LJobs(n),
  privateHistory |-> FALSE,available |-> [b \in {"A","B"} |-> FALSE],
  proofs |-> [p \in (0..1) \X {"A","B"} |-> LEmptyProof],
  published |-> [j \in 0..1 |-> <<>>],records |-> LRecords,
  canonical |-> [h \in 0..3 |-> IF h>0 /\ h<=n /\ h<=2 THEN LC(h) ELSE LC(0)]]
LSetupSeen(n) ==
 [blocks |-> {LBlock(h):h \in 1..(IF n<2 THEN n ELSE 2)},jobInputs |-> LJobs(n),
  proofInputs |-> [p \in (0..1) \X {"A","B"} |-> <<>>],lands |-> {},
  expectedRecords |-> LRecords,
  finalizations |-> {[height |-> 0,cut |-> LC(0),at |-> 0,block |-> 0,
                     kind |-> "Genesis",generation |-> 0]},
  anchors |-> {LA(0,0)},applied |-> [h \in 0..3 |-> 0],recoveries |-> {}]

VARIABLES asyncSetupOK, asyncEffects, asyncFault, witnessPhase, witnessCall
AsyncLocal == <<asyncSetupOK,asyncEffects,asyncFault,witnessPhase,witnessCall>>
AsyncVars == <<vars,AsyncLocal>>
AsyncInit == /\ Init
 /\ asyncSetupOK=(r=LSetupState(0) /\ seen=LSetupSeen(0) /\ stage=0 /\ producedCount=0)
 /\ asyncEffects=TRUE /\ asyncFault= <<>> /\ witnessPhase=0 /\ witnessCall= <<>>
AsyncSetup == /\ Setup
 /\ asyncSetupOK'=(asyncSetupOK /\ r'=LSetupState(stage+1)
     /\ seen'=LSetupSeen(stage+1) /\ producedCount'=(IF stage<2 THEN stage+1 ELSE 2))
 /\ UNCHANGED <<asyncEffects,asyncFault,witnessPhase,witnessCall>>

\* Expected predicates observe actual offered arguments; they never enable calls.
LComplete(t,b,s) == LJob(t).present /\ LJob(s).present
 /\ r.privateHistory /\ r.available[b]
 /\ LJob(s).reference-LJob(s).dependency<=1
LReadyWithoutBudget(j) == IF r.included<0 \/ r.included>=j+1 THEN FALSE ELSE
 /\ r.generation=0 /\ LJob(j).present /\ r.records[0]=LRecord(0,0,0)
 /\ LCuts(j)[r.included+1]=r.records[r.included].cut
 /\ r.records[r.included].cut=LC(r.included)
 /\ 0<r.now /\ r.now<=1 /\ 0-0<=1
 /\ r.proofs[<<j,"A">>]=[present |-> TRUE,statement |-> LStatement(j)]
 /\ r.proofs[<<j,"B">>]=[present |-> TRUE,statement |-> LStatement(j)]
 /\ r.published[j]=LData(j)
LReady(j) == LReadyWithoutBudget(j) /\ j+1<=BlobCapacity
AsyncCompleteEnabled == stage<4 \/
 (\A t \in 0..1,b \in {"A","B"},s \in 0..1:
    (ENABLED Complete(t,b,s))=LComplete(t,b,s))
AsyncLandEnabled == stage<4 \/
 (\A j \in 0..1:(ENABLED Land(j))=LReady(j))
AsyncFinalityEnabled == stage<4 \/
 (\A b \in 0..2:(ENABLED Finalize(b))=(r.finalizedBlock<b /\ b<r.now))
AsyncProduceEnabled == stage<4 \/ (\A a \in r.anchors:
 (ENABLED Produce(a))=(producedCount<3 /\ r.head<3 /\ a.generation=0
   /\ a.reference<=r.now /\ r.now-a.reference<=1 /\ r.head+1-a.checkpoint<=2))
AsyncResourceEnabled == stage<4 \/
 /\ (\A v \in BOOLEAN:ENABLED History(v))
 /\ (\A b \in {"A","B"},v \in BOOLEAN:ENABLED Availability(b,v))
AsyncSetupExact == asyncSetupOK
AsyncOriginsExact == stage<4 \/ (r.jobs=LJobs(4) /\ seen.jobInputs=LJobs(4))
AsyncActionEffects == asyncEffects /\ asyncFault= <<>>

CorrectShort == r.proofs[<<0,"A">>]=[present |-> TRUE,statement |-> LStatement(0)]
 /\ r.proofs[<<0,"B">>]=[present |-> TRUE,statement |-> LStatement(0)]
AllAbsent == ~r.privateHistory /\ ~r.available["A"] /\ ~r.available["B"]
SuffixPrestate == /\ r.included=1 /\ r.now=1 /\ r.records[1]=LRecord(1,0,1)
 /\ r.proofs[<<1,"A">>]=[present |-> TRUE,statement |-> LStatement(1)]
 /\ r.proofs[<<1,"B">>]=[present |-> TRUE,statement |-> LStatement(1)]
 /\ r.published[1]= <<LP(2)>> /\ ~(ENABLED Land(1))
BudgetPrestate == /\ BlobCapacity=1 /\ r.included=1 /\ r.now=1
 /\ r.head=2 /\ producedCount=2 /\ r.parentAnchor=LA(0,0)
 /\ r.records[1]=LRecord(1,0,1) /\ LReadyWithoutBudget(1)
 /\ Len(r.published[1])=2 /\ ~(ENABLED Land(1))

\* Only one selected, sparse witness automaton is active per profile. Normal
\* safety keeps these two variables constant. Raw traces retain actual r/seen;
\* witnessCall names the actual call (or a disabled eligibility observation).
Observe(kind,j,b,s,v) ==
 LET next==CASE
   Witness="Retry" -> (CASE
       witnessPhase=0 /\ r.privateHistory /\ ~r.available["A"]
         /\ ~(ENABLED Complete(0,"A",0)) -> 1
    [] witnessPhase=1 /\ kind="Availability" /\ b="A" /\ v=TRUE -> 2
    [] witnessPhase=2 /\ kind="Complete" /\ j=0 /\ b="A" /\ s=0 -> 3
    [] OTHER -> witnessPhase)
 [] Witness="Cached" -> (CASE
       witnessPhase=0 /\ CorrectShort' -> 1
    [] witnessPhase=1 /\ CorrectShort' /\ AllAbsent' -> 2
    [] witnessPhase=2 /\ kind="Land" /\ j=0 /\ AllAbsent /\ CorrectShort -> 3
    [] OTHER -> witnessPhase)
 [] Witness="Resume" -> (CASE
       witnessPhase=0 /\ SuffixPrestate -> 1
    [] witnessPhase=1 /\ kind="Publish" /\ j=1 /\ v=TRUE
       /\ r.included=1 /\ r.now=1 /\ r.published[1]= <<LP(2)>> -> 2
    [] witnessPhase=2 /\ kind="Land" /\ j=1 /\ r.included=1
       /\ r.records[1]=LRecord(1,0,1) /\ r'.records[1]=r.records[1]
       /\ r'.records[2]=LRecord(2,1,1) -> 3
    [] witnessPhase=3 /\ kind="Finalize" /\ j=1 /\ r.now=2
       /\ r'.finalized=2 /\ r'.finalizedBlock=1 -> 4
    [] witnessPhase=4 /\ kind="Anchor" /\ LA(2,1) \notin r.anchors
       /\ LA(2,1) \in r'.anchors -> 5
    [] witnessPhase=5 /\ kind="Produce" /\ v=LA(2,1)
       /\ r.head=2 /\ r.parentAnchor=LA(0,0) /\ r'.head=3 -> 6
    [] OTHER -> witnessPhase)
 [] OTHER -> witnessPhase
 IN /\ witnessPhase'=next
    /\ witnessCall'=IF next=witnessPhase THEN witnessCall
        ELSE IF Witness="Retry" /\ next=1 THEN <<"DisabledComplete",0,"A",0>>
        ELSE IF Witness="Resume" /\ next=1 THEN <<"SuffixRefusal",1>>
        ELSE <<kind,j,b,s,v>>

Audit(ok,kind,j,b,s,v) ==
 /\ asyncEffects'=(asyncEffects /\ ok)
 /\ asyncFault'=IF ok THEN asyncFault ELSE
       <<kind,j,b,s,v,r.included,r.now,r.privateHistory,r.available,r.proofs,r.published>>
 /\ UNCHANGED asyncSetupOK
 /\ Observe(kind,j,b,s,v)

AHistory(v) == /\ History(v)
 /\ Audit(r'=[r EXCEPT !.privateHistory=v] /\ seen'=seen /\ producedCount'=producedCount,
          "History",0,"",0,v)
AAvailability(b,v) == /\ Availability(b,v)
 /\ Audit(r'=[r EXCEPT !.available[b]=v] /\ seen'=seen /\ producedCount'=producedCount,
          "Availability",0,b,0,v)
AComplete(j,b,s) == /\ Complete(j,b,s)
 /\ Audit(r'=[r EXCEPT !.proofs[<<j,b>>]=[present |-> TRUE,statement |-> LStatement(s)]]
       /\ seen'=[seen EXCEPT !.proofInputs[<<j,b>>]=LStatement(s)]
       /\ producedCount'=producedCount,"Complete",j,b,s,FALSE)
APublish(j,full) ==
 /\ (full \/ (r.jobs[j].parent<=r.included /\ r.included<r.jobs[j].terminal))
 /\ Publish(j,full)
 /\ LET data==IF full THEN LData(j) ELSE SubSeq(LData(j),r.included+1,j+1)
    IN Audit(r'=[r EXCEPT !.published[j]=data] /\ seen'=seen
       /\ producedCount'=producedCount,"Publish",j,"",0,full)
ATick == /\ Tick
 /\ Audit(r'=[r EXCEPT !.now=r.now+1] /\ seen'=seen /\ producedCount'=producedCount,
          "Tick",0,"",0,FALSE)
ALand(j) == /\ Land(j)
 /\ LET rec==LRecord(j+1,r.included,r.now)
        event==[job |-> j,currentGeneration |-> 0,beforeC |-> r.included,
          afterC |-> j+1,record |-> rec,beforeHead |-> r.head,afterHead |-> r.head,
          beforeAnchor |-> r.parentAnchor,published |-> LData(j),
          proofA |-> LStatement(j),proofB |-> LStatement(j),at |-> r.now]
    IN Audit(LReady(j) /\ r'=[r EXCEPT !.included=j+1,!.records[j+1]=rec]
       /\ seen'=[seen EXCEPT !.lands=seen.lands \cup {event},!.expectedRecords[j+1]=rec,
           !.applied=[h \in 0..3 |-> seen.applied[h]+(IF r.included<h /\ h<=j+1 THEN 1 ELSE 0)]]
       /\ producedCount'=producedCount,"Land",j,"",0,FALSE)
AFinalize(b) == /\ Finalize(b)
 /\ LET eligible=={0} \cup {l.afterC:l \in {e \in seen.lands:e.at<=b}}
        h==CHOOSE x \in eligible:\A y \in eligible:x>=y
        event==[height |-> h,cut |-> LC(h),at |-> r.now,block |-> b,
                kind |-> "Ordinary",generation |-> 0]
    IN Audit(b<r.now /\ r'=[r EXCEPT !.finalized=h,!.finalizedBlock=b]
       /\ seen'=[seen EXCEPT !.finalizations=seen.finalizations \cup {event}]
       /\ producedCount'=producedCount,"Finalize",b,"",0,FALSE)
AAnchor == /\ PublishAnchor
 /\ LET a==LA(r.finalized,r.finalizedBlock)
    IN Audit(r'=[r EXCEPT !.anchors=r.anchors \cup {a}]
       /\ seen'=[seen EXCEPT !.anchors=seen.anchors \cup {a}]
       /\ producedCount'=producedCount,"Anchor",0,"",0,FALSE)
AProduce(a) == /\ Produce(a)
 /\ LET h==r.head+1
        event==[generation |-> 0,height |-> h,parentHeight |-> r.head,
          parentCut |-> LC(r.head),outputCut |-> LC(h),inputAnchor |-> a,
          selected |-> a,beforeAnchor |-> r.parentAnchor,at |-> r.now]
    IN Audit(h-a.checkpoint<=2 /\ r'=[r EXCEPT !.head=h,!.canonical[h]=LC(h),!.parentAnchor=a]
       /\ seen'=[seen EXCEPT !.blocks=seen.blocks \cup {event}]
       /\ producedCount'=producedCount+1,"Produce",0,"",0,a)

\* No oracle gates any real action. Only the suffix's indexing domain is limited.
AsyncActions ==
 (\E v \in BOOLEAN:AHistory(v))
 \/ (\E b \in {"A","B"},v \in BOOLEAN:AAvailability(b,v))
 \/ (\E j \in 0..1,b \in {"A","B"},s \in 0..1:AComplete(j,b,s))
 \/ (\E j \in 0..1,full \in BOOLEAN:APublish(j,full))
 \/ ATick \/ (\E j \in 0..1:ALand(j))
 \/ (\E b \in 0..2:AFinalize(b)) \/ AAnchor
 \/ (\E a \in r.anchors:AProduce(a))
AsyncNext == IF stage<4 THEN AsyncSetup ELSE AsyncActions /\ UNCHANGED stage
AsyncSpec == AsyncInit /\ [][AsyncNext]_AsyncVars

\* A named violation is reachability evidence, separate from queue-zero safety.
AsyncRetryNotReached == witnessPhase<3
AsyncCachedLandNotReached == witnessPhase<3
AsyncShortNotReached == r.included#1
AsyncSuffixNotReached == stage<4 \/ ~SuffixPrestate
AsyncBudgetNotReached == stage<4 \/ ~BudgetPrestate
AsyncResumeNotReached == witnessPhase<6
=============================================================================
