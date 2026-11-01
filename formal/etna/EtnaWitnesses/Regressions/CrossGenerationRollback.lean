import EtnaProofs.TrustedRollback
import EtnaWitnesses.Regressions.TrustState

/-! A certified source at height 1, exit, forged snapshot landing, confirmation, two
recoveries, rollback below the preserved origin, new recovery, valid snapshot-advancing
landing, reconfirmation and trust-revalidated production. All transitions use real guards.
No withdrawal or payout is reversed. Cryptographic/L1/EL adapters are decoded fixtures. -/
namespace Etna.Design.CrossGenerationRollbackRegression
open ProtocolState SigningEscrow SigningBridge

private theorem join_trace {a b c : World} (first : Trace a b) (second : Trace b c) : Trace a c := by
  induction second with
  | refl => exact first
  | step _ event ih => exact .step ih event

def sourceStatement : StatementData := Settlement.statement HistoricalEscrow.rules
  NonVacuity.genesisHeader [HistoricalEscrow.block 1] [111]
def sourceLeaves : List Leaf := gridLeaves 1 0 1
  (BlockValidity.cuts NonVacuity.genesisHeader [HistoricalEscrow.block 1])
def sourceEnv : LandingEnv := ⟨29,2800,true,[111],NonVacuity.proofs,sourceStatement⟩
def sourceWorld : World := landed HistoricalEscrow.worldB
  (applyLanding HistoricalEscrow.worldB.inbox sourceStatement.input) 29

/-- The source includes the real registration/exit plus a valid accepted batch with raw
header/archive and reference ancestry; no certified suffix is manufactured. -/
theorem certified_source : CanonicalHistory.Run NonVacuity.world0 sourceWorld HistoricalEscrow.archive := by
  have prior : CanonicalHistory.Run NonVacuity.world0 HistoricalEscrow.worldB [] :=
    .edit (.edit (.genesis NonVacuity.premises.genesis.1)
      (.registration (key := 8) (owner := 52) (amount := 1000000000000000000) (by decide) (by rfl)))
      (.modification (id := 0) (action := .requestExit 51) (by decide) rfl (by rfl))
  exact .landing (s := sourceWorld.inbox) (i := sourceStatement.input) (leaves := sourceLeaves)
    (e := sourceEnv) (r := HistoricalEscrow.rules) (parent := NonVacuity.genesisHeader)
    (blocks := [HistoricalEscrow.block 1]) (blobs := [111]) (more := HistoricalEscrow.archive)
    (template := HistoricalEscrow.fixture.template 28 2800) prior (by decide) (by decide +kernel)
    (NonVacuity.build_rulesFor (by decide +kernel) (by decide +kernel))
    ⟨by decide +kernel,rfl⟩ rfl (by decide +kernel) (by decide +kernel) (by decide +kernel)

def forgedStatement : StatementData :=
  { Settlement.statement HistoricalEscrow.rules (HistoricalEscrow.header 1) [HistoricalEscrow.block 2] [111] with
    input := { (Settlement.statement HistoricalEscrow.rules (HistoricalEscrow.header 1) [HistoricalEscrow.block 2] [111]).input with
      activeCommitteeSnapshot := 1000 } }
def forgedLeaves : List Leaf := gridLeaves 1 1 2
  (BlockValidity.cuts (HistoricalEscrow.header 1) [HistoricalEscrow.block 2])
def forgedEnv : LandingEnv := ⟨30,2800,true,[111],NonVacuity.proofs,forgedStatement⟩
def forgedWorld : World := landed sourceWorld (applyLanding sourceWorld.inbox forgedStatement.input) 30
def confirmedWorld : World := registered forgedWorld
  ((RegistryHistory.edit forgedWorld.registry forgedWorld.inbox 0 30 .confirm).getD forgedWorld.registry) 30

def request1 : Recovery.Request := ⟨0,2,[],[],0,limit256-1⟩
def origin1 : Origin := ⟨2,31,31⟩
def result1 : Recovery.World := Recovery.applyRecovery (recoveryView confirmedWorld) request1 confirmedWorld.adapters.recovery origin1
def recovered1 : World := recovered confirmedWorld request1 origin1 result1
def request2 : Recovery.Request := ⟨1,2,[],[],1,limit256-1⟩
def origin2 : Origin := ⟨2,32,32⟩
def result2 : Recovery.World := Recovery.applyRecovery (recoveryView recovered1) request2 recovered1.adapters.recovery origin2
def recovered2 : World := recovered recovered1 request2 origin2 result2
def restoredWorld : World := applyRollback recovered2 sourceWorld.inbox.checkpoint sourceWorld.inbox.snapshot 33

theorem adversarial_suffix : Trace sourceWorld recovered2 :=
  .step (.step (.step (.step (.refl _)
    (.landing (i := forgedStatement.input) (leaves := forgedLeaves) (e := forgedEnv) (by decide) (by decide +kernel)))
    (.modification (id := 0) (action := .confirm) (by decide) rfl (by rfl)))
    (.recovery (by decide) (Recovery.recover_of_allowed (by decide +kernel))))
    (.recovery (by decide) (Recovery.recover_of_allowed (by decide +kernel)))

theorem actual_rollback : Step recovered2 restoredWorld :=
  .rollback _ _ 33 (by decide) (by decide +kernel) (by decide +kernel)

def restoredContext : Consensus.Context := HistoricalContext.derive restoredWorld.inbox restoredWorld.registry
  (Deployment.parameters restoredWorld.inbox restoredWorld.inbox.configuration) HistoricalEscrow.archive

/-- A bad snapshot really confirmed key 7; the trusted rollback clears that confirmation,
retains both recovery origins and bumps the nonce. There is no origin record or valid target. -/
theorem rollback_rechecks_and_blocks :
    forgedWorld.inbox.snapshot = 1000 ∧ forgedStatement.input.l1ReferenceBlockNumber < forgedWorld.inbox.snapshot ∧
    (confirmedWorld.registry.slots 0).confirmedAt = some 30 ∧ restoredWorld.inbox.snapshot = 12 ∧
    restoredWorld.inbox.generation = 2 ∧ restoredWorld.inbox.origin.height = 2 ∧
    restoredWorld.inbox.checkpoint.height = 1 ∧ restoredWorld.inbox.recoveryNonce = 3 ∧
    (restoredWorld.registry.slots 0).confirmedAt = none ∧
    Staking.confirmExit restoredWorld.inbox (restoredWorld.registry.slots 0) 34 = none ∧
    SnapshotTrusted restoredContext restoredWorld ∧
    ¬ ∃ target : TrustState.Target, target.view = restoredWorld := by
  refine ⟨rfl,by decide,rfl,rfl,rfl,rfl,by decide +kernel,rfl,rfl,by decide +kernel,?_,?_⟩
  · exact (certified_values_trusted_across_recoveries certified_source (.step adversarial_suffix actual_rollback)
      (by decide) rfl rfl restoredWorld.inbox.configuration HistoricalEscrow.archive restoredContext
      (by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl)).1
  · exact rollback_has_no_target recovered2 sourceWorld.inbox.checkpoint sourceWorld.inbox.snapshot 33 (by decide +kernel)

/-- Quantifies over the whole interval, including further rollback and registry/FI edits. -/
theorem until_new_recovery {u : World} (trace : Trace restoredWorld u)
    (same : u.inbox.generation = 2) (i : LandInput) (leaves : List Leaf) (e : LandingEnv) :
    Etna.Design.land u.inbox i leaves e = none :=
  rollback_interval_rejects_landing (by decide +kernel) trace same i leaves e

def request3 : Recovery.Request := ⟨2,1,[],[],3,limit256-1⟩
def origin3 : Origin := ⟨1,40,40⟩
def result3 : Recovery.World := Recovery.applyRecovery (recoveryView restoredWorld) request3 restoredWorld.adapters.recovery origin3
def recovered3 : World := recovered restoredWorld request3 origin3 result3

def newFixture : Etna.Statements.Environment := { HistoricalEscrow.fixture with
  anchorAuthenticated := fun a => decide (a.number = 40 ∧ a.timestamp = 40 ∧ a.stateRoot = 50 ∧
    a.checkpointHeight = 1 ∧ a.checkpointHash = (HistoricalEscrow.header 1).elHash ∧ a.generation = 3 ∧ a.tail = 0) }
def newArchive : List Nat := [14,17,40]
def newRules : BlockValidity.Rules := NonVacuity.rulesFor newFixture recovered3 newArchive 41 4100
instance : DecidablePred newRules.signature := fun v => inferInstanceAs (Decidable (v.key = 7 ∨ v.key = 8))
def newAnchor : BlockValidity.Anchor := ⟨40,40,50,1,(HistoricalEscrow.header 1).elHash,3,0⟩
def newHeader : BlockValidity.Header := NonVacuity.hashed ⟨2,0,52,202,0,40,newAnchor⟩
def newBlock : BlockValidity.Block :=
  ⟨newHeader,(HistoricalEscrow.header 1).elHash,none,FirstBatch.deployment,3,40,100,100,true,none,12,12,50,0,
    [⟨FirstBatch.deployment,3,2,0,2,202,8⟩],none,.completedEmpty⟩
def newStatement : StatementData := Settlement.statement newRules (HistoricalEscrow.header 1) [newBlock] [111]
def newLeaves : List Leaf := gridLeaves 1 1 2 (BlockValidity.cuts (HistoricalEscrow.header 1) [newBlock])
def newEnv : LandingEnv := ⟨42,4100,true,[111],NonVacuity.proofs,newStatement⟩
def renewedWorld : World := landed recovered3 (applyLanding recovered3.inbox newStatement.input) 42
def reconfirmedWorld : World := registered renewedWorld
  ((RegistryHistory.edit renewedWorld.registry renewedWorld.inbox 0 42 .confirm).getD renewedWorld.registry) 42

theorem renewed_production :
    Recovery.recover (recoveryView restoredWorld) request3 restoredWorld.adapters.recovery origin3 true true = some result3 ∧
    recovered3.inbox.snapshot = 12 ∧
    Staking.confirmExit recovered3.inbox (recovered3.registry.slots 0) 40 = none ∧
    Settlement.BatchValid newRules (HistoricalEscrow.header 1) [newBlock] [111] ∧
    Etna.Design.land recovered3.inbox newStatement.input newLeaves newEnv = some renewedWorld.inbox ∧
    renewedWorld.inbox.snapshot = 40 ∧ (reconfirmedWorld.registry.slots 0).confirmedAt = some 42 := by
  exact ⟨Recovery.recover_of_allowed (by decide +kernel),rfl,by decide +kernel,
    ⟨by decide +kernel,rfl⟩,by decide +kernel,by decide +kernel,by rfl⟩

theorem renewed_trace : SnapshotTrace restoredWorld reconfirmedWorld :=
  .step (.step (.step (.refl _) (.recovery (by decide) renewed_production.1) (Or.inl (by decide +kernel)))
    (.landing (i := newStatement.input) (leaves := newLeaves) (e := newEnv) (by decide) renewed_production.2.2.2.2.1)
    (Or.inl (by decide +kernel)))
    (.modification (id := 0) (action := .confirm) (by decide) rfl (by rfl)) (Or.inl (by decide +kernel))

def finalContext : Consensus.Context := HistoricalContext.derive reconfirmedWorld.inbox reconfirmedWorld.registry
  (Deployment.parameters reconfirmedWorld.inbox reconfirmedWorld.inbox.configuration) newArchive

/-- The actual post-rollback confirmation is nonvacuous and excluded at every later height.
It occurs only after the valid new landing advances the snapshot from 12 to 40. -/
theorem reconfirmed_key_excluded (h : Nat) (above : reconfirmedWorld.inbox.checkpoint.height ≤ h) :
    ∀ member ∈ (Consensus.activeAt finalContext h).members, member.key ≠ 7 := by
  have prior : Trace NonVacuity.world0 restoredWorld :=
    .step (join_trace (CanonicalHistory.run_trace certified_source) adversarial_suffix) actual_rollback
  have full := join_trace prior (snapshot_trace_projects renewed_trace)
  exact confirmed_key_absent_above_checkpoint full (Deployment.genesis_core NonVacuity.premises.genesis.1)
    SigningBridgeRegression.initial_keys SigningBridgeRegression.initial_visible
    (cfg := Deployment.parameters reconfirmedWorld.inbox reconfirmedWorld.inbox.configuration)
    (archive := newArchive) (ctx := finalContext) (id := 0) (c := 42) (by decide) (by rfl)
    (trace_covered renewed_trace (rollback_covered _ _ _ _)) (by decide) (by decide)
    (by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl)
    (by unfold SnapshotTrusted; decide +kernel) above

/-- Restored state excludes the exited key even though the invalid confirmation has
been cleared. This uses its visible historical exit and the actual recovery cutoff. -/
theorem restored_key_excluded (h : Nat) :
    ∀ member ∈ (Consensus.activeAt restoredContext h).members, member.key ≠ 7 := by
  have prior := join_trace (CanonicalHistory.run_trace certified_source) (.step adversarial_suffix actual_rollback)
  have visible := trace_exit_visible prior (Deployment.genesis_core NonVacuity.premises.genesis.1)
    SigningBridgeRegression.initial_keys SigningBridgeRegression.initial_visible
    0 (by decide) (by decide) (by decide)
  have floor := Consensus.active_cutoff_monotone restoredContext (by decide +kernel)
    (fun _ _ order => HistoricalContext.derived_anchors_monotone _ _ _ _ order) (Nat.zero_le h)
  have cutoff : (restoredWorld.registry.slots 0).exitAt ≤ (Consensus.activeAt restoredContext h).cutoff := by
    change 32 ≤ (Consensus.activeAt restoredContext h).cutoff at floor
    change 17 ≤ _
    omega
  exact selected_excludes_confirmed_key (s := restoredWorld.inbox) (ctx := restoredContext)
    (cfg := Deployment.parameters restoredWorld.inbox restoredWorld.inbox.configuration)
    (archive := HistoricalEscrow.archive)
    (by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl) visible cutoff

/-- With no trusted landing, the real retained block-zero rollback uses initialization
values under the later generation, and the independent initialization theorem applies. -/
theorem initialization_restore :
    Step recovered2 (applyRollback recovered2 NonVacuity.world0.inbox.checkpoint NonVacuity.world0.inbox.snapshot 33) ∧
    SnapshotTrusted (HistoricalContext.derive
      (applyRollback recovered2 NonVacuity.world0.inbox.checkpoint NonVacuity.world0.inbox.snapshot 33).inbox
      (applyRollback recovered2 NonVacuity.world0.inbox.checkpoint NonVacuity.world0.inbox.snapshot 33).registry
      (Deployment.parameters recovered2.inbox recovered2.inbox.configuration) HistoricalEscrow.archive)
      (applyRollback recovered2 NonVacuity.world0.inbox.checkpoint NonVacuity.world0.inbox.snapshot 33) := by
  refine ⟨.rollback _ _ 33 (by decide) (by decide +kernel) (by decide +kernel),?_⟩
  exact initial_rollback_snapshot_trusted NonVacuity.premises.genesis.1
    (join_trace (CanonicalHistory.run_trace certified_source) adversarial_suffix)
    recovered2.inbox.configuration HistoricalEscrow.archive _
    (by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl)

def oldRules : BlockValidity.Rules := NonVacuity.rulesFor HistoricalEscrow.fixture recovered2 [14,17,18] 32 3200
def oldTarget : TrustState.Target where
  view := recovered2
  cfg := Deployment.parameters recovered2.inbox recovered2.inbox.configuration
  archive := [14,17,18]
  rules := oldRules
  fixedConfiguration := rfl
  constructed := by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl
  referenceFinalized := by decide +kernel
  generation := rfl
  origin := HistoricalEscrow.header 2
  originHeight := by decide +kernel
  originRecord := ⟨recovered2.inbox.checkpoint,by decide +kernel,by unfold headerMatches; decide +kernel⟩
  ownFinalized := fun a => a.number ≤ 32

def newTarget : TrustState.Target where
  view := reconfirmedWorld
  cfg := Deployment.parameters reconfirmedWorld.inbox reconfirmedWorld.inbox.configuration
  archive := newArchive
  rules := newRules
  fixedConfiguration := rfl
  constructed := by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl
  referenceFinalized := by decide +kernel
  generation := rfl
  origin := HistoricalEscrow.header 1
  originHeight := by decide +kernel
  originRecord := ⟨sourceWorld.inbox.checkpoint,by decide +kernel,by unfold headerMatches; decide +kernel⟩
  ownFinalized := fun a => a.number ≤ 42

private theorem activation_trace (s : TrustState.Node) (target : TrustState.Target) (blocks : List BlockValidity.Block)
    (running : s.halted = false)
    (valid : BlockValidity.Chain target.rules target.origin blocks) (accepted : TrustState.nodes target blocks)
    (matched : headerMatches target.view.inbox.checkpoint (BlockValidity.terminal target.origin blocks))
    (covered : (BlockValidity.terminal target.origin blocks).height < target.archive.length)
    (generation : target.view.inbox.generation = s.signer.activeGeneration)
    (deployment : target.view.inbox.domain = s.signer.domain)
    (known : s.authenticatedGeneration ≤ s.signer.activeGeneration) :
    TrustState.Trace 8 TrustStateRegression.bytes0 s (TrustStateRegression.activate s target blocks) := by
  refine .step (.step (.step (.step (.refl _) (.observeEvent s target running))
    (.progress blocks rfl rfl running rfl valid accepted))
    (.matched rfl running matched covered generation deployment
      (by simp only [TrustState.observe,TrustState.close,deployment,ite_true,generation]; omega))) (.open _ true)

private theorem join_node_trace {s t u : TrustState.Node}
    (first : TrustState.Trace 8 TrustStateRegression.bytes0 s t)
    (second : TrustState.Trace 8 TrustStateRegression.bytes0 t u) :
    TrustState.Trace 8 TrustStateRegression.bytes0 s u := by
  induction second with
  | refl => exact first
  | step _ event ih => exact .step ih event

def coldNode : TrustState.Node := TrustState.startup ⟨FirstBatch.deployment,0,1,[],false,[]⟩
def oldSession : TrustState.Node := TrustStateRegression.activate (TrustState.recover coldNode oldTarget true) oldTarget []
def oldMessage : SignMessage := ⟨FirstBatch.deployment,2,3,0,.precommitMsg,203⟩
def oldSigned : TrustState.Node := { oldSession with signer := { oldSession.signer with
  log := [⟨2,⟨3,0,3⟩,TrustStateRegression.bytes0 oldMessage,808⟩] } }
def rolledNode : TrustState.Node := TrustState.rollback oldSigned
def newSession : TrustState.Node := TrustStateRegression.activate
  (TrustState.recover rolledNode newTarget true) newTarget [newBlock]
def newMessage : SignMessage := ⟨FirstBatch.deployment,3,3,0,.precommitMsg,303⟩
def newSigned : TrustState.Node := { newSession with signer := { newSession.signer with
  log := ⟨3,⟨3,0,3⟩,TrustStateRegression.bytes0 newMessage,888⟩ :: newSession.signer.log } }

/-- Actual immutable-key/encoder session history signs before rollback, retains its HRS
and watermark while closed, then switches, replays, matches and signs in generation 3. -/
theorem trust_revalidated_sign :
    TrustState.Trace 8 TrustStateRegression.bytes0 coldNode newSigned ∧
    rolledNode.trusted = false ∧ rolledNode.target = none ∧
    rolledNode.signer.log = oldSigned.signer.log ∧ rolledNode.authenticatedGeneration = 2 ∧
    TrustState.sign rolledNode TrustStateRegression.bytes0 oldMessage 999 true = none ∧
    newSession.authenticatedGeneration = 3 ∧ 2 ∈ newSession.signer.retired ∧
    TrustState.sign newSession TrustStateRegression.bytes0 oldMessage 999 true = none ∧
    TrustState.sign newSession TrustStateRegression.bytes0 newMessage 888 true = some (newSigned.signer,888) ∧
    newSigned.signer.log.length = oldSigned.signer.log.length+1 := by
  refine ⟨?_,rfl,rfl,rfl,rfl,rfl,rfl,by decide +kernel,rfl,rfl,rfl⟩
  have first : TrustState.Trace 8 TrustStateRegression.bytes0 coldNode oldSession :=
    join_node_trace (.step (.refl _) (.recovery _ oldTarget true rfl))
      (activation_trace _ oldTarget [] rfl True.intro (by simp [TrustState.nodes,parentPairs])
        (by unfold headerMatches; decide +kernel) (by decide +kernel) rfl rfl (by decide +kernel))
  have signed : TrustState.Trace 8 TrustStateRegression.bytes0 coldNode oldSigned :=
    .step first (.signed oldMessage 808 808 true oldSigned.signer rfl (fun _ =>
      ⟨oldTarget,rfl,rfl,rfl,by decide +kernel,⟨8,1000000000000000000,17,Staking.noExit⟩,by decide +kernel,rfl⟩))
  have switched : TrustState.Trace 8 TrustStateRegression.bytes0 coldNode (TrustState.recover rolledNode newTarget true) :=
    .step (.step signed (.rollbackEvent _)) (.recovery _ newTarget true rfl)
  have ready := join_node_trace switched (activation_trace _ newTarget [newBlock] rfl
    (by unfold newTarget; decide +kernel) (by unfold TrustState.nodes BlockValidity.NodeValid newTarget; decide +kernel)
    (by unfold headerMatches; decide +kernel) (by decide +kernel) rfl rfl (by decide +kernel))
  exact .step ready (.signed newMessage 888 888 true newSigned.signer rfl (fun _ =>
    ⟨newTarget,rfl,rfl,rfl,by decide +kernel,⟨8,1000000000000000000,17,Staking.noExit⟩,by decide +kernel,rfl⟩))

/-- Rollback consumes the pending nonce even when generation and restored height match;
previous-generation authorizations and cached signatures never revive. -/
theorem rollback_nonce_and_domain :
    Recovery.recover (recoveryView restoredWorld) { request3 with nonce := 2 }
      restoredWorld.adapters.recovery origin3 true true = none ∧
    Recovery.recover (recoveryView recovered3) request3 recovered3.adapters.recovery origin3 true true = none ∧
    restoredWorld.inbox.domain = sourceWorld.inbox.domain ∧
    restoredWorld.inbox.origins = recovered2.inbox.origins ∧
    newSigned.signer.domain = oldSigned.signer.domain ∧
    (reconfirmedWorld.registry.slots 0).balance = (sourceWorld.registry.slots 0).balance := by
  exact ⟨by decide +kernel,by decide +kernel,rfl,rfl,rfl,rfl⟩

def futureArchive : List Nat := List.replicate 13 1000
def futureRules : BlockValidity.Rules := NonVacuity.rulesFor HistoricalEscrow.fixture HistoricalEscrow.worldB futureArchive 28 2800
def futureStatement : StatementData := Settlement.statement futureRules NonVacuity.genesisHeader HistoricalEscrow.blocks [111]
def futureEnv : LandingEnv := ⟨29,2800,true,[111],NonVacuity.proofs,futureStatement⟩

/-- Construction and certificate equality alone allow a snapshot above the reference and
landing block. The new result's raw canonical ancestry cannot be replaced with the weaker
same-generation theorem premises. No validity or authenticated ancestry is claimed here. -/
theorem weak_source_lacks_reference_bound :
    Deployment.build HistoricalEscrow.worldB HistoricalEscrow.worldB.inbox.configuration futureArchive
      (HistoricalEscrow.fixture.template 28 2800) = some futureRules ∧
    futureEnv.certificate = Settlement.statement futureRules NonVacuity.genesisHeader HistoricalEscrow.blocks [111] ∧
    Etna.Design.land HistoricalEscrow.worldB.inbox futureStatement.input HistoricalEscrow.leaves futureEnv =
      some (applyLanding HistoricalEscrow.worldB.inbox futureStatement.input) ∧
    futureStatement.input.l1ReferenceBlockNumber < futureStatement.input.activeCommitteeSnapshot ∧
    futureEnv.blockNumber < futureStatement.input.activeCommitteeSnapshot := by
  exact ⟨NonVacuity.build_rulesFor (by decide +kernel) (by decide +kernel),rfl,
    by decide +kernel,by decide +kernel,by decide +kernel⟩

end Etna.Design.CrossGenerationRollbackRegression
