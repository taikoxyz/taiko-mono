---------------------------- MODULE EtnaRecoveryTime ----------------------------
EXTENDS Integers, TLC
CONSTANT CaseIds
VARIABLES caseId, raw, observed, ready
vars == <<caseId,raw,observed,ready>>
CaseNames == {"equal-times","parent-dominates","later-anchor"}
ASSUME CaseIds \subseteq CaseNames /\ CaseIds # {}

\* Trusted inputs: authenticated retained parent, fixed origin and finalized anchor.
\* This is a first-header interface, not a replayed STF/consensus state machine.
Fixture(id) == [generation |-> 1,
 parent |-> [height |-> 12,elTimestamp |-> IF id="parent-dominates" THEN 3 ELSE 1],
 origin |-> [height |-> 12,l1Number |-> 103,l1Timestamp |-> 3],
 anchor |-> [l1Number |-> IF id="later-anchor" THEN 104 ELSE 103,
             l1Timestamp |-> IF id="later-anchor" THEN 4 ELSE 3]]
Max2(a,b) == IF a>b THEN a ELSE b
FirstBFT(x) == x.origin.l1Timestamp
FirstEL(x) == Max2(x.parent.elTimestamp+1, Max2(FirstBFT(x),x.anchor.l1Timestamp))
Header(x) == [generation |-> x.generation,height |-> x.origin.height+1,
 parentHeight |-> x.parent.height,bftTime |-> FirstBFT(x),elTimestamp |-> FirstEL(x),
 anchor |-> x.anchor,lastBlockIDEmpty |-> TRUE,lastCommitEmpty |-> TRUE]
Init == /\ caseId \in CaseIds /\ raw=Fixture(caseId)
        /\ observed=[present |-> FALSE] /\ ready=FALSE
Prepare == /\ ~ready /\ ready'=TRUE /\ UNCHANGED <<caseId,raw,observed>>
Construct == /\ ~observed.present /\ ready
             /\ observed'=[present |-> TRUE,raw |-> raw,header |-> Header(raw)]
             /\ UNCHANGED <<caseId,raw,ready>>
Spec == Init /\ [][Prepare \/ Construct]_vars

\* Independently captured literal oracle: never calls Fixture, Header or Max2.
\* Bind BOTH clocks, generation, retained parent, recovery origin and anchor.
Audit(id) == CASE id="equal-times" ->
 [raw |-> [generation |-> 1,parent |-> [height |-> 12,elTimestamp |-> 1],
           origin |-> [height |-> 12,l1Number |-> 103,l1Timestamp |-> 3],
           anchor |-> [l1Number |-> 103,l1Timestamp |-> 3]],
  header |-> [generation |-> 1,height |-> 13,parentHeight |-> 12,bftTime |-> 3,
              elTimestamp |-> 3,anchor |-> [l1Number |-> 103,l1Timestamp |-> 3],
              lastBlockIDEmpty |-> TRUE,lastCommitEmpty |-> TRUE]]
 [] id="parent-dominates" ->
 [raw |-> [generation |-> 1,parent |-> [height |-> 12,elTimestamp |-> 3],
           origin |-> [height |-> 12,l1Number |-> 103,l1Timestamp |-> 3],
           anchor |-> [l1Number |-> 103,l1Timestamp |-> 3]],
  header |-> [generation |-> 1,height |-> 13,parentHeight |-> 12,bftTime |-> 3,
              elTimestamp |-> 4,anchor |-> [l1Number |-> 103,l1Timestamp |-> 3],
              lastBlockIDEmpty |-> TRUE,lastCommitEmpty |-> TRUE]]
 [] id="later-anchor" ->
 [raw |-> [generation |-> 1,parent |-> [height |-> 12,elTimestamp |-> 1],
           origin |-> [height |-> 12,l1Number |-> 103,l1Timestamp |-> 3],
           anchor |-> [l1Number |-> 104,l1Timestamp |-> 4]],
  header |-> [generation |-> 1,height |-> 13,parentHeight |-> 12,bftTime |-> 3,
              elTimestamp |-> 4,anchor |-> [l1Number |-> 104,l1Timestamp |-> 4],
              lastBlockIDEmpty |-> TRUE,lastCommitEmpty |-> TRUE]]
RawPremisesBound == raw=Audit(caseId).raw
ObservationExact == ~observed.present \/
    (observed.raw=Audit(caseId).raw /\ observed.header=Audit(caseId).header)
ConstructionEnabled == (ready /\ ~observed.present) => ENABLED Construct
EqualNotReached == ~(observed.present /\ caseId="equal-times")
ParentNotReached == ~(observed.present /\ caseId="parent-dominates")
LaterNotReached == ~(observed.present /\ caseId="later-anchor")
\* Deliberately false only on the two valid EL4/BFT3 cases; scoped RED control.
CollapsedClockIdentity == ~observed.present \/ observed.header.elTimestamp=observed.header.bftTime
=============================================================================
