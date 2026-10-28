import EtnaProofs.BlockValidity
import EtnaProofs.Accountability
import EtnaProofs.RegistryHistory

/-! Derived properties that compose existing model theorems; they add no definitions and no
new guards. Each one is derived in the audit's mechanical sense (its proof uses an induction
principle, or an Etna theorem that does) and passes Rule P, so it can back a proof claim. -/
namespace Etna.Design.Derived

/-- Along a decoded valid chain the block at position i has height p + i + 1: the heights
are exactly p + 1, p + 2, … with no gap or repeat. -/
theorem chain_heights_consecutive {r : BlockValidity.Rules} :
    ∀ {p : BlockValidity.Header} {bs : List BlockValidity.Block} (_ok : BlockValidity.Chain r p bs)
      (i : Nat) (hi : i < bs.length), (bs[i]'hi).header.height = p.height+i+1
  | _, [], _, _, hi => absurd hi (Nat.not_lt_zero _)
  | p, b :: rest, ok, i, hi => by
    have first := (BlockValidity.valid_parent_links ok.1).1
    cases i with
    | zero => simpa using first
    | succ j =>
      have later := chain_heights_consecutive ok.2 j (by simpa using hi)
      simp only [List.getElem_cons_succ]
      omega

/-- Every switch block S(t) of a decoded valid chain carries a committee witness whose record
is the committee active at S(t)+2: its cutoff is at most the switch block's anchor number, its
root is that anchor's state root, and the election it records is accepted. -/
theorem chain_switch_witnesses_activate {r : BlockValidity.Rules} {p : BlockValidity.Header}
    {bs : List BlockValidity.Block} (ok : BlockValidity.Chain r p bs) (b : BlockValidity.Block)
    (mem : b ∈ bs) (switch : (b.header.height+1) % r.consensus.epochLen = 0) :
    ∃ w, b.committeeWitness = some w ∧ w.record = Consensus.activeAt r.consensus (b.header.height+2) ∧
      w.root = b.header.anchor.stateRoot ∧ w.record.cutoff ≤ b.header.anchor.number ∧
      Consensus.ElectionValid r.consensus (Consensus.activeAt r.consensus (b.header.height+2)) := by
  induction bs generalizing p with
  | nil => simp at mem
  | cons x rest ih =>
    rcases List.mem_cons.mp mem with rfl | tail
    · exact BlockValidity.valid_switch_witness_activates ok.1 switch
    · exact ih ok.2 tail

/-- Two valid decoded commits for different blocks at one height and round give anyone a
slash that succeeds at the registry: some selected member key k signed both, and every live,
staked bond whose stored occupant key is that signer's key loses its whole stake. The
registry checks the evidence with its own verifier against the stored key and reads the
Inbox and its own bounty; the caller supplies only the two votes and their signatures.
`verifies` is the signature boundary: the registry verifier accepts each vote of the two
commits that the consensus signature relation accepts. -/
theorem conflicting_commits_slashable {c : Consensus.Context} {signature : Consensus.Vote → Prop}
    {h round a b : Nat} {votesA votesB : List Consensus.Vote}
    (okA : Consensus.CommitValid c signature h round a votesA)
    (okB : Consensus.CommitValid c signature h round b votesB) (conflict : a ≠ b)
    (s : RegistryHistory.State) (inbox : State) (now : Nat) (sig : Consensus.Vote → Hash)
    (verifies : ∀ v ∈ votesA ++ votesB, signature v → s.verify v.key (Accountability.evidence v) (sig v) = true)
    (deployment : inbox.domain = c.domain) (current : c.generation ≤ inbox.generation)
    (initialized : Staking.inboxInitialized inbox = true)
    (clock : RegistryHistory.lastBlock s ≤ now) (cap : s.slashBountyBps ≤ 10000) :
    ∃ k ∈ (Consensus.activeAt c h).members.map Committee.Entry.key,
      ∃ va ∈ votesA.filter (fun v => v.key == k), ∃ vb ∈ votesB.filter (fun v => v.key == k),
      ∀ id, id < s.nextId → (s.slots id).key = k → (s.slots id).released = false →
        0 < (s.slots id).stake →
        ∃ t, RegistryHistory.edit s inbox id now
            (.slash (Accountability.evidence va) (Accountability.evidence vb) (sig va) (sig vb)) = some t ∧
          (t.slots id).stake = 0 ∧ (t.slots id).key = k ∧ (t.slots id).exitAt ≤ now := by
  obtain ⟨k,member,va,inA,vb,inB,signedA,signedB,double⟩ :=
    Accountability.conflicting_commits_double_sign okA okB conflict
  refine ⟨k,member,va,inA,vb,inB,?_⟩
  have keyA : va.key = k := beq_iff_eq.mp (List.mem_filter.mp inA).2
  have keyB : vb.key = k := beq_iff_eq.mp (List.mem_filter.mp inB).2
  intro id range key live staked
  obtain ⟨domainA,domainB,generation,past,height,round',kind,vote,different⟩ := of_decide_eq_true double
  have bond := RegistryHistory.slash_of_double_sign (r := s)
    (inbox := inbox) (now := now) (bond := s.slots id) (sigA := sig va) (sigB := sig vb)
    (by rw [key,← keyA]; exact verifies va (List.mem_append_left _ (List.mem_filter.mp inA).1) signedA)
    (by rw [key,← keyB]; exact verifies vb (List.mem_append_right _ (List.mem_filter.mp inB).1) signedB)
    (domainA.trans deployment.symm) (domainB.trans deployment.symm) generation
    (Nat.le_trans past current) height round' kind vote different initialized live staked cap
  cases edited : RegistryHistory.edit s inbox id now
      (.slash (Accountability.evidence va) (Accountability.evidence vb) (sig va) (sig vb)) with
  | none => simp [RegistryHistory.edit,range,clock,bond] at edited
  | some t =>
    refine ⟨t,rfl,?_⟩
    obtain ⟨_,_,out,changed,rfl⟩ := RegistryHistory.edit_success edited
    rw [bond] at changed
    cases changed
    simp [RegistryHistory.finish,RegistryHistory.writeSlot,key,Nat.min_le_right]

end Etna.Design.Derived
