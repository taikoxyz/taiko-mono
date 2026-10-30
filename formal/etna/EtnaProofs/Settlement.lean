import EtnaModel.Settlement
import EtnaProofs.BlockValidity

/-! Proofs about `EtnaModel.Settlement`. -/
namespace Etna.Design.Settlement

theorem chain_certified {r : BlockValidity.Rules} {p : BlockValidity.Header}
    {bs : List BlockValidity.Block} {blobs : List Hash} (valid : BlockValidity.Chain r p bs)
    (pg : p.height % r.gridK = 0) (hg : (BlockValidity.terminal p bs).height % r.gridK = 0) :
    CertifiedTable r.gridK (statement r p bs blobs) (BlockValidity.cuts p bs) := by
  have heights := BlockValidity.chain_height valid
  refine ⟨?_,rfl,BlockValidity.cuts_origin p bs,BlockValidity.cuts_terminal p bs,
    BlockValidity.chain_cursor_steps valid,pg,hg⟩
  change (BlockValidity.cuts p bs).length = (BlockValidity.terminal p bs).height-p.height+1
  rw [BlockValidity.cuts_length]
  omega

theorem accepted_input {s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    (accepted : land s i leaves e = some t) (binding : e.certificate = statement r p bs blobs) :
    i = (statement r p bs blobs).input := by
  have cert := landing_certificate (land_success accepted).1
  have input := congrArg StatementData.input (cert.symm.trans binding)
  exact input

/-- The actual execution-time c, including a competing landing's newer c, is a cut on the
validated chain. The current slot-285 record is required to represent lastCheckpoint. -/
theorem accepted_frontier_from_valid_chain {s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    (accepted : land s i leaves e = some t) (valid : BatchValid r p bs blobs)
    (binding : e.certificate = statement r p bs blobs)
    (pg : p.height % r.gridK = 0) (hg : (BlockValidity.terminal p bs).height % r.gridK = 0)
    (grid : s.gridK = r.gridK) (positive : 0 < s.gridK) (cg : s.checkpoint.height % s.gridK = 0)
    (record : recordAt s s.checkpoint.height = some s.checkpoint) :
    (BlockValidity.cuts p bs).getD (s.checkpoint.height-p.height) default =
      ⟨s.checkpoint.elHash,s.checkpoint.cometHash,s.head⟩ := by
  have certified : CertifiedTable s.gridK e.certificate (BlockValidity.cuts p bs) := by
    rw [binding,grid]
    exact chain_certified valid.1 pg hg
  have frontier := accepted_frontier_on_certified_table accepted certified positive cg
  have input := accepted_input accepted binding
  rw [input] at frontier
  simpa only [statement,currentRecord,record,Option.getD_some] using frontier

/-- All settled endpoint fields and the stored snapshot originate in the same checked
trace; all its commits have scheduled, distinct, authenticated >2/3 authorization. -/
theorem accepted_terminal_from_valid_chain {s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    (accepted : land s i leaves e = some t) (valid : BatchValid r p bs blobs)
    (binding : e.certificate = statement r p bs blobs) :
    t.checkpoint.height = (BlockValidity.terminal p bs).height ∧
    t.checkpoint.elHash = (BlockValidity.terminal p bs).elHash ∧
    t.checkpoint.cometHash = (BlockValidity.terminal p bs).cometHash ∧
    t.head = (BlockValidity.terminal p bs).cursor ∧
    t.snapshot = (Consensus.activeAt r.consensus (BlockValidity.terminal p bs).height).cutoff ∧
    t.signals = s.signals ++ [⟨(BlockValidity.terminal p bs).height,
      (BlockValidity.terminal p bs).elHash,(BlockValidity.terminal p bs).stateRoot⟩] ∧
    ∀ b ∈ bs, Consensus.CommitValid r.consensus r.signature b.header.height b.round b.header.cometHash b.votes := by
  have input := accepted_input accepted binding
  obtain ⟨_,rfl⟩ := land_success accepted
  rw [input]
  exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,BlockValidity.chain_commits valid.1⟩

/-- Snapshot monotonicity is derived from authenticated anchor history and actual
committee derivation; the contract itself stores the reported snapshot without a max. -/
theorem accepted_snapshot_monotone {s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    (accepted : land s i leaves e = some t) (valid : BatchValid r p bs blobs)
    (binding : e.certificate = statement r p bs blobs)
    (genesis : r.consensus.genesisCutoff ≤ r.consensus.originBlock)
    (anchors : ∀ a b, a ≤ b → r.consensus.anchorAt a ≤ r.consensus.anchorAt b)
    (stored : s.snapshot = (Consensus.activeAt r.consensus s.checkpoint.height).cutoff) :
    s.snapshot ≤ t.snapshot := by
  have terminal := accepted_terminal_from_valid_chain accepted valid binding
  have advance := (land_extends_checkpoint accepted).1
  rw [stored,terminal.2.2.2.2.1]
  apply Consensus.active_cutoff_monotone r.consensus genesis anchors
  rw [← terminal.1]
  exact Nat.le_of_lt advance

/-- Every active cutoff is at least the generation floor (given genesisCutoff ≤ origin block):
the initial committee uses the floor and every rotation takes max(anchor, origin block). -/
theorem floor_le_active (c : Consensus.Context) (genesis : c.genesisCutoff ≤ c.originBlock) (h : Nat) :
    floor c ≤ (Consensus.activeAt c h).cutoff := by
  have initial : (Consensus.initial c).cutoff = floor c := rfl
  have normal : ∀ t, floor c ≤ (Consensus.normal c t).cutoff := by
    intro t
    unfold Consensus.normal Consensus.selected floor
    dsimp only
    split <;> omega
  unfold Consensus.activeAt
  dsimp only
  split
  · exact normal _
  · exact Nat.le_of_eq initial.symm

/-- `accepted_snapshot_monotone` without its within-generation-only premise: an accepted
valid batch never lowers a fitting snapshot, including the first landing of a generation,
and afterwards the snapshot tracks the batch's context at the new checkpoint. -/
theorem accepted_snapshot_monotone_from {s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    (accepted : land s i leaves e = some t) (valid : BatchValid r p bs blobs)
    (binding : e.certificate = statement r p bs blobs)
    (genesis : r.consensus.genesisCutoff ≤ r.consensus.originBlock)
    (anchors : ∀ a b, a ≤ b → r.consensus.anchorAt a ≤ r.consensus.anchorAt b)
    (fits : SnapshotFits r.consensus s) :
    s.snapshot ≤ t.snapshot ∧ t.snapshot = (Consensus.activeAt r.consensus t.checkpoint.height).cutoff := by
  have terminal := accepted_terminal_from_valid_chain accepted valid binding
  have advance := (land_extends_checkpoint accepted).1
  rw [terminal.2.2.2.2.1,terminal.1]
  refine ⟨?_,rfl⟩
  rcases fits with stored | below
  · rw [stored]
    apply Consensus.active_cutoff_monotone r.consensus genesis anchors
    rw [← terminal.1]
    exact Nat.le_of_lt advance
  · exact Nat.le_trans below (floor_le_active r.consensus genesis _)

/-- Trace-level slot-284 monotonicity within a generation: from a fitting snapshot (e.g. right
after a recovery), every certified landing sequence under c keeps it nondecreasing and fitting.
Not claimed for raw uncertified landings (the contract stores the proven value without a max)
or across a rollback, which restores an older trusted snapshot by design. -/
theorem certified_trace_snapshot_monotone {c : Consensus.Context} {start finish : State}
    (genesis : c.genesisCutoff ≤ c.originBlock) (anchors : ∀ a b, a ≤ b → c.anchorAt a ≤ c.anchorAt b)
    (fits : SnapshotFits c start) (trace : CertifiedTrace c start finish) :
    start.snapshot ≤ finish.snapshot ∧ SnapshotFits c finish := by
  induction trace with
  | refl => exact ⟨Nat.le_refl _,fits⟩
  | step _ accepted context valid binding ih =>
    subst context
    have next := accepted_snapshot_monotone_from accepted valid binding genesis anchors ih.2
    exact ⟨Nat.le_trans ih.1 next.1,Or.inl next.2⟩

theorem landing_preserves_state {s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    (before : StateValid s) (accepted : land s i leaves e = some t) : StateValid t := by
  have advance := (land_extends_checkpoint accepted).1
  have grid := land_preserves_grid accepted before.2.2.1
  obtain ⟨_,rfl⟩ := land_success accepted
  refine ⟨?_,rfl,grid,?_,?_⟩
  · simp [recordAt,applyLanding,landedCheckpoint]
  · simp only [applyLanding,List.map_cons,List.nodup_cons]
    refine ⟨?_,before.2.2.2.1⟩
    intro mem
    obtain ⟨old,oldMem,same⟩ := List.mem_map.mp mem
    have bounded := before.2.2.2.2 old oldMem
    change s.checkpoint.height < i.lastHeight at advance
    change old.height = i.lastHeight at same
    omega
  · intro old mem
    simp only [applyLanding,List.mem_cons] at mem
    rcases mem with rfl | previous
    · exact Nat.le_refl _
    · have bounded := before.2.2.2.2 old previous
      change s.checkpoint.height < i.lastHeight at advance
      change old.height ≤ i.lastHeight
      omega

theorem landing_preserves_old_records {s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    (accepted : land s i leaves e = some t) (h : Nat) (old : h ≤ s.checkpoint.height) :
    recordAt t h = recordAt s h := by
  have advance := (land_extends_checkpoint accepted).1
  obtain ⟨_,rfl⟩ := land_success accepted
  have different : i.lastHeight ≠ h := by change s.checkpoint.height < i.lastHeight at advance; omega
  simp [recordAt,applyLanding,landedCheckpoint,different]

theorem trace_preserves_state {start finish : State} (valid : StateValid start)
    (trace : LandingTrace start finish) : StateValid finish := by
  induction trace with
  | refl => exact valid
  | step _ accepted ih => exact landing_preserves_state ih accepted

theorem trace_checkpoint_monotone {start finish : State} (trace : LandingTrace start finish) :
    start.checkpoint.height ≤ finish.checkpoint.height := by
  induction trace with
  | refl => exact Nat.le_refl _
  | step _ accepted ih => exact Nat.le_trans ih (Nat.le_of_lt (land_extends_checkpoint accepted).1)

/-- Trace-level DV-10: no landing sequence overwrites or removes a record at or below the
starting checkpoint. -/
theorem trace_preserves_old_records {start finish : State} (trace : LandingTrace start finish) (h : Nat)
    (old : h ≤ start.checkpoint.height) : recordAt finish h = recordAt start h := by
  induction trace with
  | refl => rfl
  | step prior accepted ih =>
    exact (landing_preserves_old_records accepted h (Nat.le_trans old (trace_checkpoint_monotone prior))).trans ih

end Etna.Design.Settlement
