----------------------- MODULE EtnaCandidateHandoff -----------------------
EXTENDS EtnaRulesSchedule
\* Thin bounded interface composition, not a client/consensus/proof refinement.
VARIABLES held, heldAudit, learnedFloor, trusted, appReply, retries, exposures,
          supportAt, knowledgeAt, proofReceipt, freshReceipt
HandoffLocal == <<held, heldAudit, learnedFloor, trusted, appReply, retries,
                  exposures, supportAt, knowledgeAt, proofReceipt, freshReceipt>>
HandoffVars == <<RulesVars, HandoffLocal>>
HandoffInit ==
    /\ RulesInit
    /\ held = [present |-> FALSE] /\ heldAudit = [present |-> FALSE]
    /\ learnedFloor = 0 /\ trusted = TRUE /\ appReply = TRUE
    /\ retries = {} /\ exposures = {}
    /\ supportAt = [index |-> 0, floor |-> 0]
    /\ knowledgeAt = [present |-> FALSE, supported |-> FALSE, previousFloor |-> 0]
    /\ proofReceipt = [present |-> FALSE] /\ freshReceipt = [present |-> FALSE]
Hold ==
    /\ phase = "Ready" /\ index = 1 /\ ~held.present
    /\ LET x == [timestamp |-> 2, parentHeight |-> 12, parentTime |-> 1,
                  anchor |-> Len(history), generation |-> generation]
       IN /\ held' = [present |-> TRUE, candidate |-> x,
                       anchor |-> history[x.anchor], cachedAllowed |-> trusted /\ appReply /\ learnedFloor = generation]
          /\ pending' = [present |-> TRUE, candidate |-> x]
    \* Observer capture is not consulted by any operational action.
    /\ heldAudit' = [present |-> TRUE, candidate |->
          [timestamp |-> 2, parentHeight |-> 12, parentTime |-> 1, anchor |-> 2, generation |-> 0],
          history |-> historyAudit, initialWait |-> Outcome(held'.candidate) = "Wait"]
    /\ event' = "Held"
    /\ UNCHANGED vars
    /\ UNCHANGED <<program, index, phase, schedule, history, historyAudit, originRecord,
                    call, receipt, supported, candidateReceipt, waitSeen, retrySeen>>
    /\ UNCHANGED <<learnedFloor, trusted, appReply, retries, exposures,
                    supportAt, knowledgeAt, proofReceipt, freshReceipt>>
CallStep ==
    /\ (index = 0 \/ (held.present /\ (program # "HandoffRecovery" \/ pendingProof.present)))
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
    /\ held.present /\ phase = "Ready" /\ index = 2
    /\ LET x == held.candidate
           r == [candidate |-> x, history |-> history, selected |-> Selected(x),
                 stopped |-> Stopped(x), fresh |-> HistoricalFresh(x), used |-> UsedSchedule(x),
                 result |-> Outcome(x), supported |-> supported, floor |-> learnedFloor]
       IN /\ r \notin retries /\ retries' = retries \cup {r}
    /\ UNCHANGED RulesVars
    /\ UNCHANGED <<held, heldAudit, learnedFloor, trusted, appReply, exposures,
                    supportAt, knowledgeAt, proofReceipt, freshReceipt>>
\* Session stays generation zero. Authentication revokes trust; software support
\* does not create a new authenticated signing session.
LiveAuthorization == held.candidate.generation = 0 /\ trusted /\ appReply /\ learnedFloor <= 0
ExposeSignature ==
    /\ held.present /\ phase = "Ready" /\ index = 2 /\ Outcome(held.candidate) = "Accept"
    /\ LET r == [floor |-> learnedFloor, trusted |-> trusted, appReply |-> appReply,
                 session |-> 0, candidateGeneration |-> held.candidate.generation,
                 allowed |-> IF Mutant = "CachedAuthorization" THEN held.cachedAllowed ELSE LiveAuthorization]
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
    /\ phase = "Ready" /\ index = 2 /\ generation = 1 /\ ~freshReceipt.present
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
    /\ heldAudit.initialWait
HistoricalDerivation == \A r \in retries :
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
=============================================================================
