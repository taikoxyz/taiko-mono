import EtnaProofs.SlashedExclusion
import EtnaWitnesses.Regressions.SigningEscrow

/-! §12 item 19's window on a real slash. In the Byzantine-minority deployment, key 9 is
slashed in L1 block 15. The committee active at height 1 was selected at cutoff 12, before the
slash, and still contains key 9 (`current_voting_power_survives_full_slash`). A fee sweep in L1
block 16 moves the World on. The first ordinary rotation whose snapshot is at or after the slash
(height 11, cutoff 16, from an anchor history that reaches L1 block 16 at height 8), in the
context built on that later World, excludes it: every hypothesis of
`slashed_key_absent_from_later_committees` holds and the theorem gives the exclusion. -/
namespace Etna.Design.SlashedExclusionRegression
open SigningEscrow NonVacuity SigningEscrowRegression

/-- An anchor history whose block at height 8 (D(1) for L = 10) anchors L1 block 16. -/
def laterArchive : List Nat := [14,14,14,14,14,14,14,14,16]

/-- L1 block 16: anyone sweeps the protocol fees. -/
def laterWorld : ProtocolState.World :=
  ProtocolState.landed afterBurn ((Forced.sweep afterBurn.inbox true).getD afterBurn.inbox) 16

def laterParameters : HistoricalContext.Parameters :=
  Deployment.parameters laterWorld.inbox laterWorld.inbox.configuration

def laterContext : Consensus.Context :=
  HistoricalContext.derive laterWorld.inbox laterWorld.registry laterParameters laterArchive

private theorem old_entries : HistoricalContext.registryAt afterBurn.registry 12 = minorityMembers := by
  decide +kernel

private theorem chosen : Committee.chosen 1000000000 1000000000000000000 12 3 minorityMembers = minorityMembers := by
  unfold Committee.chosen
  rw [show minorityMembers.filter (Committee.eligible 1000000000 1000000000000000000 12) = minorityMembers by decide +kernel,
    List.mergeSort_of_pairwise (l := minorityMembers) (le := Committee.rank) (by decide +kernel),
    show minorityMembers.take 3 = minorityMembers from rfl,
    List.mergeSort_of_pairwise (l := minorityMembers) (le := fun a b => decide (a.key ≤ b.key)) (by decide +kernel)]

private theorem elected : Committee.election 1000000000 1000000000000000000 12 3 minorityMembers = some minorityMembers := by
  unfold Committee.election
  rw [chosen]
  decide +kernel

private theorem later_built :
    HistoricalContext.build laterWorld.inbox laterWorld.registry laterParameters laterArchive = some laterContext := by
  unfold HistoricalContext.build
  refine ite_eq_left ⟨by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,?_,
    by decide,by decide⟩
  change (Committee.election 1000000000 1000000000000000000 12 3
    (HistoricalContext.registryAt afterBurn.registry 12)).isSome = true
  rw [old_entries,elected]
  rfl

private theorem minority_keys : KeysWellFormed minorityWorld.registry := by
  have count : minorityWorld.registry.nextId = 3 := by decide +kernel
  have used : ∀ id, id < 3 → (minorityWorld.registry.slots id).key ∈ minorityWorld.registry.usedKeys := by
    decide +kernel
  have distinct : ∀ i, i < 3 → ∀ j, j < 3 →
      (minorityWorld.registry.slots i).key = (minorityWorld.registry.slots j).key → i = j := by
    decide +kernel
  constructor
  · intro id range _
    exact used id (count ▸ range)
  · intro key _ i ir j jr ki kj
    exact distinct i (count ▸ ir) j (count ▸ jr) (ki.trans kj.symm)

private theorem minority_visible : ExitVisible minorityWorld.registry := by
  have count : minorityWorld.registry.nextId = 3 := by decide +kernel
  have open_ : ∀ id, id < 3 → (minorityWorld.registry.slots id).exitAt = Staking.noExit := by decide +kernel
  intro id range _ finite
  exact absurd (open_ id (count ▸ range)) finite

/-- Key 9's slash in L1 block 15 satisfies every hypothesis of
`slashed_key_absent_from_later_committees`. Before the slash's snapshot (height 1, cutoff 12)
key 9 still has power; at height 11 (cutoff 16) it is gone. -/
theorem slashed_member_leaves_next_committee :
    member9 ∈ (Consensus.activeAt rules.consensus 1).members ∧ (Consensus.activeAt rules.consensus 1).cutoff = 12 ∧
    ProtocolState.Step afterBurn laterWorld ∧
    HistoricalContext.build laterWorld.inbox laterWorld.registry laterParameters laterArchive = some laterContext ∧
    (Consensus.activeAt laterContext 11).cutoff = 16 ∧ (burned.slots 2).balance = 0 ∧
    ∀ m ∈ (Consensus.activeAt laterContext 11).members, m.key ≠ 9 := by
  have slashed : RegistryHistory.edit minorityWorld.registry minorityWorld.inbox 2 15
      (.slash evidenceA evidenceB 0 0) = some burned := by rfl
  have sweep : ProtocolState.Step afterBurn laterWorld := .sweep (now := 16) (transfer := true) (by decide) rfl
  have excluded := slashed_key_absent_from_later_committees (h := 11) (.refl _)
    (Deployment.genesis_core minority_premises.genesis.1) minority_keys minority_visible (by decide)
    (by decide) slashed (by decide +kernel) (.step (.refl _) sweep) later_built (by decide +kernel)
  have key : (minorityWorld.registry.slots 2).key = 9 := by decide +kernel
  rw [key] at excluded
  exact ⟨current_voting_power_survives_full_slash.2.2.2.2.2.2.2.2.1,by decide +kernel,sweep,later_built,
    by decide +kernel,excluded.1,excluded.2⟩

end Etna.Design.SlashedExclusionRegression
