---------------------- MODULE EtnaSignerAsyncProduct ----------------------
EXTENDS EtnaSignerCrash
CONSTANT Witness
ASSUME /\ MaxSlot=2 /\ Payloads={"A","B","Nil"} /\ SignatureSalts={0,1}
       /\ PersistBeforeExpose /\ PreserveHRSOnCrash /\ PreserveGenerationFence
       /\ ReconnectAfterTrust /\ RejectConflicts /\ EchoRequest
       /\ Witness \in {"None","Retry","ValueConflict","NilConflict",
                         "ComputedRecovery","PersistedRecovery","Uncertain"}

\* Literal independent records; never use inherited Record for expected bytes.
LEmpty(d) == [domain |-> d,slot |-> 0,payload |-> "None",signature |-> <<>>]
LBytes(d,s,p,z) == [domain |-> d,slot |-> s,payload |-> p,signature |-> <<d,s,p,z>>]
LRequestEmpty == [domain |-> 0,slot |-> 0,payload |-> "None"]
LNoFault == [durability |-> FALSE,uncertain |-> FALSE,trust |-> FALSE,
             oldDomain |-> FALSE,request |-> FALSE]
\* Every operational variable is included, so equality also checks the frame.
LState == [running |-> running,trusted |-> trusted,connected |-> connected,
 certain |-> certain,activeDomain |-> activeDomain,knownFloor |-> knownFloor,
 durableFloor |-> durableFloor,everFloor |-> everFloor,durable |-> durable,
 phase |-> phase,pending |-> pending,reuse |-> reuse,restarted |-> restarted,
 actualRequest |-> actualRequest,crashRecord |-> crashRecord,writes |-> writes,
 returned |-> returned,network |-> network,delivered |-> delivered,
 faults |-> faults,event |-> event]
LInitial == [running |-> TRUE,trusted |-> FALSE,connected |-> FALSE,
 certain |-> TRUE,activeDomain |-> 0,knownFloor |-> 0,durableFloor |-> 0,
 everFloor |-> 0,durable |-> [d \in 0..1 |-> LEmpty(d)],phase |-> "Idle",
 pending |-> LEmpty(0),reuse |-> FALSE,restarted |-> FALSE,
 actualRequest |-> LRequestEmpty,crashRecord |-> LEmpty(0),writes |-> {},
 returned |-> {},network |-> {},delivered |-> {},faults |-> LNoFault,event |-> "None"]
Offers == ({0} \X (1..2) \X {"A","B","Nil"} \X {0,1} \X BOOLEAN)
          \cup ({1} \X {1} \X {"A"} \X {0} \X BOOLEAN)
LRequest(d,s,p,z,reply) == running /\ certain /\ trusted /\ connected
 /\ reply /\ phase="Idle" /\ d=activeDomain /\ d>=knownFloor
 /\ (s>durable[d].slot \/ (s=durable[d].slot /\ p=durable[d].payload))
LExpose(reply) == running /\ certain /\ trusted /\ connected /\ reply
 /\ phase="Persisted" /\ pending.domain=activeDomain /\ pending.domain>=knownFloor
LTrust(d) == running /\ certain /\ phase="Idle" /\ d>=knownFloor
 /\ (d=0 \/ knownFloor=1)
LAllRefused == /\ \A o \in Offers:~(ENABLED Request(o[1],o[2],o[3],o[4],o[5]))
               /\ \A reply \in BOOLEAN:~(ENABLED Expose(reply))
AsyncRequestEnabled == \A o \in Offers:
 (ENABLED Request(o[1],o[2],o[3],o[4],o[5]))=LRequest(o[1],o[2],o[3],o[4],o[5])
AsyncOtherEnabled ==
 /\ (\A reply \in BOOLEAN:(ENABLED Expose(reply))=LExpose(reply))
 /\ (\A d \in 0..1:(ENABLED AuthenticateTrust(d))=LTrust(d))
 /\ (ENABLED Connect)=(running /\ phase="Idle" /\ trusted)
 /\ (ENABLED Persist)=(running /\ certain /\ phase="Computed")
 /\ (ENABLED AuthenticateRecovery)=(running /\ certain)
 /\ (ENABLED Crash)=running /\ (ENABLED Restart)=~running
 /\ (ENABLED MarkUncertain)=(running /\ certain)
 /\ (\A q \in AllRecords:(ENABLED Deliver(q))=(q \in network))

VARIABLES asyncInitOK,asyncEffects,asyncReuseOK,asyncFault,
          witnessPhase,witnessRecord,witnessCall
AsyncLocal == <<asyncInitOK,asyncEffects,asyncReuseOK,asyncFault,
                witnessPhase,witnessRecord,witnessCall>>
AsyncVars == <<vars,AsyncLocal>>
AsyncInit == /\ Init /\ asyncInitOK=(LState=LInitial)
 /\ asyncEffects=TRUE /\ asyncReuseOK=TRUE /\ asyncFault= <<>>
 /\ witnessPhase=0 /\ witnessRecord=LEmpty(0) /\ witnessCall= <<>>
AsyncInitExact == asyncInitOK
AsyncExactReuse == asyncReuseOK
AsyncActionEffects == asyncEffects /\ asyncFault= <<>>
OldQueued == LBytes(0,1,"Nil",0)

\* One sparse milestone automaton is selected per witness; safety adds no history.
Observe(kind,args) ==
 LET recoveryWitness == Witness \in {"ComputedRecovery","PersistedRecovery"}
     targetPhase == IF Witness="ComputedRecovery" THEN "Computed" ELSE "Persisted"
     next == CASE
       Witness="Retry" -> (CASE
         witnessPhase=0 /\ kind="Crash" /\ phase="Persisted"
           /\ pending=OldQueued /\ pending \notin returned -> 1
      [] witnessPhase=1 /\ kind="Restart" -> 2
      [] witnessPhase=2 /\ kind="Request" /\ args= <<0,1,"Nil",1,TRUE>>
           /\ durable[0]=OldQueued /\ crashRecord=OldQueued -> 3
      [] witnessPhase=3 /\ kind="Expose" /\ pending=OldQueued -> 4
      [] witnessPhase=4 /\ kind="Request" /\ args= <<0,1,"Nil",1,TRUE>> -> 5
      [] witnessPhase=5 /\ kind="Expose" /\ pending=OldQueued
           /\ pending \in returned /\ pending \in network
           /\ returned'=returned /\ network'=network -> 6
      [] witnessPhase=6 /\ kind="Deliver" /\ args= <<OldQueued>>
           /\ OldQueued \notin delivered -> 7
      [] witnessPhase=7 /\ kind="Deliver" /\ args= <<OldQueued>>
           /\ OldQueued \in delivered /\ delivered'=delivered -> 8
      [] OTHER -> witnessPhase)
    [] recoveryWitness -> (CASE
         witnessPhase=0 /\ kind="Recovery" /\ phase=targetPhase
           /\ pending=LBytes(0,2,"B",0) /\ pending \notin returned
           /\ OldQueued \in network /\ OldQueued \notin delivered
           /\ (IF targetPhase="Computed" THEN durable[0]=OldQueued
                /\ pending \notin writes ELSE durable[0]=pending) -> 1
      [] witnessPhase=1 /\ kind="Crash" /\ everFloor=1 -> 2
      [] witnessPhase=2 /\ kind="Restart" /\ knownFloor'=1 -> 3
      [] witnessPhase=3 /\ kind="Expose" /\ pending=LBytes(1,1,"A",0)
           /\ knownFloor=1 /\ trusted /\ connected -> 4
      [] witnessPhase=4 /\ kind="Deliver" /\ args= <<witnessRecord>>
           /\ witnessRecord \in network /\ witnessRecord \notin delivered
           /\ LBytes(1,1,"A",0) \in returned -> 5
      [] OTHER -> witnessPhase)
    [] Witness="Uncertain" -> (CASE
         witnessPhase=0 /\ kind="Uncertain" /\ certain -> 1
      [] witnessPhase=1 /\ kind="Crash" /\ ~certain /\ LAllRefused -> 2
      [] witnessPhase=2 /\ kind="Restart" /\ ~certain' -> 3
      [] OTHER -> witnessPhase)
    [] OTHER -> witnessPhase
 IN /\ witnessPhase'=next
    /\ witnessRecord'=IF recoveryWitness /\ witnessPhase=0 /\ next=1
                          THEN OldQueued ELSE witnessRecord
    /\ witnessCall'=IF next=witnessPhase THEN witnessCall ELSE <<kind,args>>

\* The audit is evaluated after a real action. It never selects or gates a call.
\* Failure-only capture preserves incoming salt/reply and complete PRE state.
Audit(ok,reuseOK,kind,args) ==
 /\ asyncEffects'=(asyncEffects /\ ok)
 /\ asyncReuseOK'=(asyncReuseOK /\ reuseOK)
 /\ asyncFault'=IF asyncFault# <<>> \/ (ok /\ reuseOK) THEN asyncFault
                 ELSE <<kind,args,LState>>
 /\ UNCHANGED asyncInitOK
 /\ Observe(kind,args)
ARequest(d,s,p,z,reply) ==
 /\ Request(d,s,p,z,reply)
 /\ LET same == s=durable[d].slot /\ p=durable[d].payload
        bytes == IF same THEN durable[d] ELSE LBytes(d,s,p,z)
    IN Audit(LState'=[LState EXCEPT !.reuse=same,
         !.actualRequest=[domain |-> d,slot |-> s,payload |-> p],!.pending=bytes,
         !.phase=IF same THEN "Persisted" ELSE "Computed",
         !.event=IF same THEN "RetryRecorded" ELSE "Computed"],
       ~same \/ (pending'=durable[d] /\ reuse' /\ phase'="Persisted"),
       "Request",<<d,s,p,z,reply>>)
APersist == /\ Persist
 /\ Audit(LState'=[LState EXCEPT !.durable[pending.domain]=pending,
      !.writes=writes \cup {pending},!.phase="Persisted",!.event="Persisted"],
      TRUE,"Persist",<<>>)
AExpose(reply) == /\ Expose(reply)
 /\ Audit(pending=durable[pending.domain] /\ pending.domain>=everFloor
      /\ pending.domain=actualRequest.domain /\ pending.slot=actualRequest.slot
      /\ pending.payload=actualRequest.payload
      /\ LState'=[LState EXCEPT !.returned=returned \cup {pending},
        !.network=network \cup {pending},!.phase="Idle",
        !.event=IF reuse /\ restarted /\ pending=crashRecord /\ crashRecord.slot>0
                 THEN "ReplayAfterRestart" ELSE "Expose"],TRUE,"Expose",<<reply>>)
ADeliver(q) == /\ Deliver(q)
 /\ Audit(LState'=[LState EXCEPT !.delivered=delivered \cup {q},!.event="Delivered"],
          TRUE,"Deliver",<<q>>)
ATrust(d) == /\ AuthenticateTrust(d)
 /\ Audit(LState'=[LState EXCEPT !.activeDomain=d,!.trusted=TRUE,!.event="Trust"],
          TRUE,"Trust",<<d>>)
AConnect == /\ Connect
 /\ Audit(LState'=[LState EXCEPT !.connected=TRUE,!.event="Connect"],TRUE,"Connect",<<>>)
ARecovery == /\ everFloor=0 /\ AuthenticateRecovery
 /\ Audit(LState'=[LState EXCEPT !.knownFloor=1,!.everFloor=1,!.durableFloor=1,
      !.trusted=FALSE,!.connected=FALSE,!.phase="Idle",!.pending=LEmpty(0),
      !.reuse=FALSE,!.actualRequest=LRequestEmpty,!.event="RecoveryAuth"],TRUE,"Recovery",<<>>)
ACrash == /\ Crash
 /\ Audit(LState'=[LState EXCEPT !.running=FALSE,!.trusted=FALSE,!.connected=FALSE,
      !.phase="Idle",!.pending=LEmpty(0),!.reuse=FALSE,!.knownFloor=0,
      !.actualRequest=LRequestEmpty,
      !.crashRecord=IF phase="Persisted" THEN durable[pending.domain] ELSE LEmpty(0),
      !.event=IF phase="Computed" THEN "BeforeWriteCrash"
          ELSE IF phase="Persisted" /\ pending \notin returned THEN "AfterWriteCrash"
          ELSE "Crash"],TRUE,"Crash",<<>>)
ARestart == /\ Restart
 /\ Audit(LState'=[LState EXCEPT !.running=TRUE,!.trusted=FALSE,!.connected=FALSE,
      !.knownFloor=durableFloor,!.restarted=TRUE,!.event="Restart"],TRUE,"Restart",<<>>)
AUncertain == /\ MarkUncertain
 /\ Audit(LState'=[LState EXCEPT !.certain=FALSE,!.trusted=FALSE,!.connected=FALSE,
      !.phase="Idle",!.pending=LEmpty(0),!.reuse=FALSE,
      !.actualRequest=LRequestEmpty,!.event="Uncertain"],TRUE,"Uncertain",<<>>)

\* Full26 actual Request offers, BOTH Expose replies, all queued deliveries,
\* both trusts and all actual lifecycle actions. No expected oracle schedules.
AsyncNext ==
 (\E o \in Offers:ARequest(o[1],o[2],o[3],o[4],o[5]))
 \/ (\E reply \in BOOLEAN:AExpose(reply)) \/ (\E q \in network:ADeliver(q))
 \/ (\E d \in 0..1:ATrust(d)) \/ AConnect \/ APersist \/ ARecovery
 \/ ACrash \/ ARestart \/ AUncertain
AsyncSpec == AsyncInit /\ [][AsyncNext]_AsyncVars

RankPrestate(p) == running /\ certain /\ trusted /\ connected /\ phase="Idle"
 /\ activeDomain=0 /\ knownFloor=0 /\ durable[0]=LBytes(0,2,p,0)
 /\ (\A v \in {"A","B","Nil"},z \in {0,1},reply \in BOOLEAN:
       ~(ENABLED Request(0,1,v,z,reply)))
 /\ (\A z \in {0,1}:ENABLED Request(0,2,p,z,TRUE))
 /\ (IF p="Nil" THEN ~(ENABLED Request(0,2,"A",1,TRUE))
                    ELSE ~(ENABLED Request(0,2,"Nil",1,TRUE)))
AsyncRetryNotReached == witnessPhase<8
AsyncValueConflictNotReached == ~RankPrestate("A")
AsyncNilConflictNotReached == ~RankPrestate("Nil")
AsyncComputedRecoveryNotReached == witnessPhase<5
AsyncPersistedRecoveryNotReached == witnessPhase<5
AsyncUncertainNotReached == ~(witnessPhase=3 /\ running /\ ~certain /\ LAllRefused)
=============================================================================
