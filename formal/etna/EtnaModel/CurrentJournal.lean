import EtnaModel.CurrentProtocol

/-! Queue and completed-block facts derived from the closed current protocol journal. -/
namespace Etna.Design.Current.Journal
open Protocol

structure Shape (env : Environment) (queue : List (Nat × Forced.Entry)) (tail number : Nat) : Prop where
  indexed : queue.map Prod.fst = List.range tail
  timed : ∀ i e, (i,e) ∈ queue → e.timestamp = env.time e.l1Block ∧ e.l1Block ≤ number

structure Invariant (env : Environment) (w : World) : Prop where
  queue : Shape env w.queue w.inbox.tail w.number
  complete : w.history.map Snapshot.number = List.range w.number
  snapshots : ∀ s ∈ w.history, s.timestamp = env.time s.number ∧ s.number < w.number ∧
    s.inbox.generation ≤ w.inbox.generation ∧ Shape env s.queue s.inbox.tail s.number
  sameGeneration : ∀ s ∈ w.history, s.inbox.generation = w.inbox.generation → s.queue.IsPrefix w.queue
  /-- A complete end-block tail covers every eventual entry already admitted by that block.
  Recovery may clear hashes but cannot erase admission metadata or indices. -/
  coverage : ∀ s ∈ w.history, ∀ i e, (i,e) ∈ w.queue → e.l1Block ≤ s.number → i < s.inbox.tail

/-- A projection proved from actual calls below, never a premise of Protocol.Step. -/
inductive Effect (env : Environment) (w t : World) : Prop
  | frame (queue : t.queue = w.queue) (tail : t.inbox.tail = w.inbox.tail)
      (number : t.number = w.number) (history : t.history = w.history)
      (generation : w.inbox.generation ≤ t.inbox.generation)
  | admission (entry : Forced.Entry)
      (queue : t.queue = w.queue ++ [(w.inbox.tail,entry)])
      (tail : t.inbox.tail = w.inbox.tail+1)
      (number : t.number = w.number) (history : t.history = w.history)
      (generation : t.inbox.generation = w.inbox.generation)
      (block : entry.l1Block = w.number) (timestamp : entry.timestamp = env.time w.number)
  | clearing (clear : List Nat)
      (queue : t.queue = w.queue.map (fun (i,e) => (i,if i ∈ clear then Forced.clear (emptyHash env) e else e)))
      (tail : t.inbox.tail = w.inbox.tail) (number : t.number = w.number)
      (history : t.history = w.history) (generation : w.inbox.generation < t.inbox.generation)
  | close (queue : t.queue = w.queue) (tail : t.inbox.tail = w.inbox.tail)
      (later : w.number < t.number) (generation : t.inbox.generation = w.inbox.generation)
      (history : t.history = w.history ++
        (List.range' w.number (t.number-w.number)).map (snapshot env w))

/-- Only successful recovery can change an existing queue entry. Admissions append. -/
def PreservesExisting (before after : World) : Prop := before.queue.IsPrefix after.queue

/-- Record-order facts needed to show that rollback restores an earlier FIFO cursor. -/
structure RecordShape (w : World) : Prop where
  bounded : w.inbox.head ≤ w.inbox.tail
  frontier : ∀ r ∈ w.activeRecords, r.height ≤ w.inbox.checkpoint.height
  cursor : ∀ r ∈ w.activeRecords, r.cursor ≤ w.inbox.head
  monotone : ∀ r ∈ w.activeRecords, ∀ s ∈ w.activeRecords, r.height ≤ s.height → r.cursor ≤ s.cursor

/-- A second exhaustive projection tracks FIFO cursor ordering through rollback. -/
inductive RecordEffect (w t : World) : Prop
  | frame (records : t.activeRecords = w.activeRecords)
      (checkpoint : t.inbox.checkpoint.height = w.inbox.checkpoint.height)
      (head : t.inbox.head = w.inbox.head) (tail : t.inbox.tail = w.inbox.tail)
  | start (cp : Checkpoint) (records : t.activeRecords = [cp])
      (checkpoint : t.inbox.checkpoint.height = cp.height) (zero : cp.cursor = 0)
      (head : t.inbox.head = w.inbox.head) (tail : t.inbox.tail = w.inbox.tail)
  | admission (records : t.activeRecords = w.activeRecords)
      (checkpoint : t.inbox.checkpoint.height = w.inbox.checkpoint.height)
      (head : t.inbox.head = w.inbox.head) (tail : t.inbox.tail = w.inbox.tail+1)
  | landing (cp : Checkpoint) (records : t.activeRecords = cp :: w.activeRecords)
      (checkpoint : t.inbox.checkpoint.height = cp.height) (cursor : cp.cursor = t.inbox.head)
      (head : w.inbox.head ≤ t.inbox.head) (height : w.inbox.checkpoint.height < cp.height)
      (tail : t.inbox.tail = w.inbox.tail) (bounded : t.inbox.head ≤ w.inbox.tail)
  | rollback (trusted : Checkpoint) (member : trusted ∈ w.activeRecords)
      (records : t.activeRecords = w.activeRecords.filter (fun r => r.height ≤ trusted.height))
      (checkpoint : t.inbox.checkpoint.height = trusted.height)
      (head : t.inbox.head = trusted.cursor) (tail : t.inbox.tail = w.inbox.tail)

/-- Reachable start lifecycle and canonical active-record lookup coherence. -/
structure FrontierShape (w : World) : Prop where
  uninitialized : w.initialized = false → w.start = none
  unstarted : w.start = none → w.everLanded = false
  unlanded : w.everLanded = false → w.inbox.head = 0
  member : w.start.isSome = true → w.inbox.checkpoint ∈ w.activeRecords
  records : ∀ r ∈ w.activeRecords, recordAt w.inbox r.height = some r
  cursor : w.start.isSome = true → w.inbox.checkpoint.cursor = w.inbox.head

end Etna.Design.Current.Journal
