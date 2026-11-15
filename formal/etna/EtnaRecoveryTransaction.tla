------------------------ MODULE EtnaRecoveryTransaction ------------------------
EXTENDS EtnaSettlement, Sequences, FiniteSets
CONSTANTS BondProfile, RequestKinds, FailureModes, CallbackModes,
          CheckIdOrder, CheckIssued, CheckKeys, CheckFIOrder, CheckFIRange,
          AbortAtomic, PreserveSnapshot, RejectReentry, CorrectOrigin
IDs == 0..2
FIIndices == 0..2
Slots == IF BondProfile="Held" THEN {0,1} ELSE {0}
Block(t) == 100+t
Timestamp(t) == 1000+t
Never == 10000
DefaultBond == [issued |-> FALSE,withdrawn |-> FALSE,key |-> "DefaultKey",owner |-> 0,
               eff |-> 0,pending |-> 0,ready |-> 0,exit |-> 0,confirmed |-> 0,
               holds |-> FALSE,slot |-> 0]
Origin(p,b,t) == [present |-> TRUE,start |-> p,block |-> b,timestamp |-> t]
NoOrigin == [present |-> FALSE,start |-> 0,block |-> 0,timestamp |-> 0]
VARIABLES storage, tx, observed, setup
newVars == <<storage,tx,observed,setup>>
allVars == <<vars,newVars>>
Canonical == [checkpoint |-> c,generation |-> generation,nonce |-> recoveryNonce,
              start |-> startHeight,landings |-> landings,state |-> storage]
CanonicalAfter == [checkpoint |-> c',generation |-> generation',nonce |-> recoveryNonce',
                   start |-> startHeight',landings |-> landings',state |-> storage']

ASSUME BondProfile \in {"Held","Displaced","Withdrawn"}
       /\ FailureModes \subseteq {"None","SecondRegistry"}
       /\ CallbackModes \subseteq {"None","Registry"}
       /\ RequestKinds \subseteq {"Mixed","Empty","Unheld","DuplicateIds","LateWrongKey",
                                  "LateUnissued","FutureFI","ConsumedFI","DuplicateFI"}
       /\ MaxHeight=2 /\ MaxGeneration=1 /\ MaxNonce=2 /\ MaxTime=1
E(id,key) == [bondId |-> id,entryKey |-> key]
Exclusions(kind) == CASE kind="Empty" -> <<>>
 [] kind="Unheld" -> <<E(0,"K0")>>
 [] kind="DuplicateIds" -> <<E(0,"K0"),E(0,"K0")>>
 [] kind="LateWrongKey" -> <<E(0,"K0"),E(1,"K0")>>
 [] kind="LateUnissued" -> <<E(0,"K0"),E(2,"DefaultKey")>>
 [] OTHER -> <<E(0,"K0"),E(1,"K1")>>
FIList(kind) == CASE kind \in {"Empty","Unheld"} -> <<>>
 [] kind="FutureFI" -> <<1,2>> [] kind="ConsumedFI" -> <<0>>
 [] kind="DuplicateFI" -> <<1,1>> [] OTHER -> <<1>>
EmptyRequest == [kind |-> "Empty",expectedGeneration |-> 0,expectedC |-> 0,
 expectedRecoveryNonce |-> 0,validUntil |-> Timestamp(0),exclusions |-> <<>>,fiToClear |-> <<>>,
 rules |-> 0,failure |-> "None",callback |-> "None"]
FixtureBond(i) == IF i=2 THEN DefaultBond ELSE
 [issued |-> TRUE,withdrawn |-> i=0 /\ BondProfile="Withdrawn",key |-> IF i=0 THEN "K0" ELSE "K1",
  owner |-> IF i=0 /\ BondProfile="Withdrawn" THEN 0 ELSE 1,
  eff |-> IF i=0 THEN CASE BondProfile="Held"->2 [] BondProfile="Displaced"->1 [] OTHER->0
          ELSE IF BondProfile="Held" THEN 3 ELSE 5,
  pending |-> IF i=0 /\ BondProfile#"Withdrawn" THEN 1 ELSE 0,
  ready |-> IF i=0 /\ BondProfile#"Withdrawn" THEN 97 ELSE 0,
  exit |-> IF i=0 /\ BondProfile#"Held" THEN 93 ELSE Never,
  confirmed |-> IF i=0 /\ BondProfile="Displaced" THEN 95 ELSE 0,
  holds |-> i=1 \/ BondProfile="Held",slot |-> IF BondProfile="Held" THEN i ELSE 0]
FixtureStorage == [bonds |-> [i \in IDs |-> FixtureBond(i)],
 slots |-> [s \in Slots |-> [occupied |-> TRUE,id |-> IF BondProfile="Held" THEN s ELSE 1]],
 registered |-> [k \in {"K0","K1","DefaultKey"} |-> k#"DefaultKey"],
 forfeited |-> [k \in {"K0","K1","DefaultKey"} |-> k="K0" /\ BondProfile#"Held"],
 tokenVault |-> CASE BondProfile="Held"->6 [] BondProfile="Displaced"->7 [] OTHER->5,
 head |-> 0,tail |-> 2,entries |-> [i \in FIIndices |->
    IF i=0 THEN [hash |-> "A",timestamp |-> 998,block |-> 98]
    ELSE IF i=1 THEN [hash |-> "B",timestamp |-> 999,block |-> 99]
    ELSE [hash |-> "Nil",timestamp |-> 0,block |-> 0]],
 fees |-> 3,activeSnapshot |-> 94,
 origins |-> [g \in 0..MaxGeneration |-> IF g=0 THEN Origin(0,97,997) ELSE NoOrigin],
 activeRules |-> 0,nextRules |-> 1,rulesTime |-> 1002,stopTime |-> 1001,stopGrid |-> 2]
EmptyCallback(w) == [present |-> FALSE,accepted |-> FALSE,before |-> w,after |-> w]
Receipt(req,pre,post,context,ok,reason,validated,applied,cb) ==
 [present |-> TRUE,request |-> req,before |-> pre,after |-> post,context |-> context,
 accepted |-> ok,reason |-> reason,validatedIds |-> validated,appliedIds |-> applied,callback |-> cb]
TransactionInit ==
 /\ Init /\ storage=FixtureStorage /\ setup=0
 /\ tx=[phase |-> "Idle",request |-> EmptyRequest,context |-> [block |-> Block(0),timestamp |-> Timestamp(0)],
        workspace |-> Canonical,index |-> 1,validated |-> 0,applied |-> 0,
        callbackDone |-> FALSE,callbackReceipt |-> EmptyCallback(Canonical),reason |-> "None"]
 /\ observed=[original |-> EmptyRequest,beginBefore |-> Canonical,
       execution |-> [block |-> Block(0),timestamp |-> Timestamp(0)],
       callback |-> EmptyCallback(Canonical),receipt |-> [present |-> FALSE]]
BaseLand(proof) ==
 /\ tx.phase="Idle" /\ Land(proof)
 /\ storage'=[storage EXCEPT !.head=proof.terminal,
           !.activeSnapshot=IF generation=0 THEN @ ELSE storage.origins[generation].block]
 /\ UNCHANGED <<tx,observed>>
FreshLand(h) == BaseLand([present |-> TRUE,generation |-> generation,parent |-> c,terminal |-> h])
BasePrepare(h) == tx.phase="Idle" /\ PrepareProof(h) /\ UNCHANGED <<storage,tx,observed>>
BaseAuthorize(d) == tx.phase="Idle" /\ Authorize(d) /\ UNCHANGED <<storage,tx,observed>>
BaseInvalidate == tx.phase="Idle" /\ InvalidateNonce /\ UNCHANGED <<storage,tx,observed>>
BaseTick == tx.phase="Idle" /\ Tick /\ UNCHANGED <<storage,tx,observed>>
Begin(kind,exclusions,fis,failure,callback) ==
 /\ tx.phase="Idle" /\ authorization.present
 \* External finite scope: do not export a protocol rejection at a model-only bound.
 /\ generation<MaxGeneration /\ recoveryNonce<MaxNonce
 /\ kind \in RequestKinds /\ failure \in FailureModes /\ callback \in CallbackModes
 /\ LET req==[kind |-> kind,expectedGeneration |-> authorization.generation,expectedC |-> authorization.checkpoint,
           expectedRecoveryNonce |-> authorization.nonce,validUntil |-> Timestamp(authorization.deadline),
           exclusions |-> exclusions,fiToClear |-> fis,rules |-> 0,failure |-> failure,callback |-> callback]
    IN /\ tx'=[tx EXCEPT !.phase="Entry",!.request=req,
           !.context=[block |-> Block(now),timestamp |-> Timestamp(now)],!.workspace=Canonical,
           !.index=1,!.validated=0,!.applied=0,!.callbackDone=FALSE,
           !.callbackReceipt=EmptyCallback(Canonical),!.reason="None"]
       /\ observed'=[observed EXCEPT !.original=[kind |-> kind,
             expectedGeneration |-> authorization.generation,expectedC |-> authorization.checkpoint,
             expectedRecoveryNonce |-> authorization.nonce,validUntil |-> 1000+authorization.deadline,
             exclusions |-> exclusions,fiToClear |-> fis,rules |-> 0,
             failure |-> failure,callback |-> callback],!.beginBefore=Canonical,
             !.execution=[block |-> 100+now,timestamp |-> 1000+now],!.callback=EmptyCallback(Canonical)]
 /\ UNCHANGED <<vars,storage>>
Entry ==
 /\ tx.phase="Entry"
 /\ tx'=[tx EXCEPT !.phase=IF ENABLED Recover THEN "ValidateIds" ELSE "Abort",
                  !.reason=IF ENABLED Recover THEN "None" ELSE "BaseRejected"]
 /\ UNCHANGED <<vars,storage,observed>>
ValidateIds ==
 /\ tx.phase="ValidateIds"
 /\ IF tx.index>Len(tx.request.exclusions)
       THEN tx'=[tx EXCEPT !.phase="ValidateFI",!.index=1]
       ELSE LET e==tx.request.exclusions[tx.index]
                ordered==tx.index=1 \/ tx.request.exclusions[tx.index-1].bondId<e.bondId
                valid==(~CheckIdOrder \/ ordered) /\ (~CheckIssued \/ storage.bonds[e.bondId].issued)
                       /\ (~CheckKeys \/ storage.bonds[e.bondId].key=e.entryKey)
            IN tx'=[tx EXCEPT !.phase=IF valid THEN @ ELSE "Abort",
                    !.reason=IF valid THEN @ ELSE "ExclusionRejected",!.index=IF valid THEN @+1 ELSE @,
                    !.validated=IF valid THEN @+1 ELSE @]
 /\ UNCHANGED <<vars,storage,observed>>
ValidateFI ==
 /\ tx.phase="ValidateFI"
 /\ IF tx.index>Len(tx.request.fiToClear)
       THEN tx'=[tx EXCEPT !.phase="ApplyIds",!.index=1]
       ELSE LET i==tx.request.fiToClear[tx.index]
                ordered==tx.index=1 \/ tx.request.fiToClear[tx.index-1]<i
                valid==(~CheckFIOrder \/ ordered) /\ (~CheckFIRange \/ (storage.head<=i /\ i<storage.tail))
            IN tx'=[tx EXCEPT !.phase=IF valid THEN @ ELSE "Abort",
                    !.reason=IF valid THEN @ ELSE "FIRejected",!.index=IF valid THEN @+1 ELSE @]
 /\ UNCHANGED <<vars,storage,observed>>
Callback ==
 /\ tx.phase="ApplyIds" /\ tx.index<=Len(tx.request.exclusions)
 /\ tx.request.callback="Registry" /\ ~tx.callbackDone
 /\ LET after==IF RejectReentry THEN tx.workspace
                ELSE [tx.workspace EXCEPT !.state.bonds[0].eff=@+1]
    IN /\ tx'=[tx EXCEPT !.workspace=after,!.callbackDone=TRUE,
             !.callbackReceipt=[present |-> TRUE,accepted |-> ~RejectReentry,before |-> tx.workspace,after |-> after]]
       /\ observed'=[observed EXCEPT !.callback=[present |-> TRUE,accepted |-> ~RejectReentry,
                    before |-> tx.workspace,after |-> tx'.workspace]]
 /\ UNCHANGED <<vars,storage>>
ApplyIds ==
 /\ tx.phase="ApplyIds"
 /\ (tx.callbackDone \/ tx.request.callback="None" \/ tx.index>Len(tx.request.exclusions))
 /\ IF tx.index>Len(tx.request.exclusions)
       THEN tx'=[tx EXCEPT !.phase="ApplyFI",!.index=1]
       ELSE IF tx.request.failure="SecondRegistry" /\ tx.index=2
         THEN tx'=[tx EXCEPT !.phase="Abort",!.reason="RegistryFailed"]
         ELSE LET id==tx.request.exclusions[tx.index].bondId
              IN tx'=[tx EXCEPT !.workspace.state.bonds[id].exit=
                       IF @<tx.context.block THEN @ ELSE tx.context.block,!.index=@+1,!.applied=@+1]
 /\ UNCHANGED <<vars,storage,observed>>
ApplyFI ==
 /\ tx.phase="ApplyFI"
 /\ IF tx.index>Len(tx.request.fiToClear)
      THEN tx'=[tx EXCEPT !.phase="Finalize"]
      ELSE LET i==tx.request.fiToClear[tx.index]
           IN tx'=[tx EXCEPT !.workspace.state.entries[i].hash="Nil",!.index=@+1]
 /\ UNCHANGED <<vars,storage,observed>>
FinalizeWork ==
 /\ tx.phase="Finalize"
 /\ tx'=[tx EXCEPT !.phase="Commit",!.workspace.generation=generation+1,
       !.workspace.nonce=recoveryNonce+1,!.workspace.start=c,
       !.workspace.state.origins[generation+1]=Origin(IF CorrectOrigin THEN c ELSE 0,tx.context.block,tx.context.timestamp),
       !.workspace.state.stopTime=0,!.workspace.state.stopGrid=0,
       !.workspace.state.activeSnapshot=IF PreserveSnapshot THEN @ ELSE tx.context.block]
 /\ UNCHANGED <<vars,storage,observed>>
Commit ==
 /\ tx.phase="Commit" /\ Recover
 /\ storage'=tx.workspace.state /\ tx'=[tx EXCEPT !.phase="Done"]
 /\ observed'=[observed EXCEPT !.receipt=Receipt(observed.original,observed.beginBefore,CanonicalAfter,
          observed.execution,TRUE,"Success",tx.validated,tx.applied,observed.callback)]
PublishWorkspace ==
 /\ c'=tx.workspace.checkpoint /\ generation'=tx.workspace.generation /\ recoveryNonce'=tx.workspace.nonce
 /\ startHeight'=tx.workspace.start /\ landings'=tx.workspace.landings /\ storage'=tx.workspace.state
 /\ UNCHANGED <<now,authorization,pendingProof,lastLanding,audit>>
Abort ==
 /\ tx.phase="Abort"
 /\ IF AbortAtomic THEN UNCHANGED <<vars,storage>> ELSE PublishWorkspace
 /\ tx'=[tx EXCEPT !.phase="Done"]
 /\ observed'=[observed EXCEPT !.receipt=Receipt(observed.original,observed.beginBefore,CanonicalAfter,
            observed.execution,FALSE,tx.reason,tx.validated,tx.applied,observed.callback)]
IdleActions == (\E h \in 0..MaxHeight:FreshLand(h) \/ BasePrepare(h)) \/ BaseLand(pendingProof)
             \/ (\E d \in 0..MaxTime:BaseAuthorize(d)) \/ BaseInvalidate \/ BaseTick
             \/ (\E kind \in RequestKinds,failure \in FailureModes,cb \in CallbackModes:Begin(kind,Exclusions(kind),FIList(kind),failure,cb))
AllActions == IdleActions \/ Entry \/ ValidateIds \/ ValidateFI \/ Callback \/ ApplyIds \/ ApplyFI \/ FinalizeWork \/ Commit \/ Abort
TransactionNext == IF setup=0 THEN FreshLand(1) /\ setup'=1
        ELSE IF setup=1 THEN BaseAuthorize(MaxTime) /\ setup'=2
        ELSE AllActions /\ UNCHANGED setup
RecoveryTransactionSpec == TransactionInit /\ [][TransactionNext]_allVars

\* Independent request/effect oracles. No mutant flag enables these assertions.
RawValid(req,pre,context) ==
 /\ req.expectedGeneration=pre.generation /\ req.expectedC=pre.checkpoint
 /\ req.expectedRecoveryNonce=pre.nonce /\ context.timestamp<=req.validUntil
 /\ \A k \in 1..Len(req.exclusions):LET e==req.exclusions[k] IN
      pre.state.bonds[e.bondId].issued /\ pre.state.bonds[e.bondId].key=e.entryKey
      /\ (\A j \in 1..(k-1):req.exclusions[j].bondId<e.bondId)
 /\ \A k \in 1..Len(req.fiToClear):pre.state.head<=req.fiToClear[k] /\ req.fiToClear[k]<pre.state.tail
      /\ (\A j \in 1..(k-1):req.fiToClear[j]<req.fiToClear[k])
ExpectedSuccess(req,pre,context) == RawValid(req,pre,context)
    /\ ~(req.failure="SecondRegistry" /\ Len(req.exclusions)>=2)
ExpectedAfter(req,pre,context) ==
 LET selected=={e.bondId:e \in {req.exclusions[k]:k \in 1..Len(req.exclusions)}}
     fis=={req.fiToClear[k]:k \in 1..Len(req.fiToClear)}
     state==[pre.state EXCEPT !.bonds=[i \in IDs |-> IF i \in selected
                THEN [pre.state.bonds[i] EXCEPT !.exit=IF @<context.block THEN @ ELSE context.block]
                ELSE pre.state.bonds[i]],
             !.entries=[i \in FIIndices |-> IF i \in fis
                THEN [pre.state.entries[i] EXCEPT !.hash="Nil"] ELSE pre.state.entries[i]],
             !.origins[pre.generation+1]=[present |-> TRUE,start |-> pre.checkpoint,block |-> context.block,timestamp |-> context.timestamp],
             !.stopTime=0,!.stopGrid=0]
 IN [pre EXCEPT !.generation=@+1,!.nonce=@+1,!.start=pre.checkpoint,!.state=state]
TransactionTypeOK == tx.phase \in {"Idle","Entry","ValidateIds","ValidateFI","ApplyIds","ApplyFI","Finalize","Commit","Abort","Done"}
OriginalRequestUnchanged == tx.phase="Idle" \/ (tx.request=observed.original /\ tx.context=observed.execution)
CanonicalUnpublishedDuringAttempt == tx.phase \in {"Idle","Done"} \/ Canonical=observed.beginBefore
CompletedAttemptCorrect == ~observed.receipt.present \/
    observed.receipt.accepted=ExpectedSuccess(observed.receipt.request,observed.receipt.before,observed.receipt.context)
AbortPreservesCanonical == ~observed.receipt.present \/ observed.receipt.accepted \/ observed.receipt.before=observed.receipt.after
SuccessfulWritesExact == ~observed.receipt.present \/ ~observed.receipt.accepted \/
    observed.receipt.after=ExpectedAfter(observed.receipt.request,observed.receipt.before,observed.receipt.context)
NestedCallsRejected == ~observed.callback.present \/ (~observed.callback.accepted /\ observed.callback.before=observed.callback.after)
MixedDeadlineSuccessNotReached == ~observed.receipt.present \/ LET q==observed.receipt IN
    ~(q.accepted /\ Len(q.request.exclusions)=2 /\ Len(q.request.fiToClear)>0
       /\ q.context.timestamp=q.request.validUntil /\ q.context.timestamp>1000)
UnheldExclusionNotReached == ~observed.receipt.present \/ LET q==observed.receipt IN
    ~(q.accepted /\ ~q.before.state.bonds[0].holds /\ ~q.before.state.bonds[0].withdrawn)
WithdrawnExclusionNotReached == ~observed.receipt.present \/ LET q==observed.receipt IN
    ~(q.accepted /\ q.before.state.bonds[0].issued /\ q.before.state.bonds[0].withdrawn)
LateInvalidAbortNotReached == ~observed.receipt.present \/ LET q==observed.receipt IN
    ~(~q.accepted /\ q.reason="ExclusionRejected" /\ q.validatedIds=1 /\ Len(q.request.exclusions)=2 /\ q.before=q.after)
TentativeFailureAbortNotReached == ~observed.receipt.present \/ LET q==observed.receipt IN
    ~(~q.accepted /\ q.reason="RegistryFailed" /\ q.appliedIds=1 /\ q.before=q.after
         /\ tx.workspace.state.bonds[0].exit#q.before.state.bonds[0].exit)
CaughtCallbackSuccessNotReached == ~observed.receipt.present \/ LET q==observed.receipt IN
    ~(q.accepted /\ q.callback.present /\ ~q.callback.accepted /\ q.callback.before=q.callback.after)
\* Versioned completed-attempt interface for C03. Internal steps are NOT onchain steps.
PublicAttempt == IF ~observed.receipt.present THEN [schemaVersion |-> 1,present |-> FALSE]
 ELSE LET q==observed.receipt IN [schemaVersion |-> 1,present |-> TRUE,
      calldata |-> [expectedGeneration |-> q.request.expectedGeneration,expectedC |-> q.request.expectedC,
         expectedRecoveryNonce |-> q.request.expectedRecoveryNonce,validUntil |-> q.request.validUntil,
         exclusions |-> q.request.exclusions,fiToClear |-> q.request.fiToClear,rules |-> 0],
      execution |-> q.context,injection |-> [failure |-> q.request.failure,callback |-> q.request.callback],
      outcome |-> [accepted |-> q.accepted,reason |-> q.reason],before |-> q.before,after |-> q.after,
      nestedCall |-> q.callback]
=============================================================================
