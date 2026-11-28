import EtnaModel.Landing
import EtnaModel.Common

namespace Etna.Design

theorem innerLeaves_getD (p h : Nat) (table : List Cut) (j : Nat) (hj : j < h-p-1) :
    (innerLeaves p h table).getD j default = cutLeaf (p+(j+1)) (table.getD (j+1) default) := by
  simp [innerLeaves, List.getD_eq_getElem?_getD, hj]

end Etna.Design
