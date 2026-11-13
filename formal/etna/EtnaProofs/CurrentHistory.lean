import EtnaModel.CurrentJournal
import EtnaProofs.CurrentBlocks
import EtnaProofs.CurrentReference

namespace Etna.Design.Current.Journal
open Protocol
set_option maxRecDepth 20000
set_option linter.unusedSimpArgs false

theorem indexed_member {queue : List (Nat × Forced.Entry)} {tail i : Nat} {e : Forced.Entry}
    (shape : queue.map Prod.fst = List.range tail) (mem : (i,e) ∈ queue) : i < tail := by
  have h := List.mem_map_of_mem (f := Prod.fst) mem
  simpa [shape] using h

theorem shape_later {env : Environment} {queue : List (Nat × Forced.Entry)} {tail n m : Nat}
    (shape : Shape env queue tail n) (later : n ≤ m) : Shape env queue tail m :=
  ⟨shape.indexed,fun i e mem => ⟨(shape.timed i e mem).1,Nat.le_trans (shape.timed i e mem).2 later⟩⟩

theorem empty_invariant (env : Environment) (registry : RegistryMachine.State) :
    Invariant env (empty env registry) := by
  refine ⟨⟨rfl,?_⟩,rfl,?_,?_,?_⟩ <;> simp [empty]

theorem effect_invariant {env : Environment} {w t : World}
    (prior : Invariant env w) (effect : Effect env w t) : Invariant env t := by
  cases effect with
  | frame hq ht hn hh hg =>
    refine ⟨?_,?_,?_,?_,?_⟩
    · simpa [hq,ht,hn] using prior.queue
    · simpa [hh,hn] using prior.complete
    · intro s mem
      obtain ⟨clock,before,generation,shape⟩ := prior.snapshots s (hh ▸ mem)
      exact ⟨clock,hn ▸ before,Nat.le_trans generation hg,shape⟩
    · intro s mem gen
      have same : s.inbox.generation = w.inbox.generation := by
        have := (prior.snapshots s (hh ▸ mem)).2.2.1
        omega
      simpa [hq] using prior.sameGeneration s (hh ▸ mem) same
    · intro s mem i e entry before
      exact prior.coverage s (hh ▸ mem) i e (hq ▸ entry) before
  | admission entry hq ht hn hh hg block clock =>
    refine ⟨⟨?_,?_⟩,?_,?_,?_,?_⟩
    · simp [hq,ht,List.map_append,prior.queue.indexed,List.range_succ]
    · intro i e mem
      rw [hq] at mem
      rcases List.mem_append.mp mem with old | fresh
      · have timed := prior.queue.timed i e old
        exact ⟨timed.1,hn ▸ timed.2⟩
      · have pair : (i,e) = (w.inbox.tail,entry) := by simpa using fresh
        cases pair
        exact ⟨by simpa [block] using clock,by omega⟩
    · simpa [hh,hn] using prior.complete
    · intro s mem
      obtain ⟨c,n,g,sh⟩ := prior.snapshots s (hh ▸ mem)
      exact ⟨c,hn ▸ n,hg ▸ g,sh⟩
    · intro s mem gen
      rw [hq]
      exact (prior.sameGeneration s (hh ▸ mem) (gen.trans hg)).trans (List.prefix_append _ _)
    · intro s mem i e queued before
      rw [hq] at queued
      rcases List.mem_append.mp queued with old | fresh
      · exact prior.coverage s (hh ▸ mem) i e old before
      · have pair : (i,e) = (w.inbox.tail,entry) := by simpa using fresh
        cases pair
        have := (prior.snapshots s (hh ▸ mem)).2.1
        omega
  | clearing clear hq ht hn hh hg =>
    refine ⟨⟨?_,?_⟩,?_,?_,?_,?_⟩
    · simpa [hq,ht,List.map_map,Function.comp_def] using prior.queue.indexed
    · intro i e mem
      rw [hq] at mem
      obtain ⟨⟨oldIndex,old⟩,present,equal⟩ := List.mem_map.mp mem
      cases equal
      have timed := prior.queue.timed i old present
      by_cases cleared : i ∈ clear <;> simpa [cleared,Forced.clear,hn] using timed
    · simpa [hh,hn] using prior.complete
    · intro s mem
      obtain ⟨c,n,g,sh⟩ := prior.snapshots s (hh ▸ mem)
      exact ⟨c,hn ▸ n,Nat.le_trans g (Nat.le_of_lt hg),sh⟩
    · intro s mem gen
      have := (prior.snapshots s (hh ▸ mem)).2.2.1
      omega
    · intro s mem i e queued before
      rw [hq] at queued
      obtain ⟨⟨oldIndex,old⟩,present,equal⟩ := List.mem_map.mp queued
      cases equal
      have oldBefore : old.l1Block ≤ s.number := by
        by_cases cleared : i ∈ clear <;> simpa [cleared,Forced.clear] using before
      exact prior.coverage s (hh ▸ mem) i old present oldBefore
  | close hq ht later hg hh =>
    refine ⟨?_,?_,?_,?_,?_⟩
    · simpa [hq,ht] using shape_later prior.queue (Nat.le_of_lt later)
    · rw [hh,List.map_append,List.map_map,prior.complete]
      simp only [Function.comp_def,snapshot,List.map_id_fun]
      rw [List.range_eq_range',List.range_eq_range']
      have eq := List.range'_append_1 (s := 0) (m := w.number) (n := t.number-w.number)
      simpa [Nat.add_sub_of_le (Nat.le_of_lt later)] using eq
    · intro s mem
      rw [hh] at mem
      rcases List.mem_append.mp mem with old | fresh
      · obtain ⟨c,n,g,sh⟩ := prior.snapshots s old
        exact ⟨c,Nat.lt_trans n later,hg ▸ g,sh⟩
      · obtain ⟨n,range,rfl⟩ := List.mem_map.mp fresh
        obtain ⟨offset,bound,equal⟩ := List.mem_range'.mp range
        refine ⟨rfl,?_,?_,shape_later prior.queue ?_⟩
        · dsimp only [snapshot]; omega
        · dsimp only [snapshot]; omega
        · dsimp only [snapshot]; omega
    · intro s mem gen
      rw [hh] at mem
      rcases List.mem_append.mp mem with old | fresh
      · simpa [hq] using prior.sameGeneration s old (gen.trans hg)
      · obtain ⟨n,_,rfl⟩ := List.mem_map.mp fresh
        simp [snapshot,hq]
    · intro s mem i e queued before
      rw [hh] at mem
      rcases List.mem_append.mp mem with old | fresh
      · exact prior.coverage s old i e (hq ▸ queued) before
      · obtain ⟨n,_,rfl⟩ := List.mem_map.mp fresh
        exact indexed_member prior.queue.indexed (hq ▸ queued)

/-- Exhaustive projection of every successful current call; no journal fact is assumed. -/
theorem execute_effect {env : Environment} {w t : World} {call : Call}
    (ok : Protocol.execute env w call = some t) : Effect env w t := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact .close rfl rfl guard.1 rfl rfl
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next guard =>
      split at ok
      next =>
        split at ok
        next =>
          cases Option.some.inj ok
          refine .frame rfl rfl rfl rfl ?_
          dsimp only [writeStart]
          omega
        next => simp at ok
      next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      refine .frame rfl rfl rfl rfl ?_
      dsimp only [writeStart]
      omega
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl (Nat.le_succ _)
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact .frame rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | enqueue raw paid refund =>
    change enqueue env w raw paid refund = some t at ok
    unfold enqueue at ok
    split at ok
    next =>
      obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at inner
      dsimp only at inner
      split at inner
      next =>
        cases Option.some.inj inner
        exact .admission _ rfl rfl rfl rfl rfl rfl rfl
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact .frame rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact .frame rfl rfl rfl rfl (Nat.le_refl _)
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact .frame rfl rfl rfl rfl (Nat.le_refl _)
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact .frame rfl rfl rfl rfl (Nat.le_refl _)
  | recover request =>
    change recover env w request = some t at ok
    unfold recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    dsimp only at ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,↓reduceIte] at ok
    all_goals
      split at ok
      next =>
        obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact .clearing request.clear rfl rfl rfl rfl (Nat.lt_succ_self _)
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact .frame rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | land a =>
    change Protocol.land env w a = some t at ok
    unfold Protocol.land at ok
    split at ok
    next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact .frame rfl rfl rfl rfl (Nat.le_refl _)
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact .frame rfl rfl rfl rfl (Nat.le_refl _)
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact .frame rfl rfl rfl rfl (Nat.le_refl _)
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact .frame rfl rfl rfl rfl (Nat.le_refl _)

theorem transact_effect (env : Environment) (w : World) (call : Call) :
    Effect env w (Protocol.transact env w call) := by
  cases h : Protocol.execute env w call with
  | none => simpa [Protocol.transact,h] using (Effect.frame (env := env) (w := w) rfl rfl rfl rfl (Nat.le_refl _))
  | some t => simpa [Protocol.transact,h] using execute_effect h

theorem step_effect {env : Environment} {w t : World} (step : Protocol.Step env w t) : Effect env w t := by
  cases step with
  | call call => exact transact_effect _ _ _
  | node after verified => exact .frame rfl rfl rfl rfl (Nat.le_refl _)

theorem trace_invariant {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w) : Invariant env w := by
  induction trace with
  | refl => exact empty_invariant _ _
  | step _ change ih => exact effect_invariant ih (step_effect change)

/-- A history lookup authenticates one actual completed snapshot and its full anchor. -/
theorem matching_snapshot_fields {env : Environment} {w : World} {a : BlockValidity.Anchor}
    {s : Snapshot} (found : matchingSnapshot env w a = some s) :
    s ∈ w.history ∧ anchor env s = a := by
  exact ⟨List.mem_of_find?_eq_some found,by simpa using List.find?_some found⟩

theorem authenticated_snapshot {env : Environment} {w : World} {archive : List Header}
    {reference : Nat} {a : BlockValidity.Anchor}
    (auth : (policy env w archive reference).anchorAuthenticated a = true) :
    ∃ s, matchingSnapshot env w a = some s ∧ s ∈ w.history ∧ anchor env s = a := by
  obtain ⟨s,found⟩ := Option.isSome_iff_exists.mp auth
  exact ⟨s,found,matching_snapshot_fields found⟩

/-- Current-generation storage openings are transported through every actual transaction,
including slot-independent registry calls and all same-block admissions. -/
theorem opening_current {env : Environment} {w : World} (inv : Invariant env w)
    {archive : List Header} {reference : Nat} {p : Header} {b : Block} {wit : Forced.Witness}
    (valid : Blocks.Valid (policy env w archive reference) p b)
    (carried : b.body.forced = some wit) : (wit.index,wit.stored) ∈ w.queue := by
  have auth := valid.storage wit carried
  change (((matchingSnapshot env w b.header.anchor).map fun s =>
    decide ((wit.index,wit.stored) ∈ s.queue) && wit.storageAuthenticated).getD false) = true at auth
  cases found : matchingSnapshot env w b.header.anchor with
  | none => simp [found] at auth
  | some s =>
    have stored : (wit.index,wit.stored) ∈ s.queue := by
      simp only [found,Option.map_some,Option.getD_some,Bool.and_eq_true,decide_eq_true_eq] at auth
      exact auth.1
    obtain ⟨member,anchored⟩ := matching_snapshot_fields found
    have generation : s.inbox.generation = w.inbox.generation := by
      have g := valid.anchor.generation
      change b.header.anchor.generation = w.inbox.generation at g
      rw [← anchored] at g
      exact g
    exact (inv.sameGeneration s member generation).subset stored

/-- Permanent queue indices uniquely identify the currently stored entry. -/
theorem queue_unique : ∀ {queue : List (Nat × Forced.Entry)}, (queue.map Prod.fst).Nodup →
    ∀ {i : Nat} {a b : Forced.Entry}, (i,a) ∈ queue → (i,b) ∈ queue → a = b
  | [], _, _, _, _, ma, _ => absurd ma List.not_mem_nil
  | x :: rest, nodup, i, a, b, ma, mb => by
    rw [List.map_cons,List.nodup_cons] at nodup
    rcases List.mem_cons.mp ma with ha | ha <;> rcases List.mem_cons.mp mb with hb | hb
    · rw [← ha] at hb; exact (Prod.mk.inj hb).2.symm
    · subst ha; exact absurd (List.mem_map_of_mem (f := Prod.fst) hb) nodup.1
    · subst hb; exact absurd (List.mem_map_of_mem (f := Prod.fst) ha) nodup.1
    · exact queue_unique nodup.2 ha hb

/-- Completed-block tails contain all entries already admitted then. No AnchorTail or
queue-service premise is supplied: coverage comes from the full current journal. -/
theorem actual_anchor_coverage {env : Environment} {w : World} (inv : Invariant env w)
    {archive : List Header} {reference : Nat} {a : BlockValidity.Anchor}
    (auth : (policy env w archive reference).anchorAuthenticated a = true) :
    a.timestamp = env.time a.number ∧
    ∀ i e, (i,e) ∈ w.queue → e.l1Block ≤ a.number → i < a.tail := by
  obtain ⟨s,_,member,rfl⟩ := authenticated_snapshot auth
  exact ⟨(inv.snapshots s member).1,fun i e mem before => inv.coverage s member i e mem before⟩

/-- Strict L1 time lets the actual overdue entry select a snapshot that already includes
its admission. The inclusive due boundary then forces canonical inclusion or legal skip. -/
theorem local_due_action {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w)
    (clock : ∀ m n, m < n → env.time m < env.time n)
    {archive : List Header} {reference : Nat} {p : Header} {b : Block} {entry : Forced.Entry}
    (valid : Blocks.Valid (policy env w archive reference) p b)
    (queued : (p.cursor,entry) ∈ w.queue)
    (due : entry.timestamp+w.inbox.forcedDelay ≤ b.header.anchor.timestamp) :
    b.header.cursor = p.cursor+1 ∧
      ActualQueue.ByteAction (Blocks.definition (policy env w archive reference) b).bytes
        p b.body entry b.raw b.first := by
  have inv := trace_invariant trace
  obtain ⟨timestamp,covered⟩ := actual_anchor_coverage inv valid.anchor.authenticated
  have timed := (inv.queue.timed p.cursor entry queued).1
  have before : entry.l1Block ≤ b.header.anchor.number := by
    apply Nat.le_of_not_gt
    intro beyond
    have strict := clock b.header.anchor.number entry.l1Block beyond
    omega
  have pending := covered p.cursor entry queued before
  obtain ⟨wit,carried,index,_⟩ := Blocks.pending_witness valid.forced pending
  have stored := opening_current inv valid carried
  rw [index] at stored
  have equal := queue_unique (inv.queue.indexed ▸ List.nodup_range) stored queued
  have witDue : wit.stored.timestamp+(policy env w archive reference).forcedDelay ≤ b.header.anchor.timestamp := by
    simpa only [equal,policy] using due
  obtain ⟨advance,_,action⟩ := Blocks.valid_due_action valid pending carried witDue
  exact ⟨advance,equal ▸ action⟩

theorem local_late_action {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w)
    (clock : ∀ m n, m < n → env.time m < env.time n)
    {archive : List Header} {reference : Nat} {p : Header} {b : Block} {entry : Forced.Entry}
    (valid : Blocks.Valid (policy env w archive reference) p b)
    (queued : (p.cursor,entry) ∈ w.queue)
    (late : entry.timestamp+w.inbox.forcedDelay+w.inbox.maxAnchorAge ≤ b.header.timestamp) :
    b.header.cursor = p.cursor+1 ∧
      ActualQueue.ByteAction (Blocks.definition (policy env w archive reference) b).bytes
        p b.body entry b.raw b.first :=
  local_due_action trace clock valid queued
    (Forced.overdue_from_block_time _ _ _ _ _ valid.anchor.age valid.anchor.timestamp late)

/-- Every consumed edge of the accepted concrete chain serves the actual current queue,
with position-zero bytes or the exact parser/singleton skip semantics. -/
theorem chain_consumes_actual {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w)
    {archive : List Header} {reference : Nat} {p : Header} {bs : List Block}
    (chain : Blocks.Chain (policy env w archive reference) p bs)
    {x : Header × Block} (member : x ∈ Blocks.consumingPairs p bs) :
    ∃ entry, (x.1.cursor,entry) ∈ w.queue ∧
      ActualQueue.ByteAction (Blocks.definition (policy env w archive reference) x.2).bytes
        x.1 x.2.body entry x.2.raw x.2.first := by
  obtain ⟨valid,_,wit,carried,index,action⟩ := Blocks.consuming_pair_action chain member
  exact ⟨wit.stored,index ▸ opening_current (trace_invariant trace) valid carried,action⟩

theorem execute_record_effect {env : Environment} {w t : World} {call : Call}
    (ok : Protocol.execute env w call = some t) : RecordEffect w t := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next guard =>
      split at ok
      next =>
        split at ok
        next =>
          cases Option.some.inj ok
          exact .start _ rfl rfl rfl rfl rfl
        next => simp at ok
      next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact .start _ rfl rfl rfl rfl rfl
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next => cases Option.some.inj ok; exact .start _ rfl rfl rfl rfl rfl
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact .frame rfl rfl rfl rfl
    next => simp at ok
  | enqueue raw paid refund =>
    change enqueue env w raw paid refund = some t at ok
    unfold enqueue at ok
    split at ok
    next =>
      obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at inner
      dsimp only at inner
      split at inner
      next =>
        cases Option.some.inj inner
        exact .admission rfl rfl rfl rfl
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact .frame rfl rfl rfl rfl
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact .frame rfl rfl rfl rfl
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact .frame rfl rfl rfl rfl
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact .frame rfl rfl rfl rfl
  | recover request =>
    change recover env w request = some t at ok
    unfold recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    dsimp only at ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,↓reduceIte] at ok
    all_goals
      split at ok
      next =>
        obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact .frame rfl rfl rfl rfl
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next guard =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact .rollback trusted guard.2.2.2.1 rfl rfl rfl rfl
    next => simp at ok
  | land a =>
    change Protocol.land env w a = some t at ok
    unfold Protocol.land at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact .landing _ rfl rfl rfl guard.head guard.progress rfl guard.tail
    next => simp at ok
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact .frame rfl rfl rfl rfl
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact .frame rfl rfl rfl rfl
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact .frame rfl rfl rfl rfl
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact .frame rfl rfl rfl rfl
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact .frame rfl rfl rfl rfl

theorem record_effect_invariant {w t : World} (prior : RecordShape w)
    (effect : RecordEffect w t) : RecordShape t := by
  cases effect with
  | frame records checkpoint head tail =>
    exact ⟨by simpa [head,tail] using prior.bounded,
      fun r mem => checkpoint ▸ prior.frontier r (records ▸ mem),
      fun r mem => head ▸ prior.cursor r (records ▸ mem),
      fun r mr s ms h => prior.monotone r (records ▸ mr) s (records ▸ ms) h⟩
  | start cp records checkpoint zero head tail =>
    refine ⟨by simpa [head,tail] using prior.bounded,?_,?_,?_⟩
    · intro r mem
      have same : r = cp := by simpa [records] using mem
      subst r
      omega
    · intro r mem
      have same : r = cp := by simpa [records] using mem
      subst r
      omega
    · intro r mr s ms _
      have rcp : r = cp := by simpa [records] using mr
      have scp : s = cp := by simpa [records] using ms
      subst r
      subst s
      exact Nat.le_refl _
  | admission records checkpoint head tail =>
    refine ⟨?_,fun r mem => checkpoint ▸ prior.frontier r (records ▸ mem),
      fun r mem => head ▸ prior.cursor r (records ▸ mem),
      fun r mr s ms h => prior.monotone r (records ▸ mr) s (records ▸ ms) h⟩
    have := prior.bounded
    omega
  | landing cp records checkpoint cursor head height tail bounded =>
    refine ⟨tail ▸ bounded,?_,?_,?_⟩
    · intro r mem
      rw [records] at mem
      rcases List.mem_cons.mp mem with rfl | old
      · omega
      · have := prior.frontier r old; omega
    · intro r mem
      rw [records] at mem
      rcases List.mem_cons.mp mem with rfl | old
      · omega
      · exact Nat.le_trans (prior.cursor r old) head
    · intro r mr s ms ordered
      rw [records] at mr ms
      rcases List.mem_cons.mp mr with rfl | oldr <;>
        rcases List.mem_cons.mp ms with rfl | olds
      · exact Nat.le_refl _
      · have := prior.frontier s olds; omega
      · have := prior.cursor r oldr; omega
      · exact prior.monotone r oldr s olds ordered
  | rollback trusted member records checkpoint head tail =>
    refine ⟨?_,?_,?_,?_⟩
    · have := prior.cursor trusted member
      have := prior.bounded
      omega
    · intro r mem
      rw [records] at mem
      have h := of_decide_eq_true (List.mem_filter.mp mem).2
      omega
    · intro r mem
      rw [records] at mem
      obtain ⟨old,le⟩ := List.mem_filter.mp mem
      rw [head]
      exact prior.monotone r old trusted member (of_decide_eq_true le)
    · intro r mr s ms ordered
      rw [records] at mr ms
      exact prior.monotone r (List.mem_filter.mp mr).1 s (List.mem_filter.mp ms).1 ordered

theorem empty_record_shape (env : Environment) (registry : RegistryMachine.State) :
    RecordShape (empty env registry) := by
  refine ⟨Nat.le_refl _,?_,?_,?_⟩ <;> simp [empty]

theorem step_record_shape {env : Environment} {w t : World} (prior : RecordShape w)
    (step : Protocol.Step env w t) : RecordShape t := by
  cases step with
  | call call =>
    cases h : Protocol.execute env w call with
    | none => simpa [Protocol.transact,h] using prior
    | some t => simpa [Protocol.transact,h] using record_effect_invariant prior (execute_record_effect h)
  | node after verified => exact ⟨prior.bounded,prior.frontier,prior.cursor,prior.monotone⟩

theorem trace_record_shape {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w) : RecordShape w := by
  induction trace with
  | refl => exact empty_record_shape _ _
  | step _ change ih => exact step_record_shape ih change

theorem execute_nonlanding_head {env : Environment} {w t : World} {call : Call}
    (ok : Protocol.execute env w call = some t) (prior : RecordShape w)
    (notLand : ∀ a, call ≠ .land a) : t.inbox.head ≤ w.inbox.head := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact Nat.le_refl _
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next guard =>
      split at ok
      next =>
        split at ok
        next =>
          cases Option.some.inj ok
          exact Nat.le_refl _
        next => simp at ok
      next => cases Option.some.inj ok; exact Nat.le_refl _
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact Nat.le_refl _
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next => cases Option.some.inj ok; exact Nat.le_refl _
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact Nat.le_refl _
    next => simp at ok
  | enqueue raw paid refund =>
    change enqueue env w raw paid refund = some t at ok
    unfold enqueue at ok
    split at ok
    next =>
      obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at inner
      dsimp only at inner
      split at inner
      next =>
        cases Option.some.inj inner
        exact Nat.le_refl _
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact Nat.le_refl _
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact Nat.le_refl _
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Nat.le_refl _
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Nat.le_refl _
  | recover request =>
    change recover env w request = some t at ok
    unfold recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    dsimp only at ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,↓reduceIte] at ok
    all_goals
      split at ok
      next =>
        obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact Nat.le_refl _
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact Nat.le_refl _
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next guard =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact prior.cursor trusted guard.2.2.2.1
    next => simp at ok
  | land a =>
    change Protocol.land env w a = some t at ok
    unfold Protocol.land at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact False.elim (notLand a rfl)
    next => simp at ok
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact Nat.le_refl _
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact Nat.le_refl _
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Nat.le_refl _
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact Nat.le_refl _
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact Nat.le_refl _
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Nat.le_refl _

theorem execute_preserves_existing {env : Environment} {w t : World} {call : Call}
    (ok : Protocol.execute env w call = some t)
    (notRecovery : ∀ a, call ≠ .recover a) : PreservesExisting w t := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact ⟨[],by simp [PreservesExisting]⟩
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next guard =>
      split at ok
      next =>
        split at ok
        next =>
          cases Option.some.inj ok
          exact ⟨[],by simp [writeStart]⟩
        next => simp at ok
      next => cases Option.some.inj ok; exact ⟨[],by simp [landed,nodeRestart]⟩
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact ⟨[],by simp [writeStart]⟩
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨[],by simp [writeStart]⟩
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact ⟨[],by simp [landed,nodeRestart]⟩
    next => simp at ok
  | enqueue raw paid refund =>
    change enqueue env w raw paid refund = some t at ok
    unfold enqueue at ok
    split at ok
    next =>
      obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at inner
      dsimp only at inner
      split at inner
      next =>
        cases Option.some.inj inner
        exact List.prefix_append _ _
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact ⟨[],by simp [landed,nodeRestart]⟩
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact ⟨[],by simp [landed,nodeRestart]⟩
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨[],by simp [landed,nodeRestart]⟩
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨[],by simp [landed,nodeRestart]⟩
  | recover request =>
    change recover env w request = some t at ok
    unfold recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    dsimp only at ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,↓reduceIte] at ok
    all_goals
      split at ok
      next =>
        obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact False.elim (notRecovery request rfl)
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨[],by simp [landed,nodeRestart]⟩
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact ⟨[],by simp [landed,nodeRestart]⟩
    next => simp at ok
  | land a =>
    change Protocol.land env w a = some t at ok
    unfold Protocol.land at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨[],by simp [landed,nodeRestart]⟩
    next => simp at ok
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨[],by simp [landed,nodeRestart]⟩
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨[],by simp [landed,nodeRestart]⟩
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨[],by simp [landed,nodeRestart]⟩
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact ⟨[],by simp [landed,nodeRestart]⟩
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact ⟨[],by simp [landed,nodeRestart]⟩
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨[],by simp [landed,nodeRestart]⟩

theorem nonlanding_never_advances {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w) (call : Call)
    (notLand : ∀ a, call ≠ .land a) : (Protocol.transact env w call).inbox.head ≤ w.inbox.head := by
  cases h : Protocol.execute env w call with
  | none => simp [Protocol.transact,h]
  | some t => simpa [Protocol.transact,h] using execute_nonlanding_head h (trace_record_shape trace) notLand

theorem nonrecovery_preserves_existing (env : Environment) (w : World) (call : Call)
    (notRecovery : ∀ a, call ≠ .recover a) : PreservesExisting w (Protocol.transact env w call) := by
  cases h : Protocol.execute env w call with
  | none => simp [Protocol.transact,h,PreservesExisting]
  | some t => simpa [Protocol.transact,h] using execute_preserves_existing h notRecovery

/-- Already closed L1 snapshots are never rewritten by any later call. -/
theorem trace_history_persistent {env : Environment} {first last : World}
    (trace : Protocol.Trace env first last) : first.history.IsPrefix last.history := by
  induction trace with
  | refl => exact ⟨[],by simp⟩
  | step _ change ih =>
    have next : _ := step_effect change
    cases next with
    | frame _ _ _ history _ => simpa [history] using ih
    | admission _ _ _ _ history _ _ _ => simpa [history] using ih
    | clearing _ _ _ _ history _ => simpa [history] using ih
    | close _ _ _ _ history =>
      rw [history]
      exact ih.trans (List.prefix_append _ _)

/-- Positive head progress identifies an actual successful landing, not a frame premise. -/
theorem head_advance_is_landing {env : Environment} {registry : RegistryMachine.State} {w t : World}
    (trace : Protocol.Trace env (empty env registry) w) (step : Protocol.Step env w t)
    (advanced : w.inbox.head < t.inbox.head) : ∃ a, Protocol.land env w a = some t := by
  cases step with
  | node after validated => exact False.elim (Nat.lt_irrefl _ advanced)
  | call call =>
    by_cases landing : ∃ a, call = .land a
    · obtain ⟨a,rfl⟩ := landing
      cases h : Protocol.land env w a with
      | none => simp [Protocol.transact,Protocol.execute,h] at advanced
      | some result => exact ⟨a,by simp [Protocol.transact,Protocol.execute,h]⟩
    · have no : ∀ a, call ≠ .land a := fun a eq => landing ⟨a,eq⟩
      have := nonlanding_never_advances trace call no
      omega

theorem recovery_queue_exact {env : Environment} {w t : World} {request : RecoveryRequest}
    (ok : recover env w request = some t) :
    t.queue = w.queue.map (fun (i,e) =>
      (i,if i ∈ request.clear then Forced.clear (emptyHash env) e else e)) := by
  unfold recover at ok
  obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
  dsimp only at ok
  cases upgrade : request.upgrade <;>
    simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,↓reduceIte] at ok
  all_goals
    split at ok
    next =>
      obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      rfl
    next => simp at ok

theorem recovery_preserves_untargeted {env : Environment} {w t : World} {request : RecoveryRequest}
    (ok : recover env w request = some t) {i : Nat} {entry : Forced.Entry}
    (queued : (i,entry) ∈ w.queue) (untargeted : i ∉ request.clear) : (i,entry) ∈ t.queue := by
  rw [recovery_queue_exact ok]
  exact List.mem_map.mpr ⟨(i,entry),queued,by simp [untargeted]⟩

theorem find_filter_retains {α : Type} {xs : List α} {p q : α → Bool} {x : α}
    (found : xs.find? p = some x) (keep : q x = true) : (xs.filter q).find? p = some x := by
  induction xs with
  | nil => simp at found
  | cons a rest ih =>
    cases hp : p a
    · simp only [List.find?_cons,hp] at found
      have tail := ih found
      cases hq : q a <;> simp [List.filter_cons,hq,List.find?_cons,hp,tail]
    · simp only [List.find?_cons,hp] at found
      cases Option.some.inj found
      simp [List.filter_cons,keep,List.find?_cons,hp]

theorem written_lookup (records : List Checkpoint) (cp : Checkpoint) :
    (writeRecord records cp).find? (fun r => r.height == cp.height) = some cp := by
  simp [writeRecord,List.find?_cons]

theorem written_preserves_lookup {records : List Checkpoint} {cp r : Checkpoint}
    (found : records.find? (fun c => c.height == r.height) = some r)
    (different : cp.height ≠ r.height) :
    (writeRecord records cp).find? (fun c => c.height == r.height) = some r := by
  have keep : (r.height != cp.height) = true := by simp [Ne.symm different]
  have filtered := find_filter_retains (q := fun c => c.height != cp.height) found keep
  simpa [writeRecord,List.find?_cons,different] using filtered

theorem write_start_frontier (w : World) (height hash root block timestamp generation : Nat)
    (initialized : w.initialized = true) (head : w.inbox.head = 0) :
    FrontierShape (writeStart w height hash root block timestamp generation) := by
  refine ⟨?_,?_,?_,?_,?_,?_⟩
  · simp [writeStart,initialized]
  · simp [writeStart]
  · intro _; exact head
  · intro _; exact List.mem_cons_self
  · intro r mem
    have same : r = ⟨height,hash,0,0,generation,height,0⟩ := by simpa [writeStart] using mem
    subst r
    exact written_lookup _ _
  · intro _; exact head.symm

theorem land_frontier {env : Environment} {w : World} {a : Landing}
    (prior : FrontierShape w) (ordered : RecordShape w) (check : LandingChecks env w a) :
    FrontierShape (landed w a) := by
  refine ⟨?_,?_,?_,?_,?_,?_⟩
  · intro uninit
    exact prior.uninitialized uninit
  · intro absent
    change w.start = none at absent
    have h := check.started
    simp [absent] at h
  · simp [landed]
  · intro _; exact List.mem_cons_self
  · intro r mem
    change r ∈ _ :: w.activeRecords at mem
    rcases List.mem_cons.mp mem with rfl | old
    · exact written_lookup _ _
    · have before := ordered.frontier r old
      have unequal : a.input.lastHeight ≠ r.height := by have := check.progress; omega
      exact written_preserves_lookup (prior.records r old) unequal
  · intro _; rfl

theorem rollback_frontier {env : Environment} {w : World} {caller snapshot : Nat} {trusted : Checkpoint}
    (prior : FrontierShape w) (ordered : RecordShape w) {t : World}
    (ok : rollback env w caller trusted snapshot = some t) : FrontierShape t := by
  unfold rollback at ok
  split at ok
  next guard =>
    obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    have retained : trusted ∈ w.activeRecords := guard.2.2.2.1
    refine ⟨prior.uninitialized,prior.unstarted,?_,?_,?_,?_⟩
    · intro never
      have oldZero := prior.unlanded never
      have bound := ordered.cursor trusted retained
      change trusted.cursor = 0
      omega
    · intro _
      exact List.mem_filter.mpr ⟨retained,by simp⟩
    · intro r mem
      obtain ⟨old,below⟩ := List.mem_filter.mp mem
      exact find_filter_retains (prior.records r old) (by simp [of_decide_eq_true below])
    · intro _; rfl
  next => simp at ok

theorem execute_frontier_shape {env : Environment} {w t : World} {call : Call}
    (ok : Protocol.execute env w call = some t) (prior : FrontierShape w)
    (ordered : RecordShape w) : FrontierShape t := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next guard =>
      have zero := prior.unlanded (prior.unstarted (prior.uninitialized guard.2.1))
      split at ok
      next =>
        split at ok
        next =>
          cases Option.some.inj ok
          refine ⟨?_,?_,fun _ => zero,fun _ => List.mem_cons_self,?_,fun _ => zero.symm⟩
          · intro impossible; cases impossible
          · intro impossible; cases impossible
          · intro r mem
            have same : r = ⟨0,env.genesisHeader.elHash,0,0,0,0,0⟩ := by simpa only [writeStart,List.mem_singleton] using mem
            subst r
            exact written_lookup _ _
        next => simp at ok
      next =>
        cases Option.some.inj ok
        exact ⟨by simp,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact write_start_frontier w height hash root w.number (env.time w.number) 0
        guard.1 (prior.unlanded (prior.unstarted guard.2.1))
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,present,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      have initialized : w.initialized = true := by
        cases hi : w.initialized
        · have absent := prior.uninitialized hi
          rw [absent] at present
          cases present
        · rfl
      exact write_start_frontier w height hash root w.number (env.time w.number) (w.inbox.generation+1)
        initialized (prior.unlanded guard.2.2.1)
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
    next => simp at ok
  | enqueue raw paid refund =>
    change enqueue env w raw paid refund = some t at ok
    unfold enqueue at ok
    split at ok
    next =>
      obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at inner
      dsimp only at inner
      split at inner
      next =>
        cases Option.some.inj inner
        exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
  | recover request =>
    change recover env w request = some t at ok
    unfold recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    dsimp only at ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,↓reduceIte] at ok
    all_goals
      split at ok
      next =>
        obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
    next => simp at ok
  | rollback caller trusted restored =>
    exact rollback_frontier prior ordered ok
  | land a =>
    change Protocol.land env w a = some t at ok
    obtain ⟨check,rfl⟩ := Protocol.land_success ok
    exact land_frontier prior ordered check
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩

theorem empty_frontier_shape (env : Environment) (registry : RegistryMachine.State) :
    FrontierShape (empty env registry) := by
  refine ⟨fun _ => rfl,fun _ => rfl,fun _ => rfl,?_,?_,?_⟩ <;> simp [empty]

theorem step_frontier_shape {env : Environment} {w t : World} (prior : FrontierShape w)
    (ordered : RecordShape w) (step : Protocol.Step env w t) : FrontierShape t := by
  cases step with
  | call call =>
    cases h : Protocol.execute env w call with
    | none => simpa [Protocol.transact,h] using prior
    | some t => simpa [Protocol.transact,h] using execute_frontier_shape h prior ordered
  | node after verified =>
    exact ⟨prior.uninitialized,prior.unstarted,prior.unlanded,prior.member,prior.records,prior.cursor⟩

theorem trace_frontier_shape {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w) : FrontierShape w := by
  induction trace with
  | refl => exact empty_frontier_shape _ _
  | step earlier change ih => exact step_frontier_shape ih (trace_record_shape earlier) change

/-- The execution frontier is a retained active record with exactly the current FIFO head. -/
theorem trace_frontier_record {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Protocol.Trace env (empty env registry) w) (started : w.start.isSome = true) :
    w.inbox.checkpoint ∈ w.activeRecords ∧
    recordAt w.inbox w.inbox.checkpoint.height = some w.inbox.checkpoint ∧
    w.inbox.checkpoint.cursor = w.inbox.head := by
  have shape := trace_frontier_shape trace
  exact ⟨shape.member started,shape.records _ (shape.member started),shape.cursor started⟩

end Etna.Design.Current.Journal
