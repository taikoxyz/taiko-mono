import EtnaWitnesses.NonVacuity.Current
import EtnaProofs.CurrentUnzen

/-! A genuine switching deployment: a fixed legacy proof, one static Etna proof
statement, injective complete L1 commitments, all current primitive premises, and
an accepting first landing that consumes an actually paid forced inclusion. -/
namespace Etna.Design.Current.Protocol.CurrentSwitch
open Etna.Design Etna.Design.Current Protocol
open _root_.Etna.Design.Current.Protocol.NonVacuity (domain unit registry genesis first second vote recoveredVote engine)
set_option maxRecDepth 30000
set_option maxHeartbeats 400000
set_option linter.unusedSimpArgs false
set_option backward.isDefEq.respectTransparency false

def legacy : Header := { first with cometHash := 0,cursor := 0 }
def baseEnv : Environment := { NonVacuity.baseEnv with
  core := ⟨domain,7,8,99,3,9⟩
  unzenNextProposal := 2
  headerHash := NonVacuity.headerCommitment
  headerParent := fun hash => hash-1
  unzenValid := fun proposal h proof => decide (proposal = 1 ∧ h = legacy ∧ proof = 77)
  unzenRoot := fun h => h = legacy }

def deployed (e : Environment) : World := empty e registry
def registered (e : Environment) := transact e (deployed e) (.registry 8 (.register 7 8 unit 1))
def advanced (e : Environment) := transact e (registered e) (.advance 2)
def initialized (e : Environment) := transact e (advanced e) (.initializeInbox 7)
def forked (e : Environment) := transact e (initialized e) (.advance 3)
def proven (e : Environment) := transact e (forked e) (.unzenProve 1 legacy 77)
def started (e : Environment) := transact e (proven e) (.setOrigin 8 1 101 100)
def enqueued (e : Environment) := transact e (started e) (.enqueue [1] 1000000000 true)
def imaged (e : Environment) := transact e (enqueued e) (.image 7 11 true)
def beforeRecovery (e : Environment) := transact e (imaged e) (.advance 4)
def request : RecoveryRequest := ⟨7,0,1,0,100,[],[],0,none⟩
def recovered (e : Environment) := transact e (beforeRecovery e) (.recover request)
def source (e : Environment) := transact e (recovered e) (.advance 5)
def closedFour : Snapshot := snapshot baseEnv (recovered baseEnv) 4

def forcedEntry : Forced.Entry := ⟨1,3,3⟩
def witness : Forced.Witness := ⟨0,forcedEntry,true,0,0,false,some 1,true,1⟩
def body : BlockValidity.Block :=
  ⟨second,101,none,domain,1,4,100,100,true,none,1,1,4,0,[recoveredVote],some witness,.completedRetained⟩
def block : Block := ⟨body,⟨0,0,0,0,0⟩,[],some [1],[[1]]⟩
def definition : Blocks.Definition :=
  ⟨fun p b => decide (p = legacy ∧ b.header = second),
    fun _ raw transactions => decide (raw = [] ∧ transactions = [[1]]),NonVacuity.bytes⟩
def landing : Landing := ⟨⟨1,2,102,202,101,4,1,4⟩,[],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩
def template : StatementData := { statement baseEnv (source baseEnv) landing with referenceHash := 16 }

def knownSnapshots : List Snapshot := (source baseEnv).history
def stateCommitment (s : Snapshot) : Hash :=
  Encoding.relabel (knownSnapshots.map Encoding.snapshot) Encoding.Tree.code (Encoding.snapshot s)
def prefixCommitment (history : List Snapshot) : Hash :=
  Encoding.relabel [Encoding.list Encoding.snapshot knownSnapshots] Encoding.Tree.code
    (Encoding.list Encoding.snapshot history)
def l1Commitment (history : List Snapshot) (number : Nat) : Hash :=
  Encoding.pair (prefixCommitment history) number

def env : Environment := { baseEnv with
  stateRoot := stateCommitment
  blockHash := l1Commitment
  catalogue := fun _ => some definition
  verify := fun _ _ image _ d => decide (image = 11 ∧ d = template) }

def archive : List Header := [second]
def pol : Blocks.Policy := policy env (source env) archive 4
instance : DecidablePred pol.signature := fun candidate =>
  inferInstanceAs (Decidable (candidate = vote ∨ candidate = recoveredVote))
instance : Decidable (Blocks.HeaderValid pol legacy block) := inferInstanceAs (Decidable (_ ∧ _))

 theorem source_reachable (e : Environment) : Trace e (empty e registry) (source e) :=
  .step (.step (.step (.step (.step (.step (.step (.step (.step (.step (.step (.refl _) (.call _ (.registry 8 (.register 7 8 unit 1)))) (.call _ (.advance 2))) (.call _ (.initializeInbox 7))) (.call _ (.advance 3))) (.call _ (.unzenProve 1 legacy 77))) (.call _ (.setOrigin 8 1 101 100))) (.call _ (.enqueue [1] 1000000000 true))) (.call _ (.image 7 11 true))) (.call _ (.advance 4))) (.call _ (.recover request))) (.call _ (.advance 5))

 theorem seed_calls_independent (w : World) (call : Call) (notLanding : ∀ a, call ≠ .land a) :
    transact env w call = transact baseEnv w call := by
  cases call <;> first | rfl | exact (notLanding _ rfl).elim

 theorem source_independent : source env = source baseEnv := by
  have emptySame : deployed env = deployed baseEnv := rfl
  have a (w : World) (n : Nat) := seed_calls_independent w (.advance n) (by intro x impossible; cases impossible)
  have b (w : World) := seed_calls_independent w (.registry 8 (.register 7 8 unit 1)) (by intro x impossible; cases impossible)
  have c (w : World) := seed_calls_independent w (.initializeInbox 7) (by intro x impossible; cases impossible)
  have d (w : World) := seed_calls_independent w (.unzenProve 1 legacy 77) (by intro x impossible; cases impossible)
  have e (w : World) := seed_calls_independent w (.setOrigin 8 1 101 100) (by intro x impossible; cases impossible)
  have f (w : World) := seed_calls_independent w (.enqueue [1] 1000000000 true) (by intro x impossible; cases impossible)
  have g (w : World) := seed_calls_independent w (.image 7 11 true) (by intro x impossible; cases impossible)
  have h (w : World) := seed_calls_independent w (.recover request) (by intro x impossible; cases impossible)
  simp only [source,recovered,beforeRecovery,imaged,enqueued,started,proven,forked,initialized,advanced,registered,
    a,b,c,d,e,f,g,h,emptySame]

 theorem first_bound : HashBound env legacy := by
  change NonVacuity.headerCommitment legacy = 101
  decide +kernel
 theorem second_bound : HashBound env second := by
  change NonVacuity.headerCommitment second = 102
  decide +kernel

 theorem primitives : Custody.Primitives env := by
  refine ⟨NonVacuity.genesis_bound,NonVacuity.primitives.separation,?_⟩
  intro proposal h proof valid
  change decide (proposal = 1 ∧ h = legacy ∧ proof = 77) = true at valid
  obtain ⟨_,rfl,_⟩ := of_decide_eq_true valid
  exact ⟨rfl,first_bound,by decide⟩

 theorem unzen_extension : Custody.UnzenExtension env env.unzenParent := by
  intro boundary proposal h proof parent _ _ bound same
  change NonVacuity.headerCommitment parent = parent.elHash at bound
  have zero : parent.elHash = 0 := same.symm
  have impossible : NonVacuity.headerCommitment parent = 0 := bound.trans zero
  have positive : 0 < NonVacuity.headerCommitment parent :=
    Nat.lt_of_lt_of_le (by decide : 0 < 100) (Nat.le_add_left _ _)
  exact (Nat.ne_of_gt positive impossible).elim

 theorem state_injective {x y : Snapshot} (same : env.stateRoot x = env.stateRoot y) : x = y :=
  Encoding.snapshot_eq.mp (Encoding.relabel_injective _ _ (fun eq => Encoding.tree_code_injective eq) same)

 theorem reference_binding : ReferenceBinding env := by
  intro a b number same
  have relabelled := (Encoding.pair_injective same).1
  have trees := Encoding.relabel_injective _ _ (fun eq => Encoding.tree_code_injective eq) relabelled
  exact Encoding.list_injective Encoding.snapshot (fun eq => Encoding.snapshot_eq.mp eq) trees

 theorem source_reference : referenceHash env (source env) 4 = 16 := by
  rw [source_independent]
  change Encoding.pair (prefixCommitment ((source baseEnv).history.take 5)) 4 = 16
  have take : (source baseEnv).history.take 5 = knownSnapshots := by rfl
  rw [take]
  change Encoding.pair (Encoding.relabel _ _ _) 4 = 16
  rw [Encoding.relabel_head]
  rfl

 theorem source_statement : statement env (source env) landing = template := by
  change (⟨domain,1,0,101,0,0,landing.input,referenceHash env (source env) 4,[1],⟨1,1,2,[]⟩⟩ : StatementData) = template
  rw [source_reference]
  rfl

 theorem source_landing_checks : LandingChecks env (source env) landing := by
  constructor
  case proofs => simp only [proofsAccepted,source_statement]; decide +kernel
  all_goals first | rfl | decide +kernel

 theorem source_landing_accepted : land env (source env) landing = some (landed (source env) landing) := by
  simp only [land,source_landing_checks,ite_true]

 theorem block_valid : Blocks.Valid pol legacy block := by
  constructor
  all_goals first
    | decide +kernel
    | (constructor <;> decide +kernel)
    | (intro wit carried
       have same : wit = witness := by simpa [block,body] using carried.symm
       subst wit
       first | (unfold ActualQueue.PayloadFields; decide +kernel) | decide +kernel)

 theorem source_parameters : parametersOf (source env).inbox = baseEnv.parameters := by rfl
 theorem source_config : config (source env) = ⟨domain,1,1,4,1,10,unit,unit,1⟩ := by rfl

 theorem source_pure_certificate : BatchCertificate env (source env) template archive legacy [block] := by
  have policyFixed : policy env (certificateWorld env (source env) 4) archive 4 = pol := by rfl
  refine ⟨?_,?_,?_⟩
  · refine ⟨?_,?_,?_,first_bound,?_,?_,?_⟩
    · decide +kernel
    · change Blocks.BatchValid (policy env (certificateWorld env (source env) 4) archive 4) legacy [block] [1]
      rw [policyFixed]
      exact ⟨⟨block_valid,True.intro⟩,rfl⟩
    · change template = Blocks.statement (policy env (certificateWorld env (source env) 4) archive 4) legacy [block] [1]
      rw [policyFixed]
      change template = (⟨domain,1,0,101,0,0,landing.input,referenceHash env (source env) 4,[1],⟨1,1,2,[]⟩⟩ : StatementData)
      rw [source_reference]
      rfl
    · intro b member
      have equal : b = block := by simpa using member
      subst b; exact second_bound
    · intro _ _; rfl
    · refine ⟨legacy,[],rfl,rfl,first_bound,rfl,rfl,?_,?_,?_,by decide,?_⟩
      · simp [Archive.Linked,archive,block,body,legacy,first,NonVacuity.firstBase,second,env,baseEnv,Blocks.Block.header]
      · intro h member
        have equal : h = second := by simpa [archive] using member
        subst h; exact second_bound
      · intro b member
        have equal : b = block := by simpa using member
        subst b; rfl
      · intro h member
        have equal : h = second := by simpa [archive] using member
        subst h; decide
  · rfl
  · rfl

 theorem codec_sound (w : World) : ProtocolFinality.CodecSound env w := by
  intro archiveA archiveB referenceA referenceB parent x y validX validY same
  have ex := validX.execution
  have ey := validY.execution
  change decide (parent = legacy ∧ x.body.header = second) = true at ex
  change decide (parent = legacy ∧ y.body.header = second) = true at ey
  exact (of_decide_eq_true ex).2.trans (of_decide_eq_true ey).2.symm

 theorem vote_attribution (w : World) : ProtocolFinality.VoteAttribution engine env w := by
  intro origin blocks reference height chain pair member vote present
  trivial

 theorem source_view_storage : CertificateStorage (certificateWorld env (source env) 4) (source env) 4 := by
  constructor
  all_goals first | rfl | decide +kernel

 theorem source_view_registry :
    (certificateWorld env (source env) 4).registry.registry.history = closedFour.registryHistory := by
  rw [source_independent]
  rfl

 theorem source_start_eq_closed : (source env).start = closedFour.start := by
  rw [source_independent]
  rfl

 theorem template_image_certifies {w : World} {a : Landing}
    (trace : Trace env (empty env registry) w) (same : statement env w a = template) :
    ImageCertifies env w 11 (statement env w a) := by
  have gen := congrArg StatementData.generation same
  change w.inbox.generation = 1 at gen
  have ref := congrArg (fun d : StatementData => d.input.l1ReferenceBlockNumber) same
  change a.input.l1ReferenceBlockNumber = 4 at ref
  have hash := congrArg StatementData.referenceHash same
  change referenceHash env w a.input.l1ReferenceBlockNumber = 16 at hash
  rw [ref] at hash
  have prefixSame : referencePrefix (source env) 4 = referencePrefix w 4 :=
    reference_hash_binds_prefix reference_binding (source_reference.trans hash.symm)
  have closed : closedFour ∈ w.history := List.mem_of_mem_take (show closedFour ∈ referencePrefix w 4 from by
    rw [← prefixSame,source_independent]
    decide +kernel)
  have metadata := closed_started_metadata trace closedFour closed (by decide +kernel) (by
    change 1 = w.inbox.generation
    exact gen.symm)
  have pars := closed_generation_parameters trace closedFour closed (by
    change 1 = w.inbox.generation
    exact gen.symm)
  change parametersOf w.inbox = baseEnv.parameters at pars
  have domainFixed := (ProtocolFinality.trace_fields trace).1
  change w.inbox.domain = domain at domainFixed
  have origin : w.inbox.origin = ⟨1,4,4⟩ := metadata.2
  have currentConfig : config w = config (source env) := by
    rw [source_config]
    have epoch : w.inbox.epochLen = 10 := congrArg Parameters.epochLen pars
    have cutoff : w.inbox.genesisCutoff = 1 := congrArg Parameters.genesisCutoff pars
    have committee : w.inbox.configuration = baseEnv.parameters.committee := congrArg Parameters.committee pars
    change (⟨w.inbox.domain,w.inbox.generation,w.inbox.origin.height,w.inbox.origin.l1Block,
      w.inbox.genesisCutoff,w.inbox.epochLen,w.inbox.configuration.unit,
      w.inbox.configuration.minimum,w.inbox.configuration.nMax⟩ : Finality.Config) = _
    rw [domainFixed,gen,origin,epoch,cutoff,committee]
    rfl
  have committee : w.inbox.committeeConfig = (source env).inbox.committeeConfig := congrArg StatementData.config same
  have viewSame := certificate_world_of_prefix (env := env) prefixSame
  refine ⟨archive,legacy,[block],?_,?_⟩
  · rw [same]
    exact batch_certificate_transport prefixSame source_pure_certificate
  · intro b member
    have equal : b = block := by simpa using member
    subst b; decide

 theorem verifier_sound : VerifierSound env (empty env registry) := by
  refine ⟨fun _ => True,?_,?_⟩
  · intro proofs accepted
    cases proofs with
    | nil => simp [dualOK] at accepted
    | cons proof rest => exact ⟨proof,List.mem_cons_self,True.intro⟩
  · intro w trace a t proof accepted present sound verified
    change decide (proof.image = 11 ∧ statement env w a = template) = true at verified
    obtain ⟨image,same⟩ := of_decide_eq_true verified
    rw [image]
    exact template_image_certifies trace same

 theorem premises : Etna.Statements.Current.Premises env registry engine := by
  refine ⟨primitives,verifier_sound,rfl,NonVacuity.signature_refinement,by decide,
    fun w _ => codec_sound w,fun w _ => vote_attribution w,fun _ _ h => h,?_,
    reference_binding,NonVacuity.registry_genesis,NonVacuity.signature_sound,by decide,unzen_extension,by decide +kernel⟩
  intro id selected present
  have same : selected = definition := by simpa [env] using present.symm
  subst selected
  rfl

/-- Joint all-14-premise switching nonvacuity with real legacy/Etna checkpoints and
paid FI consumption, under one global fixed-statement verifier relation. -/
theorem accepting_switch :
    Etna.Statements.Current.Premises env registry engine ∧
    env.core.unzenInbox ≠ 0 ∧
    Trace env (empty env registry) (source env) ∧
    land env (source env) landing = some (landed (source env) landing) ∧
    (source env).legacySignals = [⟨1,101,100⟩] ∧
    (landed (source env) landing).inbox.signals = [⟨2,102,101⟩] ∧
    (source env).inbox.head < (landed (source env) landing).inbox.head ∧
    (source env).inbox.ethBalance = 1000000000 := by
  exact ⟨premises,by decide,source_reachable env,source_landing_accepted,by decide +kernel⟩

end Etna.Design.Current.Protocol.CurrentSwitch
