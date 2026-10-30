import EtnaProofs.SigningEscrow
import EtnaWitnesses.NonVacuity.Premises

/-! Historical cryptographic validity survives ordinary exit/withdrawal, with a genuine
rotation and accepted decoded block chain. No recovery or rollback is used. The explicit
external authentication/EL adapters are fixture boundaries, not byte-level implementations. -/
namespace Etna.Design.HistoricalEscrow
open Etna.Statements NonVacuity

/-- A standby registers after genesis selection and is active before rotation. -/
def standby : RegistryHistory.State :=
  (RegistryHistory.register world0.registry 8 52 1000000000000000000 15).getD world0.registry
def worldA : ProtocolState.World := ProtocolState.registered world0 standby 15
def requested : RegistryHistory.State :=
  (RegistryHistory.edit worldA.registry worldA.inbox 0 16 (.requestExit 51)).getD worldA.registry
def worldB : ProtocolState.World := ProtocolState.registered worldA requested 16

/-- The chain crosses H(1)=11. D(1)=8 has anchor 24; key 7 exits at 17. -/
def archive : List Nat := 14 :: (List.range 12).map (fun i => 17+i)
def fixture : Environment := { relations with
  signature := fun v => v.key = 7 ∨ v.key = 8,
  anchorAuthenticated := fun a => decide (a.number = a.timestamp ∧ a.stateRoot = a.number+10 ∧
    a.checkpointHeight = 0 ∧ a.checkpointHash = genesisHeader.elHash ∧ a.generation = 0 ∧ a.tail = 0) }
def rules : BlockValidity.Rules := rulesFor fixture worldB archive 28 2800
instance : DecidablePred rules.signature := fun v => inferInstanceAs (Decidable (v.key = 7 ∨ v.key = 8))

def anchor (h : Nat) : BlockValidity.Anchor := ⟨16+h,16+h,26+h,0,genesisHeader.elHash,0,0⟩
def header (h : Nat) : BlockValidity.Header :=
  if h = 0 then genesisHeader else hashed ⟨h,0,50+h,100+h,0,16+h,anchor h⟩
def block (h : Nat) : BlockValidity.Block :=
  ⟨header h,(header (h-1)).elHash,(if h=1 then none else some (99+h)),FirstBatch.deployment,0,16+h,
    100,100,true,
    (if (h+1)%10=0 then some ⟨Consensus.normal rules.consensus ((h+1)/10),(anchor h).stateRoot⟩ else none),
    12,12,(anchor h).stateRoot,0,
    [⟨FirstBatch.deployment,0,h,0,2,100+h,(if h≤10 then 7 else 8)⟩],none,.completedEmpty⟩
def blocks : List BlockValidity.Block := (List.range 12).map (fun i => block (i+1))
def statement : StatementData := Settlement.statement rules genesisHeader blocks [111]
def leaves : List Leaf := gridLeaves 1 0 12 (BlockValidity.cuts genesisHeader blocks)
def landingEnv : LandingEnv := ⟨29,2800,true,[111],proofs,statement⟩
def worldC : ProtocolState.World := ProtocolState.landed worldB (applyLanding worldB.inbox statement.input) 29
def confirmed : RegistryHistory.State :=
  (RegistryHistory.edit worldC.registry worldC.inbox 0 29 .confirm).getD worldC.registry
def worldD : ProtocolState.World := ProtocolState.registered worldC confirmed 29
def withdrawn : RegistryHistory.State :=
  (RegistryHistory.edit worldD.registry worldD.inbox 0 30 (.withdraw 51)).getD worldD.registry
def worldE : ProtocolState.World := ProtocolState.registered worldD withdrawn 30

/-- Rebuild a historical validation context using the same decoded chain archive. -/
def historicalRules : BlockValidity.Rules := rulesFor fixture worldE archive 30 3000
instance : DecidablePred historicalRules.signature := fun v => inferInstanceAs (Decidable (v.key = 7 ∨ v.key = 8))

theorem ordinary_rotation_chain : BlockValidity.Chain rules genesisHeader blocks := by
  decide +kernel

theorem ordinary_exit_trace : ProtocolState.Trace world0 worldE :=
  .step (.step (.step (.step (.step (.refl _)
    (.registration (key := 8) (owner := 52) (amount := 1000000000000000000) (by decide) (by rfl)))
    (.modification (id := 0) (action := .requestExit 51) (by decide) rfl (by rfl)))
    (.landing (i := statement.input) (leaves := leaves) (e := landingEnv) (by decide) (by decide +kernel)))
    (.modification (id := 0) (action := .confirm) (by decide) rfl (by rfl)))
    (.modification (id := 0) (action := .withdraw 51) (by decide) rfl (by rfl))

/-- This real accepted chain supplies the additional snapshot discipline; no arbitrary
archive is used to claim that every accepted landing has it. -/
theorem snapshot_exit_trace : SigningEscrow.SnapshotTrace world0 worldE :=
  .step (.step (.step (.step (.step (.refl _)
    (.registration (key := 8) (owner := 52) (amount := 1000000000000000000) (by decide) (by rfl))
    (Or.inl (by decide +kernel)))
    (.modification (id := 0) (action := .requestExit 51) (by decide) rfl (by rfl))
    (Or.inl (by decide +kernel)))
    (.landing (i := statement.input) (leaves := leaves) (e := landingEnv) (by decide) (by decide +kernel))
    (Or.inl (by decide +kernel)))
    (.modification (id := 0) (action := .confirm) (by decide) rfl (by rfl))
    (Or.inl (by decide +kernel)))
    (.modification (id := 0) (action := .withdraw 51) (by decide) rfl (by rfl))
    (Or.inl (by decide +kernel))

private theorem initial_unconfirmed (id : Nat) : (world0.registry.slots id).confirmedAt = none := by
  change (if id = 0 then (⟨7,51,1000000000000000000,12,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
    else RegistryHistory.vacant).confirmedAt = none
  split <;> rfl

/-- The general temporal theorems apply to the accepted run. -/
theorem trajectory_invariants : SigningEscrow.Clocked worldE ∧ SigningEscrow.Covered worldE := by
  constructor
  · apply SigningEscrow.trace_clocked ordinary_exit_trace
    intro id c present
    rw [initial_unconfirmed] at present
    contradiction
  · apply SigningEscrow.trace_covered snapshot_exit_trace
    intro id c present
    rw [initial_unconfirmed] at present
    contradiction

/-- Actual ordinary rotation excludes key 7 before confirmation. The entire delay starts
at confirmation (29), not its earlier effective exit (17); no rollback/recovery occurs. -/
theorem ordinary_exit_and_historical_validity :
    ProtocolState.Trace world0 worldE ∧ BlockValidity.Chain rules genesisHeader blocks ∧
    worldC.inbox.checkpoint.height = 12 ∧ worldC.inbox.snapshot = 24 ∧
    (Consensus.activeAt rules.consensus 11).members.map Committee.Entry.key = [8] ∧
    (worldD.registry.slots 0).exitAt = 17 ∧ (worldD.registry.slots 0).confirmedAt = some 29 ∧
    Staking.withdraw worldD.inbox (worldD.registry.slots 0) 51 29 worldD.registry.withdrawalDelay = none ∧
    Staking.withdraw worldD.inbox (worldD.registry.slots 0) 51 30 worldD.registry.withdrawalDelay =
      some (RegistryHistory.vacant,1000000000000000000) ∧
    (worldE.registry.slots 0).balance = 0 ∧ (worldE.registry.slots 0).released = true ∧
    Built fixture worldE historicalRules ∧
    Consensus.CommitValid historicalRules.consensus historicalRules.signature 1 0 101 [vote 0 1 101] ∧
    ¬ Consensus.CommitValid historicalRules.consensus historicalRules.signature 13 0 113 [vote 0 13 113] := by
  refine ⟨ordinary_exit_trace,ordinary_rotation_chain,by decide +kernel,by decide +kernel,by decide +kernel,
    by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,
    ?_,by decide +kernel,by decide +kernel⟩
  exact ⟨archive,30,3000,build_rulesFor (by decide +kernel) (by decide +kernel)⟩

end Etna.Design.HistoricalEscrow
