---------------------------- MODULE EtnaCommittee ----------------------------
EXTENDS Naturals, FiniteSets, Sequences, TLC
\* Etna d18357214fab30ea512ae9858a11699806d72ba1: fixed immutable registry fixtures.
CONSTANTS NMax, VPUnit, MaxHead, ActivationDelay, IncludePendingFunds, KeyTieBreak,
          UseSwitchSnapshot, UseOriginFloor, UseSwitchRoot, ClearRecoveryPending,
          CorrectHeaderWrite, CorrectSnapshotWrite, PreserveRecoveryL1Snapshot,
          RecordAllSwitches, CaptureCommittedRoot
Keys == 1..3
Snapshots == 0..2
Generations == 0..1
Heights == 1..MaxHead
Pairs == Generations \X Heights
ASSUME /\ NMax \in 1..2 /\ VPUnit \in 1..2 /\ MaxHead = 7
       /\ ActivationDelay \in 1..3
       /\ {IncludePendingFunds, KeyTieBreak, UseSwitchSnapshot, UseOriginFloor,
             UseSwitchRoot, ClearRecoveryPending, CorrectHeaderWrite,
             CorrectSnapshotWrite, PreserveRecoveryL1Snapshot, RecordAllSwitches,
             CaptureCommittedRoot} \subseteq BOOLEAN
Max(a, b) == IF a >= b THEN a ELSE b
Slot(k) == CASE k = 1 -> 2 [] k = 2 -> 0 [] OTHER -> 1
Effective(s, k) == IF k = 2 /\ s = 2 THEN 4 ELSE IF k = 3 THEN 3 ELSE 2
PendingFunds(s, k) == IF s = 2 /\ k = 3 THEN 5 ELSE 0
ActiveFrom(k) == IF k = 3 THEN 1 ELSE 0
ExitAt(k) == IF k = 1 THEN 1 ELSE 3
Eligible(s) == {k \in Keys : ActiveFrom(k) <= s /\ s < ExitAt(k) /\
                              Effective(s, k) >= Max(2, VPUnit)}
SelectionStake(s, k) == Effective(s, k) + IF IncludePendingFunds THEN PendingFunds(s, k) ELSE 0
Before(s, a, b) == SelectionStake(s, a) > SelectionStake(s, b) \/
    (SelectionStake(s, a) = SelectionStake(s, b) /\
       IF KeyTieBreak THEN a < b ELSE Slot(a) < Slot(b))
SelectedKeys(s) == {k \in Eligible(s) :
                    Cardinality({q \in Eligible(s) : Before(s, q, k)}) < NMax}
Selected(s) ==
    LET selected == SelectedKeys(s)
    IN [snapshot |-> s,
        members |-> [i \in 1..Cardinality(selected) |->
           CHOOSE k \in selected : Cardinality({q \in selected : q < k}) = i - 1],
        powers |-> [k \in Keys |-> IF k \in selected THEN SelectionStake(s, k) \div VPUnit ELSE 0]]
\* Independent literal fixture oracle: not Selected/Before or a mutable timing helper.
ExpectedMembers(s) == IF NMax = 1
                        THEN CASE s = 0 -> <<1>> [] s = 1 -> <<3>> [] OTHER -> <<2>>
                        ELSE IF s = 0 THEN <<1, 2>> ELSE <<2, 3>>
Expected(s) ==
    [snapshot |-> s, members |-> ExpectedMembers(s),
     powers |-> [k \in Keys |->
       IF k \in {ExpectedMembers(s)[i] : i \in 1..Len(ExpectedMembers(s))}
         THEN CASE k = 1 -> 2 \div VPUnit
                [] k = 2 -> (IF s = 2 THEN 4 ELSE 2) \div VPUnit
                [] OTHER -> 3 \div VPUnit ELSE 0]]
MemberLists == {<<>>} \cup {<<k>> : k \in Keys} \cup {<<a, b>> : a \in Keys, b \in Keys}
CommitteeType == [snapshot : Snapshots, members : MemberLists, powers : [Keys -> 0..16]]
Header(cmt) == [members |-> cmt.members, powers |-> cmt.powers]
HeaderType == [members : MemberLists, powers : [Keys -> 0..16]]
EmptyPending == [present |-> FALSE, generation |-> 0, switchHeight |-> 0,
                  effectiveHeight |-> 0, committee |-> Selected(0)]
PendingType == [present : BOOLEAN, generation : Generations, switchHeight : 0..MaxHead,
                effectiveHeight : 0..(MaxHead + 3), committee : CommitteeType]
DerivationType == [generation : Generations, height : Heights, dAnchor : Snapshots,
                   switchAnchor : Snapshots, origin : Snapshots, snapshot : Snapshots,
                   proofRoot : {<<"RegistryRoot", s>> : s \in Snapshots}, committee : CommitteeType]
IsSwitch(h) == h % 3 = 2

VARIABLES initialized, head, generation, l1Tip, originL1, generationStart, genesisCommittees,
          active, pending, anchors, derivations, committed, used, headerCurrent,
          headerNext, reportedSnapshot, landedCheckpoint, l1ActiveSnapshot,
          lastLand, maximumL1Snapshot, canonicalGeneration, committedAnchors,
          committedParents, generationOrigins, recoveryOriginHeight, event
vars == <<initialized, head, generation, l1Tip, originL1, generationStart, genesisCommittees,
          active, pending, anchors, derivations, committed, used, headerCurrent,
          headerNext, reportedSnapshot, landedCheckpoint, l1ActiveSnapshot,
          lastLand, maximumL1Snapshot, canonicalGeneration, committedAnchors,
          committedParents, generationOrigins, recoveryOriginHeight, event>>
EmitSwitch(h, a) == IsSwitch(h) /\
    (RecordAllSwitches \/ ~(generation = 0 /\ h = 2 /\ a = 2))
Init ==
    /\ initialized = FALSE
    /\ head = 0 /\ generation = 0 /\ l1Tip = 0 /\ originL1 = 0
    /\ generationStart = [g \in Generations |-> 0]
    /\ genesisCommittees = [g \in Generations |-> Selected(0)]
    /\ active = Selected(0) /\ pending = EmptyPending
    /\ anchors = [h \in 0..MaxHead |-> 0]
    /\ derivations = {} /\ committed = {}
    /\ used = [p \in Pairs |-> Selected(0)]
    /\ headerCurrent = [p \in Pairs |-> Header(Selected(0))] /\ headerNext = headerCurrent
    /\ reportedSnapshot = [p \in Pairs |-> 0]
    /\ landedCheckpoint = 0 /\ l1ActiveSnapshot = 0 /\ maximumL1Snapshot = 0
    /\ canonicalGeneration = [h \in 0..MaxHead |-> 0]
    /\ committedAnchors = [p \in Pairs |-> 0]
    /\ committedParents = [p \in Pairs |-> <<0, 0>>]
    /\ generationOrigins = [g \in Generations |-> 0] /\ recoveryOriginHeight = 0
    /\ lastLand = [generation |-> 0, height |-> 0, actualSnapshot |-> 0]
    /\ event = "None"
Initialize ==
    /\ ~initialized /\ initialized' = TRUE
    /\ genesisCommittees' = [genesisCommittees EXCEPT ![0] = Selected(0)]
    /\ active' = Selected(0) /\ event' = "Initialized"
    /\ UNCHANGED <<head, generation, l1Tip, originL1, generationStart, pending, anchors,
          derivations, committed, used, headerCurrent, headerNext, reportedSnapshot,
          landedCheckpoint, l1ActiveSnapshot, lastLand, maximumL1Snapshot>>
    /\ UNCHANGED <<canonicalGeneration, committedAnchors, committedParents,
                    generationOrigins, recoveryOriginHeight>>
SelectionSnapshot(h, newAnchor) ==
    IF UseSwitchSnapshot THEN newAnchor
    ELSE IF h - 1 <= 0 THEN originL1
    ELSE IF UseOriginFloor THEN Max(anchors[h - 1], originL1) ELSE anchors[h - 1]
NewPending(h, a) ==
    [present |-> TRUE, generation |-> generation, switchHeight |-> h,
     effectiveHeight |-> h + ActivationDelay, committee |-> Selected(SelectionSnapshot(h, a))]
Commit(a) ==
    /\ initialized
    /\ head < MaxHead /\ a \in originL1..l1Tip
    /\ (head = generationStart[generation] \/ a >= anchors[head])
    /\ LET h == head + 1
           signer == IF pending.present /\ pending.effectiveHeight <= h
                       THEN pending.committee ELSE active
           pendingAfter == IF EmitSwitch(h, a) THEN NewPending(h, a)
                            ELSE IF pending.present /\ pending.effectiveHeight <= h
                              THEN EmptyPending ELSE pending
           nextSigner == IF pendingAfter.present /\ pendingAfter.effectiveHeight <= h + 1
                           THEN pendingAfter.committee ELSE signer
           alternative == IF pendingAfter.present THEN pendingAfter.committee ELSE signer
           capturedRootAnchor == IF ~CaptureCommittedRoot /\ generation = 0 /\ h = 2 /\ a = 2
                                   THEN SelectionSnapshot(h, a) ELSE a
           proofRoot == IF UseSwitchRoot THEN capturedRootAnchor ELSE SelectionSnapshot(h, a)
       IN /\ head' = h /\ active' = nextSigner /\ pending' = pendingAfter
          /\ anchors' = [anchors EXCEPT ![h] = a]
          /\ committed' = committed \cup {<<generation, h>>}
          /\ canonicalGeneration' = [canonicalGeneration EXCEPT ![h] = generation]
          /\ committedAnchors' = [committedAnchors EXCEPT ![<<generation, h>>] = a]
          /\ committedParents' = [committedParents EXCEPT
                                       ![<<generation, h>>] = <<canonicalGeneration[head], head>>]
          /\ used' = [used EXCEPT ![<<generation, h>>] = signer]
          /\ headerCurrent' = [headerCurrent EXCEPT ![<<generation, h>>] =
                    Header(IF CorrectHeaderWrite THEN signer ELSE alternative)]
          /\ headerNext' = [headerNext EXCEPT ![<<generation, h>>] = Header(nextSigner)]
          /\ reportedSnapshot' = [reportedSnapshot EXCEPT ![<<generation, h>>] =
                    IF CorrectSnapshotWrite THEN signer.snapshot ELSE alternative.snapshot]
          /\ derivations' = IF EmitSwitch(h, a) THEN derivations \cup
                {[generation |-> generation, height |-> h,
                   dAnchor |-> IF h - 1 <= 0 THEN originL1 ELSE anchors[h - 1],
                   switchAnchor |-> capturedRootAnchor, origin |-> originL1,
                   snapshot |-> SelectionSnapshot(h, a),
                   proofRoot |-> <<"RegistryRoot", proofRoot>>,
                   committee |-> Selected(SelectionSnapshot(h, a))]} ELSE derivations
          /\ event' = IF EmitSwitch(h, a) THEN "SwitchCommitted" ELSE "Committed"
    /\ UNCHANGED <<generation, l1Tip, originL1, generationStart, genesisCommittees,
          landedCheckpoint, l1ActiveSnapshot, lastLand, maximumL1Snapshot>>
    /\ UNCHANGED initialized
    /\ UNCHANGED <<generationOrigins, recoveryOriginHeight>>
AdvanceL1 ==
    /\ initialized
    /\ l1Tip < 2 /\ l1Tip' = l1Tip + 1 /\ event' = "L1Advanced"
    /\ UNCHANGED <<head, generation, originL1, generationStart, genesisCommittees,
          active, pending, anchors, derivations, committed, used, headerCurrent,
          headerNext, reportedSnapshot, landedCheckpoint, l1ActiveSnapshot, lastLand, maximumL1Snapshot>>
    /\ UNCHANGED <<canonicalGeneration, committedAnchors, committedParents,
                    generationOrigins, recoveryOriginHeight>>
    /\ UNCHANGED initialized
Land(h) ==
    /\ initialized
    /\ h \in (landedCheckpoint + 1)..head /\ <<generation, h>> \in committed
    /\ landedCheckpoint' = h
    /\ l1ActiveSnapshot' = reportedSnapshot[<<generation, h>>]
    /\ lastLand' = [generation |-> generation, height |-> h,
                     actualSnapshot |-> used[<<generation, h>>].snapshot]
    /\ maximumL1Snapshot' = Max(maximumL1Snapshot, l1ActiveSnapshot')
    /\ event' = "Landed"
    /\ UNCHANGED <<head, generation, l1Tip, originL1, generationStart, genesisCommittees,
          active, pending, anchors, derivations, committed, used, headerCurrent, headerNext, reportedSnapshot>>
    /\ UNCHANGED <<canonicalGeneration, committedAnchors, committedParents,
                    generationOrigins, recoveryOriginHeight>>
    /\ UNCHANGED initialized
Recover ==
    /\ initialized
    /\ generation = 0 /\ l1Tip = 2 /\ landedCheckpoint \in {1, 2, 3}
    /\ generationOrigins' = [generationOrigins EXCEPT ![1] = l1Tip]
    /\ recoveryOriginHeight' = landedCheckpoint
    /\ generation' = 1 /\ head' = landedCheckpoint /\ originL1' = 2
    /\ generationStart' = [generationStart EXCEPT ![1] = landedCheckpoint]
    /\ genesisCommittees' = [genesisCommittees EXCEPT ![1] = Selected(2)]
    /\ active' = Selected(2)
    /\ pending' = IF ClearRecoveryPending THEN EmptyPending ELSE pending
    /\ l1ActiveSnapshot' = IF PreserveRecoveryL1Snapshot THEN l1ActiveSnapshot ELSE 2
    /\ maximumL1Snapshot' = Max(maximumL1Snapshot, l1ActiveSnapshot')
    /\ event' = "Recovered"
    /\ UNCHANGED <<l1Tip, anchors, derivations, committed, used, headerCurrent,
          headerNext, reportedSnapshot, landedCheckpoint, lastLand>>
    /\ UNCHANGED initialized
    /\ UNCHANGED <<canonicalGeneration, committedAnchors, committedParents>>
Next == \/ Initialize \/ AdvanceL1 \/ \E a \in Snapshots : Commit(a)
        \/ \E h \in Heights : Land(h) \/ Recover
CommitteeSpec == Init /\ [][Next]_vars

\* Oracle uses raw captured D/switch/origin inputs and fixed +2, not action knobs.
ExpectedUpdateSnapshot(d) == IF d.height - 1 <= 0 THEN d.origin ELSE Max(d.dAnchor, d.origin)
OracleCommittee(g, h) ==
    LET updates == {d \in derivations : d.generation = g /\ d.height + 2 <= h}
    IN IF updates = {} THEN Expected(IF g = 0 THEN 0 ELSE 2)
       ELSE LET latest == CHOOSE d \in updates : \A other \in updates : d.height >= other.height
            IN Expected(ExpectedUpdateSnapshot(latest))
CommitteeTypeOK ==
    /\ initialized \in BOOLEAN
    /\ head \in 0..MaxHead /\ generation \in Generations /\ l1Tip \in Snapshots /\ originL1 \in Snapshots
    /\ generationStart \in [Generations -> 0..MaxHead]
    /\ canonicalGeneration \in [0..MaxHead -> Generations]
    /\ committedAnchors \in [Pairs -> Snapshots]
    /\ committedParents \in [Pairs -> (Generations \X (0..MaxHead))]
    /\ generationOrigins \in [Generations -> Snapshots] /\ recoveryOriginHeight \in 0..MaxHead
    /\ genesisCommittees \in [Generations -> CommitteeType]
    /\ active \in CommitteeType /\ pending \in PendingType
    /\ anchors \in [0..MaxHead -> Snapshots] /\ derivations \subseteq DerivationType
    /\ committed \subseteq Pairs /\ used \in [Pairs -> CommitteeType]
    /\ headerCurrent \in [Pairs -> HeaderType] /\ headerNext \in [Pairs -> HeaderType]
    /\ reportedSnapshot \in [Pairs -> Snapshots]
    /\ landedCheckpoint \in 0..head /\ l1ActiveSnapshot \in Snapshots /\ maximumL1Snapshot \in Snapshots
    /\ lastLand \in [generation : Generations, height : 0..MaxHead, actualSnapshot : Snapshots]
    /\ event \in {"None", "Initialized", "SwitchCommitted", "Committed", "L1Advanced", "Landed", "Recovered"}
GenesisSelectionCorrect == initialized => genesisCommittees[0] = Expected(0)
GenerationOriginCorrect ==
    /\ originL1 = generationOrigins[generation]
    /\ generationOrigins[0] = 0
    /\ generation = 1 => (generationOrigins[1] = 2 /\ generationStart[1] = recoveryOriginHeight)
SwitchCalendarCorrect ==
    /\ \A d \in derivations : <<d.generation, d.height>> \in committed
    /\ \A p \in committed :
          Cardinality({d \in derivations : d.generation = p[1] /\ d.height = p[2]}) =
            (IF p[2] % 3 = 2 THEN 1 ELSE 0)
RawInputsMatchHistory == \A d \in derivations :
    LET pair == <<d.generation, d.height>>
        parent == committedParents[pair]
    IN /\ d.switchAnchor = committedAnchors[pair]
       /\ d.origin = generationOrigins[d.generation]
       /\ parent[2] = d.height - 1
       /\ (parent[2] = 0 \/ parent \in committed)
       /\ d.dAnchor = IF d.height - 1 <= 0 THEN generationOrigins[d.generation]
                        ELSE committedAnchors[parent]
DerivationSnapshotCorrect == \A d \in derivations : d.snapshot = ExpectedUpdateSnapshot(d)
DerivedSelectionCorrect ==
    /\ generation = 1 => genesisCommittees[1] = Expected(2)
    /\ \A d \in derivations : d.committee = Expected(d.snapshot)
ProofRootCorrect == \A d \in derivations : d.proofRoot = <<"RegistryRoot", d.switchAnchor>>
PendingBelongsToGeneration == pending.present => pending.generation = generation
ActualScheduleCorrect == \A p \in committed : used[p] = OracleCommittee(p[1], p[2])
HeaderCurrentCorrect == \A p \in committed : headerCurrent[p] = Header(OracleCommittee(p[1], p[2]))
HeaderNextCorrect == \A p \in committed : headerNext[p] = Header(OracleCommittee(p[1], p[2] + 1))
RecordedSnapshotCorrect == \A p \in committed : reportedSnapshot[p] = OracleCommittee(p[1], p[2]).snapshot
L1SnapshotMatchesLanding == l1ActiveSnapshot = lastLand.actualSnapshot
NoL1SnapshotRegression == l1ActiveSnapshot >= maximumL1Snapshot
PowerChangeNotReached ==
    ~(<<0, 4>> \in committed /\ <<0, 7>> \in committed /\
       used[<<0, 4>>].members = <<2, 3>> /\ used[<<0, 7>>].members = <<2, 3>> /\
       used[<<0, 4>>].snapshot = 1 /\ used[<<0, 7>>].snapshot = 2 /\
       used[<<0, 4>>].powers # used[<<0, 7>>].powers)
ReplacementNotReached ==
    ~(<<0, 2>> \in committed /\ <<0, 3>> \in committed /\ <<0, 4>> \in committed /\
       used[<<0, 2>>].members = <<1>> /\ used[<<0, 3>>].members = <<1>> /\
       used[<<0, 4>>].members = <<3>>)
RecoveryBeforeSwitchNotReached ==
    ~(generation = 1 /\ generationStart[1] = 1 /\ <<1, 2>> \in committed /\
       \E d \in derivations : d.generation = 1 /\ d.height = 2 /\ d.snapshot = 2 /\ d.dAnchor < d.origin)
RecoveryAtSwitchNotReached ==
    ~(generation = 1 /\ generationStart[1] = 2 /\ <<1, 4>> \in committed /\
       used[<<1, 4>>] = Expected(2))
RecoveryAfterSwitchNotReached ==
    ~(generation = 1 /\ generationStart[1] = 3 /\ <<1, 4>> \in committed /\
       used[<<1, 4>>] = Expected(2))
=============================================================================
