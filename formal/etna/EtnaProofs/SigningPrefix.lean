import EtnaProofs.HistoricalContext
import EtnaProofs.Settlement

/-! Selected cutoffs on a shared decoded historical context. A successful historical
build binds selection to the sorted anchor archive and the registry history. An accepted
valid landing supplies the stored snapshot from that very context. Authentication and
request-to-chain binding remain obligations of the caller. -/
namespace Etna.Design.SigningPrefix

/-- A successful build supplies the genesis floor and actual archive lookup needed for
monotonicity. No ordering assumption on the selected cutoffs is supplied by the caller. -/
theorem built_active_cutoff_monotone {s : State} {registry : RegistryHistory.State}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {ctx : Consensus.Context}
    {a b : Nat} (built : HistoricalContext.build s registry cfg archive = some ctx)
    (order : a ≤ b) :
    (Consensus.activeAt ctx a).cutoff ≤ (Consensus.activeAt ctx b).cutoff := by
  obtain ⟨ready,rfl⟩ := HistoricalContext.build_success built
  apply Consensus.active_cutoff_monotone
  · exact ready.2.2.2.2.2.2.2
  · intro a b order
    exact HistoricalContext.derived_anchors_monotone s registry cfg archive order
  · exact order

/-- Slot 284 of an actual accepted batch is bounded by selection at every height at or
after that batch's terminal height, when both use the same built history. This derives
the stored-snapshot link from landing and certificate binding, without SnapshotFits. -/
theorem accepted_land_cutoff_bound {s t : State} {i : LandInput} {leaves : List Leaf}
    {e : LandingEnv} {r : BlockValidity.Rules} {p : BlockValidity.Header}
    {bs : List BlockValidity.Block} {blobs : List Hash} {registry : RegistryHistory.State}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {h : Nat}
    (accepted : land s i leaves e = some t) (valid : Settlement.BatchValid r p bs blobs)
    (binding : e.certificate = Settlement.statement r p bs blobs)
    (built : HistoricalContext.build s registry cfg archive = some r.consensus)
    (later : i.lastHeight ≤ h) :
    t.snapshot ≤ (Consensus.activeAt r.consensus h).cutoff := by
  have endpoint := Settlement.accepted_terminal_from_valid_chain accepted valid binding
  have last := congrArg LandInput.lastHeight (Settlement.accepted_input accepted binding)
  change i.lastHeight = (BlockValidity.terminal p bs).height at last
  rw [endpoint.2.2.2.2.1]
  exact built_active_cutoff_monotone built (by omega)

/-- The ordinary switch announced at S(t) retains old authority through S(t)+1 and
activates the same record selected by activeAt at S(t)+2. This includes a recovery
origin in an earlier part of the epoch; only switches actually after the origin apply. -/
theorem switch_schedule_agrees (ctx : Consensus.Context) (t : Nat) (previous : Committee.Schedule)
    (positive : 0 < t) (length : 3 ≤ ctx.epochLen)
    (occurred : ctx.originHeight < Consensus.switchHeight ctx t)
    (governing : Committee.authority previous (Consensus.switchHeight ctx t) =
      Consensus.activeAt ctx (Consensus.switchHeight ctx t)) :
    let switch := Consensus.switchHeight ctx t
    let schedule := Committee.announce previous switch (Consensus.normal ctx t)
    Committee.authority schedule switch = Consensus.activeAt ctx switch ∧
    Committee.authority schedule (switch+1) = Consensus.activeAt ctx (switch+1) ∧
    Committee.authority schedule (switch+2) = Consensus.activeAt ctx (switch+2) := by
  have product : 1 ≤ t*ctx.epochLen := by
    exact Nat.le_trans (by omega : 1 ≤ ctx.epochLen)
      (Nat.le_mul_of_pos_left ctx.epochLen positive)
  have switch_next : Consensus.switchHeight ctx t+1 = t*ctx.epochLen := by
    unfold Consensus.switchHeight
    omega
  have activation : Consensus.switchHeight ctx t+2 = t*ctx.epochLen+1 := by
    omega
  have old := Consensus.switch_keeps_old_authority ctx t positive length
  have incoming := Consensus.active_at_handover ctx t (by omega) occurred
  have schedule := Committee.h_plus_two previous
    (Consensus.switchHeight ctx t) (Consensus.normal ctx t)
  dsimp only
  refine ⟨schedule.1.trans governing,?_,?_⟩
  · rw [schedule.2.1,governing]
    rw [switch_next]
    exact old
  · rw [schedule.2.2,activation,incoming]

/-- Appending future authenticated headers preserves every covered past selection
cutoff, including while the registry history advances independently. -/
theorem extended_archive_cutoff (s : State) (oldRegistry newRegistry : RegistryHistory.State)
    (cfg : HistoricalContext.Parameters) (archive more : List Nat) (h : Nat) (covered : h < archive.length) :
    (Consensus.activeAt (HistoricalContext.derive s oldRegistry cfg archive) h).cutoff =
      (Consensus.activeAt (HistoricalContext.derive s newRegistry cfg (archive ++ more)) h).cutoff := by
  rw [HistoricalContext.derived_cutoff,HistoricalContext.derived_cutoff]
  exact (HistoricalContext.cutoff_prefix_stable s cfg archive more h covered).symm

end Etna.Design.SigningPrefix
