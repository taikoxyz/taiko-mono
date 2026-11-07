import EtnaProofs.CurrentHistory
import EtnaProofs.CurrentSettlement

namespace Etna.Design.Current.Journal
open Protocol

/-- Primitive backend soundness yields the concrete accepted statement certificate. -/
theorem accepted_image_certificate {env : Environment} {initial w t : World} {a : Landing}
    (soundness : VerifierSound env initial) (reach : Protocol.Trace env initial w)
    (ok : Protocol.land env w a = some t) :
    ∃ proof ∈ a.proofs, ImageCertifies env w proof.image (statement env w a) := by
  obtain ⟨sound,cover,verify⟩ := soundness
  have accepted := (Protocol.land_success ok).1.proofs
  obtain ⟨item,member,good⟩ := cover _ accepted
  obtain ⟨proof,present,rfl⟩ := List.mem_map.mp member
  have all : ∀ x ∈ a.proofs.map (fun p => (p.backend,
      decide (p.image ∈ w.images) && env.verify w.verifier p.backend p.image p.bytes (statement env w a))),
      x.2 = true := by
    simp only [proofsAccepted,dualOK,Bool.and_eq_true,List.all_eq_true] at accepted
    exact accepted.1.1.2
  have verified := all _ (List.mem_map_of_mem present)
  have bytes : env.verify w.verifier proof.backend proof.image proof.bytes (statement env w a) = true := by
    simp only [Bool.and_eq_true] at verified
    exact verified.2
  exact ⟨proof,present,verify w reach a t proof ok present good bytes⟩

/-- Pure backend soundness supplies the bound reference-local statement; its storage
footprint follows from the actual initialized history, not from verifier soundness. -/
theorem accepted_landing_footprint {env : Environment} {registry : RegistryMachine.State}
    {w t : World} {a : Landing} (genesis : RegistryMachine.Genesis registry)
    (soundness : VerifierSound env (empty env registry)) (reach : Protocol.Trace env (empty env registry) w)
    (ok : Protocol.land env w a = some t) : CertificateFootprint env w a.input.l1ReferenceBlockNumber := by
  obtain ⟨proof,_,certificate⟩ := accepted_image_certificate soundness reach ok
  exact certified_statement_footprint genesis reach (image_certificate_forget certificate)

theorem accepted_certificate {env : Environment} {registry : RegistryMachine.State} {w t : World} {a : Landing}
    (genesis : RegistryMachine.Genesis registry)
    (soundness : VerifierSound env (empty env registry)) (reach : Protocol.Trace env (empty env registry) w)
    (ok : Protocol.land env w a = some t) : LiveCertifies env w (statement env w a) := by
  obtain ⟨proof,_,cert⟩ := accepted_image_certificate soundness reach ok
  exact image_certificate_live cert (certified_statement_footprint genesis reach (image_certificate_forget cert))

/-- The certified execution-time suffix consumes precisely [oldHead,newHead), in FIFO
order, and each consuming edge acts on the actual queue entry and decoded payload bytes. -/
theorem landing_service_from_certificate {env : Environment} {registry : RegistryMachine.State}
    {w t : World} {a : Landing} (trace : Protocol.Trace env (empty env registry) w)
    (ok : Protocol.land env w a = some t) (cert : LiveCertifies env w (statement env w a)) :
    ∃ segment : Suffix env w a,
      (Blocks.consumingPairs segment.parent segment.blocks).map (fun x => x.1.cursor) =
        List.range' w.inbox.head (t.inbox.head-w.inbox.head) ∧
      (∀ x ∈ Blocks.consumingPairs segment.parent segment.blocks,
        ∃ entry, (x.1.cursor,entry) ∈ w.queue ∧
          ActualQueue.ByteAction (Blocks.definition
            (policy env w segment.archive a.input.l1ReferenceBlockNumber) x.2).bytes
            x.1 x.2.body entry x.2.raw x.2.first) ∧
      t.queue = w.queue := by
  obtain ⟨checks,state⟩ := Protocol.land_success ok
  have frontier := trace_frontier_record trace checks.started
  obtain ⟨segment⟩ := accepted_suffix_from_certificate ok cert frontier.2.1
  refine ⟨segment,?_,?_,?_⟩
  · have indices := Blocks.chain_consumed_indices segment.valid
    have parentCursor : segment.parent.cursor = w.inbox.head := congrArg Cut.cursor segment.parentCut
    have terminalCursor : (Blocks.terminal segment.parent segment.blocks).cursor = t.inbox.head := by
      rw [state]
      exact congrArg Cut.cursor segment.terminalCut
    simpa only [parentCursor,terminalCursor] using indices
  · intro x member
    exact chain_consumes_actual trace segment.valid member
  · rw [state]; rfl

theorem landing_service {env : Environment} {registry : RegistryMachine.State}
    {w t : World} {a : Landing}
    (genesis : RegistryMachine.Genesis registry)
    (soundness : VerifierSound env (empty env registry))
    (trace : Protocol.Trace env (empty env registry) w)
    (ok : Protocol.land env w a = some t) :
    ∃ segment : Suffix env w a,
      (Blocks.consumingPairs segment.parent segment.blocks).map (fun x => x.1.cursor) =
        List.range' w.inbox.head (t.inbox.head-w.inbox.head) ∧
      (∀ x ∈ Blocks.consumingPairs segment.parent segment.blocks,
        ∃ entry, (x.1.cursor,entry) ∈ w.queue ∧
          ActualQueue.ByteAction (Blocks.definition
            (policy env w segment.archive a.input.l1ReferenceBlockNumber) x.2).bytes
            x.1 x.2.body entry x.2.raw x.2.first) ∧
      t.queue = w.queue :=
  landing_service_from_certificate trace ok (accepted_certificate genesis soundness trace ok)

end Etna.Design.Current.Journal
