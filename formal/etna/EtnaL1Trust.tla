---------------------------- MODULE EtnaL1Trust ----------------------------
EXTENDS Naturals, TLC

\* M02 first bounded increment. SPEC d18357214fab30ea512ae9858a11699806d72ba1.
\* Fixed canonical interface trace, NOT composition/refinement of M01/M08.
CONSTANTS NodeCount, MaxSnapshot, SessionGeneration, EvidenceKinds, ExerciseErrors,
          CertificateWrite, CheckHaltFence, CheckOriginBoundary,
          CheckFinality, CheckEL, CheckComet, CheckVal, CheckValSource,
          CheckSessionReset, CheckSignTrust, CheckServeTrust, CheckAppConfirmation,
          CheckSupersession, CheckKnowledgePersistence, CheckMissingPause,
          CheckTimeoutPause, CheckUnsupportedPause, CheckContradictionHalt,
          CheckGenerationHalt

Nodes == 1..NodeCount
Kinds == {"Missing", "Exact", "WrongEL", "WrongComet", "WrongVal",
          "MissingVal", "ForeignVal", "LookupVal"}
SignatureKinds == {"Block", "Nil", "Retained"}
StartSnapshot == IF SessionGeneration = 0 THEN 0 ELSE 2
Snapshots == StartSnapshot..MaxSnapshot
Gen(s) == IF s < 2 THEN 0 ELSE 1
Height(s) == IF s = 0 THEN 0 ELSE IF s = 3 THEN 2 ELSE 1
OriginHeight == IF SessionGeneration = 0 THEN 0 ELSE 1
AtOrigin(s) == ~CheckOriginBoundary \/ Height(s) = OriginHeight
EL(s) == <<"EL", Height(s)>>
Comet(s) == <<"HistoricalComet", Height(s)>>
StoredVal(s) == IF s = 0 THEN <<"StoredStartVal", 0>>
                ELSE IF s = 3 THEN <<"RecordedVal", 1, 2>>
                ELSE <<"RecordedVal", 0, 1>>
GenesisVal(g) == <<"GenesisVal", g>>
LocalVal(s) == IF Height(s) = (IF Gen(s) = 0 THEN 0 ELSE 1)
               THEN GenesisVal(Gen(s)) ELSE StoredVal(s)
Max(a, b) == IF a >= b THEN a ELSE b
ASSUME /\ NodeCount \in 1..2 /\ SessionGeneration \in 0..1
       /\ MaxSnapshot \in StartSnapshot..3
       /\ {"Missing", "Exact"} \subseteq EvidenceKinds
       /\ EvidenceKinds \subseteq Kinds
       /\ CertificateWrite \in {"Actual", "OtherFinalizedTarget", "ExpectedEvidence"}
       /\ {ExerciseErrors, CheckHaltFence, CheckOriginBoundary, CheckFinality, CheckEL, CheckComet, CheckVal,
             CheckValSource, CheckSessionReset, CheckSignTrust, CheckServeTrust,
             CheckAppConfirmation, CheckSupersession, CheckKnowledgePersistence,
             CheckMissingPause, CheckTimeoutPause, CheckUnsupportedPause,
             CheckContradictionHalt, CheckGenerationHalt} \subseteq BOOLEAN

VARIABLES included, finalized, provider, target, local, certificate,
          trusted, halted, knownGeneration, everGeneration, lastRead,
          missingSeen, missingAt, haltHistory, faults, event
vars == <<included, finalized, provider, target, local, certificate,
          trusted, halted, knownGeneration, everGeneration, lastRead,
          missingSeen, missingAt, haltHistory, faults, event>>

EvidenceEL(s, kind) == IF kind = "WrongEL" THEN <<"WrongEL", Height(s)>> ELSE EL(s)
EvidenceComet(s, kind) ==
    IF kind = "WrongComet" THEN <<"WrongComet", Height(s)>> ELSE Comet(s)
EvidenceVal(s, kind) ==
    IF kind = "WrongVal" THEN <<"WrongVal", Height(s)>>
    ELSE IF kind \in {"Missing", "MissingVal"} THEN <<"MissingVal">>
    ELSE LocalVal(s)
ValSource(kind) == IF kind = "LookupVal" THEN "Lookup"
                   ELSE IF kind \in {"Missing", "MissingVal"} THEN "Missing"
                   ELSE "Recorded"
ValGeneration(s, kind) == IF kind = "ForeignVal" THEN 1 - Gen(s) ELSE Gen(s)
TargetType == [ready : BOOLEAN, snapshot : Snapshots, authenticatedFinalized : BOOLEAN]
LocalType == [snapshot : Snapshots, kind : EvidenceKinds]
CertificateType ==
    [present : BOOLEAN, snapshot : Snapshots, authenticatedFinalized : BOOLEAN,
     height : 0..2,
     el : {EvidenceEL(s, k) : s \in Snapshots, k \in EvidenceKinds},
     comet : {EvidenceComet(s, k) : s \in Snapshots, k \in EvidenceKinds},
     val : {EvidenceVal(s, k) : s \in Snapshots, k \in EvidenceKinds} \cup
             {StoredVal(s) : s \in Snapshots},
     valSource : {"Recorded", "Lookup", "Missing"}, valGeneration : 0..1]
FaultType ==
    [signTrust : BOOLEAN, signApp : BOOLEAN, staleSign : BOOLEAN, serveTrust : BOOLEAN,
     timeoutHalt : BOOLEAN, missingHalt : BOOLEAN, unsupportedHalt : BOOLEAN,
     contradictionRetry : BOOLEAN]
EventKinds == {"None", "Session", "Trust", "Sign", "Serve", "Learn", "Revoke",
               "StartupMismatch", "MissingPause", "MissingHalt", "ContradictionHalt",
               "ContradictionPause", "L1TimeoutPause", "L1TimeoutHalt",
               "UnsupportedPause", "UnsupportedHalt"}
EventType == [kind : EventKinds, node : Nodes]
EmptyEvent == [kind |-> "None", node |-> 1]
NewEvent(kind, n) == [kind |-> kind, node |-> n]
EmptyCertificate == [present |-> FALSE, snapshot |-> StartSnapshot,
    authenticatedFinalized |-> FALSE, height |-> Height(StartSnapshot),
    el |-> EvidenceEL(StartSnapshot, "Missing"),
    comet |-> EvidenceComet(StartSnapshot, "Missing"),
    val |-> EvidenceVal(StartSnapshot, "Missing"),
    valSource |-> "Missing", valGeneration |-> Gen(StartSnapshot)]

Init ==
    /\ included = StartSnapshot /\ finalized = StartSnapshot
    /\ provider = [n \in Nodes |-> StartSnapshot]
    /\ target = [n \in Nodes |-> [ready |-> FALSE, snapshot |-> StartSnapshot,
                                   authenticatedFinalized |-> FALSE]]
    /\ local = [n \in Nodes |-> [snapshot |-> StartSnapshot, kind |-> "Missing"]]
    /\ certificate = [n \in Nodes |-> EmptyCertificate]
    /\ trusted = [n \in Nodes |-> FALSE] /\ halted = [n \in Nodes |-> FALSE]
    /\ knownGeneration = [n \in Nodes |-> 0]
    /\ everGeneration = [n \in Nodes |-> 0]
    /\ lastRead = [n \in Nodes |-> "None"]
    /\ missingSeen = [n \in Nodes |-> FALSE]
    /\ missingAt = [n \in Nodes |-> StartSnapshot]
    /\ haltHistory = [n \in Nodes |-> FALSE]
    /\ faults = [signTrust |-> FALSE, signApp |-> FALSE, staleSign |-> FALSE,
                  serveTrust |-> FALSE, timeoutHalt |-> FALSE, missingHalt |-> FALSE,
                  unsupportedHalt |-> FALSE, contradictionRetry |-> FALSE]
    /\ event = EmptyEvent

Include ==
    /\ included < MaxSnapshot /\ included' = included + 1 /\ event' = EmptyEvent
    /\ UNCHANGED <<finalized, provider, target, local, certificate, trusted, halted,
          knownGeneration, everGeneration, lastRead, missingSeen, missingAt, faults>>
    /\ UNCHANGED haltHistory
Finalize ==
    /\ finalized < included /\ finalized' = finalized + 1 /\ event' = EmptyEvent
    /\ UNCHANGED <<included, provider, target, local, certificate, trusted, halted,
          knownGeneration, everGeneration, lastRead, missingSeen, missingAt, faults>>
    /\ UNCHANGED haltHistory
ProviderView(n, s) ==
    /\ s \in StartSnapshot..included
    /\ provider' = [provider EXCEPT ![n] = s] /\ event' = EmptyEvent
    /\ UNCHANGED <<included, finalized, target, local, certificate, trusted, halted,
          knownGeneration, everGeneration, lastRead, missingSeen, missingAt, faults>>
    /\ UNCHANGED haltHistory

\* Logical session boundary only: no physical restart, HRS or ABCI replay.
BeginSession(n) ==
    /\ (~halted[n] \/ ~CheckHaltFence)
    /\ halted' = [halted EXCEPT ![n] = IF CheckHaltFence THEN @ ELSE FALSE]
    /\ trusted' = [trusted EXCEPT ![n] = IF CheckSessionReset THEN FALSE ELSE @]
    /\ certificate' = [certificate EXCEPT ![n] = EmptyCertificate]
    /\ target' = [target EXCEPT ![n].ready = FALSE]
    /\ knownGeneration' = [knownGeneration EXCEPT
                              ![n] = IF CheckKnowledgePersistence THEN @ ELSE 0]
    /\ lastRead' = [lastRead EXCEPT ![n] = "None"]
    /\ missingSeen' = [missingSeen EXCEPT ![n] = FALSE]
    /\ event' = NewEvent("Session", n)
    /\ UNCHANGED <<included, finalized, provider, local,
                    everGeneration, missingAt, faults>>
    /\ UNCHANGED haltHistory
LoadEvidence(n, s, kind) ==
    /\ ~trusted[n] /\ ~halted[n]
    /\ local' = [local EXCEPT ![n] = [snapshot |-> s, kind |-> kind]]
    /\ event' = EmptyEvent
    /\ UNCHANGED <<included, finalized, provider, target, certificate, trusted, halted,
          knownGeneration, everGeneration, lastRead, missingSeen, missingAt, faults>>
    /\ UNCHANGED haltHistory

\* Canonical included data are provider-visible, but finality must be checked.
\* For g1 cases, pre-R startup is explicitly excluded by StartSnapshot=2.
AuthenticateTarget(n) ==
    /\ ~trusted[n] /\ ~halted[n]
    /\ (~CheckFinality \/ provider[n] <= finalized)
    /\ target' = [target EXCEPT ![n] = [ready |-> TRUE, snapshot |-> provider[n],
                          authenticatedFinalized |-> provider[n] <= finalized]]
    /\ knownGeneration' = [knownGeneration EXCEPT ![n] = Max(@, Gen(provider[n]))]
    /\ everGeneration' = [everGeneration EXCEPT ![n] = Max(@, Gen(provider[n]))]
    /\ halted' = [halted EXCEPT ![n] =
                    CheckGenerationHalt /\ Gen(provider[n]) # SessionGeneration]
    /\ haltHistory' = [haltHistory EXCEPT ![n] = @ \/ halted'[n]]
    /\ lastRead' = [lastRead EXCEPT ![n] = "OK"]
    /\ event' = NewEvent(IF Gen(provider[n]) # SessionGeneration
                          THEN "StartupMismatch" ELSE "Learn", n)
    /\ UNCHANGED <<included, finalized, provider, local, certificate, trusted,
                    missingSeen, missingAt, faults>>

\* Authenticated running-process generation observation, not full anchor validity.
\* Visibility alone, a timeout or unsupported parsing does not learn a generation.
ObserveGeneration(n) ==
    /\ ~halted[n] /\ provider[n] <= finalized
    /\ knownGeneration' = [knownGeneration EXCEPT ![n] = Max(@, Gen(provider[n]))]
    /\ everGeneration' = [everGeneration EXCEPT ![n] = Max(@, Gen(provider[n]))]
    /\ trusted' = [trusted EXCEPT ![n] =
          IF CheckSupersession /\ Gen(provider[n]) > SessionGeneration THEN FALSE ELSE @]
    /\ lastRead' = [lastRead EXCEPT ![n] = "OK"]
    /\ event' = NewEvent(IF trusted[n] /\ Gen(provider[n]) > SessionGeneration
                          THEN "Revoke" ELSE "Learn", n)
    /\ UNCHANGED <<included, finalized, provider, target, local, certificate, halted,
                    missingSeen, missingAt, faults>>
    /\ UNCHANGED haltHistory

\* Own-L1 RPC timeout is independent from the app-status reply on each vote.
ReadTimeout(n) ==
    /\ ExerciseErrors /\ ~halted[n]
    /\ halted' = [halted EXCEPT ![n] = ~CheckTimeoutPause]
    /\ haltHistory' = [haltHistory EXCEPT ![n] = @ \/ halted'[n]]
    /\ trusted' = [trusted EXCEPT ![n] = IF CheckTimeoutPause THEN @ ELSE FALSE]
    /\ lastRead' = [lastRead EXCEPT ![n] = "Timeout"]
    /\ faults' = [faults EXCEPT !.timeoutHalt = @ \/ halted'[n]]
    /\ event' = NewEvent(IF CheckTimeoutPause THEN "L1TimeoutPause" ELSE "L1TimeoutHalt", n)
    /\ UNCHANGED <<included, finalized, provider, target, local, certificate,
                    knownGeneration, everGeneration, missingSeen, missingAt>>
UnsupportedHeader(n) ==
    /\ ExerciseErrors /\ ~halted[n] /\ provider[n] <= finalized
    /\ halted' = [halted EXCEPT ![n] = ~CheckUnsupportedPause]
    /\ haltHistory' = [haltHistory EXCEPT ![n] = @ \/ halted'[n]]
    /\ trusted' = [trusted EXCEPT ![n] = IF CheckUnsupportedPause THEN @ ELSE FALSE]
    /\ lastRead' = [lastRead EXCEPT ![n] = "Unsupported"]
    /\ faults' = [faults EXCEPT !.unsupportedHalt = @ \/ halted'[n]]
    /\ event' = NewEvent(IF CheckUnsupportedPause THEN "UnsupportedPause" ELSE "UnsupportedHalt", n)
    /\ UNCHANGED <<included, finalized, provider, target, local, certificate,
                    knownGeneration, everGeneration, missingSeen, missingAt>>

BundleAvailable(n) == local[n].kind # "Missing" /\
                       Height(local[n].snapshot) = Height(target[n].snapshot)
ValPresent(n) == local[n].kind \notin {"Missing", "MissingVal"}
ValSourceGood(n) == ValSource(local[n].kind) = "Recorded" /\
                     ValGeneration(local[n].snapshot, local[n].kind) = SessionGeneration
MissingEvidence(n) == ~BundleAvailable(n) \/
    (~AtOrigin(target[n].snapshot) /\ (~ValPresent(n) \/ ~ValSourceGood(n)))
Contradiction(n) == BundleAvailable(n) /\
    (EvidenceEL(local[n].snapshot, local[n].kind) # EL(target[n].snapshot) \/
     EvidenceComet(local[n].snapshot, local[n].kind) # Comet(target[n].snapshot) \/
     (~AtOrigin(target[n].snapshot) /\ ValPresent(n) /\ ValSourceGood(n) /\
       EvidenceVal(local[n].snapshot, local[n].kind) # StoredVal(target[n].snapshot)))
AllowedEvidence(n) ==
    /\ BundleAvailable(n)
    /\ (~CheckEL \/ EvidenceEL(local[n].snapshot, local[n].kind) = EL(target[n].snapshot))
    /\ (~CheckComet \/ EvidenceComet(local[n].snapshot, local[n].kind) = Comet(target[n].snapshot))
    /\ AtOrigin(target[n].snapshot) \/
         (ValPresent(n) /\ (~CheckValSource \/ ValSourceGood(n)) /\
          (~CheckVal \/ EvidenceVal(local[n].snapshot, local[n].kind) = StoredVal(target[n].snapshot)))
MakeCertificate(n) ==
    [present |-> TRUE, snapshot |-> target[n].snapshot,
     authenticatedFinalized |-> target[n].authenticatedFinalized,
     height |-> Height(local[n].snapshot),
     el |-> EvidenceEL(local[n].snapshot, local[n].kind),
     comet |-> EvidenceComet(local[n].snapshot, local[n].kind),
     val |-> EvidenceVal(local[n].snapshot, local[n].kind),
     valSource |-> ValSource(local[n].kind),
     valGeneration |-> ValGeneration(local[n].snapshot, local[n].kind)]
\* Pure write mutations leave all acceptance guards enabled.
CanonicalCertificate(s, authenticated) ==
    [present |-> TRUE, snapshot |-> s, authenticatedFinalized |-> authenticated,
     height |-> Height(s), el |-> EL(s), comet |-> Comet(s), val |-> StoredVal(s),
     valSource |-> "Recorded", valGeneration |-> Gen(s)]
WrittenCertificate(n) ==
    CASE CertificateWrite = "Actual" -> MakeCertificate(n)
      [] CertificateWrite = "OtherFinalizedTarget" ->
           LET other == IF target[n].snapshot = StartSnapshot THEN finalized ELSE StartSnapshot
           IN IF other = target[n].snapshot THEN MakeCertificate(n)
                ELSE CanonicalCertificate(other, TRUE)
      [] OTHER -> CanonicalCertificate(target[n].snapshot, target[n].authenticatedFinalized)

GrantTrust(n) ==
    /\ ~trusted[n] /\ ~halted[n] /\ target[n].ready
    /\ Gen(target[n].snapshot) = SessionGeneration
    /\ AllowedEvidence(n)
    /\ (~CheckSupersession \/ knownGeneration[n] <= SessionGeneration)
    /\ certificate' = [certificate EXCEPT ![n] = WrittenCertificate(n)]
    /\ trusted' = [trusted EXCEPT ![n] = TRUE]
    /\ event' = NewEvent("Trust", n)
    /\ UNCHANGED <<included, finalized, provider, target, local, halted,
          knownGeneration, everGeneration, lastRead, missingSeen, missingAt, faults>>
    /\ UNCHANGED haltHistory
ClassifyEvidence(n) ==
    /\ ~trusted[n] /\ ~halted[n] /\ target[n].ready
    /\ Gen(target[n].snapshot) = SessionGeneration
    /\ ~AllowedEvidence(n)
    /\ (Contradiction(n) \/ MissingEvidence(n))
    /\ LET contradiction == Contradiction(n)
           mustHalt == IF contradiction THEN CheckContradictionHalt ELSE ~CheckMissingPause
       IN /\ halted' = [halted EXCEPT ![n] = mustHalt]
          /\ haltHistory' = [haltHistory EXCEPT ![n] = @ \/ mustHalt]
          /\ missingSeen' = [missingSeen EXCEPT ![n] = @ \/ ~contradiction]
          /\ missingAt' = [missingAt EXCEPT ![n] =
                             IF contradiction THEN @ ELSE target[n].snapshot]
          /\ faults' = [faults EXCEPT
               !.missingHalt = @ \/ (~contradiction /\ mustHalt),
               !.contradictionRetry = @ \/ (contradiction /\ ~mustHalt)]
          /\ event' = NewEvent(IF contradiction
                               THEN IF mustHalt THEN "ContradictionHalt" ELSE "ContradictionPause"
                               ELSE IF mustHalt THEN "MissingHalt" ELSE "MissingPause", n)
    /\ UNCHANGED <<included, finalized, provider, target, local, certificate, trusted,
                    knownGeneration, everGeneration, lastRead>>

CertificateMatches(cert) ==
    /\ Gen(cert.snapshot) = SessionGeneration
    /\ cert.height = Height(cert.snapshot)
    /\ cert.el = EL(cert.snapshot) /\ cert.comet = Comet(cert.snapshot)
    /\ Height(cert.snapshot) = OriginHeight \/ cert.val = StoredVal(cert.snapshot)
CertificateSourceGood(cert) == Height(cert.snapshot) = OriginHeight \/
    (cert.valSource = "Recorded" /\ cert.valGeneration = SessionGeneration)
CertificateSound(cert) == cert.present /\ cert.authenticatedFinalized /\
                           CertificateMatches(cert) /\ CertificateSourceGood(cert)

\* All Block/Nil/Retained requests share the SAME gate. HRS is not modeled.
Sign(n, kind, appReply) ==
    /\ kind \in SignatureKinds /\ ~halted[n]
    /\ (~CheckSignTrust \/ trusted[n])
    /\ (~CheckAppConfirmation \/ appReply)
    /\ (~CheckSupersession \/ knownGeneration[n] <= SessionGeneration)
    /\ faults' = [faults EXCEPT
          !.signTrust = @ \/ ~trusted[n] \/ ~CertificateSound(certificate[n]),
          !.signApp = @ \/ ~appReply,
          !.staleSign = @ \/ knownGeneration[n] > SessionGeneration]
    /\ event' = NewEvent("Sign", n)
    /\ UNCHANGED <<included, finalized, provider, target, local, certificate, trusted,
          halted, knownGeneration, everGeneration, lastRead, missingSeen, missingAt>>
    /\ UNCHANGED haltHistory
Serve(n) ==
    /\ ~halted[n] /\ (~CheckServeTrust \/ trusted[n])
    /\ faults' = [faults EXCEPT
          !.serveTrust = @ \/ ~trusted[n] \/ ~CertificateSound(certificate[n])]
    /\ event' = NewEvent("Serve", n)
    /\ UNCHANGED <<included, finalized, provider, target, local, certificate, trusted,
          halted, knownGeneration, everGeneration, lastRead, missingSeen, missingAt>>
    /\ UNCHANGED haltHistory

Next == \/ Include \/ Finalize
        \/ \E n \in Nodes, s \in StartSnapshot..included : ProviderView(n, s)
        \/ \E n \in Nodes : BeginSession(n)
        \/ \E n \in Nodes, s \in Snapshots, kind \in EvidenceKinds : LoadEvidence(n, s, kind)
        \/ \E n \in Nodes : AuthenticateTarget(n)
        \/ \E n \in Nodes : ObserveGeneration(n)
        \/ \E n \in Nodes : ReadTimeout(n)
        \/ \E n \in Nodes : UnsupportedHeader(n)
        \/ \E n \in Nodes : GrantTrust(n)
        \/ \E n \in Nodes : ClassifyEvidence(n)
        \/ \E n \in Nodes, kind \in SignatureKinds, appReply \in BOOLEAN : Sign(n, kind, appReply)
        \/ \E n \in Nodes : Serve(n)
TrustSpec == Init /\ [][Next]_vars

TrustTypeOK ==
    /\ included \in Snapshots /\ finalized \in StartSnapshot..included
    /\ provider \in [Nodes -> StartSnapshot..included]
    /\ target \in [Nodes -> TargetType] /\ local \in [Nodes -> LocalType]
    /\ certificate \in [Nodes -> CertificateType]
    /\ trusted \in [Nodes -> BOOLEAN] /\ halted \in [Nodes -> BOOLEAN]
    /\ knownGeneration \in [Nodes -> 0..1] /\ everGeneration \in [Nodes -> 0..1]
    /\ lastRead \in [Nodes -> {"None", "OK", "Timeout", "Unsupported"}]
    /\ missingSeen \in [Nodes -> BOOLEAN] /\ missingAt \in [Nodes -> Snapshots]
    /\ haltHistory \in [Nodes -> BOOLEAN]
    /\ faults \in FaultType /\ event \in EventType
TrustedHasCertificate == \A n \in Nodes : trusted[n] => certificate[n].present
TrustedCertificateFromTarget == \A n \in Nodes : trusted[n] =>
    (target[n].ready /\ certificate[n].snapshot = target[n].snapshot /\
     certificate[n].authenticatedFinalized = target[n].authenticatedFinalized)
TrustedCertificateFromLocal == \A n \in Nodes : trusted[n] =>
    (certificate[n].height = Height(local[n].snapshot) /\
     certificate[n].el = EvidenceEL(local[n].snapshot, local[n].kind) /\
     certificate[n].comet = EvidenceComet(local[n].snapshot, local[n].kind) /\
     certificate[n].val = EvidenceVal(local[n].snapshot, local[n].kind) /\
     certificate[n].valSource = ValSource(local[n].kind) /\
     certificate[n].valGeneration = ValGeneration(local[n].snapshot, local[n].kind))
TrustedTargetFinalized == \A n \in Nodes : trusted[n] =>
    (certificate[n].authenticatedFinalized /\ certificate[n].snapshot <= finalized)
TrustedCheckpointExact == \A n \in Nodes : trusted[n] => CertificateMatches(certificate[n])
TrustedValidatorProvenance == \A n \in Nodes : trusted[n] => CertificateSourceGood(certificate[n])
TrustedNeverHalted == \A n \in Nodes : trusted[n] => ~halted[n]
NoTrustedAfterSupersession == \A n \in Nodes : trusted[n] => everGeneration[n] <= SessionGeneration
SafetyHaltSticky == \A n \in Nodes : haltHistory[n] => halted[n]
KnowledgeRetained == \A n \in Nodes : knownGeneration[n] >= everGeneration[n]
StartupGenerationMismatchHalts == \A n \in Nodes :
    (target[n].ready /\ Gen(target[n].snapshot) # SessionGeneration) => halted[n]
NoSignWithoutTrust == ~faults.signTrust
NoSignWithoutAppConfirmation == ~faults.signApp
NoKnownStaleSign == ~faults.staleSign
NoServeWithoutTrust == ~faults.serveTrust
NoHaltOnL1Timeout == ~faults.timeoutHalt
NoHaltOnMissingEvidence == ~faults.missingHalt
NoHaltOnUnsupportedHeader == ~faults.unsupportedHalt
NoContradictionAsRetry == ~faults.contradictionRetry

ValidStartupNotReached == ~\E n \in Nodes : trusted[n]
MissingRetryTrustNotReached ==
    ~(event.kind = "Trust" /\ missingSeen[event.node] /\
       certificate[event.node].snapshot = missingAt[event.node])
UnsupportedPauseNotReached == event.kind # "UnsupportedPause"
DifferentViewsNotReached ==
    ~\E a, b \in Nodes : trusted[a] /\ trusted[b] /\
                           certificate[a].snapshot # certificate[b].snapshot
StaleViewSignNotReached ==
    ~(event.kind = "Sign" /\ Gen(finalized) > SessionGeneration /\
       knownGeneration[event.node] <= SessionGeneration)
L1TimeoutSignNotReached == ~(event.kind = "Sign" /\ lastRead[event.node] = "Timeout")
SupersessionNotReached == ~(event.kind = "Revoke" /\ ~trusted[event.node] /\
                            knownGeneration[event.node] > SessionGeneration)
RecoveryOriginTrustNotReached ==
    ~(event.kind = "Trust" /\ SessionGeneration = 1 /\
       AtOrigin(certificate[event.node].snapshot) /\
       certificate[event.node].val = GenesisVal(1) /\
       certificate[event.node].val # StoredVal(certificate[event.node].snapshot))
=============================================================================
