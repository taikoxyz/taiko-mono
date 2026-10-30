import EtnaProofs.Headline.ChainOfCustody
import EtnaWitnesses.Regressions.ThirdBatch

/-! A concrete run for H1, fund safety, through every way the landing records change: deploy,
land twice in generation 0, recover (generation 1 from checkpoint 2), land in generation 1, then
roll back to checkpoint 2, which voids the generation-1 record and its SignalService checkpoint.
At every World the chain-of-custody property holds (`Custody`, pinned to
`Etna.Proofs.chain_of_custody` by `custody_of_run`). Each header's EL hash is the environment's
`headerHash` of its fields (Cantor pairing of height, stateRoot, timestamp and the anchor), and
the environment's EL relation checks exactly that binding. L = 10 keeps every block before the
first switch block, and the committee has one member, so the kernel evaluates every election. -/
namespace Etna.Design.FundSafetyRun
open Etna.Statements

/-- Cantor pairing: one number for two. -/
def pair (a b : Nat) : Nat := (a+b)*(a+b+1)/2+b

/-- An anchor's seven fields as one number. -/
def anchorCode (a : BlockValidity.Anchor) : Nat :=
  pair (pair (pair a.number a.timestamp) (pair a.stateRoot a.checkpointHeight))
    (pair (pair a.checkpointHash a.generation) a.tail)

/-- The EL hash of a decoded header: an encoding of the fields its EL header fixes (height,
stateRoot, timestamp and the anchor). The header's own EL hash is not an input. -/
def headerHash (h : BlockValidity.Header) : Hash :=
  pair (pair h.height h.stateRoot) (pair h.timestamp (anchorCode h.anchor))

/-- `h` with its EL hash set to the hash of its fields. -/
def hashed (h : BlockValidity.Header) : BlockValidity.Header := { h with elHash := headerHash h }

/-- Block 0's header: stateRoot 10000 at L1 block 14. -/
def genesisHeader : BlockValidity.Header := hashed ⟨0,0,10000,0,0,14,⟨14,14,24,0,0,0,0⟩⟩

def record0 : Checkpoint := ⟨0,genesisHeader.elHash,0,0,0,0⟩

/-- ThirdBatch's deployed Inbox with L = 10, on block 0's header. -/
def inbox0 : State :=
  { ThirdBatch.deployedInbox with
    epochLen := 10,checkpoint := record0,records := [record0],signals := [⟨0,genesisHeader.elHash,10000⟩] }

/-- The initialized World. -/
def world0 : ProtocolState.World := { ThirdBatch.deployed with inbox := inbox0 }

/-- The environment's relations: votes need no further signature, L1 and storage data are
authentic, and the EL accepts a block exactly when its parent's and its own EL hashes are
`headerHash` of those headers. Landers submit nothing yet (`env` adds the run's landings). -/
def relations : Environment where
  signature := fun _ => True
  anchorAuthenticated := fun _ => true
  committeeAuthenticated := fun _ _ => true
  executionValid := fun p b => decide (p.elHash = headerHash p ∧ b.header.elHash = headerHash b.header)
  payloadValid := fun _ => true
  forcedAuthenticated := fun _ _ => true
  batchPayloadValid := fun _ _ => true
  historyAuthenticated := fun _ _ => true
  headerHash := headerHash
  genesisHeader := genesisHeader
  submits := fun _ _ _ _ => False

def proofs : List (Backend × Bool) := [(.risc0,true),(.sp1,true)]
def vote (generation height blockId : Nat) : Consensus.Vote := ⟨FirstBatch.deployment,generation,height,0,2,blockId,7⟩

/-! Generation 0: land (0, 1], then (1, 2]. -/

def archive0 : List Nat := [14,15,16]
def rules0 : BlockValidity.Rules :=
  (Deployment.build world0 world0.inbox.configuration archive0 (relations.template 16 1600)).getD (relations.template 16 1600)
instance : DecidablePred rules0.signature := fun _ => inferInstanceAs (Decidable True)

def block1 : BlockValidity.Block :=
  ⟨hashed ⟨1,0,10001,101,0,15,⟨15,15,25,0,0,0,0⟩⟩,genesisHeader.elHash,none,FirstBatch.deployment,0,15,
    100,100,true,none,12,12,25,0,[vote 0 1 101],none,.completedEmpty⟩
def statement1 : StatementData := Settlement.statement rules0 genesisHeader [block1] [111]
def env1 : LandingEnv := ⟨17,1600,true,[111],proofs,statement1⟩
def world1 : ProtocolState.World := ProtocolState.landed world0 (applyLanding world0.inbox statement1.input) 17

def rules1 : BlockValidity.Rules :=
  (Deployment.build world1 world1.inbox.configuration archive0 (relations.template 18 1800)).getD (relations.template 18 1800)
instance : DecidablePred rules1.signature := fun _ => inferInstanceAs (Decidable True)

def block2 : BlockValidity.Block :=
  ⟨hashed ⟨2,0,10002,102,0,16,⟨16,16,26,0,0,0,0⟩⟩,block1.header.elHash,some 101,FirstBatch.deployment,0,16,
    100,100,true,none,12,12,26,0,[vote 0 2 102],none,.completedEmpty⟩
def statement2 : StatementData := Settlement.statement rules1 block1.header [block2] [111]
def env2 : LandingEnv := ⟨19,1800,true,[111],proofs,statement2⟩
def world2 : ProtocolState.World := ProtocolState.landed world1 (applyLanding world1.inbox statement2.input) 19

/-! Recovery at checkpoint 2 (R = L1 block 20), then generation 1 lands (2, 3]. -/

def request : Recovery.Request := ⟨0,2,[],[],0,limit256-1⟩
def origin1 : Origin := ⟨2,20,20⟩
def world3 : ProtocolState.World :=
  ProtocolState.recovered world2 request origin1
    (Recovery.applyRecovery (ProtocolState.recoveryView world2) request SecondBatch.recoveryConfig origin1)

def archive3 : List Nat := [14,15,16,20]
def rules3 : BlockValidity.Rules :=
  (Deployment.build world3 world3.inbox.configuration archive3 (relations.template 22 2200)).getD (relations.template 22 2200)
instance : DecidablePred rules3.signature := fun _ => inferInstanceAs (Decidable True)

def block3 : BlockValidity.Block :=
  ⟨hashed ⟨3,0,10003,103,0,20,⟨20,20,30,0,0,1,0⟩⟩,block2.header.elHash,none,FirstBatch.deployment,1,20,
    100,100,true,none,12,12,30,0,[vote 1 3 103],none,.completedEmpty⟩
def statement3 : StatementData := Settlement.statement rules3 block2.header [block3] [111]
def env3 : LandingEnv := ⟨23,2200,true,[111],proofs,statement3⟩
def world4 : ProtocolState.World := ProtocolState.landed world3 (applyLanding world3.inbox statement3.input) 23

/-! Verifier-failure rollback to checkpoint 2 (the last generation-0 landing). -/

def record1 : Checkpoint := ⟨1,block1.header.elHash,101,0,0,0⟩
def record2 : Checkpoint := ⟨2,block2.header.elHash,102,0,0,1⟩
def record3 : Checkpoint := ⟨3,block3.header.elHash,103,0,1,2⟩
def world5 : ProtocolState.World := ProtocolState.applyRollback world4 record2 12 24

theorem steps_accepted :
    land world0.inbox statement1.input [] env1 = some (applyLanding world0.inbox statement1.input) ∧
    land world1.inbox statement2.input [] env2 = some (applyLanding world1.inbox statement2.input) ∧
    Recovery.recover (ProtocolState.recoveryView world2) request world2.adapters.recovery origin1 true true =
      some (Recovery.applyRecovery (ProtocolState.recoveryView world2) request SecondBatch.recoveryConfig origin1) ∧
    land world3.inbox statement3.input [] env3 = some (applyLanding world3.inbox statement3.input) ∧
    recordAt world4.inbox 2 = some record2 := by decide +kernel

theorem chains_valid : BlockValidity.Chain rules0 genesisHeader [block1] ∧
    BlockValidity.Chain rules1 block1.header [block2] ∧ BlockValidity.Chain rules3 block2.header [block3] := by
  decide +kernel

/-- The run starts at an initialized deployment on block 0's header (`Premises.genesis`), and the
environment's EL relation binds every header it accepts to its hash (`Premises.headerHashes`). -/
theorem deployed_on_genesis_header :
    (Deployment.Genesis world0 relations.genesisHeader.elHash relations.genesisHeader.stateRoot ∧
      relations.genesisHeader.height = 0 ∧ relations.genesisHeader.cometHash = 0 ∧ relations.genesisHeader.cursor = 0) ∧
    (∀ p b, relations.executionValid p b = true →
      p.elHash = relations.headerHash p ∧ b.header.elHash = relations.headerHash b.header) ∧
    relations.genesisHeader.elHash = relations.headerHash relations.genesisHeader := by
  refine ⟨⟨⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,by decide,rfl,by unfold FeeConserved; decide +kernel,
    ⟨?_,?_,?_,?_,by decide +kernel⟩,rfl,by decide +kernel,by decide +kernel,by decide +kernel,rfl,rfl,rfl,
    by unfold Deployment.GenesisElected; decide +kernel,by decide +kernel,rfl⟩,rfl,rfl,rfl⟩,
    fun _ _ accepted => of_decide_eq_true accepted,rfl⟩
  · unfold RegistryHistory.KeysValid
    decide +kernel
  · unfold RegistryHistory.IdentitiesValid
    decide +kernel
  · unfold RegistryHistory.Ordered
    decide +kernel
  · unfold RegistryHistory.CurrentSnapshot
    decide +kernel

/-! The environment submits exactly the run's three landings. -/

def env : Environment :=
  { relations with
    submits := fun w i leaves e =>
      (w = world0 ∧ i = statement1.input ∧ leaves = [] ∧ e = env1) ∨
      (w = world1 ∧ i = statement2.input ∧ leaves = [] ∧ e = env2) ∨
      (w = world3 ∧ i = statement3.input ∧ leaves = [] ∧ e = env3) }

private theorem step1 {a : ProtocolState.World} (prior : Run env a world0) : Run env a world1 :=
  .landing prior (Or.inl ⟨rfl,rfl,rfl,rfl⟩) (by decide) steps_accepted.1
private theorem step2 {a : ProtocolState.World} (prior : Run env a world1) : Run env a world2 :=
  .landing prior (Or.inr (Or.inl ⟨rfl,rfl,rfl,rfl⟩)) (by decide) steps_accepted.2.1
private theorem step3 {a : ProtocolState.World} (prior : Run env a world2) : Run env a world3 :=
  .other prior (.recovery (by decide) steps_accepted.2.2.1) (by decide +kernel)
private theorem step4 {a : ProtocolState.World} (prior : Run env a world3) : Run env a world4 :=
  .landing prior (Or.inr (Or.inr ⟨rfl,rfl,rfl,rfl⟩)) (by decide) steps_accepted.2.2.2.1
private theorem step5 {a : ProtocolState.World} (prior : Run env a world4) : Run env a world5 :=
  .other prior (.rollback record2 12 24 (by decide) steps_accepted.2.2.2.2 (by decide +kernel)) (by decide +kernel)

/-- The rules of each landing are ones the deployment builds on the World it lands on. -/
private theorem built_of {w : ProtocolState.World} {archive : List Nat} {number hash : Nat}
    (ok : (Deployment.build w w.inbox.configuration archive (relations.template number hash)).isSome = true) :
    Built env w ((Deployment.build w w.inbox.configuration archive (relations.template number hash)).getD
      (relations.template number hash)) := by
  refine ⟨archive,number,hash,?_⟩
  show Deployment.build w w.inbox.configuration archive (relations.template number hash) = _
  cases built : Deployment.build w w.inbox.configuration archive (relations.template number hash) with
  | none => rw [built] at ok; contradiction
  | some r => rfl

/-- Each record's block header. -/
def headerAt (c : Checkpoint) : BlockValidity.Header :=
  match c.height with
  | 0 => genesisHeader
  | 1 => block1.header
  | 2 => block2.header
  | _ => block3.header

/-- The H1 trace invariant, `Etna.Proofs.chain_of_custody`'s conclusion: FundSafety's body for
World `w`, plus every record's header is hash-bound (`custody_of_run` pins the two together). -/
def Custody (env : Environment) (w0 w : ProtocolState.World) : Prop :=
  ∃ H : Checkpoint → BlockValidity.Header,
    (∀ child ∈ w.inbox.records, HeaderOf H child ∧ (H child).elHash = env.headerHash (H child) ∧
      (child = w0.inbox.checkpoint ∧ H child = env.genesisHeader ∨
        ∃ parent ∈ w.inbox.records, parent.height = child.parent ∧ parent.height < child.height ∧
          Extends env w0 w child.generation (H parent) (H child))) ∧
    ∀ g ∈ w.inbox.signals, ∃ child ∈ w.inbox.records, child.height = g.height ∧ child.elHash = g.hash ∧
      (H child).stateRoot = g.stateRoot

/-- `Custody` is what the proved invariant gives on every run. -/
theorem custody_of_run {env : Environment} {w0 w : ProtocolState.World} (premises : Premises w0 env)
    (run : Run env w0 w) : Custody env w0 w :=
  Etna.Proofs.chain_of_custody premises run

/-- How record `c` hangs in World `w` under `headerAt`: one record clause of `Custody`. -/
private def Hangs (w : ProtocolState.World) (c : Checkpoint) : Prop :=
  HeaderOf headerAt c ∧ (headerAt c).elHash = env.headerHash (headerAt c) ∧
    (c = world0.inbox.checkpoint ∧ headerAt c = env.genesisHeader ∨
      ∃ parent ∈ w.inbox.records, parent.height = c.parent ∧ parent.height < c.height ∧
        Extends env world0 w c.generation (headerAt parent) (headerAt c))

private theorem hangs0 (w : ProtocolState.World) : Hangs w record0 :=
  ⟨⟨by decide +kernel,by decide +kernel⟩,by decide +kernel,Or.inl ⟨rfl,rfl⟩⟩

/-- Record 1 extends block 0's header by block 1, under rules built on the deployed World. -/
private theorem hangs1 {w : ProtocolState.World} (parent : record0 ∈ w.inbox.records) (run : Run env world0 w) :
    Hangs w record1 :=
  ⟨⟨by decide +kernel,by decide +kernel⟩,by decide +kernel,Or.inr ⟨record0,parent,rfl,by decide,
    world0,rules0,[block1],.refl _,run,rfl,built_of (by decide +kernel),chains_valid.1,rfl⟩⟩

/-- Record 2 extends record 1's header by block 2, under rules built after the first landing. -/
private theorem hangs2 {w : ProtocolState.World} (parent : record1 ∈ w.inbox.records) (run : Run env world1 w) :
    Hangs w record2 :=
  ⟨⟨by decide +kernel,by decide +kernel⟩,by decide +kernel,Or.inr ⟨record1,parent,rfl,by decide,
    world1,rules1,[block2],step1 (.refl _),run,rfl,built_of (by decide +kernel),chains_valid.2.1,rfl⟩⟩

/-- Record 3 extends record 2's header by block 3, under generation 1's rules after recovery. -/
private theorem hangs3 {w : ProtocolState.World} (parent : record2 ∈ w.inbox.records) (run : Run env world3 w) :
    Hangs w record3 :=
  ⟨⟨by decide +kernel,by decide +kernel⟩,by decide +kernel,Or.inr ⟨record2,parent,rfl,by decide,
    world3,rules3,[block3],step3 (step2 (step1 (.refl _))),run,rfl,built_of (by decide +kernel),chains_valid.2.2,rfl⟩⟩

private theorem custody_of_records {w : ProtocolState.World} (records : List Checkpoint)
    (same : w.inbox.records = records) (each : ∀ c ∈ records, Hangs w c)
    (signals : ∀ g ∈ w.inbox.signals, ∃ c ∈ w.inbox.records, c.height = g.height ∧ c.elHash = g.hash ∧
      (headerAt c).stateRoot = g.stateRoot) : Custody env world0 w :=
  ⟨headerAt,fun c mem => each c (same ▸ mem),signals⟩

/-- Along the whole run (deploy, two generation-0 landings, recovery, a generation-1 landing,
rollback to checkpoint 2), every World satisfies the chain-of-custody property with the same
header map. -/
theorem custody_along_run : Custody env world0 world0 ∧ Custody env world0 world1 ∧ Custody env world0 world2 ∧
    Custody env world0 world3 ∧ Custody env world0 world4 ∧ Custody env world0 world5 := by
  have run1 : Run env world0 world1 := step1 (.refl _)
  have run2 : Run env world0 world2 := step2 run1
  have run3 : Run env world0 world3 := step3 run2
  have run4 : Run env world0 world4 := step4 run3
  have run5 : Run env world0 world5 := step5 run4
  refine ⟨custody_of_records [record0] (by decide +kernel) ?_ (by decide +kernel),
    custody_of_records [record1,record0] (by decide +kernel) ?_ (by decide +kernel),
    custody_of_records [record2,record1,record0] (by decide +kernel) ?_ (by decide +kernel),
    custody_of_records [record2,record1,record0] (by decide +kernel) ?_ (by decide +kernel),
    custody_of_records [record3,record2,record1,record0] (by decide +kernel) ?_ (by decide +kernel),
    custody_of_records [record2,record1,record0] (by decide +kernel) ?_ (by decide +kernel)⟩
  · intro c mem
    rcases List.mem_singleton.mp mem with rfl
    exact hangs0 _
  · intro c mem
    simp only [List.mem_cons,List.not_mem_nil,or_false] at mem
    rcases mem with rfl | rfl
    · exact hangs1 (by decide +kernel) run1
    · exact hangs0 _
  · intro c mem
    simp only [List.mem_cons,List.not_mem_nil,or_false] at mem
    rcases mem with rfl | rfl | rfl
    · exact hangs2 (by decide +kernel) (step2 (.refl _))
    · exact hangs1 (by decide +kernel) run2
    · exact hangs0 _
  · intro c mem
    simp only [List.mem_cons,List.not_mem_nil,or_false] at mem
    rcases mem with rfl | rfl | rfl
    · exact hangs2 (by decide +kernel) (step3 (step2 (.refl _)))
    · exact hangs1 (by decide +kernel) run3
    · exact hangs0 _
  · intro c mem
    simp only [List.mem_cons,List.not_mem_nil,or_false] at mem
    rcases mem with rfl | rfl | rfl | rfl
    · exact hangs3 (by decide +kernel) (step4 (.refl _))
    · exact hangs2 (by decide +kernel) (step4 (step3 (step2 (.refl _))))
    · exact hangs1 (by decide +kernel) run4
    · exact hangs0 _
  · intro c mem
    simp only [List.mem_cons,List.not_mem_nil,or_false] at mem
    rcases mem with rfl | rfl | rfl
    · exact hangs2 (by decide +kernel) (step5 (step4 (step3 (step2 (.refl _)))))
    · exact hangs1 (by decide +kernel) run5
    · exact hangs0 _

/-- The run reaches the rolled-back World, and records only grow until the rollback: it voids
the generation-1 record 3 and its SignalService checkpoint, keeps records 0-2 and their
signals, and restores checkpoint 2, while the recovery's generation 1 stays. -/
theorem rollback_voids_generation_one : Run env world0 world5 ∧
    world4.inbox.records = [record3,record2,record1,record0] ∧ world4.inbox.signals.map Signal.height = [0,1,2,3] ∧
    world5.inbox.records = [record2,record1,record0] ∧ world5.inbox.signals.map Signal.height = [0,1,2] ∧
    world5.inbox.checkpoint = record2 ∧ world3.inbox.generation = 1 ∧ world5.inbox.generation = 1 :=
  ⟨step5 (step4 (step3 (step2 (step1 (.refl _))))),by decide +kernel⟩

end Etna.Design.FundSafetyRun
