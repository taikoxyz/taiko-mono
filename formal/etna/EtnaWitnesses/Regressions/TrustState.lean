import EtnaProofs.TrustState
import EtnaWitnesses.Regressions.CanonicalHistory
import EtnaWitnesses.Counterexamples.SigningViewLag

/-! Real decoded fixtures execute authentication, replay, match, opening and stock
signing. The target input carries no replay validity or trust/source grant. -/
namespace Etna.Design.TrustStateRegression
open TrustState SigningBridge

abbrev DeviceTrace := TrustState.Trace 8 SigningBridgeRegression.messageCode
abbrev DeviceStep := TrustState.Step 8 SigningBridgeRegression.messageCode
abbrev DeviceReachable := TrustState.Reachable 8 SigningBridgeRegression.messageCode

private def targetOfPrefix {view : ProtocolState.World} (p : TrustedPrefix view)
    (generation : p.rules.consensus.generation = view.inbox.generation) : Target where
  view := view
  cfg := p.cfg
  archive := p.archive
  rules := p.rules
  fixedConfiguration := p.fixedConfiguration
  constructed := p.constructed
  referenceFinalized := p.referenceFinalized
  generation := generation
  origin := p.origin
  originHeight := p.originHeight
  originRecord := p.originRecord
  ownFinalized := p.ownFinalized

def target0 : Target := targetOfPrefix SigningBridgeRegression.trustedPrefix rfl
def target1 : Target := targetOfPrefix CanonicalHistoryRegression.signingPrefix rfl

/-- Four actual events: authenticate, replay, exact match, and activate the guarded
connection. A restarted session cannot skip the first event. -/
def activate (s : TrustState.Node) (target : Target) (blocks : List BlockValidity.Block) : TrustState.Node :=
  let replayed := { observe s target with replay := blocks }
  let matched := { replayed with trusted := true }
  { matched with signer := (Signer.openSession matched.signer matched.signer.activeGeneration
    (canOpen matched) true) }

private theorem trace_append {s t u : TrustState.Node}
    (a : DeviceTrace s t) (b : DeviceTrace t u) : DeviceTrace s u := by
  induction b with
  | refl => exact a
  | step _ event ih => exact .step ih event

private theorem activate_trace {key : Hash} {encode : SignMessage → Hash} (s : TrustState.Node) (target : Target) (blocks : List BlockValidity.Block)
    (running : s.halted = false)
    (valid : BlockValidity.Chain target.rules target.origin blocks) (accepted : nodes target blocks)
    (matched : headerMatches target.view.inbox.checkpoint (BlockValidity.terminal target.origin blocks))
    (covered : (BlockValidity.terminal target.origin blocks).height < target.archive.length)
    (generation : target.view.inbox.generation = s.signer.activeGeneration)
    (deployment : target.view.inbox.domain = s.signer.domain)
    (notSuperseded : s.authenticatedGeneration ≤ s.signer.activeGeneration) :
    TrustState.Trace key encode s (activate s target blocks) := by
  refine .step (.step (.step (.step (.refl _) (.observeEvent s target running))
    (.progress blocks rfl rfl running rfl valid accepted))
    (.matched rfl running matched covered generation deployment
      (by simp only [observe,close,deployment,ite_true,generation]; omega))) (.open _ true)

def cold : TrustState.Node := startup SigningBridgeRegression.device.state
def session0 : TrustState.Node := activate cold target0 HistoricalEscrow.blocks

private theorem replay0 : nodes target0 HistoricalEscrow.blocks := by
  simpa [nodes,target0,targetOfPrefix,SigningBridgeRegression.trustedPrefix] using
    SigningBridgeRegression.trustedPrefix.nodeAccepted

/-- Cold startup, unavailable material, midway replay and final exact match are separate
steps. A six-block midway prefix remains untrusted before the remaining six arrive. -/
theorem partial_replay_waits :
    ∃ midway : TrustState.Node,
      DeviceTrace cold midway ∧ midway.trusted = false ∧ midway.replay.length = 6 ∧
      TrustState.sign midway SigningBridgeRegression.messageCode
        (SigningBridgeRegression.message .precommitMsg true) 9 true = none := by
  let loaded := observe cold target0
  let midway := { loaded with replay := HistoricalEscrow.blocks.take 6 }
  refine ⟨midway,?_,rfl,by decide +kernel,untrusted_cannot_sign _ _ _ _ _ rfl⟩
  exact .step (.step (.step (.refl _) (.missing cold)) (.observeEvent _ target0 rfl))
    (.progress (HistoricalEscrow.blocks.take 6) rfl rfl rfl rfl
      (by unfold target0 targetOfPrefix SigningBridgeRegression.trustedPrefix; decide +kernel)
      (by unfold nodes BlockValidity.NodeValid target0 targetOfPrefix SigningBridgeRegression.trustedPrefix; decide +kernel))

theorem session0_reachable : DeviceReachable session0 :=
  ⟨SigningBridgeRegression.device.state,
    activate_trace cold target0 HistoricalEscrow.blocks rfl SigningBridgeRegression.trustedPrefix.replayValid replay0
      (by unfold headerMatches; decide +kernel) (by decide +kernel) rfl rfl (by decide +kernel)⟩

def message0 := SigningBridgeRegression.message
def bytes0 := SigningBridgeRegression.messageCode

def signed0 (phase : SignPhase) (nil : Bool) : TrustState.Node :=
  { session0 with signer := { session0.signer with log :=
    [⟨0,⟨13,0,phaseStep phase⟩,bytes0 (message0 phase nil),bytes0 (message0 phase nil)+8⟩] } }

private theorem engine0 (phase : SignPhase) (nil : Bool) :
    TrustState.EngineRequest session0 8 (message0 phase nil) := by
  refine ⟨target0,rfl,rfl,rfl,by change 13 = 13; rfl,?_⟩
  exact (SigningBridgeRegression.engine_request phase nil).2.2.2

/-- All three phases and nil/non-nil choices traverse actual Signer.sign and append a
new persisted entry. The producer must be a member at the replayed next height. -/
theorem all_phases_sign (phase : SignPhase) (nil : Bool) :
    DeviceStep session0 (signed0 phase nil) ∧
    TrustState.sign session0 bytes0 (message0 phase nil) (bytes0 (message0 phase nil)+8) true =
      some ((signed0 phase nil).signer,bytes0 (message0 phase nil)+8) ∧
    (signed0 phase nil).signer.log ≠ session0.signer.log := by
  refine ⟨.signed (message0 phase nil) _ _ true _ rfl (fun _ => engine0 phase nil),rfl,?_⟩
  simp [signed0,session0,activate,observe,close,cold,startup,Signer.openSession,SigningBridgeRegression.device]

def retrySession (phase : SignPhase) (nil : Bool) : TrustState.Node :=
  activate (restart (timeout (signed0 phase nil))) target0 HistoricalEscrow.blocks

/-- Timeout blocks even cached replies. Automatic restart discards authentication and
replays/matches before reopening; WAL's identical retry returns the original signature
without another durable write and without a fresh membership/height obligation. -/
theorem timeout_restart_retry (phase : SignPhase) (nil : Bool) :
    DeviceTrace session0 (retrySession phase nil) ∧
    TrustState.sign (timeout (signed0 phase nil)) bytes0 (message0 phase nil) 999 false = none ∧
    (restart (timeout (signed0 phase nil))).target = none ∧
    TrustState.sign (retrySession phase nil) bytes0 (message0 phase nil) 999 false =
      some ((retrySession phase nil).signer,bytes0 (message0 phase nil)+8) ∧
    DeviceStep (retrySession phase nil) (retrySession phase nil) ∧
    (retrySession phase nil).signer.log = (signed0 phase nil).signer.log := by
  have cached : TrustState.sign (retrySession phase nil) bytes0 (message0 phase nil) 999 false =
      some ((retrySession phase nil).signer,bytes0 (message0 phase nil)+8) :=
    cached_retry _ _ _ ⟨0,⟨13,0,phaseStep phase⟩,bytes0 (message0 phase nil),bytes0 (message0 phase nil)+8⟩
      999 false rfl rfl rfl rfl
  refine ⟨?_,rfl,rfl,cached,?_,rfl⟩
  · have first : DeviceTrace session0 (restart (timeout (signed0 phase nil))) :=
      .step (.step (.step (.refl _) (all_phases_sign phase nil).1) (.timeoutEvent _)) (.restartEvent _ rfl)
    have again := activate_trace (key := 8) (encode := bytes0) (restart (timeout (signed0 phase nil))) target0 HistoricalEscrow.blocks
      rfl SigningBridgeRegression.trustedPrefix.replayValid replay0 (by unfold headerMatches; decide +kernel) (by decide +kernel) rfl rfl (by exact Nat.le_refl 0)
    exact trace_append first again
  · exact .signed (message0 phase nil) 999 _ false _ cached (fun changed => False.elim (changed rfl))

/-- A retained non-nil block in a later round is a new HRS and uses the same trust and
membership discipline. Nil and non-nil are never special trust bypasses. -/
theorem retained_next_round :
    ∃ after : TrustState.Node,
      DeviceStep (signed0 .precommitMsg false) after ∧
      after.signer.log.length = 2 ∧
      TrustState.sign (close (signed0 .precommitMsg false)) bytes0
        { message0 .precommitMsg false with round := 1 } 999 true = none := by
  let m := { message0 .precommitMsg false with round := 1 }
  let after := { signed0 .precommitMsg false with signer :=
    { (signed0 .precommitMsg false).signer with log :=
      ⟨0,⟨13,1,3⟩,bytes0 m,999⟩ :: (signed0 .precommitMsg false).signer.log } }
  refine ⟨after,.signed m 999 999 true after.signer rfl ?_,rfl,rfl⟩
  intro _
  exact ⟨target0,rfl,rfl,rfl,by decide +kernel,(SigningBridgeRegression.engine_request .precommitMsg false).2.2.2⟩

/-- The replay adapter authenticates both eras' actual anchor formats and all lifetime
keys present in this fixture, so cold replay can include the early committee. -/
def advancedRules : BlockValidity.Rules := { NormalSigningRegression.rules0 with
  signature := fun v => v.key = 7 ∨ v.key = 8 ∨ v.key = 9
  anchorAuthenticated := fun a => HistoricalEscrow.fixture.anchorAuthenticated a ||
    NormalSigningRegression.fixture.anchorAuthenticated a }
instance : DecidablePred advancedRules.signature := fun v =>
  inferInstanceAs (Decidable (v.key = 7 ∨ v.key = 8 ∨ v.key = 9))

/-- The same-generation target really advances from checkpoint 12 to 14. -/
def advancedTarget : Target where
  view := NormalSigningRegression.landedWorld
  cfg := Deployment.parameters NormalSigningRegression.landedWorld.inbox NormalSigningRegression.landedWorld.inbox.configuration
  archive := NormalSigningRegression.archive0
  rules := advancedRules
  fixedConfiguration := rfl
  constructed := by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl
  referenceFinalized := by decide +kernel
  generation := rfl
  origin := NonVacuity.genesisHeader
  originHeight := rfl
  originRecord := ⟨NonVacuity.world0.inbox.checkpoint,by decide +kernel,by unfold headerMatches; decide +kernel⟩
  ownFinalized := fun a => a.number ≤ 34

def advancedSession : TrustState.Node := activate (signed0 .precommitMsg false) advancedTarget
  (HistoricalEscrow.blocks ++ NormalSigningRegression.blocks0)

theorem target_advancement_revalidates :
    DeviceTrace (signed0 .precommitMsg false) advancedSession ∧
    (observe (signed0 .precommitMsg false) advancedTarget).trusted = false ∧
    target0.view.inbox.checkpoint.height = 12 ∧ advancedTarget.view.inbox.checkpoint.height = 14 ∧
    advancedSession.trusted = true ∧ advancedSession.signer.log = (signed0 .precommitMsg false).signer.log := by
  refine ⟨activate_trace _ _ _ rfl
    (by unfold advancedTarget; decide +kernel)
    (by unfold nodes BlockValidity.NodeValid advancedTarget; decide +kernel)
    (by unfold headerMatches; decide +kernel) (by decide +kernel) rfl rfl (by decide +kernel),rfl,by decide +kernel,
    by decide +kernel,rfl,rfl⟩

def recoveredSession : TrustState.Node :=
  activate (recover advancedSession target1 true) target1 NormalSigningRegression.blocks1

/-- Actual switchDomain retires generation 0, retains every logged byte and starts the
new generation at origin+1. Trust needs a new full replay to checkpoint 22. -/
theorem recovery_revalidates :
    DeviceTrace advancedSession recoveredSession ∧
    (recover advancedSession target1 true).trusted = false ∧
    recoveredSession.signer.activeGeneration = 1 ∧ 0 ∈ recoveredSession.signer.retired ∧
    recoveredSession.signer.log = advancedSession.signer.log ∧
    TrustState.sign recoveredSession bytes0 (message0 .precommitMsg false) 999 true = none := by
  refine ⟨?_,rfl,rfl,by decide +kernel,rfl,rfl⟩
  have first : DeviceTrace advancedSession (recover advancedSession target1 true) :=
    .step (.refl _) (.recovery _ target1 true rfl)
  have again := activate_trace (key := 8) (encode := bytes0) (recover advancedSession target1 true) target1 NormalSigningRegression.blocks1
    rfl NormalSigningRegression.recovered_chain
    (by unfold nodes BlockValidity.NodeValid target1 targetOfPrefix CanonicalHistoryRegression.signingPrefix; decide +kernel) (by unfold headerMatches; decide +kernel) (by decide +kernel) rfl rfl (by decide +kernel)
  exact trace_append first again

/-- The post-recovery source is supplied by the general canonical-history constructor,
which derives SnapshotSource from the actual Task 1 recovery/landing history. -/
theorem canonical_provenance {s : TrustState.Node} (run : DeviceReachable s)
    (ready : s.trusted = true) (selected : s.target = some target1)
    (replay : s.replay = NormalSigningRegression.blocks1) (extension : s.extension = []) :
    ∃ p : TrustedPrefix CanonicalHistoryRegression.finish,
      p.origin = target1.origin ∧ p.replay = s.replay ∧ p.extension = s.extension ∧ p.rules = target1.rules := by
  apply canonical_trusted_prefix run ready selected CanonicalHistoryRegression.complete_history
    (more := []) (by simp [target1,targetOfPrefix,CanonicalHistoryRegression.signingPrefix])
    (NonVacuity.build_rulesFor (by decide +kernel) (by decide +kernel))
  rw [replay,extension]
  decide +kernel

def rolledView : ProtocolState.World := ProtocolState.applyRollback CanonicalHistoryRegression.finish
  NormalSigningRegression.view.inbox.checkpoint NormalSigningRegression.view.inbox.snapshot 50

def rolledTarget : Target where
  view := rolledView
  cfg := Deployment.parameters rolledView.inbox rolledView.inbox.configuration
  archive := NormalSigningRegression.archive1
  rules := NormalSigningRegression.rules1
  fixedConfiguration := rfl
  constructed := by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl
  referenceFinalized := by decide +kernel
  generation := rfl
  origin := NormalSigningRegression.header0 14
  originHeight := rfl
  originRecord := ⟨NormalSigningRegression.view.inbox.checkpoint,by decide +kernel,by unfold headerMatches; decide +kernel⟩
  ownFinalized := fun a => a.number ≤ 50

/-- An actual protocol rollback to the generation's original checkpoint revokes the
session. Reauthentication and exact origin matching restore trust, retaining all HRS. -/
theorem rollback_revalidates :
    ProtocolState.Step CanonicalHistoryRegression.finish rolledView ∧
    DeviceTrace recoveredSession (activate (rollback recoveredSession) rolledTarget []) ∧
    (rollback recoveredSession).trusted = false ∧ (rollback recoveredSession).target = none ∧
    (activate (rollback recoveredSession) rolledTarget []).trusted = true ∧
    (activate (rollback recoveredSession) rolledTarget []).signer.log = recoveredSession.signer.log := by
  refine ⟨.rollback _ _ 50 (by decide +kernel) (by decide +kernel) (by decide +kernel),?_,rfl,rfl,rfl,rfl⟩
  have again := activate_trace (key := 8) (encode := bytes0) (rollback recoveredSession) rolledTarget [] rfl True.intro
    (by simp [nodes,parentPairs]) (by unfold headerMatches; decide +kernel) (by decide +kernel) rfl rfl (by decide +kernel)
  have first : DeviceTrace recoveredSession (rollback recoveredSession) := .step (.refl _) (.rollbackEvent _)
  exact trace_append first again

/-- The cache is historical: after target advancement, a logged height-13 precommit
is returned although current fresh requests must be at height 15. -/
theorem historical_cache_has_no_new_engine_veto :
    DeviceStep advancedSession advancedSession ∧
    TrustState.sign advancedSession bytes0 (message0 .precommitMsg false) 999 false =
      some (advancedSession.signer,bytes0 (message0 .precommitMsg false)+8) ∧
    ¬ TrustState.EngineRequest advancedSession 8 (message0 .precommitMsg false) := by
  have cached : TrustState.sign advancedSession bytes0 (message0 .precommitMsg false) 999 false =
      some (advancedSession.signer,bytes0 (message0 .precommitMsg false)+8) :=
    cached_retry _ _ _ ⟨0,⟨13,0,3⟩,bytes0 (message0 .precommitMsg false),bytes0 (message0 .precommitMsg false)+8⟩
      999 false rfl rfl rfl rfl
  refine ⟨.signed _ 999 _ false _ cached (fun changed => False.elim (changed rfl)),cached,?_⟩
  rintro ⟨target,selected,_,_,height,_⟩
  have eq : target = advancedTarget := Option.some.inj selected.symm
  subst target
  change 13 = 15 at height
  omega

/-- All message phases also sign in the recovered domain after replay; the durable old
entries are retained alongside the newly persisted generation-1 entry. -/
theorem recovered_phases_sign (phase : SignPhase) (nil : Bool) :
    ∃ after : Signer.State,
      TrustState.sign recoveredSession bytes0 (NormalSigningRegression.message phase nil) 888 true = some (after,888) ∧
      after.log = ⟨1,⟨23,0,phaseStep phase⟩,bytes0 (NormalSigningRegression.message phase nil),888⟩ ::
        recoveredSession.signer.log := ⟨_,rfl,rfl⟩

def lagRules : BlockValidity.Rules := NonVacuity.rulesFor HistoricalEscrow.fixture
  SigningViewLag.view HistoricalEscrow.archive 26 2600
instance : DecidablePred lagRules.signature := fun v => inferInstanceAs (Decidable (v.key = 7 ∨ v.key = 8))

def lagTarget : Target where
  view := SigningViewLag.view
  cfg := Deployment.parameters SigningViewLag.view.inbox SigningViewLag.view.inbox.configuration
  archive := HistoricalEscrow.archive
  rules := lagRules
  fixedConfiguration := rfl
  constructed := by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl
  referenceFinalized := by decide +kernel
  generation := rfl
  origin := NonVacuity.genesisHeader
  originHeight := rfl
  originRecord := ⟨NonVacuity.world0.inbox.checkpoint,by decide +kernel,by unfold headerMatches; decide +kernel⟩
  ownFinalized := fun a => a.number ≤ 26

def lagSession : TrustState.Node :=
  { activate (startup SigningViewLag.closed) lagTarget [] with extension := SigningViewLag.localPrefix }
def lagMessage : SignMessage := ⟨FirstBatch.deployment,0,10,1,.precommitMsg,0⟩

/-- Own-finalized authentication is not global freshness. This real trust machine can
still freshly sign a higher-round nil vote from an old view after the global withdrawal.
The live extension is validated under NodeValid; no cached return explains the event. -/
theorem stale_own_view_still_signs :
    TrustState.Reachable 7 bytes0 lagSession ∧ TrustState.EngineRequest lagSession 7 lagMessage ∧
    (SigningViewLag.current.registry.slots 0).released = true ∧
    lagTarget.view.l1Block < SigningViewLag.current.l1Block ∧
    ∃ after : Signer.State, TrustState.sign lagSession bytes0 lagMessage 777 true = some (after,777) ∧
      after.log.length = lagSession.signer.log.length+1 := by
  refine ⟨?_,?_,by decide +kernel,by decide +kernel,_,rfl,rfl⟩
  · refine ⟨SigningViewLag.closed,.step (activate_trace _ lagTarget [] rfl True.intro
      (by simp [nodes,parentPairs]) (by unfold headerMatches; decide +kernel) (by decide +kernel) rfl rfl (by decide +kernel)) ?_⟩
    exact .extend SigningViewLag.localPrefix rfl rfl rfl
      (by unfold lagTarget; decide +kernel)
      (by unfold nodes BlockValidity.NodeValid lagTarget; decide +kernel)
  · refine ⟨lagTarget,rfl,rfl,rfl,by decide +kernel,⟨7,1000000000000000000,12,Staking.noExit⟩,?_,rfl⟩
    decide +kernel

/-- The still-selected key 8 cannot be supplied as a substitute for excluded physical
key 7: the fixed-key transition has no fresh append from this session. -/
theorem excluded_device_cannot_append {after : TrustState.Node}
    (event : TrustState.Step 7 bytes0 session0 after) : after.signer.log = session0.signer.log := by
  by_cases same : after.signer.log = session0.signer.log
  · exact same
  have fresh := same
  exfalso
  obtain ⟨m,_,_,_,_,target,selected,_,_,height,e,member,key⟩ := fresh_transition_uses_device event fresh
  have eq : target = target0 := Option.some.inj selected.symm
  subst target
  have h : m.height = 13 := height
  rw [h] at member
  have only : ∀ e ∈ (Consensus.activeAt target0.rules.consensus 13).members, e.key ≠ 7 := by decide +kernel
  exact only e member key

def foreignDomain : Domain := { FirstBatch.deployment with inbox := FirstBatch.deployment.inbox+1 }
def foreignMessage : SignMessage := { message0 .precommitMsg false with domain := foreignDomain }
def foreignInitial : Signer.State :=
  ⟨foreignDomain,0,1,[],false,[⟨0,⟨13,0,3⟩,bytes0 foreignMessage,888⟩]⟩
def foreignCandidate : TrustState.Node := activate (startup foreignInitial) target0 HistoricalEscrow.blocks

/-- I1 regression: other-deployment material cannot produce a reachable trust grant or
open the cache of a signer with fixed key/encoder and an already persisted signature. -/
theorem foreign_deployment_cache_rejected :
    foreignCandidate.signer.domain ≠ target0.view.inbox.domain ∧
    ¬ DeviceReachable foreignCandidate ∧
    TrustState.sign foreignCandidate bytes0 foreignMessage 999 false = none := by
  refine ⟨by decide +kernel,?_,foreign_session_cannot_sign _ target0 rfl (by decide +kernel) true _ _ _ _⟩
  intro run
  obtain ⟨target,selected,deployment,_⟩ := trusted_session_binding run rfl
  have equal : target = target0 := Option.some.inj selected.symm
  subst target
  exact (show target0.view.inbox.domain ≠ foreignCandidate.signer.domain by decide +kernel) deployment

def supersededNode : TrustState.Node := observe session0 target1
def obsoleteCandidate : TrustState.Node := activate supersededNode target0 HistoricalEscrow.blocks

/-- I2 regression: authenticating generation 1 and then rereading generation 0 never
restores a reachable old-generation grant, nor does the actual session-open/sign path. -/
theorem observed_supersession_rejects_old_material :
    DeviceTrace session0 supersededNode ∧ supersededNode.authenticatedGeneration = 1 ∧
    ¬ DeviceReachable obsoleteCandidate ∧
    TrustState.sign obsoleteCandidate bytes0 (message0 .precommitMsg false) 999 true = none := by
  refine ⟨.step (.refl _) (.observeEvent _ target1 rfl),rfl,?_,rfl⟩
  intro run
  obtain ⟨_,_,_,fence⟩ := trusted_session_binding run rfl
  change 1 ≤ 0 at fence
  omega

/-- The failure flag concerns domain installation; authenticated generation knowledge
is an independent ideal durable fact retained through timeout, restart and rollback. -/
def failedRecovery : TrustState.Node := recover (signed0 .precommitMsg false) target1 false
def afterSupersessionLifecycle : TrustState.Node := rollback (restart (timeout failedRecovery))
def afterStaleRead : TrustState.Node := observe afterSupersessionLifecycle target0

theorem supersession_survives_failed_recovery_and_restart :
    DeviceTrace (signed0 .precommitMsg false) afterStaleRead ∧
    afterStaleRead.signer.activeGeneration = 0 ∧ afterStaleRead.authenticatedGeneration = 1 ∧
    afterStaleRead.signer.log = (signed0 .precommitMsg false).signer.log ∧
    TrustState.sign (activate afterStaleRead target0 HistoricalEscrow.blocks)
      bytes0 (message0 .precommitMsg false) 999 false = none := by
  refine ⟨?_,rfl,rfl,rfl,rfl⟩
  exact .step (.step (.step (.step (.step (.refl _)
    (.recovery _ target1 false rfl)) (.timeoutEvent _)) (.restartEvent _ rfl))
    (.rollbackEvent _)) (.observeEvent _ target0 rfl)

/-- The irreversible refusal is about already authenticated knowledge: a valid trace
with arbitrary later observations and lifecycle events still refuses every older phase. -/
theorem all_later_old_generation_requests_rejected {later : TrustState.Node}
    (trace : DeviceTrace supersededNode later) (phase : SignPhase) (nil : Bool) :
    TrustState.sign later bytes0 (message0 phase nil) 999 true = none :=
  authenticated_supersession_persists session0_reachable target1 rfl rfl trace
    bytes0 (message0 phase nil) 999 true (by change 0 < 1; decide)

end Etna.Design.TrustStateRegression
