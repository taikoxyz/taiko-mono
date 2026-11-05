import EtnaProofs.CurrentFinality

open Etna.Design
open Etna.Design.Current
open Etna.Design.Current.Finality

-- A derivation lookback at/below the new generation origin reads the fixed origin floor.
example (cfg : Config) (registry : RegistryMachine.State) (archive : List Blocks.Header)
    (h : Nat) (before : h ≤ cfg.originHeight) :
    (derive cfg registry archive).anchorAt h = cfg.originBlock :=
  derive_preorigin_anchor cfg registry archive h before

namespace Etna.CurrentFinalityRegression
set_option maxRecDepth 30000
set_option maxHeartbeats 8000000

def domain : Domain := ⟨1,2,3,4⟩
def cfg : Config := ⟨domain,0,8,10,10,10,1,1,1⟩
def bond : Registry.Bond := ⟨⟨7,70,1,0,1000,false,none,0,0⟩,some 0⟩
def rawRegistry : RegistryMachine.State where
  ledger := {
    nextId := 1
    bonds := fun i => if i = 0 then some bond else none
    slots := fun i => if i = 0 then some 0 else none
    keyId := fun k => if k = 7 then some 0 else none }
  verify := fun key _ sig => key == sig

def registry : RegistryMachine.State :=
  { rawRegistry with history := [⟨10,RegistryMachine.entries rawRegistry⟩] }
def laterRegistry : RegistryMachine.State :=
  { registry with history := ⟨20,[]⟩ :: registry.history }
def h9 : Blocks.Header := ⟨9,9,9,9,0,11,⟨11,11,11,8,8,0,0⟩,0⟩
def h10 : Blocks.Header := ⟨10,10,10,10,0,12,⟨12,12,12,8,8,0,0⟩,0⟩
def oldUnzen : Blocks.Header := ⟨8,8,8,8,0,500,⟨500,500,500,8,8,9,0⟩,0⟩
def adapters : Adapters := ⟨fun _ => true,fun _ => true,fun _ => true⟩

-- S=8,L=10,D(1)=8 must select origin10 even if supplied old bytes carry anchor500.
example : (derive cfg registry [oldUnzen]).anchorAt 8 = 10 := by decide +kernel
example : (Consensus.normal (derive cfg registry [oldUnzen]) 1).cutoff = 10 := by decide +kernel
example : (Consensus.initial (derive cfg registry [h9])).targetEpoch = 0 := by decide +kernel
example : (build adapters cfg registry [h9] 11).isSome = true := by decide +kernel
example : (build adapters cfg registry [oldUnzen] 11).isNone = true := by decide +kernel
example : (build adapters cfg registry [] 21).isNone = true := by decide +kernel
example : (build adapters cfg registry [{h9 with height := 8}] 11).isNone = true := by decide +kernel
example : (build {adapters with config := fun _ => false} cfg registry [h9] 11).isNone = true := by decide +kernel
example : (Consensus.initial (derive {cfg with genesisCutoff := 7} registry [h9])).cutoff = 7 := by decide +kernel

def normalCfg : Config := {cfg with originHeight := 0}
def normalHeader (h : Nat) : Blocks.Header := ⟨h,h,h,h,0,10+h,⟨10+h,10+h,10+h,0,0,0,0⟩,0⟩
def common : List Blocks.Header := (List.range' 1 8).map normalHeader

-- A genuine post-origin D(1)=8 reads header8's anchor18, independent of later suffixes.
example : (derive normalCfg registry (common ++ [normalHeader 9])).anchorAt 8 = 18 := by decide +kernel
example : cutoff normalCfg common 11 = 18 := by decide +kernel
example : (build adapters normalCfg registry (common ++ [normalHeader 9]) 11).isSome = true := by decide +kernel
example : Consensus.activeAt (derive normalCfg registry (common ++ [normalHeader 9])) 11 =
    Consensus.activeAt (derive normalCfg laterRegistry (common ++ [normalHeader 9,normalHeader 10])) 11 :=
  active_committee_prefix (by decide +kernel) (by decide +kernel)

def contextA : Consensus.Context := derive cfg registry [h9]
def contextB : Consensus.Context := derive cfg laterRegistry [h9,h10]
def member : Committee.Entry := ⟨7,1,0,1000⟩

theorem activeA : (Consensus.activeAt contextA 11).members = [member] := by decide +kernel
theorem activeB : (Consensus.activeAt contextB 11).members = [member] := by decide +kernel

def signature (v : Consensus.Vote) : Prop := v.key = 7
instance : DecidablePred signature := fun _ => inferInstanceAs (Decidable (_ = _))
def vote (round value : Nat) : Consensus.Vote := ⟨domain,0,11,round,2,value,7⟩

theorem commitA : Consensus.CommitValid contextA signature 11 0 20 [vote 0 20] := by decide +kernel
theorem commitB : Consensus.CommitValid contextB signature 11 1 20 [vote 1 20] := by decide +kernel
theorem conflictCommit : Consensus.CommitValid contextA signature 11 0 30 [vote 0 30] := by decide +kernel

def world : RegistryMachine.World := ⟨registry,⟨domain,4,10,true,false,100⟩,100⟩
theorem refinement : SignatureRefinement registry signature := by
  intro v _
  exact ⟨v.key,by simp [registry,rawRegistry]⟩

-- Historical generation0 evidence remains usable in current generation4, per member.
example : Committee.totalPower contextA.unit (Consensus.activeAt contextA 11).members <
    3*Committee.totalPower contextA.unit (overlap contextA 11 [vote 0 20] [vote 0 30]) ∧
    ∀ e ∈ overlap contextA 11 [vote 0 20] [vote 0 30], ∃ va ∈ [vote 0 20], ∃ vb ∈ [vote 0 30],
      va.key = e.key ∧ vb.key = e.key ∧ ∃ sa sb,
      RegistryMachine.Evidence world.registry world.inbox e.key
        (Accountability.evidence va) (Accountability.evidence vb) sa sb ∧
      FutureLiability world e.key (Accountability.evidence va) (Accountability.evidence vb) sa sb :=
  same_round_accountability commitA conflictCommit (by decide) refinement rfl (by decide) rfl (by decide)

def future : RegistryMachine.World := ⟨registry,{world.inbox with generation := 5},101⟩
theorem future_trace : RegistryMachine.Trace world future :=
  .step (.refl world) (.frame registry world.inbox future.inbox 100 101 rfl (by decide)
    (fun h => h) (by decide) (by decide))
theorem authenticated_conflict : RegistryMachine.Evidence registry world.inbox 7
    (Accountability.evidence (vote 0 20)) (Accountability.evidence (vote 0 30)) 7 7 := by decide +kernel
example : ∃ next, RegistryMachine.execute future.registry future.inbox future.now
    (.slash 0 (Accountability.evidence (vote 0 20)) (Accountability.evidence (vote 0 30)) 7 7) = some next :=
  evidence_retained_id (original := bond) (current := bond) future_trace (by decide) rfl rfl authenticated_conflict rfl rfl (by decide) rfl (by decide)

-- Distinct raw history suffixes also compose with current same-round accountability.
theorem transported : Consensus.CommitValid contextB signature 11 0 30 [vote 0 30] :=
  commit_valid_transport (common := []) (moreA := [h9,h10]) (moreB := [h9])
    (by decide +kernel) (by decide +kernel) conflictCommit
example : Accountable world contextA 11 [vote 0 20] [vote 0 30] :=
  shared_prefix_accountability (common := []) (moreA := [h9]) (moreB := [h9,h10])
    (by decide +kernel) (by decide +kernel) commitA transported (by decide) refinement rfl (by decide) rfl (by decide)

-- Actual honest local actions acquire and retain the same lock across distinct rounds.
def execution : Locking.Execution where
  prevotes := fun key _ value => key = 7 ∧ value = some 20
  precommits := fun key _ value => key = 7 ∧ value = some 20
  actions := fun _ _ => {prevote := some (some 20),precommit := some (some 20)}
  locks := fun _ round => if round = 0 then none else some (round-1,20)
def honest (key : Hash) : Bool := key == 7

theorem polc (round : Nat) : Locking.PoLC 1 [member] execution round (some 20) := by
  refine ⟨[7],by unfold Locking.Quorum; decide +kernel,?_⟩
  intro k mem
  simp only [List.mem_singleton] at mem
  exact ⟨mem,rfl⟩

theorem honest_rules : Locking.HonestRules 1 [member] honest true execution := by
  constructor
  · intro key _; rfl
  · intro key _ round
    cases round with
    | zero =>
      simpa [Locking.RoundStep,Locking.UnlockAllowed,Locking.afterPrevote,Locking.VoteAllowed,execution] using polc 0
    | succ round =>
      simpa [Locking.RoundStep,Locking.UnlockAllowed,Locking.afterPrevote,Locking.VoteAllowed,execution] using polc (round+1)
  · intro key _ round value vote
    simp only [execution] at vote ⊢
    rw [vote.2]
  · intro key _ round value vote
    simp only [execution] at vote ⊢
    rw [vote.2]

example : (20 : Nat) = 20 := by
  have rules : Locking.HonestRules 1 (Consensus.activeAt contextA 11).members honest true execution := by
    rw [activeA]
    exact honest_rules
  have minority : Locking.Minority 1 (Consensus.activeAt contextA 11).members honest := by
    rw [activeA]
    unfold Locking.Minority
    decide +kernel
  have attrA : Locking.CommitAttribution execution 0 20 [vote 0 20] := by
    intro v mem; simp only [List.mem_singleton] at mem; subst v; exact ⟨rfl,rfl⟩
  have attrB : Locking.CommitAttribution execution 1 20 [vote 1 20] := by
    intro v mem; simp only [List.mem_singleton] at mem; subst v; exact ⟨rfl,rfl⟩
  exact shared_prefix_agreement (cfg := cfg) (registryA := registry) (registryB := laterRegistry)
    (common := []) (moreA := [h9]) (moreB := [h9,h10]) (h := 11)
    (by decide +kernel) (by decide +kernel) rules minority attrA attrB commitA commitB

-- Authenticated nil precommits cannot impersonate a nonnil certificate.
example : ¬ Locking.CommitAttribution { execution with precommits := fun _ _ v => v = none }
    0 20 [vote 0 20] := by
  intro h
  have bad := h (vote 0 20) (by simp)
  cases bad

end Etna.CurrentFinalityRegression

-- A terminal-height archive-completeness check covers all earlier decisions in its batch.
example (cfg : Config) (registry : RegistryMachine.State) (archive : List Blocks.Header)
    (a b : Nat) (order : a ≤ b) (ready : Ready cfg registry archive b) :
    Ready cfg registry archive a := ready_earlier order ready

-- Global agreement compares every overlapping decoded header, including unequal lengths.
example (xs ys : List Blocks.Header) (agreed : HeaderAgreement xs ys)
    (n : Nat) (a b : Blocks.Header) (ha : xs[n]? = some a) (hb : ys[n]? = some b) :
    a = b := agreement_get agreed ha hb

namespace Etna.CurrentFullChainRegression
open Etna.CurrentFinalityRegression
open Blocks
set_option maxRecDepth 30000
set_option maxHeartbeats 12000000

def decodedHeader (h hash : Nat) : Header :=
  ⟨h,100+h,200+h,hash,0,h+2,⟨h+1,h+1,h+1,8,108,0,0⟩,0⟩
def fixedInterpreter : Definition :=
  ⟨fun _ b => decide (b.header = decodedHeader b.header.height b.header.cometHash),
    fun _ _ _ => true,⟨fun _ => 0,fun _ => false,fun _ _ _ => .unavailable⟩⟩
def policy (archive : List Header) : GenerationPolicy where
  consensus := derive cfg registry archive
  startHeight := 8
  gridK := 1
  committeeConfig := 0
  maxAnchorAge := 10
  forcedDelay := 1
  unsettled := 10
  referenceNumber := 30
  referenceHash := 300
  committeeHash := fun _ => 1
  signature := signature
  anchorAuthenticated := fun _ => true
  committeeAuthenticated := fun _ _ => true
  forcedAuthenticated := fun _ _ => true
  scheduleAuthenticated := fun _ schedule => decide (schedule = ⟨1,1,0,0,0⟩)
  batchPayloadValid := fun _ _ => true
  configHash := fun _ => 0
  historyAuthenticated := fun _ _ => true
  catalogue := fun rule => if rule = 1 then some fixedInterpreter else none

def origin : Header := ⟨8,108,208,0,0,10,⟨500,500,500,8,108,9,0⟩,0⟩
def block (h hash round : Nat) : Block :=
  ⟨⟨decodedHeader h hash,99+h,(if h = 9 then none else some 20),domain,0,h+2,
    100,100,true,(if h = 9 then some ⟨⟨1,10,[member]⟩,10⟩ else none),1,1,h+1,round,
    [⟨domain,0,h,round,2,hash,7⟩],none,.unavailable⟩,⟨1,1,0,0,0⟩,[],none,[]⟩
def one : Block := block 9 20 0
def two : Block := block 10 21 1
def shorter : Block := block 9 20 2
def conflicting : Block := block 9 30 0
def longPolicy := policy [one.header,two.header]
def shortPolicy := policy [shorter.header]
def badPolicy := policy [conflicting.header]

instance (archive : List Header) : DecidablePred (policy archive).signature :=
  fun _ => inferInstanceAs (Decidable (signature _))
instance : DecidablePred longPolicy.signature := fun _ => inferInstanceAs (Decidable (signature _))
instance : DecidablePred shortPolicy.signature := fun _ => inferInstanceAs (Decidable (signature _))
instance : DecidablePred badPolicy.signature := fun _ => inferInstanceAs (Decidable (signature _))
instance (r : GenerationPolicy) (p : Header) (b : Block) : Decidable (HeaderValid r p b) :=
  inferInstanceAs (Decidable (_ ∧ _))
instance (r : GenerationPolicy) (p : Header) (b : Block) : Decidable (ParentAnchorValid r p b) := by
  unfold ParentAnchorValid; split <;> infer_instance
instance (r : GenerationPolicy) (b : Block) : Decidable (WitnessValid r b) := by
  unfold WitnessValid
  split
  · cases b.body.committeeWitness <;> dsimp <;> infer_instance
  · infer_instance

theorem long_first : Valid longPolicy origin one := by
  constructor
  all_goals first | decide +kernel | (constructor <;> decide +kernel) | (intro w carried; cases carried)
theorem long_second : Valid longPolicy one.header two := by
  constructor
  all_goals first | decide +kernel | (constructor <;> decide +kernel) | (intro w carried; cases carried)
theorem short_first : Valid shortPolicy origin shorter := by
  constructor
  all_goals first | decide +kernel | (constructor <;> decide +kernel) | (intro w carried; cases carried)
theorem bad_first : Valid badPolicy origin conflicting := by
  constructor
  all_goals first | decide +kernel | (constructor <;> decide +kernel) | (intro w carried; cases carried)

theorem checked_shape {archive : List Header} {p : Header} {b : Block}
    (ok : Valid (policy archive) p b) : b.header = decodedHeader b.header.height b.header.cometHash := by
  have known : selectedRules b = 1 := by
    have selected := ok.selected
    change (if selectedRules b = 1 then some fixedInterpreter else none) = some (definition (policy archive) b) at selected
    split at selected
    next selectedRule => exact selectedRule
    next => cases selected
  have executed := ok.execution
  simpa [definition,policy,known,fixedInterpreter,Block.header] using executed

theorem binding (archiveA archiveB : List Header) : CometHeaderBinding (policy archiveA) (policy archiveB) := by
  intro p a b validA validB hash
  have heights : a.header.height = b.header.height := validA.header.1.trans validB.header.1.symm
  calc
    a.header = decodedHeader a.header.height a.header.cometHash := checked_shape validA
    _ = decodedHeader b.header.height b.header.cometHash := by rw [heights,hash]
    _ = b.header := (checked_shape validB).symm

def lockedExecution (value : Nat) : Locking.Execution where
  prevotes := fun key _ v => key = 7 ∧ v = some value
  precommits := fun key _ v => key = 7 ∧ v = some value
  actions := fun _ _ => {prevote := some (some value),precommit := some (some value)}
  locks := fun _ round => if round = 0 then none else some (round-1,value)
def engine : Engine := ⟨fun _ h => lockedExecution (h+11),fun _ _ => honest,true⟩

theorem locked_polc (value round : Nat) : Locking.PoLC 1 [member] (lockedExecution value) round (some value) := by
  refine ⟨[7],by unfold Locking.Quorum; decide +kernel,?_⟩
  intro k mem
  simp only [List.mem_singleton] at mem
  exact ⟨mem,rfl⟩

theorem locked_honest (value : Nat) : Locking.HonestRules 1 [member] honest true (lockedExecution value) := by
  constructor
  · intro key _; rfl
  · intro key _ round
    cases round with
    | zero =>
      simpa [Locking.RoundStep,Locking.UnlockAllowed,Locking.afterPrevote,Locking.VoteAllowed,lockedExecution] using locked_polc value 0
    | succ round =>
      simpa [Locking.RoundStep,Locking.UnlockAllowed,Locking.afterPrevote,Locking.VoteAllowed,lockedExecution] using locked_polc value (round+1)
  · intro key _ round v vote
    simp only [lockedExecution] at vote ⊢
    rw [vote.2]
  · intro key _ round v vote
    simp only [lockedExecution] at vote ⊢
    rw [vote.2]

theorem honest_at (h : Nat) (members : (Consensus.activeAt longPolicy.consensus h).members = [member]) :
    HonestAt engine cfg longPolicy.consensus h := by
  change Locking.HonestRules 1 (Consensus.activeAt longPolicy.consensus h).members honest true (lockedExecution (h+11)) ∧
    Locking.Minority 1 (Consensus.activeAt longPolicy.consensus h).members honest
  rw [members]
  exact ⟨locked_honest _,by unfold Locking.Minority; decide +kernel⟩

theorem long_honesty : ChainHonesty engine cfg longPolicy origin [one,two] := by
  intro pair mem
  simp only [pairs,List.mem_cons,List.not_mem_nil,or_false] at mem
  rcases mem with rfl | rfl
  · exact honest_at 9 (by decide +kernel)
  · exact honest_at 10 (by decide +kernel)
theorem long_attribution : ChainAttribution engine cfg origin [one,two] := by
  intro pair mem
  simp only [pairs,List.mem_cons,List.not_mem_nil,or_false] at mem
  rcases mem with rfl | rfl
  all_goals intro v member; simp only [one,two,block,List.mem_singleton] at member; subst v; exact ⟨rfl,rfl⟩
theorem short_attribution : ChainAttribution engine cfg origin [shorter] := by
  intro pair mem
  simp only [pairs,List.mem_singleton] at mem
  subst pair
  intro v member
  simp only [shorter,block,List.mem_singleton] at member
  subst v
  exact ⟨rfl,rfl⟩

-- Own commit vote lists differ; they are not inputs to the claimed Comet-header binding.
example : one.body.votes ≠ shorter.body.votes := by decide +kernel
-- Two complete chains, each with its OWN archive-derived context, agree on their overlap.
example : HeaderAgreement ([one,two].map Block.header) ([shorter].map Block.header) :=
  full_chain_agreement rfl rfl rfl ⟨long_first,long_second,True.intro⟩ ⟨short_first,True.intro⟩
    (binding _ _) long_honesty long_attribution short_attribution

-- The conflicting nonempty candidate passes direct block checks, but honest attribution
-- would force 20=30 at its first header, so it cannot become an accepted honest commit chain.
example : ¬ChainAttribution engine cfg origin [conflicting] := by
  intro attributed
  have equal : one.header = conflicting.header := full_chain_header_at (as := [one,two]) (bs := [conflicting]) (policyA := longPolicy) (policyB := badPolicy) rfl rfl rfl
    ⟨long_first,long_second,True.intro⟩ ⟨bad_first,True.intro⟩ (binding _ _)
    long_honesty long_attribution attributed (n := 0) rfl rfl
  have bad : (20 : Nat) = 30 := congrArg BlockValidity.Header.cometHash equal
  cases bad

end Etna.CurrentFullChainRegression
