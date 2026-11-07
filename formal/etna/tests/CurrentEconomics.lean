import EtnaProofs.CurrentCheckpointRisk

open Etna.Design Etna.Design.Current

-- Replacing a same-block checkpoint cannot change any already closed cutoff.
example (first later : RegistryMachine.World) (run : RegistryMachine.Trace first later)
    (cutoff : Nat) (closed : cutoff < first.now) :
    later.registry.history.filter (fun cp => decide (cp.block ≤ cutoff)) =
      first.registry.history.filter (fun cp => decide (cp.block ≤ cutoff)) :=
  RegistryMachine.trace_closed_history run closed

example (env : Protocol.Environment) (registry : RegistryMachine.State) (w : Protocol.World)
    (run : Protocol.Trace env (Protocol.empty env registry) w) (zero : w.inbox.generation = 0) :
    Protocol.parametersOf w.inbox = env.parameters :=
  Economics.generation_zero_parameters run zero

namespace Etna.EconomicsRegression
open Etna.Design Etna.Design.Current Protocol ProtocolFinality
set_option maxRecDepth 30000
set_option maxHeartbeats 12000000

def domain : Domain := ⟨1,2,30,40⟩
def oldBond : Registry.Bond := ⟨⟨7,70,100,0,1000,false,none,0,0⟩,none⟩
def replacement : Registry.Bond := ⟨⟨8,80,101,0,1000,false,none,0,0⟩,some 0⟩
def oldRegistry : RegistryMachine.State where
  ledger := {
    nextId := 2
    bonds := fun id => if id = 0 then some oldBond else if id = 1 then some replacement else none
    slots := fun slot => if slot = 0 then some 1 else none
    keyId := fun key => if key = 7 then some 0 else if key = 8 then some 1 else none }
  config := {inbox := 30,owner := 1}
  verify := fun key _ signature => key == signature
  registerAuth := fun _ _ _ _ => true

def baseEnv : Environment where
  core := ⟨domain,1,2,0,0,90⟩
  parameters := ⟨1,10,0,⟨Committee.minUnit,Committee.minUnit,1,10⟩,1,1152,10,1,1,99⟩
  genesisHeader := ⟨0,100,200,0,0,0,⟨0,0,0,0,0,0,0⟩,0⟩
  initialSigner := ⟨domain,0,1,[],false,[]⟩
  time := id
  stateRoot := fun s => s.number+100
  blockHash := fun _ n => n
  headerHash := fun h => h.elHash
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun v => v.key = 7
  txHash := fun raw => raw.length
  unzenNextProposal := 0
  timestampOf := fun _ => 0
  catalogue := fun _ => none
  payload := fun _ _ => true
  verify := fun _ _ _ _ _ => true
  imageRules := fun _ => [1]
  unzenValid := fun _ _ _ => false
  unzenRoot := fun _ => False
  startImplementation := fun _ => true
  importValid := fun _ _ _ => false
  signBytes := fun _ => 0
  token := RegistryPayments.standardEnvironment 40 90
  initialToken := ⟨fun account => if account = 40 then 1000 else if account = 71 then 500 else 0,
    fun owner spender => if owner = 71 ∧ spender = 40 then 500 else 0⟩


def registry : RegistryMachine.State := {oldRegistry with
  ledger := {oldRegistry.ledger with nextId := 0, bonds := fun _ => none, slots := fun _ => none, keyId := fun _ => none},
  verify := fun key _ sig => key == 7 && sig == 7,
  config := {oldRegistry.config with withdrawalDelay := 3}, history := []}
def env : Environment := {baseEnv with
  parameters := {baseEnv.parameters with genesisCutoff := 1}
  evidenceWindow := 1
  initialToken := ⟨fun a => if a = 71 then 2*Committee.minUnit else 0,
    fun owner spender => if owner = 71 ∧ spender = 40 then 2*Committee.minUnit else 0⟩}
def initial := Protocol.empty env registry
def registered := Protocol.transact env initial (.registry 71 (.register 7 71 Committee.minUnit 7))
def advanced := Protocol.transact env registered (.advance 2)
def started := Protocol.transact env advanced (.initializeInbox 1)

theorem genesis : RegistryMachine.Genesis registry := by
  refine ⟨rfl,fun _ => rfl,fun _ => rfl,fun _ => rfl,rfl,rfl⟩
theorem run : Protocol.Trace env initial started :=
  .step (.step (.step (.refl initial) (.call initial (.registry 71 (.register 7 71 Committee.minUnit 7))))
    (.call registered (.advance 2))) (.call advanced (.initializeInbox 1))
theorem protocolNormalRun : CheckpointRisk.NormalRun env initial started :=
  .call (.call (.call (.refl initial) (.registry 71 (.register 7 71 Committee.minUnit 7)) True.intro (by decide +kernel))
    (.advance 2) True.intro (by decide +kernel)) (.initializeInbox 1) True.intro (by decide +kernel)
theorem protocolRollbackFreeRun : CheckpointRisk.RollbackFreeRun env initial started :=
  .call (.call (.call (.refl initial) (.registry 71 (.register 7 71 Committee.minUnit 7)) True.intro)
    (.advance 2) True.intro) (.initializeInbox 1) True.intro
theorem normalRun : StakeRisk.NormalTrace (Protocol.registryWorld env initial) (Protocol.registryWorld env started) :=
  protocolNormalRun.registry
example : CheckpointRisk.CurrentSource env initial started := protocolNormalRun.source (by decide +kernel)
example : env.evidenceWindow ≤ started.registry.registry.config.withdrawalDelay :=
  CheckpointRisk.evidence_window_of_deployment (by decide +kernel) run
example : started.initialized = true := by decide +kernel
example : started.registry.token.balances 40 = Committee.minUnit := by decide +kernel
example : Economics.reserve started.registry.registry.ledger = Committee.minUnit := by decide +kernel
example : RegistryPayments.Backed env.token started.registry :=
  Economics.funds_backed genesis rfl (by decide) (by decide) run
example : RegistryMachine.HistoryIssued started.registry.registry := (Economics.history_issued genesis run).2
example : Economics.ClosedRegistryHistory started := Economics.closed_registry_history run
example : Economics.HistoricalStakeFunded env started :=
  Economics.historical_stake_funded genesis rfl (by decide) (by decide) run

def vote (value : Nat) : Consensus.Vote := ⟨domain,0,1,0,2,value,7⟩
instance : DecidablePred env.signature := fun _ => inferInstanceAs (Decidable (_ = _))
theorem voteA : Consensus.CommitValid (policy env started [] 1).consensus env.signature 1 0 11 [vote 11] := by decide +kernel
theorem voteB : Consensus.CommitValid (policy env started [] 1).consensus env.signature 1 0 12 [vote 12] := by decide +kernel
theorem refinement : Finality.SignatureRefinement registry env.signature := by
  intro v signed
  change v.key = 7 at signed
  refine ⟨7,?_⟩
  simpa only [registry,Bool.and_eq_true,beq_iff_eq,and_true] using signed
theorem signatureSound : Finality.SignatureSound registry env.signature := by
  intro key vote sig verified
  have valid : key = 7 ∧ sig = 7 := by simpa only [registry,Bool.and_eq_true,beq_iff_eq] using verified
  exact valid.1
example : Economics.Safety env started :=
  Economics.economic_safety genesis rfl (by decide) (by decide) run signatureSound
example : Economics.EconomicallyAccountable env started (policy env started [] 1).consensus 1 [vote 11] [vote 12] :=
  Economics.economically_accountable (env := env) genesis rfl (by decide) (by decide) run refinement (by decide)
    (common := []) (moreA := []) (moreB := []) (by decide) voteA voteB (by decide)
example : StakeRisk.AccountableAtRisk env started (policy env started [] 1).consensus 1 [vote 11] [vote 12] :=
  StakeRisk.economically_at_risk (env := env) genesis rfl (by decide) (by decide) run normalRun refinement
    (by decide) (by decide) (common := []) (moreA := []) (moreB := [])
    (by decide) (by decide) voteA voteB (by decide)

def evA : Staking.Vote := Accountability.evidence (vote 11)
def evB : Staking.Vote := Accountability.evidence (vote 12)
def slashed := Protocol.transact env started (.registry 77 (.slash 0 evA evB 7 7))
example : (Protocol.registryCall env started 77 (.slash 0 evA evB 7 7)).isSome = true := by decide +kernel
example : slashed.registry.token.balances 40 = 0 := by decide +kernel
example : RegistryMachine.reserve slashed.registry.registry.ledger = 0 := by decide +kernel
example : (slashed.registry.registry.ledger.bonds 0).map (fun b => b.value.released) = some false := by decide +kernel
example : RegistryPayments.Backed env.token slashed.registry :=
  Economics.funds_backed genesis rfl (by decide) (by decide)
    (.step run (.call started (.registry 77 (.slash 0 evA evB 7 7))))
example : ∃ bond, 0 < started.registry.registry.ledger.nextId ∧
    started.registry.registry.ledger.bonds 0 = some bond ∧
    env.signature (Finality.signedVote bond.value.key evA) ∧
    env.signature (Finality.signedVote bond.value.key evB) ∧
    Staking.doubleSign started.inbox.domain started.inbox.generation evA evB = true :=
  Economics.no_false_slash run signatureSound (caller := 77) (id := 0) (sa := 7) (sb := 7)
    (next := slashed) rfl

def depositedBond : Registry.Bond := ⟨⟨7,71,Committee.minUnit,1,Staking.noExit,false,none,0,0⟩,some 0⟩
theorem retainedWindow : Economics.RetainedWindowLiability env started 0 7 evA evB 7 7 := by
  exact Economics.retained_window_liability (env := env) genesis rfl (by decide) (by decide) run (by decide)
    (bond := depositedBond) (by decide) (by decide +kernel) rfl rfl (by decide) (by decide +kernel)

-- No released/positive hypotheses are supplied for a future use. A valid prior slash
-- exhausts the principal, and the retained id is still unreleased during the window.
example : ∃ current, 0 < slashed.registry.registry.ledger.nextId ∧
    slashed.registry.registry.ledger.bonds 0 = some current ∧
    current.value.key = 7 ∧ current.value.released = false ∧
    (current.value.balance = 0 ∨ ∀ caller, slashed.inbox.entered = false →
      ∃ next, Protocol.registryCall env slashed caller (.slash 0 evA evB 7 7) = some next ∧
        next.receipts = slashed.receipts ++ ProtocolFinality.slashReceipts env slashed caller current) :=
  retainedWindow slashed (.step (.refl started) (.call started (.registry 77 (.slash 0 evA evB 7 7))))
    (by decide +kernel)

example : RegistryMachine.EvidenceClock slashed.registry.registry 0 started.number :=
  Economics.evidence_window_retained (.step (.refl started) (.call started (.registry 77 (.slash 0 evA evB 7 7))))
    (bond := depositedBond) (window := 1) (by decide) (by decide +kernel) rfl rfl (by decide) (by decide)

def forfeited := Protocol.transact env started (.registry 1 (.forfeit 0 1 7 123 5))
example : (Protocol.registryCall env started 1 (.forfeit 0 1 7 123 5)).isSome = true := by decide +kernel
example : RegistryMachine.EvidenceClock forfeited.registry.registry 0 started.number :=
  Economics.evidence_window_retained (.step (.refl started) (.call started (.registry 1 (.forfeit 0 1 7 123 5))))
    (bond := depositedBond) (window := 1) (by decide) (by decide +kernel) rfl rfl (by decide) (by decide)

def falseVerifier := {registry with verify := fun _ _ _ => true}
example : ¬ Finality.SignatureSound falseVerifier env.signature := by
  intro sound
  have impossible := sound 0 evA 0 rfl
  cases impossible

-- A halt cannot consume an evidence clock before confirmation.
def exited := Protocol.transact env started (.registry 71 (.requestExit 0 71))
def halted := Protocol.transact env exited (.advance 100)
example : (Protocol.registryCall env halted 77 (.confirm 0)).isNone = true := by decide +kernel
example : (Protocol.registryCall env halted 71 (.withdraw 0 71 71)).isNone = true := by decide +kernel

-- Later activation changes live power without rewriting the already closed cutoff.
def topped := Protocol.transact env started (.registry 71 (.topUp 0 71 100))
def mature := Protocol.transact env topped (.advance 3)
def activated := Protocol.transact env mature (.registry 77 (.activateTopUp 0))
theorem laterRun : Protocol.Trace env started activated :=
  .step (.step (.step (.refl started) (.call started (.registry 71 (.topUp 0 71 100))))
    (.call topped (.advance 3))) (.call mature (.registry 77 (.activateTopUp 0)))
example : RegistryPayments.Backed env.token activated.registry :=
  Economics.funds_backed_from_seed rfl
    (Economics.funds_backed genesis rfl (by decide) (by decide) run)
    (by decide +kernel) laterRun
example : RegistryMachine.SlotsIssued activated.registry.registry.ledger ∧
    RegistryMachine.HistoryIssued activated.registry.registry :=
  Economics.history_issued_from_seed laterRun
    (Economics.history_issued genesis run).1 (Economics.history_issued genesis run).2
example : (activated.registry.registry.ledger.bonds 0).map (fun b => b.value.stake) = some (Committee.minUnit+100) := by decide +kernel
example : Consensus.activeAt (Finality.derive (config started) started.registry.registry []) 1 =
    Consensus.activeAt (Finality.derive (config activated) activated.registry.registry []) 1 :=
  Economics.temporal_committee_agreement laterRun (common := []) (moreA := []) (moreB := []) (h := 1)
    rfl (by decide) (by decide)

-- A fabricated historical committee cannot satisfy raw deployment genesis.
def phantom : RegistryMachine.State := {registry with history := [⟨0,[⟨7,Committee.minUnit,0,Staking.noExit⟩]⟩]}
example : ¬ RegistryMachine.Genesis phantom := by
  intro bad
  have empty := bad.2.2.2.2.1
  cases empty

-- Physical immutable checks are separate from the external evidence-window policy.
def zeroDelay := {registry with config := {registry.config with withdrawalDelay := 0}}
def zeroMinimum := {registry with ledger := {registry.ledger with minStake := 0}}
def noActivation := {registry with ledger := {registry.ledger with activationDelay := 0}}
def badBounty := {registry with config := {registry.config with slashBountyBps := 10000}}
def zeroBounty := {registry with config := {registry.config with slashBountyBps := 0}}
def maxBounty := {registry with config := {registry.config with slashBountyBps := 9999}}
def initializeWith (e : Environment) (r : RegistryMachine.State) :=
  Protocol.execute e (Protocol.transact e (Protocol.empty e r) (.advance 2)) (.initializeInbox 1)
example : (initializeWith env zeroDelay).isSome = true := by decide +kernel
example : ¬ (0 < env.evidenceWindow ∧ env.evidenceWindow ≤ zeroDelay.config.withdrawalDelay) := by
  decide +kernel
example : zeroMinimum.config.valid zeroMinimum.ledger = true := by decide +kernel
example : (initializeWith env zeroMinimum).isSome = true := by decide +kernel
example : (initializeWith env noActivation).isNone = true := by decide +kernel
example : (initializeWith env badBounty).isNone = true := by decide +kernel
example : (initializeWith env zeroBounty).isSome = true := by decide +kernel
example : (initializeWith env maxBounty).isSome = true := by decide +kernel
example : (initializeWith {env with core := {env.core with slashSink := 0}, token := RegistryPayments.standardEnvironment 40 0} registry).isNone = true := by decide +kernel
example : (initializeWith {env with token := RegistryPayments.standardEnvironment 41 90} registry).isNone = true := by decide +kernel

-- A registry self-deposit cannot use absent self-approval to inflate the reserve.
example : (Protocol.registryCall env started 40 (.register 9 40 Committee.minUnit 9)).isNone = true := by decide +kernel

-- RECOV-8-35 is a real limitation, even starting with raw empty Genesis and paid
-- registrations: funds withdrawn using an unsound landing are not restored by the
-- later checkpoint/snapshot rollback. The permissive verifier here deliberately
-- does not satisfy proof soundness. A historical above-checkpoint committee alone
-- therefore cannot imply that its original principal is still held.
def riskExited := Protocol.transact env started (.registry 71 (.requestExit 0 71))
def riskAdvanced := Protocol.transact env riskExited (.advance 4)
def riskImage := Protocol.transact env riskAdvanced (.image 1 11 true)
def unsoundLanding : Landing :=
  ⟨⟨0,1,101,201,0,101,3,0,3⟩,[],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩
def riskLanded := Protocol.transact env riskImage (.land unsoundLanding)
def riskConfirmed := Protocol.transact env riskLanded (.registry 77 (.confirm 0))
def riskMature := Protocol.transact env riskConfirmed (.advance 7)
def riskWithdrawn := Protocol.transact env riskMature (.registry 71 (.withdraw 0 71 71))
def riskRolled := Protocol.transact env riskWithdrawn (.rollback 1 started.inbox.checkpoint 1)

example : LandingChecks env riskImage unsoundLanding := by decide +kernel
example : (riskConfirmed.registry.registry.ledger.bonds 0).map (fun b => b.value.confirmedAt) = some (some 4) := by decide +kernel
example : riskWithdrawn.registry.token.balances 71 = 2*Committee.minUnit := by decide +kernel
example : riskRolled.inbox.checkpoint.height = 0 ∧ riskRolled.inbox.snapshot = 1 := by decide +kernel
example : (riskRolled.registry.registry.ledger.bonds 0).map (fun b => b.value.released) = some true := by decide +kernel
example : 1 > riskRolled.inbox.checkpoint.height ∧
    Consensus.CommitValid (policy env riskRolled [] 6).consensus env.signature 1 0 11 [vote 11] := by
  decide +kernel
example : (Protocol.registryCall env riskRolled 77 (.slash 0 evA evB 7 7)).isNone = true := by decide +kernel

theorem riskRun : Protocol.Trace env initial riskRolled :=
  .step (.step (.step (.step (.step (.step (.step (.step run
    (.call started (.registry 71 (.requestExit 0 71))))
    (.call riskExited (.advance 4))) (.call riskAdvanced (.image 1 11 true)))
    (.call riskImage (.land unsoundLanding))) (.call riskLanded (.registry 77 (.confirm 0))))
    (.call riskConfirmed (.advance 7))) (.call riskMature (.registry 71 (.withdraw 0 71 71))))
    (.call riskWithdrawn (.rollback 1 started.inbox.checkpoint 1))

-- The exceptional run cannot be silently admitted by the normal-execution profile.
example : ¬ StakeRisk.NormalTrace (Protocol.registryWorld env initial) (Protocol.registryWorld env riskRolled) := by
  intro normal
  let entry : Committee.Entry := ⟨7,Committee.minUnit,1,Staking.noExit⟩
  have member : entry ∈ (Consensus.activeAt (policy env riskRolled [] 6).consensus 1).members := by decide +kernel
  obtain ⟨id,bond,issued,found,_,live,_,_⟩ := StakeRisk.committee_unconfirmed normal genesis
    (cfg := Protocol.config riskRolled) (archive := []) (h := 1) (by decide +kernel) (by decide +kernel) member
  have bound : riskRolled.registry.registry.ledger.nextId = 1 := by decide +kernel
  have identity : id = 0 := by change id < riskRolled.registry.registry.ledger.nextId at issued; omega
  subst id
  have paid : (riskRolled.registry.registry.ledger.bonds 0).map (fun b => b.value.released) = some true := by decide +kernel
  change riskRolled.registry.registry.ledger.bonds 0 = some bond at found
  rw [found] at paid
  simp only [Option.map_some,Option.some.injEq,live] at paid
  cases paid

-- Existing-registry deployment is supported by START-10-16a but excluded by the
-- fresh-deployment Genesis premise. This is a deployment scope distinction, not a
-- claim that a retargeted registry starts with no permanent bonds.
example : ¬ RegistryMachine.Genesis started.registry.registry := by
  intro fresh
  have impossible : started.registry.registry.ledger.nextId = 0 := fresh.1
  have issued : started.registry.registry.ledger.nextId = 1 := by decide +kernel
  omega
end Etna.EconomicsRegression
