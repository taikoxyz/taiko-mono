import EtnaModel.Committee

namespace Etna.Design.Staking

/-- exitEffectiveL1 while no exit is set: 2^48 − 1 (4.1, appendix B). It compares above
every snapshot, as 4.3 eligibility (snapshot < exitEffectiveL1) needs. -/
def noExit : Nat := limit48-1

/-- One registry slot. `confirmedAt` is `exitConfirmedAtL1` (`none` stands for 0, not
confirmed); it lives in its own namespace and is cleared when the slot is released.
The owner is fixed at registration. There is no exit flag: an exit is set exactly when
exitEffectiveL1 differs from `noExit`. -/
structure Bond where
  key : Hash
  owner : Nat
  stake : Nat
  activeFrom : Nat
  exitAt : Nat
  released : Bool
  confirmedAt : Option Nat
  /-- Principal awaiting explicit delayed activation; excluded from election entries. -/
  pendingTopUp : Nat := 0
  topUpReadyAtL1 : Nat := 0
  deriving DecidableEq, Repr

def Bond.balance (b : Bond) : Nat := b.stake+b.pendingTopUp

/-- The election's view of a slot (three registry words). -/
def toEntry (b : Bond) : Committee.Entry := ⟨b.key,b.stake,b.activeFrom,b.exitAt⟩

/-- requestExit: owner only, only while no exit is set; effective at
max(now + exitDelay, activeFromL1 + exitDelay), which must fit below the sentinel. -/
def requestExit (b : Bond) (caller now exitDelay : Nat) : Option Bond :=
  if caller = b.owner ∧ b.released = false ∧ b.exitAt = noExit ∧
     max (now+exitDelay) (b.activeFrom+exitDelay) < noExit then
    some { b with exitAt := max (now+exitDelay) (b.activeFrom+exitDelay) }
  else none

/-- Recovery step 2: an exclusion is a forced exit only. exitEffectiveL1 moves to
min(old, R) and the principal is untouched. -/
def exclude (b : Bond) (r : Nat) : Bond := { b with exitAt := min b.exitAt r }

/-- Double-sign bounty share of the remaining principal. -/
def fraction (remaining bps : Nat) : Nat := remaining*bps/10000

/-- Fixed-rate DAO penalty rounds upwards, including for balances below 10000 units. -/
def forfeitPenalty (balance bps : Nat) : Nat := (balance*bps+9999)/10000

/-- §8 verifier-failure rollback, registry side: with slot 284 restored to the last trusted
landing's value, keep a confirmation only if that snapshot ≥ the entry's exitEffectiveL1;
clear it otherwise. -/
def rollbackBySnapshot (restored : Nat) (b : Bond) : Bond :=
  match b.confirmedAt with
  | some _ => if restored < b.exitAt then { b with confirmedAt := none } else b
  | none => b

/-- Deployment/generation are fixed by the registry's Inbox, not chosen by the submitter. -/
structure Vote where
  domain : Domain
  generation : Nat
  height : Nat
  round : Nat
  kind : Nat
  blockId : Hash
  deriving DecidableEq, Repr

def doubleSign (deployment : Domain) (currentGeneration : Nat) (a b : Vote) : Bool :=
  decide (a.domain = deployment ∧ b.domain = deployment ∧ a.generation = b.generation ∧
    a.generation ≤ currentGeneration ∧ a.height = b.height ∧ a.round = b.round ∧
    a.kind = b.kind ∧ (a.kind = 1 ∨ a.kind = 2) ∧ a.blockId ≠ b.blockId)

end Etna.Design.Staking
