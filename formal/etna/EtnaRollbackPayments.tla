----------------------- MODULE EtnaRollbackPayments -----------------------
EXTENDS EtnaVerifierRollback, Sequences, Integers
CONSTANTS PaymentProfiles, OmittedActions
ASSUME /\ PaymentProfiles # {} /\ PaymentProfiles \subseteq {"Core","NonceBefore","HeightReuse"}
       /\ OmittedActions # {}
VARIABLES paymentProfile, paymentOmission, paymentIndex, paymentReceipts
PaymentLocal == <<paymentProfile,paymentOmission,paymentIndex,paymentReceipts>>
PaymentVars == <<allVars,PaymentLocal>>
PaymentPrefix == <<"FreshGood1","Authorize1","Confirm0","SeedLegit","InjectedBad2",
    "Confirm1","SeedForged","Tick1","Withdraw1","PayForged">>
PaymentContainment == <<"PauseBoth","Upgrade","ReadVoided2","ReadRetained1","Unpause",
    "CheckLegitCache","CheckForgedCache","RetryForgedAfter","ReproveForged1","StaleRecover">>
PaymentCalls == PaymentPrefix \o
    (IF paymentProfile="NonceBefore" THEN <<"InvalidateCurrentNonce">> ELSE <<>>) \o
    PaymentContainment \o
    (IF paymentProfile="HeightReuse" THEN <<"ReuseGood2">> ELSE <<>>) \o
    <<"ReproveLegit","PayLegit","RepeatLegit">>
\* These finite scripts call the unchanged actions. Neither an audit nor an
\* expected acceptance predicate gates an enabled action, including a mutant.
PaymentCall(name) == CASE
    name="FreshGood1" -> FreshGood(1)
 [] name="Authorize1" -> OwnerAuthorize(1)
 [] name="Confirm0" -> Confirm(0)
 [] name="SeedLegit" -> SeedMessage("Legit")
 [] name="InjectedBad2" -> InjectedBad(2)
 [] name="Confirm1" -> Confirm(1)
 [] name="SeedForged" -> SeedMessage("Forged")
 [] name="Tick1" -> OwnerTick
 [] name="Withdraw1" -> Withdraw(1)
 [] name="PayForged" -> RetryAttempt("Forged")
 [] name="InvalidateCurrentNonce" -> OwnerInvalidate
 [] name="PauseBoth" -> PauseBoth
 [] name="Upgrade" -> Upgrade
 [] name="ReadVoided2" -> ReadCheckpoint(2)
 [] name="ReadRetained1" -> ReadCheckpoint(1)
 [] name="Unpause" -> Unpause
 [] name="CheckLegitCache" -> CheckCached("Legit")
 [] name="CheckForgedCache" -> CheckCached("Forged")
 [] name="RetryForgedAfter" -> RetryAttempt("Forged")
 [] name="ReproveForged1" -> Reprove("Forged",1)
 [] name="StaleRecover" -> OwnerRecover
 [] name="ReuseGood2" -> FreshGood(2)
 [] name="ReproveLegit" -> Reprove("Legit",IF paymentProfile="HeightReuse" THEN 2 ELSE 1)
 [] name="PayLegit" -> RetryAttempt("Legit")
 [] name="RepeatLegit" -> RetryAttempt("Legit")
PaymentRaw == [checkpoint |-> c,generation |-> generation,nonce |-> recoveryNonce,
    start |-> startHeight,time |-> now,authorization |-> authorization,
    pending |-> pendingProof,landings |-> landings,lastLanding |-> lastLanding,
    audit |-> audit,state |-> state,cash |-> cash,journal |-> journal,setup |-> setup]
PaymentInit == /\ RollbackInit /\ paymentProfile \in PaymentProfiles
    /\ paymentOmission \in OmittedActions
    /\ (paymentOmission="None" \/ paymentOmission \in {PaymentCalls[i] : i \in 1..Len(PaymentCalls)})
    /\ paymentIndex=1 /\ paymentReceipts= <<>>
PaymentStep ==
 /\ paymentIndex<=Len(PaymentCalls)
 \* Bind these original/local fields before evaluating the raw primed receipt.
 /\ UNCHANGED <<setup,paymentProfile,paymentOmission>>
 /\ LET name==PaymentCalls[paymentIndex]
        enabled==ENABLED PaymentCall(name)
        executed==enabled /\ name#paymentOmission
    IN /\ IF executed THEN PaymentCall(name) ELSE UNCHANGED <<vars,state,cash,journal>>
       /\ paymentReceipts'=Append(paymentReceipts,
           [call |-> name,enabled |-> enabled,executed |-> executed,
            before |-> PaymentRaw,after |-> PaymentRaw'])
 /\ paymentIndex'=paymentIndex+1
PaymentSpec == PaymentInit /\ [][PaymentStep]_PaymentVars
PaymentEvents(name) == {paymentReceipts[i] : i \in
    {k \in 1..Len(paymentReceipts) : paymentReceipts[k].call=name}}
PaymentValue(q) == q.after.cash.valuePaid-q.before.cash.valuePaid
PaymentStake(q) == q.after.cash.stakePaid-q.before.cash.stakePaid
PaymentFee(q,m) == q.after.cash.fees[m]-q.before.cash.fees[m]
RECURSIVE PaymentValueSum(_), PaymentStakeSum(_), PaymentFeeSum(_,_), PaymentPayeeSum(_,_)
PaymentValueSum(n) == IF n=0 THEN 0 ELSE PaymentValueSum(n-1)+PaymentValue(paymentReceipts[n])
PaymentStakeSum(n) == IF n=0 THEN 0 ELSE PaymentStakeSum(n-1)+PaymentStake(paymentReceipts[n])
PaymentFeeSum(n,m) == IF n=0 THEN 0 ELSE PaymentFeeSum(n-1,m)+PaymentFee(paymentReceipts[n],m)
PaymentPayeeSum(n,m) == IF n=0 THEN 0 ELSE PaymentPayeeSum(n-1,m)+
    (IF paymentReceipts[n].call=(IF m="Legit" THEN "PayLegit" ELSE "PayForged")
     THEN PaymentValue(paymentReceipts[n]) ELSE 0)
\* Every raw delta is summed, including negative and non-payment events. Literal
\* allowed amounts by action/payee separately prevent offsetting clawback/repay.
PaymentTransferAudit ==
 /\ \A q \in {paymentReceipts[i] : i \in 1..Len(paymentReceipts)} :
     /\ PaymentValue(q)=(IF q.executed /\ q.call \in {"PayForged","PayLegit"} THEN 1 ELSE 0)
     /\ PaymentStake(q)=(IF q.executed /\ q.call="Withdraw1" THEN 1 ELSE 0)
     /\ \A m \in Messages : PaymentFee(q,m)=
          (IF q.executed /\ q.call=(IF m="Legit" THEN "SeedLegit" ELSE "SeedForged") THEN 1 ELSE 0)
 /\ cash.valuePaid=1+PaymentValueSum(Len(paymentReceipts))
 /\ cash.stakePaid=1+PaymentStakeSum(Len(paymentReceipts))
 /\ \A m \in Messages :
     /\ cash.fees[m]=PaymentFeeSum(Len(paymentReceipts),m)
     /\ state.escrow[m]+PaymentPayeeSum(Len(paymentReceipts),m)=1
 /\ state.principal[0]=1 /\ state.principal[1]+PaymentStakeSum(Len(paymentReceipts))=1
PaymentRawAudit ==
 /\ paymentIndex=Len(paymentReceipts)+1 /\ setup=0
 /\ \A i \in 1..Len(paymentReceipts) :
     /\ paymentReceipts[i].call=PaymentCalls[i]
     /\ i>1 => paymentReceipts[i].before=paymentReceipts[i-1].after
     /\ ~paymentReceipts[i].executed => paymentReceipts[i].after=paymentReceipts[i].before
\* Dedicated immediate real-Upgrade checks deliberately do not trust its journal:
\* its afterCash is unprimed, and UpgradePreservesPayments omits completed.
PaymentUpgradeCashAudit == \A q \in PaymentEvents("Upgrade") : q.executed =>
    /\ q.before.cash=[fees |-> [m \in Messages |-> 1],valuePaid |-> 2,stakePaid |-> 2]
    /\ q.after.cash=q.before.cash
PaymentUpgradeCompletedAudit == \A q \in PaymentEvents("Upgrade") : q.executed =>
    /\ q.before.state.completed=[m \in Messages |-> m="Forged"]
    /\ q.after.state.completed=q.before.state.completed
    /\ q.before.state.escrow=[m \in Messages |-> IF m="Forged" THEN 0 ELSE 1]
    /\ q.after.state.escrow=q.before.state.escrow
PaymentPreservationAudit == \A q \in PaymentEvents("Upgrade") : q.executed =>
    /\ q.after.state.principal=q.before.state.principal
    /\ q.after.state.withdrawn=q.before.state.withdrawn
    /\ q.after.state.forfeited=q.before.state.forfeited
    /\ q.after.state.exits=q.before.state.exits
    /\ q.after.state.feePaid=q.before.state.feePaid
PaymentAuthorityAudit == \A q \in PaymentEvents("Upgrade") : q.executed =>
    /\ q.before.checkpoint=2 /\ q.after.checkpoint=1
    /\ q.before.generation=0 /\ q.after.generation=0
    /\ q.before.nonce=(IF paymentProfile="NonceBefore" THEN 1 ELSE 0)
    /\ q.after.nonce=(IF paymentProfile="NonceBefore" THEN 2 ELSE 1)
    /\ q.before.authorization=[present |-> TRUE,generation |-> 0,checkpoint |-> 1,nonce |-> 0,deadline |-> 1]
    /\ q.after.authorization=q.before.authorization /\ q.after.start=0 /\ q.after.time=1
    /\ q.before.state.paused /\ q.after.state.paused /\ q.after.state.upgraded
    /\ q.before.state.epoch=0 /\ q.after.state.epoch=1
    /\ q.after.state.head=1 /\ q.after.state.snapshot=10
    /\ q.after.state.checkpoints[1]=[present |-> TRUE,root |-> "Good1",head |-> 1,snapshot |-> 10]
    /\ q.before.state.checkpoints[2]=[present |-> TRUE,root |-> "Bad2",head |-> 2,snapshot |-> 20]
    /\ q.after.state.checkpoints[2]=[present |-> FALSE,root |-> "Bad2",head |-> 2,snapshot |-> 20]
    /\ q.after.landings[1]=[present |-> TRUE,generation |-> 0,parent |-> 0]
    /\ q.after.landings[2]=[present |-> FALSE,generation |-> 0,parent |-> 1]
    /\ q.before.state.firstBadBlock=100 /\ q.after.state.firstBadBlock=100
    /\ q.before.state.cache=[m \in Messages |-> TRUE]
    /\ q.before.state.cacheAt=[m \in Messages |-> 100]
    /\ q.after.state.cache=[m \in Messages |-> FALSE]
    /\ q.before.state.retry=[m \in Messages |-> m="Legit"]
    /\ q.after.state.retry=[m \in Messages |-> FALSE]
    /\ q.before.state.retryAt=[m \in Messages |-> 100]
    /\ q.after.state.confirmed=[b \in Bonds |-> IF b=0 THEN 100 ELSE 0]
\* Literal history milestones are independent of checkpoint/membership/fee helpers.
PaymentHistoryAudit ==
 /\ \A q \in PaymentEvents("FreshGood1") : q.executed /\ q.after.checkpoint=1
     /\ q.after.state.checkpoints[1]=[present |-> TRUE,root |-> "Good1",head |-> 1,snapshot |-> 10]
 /\ \A q \in PaymentEvents("Confirm0") : q.executed /\ q.before.state.snapshot=10
     /\ q.after.state.confirmed[0]=100 /\ q.after.state.exits[0]=5
 /\ \A q \in PaymentEvents("Confirm1") : q.executed /\ q.before.state.snapshot=20
     /\ q.after.state.confirmed[1]=100 /\ q.after.state.exits[1]=20
 /\ \A q \in PaymentEvents("Withdraw1") :
     /\ q.executed /\ q.before.time=1 /\ ~q.before.state.upgraded /\ ~q.before.state.paused
     /\ q.before.state.confirmed[1]=100 /\ q.after.state.confirmed[1]=0
     /\ q.before.state.principal[1]=1 /\ q.after.state.principal[1]=0
     /\ ~q.before.state.withdrawn[1] /\ q.after.state.withdrawn[1]
 /\ \A q \in PaymentEvents("PayForged") :
     /\ q.executed /\ ~q.before.state.upgraded /\ ~q.before.state.paused
     /\ ~q.before.state.completed["Forged"] /\ q.after.state.completed["Forged"]
     /\ q.before.state.escrow["Forged"]=1 /\ q.after.state.escrow["Forged"]=0
     /\ q.before.state.retry["Forged"] /\ ~q.after.state.retry["Forged"]
 /\ \A q \in PaymentEvents("InvalidateCurrentNonce") :
     /\ q.executed /\ q.before.nonce=0 /\ q.after.nonce=1 /\ q.after.authorization.nonce=0
 /\ \A q \in PaymentEvents("ReuseGood2") :
     /\ q.executed /\ q.before.state.upgraded /\ ~q.before.state.paused
     /\ q.before.checkpoint=1 /\ ~q.before.state.checkpoints[2].present
     /\ q.after.checkpoint=2 /\ q.after.generation=0
     /\ q.after.state.checkpoints[2]=[present |-> TRUE,root |-> "Good2",head |-> 2,snapshot |-> 20]
     /\ q.after.landings[2]=[present |-> TRUE,generation |-> 0,parent |-> 1]
 /\ \A q \in PaymentEvents("ReproveLegit") :
     /\ q.executed /\ q.before.state.upgraded /\ ~q.before.state.paused
     /\ ~q.before.state.retry["Legit"] /\ ~q.before.state.completed["Legit"]
     /\ q.before.state.escrow["Legit"]=1 /\ q.after.state.retry["Legit"]
     /\ q.after.state.cache["Legit"] /\ q.after.state.cacheAt["Legit"]=101
     /\ q.after.state.retryAt["Legit"]=101
     /\ q.after.journal.fresh["Legit"]=1
     /\ q.after.journal.freshProofHeight["Legit"]=(IF paymentProfile="HeightReuse" THEN 2 ELSE 1)
 /\ \A q \in PaymentEvents("PayLegit") :
     /\ q.executed /\ q.before.state.upgraded /\ q.before.state.retry["Legit"]
     /\ ~q.before.state.completed["Legit"] /\ q.after.state.completed["Legit"]
     /\ q.before.state.escrow["Legit"]=1 /\ q.after.state.escrow["Legit"]=0
     /\ ~q.after.state.retry["Legit"] /\ q.after.cash.fees["Legit"]=1
 /\ \A q \in PaymentEvents("RepeatLegit") :
     /\ q.executed /\ q.before.state.completed["Legit"] /\ ~q.before.state.retry["Legit"]
     /\ q.after=q.before
 /\ \A name \in {"CheckLegitCache","CheckForgedCache","RetryForgedAfter","ReproveForged1"} :
     \A q \in PaymentEvents(name) : q.executed /\ q.after.state=q.before.state /\ q.after.cash=q.before.cash
 /\ \A q \in PaymentEvents("StaleRecover") :
     /\ ~q.enabled /\ ~q.executed /\ q.after=q.before
     /\ q.before.authorization.generation=q.before.generation
     /\ q.before.authorization.checkpoint=q.before.checkpoint
     /\ q.before.authorization.deadline=q.before.time
     /\ q.before.authorization.nonce=0 /\ q.before.nonce>0
PaymentTerminalComplete ==
 /\ paymentIndex=Len(PaymentCalls)+1 /\ Len(paymentReceipts)=Len(PaymentCalls)
 /\ \A i \in 1..Len(paymentReceipts) :
     /\ paymentReceipts[i].enabled=(paymentReceipts[i].call#"StaleRecover")
     /\ paymentReceipts[i].executed=(paymentReceipts[i].call#"StaleRecover")
 /\ PaymentRawAudit /\ PaymentTransferAudit /\ PaymentHistoryAudit
 /\ PaymentUpgradeCashAudit /\ PaymentUpgradeCompletedAudit
 /\ PaymentPreservationAudit /\ PaymentAuthorityAudit
 /\ setup=0 /\ now=1 /\ generation=0 /\ startHeight=0
 /\ c=(IF paymentProfile="HeightReuse" THEN 2 ELSE 1)
 /\ recoveryNonce=(IF paymentProfile="NonceBefore" THEN 2 ELSE 1)
 /\ cash=[fees |-> [m \in Messages |-> 1],valuePaid |-> 3,stakePaid |-> 2]
 /\ PaymentValueSum(Len(paymentReceipts))=2 /\ PaymentStakeSum(Len(paymentReceipts))=1
 /\ \A m \in Messages : PaymentPayeeSum(Len(paymentReceipts),m)=1
 /\ state.completed=[m \in Messages |-> TRUE] /\ state.escrow=[m \in Messages |-> 0]
 /\ state.feePaid=[m \in Messages |-> TRUE] /\ state.retry=[m \in Messages |-> FALSE]
 /\ state.principal=[b \in Bonds |-> IF b=0 THEN 1 ELSE 0]
 /\ state.withdrawn=[b \in Bonds |-> b=1] /\ state.forfeited=[b \in Bonds |-> TRUE]
 /\ state.confirmed=[b \in Bonds |-> IF b=0 THEN 100 ELSE 0]
 /\ ~state.paused /\ state.upgraded /\ state.epoch=1
 /\ journal.cachedRejected /\ journal.retryRejected
 /\ ~journal.badRead /\ ~journal.badProof /\ ~journal.badAuthority
PaymentTerminalAudit == paymentIndex=Len(PaymentCalls)+1 => PaymentTerminalComplete
PaymentTerminalNotReached == ~PaymentTerminalComplete
=============================================================================
