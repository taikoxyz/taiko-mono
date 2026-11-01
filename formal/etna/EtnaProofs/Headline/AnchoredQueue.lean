import EtnaModel.AnchorHonesty
import EtnaProofs.Headline.ForcedInclusion

/-! H3 against the Inbox's actual queue, under honest anchors. H3's third part judges a due
queue-head entry against each block anchor's own tail and timestamp, and no premise makes an
accepted anchor report the Inbox's actual ones (`AnchorTail`). This adds that as explicit
hypotheses of two theorems, without changing `Premises` or H3: an L1 clock that never runs
backwards (`AnchorHonesty.ClockMonotone`), queue entries that record their enqueue block's
timestamp (`AnchorHonesty.QueueTimed`), and accepted anchors that report their own block's
timestamp and count every entry enqueued at or before it (`AnchorHonesty.AnchorCovers`). Then:
- 7.3's bound (spec L465, `honest_anchor_chain_sees_due`): in every block of a valid chain with
  `block.timestamp ≥ entry.timestamp + forcedInclusionDelay + maxAnchorAge`, the anchor shows the
  entry at the parent's cursor pending and due, because 3.4 rule 7 (spec L110) bounds the
  anchor's age by maxAnchorAge and §10 (spec L563) makes forcedInclusionDelay positive;
- every landed block consumes the queue-head entry of the Inbox's actual queue once the entry is
  due by the anchor's time, and so once that bound holds (`honest_anchor_queue_service`; 7.3,
  spec L465: "A due queue-head entry must be included or legally skipped").
Nat arithmetic does not overflow, matching the spec's overflow-safe arithmetic. The chain theorem
covers any valid chain; `honest_anchor_queue_service`, like H3, covers blocks in landed segments
only. Neither gives a wall-clock deadline (§12 item 1). -/
namespace Etna.Proofs
open Etna.Design Etna.Statements

/-- Every (parent header, block) pair of a valid chain is a valid block on its parent. -/
private theorem anchored_pairs_valid {r : BlockValidity.Rules} :
    ∀ {q : BlockValidity.Header} {bs : List BlockValidity.Block}, BlockValidity.Chain r q bs →
      ∀ x ∈ pairs q bs, BlockValidity.Valid r x.1 x.2 := by
  intro q bs
  induction bs generalizing q with
  | nil => exact fun _ x mem => absurd mem List.not_mem_nil
  | cons b rest ih =>
    intro ok x mem
    change x ∈ (q,b) :: pairs b.header rest at mem
    rcases List.mem_cons.mp mem with rfl | later
    · exact ok.1
    · exact ih ok.2 x later

/-- An honest anchor shows an entry pending once the entry is due by the anchor's time: a
positive delay and a clock that never runs backwards place the entry's enqueue block before the
anchor's. -/
private theorem honest_pending {w : ProtocolState.World} {time : Nat → Nat} {A : BlockValidity.Anchor}
    {delay j : Nat} {entry : Forced.Entry} (clock : AnchorHonesty.ClockMonotone time)
    (timed : AnchorHonesty.QueueTimed time w) (covers : AnchorHonesty.AnchorCovers time w A) (positive : 0 < delay)
    (queued : (j,entry) ∈ w.queue) (due : entry.timestamp+delay ≤ A.timestamp) : j < A.tail := by
  rcases Nat.lt_or_ge A.number entry.l1Block with after | enqueued
  · have order := clock _ _ (Nat.le_of_lt after)
    rw [← covers.1,← timed _ _ queued] at order
    omega
  · exact covers.2 _ _ queued enqueued

/-- 7.3 (spec L465): "For the current queue-head entry, any valid block with block.timestamp ≥
entry.timestamp + forcedInclusionDelay + maxAnchorAge necessarily sees it as due". Every block of
a valid chain, under rules with a positive FI delay whose accepted anchors are honest to World
`w`, sees the entry of `w`'s queue at its parent's cursor as due by then: its anchor shows the
entry pending (index below the anchor's tail) and the entry's delay elapsed by the anchor's time.
3.4 rule 7 (spec L110) bounds the anchor's age by maxAnchorAge. -/
theorem honest_anchor_chain_sees_due {r : BlockValidity.Rules} {q : BlockValidity.Header}
    {bs : List BlockValidity.Block} {w : ProtocolState.World} {time : Nat → Nat}
    (chain : BlockValidity.Chain r q bs) (positive : 0 < r.forcedDelay) (clock : AnchorHonesty.ClockMonotone time)
    (timed : AnchorHonesty.QueueTimed time w)
    (honest : ∀ A, r.anchorAuthenticated A = true → AnchorHonesty.AnchorCovers time w A) :
    ∀ x ∈ pairs q bs, ∀ entry, (x.1.cursor,entry) ∈ w.queue →
      entry.timestamp+r.forcedDelay+r.maxAnchorAge ≤ x.2.header.timestamp →
      x.1.cursor < x.2.header.anchor.tail ∧ entry.timestamp+r.forcedDelay ≤ x.2.header.anchor.timestamp := by
  intro x mem entry queued late
  obtain ⟨_,_,_,_,_,before,age,_,_,_,_,_,authenticated⟩ := (anchored_pairs_valid chain x mem).2.2.2.1
  have due : entry.timestamp+r.forcedDelay ≤ x.2.header.anchor.timestamp := by omega
  exact ⟨honest_pending clock timed (honest _ authenticated) positive queued due,due⟩

/-- Under honest anchors, a submitted landing that the Inbox accepts settles blocks that serve
the Inbox's actual queue. With `landing_consumes_queue`'s conclusions, every landed block on
parent header `x.1`:
- consumes the queue entry at the parent's cursor once the entry is due by the anchor's time
  (entry.timestamp + forcedInclusionDelay ≤ anchor timestamp), whatever tail the anchor
  reports;
- consumes it whenever block.timestamp ≥ entry.timestamp + forcedInclusionDelay + maxAnchorAge
  (7.3, spec L465; `honest_anchor_chain_sees_due`).
The hypotheses are about the landing's World `w` only: its queue entries carry their enqueue
block's time, and every anchor the environment accepts reports its block's time and an
honest-or-larger tail. -/
theorem honest_anchor_queue_service {env : Environment} {w0 w : ProtocolState.World} {s : State}
    {i : LandInput} {leaves : List Leaf} {e : LandingEnv} {time : Nat → Nat}
    (premises : Premises w0 env) (clock : AnchorHonesty.ClockMonotone time) (run : Run env w0 w)
    (submitted : env.submits w i leaves e) (ok : Etna.Design.land w.inbox i leaves e = some s)
    (timed : AnchorHonesty.QueueTimed time w)
    (honest : ∀ A, env.anchorAuthenticated A = true → AnchorHonesty.AnchorCovers time w A) :
    ∃ r q bs, Built env w r ∧ Links r w.inbox.checkpoint s.checkpoint i.lastStateRoot q bs ∧
      q.cursor = w.inbox.head ∧
      (∀ j, w.inbox.head ≤ j → j < s.head → ∃ x ∈ pairs q bs, x.1.cursor = j ∧ x.2.header.cursor = j+1) ∧
      ∀ x ∈ pairs q bs, ServesQueue w r x.1 x.2 ∧
        (∀ entry, (x.1.cursor,entry) ∈ w.queue →
          entry.timestamp+r.forcedDelay ≤ x.2.header.anchor.timestamp → x.2.header.cursor = x.1.cursor+1) ∧
        (∀ entry, (x.1.cursor,entry) ∈ w.queue →
          entry.timestamp+r.forcedDelay+r.maxAnchorAge ≤ x.2.header.timestamp →
          x.2.header.cursor = x.1.cursor+1) := by
  obtain ⟨r,q,bs,built,links,start,walk,serves⟩ := landing_consumes_queue premises run submitted ok
  -- The built rules use the environment's anchor authentication and a positive FI delay (§10).
  have rules : r.anchorAuthenticated = env.anchorAuthenticated ∧ 0 < r.forcedDelay := by
    obtain ⟨_,_,_,construction⟩ := built
    obtain ⟨constraints,_,_,_,_,_,_,_,_,rfl⟩ := Deployment.build_success construction
    exact ⟨rfl,constraints.2.1⟩
  have accepted : ∀ A, r.anchorAuthenticated A = true → AnchorHonesty.AnchorCovers time w A := by
    rw [rules.1]
    exact honest
  refine ⟨r,q,bs,built,links,start,walk,fun x mem => ⟨serves x mem,fun entry queued due => ?_,
    fun entry queued late => ?_⟩⟩
  · obtain ⟨_,_,_,_,_,_,_,_,_,_,_,_,authenticated⟩ := (anchored_pairs_valid links.1 x mem).2.2.2.1
    exact (serves x mem).2 entry queued
      (honest_pending clock timed (accepted _ authenticated) rules.2 queued due) due
  · obtain ⟨pending,due⟩ := honest_anchor_chain_sees_due links.1 rules.2 clock timed accepted x mem entry queued late
    exact (serves x mem).2 entry queued pending due

end Etna.Proofs
