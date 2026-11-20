--------------------- MODULE EtnaProvingArrivalOverlap ---------------------
EXTENDS EtnaProvingProgress
CONSTANTS OverlapPrograms, SuppressAction
\* Zero-arity literal operators allow cfg substitution without tuple-set syntax.
AllOverlapPrograms == {<<"HAB","Early">>, <<"HAB","Late">>,
    <<"HBA","Early">>, <<"HBA","Late">>, <<"AHB","Early">>, <<"AHB","Late">>,
    <<"ABH","Early">>, <<"ABH","Late">>, <<"BHA","Early">>, <<"BHA","Late">>,
    <<"BAH","Early">>, <<"BAH","Late">>}
ProgramHABEarly == {<<"HAB","Early">>}
ProgramHABLate == {<<"HAB","Late">>}
ProgramHBAEarly == {<<"HBA","Early">>}
ProgramHBALate == {<<"HBA","Late">>}
ProgramAHBEarly == {<<"AHB","Early">>}
ProgramAHBLate == {<<"AHB","Late">>}
ProgramABHEarly == {<<"ABH","Early">>}
ProgramABHLate == {<<"ABH","Late">>}
ProgramBHAEarly == {<<"BHA","Early">>}
ProgramBHALate == {<<"BHA","Late">>}
ProgramBAHEarly == {<<"BAH","Early">>}
ProgramBAHLate == {<<"BAH","Late">>}
ASSUME OverlapPrograms # {} /\ OverlapPrograms \subseteq AllOverlapPrograms
    /\ SuppressAction \in {"None","ShortLand","PublishFull"}
VARIABLES overlapProgram, overlapIndex, overlapReceipts
OverlapLocal == <<overlapProgram,overlapIndex,overlapReceipts>>
OverlapVars == <<vars,OverlapLocal>>
\* These are literal lists of attempted calls, including repeat completions.
OverlapCalls == CASE
    overlapProgram = <<"HAB","Early">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "HistoryOn", "ShortA", "ShortB", "LongA", "AOn", "ShortA", "ShortB", "LongA", "BOn", "ShortA", "ShortB", "LongA", "PublishShort", "BOff", "Tick", "ShortLand", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"HAB","Late">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "HistoryOn", "ShortA", "ShortB", "AOn", "ShortA", "ShortB", "BOn", "ShortA", "ShortB", "PublishShort", "BOff", "Tick", "ShortLand", "LongA", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"HBA","Early">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "HistoryOn", "ShortA", "ShortB", "LongA", "BOn", "ShortA", "ShortB", "LongA", "AOn", "ShortA", "ShortB", "LongA", "PublishShort", "BOff", "Tick", "ShortLand", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"HBA","Late">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "HistoryOn", "ShortA", "ShortB", "BOn", "ShortA", "ShortB", "AOn", "ShortA", "ShortB", "PublishShort", "BOff", "Tick", "ShortLand", "LongA", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"AHB","Early">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "AOn", "ShortA", "ShortB", "LongA", "HistoryOn", "ShortA", "ShortB", "LongA", "BOn", "ShortA", "ShortB", "LongA", "PublishShort", "BOff", "Tick", "ShortLand", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"AHB","Late">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "AOn", "ShortA", "ShortB", "HistoryOn", "ShortA", "ShortB", "BOn", "ShortA", "ShortB", "PublishShort", "BOff", "Tick", "ShortLand", "LongA", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"ABH","Early">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "AOn", "ShortA", "ShortB", "LongA", "BOn", "ShortA", "ShortB", "LongA", "HistoryOn", "ShortA", "ShortB", "LongA", "PublishShort", "BOff", "Tick", "ShortLand", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"ABH","Late">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "AOn", "ShortA", "ShortB", "BOn", "ShortA", "ShortB", "HistoryOn", "ShortA", "ShortB", "PublishShort", "BOff", "Tick", "ShortLand", "LongA", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"BHA","Early">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "BOn", "ShortA", "ShortB", "LongA", "HistoryOn", "ShortA", "ShortB", "LongA", "AOn", "ShortA", "ShortB", "LongA", "PublishShort", "BOff", "Tick", "ShortLand", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"BHA","Late">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "BOn", "ShortA", "ShortB", "HistoryOn", "ShortA", "ShortB", "AOn", "ShortA", "ShortB", "PublishShort", "BOff", "Tick", "ShortLand", "LongA", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"BAH","Early">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "BOn", "ShortA", "ShortB", "LongA", "AOn", "ShortA", "ShortB", "LongA", "HistoryOn", "ShortA", "ShortB", "LongA", "PublishShort", "BOff", "Tick", "ShortLand", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>
 [] overlapProgram = <<"BAH","Late">> ->
        <<"ProduceOld", "ProduceOld", "CaptureShort", "CaptureLong", "BOn", "ShortA", "ShortB", "AOn", "ShortA", "ShortB", "HistoryOn", "ShortA", "ShortB", "PublishShort", "BOff", "Tick", "ShortLand", "LongA", "AbsentLongB", "PublishSuffix", "BOn", "LongB", "SuffixLand", "PublishFull", "FullLand", "Tick", "Finalize", "PublishAnchor", "ProduceFinal">>

\* Literal expected enabledness is observation only; never used by dispatch.
OverlapExpectedEnabled == CASE
    overlapProgram = <<"HAB","Early">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"HAB","Late">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"HBA","Early">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"HBA","Late">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"AHB","Early">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"AHB","Late">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"ABH","Early">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"ABH","Late">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"BHA","Early">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"BHA","Late">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"BAH","Early">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>
 [] overlapProgram = <<"BAH","Late">> ->
        <<TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE>>

OverlapInitialAnchor == [id |-> <<0,0,0>>,generation |-> 0,checkpoint |-> 0,
    reference |-> 0,cut |-> <<"Cut",0,0>>]
OverlapFinalAnchor == [id |-> <<0,2,1>>,generation |-> 0,checkpoint |-> 2,
    reference |-> 1,cut |-> <<"Cut",0,2>>]
OverlapPartialAnchor == [id |-> <<0,1,1>>,generation |-> 0,checkpoint |-> 1,
    reference |-> 1,cut |-> <<"Cut",0,1>>]
OverlapCall(e) == CASE
    e="ProduceOld" -> Produce(OverlapInitialAnchor)
 [] e="CaptureShort" -> Capture(0,0,1,0)
 [] e="CaptureLong" -> Capture(1,0,2,0)
 [] e="HistoryOn" -> History(TRUE)
 [] e="AOn" -> Availability("A",TRUE)
 [] e="BOn" -> Availability("B",TRUE)
 [] e="BOff" -> Availability("B",FALSE)
 [] e="ShortA" -> Complete(0,"A",0)
 [] e="ShortB" -> Complete(0,"B",0)
 [] e="LongA" -> Complete(1,"A",1)
 [] e="AbsentLongB" -> Complete(1,"B",1)
 [] e="LongB" -> Complete(1,"B",1)
 [] e="PublishShort" -> Publish(0,TRUE)
 [] e="PublishSuffix" -> Publish(1,FALSE)
 [] e="PublishFull" -> Publish(1,TRUE)
 [] e="Tick" -> Tick
 [] e="ShortLand" -> Land(0)
 [] e="SuffixLand" -> Land(1)
 [] e="FullLand" -> Land(1)
 [] e="Finalize" -> Finalize(1)
 [] e="PublishAnchor" -> PublishAnchor
 [] e="ProduceFinal" -> Produce(OverlapFinalAnchor)
OverlapRaw == [state |-> r,observed |-> seen,stage |-> stage,produces |-> producedCount]
OverlapInit == /\ Init /\ overlapProgram \in OverlapPrograms
    /\ overlapIndex=1 /\ overlapReceipts= <<>>
OverlapStep ==
 /\ overlapIndex<=Len(OverlapCalls)
 \* Bind inherited stage before evaluating primed raw receipt fields. Produce
 \* itself assigns producedCount'; no wrapper increment is permitted.
 /\ UNCHANGED <<stage,overlapProgram>>
 /\ LET e==OverlapCalls[overlapIndex]
        enabled==ENABLED OverlapCall(e)
        executed==enabled /\ e#SuppressAction
    IN /\ IF executed THEN OverlapCall(e) ELSE UNCHANGED <<r,seen,producedCount>>
       /\ overlapReceipts'=Append(overlapReceipts,
            [call |-> e,enabled |-> enabled,executed |-> executed,
             before |-> OverlapRaw,after |-> OverlapRaw'])
 /\ overlapIndex'=overlapIndex+1
OverlapSpec == OverlapInit /\ [][OverlapStep]_OverlapVars

\* Literal identities do not call operational getters/Statement/Data/Cuts.
OverlapShortData == <<<<"Payload",<<"Cut",0,1>>>>>>
OverlapLongData == <<<<"Payload",<<"Cut",0,1>>>>,<<"Payload",<<"Cut",0,2>>>>>>
OverlapSuffixData == <<<<"Payload",<<"Cut",0,2>>>>>>
OverlapShortCuts == <<<<"Cut",0,0>>,<<"Cut",0,1>>>>
OverlapLongCuts == <<<<"Cut",0,0>>,<<"Cut",0,1>>,<<"Cut",0,2>>>>
OverlapShortJob == [present |-> TRUE,generation |-> 0,parent |-> 0,terminal |-> 1,
    reference |-> 0,dependency |-> 0,data |-> OverlapShortData,cuts |-> OverlapShortCuts,
    statement |-> <<0,0,1,<<"Ref",0>>,OverlapShortData,OverlapShortCuts,0>>]
OverlapLongJob == [present |-> TRUE,generation |-> 0,parent |-> 0,terminal |-> 2,
    reference |-> 0,dependency |-> 0,data |-> OverlapLongData,cuts |-> OverlapLongCuts,
    statement |-> <<0,0,2,<<"Ref",0>>,OverlapLongData,OverlapLongCuts,0>>]
OverlapShortProof == [present |-> TRUE,statement |-> OverlapShortJob.statement]
OverlapLongProof == [present |-> TRUE,statement |-> OverlapLongJob.statement]
OverlapRecord0 == [present |-> TRUE,generation |-> 0,parent |-> 0,cut |-> <<"Cut",0,0>>,includedAt |-> 0]
OverlapAbsent == [present |-> FALSE,generation |-> 0,parent |-> 0,cut |-> <<"Cut",0,0>>,includedAt |-> 0]
OverlapRecord1 == [present |-> TRUE,generation |-> 0,parent |-> 0,cut |-> <<"Cut",0,1>>,includedAt |-> 1]
OverlapRecord2 == [present |-> TRUE,generation |-> 0,parent |-> 1,cut |-> <<"Cut",0,2>>,includedAt |-> 1]
OverlapDirectRecord2 == [present |-> TRUE,generation |-> 0,parent |-> 0,cut |-> <<"Cut",0,2>>,includedAt |-> 1]
OverlapReceiptsNamed(name) == {overlapReceipts[i] : i \in
    {k \in 1..Len(overlapReceipts):overlapReceipts[k].call=name}}
OverlapDone == overlapIndex=Len(OverlapCalls)+1
\* Types cover complete original snapshots, including seen's operational journal.
OverlapCutType == {<<"Cut",g,h>>:g \in 0..1,h \in 0..3}
OverlapPayloadType == {<<"Payload",c>>:c \in OverlapCutType}
OverlapAnchorType == [id: (0..1) \X (0..3) \X (0..2),generation:0..1,
    checkpoint:0..3,reference:0..2,cut:OverlapCutType]
OverlapJobType == [present:BOOLEAN,generation:0..1,parent:0..3,terminal:0..3,
    reference:0..2,dependency:0..2,data:Seq(OverlapPayloadType),cuts:Seq(OverlapCutType),
    statement:{<<>>,OverlapShortJob.statement,OverlapLongJob.statement}]
OverlapProofType == [present:BOOLEAN,statement:{<<>>,OverlapShortJob.statement,OverlapLongJob.statement}]
OverlapRecordType == [present:BOOLEAN,generation:0..1,parent:0..3,cut:OverlapCutType,includedAt:0..2]
OverlapBlockType == [generation:0..1,height:0..3,parentHeight:0..3,parentCut:OverlapCutType,
    outputCut:OverlapCutType,inputAnchor:OverlapAnchorType,selected:OverlapAnchorType,
    beforeAnchor:OverlapAnchorType,at:0..2]
OverlapLandType == [job:0..1,currentGeneration:0..1,beforeC:0..3,afterC:0..3,
    record:OverlapRecordType,beforeHead:0..3,afterHead:0..3,beforeAnchor:OverlapAnchorType,
    published:Seq(OverlapPayloadType),proofA:{OverlapShortJob.statement,OverlapLongJob.statement},
    proofB:{OverlapShortJob.statement,OverlapLongJob.statement},at:0..2]
OverlapFinalizationType == [height:0..3,cut:OverlapCutType,at:0..2,block:0..2,
    kind:{"Genesis","Ordinary"},generation:0..1]
OverlapStateType == [head:0..3,generation:0..1,now:0..2,included:0..3,finalized:0..3,
    finalizedBlock:0..2,start:0..3,dependency:0..2,parentAnchor:OverlapAnchorType,
    anchors:SUBSET OverlapAnchorType,jobs:[0..1 -> OverlapJobType],privateHistory:BOOLEAN,
    available:[{"A","B"}->BOOLEAN],proofs:[(0..1) \X {"A","B"}->OverlapProofType],
    published:[0..1 -> Seq(OverlapPayloadType)],records:[0..3 -> OverlapRecordType],
    canonical:[0..3 -> OverlapCutType]]
OverlapSeenType == [blocks:SUBSET OverlapBlockType,jobInputs:[0..1 -> OverlapJobType],
    proofInputs:[(0..1) \X {"A","B"}->{<<>>,OverlapShortJob.statement,OverlapLongJob.statement}],
    lands:SUBSET OverlapLandType,expectedRecords:[0..3 -> OverlapRecordType],
    finalizations:SUBSET OverlapFinalizationType,anchors:SUBSET OverlapAnchorType,
    applied:[0..3 -> 0..2],recoveries:{ {}}]
OverlapRawType(q) == q \in [state:OverlapStateType,observed:OverlapSeenType,stage:{0},produces:0..3]
OverlapRawAudit ==
 /\ stage=0 /\ overlapIndex=Len(overlapReceipts)+1
 /\ OverlapRawType(OverlapRaw)
 /\ \A i \in 1..Len(overlapReceipts): LET q==overlapReceipts[i] IN
      /\ q.call=OverlapCalls[i] /\ q.enabled \in BOOLEAN /\ q.executed \in BOOLEAN
      /\ q.executed=(q.enabled /\ q.call#SuppressAction)
      /\ OverlapRawType(q.before) /\ OverlapRawType(q.after)
      /\ (i>1 => q.before=overlapReceipts[i-1].after)
      /\ (~q.executed => q.after=q.before)
 /\ Len(overlapReceipts)>=3 => r.jobs[0]=OverlapShortJob
 /\ Len(overlapReceipts)>=4 => r.jobs[1]=OverlapLongJob
\* Independent literal resource masks are (history,A,B) after each arrival.
OverlapResourceMasks == CASE
    overlapProgram[1]="HAB" -> <<<<TRUE,FALSE,FALSE>>,<<TRUE,TRUE,FALSE>>,<<TRUE,TRUE,TRUE>>>>
 [] overlapProgram[1]="HBA" -> <<<<TRUE,FALSE,FALSE>>,<<TRUE,FALSE,TRUE>>,<<TRUE,TRUE,TRUE>>>>
 [] overlapProgram[1]="AHB" -> <<<<FALSE,TRUE,FALSE>>,<<TRUE,TRUE,FALSE>>,<<TRUE,TRUE,TRUE>>>>
 [] overlapProgram[1]="ABH" -> <<<<FALSE,TRUE,FALSE>>,<<FALSE,TRUE,TRUE>>,<<TRUE,TRUE,TRUE>>>>
 [] overlapProgram[1]="BHA" -> <<<<FALSE,FALSE,TRUE>>,<<TRUE,FALSE,TRUE>>,<<TRUE,TRUE,TRUE>>>>
 [] overlapProgram[1]="BAH" -> <<<<FALSE,FALSE,TRUE>>,<<FALSE,TRUE,TRUE>>,<<TRUE,TRUE,TRUE>>>>
OverlapPrefixLength == IF overlapProgram[2]="Early" THEN 16 ELSE 13
OverlapPrefixAudit ==
 /\ \A i \in 1..Len(overlapReceipts): i<=OverlapPrefixLength =>
      LET q==overlapReceipts[i] IN
      /\ q.enabled=OverlapExpectedEnabled[i] /\ q.executed=q.enabled
      /\ q.after.state.now=0 /\ q.after.state.included=0
      /\ i>=5 => LET n==1+((i-5) \div (IF overlapProgram[2]="Early" THEN 4 ELSE 3))
                     m==OverlapResourceMasks[n]
                 IN <<q.after.state.privateHistory,q.after.state.available["A"],
                       q.after.state.available["B"]>>=m
      /\ CASE q.call="ShortA" -> q.after.state.proofs[<<0,"A">>]=
                   (IF q.enabled THEN OverlapShortProof ELSE q.before.state.proofs[<<0,"A">>])
           [] q.call="ShortB" -> q.after.state.proofs[<<0,"B">>]=
                   (IF q.enabled THEN OverlapShortProof ELSE q.before.state.proofs[<<0,"B">>])
           [] q.call="LongA" -> q.after.state.proofs[<<1,"A">>]=
                   (IF q.enabled THEN OverlapLongProof ELSE q.before.state.proofs[<<1,"A">>])
           [] OTHER -> TRUE
OverlapUnavailableAudit == \A q \in OverlapReceiptsNamed("AbsentLongB"):
    /\ q.before.state.privateHistory /\ q.before.state.available["A"]
    /\ ~q.before.state.available["B"] /\ ~q.enabled /\ ~q.executed /\ q.after=q.before
    /\ q.before.state.jobs[1]=OverlapLongJob
    /\ q.before.state.proofs[<<1,"A">>]=OverlapLongProof
OverlapFullPublicationAudit == \A q \in OverlapReceiptsNamed("SuffixLand"):
    /\ q.before.state.now=1 /\ q.before.state.included=1 /\ q.before.state.head=2
    /\ q.before.state.generation=0 /\ q.before.state.dependency=0
    /\ q.before.state.jobs[1]=OverlapLongJob
    /\ q.before.state.records[0]=OverlapRecord0 /\ q.before.state.records[1]=OverlapRecord1
    /\ q.before.state.proofs[<<1,"A">>]=OverlapLongProof
    /\ q.before.state.proofs[<<1,"B">>]=OverlapLongProof
    /\ q.before.state.published[1]=OverlapSuffixData
    /\ q.before.state.privateHistory /\ q.before.state.available=[b \in {"A","B"}|->TRUE]
    /\ ~q.enabled /\ ~q.executed /\ q.after=q.before
\* Immediate raw retained-record audit. Mutation must touch Land.r', not seen.
OverlapRetainedPrefixAudit == \A q \in OverlapReceiptsNamed("FullLand"):
    (q.executed /\ q.before.state.included=1) =>
      /\ q.before.state.records[1]=OverlapRecord1
      /\ q.after.state.records[1]=OverlapRecord1
OverlapMilestoneAudit ==
 /\ \A q \in OverlapReceiptsNamed("ShortLand"):
      /\ q.executed /\ q.before.state.now=1 /\ q.after.state.now=1
      /\ q.before.state.included=0 /\ q.after.state.included=1
      /\ ~q.before.state.available["B"] /\ ~q.after.state.available["B"]
      /\ q.before.state.proofs[<<0,"A">>]=OverlapShortProof
      /\ q.before.state.proofs[<<0,"B">>]=OverlapShortProof
      /\ q.before.state.published[0]=OverlapShortData
      /\ q.after.state.records[1]=OverlapRecord1
      /\ q.after.observed.applied=[h \in 0..3 |-> IF h=1 THEN 1 ELSE 0]
 /\ \A q \in OverlapReceiptsNamed("FullLand"):
      /\ q.executed /\ q.before.state.now=1 /\ q.after.state.now=1
      /\ q.before.state.included=1 /\ q.after.state.included=2
      /\ q.before.state.jobs[1]=OverlapLongJob /\ q.after.state.jobs[1]=OverlapLongJob
      /\ q.before.state.published[1]=OverlapLongData
      /\ q.after.state.records[2]=OverlapRecord2
      /\ q.after.observed.applied=[h \in 0..3 |-> IF h \in {1,2} THEN 1 ELSE 0]
 /\ \A q \in OverlapReceiptsNamed("Finalize"):
      /\ q.executed /\ q.before.state.now=2 /\ q.after.state.finalized=2
      /\ q.before.state.finalized=0 /\ q.after.state.finalizedBlock=1
 /\ \A q \in OverlapReceiptsNamed("PublishAnchor"):
      /\ q.executed /\ q.before.state.anchors={OverlapInitialAnchor}
      /\ q.after.state.anchors={OverlapInitialAnchor,OverlapFinalAnchor}
 /\ \A q \in OverlapReceiptsNamed("ProduceFinal"):
      /\ q.executed /\ q.before.produces=2 /\ q.after.produces=3
      /\ q.before.state.head=2 /\ q.after.state.head=3 /\ q.after.state.now=2
      /\ q.before.state.parentAnchor=OverlapInitialAnchor
      /\ q.after.state.parentAnchor=OverlapFinalAnchor
OverlapTerminalComplete ==
 /\ OverlapDone /\ Len(overlapReceipts)=(IF overlapProgram[2]="Early" THEN 31 ELSE 29)
 /\ \A i \in 1..Len(OverlapCalls):
      overlapReceipts[i].enabled=OverlapExpectedEnabled[i]
      /\ overlapReceipts[i].executed=OverlapExpectedEnabled[i]
 /\ OverlapRawAudit /\ OverlapPrefixAudit /\ OverlapUnavailableAudit
 /\ OverlapFullPublicationAudit /\ OverlapRetainedPrefixAudit /\ OverlapMilestoneAudit
 /\ r.jobs=[j \in 0..1 |-> IF j=0 THEN OverlapShortJob ELSE OverlapLongJob]
 /\ r.proofs=[p \in (0..1) \X {"A","B"} |-> IF p[1]=0 THEN OverlapShortProof ELSE OverlapLongProof]
 /\ r.published=[j \in 0..1 |-> IF j=0 THEN OverlapShortData ELSE OverlapLongData]
 /\ r.now=2 /\ r.head=3 /\ producedCount=3 /\ r.included=2 /\ r.finalized=2 /\ r.finalizedBlock=1
 /\ r.generation=0 /\ r.start=0 /\ r.dependency=0 /\ r.privateHistory
 /\ r.available=[b \in {"A","B"}|->TRUE]
 /\ r.parentAnchor=OverlapFinalAnchor /\ r.anchors={OverlapInitialAnchor,OverlapFinalAnchor}
 /\ r.records=[h \in 0..3 |-> CASE h=0 -> OverlapRecord0 [] h=1 -> OverlapRecord1
                              [] h=2 -> OverlapRecord2 [] OTHER -> OverlapAbsent]
 /\ r.canonical=[h \in 0..3 |-> <<"Cut",0,h>>]
 /\ seen.recoveries={} /\ Cardinality(seen.lands)=2 /\ Cardinality(seen.blocks)=3
 /\ seen.applied=[h \in 0..3 |-> IF h \in {1,2} THEN 1 ELSE 0]
 /\ \E b \in seen.blocks:b.height=3 /\ b.parentHeight=2 /\ b.parentCut= <<"Cut",0,2>>
      /\ b.outputCut= <<"Cut",0,3>> /\ b.selected=OverlapFinalAnchor /\ b.inputAnchor=OverlapFinalAnchor /\ b.at=2
 /\ \E f \in seen.finalizations:f.height=2 /\ f.block=1 /\ f.at=2 /\ f.kind="Ordinary" /\ f.generation=0 /\ f.cut= <<"Cut",0,2>>
OverlapTerminalAudit == OverlapDone => OverlapTerminalComplete
OverlapTerminalNotReached == ~OverlapTerminalComplete
\* Omission controls observe their actual endpoint; normal expected masks do not
\* reject the legal direct landing introduced by missing the first short Land.
OverlapOmissionAudit == OverlapDone =>
 /\ ~OverlapTerminalComplete /\ OverlapRawAudit /\ OverlapPrefixAudit /\ OverlapUnavailableAudit
 /\ r.now=2 /\ r.generation=0 /\ r.start=0 /\ r.dependency=0
 /\ r.jobs[0]=OverlapShortJob /\ r.jobs[1]=OverlapLongJob
 /\ r.proofs=[p \in (0..1) \X {"A","B"} |-> IF p[1]=0 THEN OverlapShortProof ELSE OverlapLongProof]
 /\ Cardinality(seen.lands)=1 /\ seen.recoveries={}
 /\ CASE SuppressAction="ShortLand" ->
      /\ r.head=3 /\ producedCount=3 /\ r.included=2 /\ r.finalized=2 /\ r.finalizedBlock=1
      /\ r.records[1]=OverlapAbsent /\ r.records[2]=OverlapDirectRecord2
      /\ seen.applied=[h \in 0..3 |-> IF h \in {1,2} THEN 1 ELSE 0]
      /\ r.parentAnchor=OverlapFinalAnchor
      /\ \A q \in OverlapReceiptsNamed("ShortLand"):q.enabled /\ ~q.executed /\ q.before=q.after
      /\ \A q \in OverlapReceiptsNamed("PublishSuffix"):q.after.state.published[1]=OverlapLongData
      /\ \A q \in OverlapReceiptsNamed("SuffixLand"):q.enabled /\ q.executed /\ q.before.state.included=0 /\ q.after.state.included=2
      /\ \A q \in OverlapReceiptsNamed("FullLand"):~q.enabled /\ ~q.executed /\ q.before=q.after
    [] SuppressAction="PublishFull" ->
      /\ r.head=2 /\ producedCount=2 /\ r.included=1 /\ r.finalized=1 /\ r.finalizedBlock=1
      /\ r.records[1]=OverlapRecord1 /\ r.records[2]=OverlapAbsent
      /\ r.published[1]=OverlapSuffixData
      /\ r.anchors={OverlapInitialAnchor,OverlapPartialAnchor} /\ r.parentAnchor=OverlapInitialAnchor
      /\ seen.applied=[h \in 0..3 |-> IF h=1 THEN 1 ELSE 0]
      /\ \A q \in OverlapReceiptsNamed("PublishFull"):q.enabled /\ ~q.executed /\ q.before=q.after
      /\ \A q \in OverlapReceiptsNamed("FullLand"):~q.enabled /\ ~q.executed /\ q.before=q.after
      /\ \A q \in OverlapReceiptsNamed("ProduceFinal"):~q.enabled /\ ~q.executed /\ q.before=q.after
OverlapPartialTerminalNotReached == ~OverlapDone
=============================================================================
