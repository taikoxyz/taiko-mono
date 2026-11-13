import EtnaProofs.CurrentCoherentCustody
import EtnaModel.CurrentUnzen

/-! The closed Unzen proposal lane: ordinary proofs extend the stored finalized
endpoint. Unzen proposal/recovery upgrades are outside this fixed-cut machine. -/
namespace Etna.Design.Current.Protocol.Custody
set_option maxRecDepth 20000
set_option linter.unusedSimpArgs false

theorem execute_unzen_frame {env : Environment} {w t : World} {call : Call}
    (other : ∀ p h b, call ≠ .unzenProve p h b)
    (ok : execute env w call = some t) :
    t.unzen = w.unzen ∧ t.unzenHeader = w.unzenHeader ∧ t.legacySignals = w.legacySignals := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next =>
      split at ok
      next =>
        split at ok
        next => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
        next => simp at ok
      next => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact ⟨rfl,rfl,rfl⟩
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
        exact ⟨rfl,rfl,rfl⟩
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact ⟨rfl,rfl,rfl⟩
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact ⟨rfl,rfl,rfl⟩
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl,rfl⟩
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl,rfl⟩
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
        exact ⟨rfl,rfl,rfl⟩
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact ⟨rfl,rfl,rfl⟩
    next => simp at ok
  | land a =>
    obtain ⟨_,rfl⟩ := land_success ok
    exact ⟨rfl,rfl,rfl⟩
  | unzenProve proposal header proof => exact (other _ _ _ rfl).elim
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl,rfl⟩
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact ⟨rfl,rfl,rfl⟩
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact ⟨rfl,rfl,rfl⟩
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl,rfl⟩



/-- Every successful ordinary call keeps or advances the closed proposal frontier. -/
theorem execute_unzen_proposal_monotone {env : Environment} {w t : World} {call : Call}
    (ok : execute env w call = some t) : w.unzen.finalizedProposal ≤ t.unzen.finalizedProposal := by
  by_cases legacy : ∃ p h b, call = .unzenProve p h b
  · obtain ⟨p,h,b,rfl⟩ := legacy
    change unzenProve env w p h b = some t at ok
    unfold unzenProve at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      dsimp only
      omega
    next => simp at ok
  · have frame := execute_unzen_frame (fun p h b eq => legacy ⟨p,h,b,eq⟩) ok
    rw [frame.1]
    exact Nat.le_refl _

 theorem trace_unzen_proposal_monotone {env : Environment} {w t : World}
    (trace : Trace env w t) : w.unzen.finalizedProposal ≤ t.unzen.finalizedProposal := by
  induction trace with
  | refl => exact Nat.le_refl _
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa [transact,ok] using ih
      | some result =>
        have mono := execute_unzen_proposal_monotone ok
        simpa [transact,ok] using Nat.le_trans ih mono
    | node after checked => exact ih


/-- An authenticated extension keeps all older checkpoints below its endpoint. -/
theorem legacy_prefix_extended {env : Environment} {w : World} {proposal : Nat} {h : Header}
    (held : LegacyPrefix env w) (bound : HashBound env h)
    (extension : ∀ parent, w.unzenHeader = some parent → HashBound env parent → parent.height < h.height) :
    LegacyPrefix env { w with
      unzen := ⟨w.unzen.nextProposal,proposal,h.elHash,true,h.height,h.elHash,h.stateRoot⟩,
      unzenHeader := some h,legacySignals := w.legacySignals ++ [⟨h.height,h.elHash,h.stateRoot⟩] } := by
  refine Or.inr ⟨h,rfl,rfl,bound,rfl,?_⟩
  intro signal member
  rcases List.mem_append.mp member with old | fresh
  · rcases held with ⟨_,_,empty⟩ | ⟨parent,retained,_,parentBound,_,previous⟩
    · simp [empty] at old
    · exact Nat.le_trans (previous signal old) (Nat.le_of_lt (extension parent retained parentBound))
  · have same : signal = ⟨h.height,h.elHash,h.stateRoot⟩ := by simpa using fresh
    subst signal
    exact Nat.le_refl _

 theorem legacy_prefix_frame {env : Environment} {w t : World}
    (held : LegacyPrefix env w) (unzen : t.unzen = w.unzen)
    (header : t.unzenHeader = w.unzenHeader) (signals : t.legacySignals = w.legacySignals) :
    LegacyPrefix env t := by
  simpa only [LegacyPrefix,unzen,header,signals] using held

/-- At an accepted switching root all earlier legacy signals are at or below S. -/
theorem legacy_bounded_at_first_fence {env : Environment} {w : World} {h : Header}
    (primitive : Primitives env) (held : LegacyPrefix env w)
    (fence : FirstFence env w h) (bound : HashBound env h) :
    ∀ signal ∈ w.legacySignals, signal.height ≤ h.height := by
  obtain ⟨start,_,_,_,_,finalized,present,_,_,_,_,hash,_,_,_⟩ := fence
  rcases held with ⟨_,absent,_⟩ | ⟨last,_,_,lastBound,lastHash,previous⟩
  · simp [absent] at present
  · have same := primitive.separation h last bound lastBound
      (hash.trans (finalized.symm.trans lastHash))
    intro signal member
    simpa only [same.1] using previous signal member

 theorem unzen_prefix {env : Environment} {w t : World} {proposal proof : Nat} {h : Header}
    (primitive : Primitives env) (extension : UnzenExtension env env.unzenParent)
    (held : LegacyPrefix env w) (ok : unzenProve env w proposal h proof = some t) :
    LegacyPrefix env t := by
  unfold unzenProve at ok
  split at ok
  next guard =>
    cases Option.some.inj ok
    apply legacy_prefix_extended held (primitive.unzen _ _ _ guard.2.1).2.1
    intro parent retained bound
    rcases held with ⟨none,_,_⟩ | ⟨last,header,_,_,lastHash,_⟩
    · simp [retained] at none
    · have same : last = parent := Option.some.inj (header.symm.trans retained)
      subst last
      exact extension _ _ _ _ _ guard.2.2.1 guard.2.1 bound (guard.2.2.2.2.1.trans lastHash)
  next => simp at ok

 theorem execute_legacy_prefix {env : Environment} {w t : World} {call : Call}
    (primitive : Primitives env) (extension : UnzenExtension env env.unzenParent)
    (held : LegacyPrefix env w) (ok : execute env w call = some t) : LegacyPrefix env t := by
  by_cases legacy : ∃ p h b, call = .unzenProve p h b
  · obtain ⟨p,h,b,rfl⟩ := legacy
    exact unzen_prefix primitive extension held ok
  · obtain ⟨unzen,header,signals⟩ := execute_unzen_frame (fun p h b eq => legacy ⟨p,h,b,eq⟩) ok
    exact legacy_prefix_frame held unzen header signals

 theorem trace_legacy_prefix {env : Environment} {registry : RegistryMachine.State} {w : World}
    (primitive : Primitives env) (extension : UnzenExtension env env.unzenParent)
    (trace : Trace env (empty env registry) w) : LegacyPrefix env w := by
  induction trace with
  | refl => exact Or.inl ⟨rfl,rfl,rfl⟩
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa [transact,ok] using ih
      | some result => simpa [transact,ok] using execute_legacy_prefix primitive extension ih ok
    | node after checked => exact ih

/-- Once the final Unzen proposal is finalized, no ordinary legacy proof remains. -/
theorem unzen_closed {env : Environment} {w : World}
    (closed : w.unzen.nextProposal = w.unzen.finalizedProposal+1)
    (proposal : Nat) (h : Header) (proof : Hash) : unzenProve env w proposal h proof = none := by
  unfold unzenProve
  split
  next guard => omega
  next => rfl


 theorem nonlanding_frame {env : Environment} {w t : World}
    (ever : t.everLanded = w.everLanded) (records : t.activeRecords = w.activeRecords)
    (signals : t.inbox.signals = w.inbox.signals) (checkpoint : t.inbox.checkpoint = w.inbox.checkpoint)
    (start : t.start = w.start) : NonlandingEffect env w t := by
  exact ⟨ever,fun s mem => signals ▸ mem,fun held => by
    simpa only [Waiting,Pending,records,signals,checkpoint,start] using held⟩

theorem execute_nonlanding_effect {env : Environment} {w t : World} {call : Call}
    (switching : env.core.unzenInbox ≠ 0)
    (other : ∀ a, call ≠ .land a)
    (ok : execute env w call = some t) :
    NonlandingEffect env w t := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact nonlanding_frame rfl rfl rfl rfl rfl
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next =>
      simp only [switching,↓reduceIte] at ok
      cases Option.some.inj ok
      exact nonlanding_frame rfl rfl rfl rfl rfl
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next =>
      cases Option.some.inj ok
      refine ⟨rfl,fun _ mem => mem,?_⟩
      intro held
      exact ⟨held.1,Or.inr ⟨rfl,switching,⟨height,hash,root⟩,rfl,rfl,rfl,rfl,rfl,rfl⟩⟩
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next =>
      cases Option.some.inj ok
      refine ⟨rfl,fun _ mem => mem,?_⟩
      intro held
      exact ⟨held.1,Or.inr ⟨rfl,switching,⟨height,hash,root⟩,rfl,rfl,rfl,rfl,rfl,rfl⟩⟩
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact nonlanding_frame rfl rfl rfl rfl rfl
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
        exact nonlanding_frame rfl rfl rfl rfl rfl
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact nonlanding_frame rfl rfl rfl rfl rfl
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact nonlanding_frame rfl rfl rfl rfl rfl
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact nonlanding_frame rfl rfl rfl rfl rfl
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact nonlanding_frame rfl rfl rfl rfl rfl
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
        exact nonlanding_frame rfl rfl rfl rfl rfl
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact nonlanding_frame rfl rfl rfl rfl rfl
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next guard =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      refine ⟨rfl,fun _ mem => (List.mem_filter.mp mem).1,?_⟩
      rintro ⟨signals,waiting⟩
      have member : trusted ∈ w.activeRecords := guard.2.2.2.1
      refine ⟨by simp [signals],?_⟩
      rcases waiting with none | ⟨single,pending⟩
      · simp [none] at member
      · have eq : trusted = w.inbox.checkpoint := by simpa [single] using member
        subst trusted
        exact Or.inr ⟨by simp [single],pending⟩
    next => simp at ok
  | land a => exact (other _ rfl).elim
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact nonlanding_frame rfl rfl rfl rfl rfl
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact nonlanding_frame rfl rfl rfl rfl rfl
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact nonlanding_frame rfl rfl rfl rfl rfl
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact nonlanding_frame rfl rfl rfl rfl rfl
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact nonlanding_frame rfl rfl rfl rfl rfl
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact nonlanding_frame rfl rfl rfl rfl rfl




 theorem linked_start_lower {env : Environment} {initial : World} {start : StartData}
    {H : Checkpoint → Header} {records : List Checkpoint}
    (links : Linked env initial (some start) H records)
    (headers : ∀ cp ∈ records, HeaderOf cp (H cp)) :
    ∀ cp ∈ records, start.height ≤ cp.height := by
  induction links with
  | root cp root =>
    obtain ⟨s,written,height,_,_,_⟩ := root
    have same : s = start := (Option.some.inj written).symm
    subst s
    intro record member
    have eq : record = cp := by simpa using member
    subst record
    have bound := (headers cp (List.mem_singleton_self _)).1
    omega
  | step child parent rest parentHeight lower edge prior ih =>
    intro cp member
    have earlier := ih (fun r mem => headers r (List.mem_cons_of_mem _ mem))
    rcases List.mem_cons.mp member with rfl | old
    · exact Nat.le_trans (earlier parent (List.mem_cons_self)) (Nat.le_of_lt lower)
    · exact earlier cp old

 theorem coherent_checkpoint_above_start {env : Environment} {initial w : World} {start : StartData}
    (held : Coherent env initial w) (written : w.start = some start)
    (member : w.inbox.checkpoint ∈ w.activeRecords) : start.height ≤ w.inbox.checkpoint.height := by
  rcases held with ⟨_,waiting⟩ | ⟨H,_,headers,links,_⟩
  · rcases waiting with empty | ⟨_,switching,s,stored,height,_⟩
    · simp [empty] at member
    · have same : s = start := Option.some.inj (stored.symm.trans written)
      subst s
      exact Nat.le_of_eq height.symm
  · apply linked_start_lower (written ▸ links) (fun cp mem => (headers cp mem).1) _ member

 theorem execute_closed_unzen_frame {env : Environment} {w t : World} {call : Call}
    (closed : w.unzen.nextProposal = w.unzen.finalizedProposal+1)
    (ok : execute env w call = some t) :
    t.unzen = w.unzen ∧ t.unzenHeader = w.unzenHeader ∧ t.legacySignals = w.legacySignals := by
  by_cases legacy : ∃ p h b, call = .unzenProve p h b
  · obtain ⟨p,h,b,rfl⟩ := legacy
    change unzenProve env w p h b = some t at ok
    rw [unzen_closed closed] at ok
    cases ok
  · exact execute_unzen_frame (fun p h b eq => legacy ⟨p,h,b,eq⟩) ok

 theorem execute_switching_fence {env : Environment} {registry : RegistryMachine.State}
    {w t : World} {call : Call} (genesis : RegistryMachine.Genesis registry)
    (switching : env.core.unzenInbox ≠ 0)
    (primitive : Primitives env) (soundness : VerifierSound env (empty env registry))
    (reach : Trace env (empty env registry) w) (prefixHeld : LegacyPrefix env w)
    (held : SwitchingFence env w) (ok : execute env w call = some t) : SwitchingFence env t := by
  by_cases landing : ∃ a, call = .land a
  · obtain ⟨a,rfl⟩ := landing
    change land env w a = some t at ok
    have checks := (land_success ok).1
    obtain ⟨member,record,cursor⟩ := Journal.trace_frontier_record reach checks.started
    rcases held with ⟨ever,noSignals,waiting⟩ | ⟨ever,start,written,closed,legacyBound,signalBound⟩
    · rcases waiting with none | ⟨_,pending⟩
      · simp [none] at member
      · obtain ⟨segment,_,_⟩ := landing_edge_authorized genesis primitive soundness reach ok
        have certificate := certified_landing genesis soundness reach ok
        obtain ⟨fence,_⟩ := pending_parent_fence primitive reach ok
          (trace_invariant genesis primitive soundness reach) segment cursor record pending certificate
        have bounded := legacy_bounded_at_first_fence primitive prefixHeld fence segment.parentHashBound
        obtain ⟨start,written,atStart,_,closed,_,_,_,_,_,height,_,_,_,_⟩ := fence
        obtain ⟨_,rfl⟩ := land_success ok
        refine Or.inr ⟨rfl,start,written,closed,?_,?_⟩
        · change ∀ legacy ∈ w.legacySignals, legacy.height ≤ start.height
          simpa only [height] using bounded
        · intro signal mem
          change signal ∈ w.inbox.signals ++ [⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastStateRoot⟩] at mem
          rw [noSignals] at mem
          have same : signal = ⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastStateRoot⟩ := by simpa using mem
          subst signal
          change start.height < a.input.lastHeight
          have := checks.progress
          omega
    · have lower := coherent_checkpoint_above_start (trace_coherent genesis primitive soundness reach) written member
      obtain ⟨_,rfl⟩ := land_success ok
      refine Or.inr ⟨rfl,start,written,closed,legacyBound,?_⟩
      intro signal mem
      rcases List.mem_append.mp mem with old | fresh
      · exact signalBound signal old
      · have same : signal = ⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastStateRoot⟩ := by simpa using fresh
        subst signal
        change start.height < a.input.lastHeight
        have := checks.progress
        omega
  · have effect := execute_nonlanding_effect switching (fun a eq => landing ⟨a,eq⟩) ok
    rcases held with ⟨ever,waiting⟩ | ⟨ever,start,written,closed,legacyBound,signalBound⟩
    · exact Or.inl ⟨effect.1.trans ever,effect.2.2 waiting⟩
    · have frozen := execute_frozen (Journal.trace_frontier_shape reach) ever ok
      obtain ⟨unzen,_,signals⟩ := execute_closed_unzen_frame closed ok
      refine Or.inr ⟨frozen.2,start,frozen.1.trans written,?_,?_,?_⟩
      · simpa only [unzen] using closed
      · simpa only [signals] using legacyBound
      · intro signal mem
        exact signalBound signal (effect.2.1 signal mem)

 theorem trace_switching_fence {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry)
    (switching : env.core.unzenInbox ≠ 0) (primitive : Primitives env)
    (extension : UnzenExtension env env.unzenParent) (soundness : VerifierSound env (empty env registry))
    (trace : Trace env (empty env registry) w) : SwitchingFence env w := by
  induction trace with
  | refl => exact Or.inl ⟨rfl,rfl,Or.inl rfl⟩
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa [transact,ok] using ih
      | some result =>
        have preserved := execute_switching_fence genesis switching primitive soundness prior
          (trace_legacy_prefix primitive extension prior) ih ok
        simpa [transact,ok] using preserved
    | node after checked => exact ih

/-- Full switching traces cannot overwrite a legacy checkpoint with an Etna one,
including a legacy proof emitted before a refused/too-low start was written. -/
theorem trace_legacy_etna_disjoint {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry)
    (switching : env.core.unzenInbox ≠ 0) (primitive : Primitives env)
    (extension : UnzenExtension env env.unzenParent) (soundness : VerifierSound env (empty env registry))
    (trace : Trace env (empty env registry) w) : LegacyEtnaDisjoint w := by
  rcases trace_switching_fence genesis switching primitive extension soundness trace with
    ⟨_,empty,_⟩ | ⟨_,start,_,_,legacyBound,signalBound⟩
  · intro legacy old etna fresh
    simp [empty] at fresh
  · intro legacy old etna fresh
    exact Nat.lt_of_le_of_lt (legacyBound legacy old) (signalBound etna fresh)

end Etna.Design.Current.Protocol.Custody
