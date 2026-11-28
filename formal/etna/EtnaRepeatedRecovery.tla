----------------------- MODULE EtnaRepeatedRecovery -----------------------
EXTENDS Naturals, Sequences, FiniteSets
VARIABLES s, receipt

\* Labels stand for authenticated data in this synthetic instance. No signing,
\* EL execution, DA, registry verification or backend proof generation runs here.
Start == 0
GenesisCutoff == 24
Base == 6
MaxHeight == 8
MaxProduces == 3
MaxL1 == 37
MaxAnchorAge == 1296
UnsettledLimit == 6
R1 == 32
R2 == 35
Time(n) == n + 69
Empty == <<>>
Pending == <<0, 1, 1397, 1394>>
Preserved == <<0, 1, 1397, 0>>
Replaced == <<2, 2, 0, 0>>
GenesisCut == <<0, 100, 0, 0>>
BaseCut == <<6, 106, 206, 4>>
Min(a, b) == IF a < b THEN a ELSE b
Max(a, b) == IF a > b THEN a ELSE b
Rule(q, t) == IF t >= q[3] THEN q[2] ELSE q[1]
Domain(g) == 100 + g

Origin(g, h, n, q) ==
    [generation |-> g, height |-> h, number |-> n, time |-> Time(n),
     rule |-> Rule(q, Time(n)), domain |-> Domain(g)]
O0 == Origin(0, Start, 25, <<0, 0, 0, 0>>)
O1 == Origin(1, Base, R1, Preserved)
O2 == Origin(2, Base, R2, Replaced)
Boot(o, cut, root) ==
    [generation |-> o.generation, height |-> o.height, number |-> o.number,
     time |-> o.time, rule |-> o.rule, domain |-> o.domain,
     initialHeight |-> o.height + 1, el |-> cut[2], stateRoot |-> root, fi |-> cut[4]]
Auth(g, nonce, rules) ==
    [generation |-> g, checkpoint |-> Base, nonce |-> nonce, validUntil |-> 107,
     rules |-> rules, owner |-> TRUE, exclusions |-> Empty, fiToClear |-> Empty]
\* External fixture, with the retained actual call bytes observed in every frame.
Authority == <<Auth(0, 0, 0), Auth(0, 1, 0), Auth(1, 2, 2)>>
Block(g, cut, bft, t, n, anchorCut, q, rule, first, prev) ==
    [generation |-> g, domain |-> Domain(g), cut |-> cut, stateRoot |-> 400 + cut[2],
     bftTime |-> bft, elTime |-> t, anchor |-> n, anchorCut |-> anchorCut,
     schedule |-> q, rule |-> rule, lastBlockID |-> IF first THEN Empty ELSE prev,
     lastCommit |-> IF first THEN Empty ELSE <<g, prev>>]
G0Prefix == [h \in 1..Base |->
    Block(0, <<h, 100+h, 200+h, Min(h, 4)>>, 93+h, 94+h, 24+h, GenesisCut,
          IF h <= 4 THEN <<0, 0, 0, 0>> ELSE Pending, 0, h=1, 199+h)]
Landing(g, parent, n, ref, snap, cut, root) ==
    [generation |-> g, parentHeight |-> parent, number |-> n, reference |-> ref, activeSnapshot |-> snap,
     cut |-> cut, stateRoot |-> root]
L6 == Landing(0, 0, 31, 30, GenesisCutoff, BaseCut, 506)

\* Block 31 has closed and finalized at Init. Advance opens block 32 before
\* the first contract transaction; finalization subsequently stays behind l1.
Initial ==
    [generation |-> 0, nonce |-> 0, c |-> Base, head |-> Base, fiHead |-> 4,
     activeSnapshot |-> GenesisCutoff, l1 |-> 31, finalized |-> 31, produces |-> 0,
     schedule |-> Pending, origins |-> <<O0>>, authBank |-> Authority,
     canonical |-> G0Prefix, records |-> <<L6>>, bootstrap |-> Boot(O0, GenesisCut, 500),
     job |-> Empty, archivedBlocks |-> Empty, archivedJob |-> Empty]
Init == s = Initial /\ receipt = Empty

OwnOrigin(x) == x.origins[x.generation + 1]
LastRecord(x) == x.records[Len(x.records)]
AnchorCut(x, n) == IF LastRecord(x).number <= n THEN LastRecord(x).cut ELSE BaseCut
AnchorSchedule(x, n) ==
    CASE x.generation = 2 /\ n >= R2 -> Replaced
      [] x.generation >= 1 /\ n >= R1 -> Preserved
      [] OTHER -> Pending

\* Actual execution L1 blocks are selected by the offer domain, outside the
\* protocol predicate. Old inputs can be retried at their selected clock.
Call(k, a) == [kind |-> k, args |-> a]
OpenTransaction(x) == x.finalized < x.l1
BaseOffers(x) ==
      (IF x.l1 < MaxL1 THEN {Call(1, Empty)} ELSE {})
    \cup {Call(2, <<n>>) : n \in (x.finalized+1)..(x.l1-1)}
    \cup {Call(5, <<n>>) : n \in {R1, R2}}
    \cup (IF x.produces < MaxProduces
          THEN {Call(6, <<n>>) : n \in 31..x.finalized} ELSE {})
    \cup {Call(7, <<Base, Base+1, x.finalized>>)}
TransactionOffers(x) ==
    IF ~OpenTransaction(x) THEN {} ELSE
        {Call(3, <<0>>)}
        \cup (IF x.l1 = R1 THEN {Call(4, <<i, x.authBank[i]>>) : i \in 1..2}
              ELSE IF x.l1 = R2 THEN {Call(4, <<3, x.authBank[3]>>)} ELSE {})
        \cup (IF x.job # Empty THEN {Call(8, <<1, x.job>>)} ELSE {})
        \cup (IF x.archivedJob # Empty THEN {Call(8, <<2, x.archivedJob>>)} ELSE {})
Offers(x) == BaseOffers(x) \cup TransactionOffers(x)

CanRecover(x, a) ==
    /\ a.owner /\ a.exclusions = Empty /\ a.fiToClear = Empty
    /\ a.generation = x.generation /\ a.checkpoint = x.c /\ a.nonce = x.nonce
    /\ Time(x.l1) <= a.validUntil
    /\ a.rules = 0 \/ a.rules = x.schedule[2] + 1
DoRecover(x, a) ==
    LET g == x.generation + 1
        q == IF a.rules = 0 THEN <<x.schedule[1], x.schedule[2], x.schedule[3], 0>>
             ELSE <<a.rules, a.rules, 0, 0>>
        o == Origin(g, x.c, x.l1, q)
    IN [x EXCEPT !.generation = g, !.nonce = @ + 1, !.schedule = q,
          !.origins = Append(x.origins, o),
          !.head = x.c, !.canonical = SubSeq(x.canonical, 1, x.c),
          !.archivedBlocks = IF g=2 THEN SubSeq(x.canonical, x.c+1, x.head) ELSE @,
          !.archivedJob = IF g=2 THEN x.job ELSE @, !.job = Empty, !.bootstrap = Empty]

CanObserve(x, n) == x.generation > 0 /\ n = OwnOrigin(x).number /\ n <= x.finalized
IsFirst(x) == x.head = OwnOrigin(x).height
Bft(x) == IF IsFirst(x) THEN OwnOrigin(x).time ELSE x.canonical[x.head].bftTime + 1
BlockTime(x, n) == Max(Max(x.canonical[x.head].elTime+1, Bft(x)), Time(n))
CanProduce(x, n) ==
    /\ x.head < MaxHeight /\ x.bootstrap # Empty
    /\ n >= OwnOrigin(x).number
    /\ IsFirst(x) \/ n >= x.canonical[x.head].anchor
    /\ x.head + 1 - AnchorCut(x, n)[1] <= UnsettledLimit
    /\ BlockTime(x, n) - Time(n) <= MaxAnchorAge
    /\ AnchorSchedule(x, n)[4] = 0 \/ x.canonical[x.head].elTime < AnchorSchedule(x, n)[4]

\* Use distinct symbolic identities for alternative modeled parents/anchors.
\* The preferred route has the smallest label in each generation and height.
AnchorCode(n, preferred) == IF n = preferred THEN 0 ELSE n - 30
BlockLabel(x, n) ==
    LET g == x.generation
        h == x.head + 1
        preferred == IF g=1 THEN R1 ELSE IF h=7 THEN R2 ELSE 36
        parentCode == IF IsFirst(x) THEN 0
                      ELSE AnchorCode(x.canonical[x.head].anchor, OwnOrigin(x).number)
        checkpointCode == IF AnchorCut(x, n)[1] = (IF g=2 /\ h=8 /\ n=36 THEN 7 ELSE 6)
                          THEN 0 ELSE 1
    IN 100*g + 100 + h + 1000*(AnchorCode(n, preferred) + 8*parentCode + 64*checkpointCode)
ProduceBlock(x, n) ==
    LET el == BlockLabel(x, n)
        t == BlockTime(x, n)
        q == AnchorSchedule(x, n)
        cut == <<x.head+1, el, el+100, x.fiHead>>
    IN Block(x.generation, cut, Bft(x), t, n, AnchorCut(x, n), q, Rule(q, t),
             IsFirst(x), x.canonical[x.head].cut[3])

\* One immutable height-7 job per generation suffices here. Only g2 has
\* external backend results. A staged g1 job does not decide DAO policy.
CanCapture(x, ref) ==
    /\ x.generation > 0 /\ x.c = Base /\ x.head >= Base + 1 /\ x.job = Empty
    /\ x.canonical[Base+1].anchor <= ref
Captured(x, ref) ==
    LET g == x.generation
        dep == OwnOrigin(x).number
        b == x.canonical[Base+1]
        cut == b.cut
        data == <<cut[2]>>
    IN [generation |-> g, reference |-> ref, dependency |-> dep, cuts |-> <<BaseCut, cut>>,
        data |-> data,
        statement |-> <<1, 1, 167000, 4369, 8738, g, Base, 106, 206, 333, Base+1,
                         cut[2], cut[3], b.stateRoot, ref, 500+ref, data, 4, 4, dep,
                         <<2, g, Base, Base+1, Empty>>>>]
VerifiedPairAvailable(job) == job.generation = 2
CanLand(x, job) ==
    /\ job.generation = x.generation /\ VerifiedPairAvailable(job)
    /\ x.c = Base /\ x.head >= Base + 1 /\ job.cuts[2] = x.canonical[Base+1].cut
    /\ job.reference < x.l1
Landed(x, job) ==
    LET b == x.canonical[Base+1]
        rec == Landing(x.generation, x.c, x.l1, job.reference, job.dependency, b.cut, b.stateRoot)
    IN [x EXCEPT !.c = Base+1, !.fiHead = b.cut[4], !.activeSnapshot = job.dependency,
                 !.records = Append(x.records, rec)]

Accepted(x, k, a) ==
    CASE k \in {1, 2} -> TRUE
      [] k=3 -> a[1] = x.nonce
      [] k=4 -> CanRecover(x, a[2])
      [] k=5 -> CanObserve(x, a[1])
      [] k=6 -> CanProduce(x, a[1])
      [] k=7 -> CanCapture(x, a[3])
      [] k=8 -> CanLand(x, a[2])
Apply(x, k, a, ok) ==
    IF k=6 THEN
        IF ok THEN [x EXCEPT !.produces = @ + 1, !.head = @ + 1,
                             !.canonical = Append(@, ProduceBlock(x, a[1]))]
        ELSE [x EXCEPT !.produces = @ + 1]
    ELSE IF ~ok THEN x ELSE
        CASE k=1 -> [x EXCEPT !.l1 = @ + 1]
          [] k=2 -> [x EXCEPT !.finalized = a[1]]
          [] k=3 -> [x EXCEPT !.nonce = @ + 1]
          [] k=4 -> DoRecover(x, a[2])
          [] k=5 -> [x EXCEPT !.bootstrap = Boot(OwnOrigin(x), x.records[1].cut,
                                                x.records[1].stateRoot)]
          [] k=7 -> [x EXCEPT !.job = Captured(x, a[3])]
          [] k=8 -> Landed(x, a[2])
Step(call) ==
    LET ok == Accepted(s, call.kind, call.args) IN
        /\ s' = Apply(s, call.kind, call.args, ok)
        /\ receipt' = [kind |-> call.kind, args |-> call.args, accepted |-> ok]
Next == \E call \in Offers(s): Step(call)

Bounds ==
    /\ s.generation \in 0..2 /\ s.nonce \in 0..3
    /\ s.c \in Base..(Base+1) /\ s.head \in s.c..MaxHeight
    /\ s.produces \in 0..MaxProduces /\ Len(s.canonical) = s.head
    /\ s.l1 \in 31..MaxL1 /\ s.finalized \in 31..s.l1
    /\ s.finalized = s.l1 => s.l1 = 31
FixedOrigins ==
    s.origins = (CASE s.generation = 0 -> <<O0>>
                    [] s.generation = 1 -> <<O0, O1>>
                    [] s.generation = 2 -> <<O0, O1, O2>>)
SettledPrefix ==
    /\ SubSeq(s.canonical, 1, Base) = G0Prefix /\ s.records[1] = L6
    /\ LastRecord(s).cut = s.canonical[s.c].cut
    /\ s.fiHead = LastRecord(s).cut[4] /\ s.activeSnapshot = LastRecord(s).activeSnapshot
    /\ s.c = Base => s.activeSnapshot = GenesisCutoff
RecoveryDomain ==
    /\ s.authBank = Authority
    /\ (s.generation < 2 => s.archivedBlocks = Empty /\ s.archivedJob = Empty)
    /\ \A h \in (Base+1)..s.head:
        /\ s.canonical[h].generation = s.generation
        /\ s.canonical[h].anchor >= OwnOrigin(s).number
        /\ s.canonical[h].domain = Domain(s.generation)
        /\ h = OwnOrigin(s).height + 1 =>
            /\ s.canonical[h].bftTime = OwnOrigin(s).time
            /\ s.canonical[h].lastBlockID = Empty /\ s.canonical[h].lastCommit = Empty
    /\ s.generation > 0 /\ s.bootstrap # Empty =>
        /\ s.bootstrap = Boot(OwnOrigin(s), BaseCut, 506)
        /\ s.finalized >= OwnOrigin(s).number

On(k, a, ok) == receipt # Empty /\ receipt.kind = k /\ receipt.args = a /\ receipt.accepted = ok
NoSmoke == ~(s.generation = 1 /\ s.head = 7 /\ On(6, <<R1>>, TRUE))
NoStaleNonce == ~(s.generation = 0 /\ s.nonce = 1 /\ On(4, <<1, Authority[1]>>, FALSE))
NoOldGeneration == ~(s.generation = 1 /\ s.nonce = 1 /\ On(4, <<2, Authority[2]>>, FALSE))
NoR1Only == ~(s.generation = 2 /\ s.finalized = R1 /\ s.bootstrap = Empty /\
              On(5, <<R2>>, FALSE))
NoProgress ==
    ~(/\ s.generation = 2 /\ s.c = 7 /\ s.head = 8 /\ s.produces = 3
      /\ Len(s.archivedBlocks) = 1 /\ s.archivedJob # Empty
      /\ s.canonical[7].anchor = R2 /\ LastRecord(s).number = 36
      /\ s.canonical[8].anchorCut = LastRecord(s).cut /\ On(6, <<36>>, TRUE))
=============================================================================
