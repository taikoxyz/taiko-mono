----------------------- MODULE EtnaCandidateHandoff -----------------------
EXTENDS EtnaRulesSchedule
\* Thin bounded interface composition, not a client/consensus/proof refinement.
VARIABLES held, heldAudit, learnedFloor, trusted, appReply, retries, exposures,
          supportAt, knowledgeAt, proofReceipt, freshReceipt
HandoffLocal == <<held, heldAudit, learnedFloor, trusted, appReply, retries,
                  exposures, supportAt, knowledgeAt, proofReceipt, freshReceipt>>
HandoffVars == <<RulesVars, HandoffLocal>>
StopProfile == program \in StopHandoffPrograms
HoldIndex == IF StopProfile THEN 2 ELSE 1
FinalIndex == Len(Programs(program))
RetryReady == phase = "Ready" /\ IF StopProfile THEN index >= HoldIndex ELSE index = FinalIndex
HandoffInit ==
    /\ RulesInit
    /\ held = [present |-> FALSE] /\ heldAudit = [present |-> FALSE]
    /\ learnedFloor = 0 /\ trusted = TRUE /\ appReply = TRUE
    /\ retries = {} /\ exposures = {}
    /\ supportAt = [index |-> 0, floor |-> 0]
    /\ knowledgeAt = [present |-> FALSE, supported |-> FALSE, previousFloor |-> 0]
    /\ proofReceipt = [present |-> FALSE] /\ freshReceipt = [present |-> FALSE]
Hold ==
    /\ phase = "Ready" /\ index = HoldIndex /\ ~held.present
    /\ LET x == [timestamp |-> IF StopProfile THEN 3 ELSE 2,
                  parentHeight |-> IF program = "StopOffGridRecovery" THEN 13 ELSE IF StopProfile THEN 18 ELSE 12,
                  parentTime |-> IF StopProfile THEN 2 ELSE 1,
                  anchor |-> Len(history), generation |-> generation]
       IN /\ held' = [present |-> TRUE, candidate |-> x,
                       anchor |-> history[x.anchor], cachedAllowed |-> trusted /\ appReply /\ learnedFloor = generation]
          /\ pending' = [present |-> TRUE, candidate |-> x]
    \* Observer capture is not consulted by any operational action.
    /\ heldAudit' = [present |-> TRUE, candidate |->
          [timestamp |-> IF program \in {"StopDueRecovery", "StopFutureRecovery", "StopOffGridRecovery"} THEN 3 ELSE 2,
           parentHeight |-> CASE program = "StopOffGridRecovery" -> 13
                              [] program \in {"StopDueRecovery", "StopFutureRecovery"} -> 18 [] OTHER -> 12,
           parentTime |-> IF program \in {"StopDueRecovery", "StopFutureRecovery", "StopOffGridRecovery"} THEN 2 ELSE 1,
           anchor |-> IF program \in {"StopDueRecovery", "StopFutureRecovery", "StopOffGridRecovery"} THEN 3 ELSE 2,
           generation |-> 0],
          history |-> historyAudit, initialResult |-> Outcome(held'.candidate)]
    /\ event' = "Held"
    /\ UNCHANGED vars
    /\ UNCHANGED <<program, index, phase, schedule, history, historyAudit, originRecord,
                    call, receipt, supported, candidateReceipt, waitSeen, retrySeen>>
    /\ UNCHANGED <<learnedFloor, trusted, appReply, retries, exposures,
                    supportAt, knowledgeAt, proofReceipt, freshReceipt>>
CallStep ==
    /\ (index < HoldIndex \/ (held.present /\ (program # "HandoffRecovery" \/ pendingProof.present)))
    /\ PrepareCall /\ UNCHANGED HandoffLocal
InvokeStep ==
    /\ Invoke
    /\ held' = IF held.present /\ Mutant = "RelabelHeld"
         THEN [held EXCEPT !.candidate.generation = generation']
         ELSE IF held.present /\ Mutant = "RelabelAnchor"
         THEN [held EXCEPT !.candidate.anchor = Len(history'), !.anchor = history'[Len(history')]]
         ELSE held
    /\ UNCHANGED <<heldAudit, learnedFloor, trusted, appReply, retries, exposures,
                    supportAt, knowledgeAt, proofReceipt, freshReceipt>>
InstallSupport ==
    /\ UpgradeSupport
    /\ supportAt' = [index |-> index, floor |-> learnedFloor]
    /\ UNCHANGED <<held, heldAudit, learnedFloor, trusted, appReply, retries,
                    exposures, knowledgeAt, proofReceipt, freshReceipt>>
AuthenticateRecovery ==
    /\ held.present /\ generation > learnedFloor
    /\ learnedFloor' = generation /\ trusted' = FALSE /\ appReply' = FALSE
    /\ knowledgeAt' = [present |-> TRUE, supported |-> 1 \in supported, previousFloor |-> learnedFloor]
    /\ UNCHANGED RulesVars
    /\ UNCHANGED <<held, heldAudit, retries, exposures, supportAt, proofReceipt, freshReceipt>>
HistoricalFresh(x) ==
    LET t == IF Mutant = "CurrentClock" THEN now ELSE x.timestamp
    IN history[x.anchor].timestamp <= t /\ t <= history[x.anchor].timestamp + M
RetryHeld ==
    /\ held.present /\ RetryReady
    /\ LET x == held.candidate
           r == [candidate |-> x, history |-> history, selected |-> Selected(x),
                 stopped |-> Stopped(x), fresh |-> HistoricalFresh(x), used |-> UsedSchedule(x),
                 result |-> Outcome(x), supported |-> supported, floor |-> learnedFloor,
                 currentGeneration |-> generation, currentStop |-> schedule.stopTime]
       IN /\ r \notin retries /\ retries' = retries \cup {r}
    /\ UNCHANGED RulesVars
    /\ UNCHANGED <<held, heldAudit, learnedFloor, trusted, appReply, exposures,
                    supportAt, knowledgeAt, proofReceipt, freshReceipt>>
\* Session stays generation zero. Authentication revokes trust; software support
\* does not create a new authenticated signing session.
LiveAuthorization == held.candidate.generation = 0 /\ trusted /\ appReply /\ learnedFloor <= 0
ExposeSignature ==
    /\ held.present /\ RetryReady
    /\ Outcome(held.candidate) = "Accept" \/ (StopProfile /\ Stopped(held.candidate))
    /\ LET r == [floor |-> learnedFloor, trusted |-> trusted, appReply |-> appReply,
                 session |-> 0, candidateGeneration |-> held.candidate.generation,
                 candidate |-> held.candidate, result |-> Outcome(held.candidate), supported |-> supported,
                 currentGeneration |-> generation,
                 allowed |-> (IF Mutant = "CachedAuthorization" THEN held.cachedAllowed ELSE LiveAuthorization)
                              /\ (~StopProfile \/ ~Stopped(held.candidate))]
       IN /\ r \notin exposures /\ exposures' = exposures \cup {r}
    /\ UNCHANGED RulesVars
    /\ UNCHANGED <<held, heldAudit, learnedFloor, trusted, appReply, retries,
                    supportAt, knowledgeAt, proofReceipt, freshReceipt>>
QueueProof ==
    /\ program = "HandoffRecovery" /\ phase = "Ready" /\ index = 1
    /\ held.present /\ ~pendingProof.present /\ PrepareProof(2)
    /\ UNCHANGED <<program, index, phase, schedule, history, historyAudit, originRecord,
                    call, receipt, supported, pending, candidateReceipt, waitSeen, retrySeen, event>>
    /\ UNCHANGED HandoffLocal
ObserveProof ==
    /\ phase = "Ready" /\ index = 2 /\ pendingProof.present /\ ~proofReceipt.present
    /\ proofReceipt' = [present |-> TRUE, proof |-> pendingProof, currentGeneration |-> generation,
                           enabled |-> ENABLED Land(pendingProof)]
    /\ UNCHANGED RulesVars
    /\ UNCHANGED <<held, heldAudit, learnedFloor, trusted, appReply, retries, exposures,
                    supportAt, knowledgeAt, freshReceipt>>
ObserveFresh ==
    /\ phase = "Ready" /\ index = FinalIndex /\ generation = 1 /\ ~freshReceipt.present
    /\ LET x == [timestamp |-> now + 1, parentHeight |-> H(startHeight), parentTime |-> now,
                  anchor |-> Len(history), generation |-> generation]
       IN /\ ValidCandidate(x) /\ Outcome(x) = "Accept"
          /\ freshReceipt' = [present |-> TRUE, candidate |-> x, anchor |-> history[x.anchor],
                                result |-> Outcome(x)]
    /\ UNCHANGED RulesVars
    /\ UNCHANGED <<held, heldAudit, learnedFloor, trusted, appReply, retries, exposures,
                    supportAt, knowledgeAt, proofReceipt>>
HandoffNext == (Setup /\ UNCHANGED HandoffLocal) \/ CallStep \/ InvokeStep \/ Hold \/
    InstallSupport \/ AuthenticateRecovery \/ RetryHeld \/ ExposeSignature \/ QueueProof \/
    ObserveProof \/ ObserveFresh
HandoffSpec == HandoffInit /\ [][HandoffNext]_HandoffVars

HeldIdentity == held.present =>
    /\ held.candidate = heldAudit.candidate
    /\ held.anchor = heldAudit.history[heldAudit.candidate.anchor]
    /\ heldAudit.history = SubSeq(historyAudit, 1, Len(heldAudit.history))
HistoricalDerivation ==
    /\ held.present => heldAudit.initialResult = IF ExpectedStop(heldAudit) THEN "Stop" ELSE "Wait"
    /\ \A r \in retries :
        LET original == [candidate |-> heldAudit.candidate, history |-> heldAudit.history]
            x == heldAudit.candidate
            a == heldAudit.history[x.anchor]
        IN /\ r.candidate = x /\ r.used = a.schedule
           /\ r.selected = ExpectedRule(original) /\ r.stopped = ExpectedStop(original)
           /\ r.fresh = (a.timestamp <= x.timestamp /\ x.timestamp <= a.timestamp + 1)
           /\ r.result = IF ExpectedStop(original) THEN "Stop"
                           ELSE IF ExpectedRule(original) \in r.supported THEN "Accept" ELSE "Wait"
SignatureFence == \A r \in exposures : r.allowed =>
    /\ r.trusted /\ r.appReply /\ r.floor <= r.session /\ r.candidateGeneration = r.session
\* Independent raw retained inputs, never the operational Stopped helper/current schedule.
StoppedSignatureFence == \A r \in exposures : r.allowed =>
    /\ ~ExpectedStop(heldAudit)
    /\ ExpectedRule(heldAudit) \in r.supported
StopCleared == StopProfile /\ generation = 1 => schedule.stopTime = 0 /\ schedule.stopGrid = 0
KnowledgeMonotone == knowledgeAt.present =>
    /\ learnedFloor >= knowledgeAt.previousFloor /\ learnedFloor = 1 /\ ~trusted /\ ~appReply
ProofGenerationFence == proofReceipt.present =>
    (proofReceipt.proof.generation # proofReceipt.currentGeneration => ~proofReceipt.enabled)
FreshIdentity == freshReceipt.present =>
    /\ freshReceipt.candidate.generation = 1 /\ freshReceipt.anchor.generation = 1
    /\ freshReceipt.anchor.timestamp >= 3 /\ freshReceipt.candidate.anchor # heldAudit.candidate.anchor
HoldBeforeCallNotReached == ~(held.present /\ index = 1 /\ phase = "Ready")
RetryAfterCallNotReached == ~(held.present /\ index = 2 /\ retries # {})
WaitAfterCallNotReached == ~(\E r \in retries : r.result = "Wait")
SupportBeforeRecoveryNotReached == ~(generation = 1 /\ supportAt.index = 1 /\
    \E r \in retries : r.result = "Accept")
SupportBeforeKnowledgeNotReached == ~(generation = 1 /\ supportAt.index = 2 /\
    knowledgeAt.present /\ knowledgeAt.supported /\ \E r \in retries : r.result = "Accept")
KnowledgeBeforeSupportNotReached == ~(knowledgeAt.present /\ ~knowledgeAt.supported /\
    supportAt.floor = 1 /\ \E r \in retries : r.result = "Accept")
RecoveryRefusalNotReached == ~(\E r \in exposures : r.floor = 1 /\ ~r.allowed)
PreKnowledgeSignatureNotReached == ~(generation = 1 /\ \E r \in exposures : r.floor = 0 /\ r.allowed)
PastSignaturePreservedNotReached == ~(learnedFloor = 1 /\ \E r \in exposures : r.floor = 0 /\ r.allowed)
ProofRefusalNotReached == ~(proofReceipt.present /\ ~proofReceipt.enabled)
FreshRecoveryNotReached == ~freshReceipt.present
StopHoldNotReached == ~(StopProfile /\ held.present /\ phase = "Ready" /\ index = 2)
HistoricalStopAfterRecoveryNotReached == ~(generation = 1 /\ \E r \in retries :
    r.currentGeneration = 1 /\ r.currentStop = 0 /\ r.stopped /\ r.result = "Stop")
StopBeforeSupportNotReached == ~(\E r \in retries : r.currentGeneration = 1 /\ r.stopped /\ r.supported = {0})
StopAfterSupportNotReached == ~(\E r \in retries : r.currentGeneration = 1 /\ r.stopped /\ 1 \in r.supported)
LegalWaitNotReached == ~(\E r \in retries : ~r.stopped /\ r.result = "Wait")
LegalAcceptAfterRecoveryNotReached == ~(\E r \in retries : r.currentGeneration = 1 /\
    r.currentStop = 0 /\ ~r.stopped /\ r.result = "Accept")
StopRefusalNotReached == ~(\E r \in exposures : r.currentGeneration = 1 /\ r.floor = 0 /\ r.trusted /\
    1 \in r.supported /\ r.result = "Stop" /\ ~r.allowed)
StopSupportBeforeRecoveryNotReached == ~(generation = 1 /\ supportAt.index = 2 /\
    \E r \in retries : r.currentGeneration = 1 /\ 1 \in r.supported)
StopSupportBeforeKnowledgeNotReached == ~(generation = 1 /\ supportAt.index = 3 /\
    knowledgeAt.present /\ knowledgeAt.supported /\ \E r \in retries : 1 \in r.supported)
StopKnowledgeBeforeSupportNotReached == ~(knowledgeAt.present /\ ~knowledgeAt.supported /\
    supportAt.floor = 1 /\ \E r \in retries : 1 \in r.supported)
\* Bind these new-profile witnesses to the exposure's generation, not a later
\* global state that could retain only an earlier, pre-recovery signature.
StopPreKnowledgeSignatureNotReached == ~(generation = 1 /\ \E r \in exposures :
    r.currentGeneration = 1 /\ r.floor = 0 /\ r.allowed)
StopPastSignaturePreservedNotReached == ~(learnedFloor = 1 /\ \E r \in exposures :
    r.currentGeneration = 1 /\ r.floor = 0 /\ r.allowed)
=============================================================================
