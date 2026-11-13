import EtnaModel.CurrentQueueIntegrity
import EtnaProofs.CurrentBlocks
import EtnaProofs.CurrentJournal
import EtnaProofs.Current

namespace Etna.Design.Current.QueueIntegrity
open Protocol

/-- Successful admission collects exactly the formula fee and refunds the rest, with
all byte, cursor and arithmetic range checks exposed independently of the queue journal. -/
theorem forced_admission_accounting {before after : Etna.Design.State} {raw paid : Nat} {refund : Bool}
    (ok : Forced.enqueue before raw paid refund = some after) :
    AdmissionAccounting before after raw paid refund := by
  unfold Forced.enqueue at ok
  dsimp only at ok
  split at ok
  next guard =>
    rcases guard with ⟨_,_,bytes,queue,range,payment,balance,refunded⟩
    cases Option.some.inj ok
    exact ⟨bytes,queue,range,payment,refunded,by omega,balance,rfl,rfl,rfl,rfl⟩
  next => simp at ok

/-- Current admission appends exactly one hash/time/block entry and commits its fee
accounting atomically. Hashing is the fixed deployment byte-hash adapter. -/
theorem admission_exact {env : Environment} {w t : World} {raw : Blocks.Bytes} {paid : Nat} {refund : Bool}
    (ok : enqueue env w raw paid refund = some t) :
    AdmissionAccounting w.inbox t.inbox raw.length paid refund ∧
    t.queue = w.queue ++ [(w.inbox.tail,⟨env.txHash raw,env.time w.number,w.number⟩)] ∧
    t.number = w.number ∧ t.history = w.history := by
  unfold enqueue at ok
  split at ok
  next =>
    obtain ⟨inbox,admission,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨forced_admission_accounting admission,rfl,rfl,rfl⟩
  next => simp at ok

/-- Underpayment never creates fee revenue or a queue entry, even if a refund transfer
would succeed. This rejects removing the payment guard from the admission machine. -/
theorem underpayment_rejected {s : Etna.Design.State} {raw paid : Nat} {refund : Bool}
    (under : paid < Forced.admissionFee s.forcedFee s.forcedThreshold (s.tail-s.head)) :
    Forced.enqueue s raw paid refund = none := by
  unfold Forced.enqueue
  dsimp only
  split
  next guard => have := guard.2.2.2.2.2.1; omega
  next => rfl

/-- A failed overpayment refund reverts the entire admission. -/
theorem refund_failure_rejected {s : Etna.Design.State} {raw paid : Nat}
    (over : Forced.admissionFee s.forcedFee s.forcedThreshold (s.tail-s.head) < paid) :
    Forced.enqueue s raw paid false = none := by
  unfold Forced.enqueue
  dsimp only
  split
  next guard =>
    rcases guard.2.2.2.2.2.2.2 with equal | impossible
    · omega
    · contradiction
  next => rfl

/-- All fields, including tokens, queue, history, images and signer state, stutter when
admission reverts; failure cannot charge or admit partially. -/
theorem admission_failure_atomic {env : Environment} {w : World} {raw : Blocks.Bytes}
    {paid : Nat} {refund : Bool} (failed : enqueue env w raw paid refund = none) :
    Protocol.transact env w (.enqueue raw paid refund) = w := by
  simp [Protocol.transact,Protocol.execute,failed]

/-- Every reached current world has ordered FIFO cursors, including rollback rewinds. -/
theorem trace_head_bounds {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w) : w.inbox.head ≤ w.inbox.tail :=
  (Journal.trace_record_shape trace).bounded

/-- Recovery's exact list is strictly increasing and every cleared index is pending at
execution; no already-consumed or unadmitted index can be targeted. -/
theorem recovery_pending_guards {env : Environment} {w t : World} {request : RecoveryRequest}
    (ok : recover env w request = some t) :
    request.clear.Pairwise (· < ·) ∧ ∀ i ∈ request.clear, w.inbox.head ≤ i ∧ i < w.inbox.tail := by
  unfold recover at ok
  obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
  dsimp only at ok
  cases upgrade : request.upgrade <;>
    simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,
      Bool.false_eq_true,↓reduceIte] at ok
  all_goals
    split at ok
    next guard => exact ⟨guard.2.2.2.2.2.2.2.2.2.2.2.2.1,guard.2.2.2.2.2.2.2.2.2.2.2.2.2.1⟩
    next => simp at ok

/-- A current consuming block's witness opens the actual queue and cannot skip early. -/
theorem no_early_skip {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w) : NoEarlySkip env w := by
  intro archive reference parent block entry valid next queued early
  obtain ⟨wit,carried,index,_⟩ := Blocks.valid_timely_action valid next
  have stored := Journal.opening_current (Journal.trace_invariant trace) valid carried
  rw [index] at stored
  have inv := Journal.trace_invariant trace
  have equal := Journal.queue_unique (inv.queue.indexed ▸ List.nodup_range) stored queued
  have due : block.header.anchor.timestamp < wit.stored.timestamp+(policy env w archive reference).forcedDelay := by
    simpa only [equal,policy] using early
  obtain ⟨tx,first,hash,canonical,size⟩ := Blocks.valid_early_position_zero valid next carried due
  exact ⟨tx,first,equal ▸ hash,canonical,size⟩

/-- Complete landed FIFO service strengthens the old unqualified byte-action result:
every skip is due and every inclusion uses the complete payload's position zero. -/
theorem landing_service {env : Environment} {registry : RegistryMachine.State} {w t : World} {a : Landing}
    (genesis : RegistryMachine.Genesis registry)
    (soundness : VerifierSound env (empty env registry))
    (trace : Protocol.Trace env (empty env registry) w) (ok : Protocol.land env w a = some t) :
    LandingService env w t a := by
  obtain ⟨segment,indices,_,queue⟩ := Journal.landing_service genesis soundness trace ok
  refine ⟨segment,indices,?_,queue⟩
  intro x member
  obtain ⟨valid,next,wit,carried,index,_⟩ := Blocks.consuming_pair_action segment.valid member
  obtain ⟨other,otherCarried,_,action⟩ := Blocks.valid_timely_action valid next
  have same : other = wit := Option.some.inj (otherCarried.symm.trans carried)
  subst other
  exact ⟨wit.stored,index ▸ Journal.opening_current (Journal.trace_invariant trace) valid carried,
    valid.positionZero,action⟩

/-- The importer installs the inclusive original-header range max(o, s - U + 1)..s, preserving
its order and uniqueness. This is decoded publication, not a proof of stock Comet store
refinement. -/
theorem import_complete_range {c : Import.Candidate} {generation unsettled : Nat} {signer : Signer.State}
    {durable : Bool} {installed : Import.Installed}
    (ok : Import.publish c generation unsettled signer durable = some installed) :
    ImportRange c unsettled installed := by
  obtain ⟨_,_,_,headers⟩ := Import.publish_boundary ok
  have origin : c.origin ≤ c.height := by
    unfold Import.publish at ok
    split at ok
    next guard =>
      have stage := guard.2
      unfold Import.inspect at stage
      split at stage
      next bad => simp_all
      next clean => omega
    next => simp at ok
  refine ⟨headers,origin,by simp [headers],?_,?_⟩
  · intro n
    rw [headers,List.mem_range'_1]
    unfold Import.retainedFrom
    omega
  · rw [headers]
    exact List.nodup_range'

/-- Import publication always closes signing readiness and trust, while retaining the
signer's domain, anti-double-sign HRS, prior records and the completed original-header range
max(o, s - U + 1)..s. -/
theorem node_import_closed {env : Environment} {w t : World} {candidate : Import.Candidate} {durable : Bool}
    (ok : nodeImport env w candidate durable = some t) :
    t.node.trusted = false ∧ t.node.signer.ready = false ∧
    t.node.signer = { w.node.signer with ready := false } ∧
    t.node.signer.domain = w.node.signer.domain ∧
    t.node.signer.log = w.node.signer.log ∧
    t.node.importedHeaders = List.range' (Import.retainedFrom candidate w.inbox.configuration.unsettled)
      (candidate.height+1-Import.retainedFrom candidate w.inbox.configuration.unsettled) ∧
    (∀ n, n ∈ t.node.importedHeaders ↔ candidate.origin ≤ n ∧
      candidate.height+1 ≤ n+w.inbox.configuration.unsettled ∧ n ≤ candidate.height) ∧
    candidate.origin = w.inbox.origin.height ∧
    (∀ n, n ∈ t.node.importedHeaders ↔ w.inbox.origin.height ≤ n ∧
      candidate.height+1 ≤ n+w.inbox.configuration.unsettled ∧ n ≤ candidate.height) := by
  unfold nodeImport at ok
  split at ok
  next => simp at ok
  next =>
    split at ok
    next guard =>
      obtain ⟨installed,published,rfl⟩ := Option.map_eq_some_iff.mp ok
      obtain ⟨_,signer,_,headers⟩ := Import.publish_boundary published
      have complete := import_complete_range published
      have origin : candidate.origin = w.inbox.origin.height := guard.2.2.2.2
      exact ⟨rfl,rfl,by rw [signer],by rw [signer],by rw [signer],headers,
        complete.complete,origin,by simpa [origin] using complete.complete⟩
    next => simp at ok

end Etna.Design.Current.QueueIntegrity
