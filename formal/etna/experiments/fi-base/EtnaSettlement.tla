-------------------------- MODULE EtnaSettlement --------------------------
EXTENDS Naturals, TLC

\* Source: Etna SPEC.md, d18357214fab30ea512ae9858a11699806d72ba1.
\* This finite model checks transaction ordering, not proof/consensus soundness.
CONSTANTS MaxHeight, MaxGeneration, MaxNonce, MaxTime,
          CheckCheckpoint, CheckNonce, CheckDeadline, CheckProofGeneration

ASSUME /\ MaxHeight >= 2 /\ MaxGeneration >= 1
       /\ MaxNonce >= 2 /\ MaxTime >= 1
       /\ {CheckCheckpoint, CheckNonce, CheckDeadline, CheckProofGeneration}
             \subseteq BOOLEAN

VARIABLES c, generation, recoveryNonce, startHeight, now,
          authorization, pendingProof, landings, lastLanding, audit

vars == <<c, generation, recoveryNonce, startHeight, now,
          authorization, pendingProof, landings, lastLanding, audit>>

AuthorizationType == [present : BOOLEAN, generation : 0..MaxGeneration,
                      checkpoint : 0..MaxHeight, nonce : 0..MaxNonce,
                      deadline : 0..MaxTime]
ProofType == [present : BOOLEAN, generation : 0..MaxGeneration,
              parent : 0..MaxHeight, terminal : 0..MaxHeight]
LandingType == [present : BOOLEAN, generation : 0..MaxGeneration,
                parent : 0..MaxHeight]
LastLandingType == [present : BOOLEAN, proofOrigin : 0..MaxHeight,
                    previousC : 0..MaxHeight, terminal : 0..MaxHeight,
                    recordedParent : 0..MaxHeight]
AuditType == [staleGeneration : BOOLEAN, staleCheckpoint : BOOLEAN,
              staleNonce : BOOLEAN, expired : BOOLEAN, oldProof : BOOLEAN,
              recoveryChangedC : BOOLEAN, overlap : BOOLEAN,
              deadlineEquality : BOOLEAN]

Init ==
    /\ c = 0 /\ generation = 0 /\ recoveryNonce = 0
    /\ startHeight = 0 /\ now = 0
    /\ authorization = [present |-> FALSE, generation |-> 0,
                         checkpoint |-> 0, nonce |-> 0, deadline |-> 0]
    /\ pendingProof = [present |-> FALSE, generation |-> 0,
                        parent |-> 0, terminal |-> 0]
    /\ landings = [h \in 0..MaxHeight |->
                      [present |-> h = 0, generation |-> 0, parent |-> 0]]
    /\ lastLanding = [present |-> FALSE, proofOrigin |-> 0,
                       previousC |-> 0, terminal |-> 0, recordedParent |-> 0]
    /\ audit = [staleGeneration |-> FALSE, staleCheckpoint |-> FALSE,
                 staleNonce |-> FALSE, expired |-> FALSE, oldProof |-> FALSE,
                 recoveryChangedC |-> FALSE, overlap |-> FALSE,
                 deadlineEquality |-> FALSE]

\* Captures owner-authorized arguments; authorization does not freeze land.
\* RECOV-8.3-3/4/7. Offchain authority and list validity are assumed.
Authorize(deadline) ==
    /\ deadline \in now..MaxTime
    /\ authorization' = [present |-> TRUE, generation |-> generation,
                           checkpoint |-> c, nonce |-> recoveryNonce,
                           deadline |-> deadline]
    /\ UNCHANGED <<c, generation, recoveryNonce, startHeight, now,
                    pendingProof, landings, lastLanding, audit>>

\* One delayed, otherwise-valid proof produced from the current checkpoint.
\* All proofs are for the same abstract chain and have matching interior cuts.
PrepareProof(h) ==
    /\ h \in (c + 1)..MaxHeight
    /\ pendingProof' = [present |-> TRUE, generation |-> generation,
                          parent |-> c, terminal |-> h]
    /\ UNCHANGED <<c, generation, recoveryNonce, startHeight, now,
                    authorization, landings, lastLanding, audit>>

\* LAND-6.1-2/3/9 and normative land steps 1, 2, 6, 7.
\* CheckProofGeneration abstracts verification against the CURRENT generation's
\* public input. It is not an extra caller-supplied Solidity proof-generation arg.
\* The current origin may reuse an older generation's landing record.
Land(proof) ==
    /\ proof.present
    /\ startHeight <= proof.parent /\ proof.parent <= c
    /\ c < proof.terminal /\ proof.terminal <= MaxHeight
    /\ landings[proof.parent].present
    /\ (landings[proof.parent].generation = generation
           \/ proof.parent = startHeight)
    /\ (~CheckProofGeneration \/ proof.generation = generation)
    /\ c' = proof.terminal
    /\ landings' = [landings EXCEPT ![proof.terminal] =
                        [present |-> TRUE, generation |-> generation,
                         parent |-> c]]
    /\ lastLanding' = [present |-> TRUE, proofOrigin |-> proof.parent,
                         previousC |-> c, terminal |-> proof.terminal,
                         recordedParent |-> c]
    /\ audit' = [audit EXCEPT !.oldProof = @ \/ proof.generation # generation,
                                !.overlap = @ \/ proof.parent < c]
    /\ UNCHANGED <<generation, recoveryNonce, startHeight, now,
                    authorization, pendingProof>>

LandFresh(h) ==
    /\ h \in (c + 1)..MaxHeight
    /\ Land([present |-> TRUE, generation |-> generation,
             parent |-> c, terminal |-> h])

\* RECOV-8.3-3/8 and RECOV-8-47/48: execute atomically, preserve c,
\* increment generation/nonce, and take c as the new fixed generation origin.
\* All failure cases stutter under Spec; no partial writes are represented.
Recover ==
    /\ authorization.present
    /\ generation < MaxGeneration /\ recoveryNonce < MaxNonce
    /\ authorization.generation = generation
    /\ (~CheckCheckpoint \/ authorization.checkpoint = c)
    /\ (~CheckNonce \/ authorization.nonce = recoveryNonce)
    /\ (~CheckDeadline \/ now <= authorization.deadline)
    /\ generation' = generation + 1
    /\ recoveryNonce' = recoveryNonce + 1
    /\ startHeight' = c
    /\ UNCHANGED <<c, now, authorization, pendingProof, landings, lastLanding>>
    /\ audit' = [audit EXCEPT
          !.staleGeneration = @ \/ authorization.generation # generation,
          !.staleCheckpoint = @ \/ authorization.checkpoint # c,
          !.staleNonce = @ \/ authorization.nonce # recoveryNonce,
          !.expired = @ \/ now > authorization.deadline,
          !.recoveryChangedC = @ \/ c' # c,
          !.deadlineEquality = @ \/ (now > 0 /\ now = authorization.deadline)]

\* RECOV-8.3-9: owner passes the current expected nonce and invalidates it.
InvalidateNonce ==
    /\ recoveryNonce < MaxNonce
    /\ recoveryNonce' = recoveryNonce + 1
    /\ UNCHANGED <<c, generation, startHeight, now, authorization,
                    pendingProof, landings, lastLanding, audit>>

Tick ==
    /\ now < MaxTime
    /\ now' = now + 1
    /\ UNCHANGED <<c, generation, recoveryNonce, startHeight, authorization,
                    pendingProof, landings, lastLanding, audit>>

Next == \/ \E deadline \in 0..MaxTime : Authorize(deadline)
        \/ \E h \in 0..MaxHeight : PrepareProof(h)
        \/ \E h \in 0..MaxHeight : LandFresh(h)
        \/ Land(pendingProof)
        \/ Recover
        \/ InvalidateNonce
        \/ Tick

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ c \in 0..MaxHeight /\ generation \in 0..MaxGeneration
    /\ recoveryNonce \in 0..MaxNonce /\ startHeight \in 0..c
    /\ now \in 0..MaxTime
    /\ authorization \in AuthorizationType /\ pendingProof \in ProofType
    /\ landings \in [0..MaxHeight -> LandingType]
    /\ lastLanding \in LastLandingType /\ audit \in AuditType

\* Audits are observation-only, independent of optional guard switches.
\* They never appear in action enabling conditions.
NoStaleGenerationRecovery == ~audit.staleGeneration
NoStaleCheckpointRecovery == ~audit.staleCheckpoint
NoStaleNonceRecovery == ~audit.staleNonce
NoExpiredRecovery == ~audit.expired
NoOldGenerationLanding == ~audit.oldProof
RecoveryCheckpointPreserved == ~audit.recoveryChangedC
NoFutureLandingRecords ==
    \A h \in 0..MaxHeight : landings[h].present => h <= c
ActualLandingParent ==
    lastLanding.present =>
      /\ lastLanding.recordedParent = lastLanding.previousC
      /\ landings[lastLanding.terminal].parent = lastLanding.previousC

\* Deliberately false invariants certify existential reachability, NOT liveness.
RecoveryNotReached == generation = 0
OverlapNotReached == ~audit.overlap
InvalidationNotReached ==
    ~(authorization.present /\ authorization.generation = generation
       /\ authorization.checkpoint = c /\ authorization.nonce < recoveryNonce)
ExpiryNotReached == ~(authorization.present /\ now > authorization.deadline)
DeadlineEqualityNotReached == ~audit.deadlineEquality
OldProofAfterRecoveryNotReached ==
    ~(pendingProof.present /\ pendingProof.generation < generation
       /\ pendingProof.parent = c /\ pendingProof.terminal > c)
=============================================================================
