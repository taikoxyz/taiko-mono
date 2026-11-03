import EtnaStatements.Current
import EtnaProofs.CurrentEncoding
import EtnaProofs.CurrentCheckpointRisk

/-! Full-premise H2 nonvacuity: actual paid stake and authentic equivocation, with
the raw node checkpoint/ancestry fence. This dedicated fixture refuses all L1 proof
bytes and has no accepted EL execution; the independent landing fixtures cover H1.
Its commitments are globally injective ideal Nat encodings, not fixed-width Keccak. -/
namespace Etna.Design.Current.Protocol.RiskNonVacuity
open Etna.Design Etna.Design.Current Protocol
set_option maxRecDepth 30000
set_option maxHeartbeats 12000000

def domain : Domain := ⟨1,2,3,4⟩
def unit : Nat := Committee.minUnit
def vote (block : Hash) : Consensus.Vote := ⟨domain,0,1,0,2,block,7⟩
def registry : RegistryMachine.State where
  ledger := ⟨0,fun _ => none,fun _ => none,fun _ => none,unit,1⟩
  config := {inbox := 3}
  verify := fun key message signature => decide (key = 7 ∧
    ((message = Accountability.evidence (vote 201) ∧ signature = 11) ∨
      (message = Accountability.evidence (vote 202) ∧ signature = 12)))
  registerAuth := fun key owner amount pop => decide (key = 7 ∧ owner = 8 ∧ amount = unit ∧ pop = 1)

def genesis : Header := ⟨0,100,10,0,0,1,⟨0,0,0,0,0,0,0⟩⟩
def first : Header := ⟨1,101,11,201,0,3,⟨2,2,0,0,100,0,0⟩⟩
def other : Header := {first with cometHash := 202}
def baseEnv : Environment where
  core := ⟨domain,7,8,0,2,9⟩
  parameters := ⟨1,10,1,⟨unit,unit,1,10⟩,1,1152,10,1,1,9⟩
  genesisHeader := genesis
  initialSigner := ⟨domain,0,1,[],false,[]⟩
  time := id
  stateRoot := fun _ => 0
  blockHash := fun _ _ => 0
  headerHash := fun _ => 0
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun candidate => candidate = vote 201 ∨ candidate = vote 202
  txHash := fun raw => raw.length
  unzenNextProposal := 1
  archiveAuthenticated := fun _ _ _ => true
  timestampOf := fun _ => 1
  catalogue := fun _ => none
  payload := fun _ _ => true
  verify := fun _ _ _ _ _ => false
  imageRules := fun _ => []
  unzenValid := fun _ _ _ => false
  unzenRoot := fun _ => False
  startImplementation := fun _ => true
  importValid := fun _ _ _ => true
  signBytes := fun _ => 0
  token := RegistryPayments.standardEnvironment 4 9
  initialToken := ⟨fun account => if account = 8 then unit else 0,
    fun owner spender => if owner = 8 ∧ spender = 4 then unit else 0⟩

def deployed (e : Environment) : World := empty e registry
def registered (e : Environment) : World := Protocol.transact e (deployed e) (.registry 8 (.register 7 8 unit 1))
def advanced (e : Environment) : World := Protocol.transact e (registered e) (.advance 2)
def initialized (e : Environment) : World := Protocol.transact e (advanced e) (.initializeInbox 7)
def source (e : Environment) : World := Protocol.transact e (initialized e) (.advance 3)
def closedTwo : Snapshot := snapshot baseEnv (initialized baseEnv) 2

def stateCommitment (s : Snapshot) : Hash :=
  Encoding.relabel [Encoding.snapshot closedTwo] Encoding.Tree.code (Encoding.snapshot s)
def headerCommitment (h : Header) : Hash :=
  Encoding.relabel [Encoding.header genesis,Encoding.header first] Encoding.Tree.code (Encoding.header h)+100
def prefixCommitment (history : List Snapshot) : Hash :=
  Encoding.relabel [Encoding.list Encoding.snapshot (source baseEnv).history] Encoding.Tree.code
    (Encoding.list Encoding.snapshot history)
def env : Environment := {baseEnv with
  stateRoot := stateCommitment
  headerHash := headerCommitment
  headerParent := fun hash => hash-1
  blockHash := fun history number => Encoding.pair (prefixCommitment history) number}

def engine : Finality.Engine :=
  ⟨fun _ _ => ⟨fun _ _ _ => True,fun _ _ _ => True,fun _ _ => {},fun _ _ => none⟩,
    fun _ _ _ => false,false⟩

theorem registry_genesis : RegistryMachine.Genesis registry :=
  ⟨rfl,fun _ => rfl,fun _ => rfl,fun _ => rfl,rfl,rfl⟩
theorem rollback_free : CheckpointRisk.RollbackFreeRun env (empty env registry) (source env) :=
  .call (.call (.call (.call (.refl _) (.registry 8 (.register 7 8 unit 1)) True.intro)
    (.advance 2) True.intro) (.initializeInbox 7) True.intro) (.advance 3) True.intro

theorem genesis_bound : HashBound env genesis := by
  change headerCommitment genesis = 100
  decide +kernel
theorem first_bound : HashBound env first := by
  change headerCommitment first = 101
  decide +kernel
theorem other_bound : HashBound env other := first_bound

theorem primitives : Custody.Primitives env := by
  refine ⟨genesis_bound,?_,?_⟩
  · intro x y hx hy same
    have codes : headerCommitment x = headerCommitment y := hx.trans (same.trans hy.symm)
    have relabelled := Nat.add_right_cancel codes
    have trees := Encoding.relabel_injective _ _ (fun eq => Encoding.tree_code_injective eq) relabelled
    exact Encoding.header_hash_separation (congrArg Encoding.Tree.code trees)
  · intro proposal header proof impossible
    cases impossible

theorem state_injective {x y : Snapshot} (same : env.stateRoot x = env.stateRoot y) : x = y := by
  exact Encoding.snapshot_eq.mp (Encoding.relabel_injective _ _
    (fun eq => Encoding.tree_code_injective eq) same)

theorem reference_binding : ReferenceBinding env := by
  intro a b number same
  have relabelled := (Encoding.pair_injective same).1
  have trees := Encoding.relabel_injective _ _ (fun eq => Encoding.tree_code_injective eq) relabelled
  exact Encoding.list_injective Encoding.snapshot (fun eq => Encoding.snapshot_eq.mp eq) trees

theorem signature_refinement : Finality.SignatureRefinement registry env.signature := by
  intro candidate signed
  change candidate = vote 201 ∨ candidate = vote 202 at signed
  rcases signed with rfl | rfl
  · exact ⟨11,by simp [registry,vote]⟩
  · exact ⟨12,by simp [registry,vote]⟩

theorem signature_sound : Finality.SignatureSound registry env.signature := by
  intro key message signature signed
  have fields : key = 7 ∧ ((message = Accountability.evidence (vote 201) ∧ signature = 11) ∨
      (message = Accountability.evidence (vote 202) ∧ signature = 12)) := of_decide_eq_true signed
  change Finality.signedVote key message = vote 201 ∨ Finality.signedVote key message = vote 202
  rcases fields.2 with a | b
  · left; rw [fields.1,a.1]; rfl
  · right; rw [fields.1,b.1]; rfl

theorem verifier_sound : VerifierSound env (empty env registry) := by
  refine ⟨fun _ => True,?_,?_⟩
  · intro proofs accepted
    cases proofs with
    | nil => simp [dualOK] at accepted
    | cons proof rest => exact ⟨proof,List.mem_cons_self,True.intro⟩
  · intro w reach landing next proof accepted member backend verified
    cases verified

theorem codec_sound (w : World) : ProtocolFinality.CodecSound env w := by
  intro archiveA archiveB referenceA referenceB parent a b validA validB same
  have impossible := validA.execution
  change false = true at impossible
  cases impossible

theorem vote_attribution (w : World) : ProtocolFinality.VoteAttribution engine env w := by
  intro origin blocks reference height chain pair member candidate present
  trivial

theorem premises : Etna.Statements.Current.Premises env registry engine := by
  refine ⟨primitives,verifier_sound,rfl,signature_refinement,by decide,
    fun w _ => codec_sound w,fun w _ => vote_attribution w,fun _ _ h => h,?_,
    reference_binding,registry_genesis,signature_sound,by decide,?_⟩
  · intro id selected present
    cases present
  · intro boundary proposal header proof parent earlier accepted
    cases accepted

def candidate : CheckpointRisk.Candidate env (source env) 1 where
  root := genesis
  beforeCheckpoint := []
  afterCheckpoint := [first]
  rootHeight := rfl
  linked := by
    change (1 = 0+1 ∧ 101-1 = 100 ∧ True)
    decide
  hashes := by
    intro header member
    rcases List.mem_cons.mp member with rfl | later
    · exact genesis_bound
    · have equal : header = first := by simpa using later
      subst header; exact first_bound
  checkpointHeight := rfl
  checkpointHash := rfl
  terminalHeight := rfl
  ready := by decide +kernel
  reference := 2
  closedReference := by decide +kernel
  originBeforeReference := by decide +kernel
  anchorBounds := by
    intro header member
    have equal : header = first := by simpa using member
    subst header; decide +kernel

instance : DecidablePred env.signature := fun v => inferInstanceAs (Decidable (v = vote 201 ∨ v = vote 202))
theorem commit_a : Consensus.CommitValid (policy env (source env) [first] 2).consensus env.signature 1 0 201 [vote 201] := by decide +kernel
theorem commit_b : Consensus.CommitValid (policy env (source env) [other] 2).consensus env.signature 1 0 202 [vote 202] := by decide +kernel

theorem at_risk : StakeRisk.AccountableAtRisk env (source env)
    (policy env (source env) [first] 2).consensus 1 [vote 201] [vote 202] := by
  exact CheckpointRisk.economically_at_risk_of_candidate rollback_free (by decide +kernel)
    primitives verifier_sound candidate registry_genesis rfl (by decide) (by decide)
    signature_refinement (by decide +kernel) (common := []) (moreA := [first]) (moreB := [other])
    rfl (by decide +kernel) commit_a commit_b (by decide)

private theorem label_head {α : Type} [DecidableEq α] (head : α) (code : α → Nat) :
    Encoding.relabel [head] code head = 0 := by simp [Encoding.relabel]

/-- The header's anchor is the actual closed initialization state, not a synthetic
unfunded snapshot supplied to the committee constructor. -/
theorem actual_closed_anchor : anchor env closedTwo = first.anchor := by
  have compact : env.stateRoot closedTwo = 0 := by
    exact label_head (Encoding.snapshot closedTwo) Encoding.Tree.code
  change (⟨2,2,env.stateRoot closedTwo,0,100,0,0⟩ : BlockValidity.Anchor) = _
  rw [compact]
  rfl

def RiskDeployment : Prop :=
  Etna.Statements.Current.Premises env registry engine ∧
  CheckpointRisk.RollbackFreeRun env (empty env registry) (source env) ∧
  (source env).registry.token.balances 4 = unit ∧
  (source env).inbox.checkpoint.height < 1 ∧
  Consensus.CommitValid (policy env (source env) [first] 2).consensus env.signature 1 0 201 [vote 201] ∧
  Consensus.CommitValid (policy env (source env) [other] 2).consensus env.signature 1 0 202 [vote 202] ∧
  StakeRisk.AccountableAtRisk env (source env) (policy env (source env) [first] 2).consensus 1 [vote 201] [vote 202] ∧
  ∀ x y, env.stateRoot x = env.stateRoot y → x = y

theorem risk_deployment : RiskDeployment :=
  ⟨premises,rollback_free,by decide +kernel,by decide +kernel,commit_a,commit_b,at_risk,
    fun _ _ same => state_injective same⟩

/-- Explicit independently inspectable nonvacuity contract for the full-premise
normal-node accountability branch; it asserts no accepted EL landing. -/
theorem risk_profile_satisfiable :
    ∃ (e : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine) (w : World) (h : Nat)
      (candidate : CheckpointRisk.Candidate e w h) (archiveB : List Header)
      (a b : Nat) (votesA votesB : List Consensus.Vote),
      Etna.Statements.Current.Premises e registry engine ∧
      CheckpointRisk.RollbackFreeRun e (empty e registry) w ∧
      w.registry.token.balances e.token.registryAddress = Committee.minUnit ∧
      w.inbox.checkpoint.height < h ∧ a ≠ b ∧
      Consensus.CommitValid (policy e w candidate.headers candidate.reference).consensus e.signature h 0 a votesA ∧
      Consensus.CommitValid (policy e w archiveB candidate.reference).consensus e.signature h 0 b votesB ∧
      StakeRisk.AccountableAtRisk e w (policy e w candidate.headers candidate.reference).consensus h votesA votesB :=
  ⟨env,registry,engine,source env,1,candidate,[other],201,202,[vote 201],[vote 202],
    premises,rollback_free,by decide +kernel,by decide +kernel,by decide,commit_a,commit_b,at_risk⟩

/-- This dedicated publication fixture supplies the decoded adapter's positive
authentication/material results. It exercises actual observe/import calls and the
authorization fence; canonical decoding and stock-store installation remain external. -/
def importCandidate : Import.Candidate := ⟨0,0,0,100,100,true,true,true,true⟩
def observed : World := Protocol.transact env (source env) (.observe 2)
def published : World := Protocol.transact env observed (.importSnapshot importCandidate true)

theorem observed_run : CheckpointRisk.RollbackFreeRun env (empty env registry) observed :=
  .call rollback_free (.observe 2) True.intro
theorem published_run : CheckpointRisk.RollbackFreeRun env (empty env registry) published :=
  .call observed_run (.importSnapshot importCandidate true) True.intro

theorem observed_target : observed.node.target = some (0,(source env).inbox.checkpoint) := by decide +kernel
theorem import_accepted : nodeImport env observed importCandidate true = some published := rfl
theorem import_signer_preserved : published.node.signer = observed.node.signer := rfl
theorem import_header_range : published.node.importedHeaders = [0] := by decide +kernel
theorem import_not_authorized : published.node.signer.ready = false ∧ published.node.trusted = false := by decide +kernel

def ImportDeployment : Prop :=
  Etna.Statements.Current.Premises env registry engine ∧
  Trace env (empty env registry) observed ∧
  nodeImport env observed importCandidate true = some published ∧
  Trace env (empty env registry) published ∧
  published.node.importedHeaders = [0] ∧
  published.node.signer = observed.node.signer ∧
  published.node.signer.ready = false ∧ published.node.trusted = false

theorem import_deployment : ImportDeployment :=
  ⟨premises,observed_run.project,import_accepted,published_run.project,
    import_header_range,import_signer_preserved,import_not_authorized⟩

/-- The successful importer antecedent is realized under the same complete premise
record and actual transaction trajectory as the H2 fixture, without granting signing
readiness/trust or claiming an implementation of external decoding and stores. -/
theorem import_profile_satisfiable :
    ∃ (e : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
      (before after : World) (candidate : Import.Candidate),
      Etna.Statements.Current.Premises e registry engine ∧
      Trace e (empty e registry) before ∧ nodeImport e before candidate true = some after ∧
      Trace e (empty e registry) after ∧ after.node.importedHeaders = [0] ∧
      after.node.signer = before.node.signer ∧
      after.node.signer.ready = false ∧ after.node.trusted = false :=
  ⟨env,registry,engine,observed,published,importCandidate,premises,observed_run.project,
    import_accepted,published_run.project,import_header_range,import_signer_preserved,import_not_authorized⟩

end Etna.Design.Current.Protocol.RiskNonVacuity
