import EtnaProofs.CurrentStakeRisk

namespace Etna.CurrentStakeRiskRegression
open Etna.Design Etna.Design.Current RegistryMachine StakeRisk
set_option maxRecDepth 30000
set_option maxHeartbeats 12000000

def domain : Domain := ⟨1,2,3,4⟩
def beforeView : InboxView := ⟨domain,0,0,false,false,0⟩
def closedView : InboxView := ⟨domain,0,1,true,false,2⟩
def fresh : RegistryMachine.State where
  ledger := ⟨0,fun _ => none,fun _ => none,fun _ => none,1,1⟩
  config := {withdrawalDelay := 3}
  verify := fun key _ sig => key == sig
  registerAuth := fun _ _ _ _ => true
def registered := (execute fresh beforeView 0 (.register 7 71 100 7)).getD fresh
def entry : Committee.Entry := ⟨7,100,1,Staking.noExit⟩
def first : RegistryMachine.World := ⟨fresh,beforeView,0⟩
def closed : RegistryMachine.World := ⟨registered,closedView,2⟩
theorem genesis : Genesis fresh := ⟨rfl,fun _ => rfl,fun _ => rfl,fun _ => rfl,rfl,rfl⟩
theorem closedRun : NormalTrace first closed :=
  .frame (.call (.refl first) (.register 7 71 100 7) True.intro rfl)
    rfl (by decide) (by intro impossible; cases impossible) (by decide) (by decide) (by decide)

-- Eligibility and actual landed snapshot order derive both statuses from Genesis.
example : ∃ id, Retained registered 1 id 7 :=
  selected_unconfirmed closedRun genesis (by decide) (entry := entry)
    (by decide +kernel) (by decide) (by decide)

def vote (value : Nat) : Staking.Vote := ⟨domain,0,1,0,2,value⟩
def slashAction : Action := .slash 0 (vote 11) (vote 12) 7 7
def slashed := (execute registered closedView 2 slashAction).getD registered
theorem slashedRun : NormalTrace first ⟨slashed,closedView,2⟩ :=
  .call closedRun slashAction True.intro rfl

-- The result covers punishment without claiming that original power remains funded
-- after a valid slash: the principal is exhausted but withdrawal has not occurred.
example : ∃ id, Retained slashed 1 id 7 :=
  selected_unconfirmed slashedRun genesis (by decide) (entry := entry)
    (by decide +kernel) (by decide) (by decide)
example : (slashed.ledger.bonds 0).map (fun b => b.value.balance) = some 0 := by decide +kernel
example : (slashed.ledger.bonds 0).map (fun b => b.value.released) = some false := by decide +kernel

def forfeited := (execute registered closedView 2 (.forfeit 0 1 7 123 3)).getD registered
theorem forfeitedRun : NormalTrace first ⟨forfeited,closedView,2⟩ :=
  .call closedRun (.forfeit 0 1 7 123 3) True.intro rfl
example : ∃ id, Retained forfeited 1 id 7 :=
  selected_unconfirmed forfeitedRun genesis (by decide) (entry := entry)
    (by decide +kernel) (by decide) (by decide)
example : (execute forfeited closedView 2 (.confirm 0)).isNone = true := by decide +kernel

-- Internal recovery exclusion authenticates its actual block. Earlier caller-supplied
-- cutoff replacement and exceptional confirmation recheck are excluded from normality.
example : ¬ NormalAction 2 (.exclude 2 1 [(0,7)]) := by change ¬ 1 = 2; decide
example : ¬ NormalAction 2 (.recheck 2 1) := by intro impossible; exact impossible
example : ¬ (3 ≤ 1) := by decide

end Etna.CurrentStakeRiskRegression
