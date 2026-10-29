import EtnaWitnesses.NonVacuity.Premises

/-! Scope counterexample (an open design issue): blanking a forced-inclusion entry in
governance recovery does not remove the content; anyone can enqueue the same transaction again
right after.

§1 "Censorship resistance" (spec L15): "the only exception is that governance recovery (section 8)
can explicitly blank specified entries"; 8 step 3 (spec L491): blanking "is for handling
unprovable content only"; 7.1 (spec L415): `saveForcedInclusion(bytes tx)` admits any transaction
of at most 8,192 bytes for the fee. Nothing remembers a blanked transaction, so recovery alone
does not handle a poison input: the stall it caused can recur in the new generation. H3 is not
violated: it allows exactly the blanking, and the new entry is an ordinary one.

A poison entry is modelled as one whose singleton build never completes (`Forced.step`'s
`.unavailable` execution): once due, the cursor waits on it, so no block can pass it. The run,
from the non-vacuity deployment:
1. L1 block 15: the poison transaction (hash 666, 100 bytes) is enqueued as entry 0.
2. L1 block 16: governance recovery blanks entry 0 (`fiToClear = [0]`), starting generation 1.
3. L1 block 17: the same transaction is enqueued again, as entry 1, for the same fee.
Entry 1 is pending, and once due it stalls the cursor exactly as entry 0 did. A spec fix would
remember blanked transaction hashes (refusing them in `saveForcedInclusion`, or letting the
guest skip them) or narrow the §1 and §8 wording. A hash blocklist stops only a verbatim
resubmission: the same poison with any byte changed (another nonce, another signature) has a new
hash; a guest-side rule that skips unprovable content does not depend on the bytes. -/
namespace Etna.Design.ForcedPoisonResubmit
open Etna.Statements NonVacuity

/-- The poison transaction's entry as first enqueued (hash 666, L1 block and timestamp 15). -/
def poison : Forced.Entry := ⟨666,15,15⟩
def again : Forced.Entry := ⟨666,17,17⟩

/-- L1 block 15: entry 0. -/
def inboxP : State := (Forced.enqueue world0.inbox 100 1000000000 true).getD world0.inbox
def worldP : ProtocolState.World := ProtocolState.enqueued world0 inboxP 666 15 15

/-- L1 block 16: recovery at checkpoint 0 blanking entry 0. -/
def request : Recovery.Request := ⟨0,0,[],[0],0,limit256-1⟩
def origin : Origin := ⟨0,16,16⟩
def worldR : ProtocolState.World :=
  ProtocolState.recovered worldP request origin
    (Recovery.applyRecovery (ProtocolState.recoveryView worldP) request SecondBatch.recoveryConfig origin)

/-- L1 block 17: the same transaction again, entry 1. -/
def inboxAgain : State := (Forced.enqueue worldR.inbox 100 1000000000 true).getD worldR.inbox
def worldAgain : ProtocolState.World := ProtocolState.enqueued worldR inboxAgain 666 17 17

/-- A witness for the poison at index `i`: authenticated, canonical, not block transaction 0. -/
def stalled (i : Nat) (e : Forced.Entry) : Forced.Witness := ⟨i,e,true,666,100,true,none,false,0⟩

/-- A blanked poison entry comes back. Along a protocol trace from the deployment, a recovery
blanks entry 0 (the one exception H3 allows), and the same transaction is enqueued again as
entry 1, pending at the new generation's head range. Once due under the 60-second delay, a block
whose singleton build of it cannot complete leaves the cursor waiting, for the original entry
before the recovery and for the copy after it alike. -/
theorem cleared_poison_resubmitted :
    ProtocolState.Trace world0 worldAgain ∧ Blanks worldP worldR 0 poison ∧ (0,poison) ∉ worldR.queue ∧
    worldR.inbox.generation = 1 ∧ (1,again) ∈ worldAgain.queue ∧ again.txHash = poison.txHash ∧
    worldAgain.inbox.head ≤ 1 ∧ 1 < worldAgain.inbox.tail ∧
    Forced.step 0 1 75 60 (some (stalled 0 poison)) .unavailable = .waiting ∧
    Forced.step 1 2 77 60 (some (stalled 1 again)) .unavailable = .waiting := by
  have recovered : Recovery.recover (ProtocolState.recoveryView worldP) request worldP.adapters.recovery origin true true =
      some (Recovery.applyRecovery (ProtocolState.recoveryView worldP) request SecondBatch.recoveryConfig origin) := by
    decide +kernel
  have trace : ProtocolState.Trace world0 worldAgain :=
    .step (.step (.step (.refl _)
      (.enqueue (raw := 100) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) (by rfl)))
      (.recovery (by decide) recovered))
      (.enqueue (raw := 100) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) (by rfl))
  exact ⟨trace,⟨request,origin,true,true,_,recovered,rfl,by decide,by decide +kernel⟩,by decide +kernel,
    by decide +kernel,by decide +kernel,rfl,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel⟩

end Etna.Design.ForcedPoisonResubmit
