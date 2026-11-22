-------------------- MODULE EtnaL2CommitteeRecovery --------------------
EXTENDS Naturals, FiniteSets, Sequences, TLC

\* Finite certificate-level product of Etna draft 178d7a7a66b14305c2f6467ae77163f93dd677cf.
\* Each committed block's authenticated anchor immediately adopts the latest
\* modeled finalized L1 threshold, fallback and checkpoint. Anchor lag is open.
\* The staking proxy has code. Its block-start call may apply effects or revert
\* while later ordinary calls succeed. Missing code and repair are open.
\* Spec permits infinite stuttering. These configurations check state safety
\* and existential finite paths; fairness and conditional leads-to remain open.

CONSTANTS Profile, SymmetricBonds
VARIABLES chain, landed, env, cursor, receipt

vars == <<chain, landed, env, cursor, receipt>>
Free == Profile = "Free"
SwitchHeight == 10
HeightBound == IF Free THEN 14 ELSE 19
BondIDs == IF Free THEN SymmetricBonds ELSE 0..3
ASSUME IF Free THEN Cardinality(SymmetricBonds) = 4 ELSE SymmetricBonds = {}
StakePermutations == Permutations(SymmetricBonds)

\* In Free, an atom names the corresponding bond, seat and stake key in their
\* respective fields. Witnesses keep numeric bond/seat IDs and concrete keys.
KeyOf == [i \in BondIDs |-> IF Free THEN i ELSE <<"A", "B", "C", "D">>[i + 1]]
Keys(ids) == {KeyOf[i] : i \in ids}
StakeKeys == Keys(BondIDs)
Fallback == {"F0", "F1", "F2", "F3"}
Rotated == {"G0", "G1", "G2", "G3"}
AllKeys == StakeKeys \cup Fallback \cup Rotated

\* Amounts are in Q=10^27/4. The maximum uint256 is a tag with no
\* monetary payload; the eligible finite thresholds are exactly 2Q and 3Q.
Money(q) == [disabled |-> FALSE, q |-> q]
Disabled == [disabled |-> TRUE, q |-> 0]
Thresholds == {Money(2), Money(3), Disabled}

\* All four pre-fork issued identities are permanent and never withdrawn.
\* Seat i belongs to bond i whenever occupied (there is no registration).
\* Zero is an absent exit height. Seat zero is an ordinary valid seat.
InitialLedger ==
    [balance |-> [i \in BondIDs |-> 1], occupied |-> BondIDs,
     exitHeight |-> [i \in BondIDs |-> 0], forfeited |-> {},
     misses |-> [i \in BondIDs |-> 0], sink |-> 0]
EmptyBitmap == IF Free THEN {} ELSE 0
InitialSnapshot == [height |-> 0, members |-> {}, total |-> 0]

Choice(g, h, d, source, members) ==
    [generation |-> g, target |-> h, decidedAt |-> d, source |-> source,
     members |-> members]
OriginChoice(g, o, h, fb) == Choice(g, h, o, "Origin", fb)
EmptyChoice == Choice(0, 0, 0, "None", {})
Certificate(g, h, members, votes) ==
    [generation |-> g, height |-> h, round |-> 0, blockID |-> <<g, h>>,
     members |-> members, votes |-> votes]
EmptyCert == Certificate(0, 0, {}, {})
EmptyAuth == [present |-> FALSE, generation |-> 0, c |-> 0, disable |-> FALSE]

\* At an origin there is no new-generation header or LastCommit. next and
\* pending are assignments for head+1 and head+2, including their provenance.
InitialChain ==
    [height |-> SwitchHeight, generation |-> 0, origin |-> SwitchHeight,
     originFallback |-> Fallback, ledger |-> InitialLedger,
     snapshot |-> InitialSnapshot, storedGeneration |-> 0,
     current |-> EmptyChoice,
     next |-> OriginChoice(0, SwitchHeight, SwitchHeight + 1, Fallback),
     pending |-> OriginChoice(0, SwitchHeight, SwitchHeight + 2, Fallback),
     parentCert |-> EmptyCert, cert |-> EmptyCert, missBitmap |-> EmptyBitmap, updates |-> {}]
InitialLanded == [present |-> FALSE, state |-> InitialChain]
InitialEnv ==
    [threshold |-> Money(3), changes |-> 0, fallback |-> Fallback,
     available |-> StakeKeys \cup Fallback, lossUsed |-> FALSE, lands |-> 0, auth |-> EmptyAuth]

\* Inputs are external offers only. No value from an expected state or
\* witness predicate is an argument to a protocol operation.
ExitCall(i) == [kind |-> "Exit", bond |-> i]
ForfeitCall(i) == [kind |-> "Forfeit", bond |-> i]
BlockOffer(outcome, calls, omit) == <<"Block", outcome, calls, omit>>
Plain == BlockOffer("Effects", <<>>, {})
Lose(keys) == <<"Lose", keys>>
SetM(m) == <<"SetM", m>>
Authorize(disable) == <<"Authorize", disable>>
LandInput == <<"Land">>
BatchInput == <<"Recover">>
RotateInput == <<"Rotate">>
OldStart == <<Plain, Plain, Plain, LandInput>>
OldExit == BlockOffer("Effects", <<ExitCall(3)>>, {})
OldTail == <<OldExit, Plain, Lose({"A","B"}), Plain>>
ForfeitAB == BlockOffer("Effects", <<ForfeitCall(0), ForfeitCall(1)>>, {})
RecoveryPrefix(disable) ==
    OldStart \o OldTail \o <<Authorize(disable), BatchInput>>
PenaltyPrefix ==
    <<Plain, Plain, Lose({"A"}), Plain, LandInput>>

Schedule ==
    CASE Profile = "OriginCandidate" -> <<Plain, Plain, Plain>>
      [] Profile = "RecoverMax" ->
            RecoveryPrefix(TRUE) \o <<ForfeitAB, Plain, SetM(Money(2)), Plain, Plain, Plain>>
      [] Profile = "Restall" ->
            RecoveryPrefix(FALSE) \o <<ForfeitAB, SetM(Money(2)), Plain, Plain>>
      [] Profile = "ThresholdStall" ->
            OldStart \o OldTail \o <<SetM(Disabled), Plain>>
      [] Profile = "SuffixRollback" -> RecoveryPrefix(TRUE)
      [] Profile = "Penalty" -> PenaltyPrefix \o <<Plain, Plain, Plain, Plain>>
      [] Profile = "EmptySeat" ->
            PenaltyPrefix \o <<BlockOffer("Effects", <<ExitCall(0)>>, {}), Plain>>
      [] Profile = "StaleSnapshot" ->
            RecoveryPrefix(TRUE) \o <<ForfeitAB, Plain, SetM(Money(2)),
                    BlockOffer("Revert", <<>>, {}), Plain, Plain, Plain>>
      [] Profile = "StaleAuthBudget" ->
            <<Plain, LandInput, Authorize(TRUE), Plain, LandInput,
              SetM(Money(2)), SetM(Money(3)), BatchInput>>
      [] Profile = "StaleAuth" ->
            OldStart \o <<Authorize(TRUE), OldExit, LandInput, Plain,
                           Lose({"A","B"}), Plain, BatchInput>>
      [] OTHER -> <<>>

AdvanceInput == cursor' = (IF Free THEN 0 ELSE cursor + 1)

\* A diagnostic action receipt records real pre-state and attempted input.
\* It never appears on the right hand side of an operational transition.
SaveReceipt(result, input) ==
    receipt' = [result |-> result, input |-> input,
                before |-> [chain |-> chain, landed |-> landed, env |-> env]]

Init ==
    /\ chain = InitialChain
    /\ landed = InitialLanded
    /\ env = InitialEnv
    /\ cursor = 0
    /\ receipt = [result |-> "Init", input |-> <<>>,
                  before |-> [chain |-> InitialChain, landed |-> InitialLanded,
                               env |-> InitialEnv]]

Quorum(members, votes) ==
    /\ votes \subseteq members
    /\ 3 * Cardinality(votes) > 2 * Cardinality(members)

\* Block IDs name the single committed block at (generation,height) within a trace;
\* competing proposals, signatures and cross-trace identity are outside this product.
\* All powers are exactly one. Nil and absent parent flags both map to miss.
\* The first new block has no Comet parent, even when the origin is a
\* previously committed and landed old-generation Etna block.
ParentAdmits ==
    IF chain.height = chain.origin THEN chain.cert = EmptyCert
    ELSE /\ chain.cert.generation = chain.generation
         /\ chain.cert.height = chain.height
         /\ chain.cert.blockID = <<chain.generation, chain.height>>
         /\ chain.cert.members = chain.current.members
         /\ Quorum(chain.current.members, chain.cert.votes)

Missing(ledger, cert) ==
    {i \in ledger.occupied : KeyOf[i] \in cert.members \ cert.votes}

Bitmap(missed) ==
    IF Free THEN missed
    ELSE (IF 0 \in missed THEN 1 ELSE 0) + (IF 1 \in missed THEN 2 ELSE 0)
         + (IF 2 \in missed THEN 4 ELSE 0) + (IF 3 \in missed THEN 8 ELSE 0)

HasMissBit(bitmap, i) ==
    IF Free THEN i \in bitmap ELSE (bitmap \div (2 ^ i)) % 2 = 1

Count(l, missed) ==
    [i \in BondIDs |-> IF i \notin l.occupied THEN l.misses[i]
                       ELSE IF i \in missed THEN l.misses[i] + 1 ELSE 0]
BlockStart(l, cert) ==
    LET counters == Count(l, Missing(l, cert))
        penalized == {i \in l.occupied : counters[i] >= 2}
    IN [l EXCEPT !.misses = [i \in BondIDs |-> IF i \in penalized THEN 0 ELSE counters[i]],
          !.balance = [i \in BondIDs |-> IF i \in penalized THEN 0 ELSE l.balance[i]],
          !.occupied = @ \ penalized, !.sink = @ + Cardinality(penalized)]

Snapshot(h, l) ==
    [height |-> h, members |-> Keys(l.occupied), total |-> Cardinality(l.occupied)]

Decision(g, h, snap, m, fb) ==
    IF ~m.disabled /\ snap.height = h /\ snap.members # {} /\ snap.total >= m.q
    THEN Choice(g, h + 2, h, "Candidate", snap.members)
    ELSE Choice(g, h + 2, h, "Fallback", fb)

Updates(old, new) ==
    {[key |-> k, power |-> 0] : k \in old \ new}
    \cup {[key |-> k, power |-> 1] : k \in new \ old}

\* Every offered call carries the prevalidated owner/DAO, identity and
\* expiry premise. Forfeit identities are attested at an actual landing.
Eligible(l, call) ==
    LET i == call.bond IN
    IF call.kind = "Exit" THEN l.exitHeight[i] = 0
    ELSE landed.present /\ l.balance[i] > 0 /\ i \notin l.forfeited
ApplyCall(l, call, h) ==
    LET i == call.bond IN
    IF call.kind = "Exit"
    THEN [l EXCEPT !.exitHeight[i] = h, !.occupied = @ \ {i}]
    ELSE [l EXCEPT !.balance[i] = 0, !.forfeited = @ \cup {i},
                   !.exitHeight[i] = IF @ = 0 THEN h ELSE @,
                   !.occupied = @ \ {i}, !.sink = @ + l.balance[i]]

\* Free offers up to one ordinary call. The circuit also offers two distinct
\* DAO calls in one block, ordered A then B, individually checked at execution.
RECURSIVE CallsEligible(_, _, _), ApplyCalls(_, _, _)
CallsEligible(l, calls, h) ==
    IF calls = <<>> THEN TRUE
    ELSE Eligible(l, Head(calls)) /\ CallsEligible(ApplyCall(l, Head(calls), h), Tail(calls), h)
ApplyCalls(l, calls, h) ==
    IF calls = <<>> THEN l
    ELSE ApplyCalls(ApplyCall(l, Head(calls), h), Tail(calls), h)

Commit(input, h, votes) ==
    LET effects == input[2] = "Effects"
        calls == input[3]
        start == IF effects THEN BlockStart(chain.ledger, chain.cert) ELSE chain.ledger
        snap == IF effects THEN Snapshot(h, start) ELSE chain.snapshot
        decision == Decision(chain.generation, h, snap, env.threshold, env.fallback)
    IN /\ CallsEligible(start, calls, h)
       /\ chain' = [chain EXCEPT
              !.height = h, !.ledger = ApplyCalls(start, calls, h), !.snapshot = snap,
              !.storedGeneration = IF effects THEN chain.generation ELSE @,
              !.current = chain.next, !.next = chain.pending, !.pending = decision,
              !.parentCert = chain.cert, !.missBitmap = Bitmap(Missing(chain.ledger, chain.cert)),
              !.cert = Certificate(chain.generation, h, chain.next.members, votes),
              !.updates = Updates(chain.pending.members, decision.members)]
       /\ SaveReceipt("Commit", input)

Block(input) ==
    LET h == chain.height + 1
        live == chain.next.members \cap env.available
        omit == input[4]
        votes == live \ omit
    IN /\ h <= HeightBound /\ h <= landed.state.height + 6
       /\ omit \subseteq live
       /\ (omit = {} \/ Quorum(chain.next.members, votes))
       /\ IF ParentAdmits /\ Quorum(chain.next.members, votes)
          THEN Commit(input, h, votes)
          ELSE /\ UNCHANGED chain /\ SaveReceipt("RefusedBlock", input)
       /\ UNCHANGED <<landed, env>>

Land(input) ==
    /\ chain.height > chain.origin
    /\ chain.height > landed.state.height /\ env.lands < 2
    \* A trusted completed proof attests this very committed state.
    /\ chain.cert.height = chain.height /\ chain.cert.generation = chain.generation
    /\ landed' = [present |-> TRUE, state |-> chain]
    /\ env' = [env EXCEPT !.lands = @ + 1]
    /\ UNCHANGED chain /\ SaveReceipt("Land", input)

ChangeThreshold(input) ==
    LET m == input[2] IN
    /\ env.changes < 2 /\ m # env.threshold
    /\ env' = [env EXCEPT !.threshold = m, !.changes = @ + 1]
    /\ UNCHANGED <<chain, landed>> /\ SaveReceipt("SetM", input)

ChangeAvailability(input) ==
    /\ ~env.lossUsed
    /\ env' = [env EXCEPT !.available = @ \ input[2], !.lossUsed = TRUE]
    /\ UNCHANGED <<chain, landed>> /\ SaveReceipt("Lose", input)

\* Rotation first introduces G's four keys into the availability domain. They
\* are ready on introduction and always online. Previously admitted F stays online.
Rotate(input) ==
    /\ env.fallback = Fallback
    /\ env' = [env EXCEPT !.fallback = Rotated, !.available = @ \cup Rotated]
    /\ UNCHANGED <<chain, landed>> /\ SaveReceipt("Rotate", input)

Grant(input) ==
    /\ landed.present /\ ~env.auth.present
    /\ env' = [env EXCEPT !.auth = [present |-> TRUE, generation |-> chain.generation,
                                    c |-> landed.state.height, disable |-> input[2]]]
    /\ UNCHANGED <<chain, landed>> /\ SaveReceipt("Authorize", input)

Recover(input) ==
    LET c == landed.state.height
        g == chain.generation + 1
        fb == env.fallback
        matches == env.auth.generation = chain.generation /\ env.auth.c = c
    IN /\ env.auth.present /\ landed.present /\ g <= 1
       /\ IF matches
          THEN /\ (~env.auth.disable \/ env.threshold = Disabled \/ env.changes < 2)
               /\ chain' = [landed.state EXCEPT
                       !.generation = g, !.origin = c, !.originFallback = fb,
                       !.current = EmptyChoice, !.parentCert = EmptyCert, !.cert = EmptyCert, !.missBitmap = EmptyBitmap,
                       !.next = OriginChoice(g, c, c + 1, fb),
                       !.pending = OriginChoice(g, c, c + 2, fb), !.updates = {}]
               /\ env' = [env EXCEPT !.changes = 0, !.lands = 0, !.auth = EmptyAuth,
                              !.threshold = IF env.auth.disable THEN Disabled ELSE @]
               /\ SaveReceipt("Recover", input)
          ELSE /\ UNCHANGED <<chain, env>> /\ SaveReceipt("RefusedRecovery", input)
       /\ UNCHANGED landed

\* The complete finite external alphabet uses one shared dispatch for all profiles.
Step(input) ==
    /\ CASE input[1] = "Block" -> Block(input)
         [] input[1] = "Land" -> Land(input)
         [] input[1] = "SetM" -> ChangeThreshold(input)
         [] input[1] = "Lose" -> ChangeAvailability(input)
         [] input[1] = "Rotate" -> Rotate(input)
         [] input[1] = "Authorize" -> Grant(input)
         [] input[1] = "Recover" -> Recover(input)
    /\ AdvanceInput

SingleCalls ==
    {<<>>} \cup {<<ExitCall(i)>> : i \in BondIDs}
           \cup {<<ForfeitCall(i)>> : i \in BondIDs}
OneOmission(s) == {{}} \cup {{k} : k \in s}
FreeStep ==
    \/ \E outcome \in {"Effects", "Revert"}, calls \in SingleCalls,
          omit \in OneOmission(chain.next.members \cap env.available) :
          Step(BlockOffer(outcome, calls, omit))
    \/ Step(LandInput) \/ Step(BatchInput) \/ Step(RotateInput)
    \/ \E m \in Thresholds : Step(SetM(m))
    \/ \E disable \in BOOLEAN : Step(Authorize(disable))
    \/ \E lost \in {s \in SUBSET StakeKeys : Cardinality(s) <= 2} : Step(Lose(lost))

Next ==
    \/ IF Free THEN FreeStep
       ELSE /\ cursor < Len(Schedule) /\ Step(Schedule[cursor + 1])
    \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

\* The checks below read completed actions. The before-projection is a record
\* of what actually ran, independent of the input schedule and named witnesses.
Prior == receipt.before
PriorChain == Prior.chain
Result == receipt.result

LedgerOK(l) ==
    /\ l.balance \in [BondIDs -> 0..1] /\ l.exitHeight \in [BondIDs -> 0..HeightBound]
    /\ l.occupied \subseteq BondIDs /\ l.forfeited \subseteq BondIDs
    /\ l.misses \in [BondIDs -> 0..1] /\ l.sink \in 0..4
    /\ \A i \in BondIDs :
           /\ (i \in l.occupied) = (l.balance[i] = 1 /\ l.exitHeight[i] = 0)
           /\ (i \in l.forfeited => l.balance[i] = 0 /\ l.exitHeight[i] > 0)
           /\ (l.exitHeight[i] # 0 => l.exitHeight[i] \in (SwitchHeight + 1)..HeightBound)
    /\ l.sink + Cardinality({i \in BondIDs : l.balance[i] = 1}) = 4

ChoiceOK(d) ==
    /\ d.generation \in 0..1 /\ d.target \in 0..(HeightBound + 2)
    /\ d.decidedAt \in 0..HeightBound /\ d.members \subseteq AllKeys
    /\ d.source \in {"None", "Origin", "Candidate", "Fallback"}
CertOK(c) ==
    /\ c.generation \in 0..1 /\ c.height \in 0..HeightBound
    /\ c.round = 0 /\ c.blockID = <<c.generation, c.height>>
    /\ c.members \subseteq AllKeys /\ c.votes \subseteq c.members
ChainOK(s) ==
    /\ s.height \in SwitchHeight..HeightBound /\ s.origin \in SwitchHeight..s.height
    /\ s.generation \in 0..1 /\ s.storedGeneration \in 0..s.generation
    /\ s.originFallback \in {Fallback, Rotated}
    /\ s.snapshot.height \in 0..s.height /\ s.snapshot.members \subseteq StakeKeys
    /\ s.snapshot.total = Cardinality(s.snapshot.members)
    /\ ChoiceOK(s.current) /\ ChoiceOK(s.next) /\ ChoiceOK(s.pending)
    /\ (IF Free THEN s.missBitmap \subseteq BondIDs ELSE s.missBitmap \in 0..15)
    /\ CertOK(s.parentCert) /\ CertOK(s.cert)

TypeOK ==
    /\ ChainOK(chain) /\ ChainOK(landed.state) /\ landed.present \in BOOLEAN
    /\ landed.state.height <= chain.height /\ chain.height <= landed.state.height + 6
    /\ env.threshold \in Thresholds /\ env.changes \in 0..2 /\ env.lands \in 0..2
    /\ env.fallback \in {Fallback, Rotated} /\ env.lossUsed \in BOOLEAN
    /\ env.available \subseteq AllKeys /\ Fallback \subseteq env.available
    /\ (env.fallback = Rotated => Rotated \subseteq env.available)
    /\ Cardinality(StakeKeys \ env.available) <= 2
    /\ env.auth.present \in BOOLEAN /\ env.auth.disable \in BOOLEAN
    /\ env.auth.generation \in 0..1 /\ env.auth.c \in 0..HeightBound
    /\ IF Free THEN cursor = 0 ELSE cursor \in 0..Len(Schedule)

AtOrigin(s, d) ==
    /\ d.source = "Origin" /\ d.members = s.originFallback
    /\ d.generation = s.generation /\ d.decidedAt = s.origin
Assigned(s, d, h) ==
    /\ d.target = h /\ d.generation = s.generation /\ d.members # {}
    /\ IF h <= s.origin + 2 THEN AtOrigin(s, d)
       ELSE /\ d.decidedAt + 2 = h
            /\ CASE d.source = "Candidate" -> d.members \subseteq StakeKeys
                 [] d.source = "Fallback" -> d.members \in {Fallback, Rotated}
                 [] OTHER -> FALSE

\* Check the update list independently, key by key, including every deletion.
UpdateListOK ==
    /\ \A u \in chain.updates : u.key \in AllKeys /\ u.power \in 0..1
    /\ \A k \in AllKeys :
         /\ ([key |-> k, power |-> 0] \in chain.updates)
               = (k \in chain.next.members /\ k \notin chain.pending.members)
         /\ ([key |-> k, power |-> 1] \in chain.updates)
               = (k \notin chain.next.members /\ k \in chain.pending.members)

PipelineSafe ==
    /\ Assigned(chain, chain.next, chain.height + 1)
    /\ Assigned(chain, chain.pending, chain.height + 2)
    /\ IF chain.height = chain.origin THEN chain.current = EmptyChoice
       ELSE Assigned(chain, chain.current, chain.height)
    /\ IF Result = "Commit" THEN
        LET useStake == ~Prior.env.threshold.disabled
                        /\ chain.snapshot.height = chain.height
                        /\ chain.snapshot.members # {}
                        /\ chain.snapshot.total >= Prior.env.threshold.q
        IN /\ chain.height = PriorChain.height + 1
           /\ chain.origin = PriorChain.origin /\ chain.generation = PriorChain.generation
           /\ chain.originFallback = PriorChain.originFallback
           /\ chain.current = PriorChain.next /\ chain.next = PriorChain.pending
           /\ chain.pending.source = (IF useStake THEN "Candidate" ELSE "Fallback")
           /\ chain.pending.members = (IF useStake THEN chain.snapshot.members ELSE Prior.env.fallback)
           /\ UpdateListOK
       ELSE TRUE

\* Independent per-seat accounting for the last committed block. Miss lookup
\* uses only the actual parent certificate and the parent's post-transaction seat.
WasMiss(i) ==
    /\ i \in PriorChain.ledger.occupied
    /\ KeyOf[i] \in PriorChain.cert.members /\ KeyOf[i] \notin PriorChain.cert.votes
Deductions ==
    {i \in PriorChain.ledger.occupied :
        receipt.input[2] = "Effects" /\ WasMiss(i) /\ PriorChain.ledger.misses[i] = 1}
Called(kind) ==
    {i \in BondIDs : \E j \in 1..Len(receipt.input[3]) :
         receipt.input[3][j] = [kind |-> kind, bond |-> i]}

SnapshotOrderSafe ==
    IF Result # "Commit" THEN TRUE
    ELSE IF receipt.input[2] = "Effects"
         THEN /\ chain.storedGeneration = chain.generation
              /\ chain.snapshot.height = chain.height
              /\ chain.snapshot.members = Keys(PriorChain.ledger.occupied \ Deductions)
              /\ chain.snapshot.total = Cardinality(PriorChain.ledger.occupied \ Deductions)
         ELSE /\ chain.snapshot = PriorChain.snapshot
              /\ chain.storedGeneration = PriorChain.storedGeneration

LedgerSafe ==
    /\ LedgerOK(chain.ledger) /\ LedgerOK(landed.state.ledger)
    /\ IF Result # "Commit" THEN TRUE ELSE
        LET a == PriorChain.ledger
            b == chain.ledger
            forfeits == Called("Forfeit")
            exits == Called("Exit") \cup forfeits
        IN /\ b.forfeited = a.forfeited \cup forfeits
           /\ b.occupied = a.occupied \ (Deductions \cup exits)
           /\ b.sink = a.sink + Cardinality(Deductions) + Cardinality(forfeits)
           /\ \A i \in BondIDs :
                /\ b.balance[i] = (IF i \in Deductions \cup forfeits THEN 0 ELSE a.balance[i])
                /\ b.exitHeight[i] =
                     (IF i \in exits /\ a.exitHeight[i] = 0 THEN chain.height ELSE a.exitHeight[i])
                /\ b.misses[i] =
                     (IF receipt.input[2] # "Effects" \/ i \notin a.occupied THEN a.misses[i]
                      ELSE IF WasMiss(i) /\ i \notin Deductions THEN a.misses[i] + 1 ELSE 0)

StrictCert(c) ==
    /\ c.votes \subseteq c.members
    /\ Cardinality(c.members) * 2 < Cardinality(c.votes) * 3
QuorumSafe ==
    /\ IF chain.height = chain.origin
       THEN chain.cert = EmptyCert /\ chain.parentCert = EmptyCert /\ chain.missBitmap = EmptyBitmap
       ELSE /\ StrictCert(chain.cert) /\ chain.cert.members = chain.current.members
            /\ chain.cert.height = chain.height /\ chain.cert.generation = chain.generation
            /\ IF chain.height = chain.origin + 1 THEN chain.parentCert = EmptyCert
               ELSE /\ StrictCert(chain.parentCert)
                    /\ chain.parentCert.generation = chain.generation
                    /\ chain.parentCert.height + 1 = chain.height
    /\ CASE Result = "Commit" ->
               /\ chain.cert.votes = (Prior.env.available \cap PriorChain.next.members) \ receipt.input[4]
               /\ chain.parentCert = PriorChain.cert
               /\ \A i \in BondIDs : HasMissBit(chain.missBitmap, i) = WasMiss(i)
               /\ env = Prior.env /\ landed = Prior.landed
         [] Result = "RefusedBlock" ->
               /\ chain = PriorChain /\ landed = Prior.landed /\ env = Prior.env
               /\ 3 * Cardinality(Prior.env.available \cap PriorChain.next.members)
                    <= 2 * Cardinality(PriorChain.next.members)
         [] OTHER -> TRUE

RecoverySafe ==
    /\ IF Result = "Land"
       THEN /\ landed.present /\ landed.state = PriorChain
            /\ landed.state.height > Prior.landed.state.height
            /\ PriorChain.height > PriorChain.origin
            /\ chain = PriorChain /\ StrictCert(landed.state.cert)
       ELSE landed = Prior.landed
    /\ CASE Result = "Recover" ->
               /\ Prior.env.auth.present /\ Prior.env.auth.generation = PriorChain.generation
               /\ Prior.env.auth.c = landed.state.height
               /\ chain.height = landed.state.height /\ chain.origin = chain.height
               /\ chain.generation = PriorChain.generation + 1
               /\ chain.ledger = landed.state.ledger /\ chain.snapshot = landed.state.snapshot
               /\ chain.storedGeneration = landed.state.storedGeneration
               /\ chain.originFallback = Prior.env.fallback /\ chain.updates = {}
               /\ AtOrigin(chain, chain.next) /\ AtOrigin(chain, chain.pending)
               /\ chain.next.target = chain.height + 1 /\ chain.pending.target = chain.height + 2
               /\ chain.current = EmptyChoice /\ chain.cert = EmptyCert /\ chain.parentCert = EmptyCert
               /\ env.threshold = (IF Prior.env.auth.disable THEN Disabled ELSE Prior.env.threshold)
               /\ env.available = Prior.env.available /\ env.fallback = Prior.env.fallback
         [] Result = "RefusedRecovery" ->
               /\ (Prior.env.auth.c # Prior.landed.state.height
                     \/ Prior.env.auth.generation # PriorChain.generation)
               /\ env = Prior.env /\ chain = PriorChain
         [] Result = "Authorize" ->
               /\ env.auth.present /\ env.auth.generation = chain.generation
               /\ env.auth.c = landed.state.height /\ chain = PriorChain
         [] Result \in {"SetM", "Rotate", "Lose"} -> chain = PriorChain
         [] OTHER -> TRUE

CoreChain(s) ==
    [f \in (DOMAIN s) \ {"parentCert", "missBitmap", "updates"} |-> s[f]]

CoreCheckpoint(cp) ==
    [present |-> cp.present, height |-> cp.state.height, ledger |-> cp.state.ledger,
     snapshot |-> cp.state.snapshot, storedGeneration |-> cp.state.storedGeneration]

\* The six concrete predicate values distinguish a first failure from a good
\* state with identical operational fields. See L2_COMMITTEE_SAFETY_PROJECTION.md.
SafetyView ==
    IF Free
    THEN <<CoreChain(chain), CoreCheckpoint(landed), env,
           <<TypeOK, PipelineSafe, SnapshotOrderSafe, QuorumSafe, RecoverySafe, LedgerSafe>>>>
    ELSE vars

\* Reachability negations use actual state/receipts, without consulting the
\* schedule or the implementation's committee, ledger or election functions.
NoCandidate ==
    ~(/\ chain.generation = 0 /\ chain.height = 13
      /\ chain.current.source = "Candidate" /\ chain.current.decidedAt = 11
      /\ chain.current.members = StakeKeys /\ chain.cert.votes = StakeKeys)

NoRecoveryCircuit ==
    ~(/\ Result = "Commit" /\ chain.generation = 1 /\ chain.origin = 13 /\ chain.height = 18
      /\ chain.current.source = "Candidate" /\ chain.current.decidedAt = 16
      /\ chain.current.members = {"C","D"} /\ chain.cert.votes = {"C","D"}
      /\ chain.parentCert.members = Fallback /\ chain.ledger.forfeited = {0,1}
      /\ chain.ledger.sink = 2 /\ env.threshold = Money(2))

NoRecoveryRestall ==
    ~(/\ Result = "RefusedBlock" /\ chain.generation = 1 /\ chain.height = 15
      /\ chain.origin = 13 /\ env.threshold = Money(2) /\ chain.ledger.forfeited = {0,1}
      /\ chain.next.members = StakeKeys /\ chain.pending.members = {"C","D"}
      /\ chain.next.members \cap env.available = {"C","D"})

NoThresholdStall ==
    ~(/\ Result = "RefusedBlock" /\ chain.generation = 0 /\ chain.height = 15
      /\ env.threshold = Disabled /\ chain.snapshot.height = 15
      /\ chain.next.members = StakeKeys /\ chain.pending.members = {"A","B","C"}
      /\ chain.next.members \cap env.available = {"C","D"} /\ chain.ledger.exitHeight[3] = 14)

NoSuffixRollback ==
    ~(/\ Result = "Recover" /\ chain.origin = 13 /\ chain.generation = 1
      /\ PriorChain.height = 15 /\ PriorChain.ledger.exitHeight[3] = 14
      /\ PriorChain.pending.members = {"A","B","C"} /\ chain.ledger.occupied = BondIDs
      /\ chain.ledger.exitHeight[3] = 0 /\ chain.ledger = landed.state.ledger
      /\ chain.snapshot.height = 13 /\ chain.storedGeneration = 0
      /\ chain.next.members = Fallback /\ chain.pending.members = Fallback)

NoPenalty ==
    ~(/\ Result = "Commit" /\ chain.generation = 0 /\ chain.height = 17
      /\ chain.current.members = {"B","C","D"} /\ chain.cert.votes = {"B","C","D"}
      /\ chain.ledger.balance[0] = 0 /\ chain.ledger.exitHeight[0] = 0
      /\ chain.ledger.forfeited = {} /\ chain.ledger.misses[0] = 0 /\ chain.ledger.sink = 1)

NoEmptySeatCounter ==
    ~(/\ Result = "Commit" /\ chain.height = 15 /\ chain.generation = 0
      /\ chain.parentCert.votes = {"B","C","D"} /\ chain.ledger.exitHeight[0] = 14
      /\ chain.ledger.occupied = {1,2,3} /\ PriorChain.ledger.misses[0] = 1
      /\ chain.ledger.misses[0] = 1 /\ chain.ledger.balance[0] = 1
      /\ chain.ledger.sink = 0 /\ chain.snapshot.members = {"B","C","D"})

NoStaleSnapshotDelay ==
    ~(/\ Result = "Commit" /\ chain.generation = 1 /\ chain.height = 19
      /\ PriorChain.current.members = Fallback /\ PriorChain.next.members = {"C","D"}
      /\ chain.current.members = {"C","D"} /\ chain.current.decidedAt = 17
      /\ chain.cert.votes = {"C","D"} /\ chain.ledger.forfeited = {0,1})

NoStaleRecoveryRefusal ==
    ~(/\ Result = "RefusedRecovery" /\ Prior.env.auth.present /\ Prior.env.auth.disable
      /\ Prior.env.auth.c = 13 /\ landed.state.height = 14 /\ chain.height = 15
      /\ Prior.env.auth.generation = 0 /\ chain.generation = 0
      /\ env.threshold = Money(3) /\ env = Prior.env /\ chain = PriorChain)

NoStaleRecoveryBudgetRefusal ==
    ~(/\ Result = "RefusedRecovery" /\ chain.generation = 0 /\ chain.height = 12
      /\ landed.present /\ landed.state.height = 12
      /\ Prior.env.auth.present /\ Prior.env.auth.disable
      /\ Prior.env.auth.generation = 0 /\ Prior.env.auth.c = 11
      /\ env.changes = 2 /\ env.threshold = Money(3)
      /\ env = Prior.env /\ chain = PriorChain /\ landed = Prior.landed)
=========================================================================
