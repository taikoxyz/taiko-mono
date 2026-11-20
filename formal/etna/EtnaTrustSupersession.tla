--------------------- MODULE EtnaTrustSupersession ---------------------
EXTENDS EtnaL1Trust, Sequences
CONSTANTS FirstObservers, SuppressAttempt
ASSUME /\ FirstObservers # {} /\ FirstObservers \subseteq {1,2}
       /\ SuppressAttempt \in {0,21}
       /\ NodeCount=2 /\ MaxSnapshot=2 /\ SessionGeneration=0
VARIABLES firstObserver, trustIndex, trustReceipts, trustNodeHistories
TrustLocal == <<firstObserver,trustIndex,trustReceipts,trustNodeHistories>>
TrustAllVars == <<vars,TrustLocal>>
TrustA == firstObserver
TrustB == 3-firstObserver
TrustCalls == <<"Include1","Finalize1","ProviderA1","SessionA","AuthenticateA1",
    "EvidenceA1Exact","GrantA","BlockA","ServeA","ProviderB1","SessionB",
    "AuthenticateB1","EvidenceB1Exact","GrantB","BlockB","ServeB",
    "Include2","ProviderA2","ObserveAUnfinalized","Finalize2","ObserveAFinalized",
    "RetainedB","ServeBLagging","BlockARevoked","NilARevoked","RetainedARevoked",
    "ServeARevoked","SessionAKnown","ProviderAOld","AuthenticateAOld",
    "EvidenceAOldExact","GrantAOld","BlockAOld","ServeAOld","ProviderANew",
    "AuthenticateANew","SessionAHalted","ProviderBNew","ObserveBFinalized",
    "SessionBKnown","AuthenticateBNew">>
\* This table calls the original actions. Expected receipts are never guards.
TrustCall(i) == CASE
    i \in {1,17} -> Include
 [] i \in {2,20} -> Finalize
 [] i \in {3,29} -> ProviderView(TrustA,1)
 [] i \in {18,35} -> ProviderView(TrustA,2)
 [] i=10 -> ProviderView(TrustB,1)
 [] i=38 -> ProviderView(TrustB,2)
 [] i \in {4,28,37} -> BeginSession(TrustA)
 [] i \in {11,40} -> BeginSession(TrustB)
 [] i \in {5,30,36} -> AuthenticateTarget(TrustA)
 [] i \in {12,41} -> AuthenticateTarget(TrustB)
 [] i \in {6,31} -> LoadEvidence(TrustA,1,"Exact")
 [] i=13 -> LoadEvidence(TrustB,1,"Exact")
 [] i \in {7,32} -> GrantTrust(TrustA)
 [] i=14 -> GrantTrust(TrustB)
 [] i \in {8,24,33} -> Sign(TrustA,"Block",TRUE)
 [] i=25 -> Sign(TrustA,"Nil",TRUE)
 [] i=26 -> Sign(TrustA,"Retained",TRUE)
 [] i=15 -> Sign(TrustB,"Block",TRUE)
 [] i=22 -> Sign(TrustB,"Retained",TRUE)
 [] i \in {9,27,34} -> Serve(TrustA)
 [] i \in {16,23} -> Serve(TrustB)
 [] i \in {19,21} -> ObserveGeneration(TrustA)
 [] i=39 -> ObserveGeneration(TrustB)
TrustRaw == [included |-> included,finalized |-> finalized,provider |-> provider,
    target |-> target,local |-> local,certificate |-> certificate,trusted |-> trusted,
    halted |-> halted,known |-> knownGeneration,ever |-> everGeneration,
    lastRead |-> lastRead,missingSeen |-> missingSeen,missingAt |-> missingAt,
    haltHistory |-> haltHistory,faults |-> faults,event |-> event]
TrustNode(r,n) == [provider |-> r.provider[n],target |-> r.target[n],local |-> r.local[n],
    certificate |-> r.certificate[n],trusted |-> r.trusted[n],halted |-> r.halted[n],
    known |-> r.known[n],ever |-> r.ever[n],lastRead |-> r.lastRead[n],
    missingSeen |-> r.missingSeen[n],missingAt |-> r.missingAt[n],haltHistory |-> r.haltHistory[n]]
TrustInit == /\ Init /\ firstObserver \in FirstObservers /\ trustIndex=1
             /\ trustReceipts= <<>> /\ trustNodeHistories=[n \in Nodes |-> <<>>]
TrustStep ==
 /\ trustIndex<=41 /\ UNCHANGED firstObserver
 /\ LET enabled==ENABLED TrustCall(trustIndex)
        executed==enabled /\ trustIndex#SuppressAttempt
    IN /\ IF executed THEN TrustCall(trustIndex) ELSE UNCHANGED vars
       /\ trustReceipts'=Append(trustReceipts,
           [call |-> TrustCalls[trustIndex],enabled |-> enabled,executed |-> executed,
            before |-> TrustRaw,after |-> TrustRaw'])
       /\ trustNodeHistories'=[n \in Nodes |-> Append(trustNodeHistories[n],
           [call |-> TrustCalls[trustIndex],enabled |-> enabled,executed |-> executed,
            before |-> TrustNode(TrustRaw,n),after |-> TrustNode(TrustRaw',n)])]
 /\ trustIndex'=trustIndex+1
TrustSupersessionSpec == TrustInit /\ [][TrustStep]_TrustAllVars

\* Literal identities: no certificate/height/generation/evidence helper oracle.
TrustEmptyCert == [present |-> FALSE,snapshot |-> 0,authenticatedFinalized |-> FALSE,
    height |-> 0,el |-> <<"EL",0>>,comet |-> <<"HistoricalComet",0>>,
    val |-> <<"MissingVal">>,valSource |-> "Missing",valGeneration |-> 0]
TrustSnapshot1Cert == [present |-> TRUE,snapshot |-> 1,authenticatedFinalized |-> TRUE,
    height |-> 1,el |-> <<"EL",1>>,comet |-> <<"HistoricalComet",1>>,
    val |-> <<"RecordedVal",0,1>>,valSource |-> "Recorded",valGeneration |-> 0]
TrustTarget0 == [ready |-> FALSE,snapshot |-> 0,authenticatedFinalized |-> FALSE]
TrustTarget1 == [ready |-> TRUE,snapshot |-> 1,authenticatedFinalized |-> TRUE]
TrustTarget2 == [ready |-> TRUE,snapshot |-> 2,authenticatedFinalized |-> TRUE]
TrustExact1 == [snapshot |-> 1,kind |-> "Exact"]
TrustNoFaults == [signTrust |-> FALSE,signApp |-> FALSE,staleSign |-> FALSE,
    serveTrust |-> FALSE,timeoutHalt |-> FALSE,missingHalt |-> FALSE,
    unsupportedHalt |-> FALSE,contradictionRetry |-> FALSE]
TrustNone == [kind |-> "None",node |-> 1]
TrustInitialRaw == [included |-> 0,finalized |-> 0,provider |-> [n \in 1..2 |-> 0],
    target |-> [n \in 1..2 |-> TrustTarget0],
    local |-> [n \in 1..2 |-> [snapshot |-> 0,kind |-> "Missing"]],
    certificate |-> [n \in 1..2 |-> TrustEmptyCert],
    trusted |-> [n \in 1..2 |-> FALSE],halted |-> [n \in 1..2 |-> FALSE],
    known |-> [n \in 1..2 |-> 0],ever |-> [n \in 1..2 |-> 0],
    lastRead |-> [n \in 1..2 |-> "None"],missingSeen |-> [n \in 1..2 |-> FALSE],
    missingAt |-> [n \in 1..2 |-> 0],haltHistory |-> [n \in 1..2 |-> FALSE],
    faults |-> TrustNoFaults,event |-> TrustNone]
TrustOmitted == SuppressAttempt=21
TrustNormalRefusals == {19,24,25,26,27,32,33,34,37}
\* Omission changes real enabledness: 24..27 and 32..34 execute, 36 refuses,
\* 37 executes. 21 was enabled but deliberately omitted; 19 still refuses.
TrustExpectedEnabled(i) == i \notin (IF TrustOmitted THEN {19,36} ELSE TrustNormalRefusals)
TrustActor(i) == IF i \in {10,11,12,13,14,15,16,22,23,38,39,40,41} THEN TrustB ELSE TrustA
\* Whole-record independent frames: EXCEPT changes only the listed fields.
\* Literals come from the fixed 41-call histories, never source model getters.
TrustExpectedAfter(r,i) ==
 LET n==TrustActor(i)
 IN IF ~TrustExpectedEnabled(i) \/ i=SuppressAttempt THEN r ELSE CASE
    i \in {1,17} -> [r EXCEPT !.included=IF i=1 THEN 1 ELSE 2,!.event=TrustNone]
 [] i \in {2,20} -> [r EXCEPT !.finalized=IF i=2 THEN 1 ELSE 2,!.event=TrustNone]
 [] i \in {3,10,29} -> [r EXCEPT !.provider[n]=1,!.event=TrustNone]
 [] i \in {18,35,38} -> [r EXCEPT !.provider[n]=2,!.event=TrustNone]
 [] i \in {4,11,28,37,40} -> [r EXCEPT !.trusted[n]=FALSE,
      !.certificate[n]=TrustEmptyCert,!.target[n].ready=FALSE,
      !.lastRead[n]="None",!.missingSeen[n]=FALSE,!.event=[kind |-> "Session",node |-> n]]
 [] i \in {5,12,30} -> [r EXCEPT !.target[n]=TrustTarget1,
      !.known[n]=IF i=30 /\ ~TrustOmitted THEN 1 ELSE 0,
      !.ever[n]=IF i=30 /\ ~TrustOmitted THEN 1 ELSE 0,
      !.halted[n]=FALSE,!.lastRead[n]="OK",!.event=[kind |-> "Learn",node |-> n]]
 [] i \in {36,41} -> [r EXCEPT !.target[n]=TrustTarget2,!.known[n]=1,!.ever[n]=1,
      !.halted[n]=TRUE,!.haltHistory[n]=TRUE,!.lastRead[n]="OK",
      !.event=[kind |-> "StartupMismatch",node |-> n]]
 [] i \in {6,13,31} -> [r EXCEPT !.local[n]=TrustExact1,!.event=TrustNone]
 [] i \in {7,14,32} -> [r EXCEPT !.certificate[n]=TrustSnapshot1Cert,
      !.trusted[n]=TRUE,!.event=[kind |-> "Trust",node |-> n]]
 [] i \in {8,15,22,24,25,26,33} -> [r EXCEPT !.event=[kind |-> "Sign",node |-> n]]
 [] i \in {9,16,23,27,34} -> [r EXCEPT !.event=[kind |-> "Serve",node |-> n]]
 [] i \in {21,39} -> [r EXCEPT !.known[n]=1,!.ever[n]=1,!.trusted[n]=FALSE,
      !.lastRead[n]="OK",!.event=[kind |-> "Revoke",node |-> n]]
TrustRawAudit ==
 /\ trustIndex=Len(trustReceipts)+1 /\ trustIndex \in 1..42
 /\ trustIndex=1 => TrustRaw=TrustInitialRaw
 /\ \A i \in 1..Len(trustReceipts) : LET q==trustReceipts[i] IN
     /\ q.call=TrustCalls[i]
     /\ q.before=IF i=1 THEN TrustInitialRaw ELSE trustReceipts[i-1].after
     /\ q.enabled=TrustExpectedEnabled(i)
     /\ q.executed=(q.enabled /\ i#SuppressAttempt)
     /\ q.after=TrustExpectedAfter(q.before,i)
 /\ trustIndex>1 => TrustRaw=trustReceipts[trustIndex-1].after
 /\ \A n \in Nodes :
     /\ Len(trustNodeHistories[n])=Len(trustReceipts)
     /\ \A i \in 1..Len(trustReceipts) : LET q==trustReceipts[i] IN
          trustNodeHistories[n][i]=[call |-> q.call,enabled |-> q.enabled,executed |-> q.executed,
              before |-> TrustNode(q.before,n),after |-> TrustNode(q.after,n)]
\* Sole invariant in focused source-fault profiles: catches the FIRST wrong write
\* immediately, before a later unavailable lagging Sign/Serve can obscure it.
TrustSelectiveRevokeAudit == \A i \in {k \in 1..Len(trustReceipts) : k \in {21,39}} :
 LET q==trustReceipts[i] n==IF i=21 THEN TrustA ELSE TrustB other==3-n IN
 q.executed =>
    /\ q.before.trusted[n] /\ q.after.trusted[n]=FALSE
    /\ q.before.known[n]=0 /\ q.after.known[n]=1 /\ q.after.ever[n]=1
    /\ TrustNode(q.after,other)=TrustNode(q.before,other)
    /\ i=21 => q.before.trusted[other] /\ q.after.trusted[other]
TrustMilestoneAudit ==
 /\ Len(trustReceipts)>=16 => LET r==trustReceipts[16].after IN
       /\ r.included=1 /\ r.finalized=1
       /\ \A n \in Nodes : r.certificate[n]=TrustSnapshot1Cert /\ r.trusted[n]
              /\ r.target[n]=TrustTarget1 /\ r.local[n]=TrustExact1
              /\ r.known[n]=0 /\ r.ever[n]=0 /\ ~r.halted[n]
 /\ Len(trustReceipts)>=19 => LET q==trustReceipts[19] IN
       /\ q.before.included=2 /\ q.before.finalized=1 /\ q.before.provider[TrustA]=2
       /\ ~q.enabled /\ ~q.executed /\ q.after=q.before
 /\ Len(trustReceipts)>=23 =>
       /\ trustReceipts[22].executed /\ trustReceipts[23].executed
       /\ \A i \in {22,23} : LET r==trustReceipts[i].before IN
            /\ r.provider[TrustB]=1 /\ r.known[TrustB]=0 /\ r.ever[TrustB]=0
            /\ r.trusted[TrustB] /\ r.certificate[TrustB]=TrustSnapshot1Cert
            /\ r.finalized=2
 /\ ~TrustOmitted /\ Len(trustReceipts)>=28 => LET q==trustReceipts[28] IN
       /\ q.executed /\ q.before.known[TrustA]=1 /\ q.after.known[TrustA]=1
       /\ q.after.certificate[TrustA]=TrustEmptyCert /\ ~q.after.target[TrustA].ready
 /\ ~TrustOmitted /\ Len(trustReceipts)>=37 =>
       /\ trustReceipts[36].executed /\ trustReceipts[36].after.halted[TrustA]
       /\ ~trustReceipts[37].enabled
       /\ TrustNode(trustReceipts[37].after,TrustB)=TrustNode(trustReceipts[21].before,TrustB)
TrustFinalRaw(omitted) == [included |-> 2,finalized |-> 2,provider |-> [n \in 1..2 |-> 2],
    target |-> [n \in 1..2 |-> IF omitted /\ n=TrustA
        THEN [ready |-> FALSE,snapshot |-> 1,authenticatedFinalized |-> TRUE] ELSE TrustTarget2],
    local |-> [n \in 1..2 |-> TrustExact1],certificate |-> [n \in 1..2 |-> TrustEmptyCert],
    trusted |-> [n \in 1..2 |-> FALSE],halted |-> [n \in 1..2 |-> ~(omitted /\ n=TrustA)],
    known |-> [n \in 1..2 |-> IF omitted /\ n=TrustA THEN 0 ELSE 1],
    ever |-> [n \in 1..2 |-> IF omitted /\ n=TrustA THEN 0 ELSE 1],
    lastRead |-> [n \in 1..2 |-> IF omitted /\ n=TrustA THEN "None" ELSE "OK"],
    missingSeen |-> [n \in 1..2 |-> FALSE],missingAt |-> [n \in 1..2 |-> 0],
    haltHistory |-> [n \in 1..2 |-> ~(omitted /\ n=TrustA)],faults |-> TrustNoFaults,
    event |-> [kind |-> "StartupMismatch",node |-> TrustB]]
TrustComplete ==
 /\ ~TrustOmitted /\ trustIndex=42 /\ Len(trustReceipts)=41
 /\ TrustRawAudit /\ TrustSelectiveRevokeAudit /\ TrustMilestoneAudit
 /\ \A i \in 1..41 : trustReceipts[i].enabled=(i \notin TrustNormalRefusals)
                          /\ trustReceipts[i].executed=(i \notin TrustNormalRefusals)
 /\ TrustRaw=TrustFinalRaw(FALSE)
TrustPartialComplete ==
 /\ TrustOmitted /\ trustIndex=42 /\ Len(trustReceipts)=41
 /\ TrustRawAudit /\ TrustSelectiveRevokeAudit /\ TrustMilestoneAudit
 /\ trustReceipts[21].enabled /\ ~trustReceipts[21].executed
 /\ \A i \in {24,25,26,27,32,33,34,37} : trustReceipts[i].executed
 /\ ~trustReceipts[36].enabled /\ TrustRaw=TrustFinalRaw(TRUE)
TrustTerminalAudit == trustIndex=42 => IF TrustOmitted THEN TrustPartialComplete ELSE TrustComplete
TrustCompleteNotReached == ~TrustComplete
TrustPartialNotReached == ~TrustPartialComplete
=============================================================================
