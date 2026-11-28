-------------------- MODULE EtnaL2CommitteeFreeView --------------------
EXTENDS Naturals, FiniteSets, Sequences

CONSTANTS Profile, SymmetricBonds, Partitioned, LossCount, FirstMKind, SecondMKind
ASSUME /\ Partitioned \in BOOLEAN
       /\ IF Partitioned
          THEN /\ LossCount \in 0..2
               /\ <<FirstMKind, SecondMKind>> \in {<<2,3>>, <<2,4>>, <<4,2>>, <<4,3>>}
          ELSE TRUE

VARIABLES chain, landed, env, cursor, receipt
vars == <<chain, landed, env, cursor, receipt>>

K == INSTANCE EtnaL2CommitteeRecovery
     WITH Profile <- Profile, SymmetricBonds <- SymmetricBonds,
          chain <- chain, landed <- landed, env <- env,
          cursor <- cursor, receipt <- receipt

Init == K!Init
MFromKind(k) ==
    CASE k = 2 -> K!Money(2)
      [] k = 3 -> K!Money(3)
      [] k = 4 -> K!Disabled

\* K!Next assigns the receipt of this step. Only these two fresh events
\* have the corresponding second input element, independent of the old receipt.
KeepInputs ==
    IF ~Partitioned THEN TRUE
    ELSE IF ~env.lossUsed /\ env'.lossUsed
         THEN Cardinality(receipt'.input[2]) = LossCount
         ELSE IF chain.generation = 0 /\ env'.changes = env.changes + 1
              THEN CASE env.changes = 0 -> receipt'.input[2] = MFromKind(FirstMKind)
                     [] env.changes = 1 -> receipt'.input[2] = MFromKind(SecondMKind)
                     [] OTHER -> FALSE
              ELSE TRUE

Next == K!Next /\ KeepInputs
Spec == Init /\ [][Next]_vars

TypeOK == K!TypeOK
PipelineSafe == K!PipelineSafe
SnapshotOrderSafe == K!SnapshotOrderSafe
QuorumSafe == K!QuorumSafe
RecoverySafe == K!RecoverySafe
LedgerSafe == K!LedgerSafe
NoCandidate == K!NoCandidate
StakePermutations == K!StakePermutations

CoreLedger(l) ==
    [l EXCEPT !.exitHeight = [i \in DOMAIN l.exitHeight |->
                                 IF l.exitHeight[i] = 0 THEN 0 ELSE 1]]

CoreChain(s) ==
    [height |-> s.height, generation |-> s.generation, origin |-> s.origin,
     originFallback |-> s.originFallback, ledger |-> CoreLedger(s.ledger),
     current |-> s.current, next |-> s.next, pending |-> s.pending,
     cert |-> [s.cert EXCEPT !.votes = @ \cap K!StakeKeys]]

CoreCheckpoint(cp) ==
    [present |-> cp.present, height |-> cp.state.height,
     ledger |-> CoreLedger(cp.state.ledger)]

\* TLC evaluates each original predicate on the complete state and receipt.
SafetyView ==
    IF K!Free
    THEN <<CoreChain(chain), CoreCheckpoint(landed), env,
           <<TypeOK, PipelineSafe, SnapshotOrderSafe, QuorumSafe, RecoverySafe, LedgerSafe>>>>
    ELSE vars

\* A completed receipt carries its input and predecessor even after a stutter.
InputClassSafe ==
    IF ~Partitioned THEN TRUE
    ELSE CASE receipt.result = "Lose" ->
                  IF Len(receipt.input) = 2
                  THEN /\ receipt.input[1] = "Lose"
                       /\ Cardinality(receipt.input[2]) = LossCount
                  ELSE FALSE
           [] receipt.result = "SetM" /\ receipt.before.chain.generation = 0 ->
                  IF Len(receipt.input) = 2
                  THEN /\ receipt.input[1] = "SetM"
                       /\ CASE receipt.before.env.changes = 0 ->
                                   receipt.input[2] = MFromKind(FirstMKind)
                            [] receipt.before.env.changes = 1 ->
                                   receipt.input[2] = MFromKind(SecondMKind)
                            [] OTHER -> FALSE
                  ELSE FALSE
           [] OTHER -> TRUE

PartitionView == <<SafetyView, InputClassSafe>>

NoPartitionWitness ==
    ~(/\ chain.generation = 0 /\ chain.height = 11
      /\ env.changes = 2 /\ env.threshold = MFromKind(SecondMKind)
      /\ env.lossUsed /\ Cardinality(K!StakeKeys \ env.available) = LossCount)

========================================================================
