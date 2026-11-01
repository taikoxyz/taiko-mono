import EtnaWitnesses.NonVacuity.Premises

/-! Scope counterexample: H3's queue service (`ServesQueue`) judges a due queue-head entry
against the block anchor's own `tail` and `timestamp`. `AnchorValid` checks the anchor's Inbox
fields only through the environment's `anchorAuthenticated`, and, by inspection of `Premises`,
no premise requires an accepted anchor to report the Inbox's actual tail and timestamp: `InputsAuthenticated` uses it only as
an antecedent and binds only FI witnesses whose index is below the anchor's tail. So H3's third
part holds relative to the tail and timestamp an accepted anchor reports. This is a concrete
instance, not a run under the premises.

§1 "Censorship resistance" (spec L15): "a due queue-head entry can only be included or legally
skipped, otherwise the block is invalid"; 3.3 (spec L90): the anchor witness "proves ... the
forced inclusion queue's head and tail"; 7.2 (spec L427): "if `c ≥ tail(A)`, it carries no forced witness", and (spec L451)
"a block at or after due that neither includes nor legally skips the entry is invalid"; 7.3
(spec L465). In the non-vacuity World after L1
block 15, entry 0 (timestamp 15) is the queue head and the Inbox's tail is 1. Two anchors
differ only in the tail they report: `honest` (tail 1) and `understated` (tail 0). Both carry
timestamp 200, chosen so that entry 0 is due under any delay up to 100. A block on block 0 that keeps
the FI cursor at 0 and carries no FI witness:
- passes `Forced.step` under `understated` with no witness, and serves the queue;
- does not serve the queue under `honest`, which requires the due entry to be consumed;
- is outside `InputsAuthenticated` under `understated`: no witness index is below its tail.
The non-vacuity environment's adapter accepts its own L1 anchor of block 15 (tail 1) and rejects
the same anchor with tail 0: there the adapter, not a premise, rules the understated tail out.
Closing the gap needs
a premise, or an implementation obligation, that every accepted anchor shows the Inbox's
actual tail, and its L1 block's timestamp. `AnchorHonesty` states that obligation as explicit
hypotheses of `Etna.Proofs.honest_anchor_queue_service`; `AnchorHonestyRegression` shows this
anchor violates them for every clock. -/
namespace Etna.Design.AnchorTail

/-- An anchor that reports the Inbox's actual tail after L1 block 15, at timestamp 200 so that
entry 0 is due. -/
def honest : BlockValidity.Anchor := ⟨15,200,25,0,NonVacuity.genesisHeader.elHash,0,1⟩
/-- The same anchor reporting tail 0: the queue looks empty. -/
def understated : BlockValidity.Anchor := { honest with tail := 0 }

/-- A block on block 0 under anchor `A` that keeps the FI cursor at 0 and carries no FI
witness. -/
def skipping (A : BlockValidity.Anchor) : BlockValidity.Block :=
  { NonVacuity.block2 with
    header := { NonVacuity.block2.header with height := 1, cursor := 0, anchor := A }, forced := none }

/-- An understated anchor tail lets a block pass a due queue-head entry. Entry 0 is pending
at the head of the Inbox's queue (tail 1). Under `understated`, the block that keeps the
cursor at 0 passes the per-block FI check with no witness and serves the queue for every rule
set; under `honest`, the same block does not serve the queue whenever the delay is at most 100.
No FI witness falls under `InputsAuthenticated` for `understated`. The non-vacuity
environment's adapter accepts its L1 anchor of block 15 and rejects that anchor with tail 0. -/
theorem understated_tail_passes_due_entry :
    (0,NonVacuity.entry0) ∈ NonVacuity.worldQ.queue ∧ NonVacuity.worldQ.inbox.head = 0 ∧
    0 < NonVacuity.worldQ.inbox.tail ∧ understated.tail = 0 ∧ honest.tail = 1 ∧
    (∀ (delay : Nat) (singleton : Forced.Singleton),
      Forced.step NonVacuity.genesisHeader.cursor understated.tail understated.timestamp delay
        (skipping understated).forced singleton = .accepted (skipping understated).header.cursor) ∧
    (∀ r, Statements.ServesQueue NonVacuity.worldQ r NonVacuity.genesisHeader (skipping understated)) ∧
    (∀ r : BlockValidity.Rules, r.forcedDelay ≤ 100 →
      ¬ Statements.ServesQueue NonVacuity.worldQ r NonVacuity.genesisHeader (skipping honest)) ∧
    (∀ wit : Forced.Witness, ¬ wit.index < understated.tail) ∧
    NonVacuity.relations.anchorAuthenticated (NonVacuity.l1Anchor 15) = true ∧
    NonVacuity.relations.anchorAuthenticated { NonVacuity.l1Anchor 15 with tail := 0 } = false := by
  have mem : (NonVacuity.genesisHeader.cursor,NonVacuity.entry0) ∈ NonVacuity.worldQ.queue := by
    decide +kernel
  refine ⟨mem,by decide +kernel,by decide +kernel,rfl,rfl,fun _ _ => rfl,?_,?_,?_,by decide +kernel,
    by decide +kernel⟩
  · intro r
    refine ⟨fun advanced => absurd advanced (by decide +kernel),fun _ _ pending _ => absurd pending (by decide +kernel)⟩
  · intro r delay serves
    have due : NonVacuity.entry0.timestamp+r.forcedDelay ≤ (skipping honest).header.anchor.timestamp := by
      show 15+r.forcedDelay ≤ 200
      omega
    exact absurd (serves.2 NonVacuity.entry0 mem (by decide +kernel) due) (by decide +kernel)
  · intro wit below
    exact Nat.not_lt_zero _ below

end Etna.Design.AnchorTail
