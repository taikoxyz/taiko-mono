import EtnaModel.CanonicalHistory
import EtnaProofs.NormalSigning
import EtnaProofs.Headline.ChainOfCustody

namespace Etna.Design.CanonicalHistory
open ProtocolState SigningBridge

private theorem edit_ordinary {w t : World} (change : Edit w t) : OrdinaryStep w t := by
  cases change with
  | registration time ok => exact .registration time ok
  | modification time callable ok => exact .modification time callable ok
  | enqueue time blockRange timestampRange ok => exact .enqueue time blockRange timestampRange ok
  | sweep time ok => exact .sweep time ok
  | invalidation time ok => exact .invalidation time ok

private theorem edit_fields {w t : World} (change : Edit w t) :
    t.inbox.checkpoint = w.inbox.checkpoint ∧ t.inbox.snapshot = w.inbox.snapshot ∧
    t.inbox.domain = w.inbox.domain ∧ t.inbox.generation = w.inbox.generation ∧
    t.inbox.origin = w.inbox.origin ∧
    Deployment.parameters t.inbox t.inbox.configuration = Deployment.parameters w.inbox w.inbox.configuration := by
  cases change with
  | registration => exact ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  | modification => exact ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok <;> cases ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  | sweep _ ok =>
    unfold Forced.sweep at ok
    split at ok <;> cases ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  | invalidation _ ok =>
    obtain ⟨_,rfl⟩ := Recovery.invalidation_success ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩

private theorem built_context {w : World} {archive : List Nat} {r template : BlockValidity.Rules}
    (built : Deployment.build w w.inbox.configuration archive template = some r) :
    HistoricalContext.build w.inbox w.registry
      (Deployment.parameters w.inbox w.inbox.configuration) archive = some r.consensus := by
  obtain ⟨_,_,_,_,_,_,_,ctx,constructed,rfl⟩ := Deployment.build_success built
  exact constructed

private theorem terminal_member (parent : BlockValidity.Header) (blocks : List BlockValidity.Block)
    (nonempty : blocks ≠ []) : ∃ b ∈ blocks, b.header = BlockValidity.terminal parent blocks := by
  induction blocks generalizing parent with
  | nil => contradiction
  | cons b rest ih =>
    cases rest with
    | nil => exact ⟨b,by simp,rfl⟩
    | cons next tail =>
      obtain ⟨last,member,equal⟩ := ih b.header (by simp)
      exact ⟨last,List.mem_cons_of_mem b member,equal⟩

/-- Binding real accepted decoded headers to their archive derives terminal coverage;
there is no independent archive-length assertion in the transition relation. -/
theorem accepted_archive_covered {w : World} {s : State} {i : LandInput} {leaves : List Leaf}
    {e : LandingEnv} {r : BlockValidity.Rules} {archive : List Nat}
    {parent : BlockValidity.Header} {blocks : List BlockValidity.Block} {blobs : List Hash}
    (accepted : Etna.Design.land w.inbox i leaves e = some s)
    (valid : Settlement.BatchValid r parent blocks blobs)
    (binding : e.certificate = Settlement.statement r parent blocks blobs)
    (headers : ∀ b ∈ blocks, archive[b.header.height]? = some b.header.anchor.number) :
    s.checkpoint.height < archive.length := by
  have input := Settlement.accepted_input accepted binding
  have allowed := (land_success accepted).1.1.1
  have nonempty : blocks ≠ [] := by
    intro empty
    subst blocks
    rw [input] at allowed
    have below := allowed.2.2.1
    have above := allowed.2.2.2.1
    change parent.height ≤ w.inbox.checkpoint.height at below
    change w.inbox.checkpoint.height < parent.height at above
    omega
  obtain ⟨last,member,equal⟩ := terminal_member parent blocks nonempty
  have present := headers last member
  have height := (Settlement.accepted_terminal_from_valid_chain accepted valid binding).1
  rw [height,← equal]
  exact List.getElem?_eq_some_iff.mp present |>.1

/-- The statement's snapshot/reference inequality follows from decoded L1 origin and
archive bounds plus the accepted certificate, without assuming a selected-cutoff bound. -/
theorem landing_reference_bound {w : World} {s : State} {i : LandInput} {leaves : List Leaf}
    {e : LandingEnv} {r template : BlockValidity.Rules} {archive : List Nat}
    {parent : BlockValidity.Header} {blocks : List BlockValidity.Block} {blobs : List Hash}
    (accepted : Etna.Design.land w.inbox i leaves e = some s)
    (built : Deployment.build w w.inbox.configuration archive template = some r)
    (binding : e.certificate = Settlement.statement r parent blocks blobs)
    (origin : w.inbox.origin.l1Block ≤ r.referenceNumber)
    (anchors : ∀ a ∈ archive, a ≤ r.referenceNumber) :
    i.activeCommitteeSnapshot ≤ i.l1ReferenceBlockNumber := by
  have input := Settlement.accepted_input accepted binding
  obtain ⟨ready,ctx⟩ := HistoricalContext.build_success (built_context built)
  rw [input]
  change (Consensus.activeAt r.consensus (BlockValidity.terminal parent blocks).height).cutoff ≤ r.referenceNumber
  rw [ctx,HistoricalContext.derived_cutoff]
  exact HistoricalContext.cutoff_bounded _ _ _ _ _ origin
    (Nat.le_trans ready.2.2.2.2.2.2.2 origin) anchors

/-- Transport across an ordinary edit reads only fields that the original call preserves. -/
private theorem carry_source {s t : State} {a b : Consensus.Context}
    (source : SnapshotSource s a) (checkpoint : t.checkpoint = s.checkpoint)
    (snapshot : t.snapshot = s.snapshot) (same : a = b) : SnapshotSource t b := by
  subst b
  cases source with
  | atFloor stored => exact .atFloor (snapshot.trans stored)
  | acceptedBatch accepted valid binding history =>
    exact .carriedBatch accepted valid binding history checkpoint snapshot
  | carriedBatch accepted valid binding history cp snap =>
    exact .carriedBatch accepted valid binding history (checkpoint.trans cp) (snapshot.trans snap)
  | extendedArchive accepted valid binding old new covered cp snap =>
    exact .extendedArchive accepted valid binding old new covered (checkpoint.trans cp) (snapshot.trans snap)
  | beforeRecovery accepted valid binding reference generation origin cp snap =>
    exact .beforeRecovery accepted valid binding reference generation origin (checkpoint.trans cp) (snapshot.trans snap)
  | normalRecovery time accepted clock cp snap generation origin =>
    exact .normalRecovery time accepted clock (checkpoint.trans cp) (snapshot.trans snap) generation origin

/-- Induction over actual accepted history supplies a source for every subsequent extension
of the same canonical archive. The simultaneous normal-run invariant supplies the clock
needed by the actual recovery source; neither is stored in the raw relation. -/
private theorem run_invariants {initial w : World} {archive : List Nat} (run : Run initial w archive) :
    NormalSigning.Run initial w ∧ w.inbox.snapshot < w.l1Block ∧
    ∀ (registry : RegistryHistory.State) (more : List Nat),
      SnapshotSource w.inbox (HistoricalContext.derive w.inbox registry
        (Deployment.parameters w.inbox w.inbox.configuration) (archive ++ more)) := by
  induction run with
  | genesis init =>
    refine ⟨.refl _,Deployment.genesis_snapshot_below init,?_⟩
    intro registry more
    apply SnapshotSource.atFloor
    simp only [Settlement.floor,HistoricalContext.derive,init.1,↓reduceIte,Deployment.parameters]
    exact init.2.2.2.2.2.2.2.1
  | @landing w old more s i leaves e r template parent blocks blobs prior time accepted built valid binding headers origin anchors ih =>
    have context := (HistoricalContext.build_success (built_context built)).2
    have source : SnapshotSource w.inbox r.consensus := context ▸ ih.2.2 w.registry more
    have reference := landing_reference_bound accepted built binding origin anchors
    refine ⟨.landing ih.1 time accepted built valid binding source reference,
      land_snapshot_below_block accepted reference,?_⟩
    intro registry future
    apply SnapshotSource.extendedArchive (historyState := w.inbox) (oldRegistry := w.registry)
      (newRegistry := registry) (params := Deployment.parameters w.inbox w.inbox.configuration)
      (oldArchive := old ++ more) (more := future) accepted valid binding context
    · obtain ⟨_,rfl⟩ := land_success accepted
      rfl
    · exact accepted_archive_covered accepted valid binding headers
    · rfl
    · rfl
  | @edit w t archive prior change ih =>
    obtain ⟨cp,snapshot,domain,generation,origin,params⟩ := edit_fields change
    refine ⟨.other ih.1 (edit_ordinary change) (by simpa only [cp] using Nat.le_refl w.inbox.checkpoint.height),?_,?_⟩
    · rw [snapshot]
      exact Nat.lt_of_lt_of_le ih.2.1 (step_clock_monotone (ordinary_step_is_step (edit_ordinary change)))
    · intro registry more
      apply carry_source (ih.2.2 registry more) cp snapshot
      simp only [HistoricalContext.derive,domain,generation,origin,params]
  | @recovery w archive s a origin owner externalOK prior time accepted ih =>
    have ordinary : OrdinaryStep w (recovered w a origin s) := .recovery time accepted
    obtain ⟨_,result⟩ := Recovery.recover_success accepted
    have cp : (recovered w a origin s).inbox.checkpoint = w.inbox.checkpoint := by rw [result]; rfl
    refine ⟨.other ih.1 ordinary (by simpa only [cp] using Nat.le_refl w.inbox.checkpoint.height),?_,?_⟩
    · rw [result]
      change w.inbox.snapshot < origin.l1Block
      omega
    · intro registry more
      apply SnapshotSource.normalRecovery (before := w) time accepted ih.2.1 cp
      · rw [result]; rfl
      · rw [result]; rfl
      · rw [result]; rfl

/-- General lift from raw canonical accepted history, including normal recoveries and all
ordinary edits. No source, selected cutoff, confirmation coverage or key exclusion premise. -/
theorem run_normal {initial w : World} {archive : List Nat} (run : Run initial w archive) :
    NormalSigning.Run initial w := (run_invariants run).1

/-- The prior stored snapshot comes from initialization, an actual accepted batch, or the
actual last normal recovery; archive extension and ordinary edits preserve that provenance. -/
theorem prior_snapshot_source {initial w : World} {archive more : List Nat}
    {r template : BlockValidity.Rules} (run : Run initial w archive)
    (built : Deployment.build w w.inbox.configuration (archive ++ more) template = some r) :
    SnapshotSource w.inbox r.consensus := by
  rw [(HistoricalContext.build_success (built_context built)).2]
  exact (run_invariants run).2.2 w.registry more

/-- The projection retains every original transition in its original order. -/
theorem run_trace {initial w : World} {archive : List Nat} (run : Run initial w archive) :
    Trace initial w := NormalSigning.run_trace (run_normal run)

/-- Forget only the decoded historical annotations: all submitted landing inputs and
all ordinary edits/recoveries remain the exact original Statements.Run constructors. -/
theorem run_statements {env : Etna.Statements.Environment} {initial w : World} {archive : List Nat}
    (run : Run initial w archive) (submitted : Submitted env.submits run) :
    Etna.Statements.Run env initial w := by
  induction submitted with
  | genesis => exact .refl _
  | @landing w old more s i leaves e r template parent blocks blobs history time accepted built valid binding headers origin anchors _ submitted ih =>
    exact .landing ih submitted time accepted
  | edit _ change ih =>
    exact .other ih (ordinary_step_is_step (edit_ordinary change))
      (by simp only [(edit_fields change).1,Nat.le_refl])
  | recovery _ time accepted ih =>
    apply Etna.Statements.Run.other ih (.recovery time accepted)
    obtain ⟨_,rfl⟩ := Recovery.recover_success accepted
    exact Nat.le_refl _

/-- A submitted landing under the unchanged seven headline premises obtains its batch
from submitted_landing_certified. The remaining adapter contract concerns only canonical
EL header identity and L1 reference ancestry. It is deliberately separate from Premises:
the old historyAuthenticated Boolean alone does not establish these decoded facts. -/
theorem submitted_history_landing {env : Etna.Statements.Environment} {initial w : World}
    {archive : List Nat} {s : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    (premises : Etna.Statements.Premises initial env) (prior : Etna.Statements.Run env initial w)
    (history : Run initial w archive) (submitted : env.submits w i leaves e)
    (time : w.l1Block ≤ e.blockNumber) (accepted : Etna.Design.land w.inbox i leaves e = some s)
    (authenticate : ∀ r parent blocks blobs, Etna.Statements.Built env w r →
      Settlement.BatchValid r parent blocks blobs → e.certificate = Settlement.statement r parent blocks blobs →
      ∃ (more : List Nat) (template : BlockValidity.Rules),
        Deployment.build w w.inbox.configuration (archive ++ more) template = some r ∧
        (∀ b ∈ blocks, (archive ++ more)[b.header.height]? = some b.header.anchor.number) ∧
        w.inbox.origin.l1Block ≤ r.referenceNumber ∧ (∀ a ∈ archive ++ more, a ≤ r.referenceNumber)) :
    ∃ more, Run initial (landed w s e.blockNumber) (archive ++ more) := by
  obtain ⟨r,parent,blocks,blobs,built,valid,binding⟩ :=
    Etna.Proofs.submitted_landing_certified premises prior submitted accepted
  obtain ⟨more,template,constructed,headers,origin,anchors⟩ :=
    authenticate r parent blocks blobs built valid binding
  exact ⟨more,.landing history time accepted constructed valid binding headers origin anchors⟩

end Etna.Design.CanonicalHistory
