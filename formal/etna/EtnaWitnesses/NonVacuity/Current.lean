import EtnaStatements.Current
import EtnaProofs.CurrentEncoding
import EtnaProofs.CurrentEconomics
import EtnaProofs.CurrentMetadata
import EtnaProofs.CurrentCoherentCustody

/-! A finite accepting deployment with globally sound fixed proof bytes. The commitments
encode the complete closed state. They are ideal unbounded Nat commitments, not Keccak. -/
namespace Etna.Design.Current.Protocol.NonVacuity
open Etna.Design Etna.Design.Current Protocol
set_option maxRecDepth 30000
set_option maxHeartbeats 8000000
set_option linter.unusedSimpArgs false
set_option backward.isDefEq.respectTransparency false

abbrev Commitments := Etna.Design.Current.Encoding.Tree

def domain : Domain := ⟨1,2,3,4⟩
def unit : Nat := Committee.minUnit

def vote : Consensus.Vote := ⟨domain,0,1,0,2,201,7⟩
def recoveredVote : Consensus.Vote := ⟨domain,1,2,0,2,202,7⟩
def registry : RegistryMachine.State where
  ledger := ⟨0,fun _ => none,fun _ => none,fun _ => none,unit,1⟩
  config := { inbox := 3 }
  verify := fun key message signature =>
    decide (key = 7 ∧ ((message = Accountability.evidence vote ∧ signature = 11) ∨
      (message = Accountability.evidence recoveredVote ∧ signature = 12)))
  registerAuth := fun key owner amount pop => decide (key = 7 ∧ owner = 8 ∧ amount = unit ∧ pop = 1)

def genesisBase : Header := ⟨0,0,10,0,0,1,⟨0,0,0,0,0,0,0⟩,0⟩
def genesis : Header := { genesisBase with elHash := 100 }
def initialSigner : Signer.State := ⟨domain,0,1,[],false,[]⟩
def txHash (bytes : Blocks.Bytes) : Hash := if bytes = [1] then 1 else 0

def baseEnv : Environment where
  core := ⟨domain,7,8,0,2,9⟩
  parameters := ⟨1,10,1,⟨unit,unit,1,10⟩,1,1152,10,1,1,9⟩
  genesisHeader := genesis
  initialSigner := initialSigner
  time := id
  stateRoot := fun _ => 0
  blockHash := fun _ _ => 0
  headerHash := fun _ => 0
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun candidate => candidate = vote ∨ candidate = recoveredVote
  txHash := txHash
  unzenNextProposal := 1
  timestampOf := fun _ => 1
  catalogue := fun _ => none
  payload := fun _ _ => true
  verify := fun _ _ _ _ _ => false
  imageRules := fun _ => [0]
  unzenValid := fun _ _ _ => false
  unzenRoot := fun _ => False
  startImplementation := fun _ => true
  importValid := fun _ _ _ => true
  signBytes := fun _ => 0
  token := RegistryPayments.standardEnvironment 4 9
  initialToken := ⟨fun account => if account = 8 then unit else 0,
    fun owner spender => if owner = 8 ∧ spender = 4 then unit else 0⟩

def deployed (env : Environment) : World := empty env registry
def registered (env : Environment) : World :=
  transact env (deployed env) (.registry 8 (.register 7 8 unit 1))
def advanced (env : Environment) : World := transact env (registered env) (.advance 2)
def initialized (env : Environment) : World := transact env (advanced env) (.initializeInbox 7)
def enqueued (env : Environment) : World := transact env (initialized env) (.enqueue [1] 1000000000 true)
def imaged (env : Environment) : World := transact env (enqueued env) (.image 7 11 true)
def source (env : Environment) : World := transact env (imaged env) (.advance 3)

def closedTwo : Snapshot := snapshot baseEnv (imaged baseEnv) 2

def firstBase : Header := ⟨1,0,100,201,1,2,⟨2,2,2,0,100,0,1⟩,301⟩
def first : Header := { firstBase with elHash := 101 }
def second : Header := ⟨2,102,101,202,1,4,⟨4,4,4,1,101,1,1⟩,302⟩
def forcedEntry : Forced.Entry := ⟨1,2,2⟩
def witness : Forced.Witness := ⟨0,forcedEntry,true,0,0,false,some 1,true,1⟩
def body : BlockValidity.Block :=
  ⟨first,genesis.elHash,none,domain,0,2,100,100,true,none,1,1,
    first.anchor.stateRoot,0,[vote],some witness,.completedRetained⟩
def block : Block := ⟨body,⟨0,0,0,0,0⟩,[],some [1],[[1]]⟩
def bytes : ActualQueue.Primitives :=
  ⟨txHash,fun raw => decide (raw = [1]),fun _ _ _ => .completedRetained⟩
def definition : Blocks.Definition :=
  ⟨fun p b => decide ((p = genesis ∧ b.header = first) ∨ (p = first ∧ b.header = second)),
    fun b raw transactions => decide (raw = [] ∧ transactions = if b.header.height = 1 then [[1]] else []),bytes⟩
def landing : Landing := ⟨⟨0,1,first.elHash,201,301,100,2,1,1⟩,[],[1],
  [⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩
def template : StatementData := { statement baseEnv (source baseEnv) landing with referenceHash := 4 }

def recoveryRequest : RecoveryRequest := ⟨7,0,1,0,100,[],[],0,none⟩
def beforeRecovery (e : Environment) : World := transact e (landed (source e) landing) (.advance 4)
def recovered (e : Environment) : World := transact e (beforeRecovery e) (.recover recoveryRequest)
def recoveredSource (e : Environment) : World := transact e (recovered e) (.advance 5)
def closedThree : Snapshot := snapshot baseEnv (landed (source baseEnv) landing) 3
def closedFour : Snapshot := snapshot baseEnv (recovered baseEnv) 4

def recoveredBody : BlockValidity.Block :=
  ⟨second,first.elHash,none,domain,1,4,100,100,true,none,1,1,
    second.anchor.stateRoot,0,[recoveredVote],none,.completedRetained⟩
def recoveredBlock : Block := ⟨recoveredBody,⟨0,0,0,0,0⟩,[],none,[]⟩
def recoveredLanding : Landing := ⟨⟨1,2,102,202,302,101,4,1,4⟩,[],[1],
  [⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩
def recoveredTemplate : StatementData :=
  { statement baseEnv (recoveredSource baseEnv) recoveredLanding with referenceHash := 26 }

def knownSnapshots : List Snapshot :=
  [snapshot baseEnv (registered baseEnv) 0,snapshot baseEnv (registered baseEnv) 1,closedTwo]
def stateCommitment (s : Snapshot) : Hash :=
  Encoding.relabel ((knownSnapshots ++ [closedThree,closedFour]).map Encoding.snapshot) Encoding.Tree.code (Encoding.snapshot s)
def headerCommitment (h : Header) : Hash :=
  Encoding.relabel [Encoding.header genesis,Encoding.header first,Encoding.header second] Encoding.Tree.code (Encoding.header h)+100
def prefixCommitment (history : List Snapshot) : Hash :=
  Encoding.relabel [Encoding.list Encoding.snapshot (source baseEnv).history,
    Encoding.list Encoding.snapshot (recoveredSource baseEnv).history] Encoding.Tree.code
    (Encoding.list Encoding.snapshot history)
def l1Commitment (history : List Snapshot) (number : Nat) : Hash :=
  Encoding.pair (prefixCommitment history) number

def env : Environment := { baseEnv with
  stateRoot := stateCommitment
  headerHash := headerCommitment
  headerParent := fun hash => hash-1
  blockHash := l1Commitment
  catalogue := fun _ => some definition
  verify := fun _ _ image _ d => decide (image = 11 ∧ (d = template ∨ d = recoveredTemplate)) }

def archive : List Header := [first]
def pol : Blocks.Policy := policy env (source env) archive 2

 theorem source_reachable (e : Environment) : Trace e (empty e registry) (source e) :=
  .step (.step (.step (.step (.step (.step (.refl _) (.call _ (.registry 8 (.register 7 8 unit 1))))
    (.call _ (.advance 2))) (.call _ (.initializeInbox 7)))
    (.call _ (.enqueue [1] 1000000000 true))) (.call _ (.image 7 11 true))) (.call _ (.advance 3))

theorem seed_calls_independent (w : World) (call : Call) (notLanding : ∀ a, call ≠ .land a) :
    transact env w call = transact baseEnv w call := by
  cases call <;> first | rfl | exact (notLanding _ rfl).elim

 theorem source_independent_of_verifier : source env = source baseEnv := by
  have emptySame : deployed env = deployed baseEnv := rfl
  have a (w : World) (n : Nat) := seed_calls_independent w (.advance n) (by intro x impossible; cases impossible)
  have b (w : World) := seed_calls_independent w (.image 7 11 true) (by intro x impossible; cases impossible)
  have c (w : World) := seed_calls_independent w (.enqueue [1] 1000000000 true) (by intro x impossible; cases impossible)
  have d (w : World) := seed_calls_independent w (.initializeInbox 7) (by intro x impossible; cases impossible)
  have e (w : World) := seed_calls_independent w (.registry 8 (.register 7 8 unit 1)) (by intro x impossible; cases impossible)
  simp only [source,imaged,enqueued,initialized,advanced,registered,a,b,c,d,e,emptySame]

 theorem registry_genesis : RegistryMachine.Genesis registry := by
  exact ⟨rfl,fun _ => rfl,fun _ => rfl,fun _ => rfl,rfl,rfl⟩

 theorem actual_funding_and_queue :
    (source env).registry.registry.ledger.nextId = 1 ∧
    (source env).registry.token.balances 4 = unit ∧
    (source env).inbox.ethBalance = 1000000000 ∧ (source env).inbox.tail = 1 ∧
    (0,forcedEntry) ∈ (source env).queue := by decide +kernel

 theorem genesis_bound : HashBound env genesis := by
  change headerCommitment genesis = 100
  decide +kernel
 theorem first_bound : HashBound env first := by
  change headerCommitment first = 101
  decide +kernel

 theorem state_injective {x y : Snapshot} (same : env.stateRoot x = env.stateRoot y) : x = y := by
  exact Encoding.snapshot_eq.mp (Encoding.relabel_injective _ _
    (fun eq => Encoding.tree_code_injective eq) same)

 theorem primitives : Custody.Primitives env := by
  refine ⟨genesis_bound,?_,?_⟩
  · intro x y hx hy same
    have codes : headerCommitment x = headerCommitment y := hx.trans (same.trans hy.symm)
    have relabelled := Nat.add_right_cancel codes
    have trees := Encoding.relabel_injective _ _ (fun eq => Encoding.tree_code_injective eq) relabelled
    exact Encoding.header_hash_separation (congrArg Encoding.Tree.code trees)
  · intro proposal h proof impossible
    contradiction

 theorem reference_binding : ReferenceBinding env := by
  intro a b number same
  have relabelled := (Encoding.pair_injective same).1
  have trees := Encoding.relabel_injective _ _ (fun eq => Encoding.tree_code_injective eq) relabelled
  exact Encoding.list_injective Encoding.snapshot (fun eq => Encoding.snapshot_eq.mp eq) trees

 theorem signature_refinement : Finality.SignatureRefinement registry env.signature := by
  intro candidate authentic
  change candidate = vote ∨ candidate = recoveredVote at authentic
  rcases authentic with rfl | rfl
  · exact ⟨11,by simp [registry,vote]⟩
  · exact ⟨12,by simp [registry,recoveredVote]⟩

 theorem signature_sound : Finality.SignatureSound registry env.signature := by
  intro key message signature authentic
  change decide (key = 7 ∧ ((message = Accountability.evidence vote ∧ signature = 11) ∨
    (message = Accountability.evidence recoveredVote ∧ signature = 12))) = true at authentic
  have fields : key = 7 ∧ ((message = Accountability.evidence vote ∧ signature = 11) ∨
      (message = Accountability.evidence recoveredVote ∧ signature = 12)) := of_decide_eq_true authentic
  change Finality.signedVote key message = vote ∨ Finality.signedVote key message = recoveredVote
  rcases fields.2 with ordinary | recovered
  · apply Or.inl
    rw [fields.1,ordinary.1]
    rfl
  · apply Or.inr
    rw [fields.1,recovered.1]
    rfl

 theorem codec_sound (w : World) : ProtocolFinality.CodecSound env w := by
  intro archiveA archiveB referenceA referenceB parent x y validX validY same
  have ex := validX.execution
  have ey := validY.execution
  change decide ((parent = genesis ∧ x.body.header = first) ∨ (parent = first ∧ x.body.header = second)) = true at ex
  change decide ((parent = genesis ∧ y.body.header = first) ∨ (parent = first ∧ y.body.header = second)) = true at ey
  rcases of_decide_eq_true ex with ⟨_,hx⟩ | ⟨_,hx⟩ <;>
    rcases of_decide_eq_true ey with ⟨_,hy⟩ | ⟨_,hy⟩
  · exact hx.trans hy.symm
  · simp [Blocks.Block.header,hx,hy,first,firstBase,second] at same
  · simp [Blocks.Block.header,hx,hy,first,firstBase,second] at same
  · exact hx.trans hy.symm

 def engine : Finality.Engine :=
  ⟨fun _ _ => ⟨fun _ _ _ => True,fun _ _ _ => True,
    fun _ _ => {},fun _ _ => none⟩,fun _ _ _ => false,false⟩

 theorem vote_attribution (w : World) : ProtocolFinality.VoteAttribution engine env w := by
  intro origin blocks reference height chain pair member vote present
  trivial

instance : DecidablePred pol.signature := fun candidate =>
  inferInstanceAs (Decidable (candidate = vote ∨ candidate = recoveredVote))
instance (r : Blocks.Policy) (p : Header) (b : Block) : Decidable (Blocks.ParentAnchorValid r p b) := by
  unfold Blocks.ParentAnchorValid
  split <;> infer_instance
instance : Decidable (Blocks.HeaderValid pol genesis block) := inferInstanceAs (Decidable (_ ∧ _))

 theorem source_history : (source baseEnv).history = knownSnapshots := by rfl

private theorem label_head {α : Type} [DecidableEq α] (head : α) (rest : List α) (code : α → Nat) :
    Encoding.relabel (head :: rest) code head = 0 := by simp [Encoding.relabel]

private theorem label_tail {α : Type} [DecidableEq α] (head x : α) (rest : List α) (code : α → Nat)
    (different : x ≠ head) :
    Encoding.relabel (head :: rest) code x = Encoding.relabel rest code x+1 := by
  simp [Encoding.relabel,different]

 theorem closed_two_label : env.stateRoot closedTwo = 2 := by
  have n0 : Encoding.snapshot closedTwo ≠ Encoding.snapshot (snapshot baseEnv (registered baseEnv) 0) := by
    intro same
    have numbers := congrArg Snapshot.number (Encoding.snapshot_eq.mp same)
    change 2 = 0 at numbers
    contradiction
  have n1 : Encoding.snapshot closedTwo ≠ Encoding.snapshot (snapshot baseEnv (registered baseEnv) 1) := by
    intro same
    have numbers := congrArg Snapshot.number (Encoding.snapshot_eq.mp same)
    change 2 = 1 at numbers
    contradiction
  change stateCommitment closedTwo = 2
  change Encoding.relabel [Encoding.snapshot (snapshot baseEnv (registered baseEnv) 0),
    Encoding.snapshot (snapshot baseEnv (registered baseEnv) 1),Encoding.snapshot closedTwo,
    Encoding.snapshot closedThree,Encoding.snapshot closedFour]
    Encoding.Tree.code (Encoding.snapshot closedTwo) = 2
  rw [label_tail _ _ _ _ n0,label_tail _ _ _ _ n1,label_head]

 theorem closed_two_anchor : anchor env closedTwo = first.anchor := by
  have label := closed_two_label
  change (⟨2,2,env.stateRoot closedTwo,0,100,0,1⟩ : BlockValidity.Anchor) = _
  rw [label]
  rfl

 theorem source_reference : referenceHash env (source env) 2 = 4 := by
  rw [source_independent_of_verifier]
  change Encoding.pair (prefixCommitment ((source baseEnv).history.take 3)) 2 = 4
  have take : (source baseEnv).history.take 3 = (source baseEnv).history := by
    rw [source_history]
    rfl
  rw [take]
  have label := label_head (Encoding.list Encoding.snapshot (source baseEnv).history)
    [Encoding.list Encoding.snapshot (recoveredSource baseEnv).history] Encoding.Tree.code
  change Encoding.pair (Encoding.relabel _ _ _) 2 = 4
  rw [label]
  rfl

theorem source_statement : statement env (source env) landing = template := by
  change (⟨domain,0,0,100,0,0,0,landing.input,referenceHash env (source env) 2,[1],
    ⟨0,0,1,[]⟩⟩ : StatementData) = template
  rw [source_reference]
  rfl

theorem source_landing_checks : LandingChecks env (source env) landing := by
  constructor
  case proofs =>
    simp only [proofsAccepted,source_statement]
    decide +kernel
  all_goals first | rfl | decide +kernel

theorem source_landing_accepted : land env (source env) landing = some (landed (source env) landing) := by
  simp only [Protocol.land,source_landing_checks,ite_true]

 theorem latest_bounded_filter (history : List RegistryHistory.Snapshot) {cutoff bound : Nat}
    (within : cutoff ≤ bound) :
    RegistryHistory.latestSnapshot (history.filter (fun cp => decide (cp.block ≤ bound))) cutoff =
      RegistryHistory.latestSnapshot history cutoff := by
  induction history with
  | nil => rfl
  | cons cp rest ih =>
    by_cases low : cp.block ≤ cutoff
    · have high : cp.block ≤ bound := Nat.le_trans low within
      simp [RegistryHistory.latestSnapshot,List.filter_cons,low,high]
    · by_cases high : cp.block ≤ bound
      · simpa [RegistryHistory.latestSnapshot,List.filter_cons,low,high] using ih
      · simpa [RegistryHistory.latestSnapshot,List.filter_cons,low,high] using ih

 theorem find_unique {α : Type} (predicate : α → Bool) (list : List α) (target : α)
    (present : target ∈ list) (yes : predicate target = true)
    (unique : ∀ x ∈ list, predicate x = true → x = target) : list.find? predicate = some target := by
  induction list with
  | nil => cases present
  | cons x rest ih =>
    by_cases tested : predicate x = true
    · have same := unique x List.mem_cons_self tested
      subst x
      simp [List.find?,yes]
    · have later : target ∈ rest := by
        rcases List.mem_cons.mp present with equal | later
        · subst x; exact (tested yes).elim
        · exact later
      simpa [List.find?,tested] using ih later (fun y mem => unique y (List.mem_cons_of_mem _ mem))

 theorem matching_closed_two {w : World} (present : closedTwo ∈ w.history) :
    matchingSnapshot env w first.anchor = some closedTwo := by
  change w.history.find? (fun s => anchor env s == first.anchor) = some closedTwo
  apply find_unique _ _ _ present
  · simp [closed_two_anchor]
  · intro s mem authentic
    have same : anchor env s = first.anchor := by simpa using authentic
    rw [← closed_two_anchor] at same
    exact state_injective (congrArg BlockValidity.Anchor.stateRoot same)

 theorem first_valid : Blocks.Valid pol genesis block := by
  constructor
  all_goals first
    | rfl
    | decide +kernel
    | (constructor <;> decide +kernel)
    | (intro wit carried
       have same : wit = witness := by simpa [block,body] using carried.symm
       subst wit
       first | (unfold ActualQueue.PayloadFields; decide +kernel) | decide +kernel)

theorem source_config : config (source env) = ⟨domain,0,0,2,1,10,unit,unit,1⟩ := by rfl

theorem source_parameters : parametersOf (source env).inbox = baseEnv.parameters := by rfl

structure TemplateContext (w : World) : Prop where
  generation : w.inbox.generation = 0
  parameters : parametersOf w.inbox = baseEnv.parameters
  config : config w = config (source env)
  start : w.start = (source env).start
  committee : w.inbox.committeeConfig = 0
  closed : closedTwo ∈ w.history
  latest : RegistryHistory.latestSnapshot w.registry.registry.history 1 =
    RegistryHistory.latestSnapshot (source env).registry.registry.history 1
  reference : referenceHash env w 2 = 4
  lookup : Finality.registryAt w.registry.registry 1 = Finality.registryAt (source env).registry.registry 1

theorem template_context {w : World} {a : Landing}
    (trace : Trace env (empty env registry) w) (same : statement env w a = template) :
    TemplateContext w := by
  have gen := congrArg StatementData.generation same
  change w.inbox.generation = 0 at gen
  have ref := congrArg (fun d : StatementData => d.input.l1ReferenceBlockNumber) same
  change a.input.l1ReferenceBlockNumber = 2 at ref
  have hash := congrArg StatementData.referenceHash same
  change referenceHash env w a.input.l1ReferenceBlockNumber = 4 at hash
  rw [ref,← source_reference] at hash
  have refCut := reference_hash_binds_prefix reference_binding hash
  have sourcePrefix : referencePrefix (source env) 2 = knownSnapshots := by
    rw [source_independent_of_verifier]
    change (source baseEnv).history.take 3 = knownSnapshots
    rw [source_history]
    rfl
  rw [sourcePrefix] at refCut
  have closed : closedTwo ∈ w.history := List.mem_of_mem_take (show closedTwo ∈ referencePrefix w 2 from by
    rw [refCut]
    simp [knownSnapshots])
  have metadata := closed_started_metadata trace closedTwo closed (by decide +kernel) (by
    change 0 = w.inbox.generation
    exact gen.symm)
  have pars := Economics.generation_zero_parameters trace gen
  change parametersOf w.inbox = baseEnv.parameters at pars
  have domainFixed := (ProtocolFinality.trace_fields trace).1
  change w.inbox.domain = domain at domainFixed
  have origin : w.inbox.origin = ⟨0,2,2⟩ := metadata.2
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
  have latest : RegistryHistory.latestSnapshot w.registry.registry.history 1 =
      RegistryHistory.latestSnapshot (source env).registry.registry.history 1 := by
    have history := (Economics.closed_registry_history trace closedTwo closed).2
    change w.registry.registry.history.filter (fun cp => decide (cp.block ≤ 2)) =
      closedTwo.registryHistory.filter (fun cp => decide (cp.block ≤ 2)) at history
    rw [← latest_bounded_filter w.registry.registry.history (show 1 ≤ 2 from by decide),history,
      latest_bounded_filter closedTwo.registryHistory (show 1 ≤ 2 from by decide)]
    rw [source_independent_of_verifier]
    rfl
  have lookup : Finality.registryAt w.registry.registry 1 = Finality.registryAt (source env).registry.registry 1 := by
    unfold Finality.registryAt
    rw [latest]
  exact ⟨gen,pars,currentConfig,metadata.1,congrArg StatementData.config same,closed,latest,
    hash.trans source_reference,lookup⟩

theorem active_one_same {w : World} (context : TemplateContext w) :
    Consensus.activeAt (policy env w archive 2).consensus 1 = Consensus.activeAt pol.consensus 1 := by
  simp [pol,policy,context.config,source_config,Finality.derive,Consensus.activeAt,
    Consensus.epoch,Consensus.switchHeight,Consensus.initial,Consensus.selected,context.lookup]


theorem first_valid_in_context {w : World} (context : TemplateContext w) :
    Blocks.Valid (policy env w archive 2) genesis block := by
  have grid : w.inbox.gridK = 1 := congrArg Parameters.gridK context.parameters
  have epoch : w.inbox.epochLen = 10 := congrArg Parameters.epochLen context.parameters
  have committee : w.inbox.configuration = baseEnv.parameters.committee := congrArg Parameters.committee context.parameters
  have delay : w.inbox.forcedDelay = 1 := congrArg Parameters.forcedDelay context.parameters
  have age : w.inbox.maxAnchorAge = 1152 := congrArg Parameters.maxAnchorAge context.parameters
  constructor
  · change Committee.configOK w.inbox.gridK w.inbox.epochLen w.inbox.configuration.unsettled = true
    rw [grid,epoch,committee]
    decide +kernel
  · change (config w).originHeight ≤ genesis.height
    rw [context.config,source_config]
    decide +kernel
  · have fixedConfig := context.config.trans source_config
    simp only [Blocks.HeaderValid,policy,Finality.derive,fixedConfig,env,baseEnv]
    decide +kernel
  · constructor
    · change Blocks.ParentAnchorValid (policy env w archive 2) genesis block
      simp only [Blocks.ParentAnchorValid,policy,Finality.derive,context.config,source_config]
      rfl
    · change (config w).originBlock ≤ first.anchor.number
      rw [context.config,source_config]
      decide +kernel
    · change first.anchor.number ≤ 2
      decide +kernel
    · decide +kernel
    · change first.anchor.generation = w.inbox.generation
      rw [context.generation]
      rfl
    · decide +kernel
    · change first.timestamp-first.anchor.timestamp ≤ w.inbox.maxAnchorAge
      rw [age]
      decide +kernel
    · change first.height-first.anchor.checkpointHeight ≤ w.inbox.configuration.unsettled
      rw [committee]
      decide +kernel
    · change Finality.anchorAt (config w) archive first.height = first.anchor.number
      rw [context.config,source_config]
      rfl
    · change (matchingSnapshot env w first.anchor).isSome = true
      rw [matching_closed_two context.closed]
      rfl
  · change Blocks.WitnessValid (policy env w archive 2) block
    simp only [Blocks.WitnessValid,policy,Finality.derive,context.config,source_config]
    rfl
  · have active := active_one_same context
    change Consensus.CommitValid (policy env w archive 2).consensus env.signature 1 0 201 [vote]
    have sourceCommit : Consensus.CommitValid pol.consensus env.signature 1 0 201 [vote] := first_valid.commit
    unfold Consensus.CommitValid Consensus.ElectionValid Consensus.VoteValid at sourceCommit ⊢
    rw [active]
    have cutoffOne : (Consensus.activeAt pol.consensus 1).cutoff = 1 := by decide +kernel
    simp only [cutoffOne] at sourceCommit ⊢
    simp only [pol,policy,Finality.derive,context.config,source_config,context.lookup,
      Consensus.signedPower] at sourceCommit ⊢
    exact sourceCommit
  · change Forced.step 0 1 2 w.inbox.forcedDelay (some witness) .completedRetained = .accepted 1
    rw [delay]
    decide +kernel
  · rfl
  · exact first_valid.schedule
  · change ((matchingSnapshot env w first.anchor).map fun s => decide (s.schedule = block.schedule)).getD false = true
    rw [matching_closed_two context.closed]
    rfl
  · exact first_valid.notStopped
  · exact first_valid.execution
  · exact first_valid.payload
  · rfl
  · exact first_valid.fields
  · intro wit carried
    have same : wit = witness := by simpa [block,body] using carried.symm
    subst wit
    change ((matchingSnapshot env w first.anchor).map fun s => decide ((witness.index,witness.stored) ∈ s.queue) &&
      witness.storageAuthenticated).getD false = true
    rw [matching_closed_two context.closed]
    decide +kernel
  · change w.inbox.committeeConfig = 0
    exact context.committee
  · rfl

theorem ready_in_context {w : World} (trace : Trace env (empty env registry) w)
    (context : TemplateContext w) : Finality.Ready (config w) w.registry.registry archive 1 := by
  rw [context.config,source_config]
  refine ⟨by decide,by decide,by decide,?_,by decide,
    (Economics.registry_history_time registry_genesis trace).1,by decide,?_⟩
  · intro header member
    have same : header = first := by simpa [archive] using member
    subst header
    decide +kernel
  · change (RegistryHistory.latestSnapshot w.registry.registry.history 1).isSome = true
    rw [context.latest]
    decide +kernel

theorem batch_binding_in_context {w : World} (context : TemplateContext w) :
    Blocks.statement (policy env w archive 2) genesis [block] [1] = template := by
  have grid : w.inbox.gridK = 1 := congrArg Parameters.gridK context.parameters
  have active := active_one_same context
  have cutoffOne : (Consensus.activeAt pol.consensus 1).cutoff = 1 := by decide +kernel
  unfold Blocks.statement
  change (⟨(policy env w archive 2).consensus.domain,(policy env w archive 2).consensus.generation,
    (policy env w archive 2).committeeConfig,100,0,0,0,
    ⟨0,1,101,201,301,100,2,1,(Consensus.activeAt (policy env w archive 2).consensus 1).cutoff⟩,
    referenceHash env w 2,[1],tableHash w.inbox.gridK w.inbox.generation 0 1 (Blocks.cuts genesis [block])⟩ : StatementData) = template
  rw [active,cutoffOne,context.reference,grid,context.generation]
  simp only [policy,Finality.derive,context.config,source_config,context.committee]
  rfl

set_option maxHeartbeats 400000 in
theorem source_pure_certificate : BatchCertificate env (source env) template archive genesis [block] := by
  have context := template_context (source_reachable env) source_statement
  have policyFixed : policy env (certificateWorld env (source env) 2) archive 2 = pol := by rfl
  refine ⟨?_,?_,?_⟩
  · refine ⟨?_,?_,?_,genesis_bound,?_,?_,?_⟩
    · have ready := ready_in_context (source_reachable env) context
      exact ready
    · change Blocks.BatchValid (policy env (certificateWorld env (source env) 2) archive 2) genesis [block] [1]
      rw [policyFixed]
      exact ⟨⟨first_valid,True.intro⟩,rfl⟩
    · change template = Blocks.statement (policy env (certificateWorld env (source env) 2) archive 2) genesis [block] [1]
      rw [policyFixed]
      exact (batch_binding_in_context context).symm
    · intro b member
      have equal : b = block := by simpa using member
      subst b; exact first_bound
    · intro impossible; exact (impossible rfl).elim
    · refine ⟨genesis,[],rfl,rfl,genesis_bound,rfl,rfl,?_,?_,?_,by decide,?_⟩
      · simp [Archive.Linked,archive,block,body,first,firstBase,genesis,genesisBase,env,Blocks.Block.header]
      · intro h member
        have equal : h = first := by simpa [archive] using member
        subst h; exact first_bound
      · intro b member
        have equal : b = block := by simpa using member
        subst b; rfl
      · intro h member
        have equal : h = first := by simpa [archive] using member
        subst h; decide
  · rfl
  · rfl

theorem source_view_registry :
    (certificateWorld env (source env) 2).registry.registry.history = closedTwo.registryHistory := by
  have last : (referencePrefix (source env) 2).getLast? = some closedTwo := by
    rw [source_independent_of_verifier]
    rfl
  simp only [certificateWorld,last,Option.getD_some]

set_option maxHeartbeats 400000 in
theorem template_image_certifies {w : World} {a : Landing}
    (trace : Trace env (empty env registry) w) (same : statement env w a = template) :
    ImageCertifies env w 11 (statement env w a) := by
  have context := template_context trace same
  have ref := congrArg (fun d : StatementData => d.input.l1ReferenceBlockNumber) same
  change a.input.l1ReferenceBlockNumber = 2 at ref
  have prefixSame : referencePrefix (source env) 2 = referencePrefix w 2 :=
    reference_hash_binds_prefix reference_binding (source_reference.trans context.reference.symm)
  have viewSame := certificate_world_of_prefix (env := env) prefixSame
  refine ⟨archive,genesis,[block],?_,?_⟩
  · rw [same]
    exact batch_certificate_transport prefixSame source_pure_certificate
  · intro b member
    have equal : b = block := by simpa using member
    subst b; decide

theorem recovered_source_independent : recoveredSource env = recoveredSource baseEnv := by
  have advanceSame (w : World) (n : Nat) := seed_calls_independent w (.advance n) (by intro x impossible; cases impossible)
  have recoverSame (w : World) := seed_calls_independent w (.recover recoveryRequest) (by intro x impossible; cases impossible)
  simp only [recoveredSource,recovered,beforeRecovery,advanceSame,recoverSame,source_independent_of_verifier]

def recoveredSnapshots : List Snapshot := knownSnapshots ++ [closedThree,closedFour]

theorem recovered_history : (recoveredSource baseEnv).history = recoveredSnapshots := by rfl

theorem second_bound : HashBound env second := by
  change headerCommitment second = 102
  decide +kernel

theorem closed_four_label : env.stateRoot closedFour = 4 := by
  have different (s : Snapshot) (neq : s.number ≠ 4) : Encoding.snapshot closedFour ≠ Encoding.snapshot s := by
    intro eq
    have numbers := congrArg Snapshot.number (Encoding.snapshot_eq.mp eq)
    exact neq numbers.symm
  have n0 := different (snapshot baseEnv (registered baseEnv) 0) (by decide)
  have n1 := different (snapshot baseEnv (registered baseEnv) 1) (by decide)
  have n2 := different closedTwo (by decide)
  have n3 := different closedThree (by decide)
  change Encoding.relabel [Encoding.snapshot (snapshot baseEnv (registered baseEnv) 0),
    Encoding.snapshot (snapshot baseEnv (registered baseEnv) 1),Encoding.snapshot closedTwo,
    Encoding.snapshot closedThree,Encoding.snapshot closedFour] Encoding.Tree.code (Encoding.snapshot closedFour) = 4
  rw [label_tail _ _ _ _ n0,label_tail _ _ _ _ n1,label_tail _ _ _ _ n2,label_tail _ _ _ _ n3,label_head]

theorem closed_four_anchor : anchor env closedFour = second.anchor := by
  change (⟨4,4,env.stateRoot closedFour,1,101,1,1⟩ : BlockValidity.Anchor) = _
  rw [closed_four_label]
  rfl

theorem recovered_reference : referenceHash env (recoveredSource env) 4 = 26 := by
  rw [recovered_source_independent]
  have take : (recoveredSource baseEnv).history.take 5 = (recoveredSource baseEnv).history := by
    rw [recovered_history]
    rfl
  change Encoding.pair (prefixCommitment ((recoveredSource baseEnv).history.take 5)) 4 = 26
  rw [take]
  have different : Encoding.list Encoding.snapshot (recoveredSource baseEnv).history ≠
      Encoding.list Encoding.snapshot (source baseEnv).history := by
    intro eq
    have history := Encoding.list_injective Encoding.snapshot (fun eq => Encoding.snapshot_eq.mp eq) eq
    have lengths := congrArg List.length history
    change 5 = 3 at lengths
    contradiction
  change Encoding.pair (Encoding.relabel _ _ _) 4 = 26
  rw [label_tail _ _ _ _ different,label_head]
  rfl

theorem matching_closed_four {w : World} (present : closedFour ∈ w.history) :
    matchingSnapshot env w second.anchor = some closedFour := by
  change w.history.find? (fun s => anchor env s == second.anchor) = some closedFour
  apply find_unique _ _ _ present
  · simp [closed_four_anchor]
  · intro s mem authentic
    have same : anchor env s = second.anchor := by simpa using authentic
    rw [← closed_four_anchor] at same
    exact state_injective (congrArg BlockValidity.Anchor.stateRoot same)

def recoveredArchive : List Header := [second]
def recoveredPolicy : Blocks.Policy := policy env (recoveredSource env) recoveredArchive 4
instance : DecidablePred recoveredPolicy.signature := fun candidate =>
  inferInstanceAs (Decidable (candidate = vote ∨ candidate = recoveredVote))
instance : Decidable (Blocks.HeaderValid recoveredPolicy first recoveredBlock) := inferInstanceAs (Decidable (_ ∧ _))

theorem second_valid : Blocks.Valid recoveredPolicy first recoveredBlock := by
  constructor
  all_goals first
    | rfl
    | decide +kernel
    | (constructor <;> decide +kernel)
    | (intro wit carried; cases carried)

theorem recovered_config : config (recoveredSource env) = ⟨domain,1,1,4,1,10,unit,unit,1⟩ := by rfl

structure RecoveredContext (w : World) : Prop where
  generation : w.inbox.generation = 1
  parameters : parametersOf w.inbox = baseEnv.parameters
  config : config w = config (recoveredSource env)
  start : w.start = (recoveredSource env).start
  committee : w.inbox.committeeConfig = 0
  closed : closedFour ∈ w.history
  latest : RegistryHistory.latestSnapshot w.registry.registry.history 4 =
    RegistryHistory.latestSnapshot (recoveredSource env).registry.registry.history 4
  reference : referenceHash env w 4 = 26
  lookup : Finality.registryAt w.registry.registry 4 = Finality.registryAt (recoveredSource env).registry.registry 4

theorem recovered_source_statement : statement env (recoveredSource env) recoveredLanding = recoveredTemplate := by
  change (⟨domain,1,0,101,201,301,1,recoveredLanding.input,referenceHash env (recoveredSource env) 4,[1],
    ⟨1,1,2,[]⟩⟩ : StatementData) = recoveredTemplate
  rw [recovered_reference]
  rfl

theorem recovered_context {w : World} {a : Landing}
    (trace : Trace env (empty env registry) w) (same : statement env w a = recoveredTemplate) :
    RecoveredContext w := by
  have gen := congrArg StatementData.generation same
  change w.inbox.generation = 1 at gen
  have ref := congrArg (fun d : StatementData => d.input.l1ReferenceBlockNumber) same
  change a.input.l1ReferenceBlockNumber = 4 at ref
  have hash := congrArg StatementData.referenceHash same
  change referenceHash env w a.input.l1ReferenceBlockNumber = 26 at hash
  rw [ref,← recovered_reference] at hash
  have refCut := reference_hash_binds_prefix reference_binding hash
  have sourcePrefix : referencePrefix (recoveredSource env) 4 = recoveredSnapshots := by
    rw [recovered_source_independent]
    change (recoveredSource baseEnv).history.take 5 = recoveredSnapshots
    rw [recovered_history]
    rfl
  rw [sourcePrefix] at refCut
  have closed : closedFour ∈ w.history := List.mem_of_mem_take (show closedFour ∈ referencePrefix w 4 from by
    rw [refCut]
    simp [recoveredSnapshots])
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
  have currentConfig : config w = config (recoveredSource env) := by
    rw [recovered_config]
    have epoch : w.inbox.epochLen = 10 := congrArg Parameters.epochLen pars
    have cutoff : w.inbox.genesisCutoff = 1 := congrArg Parameters.genesisCutoff pars
    have committee : w.inbox.configuration = baseEnv.parameters.committee := congrArg Parameters.committee pars
    change (⟨w.inbox.domain,w.inbox.generation,w.inbox.origin.height,w.inbox.origin.l1Block,
      w.inbox.genesisCutoff,w.inbox.epochLen,w.inbox.configuration.unit,
      w.inbox.configuration.minimum,w.inbox.configuration.nMax⟩ : Finality.Config) = _
    rw [domainFixed,gen,origin,epoch,cutoff,committee]
    rfl
  have latest : RegistryHistory.latestSnapshot w.registry.registry.history 4 =
      RegistryHistory.latestSnapshot (recoveredSource env).registry.registry.history 4 := by
    have history := (Economics.closed_registry_history trace closedFour closed).2
    change w.registry.registry.history.filter (fun cp => decide (cp.block ≤ 4)) =
      closedFour.registryHistory.filter (fun cp => decide (cp.block ≤ 4)) at history
    rw [← latest_bounded_filter w.registry.registry.history (show 4 ≤ 4 from by decide),history,
      latest_bounded_filter closedFour.registryHistory (show 4 ≤ 4 from by decide)]
    rw [recovered_source_independent]
    rfl
  have lookup : Finality.registryAt w.registry.registry 4 = Finality.registryAt (recoveredSource env).registry.registry 4 := by
    unfold Finality.registryAt
    rw [latest]
  exact ⟨gen,pars,currentConfig,metadata.1,congrArg StatementData.config same,closed,latest,
    hash.trans recovered_reference,lookup⟩

theorem active_two_same {w : World} (context : RecoveredContext w) :
    Consensus.activeAt (policy env w recoveredArchive 4).consensus 2 = Consensus.activeAt recoveredPolicy.consensus 2 := by
  simp [recoveredPolicy,policy,context.config,recovered_config,Finality.derive,Consensus.activeAt,
    Consensus.epoch,Consensus.switchHeight,Consensus.initial,Consensus.selected,context.lookup]


theorem second_valid_in_context {w : World} (context : RecoveredContext w) :
    Blocks.Valid (policy env w recoveredArchive 4) first recoveredBlock := by
  have grid : w.inbox.gridK = 1 := congrArg Parameters.gridK context.parameters
  have epoch : w.inbox.epochLen = 10 := congrArg Parameters.epochLen context.parameters
  have committee : w.inbox.configuration = baseEnv.parameters.committee := congrArg Parameters.committee context.parameters
  have delay : w.inbox.forcedDelay = 1 := congrArg Parameters.forcedDelay context.parameters
  have age : w.inbox.maxAnchorAge = 1152 := congrArg Parameters.maxAnchorAge context.parameters
  constructor
  · change Committee.configOK w.inbox.gridK w.inbox.epochLen w.inbox.configuration.unsettled = true
    rw [grid,epoch,committee]
    decide +kernel
  · change (config w).originHeight ≤ first.height
    rw [context.config,recovered_config]
    decide +kernel
  · have fixedConfig := context.config.trans recovered_config
    simp only [Blocks.HeaderValid,policy,Finality.derive,fixedConfig,env,baseEnv]
    decide +kernel
  · constructor
    · change Blocks.ParentAnchorValid (policy env w recoveredArchive 4) first recoveredBlock
      simp only [Blocks.ParentAnchorValid,policy,Finality.derive,context.config,recovered_config]
      rfl
    · change (config w).originBlock ≤ second.anchor.number
      rw [context.config,recovered_config]
      decide +kernel
    · change second.anchor.number ≤ 4
      decide +kernel
    · decide +kernel
    · change second.anchor.generation = w.inbox.generation
      rw [context.generation]
      rfl
    · decide +kernel
    · change second.timestamp-second.anchor.timestamp ≤ w.inbox.maxAnchorAge
      rw [age]
      decide +kernel
    · change second.height-second.anchor.checkpointHeight ≤ w.inbox.configuration.unsettled
      rw [committee]
      decide +kernel
    · change Finality.anchorAt (config w) recoveredArchive second.height = second.anchor.number
      rw [context.config,recovered_config]
      rfl
    · change (matchingSnapshot env w second.anchor).isSome = true
      rw [matching_closed_four context.closed]
      rfl
  · change Blocks.WitnessValid (policy env w recoveredArchive 4) recoveredBlock
    simp only [Blocks.WitnessValid,policy,Finality.derive,context.config,recovered_config]
    rfl
  · have active := active_two_same context
    change Consensus.CommitValid (policy env w recoveredArchive 4).consensus env.signature 2 0 202 [recoveredVote]
    have sourceCommit : Consensus.CommitValid recoveredPolicy.consensus env.signature 2 0 202 [recoveredVote] := second_valid.commit
    unfold Consensus.CommitValid Consensus.ElectionValid Consensus.VoteValid at sourceCommit ⊢
    rw [active]
    have cutoffOne : (Consensus.activeAt recoveredPolicy.consensus 2).cutoff = 4 := by decide +kernel
    simp only [cutoffOne] at sourceCommit ⊢
    simp only [recoveredPolicy,policy,Finality.derive,context.config,recovered_config,context.lookup,
      Consensus.signedPower] at sourceCommit ⊢
    exact sourceCommit
  · change Forced.step 1 1 4 w.inbox.forcedDelay none .completedRetained = .accepted 1
    rw [delay]
    decide +kernel
  · rfl
  · exact second_valid.schedule
  · change ((matchingSnapshot env w second.anchor).map fun s => decide (s.schedule = recoveredBlock.schedule)).getD false = true
    rw [matching_closed_four context.closed]
    rfl
  · exact second_valid.notStopped
  · exact second_valid.execution
  · exact second_valid.payload
  · rfl
  · exact second_valid.fields
  · intro wit carried
    cases carried
  · change w.inbox.committeeConfig = 0
    exact context.committee
  · rfl

theorem ready_recovered_context {w : World} (trace : Trace env (empty env registry) w)
    (context : RecoveredContext w) : Finality.Ready (config w) w.registry.registry recoveredArchive 2 := by
  rw [context.config,recovered_config]
  refine ⟨by decide,by decide,by decide,?_,by decide,
    (Economics.registry_history_time registry_genesis trace).1,by decide,?_⟩
  · intro header member
    have same : header = second := by simpa [recoveredArchive] using member
    subst header
    decide +kernel
  · change (RegistryHistory.latestSnapshot w.registry.registry.history 4).isSome = true
    rw [context.latest]
    decide +kernel

theorem recovered_binding_in_context {w : World} (context : RecoveredContext w) :
    Blocks.statement (policy env w recoveredArchive 4) first [recoveredBlock] [1] = recoveredTemplate := by
  have grid : w.inbox.gridK = 1 := congrArg Parameters.gridK context.parameters
  have active := active_two_same context
  have cutoffOne : (Consensus.activeAt recoveredPolicy.consensus 2).cutoff = 4 := by decide +kernel
  unfold Blocks.statement
  change (⟨(policy env w recoveredArchive 4).consensus.domain,(policy env w recoveredArchive 4).consensus.generation,
    (policy env w recoveredArchive 4).committeeConfig,101,201,301,1,
    ⟨1,2,102,202,302,101,4,1,(Consensus.activeAt (policy env w recoveredArchive 4).consensus 2).cutoff⟩,
    referenceHash env w 4,[1],tableHash w.inbox.gridK w.inbox.generation 1 2 (Blocks.cuts first [recoveredBlock])⟩ : StatementData) = recoveredTemplate
  rw [active,cutoffOne,context.reference,grid,context.generation]
  simp only [policy,Finality.derive,context.config,recovered_config,context.committee]
  rfl

theorem recovered_source_reachable : Trace env (empty env registry) (recoveredSource env) := by
  have landedTrace : Trace env (empty env registry) (landed (source env) landing) := by
    have call := Step.call (env := env) (source env) (.land landing)
    have actual : transact env (source env) (.land landing) = landed (source env) landing := by
      simp only [transact,execute,source_landing_accepted,Option.getD_some]
    exact .step (source_reachable env) (actual ▸ call)
  exact .step (.step (.step landedTrace (.call _ (.advance 4))) (.call _ (.recover recoveryRequest)))
    (.call _ (.advance 5))

set_option maxHeartbeats 400000 in
theorem recovered_pure_certificate : BatchCertificate env (recoveredSource env) recoveredTemplate recoveredArchive first [recoveredBlock] := by
  have context := recovered_context (show Trace env (empty env registry) (recoveredSource env) from recovered_source_reachable) recovered_source_statement
  have policyFixed : policy env (certificateWorld env (recoveredSource env) 4) recoveredArchive 4 = recoveredPolicy := by rfl
  refine ⟨?_,?_,?_⟩
  · refine ⟨?_,?_,?_,first_bound,?_,?_,?_⟩
    · have ready := ready_recovered_context recovered_source_reachable context
      exact ready
    · change Blocks.BatchValid (policy env (certificateWorld env (recoveredSource env) 4) recoveredArchive 4) first [recoveredBlock] [1]
      rw [policyFixed]
      exact ⟨⟨second_valid,True.intro⟩,rfl⟩
    · change recoveredTemplate = Blocks.statement (policy env (certificateWorld env (recoveredSource env) 4) recoveredArchive 4) first [recoveredBlock] [1]
      rw [policyFixed]
      exact (recovered_binding_in_context context).symm
    · intro b member
      have equal : b = recoveredBlock := by simpa using member
      subst b; exact second_bound
    · intro impossible; exact (impossible rfl).elim
    · refine ⟨first,[],rfl,rfl,first_bound,rfl,rfl,?_,?_,?_,by decide,?_⟩
      · simp [Archive.Linked,recoveredArchive,recoveredBlock,recoveredBody,second,first,firstBase,env,Blocks.Block.header]
      · intro h member
        have equal : h = second := by simpa [recoveredArchive] using member
        subst h; exact second_bound
      · intro b member
        have equal : b = recoveredBlock := by simpa using member
        subst b; rfl
      · intro h member
        have equal : h = second := by simpa [recoveredArchive] using member
        subst h; decide
  · rfl
  · rfl

theorem recovered_view_registry :
    (certificateWorld env (recoveredSource env) 4).registry.registry.history = closedFour.registryHistory := by
  have last : (referencePrefix (recoveredSource env) 4).getLast? = some closedFour := by
    rw [recovered_source_independent]
    rfl
  simp only [certificateWorld,last,Option.getD_some]

set_option maxHeartbeats 400000 in
theorem recovered_image_certifies {w : World} {a : Landing}
    (trace : Trace env (empty env registry) w) (same : statement env w a = recoveredTemplate) :
    ImageCertifies env w 11 (statement env w a) := by
  have context := recovered_context trace same
  have ref := congrArg (fun d : StatementData => d.input.l1ReferenceBlockNumber) same
  change a.input.l1ReferenceBlockNumber = 4 at ref
  have prefixSame : referencePrefix (recoveredSource env) 4 = referencePrefix w 4 :=
    reference_hash_binds_prefix reference_binding (recovered_reference.trans context.reference.symm)
  have viewSame := certificate_world_of_prefix (env := env) prefixSame
  refine ⟨recoveredArchive,first,[recoveredBlock],?_,?_⟩
  · rw [same]
    exact batch_certificate_transport prefixSame recovered_pure_certificate
  · intro b member
    have equal : b = recoveredBlock := by simpa using member
    subst b; decide


theorem verifier_sound : VerifierSound env (empty env registry) := by
  refine ⟨fun _ => True,?_,?_⟩
  · intro proofs accepted
    cases proofs with
    | nil => simp [dualOK] at accepted
    | cons proof rest => exact ⟨proof,List.mem_cons_self,True.intro⟩
  · intro w trace a t proof accepted present sound verified
    change decide (proof.image = 11 ∧ (statement env w a = template ∨ statement env w a = recoveredTemplate)) = true at verified
    obtain ⟨image,same⟩ := of_decide_eq_true verified
    rw [image]
    rcases same with ordinary | recovered
    · exact template_image_certifies trace ordinary
    · exact recovered_image_certifies trace recovered

theorem premises : Etna.Statements.Current.Premises env registry engine := by
  refine ⟨primitives,verifier_sound,rfl,signature_refinement,by decide,
    fun w _ => codec_sound w,fun w _ => vote_attribution w,fun _ _ h => h,?_,
    reference_binding,registry_genesis,signature_sound,by decide,?_,by decide +kernel⟩
  · intro id selected present
    have same : selected = definition := by simpa [env,baseEnv] using present.symm
    subst selected
    rfl
  · intro boundary proposal h proof parent earlier accepted
    cases accepted

def AcceptingDeployment : Prop :=
  ∃ e registry engine w t a, Etna.Statements.Current.Premises e registry engine ∧
    Trace e (empty e registry) w ∧ land e w a = some t ∧ w.inbox.head < t.inbox.head ∧
    ∀ x y, e.stateRoot x = e.stateRoot y → x = y

theorem accepting_deployment : AcceptingDeployment :=
  ⟨env,registry,engine,source env,landed (source env) landing,landing,premises,
    source_reachable env,source_landing_accepted,by decide,fun _ _ same => state_injective same⟩

/-- Explicit existential contract, independently mandatory in the package audit. -/
theorem premises_satisfiable :
    ∃ e registry engine w t a, Etna.Statements.Current.Premises e registry engine ∧
      Trace e (empty e registry) w ∧ land e w a = some t ∧ w.inbox.head < t.inbox.head ∧
      ∀ x y, e.stateRoot x = e.stateRoot y → x = y := accepting_deployment

def beforeReference : World :=
  transact env (transact env (imaged env) (.forcedETH 1)) (.advance 3)
def afterReference : World := transact env (source env) (.forcedETH 1)

theorem before_reference_changes_prefix :
    referencePrefix beforeReference 2 ≠ referencePrefix (source env) 2 := by
  intro same
  have balances := congrArg (fun history : List Snapshot =>
    (history[2]?).map (fun s => s.inbox.ethBalance)) same
  change some 1000000001 = some 1000000000 at balances
  contradiction

theorem before_reference_changes_commitment :
    referenceHash env beforeReference 2 ≠ referenceHash env (source env) 2 :=
  different_prefix_changes_reference reference_binding before_reference_changes_prefix

theorem accepted_proofs_bind_template {w : World} {a : Landing}
    (accepted : proofsAccepted env w a = true) : statement env w a = template ∨ statement env w a = recoveredTemplate := by
  have raw := accepted
  simp only [proofsAccepted,dualOK,Bool.and_eq_true,List.all_eq_true] at raw
  cases proofs : a.proofs with
  | nil => simp [proofsAccepted,proofs,dualOK] at accepted
  | cons proof rest =>
    have member : proof ∈ a.proofs := by rw [proofs]; exact List.mem_cons_self
    have verified := raw.1.1.2 _ (List.mem_map_of_mem member)
    simp only [Bool.and_eq_true] at verified
    have bytes := verified.2
    change decide (proof.image = 11 ∧ (statement env w a = template ∨ statement env w a = recoveredTemplate)) = true at bytes
    exact (of_decide_eq_true bytes).2

theorem statement_reference {w : World} {a : Landing} (same : statement env w a = template) :
    referenceHash env w a.input.l1ReferenceBlockNumber = 4 := by
  exact congrArg StatementData.referenceHash same

theorem before_reference_old_proof_rejected : land env beforeReference landing = none := by
  unfold Protocol.land
  split
  next checks =>
    rcases accepted_proofs_bind_template checks.proofs with ordinary | recovered
    · have hashes := statement_reference ordinary
      exact (before_reference_changes_commitment (hashes.trans source_reference.symm)).elim
    · have heights := congrArg (fun d : StatementData => d.input.lastHeight) recovered
      change 1 = 2 at heights
      exact ((by decide : (1 : Nat) ≠ 2) heights).elim
  next => rfl

theorem after_reference_preserves_commitment :
    referenceHash env afterReference 2 = referenceHash env (source env) 2 := rfl

theorem after_reference_landing_accepted :
    land env afterReference landing = some (landed afterReference landing) := by
  have checks : LandingChecks env afterReference landing := ⟨source_landing_checks.initialized,source_landing_checks.started,source_landing_checks.entered,source_landing_checks.origin,source_landing_checks.parentBeforeFrontier,source_landing_checks.progress,source_landing_checks.height,source_landing_checks.parentGrid,source_landing_checks.lastGrid,source_landing_checks.frontierGrid,source_landing_checks.batchSize,source_landing_checks.record,source_landing_checks.generation,source_landing_checks.leafCount,source_landing_checks.frontier,source_landing_checks.cursor,source_landing_checks.head,source_landing_checks.tail,source_landing_checks.service,source_landing_checks.reference,source_landing_checks.referenceAge,source_landing_checks.blobs,source_landing_checks.unzen,source_landing_checks.proofs⟩
  simp only [Protocol.land,checks,ite_true]


def closedAfterReference : World := transact env afterReference (.advance 4)

theorem closed_after_reference_reachable : Trace env (empty env registry) closedAfterReference :=
  .step (.step (source_reachable env) (.call _ (.forcedETH 1))) (.call _ (.advance 4))

theorem closed_after_reference_history : closedAfterReference.history =
    (source env).history ++ [snapshot env afterReference 3] := rfl

theorem closed_after_reference_prefix : referencePrefix closedAfterReference 2 = referencePrefix (source env) 2 := by
  unfold referencePrefix
  rw [closed_after_reference_history,List.take_append_of_le_length (show 3 ≤ (source env).history.length from by decide)]

theorem closed_after_reference_statement : statement env closedAfterReference landing = template := by
  change (⟨domain,0,0,100,0,0,0,landing.input,referenceHash env closedAfterReference 2,[1],⟨0,0,1,[]⟩⟩ : StatementData) = template
  have hashes : referenceHash env closedAfterReference 2 = referenceHash env (source env) 2 :=
    congrArg (fun history => env.blockHash history 2) closed_after_reference_prefix
  rw [hashes,source_reference]
  rfl

theorem closed_after_reference_checks : LandingChecks env closedAfterReference landing := by
  constructor
  case proofs =>
    simp only [proofsAccepted,closed_after_reference_statement]
    decide +kernel
  all_goals first | rfl | decide +kernel

theorem closed_after_reference_landing :
    land env closedAfterReference landing = some (landed closedAfterReference landing) := by
  simp only [Protocol.land,closed_after_reference_checks,ite_true]

/-- A changed block strictly beyond the reference has actually closed, and the original
proof still settles under the complete global deployment premise record. -/
theorem accepting_after_closed_reference_change :
    Etna.Statements.Current.Premises env registry engine ∧
    Trace env (empty env registry) closedAfterReference ∧
    3 < closedAfterReference.history.length ∧
    land env closedAfterReference landing = some (landed closedAfterReference landing) :=
  ⟨premises,closed_after_reference_reachable,by decide,closed_after_reference_landing⟩

def firstLanded : World := landed (source env) landing

def rolledBack : World :=
  (rollback env firstLanded 7 (source env).inbox.checkpoint 1).getD firstLanded

theorem positive_rollback : rollback env firstLanded 7 (source env).inbox.checkpoint 1 = some rolledBack := by rfl

theorem rollback_then_landing_accepted :
    land env rolledBack landing = some (landed rolledBack landing) := by
  have checks : LandingChecks env rolledBack landing := ⟨source_landing_checks.initialized,source_landing_checks.started,source_landing_checks.entered,source_landing_checks.origin,source_landing_checks.parentBeforeFrontier,source_landing_checks.progress,source_landing_checks.height,source_landing_checks.parentGrid,source_landing_checks.lastGrid,source_landing_checks.frontierGrid,source_landing_checks.batchSize,source_landing_checks.record,source_landing_checks.generation,source_landing_checks.leafCount,source_landing_checks.frontier,source_landing_checks.cursor,source_landing_checks.head,source_landing_checks.tail,source_landing_checks.service,source_landing_checks.reference,source_landing_checks.referenceAge,source_landing_checks.blobs,source_landing_checks.unzen,source_landing_checks.proofs⟩
  simp only [Protocol.land,checks,ite_true]


theorem first_landed_reachable : Trace env (empty env registry) firstLanded := by
  have call := Step.call (env := env) (source env) (.land landing)
  have actual : transact env (source env) (.land landing) = firstLanded := by
    simp only [transact,execute,source_landing_accepted,Option.getD_some,firstLanded]
  exact .step (source_reachable env) (actual ▸ call)

/-! An import at a landed checkpoint above the origin. After the first landing, s = 1 > o = 0, so
DATA-5.4-3/5's validator-state checks apply: the candidate reports the preimage of 301 as
authenticated, and the same candidate without it is rejected. With U = 10 the window
max(o, s − U + 1)..s reaches the origin; window truncation is covered by unit regressions. -/
def landedClosed : World := transact env firstLanded (.advance 4)
def landedObserved : World := transact env landedClosed (.observe 3)
def windowedCandidate : Import.Candidate := ⟨0,0,1,101,101,true,true,true,true,true,true,true,true⟩
def landedImported : World := transact env landedObserved (.importSnapshot windowedCandidate true)

/-- The windowed import is realized under the complete premise record on an actual trace:
it installs headers 0..1, grants no trust or signing readiness, and is rejected without an
authenticated validator-state preimage. -/
theorem windowed_import_satisfiable :
    ∃ (e : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
      (before after : World) (candidate : Import.Candidate),
      Etna.Statements.Current.Premises e registry engine ∧
      Trace e (empty e registry) before ∧ candidate.origin < candidate.height ∧
      nodeImport e before candidate true = some after ∧
      Trace e (empty e registry) after ∧ after.node.importedHeaders = [0,1] ∧
      nodeImport e before { candidate with valStateAuthenticated := false } true = none ∧
      after.node.signer.ready = false ∧ after.node.trusted = false := by
  have closed : Trace env (empty env registry) landedClosed :=
    .step first_landed_reachable (Step.call firstLanded (.advance 4))
  have observed : Trace env (empty env registry) landedObserved :=
    .step closed (Step.call landedClosed (.observe 3))
  have imported : Trace env (empty env registry) landedImported :=
    .step observed (Step.call landedObserved (.importSnapshot windowedCandidate true))
  exact ⟨env,registry,engine,landedObserved,landedImported,windowedCandidate,premises,observed,
    by decide,rfl,imported,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel⟩

theorem rolled_back_reachable : Trace env (empty env registry) rolledBack := by
  have call := Step.call (env := env) firstLanded (.rollback 7 (source env).inbox.checkpoint 1)
  have actual : transact env firstLanded (.rollback 7 (source env).inbox.checkpoint 1) = rolledBack := by
    simp only [transact,execute,positive_rollback,Option.getD_some]
  exact .step first_landed_reachable (actual ▸ call)

theorem accepting_after_actual_rollback :
    Etna.Statements.Current.Premises env registry engine ∧
    Trace env (empty env registry) rolledBack ∧
    land env rolledBack landing = some (landed rolledBack landing) :=
  ⟨premises,rolled_back_reachable,rollback_then_landing_accepted⟩

theorem actual_recovery_after_rollback :
    (recover env rolledBack ⟨7,0,0,1,100,[],[],0,none⟩).isSome = true := by decide +kernel

theorem recovered_landing_checks : LandingChecks env (recoveredSource env) recoveredLanding := by
  constructor
  case proofs =>
    simp only [proofsAccepted,recovered_source_statement]
    decide +kernel
  all_goals first | rfl | decide +kernel

theorem recovery_landing_accepted :
    land env (recoveredSource env) recoveredLanding = some (landed (recoveredSource env) recoveredLanding) := by
  simp only [Protocol.land,recovered_landing_checks,ite_true]

theorem recovered_generation_advanced :
    (recoveredSource env).inbox.generation = 1 ∧
    (landed (recoveredSource env) recoveredLanding).inbox.checkpoint.height = 2 := by decide +kernel

/-- Both generations land under the same fully realized global premise record. -/
theorem accepting_after_recovery :
    Etna.Statements.Current.Premises env registry engine ∧
    Trace env (empty env registry) (recoveredSource env) ∧
    (recoveredSource env).inbox.generation = 1 ∧
    land env (recoveredSource env) recoveredLanding = some (landed (recoveredSource env) recoveredLanding) ∧
    (recoveredSource env).inbox.checkpoint.height < (landed (recoveredSource env) recoveredLanding).inbox.checkpoint.height :=
  ⟨premises,recovered_source_reachable,recovered_generation_advanced.1,recovery_landing_accepted,by decide⟩

end Etna.Design.Current.Protocol.NonVacuity
