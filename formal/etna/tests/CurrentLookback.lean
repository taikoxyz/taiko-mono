import EtnaProofs.CurrentLookback

/-! A bounded historical suffix is extractable from full ordinary ancestry. These
fixtures do not implement guest certificates from only that suffix. -/
namespace Etna.CurrentLookbackRegression
open Etna.Design Etna.Design.Current

def domain : Domain := ⟨1,2,3,4⟩
def cfg : Finality.Config := ⟨domain,0,0,10,10,10,1,1,1⟩
def header (height : Nat) : Blocks.Header :=
  ⟨height,100+height,0,0,0,height,⟨1000+height,0,0,0,0,0,0⟩⟩
def parentOf (hash : Hash) := hash-1
def prior : List Blocks.Header := (List.range' 1 99).map header

def linkedDecision (root : Blocks.Header) (headers : List Blocks.Header) :
    Decidable (Archive.Linked parentOf root headers) :=
  match headers with
  | [] => isTrue True.intro
  | h :: rest =>
    letI := linkedDecision h rest
    inferInstanceAs (Decidable (h.height = root.height+1 ∧ parentOf h.elHash = root.elHash ∧
      Archive.Linked parentOf h rest))

instance (root : Blocks.Header) (headers : List Blocks.Header) :
    Decidable (Archive.Linked parentOf root headers) := linkedDecision root headers

theorem linked : Archive.Linked parentOf (header 0) prior := by decide +kernel
theorem ends : Archive.terminal (header 0) prior = header 99 := by decide +kernel

example (c : Finality.Config) (parent : Hash → Hash) (root p : Blocks.Header)
    (history : List Blocks.Header) (positive : 0 < c.epochLen)
    (ancestry : Archive.Linked parent root history) (last : Archive.terminal root history = p) :
    (Archive.decisionWindow c root history p).length ≤ c.epochLen+2 :=
  Archive.decisionWindow_length_le positive ancestry last

example : Finality.decisionLookback cfg 100 = 88 := by decide +kernel
example : (Archive.decisionWindow cfg (header 0) prior (header 99)).map BlockValidity.Header.height =
    List.range' 88 12 := by decide +kernel
example : (Archive.decisionWindow cfg (header 0) prior (header 99)).length = 12 := by decide +kernel
example : (Archive.decisionWindow cfg (header 0) prior (header 99)).length ≤ 12 :=
  Archive.decisionWindow_length_le (by decide) linked ends
example : (Archive.decisionWindow cfg (header 0) prior (header 99)).head? = some (header 88) := by
  decide +kernel
example : (Archive.decisionWindow cfg (header 0) prior (header 99)).head? = prior[87]? :=
  Archive.decisionWindow_head_eq_decision rfl (by decide)
example : ∃ h, (Archive.decisionWindow cfg (header 0) prior (header 99)).head? = some h ∧
    prior[87]? = some h ∧ h.height = 88 :=
  Archive.decisionWindow_decision_header linked ends rfl (by decide)
example (first : Blocks.Header) (rest : List Blocks.Header)
    (shape : Archive.decisionWindow cfg (header 0) prior (header 99) = first :: rest) :
    Archive.Linked parentOf first rest ∧ Archive.terminal first rest = header 99 :=
  Archive.decisionWindow_ancestry linked ends shape
example : Finality.anchorAt cfg prior 88 = 1088 := by decide +kernel
example : Finality.anchorAt cfg prior 88 =
    ((Archive.decisionWindow cfg (header 0) prior (header 99)).head?.map
      (fun h => h.anchor.number)).getD cfg.originBlock :=
  Archive.decisionWindow_anchor_eq (cfg := cfg) (root := header 0) (p := header 99) rfl (by decide)
example : Finality.cutoff cfg prior 100 =
    max (((Archive.decisionWindow cfg (header 0) prior (header 99)).head?.map
      (fun h => h.anchor.number)).getD cfg.originBlock) cfg.originBlock :=
  Archive.decisionWindow_cutoff_eq (cfg := cfg) (root := header 0) (p := header 99) rfl (by decide)

-- A decision at or below the generation origin uses the origin floor, not the
-- origin header's own anchor. The retained suffix begins with that origin header.
example : (Archive.decisionWindow {cfg with originHeight := 95}
    (header 95) ((List.range' 96 4).map header) (header 99)).map BlockValidity.Header.height =
      List.range' 95 5 := by decide +kernel
example : Finality.anchorAt {cfg with originHeight := 95} ((List.range' 96 4).map header) 88 =
    cfg.originBlock := by decide +kernel
example : Archive.decisionWindow {cfg with originHeight := 95}
    (header 95) ((List.range' 96 4).map header) (header 99) =
      header 95 :: (List.range' 96 4).map header ∧
    Finality.anchorAt {cfg with originHeight := 95} ((List.range' 96 4).map header) 88 = cfg.originBlock :=
  Archive.decisionWindow_origin_floor rfl (by decide)
example : Finality.anchorAt {cfg with originHeight := 88} ((List.range' 89 11).map header) 88 =
    cfg.originBlock := by decide +kernel
example : (Archive.decisionWindow cfg (header 0) [header 1,header 2] (header 2)).map BlockValidity.Header.height =
    [0,1,2] := by decide +kernel
example : Archive.decisionWindow cfg (header 0) [] (header 0) = [header 0] := by decide +kernel

-- Positive epoch length is essential: the total zero-divisor convention gives
-- D=0 and retains the entire 100-header history instead of a two-header window.
example : (Archive.decisionWindow {cfg with epochLen := 0} (header 0) prior (header 99)).length = 100 := by
  decide +kernel

end Etna.CurrentLookbackRegression
