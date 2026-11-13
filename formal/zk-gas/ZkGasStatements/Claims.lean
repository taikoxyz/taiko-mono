import ZkGasModel

/-!
# Reviewable zk gas metering claims

The metering propositions describe how one block's zk gas charges are accounted: the block
limit, the abort of the transaction that exceeds it, the commit of one that fits and the block
total. Each transaction is the list of its charges in metering order, starting with its
intrinsic charge; how an opcode or precompile charge is computed is not part of these claims.
They range over every schedule, so they hold for `unzen` in particular.

The step propositions are about the step model `stepOutcome` (`ZkGasModel.Step`) on Unzen: the
branch list the coverage gate uses is complete, no step raises the frame's gas, and only a spawn
opcode opens a frame.
-/
namespace TaikoSpec.ZkGas.Statements

/-- A block never uses more zk gas than its limit, whatever its transactions charge. -/
def BlockWithinLimit : Prop :=
  ∀ (s : Schedule) (txs : List (List Nat)), (meterBlock s txs).2 ≤ s.blockLimit

/-- Take a block whose transactions `pre` all committed, followed by a transaction `tx` whose
charges exceed what the block has left. Then `tx` aborts: it contributes nothing to the block
total, which stays `pre`'s, and the transactions `rest` after it are not executed, so they get
no result and change nothing. -/
def AbortContributesNothing : Prop :=
  ∀ (s : Schedule) (pre : List (List Nat)) (tx : List Nat) (rest : List (List Nat)),
    none ∉ (meterBlock s pre).1 →
    meterTx s (meterBlock s pre).2 tx = none →
    meterBlock s (pre ++ tx :: rest) = ((meterBlock s pre).1 ++ [none], (meterBlock s pre).2)

/-- Every committed transaction's total is the sum of its charges, intrinsic charge included,
and the block total is the sum of the committed transactions' totals. -/
def TotalIsSum : Prop :=
  ∀ (s : Schedule) (txs : List (List Nat)),
    (∀ (i n : Nat), (meterBlock s txs).1[i]? = some (some n) → txs[i]?.map List.sum = some n) ∧
      (meterBlock s txs).2 = ((meterBlock s txs).1.filterMap id).sum

/-- Take a block whose transactions `pre` all committed, followed by a transaction `tx` whose
charges fit what the block has left. Then `tx` commits with the sum of its charges, intrinsic
charge included, as its result, and adds that sum to the block total. With the claims above, this
rules out a meter that aborts transactions that fit. -/
def FitCommits : Prop :=
  ∀ (s : Schedule) (pre : List (List Nat)) (tx : List Nat) (rest : List (List Nat)),
    none ∉ (meterBlock s pre).1 →
    tx.sum ≤ s.blockLimit - (meterBlock s pre).2 →
    (meterBlock s (pre ++ tx :: rest)).1[pre.length]? = some (some tx.sum) ∧
      (meterBlock s (pre ++ [tx])).2 = (meterBlock s pre).2 + tx.sum

/-- `allBranches` lists every branch of the step model, so the coverage gate, which requires the
corpus to reach each branch it lists apart from `unreachableBranches`, leaves no branch out. -/
def BranchesComplete : Prop := ∀ b : BranchId, b ∈ allBranches

/-- On Unzen, no step leaves its frame more gas than the frame had before it. So the gas a step
uses, the gas before minus the gas after, is never negative: alethia-reth's saturating
subtraction and taiko-geth's error for a rise in gas never take effect. -/
def StepGasMonotone : Prop :=
  ∀ (pre : Pre) (r : StepResult), stepOutcome .unzen pre = .ok r → r.gasAfter ≤ pre.gas

/-- On Unzen, only an opcode with a spawn estimate opens a new frame, so every step that is
charged a spawn estimate instead of its gas has one. -/
def SpawnOnlyForSpawnOps : Prop :=
  ∀ (pre : Pre) (r : StepResult), stepOutcome .unzen pre = .ok r → r.outcome = .newFrame →
    unzen.spawnEstimate pre.op ≠ none

end TaikoSpec.ZkGas.Statements
