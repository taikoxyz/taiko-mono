------------------- MODULE EtnaRepeatedRecoveryIdentity -------------------
EXTENDS EtnaCheckpointIdentity, Sequences, FiniteSets
CONSTANTS RepeatedSuppress, RepeatedEnd
ASSUME /\ RepeatedSuppress \in {"None", "OverlapLand", "Recover1", "Recover2"}
       /\ RepeatedEnd \in 1..13
VARIABLES repeatedIndex, repeatedReceipts
RepeatedLocal == <<repeatedIndex, repeatedReceipts>>
RepeatedVars == <<allVars, RepeatedLocal>>
RepeatedCalls == <<"Fresh1", "Authorize1", "Tick1", "Recover1", "Prepare3",
    "Fresh2", "OverlapLand", "Prepare4", "Authorize2", "Tick2", "Recover2",
    "OldLand4", "Fresh4">>
\* Dispatch contains only the inherited API and identity-local framing for bare
\* settlement actions. Expected results never participate in enabling a call.
RepeatedCall(name) == CASE
    name="Fresh1" -> IdentityLandFresh(1,"A","A",FALSE)
 [] name="Authorize1" -> Authorize(1) /\ UNCHANGED identityVars
 [] name="Tick1" -> Tick /\ UNCHANGED identityVars
 [] name="Recover1" -> IdentityRecover
 [] name="Prepare3" -> PrepareIdentityProof(3,"A","A",FALSE)
 [] name="Fresh2" -> IdentityLandFresh(2,"A","A",FALSE)
 [] name="OverlapLand" -> IdentityLand(pendingProof,queuedIdentity)
 [] name="Prepare4" -> PrepareIdentityProof(4,"A","A",FALSE)
 [] name="Authorize2" -> Authorize(2) /\ UNCHANGED identityVars
 [] name="Tick2" -> Tick /\ UNCHANGED identityVars
 [] name="Recover2" -> IdentityRecover
 [] name="OldLand4" -> IdentityLand(pendingProof,queuedIdentity)
 [] name="Fresh4" -> IdentityLandFresh(4,"B","B",FALSE)
RepeatedRaw == [c |-> c, generation |-> generation, nonce |-> recoveryNonce,
    start |-> startHeight, now |-> now, authorization |-> authorization,
    pending |-> pendingProof, landings |-> landings, lastLanding |-> lastLanding,
    audit |-> audit, queued |-> queuedIdentity, records |-> recordCuts,
    prefix |-> prefixCuts, prefixGeneration |-> prefixGeneration,
    identityAudit |-> identityAudit]
RepeatedInit == /\ IdentityInit /\ repeatedIndex=1 /\ repeatedReceipts= <<>>
RepeatedStep ==
 /\ repeatedIndex<=RepeatedEnd
 /\ LET name==RepeatedCalls[repeatedIndex]
        enabled==ENABLED RepeatedCall(name)
        executed==enabled /\ name#RepeatedSuppress
    IN /\ IF executed THEN RepeatedCall(name) ELSE UNCHANGED allVars
       /\ repeatedReceipts'=Append(repeatedReceipts,
           [ordinal |-> repeatedIndex, call |-> name, enabled |-> enabled,
            executed |-> executed, before |-> RepeatedRaw, after |-> RepeatedRaw'])
 /\ repeatedIndex'=repeatedIndex+1
RepeatedSpec == RepeatedInit /\ [][RepeatedStep]_RepeatedVars

\* These expected values are literal records, never CandidateCut/BuildIdentity
\* or sticky identity journals. Helpers below construct only literal fixtures.
RepeatedCut(g,h,tag) == [height |-> h, el |-> <<"EL",g,h,"Shared">>,
    comet |-> <<"Comet",g,h,"Shared">>, fi |-> 0, val |-> <<"Val",g,h,tag>>]
RepeatedProof(g,p,h) == [present |-> TRUE,generation |-> g,parent |-> p,terminal |-> h]
RepeatedLanding(g,p) == [present |-> TRUE,generation |-> g,parent |-> p]
RepeatedIdentity(public,execution) == [executionHistory |-> "A",leafHistory |-> "A",
    publicOrigin |-> public, executionOrigin |-> execution]
RepeatedPrepared3 == RepeatedIdentity(RepeatedCut(0,1,"Shared"),
    [RepeatedCut(0,1,"Shared") EXCEPT !.val= <<"Genesis",1>>])
RepeatedPrepared4 == RepeatedIdentity(RepeatedCut(1,3,"A"),RepeatedCut(1,3,"A"))
RepeatedScalar(x) == <<x.c,x.generation,x.nonce,x.start,x.now>>
RepeatedScalars == << <<1,0,0,0,0>>, <<1,0,0,0,0>>, <<1,0,0,0,1>>,
    <<1,1,1,1,1>>, <<1,1,1,1,1>>, <<2,1,1,1,1>>, <<3,1,1,1,1>>,
    <<3,1,1,1,1>>, <<3,1,1,1,1>>, <<3,1,1,1,2>>, <<3,2,2,3,2>>,
    <<3,2,2,3,2>>, <<4,2,2,3,2>> >>
RepeatedRawAudit ==
 /\ repeatedIndex=Len(repeatedReceipts)+1 /\ repeatedIndex \in 1..(RepeatedEnd+1)
 /\ \A i \in 1..Len(repeatedReceipts): LET q==repeatedReceipts[i] IN
     /\ q.ordinal=i /\ q.call=RepeatedCalls[i]
     /\ q.executed=(q.enabled /\ q.call#RepeatedSuppress)
     /\ i>1 => q.before=repeatedReceipts[i-1].after
     /\ ~q.executed => q.after=q.before
 /\ Len(repeatedReceipts)>0 => RepeatedRaw=repeatedReceipts[Len(repeatedReceipts)].after
\* Deliberately narrow immediate source-fault oracle. It does not assert a
\* refusal or terminal first, and does not constrain the dispatched action.
RepeatedSecondGenerationAudit == Len(repeatedReceipts)>=11 =>
    LET q==repeatedReceipts[11] IN
      q.executed => q.before.generation=1 /\ q.after.generation=2
RepeatedSecondNonceAudit == Len(repeatedReceipts)>=11 =>
    LET q==repeatedReceipts[11] IN
      q.executed => q.before.nonce=1 /\ q.after.nonce=2
RepeatedHistoryAudit ==
 /\ \A i \in 1..Len(repeatedReceipts): LET q==repeatedReceipts[i] IN
     /\ q.enabled=(i#12) /\ q.executed=(i#12)
     /\ RepeatedScalar(q.after)=RepeatedScalars[i]
     /\ RepeatedScalar(q.before)=(IF i=1 THEN <<0,0,0,0,0>> ELSE RepeatedScalars[i-1])
     /\ i \in {2,3,9,10} =>
         /\ q.after.queued=q.before.queued /\ q.after.records=q.before.records
         /\ q.after.prefix=q.before.prefix /\ q.after.prefixGeneration=q.before.prefixGeneration
         /\ q.after.identityAudit=q.before.identityAudit
     /\ i \in {4,11} =>
         /\ q.after.c=q.before.c /\ q.after.landings=q.before.landings
         /\ q.after.records=q.before.records /\ q.after.prefix=q.before.prefix
         /\ q.after.prefixGeneration=q.before.prefixGeneration
         /\ q.after.pending=q.before.pending /\ q.after.queued=q.before.queued
     /\ i \in {6,7,9,10,11,12,13} =>
         q.after.pending=q.before.pending /\ q.after.queued=q.before.queued
 /\ Len(repeatedReceipts)>=2 => repeatedReceipts[2].after.authorization=
     [present |-> TRUE,generation |-> 0,checkpoint |-> 1,nonce |-> 0,deadline |-> 1]
 /\ Len(repeatedReceipts)>=5 =>
     /\ repeatedReceipts[5].after.pending=RepeatedProof(1,1,3)
     /\ repeatedReceipts[5].after.queued=RepeatedPrepared3
 /\ Len(repeatedReceipts)>=7 => LET q==repeatedReceipts[7] IN
     /\ q.before.pending=RepeatedProof(1,1,3) /\ q.before.c=2
     /\ q.before.queued=RepeatedPrepared3
     /\ q.after.landings[3]=RepeatedLanding(1,2)
     /\ q.after.lastLanding=[present |-> TRUE,proofOrigin |-> 1,previousC |-> 2,
           terminal |-> 3,recordedParent |-> 2]
     /\ \A h \in 0..2: q.after.prefix[h]=q.before.prefix[h]
 /\ Len(repeatedReceipts)>=8 =>
     /\ repeatedReceipts[8].after.pending=RepeatedProof(1,3,4)
     /\ repeatedReceipts[8].after.queued=RepeatedPrepared4
 /\ Len(repeatedReceipts)>=9 => repeatedReceipts[9].after.authorization=
     [present |-> TRUE,generation |-> 1,checkpoint |-> 3,nonce |-> 1,deadline |-> 2]
 /\ Len(repeatedReceipts)>=12 => LET q==repeatedReceipts[12] IN
     /\ q.before.pending=RepeatedProof(1,3,4) /\ q.before.queued=RepeatedPrepared4
     /\ q.before.generation=2 /\ q.before.start=3
     /\ q.before.queued.executionOrigin.val # <<"Genesis",1>>
     /\ ~q.enabled /\ ~q.executed /\ q.after=q.before
 /\ Len(repeatedReceipts)>=13 => LET q==repeatedReceipts[13] IN
     /\ q.before.records[3]=RepeatedCut(1,3,"A")
     /\ q.before.records[3].val # <<"Genesis",2>>
     /\ q.after.records[4]=RepeatedCut(2,4,"B")
RepeatedTerminalComplete ==
 /\ repeatedIndex=14 /\ Len(repeatedReceipts)=13
 /\ RepeatedRawAudit /\ RepeatedHistoryAudit
 /\ RepeatedScalar(RepeatedRaw)= <<4,2,2,3,2>>
 /\ landings[1]=RepeatedLanding(0,0) /\ landings[2]=RepeatedLanding(1,1)
 /\ landings[3]=RepeatedLanding(1,2) /\ landings[4]=RepeatedLanding(2,3)
 /\ <<prefixGeneration[1],prefixGeneration[2],prefixGeneration[3],prefixGeneration[4]>>= <<0,1,1,2>>
 /\ <<recordCuts[1],recordCuts[2],recordCuts[3],recordCuts[4]>>=
      <<RepeatedCut(0,1,"Shared"),RepeatedCut(1,2,"Shared"),
        RepeatedCut(1,3,"A"),RepeatedCut(2,4,"B")>>
 /\ \A h \in 1..4: prefixCuts[h]=recordCuts[h]
 /\ Cardinality({i \in 1..13: repeatedReceipts[i].executed /\
        repeatedReceipts[i].call \in {"Recover1","Recover2"}})=2
 /\ Cardinality({i \in 1..13: repeatedReceipts[i].executed /\
        repeatedReceipts[i].call \in {"Fresh1","Fresh2","OverlapLand","OldLand4","Fresh4"}})=4
RepeatedTerminalAudit == repeatedIndex=14 => RepeatedTerminalComplete
RepeatedTerminalNotReached == ~RepeatedTerminalComplete
RepeatedEndNotReached == repeatedIndex<=RepeatedEnd
=============================================================================
