import EtnaProofs.Headline.AnchoredQueue
import EtnaWitnesses.Counterexamples.AnchorTail

/-! `honest_anchor_queue_service`'s hypotheses are satisfiable and exclude the `AnchorTail`
counterexample. In the non-vacuity deployment, with L1 block n at time n, every World the
environment lands on has queue entries that record their enqueue block's time, and every anchor
the environment accepts reports its block's time and an honest tail; the premises hold too.
`AnchorTail`'s understated anchor violates the tail half for every clock, and so does the
non-vacuity L1 anchor of block 15 with its tail lowered to 0. -/
namespace Etna.Design.AnchorHonestyRegression
open Etna.Statements NonVacuity AnchorHonesty

/-- An anchor the environment accepts is the L1 history's anchor of its block, which reports
time n and, from block 15 on, tail 1. -/
private theorem accepted_reports {A : BlockValidity.Anchor} (accepted : A = l1Anchor A.number) :
    A.timestamp = A.number ∧ (15 ≤ A.number → 0 < A.tail) := by
  generalize number : A.number = n at accepted
  subst accepted
  refine ⟨?_,fun late => ?_⟩
  · unfold l1Anchor
    repeat' split
    all_goals rfl
  · unfold l1Anchor
    repeat' split
    all_goals first | exact absurd late (by omega) | exact Nat.zero_lt_one

/-- The Worlds the environment lands on hold the one entry 0, enqueued in L1 block 15 at time 15. -/
private theorem landed_queues :
    worldQ.queue = l1Queue ∧ world1.queue = l1Queue ∧ world3.queue = l1Queue := by
  decide +kernel

/-- The hypotheses of `honest_anchor_queue_service` hold for every landing the non-vacuity
environment submits, under the L1 clock `id`, together with the premises; the understated
anchors are excluded. -/
theorem honest_anchor_hypotheses_hold :
    Premises world0 env ∧ ClockMonotone id ∧
    (∀ w i leaves e s, env.submits w i leaves e → Etna.Design.land w.inbox i leaves e = some s →
      QueueTimed id w ∧ ∀ A, env.anchorAuthenticated A = true → AnchorCovers id w A) ∧
    env.anchorAuthenticated (l1Anchor 15) = true ∧ AnchorCovers id worldQ (l1Anchor 15) ∧
    ¬ AnchorCovers id worldQ { l1Anchor 15 with tail := 0 } ∧
    ∀ time, ¬ AnchorCovers time worldQ AnchorTail.understated := by
  have queued : (0,entry0) ∈ worldQ.queue := by decide +kernel
  refine ⟨premises,fun _ _ order => order,?_,by decide +kernel,⟨rfl,?_⟩,?_,?_⟩
  · intro w _ _ _ _ submitted _
    have queue : w.queue = l1Queue := by
      rcases submitted.1 with rfl | rfl | rfl
      · exact landed_queues.1
      · exact landed_queues.2.1
      · exact landed_queues.2.2
    refine ⟨fun j entry mem => ?_,fun A shown => ?_⟩
    · rw [queue] at mem
      simp only [l1Queue,List.mem_singleton,Prod.mk.injEq] at mem
      rw [mem.2]
      rfl
    · have reports := accepted_reports (of_decide_eq_true shown)
      refine ⟨reports.1,fun j entry mem enqueued => ?_⟩
      rw [queue] at mem
      simp only [l1Queue,List.mem_singleton,Prod.mk.injEq] at mem
      rw [mem.1]
      rw [mem.2] at enqueued
      exact reports.2 enqueued
  · intro j entry mem _
    have stored : (j,entry) = (0,entry0) := by
      rw [landed_queues.1] at mem
      simpa only [l1Queue,List.mem_singleton] using mem
    rw [(Prod.mk.injEq _ _ _ _).mp stored |>.1]
    decide
  · intro covers
    exact absurd (covers.2 0 entry0 queued (by decide)) (by decide)
  · intro time covers
    exact absurd (covers.2 0 entry0 queued (by decide)) (by decide)

end Etna.Design.AnchorHonestyRegression
