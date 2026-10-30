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

def Bond.exitSet (b : Bond) : Bool := b.exitAt != noExit

/-- The election's view of a slot (three registry words). -/
def toEntry (b : Bond) : Committee.Entry := ⟨b.key,b.stake,b.activeFrom,b.exitAt⟩

/-- register into a released or never-used slot: a fresh occupant with no exit and no
confirmation; activation after `activationDelay` blocks. -/
def register (slot : Bond) (key owner stake now activationDelay : Nat) : Option Bond :=
  if slot.released = true ∧ 0 < activationDelay then
    some ⟨key,owner,stake,now+activationDelay,noExit,false,none,0,0⟩
  else none

/-- requestExit: owner only, only while no exit is set; effective at
max(now + exitDelay, activeFromL1 + exitDelay), which must fit below the sentinel. -/
def requestExit (b : Bond) (caller now exitDelay : Nat) : Option Bond :=
  if caller = b.owner ∧ b.released = false ∧ b.exitAt = noExit ∧
     max (now+exitDelay) (b.activeFrom+exitDelay) < noExit then
    some { b with exitAt := max (now+exitDelay) (b.activeFrom+exitDelay) }
  else none

/-- The registry reads the Inbox's own initialization state; no caller supplies it.
Initialization writes generation 0's slot-290 origin record (8.4), which is never
overwritten or deleted, so its presence is that state here (slot 258 is not modeled). -/
def inboxInitialized (s : State) : Bool := s.origins.any (fun pair => pair.1 == 0)

/-- Owner deposits into an active, unexited entry. Pending principal is not effective
stake; both the eventual balance and uint48 ready block must fit their storage widths.
Inbox initialization is deliberately not required. -/
def topUp (s : State) (b : Bond) (caller amount now activationDelay : Nat) : Option Bond :=
  if s.entered = false ∧ caller = b.owner ∧ b.released = false ∧ b.activeFrom ≤ now ∧
      0 < b.stake ∧ b.exitAt = noExit ∧ b.pendingTopUp = 0 ∧ 0 < amount ∧
      b.balance+amount < limit256 ∧ 0 < activationDelay ∧ now+activationDelay < limit48 then
    some { b with pendingTopUp := amount,topUpReadyAtL1 := now+activationDelay }
  else none

/-- Anyone may explicitly activate a mature pending deposit before exit is set.
The normal registry checkpoint is written only when effective stake changes. -/
def activateTopUp (s : State) (b : Bond) (now : Nat) : Option Bond :=
  if s.entered = false ∧ b.released = false ∧ 0 < b.pendingTopUp ∧
      b.exitAt = noExit ∧ b.topUpReadyAtL1 ≤ now ∧ b.balance < limit256 then
    some { b with stake := b.balance,pendingTopUp := 0,topUpReadyAtL1 := 0 }
  else none

/-- confirmExit: the Inbox is initialized, no reentrant call is running, the slot is not
released, an exit is set and the Inbox's landed `activeCommitteeSnapshot` already covers it. -/
def Confirmable (s : State) (b : Bond) : Prop :=
  inboxInitialized s = true ∧ s.entered = false ∧ b.released = false ∧ b.exitAt ≠ noExit ∧ b.exitAt ≤ s.snapshot

instance (s : State) (b : Bond) : Decidable (Confirmable s b) :=
  inferInstanceAs (Decidable (_ ∧ _))

/-- The first success records the current L1 block; later calls change nothing. -/
def confirmExit (s : State) (b : Bond) (now : Nat) : Option Bond :=
  if Confirmable s b then
    match b.confirmedAt with
    | some _ => some b
    | none => some { b with confirmedAt := some now }
  else none

/-- withdraw: only a recorded confirmation and the full delay since it. -/
def Withdrawable (s : State) (b : Bond) (atL1 caller now delay : Nat) : Prop :=
  s.entered = false ∧ b.released = false ∧ atL1+delay ≤ now ∧ atL1+delay < limit256 ∧
  (b.balance = 0 ∨ caller = b.owner)

instance (s : State) (b : Bond) (atL1 caller now delay : Nat) :
    Decidable (Withdrawable s b atL1 caller now delay) := inferInstanceAs (Decidable (_ ∧ _))

/-- Zero the entry, release the slot and clear its confirmation; pay the principal. -/
def withdraw (s : State) (b : Bond) (caller now delay : Nat) : Option (Bond × Nat) :=
  match b.confirmedAt with
  | none => none
  | some atL1 => if Withdrawable s b atL1 caller now delay then
      some (⟨0,0,0,0,0,true,none,0,0⟩,b.balance)
    else none

/-- Recovery step 2: an exclusion is a forced exit only. exitEffectiveL1 moves to
min(old, R) and the principal is untouched. -/
def exclude (b : Bond) (r : Nat) : Bond := { b with exitAt := min b.exitAt r }

/-- Double-sign bounty share of the remaining principal. -/
def fraction (remaining bps : Nat) : Nat := remaining*bps/10000

/-- slashDoubleSign success: before Inbox initialization (read from the Inbox state) it
fails; otherwise the entire remaining balance is slashed, exitEffectiveL1 becomes min(old, now),
the fixed registry `bountyBps` goes to the caller and the rest to slashSink. -/
def slashDouble (inbox : State) (b : Bond) (now bountyBps : Nat) : Option (Bond × Nat × Nat) :=
  if inboxInitialized inbox = true ∧ b.released = false ∧ 0 < b.balance ∧ bountyBps ≤ 10000 then
    some ({ b with stake := 0,pendingTopUp := 0,topUpReadyAtL1 := 0,exitAt := min b.exitAt now },
      fraction b.balance bountyBps,b.balance-fraction b.balance bountyBps)
  else none

/-- Fixed-rate DAO penalty rounds upwards, including for balances below 10000 units. -/
def forfeitPenalty (balance bps : Nat) : Nat := (balance*bps+9999)/10000

/-- Decoded owner authorization and external transfer success are authenticated adapter
boundaries. `unused` is read from the registry's lifetime entry-key flag. Failure returns
no replacement bond or payout, so the registry can atomically retain all prior state.
The incident identifier is attribution metadata, not a global deduplication key. -/
def forfeit (s : State) (b : Bond) (entryKey now timestamp validUntil bps : Nat)
    (owner unused externalOK : Bool) : Option (Bond × Nat) :=
  if inboxInitialized s = true ∧ s.entered = false ∧ owner = true ∧
      b.released = false ∧ b.key = entryKey ∧ unused = true ∧ 0 < b.balance ∧
      timestamp ≤ validUntil ∧ 0 < bps ∧ bps ≤ 10000 ∧ externalOK = true then
    let penalty := forfeitPenalty b.balance bps
    let pending := b.pendingTopUp-(penalty-b.stake)
    some ({ b with stake := b.stake-penalty,pendingTopUp := pending,topUpReadyAtL1 := (if pending = 0 then 0 else b.topUpReadyAtL1),exitAt := min b.exitAt now },penalty)
  else none

/-- Rejected block-number rule (shown for contrast): clear confirmations recorded later
than the L1 block of the last trusted landing. -/
def rollbackAfter (lastTrustedBlock : Nat) (b : Bond) : Bond :=
  match b.confirmedAt with
  | some atL1 => if lastTrustedBlock < atL1 then { b with confirmedAt := none } else b
  | none => b

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
