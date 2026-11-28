--------------------- MODULE EtnaCheckpointIdentity ---------------------
EXTENDS EtnaSettlement

\* Compose (do not duplicate) EtnaSettlement's transaction transitions.
\* Source: SPEC.md d18357214fab30ea512ae9858a11699806d72ba1, §§6.1/6.2/8,
\* ENC-A-29..35. Hash tokens are injective symbolic identities, not real hashes.
CONSTANTS IdentityDifference, ForkHeight, CheckOriginBinding,
          BoundaryMode, CheckCutBinding, KeepRecoveryIdentity, KeepLandingIdentity

Histories == {"A", "B"}
ASSUME /\ IdentityDifference \in {"EL", "Comet", "FI", "Val"}
       /\ ForkHeight \in 1..MaxHeight
       /\ BoundaryMode \in {"Full", "ELOnly", "None"}
       /\ {CheckOriginBinding, CheckCutBinding, KeepRecoveryIdentity, KeepLandingIdentity}
             \subseteq BOOLEAN

VARIABLES queuedIdentity, recordCuts, prefixCuts, prefixGeneration, identityAudit
identityVars == <<queuedIdentity, recordCuts, prefixCuts,
                  prefixGeneration, identityAudit>>
allVars == <<vars, identityVars>>

Tag(field, history, h) ==
    IF field = IdentityDifference /\ h >= ForkHeight THEN history ELSE "Shared"
GenesisVal(g) == <<"Genesis", g>>
CandidateCut(g, history, h) ==
    [height |-> h, el |-> <<"EL", g, h, Tag("EL", history, h)>>,
     comet |-> <<"Comet", g, h, Tag("Comet", history, h)>>,
     fi |-> IF IdentityDifference = "FI" /\ history = "B" /\ h >= ForkHeight
               THEN 1 ELSE 0,
     val |-> <<"Val", g, h, Tag("Val", history, h)>>]

\* An alternative origin input changes one selected component, even at p=c.
\* This input is deliberately NOT assumed to pass the origin verification.
AlternativeCut(cut) ==
    [cut EXCEPT
      !.el = IF IdentityDifference = "EL"
               THEN <<"EL", cut.el[2], cut.height, "Other">> ELSE @,
      !.comet = IF IdentityDifference = "Comet"
                  THEN <<"Comet", cut.comet[2], cut.height, "Other">> ELSE @,
      !.fi = IF IdentityDifference = "FI" THEN 1 - @ ELSE @,
      !.val = IF IdentityDifference = "Val"
                THEN <<"Val", cut.el[2], cut.height, "Other">> ELSE @]

Tokens(kind) == {<<kind, g, h, tag>> : g \in 0..MaxGeneration,
                  h \in 0..MaxHeight, tag \in {"Shared", "A", "B", "Other"}}
CutType == [height : 0..MaxHeight, el : Tokens("EL"), comet : Tokens("Comet"),
            fi : 0..1, val : Tokens("Val") \cup
                               {GenesisVal(g) : g \in 0..MaxGeneration}]
QueuedIdentityType == [executionHistory : Histories, leafHistory : Histories,
                       publicOrigin : CutType, executionOrigin : CutType]
IdentityAuditType ==
    [originFault : BOOLEAN, cutFault : BOOLEAN, boundaryFault : BOOLEAN,
     recoveryFault : BOOLEAN, prefixFault : BOOLEAN, goodOverlap : BOOLEAN,
     recoveredPositive : BOOLEAN, reusedOrigin : BOOLEAN, divergentSuffix : BOOLEAN]

IdentityInit ==
    /\ Init
    /\ recordCuts = [x \in 0..MaxHeight |-> CandidateCut(0, "A", x)]
    /\ prefixCuts = recordCuts
    /\ prefixGeneration = [x \in 0..MaxHeight |-> 0]
    /\ queuedIdentity = [executionHistory |-> "A", leafHistory |-> "A",
          publicOrigin |-> recordCuts[0],
          executionOrigin |-> [recordCuts[0] EXCEPT !.val = GenesisVal(0)]]
    /\ identityAudit = [originFault |-> FALSE, cutFault |-> FALSE,
          boundaryFault |-> FALSE, recoveryFault |-> FALSE, prefixFault |-> FALSE,
          goodOverlap |-> FALSE, recoveredPositive |-> FALSE,
          reusedOrigin |-> FALSE, divergentSuffix |-> FALSE]

\* ENC-A-35 always binds the RETAINED public-input parentValStateHash.
\* PROOF-6.2-41a separately reconstructs the execution-start genesis state.
BuildIdentity(execution, leaves, alternativeOrigin) ==
    LET public == IF alternativeOrigin THEN AlternativeCut(recordCuts[c])
                   ELSE recordCuts[c]
        executed == IF c = startHeight
                     THEN [public EXCEPT !.val = GenesisVal(generation)]
                     ELSE CandidateCut(generation, execution, c)
    IN [executionHistory |-> execution, leafHistory |-> leaves,
         publicOrigin |-> public, executionOrigin |-> executed]

ExecutedCut(proof, identity, x) ==
    IF x = proof.parent THEN identity.executionOrigin
    ELSE CandidateCut(proof.generation, identity.executionHistory, x)
SuppliedCut(proof, identity, x) ==
    CandidateCut(proof.generation, identity.leafHistory, x)

ExecutionOriginMatches(proof, identity) ==
    /\ identity.executionOrigin.height = identity.publicOrigin.height
    /\ identity.executionOrigin.el = identity.publicOrigin.el
    /\ identity.executionOrigin.comet = identity.publicOrigin.comet
    /\ identity.executionOrigin.fi = identity.publicOrigin.fi
    /\ identity.executionOrigin.val =
          IF proof.parent = startHeight THEN GenesisVal(proof.generation)
          ELSE identity.publicOrigin.val
OriginBound(proof, identity) ==
    /\ identity.publicOrigin = recordCuts[proof.parent]
    /\ ExecutionOriginMatches(proof, identity)
CutsBound(proof, identity) ==
    \A x \in (proof.parent + 1)..(proof.terminal - 1) :
      SuppliedCut(proof, identity, x) = ExecutedCut(proof, identity, x)
BoundaryBound(proof, identity) ==
    proof.parent < c => SuppliedCut(proof, identity, c) = recordCuts[c]
AllowedBoundary(proof, identity) ==
    IF proof.parent = c THEN TRUE
    ELSE CASE BoundaryMode = "Full" -> BoundaryBound(proof, identity)
           [] BoundaryMode = "ELOnly" ->
                  SuppliedCut(proof, identity, c).el = recordCuts[c].el
           [] OTHER -> TRUE

PrepareIdentityProof(h, execution, leaves, alternativeOrigin) ==
    /\ PrepareProof(h)
    /\ queuedIdentity' = BuildIdentity(execution, leaves, alternativeOrigin)
    /\ UNCHANGED <<recordCuts, prefixCuts, prefixGeneration, identityAudit>>

IdentityLand(proof, identity) ==
    /\ Land(proof)
    /\ (~CheckOriginBinding \/ OriginBound(proof, identity))
    /\ AllowedBoundary(proof, identity)
    /\ (~CheckCutBinding \/ CutsBound(proof, identity))
    \* Normative land step 4: FI cannot regress or consume more than the suffix.
    /\ LET terminal == ExecutedCut(proof, identity, proof.terminal)
       IN /\ recordCuts[c].fi <= terminal.fi
          /\ terminal.fi - recordCuts[c].fi <= proof.terminal - c
    /\ recordCuts' = [recordCuts EXCEPT ![proof.terminal] =
                       IF KeepLandingIdentity
                         THEN ExecutedCut(proof, identity, proof.terminal)
                         ELSE AlternativeCut(ExecutedCut(proof, identity, proof.terminal))]
    /\ prefixCuts' = [x \in 0..MaxHeight |->
          IF c < x /\ x <= proof.terminal
            THEN ExecutedCut(proof, identity, x) ELSE prefixCuts[x]]
    /\ prefixGeneration' = [x \in 0..MaxHeight |->
          IF c < x /\ x <= proof.terminal THEN generation ELSE prefixGeneration[x]]
    /\ identityAudit' = [identityAudit EXCEPT
          !.originFault = @ \/ ~OriginBound(proof, identity),
          !.cutFault = @ \/ ~CutsBound(proof, identity),
          !.boundaryFault = @ \/ ~BoundaryBound(proof, identity),
          !.prefixFault = @ \/ (\E x \in 0..c : prefixCuts'[x] # prefixCuts[x]),
          !.goodOverlap = @ \/
              (proof.parent < c /\ OriginBound(proof, identity)
                /\ CutsBound(proof, identity) /\ BoundaryBound(proof, identity)),
          !.reusedOrigin = @ \/
              (generation > 0 /\ startHeight > 0 /\ proof.parent = startHeight
                /\ landings[proof.parent].generation < generation
                /\ identity.executionOrigin.val = GenesisVal(generation)
                /\ identity.executionOrigin.val # identity.publicOrigin.val),
          !.divergentSuffix = @ \/
              (proof.parent < c /\ identity.executionHistory = "B"
                /\ CandidateCut(generation, "A", c) =
                       CandidateCut(generation, "B", c)
                /\ CandidateCut(generation, "A", proof.terminal) #
                       CandidateCut(generation, "B", proof.terminal))]
    /\ UNCHANGED queuedIdentity

IdentityLandFresh(h, execution, leaves, alternativeOrigin) ==
    /\ h \in (c + 1)..MaxHeight
    /\ IdentityLand([present |-> TRUE, generation |-> generation,
                      parent |-> c, terminal |-> h],
                     BuildIdentity(execution, leaves, alternativeOrigin))

IdentityRecover ==
    /\ Recover
    /\ recordCuts' = IF KeepRecoveryIdentity THEN recordCuts
                        ELSE [recordCuts EXCEPT ![c] = AlternativeCut(@)]
    /\ UNCHANGED <<queuedIdentity, prefixCuts, prefixGeneration>>
    /\ identityAudit' = [identityAudit EXCEPT
          !.recoveryFault = @ \/ recordCuts' # recordCuts,
          !.recoveredPositive = @ \/ c > 0]

IdentityNext ==
    \/ \E deadline \in 0..MaxTime :
           Authorize(deadline) /\ UNCHANGED identityVars
    \/ \E h \in 0..MaxHeight, execution \in Histories, leaves \in Histories,
          alternativeOrigin \in BOOLEAN :
           PrepareIdentityProof(h, execution, leaves, alternativeOrigin)
    \/ \E h \in 0..MaxHeight, execution \in Histories, leaves \in Histories,
          alternativeOrigin \in BOOLEAN :
           IdentityLandFresh(h, execution, leaves, alternativeOrigin)
    \/ IdentityLand(pendingProof, queuedIdentity)
    \/ IdentityRecover
    \/ (InvalidateNonce /\ UNCHANGED identityVars)
    \/ (Tick /\ UNCHANGED identityVars)

IdentitySpec == IdentityInit /\ [][IdentityNext]_allVars

IdentityTypeOK ==
    /\ queuedIdentity \in QueuedIdentityType
    /\ recordCuts \in [0..MaxHeight -> CutType]
    /\ prefixCuts \in [0..MaxHeight -> CutType]
    /\ prefixGeneration \in [0..MaxHeight -> 0..MaxGeneration]
    /\ identityAudit \in IdentityAuditType
OriginIdentityBound == ~identityAudit.originFault
ExecutionCutsBound == ~identityAudit.cutFault
OverlapCheckpointBound == ~identityAudit.boundaryFault
RecoveryIdentityPreserved == ~identityAudit.recoveryFault
SettledPrefixStable == ~identityAudit.prefixFault
RetainedRecordsMatchSettledPrefix ==
    \A x \in 0..MaxHeight : landings[x].present => recordCuts[x] = prefixCuts[x]
SettledHistoryCompatible ==
    \A g \in 0..MaxGeneration : \E history \in Histories :
      \A x \in 1..c : prefixGeneration[x] = g =>
        prefixCuts[x] = CandidateCut(g, history, x)

CompatibleOverlapNotReached == ~identityAudit.goodOverlap
ConflictingOverlapNotReached ==
    ~(pendingProof.present /\ pendingProof.parent < c /\ c < pendingProof.terminal
      /\ ExecutedCut(pendingProof, queuedIdentity, c) # recordCuts[c])
SubstitutedLeavesNotReached ==
    ~(pendingProof.present /\ ~CutsBound(pendingProof, queuedIdentity))
IdentityRecoveryNotReached == ~identityAudit.recoveredPositive
RecoveryOriginReuseNotReached == ~identityAudit.reusedOrigin
DivergentSuffixNotReached == ~identityAudit.divergentSuffix
=============================================================================
