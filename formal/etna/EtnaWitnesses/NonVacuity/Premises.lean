import EtnaProofs.Headline.FundSafety
import EtnaProofs.Headline.AccountableFinality
import EtnaProofs.Headline.ForcedInclusion
import EtnaWitnesses.Regressions.ThirdBatch

/-! Non-vacuity of the headline premises. One deployment and one environment satisfy every field
of `Etna.Statements.Premises`, and a run under them goes through an FI enqueue, two submitted
landings in generation 0 (the first consumes the queued entry), a governance recovery and a
submitted landing in generation 1. So the record is not contradictory, and H1–H3 are not true
only because nothing can happen.

The environment is concrete and decidable. Every relation a premise field constrains is a
non-trivial one:
- `headerHash` is an injective code of the fields an EL header fixes (height, stateRoot,
  timestamp and the whole anchor), so `Premises.headerSeparation` is a theorem about it. The EL
  relation accepts a block exactly when its parent's and its own EL hash are that code.
- the config hash is an injective code of the seven words' bytes, so the stored commitment has
  exactly one representable opening (`Premises.hashSeparation`).
- the L1 is one fixed history: an anchor is authenticated exactly when it is that history's
  block at its number (Inbox checkpoint, generation and FI tail as they were then), and an FI
  witness exactly when it shows the entry L1 stores at its index, below the anchor's tail.
- a vote is signed exactly when it is one of the three precommits the one validator cast (key 7,
  one per height), and the registry verifier accepts exactly those votes' evidence. Nobody else
  holds a key, and key 7 never signs two blocks at one height, so H2's finality hypothesis holds
  with every member honest (`finality_hypothesis_satisfiable`).
- landers submit, on the run's landing Worlds, any call whose certificate is the statement of a
  batch valid under the rules the deployment builds there (`Certifies`): a verifier that accepts
  exactly certified statements. Every backend is sound.
The relations no premise mentions (switch-block registry proofs, payload and blob decoding,
history authentication) accept everything; the run has no switch block. -/
namespace Etna.Design.NonVacuity
open Etna.Statements

/-! ## Injective codes -/

/-- One number for two: 2^b·(2a+1). Every positive number has exactly one such form (b counts
its factors 2), so equal codes have equal arguments. The code grows by b bits, so the small
fields go in `b`. -/
def code (a b : Nat) : Nat := 2^b*(2*a+1)

private theorem code_injective {a b c d : Nat} (same : code a b = code c d) : a = c ∧ b = d := by
  unfold code at same
  have shift : ∀ {a b c k : Nat}, 2^b*(2*a+1) ≠ 2^(b+(k+1))*(2*c+1) := by
    intro a b c k eq
    rw [Nat.pow_add,Nat.mul_assoc] at eq
    have odd := Nat.eq_of_mul_eq_mul_left (Nat.two_pow_pos b) eq
    rw [Nat.pow_succ,Nat.mul_comm (2^k) 2,Nat.mul_assoc] at odd
    omega
  rcases Nat.lt_trichotomy b d with lt | rfl | gt
  · obtain ⟨k,rfl⟩ : ∃ k, d = b+(k+1) := ⟨d-b-1,by omega⟩
    exact absurd same shift
  · have := Nat.eq_of_mul_eq_mul_left (Nat.two_pow_pos b) same
    exact ⟨by omega,rfl⟩
  · obtain ⟨k,rfl⟩ : ∃ k, b = d+(k+1) := ⟨b-d-1,by omega⟩
    exact absurd same.symm shift

/-- An anchor's seven fields as one number (the L1 checkpoint hash, the only large field, is
the innermost argument). -/
def anchorCode (a : BlockValidity.Anchor) : Nat :=
  code (code (code (code (code (code a.checkpointHash a.tail) a.generation) a.checkpointHeight) a.stateRoot)
    a.timestamp) a.number

private theorem anchorCode_injective {a b : BlockValidity.Anchor} (same : anchorCode a = anchorCode b) : a = b := by
  obtain ⟨n,t,r,h,c,g,q⟩ := a
  obtain ⟨n',t',r',h',c',g',q'⟩ := b
  unfold anchorCode at same
  obtain ⟨same,rfl⟩ := code_injective same
  obtain ⟨same,rfl⟩ := code_injective same
  obtain ⟨same,rfl⟩ := code_injective same
  obtain ⟨same,rfl⟩ := code_injective same
  obtain ⟨same,rfl⟩ := code_injective same
  obtain ⟨rfl,rfl⟩ := code_injective same
  rfl

/-- The EL hash of a decoded header: a code of the fields its EL header fixes (height,
stateRoot, timestamp and the anchor). The header's own EL hash, Comet hash and FI cursor are
not inputs. -/
def headerHash (h : BlockValidity.Header) : Hash :=
  code (code (code (anchorCode h.anchor) h.stateRoot) h.timestamp) h.height

/-- Equal header hashes mean equal height, stateRoot, timestamp and anchor
(`Premises.headerSeparation` for this adapter). -/
private theorem headerHash_separates (h₁ h₂ : BlockValidity.Header) (same : headerHash h₁ = headerHash h₂) :
    h₁.height = h₂.height ∧ h₁.stateRoot = h₂.stateRoot ∧ h₁.timestamp = h₂.timestamp ∧ h₁.anchor = h₂.anchor := by
  unfold headerHash at same
  obtain ⟨same,height⟩ := code_injective same
  obtain ⟨same,timestamp⟩ := code_injective same
  obtain ⟨same,root⟩ := code_injective same
  exact ⟨height,root,timestamp,anchorCode_injective same⟩

/-- `h` with its EL hash set to the hash of its fields. -/
def hashed (h : BlockValidity.Header) : BlockValidity.Header := { h with elHash := headerHash h }

/-- Bytes as one number in base 256, each digit shifted past a length marker, so lists of
different lengths or contents differ. -/
def bytesCode : List Encoding.Byte → Nat
  | [] => 0
  | b :: rest => b.val+256*(bytesCode rest+1)

private theorem bytesCode_injective : ∀ {xs ys : List Encoding.Byte}, bytesCode xs = bytesCode ys → xs = ys
  | [], [], _ => rfl
  | [], _ :: _, same => by simp only [bytesCode] at same; omega
  | _ :: _, [], same => by simp only [bytesCode] at same; omega
  | a :: xs, b :: ys, same => by
    simp only [bytesCode] at same
    have ha := a.isLt
    have hb := b.isLt
    have head : a = b := Fin.ext (by omega)
    have tail : bytesCode xs = bytesCode ys := by omega
    rw [head,bytesCode_injective tail]

private theorem flatBytes_injective : ∀ {xs ys : List Encoding.Word},
    Encoding.flatBytes xs = Encoding.flatBytes ys → xs = ys
  | [], [], _ => rfl
  | [], _ :: _, same => by
    have := congrArg List.length same
    simp [Encoding.flatBytes] at this <;> omega
  | _ :: _, [], same => by
    have := congrArg List.length same
    simp [Encoding.flatBytes] at this <;> omega
  | x :: xs, y :: ys, same => by
    simp only [Encoding.flatBytes,List.flatMap_cons] at same
    obtain ⟨head,tail⟩ := List.append_inj same (by simp)
    rw [Vector.toList_inj.mp head,flatBytes_injective tail]

/-- The committeeConfigHash adapter: an injective code of the config words' bytes. -/
def configHash (words : List Encoding.Word) : Hash := bytesCode (Encoding.flatBytes words)

private theorem configHash_injective {xs ys : List Encoding.Word} (same : configHash xs = configHash ys) : xs = ys :=
  flatBytes_injective (bytesCode_injective same)

/-! ## The validator's votes and the registry's verifier -/

/-- Key 7's round-0 precommit for Comet block `blockId` at `height` of `generation`. -/
def vote (generation height blockId : Nat) : Consensus.Vote := ⟨FirstBatch.deployment,generation,height,0,2,blockId,7⟩

/-- Every vote anyone signed: the run's three precommits, one per height. -/
def castVotes : List Consensus.Vote := [vote 0 1 101,vote 0 2 102,vote 1 3 103]

/-- The consensus signature relation: a vote carries a valid signature exactly when it was cast. -/
def signed (v : Consensus.Vote) : Prop := v ∈ castVotes

instance : DecidablePred signed := fun v => inferInstanceAs (Decidable (v ∈ castVotes))

/-- The registry's signature check: key `key` signed evidence `evidence` exactly when a cast vote
by that key has that evidence view. The signature bytes are not decoded. -/
def verifyVotes (key : Hash) (evidence : Staking.Vote) (_signature : Hash) : Bool :=
  castVotes.any fun v => v.key == key && Accountability.evidence v == evidence

/-! ## The deployment -/

/-- Block 0's header: stateRoot 50, L1 block 14 (the Inbox's initialization block). Its anchor is
never authenticated (block 0 is not landed). -/
def genesisHeader : BlockValidity.Header := hashed ⟨0,0,50,0,0,14,⟨14,14,24,0,0,0,0⟩⟩

def record0 : Checkpoint := ⟨0,genesisHeader.elHash,0,0,0,0⟩

/-- ThirdBatch's registry (key 7, owner 51, 1 TAIKO, registered at L1 block 10, active from 12)
with this verifier. -/
def emptyRegistry : RegistryHistory.State := { SecondBatch.emptyRegistry with verify := verifyVotes }
def registry0 : RegistryHistory.State :=
  (RegistryHistory.register emptyRegistry 7 51 1000000000000000000 10).getD emptyRegistry

/-- The seven committeeConfigHash words of the deployed configuration (ThirdBatch's: vp_unit
10^9, s_min 1 TAIKO, n_max 3, U = 100) in this deployment's domain. -/
def configWords0 : List Encoding.Word :=
  Encoding.configWords FirstBatch.deployment.l2ChainId FirstBatch.deployment.registry ThirdBatch.cfgD.unit
    ThirdBatch.cfgD.minimum ThirdBatch.cfgD.nMax ThirdBatch.cfgD.unsettled

/-- ThirdBatch's deployed Inbox with L = 10, the injective config commitment and block 0's
header. -/
def inbox0 : State :=
  { ThirdBatch.deployedInbox with
    committeeConfig := configHash configWords0,
    epochLen := 10,checkpoint := record0,records := [record0],signals := [⟨0,genesisHeader.elHash,50⟩] }

/-- The initialized World at L1 block 14. -/
def world0 : ProtocolState.World :=
  ⟨inbox0,registry0,[],Committee.recoverySchedule ThirdBatch.zeroRecord,14,
    ⟨configHash,fun _ => 12,SecondBatch.recoveryConfig⟩⟩

/-! ## The run -/

/-- L1 block 15: someone enqueues a 10-byte transaction with hash 50, paying the 1 gwei fee. -/
def entry0 : Forced.Entry := ⟨50,15,15⟩
def inboxQ : State := (Forced.enqueue world0.inbox 10 1000000000 true).getD world0.inbox
def worldQ : ProtocolState.World := ProtocolState.enqueued world0 inboxQ 50 15 15

/-- The witness for entry 0: its stored value, and its raw bytes as block transaction 0. -/
def witness0 : Forced.Witness := ⟨0,entry0,true,50,10,true,some 50,true,10⟩

/-- L1 block 15's anchor: the Inbox at checkpoint 0 with entry 0 enqueued. -/
def anchor15 : BlockValidity.Anchor := ⟨15,15,25,0,genesisHeader.elHash,0,1⟩

def proofs : List (Backend × Bool) := [(.risc0,true),(.sp1,true)]

/-- Block 1 (generation 0) on block 0: it carries entry 0 as transaction 0, so the FI cursor
moves 0 → 1. Anchor L1 block 15, BFT time 15. -/
def block1 : BlockValidity.Block :=
  ⟨hashed ⟨1,0,51,101,1,15,anchor15⟩,genesisHeader.elHash,none,FirstBatch.deployment,0,15,
    100,100,true,none,12,12,25,0,[vote 0 1 101],some witness0,.completedEmpty⟩

/-- L1 block 17's anchor: checkpoint 1 landed in that block. -/
def anchor17 : BlockValidity.Anchor := ⟨17,17,27,1,block1.header.elHash,0,1⟩

/-- Block 2 (generation 0) on block 1; the queue is served (cursor 1 = tail). -/
def block2 : BlockValidity.Block :=
  ⟨hashed ⟨2,0,52,102,1,17,anchor17⟩,block1.header.elHash,some 101,FirstBatch.deployment,0,17,
    100,100,true,none,12,12,27,0,[vote 0 2 102],none,.completedEmpty⟩

/-- L1 block 21's anchor: checkpoint 2, generation 1 (the recovery ran in L1 block 20). -/
def anchor21 : BlockValidity.Anchor := ⟨21,21,31,2,block2.header.elHash,1,1⟩

/-- Block 3, the first block of generation 1, on block 2 (the recovery's checkpoint). -/
def block3 : BlockValidity.Block :=
  ⟨hashed ⟨3,0,53,103,1,21,anchor21⟩,block2.header.elHash,none,FirstBatch.deployment,1,21,
    100,100,true,none,12,12,31,0,[vote 1 3 103],none,.completedEmpty⟩

/-- The L1 history: the anchor of L1 block `n` shows the Inbox as it was after that block (the
enqueue in 15, landings in 17, 19 and 23, the recovery in 20). L1 stateRoots and timestamps are
placeholders. -/
def l1Anchor (n : Nat) : BlockValidity.Anchor :=
  if n < 15 then ⟨n,n,n+10,0,genesisHeader.elHash,0,0⟩
  else if n < 17 then ⟨n,n,n+10,0,genesisHeader.elHash,0,1⟩
  else if n < 19 then ⟨n,n,n+10,1,block1.header.elHash,0,1⟩
  else if n < 20 then ⟨n,n,n+10,2,block2.header.elHash,0,1⟩
  else if n < 23 then ⟨n,n,n+10,2,block2.header.elHash,1,1⟩
  else ⟨n,n,n+10,3,block3.header.elHash,1,1⟩

/-- The FI queue L1 stores: entry 0, never changed. -/
def l1Queue : List (Nat × Forced.Entry) := [(0,entry0)]

/-- The environment's relations; landers submit nothing yet (`env` adds the landings). -/
def relations : Environment where
  signature := signed
  anchorAuthenticated := fun a => decide (a = l1Anchor a.number)
  committeeAuthenticated := fun _ _ => true
  executionValid := fun p b => decide (p.elHash = headerHash p ∧ b.header.elHash = headerHash b.header)
  payloadValid := fun _ => true
  forcedAuthenticated := fun a w => decide ((w.index,w.stored) ∈ l1Queue ∧ w.index < a.tail)
  batchPayloadValid := fun _ _ => true
  historyAuthenticated := fun _ _ => true
  headerHash := headerHash
  genesisHeader := genesisHeader
  submits := fun _ _ _ _ => False

/-- The rules `Deployment.build` derives on `w` from its stored configuration, archive `archive`
and `env`'s template at reference block `number` with hash `hash` (`build_rulesFor`). -/
def rulesFor (env : Environment) (w : ProtocolState.World) (archive : List Nat) (number hash : Nat) :
    BlockValidity.Rules :=
  { env.template number hash with
    consensus := HistoricalContext.derive w.inbox w.registry (Deployment.parameters w.inbox w.inbox.configuration) archive,
    gridK := w.inbox.gridK,committeeConfig := w.inbox.committeeConfig,maxAnchorAge := w.inbox.maxAnchorAge,
    forcedDelay := w.inbox.forcedDelay,unsettled := w.inbox.configuration.unsettled,
    configHash := w.adapters.configHash,committeeHash := w.adapters.recordHash }

/-- `rulesFor` is what `Deployment.build` returns when its guard and the history context's
`Ready` hold (both decidable, checked per World by the kernel). -/
theorem build_rulesFor {env : Environment} {w : ProtocolState.World} {archive : List Nat} {number hash : Nat}
    (guard : Deployment.Constraints w.inbox w.inbox.configuration ∧ w.inbox.configuration = w.inbox.configuration ∧
      w.inbox.committeeConfig = w.adapters.configHash (Deployment.words w.inbox w.inbox.configuration) ∧
      Deployment.genesis w.inbox w.registry w.inbox.configuration archive = w.inbox.committeeZeroRecord ∧
      Deployment.GenesisElected w.inbox w.registry w.inbox.configuration ∧
      w.inbox.committeeZero = w.adapters.recordHash w.inbox.committeeZeroRecord ∧ Deployment.RegistryConstraints w.registry)
    (ready : HistoricalContext.Ready w.inbox w.registry (Deployment.parameters w.inbox w.inbox.configuration) archive) :
    Deployment.build w w.inbox.configuration archive (env.template number hash) =
      some (rulesFor env w archive number hash) := by
  unfold Deployment.build HistoricalContext.build
  rw [ite_eq_left guard,ite_eq_left ready]
  rfl

/-! L1 block 17: land (0, 1] on `worldQ`. -/

def archive0 : List Nat := [14,15]
def rules0 : BlockValidity.Rules := rulesFor relations worldQ archive0 16 1600
instance : DecidablePred rules0.signature := fun v => inferInstanceAs (Decidable (signed v))

def statement1 : StatementData := Settlement.statement rules0 genesisHeader [block1] [111]
def env1 : LandingEnv := ⟨17,1600,true,[111],proofs,statement1⟩
def world1 : ProtocolState.World := ProtocolState.landed worldQ (applyLanding worldQ.inbox statement1.input) 17

/-! L1 block 19: land (1, 2] on `world1`. -/

def archive1 : List Nat := [14,15,17]
def rules1 : BlockValidity.Rules := rulesFor relations world1 archive1 18 1800
instance : DecidablePred rules1.signature := fun v => inferInstanceAs (Decidable (signed v))

def statement2 : StatementData := Settlement.statement rules1 block1.header [block2] [111]
def env2 : LandingEnv := ⟨19,1800,true,[111],proofs,statement2⟩
def world2 : ProtocolState.World := ProtocolState.landed world1 (applyLanding world1.inbox statement2.input) 19

/-! L1 block 20: governance recovery at checkpoint 2 (R = L1 block 20), nothing excluded or
blanked. -/

def request1 : Recovery.Request := ⟨0,2,[],[],0,limit256-1⟩
def origin1 : Origin := ⟨2,20,20⟩
def world3 : ProtocolState.World :=
  ProtocolState.recovered world2 request1 origin1
    (Recovery.applyRecovery (ProtocolState.recoveryView world2) request1 SecondBatch.recoveryConfig origin1)

/-! L1 block 23: generation 1 lands (2, 3] on `world3`. -/

def archive3 : List Nat := [14,15,17,21]
def rules3 : BlockValidity.Rules := rulesFor relations world3 archive3 22 2200
instance : DecidablePred rules3.signature := fun v => inferInstanceAs (Decidable (signed v))

def statement3 : StatementData := Settlement.statement rules3 block2.header [block3] [111]
def env3 : LandingEnv := ⟨23,2200,true,[111],proofs,statement3⟩
def world4 : ProtocolState.World := ProtocolState.landed world3 (applyLanding world3.inbox statement3.input) 23

theorem steps_accepted :
    Forced.enqueue world0.inbox 10 1000000000 true = some inboxQ ∧
    land worldQ.inbox statement1.input [] env1 = some (applyLanding worldQ.inbox statement1.input) ∧
    land world1.inbox statement2.input [] env2 = some (applyLanding world1.inbox statement2.input) ∧
    Recovery.recover (ProtocolState.recoveryView world2) request1 world2.adapters.recovery origin1 true true =
      some (Recovery.applyRecovery (ProtocolState.recoveryView world2) request1 SecondBatch.recoveryConfig origin1) ∧
    land world3.inbox statement3.input [] env3 = some (applyLanding world3.inbox statement3.input) := by
  decide +kernel

theorem chains_valid : BlockValidity.Chain rules0 genesisHeader [block1] ∧
    BlockValidity.Chain rules1 block1.header [block2] ∧ BlockValidity.Chain rules3 block2.header [block3] := by
  decide +kernel

/-! ## The environment and the premises -/

/-- Landers submit, on the Worlds the run lands on, any call whose certificate is certified
there: the proof system has proofs exactly for statements of batches valid under the rules the
deployment builds (`Certifies`). -/
def env : Environment :=
  { relations with
    submits := fun w _ _ e => (w = worldQ ∨ w = world1 ∨ w = world3) ∧ Certifies relations w e.certificate }

/-- Each landing's certificate is the statement of a batch valid under the rules built on the
World it lands on, from the stored (representable) configuration. -/
private theorem certified :
    Certifies relations worldQ statement1 ∧ Certifies relations world1 statement2 ∧
    Certifies relations world3 statement3 := by
  refine ⟨⟨worldQ.inbox.configuration,worldQ.inbox.committeeZeroRecord,archive0,rules0,genesisHeader,[block1],[111],
      by unfold Representable; decide +kernel,build_rulesFor (by decide +kernel) (by decide +kernel),⟨chains_valid.1,rfl⟩,rfl⟩,
    ⟨world1.inbox.configuration,world1.inbox.committeeZeroRecord,archive1,rules1,block1.header,[block2],[111],
      by unfold Representable; decide +kernel,build_rulesFor (by decide +kernel) (by decide +kernel),⟨chains_valid.2.1,rfl⟩,rfl⟩,
    ⟨world3.inbox.configuration,world3.inbox.committeeZeroRecord,archive3,rules3,block2.header,[block3],[111],
      by unfold Representable; decide +kernel,build_rulesFor (by decide +kernel) (by decide +kernel),⟨chains_valid.2.2,rfl⟩,rfl⟩⟩

/-- Every premise field holds for the deployment `world0` and the environment `env`. -/
theorem premises : Premises world0 env where
  genesis := by
    refine ⟨⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,by decide,rfl,by unfold FeeConserved; decide +kernel,
      ⟨?_,?_,?_,?_,by decide +kernel⟩,rfl,by decide +kernel,by decide +kernel,by decide +kernel,rfl,rfl,rfl,
      by unfold Deployment.GenesisElected; decide +kernel,by decide +kernel,rfl⟩,rfl,rfl,rfl⟩
    · unfold RegistryHistory.KeysValid
      decide +kernel
    · unfold RegistryHistory.IdentitiesValid
      decide +kernel
    · unfold RegistryHistory.Ordered
      decide +kernel
    · unfold RegistryHistory.CurrentSnapshot
      decide +kernel
  verifierSound := by
    refine ⟨fun _ => True,fun proofs ok => ?_,fun _ _ _ _ _ _ _ submitted _ _ => submitted.2⟩
    match proofs, dual_count ok with
    | q :: _, _ => exact ⟨q,List.mem_cons_self,trivial⟩
  authenticatedInputs := by
    intro w _ _ _ _ submitted _ _ wit _ shown _ _ _
    have stored : (wit.index,wit.stored) ∈ l1Queue := (of_decide_eq_true shown).1
    simp only [l1Queue,List.mem_singleton] at stored
    rw [stored]
    rcases submitted.1 with rfl | rfl | rfl <;> decide +kernel
  hashSeparation := by
    intro cfg representable opened
    have stored : world0.inbox.committeeConfig = configHash configWords0 := rfl
    have adapter : world0.adapters.configHash = configHash := rfl
    have deployed : Deployment.words world0.inbox ThirdBatch.cfgD = configWords0 := rfl
    rw [stored,adapter] at opened
    exact Deployment.representable_words_injective world0.inbox representable (by unfold Representable; decide +kernel)
      ((configHash_injective opened).trans deployed.symm)
  headerHashes := ⟨fun _ _ accepted => of_decide_eq_true accepted,rfl⟩
  headerSeparation := headerHash_separates
  signatureAgreement := by
    refine ⟨fun _ => 0,fun v _ cast => ?_⟩
    show verifyVotes v.key (Accountability.evidence v) 0 = true
    exact List.any_eq_true.mpr ⟨v,cast,by simp⟩

private theorem run1 : Run env world0 worldQ :=
  .other (.refl _) (.enqueue (by decide) (by decide) (by decide) steps_accepted.1) (by decide +kernel)
private theorem run2 : Run env world0 world1 :=
  .landing (i := statement1.input) (leaves := []) (e := env1) run1 ⟨Or.inl rfl,certified.1⟩ (by decide)
    steps_accepted.2.1
private theorem run3 : Run env world0 world2 :=
  .landing (i := statement2.input) (leaves := []) (e := env2) run2 ⟨Or.inr (Or.inl rfl),certified.2.1⟩ (by decide)
    steps_accepted.2.2.1
private theorem run4 : Run env world0 world3 :=
  .other run3 (.recovery (by decide) steps_accepted.2.2.2.1) (by decide +kernel)
private theorem run5 : Run env world0 world4 :=
  .landing (i := statement3.input) (leaves := []) (e := env3) run4 ⟨Or.inr (Or.inr rfl),certified.2.2⟩ (by decide)
    steps_accepted.2.2.2.2

/-- The premise record is satisfiable by a run where things happen. Some deployment and
environment satisfy every field of `Premises`, and a `Run` under them (every landing one the
environment submits) ends in a World with:
- three landing records above block 0's: records enter only through landings, two of them in
  generation 0 and one in generation 1;
- generation 1: only a governance recovery increments the generation;
- the FI head at 1 with entry 0 in the queue, which started empty: an enqueue added the entry
  and a landing moved the head past it (H3: only landings advance the head, through blocks
  that consume the entry). -/
theorem premises_satisfiable : ∃ (w0 : ProtocolState.World) (env : Environment), Premises w0 env ∧
    ∃ w, Run env w0 w ∧ w0.inbox.records.map Checkpoint.height = [0] ∧
      w.inbox.records.map (fun c => (c.height,c.generation,c.cursor)) = [(3,1,1),(2,0,1),(1,0,1),(0,0,0)] ∧
      w0.inbox.generation = 0 ∧ w.inbox.generation = 1 ∧
      w0.queue = [] ∧ w0.inbox.head = 0 ∧ (∃ entry, (0,entry) ∈ w.queue) ∧ w.inbox.head = 1 :=
  ⟨world0,env,premises,world4,run5,by decide +kernel,by decide +kernel,rfl,by decide +kernel,rfl,rfl,
    ⟨entry0,by decide +kernel⟩,by decide +kernel⟩

/-! ## H2's finality half is not vacuous -/

/-- H2's finality hypothesis can hold. Under this environment the signature relation accepts
only cast votes (key 7 never signed block 999 at height 1), and on the World after the recovery
the rules the deployment builds for generation 1 have a valid commit at height 3, round 0,
while no member of the committee equivocates there: with every member honest, the dishonest
power is 0, below a third. H2 (`Etna.Proofs.accountable_finality`) then gives that every two
valid commits at that height and round are for the same block. -/
theorem finality_hypothesis_satisfiable : Premises world0 env ∧ ¬ env.signature (vote 0 1 999) ∧
    ∃ w r, Run env world0 w ∧ Built env w r ∧ ∃ (h round : Nat) (honest : Hash → Bool),
      (∀ m ∈ (Consensus.activeAt r.consensus h).members, honest m.key = true →
        ¬ Equivocates r.consensus r.signature h round m.key) ∧
      3*Committee.totalPower r.consensus.unit
          ((Consensus.activeAt r.consensus h).members.filter fun m => !honest m.key) <
        Committee.totalPower r.consensus.unit (Consensus.activeAt r.consensus h).members ∧
      (∃ a votes, Consensus.CommitValid r.consensus r.signature h round a votes) ∧
      ∀ a b votesA votesB, Consensus.CommitValid r.consensus r.signature h round a votesA →
        Consensus.CommitValid r.consensus r.signature h round b votesB → a = b := by
  have built : Built env world3 rules3 := ⟨archive3,22,2200,build_rulesFor (by decide +kernel) (by decide +kernel)⟩
  have honest : ∀ m ∈ (Consensus.activeAt rules3.consensus 3).members, (fun _ => true : Hash → Bool) m.key = true →
      ¬ Equivocates rules3.consensus rules3.signature 3 0 m.key := by
    rintro m _ _ ⟨va,vb,signedA,signedB,_,_,_,_,_,_,heightA,heightB,_,_,_,_,different⟩
    change va ∈ castVotes at signedA
    change vb ∈ castVotes at signedB
    simp only [castVotes,List.mem_cons,List.not_mem_nil,or_false] at signedA signedB
    rcases signedA with rfl | rfl | rfl <;> rcases signedB with rfl | rfl | rfl <;>
      simp [vote] at heightA heightB different
  have power : 3*Committee.totalPower rules3.consensus.unit
      ((Consensus.activeAt rules3.consensus 3).members.filter fun m => !(fun _ => true : Hash → Bool) m.key) <
      Committee.totalPower rules3.consensus.unit (Consensus.activeAt rules3.consensus 3).members := by decide +kernel
  refine ⟨premises,by show ¬ signed (vote 0 1 999); decide,world3,rules3,run4,built,3,0,fun _ => true,honest,power,
    ⟨block3.header.cometHash,block3.votes,chains_valid.2.2.1.2.2.2.2.2.1⟩,?_⟩
  exact (Etna.Proofs.accountable_finality env world0 premises world3 (Etna.Proofs.run_trace run4) rules3 built).2
    3 0 (fun _ => true) honest power

/-! ## A Byzantine minority: H2's finality with an actual double sign

The deployment above has one validator, so nobody can double-sign without holding all the
power. Here a second deployment (same adapters, Inbox and relations) has three validators with
3, 2 and 1 TAIKO; key 9 (1/6 of the power) signs two blocks at height 1, round 0. Its landers
submit nothing: H2 ranges over every protocol trace, so the submission fields play no role. -/

def member9 : Committee.Entry := ⟨9,1000000000000000000,12,Staking.noExit⟩
def member7 : Committee.Entry := ⟨7,3000000000000000000,12,Staking.noExit⟩
def member8 : Committee.Entry := ⟨8,2000000000000000000,12,Staking.noExit⟩
def minorityMembers : List Committee.Entry := [member7,member8,member9]

/-- Key `key`'s round-0 precommit for Comet block `blockId` at height 1 of generation 0. -/
def minorityVote (key blockId : Nat) : Consensus.Vote := ⟨FirstBatch.deployment,0,1,0,2,blockId,key⟩

/-- Every vote anyone signed: keys 7 and 8 sign block 101; key 9 signs blocks 101 and 102. -/
def minorityVotes : List Consensus.Vote :=
  [minorityVote 7 101,minorityVote 8 101,minorityVote 9 101,minorityVote 9 102]

def signedMinority (v : Consensus.Vote) : Prop := v ∈ minorityVotes

instance : DecidablePred signedMinority := fun v => inferInstanceAs (Decidable (v ∈ minorityVotes))

def verifyMinority (key : Hash) (evidence : Staking.Vote) (_signature : Hash) : Bool :=
  minorityVotes.any fun v => v.key == key && Accountability.evidence v == evidence

/-- Keys 7, 8 and 9 (owners 51-53) register 3, 2 and 1 TAIKO in L1 block 10. -/
def minorityRegistry : RegistryHistory.State :=
  let empty : RegistryHistory.State := { SecondBatch.emptyRegistry with verify := verifyMinority }
  let one := (RegistryHistory.register empty 7 51 3000000000000000000 10).getD empty
  let two := (RegistryHistory.register one 8 52 2000000000000000000 10).getD one
  (RegistryHistory.register two 9 53 1000000000000000000 10).getD two

def minorityZero : Committee.Record := ⟨0,12,minorityMembers⟩
def minorityWorld : ProtocolState.World :=
  ⟨{ inbox0 with committeeZeroRecord := minorityZero },minorityRegistry,[],Committee.recoverySchedule minorityZero,14,
    ⟨configHash,fun _ => 12,SecondBatch.recoveryConfig⟩⟩

def minorityEnv : Environment := { relations with signature := signedMinority,submits := fun _ _ _ _ => False }

def minorityRules : BlockValidity.Rules := rulesFor minorityEnv minorityWorld [14] 16 1600
instance : DecidablePred minorityRules.signature := fun v => inferInstanceAs (Decidable (signedMinority v))

private theorem minority_registry_at_cutoff :
    HistoricalContext.registryAt minorityWorld.registry 12 = minorityMembers := by
  decide +kernel

/-- The registry order is already the election's order (stake down, then key up), so both
`mergeSort`s of `Committee.chosen` return their input (`List.mergeSort_of_pairwise`). -/
private theorem minority_chosen : Committee.chosen 1000000000 1000000000000000000 12 3 minorityMembers = minorityMembers := by
  unfold Committee.chosen
  rw [show minorityMembers.filter (Committee.eligible 1000000000 1000000000000000000 12) = minorityMembers by decide +kernel,
    List.mergeSort_of_pairwise (l := minorityMembers) (le := Committee.rank) (by decide +kernel),
    show minorityMembers.take 3 = minorityMembers from rfl,
    List.mergeSort_of_pairwise (l := minorityMembers) (le := fun a b => decide (a.key ≤ b.key)) (by decide +kernel)]

private theorem minority_election : Committee.election 1000000000 1000000000000000000 12 3 minorityMembers = some minorityMembers := by
  unfold Committee.election
  simp only [minority_chosen]
  decide +kernel

private theorem minority_elected :
    Deployment.GenesisElected minorityWorld.inbox minorityWorld.registry minorityWorld.inbox.configuration := by
  show Committee.election 1000000000 1000000000000000000 12 3 (HistoricalContext.registryAt minorityWorld.registry 12) =
    some minorityMembers
  rw [minority_registry_at_cutoff,minority_election]

private theorem minority_built : Built minorityEnv minorityWorld minorityRules := by
  refine ⟨[14],16,1600,build_rulesFor ⟨by decide +kernel,rfl,by decide +kernel,?_,minority_elected,by decide +kernel,
    by decide +kernel⟩ ⟨by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,?_,
    by decide,by decide⟩⟩
  · show (⟨0,12,Committee.chosen 1000000000 1000000000000000000 12 3 (HistoricalContext.registryAt minorityWorld.registry 12)⟩ :
      Committee.Record) = minorityZero
    rw [minority_registry_at_cutoff,minority_chosen]
    rfl
  · show (Committee.election 1000000000 1000000000000000000 12 3 (HistoricalContext.registryAt minorityWorld.registry 12)).isSome
      = true
    rw [minority_registry_at_cutoff,minority_election]
    rfl

private theorem minority_active : Consensus.activeAt minorityRules.consensus 1 = minorityZero := by
  rw [Consensus.active_before_switch _ 1 (by decide +kernel)]
  show (⟨0,12,Committee.chosen 1000000000 1000000000000000000 12 3 (HistoricalContext.registryAt minorityWorld.registry 12)⟩ :
    Committee.Record) = minorityZero
  rw [minority_registry_at_cutoff,minority_chosen]
  rfl

/-- The three-validator deployment and its environment satisfy every premise field. -/
theorem minority_premises : Premises minorityWorld minorityEnv where
  genesis := by
    refine ⟨⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,by decide,rfl,by unfold FeeConserved; decide +kernel,
      ⟨?_,?_,?_,?_,by decide +kernel⟩,rfl,by decide +kernel,by decide +kernel,by decide +kernel,rfl,rfl,rfl,
      minority_elected,by decide +kernel⟩,rfl,rfl,rfl⟩
    · unfold RegistryHistory.KeysValid
      decide +kernel
    · unfold RegistryHistory.IdentitiesValid
      decide +kernel
    · unfold RegistryHistory.Ordered
      decide +kernel
    · unfold RegistryHistory.CurrentSnapshot
      decide +kernel
  verifierSound := ⟨fun _ => True,fun proofs ok => match proofs, dual_count ok with
    | q :: _, _ => ⟨q,List.mem_cons_self,trivial⟩,fun _ _ _ _ _ _ _ submitted => submitted.elim⟩
  authenticatedInputs := fun _ _ _ _ _ submitted => submitted.elim
  hashSeparation := premises.hashSeparation
  headerHashes := premises.headerHashes
  headerSeparation := premises.headerSeparation
  signatureAgreement := by
    refine ⟨fun _ => 0,fun v _ cast => ?_⟩
    show verifyMinority v.key (Accountability.evidence v) 0 = true
    exact List.any_eq_true.mpr ⟨v,cast,by simp⟩

/-- H2's finality with a Byzantine minority that does double-sign. In the deployment's built
rules, key 9 (1/6 of the power) signed precommits for blocks 101 and 102 at height 1, round 0;
keys 7 and 8 equivocate nowhere; key 9's power is positive and below a third. Keys
7 and 8 make a valid commit for block 101, and key 9 alone cannot make one for 102. By H2
(`Etna.Proofs.accountable_finality`), every two valid commits at that height and round agree. -/
theorem byzantine_minority_finality : Premises minorityWorld minorityEnv ∧ Built minorityEnv minorityWorld minorityRules ∧
    Equivocates minorityRules.consensus minorityRules.signature 1 0 9 ∧
    (∀ m ∈ (Consensus.activeAt minorityRules.consensus 1).members, (m.key != 9) = true →
      ¬ Equivocates minorityRules.consensus minorityRules.signature 1 0 m.key) ∧
    0 < Committee.totalPower minorityRules.consensus.unit
        ((Consensus.activeAt minorityRules.consensus 1).members.filter fun m => !(m.key != 9)) ∧
    3*Committee.totalPower minorityRules.consensus.unit
        ((Consensus.activeAt minorityRules.consensus 1).members.filter fun m => !(m.key != 9)) <
      Committee.totalPower minorityRules.consensus.unit (Consensus.activeAt minorityRules.consensus 1).members ∧
    Consensus.CommitValid minorityRules.consensus minorityRules.signature 1 0 101 [minorityVote 7 101,minorityVote 8 101] ∧
    ¬ Consensus.CommitValid minorityRules.consensus minorityRules.signature 1 0 102 [minorityVote 9 102] ∧
    ∀ a b votesA votesB, Consensus.CommitValid minorityRules.consensus minorityRules.signature 1 0 a votesA →
      Consensus.CommitValid minorityRules.consensus minorityRules.signature 1 0 b votesB → a = b := by
  have double : Equivocates minorityRules.consensus minorityRules.signature 1 0 9 :=
    ⟨minorityVote 9 101,minorityVote 9 102,by decide,by decide,rfl,rfl,by decide +kernel,by decide +kernel,by decide +kernel,
      by decide +kernel,rfl,rfl,rfl,rfl,rfl,rfl,by decide⟩
  have honest : ∀ m ∈ (Consensus.activeAt minorityRules.consensus 1).members, (m.key != 9) = true →
      ¬ Equivocates minorityRules.consensus minorityRules.signature 1 0 m.key := by
    rintro m _ notNine ⟨va,vb,signedA,signedB,keyA,keyB,_,_,_,_,_,_,_,_,_,_,different⟩
    change va ∈ minorityVotes at signedA
    change vb ∈ minorityVotes at signedB
    simp only [minorityVotes,List.mem_cons,List.not_mem_nil,or_false] at signedA signedB
    rcases signedA with rfl | rfl | rfl | rfl <;> rcases signedB with rfl | rfl | rfl | rfl <;>
      simp only [minorityVote] at keyA keyB different <;> simp_all
  have power : 3*Committee.totalPower minorityRules.consensus.unit
      ((Consensus.activeAt minorityRules.consensus 1).members.filter fun m => !(m.key != 9)) <
      Committee.totalPower minorityRules.consensus.unit (Consensus.activeAt minorityRules.consensus 1).members := by
    rw [minority_active]
    decide +kernel
  have elected : Consensus.ElectionValid minorityRules.consensus minorityZero := by
    show Committee.election 1000000000 1000000000000000000 12 3 (HistoricalContext.registryAt minorityWorld.registry 12) =
      some minorityMembers
    rw [minority_registry_at_cutoff,minority_election]
  have commit : Consensus.CommitValid minorityRules.consensus minorityRules.signature 1 0 101
      [minorityVote 7 101,minorityVote 8 101] := by
    unfold Consensus.CommitValid Consensus.VoteValid
    rw [minority_active]
    exact ⟨by decide +kernel,elected,by decide +kernel⟩
  have alone : ¬ Consensus.CommitValid minorityRules.consensus minorityRules.signature 1 0 102 [minorityVote 9 102] := by
    intro valid
    have quorum := Consensus.commit_strict_quorum valid
    rw [minority_active] at quorum
    exact absurd quorum (by decide +kernel)
  have member : 0 < Committee.totalPower minorityRules.consensus.unit
      ((Consensus.activeAt minorityRules.consensus 1).members.filter fun m => !(m.key != 9)) := by
    rw [minority_active]
    decide +kernel
  exact ⟨minority_premises,minority_built,double,honest,member,power,commit,alone,
    (Etna.Proofs.accountable_finality minorityEnv minorityWorld minority_premises minorityWorld (.refl _) minorityRules
      minority_built).2 1 0 (fun k => k != 9)
      honest power⟩

end Etna.Design.NonVacuity
