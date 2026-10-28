import EtnaWitnesses.NonVacuity.Premises

/-! Scope counterexample: H1 (fund safety) needs `Premises.verifierSound`. This is not a failure
of H1; it shows what the premise carries.

§1 "Funds" (EN L14): "every landing needs two proofs, at least one of them ZK"; §1 "Upgrades and
trust" (EN L18): "Verifier soundness ... is a separate assumption"; §8 "Verifier failure" (EN
L457): "both proofs accepting a wrong result is outside the threat model". `land` checks the
proofs' shape (`dualOK`) and that the certificate is the Inbox's own statement for the call, but
nothing in the contract checks that the statement comes from valid blocks.

The run uses the non-vacuity deployment and relations unchanged, and every premise field except
`verifierSound` holds. Landers submit one call: (0, 1] with EL hash 0 and stateRoot 666, carrying
two accepting proofs from different backends. No EL header hashes to 0, so no valid chain ends
there, yet the Inbox lands it and SignalService records stateRoot 666 for block 1. So FundSafety's
conclusion fails on this run; by `Etna.Proofs.fund_safety`, the environment's verifier is not
sound and the certificate is not certified. -/
namespace Etna.Design.NoVerifierSoundness
open Etna.Statements NonVacuity

/-- The forged call: from block 0 to block 1, EL hash 0, Comet hash 777, stateRoot 666,
reference L1 block 14, FI head 0, committee snapshot 12. -/
def forgedInput : LandInput := ⟨0,1,0,777,666,14,0,12⟩

/-- The Inbox's statement for the call (6.1 step 6; `statementData`). -/
def forgedCertificate : StatementData :=
  ⟨FirstBatch.deployment,0,world0.inbox.committeeConfig,genesisHeader.elHash,0,0,forgedInput,1400,[111],⟨0,0,1,[]⟩⟩

/-- Landed at L1 block 15 with two accepting proofs (RISC0 and SP1). -/
def forgedEnv : LandingEnv := ⟨15,1400,true,[111],proofs,forgedCertificate⟩

def forgedWorld : ProtocolState.World :=
  ProtocolState.landed world0 (applyLanding world0.inbox forgedInput) 15

/-- The forged record at height 1. -/
def forgedRecord : Checkpoint := ⟨1,0,777,0,0,0⟩

/-- The non-vacuity relations; landers submit only the forged call. -/
def environment : Environment :=
  { relations with submits := fun w i leaves e => w = world0 ∧ i = forgedInput ∧ leaves = [] ∧ e = forgedEnv }

/-- FundSafety's conclusion for the end `w` of one run from `w0` (the body of
`Etna.Statements.FundSafety`, `fund_safety_body`). -/
def Safe (env : Environment) (w0 w : ProtocolState.World) : Prop :=
  ∃ H : Checkpoint → BlockValidity.Header,
    (∀ child ∈ w.inbox.records, HeaderOf H child ∧
      (child = w0.inbox.checkpoint ∧ H child = env.genesisHeader ∨
        ∃ parent ∈ w.inbox.records, parent.height = child.parent ∧ parent.height < child.height ∧
          Extends env w0 w child.generation (H parent) (H child))) ∧
    ∀ g ∈ w.inbox.signals, ∃ child ∈ w.inbox.records, child.height = g.height ∧ child.elHash = g.hash ∧
      (H child).stateRoot = g.stateRoot

/-- `Safe` is exactly what H1 claims for every run. -/
theorem fund_safety_body :
    FundSafety ↔ ∀ env w0, Premises w0 env → ∀ w, Run env w0 w → Safe env w0 w := Iff.rfl

private theorem terminal_mem : ∀ (q : BlockValidity.Header) (bs : List BlockValidity.Block),
    BlockValidity.terminal q bs ∈ q :: bs.map BlockValidity.Block.header
  | q, [] => List.mem_singleton_self q
  | _, b :: rest => List.mem_cons_of_mem _ (terminal_mem b.header rest)

private theorem headerHash_pos (h : BlockValidity.Header) : 0 < headerHash h :=
  Nat.mul_pos (Nat.two_pow_pos _) (Nat.succ_pos _)

private theorem forged_run : Run environment world0 forgedWorld :=
  .landing (i := forgedInput) (leaves := []) (e := forgedEnv) (.refl _) ⟨rfl,rfl,rfl,rfl⟩ (by decide)
    (by decide +kernel)

private theorem inputs : InputsAuthenticated environment := by
  rintro w i leaves e s ⟨rfl,rfl,rfl,rfl⟩ _ anchor witness real _ _ before below
  have tail : (l1Anchor anchor.number).tail = 0 := by
    have early : anchor.number < 15 := before
    unfold l1Anchor
    simp [early]
  rw [of_decide_eq_true real,tail] at below
  omega

/-- No run that lands the forged call is safe: the forged record's header would have EL hash 0,
but it would end a valid chain, whose headers all have nonzero `headerHash`es. -/
private theorem not_safe : ¬ Safe environment world0 forgedWorld := by
  rintro ⟨H,records,_⟩
  have forged : forgedRecord ∈ forgedWorld.inbox.records := by decide +kernel
  obtain ⟨⟨height,cut⟩,origin⟩ := records forgedRecord forged
  rcases origin with ⟨genesis,_⟩ | ⟨parent,retained,_,below,_,r,bs,_,_,_,built,chain,last⟩
  · exact absurd (congrArg Checkpoint.height genesis) (by decide)
  · obtain ⟨archive,number,hash,ok⟩ := built
    obtain ⟨_,_,_,_,_,_,_,_,_,rfl⟩ := Deployment.build_success ok
    have parentHeight := (records parent retained).1.1
    have nonempty : bs ≠ [] := by
      rintro rfl
      have same : H parent = H forgedRecord := last
      have lowered : (H forgedRecord).height = parent.height := same ▸ parentHeight
      rw [height] at lowered
      rw [lowered] at below
      exact Nat.lt_irrefl _ below
    have bound := Etna.Proofs.chain_headers_bound (hash := headerHash) (fun _ _ accepted => of_decide_eq_true accepted)
      chain nonempty _ (terminal_mem (H parent) bs)
    rw [last] at bound
    have zero : (H forgedRecord).elHash = 0 := congrArg Cut.elHash cut
    rw [zero] at bound
    exact Nat.ne_of_lt (headerHash_pos (H forgedRecord)) bound

/-- Without verifier soundness a forged checkpoint lands. Every premise field except
`verifierSound` holds for the non-vacuity deployment and this environment (the fields are
listed in `Premises` order). A run lands the forged call, and SignalService then holds
stateRoot 666 for block 1. FundSafety's conclusion fails on that run. So, by H1, the
environment's verifier is not sound, and the forged certificate is not the statement of any
batch valid under the rules the deployment builds. -/
theorem forged_checkpoint_lands :
    (Deployment.Genesis world0 environment.genesisHeader.elHash environment.genesisHeader.stateRoot ∧
      environment.genesisHeader.height = 0 ∧ environment.genesisHeader.cometHash = 0 ∧
      environment.genesisHeader.cursor = 0) ∧
    InputsAuthenticated environment ∧
    (∀ cfg, Representable cfg →
      world0.adapters.configHash (Deployment.words world0.inbox cfg) = world0.inbox.committeeConfig →
        cfg = world0.inbox.configuration) ∧
    ((∀ p b, environment.executionValid p b = true →
        p.elHash = environment.headerHash p ∧ b.header.elHash = environment.headerHash b.header) ∧
      environment.genesisHeader.elHash = environment.headerHash environment.genesisHeader) ∧
    (∀ h₁ h₂, environment.headerHash h₁ = environment.headerHash h₂ →
      h₁.height = h₂.height ∧ h₁.stateRoot = h₂.stateRoot ∧ h₁.timestamp = h₂.timestamp ∧ h₁.anchor = h₂.anchor) ∧
    (∃ sig : Consensus.Vote → Hash, ∀ v, v.domain = world0.inbox.domain → environment.signature v →
      world0.registry.verify v.key (Accountability.evidence v) (sig v) = true) ∧
    Run environment world0 forgedWorld ∧ (⟨1,0,666⟩ : Signal) ∈ forgedWorld.inbox.signals ∧
    ¬ Safe environment world0 forgedWorld ∧ ¬ VerifierSound environment ∧
    ¬ Certifies environment world0 forgedCertificate := by
  have noSound : ¬ VerifierSound environment := fun sound =>
    not_safe (Etna.Proofs.fund_safety environment world0
      ⟨premises.genesis,sound,inputs,premises.hashSeparation,premises.headerHashes,premises.headerSeparation,
        premises.signatureAgreement⟩ forgedWorld forged_run)
  refine ⟨premises.genesis,inputs,premises.hashSeparation,premises.headerHashes,premises.headerSeparation,
    premises.signatureAgreement,forged_run,by decide +kernel,not_safe,noSound,fun certified => noSound ?_⟩
  refine ⟨fun _ => True,fun proofs ok => ?_,?_⟩
  · match proofs, dual_count ok with
    | q :: _, _ => exact ⟨q,List.mem_cons_self,trivial⟩
  · rintro _ _ _ _ _ _ _ ⟨rfl,rfl,rfl,rfl⟩ _ _
    exact certified

end Etna.Design.NoVerifierSoundness
