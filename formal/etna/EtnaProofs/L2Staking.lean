import EtnaModel.L2Staking
import EtnaProofs.Staking

namespace Etna.Design.L2Staking

/-- A miss penalty or forfeiture rounds the exact fixed-rate fraction upwards. -/
theorem rounded_penalty_ceiling (balance bps : Nat) :
    balance * bps ≤ roundedPenalty balance bps * 10000 ∧
      roundedPenalty balance bps * 10000 < balance * bps + 10000 :=
  Staking.forfeit_penalty_ceiling balance bps

theorem rounded_penalty_bounded (balance bps : Nat) (cap : bps ≤ 10000) :
    roundedPenalty balance bps ≤ balance :=
  Staking.forfeit_penalty_bounded balance bps cap

/-- Failure preserves the live staking state, evidence generation and stored snapshot. -/
theorem failed_block_start_preserves_state {s : State} {height caller generation missBitmap : Nat}
    {systemSucceeded : Bool}
    (failed : blockStartTransition s height caller generation missBitmap systemSucceeded = none) :
    onBlockStart s height caller generation missBitmap systemSucceeded = s := by
  simp [onBlockStart, failed]

/-- A successful block-start writes a snapshot for this height with one record per seat. -/
theorem successful_block_start_snapshot {s : State} {height caller generation missBitmap : Nat}
    {systemSucceeded : Bool} {result : Result}
    (ok : blockStartTransition s height caller generation missBitmap systemSucceeded =
      some result) :
    result.state.snapshot.height = height ∧ result.state.snapshot.seats.length = seatLimit := by
  unfold blockStartTransition at ok
  split at ok
  · cases Option.some.inj ok
    simp [buildSnapshot, Nat.add_sub_of_le (Nat.min_le_right _ _)]
  · cases ok

/-- A successful transaction changes the live ledger while retaining the block-start view. -/
theorem transaction_preserves_snapshot {s : State} {adapters : Adapters} {ctx : Context}
    {action : Action} {result : Result} (ok : execute s adapters ctx action = some result) :
    result.state.snapshot = s.snapshot ∧ result.state.generation = s.generation := by
  unfold execute at ok
  split at ok
  · cases ok
  · obtain ⟨_, _, applied⟩ := Option.bind_eq_some_iff.mp ok
    split at applied
    · cases Option.some.inj applied
      exact ⟨rfl, rfl⟩
    · cases applied

end Etna.Design.L2Staking
