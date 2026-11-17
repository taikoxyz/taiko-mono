----------------------- MODULE EtnaFISuffixRecovery -----------------------
EXTENDS EtnaForcedInclusion, Sequences
CONSTANTS SuffixProfiles, SuppressAction
ASSUME SuffixProfiles # {} /\ SuffixProfiles \subseteq {"Blank", "Retain"}
VARIABLES suffixProfile, suffixIndex, suffixReceipts
SuffixLocal == <<suffixProfile,suffixIndex,suffixReceipts>>
SuffixVars == <<allVars,SuffixLocal>>
SuffixCalls == <<"EnqueueA", "CloseAnchor0", "ProduceOld1", "EnqueueB",
    "CloseAnchor1", "CloseAnchor2", "ProduceOld2", "PrepareOld2", "LandPrefix1",
    "AuthorizeRecovery", "RecoverSuffix", "TryOldProof", "CloseRecoveryAnchor",
    "ProduceReplacement", "LandReplacement2">>
\* Preserve the outer AllFIActions production budget exactly. No actual FI action
\* writes stage; the companion keeps its original initial value instead of Setup.
SuffixProduce(a,mode) == /\ produces<MaxProduces /\ Produce(a,mode,TRUE)
                          /\ produces'=produces+1
SuffixCall(name) == CASE
    name="EnqueueA" -> Enqueue /\ UNCHANGED produces
 [] name="CloseAnchor0" -> FITick /\ UNCHANGED produces
 [] name="ProduceOld1" -> SuffixProduce(0,"First")
 [] name="EnqueueB" -> Enqueue /\ UNCHANGED produces
 [] name="CloseAnchor1" -> FITick /\ UNCHANGED produces
 [] name="CloseAnchor2" -> FITick /\ UNCHANGED produces
 [] name="ProduceOld2" -> SuffixProduce(2,"First")
 [] name="PrepareOld2" -> FIPrepare(2) /\ UNCHANGED produces
 [] name="LandPrefix1" -> FIFresh(1) /\ UNCHANGED produces
 [] name="AuthorizeRecovery" -> FIAuthorize(4) /\ UNCHANGED produces
 [] name="RecoverSuffix" -> FIRecover(IF suffixProfile="Blank" THEN {1} ELSE {}) /\ UNCHANGED produces
 [] name="TryOldProof" -> FILand(pendingProof,fi.queued) /\ UNCHANGED produces
 [] name="CloseRecoveryAnchor" -> FITick /\ UNCHANGED produces
 [] name="ProduceReplacement" -> SuffixProduce(3,IF suffixProfile="Blank" THEN "Skip" ELSE "First")
 [] name="LandReplacement2" -> FIFresh(2) /\ UNCHANGED produces
SuffixRaw == [checkpoint |-> c, generation |-> generation, nonce |-> recoveryNonce,
    start |-> startHeight, time |-> now, authorization |-> authorization,
    pending |-> pendingProof, landings |-> landings, lastLanding |-> lastLanding,
    audit |-> audit, queue |-> fi, produces |-> produces, stage |-> stage]
SuffixInit == /\ FIInit /\ suffixProfile \in SuffixProfiles
              /\ suffixIndex=1 /\ suffixReceipts= <<>>
\* The audit never chooses an outcome. Even a bad enabled Recover or Land executes
\* and its complete raw write is appended before an invariant examines it.
SuffixStep ==
 /\ suffixIndex<=Len(SuffixCalls)
 /\ UNCHANGED <<stage,suffixProfile>>
 /\ LET name==SuffixCalls[suffixIndex]
        enabled==ENABLED SuffixCall(name)
        executed==enabled /\ name#SuppressAction
    IN /\ IF executed THEN SuffixCall(name) ELSE UNCHANGED <<vars,fi,observations,produces>>
       /\ suffixReceipts'=Append(suffixReceipts,
          [call |-> name, enabled |-> enabled, executed |-> executed,
           before |-> SuffixRaw, after |-> SuffixRaw'])
 /\ suffixIndex'=suffixIndex+1
SuffixSpec == SuffixInit /\ [][SuffixStep]_SuffixVars

\* Expected inputs below are literal records, independent of FI fee, block,
\* cursor, recovery, proof and landing decision helpers.
SuffixEmptyBuild == [present |-> FALSE,generation |-> 0,height |-> 0,index |-> 0,
    hash |-> "Nil",parent |-> <<0,0>>,budget |-> "Full",status |-> "None",result |-> "None"]
SuffixEntryA == [hash |-> "A",timestamp |-> 10,block |-> 0]
SuffixEntryB == [hash |-> "B",timestamp |-> 12,block |-> 1]
SuffixEntryNil == [hash |-> "Nil",timestamp |-> 12,block |-> 1]
SuffixBlank == [hash |-> "Nil",timestamp |-> 0,block |-> 0]
SuffixQueue(hash) == [i \in 0..2 |-> IF i=0 THEN SuffixEntryA
    ELSE IF i=1 THEN [hash |-> hash,timestamp |-> 12,block |-> 1] ELSE SuffixBlank]
SuffixNewHash == IF suffixProfile="Blank" THEN "Nil" ELSE "B"
SuffixBlock(g,h,b,a,k,hash,body,raw) == [present |-> TRUE,generation |-> g,
    height |-> h,before |-> b,after |-> a,anchor |-> k,witness |-> TRUE,
    witnessHash |-> hash,body0 |-> body,body1 |-> "Ord",raw |-> raw,build |-> SuffixEmptyBuild]
SuffixOld1 == SuffixBlock(0,1,0,1,0,"A","A","Absent")
SuffixOld2 == SuffixBlock(0,2,1,2,2,"B","B","Absent")
SuffixNew2 == SuffixBlock(1,2,1,2,3,SuffixNewHash,
    IF suffixProfile="Blank" THEN "Ord" ELSE "B",
    IF suffixProfile="Blank" THEN "Nil" ELSE "Absent")
SuffixRecoveryReceipts == {suffixReceipts[i] : i \in {k \in 1..Len(suffixReceipts) : suffixReceipts[k].call="RecoverSuffix"}}
SuffixOldAttempts == {suffixReceipts[i] : i \in {k \in 1..Len(suffixReceipts) : suffixReceipts[k].call="TryOldProof"}}
\* Narrow actual-source fault targets: these check the write after real Recover,
\* with no original safety invariant able to intercept the intended violation.
SuffixCursorAudit == \A q \in SuffixRecoveryReceipts : q.executed =>
    /\ q.before.queue.cursor=2 /\ q.before.queue.head=1 /\ q.before.checkpoint=1
    /\ q.after.queue.cursor=1 /\ q.after.queue.frontier=1
    /\ q.after.queue.cuts[<<1,1>>]=1 /\ q.after.queue.head=1 /\ q.after.checkpoint=1
SuffixHashAudit == \A q \in SuffixRecoveryReceipts : q.executed =>
    /\ q.before.queue.queue=SuffixQueue("B")
    /\ q.after.queue.queue=SuffixQueue(SuffixNewHash)
SuffixRawAudit ==
 /\ suffixIndex=Len(suffixReceipts)+1 /\ stage=0
 /\ \A i \in 1..Len(suffixReceipts) :
     /\ suffixReceipts[i].call=SuffixCalls[i]
     /\ i>1 => suffixReceipts[i].before=suffixReceipts[i-1].after
     /\ ~suffixReceipts[i].executed => suffixReceipts[i].after=suffixReceipts[i].before
     /\ suffixReceipts[i].after.produces=suffixReceipts[i].before.produces+
          (IF suffixReceipts[i].executed /\ suffixReceipts[i].call \in
              {"ProduceOld1","ProduceOld2","ProduceReplacement"} THEN 1 ELSE 0)
 /\ \A q \in SuffixOldAttempts : ~q.enabled /\ ~q.executed /\ q.after=q.before
SuffixMilestoneAudit ==
 /\ Len(suffixReceipts)>=3 => LET q==suffixReceipts[3] IN
     /\ q.executed /\ q.before.time=1 /\ q.before.queue.cursor=0
     /\ q.before.queue.frontier=0 /\ q.after.queue.cursor=1 /\ q.after.queue.frontier=1
     /\ q.after.queue.blocks[<<0,1>>]=SuffixOld1 /\ q.after.produces=1
 /\ Len(suffixReceipts)>=4 => LET q==suffixReceipts[4] IN
     /\ q.executed /\ q.before.time=1 /\ q.before.checkpoint=0
     /\ q.before.queue.head=0 /\ q.before.queue.cursor=1 /\ q.before.queue.tail=1
     /\ q.before.queue.revenue=1 /\ q.after.queue.revenue=3
     /\ q.after.queue.queue=SuffixQueue("B")
 /\ Len(suffixReceipts)>=7 => LET q==suffixReceipts[7] IN
     /\ q.executed /\ q.before.time=3 /\ q.before.queue.anchors[2].entries=SuffixQueue("B")
     /\ q.before.queue.cursor=1 /\ q.before.queue.frontier=1
     /\ q.after.queue.blocks[<<0,2>>]=SuffixOld2 /\ q.after.queue.cursor=2
     /\ q.after.queue.frontier=2 /\ q.after.produces=2
 /\ Len(suffixReceipts)>=8 => LET q==suffixReceipts[8] IN
     /\ q.executed /\ q.after.pending=[present |-> TRUE,generation |-> 0,parent |-> 0,terminal |-> 2]
     /\ q.after.queue.queued=[present |-> TRUE,generation |-> 0,parent |-> 0,terminal |-> 2,
          cuts |-> [h \in 0..2 |-> h]]
 /\ Len(suffixReceipts)>=9 => LET q==suffixReceipts[9] IN
     /\ q.executed /\ q.before.checkpoint=0 /\ q.before.queue.head=0
     /\ q.after.checkpoint=1 /\ q.after.queue.head=1 /\ q.after.queue.cursor=2
     /\ q.after.queue.frontier=2 /\ q.after.queue.landedCuts[1]=1
     /\ q.after.landings[1]=[present |-> TRUE,generation |-> 0,parent |-> 0]
 /\ \A q \in SuffixRecoveryReceipts :
     /\ q.executed /\ q.before.time=3 /\ q.after.time=3
     /\ q.before.generation=0 /\ q.after.generation=1
     /\ q.before.nonce=0 /\ q.after.nonce=1 /\ q.before.start=0 /\ q.after.start=1
     /\ q.before.queue.frontier=2 /\ q.after.queue.frontier=1
     /\ q.before.queue.cursor=2 /\ q.after.queue.cursor=1
     /\ q.before.queue.head=1 /\ q.after.queue.head=1
     /\ q.before.queue.tail=2 /\ q.after.queue.tail=2
     /\ q.before.queue.revenue=3 /\ q.after.queue.revenue=3
     /\ q.before.queue.blocks=q.after.queue.blocks /\ q.before.landings=q.after.landings
     /\ q.before.pending=q.after.pending /\ q.before.queue.queued=q.after.queue.queued
     /\ q.after.queue.anchorFloor=3 /\ q.after.queue.lastAnchor=3
     /\ q.after.authorization=[present |-> TRUE,generation |-> 0,checkpoint |-> 1,nonce |-> 0,deadline |-> 4]
 /\ Len(suffixReceipts)>=12 => LET q==suffixReceipts[12] IN
     /\ q.before.pending=[present |-> TRUE,generation |-> 0,parent |-> 0,terminal |-> 2]
     /\ q.before.generation=1 /\ q.before.start=1 /\ q.before.checkpoint=1
 /\ Len(suffixReceipts)>=14 => LET q==suffixReceipts[14] IN
     /\ q.executed /\ q.before.time=4 /\ q.before.queue.cursor=1
     /\ q.before.queue.frontier=1 /\ q.before.queue.owners[1]=0
     /\ q.before.queue.anchors[3]=[tail |-> 2,head |-> 1,entries |-> SuffixQueue(SuffixNewHash)]
     /\ q.after.queue.blocks[<<1,2>>]=SuffixNew2 /\ q.after.queue.cursor=2
     /\ q.after.queue.frontier=2 /\ q.after.queue.owners[2]=1 /\ q.after.produces=3
 /\ Len(suffixReceipts)>=15 => LET q==suffixReceipts[15] IN
     /\ q.executed /\ q.before.checkpoint=1 /\ q.after.checkpoint=2
     /\ q.before.queue.head=1 /\ q.after.queue.head=2
     /\ q.after.landings[2]=[present |-> TRUE,generation |-> 1,parent |-> 1]
     /\ q.after.lastLanding=[present |-> TRUE,proofOrigin |-> 1,previousC |-> 1,terminal |-> 2,recordedParent |-> 1]
SuffixTerminalComplete ==
 /\ suffixIndex=16 /\ Len(suffixReceipts)=15
 /\ \A i \in 1..15 : suffixReceipts[i].enabled=(i#12) /\ suffixReceipts[i].executed=(i#12)
 /\ SuffixRawAudit /\ SuffixMilestoneAudit /\ SuffixCursorAudit /\ SuffixHashAudit
 /\ generation=1 /\ c=2 /\ startHeight=1 /\ recoveryNonce=1 /\ now=4 /\ produces=3 /\ stage=0
 /\ fi.head=2 /\ fi.tail=2 /\ fi.cursor=2 /\ fi.frontier=2 /\ fi.revenue=3
 /\ fi.queue=SuffixQueue(SuffixNewHash) /\ fi.landedCuts=[h \in 0..2 |-> h]
 /\ fi.blocks[<<0,1>>]=SuffixOld1 /\ fi.blocks[<<0,2>>]=SuffixOld2
 /\ fi.blocks[<<1,2>>]=SuffixNew2 /\ fi.blocks[<<0,2>>]#fi.blocks[<<1,2>>]
 /\ fi.cuts[<<0,1>>]=1 /\ fi.cuts[<<0,2>>]=2 /\ fi.cuts[<<1,1>>]=1 /\ fi.cuts[<<1,2>>]=2
 /\ fi.owners=[h \in 0..2 |-> IF h=2 THEN 1 ELSE 0]
 /\ observations.originParents[1]= <<0,1>> /\ observations.originCursors[1]=1
 /\ observations.starts[1]=1 /\ observations.origins[1]=3
 /\ observations.blanked=(IF suffixProfile="Blank" THEN {1} ELSE {})
 /\ observations.applied=[i \in 0..2 |-> IF i<2 THEN 1 ELSE 0]
 /\ observations.cashPaid=3
 /\ observations.admissions[0]=[present |-> TRUE,hash |-> "A",timestamp |-> 10,block |-> 0,beforeHead |-> 0,beforeTail |-> 0,charged |-> 1]
 /\ observations.admissions[1]=[present |-> TRUE,hash |-> "B",timestamp |-> 12,block |-> 1,beforeHead |-> 0,beforeTail |-> 1,charged |-> 2]
 /\ Cardinality(observations.produced)=3
 /\ \E u \in observations.produced : u.pair= <<0,1>> /\ u.parent= <<0,0>> /\ u.block=SuffixOld1
 /\ \E u \in observations.produced : u.pair= <<0,2>> /\ u.parent= <<0,1>> /\ u.block=SuffixOld2
 /\ \E u \in observations.produced : u.pair= <<1,2>> /\ u.parent= <<0,1>> /\ u.block=SuffixNew2
 /\ Cardinality({i \in 1..15 : suffixReceipts[i].executed /\ suffixReceipts[i].call="RecoverSuffix"})=1
 /\ Cardinality({i \in 1..15 : suffixReceipts[i].executed /\ suffixReceipts[i].call \in {"LandPrefix1","TryOldProof","LandReplacement2"}})=2
SuffixTerminalAudit == suffixIndex=16 => SuffixTerminalComplete
SuffixTerminalNotReached == ~SuffixTerminalComplete
=============================================================================
