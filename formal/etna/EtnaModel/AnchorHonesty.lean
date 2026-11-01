import EtnaModel.ProtocolState

/-! Anchor honesty, the hypothesis H3 leaves open (`AnchorTail`). 3.3 (spec L90): a block's
anchor is an L1 block whose state it reads, and its witness "proves ... the forced inclusion
queue's head and tail"; 3.2 (spec L77) and 3.4 rule 7 (spec L110) read the anchor's timestamp.
These predicates state what an honest anchor reports about the Inbox's queue, against an L1
clock `time` (L1 block n has timestamp `time n`). They are explicit hypotheses of their own
theorems, not premises: no field of `Etna.Statements.Premises` mentions them. -/
namespace Etna.Design.AnchorHonesty

/-- An L1 clock: block numbers never run backwards in time. Real L1 timestamps strictly
increase; never decreasing is all the theorems use. -/
def ClockMonotone (time : Nat → Nat) : Prop := ∀ m n, m ≤ n → time m ≤ time n

/-- Every queue entry of World `w` records its enqueue block's L1 timestamp (7.1: the entry
keeps `block.timestamp` and the enqueue block; recovery blanking keeps both, spec L491). -/
def QueueTimed (time : Nat → Nat) (w : ProtocolState.World) : Prop :=
  ∀ j entry, (j,entry) ∈ w.queue → entry.timestamp = time entry.l1Block

/-- Anchor `A` reports its own L1 block honestly to World `w`: its timestamp is that block's,
and its tail counts every entry of `w`'s queue enqueued at or before that block. An anchor
that shows the Inbox's actual tail after its block satisfies this for every later World, since
entries are only appended with their enqueue block and never removed. -/
def AnchorCovers (time : Nat → Nat) (w : ProtocolState.World) (A : BlockValidity.Anchor) : Prop :=
  A.timestamp = time A.number ∧ ∀ j entry, (j,entry) ∈ w.queue → entry.l1Block ≤ A.number → j < A.tail

end Etna.Design.AnchorHonesty
