----------------------- MODULE EtnaStopProofHandoff -----------------------
EXTENDS EtnaCandidateHandoff
ASSUME Scenarios # {} /\ Scenarios \subseteq StopHandoffPrograms
\* Additive selected product: actual public Stop/Rules/Recover and an opaque,
\* independent old proof. No proof producer, age clock or second landing engine.
VARIABLES stopProofQueue, stopProofPre, stopProofAttempt, stopProofCalls,
          stopProofTerminal
StopProofLocal == <<stopProofQueue, stopProofPre, stopProofAttempt,
                    stopProofCalls, stopProofTerminal>>
StopProofVars == <<HandoffVars, StopProofLocal>>
StopProofRaw == [checkpoint |-> c, generation |-> generation, origin |-> startHeight,
    nonce |-> recoveryNonce, now |-> now, authorization |-> authorization,
    proof |-> pendingProof, prefix |-> landings, lastLanding |-> lastLanding, audit |-> audit]
StopProofInit ==
    /\ HandoffInit
    /\ stopProofQueue = [present |-> FALSE] /\ stopProofPre = [present |-> FALSE]
    /\ stopProofAttempt = [present |-> FALSE] /\ stopProofCalls = <<>>
    /\ stopProofTerminal = [present |-> FALSE]
StopProofCall ==
    /\ (index < 2 \/ (held.present /\ stopProofPre.present))
    /\ CallStep /\ UNCHANGED StopProofLocal
StopProofInvoke ==
    /\ InvokeStep /\ stopProofCalls' = Append(stopProofCalls, receipt')
    /\ UNCHANGED <<stopProofQueue, stopProofPre, stopProofAttempt, stopProofTerminal>>
StopProofQueueOld ==
    /\ phase = "Ready" /\ index = 2 /\ held.present /\ ~pendingProof.present
    /\ PrepareProof(2)
    /\ stopProofQueue' = [present |-> TRUE, proof |-> pendingProof',
          checkpoint |-> c, generation |-> generation, origin |-> startHeight,
          prefix |-> landings, held |-> held.candidate, history |-> historyAudit]
    /\ UNCHANGED <<program, index, phase, schedule, history, historyAudit, originRecord,
                    call, receipt, supported, pending, candidateReceipt, waitSeen, retrySeen, event>>
    /\ UNCHANGED HandoffLocal
    /\ UNCHANGED <<stopProofPre, stopProofAttempt, stopProofCalls, stopProofTerminal>>
StopProofObservePre ==
    /\ phase = "Ready" /\ index = 2 /\ pendingProof.present /\ ~stopProofPre.present
    /\ stopProofPre' = [present |-> TRUE, proof |-> pendingProof,
          state |-> StopProofRaw, enabled |-> ENABLED Land(pendingProof)]
    /\ UNCHANGED HandoffVars
    /\ UNCHANGED <<stopProofQueue, stopProofAttempt, stopProofCalls, stopProofTerminal>>
StopProofAttemptOld ==
    /\ phase = "Ready" /\ index = 3 /\ pendingProof.present /\ ~stopProofAttempt.present
    \* Actual enabledness alone decides execution. No expected rejection guard.
    /\ LET enabled == ENABLED Land(pendingProof)
       IN /\ IF enabled THEN Land(pendingProof) ELSE UNCHANGED vars
          /\ stopProofAttempt' = [present |-> TRUE, proof |-> pendingProof,
                enabled |-> enabled, before |-> StopProofRaw, after |-> StopProofRaw']
          /\ proofReceipt' = [present |-> TRUE, proof |-> pendingProof,
                currentGeneration |-> generation, enabled |-> enabled]
    /\ UNCHANGED <<program, index, phase, schedule, history, historyAudit, originRecord,
                    call, receipt, supported, pending, candidateReceipt, waitSeen, retrySeen, event>>
    /\ UNCHANGED <<held, heldAudit, learnedFloor, trusted, appReply, retries, exposures,
                    supportAt, knowledgeAt, freshReceipt, freshAudit>>
    /\ UNCHANGED <<stopProofQueue, stopProofPre, stopProofCalls, stopProofTerminal>>
StopProofContinue ==
    /\ stopProofAttempt.present
    /\ (AuthenticateRecovery \/ RetryHeld \/ ExposeSignature \/ ObserveFresh)
    /\ UNCHANGED StopProofLocal
StopProofRecordTerminal ==
    /\ ~stopProofTerminal.present /\ stopProofAttempt.present /\ freshReceipt.present
    /\ knowledgeAt.present /\ 1 \in supported
    \* Workflow milestones only; expected results belong to the witness below.
    /\ \E r \in retries : r.currentGeneration = 1 /\ r.floor = 1 /\ 1 \in r.supported
    /\ \E r \in exposures : r.currentGeneration = 1 /\ r.floor = 1
    /\ stopProofTerminal' = [present |-> TRUE, program |-> program,
          queue |-> stopProofQueue, pre |-> stopProofPre, attempt |-> stopProofAttempt,
          calls |-> stopProofCalls, index |-> index, phase |-> phase,
          state |-> StopProofRaw, schedule |-> schedule, origin |-> originRecord,
          proofReceipt |-> proofReceipt,
          held |-> held, heldAudit |-> heldAudit, history |-> historyAudit,
          floor |-> learnedFloor, trusted |-> trusted, appReply |-> appReply,
          support |-> supported, supportAt |-> supportAt, knowledge |-> knowledgeAt,
          retries |-> retries, exposures |-> exposures, fresh |-> freshReceipt]
    /\ UNCHANGED HandoffVars
    /\ UNCHANGED <<stopProofQueue, stopProofPre, stopProofAttempt, stopProofCalls>>
StopProofNext ==
    (Setup /\ UNCHANGED HandoffLocal /\ UNCHANGED StopProofLocal) \/ StopProofCall \/ StopProofInvoke \/
    (Hold /\ UNCHANGED StopProofLocal) \/ StopProofQueueOld \/ StopProofObservePre \/
    StopProofAttemptOld \/ (InstallSupport /\ UNCHANGED StopProofLocal) \/
    StopProofContinue \/ StopProofRecordTerminal
StopProofSpec == StopProofInit /\ [][StopProofNext]_StopProofVars

\* Independent observers; never used to enable the queue, recovery or attempt.
StopProofQueueAudit == stopProofQueue.present =>
    /\ stopProofQueue.proof = [present |-> TRUE, generation |-> 0, parent |-> 1, terminal |-> 2]
    /\ pendingProof = stopProofQueue.proof
    /\ stopProofQueue.checkpoint = 1 /\ stopProofQueue.generation = 0 /\ stopProofQueue.origin = 0
    /\ stopProofQueue.prefix[1] = [present |-> TRUE, generation |-> 0, parent |-> 0]
    /\ stopProofQueue.held = heldAudit.candidate /\ stopProofQueue.history = heldAudit.history
StopProofPreAudit == stopProofPre.present =>
    /\ stopProofQueue.present /\ stopProofPre.proof = stopProofQueue.proof
    /\ stopProofPre.state.proof = stopProofQueue.proof /\ stopProofPre.state.checkpoint = 1
    /\ stopProofPre.state.generation = 0 /\ stopProofPre.state.origin = 0
    /\ stopProofPre.state.prefix = stopProofQueue.prefix /\ stopProofPre.enabled
StopProofCallsAudit ==
    /\ Len(stopProofCalls) = index
    /\ \A j \in 1..Len(stopProofCalls) :
          /\ stopProofCalls[j].accepted /\ stopProofCalls[j].index = j
          /\ stopProofCalls[j].program = program
          /\ stopProofCalls[j].operation = <<"Stop", "Rules", "Recover">>[j]
    /\ index = 3 =>
          /\ stopProofCalls[3].after.generation = 1 /\ stopProofCalls[3].after.checkpoint = 12
          /\ stopProofCalls[3].after.originHeight = 12 /\ stopProofCalls[3].after.nonce = 1
          /\ stopProofCalls[3].after.schedule.stopTime = 0 /\ stopProofCalls[3].after.schedule.stopGrid = 0
          /\ pendingProof = stopProofQueue.proof /\ landings = stopProofQueue.prefix
StopProofAttemptAudit == stopProofAttempt.present =>
    /\ stopProofPre.present /\ stopProofAttempt.proof = stopProofQueue.proof
    /\ stopProofAttempt.before.proof = stopProofQueue.proof
    /\ stopProofAttempt.before.checkpoint = 1 /\ stopProofAttempt.before.origin = 1
    /\ stopProofAttempt.before.generation = 1 /\ stopProofAttempt.before.nonce = 1
    /\ stopProofAttempt.before.prefix = stopProofQueue.prefix
    /\ stopProofAttempt.before.prefix[stopProofAttempt.proof.parent].present
    /\ ~stopProofAttempt.enabled => stopProofAttempt.after = stopProofAttempt.before
\* Focused source-fault profile selects only this audit, so an actual bad land
\* cannot be credited to a different inherited/public-state failure.
StopProofGenerationAudit == stopProofAttempt.present =>
    /\ stopProofAttempt.proof.generation = 0
    /\ stopProofAttempt.before.generation = 1
    /\ ~stopProofAttempt.enabled
StopProofTerminalComplete ==
    /\ stopProofTerminal.present
    /\ LET t == stopProofTerminal
           expected == IF t.program = "StopDueRecovery" THEN "Stop" ELSE "Accept"
       IN /\ t.index = 3 /\ t.phase = "Ready"
          /\ Len(t.calls) = 3 /\ \A j \in 1..3 : t.calls[j].accepted
          /\ t.calls[1].operation = "Stop" /\ t.calls[2].operation = "Rules" /\ t.calls[3].operation = "Recover"
          /\ t.calls[3].after.checkpoint = 12 /\ t.calls[3].after.generation = 1
          /\ t.calls[3].after.originHeight = 12 /\ t.calls[3].after.nonce = 1
          /\ t.queue.present /\ t.pre.present /\ t.attempt.present
          /\ t.queue.proof = [present |-> TRUE, generation |-> 0, parent |-> 1, terminal |-> 2]
          /\ t.pre.proof = t.queue.proof /\ t.pre.state.generation = 0
          /\ t.pre.state.checkpoint = 1 /\ t.pre.state.prefix = t.queue.prefix /\ t.pre.enabled
          /\ t.attempt.proof = t.queue.proof /\ t.attempt.before.generation = 1
          /\ t.attempt.before.checkpoint = 1 /\ t.attempt.before.origin = 1
          /\ t.attempt.before.prefix = t.queue.prefix /\ t.attempt.before.prefix[1].present
          /\ ~t.attempt.enabled /\ t.attempt.after = t.attempt.before
          /\ t.state.proof = t.queue.proof /\ t.state.checkpoint = 1
          /\ t.state.generation = 1 /\ t.state.origin = 1 /\ t.state.nonce = 1
          /\ t.state.prefix = t.queue.prefix /\ t.schedule.stopTime = 0 /\ t.schedule.stopGrid = 0
          /\ t.held.present /\ t.heldAudit.present
          /\ t.held.candidate = t.heldAudit.candidate
          /\ t.held.candidate = [timestamp |-> 3, parentHeight |-> IF t.program = "StopOffGridRecovery" THEN 13 ELSE 18,
                 parentTime |-> 2, anchor |-> 3, generation |-> 0]
          /\ t.held.anchor = t.heldAudit.history[3]
          /\ t.heldAudit.history = SubSeq(t.history, 1, 3) /\ Len(t.history) = 4
          /\ t.floor = 1 /\ ~t.trusted /\ ~t.appReply /\ t.knowledge.present /\ t.support = {0, 1, 2, 3}
          /\ \E r \in t.retries : r.candidate = t.heldAudit.candidate /\ r.currentGeneration = 1
                 /\ r.currentStop = 0 /\ r.floor = 1 /\ r.supported = t.support /\ r.result = expected
                 /\ r.stopped = (t.program = "StopDueRecovery") /\ r.fresh /\ r.selected = 1
          /\ \E r \in t.exposures : r.currentGeneration = 1 /\ r.floor = 1 /\ ~r.allowed
          /\ t.fresh.present /\ t.fresh.result = "Accept"
          /\ t.fresh.candidate = [timestamp |-> 3, parentHeight |-> 12, parentTime |-> 1, anchor |-> 4, generation |-> 1]
          /\ t.fresh.origin = [present |-> TRUE, height |-> 12, l1Block |-> 103, timestamp |-> 3]
          /\ t.origin = t.fresh.origin
          /\ t.proofReceipt = [present |-> TRUE, proof |-> t.queue.proof, currentGeneration |-> 1, enabled |-> FALSE]
          /\ t.fresh.anchor = t.history[4] /\ t.fresh.anchor.generation = 1
StopProofTerminalNotReached == ~StopProofTerminalComplete
StopProofSupportFirstNotReached == ~(StopProofTerminalComplete /\
    stopProofTerminal.knowledge.supported /\ stopProofTerminal.supportAt.floor = 0 /\
    stopProofTerminal.supportAt.index = 2)
StopProofKnowledgeFirstNotReached == ~(StopProofTerminalComplete /\
    ~stopProofTerminal.knowledge.supported /\ stopProofTerminal.supportAt.floor = 1)
=============================================================================
