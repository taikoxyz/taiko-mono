import EtnaStatements
import EtnaProofs.Accountability
import EtnaProofs.Deployment
import EtnaProofs.HistoricalContext
import EtnaProofs.Lifecycle

/-! H2, accountable finality (`Etna.Statements.AccountableFinality`). The per-context results
(`Accountability.conflicting_commits_overlap`, the registry's `slash_of_double_sign`) are lifted
to the rules `Deployment.build` derives on a World that a trace reaches from the initialized
World: the built context's domain and generation are the World's own, its signature relation is
the environment's, and `Premises.signatureAgreement` turns a consensus-signed vote into one the
registry's own verifier accepts. -/
namespace Etna.Proofs
open Etna.Design Etna.Statements

/-- Power counted by a filter grows with the filter: if every member that `p` selects is also
selected by `q`, the members `p` selects hold at most the power of those `q` selects. -/
theorem selected_power_le (unit : Nat) (members : List Committee.Entry) {p q : Committee.Entry → Bool}
    (sub : ∀ e ∈ members, p e = true → q e = true) :
    Committee.totalPower unit (members.filter p) ≤ Committee.totalPower unit (members.filter q) := by
  induction members with
  | nil => exact Nat.le_refl _
  | cons e rest ih =>
    have tail := ih (fun x mem => sub x (List.mem_cons_of_mem _ mem))
    have head := sub e List.mem_cons_self
    simp only [Committee.totalPower,List.filter_cons] at tail ⊢
    cases hp : p e <;> cases hq : q e <;> simp_all <;> omega

/-- Double-sign evidence that the registry accepts on a World stays usable from then on (4.1:
"Valid evidence from historical generations remains admissible after recovery"): if the World
satisfies the structural invariant, its Inbox is initialized, its registry bounds hold, the
registry's own verifier accepts both votes under key `k` and the votes are double-sign evidence
for the current deployment and generation, then anyone can slash every live staked bond with key
`k` in every later World, at any later block. -/
theorem evidence_stays_slashable {w : ProtocolState.World} {a b : Staking.Vote} {sigA sigB k : Hash}
    (core : ProtocolState.Core w) (initialized : Staking.inboxInitialized w.inbox = true)
    (bounds : Deployment.RegistryConstraints w.registry) (notEntered : w.inbox.entered = false)
    (signedA : w.registry.verify k a sigA = true) (signedB : w.registry.verify k b sigB = true)
    (double : Staking.doubleSign w.inbox.domain w.inbox.generation a b = true) :
    Slashable w a b sigA sigB k := by
  intro t trace now id clock range key live staked
  obtain ⟨domain,_,_,_,_,_,_,_,_,_,_,_,_,_,_,verify,_⟩ := ProtocolState.trace_preserves_immutables trace
  obtain ⟨domainA,domainB,generation,past,height,round,kind,vote,conflict⟩ := of_decide_eq_true double
  have bond := RegistryHistory.slash_of_double_sign (r := t.registry) (inbox := t.inbox) (now := now)
    (bond := t.registry.slots id) (by rw [key,verify]; exact signedA) (by rw [key,verify]; exact signedB)
    (domainA.trans domain.symm) (domainB.trans domain.symm) generation
    (Nat.le_trans past (ProtocolState.trace_generation_monotone trace)) height round kind vote conflict
    (Lifecycle.trace_keeps_inbox_initialized trace initialized) live staked
    (Deployment.trace_preserves_registry_constraints trace bounds).2.2.1
  have free : t.inbox.entered = false := (ProtocolState.trace_entered trace).trans notEntered
  have registered := Nat.le_trans (ProtocolState.trace_preserves_core core trace).registry.clock clock
  cases edited : RegistryHistory.edit t.registry t.inbox id now (.slash a b sigA sigB) with
  | none => simp [RegistryHistory.edit,range,registered,free,bond] at edited
  | some s => exact ⟨s,rfl,RegistryHistory.edit_slash_balance edited⟩

/-- H2, accountable finality: see `Etna.Statements.AccountableFinality`. -/
theorem accountable_finality : AccountableFinality := by
  intro env w0 premises w trace r built
  obtain ⟨sig,agree⟩ := premises.signatureAgreement
  obtain ⟨core,_,bounds,initialized,_⟩ := Deployment.genesis_trace_invariants premises.genesis.1 trace
  obtain ⟨domain0,_,_,_,_,_,_,_,_,_,_,_,_,_,_,verify0,_⟩ := ProtocolState.trace_preserves_immutables trace
  have startFree : w0.inbox.entered = false := by
    obtain ⟨_,_,_,_,_,_,_,_,_,_,free,_⟩ := premises.genesis.1
    exact free
  -- The built context belongs to this World and checks votes with the environment's signatures.
  have context : r.consensus.domain = w.inbox.domain ∧ r.consensus.generation = w.inbox.generation ∧
      r.signature = env.signature := by
    obtain ⟨archive,number,hash,ok⟩ := built
    obtain ⟨_,_,_,_,_,_,_,c,found,rfl⟩ := Deployment.build_success ok
    obtain ⟨domain,generation,_,_⟩ := HistoricalContext.fixed_origin_not_checkpoint found
    exact ⟨domain,generation,rfl⟩
  -- The registry's verifier accepts every vote of a valid commit (signature agreement).
  have registered : ∀ {h round block : Nat} {v : Consensus.Vote},
      Consensus.VoteValid r.consensus r.signature h round block v →
      w.registry.verify v.key (Accountability.evidence v) (sig v) = true := by
    intro h round block v valid
    rw [verify0]
    exact agree v (valid.1.trans (context.1.trans domain0)) (context.2.2 ▸ valid.2.2.2.2.2.2.2)
  -- Two valid votes for different blocks at one height and round are double-sign evidence.
  have double : ∀ {h round a b : Nat} {va vb : Consensus.Vote},
      Consensus.VoteValid r.consensus r.signature h round a va →
      Consensus.VoteValid r.consensus r.signature h round b vb → a ≠ b →
      Staking.doubleSign w.inbox.domain w.inbox.generation (Accountability.evidence va)
        (Accountability.evidence vb) = true := by
    intro h round a b va vb validA validB conflict
    apply decide_eq_true
    simp only [Accountability.evidence]
    refine ⟨validA.1.trans context.1,validB.1.trans context.1,validA.2.1.trans validB.2.1.symm,
      Nat.le_of_eq (validA.2.1.trans context.2.1),validA.2.2.1.trans validB.2.2.1.symm,
      validA.2.2.2.1.trans validB.2.2.2.1.symm,validA.2.2.2.2.1.trans validB.2.2.2.2.1.symm,
      Or.inr validA.2.2.2.2.1,?_⟩
    rw [validA.2.2.2.2.2.1,validB.2.2.2.2.2.1]
    exact conflict
  -- A member counted in `signedBoth` has a vote in each commit.
  have pair : ∀ {members : List Committee.Entry} {votesA votesB : List Consensus.Vote} {m : Committee.Entry},
      m ∈ signedBoth members votesA votesB →
      m ∈ members ∧ (∃ va ∈ votesA, va.key = m.key) ∧ ∃ vb ∈ votesB, vb.key = m.key := by
    intro members votesA votesB m mem
    obtain ⟨member,both⟩ := List.mem_filter.mp mem
    simp only [Bool.and_eq_true,List.contains_iff_mem] at both
    obtain ⟨va,inA,keyA⟩ := List.mem_map.mp both.1
    obtain ⟨vb,inB,keyB⟩ := List.mem_map.mp both.2
    exact ⟨member,⟨va,inA,keyA⟩,vb,inB,keyB⟩
  constructor
  · -- Accountability: quorum intersection, and each common signer is slashable from `w` on.
    intro h round a b votesA votesB okA okB conflict
    refine ⟨Accountability.conflicting_commits_overlap okA okB,?_⟩
    intro m mem
    obtain ⟨_,⟨va,inA,keyA⟩,vb,inB,keyB⟩ := pair mem
    have validA := okA.2.2.2.1 va inA
    have validB := okB.2.2.2.1 vb inB
    have signedA := registered validA
    have signedB := registered validB
    rw [keyA] at signedA
    rw [keyB] at signedB
    exact ⟨va,inA,vb,inB,keyA,keyB,sig va,sig vb,
      evidence_stays_slashable core initialized bounds ((ProtocolState.trace_entered trace).trans startFree) signedA signedB (double validA validB conflict)⟩
  · -- Finality: every common signer of two conflicting commits equivocates, so it is not honest;
    -- then the dishonest power would exceed 1/3, contradicting the minority bound.
    intro h round honest clean minority a b votesA votesB okA okB
    by_cases same : a = b
    · exact same
    exfalso
    have dishonest : ∀ m ∈ (Consensus.activeAt r.consensus h).members,
        ((votesA.map Consensus.Vote.key).contains m.key && (votesB.map Consensus.Vote.key).contains m.key) = true →
        (!honest m.key) = true := by
      intro m member both
      obtain ⟨_,⟨va,inA,keyA⟩,vb,inB,keyB⟩ := pair (List.mem_filter.mpr ⟨member,both⟩)
      have validA := okA.2.2.2.1 va inA
      have validB := okB.2.2.2.1 vb inB
      cases hm : honest m.key with
      | false => rfl
      | true =>
        exact absurd ⟨va,vb,validA.2.2.2.2.2.2.2,validB.2.2.2.2.2.2.2,keyA,keyB,validA.1,validB.1,validA.2.1,
          validB.2.1,validA.2.2.1,validB.2.2.1,validA.2.2.2.1,validB.2.2.2.1,validA.2.2.2.2.1,validB.2.2.2.2.1,
          fun ids => same (validA.2.2.2.2.2.1.symm.trans (ids.trans validB.2.2.2.2.2.1))⟩ (clean m member hm)
    have overlap := Accountability.conflicting_commits_overlap okA okB
    have covered := selected_power_le r.consensus.unit _ dishonest
    omega

end Etna.Proofs
