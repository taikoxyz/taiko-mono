---------------------------- MODULE EtnaAppCrash ----------------------------
EXTENDS Naturals, TLC
\* Comet v0.40.0 0880b4d378f347ab16e54ec677ff50d803f37d62 ordering.
\* Independent process-durable stores; no power-loss or actual client refinement.
CONSTANTS InitialHeight, MaxBlocks, CorrectInfo, IdempotentEffects,
          StableResponse, DurableCommit, RequireSavedResponse, EnforceInitialGap
Blocks == 1..MaxBlocks
Counts == 0..MaxBlocks
ASSUME /\ InitialHeight \in {1, 5} /\ MaxBlocks \in 1..2
       /\ {CorrectInfo, IdempotentEffects, StableResponse, DurableCommit,
             RequireSavedResponse, EnforceInitialGap} \subseteq BOOLEAN
ActualHeight(k) == IF k = 0 THEN 0 ELSE InitialHeight + k - 1
RECURSIVE EffectSum(_, _)
EffectSum(effects, k) == IF k = 0 THEN 0 ELSE effects[k] + EffectSum(effects, k - 1)
CanonicalHash(k) == IF k = 0 THEN <<"Origin", InitialHeight - 1>>
                     ELSE <<"EL", ActualHeight(k), k>>
ActualELHash(k, effects) == IF k = 0 THEN CanonicalHash(0)
                           ELSE <<"EL", ActualHeight(k), EffectSum(effects, k)>>
EmptyResponse == [present |-> FALSE, appHash |-> CanonicalHash(0),
                   txResults |-> "Fixed", validators |-> <<"Empty">>]
Response(k, hash, replay) ==
    [present |-> TRUE, appHash |-> hash, txResults |-> "Fixed",
     validators |-> IF ~StableResponse /\ replay
                     THEN <<"WrongUpdates", k>> ELSE <<"Updates", k>>]
ResponseType == {EmptyResponse} \cup
    {[present |-> TRUE, appHash |-> <<"EL", ActualHeight(k), effects>>,
       txResults |-> "Fixed", validators |-> <<tag, k>>] : k \in Blocks,
       effects \in 0..(2 * MaxBlocks), tag \in {"Updates", "WrongUpdates"}}
ReceiptType == [block : Blocks,
                 elHash : {<<"EL", ActualHeight(k), total>> :
                             k \in Blocks, total \in 0..(2 * MaxBlocks)},
                 balance : 0..(2 * MaxBlocks)]

VARIABLES running, ready, phase, store, comet, appCommitted,
          elVol, elDur, volEffects, durEffects, responseStore, memResponse,
          work, reportedCount, infoValid, infoHash, initHash, cometResponse,
          responseHistory, commitReceipts, responseReadable, faults, event
vars == <<running, ready, phase, store, comet, appCommitted,
          elVol, elDur, volEffects, durEffects, responseStore, memResponse,
          work, reportedCount, infoValid, infoHash, initHash, cometResponse,
          responseHistory, commitReceipts, responseReadable, faults, event>>
Init ==
    /\ running = TRUE /\ ready = TRUE /\ phase = "Idle"
    /\ store = 0 /\ comet = 0 /\ appCommitted = 0 /\ elVol = 0 /\ elDur = 0
    /\ volEffects = [b \in Blocks |-> 0] /\ durEffects = volEffects
    /\ responseStore = [b \in Blocks |-> EmptyResponse] /\ memResponse = EmptyResponse
    /\ work = 0 /\ reportedCount = 0 /\ infoValid = FALSE
    /\ infoHash = CanonicalHash(0) /\ initHash = CanonicalHash(0)
    /\ cometResponse = EmptyResponse /\ responseHistory = {} /\ commitReceipts = {}
    /\ responseReadable = TRUE
    /\ faults = [mockWithoutResponse |-> FALSE, bypassedGap |-> FALSE]
    /\ event = "None"
StoreNextBlock ==
    /\ running /\ ready /\ phase = "Idle" /\ store = comet
    /\ store < MaxBlocks /\ store' = store + 1 /\ work' = store + 1
    /\ ready' = FALSE /\ phase' = "Finalize" /\ event' = "StoredBlock"
    /\ UNCHANGED <<running, comet, appCommitted, elVol, elDur, volEffects, durEffects,
          responseStore, memResponse, reportedCount, infoValid, infoHash, initHash,
          cometResponse, responseHistory, commitReceipts, responseReadable, faults>>
FinalizeEffect ==
    /\ running /\ phase = "Finalize" /\ work \in Blocks
    /\ work <= elVol + 1
    /\ (IdempotentEffects \/ volEffects[work] < 2)
    /\ elVol' = IF work > elVol THEN work ELSE elVol
    /\ volEffects' = IF work > elVol \/ ~IdempotentEffects
                       THEN [volEffects EXCEPT ![work] = @ + 1] ELSE volEffects
    /\ memResponse' = Response(work, ActualELHash(work, volEffects'), work <= elVol)
    /\ phase' = "ReturnFinalize" /\ event' = "ELExecuted"
    /\ UNCHANGED <<running, ready, store, comet, appCommitted, elDur, durEffects,
          responseStore, work, reportedCount, infoValid, infoHash, initHash,
          cometResponse, responseHistory, commitReceipts, responseReadable, faults>>
FlushEL ==
    /\ running /\ (elDur # elVol \/ durEffects # volEffects)
    /\ elDur' = elVol /\ durEffects' = volEffects /\ event' = "ELFlushed"
    /\ UNCHANGED <<running, ready, phase, store, comet, appCommitted, elVol, volEffects,
          responseStore, memResponse, work, reportedCount, infoValid, infoHash, initHash,
          cometResponse, responseHistory, commitReceipts, responseReadable, faults>>
ReturnFinalize ==
    /\ running /\ phase = "ReturnFinalize"
    /\ responseHistory' = responseHistory \cup {[block |-> work, response |-> memResponse]}
    /\ phase' = "SaveResponse" /\ event' = "FinalizeReturned"
    /\ UNCHANGED <<running, ready, store, comet, appCommitted, elVol, elDur,
          volEffects, durEffects, responseStore, memResponse, work, reportedCount,
          infoValid, infoHash, initHash, cometResponse, commitReceipts, responseReadable, faults>>
SaveResponse ==
    /\ running /\ phase = "SaveResponse"
    /\ responseStore' = [responseStore EXCEPT ![work] = memResponse]
    /\ phase' = "Commit" /\ event' = "ResponseSaved"
    /\ UNCHANGED <<running, ready, store, comet, appCommitted, elVol, elDur,
          volEffects, durEffects, memResponse, work, reportedCount, infoValid, infoHash,
          initHash, cometResponse, responseHistory, commitReceipts, responseReadable, faults>>
WriteCommit ==
    /\ running /\ phase = "Commit"
    /\ (~DurableCommit \/ elDur >= work)
    /\ appCommitted' = work
    /\ commitReceipts' = commitReceipts \cup
          {[block |-> work, elHash |-> ActualELHash(work, durEffects),
              balance |-> EffectSum(durEffects, work)]}
    /\ phase' = "CommitAck" /\ event' = "CommitWritten"
    /\ UNCHANGED <<running, ready, store, comet, elVol, elDur, volEffects, durEffects,
          responseStore, memResponse, work, reportedCount, infoValid, infoHash, initHash,
          cometResponse, responseHistory, responseReadable, faults>>
ReturnCommit ==
    /\ running /\ phase = "CommitAck" /\ phase' = "SaveComet" /\ event' = "CommitReturned"
    /\ UNCHANGED <<running, ready, store, comet, appCommitted, elVol, elDur,
          volEffects, durEffects, responseStore, memResponse, work, reportedCount,
          infoValid, infoHash, initHash, cometResponse, responseHistory,
          commitReceipts, responseReadable, faults>>
SaveComet ==
    /\ running /\ phase = "SaveComet"
    /\ comet' = work /\ cometResponse' = memResponse
    /\ phase' = "Idle" /\ ready' = TRUE /\ event' = "CometSaved"
    /\ UNCHANGED <<running, store, appCommitted, elVol, elDur, volEffects, durEffects,
          responseStore, memResponse, work, reportedCount, infoValid, infoHash, initHash,
          responseHistory, commitReceipts, responseReadable, faults>>

Crash ==
    /\ running /\ running' = FALSE /\ ready' = FALSE /\ phase' = "Down"
    /\ event' = IF phase = "CommitAck" THEN "CrashCommitBeforeAck"
                  ELSE IF elDur > appCommitted THEN "CrashELBeforeCommit" ELSE "Crash"
    /\ elVol' = elDur /\ volEffects' = durEffects
    /\ memResponse' = EmptyResponse /\ work' = 0 /\ infoValid' = FALSE
    /\ UNCHANGED <<store, comet, appCommitted, elDur, durEffects, responseStore,
          reportedCount, infoHash, initHash, cometResponse, responseHistory,
          commitReceipts, responseReadable, faults>>
Restart ==
    /\ ~running /\ running' = TRUE /\ phase' = "Info" /\ ready' = FALSE /\ event' = "Restart"
    /\ UNCHANGED <<store, comet, appCommitted, elVol, elDur, volEffects, durEffects,
          responseStore, memResponse, work, reportedCount, infoValid, infoHash, initHash,
          cometResponse, responseHistory, commitReceipts, responseReadable, faults>>
Info ==
    /\ running /\ phase = "Info" /\ elDur >= appCommitted
    /\ reportedCount' = IF CorrectInfo THEN appCommitted ELSE elDur
    /\ infoHash' = ActualELHash(reportedCount', durEffects)
    /\ infoValid' = TRUE /\ phase' = "Handshake" /\ event' = "InfoReturned"
    \* InitChain always returns fixed origin hash, even when EL is already ahead.
    /\ initHash' = IF reportedCount' = 0 THEN CanonicalHash(0) ELSE initHash
    /\ UNCHANGED <<running, ready, store, comet, appCommitted, elVol, elDur,
          volEffects, durEffects, responseStore, memResponse, work, cometResponse,
          responseHistory, commitReceipts, responseReadable, faults>>
Handshake ==
    /\ running /\ phase = "Handshake"
    /\ LET gap == ActualHeight(store) > ActualHeight(comet) + 1
       IN /\ faults' = [faults EXCEPT !.bypassedGap = @ \/ (gap /\ ~EnforceInitialGap)]
          /\ work' = store
          /\ phase' = IF gap /\ EnforceInitialGap THEN "KnownGapStop"
                       ELSE IF store = comet THEN "Idle"
                       ELSE IF reportedCount = store THEN "MockReplay" ELSE "Finalize"
          /\ ready' = (phase' = "Idle")
          /\ event' = IF gap /\ EnforceInitialGap THEN "KnownFirstGap" ELSE "Handshake"
    /\ UNCHANGED <<running, store, comet, appCommitted, elVol, elDur, volEffects,
          durEffects, responseStore, memResponse, reportedCount, infoValid, infoHash,
          initHash, cometResponse, responseHistory, commitReceipts, responseReadable>>
MockReplay ==
    /\ running /\ phase = "MockReplay" /\ work \in Blocks
    /\ LET saved == responseReadable /\ responseStore[work].present
       IN /\ faults' = [faults EXCEPT !.mockWithoutResponse = @ \/ (~saved /\ ~RequireSavedResponse)]
          /\ phase' = IF ~saved /\ RequireSavedResponse THEN "MissingResponseStop" ELSE "SaveComet"
          /\ memResponse' = IF saved THEN responseStore[work]
                              ELSE Response(work, CanonicalHash(work), FALSE)
          /\ event' = IF ~saved /\ RequireSavedResponse THEN "MissingResponseStop" ELSE "MockReplay"
    /\ UNCHANGED <<running, ready, store, comet, appCommitted, elVol, elDur,
          volEffects, durEffects, responseStore, work, reportedCount, infoValid,
          infoHash, initHash, cometResponse, responseHistory, commitReceipts, responseReadable>>
ReadAvailability(available) ==
    /\ responseReadable' = available /\ event' = "None"
    /\ UNCHANGED <<running, ready, phase, store, comet, appCommitted, elVol, elDur,
          volEffects, durEffects, responseStore, memResponse, work, reportedCount,
          infoValid, infoHash, initHash, cometResponse, responseHistory, commitReceipts, faults>>
Next == \/ StoreNextBlock \/ FinalizeEffect \/ FlushEL \/ ReturnFinalize \/ SaveResponse
        \/ WriteCommit \/ ReturnCommit \/ SaveComet \/ Crash \/ Restart \/ Info
        \/ Handshake \/ MockReplay \/ \E available \in BOOLEAN : ReadAvailability(available)
AppSpec == Init /\ [][Next]_vars
AppTypeOK ==
    /\ {running, ready, infoValid, responseReadable} \subseteq BOOLEAN
    /\ {store, comet, appCommitted, elVol, elDur, work, reportedCount} \subseteq Counts
    /\ volEffects \in [Blocks -> 0..2] /\ durEffects \in [Blocks -> 0..2]
    /\ responseStore \in [Blocks -> ResponseType] /\ memResponse \in ResponseType
    /\ cometResponse \in ResponseType
    /\ responseHistory \subseteq [block : Blocks, response : ResponseType]
    /\ commitReceipts \subseteq ReceiptType
    /\ phase \in {"Idle", "Finalize", "ReturnFinalize", "SaveResponse", "Commit", "CommitAck",
          "SaveComet", "Down", "Info", "Handshake", "MockReplay", "KnownGapStop", "MissingResponseStop"}
    /\ infoHash \in {CanonicalHash(0)} \cup
          {<<"EL", ActualHeight(k), effects>> : k \in Blocks, effects \in 0..(2 * MaxBlocks)}
    /\ initHash = CanonicalHash(0)
    /\ faults \in [mockWithoutResponse : BOOLEAN, bypassedGap : BOOLEAN]
    /\ event \in {"None", "StoredBlock", "ELExecuted", "ELFlushed", "FinalizeReturned",
          "ResponseSaved", "CommitWritten", "CommitReturned", "CometSaved", "CrashCommitBeforeAck",
          "CrashELBeforeCommit", "Crash", "Restart", "InfoReturned", "KnownFirstGap", "Handshake",
          "MissingResponseStop", "MockReplay"}
ELStateMatchesExecutedPrefix ==
    /\ elDur <= elVol /\ elVol <= store
    /\ \A b \in Blocks : volEffects[b] = (IF b <= elVol THEN 1 ELSE 0)
    /\ \A b \in Blocks : durEffects[b] = (IF b <= elDur THEN 1 ELSE 0)
CommitBackedByDurableEL == appCommitted <= elDur
CommitReceiptsCanonical == \A r \in commitReceipts :
    r.elHash = CanonicalHash(r.block) /\ r.balance = r.block
InfoNeverAheadOfCommit == infoValid => reportedCount <= appCommitted
InfoHashMatchesCommittedEL == infoValid =>
    (reportedCount <= elDur /\ infoHash = ActualELHash(reportedCount, durEffects))
FinalizeResponsesStable == \A r \in responseHistory :
    /\ r.response.appHash = CanonicalHash(r.block)
    /\ r.response.txResults = "Fixed"
    /\ r.response.validators = <<"Updates", r.block>>
CometNeverAheadOfApp == comet <= appCommitted
CometResponseCanonical == comet > 0 =>
    (cometResponse.appHash = CanonicalHash(comet) /\ cometResponse.txResults = "Fixed" /\
      cometResponse.validators = <<"Updates", comet>>)
ReadyStoresAgree == ready => (running /\ store = comet /\ comet = appCommitted)
NoMockWithoutSavedResponse == ~faults.mockWithoutResponse
StockHandshakeGapEnforced == ~faults.bypassedGap
ELReplayWindowNotReached == event # "CrashELBeforeCommit"
DurableCommitNoAckNotReached == event # "CrashCommitBeforeAck"
MockReplayNotReached == event # "MockReplay"
KnownFirstBlockStopNotReached == event # "KnownFirstGap"
=============================================================================
