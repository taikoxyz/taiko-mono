module
public import Mathlib.Tactic
@[expose] public section
namespace Etna.Committee

def max64 : Nat := 2^64-1
def max48 : Nat := 2^48-1
def maxCommitteeSize : Nat := 4096
/-- Only the upper bound: production rejects zero independently, before this guard. -/
def committeeSizeBounded (n : Nat) : Bool := decide (n ≤ maxCommitteeSize)
/-- Strict configuration guard; the saturated subtraction itself still admits zero. -/
def positiveCap (depth margin : Nat) : Bool := decide (margin < depth)
def checked (n : Nat) : Option Nat := if n ≤ max64 then some n else none
def add (a b : Nat) := checked (a+b)
def mul (a b : Nat) := checked (a*b)
def sub (a b : Nat) : Option Nat := if b ≤ a then some (a-b) else none
def div (a b : Nat) : Option Nat := if b = 0 then none else some (a/b)
structure Schedule where
  l1₀ : Nat
  length : Nat
  l1Length : Nat
  genesisCutoff : Nat
  deriving DecidableEq, Repr
inductive ScheduleError | tooShort | shorterThanCap | zeroL1 | firstHeight | firstAnchor deriving DecidableEq, Repr

def epochOf (s : Schedule) (h : Nat) := div (h-1) s.length
def first (s : Schedule) (t : Nat) := (mul t s.length).bind (add · 1)
/-- Preserve both intermediate checks, even if the mathematical last height fits. -/
def last (s : Schedule) (t : Nat) := (add t 1).bind fun n => (first s n).bind (sub · 1)
def l1First (s : Schedule) (t : Nat) := (mul t s.l1Length).bind (add · s.l1₀)
/-- Checked configuration validation in consensus-visible source priority. -/
def validate (s : Schedule) (cap : Nat) : Except ScheduleError Unit :=
  if s.length < 3 then .error .tooShort else
  match add cap 3 with
  | none => .error .shorterThanCap
  | some minimum => if s.length < minimum then .error .shorterThanCap
    else if s.l1Length = 0 then .error .zeroL1 else
      match first s 1 with
      | none => .error .firstHeight
      | some height => if height ≤ max48 then
        match l1First s 1 with
        | none => .error .firstAnchor
        | some anchor => if anchor ≤ max48 then .ok () else .error .firstAnchor
        else .error .firstHeight

inductive AnchorError
  | regressed | beforeActivation | invalidSchedule | epochNotOpen (epoch minimum : Nat)
  deriving DecidableEq, Repr
/-- MAX is only an overflow diagnostic; it cannot turn overflow into acceptance. -/
def anchorProgress (s : Schedule) (parent anchor height : Nat) : Except AnchorError Unit :=
  if anchor < parent then .error .regressed else
  if anchor < s.l1₀ then .error .beforeActivation else
  match epochOf s height with
  | none => .error .invalidSchedule
  | some epoch => match l1First s epoch with
    | none => .error (.epochNotOpen epoch max64)
    | some minimum => if minimum ≤ anchor then .ok () else .error (.epochNotOpen epoch minimum)

def parentHeight (s : Schedule) (t : Nat) :=
  if t = 0 then none else (first s t).bind (sub · 3)
def startingAt (s : Schedule) (h : Nat) : Option Nat :=
  if s.length = 0 then none else (sub h 1).bind fun n =>
    if n % s.length = 0 then some (n / s.length) else none
def switchTarget (s : Schedule) (h : Nat) : Option Nat :=
  (add h 2).bind fun h' => (startingAt s h').bind fun t => if t = 0 then none else some t
def nextSwitch (s : Schedule) (h : Nat) :=
  (add h 1).bind fun h' => (epochOf s h').bind (add · 1)
/-- A publish hint only, independent of committee activation authority. -/
def forceEpoch (s : Schedule) (tip checkpoint : Nat) : Option Bool := do
  let epoch ← epochOf s tip
  if (switchTarget s tip).isSome then return true
  let next := match add epoch 1 with
    | none => false
    | some nextEpoch => match first s nextEpoch with
      | none => false
      | some height => decide (height-2 ≤ tip ∧ checkpoint < height-2)
  let current := if 0 < epoch then match first s epoch with
    | none => false
    | some height => decide (checkpoint < height-2)
    else false
  return next || current

theorem checked_some {n v : Nat} : checked n = some v ↔ n ≤ max64 ∧ v = n := by
  by_cases h : n ≤ max64 <;> simp [checked, h, eq_comm]

/-- Successful validation establishes representable first transition bounds. -/
theorem validate_first_ranges (s : Schedule) (cap : Nat) (accepted : validate s cap = .ok ()) :
    (∃ height, first s 1 = some height ∧ height ≤ max48) ∧
    (∃ anchor, l1First s 1 = some anchor ∧ anchor ≤ max48) := by
  unfold validate at accepted
  split at accepted <;> try contradiction
  cases hc : add cap 3 with
  | none => simp [hc] at accepted
  | some minimum =>
    simp only [hc] at accepted
    split at accepted <;> try contradiction
    split at accepted <;> try contradiction
    cases hf : first s 1 with
    | none => simp [hf] at accepted
    | some height =>
      simp only [hf] at accepted
      split at accepted <;> try contradiction
      rename_i heightBound
      cases ha : l1First s 1 with
      | none => simp [ha] at accepted
      | some anchor =>
        simp only [ha] at accepted
        split at accepted <;> try contradiction
        exact ⟨⟨height, rfl, heightBound⟩, ⟨anchor, rfl, by assumption⟩⟩

/-- The new range guards preserve all existing length/cap validation requirements. -/
theorem validate_lengths (s : Schedule) (cap : Nat) (accepted : validate s cap = .ok ()) :
    3 ≤ s.length ∧ cap+3 ≤ max64 ∧ cap+3 ≤ s.length ∧ 0 < s.l1Length := by
  unfold validate at accepted
  split at accepted <;> try contradiction
  rename_i lengthBound
  cases hc : add cap 3 with
  | none => simp [hc] at accepted
  | some minimum =>
    have value := checked_some.mp hc
    simp only [hc] at accepted
    split at accepted <;> try contradiction
    rename_i capBound
    split at accepted <;> try contradiction
    omega

theorem committee_size_bounded_iff (n : Nat) : committeeSizeBounded n = true ↔ n ≤ 4096 := by
  by_cases h : n ≤ 4096 <;> simp [committeeSizeBounded, maxCommitteeSize, h]

theorem anchor_progress_success (s : Schedule) (parent anchor height : Nat)
    (accepted : anchorProgress s parent anchor height = .ok ()) :
    parent ≤ anchor ∧ s.l1₀ ≤ anchor ∧
      ∃ epoch minimum, epochOf s height = some epoch ∧ l1First s epoch = some minimum ∧ minimum ≤ anchor := by
  unfold anchorProgress at accepted
  split at accepted <;> try contradiction
  rename_i parentBound
  split at accepted <;> try contradiction
  rename_i activationBound
  cases he : epochOf s height with
  | none => simp [he] at accepted
  | some epoch =>
    simp only [he] at accepted
    cases hm : l1First s epoch with
    | none => simp [hm] at accepted
    | some minimum =>
      simp only [hm] at accepted
      split at accepted <;> try contradiction
      exact ⟨by omega, by omega, epoch, minimum, rfl, hm, by assumption⟩

theorem positive_cap_iff (depth margin : Nat) : positiveCap depth margin = true ↔ margin < depth := by
  simp [positiveCap]
theorem positive_cap_difference (depth margin : Nat) (accepted : positiveCap depth margin = true) :
    0 < depth-margin := by have := (positive_cap_iff depth margin).mp accepted; omega

def H (s : Schedule) (t : Nat) := 1+t*s.length
def D (s : Schedule) (t : Nat) := H s t-3
def S (s : Schedule) (t : Nat) := H s t-2

theorem switch_positive {s : Schedule} {h t : Nat} (hs : switchTarget s h = some t) : 0 < t := by
  unfold switchTarget at hs
  cases hh : add h 2 with
  | none => simp [hh] at hs
  | some h' =>
    simp only [hh, Option.bind_some] at hs
    cases ht : startingAt s h' with
    | none => simp [ht] at hs
    | some t' =>
      simp only [ht, Option.bind_some] at hs
      split_ifs at hs; simp_all; omega
end Etna.Committee
