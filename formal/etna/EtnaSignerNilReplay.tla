--------------------- MODULE EtnaSignerNilReplay ---------------------
EXTENDS EtnaSignerCrash, Sequences
CONSTANTS NilProfiles, SuppressAction
NilProfileSet == {<<c,s,t>> : c \in {"Computed","Written"}, s \in 0..1,
                             t \in {"Early","Late"}}
NilComputed0EarlyProfiles == {<<"Computed",0,"Early">>}
NilComputed0LateProfiles == {<<"Computed",0,"Late">>}
NilComputed1EarlyProfiles == {<<"Computed",1,"Early">>}
NilComputed1LateProfiles == {<<"Computed",1,"Late">>}
NilWritten0EarlyProfiles == {<<"Written",0,"Early">>}
NilWritten0LateProfiles == {<<"Written",0,"Late">>}
NilWritten1EarlyProfiles == {<<"Written",1,"Early">>}
NilWritten1LateProfiles == {<<"Written",1,"Late">>}
ASSUME /\ NilProfiles # {} /\ NilProfiles \subseteq NilProfileSet
       /\ SuppressAction \in {"None","DeliverOld"}
       /\ MaxSlot=2 /\ Payloads={"A","B","Nil"} /\ SignatureSalts={0,1}
       /\ PersistBeforeExpose /\ PreserveHRSOnCrash /\ PreserveGenerationFence
       /\ ReconnectAfterTrust /\ RejectConflicts /\ EchoRequest
VARIABLES nilProfile, nilIndex, nilReceipts, nilSavedOld, nilSavedFresh
NilLocal == <<nilProfile,nilIndex,nilReceipts,nilSavedOld,nilSavedFresh>>
NilAllVars == <<vars,NilLocal>>
NilWritten == nilProfile[1]="Written"
NilFirstSalt == nilProfile[2]
NilRetrySalt == 1-NilFirstSalt
NilEarly == nilProfile[3]="Early"
NilCalls == <<"Trust0","Connect0","RequestNil">>
    \o (IF NilWritten THEN <<"PersistFirst">> ELSE <<>>)
    \o <<"CrashFirst","RestartFirst","ConnectUntrusted","TrustAgain","ConnectAgain",
         "RetryNil","PersistRetry","ExposeNil","ConflictA","RequestB","PersistB","ExposeB">>
    \o (IF NilEarly THEN <<"DeliverOld">> ELSE <<>>)
    \o <<"Recover","CrashSecond","RestartSecond","TrustFresh","ConnectFresh",
         "RequestA","PersistA","ExposeA">>
    \o (IF NilEarly THEN <<>> ELSE <<"DeliverOld">>) \o <<"DeliverFresh">>
\* Independent typed literal records. Never use the original Record getter.
NilEmpty0 == [domain |-> 0,slot |-> 0,payload |-> "None",signature |-> <<>>]
NilEmpty1 == [domain |-> 1,slot |-> 0,payload |-> "None",signature |-> <<>>]
NilFirst == [domain |-> 0,slot |-> 1,payload |-> "Nil",
             signature |-> <<0,1,"Nil",NilFirstSalt>>]
NilReturned == [domain |-> 0,slot |-> 1,payload |-> "Nil",
    signature |-> <<0,1,"Nil",IF NilWritten THEN NilFirstSalt ELSE NilRetrySalt>>]
NilOldB == [domain |-> 0,slot |-> 2,payload |-> "B",
            signature |-> <<0,2,"B",NilRetrySalt>>]
NilFreshA == [domain |-> 1,slot |-> 1,payload |-> "A",signature |-> <<1,1,"A",0>>]
NilNoRequest == [domain |-> 0,slot |-> 0,payload |-> "None"]
NilRequestNil == [domain |-> 0,slot |-> 1,payload |-> "Nil"]
NilRequestB == [domain |-> 0,slot |-> 2,payload |-> "B"]
NilRequestA == [domain |-> 1,slot |-> 1,payload |-> "A"]
NilNoFaults == [durability |-> FALSE,uncertain |-> FALSE,trust |-> FALSE,
               oldDomain |-> FALSE,request |-> FALSE]
\* Every original variable is recorded before and after every attempted action.
NilRaw == [running |-> running,trusted |-> trusted,connected |-> connected,
    certain |-> certain,activeDomain |-> activeDomain,knownFloor |-> knownFloor,
    durableFloor |-> durableFloor,everFloor |-> everFloor,durable |-> durable,
    phase |-> phase,pending |-> pending,reuse |-> reuse,restarted |-> restarted,
    actualRequest |-> actualRequest,crashRecord |-> crashRecord,writes |-> writes,
    returned |-> returned,network |-> network,delivered |-> delivered,
    faults |-> faults,event |-> event]
NilCall(name) == CASE
    name \in {"Trust0","TrustAgain"} -> AuthenticateTrust(0)
 [] name="TrustFresh" -> AuthenticateTrust(1)
 [] name \in {"Connect0","ConnectUntrusted","ConnectAgain","ConnectFresh"} -> Connect
 [] name="RequestNil" -> Request(0,1,"Nil",NilFirstSalt,TRUE)
 [] name="RetryNil" -> Request(0,1,"Nil",NilRetrySalt,TRUE)
 [] name="ConflictA" -> Request(0,1,"A",NilRetrySalt,TRUE)
 [] name="RequestB" -> Request(0,2,"B",NilRetrySalt,TRUE)
 [] name="RequestA" -> Request(1,1,"A",0,TRUE)
 [] name \in {"PersistFirst","PersistRetry","PersistB","PersistA"} -> Persist
 [] name \in {"ExposeNil","ExposeB","ExposeA"} -> Expose(TRUE)
 [] name \in {"CrashFirst","CrashSecond"} -> Crash
 [] name \in {"RestartFirst","RestartSecond"} -> Restart
 [] name="Recover" -> AuthenticateRecovery
 [] name="DeliverOld" -> Deliver(nilSavedOld)
 [] name="DeliverFresh" -> Deliver(nilSavedFresh)
NilInit == /\ Init /\ nilProfile \in NilProfiles /\ nilIndex=1 /\ nilReceipts= <<>>
           /\ nilSavedOld=NilEmpty0 /\ nilSavedFresh=NilEmpty1
NilStep ==
 /\ nilIndex<=Len(NilCalls) /\ UNCHANGED nilProfile
 /\ LET name==NilCalls[nilIndex] enabled==ENABLED NilCall(name)
        executed==enabled /\ name#SuppressAction
    IN /\ IF executed THEN NilCall(name) ELSE UNCHANGED vars
       /\ nilSavedOld'=IF executed /\ name="ExposeNil" THEN pending ELSE nilSavedOld
       /\ nilSavedFresh'=IF executed /\ name="ExposeA" THEN pending ELSE nilSavedFresh
       /\ nilReceipts'=Append(nilReceipts,[call |-> name,enabled |-> enabled,
            executed |-> executed,before |-> NilRaw,after |-> NilRaw'])
 /\ nilIndex'=nilIndex+1
NilReplaySpec == NilInit /\ [][NilStep]_NilAllVars

NilInitialRaw == [running |-> TRUE,trusted |-> FALSE,connected |-> FALSE,
    certain |-> TRUE,activeDomain |-> 0,knownFloor |-> 0,durableFloor |-> 0,
    everFloor |-> 0,durable |-> [d \in 0..1 |-> IF d=0 THEN NilEmpty0 ELSE NilEmpty1],
    phase |-> "Idle",pending |-> NilEmpty0,reuse |-> FALSE,restarted |-> FALSE,
    actualRequest |-> NilNoRequest,crashRecord |-> NilEmpty0,writes |-> {},
    returned |-> {},network |-> {},delivered |-> {},faults |-> NilNoFaults,event |-> "None"]
NilRefused == {"ConnectUntrusted","ConflictA"} \cup
    (IF NilWritten THEN {"PersistRetry"} ELSE {})
NilExpectedEnabled(name) == name \notin NilRefused
\* Entire independent record frames: each EXCEPT leaves all other raw fields fixed.
\* These expected writes inspect neither original helpers nor original audit bits.
NilExpectedAfter(r,name) ==
 IF ~NilExpectedEnabled(name) \/ name=SuppressAction THEN r ELSE CASE
    name \in {"Trust0","TrustAgain","TrustFresh"} -> [r EXCEPT
        !.activeDomain=IF name="TrustFresh" THEN 1 ELSE 0,!.trusted=TRUE,!.event="Trust"]
 [] name \in {"Connect0","ConnectAgain","ConnectFresh"} ->
        [r EXCEPT !.connected=TRUE,!.event="Connect"]
 [] name="RequestNil" -> [r EXCEPT !.pending=NilFirst,!.reuse=FALSE,
        !.actualRequest=NilRequestNil,!.phase="Computed",!.event="Computed"]
 [] name="RetryNil" -> [r EXCEPT !.pending=NilReturned,!.reuse=NilWritten,
        !.actualRequest=NilRequestNil,!.phase=IF NilWritten THEN "Persisted" ELSE "Computed",
        !.event=IF NilWritten THEN "RetryRecorded" ELSE "Computed"]
 [] name="RequestB" -> [r EXCEPT !.pending=NilOldB,!.reuse=FALSE,
        !.actualRequest=NilRequestB,!.phase="Computed",!.event="Computed"]
 [] name="RequestA" -> [r EXCEPT !.pending=NilFreshA,!.reuse=FALSE,
        !.actualRequest=NilRequestA,!.phase="Computed",!.event="Computed"]
 [] name="PersistFirst" -> [r EXCEPT !.durable[0]=NilFirst,!.writes={NilFirst},
        !.phase="Persisted",!.event="Persisted"]
 [] name="PersistRetry" -> [r EXCEPT !.durable[0]=NilReturned,!.writes={NilReturned},
        !.phase="Persisted",!.event="Persisted"]
 [] name="PersistB" -> [r EXCEPT !.durable[0]=NilOldB,!.writes={NilReturned,NilOldB},
        !.phase="Persisted",!.event="Persisted"]
 [] name="PersistA" -> [r EXCEPT !.durable[1]=NilFreshA,
        !.writes={NilReturned,NilOldB,NilFreshA},!.phase="Persisted",!.event="Persisted"]
 [] name="ExposeNil" -> [r EXCEPT !.returned={NilReturned},!.network={NilReturned},
        !.phase="Idle",!.event=IF NilWritten THEN "ReplayAfterRestart" ELSE "Expose"]
 [] name="ExposeB" -> [r EXCEPT !.returned={NilReturned,NilOldB},
        !.network={NilReturned,NilOldB},!.phase="Idle",!.event="Expose"]
 [] name="ExposeA" -> [r EXCEPT !.returned={NilReturned,NilOldB,NilFreshA},
        !.network={NilReturned,NilOldB,NilFreshA},!.phase="Idle",!.event="Expose"]
 [] name="CrashFirst" -> [r EXCEPT !.running=FALSE,!.trusted=FALSE,!.connected=FALSE,
        !.phase="Idle",!.pending=NilEmpty0,!.reuse=FALSE,!.knownFloor=0,
        !.actualRequest=NilNoRequest,!.crashRecord=IF NilWritten THEN NilFirst ELSE NilEmpty0,
        !.event=IF NilWritten THEN "AfterWriteCrash" ELSE "BeforeWriteCrash"]
 [] name="CrashSecond" -> [r EXCEPT !.running=FALSE,!.trusted=FALSE,!.connected=FALSE,
        !.phase="Idle",!.pending=NilEmpty0,!.reuse=FALSE,!.knownFloor=0,
        !.actualRequest=NilNoRequest,!.crashRecord=NilEmpty0,!.event="Crash"]
 [] name="RestartFirst" -> [r EXCEPT !.running=TRUE,!.trusted=FALSE,!.connected=FALSE,
        !.knownFloor=0,!.restarted=TRUE,!.event="Restart"]
 [] name="RestartSecond" -> [r EXCEPT !.running=TRUE,!.trusted=FALSE,!.connected=FALSE,
        !.knownFloor=1,!.restarted=TRUE,!.event="Restart"]
 [] name="Recover" -> [r EXCEPT !.knownFloor=1,!.everFloor=1,!.durableFloor=1,
        !.trusted=FALSE,!.connected=FALSE,!.phase="Idle",!.pending=NilEmpty0,
        !.reuse=FALSE,!.actualRequest=NilNoRequest,!.event="RecoveryAuth"]
 [] name="DeliverOld" -> [r EXCEPT !.delivered={NilReturned},!.event="Delivered"]
 [] name="DeliverFresh" -> [r EXCEPT !.delivered=
        IF SuppressAction="DeliverOld" THEN {NilFreshA} ELSE {NilReturned,NilFreshA},
        !.event="Delivered"]
NilAt(name) == {nilReceipts[i] : i \in {k \in 1..Len(nilReceipts) : nilReceipts[k].call=name}}
NilRawAudit ==
 /\ nilIndex=Len(nilReceipts)+1 /\ nilIndex \in 1..(Len(NilCalls)+1)
 /\ nilIndex=1 => NilRaw=NilInitialRaw
 /\ \A i \in 1..Len(nilReceipts) : LET q==nilReceipts[i] IN
       /\ q.call=NilCalls[i]
       /\ q.before=IF i=1 THEN NilInitialRaw ELSE nilReceipts[i-1].after
       /\ q.enabled=NilExpectedEnabled(q.call)
       /\ q.executed=(q.enabled /\ q.call#SuppressAction)
       /\ q.after=NilExpectedAfter(q.before,q.call)
 /\ nilIndex>1 => NilRaw=nilReceipts[nilIndex-1].after
 /\ nilSavedOld=(IF NilAt("ExposeNil")={} THEN NilEmpty0 ELSE NilReturned)
 /\ nilSavedFresh=(IF NilAt("ExposeA")={} THEN NilEmpty1 ELSE NilFreshA)
\* Dedicated FIRST-change audit for the unique actual Request reuse-byte fault.
\* Fault configs select this alone, so inherited ReplayUsesRecordedSignature and
\* generic raw audits cannot intercept the intended immediate RetryNil failure.
NilRetryByteAudit == \A q \in NilAt("RetryNil") :
 /\ q.enabled /\ q.executed /\ q.before.phase="Idle"
 /\ q.before.durable[0]=(IF NilWritten THEN NilFirst ELSE NilEmpty0)
 /\ q.after.pending=NilReturned
 /\ q.after.phase=(IF NilWritten THEN "Persisted" ELSE "Computed")
 /\ q.after.reuse=NilWritten /\ q.after.durable=q.before.durable
 /\ q.after.writes=q.before.writes /\ q.after.returned={} /\ q.after.network={}
NilMilestoneAudit ==
 /\ \A q \in NilAt("CrashFirst") : q.executed /\ q.before.pending=NilFirst
       /\ q.before.phase=(IF NilWritten THEN "Persisted" ELSE "Computed")
       /\ q.after.crashRecord=(IF NilWritten THEN NilFirst ELSE NilEmpty0)
 /\ \A q \in NilAt("ConnectUntrusted") : ~q.enabled /\ ~q.executed
       /\ q.before.running /\ ~q.before.trusted /\ q.before.phase="Idle"
 /\ \A q \in NilAt("PersistRetry") : q.enabled=~NilWritten /\ q.executed=~NilWritten
       /\ q.after.durable[0]=NilReturned /\ q.after.phase="Persisted"
 /\ \A q \in NilAt("ConflictA") : ~q.enabled /\ ~q.executed
       /\ q.before.phase="Idle" /\ q.before.running /\ q.before.certain
       /\ q.before.trusted /\ q.before.connected /\ q.before.activeDomain=0
       /\ q.before.knownFloor=0 /\ q.before.durable[0]=NilReturned
 /\ \A q \in NilAt("ExposeB") : q.executed /\ q.after.durable[0]=NilOldB
       /\ q.after.returned={NilReturned,NilOldB} /\ q.after.network=q.after.returned
 /\ \A q \in NilAt("CrashSecond") : q.executed /\ q.before.knownFloor=1
       /\ q.after.knownFloor=0 /\ q.after.durableFloor=1 /\ q.after.everFloor=1
 /\ \A q \in NilAt("RestartSecond") : q.executed /\ q.after.knownFloor=1
       /\ q.after.durableFloor=1 /\ q.after.everFloor=1 /\ ~q.after.trusted /\ ~q.after.connected
 /\ \A q \in NilAt("DeliverOld") : q.enabled
       /\ q.before.knownFloor=(IF NilEarly THEN 0 ELSE 1)
       /\ q.before.durableFloor=(IF NilEarly THEN 0 ELSE 1)
       /\ q.before.returned=(IF NilEarly THEN {NilReturned,NilOldB}
                                           ELSE {NilReturned,NilOldB,NilFreshA})
       /\ q.before.network=q.before.returned
       /\ q.after.returned=q.before.returned /\ q.after.network=q.before.network
NilFinalRaw(omitted) == [running |-> TRUE,trusted |-> TRUE,connected |-> TRUE,
    certain |-> TRUE,activeDomain |-> 1,knownFloor |-> 1,durableFloor |-> 1,everFloor |-> 1,
    durable |-> [d \in 0..1 |-> IF d=0 THEN NilOldB ELSE NilFreshA],phase |-> "Idle",
    pending |-> NilFreshA,reuse |-> FALSE,restarted |-> TRUE,actualRequest |-> NilRequestA,
    crashRecord |-> NilEmpty0,writes |-> {NilReturned,NilOldB,NilFreshA},
    returned |-> {NilReturned,NilOldB,NilFreshA},network |-> {NilReturned,NilOldB,NilFreshA},
    delivered |-> IF omitted THEN {NilFreshA} ELSE {NilReturned,NilFreshA},
    faults |-> NilNoFaults,event |-> "Delivered"]
NilComplete ==
 /\ SuppressAction="None" /\ nilIndex=Len(NilCalls)+1
 /\ Len(nilReceipts)=(IF NilWritten THEN 26 ELSE 25)
 /\ NilRawAudit /\ NilRetryByteAudit /\ NilMilestoneAudit
 /\ \A i \in 1..Len(NilCalls) : nilReceipts[i].executed=NilExpectedEnabled(NilCalls[i])
 /\ NilRaw=NilFinalRaw(FALSE)
NilPartialComplete ==
 /\ SuppressAction="DeliverOld" /\ nilIndex=Len(NilCalls)+1
 /\ Len(nilReceipts)=(IF NilWritten THEN 26 ELSE 25)
 /\ NilRawAudit /\ NilRetryByteAudit /\ NilMilestoneAudit
 /\ \A q \in NilAt("DeliverOld") : q.enabled /\ ~q.executed /\ q.after=q.before
 /\ NilRaw=NilFinalRaw(TRUE)
NilTerminalAudit == nilIndex=Len(NilCalls)+1 =>
    IF SuppressAction="DeliverOld" THEN NilPartialComplete ELSE NilComplete
NilCompleteNotReached == ~NilComplete
NilPartialNotReached == ~NilPartialComplete
=============================================================================
