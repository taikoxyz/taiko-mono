import EtnaModel.Common

namespace Etna.Design.Committee

def eligible (unit minimum cutoff : Nat) (e : Entry) : Bool :=
  decide (e.activeFrom ≤ cutoff ∧ cutoff < e.exitAt ∧ max minimum unit ≤ e.stake)

def rank (a b : Entry) : Bool :=
  decide (b.stake < a.stake ∨ (a.stake = b.stake ∧ a.key ≤ b.key))

def chosen (unit minimum cutoff nMax : Nat) (entries : List Entry) : List Entry :=
  (((entries.filter (eligible unit minimum cutoff)).mergeSort rank).take nMax).mergeSort
    (fun a b => decide (a.key ≤ b.key))

def power (unit : Nat) (e : Entry) : Nat := e.stake/unit
def totalPower (unit : Nat) (es : List Entry) : Nat := (es.map (power unit)).sum
def maxPower : Nat := (2^63-1)/8

def minUnit : Nat := 867361738

/-- Duplicate keys invalidate the state only among eligible entries: released slots are all
zero (exitEffectiveL1 = 0, so never eligible) and legitimately repeat the zero key. -/
def election (unit minimum cutoff nMax : Nat) (entries : List Entry) : Option (List Entry) :=
  let selected := chosen unit minimum cutoff nMax entries
  if 0 < unit ∧ unit ≤ minimum ∧ 1 ≤ nMax ∧ nMax ≤ 4096 ∧
     ((entries.filter (eligible unit minimum cutoff)).map Entry.key).Nodup ∧ selected ≠ [] ∧
     (∀ e ∈ selected, 0 < power unit e) ∧ totalPower unit selected ≤ maxPower
  then some selected else none

/-- Grid interval 1 ≤ K ≤ 6; U and L have no dependency; K ≤ U ≤ 65,536 and U a multiple of
K, so the pause point is a grid point (target deployment U = 3,600 suits every K ≤ 6). -/
def configOK (k l u : Nat) : Bool :=
  decide (1 ≤ k ∧ k ≤ 6 ∧ 3 ≤ l ∧ l+1 < limit48 ∧ k ≤ u ∧ u ≤ 65536 ∧ u % k = 0)

end Etna.Design.Committee
