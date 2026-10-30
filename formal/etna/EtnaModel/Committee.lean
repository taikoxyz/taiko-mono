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

/-- Fixed TAIKO supply in base units and the deployment floor for vp_unit (4.3). -/
def supply : Nat := 10^27
def minUnit : Nat := 867361738

/-- Duplicate keys invalidate the state only among eligible entries: released slots are all
zero (exitEffectiveL1 = 0, so never eligible) and legitimately repeat the zero key. -/
def election (unit minimum cutoff nMax : Nat) (entries : List Entry) : Option (List Entry) :=
  let selected := chosen unit minimum cutoff nMax entries
  if 0 < unit ∧ unit ≤ minimum ∧ 1 ≤ nMax ∧ nMax ≤ 4096 ∧
     ((entries.filter (eligible unit minimum cutoff)).map Entry.key).Nodup ∧ selected ≠ [] ∧
     (∀ e ∈ selected, 0 < power unit e) ∧ totalPower unit selected ≤ maxPower
  then some selected else none

structure Witness where
  proofRoot : Hash
  cutoff : Nat
  deriving DecidableEq, Repr

def normalCutoff (derivationParentAnchor generationOriginBlock : Nat) : Nat :=
  max derivationParentAnchor generationOriginBlock

/-- §3.4 rule 3: an anchor never goes below its parent's anchor or the current
generation's fixed L1 origin (L1_0 for generation 0, R after a recovery). -/
def anchorOK (parentAnchor originBlock anchor : Nat) : Bool :=
  decide (parentAnchor ≤ anchor ∧ originBlock ≤ anchor)

/-- Anchors of consecutive blocks in one generation, starting after `parentAnchor`. -/
def anchorChain (originBlock : Nat) : Nat → List Nat → Bool
  | _, [] => true
  | parent, a :: rest => anchorOK parent originBlock a && anchorChain originBlock a rest

/-- Cutoff of the committee governing epoch t of one generation: its first committee
(genesisCutoff for generation 0, R after a recovery) until the first normal switch takes
effect at epoch t₀, then max(anchor of D(t), origin). -/
def generationCutoff (first origin t₀ : Nat) (anchorD : Nat → Nat) (t : Nat) : Nat :=
  if t < t₀ then first else normalCutoff (anchorD t) origin

def witnessOK (parentAnchor originBlock : Nat) (switchRoot : Hash) (w : Witness) : Prop :=
  w.cutoff = normalCutoff parentAnchor originBlock ∧ w.proofRoot = switchRoot

structure Schedule where
  current : Record
  pending : Option (Nat × Record)
  deriving DecidableEq, Repr

def authority (s : Schedule) (h : Nat) : Record :=
  match s.pending with
  | none => s.current
  | some (activation,r) => if activation ≤ h then r else s.current

def announce (s : Schedule) (height : Nat) (incoming : Record) : Schedule :=
  ⟨authority s height, some (height+2,incoming)⟩

def recoverySchedule (r : Record) : Schedule := ⟨r,none⟩

/-- Grid interval 1 ≤ K ≤ 6; U and L have no dependency; K ≤ U ≤ 65,536 and U a multiple of
K, so the pause point is a grid point (target deployment U = 3,600 suits every K ≤ 6). -/
def configOK (k l u : Nat) : Bool :=
  decide (1 ≤ k ∧ k ≤ 6 ∧ 3 ≤ l ∧ l+1 < limit48 ∧ k ≤ u ∧ u ≤ 65536 ∧ u % k = 0)

def backPressure (height checkpoint u : Nat) : Bool := decide (height-checkpoint ≤ u)

end Etna.Design.Committee
