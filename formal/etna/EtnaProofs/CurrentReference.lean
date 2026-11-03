import EtnaModel.CurrentProtocol

namespace Etna.Design.Current.Protocol

theorem image_certificate_forget {env : Environment} {w : World} {image : Hash}
    {d : StatementData} (cert : ImageCertifies env w image d) : Certifies env w d := by
  obtain ⟨archive,parent,blocks,certificate,_⟩ := cert
  exact ⟨archive,parent,blocks,certificate⟩

theorem reference_hash_binds_prefix {env : Environment} (binding : ReferenceBinding env)
    {a b : World} {number : Nat}
    (same : referenceHash env a number = referenceHash env b number) :
    referencePrefix a number = referencePrefix b number := binding _ _ _ same

theorem different_prefix_changes_reference {env : Environment} (binding : ReferenceBinding env)
    {a b : World} {number : Nat}
    (different : referencePrefix a number ≠ referencePrefix b number) :
    referenceHash env a number ≠ referenceHash env b number := by
  intro same
  exact different (reference_hash_binds_prefix binding same)

theorem certificate_world_of_prefix {env : Environment} {a b : World} {reference : Nat}
    (same : referencePrefix a reference = referencePrefix b reference) :
    certificateWorld env a reference = certificateWorld env b reference := by
  unfold certificateWorld
  rw [same]

theorem certificate_world_idempotent {env : Environment} {w : World} {reference : Nat} :
    certificateWorld env (certificateWorld env w reference) reference = certificateWorld env w reference := by
  apply certificate_world_of_prefix
  simp [referencePrefix,certificateWorld,List.take_take]

theorem batch_certificate_transport {env : Environment} {a b : World} {d : StatementData}
    {archive : List Header} {p : Header} {bs : List Block}
    (closed : referencePrefix a d.input.l1ReferenceBlockNumber = referencePrefix b d.input.l1ReferenceBlockNumber)
    (cert : BatchCertificate env a d archive p bs) : BatchCertificate env b d archive p bs := by
  unfold BatchCertificate at cert ⊢
  rw [← certificate_world_of_prefix closed,← closed]
  exact cert

/-- Any certificate transports across worlds sharing its complete closed reference
prefix. Later calls, registry changes, images and the execution frontier are unrestricted. -/
theorem certificate_transport {env : Environment} {a b : World} {da db : StatementData}
    (same : da = db)
    (closed : referencePrefix a da.input.l1ReferenceBlockNumber = referencePrefix b db.input.l1ReferenceBlockNumber)
    (cert : Certifies env a da) : Certifies env b db := by
  subst db
  obtain ⟨archive,parent,blocks,checked,canonical,origin⟩ := cert
  refine ⟨archive,parent,blocks,?_,?_,?_⟩
  · rw [← certificate_world_of_prefix closed]
    exact checked
  · rw [← closed]; exact canonical
  · rw [← certificate_world_of_prefix closed]
    exact origin

/-- Equal full submitted statements and the ideal reference commitment binding give
general certificate reuse, including after another landing advances the frontier. -/
theorem equal_statement_certificate_transport {env : Environment} (binding : ReferenceBinding env)
    {a b : World} {la lb : Landing}
    (same : statement env a la = statement env b lb)
    (cert : Certifies env a (statement env a la)) : Certifies env b (statement env b lb) := by
  have reference := congrArg (fun d : StatementData => d.input.l1ReferenceBlockNumber) same
  have hash := congrArg StatementData.referenceHash same
  change la.input.l1ReferenceBlockNumber = lb.input.l1ReferenceBlockNumber at reference
  change referenceHash env a la.input.l1ReferenceBlockNumber = referenceHash env b lb.input.l1ReferenceBlockNumber at hash
  rw [← reference] at hash
  exact certificate_transport same (by
    change referencePrefix a la.input.l1ReferenceBlockNumber = referencePrefix b lb.input.l1ReferenceBlockNumber
    rw [← reference]
    exact reference_hash_binds_prefix binding hash) cert

end Etna.Design.Current.Protocol
