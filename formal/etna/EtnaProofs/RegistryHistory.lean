import EtnaModel.RegistryHistory
import EtnaProofs.Staking
import EtnaModel.Landing
import EtnaModel.Staking
import EtnaModel.Forced
import EtnaProofs.Landing
import EtnaProofs.Forced

/-! Proofs about `EtnaModel.RegistryHistory`. -/
namespace Etna.Design.RegistryHistory

theorem record_head (now : Nat) (es : List Committee.Entry) (history : List Snapshot) :
    (recordSnapshot now es history).head? = some ⟨now,es⟩ := by
  cases history <;> simp [recordSnapshot]
  split <;> rfl

theorem record_preserves_order (history : List Snapshot) (now : Nat) (es : List Committee.Entry)
    (ordered : Ordered history) (time : ((history.head?).getD default).block ≤ now) :
    Ordered (recordSnapshot now es history) := by
  cases history with
  | nil => simp [Ordered,recordSnapshot]
  | cons head rest =>
    change head.block ≤ now at time
    have parts := List.pairwise_cons.mp ordered
    by_cases same : head.block = now
    · simp only [recordSnapshot,same,ite_true,Ordered,List.pairwise_cons]
      exact ⟨by intro old mem; have := parts.1 old mem; omega,parts.2⟩
    · simp only [recordSnapshot,same,ite_false,Ordered,List.pairwise_cons]
      refine ⟨?_,parts⟩
      intro old mem
      rcases List.mem_cons.mp mem with rfl | tail
      · omega
      · have := parts.1 old tail
        omega

end Etna.Design.RegistryHistory
