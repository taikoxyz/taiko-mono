import EtnaModel.Landing
import EtnaModel.Common

namespace Etna.Design

theorem gridLeaves_getD (k p h : Nat) (table : List Cut) (j : Nat) (hj : j < gridCount k p h) :
    (gridLeaves k p h table).getD j default = cutLeaf (p+k*(j+1)) (table.getD (k*(j+1)) default) := by
  simp [gridLeaves, List.getD_eq_getElem?_getD, hj]

end Etna.Design
