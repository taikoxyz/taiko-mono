import EtnaModel.Signer
import EtnaProofs.Common

/-! Proofs about `EtnaModel.Signer`. -/
namespace Etna.Design.Signer

theorem retired_cannot_sign (s : State) (r : Request) (signature : Hash) (persisted : Bool)
    (retired : r.generation ∈ s.retired) : sign s r signature persisted = none := by
  have denied : authorized s r = false := by simp [authorized,retired]
  simp [sign,denied]

theorem untrusted_cannot_sign (s : State) (r : Request) (signature : Hash) (persisted : Bool)
    (untrusted : r.trusted = false) : sign s r signature persisted = none := by
  simp [sign,authorized,untrusted]

theorem retry_returns_original (s : State) (r : Request) (old : Signed) (signature : Hash) (persisted : Bool)
    (allow : authorized s r = true) (found : latest s r.generation = some old)
    (position : old.position = r.position) (bytes : old.bytes = r.bytes) :
    sign s r signature persisted = some (s,old.signature) := by simp [sign,allow,found,position,bytes]

theorem same_position_different_bytes_rejected (s : State) (r : Request) (old : Signed)
    (signature : Hash) (persisted : Bool) (found : latest s r.generation = some old)
    (position : old.position = r.position) (different : old.bytes ≠ r.bytes) :
    sign s r signature persisted = none := by
  simp [sign,found,position,different]

theorem switching_stays_closed (s : State) (domain : Domain) (generation start : Nat) (auth persisted : Bool) :
    (switchDomain s domain generation start auth persisted).ready = false ∧
    (switchDomain s domain generation start auth persisted).log = s.log := by
  simp only [switchDomain]
  split <;> exact ⟨rfl,rfl⟩

theorem successful_switch_retires_old (s : State) (domain : Domain) (generation start : Nat)
    (same : domain = s.domain) (advance : s.activeGeneration < generation)
    (bounded : generation < limit48) (fresh : generation ∉ s.retired) :
    let t := switchDomain s domain generation start true true
    t.activeGeneration = generation ∧ s.activeGeneration ∈ t.retired ∧
    t.startHeight = start ∧ t.log = s.log := by simp [switchDomain,same,advance,bounded,fresh]

theorem uncertain_switch_cannot_sign (s : State) (domain : Domain) (generation start : Nat)
    (auth : Bool) (r : Request) (signature : Hash) (persisted : Bool) :
    sign (switchDomain s domain generation start auth false) r signature persisted = none := by
  simp [switchDomain,sign,authorized]

/-- Signing only ever adds to the persisted log; no request erases or rewinds HRS state. -/
theorem sign_never_drops_log {s t : State} {r : Request} {signature out : Hash} {persisted : Bool}
    (ok : sign s r signature persisted = some (t,out)) : ∃ extra, t.log = extra ++ s.log := by
  unfold sign at ok
  split at ok
  · split at ok
    · split at ok
      · split at ok
        · cases ok; exact ⟨[],rfl⟩
        · contradiction
      · split at ok
        · cases ok; exact ⟨[_],rfl⟩
        · contradiction
    · split at ok
      · cases ok; exact ⟨[_],rfl⟩
      · contradiction
  · contradiction

theorem opening_keeps_logs (s : State) (generation : Nat) (trust logs : Bool) :
    (openSession s generation trust logs).log = s.log ∧
    (openSession s generation trust logs).retired = s.retired := ⟨rfl,rfl⟩

end Etna.Design.Signer
