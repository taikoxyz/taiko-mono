------------------------ MODULE EtnaProofRecapture ------------------------
EXTENDS EtnaProvingProgress
CONSTANTS RecapturePrograms, SuppressAction
ASSUME RecapturePrograms # {} /\ RecapturePrograms \subseteq {"HistoryFirst", "BackendFirst"}
VARIABLES recaptureProgram, recaptureIndex, recaptureReceipts
RecaptureLocal == <<recaptureProgram, recaptureIndex, recaptureReceipts>>
RecaptureVars == <<vars, RecaptureLocal>>
\* Event names identify calls, not expected answers. Every attempted call executes
\* the inherited action if enabled; refusals preserve its complete raw state.
E(name, a, b, c) == <<name,a,b,c>>
H(v) == E("History",v,0,0)
A(b,v) == E("Availability",b,v,0)
C(j,b,k) == E("Complete",j,b,k)
P(j) == E("Publish",j,0,0)
InitialCalls == <<E("ProduceOld",0,0,0), E("ProduceOld",0,0,0), E("CaptureOld",0,0,0)>>
HistoryOrder == <<H(TRUE), C(0,"A",0), A("A",TRUE), C(0,"A",0),
    H(FALSE), C(0,"A",0), A("A",FALSE), A("B",TRUE), C(0,"B",0),
    H(TRUE), C(0,"B",0), P(0), C(0,"A",0), H(FALSE), A("B",FALSE)>>
BackendOrder == <<A("A",TRUE), C(0,"A",0), H(TRUE), C(0,"A",0),
    A("A",FALSE), C(0,"A",0), H(FALSE), H(TRUE), C(0,"B",0),
    A("B",TRUE), C(0,"B",0), P(0), C(0,"A",0), H(FALSE), A("B",FALSE)>>
FinalCalls == <<E("Tick",0,0,0), E("Tick",0,0,0), E("ExpiredLand",0,0,0),
    E("CaptureFresh",0,0,0), H(TRUE), A("A",TRUE), A("B",TRUE),
    C(1,"A",0), C(1,"B",1), P(1), E("Tick",0,0,0),
    E("MixedLand",0,0,0), E("CompleteFresh",0,0,0), E("LandFresh",0,0,0),
    E("Tick",0,0,0), E("Finalize",0,0,0), E("PublishAnchor",0,0,0), E("ProduceFresh",0,0,0)>>
RecaptureCalls == InitialCalls \o
    (IF recaptureProgram="HistoryFirst" THEN HistoryOrder ELSE BackendOrder) \o FinalCalls
FreshAnchor == [id |-> <<0,2,3>>,generation |-> 0,checkpoint |-> 2,
    reference |-> 3,cut |-> <<"Cut",0,2>>]
RecaptureCall(e) == CASE
    e[1]="ProduceOld" -> Produce(InitialAnchor)
 [] e[1]="CaptureOld" -> Capture(0,0,2,0)
 [] e[1]="History" -> History(e[2])
 [] e[1]="Availability" -> Availability(e[2],e[3])
 [] e[1]="Complete" -> Complete(e[2],e[3],e[4])
 [] e[1]="Publish" -> Publish(e[2],TRUE)
 [] e[1]="Tick" -> Tick
 [] e[1]="ExpiredLand" -> Land(0)
 [] e[1]="CaptureFresh" -> Capture(1,0,2,2)
 [] e[1]="MixedLand" -> Land(1)
 [] e[1]="CompleteFresh" -> Complete(1,"A",1)
 [] e[1]="LandFresh" -> Land(1)
 [] e[1]="Finalize" -> Finalize(3)
 [] e[1]="PublishAnchor" -> PublishAnchor
 [] e[1]="ProduceFresh" -> Produce(FreshAnchor)
RecaptureRaw == [state |-> r, produces |-> producedCount]
\* Additive Init retains the exact original state; only Setup is bypassed.
RecaptureInit == /\ Init /\ recaptureProgram \in RecapturePrograms
    /\ recaptureIndex=1 /\ recaptureReceipts= <<>>
RecaptureStep ==
 /\ recaptureIndex<=Len(RecaptureCalls)
 /\ LET e==RecaptureCalls[recaptureIndex]
        enabled==ENABLED RecaptureCall(e)
        executed==enabled /\ e[1]#SuppressAction
    IN /\ IF executed THEN RecaptureCall(e) ELSE UNCHANGED <<r,seen,producedCount>>
       /\ recaptureReceipts'=Append(recaptureReceipts,
           [call |-> e, enabled |-> enabled, executed |-> executed,
            before |-> RecaptureRaw, after |-> RecaptureRaw'])
 /\ recaptureIndex'=recaptureIndex+1 /\ UNCHANGED <<stage,recaptureProgram>>
RecaptureNext == RecaptureStep
RecaptureSpec == RecaptureInit /\ [][RecaptureNext]_RecaptureVars

\* Literal captured inputs are independent of Data/Statement/Ready/OracleReady.
RecaptureData == <<<<"Payload",<<"Cut",0,1>>>>,<<"Payload",<<"Cut",0,2>>>>>>
RecaptureCuts == <<<<"Cut",0,0>>,<<"Cut",0,1>>,<<"Cut",0,2>>>>
LiteralJob(t) == [present |-> TRUE,generation |-> 0,parent |-> 0,terminal |-> 2,
    reference |-> t,dependency |-> 0,data |-> RecaptureData,cuts |-> RecaptureCuts,
    statement |-> <<0,0,2,<<"Ref",t>>,RecaptureData,RecaptureCuts,0>>]
LiteralProof(t) == [present |-> TRUE,statement |-> LiteralJob(t).statement]
ExpiredReceipts == {recaptureReceipts[i] : i \in {k \in 1..Len(recaptureReceipts) : recaptureReceipts[k].call[1]="ExpiredLand"}}
MixedReceipts == {recaptureReceipts[i] : i \in {k \in 1..Len(recaptureReceipts) : recaptureReceipts[k].call[1]="MixedLand"}}
\* Dedicated source-fault audits assert observed outcomes only. No scheduler uses
\* these assertions to preclude a bad Land when a source guard is omitted.
RecaptureExpiryAudit == \A q \in ExpiredReceipts : ~q.enabled /\ ~q.executed /\ q.after=q.before
RecaptureBindingAudit == \A q \in MixedReceipts : ~q.enabled /\ ~q.executed /\ q.after=q.before
RecaptureRawAudit ==
 /\ recaptureIndex=Len(recaptureReceipts)+1 /\ stage=0
 /\ \A i \in 1..Len(recaptureReceipts):
      /\ recaptureReceipts[i].call=RecaptureCalls[i]
      /\ i>1 => recaptureReceipts[i].before=recaptureReceipts[i-1].after
      /\ ~recaptureReceipts[i].executed => recaptureReceipts[i].after=recaptureReceipts[i].before
 /\ \A q \in ExpiredReceipts : LET x==q.before.state IN
      /\ x.now=2 /\ x.generation=0 /\ x.head=2 /\ x.included=0 /\ x.start=0
      /\ x.jobs[0]=LiteralJob(0) /\ x.proofs[<<0,"A">>]=LiteralProof(0)
      /\ x.proofs[<<0,"B">>]=LiteralProof(0) /\ x.published[0]=RecaptureData
      /\ x.records[0]=GenesisRecord /\ ~x.privateHistory
      /\ x.available=[b \in {"A","B"} |-> FALSE]
 /\ \A q \in MixedReceipts : LET x==q.before.state IN
      /\ x.now=3 /\ x.generation=0 /\ x.head=2 /\ x.included=0 /\ x.start=0
      /\ x.jobs[0]=LiteralJob(0) /\ x.jobs[1]=LiteralJob(2)
      /\ x.proofs[<<1,"A">>]=LiteralProof(0) /\ x.proofs[<<1,"B">>]=LiteralProof(2)
      /\ x.published[1]=RecaptureData /\ x.records[0]=GenesisRecord
      /\ x.privateHistory /\ x.available=[b \in {"A","B"} |-> TRUE]
 /\ Len(recaptureReceipts)>=3 => r.jobs[0]=LiteralJob(0)
RecaptureResourceAudit ==
 /\ \A i \in {5,9,12,16} \cap (1..Len(recaptureReceipts)):
      LET q==recaptureReceipts[i] IN
      /\ ~q.enabled /\ ~q.executed /\ q.after=q.before
      /\ IF i=5 THEN
           IF recaptureProgram="HistoryFirst" THEN q.before.state.privateHistory /\ ~q.before.state.available["A"]
           ELSE ~q.before.state.privateHistory /\ q.before.state.available["A"]
         ELSE IF i=9 THEN
           IF recaptureProgram="HistoryFirst" THEN ~q.before.state.privateHistory /\ q.before.state.available["A"]
           ELSE q.before.state.privateHistory /\ ~q.before.state.available["A"]
         ELSE IF i=12 THEN
           IF recaptureProgram="HistoryFirst" THEN ~q.before.state.privateHistory /\ q.before.state.available["B"]
           ELSE q.before.state.privateHistory /\ ~q.before.state.available["B"]
         ELSE q.before.state.privateHistory /\ ~q.before.state.available["A"]
               /\ q.before.state.proofs[<<0,"A">>]=LiteralProof(0)
RecaptureMilestoneAudit ==
 /\ Len(recaptureReceipts)>=22 =>
      /\ recaptureReceipts[22].after.state.jobs[1]=LiteralJob(2)
      /\ recaptureReceipts[22].before.state.jobs[0]=LiteralJob(0)
      /\ recaptureReceipts[22].after.state.jobs[0]=LiteralJob(0)
 /\ Len(recaptureReceipts)>=31 =>
      /\ recaptureReceipts[31].executed
      /\ recaptureReceipts[31].before.state.proofs[<<1,"A">>]=LiteralProof(0)
      /\ recaptureReceipts[31].after.state.proofs[<<1,"A">>]=LiteralProof(2)
 /\ Len(recaptureReceipts)>=32 =>
      /\ recaptureReceipts[32].executed /\ recaptureReceipts[32].before.state.included=0
      /\ recaptureReceipts[32].before.state.now=3 /\ recaptureReceipts[32].after.state.included=2
      /\ recaptureReceipts[32].after.state.records[2]=
           [present |-> TRUE,generation |-> 0,parent |-> 0,cut |-> <<"Cut",0,2>>,includedAt |-> 3]
 /\ Len(recaptureReceipts)>=34 =>
      /\ recaptureReceipts[34].executed /\ recaptureReceipts[34].before.state.now=4
      /\ recaptureReceipts[34].before.state.finalized=0
      /\ recaptureReceipts[34].after.state.finalized=2 /\ recaptureReceipts[34].after.state.finalizedBlock=3
 /\ Len(recaptureReceipts)>=35 =>
      /\ recaptureReceipts[35].executed /\ recaptureReceipts[35].before.state.anchors={InitialAnchor}
      /\ recaptureReceipts[35].after.state.anchors={InitialAnchor,FreshAnchor}
 /\ Len(recaptureReceipts)>=36 =>
      /\ recaptureReceipts[36].executed /\ recaptureReceipts[36].before.state.head=2
      /\ recaptureReceipts[36].before.state.parentAnchor=InitialAnchor
      /\ recaptureReceipts[36].before.produces=2 /\ recaptureReceipts[36].after.produces=3
      /\ recaptureReceipts[36].after.state.head=3 /\ recaptureReceipts[36].after.state.parentAnchor=FreshAnchor
\* Refusals at 5/9/12 isolate one missing resource in the two legal orders.
\* At 16 cached A exists but its backend is absent. Resources are irrelevant to
\* cached Land at 21: the reference alone is expired. At 30 only binding fails.
RecaptureExpectedRefusals == {5,9,12,16,21,30}
RecaptureTerminalComplete ==
 /\ recaptureIndex=37 /\ Len(recaptureReceipts)=36
 /\ \A i \in 1..36 :
      recaptureReceipts[i].executed=(i \notin RecaptureExpectedRefusals)
      /\ recaptureReceipts[i].enabled=(i \notin RecaptureExpectedRefusals)
 /\ r.jobs[0]=LiteralJob(0) /\ r.jobs[1]=LiteralJob(2)
 /\ r.proofs[<<0,"A">>]=LiteralProof(0) /\ r.proofs[<<0,"B">>]=LiteralProof(0)
 /\ r.proofs[<<1,"A">>]=LiteralProof(2) /\ r.proofs[<<1,"B">>]=LiteralProof(2)
 /\ r.published[0]=RecaptureData /\ r.published[1]=RecaptureData
 /\ r.generation=0 /\ r.start=0 /\ r.dependency=0 /\ r.now=4
 /\ r.head=3 /\ producedCount=3 /\ r.included=2 /\ r.finalized=2 /\ r.finalizedBlock=3
 /\ r.records[2]=[present |-> TRUE,generation |-> 0,parent |-> 0,cut |-> <<"Cut",0,2>>,includedAt |-> 3]
 /\ r.parentAnchor=FreshAnchor /\ r.anchors={InitialAnchor,FreshAnchor}
 /\ r.canonical=[h \in 0..3 |-> <<"Cut",0,h>>]
 /\ seen.recoveries={} /\ Cardinality(seen.lands)=1
 /\ seen.applied=[h \in 0..3 |-> IF h \in {1,2} THEN 1 ELSE 0]
 /\ \E b \in seen.blocks : b.height=3 /\ b.parentHeight=2 /\ b.parentCut= <<"Cut",0,2>>
      /\ b.inputAnchor=FreshAnchor /\ b.selected=FreshAnchor /\ b.at=4
 /\ \E f \in seen.finalizations : f.height=2 /\ f.block=3 /\ f.at=4 /\ f.kind="Ordinary" /\ f.generation=0
 /\ RecaptureExpiryAudit /\ RecaptureBindingAudit
RecaptureTerminalAudit == recaptureIndex=37 => RecaptureTerminalComplete
RecaptureTerminalNotReached == ~RecaptureTerminalComplete
=============================================================================
