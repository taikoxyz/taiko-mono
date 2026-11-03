import EtnaModel.CurrentCustody
import EtnaProofs.CurrentSettlement
import EtnaProofs.CurrentJournal

namespace Etna.Design.Current.Protocol.Custody
set_option maxRecDepth 20000
set_option linter.unusedSimpArgs false

/-- Paths unfold into an authenticated root and only actual accepted landing edges. -/
theorem path_rooted {env : Environment} {initial : World} {h : Header}
    (path : Path env initial h) :
    ∃ root, AuthenticRoot env initial root ∧ Descends env initial root h := by
  induction path with
  | genesis _ _ _ newNetwork => exact ⟨_,Or.inl ⟨newNetwork,rfl⟩,.refl⟩
  | unzen prior accepted first switching retained authenticated starts bound fence =>
    exact ⟨_,Or.inr ⟨_,_,_,_,prior,accepted,fence,retained,authenticated,starts⟩,.refl⟩
  | landing prior accepted segment _ ih =>
    obtain ⟨root,auth,descends⟩ := ih
    exact ⟨root,auth,.landing prior accepted segment descends⟩

/-- A switching root retains the actual reachable state whose first landing
passed the fence; an arbitrary synthetic accepting world cannot authorize a root. -/
theorem authentic_root_reachable {env : Environment} {initial : World} {h : Header}
    (switching : env.core.unzenInbox ≠ 0) (auth : AuthenticRoot env initial h) :
    ∃ w t a legacy, Trace env initial w ∧ land env w a = some t ∧ FirstFence env w h ∧
      w.unzenHeader = some legacy ∧ env.unzenRoot legacy ∧ StartsAt h legacy := by
  rcases auth with ⟨newNetwork,_⟩ | reachable
  · exact (switching newNetwork).elim
  · exact reachable

theorem certified_landing {env : Environment} {initial w t : World} {a : Landing}
    (soundness : VerifierSound env initial) (reach : Trace env initial w)
    (ok : land env w a = some t) : LiveCertifies env w (statement env w a) := by
  obtain ⟨sound,cover,verify⟩ := soundness
  have accepted := (land_success ok).1.proofs
  obtain ⟨item,member,good⟩ := cover _ accepted
  obtain ⟨proof,present,rfl⟩ := List.mem_map.mp member
  have all : ∀ x ∈ a.proofs.map (fun p => (p.backend,
      decide (p.image ∈ w.images) && env.verify w.verifier p.backend p.image p.bytes (statement env w a))),
      x.2 = true := by
    simp only [proofsAccepted,dualOK,Bool.and_eq_true,List.all_eq_true] at accepted
    exact accepted.1.1.2
  have verified := all _ (List.mem_map_of_mem present)
  have bytes : env.verify w.verifier proof.backend proof.image proof.bytes (statement env w a) = true := by
    simp only [Bool.and_eq_true] at verified
    exact verified.2
  exact image_certificate_live (verify w reach a t proof ok present good bytes)

theorem bound_headers_equal {env : Environment} (primitive : Primitives env)
    {x y : Header} (hx : HashBound env x) (hy : HashBound env y) (cut : x.cut = y.cut) : x = y := by
  have fields : x.elHash = y.elHash ∧ x.cometHash = y.cometHash ∧ x.cursor = y.cursor := by
    simpa [BlockValidity.Header.cut] using cut
  obtain ⟨height,root,time,anchor⟩ := primitive.separation x y hx hy fields.1
  cases x
  cases y
  simp_all only [BlockValidity.Header.mk.injEq]

theorem suffix_terminal_bound {env : Environment} {w : World} {a : Landing}
    (segment : Suffix env w a) : HashBound env (Blocks.terminal segment.parent segment.blocks) := by
  have h := headerAt_hash_bound segment.parentHashBound segment.headerHashes segment.blocks.length
  simpa [Blocks.headerAt] using h

/-- The decoded Unzen state becomes a root only through an accepted first landing. -/
theorem pending_parent_fence {env : Environment} {initial w t : World} {a : Landing}
    (primitive : Primitives env) (_reach : Trace env initial w) (ok : land env w a = some t)
    (inv : Invariant env initial w) (segment : Suffix env w a)
    (cursorHead : w.inbox.checkpoint.cursor = w.inbox.head)
    (record : recordAt w.inbox w.inbox.checkpoint.height = some w.inbox.checkpoint)
    (pending : Pending env w w.inbox.checkpoint)
    (certificate : LiveCertifies env w (statement env w a)) :
    FirstFence env w segment.parent ∧ ∃ legacy, w.unzenHeader = some legacy ∧
      env.unzenRoot legacy ∧ StartsAt segment.parent legacy := by
  obtain ⟨switching,start,written,height,hash,comet,cursor⟩ := pending
  have first : w.inbox.checkpoint.height = (w.start.map StartData.height).getD 0 := by simpa [written] using height
  have fence := (land_success ok).1.unzen
  have fenced : w.unzen.nextProposal = w.unzen.finalizedProposal+1 ∧
      w.unzen.finalizedHash = start.hash ∧ w.unzen.checkpointExists = true ∧
      w.unzen.checkpointHash = start.hash ∧ w.unzen.checkpointRoot = start.stateRoot := by
    simpa [firstFence,written,Start.firstLanding,switching,height] using fence
  obtain ⟨legacy,retained,auth,bound,finalized,checkpoint,root,preFork⟩ := inv.unzen fenced.2.2.1
  have parentEl : segment.parent.elHash = w.inbox.checkpoint.elHash := congrArg Cut.elHash segment.parentCut
  have el : segment.parent.elHash = legacy.elHash := parentEl.trans (hash.trans (fenced.2.1.symm.trans finalized))
  obtain ⟨h,r,tm,an⟩ := primitive.separation _ _ segment.parentHashBound bound el
  have pc : segment.parent.cometHash = 0 := (congrArg Cut.cometHash segment.parentCut).trans comet
  have cur : segment.parent.cursor = 0 :=
    (congrArg Cut.cursor segment.parentCut).trans (cursorHead.symm.trans cursor)
  have implementation : env.startImplementation segment.parent.stateRoot = true := by
    obtain ⟨archive,p,bs,ready,valid,binding,hashp,hashes,implemented,_⟩ := certificate
    have inputs := congrArg StatementData.input binding
    have ph : a.input.parentHeight = p.height := congrArg LandInput.parentHeight inputs
    have pg := (land_success ok).1.parentGrid
    simp only [Start.onGrid,decide_eq_true_eq] at pg
    have ps : p.height = start.height := by
      have before := (land_success ok).1.parentBeforeFrontier
      simp only [written,Option.map_some,Option.getD_some] at pg
      omega
    have originRecord : recordAt w.inbox a.input.parentHeight = some w.inbox.checkpoint := by
      rw [ph,ps,← height]
      exact record
    have pe := congrArg StatementData.parentHash binding
    have pm := congrArg StatementData.parentCometHash binding
    have pu := congrArg StatementData.headBefore binding
    simp only [statement,originRecord,Option.getD_some,Blocks.statement] at pe pm pu
    have pcut : p.cut = segment.parent.cut := by
      rw [segment.parentCut]
      simp only [BlockValidity.Header.cut]
      rw [← pe,← pm,← pu,cursorHead]
    have same := bound_headers_equal primitive hashp segment.parentHashBound pcut
    have checked := implemented switching (by simpa [written] using ps)
    simpa [same] using checked
  refine ⟨?_,legacy,retained,auth,⟨h,el,r,tm,an,pc,cur⟩⟩
  exact ⟨start,written,height,switching,fenced.1,fenced.2.1,fenced.2.2.1,fenced.2.2.2.1,
      fenced.2.2.2.2,segment.parentHeight.trans height,el.trans (finalized.symm.trans fenced.2.1),
      r.trans (root.symm.trans fenced.2.2.2.2),implementation,tm ▸ preFork⟩

theorem pending_parent {env : Environment} {initial w t : World} {a : Landing}
    (primitive : Primitives env) (reach : Trace env initial w) (ok : land env w a = some t)
    (inv : Invariant env initial w) (segment : Suffix env w a)
    (cursorHead : w.inbox.checkpoint.cursor = w.inbox.head)
    (record : recordAt w.inbox w.inbox.checkpoint.height = some w.inbox.checkpoint)
    (pending : Pending env w w.inbox.checkpoint)
    (certificate : LiveCertifies env w (statement env w a)) : Path env initial segment.parent := by
  obtain ⟨fence,legacy,retained,auth,starts⟩ :=
    pending_parent_fence primitive reach ok inv segment cursorHead record pending certificate
  obtain ⟨switching,start,written,height,_⟩ := pending
  exact .unzen reach ok (by simpa [written] using height) switching retained auth starts
    segment.parentHashBound fence

/-- An actual accepted landing creates a full-header custody edge. -/
theorem accepted_landing_path {env : Environment} {initial w t : World} {a : Landing}
    (primitive : Primitives env) (soundness : VerifierSound env initial)
    (reach : Trace env initial w) (ok : land env w a = some t)
    (inv : Invariant env initial w) (frontier : Frontier w) :
    ∃ segment : Suffix env w a, Path env initial segment.parent ∧
      Path env initial (Blocks.terminal segment.parent segment.blocks) := by
  obtain ⟨member,record,cursor⟩ := frontier (land_success ok).1.started
  have certificate := certified_landing soundness reach ok
  obtain ⟨segment⟩ := accepted_suffix_from_certificate ok certificate record
  have parent : Path env initial segment.parent := by
    rcases inv.records _ member with certified | pending
    · obtain ⟨h,matched,bound,path⟩ := certified
      have cut : segment.parent.cut = h.cut := by rw [matched.2,cursor]; exact segment.parentCut
      have same := bound_headers_equal primitive segment.parentHashBound bound cut
      exact same ▸ path
    · exact pending_parent primitive reach ok inv segment cursor record pending certificate
  exact ⟨segment,parent,.landing reach ok segment parent⟩

theorem landing_invariant {env : Environment} {initial w t : World} {a : Landing}
    (primitive : Primitives env) (soundness : VerifierSound env initial)
    (reach : Trace env initial w) (ok : land env w a = some t)
    (inv : Invariant env initial w) (frontier : Frontier w) : Invariant env initial t := by
  obtain ⟨segment,parent,path⟩ := accepted_landing_path primitive soundness reach ok inv frontier
  have bound := suffix_terminal_bound segment
  rcases land_success ok with ⟨_,rfl⟩
  refine ⟨?_,?_,inv.unzen⟩
  · intro cp member
    rcases List.mem_cons.mp member with rfl | old
    · exact Or.inl ⟨Blocks.terminal segment.parent segment.blocks,
        ⟨segment.terminalHeight,segment.terminalCut⟩,bound,path⟩
    · rcases inv.records cp old with certified | pending
      · exact Or.inl certified
      · exact Or.inr pending
  · intro signal member
    rcases List.mem_append.mp member with old | fresh
    · exact inv.signals signal old
    · have same : signal = ⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastStateRoot⟩ := by simpa using fresh
      subst signal
      exact ⟨_,path,bound,segment.terminalHeight,congrArg Cut.elHash segment.terminalCut,segment.terminalRoot⟩

theorem frame_invariant {env : Environment} {initial w t : World}
    (inv : Invariant env initial w)
    (records : ∀ cp ∈ t.activeRecords, cp ∈ w.activeRecords)
    (signals : ∀ s ∈ t.inbox.signals, s ∈ w.inbox.signals)
    (start : t.start = w.start) (unzen : t.unzen = w.unzen)
    (header : t.unzenHeader = w.unzenHeader) : Invariant env initial t := by
  refine ⟨?_,fun s mem => inv.signals s (signals s mem),?_⟩
  · intro cp mem
    rcases inv.records cp (records cp mem) with certified | pending
    · exact Or.inl certified
    · exact Or.inr (by simpa [Pending,start] using pending)
  · simpa [unzen,header] using inv.unzen

theorem unchanged_invariant {env : Environment} {initial w t : World}
    (inv : Invariant env initial w)
    (records : t.activeRecords = w.activeRecords) (signals : t.inbox.signals = w.inbox.signals)
    (start : t.start = w.start) (unzen : t.unzen = w.unzen)
    (header : t.unzenHeader = w.unzenHeader) : Invariant env initial t :=
  frame_invariant inv (fun _ h => records ▸ h) (fun _ h => signals ▸ h) start unzen header

theorem write_start_invariant {env : Environment} {initial w : World}
    (inv : Invariant env initial w) (switching : env.core.unzenInbox ≠ 0)
    (height hash root block timestamp generation : Nat) :
    Invariant env initial (writeStart w height hash root block timestamp generation) := by
  refine ⟨?_,inv.signals,inv.unzen⟩
  intro cp member
  have same : cp = ⟨height,hash,0,0,generation,height⟩ := by simpa [writeStart] using member
  subst cp
  exact Or.inr ⟨switching,⟨height,hash,root⟩,rfl,rfl,rfl,rfl,rfl⟩

theorem initialize_invariant {env : Environment} {initial w t : World} {caller : Nat}
    (primitive : Primitives env) (reach : Trace env initial w)
    (inv : Invariant env initial w) (ok : initializeInbox env w caller = some t) :
    Invariant env initial t := by
  have accepted := ok
  unfold initializeInbox at ok
  split at ok
  next =>
    split at ok
    next newNetwork =>
      split at ok
      next genesis =>
        cases Option.some.inj ok
        have path : Path env initial env.genesisHeader := .genesis caller reach accepted newNetwork
        refine ⟨?_,?_,inv.unzen⟩
        · intro cp mem
          have same : cp = ⟨0,env.genesisHeader.elHash,0,0,0,0⟩ := by simpa [writeStart] using mem
          subst cp
          exact Or.inl ⟨env.genesisHeader,⟨genesis.1,by simp [BlockValidity.Header.cut,genesis.2.1,genesis.2.2]⟩,primitive.genesis,path⟩
        · intro signal mem
          have same : signal = ⟨0,env.genesisHeader.elHash,env.genesisHeader.stateRoot⟩ := by simpa [writeStart] using mem
          subst signal
          exact ⟨env.genesisHeader,path,primitive.genesis,genesis.1,rfl,rfl⟩
      next => simp at ok
    next =>
      cases Option.some.inj ok
      exact unchanged_invariant inv rfl rfl rfl rfl rfl
  next => simp at ok

theorem unzen_invariant {env : Environment} {initial w t : World} {proposal proof : Nat} {h : Header}
    (primitive : Primitives env) (inv : Invariant env initial w)
    (ok : unzenProve env w proposal h proof = some t) : Invariant env initial t := by
  unfold unzenProve at ok
  split at ok
  next guard =>
    cases Option.some.inj ok
    refine ⟨inv.records,inv.signals,?_⟩
    intro _
    exact ⟨h,rfl,(primitive.unzen proposal h proof guard.2.1).1,
      (primitive.unzen proposal h proof guard.2.1).2.1,rfl,rfl,rfl,
      (primitive.unzen proposal h proof guard.2.1).2.2⟩
  next => simp at ok

/-- Exhaustive successful-call induction. No public action is hidden behind a frame premise. -/
theorem execute_invariant {env : Environment} {initial w t : World} {call : Call}
    (primitive : Primitives env) (soundness : VerifierSound env initial)
    (reach : Trace env initial w) (inv : Invariant env initial w) (frontier : Frontier w)
    (ok : execute env w call = some t) : Invariant env initial t := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard => cases Option.some.inj ok; exact unchanged_invariant inv rfl rfl rfl rfl rfl
    next => simp at ok
  | initializeInbox caller => exact initialize_invariant primitive reach inv ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact write_start_invariant inv guard.2.2.2.2.1 _ _ _ _ _ _
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact write_start_invariant inv guard.2.1 _ _ _ _ _ _
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact unchanged_invariant inv rfl rfl rfl rfl rfl
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
        exact unchanged_invariant inv rfl rfl rfl rfl rfl
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact unchanged_invariant inv rfl rfl rfl rfl rfl
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact unchanged_invariant inv rfl rfl rfl rfl rfl
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact unchanged_invariant inv rfl rfl rfl rfl rfl
  | scheduleStop caller time grid =>
    change scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact unchanged_invariant inv rfl rfl rfl rfl rfl
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
        exact unchanged_invariant inv rfl rfl rfl rfl rfl
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact unchanged_invariant inv rfl rfl rfl rfl rfl
    next => simp at ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    next guard =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact frame_invariant inv (fun _ h => (List.mem_filter.mp h).1)
        (fun _ h => (List.mem_filter.mp h).1) rfl rfl rfl
    next => simp at ok
  | land a => exact landing_invariant primitive soundness reach ok inv frontier
  | unzenProve proposal header proof => exact unzen_invariant primitive inv ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact unchanged_invariant inv rfl rfl rfl rfl rfl
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact unchanged_invariant inv rfl rfl rfl rfl rfl
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact unchanged_invariant inv rfl rfl rfl rfl rfl
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact unchanged_invariant inv rfl rfl rfl rfl rfl
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact unchanged_invariant inv rfl rfl rfl rfl rfl


theorem empty_invariant (env : Environment) (registry : RegistryMachine.State) :
    Invariant env (empty env registry) (empty env registry) := by
  refine ⟨?_,?_,?_⟩ <;> simp [empty,install,bareInbox]

/-- Whole current-machine custody, including failed transactions and node events. -/
theorem trace_invariant {env : Environment} {registry : RegistryMachine.State} {w : World}
    (primitive : Primitives env) (soundness : VerifierSound env (empty env registry))
    (trace : Trace env (empty env registry) w) : Invariant env (empty env registry) w := by
  induction trace with
  | refl => exact empty_invariant _ _
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa [transact,ok] using ih
      | some t =>
        have inv := execute_invariant primitive soundness prior ih
          (Journal.trace_frontier_record prior) ok
        simpa [transact,ok] using inv
    | node after verified => exact unchanged_invariant ih rfl rfl rfl rfl rfl

/-- Every funds-authorizing Etna signal has a complete current custody path. -/
theorem funds_authorized {env : Environment} {registry : RegistryMachine.State} {w : World}
    (primitive : Primitives env) (soundness : VerifierSound env (empty env registry))
    (trace : Trace env (empty env registry) w) :
    ∀ signal ∈ w.inbox.signals, SignalSafe env (empty env registry) signal :=
  (trace_invariant primitive soundness trace).signals

/-- Every successful landing edge has the same concrete path and exact endpoint. -/
theorem landing_edge_authorized {env : Environment} {registry : RegistryMachine.State} {w t : World} {a : Landing}
    (primitive : Primitives env) (soundness : VerifierSound env (empty env registry))
    (trace : Trace env (empty env registry) w) (accepted : land env w a = some t) :
    ∃ segment : Suffix env w a, Path env (empty env registry) segment.parent ∧
      Path env (empty env registry) (Blocks.terminal segment.parent segment.blocks) :=
  accepted_landing_path primitive soundness trace accepted (trace_invariant primitive soundness trace)
    (Journal.trace_frontier_record trace)

end Etna.Design.Current.Protocol.Custody
