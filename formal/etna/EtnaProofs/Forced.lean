import EtnaModel.Forced
import EtnaModel.Common

namespace Etna.Design.Forced

theorem step_one_or_zero {c tail anchor delay next : Nat} {w : Option Witness} {x : Singleton}
    (ok : step c tail anchor delay w x = .accepted next) : next = c ∨ next = c+1 := by
  cases x <;> simp only [step] at ok <;> (repeat' split at ok) <;> simp_all

theorem overdue_from_block_time (blockTime anchorTime submitted delay maxAge : Nat)
    (age : blockTime-anchorTime ≤ maxAge) (anchorBefore : anchorTime ≤ blockTime)
    (late : submitted+delay+maxAge ≤ blockTime) : submitted+delay ≤ anchorTime := by omega

end Etna.Design.Forced
