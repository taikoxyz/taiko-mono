------------------------- MODULE EtnaForcedInclusion -------------------------
EXTENDS EtnaSettlement, FiniteSets, Integers

CONSTANTS MaxProduces, CorrectBeforeCapture, CorrectClosedAnchor, Prefix, QueueBound, Fixture, RequireDueWork, PositionZeroOnly, TimeoutNotEmpty,
          CheckBuildContext, BuildContext, BindAnchorHash, CorrectCursorWrite,
          SuffixOnly, FeeUsesL1Head
ASSUME /\ QueueBound=2 /\ Fixture \in {"Mixed","EmptyRevert","Fee"}
       /\ BuildContext \in {"Correct","WrongParent","SmallBudget"}
Indices == 0..QueueBound
Pairs == (0..MaxGeneration) \X (0..MaxHeight)
Timestamp(b) == 10+2*b
Original(i) == IF Fixture="Mixed" THEN IF i=0 THEN "A" ELSE "Bad"
               ELSE IF Fixture="Fee" THEN IF i=0 THEN "A" ELSE "B"
               ELSE IF i=0 THEN "Empty" ELSE "B"
BlankEntry == [hash |-> "Nil", timestamp |-> 0, block |-> 0]
Parent(g,h) == <<g,h>>
EmptyBuild == [present |-> FALSE, generation |-> 0, height |-> 0, index |-> 0,
              hash |-> "Nil", parent |-> Parent(0,0), budget |-> "Full",
              status |-> "None", result |-> "None"]
EmptyBlock == [present |-> FALSE, generation |-> 0, height |-> 0, before |-> 0,
               after |-> 0, anchor |-> 0, witness |-> FALSE, witnessHash |-> "Nil",
               body0 |-> "Ord", body1 |-> "Ord", raw |-> "Absent", build |-> EmptyBuild]
EmptyFIProof == [present |-> FALSE, generation |-> 0, parent |-> 0, terminal |-> 0,
                 cuts |-> [h \in 0..MaxHeight |-> 0]]
VARIABLES fi, observations, stage, produces
fiVars == <<fi,observations,stage,produces>>
allVars == <<vars,fiVars>>
FIInit ==
 /\ Init /\ stage=0 /\ produces=0
 /\ fi=[tail |-> 0, head |-> 0, queue |-> [i \in Indices |-> BlankEntry],
        anchors |-> [a \in 0..MaxTime |-> [tail |-> 0, head |-> 0,
                     entries |-> [i \in Indices |-> BlankEntry]]],
        frontier |-> 0, cursor |-> 0, lastAnchor |-> 0, anchorFloor |-> 0,
        cuts |-> [p \in Pairs |-> 0], blocks |-> [p \in Pairs |-> EmptyBlock],
        owners |-> [h \in 0..MaxHeight |-> 0],
        landedCuts |-> [h \in 0..MaxHeight |-> 0], queued |-> EmptyFIProof,
        build |-> EmptyBuild, halted |-> FALSE, revenue |-> 0]
 /\ observations=[admissions |-> [i \in Indices |-> [present |-> FALSE, hash |-> "Nil",
                     timestamp |-> 0, block |-> 0, beforeHead |-> 0, beforeTail |-> 0, charged |-> 0]],
        cashPaid |-> 0, produced |-> {},
        closedSnapshots |-> [a \in 0..MaxTime |-> [tail |-> 0, head |-> 0,
                       entries |-> [i \in Indices |-> BlankEntry]]],
        originCursors |-> [g \in 0..MaxGeneration |-> 0], origins |-> [g \in 0..MaxGeneration |-> 0],
        applied |-> [i \in Indices |-> 0], blanked |-> {},
        lastRecovery |-> [present |-> FALSE, oldHead |-> 0, newHead |-> 0,
             oldTail |-> 0, newTail |-> 0, oldRevenue |-> 0, newRevenue |-> 0,
             oldC |-> 0, newC |-> 0, oldCursor |-> 0, newCursor |-> 0],
        transient |-> {}, retryComplete |-> FALSE,
        starts |-> [g \in 0..MaxGeneration |-> 0],
        originParents |-> [g \in 0..MaxGeneration |-> Parent(0,0)]]
Enqueue ==
 /\ fi.tail<QueueBound
 /\ LET i==fi.tail
        fee==1+fi.tail-(IF FeeUsesL1Head THEN fi.head ELSE fi.cursor)
        entry==[hash |-> Original(i), timestamp |-> Timestamp(now), block |-> now]
    IN /\ fi'=[fi EXCEPT !.queue[i]=entry, !.tail=@+1, !.revenue=@+fee]
       /\ observations'=[observations EXCEPT !.admissions[i]=[present |-> TRUE,
               hash |-> Original(i), timestamp |-> Timestamp(now), block |-> now,
               beforeHead |-> fi.head, beforeTail |-> fi.tail, charged |-> fi'.revenue-fi.revenue],
               !.cashPaid=@+fee]
 /\ UNCHANGED vars
FITick ==
 /\ Tick
 /\ fi'=[fi EXCEPT !.anchors[now]=[tail |-> fi.tail, head |-> fi.head,
           entries |-> IF CorrectClosedAnchor THEN fi.queue ELSE [fi.queue EXCEPT ![0].hash="Bad"]]]
 /\ observations'=[observations EXCEPT !.closedSnapshots[now]=
       [tail |-> fi.tail, head |-> fi.head,
        entries |-> [i \in Indices |-> [hash |-> fi.queue[i].hash,
                      timestamp |-> fi.queue[i].timestamp, block |-> fi.queue[i].block]]]]
FIAuthorize(d) == Authorize(d) /\ UNCHANGED <<fi,observations>>
FIInvalidate == InvalidateNonce /\ UNCHANGED <<fi,observations>>


Eligible(raw) == raw \in {"A","B","Empty"}
Completed(raw,parent,budget) ==
    IF parent="Other" \/ budget="Small" \/ raw="Empty" THEN "Empty"
    ELSE IF raw="B" THEN "Reverted" ELSE "Included"
ObserveBuild(a,status) ==
 /\ a \in 0..MaxTime /\ a<now /\ a>=fi.anchorFloor /\ a>=fi.lastAnchor
 /\ fi.frontier<MaxHeight
 /\ status \in {"Complete","Transient","Pruned"}
 /\ fi.cursor<fi.anchors[a].tail
 /\ LET raw==fi.anchors[a].entries[fi.cursor].hash
        parent==IF BuildContext="WrongParent" THEN "Other" ELSE Parent(fi.owners[fi.frontier],fi.frontier)
        budget==IF BuildContext="SmallBudget" THEN "Small" ELSE "Full"
    IN /\ Eligible(raw)
       /\ fi'=[fi EXCEPT !.build=[present |-> TRUE, generation |-> generation,
                 height |-> fi.frontier, index |-> fi.cursor, hash |-> raw,
                 parent |-> parent, budget |-> budget, status |-> status,
                 result |-> IF status="Complete" THEN Completed(raw,parent,budget) ELSE "None"],
                 !.halted=@ \/ status="Pruned"]
       /\ observations'=[observations EXCEPT !.transient=
                IF status="Transient" THEN {<<generation,fi.frontier,fi.cursor,raw>>} ELSE @]
 /\ UNCHANGED vars
RestoreParent ==
 /\ fi.halted
 /\ fi'=[fi EXCEPT !.halted=FALSE, !.build=EmptyBuild]
 /\ UNCHANGED <<vars,observations>>
Produce(a,mode,advance) ==
 /\ ~fi.halted /\ fi.frontier<MaxHeight
 /\ a \in 0..MaxTime /\ a<now /\ a>=fi.anchorFloor /\ a>=fi.lastAnchor
 /\ mode \in {"Ordinary","First","Second","Replacement","Skip","OldOrdinary"}
 /\ advance \in BOOLEAN
 /\ LET before==IF CorrectBeforeCapture THEN fi.cursor ELSE
                      IF fi.cursor=0 /\ fi.anchors[a].tail=2 THEN 1 ELSE fi.cursor
        anchor==fi.anchors[a]
        visible==before<anchor.tail
        e==anchor.entries[before]
        body0==IF mode \in {"First","OldOrdinary"} THEN Original(before)
               ELSE IF mode="Replacement" THEN "Replacement" ELSE "Ord"
        body1==IF mode="Second" THEN Original(before) ELSE "Ord"
        raw==IF mode \in {"Skip","OldOrdinary","Second","Replacement"} THEN e.hash ELSE "Absent"
        boundHash==IF BindAnchorHash THEN e.hash ELSE Original(before)
        included==(visible /\ Eligible(body0) /\ body0=boundHash)
                    \/ (~PositionZeroOnly /\ visible /\ Eligible(body1) /\ body1=boundHash)
        due==visible /\ Timestamp(a)>=e.timestamp+2
        b==fi.build
        ready==b.present /\ b.generation=generation /\ b.height=fi.frontier
                /\ b.index=before /\ b.hash=e.hash
        empty==ready /\ ((b.status="Complete" /\ b.result="Empty")
                          \/ (~TimeoutNotEmpty /\ b.status="Transient"))
               /\ (~CheckBuildContext \/ (b.parent=Parent(fi.owners[fi.frontier],fi.frontier) /\ b.budget="Full"))
        skip==visible /\ due /\ raw=e.hash /\ (~Eligible(e.hash) \/ empty)
        after==before+(IF advance THEN IF CorrectCursorWrite THEN 1 ELSE 2 ELSE 0)
        h==fi.frontier+1
        block==[present |-> TRUE, generation |-> generation, height |-> h,
                before |-> before, after |-> after, anchor |-> a, witness |-> visible,
                witnessHash |-> e.hash, body0 |-> body0, body1 |-> body1,
                raw |-> raw, build |-> b]
    IN /\ body0 \notin {"Nil","Bad","Empty"} /\ body1 \notin {"Nil","Bad","Empty"}
       /\ IF advance THEN included \/ skip
                     ELSE ~included /\ (~visible \/ ~due \/ ~RequireDueWork)
       /\ fi'=[fi EXCEPT !.frontier=h, !.cursor=after, !.lastAnchor=a,
                         !.owners[h]=generation, !.cuts[<<generation,h>>]=after, !.blocks[<<generation,h>>]=block]
       /\ observations'=[observations EXCEPT !.produced=@ \cup {
               [pair |-> <<generation,h>>, before |-> fi.cursor, after |-> fi'.cursor,
                anchor |-> a, tail |-> anchor.tail, entry |-> anchor.entries[before],
                parent |-> Parent(fi.owners[fi.frontier],fi.frontier), block |-> fi'.blocks[<<generation,h>>]]},
                !.retryComplete=@ \/ (advance /\ b.status="Complete"
                     /\ <<generation,fi.frontier,before,e.hash>> \in observations.transient)]
 /\ UNCHANGED vars
CurrentFIProof(h) == [present |-> TRUE, generation |-> generation, parent |-> c,
                      terminal |-> h, cuts |-> [j \in 0..MaxHeight |-> fi.cuts[<<generation,j>>]]]
FIPrepare(h) ==
 /\ h<=fi.frontier /\ PrepareProof(h)
 /\ fi'=[fi EXCEPT !.queued=CurrentFIProof(h)]
 /\ UNCHANGED observations
FILand(proof,fp) ==
 /\ Land(proof)
 /\ fp.present /\ fp.generation=proof.generation /\ fp.parent=proof.parent /\ fp.terminal=proof.terminal
 /\ proof.terminal<=fi.frontier
 /\ fp.cuts[proof.parent]=fi.landedCuts[proof.parent]
 /\ fp.cuts[c]=fi.landedCuts[c] /\ fi.head=fi.landedCuts[c]
 /\ \A j \in proof.parent..proof.terminal : fp.cuts[j]=fi.cuts[<<generation,j>>]
 /\ LET newHead==fp.cuts[proof.terminal]
        from==IF SuffixOnly THEN fi.head ELSE fp.cuts[proof.parent]
    IN /\ fi.head<=newHead /\ newHead<=fi.tail /\ newHead-fi.head<=proof.terminal-c
       /\ fi'=[fi EXCEPT !.head=newHead, !.landedCuts[proof.terminal]=newHead]
       /\ observations'=[observations EXCEPT !.applied=[i \in Indices |->
               observations.applied[i]+(IF from<=i /\ i<newHead THEN 1 ELSE 0)]]
FIFresh(h) == FILand([present |-> TRUE,generation |-> generation,parent |-> c,terminal |-> h],CurrentFIProof(h))
FIRecover(blanks) ==
 /\ blanks \subseteq fi.head..(fi.tail-1)
 /\ Recover
 /\ fi'=[fi EXCEPT !.queue=[i \in Indices |-> IF i \in blanks
              THEN [fi.queue[i] EXCEPT !.hash="Nil"] ELSE fi.queue[i]],
              !.frontier=c, !.cursor=fi.landedCuts[c], !.anchorFloor=now, !.lastAnchor=now,
              !.cuts[<<generation+1,c>>]=fi.landedCuts[c], !.build=EmptyBuild]
 /\ observations'=[observations EXCEPT !.blanked=@ \cup blanks, !.origins[generation+1]=now,
              !.originCursors[generation+1]=fi.head,
              !.starts[generation+1]=c, !.originParents[generation+1]=Parent(landings[c].generation,c),
              !.lastRecovery=[present |-> TRUE,oldHead |-> fi.head,newHead |-> fi'.head,
                  oldTail |-> fi.tail,newTail |-> fi'.tail,oldRevenue |-> fi.revenue,
                  newRevenue |-> fi'.revenue,oldC |-> c,newC |-> c',
                  oldCursor |-> fi.landedCuts[c],newCursor |-> fi'.cursor]]
NonProductionActions == Enqueue \/ FITick \/ (\E d \in 0..MaxTime : FIAuthorize(d)) \/ FIInvalidate
       \/ (\E a \in 0..MaxTime,status \in {"Complete","Transient","Pruned"}:
                 produces<MaxProduces /\ ObserveBuild(a,status))
       \/ RestoreParent
       \/ (\E h \in 0..MaxHeight : FIPrepare(h) \/ FIFresh(h))
       \/ FILand(pendingProof,fi.queued)
       \/ (\E blanks \in SUBSET Indices : FIRecover(blanks))
AllFIActions == (NonProductionActions /\ UNCHANGED produces)
       \/ (\E a \in 0..MaxTime, mode \in {"Ordinary","First","Second","Replacement","Skip","OldOrdinary"},
                  advance \in BOOLEAN : produces<MaxProduces /\ Produce(a,mode,advance)
                                           /\ produces'=produces+1)
SetupAdmissions == /\ CASE stage=0 -> Enqueue [] stage=1 -> Enqueue [] stage=2 -> FITick
                   /\ stage'=stage+1 /\ UNCHANGED produces
SetupFeeLag == /\ CASE stage=0 -> Enqueue [] stage=1 -> FITick
                            [] stage=2 -> Produce(0,"First",TRUE) [] stage=3 -> Enqueue
               /\ stage'=stage+1
               /\ IF stage=2 THEN produces'=produces+1 ELSE UNCHANGED produces
FINext == IF Prefix="Admissions" /\ stage<3 THEN SetupAdmissions
          ELSE IF Prefix="FeeLag" /\ stage<4 THEN SetupFeeLag
          ELSE AllFIActions /\ UNCHANGED stage
FISpec == FIInit /\ [][FINext]_allVars

\* Independent every-produced-block oracle: no decision-helper or mutant switch.
ExpectedParent(u) == IF u.pair[2]-1=observations.starts[u.pair[1]]
                        THEN observations.originParents[u.pair[1]]
                        ELSE Parent(u.pair[1],u.pair[2]-1)
ExpectedBefore(u) == IF u.pair[2]-1=observations.starts[u.pair[1]]
                        THEN observations.originCursors[u.pair[1]]
                        ELSE fi.blocks[<<u.pair[1],u.pair[2]-1>>].after
HistoricalAnchorsExact == \A a \in 0..MaxTime : a<now => fi.anchors[a]=observations.closedSnapshots[a]
OracleBlock(u) ==
 LET b==u.block
     visible==u.before<u.tail
     e==u.entry
     inclusion==visible /\ b.body0 \in {"A","B","Empty"} /\ b.body0=e.hash
     due==visible /\ Timestamp(u.anchor)>=e.timestamp+2
     build==b.build
     exactEmpty==build.present /\ build.generation=u.pair[1] /\ build.height=u.parent[2]
        /\ build.index=u.before /\ build.hash=e.hash /\ build.parent=u.parent
        /\ build.budget="Full" /\ build.status="Complete" /\ build.result="Empty" /\ e.hash="Empty"
     legalSkip==visible /\ due /\ b.raw=e.hash /\ (e.hash \notin {"A","B","Empty"} \/ exactEmpty)
 IN /\ u.before=ExpectedBefore(u) /\ u.parent=ExpectedParent(u)
    /\ b.present /\ b.generation=u.pair[1] /\ b.height=u.pair[2]
    /\ b.before=u.before /\ b.after=u.after /\ b.anchor=u.anchor
    /\ b.witness=visible /\ (visible=>b.witnessHash=e.hash)
    /\ u.tail=fi.anchors[u.anchor].tail /\ e=fi.anchors[u.anchor].entries[u.before]
    /\ (IF inclusion THEN u.after=u.before+1
         ELSE IF due THEN legalSkip /\ u.after=u.before+1
         ELSE u.after=u.before)
FITypeOK == /\ fi.head \in 0..fi.tail /\ fi.tail \in 0..QueueBound
            /\ fi.cursor \in 0..QueueBound /\ fi.frontier \in c..MaxHeight
ProducedBlockRules == \A u \in observations.produced : OracleBlock(u)
CursorCutsExact ==
 /\ fi.cursor=fi.cuts[<<generation,fi.frontier>>] /\ fi.head=fi.landedCuts[c]
 /\ {p \in Pairs : fi.blocks[p].present}={u.pair : u \in observations.produced}
 /\ \A u \in observations.produced :
      /\ fi.blocks[u.pair]=u.block /\ fi.cuts[u.pair]=u.after
      /\ u.block.before=u.before /\ u.block.after=u.after
      /\ u.after \in u.before..(u.before+1)
LandingPrefixOnce == \A i \in Indices : observations.applied[i]=(IF i<fi.head THEN 1 ELSE 0)
RecoveryFIPreserved == LET x==observations.lastRecovery IN ~x.present \/
    (x.oldHead=x.newHead /\ x.oldTail=x.newTail /\ x.oldRevenue=x.newRevenue
     /\ x.oldC=x.newC /\ x.oldCursor=x.newCursor)
RECURSIVE Fees(_)
Fees(n) == IF n=0 THEN 0 ELSE observations.admissions[n-1].charged+Fees(n-1)
AdmissionFeesExact == /\ fi.revenue=observations.cashPaid /\ fi.revenue=Fees(fi.tail)
 /\ \A i \in 0..(fi.tail-1) : LET a==observations.admissions[i] IN
       a.present /\ a.beforeTail=i /\ a.charged=1+a.beforeTail-a.beforeHead
QueueIdentityPreserved == \A i \in 0..(fi.tail-1) :
    /\ fi.queue[i].timestamp=observations.admissions[i].timestamp
    /\ fi.queue[i].block=observations.admissions[i].block
    /\ observations.admissions[i].hash=Original(i)
    /\ fi.queue[i].hash=(IF i \in observations.blanked THEN "Nil" ELSE Original(i))
AnchorGenerationCorrect == \A u \in observations.produced : u.anchor>=observations.origins[u.pair[1]]
EarlyInclusionNotReached == \A u \in observations.produced :
    ~(u.after=u.before+1 /\ Timestamp(u.anchor)<u.entry.timestamp+2 /\ u.block.body0=u.entry.hash)
BlankSkipNotReached == \A u \in observations.produced :
    ~(u.pair[1]>0 /\ u.after=u.before+1 /\ u.entry.hash="Nil" /\ Timestamp(u.anchor)>=u.entry.timestamp+2)
EligibleEmptyNotReached == \A u \in observations.produced :
    ~(u.entry.hash="Empty" /\ u.after=u.before+1 /\ u.block.build.status="Complete")
IncludedRevertNotReached == \A u \in observations.produced :
    ~(u.entry.hash="B" /\ u.after=u.before+1 /\ u.block.body0="B")
RetryThenCompleteNotReached == ~observations.retryComplete
OverlapFIPNotReached == ~(audit.overlap /\ fi.head>0)
=============================================================================
