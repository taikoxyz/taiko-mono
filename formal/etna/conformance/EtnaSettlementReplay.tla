----------------------- MODULE EtnaSettlementReplay -----------------------
EXTENDS EtnaSettlement, Sequences

\* Script inputs only; outcomes/states come from the unchanged base actions.
\* 1 Authorize, 2 PrepareProof, 3 Land(pending), 4 LandFresh,
\* 5 Recover, 6 InvalidateNonce, 7 Tick. Argument zero is unused.
Scripts == <<
 <<<<2,3>>,<<4,1>>,<<3,0>>>>,
 <<<<1,3>>,<<4,1>>,<<5,0>>>>,
 <<<<1,3>>,<<6,0>>,<<5,0>>>>,
 <<<<1,1>>,<<7,0>>,<<5,0>>,<<5,0>>>>,
 <<<<1,0>>,<<7,0>>,<<5,0>>,<<1,2>>,<<5,0>>>>,
 <<<<2,2>>,<<1,3>>,<<5,0>>,<<3,0>>,<<7,0>>,<<4,1>>>>,
 <<<<4,1>>,<<2,3>>,<<1,3>>,<<5,0>>,<<3,0>>,<<7,0>>,<<4,2>>>>,
 <<<<1,3>>,<<5,0>>,<<1,3>>,<<5,0>>,<<7,0>>,<<4,1>>>>
>>
VARIABLES caseId, step, emitting, accepted, op, arg, originHistory
replayVars == <<vars,caseId,step,emitting,accepted,op,arg,originHistory>>
ReplayInit == /\ Init /\ caseId \in 1..Len(Scripts)
 /\ originHistory = [i \in 1..3 |-> <<i=1,0,0>>]
 /\ step=0 /\ emitting=TRUE /\ accepted=TRUE /\ op=0 /\ arg=0
Apply(o,a) == CASE o=1 -> Authorize(a)
 [] o=2 -> PrepareProof(a)
 [] o=3 -> Land(pendingProof)
 [] o=4 -> LandFresh(a)
 [] o=5 -> Recover
 [] o=6 -> InvalidateNonce
 [] o=7 -> Tick
Execute ==
 /\ ~emitting /\ step < Len(Scripts[caseId])
 /\ LET request == Scripts[caseId][step+1]
        enabled == ENABLED Apply(request[1],request[2])
    IN /\ IF enabled THEN Apply(request[1],request[2]) ELSE UNCHANGED vars
       /\ op'=request[1] /\ arg'=request[2] /\ accepted'=enabled
       /\ originHistory' = IF enabled /\ request[1]=5
           THEN [originHistory EXCEPT ![generation+2] = <<TRUE,c,now>>]
           ELSE originHistory
 /\ step'=step+1 /\ emitting'=TRUE /\ UNCHANGED caseId
Emit ==
 /\ emitting
 /\ PrintT(<<"ETNA_SETTLEMENT",caseId,step,op,arg,accepted,
       c,generation,recoveryNonce,startHeight,now,
       <<authorization.present,authorization.generation,authorization.checkpoint,
       authorization.nonce,authorization.deadline>>,
       <<pendingProof.present,pendingProof.generation,pendingProof.parent,pendingProof.terminal>>,
       [i \in 1..(MaxHeight+1) |-> <<landings[i-1].present,
       landings[i-1].generation,landings[i-1].parent>>], originHistory>>)
 /\ emitting'=FALSE /\ UNCHANGED <<vars,caseId,step,accepted,op,arg,originHistory>>
ReplaySpec == ReplayInit /\ [][Execute \/ Emit]_replayVars
=============================================================================
