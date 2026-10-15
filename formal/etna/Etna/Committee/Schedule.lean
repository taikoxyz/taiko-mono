module
public import Mathlib.Tactic
@[expose] public section
namespace Etna.Committee

def max64 : Nat := 2^64-1
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
inductive ScheduleError | tooShort | shorterThanCap | zeroL1 deriving DecidableEq, Repr

def validate (s : Schedule) (cap : Nat) : Except ScheduleError Unit :=
  if s.length < 3 then .error .tooShort else
  match add cap 3 with
  | none => .error .shorterThanCap
  | some minimum => if s.length < minimum then .error .shorterThanCap
    else if s.l1Length = 0 then .error .zeroL1 else .ok ()
def epochOf (s : Schedule) (h : Nat) := div (h-1) s.length
def first (s : Schedule) (t : Nat) := (mul t s.length).bind (add · 1)
/-- Preserve both intermediate checks, even if the mathematical last height fits. -/
def last (s : Schedule) (t : Nat) := (add t 1).bind fun n => (first s n).bind (sub · 1)
def l1First (s : Schedule) (t : Nat) := (mul t s.l1Length).bind (add · s.l1₀)
def parentHeight (s : Schedule) (t : Nat) :=
  if t = 0 then none else (first s t).bind (sub · 3)
def startingAt (s : Schedule) (h : Nat) : Option Nat :=
  if s.length = 0 then none else (sub h 1).bind fun n =>
    if n % s.length = 0 then some (n / s.length) else none
def switchTarget (s : Schedule) (h : Nat) : Option Nat :=
  (add h 2).bind fun h' => (startingAt s h').bind fun t => if t = 0 then none else some t
def nextSwitch (s : Schedule) (h : Nat) :=
  (add h 1).bind fun h' => (epochOf s h').bind (add · 1)
def H (s : Schedule) (t : Nat) := 1+t*s.length
def D (s : Schedule) (t : Nat) := H s t-3
def S (s : Schedule) (t : Nat) := H s t-2

theorem checked_some {n v : Nat} : checked n = some v ↔ n ≤ max64 ∧ v = n := by
  by_cases h : n ≤ max64 <;> simp [checked, h, eq_comm]

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
      split_ifs at hs <;> simp_all <;> omega
end Etna.Committee
