------------------------- MODULE EtnaRulesSchedule -------------------------
EXTENDS EtnaSettlement, Sequences, FiniteSets
\* SPEC d183572; Inbox 89f419. Accepted recovery invokes inherited Recover.
CONSTANTS Scenarios, ExploreCandidates, Mutant
S == 6
K == 6
M == 1
CancelTime == 99
H(h) == S + K * h
ZeroSchedule == [activeRules |-> 0, nextRules |-> 0, rulesTime |-> 0,
                 stopTime |-> 0, stopGrid |-> 0]
StopHandoffPrograms == {"StopDueRecovery", "StopFutureRecovery", "StopOffGridRecovery"}
\* Raw public-call fixtures only; all three execute the original public actions.
StopHandoffProgram(stopAt) ==
    LET context == [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]
        args == [rules |-> 0, time |-> 0, grid |-> 0, expectedGeneration |-> 0,
                 expectedC |-> 12, expectedRecoveryNonce |-> 0, validUntil |-> 6]
    IN <<[operation |-> "Stop", at |-> 1, args |-> [args EXCEPT !.time = stopAt, !.grid = 12], context |-> context],
         [operation |-> "Rules", at |-> 2, args |-> [args EXCEPT !.rules = 1, !.time = 3], context |-> context],
         [operation |-> "Recover", at |-> 3, args |-> [args EXCEPT !.rules = 2], context |-> context]>>
Programs(id) == CASE
    id \in StopHandoffPrograms -> StopHandoffProgram(IF id = "StopFutureRecovery" THEN 3 ELSE 2)
 []
    "Earliest" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 2, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Stop", at |-> 2, args |-> [rules |-> 0, time |-> 3, grid |-> 6, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "Reschedule" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 5, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Rules", at |-> 2, args |-> [rules |-> 1, time |-> 6, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Rules", at |-> 3, args |-> [rules |-> 1, time |-> 99, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Rules", at |-> 4, args |-> [rules |-> 2, time |-> 5, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RulesLock" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 3, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Rules", at |-> 2, args |-> [rules |-> 1, time |-> 4, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RuleNumber" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 2, time |-> 3, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "Promote" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 2, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Rules", at |-> 2, args |-> [rules |-> 2, time |-> 4, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "HandoffRecovery" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 2, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Recover", at |-> 3, args |-> [rules |-> 2, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 12, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "PromotionRevert" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 2, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Rules", at |-> 2, args |-> [rules |-> 3, time |-> 4, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "StopCancel" = id -> <<[operation |-> "Stop", at |-> 1, args |-> [rules |-> 0, time |-> 5, grid |-> 6, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Stop", at |-> 2, args |-> [rules |-> 0, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "StopLock" = id -> <<[operation |-> "Stop", at |-> 1, args |-> [rules |-> 0, time |-> 3, grid |-> 6, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Stop", at |-> 2, args |-> [rules |-> 0, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "StopReached" = id -> <<[operation |-> "Stop", at |-> 1, args |-> [rules |-> 0, time |-> 2, grid |-> 6, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "BadStop" = id -> <<[operation |-> "Stop", at |-> 1, args |-> [rules |-> 0, time |-> 2, grid |-> 7, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "BadZeroStop" = id -> <<[operation |-> "Stop", at |-> 1, args |-> [rules |-> 0, time |-> 0, grid |-> 6, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "TooEarly" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 1, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "NotOwner" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 3, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> FALSE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "Uninitialized" = id -> <<[operation |-> "Stop", at |-> 1, args |-> [rules |-> 0, time |-> 3, grid |-> 6, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> FALSE, registryUnlocked |-> TRUE, startWritten |-> FALSE]]>>
 [] "RecoveryZero" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 5, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Stop", at |-> 2, args |-> [rules |-> 0, time |-> 4, grid |-> 12, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Recover", at |-> 3, args |-> [rules |-> 0, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 12, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RecoveryNew" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 5, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Stop", at |-> 2, args |-> [rules |-> 0, time |-> 4, grid |-> 12, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Recover", at |-> 3, args |-> [rules |-> 2, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 12, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RecoveryNumber" = id -> <<[operation |-> "Rules", at |-> 1, args |-> [rules |-> 1, time |-> 5, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Recover", at |-> 2, args |-> [rules |-> 3, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 12, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RecoveryExpired" = id -> <<[operation |-> "Recover", at |-> 2, args |-> [rules |-> 0, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 12, expectedRecoveryNonce |-> 0, validUntil |-> 1], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RecoveryNonce" = id -> <<[operation |-> "Recover", at |-> 2, args |-> [rules |-> 0, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 12, expectedRecoveryNonce |-> 1, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RecoveryCheckpoint" = id -> <<[operation |-> "Recover", at |-> 2, args |-> [rules |-> 0, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RecoveryGeneration" = id -> <<[operation |-> "Recover", at |-> 2, args |-> [rules |-> 0, time |-> 0, grid |-> 0, expectedGeneration |-> 1, expectedC |-> 12, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RecoveryStop" = id -> <<[operation |-> "Recover", at |-> 2, args |-> [rules |-> 1, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 12, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]], [operation |-> "Stop", at |-> 3, args |-> [rules |-> 0, time |-> 4, grid |-> 12, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> TRUE]]>>
 [] "RecoveryNoStart" = id -> <<[operation |-> "Recover", at |-> 1, args |-> [rules |-> 0, time |-> 0, grid |-> 0, expectedGeneration |-> 0, expectedC |-> 6, expectedRecoveryNonce |-> 0, validUntil |-> 6], context |-> [owner |-> TRUE, initialized |-> TRUE, registryUnlocked |-> TRUE, startWritten |-> FALSE]]>>
NeedsLanding(id) == id \in {"RecoveryZero", "RecoveryNew", "RecoveryNumber", "RecoveryExpired",
                             "RecoveryNonce", "RecoveryCheckpoint", "RecoveryGeneration", "RecoveryStop", "HandoffRecovery"}
                    \cup StopHandoffPrograms
Context(x) == [owner |-> x.context.owner, initialized |-> x.context.initialized,
              registryUnlocked |-> x.context.registryUnlocked, startWritten |-> x.context.startWritten,
              timestamp |-> x.at, l1Block |-> 100 + x.at]
VARIABLES program, index, phase, schedule, history, historyAudit, originRecord, call, receipt,
          supported, pending, candidateReceipt, waitSeen, retrySeen, event
SetupProjection == [etnaStart |-> S, gridInterval |-> K, maxAnchorAge |-> M,
    cancellationSentinel |-> CancelTime, seededLanding |-> NeedsLanding(program),
    initialized |-> Programs(program)[1].context.initialized,
    startWritten |-> Programs(program)[1].context.startWritten,
    originL1Block |-> 100, originTimestamp |-> 0]
RulesVars == <<vars, program, index, phase, schedule, history, historyAudit, originRecord, call, receipt,
               supported, pending, candidateReceipt, waitSeen, retrySeen, event>>
Snapshot(t, sch, g, o) ==
    [timestamp |-> t, schedule |-> IF Mutant = "WrongHistory" THEN ZeroSchedule ELSE sch,
     generation |-> g, origin |-> o]
AppendSnapshot(old, t, sch, g, o) ==
    LET extended == Append(old, Snapshot(t, sch, g, o))
    IN IF Mutant = "SkipHistoryAppend" THEN old
       ELSE IF Mutant = "CorruptRetainedHistory" /\ Len(old) > 1
         THEN [extended EXCEPT ![2].schedule = ZeroSchedule] ELSE extended
PublicHeight(h) == IF call.context.startWritten THEN H(h) ELSE 0
StateOf(sch, g, nonce, cut, o, record) ==
    [schedule |-> sch, generation |-> g, nonce |-> nonce, checkpoint |-> PublicHeight(cut),
     originHeight |-> PublicHeight(o), origin |-> record]
RawState == StateOf(schedule, generation, recoveryNonce, c, startHeight, originRecord)
EmptyCandidate == [timestamp |-> 1, parentHeight |-> S, parentTime |-> 0, anchor |-> 1]
RulesInit ==
    /\ Init /\ program \in Scenarios /\ index = 0 /\ phase = "Setup"
    /\ schedule = ZeroSchedule
    /\ history = <<Snapshot(0, ZeroSchedule, 0,
          IF Programs(program)[1].context.startWritten THEN S ELSE 0)>>
    /\ historyAudit = <<[timestamp |-> 0,
          schedule |-> [activeRules |-> 0, nextRules |-> 0, rulesTime |-> 0, stopTime |-> 0, stopGrid |-> 0],
          generation |-> 0, origin |-> IF Programs(program)[1].context.startWritten THEN 6 ELSE 0]>>
    /\ originRecord = IF Programs(program)[1].context.startWritten
         THEN [present |-> TRUE, height |-> S, l1Block |-> 100, timestamp |-> 0]
         ELSE [present |-> FALSE, height |-> 0, l1Block |-> 0, timestamp |-> 0]
    /\ call = Programs(program)[1] /\ receipt = [present |-> FALSE, schemaVersion |-> 1]
    /\ supported = {0} /\ pending = [present |-> FALSE, candidate |-> EmptyCandidate]
    /\ candidateReceipt = [present |-> FALSE] /\ waitSeen = FALSE /\ retrySeen = FALSE
    /\ event = "Init"
Setup ==
    /\ phase = "Setup"
    /\ IF NeedsLanding(program) THEN LandFresh(1) ELSE UNCHANGED vars
    /\ phase' = "Ready" /\ event' = "Setup"
    /\ UNCHANGED <<program, index, schedule, history, historyAudit, originRecord, call, receipt,
                    supported, pending, candidateReceipt, waitSeen, retrySeen>>
PrepareCall ==
    /\ phase = "Ready" /\ index < Len(Programs(program))
    /\ LET x == Programs(program)[index + 1]
       IN /\ x.at >= now /\ now' = x.at /\ call' = x
          /\ authorization' = [present |-> x.operation = "Recover", generation |-> x.args.expectedGeneration,
                checkpoint |-> (x.args.expectedC - S) \div K, nonce |-> x.args.expectedRecoveryNonce,
                deadline |-> x.args.validUntil]
    /\ phase' = "Call" /\ event' = "Prepared"
    /\ UNCHANGED <<c, generation, recoveryNonce, startHeight, pendingProof, landings, lastLanding, audit>>
    /\ UNCHANGED <<program, index, schedule, history, historyAudit, originRecord, receipt,
                    supported, pending, candidateReceipt, waitSeen, retrySeen>>
Allowed(sch, x) ==
    /\ (x.context.owner \/ Mutant = "OwnerBypass")
    /\ (x.context.initialized \/ Mutant = "InitBypass") /\ x.context.registryUnlocked
    /\ CASE x.operation = "Rules" ->
              /\ now >= sch.rulesTime \/
                 (IF Mutant = "RulesEquality" THEN now + M <= sch.rulesTime ELSE now + M < sch.rulesTime)
              /\ x.args.rules \in {sch.nextRules, sch.nextRules + 1}
              /\ x.args.time >= now + M
         [] x.operation = "Stop" ->
              /\ sch.stopTime = 0 \/
                 (IF Mutant = "StopEquality" THEN now + M <= sch.stopTime ELSE now + M < sch.stopTime)
              /\ (x.args.time = 0 /\ x.args.grid = 0) \/
                 (x.args.time >= now + M /\ x.args.grid > 0 /\ x.args.grid % K = 0)
         [] OTHER ->
              /\ x.context.startWritten
              /\ x.args.expectedGeneration = generation /\ x.args.expectedC = H(c)
              /\ x.args.expectedRecoveryNonce = recoveryNonce /\ now <= x.args.validUntil
              /\ generation < MaxGeneration /\ recoveryNonce < MaxNonce
              /\ x.args.rules = 0 \/ x.args.rules = sch.nextRules + 1 \/ Mutant = "RecoveryNumber"
Changed(sch, x) == CASE
    x.operation = "Rules" -> [sch EXCEPT !.activeRules = IF now >= sch.rulesTime THEN sch.nextRules ELSE @,
                               !.nextRules = x.args.rules, !.rulesTime = x.args.time]
 [] x.operation = "Stop" -> [sch EXCEPT !.stopTime = x.args.time, !.stopGrid = x.args.grid]
 [] OTHER -> [sch EXCEPT !.stopTime = 0, !.stopGrid = 0,
                !.activeRules = IF x.args.rules = 0 THEN @ ELSE x.args.rules,
                !.nextRules = IF x.args.rules = 0 THEN @ ELSE x.args.rules,
                !.rulesTime = IF x.args.rules = 0 THEN @ ELSE 0]
Written(sch, x, ok) ==
    LET updated == IF ok THEN Changed(sch, x) ELSE sch
    IN CASE Mutant = "PersistPromotion" /\ ~ok /\ x.operation = "Rules" /\ now >= sch.rulesTime ->
                [sch EXCEPT !.activeRules = sch.nextRules]
       [] Mutant = "WrongSchedule" /\ ok -> [updated EXCEPT !.nextRules = @ + 1]
       [] Mutant = "LosePending" /\ ok /\ x.operation = "Recover" /\ x.args.rules = 0 ->
                [updated EXCEPT !.activeRules = 0, !.nextRules = 0, !.rulesTime = 0]
       [] Mutant = "RetainStop" /\ ok /\ x.operation = "Recover" ->
                [updated EXCEPT !.stopTime = sch.stopTime, !.stopGrid = sch.stopGrid]
       [] OTHER -> updated
EventPayload(sch, ok) == [present |-> ok, reserved16 |-> 0,
    limbs |-> <<sch.activeRules, IF Mutant = "WrongEvent" THEN sch.nextRules + 1 ELSE sch.nextRules,
                sch.rulesTime, sch.stopTime, sch.stopGrid>>]
Invoke ==
    /\ phase = "Call"
    /\ LET ok == Allowed(schedule, call)
       IN /\ IF ok /\ call.operation = "Recover" THEN Recover ELSE UNCHANGED vars
          /\ schedule' = Written(schedule, call, ok)
          /\ originRecord' = IF ok /\ call.operation = "Recover"
               THEN [present |-> TRUE, height |-> IF Mutant = "WrongOrigin" THEN S ELSE H(c),
                     l1Block |-> 100 + now, timestamp |-> now] ELSE originRecord
          /\ receipt' = [schemaVersion |-> 1, present |-> TRUE, program |-> program, index |-> index + 1,
               setup |-> SetupProjection, operation |-> call.operation,
               args |-> IF Mutant = "RewriteArguments" THEN [call.args EXCEPT !.rules = @ + 1] ELSE call.args,
               context |-> Context(call),
               before |-> RawState,
               after |-> StateOf(schedule', generation', recoveryNonce', c', startHeight', originRecord'),
               accepted |-> ok, scheduleEvent |-> EventPayload(schedule', ok)]
          /\ history' = AppendSnapshot(history, now, schedule', generation', PublicHeight(startHeight'))
          \* Observe actual public writes independently; never construct this with Snapshot.
          /\ historyAudit' = Append(historyAudit,
              [timestamp |-> call.at, schedule |-> receipt'.after.schedule,
               generation |-> receipt'.after.generation, origin |-> receipt'.after.originHeight])
    /\ index' = index + 1 /\ phase' = "Ready" /\ event' = "Called"
    /\ UNCHANGED <<program, call, supported, pending, candidateReceipt, waitSeen, retrySeen>>
AdvanceL1 ==
    /\ phase = "Ready" /\ index = Len(Programs(program)) /\ now < MaxTime
    /\ now' = now + 1
    /\ history' = AppendSnapshot(history, now', schedule, generation, PublicHeight(startHeight))
    /\ historyAudit' = Append(historyAudit,
          [timestamp |-> now + 1,
           schedule |-> [activeRules |-> schedule.activeRules, nextRules |-> schedule.nextRules,
                         rulesTime |-> schedule.rulesTime, stopTime |-> schedule.stopTime, stopGrid |-> schedule.stopGrid],
           generation |-> generation, origin |-> originRecord.height])
    /\ event' = "L1Advanced"
    /\ UNCHANGED <<c, generation, recoveryNonce, startHeight, authorization,
                    pendingProof, landings, lastLanding, audit>>
    /\ UNCHANGED <<program, index, phase, schedule, originRecord, call, receipt,
                    supported, pending, candidateReceipt, waitSeen, retrySeen>>
CandidateHeights == {h \in {S, S + 1, S + K, S + K + 1, S + 2*K} : h >= H(startHeight)}
Candidates == UNION {UNION {
    [timestamp : {t}, parentHeight : CandidateHeights, parentTime : 0..(t - 1), anchor : {a}] :
        t \in {z \in 1..(MaxTime + 1) : history[a].timestamp <= z /\ z <= history[a].timestamp + M}} :
        a \in {j \in 1..Len(history) : history[j].generation = generation}}
ValidCandidate(x) ==
    /\ x.parentTime < x.timestamp /\ x.parentHeight >= H(startHeight)
    /\ history[x.anchor].generation = generation
    /\ history[x.anchor].timestamp <= x.timestamp /\ x.timestamp <= history[x.anchor].timestamp + M
UsedSchedule(x) == IF Mutant = "LatestAnchor" THEN schedule ELSE history[x.anchor].schedule
Selected(x) ==
    LET sch == UsedSchedule(x)
        t == IF Mutant = "L1Clock" THEN now ELSE x.timestamp
        due == IF Mutant = "StrictActivation" THEN t > sch.rulesTime ELSE t >= sch.rulesTime
    IN (IF due THEN sch.nextRules ELSE sch.activeRules) + (IF Mutant = "WrongSelected" THEN 1 ELSE 0)
Stopped(x) ==
    LET sch == UsedSchedule(x)
        height == IF Mutant = "CandidateStop" THEN x.parentHeight + 1 ELSE x.parentHeight
        time == IF Mutant = "CandidateStop" THEN x.timestamp ELSE x.parentTime
        origin == IF Mutant = "RecoveryOrigin" THEN H(startHeight) ELSE S
    IN IF sch.stopTime = 0 THEN FALSE
       ELSE (height - origin) % sch.stopGrid = 0 /\ time >= sch.stopTime
Outcome(x) == IF Stopped(x) THEN "Stop"
              ELSE IF Selected(x) \notin supported /\ Mutant # "IgnoreSupport" THEN "Wait" ELSE "Accept"
ObserveCandidate(x, retry) ==
    /\ ExploreCandidates /\ phase = "Ready" /\ index = Len(Programs(program))
    /\ (~candidateReceipt.present \/ (retry /\ ~retrySeen))
    /\ x \in Candidates /\ ValidCandidate(x)
    /\ candidateReceipt' = [present |-> TRUE, candidate |-> x, history |-> history, observedCount |-> Len(history),
          l1Now |-> now, latest |-> schedule, generation |-> generation,
          selected |-> Selected(x), stopped |-> Stopped(x), result |-> Outcome(x),
          used |-> UsedSchedule(x), supported |-> supported]
    /\ pending' = IF Outcome(x) = "Wait" THEN [present |-> TRUE, candidate |-> x] ELSE pending
    /\ waitSeen' = (waitSeen \/ Outcome(x) = "Wait")
    /\ retrySeen' = (retrySeen \/ (retry /\ Outcome(x) = "Accept"))
    /\ event' = "Candidate"
    /\ UNCHANGED vars
    /\ UNCHANGED <<program, index, phase, schedule, history, historyAudit, originRecord, call, receipt, supported>>
UpgradeSupport ==
    /\ ExploreCandidates /\ supported = {0} /\ pending.present
    /\ supported' = {0, 1, 2, 3} /\ event' = "Supported"
    /\ UNCHANGED vars
    /\ UNCHANGED <<program, index, phase, schedule, history, historyAudit, originRecord, call, receipt,
                    pending, candidateReceipt, waitSeen, retrySeen>>
RulesNext == Setup \/ PrepareCall \/ Invoke \/ AdvanceL1 \/ UpgradeSupport \/
    (\E x \in Candidates : ObserveCandidate(x, FALSE)) \/
    (pending.present /\ ObserveCandidate(pending.candidate, TRUE))
RulesSpec == RulesInit /\ [][RulesNext]_RulesVars
PublicAttempt == receipt

\* Independent observer formulas use receipt input/prestate, never Allowed/Changed/Written.
ExpectedAccept(r) ==
    LET a == r.args
        x == r.context
        b == r.before
        s == b.schedule
    IN /\ x.owner /\ x.initialized /\ x.registryUnlocked
       /\ CASE r.operation = "Rules" ->
                    /\ (x.timestamp >= s.rulesTime \/ x.timestamp + 1 < s.rulesTime)
                    /\ (a.rules = s.nextRules \/ a.rules = s.nextRules + 1)
                    /\ a.time >= x.timestamp + 1
             [] r.operation = "Stop" ->
                    /\ (s.stopTime = 0 \/ x.timestamp + 1 < s.stopTime)
                    /\ ((a.time = 0 /\ a.grid = 0) \/
                        (a.time >= x.timestamp + 1 /\ a.grid > 0 /\ a.grid % 6 = 0))
             [] OTHER ->
                    /\ x.startWritten /\ a.expectedGeneration = b.generation
                    /\ a.expectedC = b.checkpoint /\ a.expectedRecoveryNonce = b.nonce
                    /\ x.timestamp <= a.validUntil /\ b.generation < MaxGeneration /\ b.nonce < MaxNonce
                    /\ a.rules = 0 \/ a.rules = s.nextRules + 1
ExpectedAfter(r) ==
    LET b == r.before
        a == r.args
        s == b.schedule
    IN IF ~ExpectedAccept(r) THEN b
       ELSE CASE r.operation = "Rules" ->
              [b EXCEPT !.schedule = [activeRules |-> IF r.context.timestamp < s.rulesTime
                                                       THEN s.activeRules ELSE s.nextRules,
                 nextRules |-> a.rules, rulesTime |-> a.time, stopTime |-> s.stopTime, stopGrid |-> s.stopGrid]]
         [] r.operation = "Stop" -> [b EXCEPT !.schedule.stopTime = a.time, !.schedule.stopGrid = a.grid]
         [] OTHER -> [b EXCEPT !.generation = @ + 1, !.nonce = @ + 1,
              !.originHeight = b.checkpoint,
              !.origin = [present |-> TRUE, height |-> b.checkpoint, l1Block |-> r.context.l1Block, timestamp |-> r.context.timestamp],
              !.schedule = [activeRules |-> IF a.rules = 0 THEN s.activeRules ELSE a.rules,
                  nextRules |-> IF a.rules = 0 THEN s.nextRules ELSE a.rules,
                  rulesTime |-> IF a.rules = 0 THEN s.rulesTime ELSE 0, stopTime |-> 0, stopGrid |-> 0]]
RulesTypeOK ==
    /\ TypeOK /\ program \in Scenarios /\ index \in 0..Len(Programs(program))
    /\ phase \in {"Setup", "Ready", "Call"}
    /\ schedule \in [activeRules : 0..4, nextRules : 0..4, rulesTime : (0..6) \cup {CancelTime},
                      stopTime : 0..6, stopGrid : {0, 6, 12}]
    /\ supported \subseteq 0..3 /\ Len(history) >= 1
\* Observation-only audit is never consulted by operational enablement or writes.
HistoryProvenance ==
    /\ history = historyAudit
    /\ historyAudit[Len(historyAudit)].schedule = schedule
    /\ historyAudit[Len(historyAudit)].generation = generation
    /\ historyAudit[Len(historyAudit)].origin = originRecord.height
    /\ phase # "Call" => historyAudit[Len(historyAudit)].timestamp = now
    /\ candidateReceipt.present =>
          /\ candidateReceipt.observedCount = Len(candidateReceipt.history)
          /\ candidateReceipt.observedCount <= Len(historyAudit)
          /\ candidateReceipt.history = SubSeq(historyAudit, 1, candidateReceipt.observedCount)
PublicCallCorrect == receipt.present => receipt.accepted = ExpectedAccept(receipt)
PublicStateCorrect == receipt.present =>
    /\ receipt.after = ExpectedAfter(receipt)
    /\ phase = "Ready" => receipt.after = RawState
OriginalCallPreserved == receipt.present =>
    LET original == Programs(program)[receipt.index]
    IN /\ receipt.args = original.args /\ receipt.operation = original.operation
       /\ receipt.context = [owner |-> original.context.owner, initialized |-> original.context.initialized,
            registryUnlocked |-> original.context.registryUnlocked, startWritten |-> original.context.startWritten,
            timestamp |-> original.at, l1Block |-> 100 + original.at]
ScheduleEventCorrect == receipt.present =>
    /\ receipt.scheduleEvent.present = receipt.accepted
    /\ receipt.scheduleEvent.reserved16 = 0
    /\ receipt.accepted => receipt.scheduleEvent.limbs =
        <<receipt.after.schedule.activeRules, receipt.after.schedule.nextRules, receipt.after.schedule.rulesTime,
          receipt.after.schedule.stopTime, receipt.after.schedule.stopGrid>>
ExpectedRule(r) ==
    LET x == r.candidate
        s == r.history[x.anchor].schedule
    IN IF x.timestamp >= s.rulesTime THEN s.nextRules ELSE s.activeRules
ExpectedStop(r) ==
    LET x == r.candidate
        s == r.history[x.anchor].schedule
    IN IF s.stopTime = 0 THEN FALSE ELSE (x.parentHeight - 6) % s.stopGrid = 0 /\ x.parentTime >= s.stopTime
CandidateCorrect == candidateReceipt.present =>
    /\ candidateReceipt.used = candidateReceipt.history[candidateReceipt.candidate.anchor].schedule
    /\ candidateReceipt.selected = ExpectedRule(candidateReceipt)
    /\ candidateReceipt.stopped = ExpectedStop(candidateReceipt)
    /\ candidateReceipt.result = IF ExpectedStop(candidateReceipt) THEN "Stop"
          ELSE IF ExpectedRule(candidateReceipt) \in candidateReceipt.supported THEN "Accept" ELSE "Wait"
AnchorAgreement == candidateReceipt.present =>
    LET r == candidateReceipt
        x == r.candidate
        alternatives == {j \in 1..Len(r.history) : r.history[j].generation = r.generation /\
            r.history[j].timestamp <= x.timestamp /\ x.timestamp <= r.history[j].timestamp + 1}
    IN \A j \in alternatives :
        /\ ExpectedRule([r EXCEPT !.candidate.anchor = j]) = ExpectedRule(r)
        /\ ExpectedStop([r EXCEPT !.candidate.anchor = j]) = ExpectedStop(r)
EarliestNotReached == ~(receipt.present /\ receipt.accepted /\ receipt.operation = "Rules" /\
                         receipt.args.time = receipt.context.timestamp + 1)
LockNotReached == ~(receipt.present /\ ~receipt.accepted /\ receipt.operation = "Rules" /\
                    receipt.context.timestamp + 1 = receipt.before.schedule.rulesTime)
CancelNotReached == ~(receipt.present /\ receipt.accepted /\ receipt.after.schedule.rulesTime = CancelTime)
PromotionNotReached == ~(receipt.present /\ receipt.accepted /\ receipt.operation = "Rules" /\
                         receipt.after.schedule.activeRules > receipt.before.schedule.activeRules)
ZeroRecoveryNotReached == ~(receipt.present /\ receipt.accepted /\ receipt.operation = "Recover" /\
    receipt.args.rules = 0 /\ receipt.after.schedule.nextRules > receipt.after.schedule.activeRules)
NewRecoveryNotReached == ~(receipt.present /\ receipt.accepted /\ receipt.operation = "Recover" /\ receipt.args.rules > 0)
HistoricalRuleNotReached == ~(candidateReceipt.present /\
    candidateReceipt.used # candidateReceipt.latest /\ candidateReceipt.selected #
      (IF candidateReceipt.candidate.timestamp >= candidateReceipt.latest.rulesTime
         THEN candidateReceipt.latest.nextRules ELSE candidateReceipt.latest.activeRules))
StopNotReached == ~(candidateReceipt.present /\ candidateReceipt.result = "Stop")
RetryNotReached == ~retrySeen
RecoveryResumeNotReached == ~(candidateReceipt.present /\ candidateReceipt.generation = 1 /\ candidateReceipt.result = "Accept")
=============================================================================
