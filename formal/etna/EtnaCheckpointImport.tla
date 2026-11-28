----------------------- MODULE EtnaCheckpointImport -----------------------
EXTENDS Integers, FiniteSets, TLC
\* SPEC d18357214fab30ea512ae9858a11699806d72ba1, DATA-5.3/5.4 and SYNC-9.
\* Thin import boundary; symbolic commitments, fixed authenticated window.
CONSTANTS ImportHeight, TargetHeight, RawCases, Mutant
ASSUME /\ ImportHeight \in {2, 4} /\ TargetHeight \in {2, 4, 6}
       /\ ImportHeight <= TargetHeight /\ RawCases \subseteq 0..29 /\ RawCases # {}
Origin == 2
Chain == <<"Chain", 1>>
StoreNames == {"el", "app", "comet", "evidence"}
EL(h) == <<"EL", h>>
Root(h) == <<"State", h>>
KP(c) == <<c.keys, c.powers>>
VHash(c) == <<"Validators", KP(c)>>
Hash(x) == <<"Hash", x>>
First == [keys |-> <<1, 2>>, powers |-> <<3, 2>>, priorities |-> <<-1, 1>>, proposer |-> 1]
Second == [keys |-> <<2, 3>>, powers |-> <<2, 4>>, priorities |-> <<2, -1>>, proposer |-> 2]
Preimage == [first |-> First, second |-> Second]
GenesisPreimage == [first |-> [keys |-> <<1, 2>>, powers |-> <<3, 2>>, priorities |-> <<-2, 2>>, proposer |-> 1],
                    second |-> [keys |-> <<1, 2>>, powers |-> <<3, 2>>, priorities |-> <<1, -1>>, proposer |-> 2]]
RequiredAncestors == Origin..ImportHeight
RequiredEvidence == IF ImportHeight = Origin THEN {} ELSE {<<"Evidence", 3>>}
Window == [ancestors |-> RequiredAncestors, evidence |-> RequiredEvidence,
           validators |-> <<"WindowValidators", ImportHeight>>,
           commits |-> <<"WindowCommits", ImportHeight>>]
Envelope == [execution |-> EL(ImportHeight)]
Header == [height |-> ImportHeight, chain |-> IF ImportHeight = Origin THEN <<"Chain", 0>> ELSE Chain,
           data |-> Hash(Envelope),
           next |-> VHash(First), appHash |-> EL(ImportHeight - 1),
           window |-> Hash(Window), time |-> IF ImportHeight = Origin THEN 20 ELSE 102]
\* Genesis does not authenticate the old-generation Comet/validator hashes.
Landing == [height |-> ImportHeight, generation |-> 1, origin |-> Origin, originTime |-> 100,
            recordGeneration |-> IF ImportHeight = Origin THEN 0 ELSE 1,
            finalized |-> TRUE, el |-> EL(ImportHeight), state |-> Root(ImportHeight),
            comet |-> Hash(Header), val |-> Hash(Preimage), fi |-> 1,
            registry |-> Hash(<<KP(First), KP(Second)>>)]
Peer == [present |-> TRUE, header |-> Header, envelope |-> Envelope,
         el |-> EL(ImportHeight), state |-> Root(ImportHeight),
         computedState |-> Root(ImportHeight), preimage |-> Preimage,
         entries |-> <<KP(First), KP(Second)>>, window |-> Window,
         ancestors |-> RequiredAncestors, evidence |-> RequiredEvidence]
Input == [l1 |-> Landing, peer |-> Peer]
\* Cases only construct raw inputs. No operational/oracle verdict reads a case id.
Raw(i) == CASE
    i = 1 -> [Input EXCEPT !.l1.finalized = FALSE]
 [] i = 2 -> [Input EXCEPT !.peer.envelope.execution = EL(99)]
 [] i = 3 -> LET env == [Envelope EXCEPT !.execution = EL(99)]
                hdr == [Header EXCEPT !.data = Hash(env)]
            IN [Input EXCEPT !.peer.envelope = env, !.peer.header = hdr,
                              !.l1.comet = Hash(hdr)]
 [] i = 4 -> [Input EXCEPT !.peer.preimage.first.proposer = 2]
 [] i = 5 -> LET pre == [Preimage EXCEPT !.first.powers = <<4, 2>>]
            IN [Input EXCEPT !.peer.preimage = pre, !.l1.val = Hash(pre)]
 [] i = 6 -> LET entries == <<<<First.keys, <<4, 2>>>>, KP(Second)>>
            IN [Input EXCEPT !.peer.entries = entries, !.l1.registry = Hash(entries)]
 [] i = 7 -> [Input EXCEPT !.peer.present = FALSE]
 [] i = 8 -> [Input EXCEPT !.peer.ancestors = {ImportHeight}]
 [] i = 9 -> [Input EXCEPT !.peer.computedState = Root(99)]
 [] i = 10 -> [Input EXCEPT !.peer.evidence = {}]
 [] i = 11 -> LET pre == [Preimage EXCEPT !.first.powers = <<3, 5>>,
                                       !.first.priorities = <<4, -4>>, !.first.proposer = 2,
                                       !.second.priorities = <<-1, 1>>]
                 entries == <<KP(pre.first), KP(pre.second)>>
                 hdr == [Header EXCEPT !.next = VHash(pre.first)]
             IN [Input EXCEPT !.peer.preimage = pre, !.l1.val = Hash(pre),
                   !.peer.entries = entries, !.l1.registry = Hash(entries),
                   !.peer.header = hdr, !.l1.comet = Hash(hdr)]
 [] i = 12 -> LET env == [Envelope EXCEPT !.execution = EL(99)]
                 hdr == [Header EXCEPT !.data = Hash(env)]
             IN [Input EXCEPT !.peer.envelope = env, !.peer.header = hdr,
                   !.l1.comet = Hash(hdr), !.peer.preimage.first.proposer = 2]
 [] i = 13 -> LET pre == [Preimage EXCEPT !.first.powers = <<4, 2>>]
             IN [Input EXCEPT !.peer.preimage = pre, !.l1.val = Hash(pre),
                               !.peer.ancestors = {ImportHeight}]
 [] i = 14 -> LET entries == <<<<First.keys, <<4, 2>>>>, KP(Second)>>
             IN [Input EXCEPT !.peer.entries = entries, !.l1.registry = Hash(entries),
                               !.peer.evidence = {}]
 [] i = 15 -> [Input EXCEPT !.peer.header.time = 99]
 [] i = 16 -> [Input EXCEPT !.peer.el = EL(99)]
 \* Matching bad downloaded/computed roots leave only the L1 root binding false.
 [] i = 17 -> [Input EXCEPT !.peer.state = Root(99), !.peer.computedState = Root(99)]
 \* Keep authenticated commitments unchanged: these are corrupt peer candidates.
 [] i = 18 -> [Input EXCEPT !.peer.entries = <<KP(Second), KP(First)>>]
 [] i = 19 -> [Input EXCEPT !.peer.window.validators = <<"WrongWindowValidators">>]
 \* Landed proposer/priority values are authoritative for both future sets.
 [] i = 20 -> LET pre == [Preimage EXCEPT !.second.powers = <<3, 4>>,
                                       !.second.priorities = <<2, -2>>]
                 entries == <<KP(pre.first), KP(pre.second)>>
             IN [Input EXCEPT !.peer.preimage = pre, !.l1.val = Hash(pre),
                   !.peer.entries = entries, !.l1.registry = Hash(entries)]
 \* Match the derived entries to the changed preimage, isolating header.next.
 [] i = 21 -> LET pre == [Preimage EXCEPT !.first.powers = <<4, 2>>]
                 entries == <<KP(pre.first), KP(pre.second)>>
             IN [Input EXCEPT !.peer.preimage = pre, !.l1.val = Hash(pre),
                               !.peer.entries = entries, !.l1.registry = Hash(entries)]
 \* A contradictory-looking package cannot prove a conflict before finality/arrival.
 [] i = 22 -> LET env == [Envelope EXCEPT !.execution = EL(99)]
                 hdr == [Header EXCEPT !.data = Hash(env)]
             IN [Input EXCEPT !.peer.envelope = env, !.peer.header = hdr,
                               !.l1.comet = Hash(hdr), !.l1.finalized = FALSE]
 [] i = 23 -> LET env == [Envelope EXCEPT !.execution = EL(99)]
                 hdr == [Header EXCEPT !.data = Hash(env)]
             IN [Input EXCEPT !.peer.envelope = env, !.peer.header = hdr,
                               !.l1.comet = Hash(hdr), !.peer.present = FALSE]
 \* Coherent corrupt peer bundle; do not rebind the retained L1 Comet commitment.
 [] i = 24 -> LET env == [Envelope EXCEPT !.execution = EL(99)]
                 hdr == [Header EXCEPT !.data = Hash(env)]
             IN [Input EXCEPT !.peer.envelope = env, !.peer.header = hdr]
 \* Match entries to the corrupt preimage, without rebinding either L1 commitment.
 [] i = 25 -> LET pre == [Preimage EXCEPT !.first.powers = <<4, 2>>]
                  entries == <<KP(pre.first), KP(pre.second)>>
              IN [Input EXCEPT !.peer.preimage = pre, !.peer.entries = entries]
 \* Only the second set changes: header.next still agrees with the first set.
 [] i = 26 -> [Input EXCEPT !.peer.preimage.second.powers = <<3, 4>>]
 \* Negative classifier input: conflicting bound entries plus an unbound window.
 [] i = 27 -> LET entries == <<KP(Second), KP(First)>>
              IN [Input EXCEPT !.peer.entries = entries, !.l1.registry = Hash(entries),
                                !.peer.window.validators = <<"WrongWindowValidators">>]
 \* Negative classifier inputs: bind only the changed header to the retained L1 record.
 \* These tuples do not establish proof-valid landings or a proven contradiction.
 [] i = 28 -> LET hdr == [Header EXCEPT !.chain = <<"Chain", 99>>]
              IN [Input EXCEPT !.peer.header = hdr, !.l1.comet = Hash(hdr)]
 [] i = 29 -> LET hdr == [Header EXCEPT !.height = 99]
              IN [Input EXCEPT !.peer.header = hdr, !.l1.comet = Hash(hdr)]
 [] OTHER -> Input
Inputs == {Raw(i) : i \in RawCases}
AtOrigin(x) == x.l1.height = x.l1.origin
Missing(x) == ~x.peer.present \/ ~x.l1.finalized \/
              ~RequiredAncestors \subseteq x.peer.ancestors \/
              ~RequiredEvidence \subseteq x.peer.evidence
Authentic(x) ==
    /\ x.peer.el = x.l1.el /\ x.peer.state = x.l1.state
    /\ x.peer.computedState = x.peer.state
    /\ AtOrigin(x) \/
       /\ Hash(x.peer.header) = x.l1.comet
       /\ Hash(x.peer.envelope) = x.peer.header.data
       /\ Hash(x.peer.preimage) = x.l1.val
       /\ Hash(x.peer.entries) = x.l1.registry
       /\ Hash(x.peer.window) = x.peer.header.window
       /\ x.peer.header.chain = Chain /\ x.peer.header.height = x.l1.height
ProvenContradiction(x) ==
    /\ ~AtOrigin(x) /\ x.l1.finalized /\ x.peer.present
    /\ Hash(x.peer.header) = x.l1.comet
    /\ \/ (Hash(x.peer.envelope) = x.peer.header.data /\ x.peer.envelope.execution # x.l1.el)
        \/ (Hash(x.peer.preimage) = x.l1.val /\ VHash(x.peer.preimage.first) # x.peer.header.next)
        \/ (Hash(x.peer.preimage) = x.l1.val /\ Hash(x.peer.entries) = x.l1.registry /\
             Hash(x.peer.window) = x.peer.header.window /\
             x.peer.entries # <<KP(x.peer.preimage.first), KP(x.peer.preimage.second)>>)
Decision(x) ==
    IF ProvenContradiction(x) THEN IF Mutant = "ContradictionRetry" THEN "Reject" ELSE "Halt"
    ELSE IF Missing(x) THEN IF Mutant = "MissingHalt" THEN "Halt"
                           ELSE IF Mutant = "Unfinalized" /\ ~x.l1.finalized THEN "Verified"
                           ELSE "Wait"
    ELSE IF ~Authentic(x) THEN IF Mutant = "BadPeer" THEN "Verified" ELSE "Reject"
    ELSE "Verified"
\* Source for origin sets is fixed genesis, not the retained old-generation preimage.
InstallPreimage(x) == IF AtOrigin(x) /\ Mutant # "OriginUsesLanded" THEN GenesisPreimage ELSE x.peer.preimage
Planned(x) ==
    LET pre == InstallPreimage(x)
    IN [el |-> [height |-> x.l1.height, hash |-> x.peer.el, state |-> x.peer.computedState,
                 ancestors |-> x.peer.ancestors, fi |-> x.l1.fi],
        app |-> [height |-> IF AtOrigin(x) THEN 0 ELSE x.l1.height, appHash |-> x.peer.el, chain |-> Chain,
                  initialHeight |-> Origin + 1, fi |-> x.l1.fi,
                  active |-> KP(pre.first), pending |-> KP(pre.second), recorded |-> pre],
        comet |-> [height |-> IF AtOrigin(x) THEN 0 ELSE x.l1.height, appHash |-> x.peer.el, chain |-> Chain,
                    initialHeight |-> Origin + 1, validators |-> pre.first, next |-> pre.second,
                    last |-> IF AtOrigin(x) THEN <<>> ELSE x.peer.window.validators,
                    blockID |-> IF AtOrigin(x) THEN <<>> ELSE Hash(x.peer.header),
                    time |-> IF AtOrigin(x) THEN x.l1.originTime ELSE x.peer.header.time, results |-> IF ImportHeight = Origin THEN <<>> ELSE <<"FixedExecTxResult">>,
                    valChanged |-> IF AtOrigin(x) THEN Origin + 1 ELSE x.l1.height + 2,
                    paramsChanged |-> IF AtOrigin(x) THEN Origin + 1 ELSE x.l1.height + 1],
        evidence |-> [markers |-> x.peer.evidence, validators |-> IF AtOrigin(x) THEN <<>> ELSE x.peer.window.validators,
                       commits |-> IF AtOrigin(x) THEN <<>> ELSE x.peer.window.commits]]
EmptyStores == [k \in StoreNames |-> "Empty"]
Written(k, x) ==
    LET base == Planned(x)
    IN CASE Mutant = "WrongELStore" /\ k = "el" -> [base.el EXCEPT !.hash = EL(99)]
       [] Mutant = "WrongPriority" /\ k = "comet" ->
            [base.comet EXCEPT !.validators.priorities = <<0, 0>>]
       [] Mutant = "WrongProposer" /\ k = "comet" -> [base.comet EXCEPT !.next.proposer = 3]
       [] Mutant = "WrongFI" /\ k = "app" -> [base.app EXCEPT !.fi = 0]
       [] Mutant = "WrongPending" /\ k = "app" -> [base.app EXCEPT !.pending = KP(First)]
       [] Mutant = "WrongOriginHeight" /\ k = "app" -> [base.app EXCEPT !.height = x.l1.height]
       [] Mutant = "WrongAppHash" /\ k = "app" -> [base.app EXCEPT !.appHash = x.peer.header.appHash]
       [] Mutant = "MissingAncestor" /\ k = "el" -> [base.el EXCEPT !.ancestors = {ImportHeight}]
       [] Mutant = "MissingEvidence" /\ k = "evidence" -> [base.evidence EXCEPT !.markers = {}]
       [] Mutant = "NewGenesis" /\ k = "comet" -> [base.comet EXCEPT !.initialHeight = ImportHeight + 1]
       [] OTHER -> base[k]

VARIABLES n, seen, event
vars == <<n, seen, event>>
Init ==
    /\ \E x \in Inputs : n =
        [input |-> x, phase |-> "Check", stores |-> EmptyStores, staged |-> {}, durable |-> {},
         published |-> FALSE, boundary |-> EmptyStores, trusted |-> FALSE, connected |-> FALSE,
         knownGeneration |-> 1, targetReady |-> FALSE, reached |-> ImportHeight,
         localEL |-> EL(ImportHeight), localComet |-> Hash(Header), localVal |-> Hash(Preimage),
         hrs |-> <<1, 9, 2>>, crashes |-> 0, resumed |-> FALSE, retried |-> FALSE]
    /\ seen = [classification |-> [present |-> FALSE, input |-> Input, result |-> "Wait"],
                publication |-> [present |-> FALSE, input |-> Input, stores |-> EmptyStores,
                                  durable |-> {}, crash |-> FALSE],
                admission |-> [present |-> FALSE, height |-> 0, known |-> 1,
                                el |-> EL(0), comet |-> Hash(Header), val |-> Hash(Preimage)],
                halt |-> FALSE, partialCrash |-> FALSE, restartTrusted |-> FALSE]
    /\ event = "Init"
Check ==
    /\ n.phase = "Check"
    /\ n' = [n EXCEPT !.phase = Decision(n.input)]
    /\ seen' = [seen EXCEPT
          !.classification = [present |-> TRUE, input |-> n.input, result |-> Decision(n.input)],
          !.halt = @ \/ Decision(n.input) = "Halt"]
    /\ event' = "Classified"
Retry ==
    /\ n.phase = "Wait"
    /\ n' = [n EXCEPT !.phase = "Check", !.retried = TRUE,
               !.input.l1.finalized = TRUE, !.input.peer.present = TRUE,
               !.input.peer.ancestors = RequiredAncestors, !.input.peer.evidence = RequiredEvidence]
    /\ UNCHANGED seen /\ event' = "Retry"
Stage(k) ==
    /\ n.phase = "Verified" /\ k \in StoreNames /\ k \notin n.staged
    /\ n' = [n EXCEPT !.stores[k] = Written(k, n.input), !.staged = @ \cup {k}]
    /\ UNCHANGED seen /\ event' = "Staged"
Flush(k) ==
    /\ n.phase = "Verified" /\ k \in StoreNames /\ k \in n.staged /\ k \notin n.durable
    /\ n' = [n EXCEPT !.durable = @ \cup {k}]
    /\ UNCHANGED seen /\ event' = "Flushed"
Publish ==
    /\ n.phase = "Verified"
    /\ n.durable = StoreNames \/ Mutant = "PartialPublication"
    /\ LET actual == IF Mutant = "WrongPublication" /\ "el" \in n.staged
                       THEN [n.stores EXCEPT !.el.height = ImportHeight + 1] ELSE n.stores
       IN /\ n' = [n EXCEPT !.published = TRUE, !.boundary = actual, !.phase = "Running",
                    !.trusted = (Mutant = "ImportTrust"),
                    !.hrs = IF Mutant = "ResetHRS" THEN <<0, 0, 0>> ELSE @,
                    !.localEL = n.input.peer.el, !.localComet = Hash(n.input.peer.header),
                    !.localVal = Hash(InstallPreimage(n.input))]
          /\ seen' = [seen EXCEPT !.publication =
                [present |-> TRUE, input |-> n.input, stores |-> actual,
                 durable |-> n.durable, crash |-> n.resumed]]
    /\ event' = "Published"
Crash ==
    /\ n.phase \in {"Verified", "Running"} /\ n.crashes = 0
    /\ n' = [n EXCEPT !.phase = "Down", !.crashes = 1, !.trusted = FALSE,
               !.connected = FALSE, !.targetReady = FALSE, !.staged = n.durable,
               !.stores = [k \in StoreNames |-> IF k \in n.durable THEN n.stores[k] ELSE "Empty"]]
    /\ seen' = [seen EXCEPT
          !.partialCrash = @ \/ (~n.published /\ n.durable # {} /\ n.durable # StoreNames),
          !.restartTrusted = @ \/ n.trusted]
    /\ event' = "Crash"
Restart ==
    /\ n.phase = "Down"
    /\ n' = [n EXCEPT !.phase = IF n.published THEN "Running" ELSE "Check", !.resumed = TRUE]
    /\ UNCHANGED seen /\ event' = "Restart"
ReadTarget ==
    /\ n.phase = "Running" /\ ~n.targetReady
    /\ n' = [n EXCEPT !.targetReady = TRUE]
    /\ UNCHANGED seen /\ event' = "TargetAuthenticated"
Continue ==
    /\ n.phase = "Running" /\ n.reached < TargetHeight /\ n.knownGeneration = 1
    \* Interface assumption: normal execution validated every intervening block.
    /\ n' = [n EXCEPT !.reached = TargetHeight, !.localEL = EL(TargetHeight),
               !.localComet = <<"CommittedComet", TargetHeight>>,
               !.localVal = <<"RecordedVal", 1, TargetHeight>>]
    /\ UNCHANGED seen /\ event' = "Continued"
TargetComet == IF TargetHeight = ImportHeight THEN n.input.l1.comet
               ELSE <<"CommittedComet", TargetHeight>>
TargetVal == IF TargetHeight = ImportHeight THEN n.input.l1.val
             ELSE <<"RecordedVal", 1, TargetHeight>>
Admit ==
    /\ n.phase = "Running" /\ ~n.trusted /\ n.targetReady
    /\ n.knownGeneration = 1 \/ Mutant = "GenerationBypass"
    /\ Mutant = "BypassTarget" \/
       (n.reached = TargetHeight /\ n.localEL = EL(TargetHeight) /\
        (n.localComet = TargetComet \/ Mutant = "OriginCometBypass") /\
        (TargetHeight = Origin \/ n.localVal = TargetVal))
    /\ n' = [n EXCEPT !.trusted = TRUE]
    /\ seen' = [seen EXCEPT !.admission = [present |-> TRUE, height |-> n.reached,
          known |-> n.knownGeneration, el |-> n.localEL, comet |-> n.localComet, val |-> n.localVal]]
    /\ event' = "Trusted"
Connect ==
    /\ n.phase = "Running" /\ n.trusted /\ ~n.connected /\ n.knownGeneration = 1
    /\ n' = [n EXCEPT !.connected = TRUE]
    /\ UNCHANGED seen /\ event' = "Connected"
LearnGeneration ==
    /\ n.knownGeneration = 1 /\ n.phase \notin {"Halt", "Reject"}
    /\ n' = [n EXCEPT !.knownGeneration = 2, !.trusted = FALSE, !.connected = FALSE]
    /\ UNCHANGED seen /\ event' = "Superseded"
RestartHalt ==
    /\ Mutant = "LostHalt" /\ n.phase = "Halt"
    /\ n' = [n EXCEPT !.phase = "Check"]
    /\ UNCHANGED seen /\ event' = "RestartedHalt"
Next == Check \/ Retry \/ (\E k \in StoreNames : Stage(k) \/ Flush(k)) \/ Publish \/
        Crash \/ Restart \/ ReadTarget \/ Continue \/ Admit \/ Connect \/ LearnGeneration \/ RestartHalt
ImportSpec == Init /\ [][Next]_vars

\* Independent observer classification over raw source fields, with no action/guard helpers.
ObservedClass(x) ==
    LET headerBound == <<"Hash", x.peer.header>> = x.l1.comet
        preimageBound == <<"Hash", x.peer.preimage>> = x.l1.val
        firstKP == <<x.peer.preimage.first.keys, x.peer.preimage.first.powers>>
        secondKP == <<x.peer.preimage.second.keys, x.peer.preimage.second.powers>>
        conflict == x.l1.height # Origin /\ x.l1.finalized /\ x.peer.present /\ headerBound /\
          ((<<"Hash", x.peer.envelope>> = x.peer.header.data /\ x.peer.envelope.execution # x.l1.el) \/
           (preimageBound /\ <<"Validators", firstKP>> # x.peer.header.next) \/
           (preimageBound /\ <<"Hash", x.peer.entries>> = x.l1.registry /\
            <<"Hash", x.peer.window>> = x.peer.header.window /\ x.peer.entries # <<firstKP, secondKP>>))
    IN IF conflict THEN "Halt"
    ELSE IF ~x.peer.present \/ ~x.l1.finalized \/
       ~RequiredAncestors \subseteq x.peer.ancestors \/ ~RequiredEvidence \subseteq x.peer.evidence
    THEN "Wait"
    ELSE IF x.peer.el # x.l1.el \/ x.peer.state # x.l1.state \/
            x.peer.computedState # x.l1.state THEN "Reject"
    ELSE IF x.l1.height = Origin THEN "Verified"
    ELSE IF ~headerBound \/ <<"Hash", x.peer.envelope>> # x.peer.header.data \/
            ~preimageBound \/ <<"Hash", x.peer.entries>> # x.l1.registry \/
            <<"Hash", x.peer.window>> # x.peer.header.window \/
            x.peer.header.chain # <<"Chain", 1>> \/ x.peer.header.height # ImportHeight
    THEN "Reject" ELSE "Verified"
\* This record is deliberately independent of Planned/Written and publication flags.
ObservedStores(x) ==
    LET pre == IF x.l1.height = Origin THEN GenesisPreimage ELSE x.peer.preimage
    IN [el |-> [height |-> x.l1.height, hash |-> x.l1.el, state |-> x.l1.state,
                 ancestors |-> RequiredAncestors, fi |-> x.l1.fi],
        app |-> [height |-> IF x.l1.height = 2 THEN 0 ELSE x.l1.height, appHash |-> x.l1.el, chain |-> <<"Chain", 1>>,
                  initialHeight |-> 3, fi |-> x.l1.fi,
                  active |-> <<pre.first.keys, pre.first.powers>>,
                  pending |-> <<pre.second.keys, pre.second.powers>>, recorded |-> pre],
        comet |-> [height |-> IF x.l1.height = 2 THEN 0 ELSE x.l1.height, appHash |-> x.l1.el, chain |-> <<"Chain", 1>>,
                    initialHeight |-> 3, validators |-> pre.first, next |-> pre.second,
                    last |-> IF ImportHeight = 2 THEN <<>> ELSE Window.validators,
                    blockID |-> IF ImportHeight = 2 THEN <<>> ELSE <<"Hash", x.peer.header>>,
                    time |-> IF ImportHeight = 2 THEN x.l1.originTime ELSE 102, results |-> IF ImportHeight = Origin THEN <<>> ELSE <<"FixedExecTxResult">>,
                    valChanged |-> IF ImportHeight = 2 THEN 3 ELSE ImportHeight + 2,
                    paramsChanged |-> IF ImportHeight = 2 THEN 3 ELSE ImportHeight + 1],
        evidence |-> [markers |-> RequiredEvidence, validators |-> IF ImportHeight = 2 THEN <<>> ELSE Window.validators,
                       commits |-> IF ImportHeight = 2 THEN <<>> ELSE Window.commits]]
ImportTypeOK ==
    /\ n.phase \in {"Check", "Wait", "Reject", "Halt", "Verified", "Running", "Down"}
    /\ n.durable \subseteq n.staged /\ n.staged \subseteq StoreNames /\ DOMAIN n.stores = StoreNames /\ DOMAIN n.boundary = StoreNames
    /\ {n.published, n.trusted, n.connected, n.targetReady, n.resumed, n.retried} \subseteq BOOLEAN
    /\ n.knownGeneration \in {1, 2} /\ n.crashes \in 0..1
    /\ n.reached \in {ImportHeight, TargetHeight}
ClassificationCorrect == seen.classification.present =>
    seen.classification.result = ObservedClass(seen.classification.input)
PublishedStoresAligned == seen.publication.present =>
    (seen.publication.stores = ObservedStores(seen.publication.input) /\
     n.boundary = seen.publication.stores /\ n.stores = seen.publication.stores)
PublicationDurable == seen.publication.present => seen.publication.durable = StoreNames
FixedGenesisPreserved == n.published =>
    (n.boundary.comet.initialHeight = Origin + 1 /\ n.boundary.app.initialHeight = Origin + 1 /\
     n.boundary.comet.chain = Chain /\ n.boundary.app.chain = Chain)
TrustRequiresLatest ==
    /\ n.trusted => (n.published /\ n.reached = TargetHeight /\ n.knownGeneration = 1 /\ n.targetReady)
    /\ seen.admission.present =>
       (seen.admission.height = TargetHeight /\ seen.admission.known = 1 /\
        seen.admission.el = EL(TargetHeight) /\
        seen.admission.comet = TargetComet /\
        (TargetHeight = Origin \/ seen.admission.val = TargetVal))
NoImportAuthority == event = "Published" => ~n.trusted /\ ~n.connected
ConnectedRequiresTrust == n.connected => n.trusted /\ n.published /\ n.knownGeneration = 1
SignerStatePreserved == n.hrs = <<1, 9, 2>>
HaltSticky == seen.halt => n.phase = "Halt"
TrustedNotReached == ~n.trusted
OlderContinuationNotReached == ~(n.trusted /\ ImportHeight < TargetHeight)
OriginNotReached == ~(n.trusted /\ ImportHeight = Origin)
MissingRetryNotReached == ~(n.trusted /\ n.retried)
CrashResumeNotReached == ~(n.published /\ seen.publication.crash)
PartialCrashNotReached == ~seen.partialCrash
ImportUntrustedNotReached == ~(n.published /\ ~n.trusted /\ n.reached < TargetHeight)
ContradictionNotReached == ~seen.halt
SupersededNotReached == ~(n.published /\ n.knownGeneration = 2 /\ ~n.trusted)
RestartTrustNotReached == ~(n.trusted /\ n.resumed /\ seen.restartTrusted)

\* Independent readiness observation: do not use Connect's guard as the antecedent.
\* This detects a disabled action; ineffective actions need the temporal companion.
ConnectionEnabledWhenReady ==
    (n.phase = "Running" /\ n.published /\ n.trusted /\
     n.knownGeneration = 1 /\ ~n.connected) => ENABLED Connect
ConnectionNotReached == ~n.connected

\* Selected healthy publication fixtures: necessary chronology/genesis premises.
\* Literal raw-source/publication audit; no constructor, Planned or ObservedStores.
\* Origin's retained generation-0 header is not a generation-1 parent.
PositiveImportPremises == seen.publication.present =>
    LET x == seen.publication.input
        c == seen.publication.stores.comet
    IN /\ x.l1.generation = 1 /\ x.l1.origin = 2 /\ x.l1.originTime = 100
       /\ c.chain = <<"Chain", 1>> /\ c.initialHeight = 3
       /\ IF x.l1.height = 2
          THEN /\ x.peer.header.height = 2 /\ x.peer.header.chain = <<"Chain", 0>>
               /\ x.peer.header.time = 20
               /\ c.height = 0 /\ c.time = 100 /\ c.blockID = <<>>
               /\ c.validators = [keys |-> <<1, 2>>, powers |-> <<3, 2>>,
                                    priorities |-> <<-2, 2>>, proposer |-> 1]
               /\ c.next = [keys |-> <<1, 2>>, powers |-> <<3, 2>>,
                              priorities |-> <<1, -1>>, proposer |-> 2]
               /\ seen.publication.stores.app.recorded.first = c.validators
               /\ seen.publication.stores.app.recorded.second = c.next
               /\ seen.publication.stores.app.active = <<<<1, 2>>, <<3, 2>>>>
               /\ seen.publication.stores.app.pending = <<<<1, 2>>, <<3, 2>>>>
          ELSE /\ x.l1.height = 4 /\ x.peer.header.height = 4
               /\ x.peer.header.chain = <<"Chain", 1>>
               /\ x.peer.header.time = 102 /\ x.peer.header.time > x.l1.originTime
               /\ c.height = 4 /\ c.time = x.peer.header.time
               /\ c.blockID = <<"Hash", x.peer.header>>
               \* Actual committed pair from the selected two-update stock prefixes.
               \* Literal publication table, independent of raw ids/fixture constructors.
               /\ <<c.validators, c.next>> \in {
                                                <<[keys |-> <<1, 2>>, powers |-> <<3, 2>>, priorities |-> <<-1, 1>>, proposer |-> 1],
                                                  [keys |-> <<2, 3>>, powers |-> <<2, 4>>, priorities |-> <<2, -1>>, proposer |-> 2]>>,
                                                <<[keys |-> <<1, 2>>, powers |-> <<3, 5>>, priorities |-> <<4, -4>>, proposer |-> 2],
                                                  [keys |-> <<2, 3>>, powers |-> <<2, 4>>, priorities |-> <<-1, 1>>, proposer |-> 2]>>,
                                                <<[keys |-> <<1, 2>>, powers |-> <<3, 2>>, priorities |-> <<-1, 1>>, proposer |-> 1],
                                                  [keys |-> <<2, 3>>, powers |-> <<3, 4>>, priorities |-> <<2, -2>>, proposer |-> 2]>>}
               /\ seen.publication.stores.app.recorded.first = c.validators
               /\ seen.publication.stores.app.recorded.second = c.next
               \* Necessary bounds remain power-sensitive; they do not imply pair coherence.
               /\ c.validators.priorities[1] - c.validators.priorities[2] \in
                    (IF c.validators.powers = <<3, 5>> THEN (-10)..10 ELSE (-6)..6)
               /\ c.next.priorities[1] - c.next.priorities[2] \in (-8)..8
PositivePublicationNotReached == ~seen.publication.present
=============================================================================
