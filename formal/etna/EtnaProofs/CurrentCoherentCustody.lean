import EtnaModel.CurrentCoherentCustody
import EtnaProofs.CurrentCustody

namespace Etna.Design.Current.Protocol.Custody
set_option maxRecDepth 20000
set_option linter.unusedSimpArgs false

 theorem linked_map {env : Environment} {initial : World} {start : Option StartData}
    {H G : Checkpoint → Header} {records : List Checkpoint}
    (links : Linked env initial start H records)
    (same : ∀ cp ∈ records, G cp = H cp) : Linked env initial start G records := by
  induction links with
  | root cp root => exact .root cp (by simpa [same cp (by simp)] using root)
  | step child parent rest height lower edge prior ih =>
    refine .step child parent rest height lower ?_ (ih (fun cp mem => same cp (List.mem_cons_of_mem _ mem)))
    simpa [same child (by simp),same parent (by simp)] using edge

 theorem linked_bounds {env : Environment} {initial : World} {start : Option StartData}
    {H : Checkpoint → Header} {records : List Checkpoint}
    (links : Linked env initial start H records) :
    ∀ head rest, records = head :: rest → ∀ cp ∈ records, cp.height ≤ head.height := by
  induction links with
  | root cp root =>
    intro head rest eq x mem
    cases eq
    have same : x = cp := by simpa using mem
    subst x
    exact Nat.le_refl _
  | step child parent rest height lower edge prior ih =>
    intro head tail eq cp mem
    cases eq
    rcases List.mem_cons.mp mem with rfl | later
    · exact Nat.le_refl _
    · have bound := ih parent rest rfl cp later
      omega

 theorem linked_filter {env : Environment} {initial : World} {start : Option StartData}
    {H : Checkpoint → Header} {records : List Checkpoint} {trusted : Checkpoint}
    (links : Linked env initial start H records) (member : trusted ∈ records) :
    Linked env initial start H (records.filter (fun cp => cp.height ≤ trusted.height)) ∧
    (records.filter (fun cp => cp.height ≤ trusted.height)).head? = some trusted := by
  induction links with
  | root cp root =>
    have eq : trusted = cp := by simpa using member
    subst trusted
    simpa using And.intro (Linked.root cp root) (show [cp].head? = some cp from rfl)
  | step child parent rest height lower edge prior ih =>
    by_cases kept : child.height ≤ trusted.height
    · have eq : trusted = child := by
        rcases List.mem_cons.mp member with eq | later
        · exact eq
        · have below := linked_bounds prior parent rest rfl trusted later
          omega
      subst trusted
      have allKept : (child :: parent :: rest).filter (fun cp => cp.height ≤ child.height) =
          child :: parent :: rest := List.filter_eq_self.mpr (fun cp mem =>
            decide_eq_true (linked_bounds (.step child parent rest height lower edge prior) child _ rfl cp mem))
      rw [allKept]
      exact ⟨.step child parent rest height lower edge prior,rfl⟩
    · have later : trusted ∈ parent :: rest := by
        rcases List.mem_cons.mp member with eq | later
        · subst trusted; exact (kept (Nat.le_refl _)).elim
        · exact later
      simpa [List.filter_cons,kept] using ih later

 theorem frame_coherent {env : Environment} {initial w t : World}
    (held : Coherent env initial w)
    (records : t.activeRecords = w.activeRecords) (signals : t.inbox.signals = w.inbox.signals)
    (start : t.start = w.start) (checkpoint : t.inbox.checkpoint = w.inbox.checkpoint) :
    Coherent env initial t := by
  rcases held with waiting | ⟨H,head,headers,links,named⟩
  · exact Or.inl (by simpa [Waiting,Pending,records,signals,start,checkpoint] using waiting)
  · exact Or.inr ⟨H,by simpa [records,checkpoint] using head,
      by simpa [records] using headers,by simpa [records,start] using links,
      by simpa [records,signals] using named⟩

 theorem write_start_coherent {env : Environment} {initial w : World}
    (switching : env.core.unzenInbox ≠ 0) (noSignals : w.inbox.signals = [])
    (height hash root block timestamp generation : Nat) :
    Coherent env initial (writeStart w height hash root block timestamp generation) := by
  exact Or.inl ⟨noSignals,Or.inr ⟨rfl,switching,⟨height,hash,root⟩,rfl,rfl,rfl,rfl,rfl,rfl⟩⟩

 theorem rollback_coherent {env : Environment} {initial w t : World} {caller snap : Nat}
    {trusted : Checkpoint} (held : Coherent env initial w)
    (ok : rollback env w caller trusted snap = some t) : Coherent env initial t := by
  unfold rollback at ok
  split at ok
  next guard =>
    obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    have member : trusted ∈ w.activeRecords := guard.2.2.2.1
    rcases held with ⟨signals,waiting⟩ | ⟨H,head,headers,links,named⟩
    · refine Or.inl ⟨by simp [signals],?_⟩
      rcases waiting with none | ⟨single,pending⟩
      · simp [none] at member
      · have eq : trusted = w.inbox.checkpoint := by simpa [single] using member
        subst trusted
        exact Or.inr ⟨by simp [single],pending⟩
    · obtain ⟨restricted,first⟩ := linked_filter links member
      refine Or.inr ⟨H,first,fun cp mem => headers cp (List.mem_filter.mp mem).1,restricted,?_⟩
      intro signal mem
      obtain ⟨old,kept⟩ := List.mem_filter.mp mem
      obtain ⟨cp,record,height,hash,root⟩ := named signal old
      exact ⟨cp,List.mem_filter.mpr ⟨record,decide_eq_true (by
        have := of_decide_eq_true kept
        omega)⟩,height,hash,root⟩
  next => simp at ok

 theorem landing_coherent {env : Environment} {registry : RegistryMachine.State} {w t : World} {a : Landing}
    (genesis : RegistryMachine.Genesis registry)
    (primitive : Primitives env) (soundness : VerifierSound env (empty env registry))
    (reach : Trace env (empty env registry) w) (ok : land env w a = some t)
    (old : Invariant env (empty env registry) w) (held : Coherent env (empty env registry) w) (frontier : Frontier w) :
    Coherent env (empty env registry) t := by
  have checks := (land_success ok).1
  obtain ⟨member,record,cursor⟩ := frontier checks.started
  have certificate := certified_landing genesis soundness reach ok
  obtain ⟨segment⟩ := accepted_suffix_from_certificate ok certificate record
  have existing : ∃ H : Checkpoint → Header,
      w.activeRecords.head? = some w.inbox.checkpoint ∧
      (∀ cp ∈ w.activeRecords, HeaderOf cp (H cp) ∧ HashBound env (H cp)) ∧
      Linked env (empty env registry) w.start H w.activeRecords ∧
      (∀ signal ∈ w.inbox.signals, ∃ cp ∈ w.activeRecords,
        cp.height = signal.height ∧ cp.elHash = signal.hash ∧ (H cp).stateRoot = signal.stateRoot) ∧
      H w.inbox.checkpoint = segment.parent := by
    rcases held with ⟨noSignals,waiting⟩ | ⟨H,head,headers,links,named⟩
    · rcases waiting with none | ⟨single,pending⟩
      · simp [none] at member
      · obtain ⟨fence,legacy,retained,auth,starts⟩ :=
          pending_parent_fence primitive reach ok old segment cursor record pending certificate
        have rootAuth : AuthenticRoot env (empty env registry) segment.parent :=
          Or.inr ⟨w,t,a,legacy,reach,ok,fence,retained,auth,starts⟩
        obtain ⟨start,written,atStart,switching,complete,finalized,checkpoint,_,hash,root,
          height,el,state,implementation,preFork⟩ := fence
        refine ⟨fun _ => segment.parent,by simp [single],?_,?_,?_,rfl⟩
        · intro cp mem
          have eq : cp = w.inbox.checkpoint := by simpa [single] using mem
          subst cp
          exact ⟨⟨segment.parentHeight,by rw [cursor]; exact segment.parentCut⟩,segment.parentHashBound⟩
        · rw [single]
          exact .root _ ⟨start,written,height,el,state,rootAuth⟩
        · simp [noSignals]
    · obtain ⟨matched,bound⟩ := headers _ member
      have cut : (H w.inbox.checkpoint).cut = segment.parent.cut := by
        rw [matched.2,cursor]; exact segment.parentCut.symm
      exact ⟨H,head,headers,links,named,bound_headers_equal primitive bound segment.parentHashBound cut⟩
  obtain ⟨H,head,headers,links,named,parent⟩ := existing
  obtain ⟨rest,records⟩ := List.head?_eq_some_iff.mp head
  let cp : Checkpoint := ⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastCometHash,
    a.input.forcedInclusionHead,w.inbox.generation,w.inbox.checkpoint.height,a.input.lastValStateHash⟩
  let terminal := Blocks.terminal segment.parent segment.blocks
  let G : Checkpoint → Header := fun r => if r = cp then terminal else H r
  have fresh : ∀ r ∈ w.activeRecords, r ≠ cp := by
    intro r mem eq
    have below := linked_bounds links w.inbox.checkpoint rest records r mem
    have higher := checks.progress
    subst r
    change a.input.lastHeight ≤ _ at below
    omega
  have kept : ∀ r ∈ w.activeRecords, G r = H r := by
    intro r mem
    simp [G,fresh r mem]
  have newHeader : G cp = terminal := by simp [G]
  have parentHeader : G w.inbox.checkpoint = segment.parent := (kept _ member).trans parent
  have edge : Edge env (empty env registry) (G w.inbox.checkpoint) (G cp) :=
    ⟨w,t,a,segment,reach,ok,parentHeader.symm,newHeader.symm⟩
  rcases land_success ok with ⟨_,rfl⟩
  refine Or.inr ⟨G,rfl,?_,?_,?_⟩
  · intro r mem
    rcases List.mem_cons.mp mem with rfl | oldMember
    · rw [newHeader]
      exact ⟨⟨segment.terminalHeight,segment.terminalCut⟩,suffix_terminal_bound segment⟩
    · rw [kept r oldMember]
      exact headers r oldMember
  · have prior := linked_map links kept
    change Linked env (empty env registry) w.start G (cp :: w.activeRecords)
    rw [records] at prior ⊢
    exact .step cp w.inbox.checkpoint rest rfl checks.progress edge prior
  · intro signal mem
    rcases List.mem_append.mp mem with oldSignal | newSignal
    · obtain ⟨r,present,height,hash,root⟩ := named signal oldSignal
      exact ⟨r,List.mem_cons_of_mem _ present,height,hash,by rw [kept r present]; exact root⟩
    · have same : signal = ⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastStateRoot⟩ := by simpa using newSignal
      subst signal
      exact ⟨cp,List.mem_cons_self,rfl,rfl,by rw [newHeader]; exact segment.terminalRoot⟩

 theorem linked_start_written {env : Environment} {initial : World} {start : Option StartData}
    {H : Checkpoint → Header} {records : List Checkpoint}
    (links : Linked env initial start H records) : ∃ s, start = some s := by
  induction links with
  | root cp root => obtain ⟨s,written,_⟩ := root; exact ⟨s,written⟩
  | step _ _ _ _ _ _ _ ih => exact ih

 theorem unstarted_no_signals {env : Environment} {initial w : World}
    (held : Coherent env initial w) (unstarted : w.start = none) : w.inbox.signals = [] := by
  rcases held with waiting | ⟨H,head,headers,links,named⟩
  · exact waiting.1
  · obtain ⟨s,written⟩ := linked_start_written links
    simp [unstarted] at written

 theorem initialize_coherent {env : Environment} {initial w t : World} {caller : Nat}
    (primitive : Primitives env) (held : Coherent env initial w)
    (ok : initializeInbox env w caller = some t) : Coherent env initial t := by
  unfold initializeInbox at ok
  split at ok
  next guard =>
    split at ok
    next newNetwork =>
      split at ok
      next genesis =>
        cases Option.some.inj ok
        refine Or.inr ⟨fun _ => env.genesisHeader,rfl,?_,?_,?_⟩
        · intro cp mem
          have same : cp = ⟨0,env.genesisHeader.elHash,0,0,0,0,0⟩ := by simpa [writeStart] using mem
          subst cp
          exact ⟨⟨genesis.1,by simp [BlockValidity.Header.cut,genesis.2.1,genesis.2.2.1,genesis.2.2.2]⟩,primitive.genesis⟩
        · exact .root _ ⟨⟨0,env.genesisHeader.elHash,env.genesisHeader.stateRoot⟩,rfl,genesis.1,rfl,rfl,
            Or.inl ⟨newNetwork,rfl⟩⟩
        · intro signal mem
          have same : signal = ⟨0,env.genesisHeader.elHash,env.genesisHeader.stateRoot⟩ := by simpa [writeStart] using mem
          subst signal
          exact ⟨_,List.mem_singleton_self _,rfl,rfl,rfl⟩
      next => simp at ok
    next =>
      cases Option.some.inj ok
      exact frame_coherent held rfl rfl rfl rfl
  next => simp at ok

theorem execute_coherent {env : Environment} {registry : RegistryMachine.State} {w t : World} {call : Call}
    (genesis : RegistryMachine.Genesis registry)
    (primitive : Primitives env) (soundness : VerifierSound env (empty env registry))
    (reach : Trace env (empty env registry) w) (inv : Invariant env (empty env registry) w)
    (held : Coherent env (empty env registry) w) (frontier : Frontier w)
    (ok : execute env w call = some t) : Coherent env (empty env registry) t := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact frame_coherent held rfl rfl rfl rfl
    next => simp at ok
  | initializeInbox caller => exact initialize_coherent primitive held ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact write_start_coherent guard.2.2.2.2.1
        (unstarted_no_signals held guard.2.1) _ _ _ _ _ _
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact write_start_coherent guard.2.1 guard.2.2.2.2.1 _ _ _ _ _ _
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact frame_coherent held rfl rfl rfl rfl
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
        exact frame_coherent held rfl rfl rfl rfl
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact frame_coherent held rfl rfl rfl rfl
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact frame_coherent held rfl rfl rfl rfl
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact frame_coherent held rfl rfl rfl rfl
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact frame_coherent held rfl rfl rfl rfl
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
        exact frame_coherent held rfl rfl rfl rfl
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact frame_coherent held rfl rfl rfl rfl
    next => simp at ok
  | rollback caller trusted restored => exact rollback_coherent held ok
  | land a => exact landing_coherent genesis primitive soundness reach ok inv held frontier
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact frame_coherent held rfl rfl rfl rfl
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact frame_coherent held rfl rfl rfl rfl
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact frame_coherent held rfl rfl rfl rfl
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact frame_coherent held rfl rfl rfl rfl
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact frame_coherent held rfl rfl rfl rfl
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact frame_coherent held rfl rfl rfl rfl


 theorem empty_coherent (env : Environment) (registry : RegistryMachine.State) :
    Coherent env (empty env registry) (empty env registry) :=
  Or.inl ⟨rfl,Or.inl rfl⟩

/-- Every actual successful call, revert and node event preserves the shared chain. -/
 theorem trace_coherent {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry)
    (primitive : Primitives env) (soundness : VerifierSound env (empty env registry))
    (trace : Trace env (empty env registry) w) : Coherent env (empty env registry) w := by
  induction trace with
  | refl => exact empty_coherent _ _
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa [transact,ok] using ih
      | some t =>
        have invariant := execute_coherent genesis primitive soundness prior
          (trace_invariant genesis primitive soundness prior) ih (Journal.trace_frontier_record prior) ok
        simpa [transact,ok] using invariant
    | node after verified => exact frame_coherent ih rfl rfl rfl rfl

/-- A retained signal cannot remain above the restored execution frontier. -/
 theorem coherent_signal_bounded {env : Environment} {initial w : World}
    (held : Coherent env initial w) {signal : Signal} (present : signal ∈ w.inbox.signals) :
    signal.height ≤ w.inbox.checkpoint.height := by
  rcases held with ⟨empty,_⟩ | ⟨H,head,headers,links,named⟩
  · simp [empty] at present
  · obtain ⟨cp,member,height,hash,root⟩ := named signal present
    obtain ⟨rest,records⟩ := List.head?_eq_some_iff.mp head
    rw [← height]
    exact linked_bounds links _ rest records cp member

theorem execute_frozen {env : Environment} {w t : World} {call : Call}
    (shape : Journal.FrontierShape w) (ever : w.everLanded = true)
    (ok : execute env w call = some t) : t.start = w.start ∧ t.everLanded = true := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact And.intro rfl ever
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next guard =>
      have impossible := shape.unstarted (shape.uninitialized guard.2.1)
      simp [ever] at impossible
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next guard => have impossible := shape.unstarted guard.2.1; simp [ever] at impossible
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next guard => simp [ever] at guard
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact And.intro rfl ever
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
        exact And.intro rfl ever
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact And.intro rfl ever
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact And.intro rfl ever
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact And.intro rfl ever
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact And.intro rfl ever
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
        exact And.intro rfl ever
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact And.intro rfl ever
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact ⟨rfl,ever⟩
    next => simp at ok
  | land a =>
    obtain ⟨_,rfl⟩ := land_success ok
    exact ⟨rfl,rfl⟩
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact And.intro rfl ever
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact And.intro rfl ever
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact And.intro rfl ever
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact And.intro rfl ever
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact And.intro rfl ever
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact And.intro rfl ever


 theorem trace_append {env : Environment} {first middle last : World}
    (before : Trace env first middle) (after : Trace env middle last) : Trace env first last := by
  induction after with
  | refl => exact before
  | step prior change ih => exact .step ih change

/-- After any successful landing, every later call keeps the same start, including
rollback to S followed by a new attempt to correct it. -/
 theorem trace_start_frozen {env : Environment} {registry : RegistryMachine.State} {w t : World}
    (reach : Trace env (empty env registry) w) (ever : w.everLanded = true)
    (later : Trace env w t) : t.start = w.start ∧ t.everLanded = true := by
  induction later with
  | refl => exact ⟨rfl,ever⟩
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa [transact,ok] using ih
      | some result =>
        have frozen := execute_frozen (Journal.trace_frontier_shape (trace_append reach prior)) ih.2 ok
        exact (show (transact env previous call).start = w.start ∧
            (transact env previous call).everLanded = true from by
          simpa [transact,ok] using And.intro (frozen.1.trans ih.1) frozen.2)
    | node after validated => exact ih

 theorem set_origin_once {env : Environment} {w : World} {start : StartData}
    (written : w.start = some start) (caller height hash root : Nat) :
    setOrigin env w caller height hash root = none := by
  simp [setOrigin,written]

 theorem correction_before_any_landing {env : Environment} {w t : World}
    {caller height hash root : Nat} (ok : correctStart env w caller height hash root = some t) :
    w.everLanded = false ∧ w.inbox.signals = [] := by
  unfold correctStart at ok
  obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
  split at ok
  next guard => exact ⟨guard.2.2.1,guard.2.2.2.2.1⟩
  next => simp at ok

/-- The caller-selected restore value must be the value saved with the trusted
checkpoint; checkpoint, cursor and snapshot commit together. -/
 theorem rollback_snapshot_exact {env : Environment} {w t : World} {caller snap : Nat}
    {trusted : Checkpoint} (ok : rollback env w caller trusted snap = some t) :
    (trusted,snap) ∈ w.activeSnapshots ∧ t.inbox.checkpoint = trusted ∧
      t.inbox.head = trusted.cursor ∧ t.inbox.snapshot = snap := by
  unfold rollback at ok
  split at ok
  next guard =>
    obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨guard.2.2.2.2.2.2,rfl,rfl,rfl⟩
  next => simp at ok

 theorem landing_snapshot_saved (w : World) (a : Landing) :
    ((landed w a).inbox.checkpoint,a.input.activeCommitteeSnapshot) ∈ (landed w a).activeSnapshots :=
  List.mem_cons_self

 theorem start_snapshot_saved (w : World) (height hash root block timestamp generation : Nat) :
    let t := writeStart w height hash root block timestamp generation
    (t.inbox.checkpoint,w.inbox.snapshot) ∈ t.activeSnapshots := List.mem_singleton_self _

theorem execute_legacy_authenticated {env : Environment} {w t : World} {call : Call}
    (primitive : Primitives env)
    (held : ∀ signal ∈ w.legacySignals, LegacySignalSafe env signal)
    (ok : execute env w call = some t) :
    ∀ signal ∈ t.legacySignals, LegacySignalSafe env signal := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact held
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next =>
      split at ok
      next =>
        split at ok
        next => cases Option.some.inj ok; exact held
        next => simp at ok
      next => cases Option.some.inj ok; exact held
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next => cases Option.some.inj ok; exact held
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next => cases Option.some.inj ok; exact held
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact held
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
        exact held
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact held
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact held
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact held
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact held
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
        exact held
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact held
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact held
    next => simp at ok
  | land a =>
    obtain ⟨_,rfl⟩ := land_success ok
    exact held
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      intro signal mem
      rcases List.mem_append.mp mem with old | fresh
      · exact held signal old
      · have same : signal = ⟨header.height,header.elHash,header.stateRoot⟩ := by simpa using fresh
        subst signal
        obtain ⟨auth,bound,preFork⟩ := primitive.unzen proposal header proof guard.2.1
        exact ⟨header,auth,bound,preFork,rfl,rfl,rfl⟩
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact held
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact held
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact held
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact held
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact held


/-- Legacy SignalService checkpoints remain explicitly authenticated even though
Etna's retained parent chain starts only at the final Unzen checkpoint. -/
 theorem trace_legacy_authenticated {env : Environment} {registry : RegistryMachine.State} {w : World}
    (primitive : Primitives env) (trace : Trace env (empty env registry) w) :
    ∀ signal ∈ w.legacySignals, LegacySignalSafe env signal := by
  induction trace with
  | refl => simp [empty]
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa [transact,ok] using ih
      | some t => simpa [transact,ok] using execute_legacy_authenticated primitive ih ok
    | node after verified => exact ih

theorem execute_snapshot_source {env : Environment} {w t : World} {call : Call}
    (ok : execute env w call = some t) : ∀ pair ∈ t.activeSnapshots,
    pair ∈ w.activeSnapshots ∨ writesCheckpoint call = true ∧
      pair = (t.inbox.checkpoint,t.inbox.snapshot) := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact fun pair mem => Or.inl mem
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next =>
      split at ok
      next =>
        split at ok
        next =>
          cases Option.some.inj ok
          intro pair mem
          exact Or.inr ⟨rfl,by simpa [writeStart] using mem⟩
        next => simp at ok
      next => cases Option.some.inj ok; exact fun pair mem => Or.inl mem
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next =>
      cases Option.some.inj ok
      intro pair mem
      exact Or.inr ⟨rfl,by simpa [writeStart] using mem⟩
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next =>
      cases Option.some.inj ok
      intro pair mem
      exact Or.inr ⟨rfl,by simpa [writeStart] using mem⟩
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact fun pair mem => Or.inl mem
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
        exact fun pair mem => Or.inl mem
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact fun pair mem => Or.inl mem
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact fun pair mem => Or.inl mem
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact fun pair mem => Or.inl mem
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact fun pair mem => Or.inl mem
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
        exact fun pair mem => Or.inl mem
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact fun pair mem => Or.inl mem
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact fun pair mem => Or.inl (List.mem_filter.mp mem).1
    next => simp at ok
  | land a =>
    obtain ⟨_,rfl⟩ := land_success ok
    intro pair mem
    rcases List.mem_cons.mp mem with fresh | old
    · exact Or.inr ⟨rfl,fresh⟩
    · exact Or.inl old
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact fun pair mem => Or.inl mem
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact fun pair mem => Or.inl mem
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact fun pair mem => Or.inl mem
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact fun pair mem => Or.inl mem
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact fun pair mem => Or.inl mem
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact fun pair mem => Or.inl mem


/-- Every retained rollback snapshot originated in a real checkpoint-writing call. -/
 theorem trace_snapshot_provenance {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Trace env (empty env registry) w) :
    ∀ pair ∈ w.activeSnapshots, SnapshotSource env (empty env registry) pair.1 pair.2 := by
  induction trace with
  | refl => simp [empty]
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa [transact,ok] using ih
      | some result =>
        change ∀ pair ∈ (transact env previous call).activeSnapshots, _
        simp only [transact,ok,Option.getD_some]
        intro pair mem
        rcases execute_snapshot_source ok pair mem with old | ⟨writer,fresh⟩
        · exact ih pair old
        · refine ⟨previous,call,result,prior,ok,writer,?_,?_⟩
          · exact (congrArg Prod.fst fresh).symm
          · exact (congrArg Prod.snd fresh).symm
    | node after verified => exact ih

 theorem rollback_snapshot_provenance {env : Environment} {registry : RegistryMachine.State}
    {w t : World} {caller snap : Nat} {trusted : Checkpoint}
    (trace : Trace env (empty env registry) w) (ok : rollback env w caller trusted snap = some t) :
    SnapshotSource env (empty env registry) trusted snap ∧
      t.inbox.checkpoint = trusted ∧ t.inbox.head = trusted.cursor ∧ t.inbox.snapshot = snap := by
  obtain ⟨saved,checkpoint,head,snapshot⟩ := rollback_snapshot_exact ok
  exact ⟨trace_snapshot_provenance trace _ saved,checkpoint,head,snapshot⟩

end Etna.Design.Current.Protocol.Custody
