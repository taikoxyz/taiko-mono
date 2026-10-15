module
import all Aeneas.Std.Scalar.SaturatingOps
public import Etna.Committee.Transition
public import Etna.Refinement.Rust.Forced
@[expose] public section
open Aeneas Aeneas.Std
namespace Etna.Refinement.Rust.Committee
open Etna.Refinement.Rust

def schedule (s : etna_consensus_core.schedule.Schedule) : Etna.Committee.Schedule :=
  ⟨s.l1_0.val, s.epoch_len.val, s.epoch_len_l1.val, s.genesis_cutoff.val⟩

theorem checked_add (a b : U64) : U64.checked_add a b = (Etna.Committee.add a.val b.val).map word := by
  have spec := U64.checked_add_bv_spec a b
  cases h : U64.checked_add a b with
  | none =>
    simp [h, U64.max, U64.numBits] at spec
    have hn : ¬ a.val+b.val ≤ Etna.Committee.max64 := by norm_num [Etna.Committee.max64]; omega
    simp [Etna.Committee.add, Etna.Committee.checked, hn]
  | some v =>
    simp [h, U64.max, U64.numBits] at spec
    have bound : a.val+b.val ≤ Etna.Committee.max64 := spec.1
    simp [Etna.Committee.add, Etna.Committee.checked, bound]
    apply UScalar.eq_of_val_eq
    simp [word_val, ← spec.2.1]

theorem checked_mul (a b : U64) : U64.checked_mul a b = (Etna.Committee.mul a.val b.val).map word := by
  have spec := U64.checked_mul_bv_spec a b
  cases h : U64.checked_mul a b with
  | none =>
    simp [h, U64.max, U64.numBits] at spec
    have hn : ¬ a.val*b.val ≤ Etna.Committee.max64 := by norm_num [Etna.Committee.max64]; omega
    simp [Etna.Committee.mul, Etna.Committee.checked, hn]
  | some v =>
    simp [h, U64.max, U64.numBits] at spec
    have bound : a.val*b.val ≤ Etna.Committee.max64 := spec.1
    simp [Etna.Committee.mul, Etna.Committee.checked, bound]
    apply UScalar.eq_of_val_eq
    simp [word_val, ← spec.2.1]

theorem checked_sub (a b : U64) : U64.checked_sub a b = (Etna.Committee.sub a.val b.val).map word := by
  have spec := U64.checked_sub_bv_spec a b
  cases h : U64.checked_sub a b with
  | none => simp [h] at spec; simp [Etna.Committee.sub]; omega
  | some v =>
    simp [h] at spec
    simp [Etna.Committee.sub, spec.1]
    apply UScalar.eq_of_val_eq
    simp [word_val, ← spec.2.1]

theorem checked_div (a b : U64) : U64.checked_div a b = (Etna.Committee.div a.val b.val).map word := by
  have spec := U64.checked_div_bv_spec a b
  cases h : U64.checked_div a b with
  | none => simp [h] at spec; simp [Etna.Committee.div, spec]
  | some v =>
    simp [h] at spec
    simp [Etna.Committee.div, spec.1]
    apply UScalar.eq_of_val_eq
    simp [word_val, ← spec.2.1]

theorem checked_bound {n v : Nat} (h : Etna.Committee.checked n = some v) : v < 2^64 := by
  have := Etna.Committee.checked_some.mp h
  norm_num [Etna.Committee.max64] at this ⊢; omega

def scheduleError : Etna.Committee.ScheduleError → etna_consensus_core.schedule.ScheduleError
  | .tooShort => .EpochTooShort | .shorterThanCap => .EpochShorterThanCap | .zeroL1 => .ZeroEpochLenL1
def scheduleResult : Except Etna.Committee.ScheduleError Unit → core.result.Result Unit etna_consensus_core.schedule.ScheduleError
  | .ok u => .Ok u | .error e => .Err (scheduleError e)

theorem rust_validate_refines (s : etna_consensus_core.schedule.Schedule) (cap : U64) :
    etna_consensus_core.schedule.Schedule.validate s cap = .ok (scheduleResult (Etna.Committee.validate (schedule s) cap.val)) := by
  by_cases hshort : s.epoch_len.val < 3
  · simp [etna_consensus_core.schedule.Schedule.validate, Etna.Committee.validate, schedule, UScalar.lt_equiv, hshort, scheduleResult, scheduleError]
  unfold etna_consensus_core.schedule.Schedule.validate Etna.Committee.validate
  simp only [schedule, UScalar.lt_equiv, UScalar.eq_equiv]
  rw [checked_add]
  cases h : Etna.Committee.add cap.val 3 with
  | none => simp [h, lift, hshort, scheduleResult, scheduleError]
  | some n =>
    have hn := checked_bound h
    have hn' : n % 18446744073709551616 = n := Nat.mod_eq_of_lt hn
    by_cases hsmall : s.epoch_len.val < n <;> by_cases hz : s.epoch_len_l1.val = 0 <;>
      simp [h, lift, word_val, hn', hshort, hsmall, hz, scheduleResult, scheduleError]

theorem word_small {n : Nat} (h : n < 2^64) : (word n).val = n := by
  exact Nat.mod_eq_of_lt h

theorem rust_first_refines (s : etna_consensus_core.schedule.Schedule) (t : U64) :
    etna_consensus_core.schedule.Schedule.h_first s t = .ok ((Etna.Committee.first (schedule s) t.val).map word) := by
  unfold etna_consensus_core.schedule.Schedule.h_first Etna.Committee.first
  rw [checked_mul]
  cases h : Etna.Committee.mul t.val s.epoch_len.val with
  | none => simp [schedule, h, lift]
  | some n => simp [schedule, h, lift, checked_add, word_small (checked_bound h)]

theorem first_bound {s : Etna.Committee.Schedule} {t v : Nat}
    (h : Etna.Committee.first s t = some v) : v < 2^64 := by
  unfold Etna.Committee.first at h
  cases hm : Etna.Committee.mul t s.length with
  | none => simp [hm] at h
  | some n => simp only [hm, Option.bind_some] at h; exact checked_bound h

theorem rust_last_refines (s : etna_consensus_core.schedule.Schedule) (t : U64) :
    etna_consensus_core.schedule.Schedule.h_last s t = .ok ((Etna.Committee.last (schedule s) t.val).map word) := by
  unfold etna_consensus_core.schedule.Schedule.h_last Etna.Committee.last
  rw [checked_add]
  cases h : Etna.Committee.add t.val 1 with
  | none => simp [h, lift]
  | some n =>
    simp only [lift, bind_ok, rust_first_refines]
    simp only [show (1#u64).val = 1 from rfl, h, Option.map_some, word_small (checked_bound h)]
    cases hf : Etna.Committee.first (schedule s) n with
    | none => simp [hf]
    | some v => simp [hf, checked_sub, word_small (first_bound hf)]

theorem rust_l1First_refines (s : etna_consensus_core.schedule.Schedule) (t : U64) :
    etna_consensus_core.schedule.Schedule.checked_l1_first s t = .ok ((Etna.Committee.l1First (schedule s) t.val).map word) := by
  unfold etna_consensus_core.schedule.Schedule.checked_l1_first Etna.Committee.l1First
  rw [checked_mul]
  cases h : Etna.Committee.mul t.val s.epoch_len_l1.val with
  | none => simp [schedule, h, lift]
  | some n => simp [schedule, h, lift, checked_add, word_small (checked_bound h)]

theorem rust_parent_refines (s : etna_consensus_core.schedule.Schedule) (t : U64) :
    etna_consensus_core.schedule.Schedule.derivation_parent_height s t = .ok ((Etna.Committee.parentHeight (schedule s) t.val).map word) := by
  unfold etna_consensus_core.schedule.Schedule.derivation_parent_height Etna.Committee.parentHeight
  by_cases hz : t.val = 0
  · simp [UScalar.eq_equiv, hz]
  simp only [UScalar.eq_equiv, hz, ↓reduceIte, rust_first_refines]
  cases hf : Etna.Committee.first (schedule s) t.val with
  | none => simp [hf, hz]
  | some v => simp [hf, hz, checked_sub, word_small (first_bound hf)]

theorem saturating_val (h : U64) : (core.num.U64.saturating_sub h 1#u64).val = h.val-1 := by
  change (max 0 (h.val - 1)) % 2^64 = h.val - 1
  rw [Nat.zero_max]
  exact Nat.mod_eq_of_lt (lt_of_le_of_lt (Nat.sub_le _ _) h.hBounds)

theorem rust_epoch_refines (s : etna_consensus_core.schedule.Schedule) (h : U64) :
    etna_consensus_core.schedule.Schedule.epoch_of s h = .ok ((Etna.Committee.epochOf (schedule s) h.val).map word) := by
  simp [etna_consensus_core.schedule.Schedule.epoch_of, lift, checked_div,
    saturating_val, Etna.Committee.epochOf, schedule]

theorem sub_bound {a b v : Nat} (h : Etna.Committee.sub a b = some v) (ha : a < 2^64) : v < 2^64 := by
  unfold Etna.Committee.sub at h
  split_ifs at h <;> simp_all; omega

theorem rust_starting_refines (s : etna_consensus_core.schedule.Schedule) (h : U64) :
    etna_consensus_core.schedule.Schedule.epoch_starting_at s h = .ok ((Etna.Committee.startingAt (schedule s) h.val).map word) := by
  unfold etna_consensus_core.schedule.Schedule.epoch_starting_at Etna.Committee.startingAt
  by_cases hz : s.epoch_len.val = 0
  · simp [schedule, UScalar.eq_equiv, hz]
  have nonzero : s.epoch_len ≠ 0#u64 := by simpa [UScalar.eq_equiv] using hz
  simp only [schedule, UScalar.eq_equiv, hz, ↓reduceIte, checked_sub]
  cases hs : Etna.Committee.sub h.val 1 with
  | none => simp [hs, lift]
  | some n =>
    have hn := sub_bound hs h.hBounds
    obtain ⟨r, hr, rv⟩ := total_result_exists _ _ (U64.rem_spec (word n) hz)
    obtain ⟨q, hq, qv⟩ := UScalar.div_spec (word n) hz
    have wr : word (n / s.epoch_len.val) = q := by
      apply UScalar.eq_of_val_eq
      simp only [word_small hn] at qv
      simp [← qv]
    simp only [show (1#u64).val = 1 from rfl, hs, Option.map_some, lift, bind_ok, hr, hq, Option.bind_some]
    by_cases hm : n % s.epoch_len.val = 0 <;>
      simp [UScalar.eq_equiv, rv, word_small hn, hm, wr, hz]



theorem starting_bound {s : Etna.Committee.Schedule} {h t : Nat}
    (hs : Etna.Committee.startingAt s h = some t) (hh : h < 2^64) : t < 2^64 := by
  unfold Etna.Committee.startingAt at hs
  by_cases hz : s.length = 0
  · simp [hz] at hs
  simp only [hz, ↓reduceIte] at hs
  cases he : Etna.Committee.sub h 1 with
  | none => simp [he] at hs
  | some n =>
    have hn := sub_bound he hh
    simp only [he, Option.bind_some] at hs
    split_ifs at hs <;> simp_all
    have := Nat.div_le_self n s.length
    omega

theorem rust_switch_refines (s : etna_consensus_core.schedule.Schedule) (h : U64) :
    etna_consensus_core.schedule.Schedule.switch_target s h = .ok ((Etna.Committee.switchTarget (schedule s) h.val).map word) := by
  unfold etna_consensus_core.schedule.Schedule.switch_target Etna.Committee.switchTarget
  rw [checked_add]
  simp only [show (2#u64).val = 2 from rfl]
  cases ha : Etna.Committee.add h.val 2 with
  | none => simp [ha, lift]
  | some n =>
    simp only [ha, Option.map_some, lift, bind_ok, rust_starting_refines, word_small (checked_bound ha), Option.bind_some]
    cases ht : Etna.Committee.startingAt (schedule s) n with
    | none => simp [ht]
    | some t =>
      have ht' := word_small (starting_bound ht (checked_bound ha))
      simp only [ht, Option.map_some, bind_ok, Option.bind_some]
      split <;> rename_i he
      · have hv : t = 0 := by
          have hv := congrArg UScalar.val he
          change (word t).val = 0 at hv
          simpa only [ht'] using hv
        simp [hv]
      · have hv : t ≠ 0 := by
          intro hz
          apply he
          apply UScalar.eq_of_val_eq
          change (word t).val = 0
          simp [hz]
        simp [hv]

theorem epoch_bound {s : Etna.Committee.Schedule} {h t : Nat}
    (hs : Etna.Committee.epochOf s h = some t) (hh : h < 2^64) : t < 2^64 := by
  unfold Etna.Committee.epochOf Etna.Committee.div at hs
  split_ifs at hs <;> simp_all
  have := Nat.div_le_self (h-1) s.length
  omega

theorem rust_next_refines (s : etna_consensus_core.schedule.Schedule) (h : U64) :
    etna_consensus_core.schedule.Schedule.next_switch_target s h = .ok ((Etna.Committee.nextSwitch (schedule s) h.val).map word) := by
  unfold etna_consensus_core.schedule.Schedule.next_switch_target Etna.Committee.nextSwitch
  rw [checked_add]
  simp only [show (1#u64).val = 1 from rfl]
  cases ha : Etna.Committee.add h.val 1 with
  | none => simp [ha, lift]
  | some n =>
    simp only [ha, Option.map_some, lift, bind_ok, rust_epoch_refines, word_small (checked_bound ha), Option.bind_some]
    cases ht : Etna.Committee.epochOf (schedule s) n with
    | none => simp [ht]
    | some t => simp [ht, checked_add, word_small (epoch_bound ht (checked_bound ha))]

/-- Exact total output for the overflow-safe source formula, with the full u128 input domain. -/
theorem rust_quorum_refines (signed total : U128) :
    etna_consensus_core.has_strict_quorum signed total = .ok (decide (3*signed.val > 2*total.val)) := by
  obtain ⟨q, hq, qv⟩ := UScalar.div_spec total (y := 3#u128) (by decide)
  obtain ⟨r, hr, rv⟩ := total_result_exists _ _ (U128.rem_spec total (y := 3#u128) (by decide))
  simp only [show (3#u128).val = 3 from rfl] at qv rv
  have tb := total.hBounds
  have rem := Nat.mod_lt total.val (by omega : 0 < 3)
  have split := Nat.div_add_mod total.val 3
  have qb : q.val * (2#u128).val ≤ U128.max := by
    norm_num [U128.max, U128.numBits, UScalarTy.numBits] at tb ⊢
    omega
  have rb : r.val * (2#u128).val ≤ U128.max := by
    norm_num [U128.max, U128.numBits]
    omega
  obtain ⟨a, ha, av⟩ := total_result_exists _ _ (U128.mul_spec qb)
  obtain ⟨b, hb, bv⟩ := total_result_exists _ _ (U128.mul_spec rb)
  obtain ⟨c, hc, cv⟩ := UScalar.div_spec b (y := 3#u128) (by decide)
  simp only [show (2#u128).val = 2 from rfl, show (3#u128).val = 3 from rfl] at av bv cv
  have ab : a.val+c.val ≤ U128.max := by
    norm_num [U128.max, U128.numBits, UScalarTy.numBits] at tb ⊢
    omega
  obtain ⟨v, hv, vv⟩ := total_result_exists _ _ (U128.add_spec ab)
  unfold etna_consensus_core.has_strict_quorum
  simp only [hq, ha, hr, hb, hc, hv, bind_ok]
  congr 1
  simp only [UScalar.lt_equiv]
  have hi : v.val < signed.val ↔ 3*signed.val > 2*total.val := by omega
  simp only [hi]


def modelRelation : etna_consensus_core.transition.DerivedRelation → Etna.Committee.Relation
  | .None => .none | .Absent t => .absent t.val | .Equal t => .equal t.val | .Conflicting t => .conflict t.val
def encodePlan (p : Etna.Committee.Plan) : etna_consensus_core.transition.CommitteePlan :=
  ⟨p.insertEpoch.map word, p.switch.map (fun sw => ⟨word sw.outgoing, word sw.incoming, word sw.pruneBefore⟩)⟩
/-- The plan emits only conflict/unknown; all remaining constructors belong to adapters. -/
def planError : Etna.Committee.Failure → etna_consensus_core.transition.CommitteeError
  | .conflict t => .Conflict (word t) | .unknown t => .Unknown (word t)
  | _ => .Unknown (word 0)
def planResult : Except Etna.Committee.Failure Etna.Committee.Plan → core.result.Result etna_consensus_core.transition.CommitteePlan etna_consensus_core.transition.CommitteeError
  | .ok p => .Ok (encodePlan p) | .error e => .Err (planError e)

theorem switch_bound {s : Etna.Committee.Schedule} {h t : Nat}
    (hs : Etna.Committee.switchTarget s h = some t) : t < 2^64 := by
  unfold Etna.Committee.switchTarget at hs
  cases ha : Etna.Committee.add h 2 with
  | none => simp [ha] at hs
  | some n =>
    simp only [ha, Option.bind_some] at hs
    cases ht : Etna.Committee.startingAt s n with
    | none => simp [ht] at hs
    | some e =>
      have hb := starting_bound ht (checked_bound ha)
      simp only [ht, Option.bind_some] at hs
      split_ifs at hs <;> simp_all

theorem rust_transition_refines (s : etna_consensus_core.schedule.Schedule) (h : U64)
    (f : etna_consensus_core.transition.CommitteeFacts) :
    etna_consensus_core.transition.transition_committee s h f =
      .ok (planResult (Etna.Committee.plan (schedule s) h.val (modelRelation f.derived) f.outgoing_known f.incoming_known)) := by
  cases hs : Etna.Committee.switchTarget (schedule s) h.val with
  | none =>
    cases f with | mk derived outgoing incoming =>
      cases derived <;>
        simp [etna_consensus_core.transition.transition_committee, rust_switch_refines, hs,
          Etna.Committee.plan, modelRelation, planResult, encodePlan, planError,
          Bind.bind, Except.bind, Pure.pure, Except.pure]
  | some t =>
    have positive := Etna.Committee.switch_positive hs
    have different : t-1 ≠ t := by omega
    have wt := word_small (switch_bound hs)
    have safe : (1#u64).val ≤ (word t).val := by simp only [wt]; exact positive
    obtain ⟨old, hold, ov⟩ := total_result_exists _ _ (U64.sub_spec safe)
    have ov' : old.val = t-1 := by simpa only [wt, show (1#u64).val = 1 from rfl] using ov.1
    have wo : word (t-1) = old := by rw [← ov']; simp
    cases f with | mk derived outgoing incoming =>
      cases derived with
      | None =>
        cases outgoing <;> cases incoming <;>
          simp [etna_consensus_core.transition.transition_committee, rust_switch_refines, hs, hold,
            Etna.Committee.plan, modelRelation, planResult, encodePlan, planError, wo,
            Bind.bind, Except.bind, Pure.pure, Except.pure]
      | Conflicting epoch =>
        simp [etna_consensus_core.transition.transition_committee, Etna.Committee.plan,
          modelRelation, planResult, planError, Bind.bind, Except.bind]
      | Absent epoch | Equal epoch =>
        cases outgoing <;> cases incoming <;>
          by_cases he : epoch.val = t <;> by_cases ho : epoch.val = t-1 <;>
          simp [etna_consensus_core.transition.transition_committee, rust_switch_refines, hs, hold,
            Etna.Committee.plan, modelRelation, planResult, encodePlan, planError, wo,
            UScalar.eq_equiv, wt, ov', he, ho, different, Ne.symm different, Bind.bind, Except.bind, Pure.pure, Except.pure] <;> simp_all [word_roundtrip]
end Etna.Refinement.Rust.Committee
