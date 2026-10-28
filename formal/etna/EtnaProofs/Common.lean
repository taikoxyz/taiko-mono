import EtnaModel.Common

/-! Proofs about `EtnaModel.Common`. -/
namespace Etna.Design

theorem dual_count {ps : List (Backend × Bool)} (ok : dualOK ps = true) : ps.length = 2 := by
  simp only [dualOK, Bool.and_eq_true, decide_eq_true_eq] at ok
  exact ok.1.1.1

end Etna.Design
