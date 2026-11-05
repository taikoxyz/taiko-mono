import EtnaModel.ActualQueue
import EtnaModel.SigningBridge
import EtnaModel.RegistryHistory
import EtnaModel.Consensus
import EtnaModel.BlockValidity
import EtnaProofs.RegistryHistory
import EtnaProofs.Consensus
import EtnaProofs.Landing
import EtnaProofs.Forced
import EtnaModel.Encoding
import EtnaModel.Signer
import EtnaModel.Common
import EtnaModel
import EtnaStatements

namespace Etna.Design.ActualQueue

/-- Decode an accepted cursor advance into actual include/skip semantics. This is where
the explicit hash, parser and deterministic singleton contracts are used. -/
theorem opened_advance_action {primitive : Primitives} {p : BlockValidity.Header}
    {b : BlockValidity.Block} {wit : Forced.Witness} {raw : Bytes} {first : Option Bytes} {delay : Nat}
    (fields : PayloadFields primitive p b wit raw first)
    (accepted : Forced.step p.cursor b.header.anchor.tail b.header.anchor.timestamp delay
      (some wit) b.singleton = .accepted (p.cursor+1)) :
    ByteAction primitive p b wit.stored raw first := by
  have flags : (wit.firstHash = some wit.stored.txHash ∧ wit.firstCanonical = true ∧ wit.firstBytes ≤ 8192) ∨
      (wit.rawHash = wit.stored.txHash ∧ wit.rawBytes ≤ 8192 ∧
        (wit.canonical = false ∨ b.singleton = .completedEmpty)) := by
    cases result : b.singleton <;> rw [result] at accepted <;>
      simp only [Forced.step] at accepted <;> (repeat' split at accepted) <;> simp_all <;> omega
  obtain ⟨size,hash,parse,firstHash,firstParse,firstSize,result⟩ := fields
  rcases flags with included | skipped
  · apply Or.inl
    rw [firstHash,firstParse,firstSize] at included
    cases first with
    | none => simp at included
    | some tx => exact ⟨tx,rfl,Option.some.inj included.1,included.2⟩
  · exact Or.inr ⟨hash ▸ skipped.1,size ▸ skipped.2.1,
      skipped.2.2.elim (fun invalid => Or.inl (parse ▸ invalid)) (fun empty => Or.inr (result ▸ empty))⟩

end Etna.Design.ActualQueue
