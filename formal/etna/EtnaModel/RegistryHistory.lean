import EtnaModel.Staking
import EtnaModel.Landing
import EtnaModel.Forced

/-! L1 registry specification state. Keys are canonical abstract registration identities
(the real key/address/PoP binding is external). Historical snapshots contain election
entries only: owner and exit confirmation metadata never enter entriesRoot. -/
namespace Etna.Design.RegistryHistory

structure Snapshot where
  block : Nat
  entries : List Committee.Entry
  deriving DecidableEq, Repr, Inhabited

/-- Newest checkpoint first. An entry-changing transaction in the same L1 block replaces
that block's checkpoint; finalized later blocks never mutate an older snapshot. -/
def recordSnapshot (now : Nat) (entries : List Committee.Entry) : List Snapshot → List Snapshot
  | [] => [⟨now,entries⟩]
  | head :: rest => if head.block = now then ⟨now,entries⟩ :: rest else ⟨now,entries⟩ :: head :: rest

def latestSnapshot (history : List Snapshot) (cutoff : Nat) : Option Snapshot :=
  history.find? (fun cp => decide (cp.block ≤ cutoff))

def Ordered (history : List Snapshot) : Prop := history.Pairwise (fun a b => b.block < a.block)

instance (history : List Snapshot) : Decidable (Ordered history) :=
  inferInstanceAs (Decidable (history.Pairwise (fun a b => b.block < a.block)))

end Etna.Design.RegistryHistory
