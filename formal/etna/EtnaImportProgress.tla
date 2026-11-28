------------------------ MODULE EtnaImportProgress ------------------------
EXTENDS EtnaCheckpointImport
\* Conditional liveness companion; the safety model/actions remain unchanged.
VARIABLE progressEvent
progressAllVars == <<n, seen, event, progressEvent>>
\* Typed projection: genuine internal steps change one or more of these fields.
\* Avoid equality between the base model's Empty sentinel and store records.
progressVars == <<progressEvent, n.phase, n.staged, n.durable, n.published,
                 n.trusted, n.connected, n.targetReady, n.reached, n.crashes>>
ImportProgressInit == Init /\ n.input = Raw(0) /\ progressEvent = <<"Init", "">>
\* Put the primitive tag assignment first: ENABLED can construct a successor,
\* while temporal edge checks reject other actions before comparing store records.
ProgressCheck == progressEvent' = <<"Check", "">> /\ Check
ProgressStage(k) == progressEvent' = <<"Stage", k>> /\ Stage(k)
ProgressFlush(k) == progressEvent' = <<"Flush", k>> /\ Flush(k)
ProgressPublish == progressEvent' = <<"Publish", "">> /\ Publish
ProgressCrash == progressEvent' = <<"Crash", "">> /\ Crash
ProgressRestart == progressEvent' = <<"Restart", "">> /\ Restart
ProgressReadTarget == progressEvent' = <<"ReadTarget", "">> /\ ReadTarget
ProgressContinue == progressEvent' = <<"Continue", "">> /\ Continue
ProgressAdmit == progressEvent' = <<"Admit", "">> /\ Admit
ProgressConnect == progressEvent' = <<"Connect", "">> /\ Connect
\* Correct available input, fixed target/generation, optional existing bounded crash.
\* Continue retains its trusted normal-execution premise. No resource arrival,
\* Byzantine-input handling, generation changes or unconditional liveness claim.
ImportProgressNext == ProgressCheck \/
    (\E k \in StoreNames : ProgressStage(k) \/ ProgressFlush(k)) \/
    ProgressPublish \/ ProgressCrash \/ ProgressRestart \/ ProgressReadTarget \/
    ProgressContinue \/ ProgressAdmit \/ ProgressConnect
ImportProgressSpec ==
    /\ ImportProgressInit
    /\ [][ImportProgressNext]_progressAllVars
    /\ WF_progressVars(ProgressCheck)
    /\ \A k \in StoreNames : WF_progressVars(ProgressStage(k)) /\ WF_progressVars(ProgressFlush(k))
    /\ WF_progressVars(ProgressPublish) /\ WF_progressVars(ProgressRestart)
    /\ WF_progressVars(ProgressReadTarget) /\ WF_progressVars(ProgressContinue)
    /\ WF_progressVars(ProgressAdmit) /\ WF_progressVars(ProgressConnect)
\* Fairness uses the actual actions, not preserved unmutated copies or the result.
\* No fairness condition requires Crash. Its existing guard permits at most one.
ConditionalStableConnection == <>[]n.connected
=============================================================================
