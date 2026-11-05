import EtnaProofs.CurrentBlocks

open Etna.Design
open Etna.Design.Current.Blocks

-- First generation block takes a fresh origin anchor, not the old network anchor.
example (r : GenerationPolicy) (p : Header) (b : Block)
    (first : p.height = r.consensus.originHeight) (ok : AnchorValid r p b) :
    b.body.anchorWitness = true := first_anchor_witness first ok

-- An accepted advance exposes actual canonical inclusion or byte-bound legal skip.
example (r : GenerationPolicy) (p : Header) (b : Block) (ok : Valid r p b)
    (next : b.body.header.cursor = p.cursor+1) :
    ∃ w, b.body.forced = some w ∧ w.index = p.cursor ∧
      ActualQueue.ByteAction (definition r b).bytes p b.body w.stored b.raw b.first :=
  valid_advance_action ok next

namespace Etna.CurrentBlocksRegression
open Etna.Design.Current

def domain : Domain := ⟨1,2,3,4⟩
def context : Consensus.Context :=
  ⟨domain,0,0,10,10,10,1,1,1,fun _ => [⟨7,1,0,1000⟩],fun h => 10+(h-1)⟩
def byteAdapters : ActualQueue.Primitives :=
  ⟨fun raw => ((raw.head?).getD 0).toNat,fun raw => !raw.isEmpty,fun _ _ _ => .completedEmpty⟩
def interpreter : Definition := ⟨fun _ _ => true,fun _ _ _ => true,byteAdapters⟩
def policy : GenerationPolicy where
  consensus := context
  startHeight := 0
  gridK := 1
  committeeConfig := 0
  maxAnchorAge := 10
  forcedDelay := 1
  unsettled := 10
  referenceNumber := 20
  referenceHash := 200
  committeeHash := fun _ => 1
  signature := fun _ => True
  anchorAuthenticated := fun _ => true
  committeeAuthenticated := fun _ _ => true
  forcedAuthenticated := fun _ _ => true
  scheduleAuthenticated := fun _ s => decide (s = ⟨1,2,12,0,0⟩)
  batchPayloadValid := fun _ _ => true
  configHash := fun _ => 0
  historyAuthenticated := fun _ _ => true
  catalogue := fun id => if id = 1 ∨ id = 2 then some interpreter else none

def parent : Header := ⟨0,100,100,0,0,10,⟨500,1,500,0,0,9,0⟩,0⟩
def w0 : Forced.Witness := ⟨0,⟨7,9,9⟩,true,7,1,true,some 7,true,1⟩
def w1 : Forced.Witness := ⟨1,⟨8,9,9⟩,true,8,1,true,none,false,0⟩
def b1 : Block := ⟨
  ⟨⟨1,101,101,201,1,11,⟨10,10,1,0,0,0,1⟩,0⟩,100,none,domain,0,11,100,100,true,none,
    1,1,1,0,[⟨domain,0,1,0,2,201,7⟩],some w0,.completedEmpty⟩,
  ⟨1,2,12,0,0⟩,[7],some [7],[[7]]⟩
def b2 : Block := ⟨
  ⟨⟨2,102,102,202,2,12,⟨11,11,2,0,0,0,2⟩,0⟩,101,some 201,domain,0,12,100,100,true,none,
    1,1,2,0,[⟨domain,0,2,0,2,202,7⟩],some w1,.completedEmpty⟩,
  ⟨1,2,12,0,0⟩,[8],none,[]⟩

instance (r : GenerationPolicy) (p : Header) (b : Block) : Decidable (ParentAnchorValid r p b) := by
  unfold ParentAnchorValid
  split <;> infer_instance
instance (a : ActualQueue.Primitives) (p : Header) (b : BlockValidity.Block) (w : Forced.Witness)
    (raw : Bytes) (first : Option Bytes) : Decidable (ActualQueue.PayloadFields a p b w raw first) :=
  inferInstanceAs (Decidable (_ ∧ _))

-- A copied unconditional parent-anchor floor rejects this valid first block.
example : ParentAnchorValid policy parent b1 := by decide +kernel
example : ¬ parent.anchor.number ≤ b1.header.anchor.number := by decide +kernel

-- Different timestamps select different immutable definitions inside one proof batch.
example : selectedRules b1 = 1 ∧ selectedRules b2 = 2 := by decide +kernel

instance : DecidablePred policy.signature := fun _ => inferInstanceAs (Decidable True)
instance : Decidable (HeaderValid policy parent b1) := inferInstanceAs (Decidable (_ ∧ _))
instance : Decidable (HeaderValid policy b1.header b2) := inferInstanceAs (Decidable (_ ∧ _))

theorem first_valid : Valid policy parent b1 := by
  constructor
  all_goals first
    | decide +kernel
    | (constructor <;> decide +kernel)
    | (intro w carried; have same : w = w0 := (Option.some.inj carried).symm; subst w; decide +kernel)

theorem second_valid : Valid policy b1.header b2 := by
  constructor
  all_goals first
    | decide +kernel
    | (constructor <;> decide +kernel)
    | (intro w carried; have same : w = w1 := (Option.some.inj carried).symm; subst w; decide +kernel)

theorem crossing_chain : Chain policy parent [b1,b2] := ⟨first_valid,second_valid,True.intro⟩
example : (headerAt parent [b1,b2] 1).elHash = 101 := rfl
example : (terminal parent [b1,b2]).cursor = 2 := rfl
example : Chain policy (headerAt parent [b1,b2] 1) ([b1,b2].drop 1) := (chain_suffix crossing_chain 1).2

-- The local accepted block exposes position-zero canonical bytes.
example : ActualQueue.ByteAction (definition policy b1).bytes parent b1.body w0.stored b1.raw b1.first := by
  exact ⟨[7],rfl,rfl,rfl,by decide⟩ |> Or.inl

-- The next due block legally skips by a completed-empty deterministic singleton.
example : b2.header.cursor = b1.header.cursor+1 ∧ w1.index = b1.header.cursor ∧
    ActualQueue.ByteAction (definition policy b2).bytes b1.header b2.body w1.stored b2.raw b2.first :=
  valid_due_action second_valid (by decide) rfl (by decide)

-- Resource unavailability does not become a legal skip.
example : Forced.step 1 2 11 1 (some w1) .unavailable = .waiting := by decide +kernel

-- Unknown definitions and active stop grids cannot authorize a block.
example (r : GenerationPolicy) (p : Header) (b : Block)
    (unknown : r.catalogue (selectedRules b) = none) : ¬Valid r p b := unknown_rules_refused unknown
example (r : GenerationPolicy) (p : Header) (b : Block)
    (stopped : Rules.stopped b.schedule r.startHeight p.height p.timestamp = true) : ¬Valid r p b := by
  intro ok
  have no := ok.notStopped
  rw [stopped] at no
  cases no

-- Fixed parser decoding rejects empty raw bytes; that is a legal hash-bound skip.
def invalidWitness : Forced.Witness := ⟨0,⟨0,9,9⟩,true,0,0,false,none,false,0⟩
def invalidBlock : Block := { b1 with body := { b1.body with forced := some invalidWitness },raw := [],first := none,transactions := [] }
instance : Decidable (HeaderValid policy parent invalidBlock) := inferInstanceAs (Decidable (_ ∧ _))
theorem invalid_raw_valid : Valid policy parent invalidBlock := by
  constructor
  all_goals first
    | decide +kernel
    | (constructor <;> decide +kernel)
    | (intro w carried; have same : w = invalidWitness := (Option.some.inj carried).symm; subst w; decide +kernel)
example : ActualQueue.ByteAction (definition policy invalidBlock).bytes parent invalidBlock.body
    invalidWitness.stored invalidBlock.raw invalidBlock.first :=
  (valid_due_action invalid_raw_valid (by decide) rfl (by decide)).2.2

-- Neither fabricated witness bytes nor an unavailable singleton can pass direct checks.
example : ¬Valid policy b1.header { b2 with body := { b2.body with singleton := .unavailable } } := by
  intro ok
  have forced := ok.forced
  change Forced.Result.waiting = Forced.Result.accepted 2 at forced
  cases forced
example : ¬Valid policy parent { b1 with raw := [8] } := by
  intro ok
  have fields := ok.fields w0 rfl
  have hash := fields.2.1
  change 7 = 8 at hash
  cases hash

-- A supplied position-zero field must be the head of the complete decoded payload.
-- Finding the entry later in the execution body is not inclusion.
example : ¬Valid policy parent { b1 with transactions := [[8],[7]] } := by
  intro valid
  have head := valid.positionZero
  change some [7] = some [8] at head
  cases head

-- Even an ineligible byte string cannot be skipped before its inclusive deadline.
def earlyWitness : Forced.Witness := { invalidWitness with stored := ⟨0,20,9⟩ }
example : Forced.step 0 1 10 1 (some earlyWitness) .completedEmpty = .accepted 0 := by decide
example : Forced.step 0 1 10 1 (some earlyWitness) .completedEmpty ≠ .accepted 1 := by decide

-- All three installed definitions matter across separate authenticated schedule writes;
-- an image missing the middle definition cannot certify the complete decoded batch.
def third : Block := ⟨
  ⟨⟨3,103,103,203,2,13,⟨12,12,3,0,0,0,2⟩,0⟩,102,some 202,domain,0,13,100,100,true,none,
    1,1,3,0,[⟨domain,0,3,0,2,203,7⟩],none,.completedEmpty⟩,
  ⟨2,3,13,0,0⟩,[],none,[]⟩
def threePolicy : GenerationPolicy :=
  { policy with
    catalogue := fun id => if id = 1 ∨ id = 2 ∨ id = 3 then some interpreter else none
    scheduleAuthenticated := fun _ s => decide (s = ⟨1,2,12,0,0⟩ ∨ s = ⟨2,3,13,0,0⟩) }
instance : Decidable (HeaderValid threePolicy b2.header third) := inferInstanceAs (Decidable (_ ∧ _))
instance : Decidable (HeaderValid threePolicy parent b1) := inferInstanceAs (Decidable (_ ∧ _))
instance : Decidable (HeaderValid threePolicy b1.header b2) := inferInstanceAs (Decidable (_ ∧ _))
instance : DecidablePred threePolicy.signature := fun _ => inferInstanceAs (Decidable True)
theorem first_three_valid : Valid threePolicy parent b1 := by
  constructor
  all_goals first
    | decide +kernel
    | (constructor <;> decide +kernel)
    | (intro w carried; have same : w = w0 := (Option.some.inj carried).symm; subst w; decide +kernel)
theorem second_three_valid : Valid threePolicy b1.header b2 := by
  constructor
  all_goals first
    | decide +kernel
    | (constructor <;> decide +kernel)
    | (intro w carried; have same : w = w1 := (Option.some.inj carried).symm; subst w; decide +kernel)
theorem third_valid : Valid threePolicy b2.header third := by
  constructor
  all_goals first
    | decide +kernel
    | (constructor <;> decide +kernel)
    | (intro witness carried; cases carried)
theorem three_chain : Chain threePolicy parent [b1,b2,third] :=
  ⟨first_three_valid,second_three_valid,third_valid,True.intro⟩
example : [b1,b2,third].map selectedRules = [1,2,3] := by decide
example : ([b1,b2,third].all fun b => decide (selectedRules b ∈ [1,2,3])) = true := by decide
example : ([b1,b2,third].all fun b => decide (selectedRules b ∈ [1,3])) = false := by decide

-- Unlanded current validity has no uint48 height cap; land enforces its own field bound.
def highPolicy : GenerationPolicy := { policy with consensus := { context with originHeight := limit48-1 } }
def highParent : Header := { parent with height := limit48-1 }
def highBlock : Block := { b1 with body := { b1.body with header := { b1.header with height := limit48 } } }
instance : Decidable (HeaderValid highPolicy highParent highBlock) := inferInstanceAs (Decidable (_ ∧ _))
example : HeaderValid highPolicy highParent highBlock := by decide +kernel

end Etna.CurrentBlocksRegression

-- Every advanced pair is retained, and its actual parent cursor is in exact FIFO order.
example (r : GenerationPolicy) (p : Header) (bs : List Block) (ok : Chain r p bs) :
    (consumingPairs p bs).map (fun x => x.1.cursor) =
      List.range' p.cursor ((terminal p bs).cursor-p.cursor) := chain_consumed_indices ok
