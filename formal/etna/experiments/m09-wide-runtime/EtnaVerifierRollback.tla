-------------------------- MODULE EtnaVerifierRollback --------------------------
EXTENDS EtnaSettlement, FiniteSets, Sequences
\* Explicit verifier-failure/atomic corrective-upgrade interface, not ordinary
\* proof soundness or a claim that a concrete corrective-upgrade API exists.
CONSTANTS Profile, AdvanceCurrentNonce, SnapshotConfirmation, VoidLater,
          PreserveTrusted, RevokeCached, RevokeRetry, PreserveFeePaid,
          PreserveOriginFence, LatestStart
Heights == 0..MaxHeight
Bonds == {0,1}
Messages == {"Legit","Forged"}
Block(t) == 100+t
Meta(root,head,snapshot) == [present |-> TRUE,root |-> root,head |-> head,snapshot |-> snapshot]
EmptyMeta == [present |-> FALSE,root |-> "None",head |-> 0,snapshot |-> 0]
StartMeta == Meta("StartLatest",0,5)
Target == IF Profile="NoTrusted" THEN 0 ELSE 1
VARIABLES state, cash, journal, setup
newVars == <<state,cash,journal,setup>>
allVars == <<vars,newVars>>
RollbackInit ==
 /\ Init /\ setup=0
 /\ state=[checkpoints |-> [h \in Heights |-> IF h=0 THEN StartMeta ELSE EmptyMeta],
       head |-> 0,snapshot |-> 5,confirmed |-> [b \in Bonds |-> 0],exits |-> [b \in Bonds |-> IF b=0 THEN 5 ELSE 20],
       principal |-> [b \in Bonds |-> 1],withdrawn |-> [b \in Bonds |-> FALSE],
       forfeited |-> [b \in Bonds |-> TRUE],cache |-> [m \in Messages |-> FALSE],
       cacheAt |-> [m \in Messages |-> 0],retry |-> [m \in Messages |-> FALSE],
       retryAt |-> [m \in Messages |-> 0],feePaid |-> [m \in Messages |-> FALSE],
       escrow |-> [m \in Messages |-> 1],completed |-> [m \in Messages |-> FALSE],
       paused |-> FALSE,upgraded |-> FALSE,badObserved |-> FALSE,firstBadBlock |-> 0,epoch |-> 0]
 /\ cash=[fees |-> [m \in Messages |-> 0],valuePaid |-> 1,stakePaid |-> 1]
 /\ journal=[restore |-> [height |-> 0,meta |-> StartMeta],authEpoch |-> 0,
       originStarts |-> [g \in 0..MaxGeneration |-> 0],
       upgrade |-> [present |-> FALSE],fresh |-> [m \in Messages |-> 0],
       expectedCheckpoints |-> [h \in Heights |-> IF h=0 THEN StartMeta ELSE EmptyMeta],
       badAuthority |-> FALSE,badProof |-> FALSE,cachedRejected |-> FALSE,retryRejected |-> FALSE,
       messageTransfers |-> [m \in Messages |-> [present |-> FALSE,value |-> 0,fee |-> 0,
                                  afterUpgrade |-> FALSE,proofHeight |-> 0]],
       freshProofHeight |-> [m \in Messages |-> 0],stakeTransfers |-> [b \in Bonds |-> 0],
       lastLand |-> [present |-> FALSE,generation |-> 0,terminal |-> 0,afterUpgrade |-> FALSE]]
GoodLand(proof) ==
 /\ Land(proof)
 /\ LET meta==Meta(IF proof.terminal=1 THEN "Good1" ELSE "Good2",proof.terminal,
                   IF generation=0 THEN IF proof.terminal=1 THEN 10 ELSE 20 ELSE Block(now))
    IN /\ state'=[state EXCEPT !.checkpoints[proof.terminal]=meta,!.head=proof.terminal,!.snapshot=meta.snapshot]
       /\ journal'=[journal EXCEPT
          !.restore=IF ~state.badObserved THEN [height |-> proof.terminal,
                 meta |-> [present |-> TRUE,root |-> IF proof.terminal=1 THEN "Good1" ELSE "Good2",
                          head |-> proof.terminal,snapshot |-> IF proof.terminal=1 THEN 10 ELSE 20]] ELSE @,
          !.expectedCheckpoints[proof.terminal]=[present |-> TRUE,
              root |-> IF proof.terminal=1 THEN "Good1" ELSE "Good2",head |-> proof.terminal,
              snapshot |-> IF generation=0 THEN IF proof.terminal=1 THEN 10 ELSE 20 ELSE 100+now],
          !.lastLand=[present |-> TRUE,generation |-> generation,terminal |-> proof.terminal,afterUpgrade |-> state.upgraded]]
 /\ UNCHANGED cash
FreshGood(h) == GoodLand([present |-> TRUE,generation |-> generation,parent |-> c,terminal |-> h])
InjectedBad(h) ==
 /\ LandFresh(h)
 /\ state'=[state EXCEPT !.checkpoints[h]=Meta(IF h=1 THEN "Bad1" ELSE "Bad2",h,20),
                  !.head=h,!.snapshot=20,!.badObserved=TRUE,!.firstBadBlock=Block(now)]
 /\ journal'=[journal EXCEPT !.expectedCheckpoints[h]=[present |-> TRUE,
       root |-> IF h=1 THEN "Bad1" ELSE "Bad2",head |-> h,snapshot |-> 20]]
 /\ UNCHANGED cash
Confirm(b) ==
 /\ b \in Bonds /\ ~state.withdrawn[b] /\ state.snapshot>=state.exits[b]
 /\ state'=[state EXCEPT !.confirmed[b]=IF @=0 THEN Block(now) ELSE @]
 /\ UNCHANGED <<vars,cash,journal>>
SeedMessage(m) ==
 /\ m \in Messages /\ ~state.feePaid[m]
 /\ (m="Legit" \/ state.badObserved)
 /\ state'=[state EXCEPT !.cache[m]=TRUE,!.cacheAt[m]=Block(now),
                        !.retry[m]=TRUE,!.retryAt[m]=Block(now),!.feePaid[m]=TRUE]
 /\ cash'=[cash EXCEPT !.fees[m]=@+1]
 /\ UNCHANGED <<vars,journal>>
OwnerAuthorize(d) == Authorize(d) /\ journal'=[journal EXCEPT !.authEpoch=state.epoch] /\ UNCHANGED <<state,cash>>
OwnerRecover == Recover /\ journal'=[journal EXCEPT !.originStarts[generation+1]=c] /\ UNCHANGED <<state,cash>>
PauseBoth == state.badObserved /\ state'=[state EXCEPT !.paused=TRUE] /\ UNCHANGED <<vars,cash,journal>>
Upgrade ==
 /\ state.paused /\ ~state.upgraded /\ recoveryNonce<MaxNonce
 /\ c'=Target /\ generation'=generation
 /\ recoveryNonce'=IF AdvanceCurrentNonce THEN recoveryNonce+1 ELSE 0
 /\ startHeight'=IF PreserveOriginFence THEN startHeight ELSE Target
 /\ landings'=[h \in Heights |-> IF h>Target THEN [landings[h] EXCEPT !.present=FALSE] ELSE landings[h]]
 /\ LET restored==IF Target=0 /\ ~LatestStart THEN Meta("StartSuperseded",0,5) ELSE state.checkpoints[Target]
        metas==[h \in Heights |-> IF h=Target THEN restored
                 ELSE IF h>Target /\ VoidLater THEN [state.checkpoints[h] EXCEPT !.present=FALSE]
                 ELSE state.checkpoints[h]]
    IN /\ state'=[state EXCEPT !.checkpoints=IF PreserveTrusted THEN metas
                           ELSE [h \in Heights |-> [metas[h] EXCEPT !.present=FALSE]],
                 !.head=restored.head,!.snapshot=restored.snapshot,
                 !.confirmed=[b \in Bonds |-> IF SnapshotConfirmation
                         THEN IF restored.snapshot>=state.exits[b] THEN state.confirmed[b] ELSE 0
                         ELSE IF state.confirmed[b]<=state.firstBadBlock THEN state.confirmed[b] ELSE 0],
                 !.cache=[m \in Messages |-> IF RevokeCached /\ state.cacheAt[m]>=state.firstBadBlock THEN FALSE ELSE state.cache[m]],
                 !.retry=[m \in Messages |-> IF RevokeRetry /\ state.retryAt[m]>=state.firstBadBlock THEN FALSE ELSE state.retry[m]],
                 !.feePaid=IF PreserveFeePaid THEN state.feePaid ELSE [m \in Messages |-> FALSE],
                 !.upgraded=TRUE,!.epoch=@+1]
       /\ journal'=[journal EXCEPT !.upgrade=[present |-> TRUE,beforeC |-> c,afterC |-> c',
              beforeGeneration |-> generation,afterGeneration |-> generation',beforeNonce |-> recoveryNonce,
              afterNonce |-> recoveryNonce',beforeStart |-> startHeight,afterStart |-> startHeight',
              beforeState |-> state,afterState |-> state',beforeCash |-> cash,afterCash |-> cash],
              !.expectedCheckpoints=[h \in Heights |-> IF h>journal.restore.height
                 THEN [journal.expectedCheckpoints[h] EXCEPT !.present=FALSE] ELSE journal.expectedCheckpoints[h]] ]
 /\ UNCHANGED <<now,authorization,pendingProof,lastLanding,audit,cash>>
OwnerTick == Tick /\ UNCHANGED <<state,cash,journal>>
OwnerInvalidate == InvalidateNonce /\ UNCHANGED <<state,cash,journal>>
SetupStep ==
 /\ IF Profile="NoTrusted"
       THEN CASE setup=0 -> Confirm(0) [] setup=1 -> SeedMessage("Legit")
              [] setup=2 -> InjectedBad(1) [] setup=3 -> Confirm(1) [] setup=4 -> SeedMessage("Forged")
              [] setup=5 -> OwnerAuthorize(MaxTime) [] setup=6 -> OwnerRecover [] setup=7 -> PauseBoth
       ELSE CASE setup=0 -> FreshGood(1) [] setup=1 -> OwnerAuthorize(MaxTime)
              [] setup=2 -> Confirm(0) [] setup=3 -> SeedMessage("Legit") [] setup=4 -> InjectedBad(2)
              [] setup=5 -> Confirm(1) [] setup=6 -> SeedMessage("Forged")
              [] setup=7 -> IF Profile="Stranded" THEN OwnerAuthorize(MaxTime) ELSE PauseBoth
              [] setup=8 -> OwnerRecover [] setup=9 -> PauseBoth
 /\ setup'=setup+1

Unpause ==
 /\ state.upgraded /\ state.paused /\ state'=[state EXCEPT !.paused=FALSE]
 /\ UNCHANGED <<vars,cash,journal>>
Contains(root,m) == (m="Legit" /\ root \in {"StartLatest","Good1","Good2","Bad1","Bad2"})
                    \/ (m="Forged" /\ root \in {"Bad1","Bad2"})
Reprove(m,h) ==
 /\ m \in Messages /\ h \in Heights /\ state.upgraded /\ ~state.paused
 /\ state.checkpoints[h].present /\ Contains(state.checkpoints[h].root,m)
 /\ state'=[state EXCEPT !.cache[m]=TRUE,!.cacheAt[m]=Block(now),!.retry[m]=TRUE,!.retryAt[m]=Block(now)]
 /\ LET correct==journal.expectedCheckpoints[h].present
               /\ state.checkpoints[h].root=journal.expectedCheckpoints[h].root /\ m="Legit"
    IN journal'=[journal EXCEPT !.badProof=@ \/ ~correct,
                !.fresh[m]=IF correct THEN state.epoch ELSE @,
                !.freshProofHeight[m]=IF correct THEN h ELSE @]
 /\ UNCHANGED <<vars,cash>>
CheckCached(m) ==
 /\ m \in Messages /\ ~state.paused
 /\ LET accepted==state.cache[m]
    IN journal'=[journal EXCEPT !.badAuthority=@ \/
             (state.upgraded /\ accepted /\ state.cacheAt[m]>=state.firstBadBlock /\ journal.fresh[m]#state.epoch),
             !.cachedRejected=@ \/ (state.upgraded /\ m="Forged" /\ ~accepted)]
 /\ UNCHANGED <<vars,state,cash>>
RetryAttempt(m) ==
 /\ m \in Messages /\ ~state.paused
 /\ LET accepted==state.retry[m] /\ ~state.completed[m]
        fee==IF state.feePaid[m] THEN 0 ELSE 1
        amount==state.escrow[m]
    IN /\ state'=IF accepted THEN [state EXCEPT !.completed[m]=TRUE,!.retry[m]=FALSE,
                                   !.escrow[m]=0,!.feePaid[m]=TRUE] ELSE state
       /\ cash'=IF accepted THEN [cash EXCEPT !.fees[m]=@+fee,!.valuePaid=@+amount] ELSE cash
       /\ journal'=[journal EXCEPT !.badAuthority=@ \/
               (state.upgraded /\ accepted /\ state.retryAt[m]>=state.firstBadBlock /\ journal.fresh[m]#state.epoch),
               !.retryRejected=@ \/ (state.upgraded /\ m="Forged" /\ ~accepted),
               !.messageTransfers[m]=IF accepted THEN [present |-> TRUE,value |-> cash'.valuePaid-cash.valuePaid,
                      fee |-> cash'.fees[m]-cash.fees[m],afterUpgrade |-> state.upgraded,
                      proofHeight |-> journal.freshProofHeight[m]] ELSE @]
 /\ UNCHANGED vars
Withdraw(b) ==
 /\ b \in Bonds /\ ~state.withdrawn[b] /\ state.confirmed[b]>0
 /\ Block(now)>=state.confirmed[b]+1
 /\ state'=[state EXCEPT !.withdrawn[b]=TRUE,!.principal[b]=0,!.confirmed[b]=0]
 /\ cash'=[cash EXCEPT !.stakePaid=@+state.principal[b]]
 /\ journal'=[journal EXCEPT !.stakeTransfers[b]=@+(cash'.stakePaid-cash.stakePaid)]
 /\ UNCHANGED vars
Runtime == Upgrade \/ OwnerTick \/ OwnerInvalidate \/ (\E d \in 0..MaxTime:OwnerAuthorize(d))
           \/ OwnerRecover \/ (\E h \in Heights:state.upgraded /\ FreshGood(h))
           \/ Unpause \/ (\E m \in Messages,h \in Heights:Reprove(m,h))
           \/ (\E m \in Messages:CheckCached(m) \/ RetryAttempt(m))
           \/ (\E b \in Bonds:Confirm(b) \/ Withdraw(b))
RollbackNext == IF setup<(IF Profile="Stranded" THEN 10 ELSE 8) THEN SetupStep ELSE Runtime /\ UNCHANGED setup
RollbackSpec == RollbackInit /\ [][RollbackNext]_allVars
RollbackNonceCorrect == ~journal.upgrade.present \/
    (journal.upgrade.afterNonce=journal.upgrade.beforeNonce+1
     /\ journal.upgrade.afterGeneration=journal.upgrade.beforeGeneration)
ConfirmationsRevalidated == ~journal.upgrade.present \/ LET u==journal.upgrade IN
    \A b \in Bonds:u.afterState.confirmed[b]=(IF journal.restore.meta.snapshot>=u.beforeState.exits[b]
                                             THEN u.beforeState.confirmed[b] ELSE 0)
ExpectedRestoration == ~journal.upgrade.present \/ LET u==journal.upgrade IN
    u.afterC=journal.restore.height /\ u.afterState.head=journal.restore.meta.head
    /\ u.afterState.snapshot=journal.restore.meta.snapshot
    /\ u.afterState.checkpoints[journal.restore.height].root=journal.restore.meta.root
PreRollbackAuthorizationCannotExecute == ~state.upgraded \/ journal.authEpoch=state.epoch \/ ~ENABLED Recover

RollbackTypeOK == c \in Heights /\ generation \in 0..MaxGeneration /\ recoveryNonce \in 0..MaxNonce
                  /\ startHeight \in Heights /\ state.head \in 0..2 /\ state.epoch \in 0..1
CheckpointProjectionMatches == state.checkpoints=journal.expectedCheckpoints
DerivedAuthorityRevoked == ~journal.badAuthority
ProofAuthorizationCorrect == ~journal.badProof
FeeNotPaidTwice == \A m \in Messages:cash.fees[m]<=1
ValueAndStakeConserved ==
 /\ cash.valuePaid=1+journal.messageTransfers["Legit"].value+journal.messageTransfers["Forged"].value
 /\ \A m \in Messages:state.escrow[m]+journal.messageTransfers[m].value=1
 /\ cash.stakePaid=1+journal.stakeTransfers[0]+journal.stakeTransfers[1]
 /\ \A b \in Bonds:state.principal[b]+journal.stakeTransfers[b]=1
UpgradePreservesPayments == ~journal.upgrade.present \/ LET u==journal.upgrade IN
    u.beforeCash=u.afterCash /\ u.beforeState.escrow=u.afterState.escrow
    /\ u.beforeState.principal=u.afterState.principal /\ u.beforeState.withdrawn=u.afterState.withdrawn
    /\ u.beforeState.forfeited=u.afterState.forfeited
StrandedGenerationCannotLand == ~state.upgraded \/ journal.originStarts[generation]<=c \/
    (\A h \in (c+1)..MaxHeight:~ENABLED LandFresh(h))
SameBlockSplitNotReached == ~journal.upgrade.present \/ LET u==journal.upgrade IN
    ~(u.beforeState.confirmed[0]=u.beforeState.confirmed[1] /\ u.beforeState.confirmed[0]>0
       /\ u.afterState.confirmed[0]=u.beforeState.confirmed[0] /\ u.afterState.confirmed[1]=0)
StaleAuthorizationRejectedNotReached == ~(state.upgraded /\ journal.authEpoch<state.epoch
    /\ authorization.generation=generation /\ authorization.checkpoint=c
    /\ authorization.nonce<recoveryNonce /\ now<=authorization.deadline /\ ~ENABLED Recover)
BothOldPathsRejectedNotReached == ~(journal.cachedRejected /\ journal.retryRejected)
CanonicalReproofRetryNotReached == LET q==journal.messageTransfers["Legit"] IN
    ~(q.present /\ q.afterUpgrade /\ q.proofHeight=2 /\ q.value=1 /\ q.fee=0 /\ cash.fees["Legit"]=1)
FreshRecoveryLandingNotReached == ~journal.upgrade.present \/
    ~(journal.upgrade.beforeStart>journal.upgrade.afterC /\ journal.lastLand.present
       /\ journal.lastLand.afterUpgrade /\ journal.lastLand.generation>journal.upgrade.afterGeneration
       /\ journal.lastLand.terminal>journal.upgrade.afterC)
LatestStartRestoreNotReached == ~journal.upgrade.present \/
    ~(Profile="NoTrusted" /\ journal.upgrade.afterC=0
       /\ journal.upgrade.afterState.checkpoints[0].root="StartLatest")
=============================================================================
