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

end Etna.Design.Current.Protocol
