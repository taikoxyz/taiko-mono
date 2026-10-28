import EtnaWitnesses.Regressions.FourthBatch

/-! Kernel-checked regressions for the fourth review's model fixes: `Deployment.Genesis` now
requires committee 0 to be the genesis-cutoff election (target epoch 0, cutoff genesisCutoff,
a registry checkpoint at or before it), so Worlds that met every earlier conjunct but admit no
deployment construction are rejected; and the recovery `below` premise is derived along a
sound trace with a recovery and a certified landing before a second recovery. -/
namespace Etna.Design.FifthBatch

/-! Committee 0 must be the genesis election. -/

/-- ThirdBatch's deployed World with another committee-0 opening (and the matching schedule). -/
def withZero (z : Committee.Record) (registry : RegistryHistory.State) : ProtocolState.World :=
  { ThirdBatch.deployed with
    inbox := { ThirdBatch.deployedInbox with committeeZeroRecord := z },registry := registry,
    schedule := Committee.recoverySchedule z }

/-- The reviewed counterexample: opening ⟨7,3,[]⟩ over a registry with no checkpoint. -/
def stray : ProtocolState.World := withZero ⟨7,3,[]⟩ SecondBatch.emptyRegistry
/-- The elected members under a stale target epoch, or a cutoff other than genesisCutoff. -/
def staleTarget : ProtocolState.World := withZero { ThirdBatch.zeroRecord with targetEpoch := 7 } ThirdBatch.bigRegistry
def staleCutoff : ProtocolState.World := withZero { ThirdBatch.zeroRecord with cutoff := 11 } ThirdBatch.bigRegistry

/-- The counterexample satisfies the §10 constraints, a valid registry and both openings (every
conjunct `Genesis` had before), yet it is not an initialized World: committee 0 is not elected
and no checkpoint precedes genesisCutoff, so no configuration, archive or template builds. -/
theorem stray_committee_zero_rejected :
    Deployment.Constraints stray.inbox stray.inbox.configuration ∧
    ProtocolState.RegistryValid stray.registry stray.l1Block ∧ Deployment.RegistryConstraints stray.registry ∧
    stray.inbox.committeeConfig = stray.adapters.configHash (Deployment.words stray.inbox stray.inbox.configuration) ∧
    stray.inbox.committeeZero = stray.adapters.recordHash stray.inbox.committeeZeroRecord ∧
    ¬ Deployment.GenesisElected stray.inbox stray.registry stray.inbox.configuration ∧
    (RegistryHistory.latestSnapshot stray.registry.history stray.inbox.genesisCutoff).isNone = true ∧
    ¬ Deployment.Genesis stray 1000 10000 ∧
    ∀ cfg archive template, Deployment.build stray cfg archive template = none := by
  have empty : HistoricalContext.registryAt stray.registry stray.inbox.genesisCutoff = [] := by decide +kernel
  have unelected : ∀ cfg : Deployment.Config, ¬ Deployment.GenesisElected stray.inbox stray.registry cfg := by
    intro cfg elected
    unfold Deployment.GenesisElected at elected
    rw [empty] at elected
    simp [Committee.election,Committee.chosen] at elected
  refine ⟨by decide +kernel,⟨?_,?_,?_,?_,by decide +kernel⟩,by decide +kernel,by decide +kernel,rfl,
    unelected _,by decide +kernel,?_,?_⟩
  · unfold RegistryHistory.KeysValid
    decide +kernel
  · unfold RegistryHistory.IdentitiesValid
    decide +kernel
  · unfold RegistryHistory.Ordered
    decide +kernel
  · unfold RegistryHistory.CurrentSnapshot
    decide +kernel
  · intro init
    exact unelected _ init.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1
  · intro cfg archive template
    unfold Deployment.build
    apply ite_eq_right
    intro guard
    exact absurd guard.2.2.2.2.1 (unelected cfg)

/-- With the elected members, a stale target epoch or a cutoff other than genesisCutoff is not
the genesis record: neither World is initialized and neither builds a deployment context. -/
theorem stale_committee_zero_rejected :
    ¬ Deployment.Genesis staleTarget 1000 10000 ∧ ¬ Deployment.Genesis staleCutoff 1000 10000 ∧
    (∀ cfg archive template, Deployment.build staleTarget cfg archive template = none) ∧
    (∀ cfg archive template, Deployment.build staleCutoff cfg archive template = none) := by
  refine ⟨fun init => absurd init.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1 (by decide),
    fun init => absurd init.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1 (by decide),?_,?_⟩
  · intro cfg archive template
    unfold Deployment.build
    apply ite_eq_right
    intro guard
    have zero : (0:Nat) = 7 := congrArg Committee.Record.targetEpoch guard.2.2.2.1
    exact absurd zero (by decide)
  · intro cfg archive template
    unfold Deployment.build
    apply ite_eq_right
    intro guard
    have zero : (12:Nat) = 11 := congrArg Committee.Record.cutoff guard.2.2.2.1
    exact absurd zero (by decide)

/-- The strengthened `Genesis` still admits the deployed Worlds, and on them `genesis_builds`
yields the deployment construction from the stored configuration. -/
theorem deployed_genesis_builds :
    (Deployment.build ThirdBatch.deployed ThirdBatch.cfgD [14] SecondBatch.historicalRules).isSome = true ∧
    (Deployment.build FourthBatch.worldM FourthBatch.cfgM [14] SecondBatch.historicalRules).isSome = true := by
  obtain ⟨r,built⟩ := Deployment.genesis_builds FourthBatch.deployed_genesis [14] SecondBatch.historicalRules
    (by decide) (by decide)
  obtain ⟨m,builtM⟩ := Deployment.genesis_builds FourthBatch.multi_member_build.2 [14] SecondBatch.historicalRules
    (by decide) (by decide)
  exact ⟨by rw [show ThirdBatch.cfgD = ThirdBatch.deployed.inbox.configuration from rfl,built]; rfl,
    by rw [show FourthBatch.cfgM = FourthBatch.worldM.inbox.configuration from rfl,builtM]; rfl⟩

/-! The recovery premise along a non-trivial sound trace. -/

/-- Deployed genesis → recovery (framed: slot 284 untouched) → certified generation-1 landing
(snapshot 20 ≤ reference block 21). -/
theorem deployed_sound_trace : ProtocolState.SoundTrace ThirdBatch.deployed ThirdBatch.landedWorld1 :=
  .step (.step (.refl _) (.framed ThirdBatch.deployed_recovery_step (by decide +kernel)))
    (.landing (s := ThirdBatch.landed1) (i := ThirdBatch.statement1.input) (leaves := []) (e := ThirdBatch.env1)
      (by decide +kernel) (by decide +kernel) (by decide +kernel))

/-- A second recovery at the generation-1 checkpoint, with R = (1, 30, 30). -/
def request2 : Recovery.Request := ⟨1,1,[],[]⟩
def origin2 : Origin := ⟨1,30,30⟩
def recovered2 : ProtocolState.World :=
  (ProtocolState.recover ThirdBatch.landedWorld1 request2 origin2 true true).getD ThirdBatch.landedWorld1

theorem second_recover : ProtocolState.recover ThirdBatch.landedWorld1 request2 origin2 true true = some recovered2 := by
  have ok : (ProtocolState.recover ThirdBatch.landedWorld1 request2 origin2 true true).isSome = true := by
    decide +kernel
  unfold recovered2
  cases h : ProtocolState.recover ThirdBatch.landedWorld1 request2 origin2 true true with
  | none => rw [h] at ok; contradiction
  | some w => rfl

def archive2 : List Nat := [14,20]
def context2 : Consensus.Context :=
  HistoricalContext.derive recovered2.inbox recovered2.registry (Deployment.parameters recovered2.inbox ThirdBatch.cfgD)
    archive2

theorem generation_two_context :
    HistoricalContext.build recovered2.inbox recovered2.registry (Deployment.parameters recovered2.inbox ThirdBatch.cfgD)
      archive2 = some context2 := by
  have ready : HistoricalContext.Ready recovered2.inbox recovered2.registry
      (Deployment.parameters recovered2.inbox ThirdBatch.cfgD) archive2 := by decide +kernel
  unfold HistoricalContext.build
  rw [ite_eq_left ready]
  rfl

/-- The derived premise: along `deployed_sound_trace` slot 284 (20 after the generation-1
landing) stays below the L1 clock (22), hence below R = 30, and the generation-2 context
(floor 30) fits the recovered Inbox. -/
theorem recovery_after_sound_trace :
    ThirdBatch.landedWorld1.inbox.snapshot < ThirdBatch.landedWorld1.l1Block ∧
    ThirdBatch.landedWorld1.inbox.snapshot < origin2.l1Block ∧
    ThirdBatch.landedWorld1.inbox.snapshot ≤ recovered2.inbox.snapshot ∧
    Settlement.SnapshotFits context2 recovered2.inbox ∧ context2.generation = 2 ∧ Settlement.floor context2 = 30 := by
  have below := ProtocolState.sound_trace_snapshot_below deployed_sound_trace
    (Deployment.genesis_snapshot_below FourthBatch.deployed_genesis)
  have result := Deployment.genesis_snapshot_monotone_across_recovery FourthBatch.deployed_genesis
    deployed_sound_trace (by decide) second_recover generation_two_context (.refl _)
  exact ⟨below,result.1,result.2.1,result.2.2,by decide +kernel,by decide +kernel⟩

end Etna.Design.FifthBatch
