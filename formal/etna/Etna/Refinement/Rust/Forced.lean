module
public import Etna.FI.Model
public import Etna.Refinement.Rust.EtnaConsensusCore
@[expose] public section
open Aeneas Aeneas.Std
namespace Etna.Refinement.Rust

/-- Result encoding; the proofs establish exact source outputs, including overflow rejection. -/
def word (n : Nat) : U64 := UScalar.ofNatCore (n % 2^64) (Nat.mod_lt _ (by decide))
@[simp] theorem word_val (n : Nat) : (word n).val = n % 2^64 := by simp [word]
@[simp] theorem word_roundtrip (n : U64) : word n.val = n := by
  apply UScalar.eq_of_val_eq
  simp

/-- The six scalar specifications never emit adapter-only malformed/wrongContext errors.
    Their total encoding below does not claim any refinement of those async adapter errors. -/
def error : FI.Error → etna_consensus_core.forced.ForcedError
  | .missingWitness c => .MissingWitness (word c)
  | .unexpectedWitness => .UnexpectedWitness
  | .wrongIndex e g => .WrongIndex (word e) (word g)
  | .tooLarge s => .TooLarge (word s)
  | .hashMismatch => .HashMismatch
  | .needsSingleton | .malformed | .wrongContext => .NeedsSingleton
  | .retained => .Retained
  | .cursorOverflow => .CursorOverflow

def decision : FI.Decision → etna_consensus_core.forced.ForcedDecision
  | .ordinary => .Ordinary
  | .included i => .Included (word i)
  | .skippedInvalid i => .SkippedInvalid (word i)
  | .needsSkip i => .NeedsSkip (word i)

def result (f : α → β) : Except FI.Error α → core.result.Result β etna_consensus_core.forced.ForcedError
  | .ok a => .Ok (f a)
  | .error e => .Err (error e)

def facts (f : etna_consensus_core.forced.ForcedFacts) : FI.ForcedFacts :=
  ⟨f.cursor.val, f.timestamp.val, f.delay.val, f.anchor_timestamp.val,
   f.preimage_len.val, f.preimage_hash_matches, f.preimage_canonical, f.first_matches⟩

theorem rust_pending_refines (cursor tail : U64) (witness : Option U64) :
    etna_consensus_core.forced.pending_entry cursor tail witness =
      .ok (result id (FI.pending cursor.val tail.val (witness.map UScalar.val))) := by
  cases witness with
  | none =>
    by_cases h : tail.val ≤ cursor.val <;>
      simp [etna_consensus_core.forced.pending_entry, FI.pending, UScalar.le_equiv,
        h, result, error]
  | some got =>
    by_cases h : tail.val ≤ cursor.val <;> by_cases e : got.val = cursor.val <;>
      simp [etna_consensus_core.forced.pending_entry, FI.pending, UScalar.le_equiv,
        UScalar.eq_equiv, h, e, result, error]

theorem rust_preimage_refines (size : U64) (hashMatches : Bool) :
    etna_consensus_core.forced.check_preimage size hashMatches =
      .ok (result id (FI.checkPreimage size.val hashMatches)) := by
  by_cases h : 8192 < size.val <;> by_cases z : size.val = 0 <;> cases hashMatches <;>
    simp [etna_consensus_core.forced.check_preimage, FI.checkPreimage,
      etna_consensus_core.forced.MAX_FORCED_TX_BYTES, UScalar.lt_equiv,
      UScalar.eq_equiv, h, z, result, error]

theorem total_result_exists {α : Type} (m : Result α) (p : α → Prop)
    (h : WP.spec m p) : ∃ x, m = .ok x ∧ p x := by
  induction m using Result.cases with
  | ret x => exact ⟨x, rfl, by simpa using h⟩
  | vis e k => simp at h
  | div => simp at h

theorem rust_is_due_refines (timestamp delay anchor : U64) :
    etna_consensus_core.forced.is_due timestamp delay anchor =
      .ok (FI.isDue timestamp.val delay.val anchor.val) := by
  have bound : (UScalar.cast .U128 timestamp).val + (UScalar.cast .U128 delay).val ≤ U128.max := by
    have ht := timestamp.hBounds
    have hd := delay.hBounds
    norm_num [UScalarTy.numBits] at ht hd
    simp only [U64.cast_U128_val_eq]
    norm_num [U128.max, U128.numBits]
    omega
  obtain ⟨sum, hs, hv⟩ := total_result_exists _ _ (U128.add_spec bound)
  unfold etna_consensus_core.forced.is_due
  simp only [lift, bind_ok, hs]
  simp [FI.isDue, UScalar.le_equiv, hv]

theorem rust_classify_refines (f : etna_consensus_core.forced.ForcedFacts) :
    etna_consensus_core.forced.classify_forced f = .ok (result decision (FI.classify (facts f))) := by
  unfold etna_consensus_core.forced.classify_forced FI.classify
  rw [rust_preimage_refines]
  cases hp : FI.checkPreimage f.preimage_len.val f.preimage_hash_matches with
  | error e =>
    simp [Bind.bind, Except.bind, hp, facts, result, core.result.Result.Insts.CoreOpsTry.branch,
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
      core.convert.FromSame.from]
  | ok u =>
    cases u
    simp only [hp, facts, result, bind_ok, core.result.Result.Insts.CoreOpsTry.branch]
    by_cases hfirst : f.first_matches = true <;>
      by_cases hd : FI.isDue f.timestamp.val f.delay.val f.anchor_timestamp.val = true <;>
      by_cases hh : f.preimage_hash_matches = true <;>
      by_cases hc : f.preimage_canonical = true <;>
      simp [Bind.bind, Pure.pure, Except.bind, Except.pure, hfirst,
        rust_is_due_refines, hd, hh, hc, decision, error]

def modelDecision : etna_consensus_core.forced.ForcedDecision → FI.Decision
  | .Ordinary => .ordinary
  | .Included i => .included i.val
  | .SkippedInvalid i => .skippedInvalid i.val
  | .NeedsSkip i => .needsSkip i.val

def modelOutcome : etna_consensus_core.forced.SingletonOutcome → FI.SingletonOutcome
  | .NotBuilt => .unavailable
  | .Empty => .completedEmpty
  | .Retained => .retained

theorem rust_resolve_refines (d : etna_consensus_core.forced.ForcedDecision)
    (o : etna_consensus_core.forced.SingletonOutcome) :
    etna_consensus_core.forced.resolve_forced d o =
      .ok (result (Option.map word) (FI.resolve (modelDecision d) (modelOutcome o))) := by
  cases d <;> cases o <;>
    simp [etna_consensus_core.forced.resolve_forced, FI.resolve, modelDecision, modelOutcome,
      result, error]

theorem rust_advance_refines (cursor : U64) (consumed : Option U64) :
    etna_consensus_core.forced.advance_cursor cursor consumed =
      .ok (result word (FI.advance cursor.val (consumed.map UScalar.val))) := by
  cases consumed with
  | none => simp [etna_consensus_core.forced.advance_cursor, FI.advance, result]
  | some got =>
    by_cases e : got.val = cursor.val
    · have hc := U64.checked_add_bv_spec cursor 1#u64
      cases ha : U64.checked_add cursor 1#u64 with
      | none =>
        simp [ha, U64.max, U64.numBits] at hc
        have hn : ¬ cursor.val + 1 < 18446744073709551616 := by omega
        simp [etna_consensus_core.forced.advance_cursor, FI.advance, result, error,
          UScalar.eq_equiv, e, ha, lift, hn]
      | some next =>
        simp [ha, U64.max, U64.numBits] at hc
        have hn : cursor.val + 1 < 18446744073709551616 := by omega
        have he : word (cursor.val + 1) = next := by
          apply UScalar.eq_of_val_eq
          simp [Nat.mod_eq_of_lt hn, hc.2.1]
        simp [etna_consensus_core.forced.advance_cursor, FI.advance, result,
          UScalar.eq_equiv, e, ha, lift, hn, he]
    · simp [etna_consensus_core.forced.advance_cursor, FI.advance, result, error,
        e]
end Etna.Refinement.Rust
