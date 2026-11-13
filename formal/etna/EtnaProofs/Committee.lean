import EtnaModel.Committee
import EtnaModel.Common

namespace Etna.Design.Committee

theorem chosen_eligible (unit minimum cutoff nMax : Nat) (entries : List Entry) (e : Entry)
    (selected : e ∈ chosen unit minimum cutoff nMax entries) :
    e ∈ entries ∧ e.activeFrom ≤ cutoff ∧ cutoff < e.exitAt ∧ max minimum unit ≤ e.stake := by
  have m := List.mem_of_mem_take (List.mem_mergeSort.mp selected)
  have f := List.mem_filter.mp (List.mem_mergeSort.mp m)
  exact ⟨f.1, by simpa [eligible] using f.2⟩

end Etna.Design.Committee
