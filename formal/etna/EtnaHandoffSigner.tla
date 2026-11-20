----------------------- MODULE EtnaHandoffSigner -----------------------
EXTENDS EtnaStopProofHandoff
CONSTANT SignerProfile
ASSUME /\ Scenarios = {"StopFutureRecovery"}
       /\ SignerProfile \in {"Computed", "Persisted", "Exposed"}
\* The actual signer owns DISTINCT variables; the inherited session stays revoked.
VARIABLES signerRunning, signerTrusted, signerConnected, signerCertain, signerActiveDomain, signerKnownFloor, signerDurableFloor, signerEverFloor, signerDurable, signerPhase, signerPending, signerReuse, signerRestarted, signerActualRequest, signerCrashRecord, signerWrites, signerReturned, signerNetwork, signerDelivered, signerFaults, signerEvent, signerStep, signerTrace
Signer == INSTANCE EtnaSignerCrash WITH
    MaxSlot <- 2, Payloads <- {"A", "B"}, SignatureSalts <- {0},
    PersistBeforeExpose <- TRUE, PreserveHRSOnCrash <- TRUE,
    PreserveGenerationFence <- TRUE, ReconnectAfterTrust <- TRUE,
    RejectConflicts <- TRUE, EchoRequest <- TRUE,
    running <- signerRunning,
    trusted <- signerTrusted,
    connected <- signerConnected,
    certain <- signerCertain,
    activeDomain <- signerActiveDomain,
    knownFloor <- signerKnownFloor,
    durableFloor <- signerDurableFloor,
    everFloor <- signerEverFloor,
    durable <- signerDurable,
    phase <- signerPhase,
    pending <- signerPending,
    reuse <- signerReuse,
    restarted <- signerRestarted,
    actualRequest <- signerActualRequest,
    crashRecord <- signerCrashRecord,
    writes <- signerWrites,
    returned <- signerReturned,
    network <- signerNetwork,
    delivered <- signerDelivered,
    faults <- signerFaults,
    event <- signerEvent
SignerVars == <<signerRunning, signerTrusted, signerConnected, signerCertain, signerActiveDomain, signerKnownFloor, signerDurableFloor, signerEverFloor, signerDurable, signerPhase, signerPending, signerReuse, signerRestarted, signerActualRequest, signerCrashRecord, signerWrites, signerReturned, signerNetwork, signerDelivered, signerFaults, signerEvent>>
SignerLocal == <<signerStep, signerTrace>>
HandoffSignerVars == <<StopProofVars, SignerVars, SignerLocal>>
SignerRaw == [running |-> signerRunning, trusted |-> signerTrusted,
    connected |-> signerConnected, domain |-> signerActiveDomain,
    known |-> signerKnownFloor, durableFloor |-> signerDurableFloor,
    ever |-> signerEverFloor, durable |-> signerDurable,
    phase |-> signerPhase, pending |-> signerPending, reuse |-> signerReuse,
    request |-> signerActualRequest, writes |-> signerWrites,
    returned |-> signerReturned, network |-> signerNetwork,
    delivered |-> signerDelivered, event |-> signerEvent]
\* Application approval is the real held/fresh Outcome; domain identity belongs
\* to the selected authenticated session premise, checked again by actual Request.
OldReply == held.present /\ held.candidate.generation = 0 /\ Outcome(held.candidate) = "Accept"
FreshReply == freshReceipt.present /\ freshReceipt.candidate.generation = 1 /\
              Outcome(freshReceipt.candidate) = "Accept"
HandoffSignerInit == /\ StopProofInit /\ Signer!Init /\ signerStep = 0 /\ signerTrace = <<>>
\* Receipt guards never encode expected denials. Optional attempts invoke the
\* unchanged action iff enabled, including idempotent repeated Expose events.
SignerReceipt(label, enabled) ==
    /\ signerTrace' = Append(signerTrace,
          [label |-> label, enabled |-> enabled, before |-> SignerRaw,
           after |-> SignerRaw', generation |-> generation, floor |-> learnedFloor,
           floorAfter |-> learnedFloor', oldReply |-> OldReply, freshReply |-> FreshReply])
    /\ signerStep' = signerStep + 1
SignerDo(action, label) ==
    /\ action /\ UNCHANGED StopProofVars /\ SignerReceipt(label, TRUE)
SignerAttempt(action, label) ==
    /\ UNCHANGED StopProofVars
    /\ LET enabled == ENABLED action
       IN /\ IF enabled THEN action ELSE UNCHANGED SignerVars
          /\ SignerReceipt(label, enabled)
SignerSkip(label) == /\ UNCHANGED SignerVars /\ UNCHANGED StopProofVars /\ SignerReceipt(label, FALSE)
\* Filter inherited Next only: no copied public/landing/acceptance engine.
\* Keep recovery behind actual prework, and forbid uncoupled local knowledge.
SignerHandoff ==
    /\ StopProofNext
    /\ (signerStep >= 6 \/ index < 2 \/ (index = 2 /\ phase = "Ready" /\ phase' = "Ready"))
    /\ UNCHANGED learnedFloor
    /\ UNCHANGED <<SignerVars, SignerLocal>>
SignerLearnRecovery ==
    /\ signerStep = 6 /\ stopProofAttempt.present /\ index = 3
    /\ Len(stopProofCalls) = 3 /\ stopProofCalls[3].operation = "Recover"
    /\ stopProofCalls[3].accepted
    /\ AuthenticateRecovery /\ Signer!AuthenticateRecovery
    /\ UNCHANGED StopProofLocal
    /\ SignerReceipt("Recovery", TRUE)
SignerProgram ==
    \/ /\ signerStep = 0
         /\ (index = 2 /\ phase = "Ready" /\ held.present /\ 1 \in supported /\ SignerDo(Signer!AuthenticateTrust(0), "OldTrust"))
    \/ /\ signerStep = 1
         /\ (SignerDo(Signer!Connect, "OldConnect"))
    \/ /\ signerStep = 2
         /\ (SignerDo(Signer!Request(0, 2, "A", 0, OldReply), "OldRequest"))
    \/ /\ signerStep = 3
         /\ (IF SignerProfile = "Computed" THEN SignerSkip("OldPersist") ELSE SignerDo(Signer!Persist, "OldPersist"))
    \/ /\ signerStep = 4
         /\ (IF SignerProfile = "Exposed" THEN SignerDo(Signer!Expose(OldReply), "OldExpose") ELSE SignerSkip("OldExpose"))
    \/ /\ signerStep = 5
         /\ (IF SignerProfile = "Exposed" THEN SignerDo(Signer!Request(0, 2, "A", 0, OldReply), "OldRetry") ELSE SignerSkip("OldRetry"))
    \/ /\ signerStep = 7
         /\ (SignerAttempt(Signer!Expose(OldReply), "RevokedExpose"))
    \/ /\ signerStep = 8
         /\ (SignerDo(Signer!Crash, "RecoveryCrash"))
    \/ /\ signerStep = 9
         /\ (SignerDo(Signer!Restart, "RecoveryRestart"))
    \/ /\ signerStep = 10
         /\ (SignerAttempt(Signer!AuthenticateTrust(0), "StaleTrust"))
    \/ /\ signerStep = 11
         /\ (SignerAttempt(Signer!Connect, "StaleConnect"))
    \/ /\ signerStep = 12
         /\ (SignerAttempt(Signer!Request(0, 2, "A", 0, OldReply), "StaleRequest"))
    \/ /\ signerStep = 13
         /\ (SignerAttempt(Signer!Persist, "StalePersist"))
    \/ /\ signerStep = 14
         /\ (SignerAttempt(Signer!Expose(OldReply), "StaleExpose"))
    \/ /\ signerStep = 15
         /\ (IF SignerProfile = "Exposed" THEN SignerDo(Signer!Deliver(Signer!Record(0, 2, "A", 0)), "DelayedDelivery") ELSE SignerSkip("DelayedDelivery"))
    \/ /\ signerStep = 16
         /\ (SignerDo(Signer!AuthenticateRecovery, "RefreshRecovery"))
    \/ /\ signerStep = 17
         /\ (freshReceipt.present /\ SignerDo(Signer!AuthenticateTrust(1), "FreshTrust"))
    \/ /\ signerStep = 18
         /\ (SignerDo(Signer!Connect, "FreshConnect"))
    \/ /\ signerStep = 19
         /\ (SignerDo(Signer!Request(1, 1, "A", 0, FreshReply), "FreshRequest1"))
    \/ /\ signerStep = 20
         /\ (SignerDo(Signer!Persist, "FreshPersist1"))
    \/ /\ signerStep = 21
         /\ (SignerDo(Signer!Expose(FreshReply), "FreshExpose1"))
    \/ /\ signerStep = 22
         /\ (SignerDo(Signer!Request(1, 2, "B", 0, FreshReply), "FreshRequest2"))
    \/ /\ signerStep = 23
         /\ (SignerDo(Signer!Persist, "FreshPersist2"))
    \/ /\ signerStep = 24
         /\ (SignerDo(Signer!Expose(FreshReply), "FreshExpose2"))
    \/ /\ signerStep = 25
         /\ (SignerDo(Signer!Crash, "FreshCrash"))
    \/ /\ signerStep = 26
         /\ (SignerDo(Signer!Restart, "FreshRestart"))
    \/ /\ signerStep = 27
         /\ (SignerDo(Signer!AuthenticateTrust(1), "RestartTrust"))
    \/ /\ signerStep = 28
         /\ (SignerDo(Signer!Connect, "RestartConnect"))
    \/ /\ signerStep = 29
         /\ (SignerAttempt(Signer!Request(1, 1, "B", 0, FreshReply), "RollbackRequest"))
    \/ /\ signerStep = 30
         /\ (SignerAttempt(Signer!Persist, "RollbackPersist"))
    \/ /\ signerStep = 31
         /\ (SignerAttempt(Signer!Expose(FreshReply), "RollbackExpose"))
HandoffSignerNext == SignerHandoff \/ SignerLearnRecovery \/ SignerProgram
HandoffSignerSpec == HandoffSignerInit /\ [][HandoffSignerNext]_HandoffSignerVars

\* Independent raw-event audits do not consult signer faults or expected gates.
SignerExposureLabels == {"OldExpose", "RevokedExpose", "StaleExpose", "FreshExpose1", "FreshExpose2", "RollbackExpose"}
SignerFloorExposureAudit == \A i \in 1..Len(signerTrace) :
    LET r == signerTrace[i]
    IN r.label \in SignerExposureLabels /\ r.enabled => r.before.pending.domain >= r.floor
SignerHRSExposureAudit == \A i \in 1..Len(signerTrace) :
    LET r == signerTrace[i]
    IN r.label \in SignerExposureLabels /\ r.enabled =>
       \A old \in r.before.returned : old.domain = r.before.pending.domain =>
          /\ old.slot <= r.before.pending.slot
          /\ old.slot = r.before.pending.slot => old = r.before.pending
SignerBridgeAudit ==
    /\ signerStep = Len(signerTrace) /\ signerStep \in 0..32
    /\ Signer!SignerTypeOK
    /\ signerEverFloor = learnedFloor
    /\ signerRunning => signerKnownFloor = learnedFloor
    /\ signerDurableFloor = learnedFloor
    /\ signerEverFloor = 1 => knowledgeAt.present /\ index = 3 /\ stopProofCalls[3].accepted
    /\ \A i \in 1..Len(signerTrace) :
       LET r == signerTrace[i]
       IN /\ ~r.enabled => r.before = r.after
          /\ r.label \in {"RecoveryCrash", "FreshCrash", "RecoveryRestart", "FreshRestart"} =>
               r.before.durable = r.after.durable
          /\ r.label \in SignerExposureLabels /\ r.enabled =>
               /\ r.before.pending = r.before.durable[r.before.pending.domain]
               /\ r.after.returned = r.before.returned \cup {r.before.pending}
               /\ r.after.network = r.before.network \cup {r.before.pending}
SignerTerminalComplete ==
    /\ signerStep = 32 /\ StopProofTerminalComplete
    /\ supportAt.index = 2 /\ supportAt.floor = 0 /\ knowledgeAt.supported
    /\ LET t == signerTrace
           old == [domain |-> 0, slot |-> 2, payload |-> "A", signature |-> <<0, 2, "A", 0>>]
           fresh1 == [domain |-> 1, slot |-> 1, payload |-> "A", signature |-> <<1, 1, "A", 0>>]
           fresh2 == [domain |-> 1, slot |-> 2, payload |-> "B", signature |-> <<1, 2, "B", 0>>]
       IN /\ \A i \in {1, 2, 3, 7, 9, 10, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29} : t[i].enabled
          /\ t[3].before.domain = 0 /\ t[3].oldReply /\ t[3].generation = 0
          /\ t[3].after.pending = old /\ t[3].after.phase = "Computed"
          /\ t[7].before.pending = old /\ t[7].generation = 1
          /\ t[7].before.phase = IF SignerProfile = "Computed" THEN "Computed" ELSE "Persisted"
          /\ t[7].floor = 0 /\ t[7].floorAfter = 1
          /\ t[7].after.known = 1 /\ t[7].after.durableFloor = 1
          /\ ~t[7].after.trusted /\ ~t[7].after.connected
          /\ t[10].after.known = 1 /\ t[10].after.durable = t[7].before.durable
          /\ \A i \in {8, 11, 12, 13, 14, 15, 30, 31, 32} : ~t[i].enabled /\ t[i].before = t[i].after
          /\ t[18].after.domain = 1 /\ t[18].after.trusted /\ t[19].after.connected
          /\ t[20].freshReply /\ t[20].after.pending = fresh1
          /\ t[21].after.durable[1] = fresh1 /\ t[22].after.returned = t[22].before.returned \cup {fresh1}
          /\ t[23].freshReply /\ t[23].after.pending = fresh2
          /\ t[24].after.durable[1] = fresh2 /\ t[25].after.returned = t[25].before.returned \cup {fresh2}
          /\ t[27].after.durable[1] = fresh2 /\ t[27].after.known = 1
          /\ signerDurable[1] = fresh2 /\ {fresh1, fresh2} \subseteq signerReturned
          /\ IF SignerProfile = "Computed"
                 THEN /\ ~t[4].enabled /\ t[7].before.writes = {} /\ t[7].before.durable[0].slot = 0
                 ELSE /\ t[4].enabled /\ t[7].before.durable[0] = old /\ old \in t[7].before.writes
          /\ IF SignerProfile = "Exposed"
                 THEN /\ t[5].enabled /\ t[6].enabled /\ t[6].after.reuse
                      /\ old \in t[7].before.returned /\ t[16].enabled /\ t[16].floor = 1
                      /\ old \in t[16].after.delivered /\ old \in signerDelivered
                 ELSE /\ ~t[5].enabled /\ ~t[6].enabled /\ ~t[16].enabled
                      /\ old \notin signerReturned
SignerTerminalNotReached == ~SignerTerminalComplete
=============================================================================
