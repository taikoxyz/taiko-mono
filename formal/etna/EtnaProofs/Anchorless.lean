import EtnaModel.Anchorless

namespace Etna.Design.Anchorless

private theorem get_entry {code : Bool} {ring : Ring} {timestamp root : Nat}
    (ok : beaconGet code ring timestamp = some root) :
    code = true ∧ timestamp ≠ 0 ∧ ∃ entry,
      ring (timestamp % 8191) = some entry ∧ entry.timestamp = timestamp ∧ entry.root = root := by
  unfold beaconGet at ok
  split at ok
  next guard =>
    have parts : code = true ∧ timestamp ≠ 0 := by simpa only [Bool.and_eq_true,decide_eq_true_eq] using guard
    refine ⟨parts.1,parts.2,?_⟩
    split at ok
    next entry present =>
      split at ok
      next same => exact ⟨entry,present,same,Option.some.inj ok⟩
      next => cases ok
    next => cases ok
  next => cases ok

/-- Canonical provenance and future bounds are derived from accepted header/checkpoint
writes, rather than a root-authenticated flag or an invented source getter time guard. -/
private theorem root_invariants {l1 : Nat → Nat} {fork : Nat} {s : RootState}
    (history : RootRun l1 fork s) :
    (∀ number root, s.checkpoints number = some root → root = l1 number) ∧
    (∀ slot entry, s.ring slot = some entry → entry.timestamp ≤ s.clock ∧
      (fork ≤ entry.timestamp → ∃ number, entry.root = l1 number)) := by
  induction history with
  | genesis =>
    constructor
    · intro n r h; cases h
    · intro n r h; cases h
  | @step s t prior event ih =>
    cases event with
    | legacyStorage => exact ih
    | deploy => exact ih
    | checkpoint number root before range binding =>
      refine ⟨?_,ih.2⟩
      intro n r present
      change (if n = number then some root else s.checkpoints n) = some r at present
      split at present
      next same => cases present; simpa only [same] using binding
      next => exact ih.1 n r present
    | block h later valid =>
      refine ⟨ih.1,?_⟩
      intro slot entry present
      change write s.code s.ring h slot = some entry at present
      unfold write at present
      split at present
      next code =>
        dsimp only at present
        split at present
        next same =>
          cases present
          refine ⟨Nat.le_refl _,?_⟩
          intro post
          change fork ≤ h.timestamp at post
          have bound : ¬ h.timestamp < fork := by omega
          have binding : h.root ≠ 0 ∧ h.extraBytes = 13 ∧ h.encodedNumber = h.anchorNumber ∧ h.root = l1 h.anchorNumber := by simpa only [ValidHeader,bound,↓reduceIte] using valid
          exact ⟨h.anchorNumber,binding.2.2.2⟩
        next =>
          have old := ih.2 slot entry present
          exact ⟨Nat.le_trans old.1 (Nat.le_of_lt later),old.2⟩
      next =>
        have old := ih.2 slot entry present
        exact ⟨Nat.le_trans old.1 (Nat.le_of_lt later),old.2⟩

/-- Canonical validation includes both EL shape and the independently decoded L1 binding. -/
theorem postfork_header {l1 : Nat → Nat} {fork : Nat} {h : Header}
    (valid : ValidHeader l1 fork h) (post : fork ≤ h.timestamp) :
    h.root ≠ 0 ∧ h.extraBytes = 13 ∧ h.encodedNumber = h.anchorNumber ∧ h.root = l1 h.anchorNumber := by
  simpa only [ValidHeader,Nat.not_lt.mpr post,↓reduceIte] using valid

theorem prefork_header {l1 : Nat → Nat} {fork : Nat} {h : Header}
    (valid : ValidHeader l1 fork h) (pre : h.timestamp < fork) : h.root = 0 ∧ h.extraBytes = 7 := by
  simpa only [ValidHeader,pre,↓reduceIte] using valid

/-- No valid postfork event writes a current checkpoint; root resolution has switched to
EIP timestamps, and legacy bytes remain outside the service's current namespace. -/
theorem postfork_checkpoints_frozen {l1 : Nat → Nat} {fork : Nat} {s t : RootState}
    (event : RootStep l1 fork s t) (post : fork ≤ s.clock) : t.checkpoints = s.checkpoints := by
  cases event with
  | legacyStorage => rfl
  | deploy => rfl
  | block => rfl
  | checkpoint number root before range binding => omega

/-- Verifier time determines exactly one interpretation, irrespective of any numeric
overlap between L1 block numbers and L2 timestamps. -/
theorem resolver_modes (fork : Nat) (s : RootState) (id : Nat) :
    resolve fork s true id =
      (if s.clock < fork then do
        let root ← if id < limit48 then s.checkpoints id else none
        if root ≠ 0 then some root else none
      else do
        let root ← if fork ≤ id then beaconGet s.code s.ring id else none
        if root ≠ 0 then some root else none) := by
  unfold resolve
  simp only [Bool.not_true,Bool.false_eq_true,↓reduceIte]

private theorem resolved_source {fork : Nat} {s : RootState} {id root : Nat}
    (accepted : resolve fork s true id = some root) :
    root ≠ 0 ∧ ((s.clock < fork ∧ id < limit48 ∧ s.checkpoints id = some root) ∨
      (fork ≤ s.clock ∧ fork ≤ id ∧ beaconGet s.code s.ring id = some root)) := by
  rw [resolver_modes] at accepted
  split at accepted
  next pre =>
    split at accepted
    next range =>
      cases present : s.checkpoints id with
      | none => simp [present] at accepted
      | some value =>
        simp only [present] at accepted
        change (if value ≠ 0 then some value else none) = some root at accepted
        split at accepted
        next nonzero => cases accepted; exact ⟨nonzero,Or.inl ⟨pre,range,rfl⟩⟩
        next => cases accepted
    next => cases accepted
  next post =>
    split at accepted
    next range =>
      cases present : beaconGet s.code s.ring id with
      | none => simp [present] at accepted
      | some value =>
        simp only [present] at accepted
        change (if value ≠ 0 then some value else none) = some root at accepted
        split at accepted
        next nonzero => cases accepted; exact ⟨nonzero,Or.inr ⟨by omega,range,rfl⟩⟩
        next => cases accepted
    next => cases accepted

/-- Every resolved nonzero root comes from its actual authenticated source: a numbered
current checkpoint before the fork, or a valid postfork canonical header write afterwards. -/
theorem resolved_canonical {l1 : Nat → Nat} {fork : Nat} {s : RootState} {id root : Nat}
    (history : RootRun l1 fork s) (accepted : resolve fork s true id = some root) :
    ∃ number, root = l1 number := by
  rcases (resolved_source accepted).2 with pre | post
  · exact ⟨id,(root_invariants history).1 id root pre.2.2⟩
  · obtain ⟨_,_,entry,present,time,binding⟩ := get_entry post.2.2
    have source := (root_invariants history).2 _ entry present
    rw [time,binding] at source
    exact source.2 post.2.1

/-- Exact source selection is stronger than existence of a canonical root: the returned
root is the numbered checkpoint before the fork or the exact timestamp pair afterwards. -/
theorem resolved_exact_source {l1 : Nat → Nat} {fork : Nat} {s : RootState} {id root : Nat}
    (history : RootRun l1 fork s) (accepted : resolve fork s true id = some root) :
    root ≠ 0 ∧ ((s.clock < fork ∧ id < limit48 ∧ s.checkpoints id = some root ∧ root = l1 id) ∨
      (fork ≤ s.clock ∧ fork ≤ id ∧ s.ring (id % 8191) = some ⟨id,root⟩ ∧
        ∃ number, root = l1 number)) := by
  have source := resolved_source accepted
  refine ⟨source.1,?_⟩
  rcases source.2 with pre | post
  · exact Or.inl ⟨pre.1,pre.2.1,pre.2.2,(root_invariants history).1 id root pre.2.2⟩
  · obtain ⟨_,_,entry,present,time,binding⟩ := get_entry post.2.2
    have same : entry = ⟨id,root⟩ := by cases entry; simp_all
    rw [same] at present
    exact Or.inr ⟨post.1,post.2.1,present,resolved_canonical history accepted⟩

/-- There is no source getter future check; monotone accepted writes derive this bound. -/
theorem postfork_timestamp_bound {l1 : Nat → Nat} {fork : Nat} {s : RootState} {id root : Nat}
    (history : RootRun l1 fork s) (post : fork ≤ s.clock)
    (accepted : resolve fork s true id = some root) : fork ≤ id ∧ id ≤ s.clock := by
  rcases (resolved_source accepted).2 with pre | source
  · omega
  · obtain ⟨_,_,entry,present,time,_⟩ := get_entry source.2.2
    exact ⟨source.2.1,time ▸ ((root_invariants history).2 _ entry present).1⟩

theorem missing_provider (fork : Nat) (s : RootState) (id : Nat) :
    resolve fork s false id = none := rfl

theorem missing_code (fork : Nat) (s : RootState) (id : Nat)
    (post : fork ≤ s.clock) (absent : s.code = false) : resolve fork s true id = none := by
  rw [resolver_modes]
  simp [Nat.not_lt.mpr post,beaconGet,absent]

theorem zero_root_rejected (fork : Nat) (s : RootState) (id : Nat) :
    resolve fork s true id ≠ some 0 := by
  intro accepted
  exact (resolved_source accepted).1 rfl

/-- Actual same-slot overwrite invalidates the old timestamp, regardless of its old root. -/
theorem overwritten_unreadable (ring : Ring) (h : Header) (old : Nat)
    (same : old % 8191 = h.timestamp % 8191) (different : h.timestamp ≠ old) :
    beaconGet true (write true ring h) old = none := by
  simp [beaconGet,write,same,different]

/-- No fixed TTL is imposed: an untouched matching entry remains readable at any age. -/
theorem untouched_readable (ring : Ring) (h : Header) (old root : Nat)
    (present : beaconGet true ring old = some root)
    (different : old % 8191 ≠ h.timestamp % 8191) :
    beaconGet true (write true ring h) old = some root := by
  simpa only [beaconGet,write,↓reduceIte,different] using present

theorem fork_gate (fork : Nat) : anchorV4 fork fork true = false := by simp [anchorV4]

theorem postfork_anchor_closed (fork now : Nat) (ancestorsPass : Bool) (post : fork ≤ now) :
    anchorV4 fork now ancestorsPass = false := by simp [anchorV4,Nat.not_lt.mpr post]

/-- Proof root/chain/account/slot binding is checked against the resolver and immutable
deployment/request coordinates, rather than trusting the values inside the proof. -/
theorem proof_binding {fork : Nat} {s : RootState} {provider : Bool} {domain : SourceDomain}
    {verify : HopProof → Bool} {slot : Nat} {p : HopProof}
    (accepted : checkProof fork s provider domain verify slot p = true) :
    resolve fork s provider p.blockId = some p.root ∧ p.chain = domain.chain ∧
      p.account = domain.signalService ∧ p.slot = slot ∧ verify p = true := by
  simpa only [checkProof,Bool.and_eq_true,decide_eq_true_eq,and_assoc] using accepted

/-- Accepted uncached proofs establish the specified source fact under a canonical root.
L1 ancestry and cryptographic storage verification remain the explicit ideal boundaries. -/
theorem uncached_authorization {l1 : Nat → Nat} {fork : Nat} {s : RootState} {domain : SourceDomain}
    {verify : HopProof → Bool} {stored : Nat → Nat → Nat → Nat → Prop} {slot : Nat} {p : HopProof}
    (history : RootRun l1 fork s) (sound : StorageSound l1 verify stored)
    (accepted : checkProof fork s true domain verify slot p = true) :
    ∃ number, p.root = l1 number ∧ stored number domain.chain domain.signalService slot := by
  obtain ⟨resolved,chain,account,signal,verified⟩ := proof_binding accepted
  obtain ⟨number,binding⟩ := resolved_canonical history resolved
  have fact := sound p number verified binding
  rw [chain,account,signal] at fact
  exact ⟨number,binding,fact⟩

private theorem cache_roots {l1 : Nat → Nat} {fork : Nat} {domain : SourceDomain}
    {verify : HopProof → Bool} {s : RootState} {cache : Cache}
    (history : CacheRun l1 fork domain verify s cache) : RootRun l1 fork s := by
  induction history with
  | initial => exact .genesis
  | roots _ event ih => exact .step ih event
  | prove _ _ _ _ ih => exact ih

/-- Cache facts come from real prior accepted proofs; ring replacement never rewrites their
provenance. Arbitrary old flat entries are not part of this current VERSION invariant. -/
theorem cached_authorization {l1 : Nat → Nat} {fork : Nat} {domain : SourceDomain}
    {verify : HopProof → Bool} {stored : Nat → Nat → Nat → Nat → Prop}
    {s : RootState} {cache : Cache} (history : CacheRun l1 fork domain verify s cache)
    (sound : StorageSound l1 verify stored) :
    ∀ slot, cached cache slot = true → ∃ number, stored number domain.chain domain.signalService slot := by
  induction history with
  | initial flat => intro slot accepted; simp [cached] at accepted
  | roots prior event ih => exact ih
  | prove prior slot p accepted ih =>
    intro wanted hit
    simp only [cached,decide_eq_true_eq,List.mem_cons] at hit
    rcases hit with equal | old
    · subst wanted
      obtain ⟨number,_,fact⟩ := uncached_authorization (cache_roots prior) sound accepted
      exact ⟨number,fact⟩
    · exact ih wanted (by simpa [cached] using old)

/-- The current cached signal retains an actual historical acceptance receipt at its
original state and root; later expiry needs no new successful root lookup. -/
theorem cached_provenance {l1 : Nat → Nat} {fork : Nat} {domain : SourceDomain}
    {verify : HopProof → Bool} {s : RootState} {cache : Cache}
    (history : CacheRun l1 fork domain verify s cache) :
    ∀ slot, cached cache slot = true → ∃ source p,
      RootRun l1 fork source ∧ checkProof fork source true domain verify slot p = true := by
  induction history with
  | initial flat => intro slot accepted; simp [cached] at accepted
  | roots prior event ih => exact ih
  | prove prior slot p accepted ih =>
    intro wanted hit
    simp only [cached,decide_eq_true_eq,List.mem_cons] at hit
    rcases hit with equal | old
    · subst wanted
      exact ⟨_,p,cache_roots prior,accepted⟩
    · exact ih wanted (by simpa [cached] using old)

/-- Authorization never falls back to flat checkpoints, at either side of the time fork. -/
theorem flat_checkpoint_irrelevant (fork : Nat) (s : RootState) (flat : Nat → Option Nat)
    (provider : Bool) (id : Nat) :
    resolve fork { s with flatCheckpoints := flat } provider id = resolve fork s provider id := rfl

/-- Switching to VERSION discards old received authorization, not its physical bytes. -/
theorem flat_cache_unreadable (flat : List Nat) (slot : Nat) :
    cached ⟨flat,[]⟩ slot = false := by simp [cached]

theorem failed_pair_anchor (s : Installation) (signalOK : Bool) : pairedUpgrade s false signalOK = s := by
  simp [pairedUpgrade]

theorem failed_pair_signal (s : Installation) : pairedUpgrade s true false = s := by simp [pairedUpgrade]

/-- No observable intermediate proxy installation is exposed by the atomic batch. -/
theorem paired_atomic (s : Installation) (anchorOK signalOK : Bool) :
    pairedUpgrade s anchorOK signalOK = s ∨
      pairedUpgrade s anchorOK signalOK = { s with anchor := true, signal := true } := by
  unfold pairedUpgrade
  split <;> simp

private theorem installation_invariants {fork : Nat} {s : Installation} (history : InstallRun fork s) :
    s.anchor = s.signal ∧ (s.signal = true → s.identicalCalls = true ∧ s.historyCode = true ∧
      s.beaconCode = true ∧ s.dualReaders = true ∧ s.images = true) := by
  induction history with
  | initial => exact ⟨rfl,by intro impossible; cases impossible⟩
  | @step s t prior event ih =>
    cases event with
    | advance => exact ih
    | engines => exact ⟨ih.1,fun active => ⟨rfl,(ih.2 active).2⟩⟩
    | history ready => exact ⟨ih.1,fun active => ⟨(ih.2 active).1,rfl,(ih.2 active).2.2⟩⟩
    | beacon ready => exact ⟨ih.1,fun active => ⟨(ih.2 active).1,(ih.2 active).2.1,rfl,(ih.2 active).2.2.2⟩⟩
    | readers ready => exact ⟨ih.1,fun active => ⟨(ih.2 active).1,(ih.2 active).2.1,(ih.2 active).2.2.1,rfl,(ih.2 active).2.2.2.2⟩⟩
    | images ready => exact ⟨ih.1,fun active => ⟨(ih.2 active).1,(ih.2 active).2.1,(ih.2 active).2.2.1,(ih.2 active).2.2.2.1,rfl⟩⟩
    | pair anchorOK signalOK =>
      unfold pairedUpgrade
      split
      next guard =>
        simp only [Bool.and_eq_true] at guard
        have guard := guard.1
        exact ⟨rfl,fun _ => ⟨guard.1.1.1.1.1.1,guard.1.1.1.1.1.2,guard.1.1.1.1.2,guard.1.1.1.2,guard.1.1.2⟩⟩
      next => exact ih
    | rollback accepted =>
      unfold rollbackFlat at accepted
      split at accepted
      next => cases accepted
      next => cases accepted; exact ih

/-- Each deployment stage depends on its predecessor even before proxies are upgraded.
The `identicalCalls` completion event is the explicit ideal EL integration boundary. -/
theorem deployment_order {fork : Nat} {s : Installation} (history : InstallRun fork s) :
    (s.historyCode = true → s.identicalCalls = true) ∧
    (s.beaconCode = true → s.historyCode = true) ∧
    (s.dualReaders = true → s.beaconCode = true) ∧
    (s.images = true → s.dualReaders = true) := by
  induction history with
  | initial => exact ⟨id,id,id,id⟩
  | @step s t prior event ih =>
    cases event with
    | advance => exact ih
    | engines => exact ⟨fun _ => rfl,ih.2⟩
    | history ready => exact ⟨fun _ => ready,fun _ => rfl,ih.2.2⟩
    | beacon ready => exact ⟨ih.1,fun _ => ready,fun _ => rfl,ih.2.2.2⟩
    | readers ready => exact ⟨ih.1,ih.2.1,fun _ => ready,fun _ => rfl⟩
    | images ready => exact ⟨ih.1,ih.2.1,ih.2.2.1,fun _ => ready⟩
    | pair anchorOK signalOK => unfold pairedUpgrade; split <;> exact ih
    | rollback accepted =>
      unfold rollbackFlat at accepted
      split at accepted
      next => cases accepted
      next => cases accepted; exact ih

/-- Every reachable upgraded service has its provider and prerequisite images installed;
failed attempts and prohibited flat rollbacks cannot create a partially upgraded state. -/
theorem migration_safety {fork : Nat} {s : Installation} (history : InstallRun fork s) (active : s.signal = true) :
    s.anchor = true ∧ s.identicalCalls = true ∧ s.historyCode = true ∧ s.beaconCode = true ∧
      s.dualReaders = true ∧ s.images = true := by
  have invariant := installation_invariants history
  exact ⟨invariant.1.trans active,invariant.2 active⟩

theorem rollback_rejected (s : Installation) (active : s.signal = true) : rollbackFlat s = none := by
  simp [rollbackFlat,active]

/-- Every lifecycle event preserves the Anchor fork time fixed at initialization. -/
theorem installation_fork {fork : Nat} {s : Installation} (history : InstallRun fork s) :
    s.forkTime = fork := by
  induction history with
  | initial => rfl
  | step prior event ih =>
    cases event with
    | advance => exact ih
    | engines => exact ih
    | history => exact ih
    | beacon => exact ih
    | readers => exact ih
    | images => exact ih
    | pair anchorOK signalOK => unfold pairedUpgrade; split <;> exact ih
    | rollback accepted =>
      unfold rollbackFlat at accepted
      split at accepted
      next => cases accepted
      next => cases accepted; exact ih

/-- The atomic proxy batch can change installation only before the stored fork time. -/
theorem upgrade_before_fork (s : Installation) (anchorOK signalOK : Bool)
    (changed : pairedUpgrade s anchorOK signalOK ≠ s) : s.clock < s.forkTime := by
  unfold pairedUpgrade at changed
  split at changed
  next guard =>
    simp only [Bool.and_eq_true,decide_eq_true_eq] at guard
    exact guard.2
  next => exact False.elim (changed rfl)

/-- Client and stored Anchor fork times agree at successful readiness, after reaching
that timestamp. Actual scheduling and subsequent rescheduling are outside this lifecycle. -/
theorem activation_consistent {s : Installation} {clientFork : Nat}
    (accepted : activate s clientFork = true) :
    s.forkTime = clientFork ∧ s.forkTime ≤ s.clock ∧ s.anchor = true ∧ s.signal = true ∧
      s.identicalCalls = true ∧ s.historyCode = true ∧ s.beaconCode = true ∧ s.dualReaders = true ∧ s.images = true := by
  simp only [activate,Bool.and_eq_true,decide_eq_true_eq] at accepted
  exact ⟨accepted.1.2,accepted.2,accepted.1.1.1.2,accepted.1.1.2,accepted.1.1.1.1.1.1.1.1,
    accepted.1.1.1.1.1.1.1.2,accepted.1.1.1.1.1.1.2,accepted.1.1.1.1.1.2,accepted.1.1.1.1.2⟩

/-- Compose reachable migration state, raw canonical root/cache history and ideal storage
soundness. Both empty cached proofs and fresh proofs authorize only a real source fact. -/
theorem authorization_sound {installation : Installation} {l1 : Nat → Nat} {fork : Nat}
    {s : RootState} {cache : Cache} {domain : SourceDomain} {verify : HopProof → Bool}
    {stored : Nat → Nat → Nat → Nat → Prop} {slot : Nat} {proof : Option HopProof}
    (migration : InstallRun fork installation) (history : CacheRun l1 fork domain verify s cache)
    (sound : StorageSound l1 verify stored)
    (accepted : authorize installation s cache domain verify slot proof = true) :
    ∃ number, stored number domain.chain domain.signalService slot := by
  simp only [authorize,Bool.and_eq_true] at accepted
  cases proof with
  | none => exact cached_authorization history sound slot accepted.2
  | some p =>
    have provider := (migration_safety migration accepted.1).1
    have checked := accepted.2
    rw [provider,installation_fork migration] at checked
    obtain ⟨number,_,fact⟩ := uncached_authorization (cache_roots history) sound checked
    exact ⟨number,fact⟩

/-- Exact source chain/account and app/signal-derived slot binding. These coordinates
are derived by the service's fixed adapter, not supplied as a raw slot by its caller. -/
theorem service_proof_binding {config : ServiceConfig} {installation : Installation} {s : RootState}
    {cache : Cache} {verify : HopProof → Bool} {request : ServiceRequest} {p : HopProof}
    (accepted : serviceAuthorize config installation s cache verify request (some p) = true) :
    request.sourceChain = config.domain.chain ∧ p.chain = request.sourceChain ∧
      p.account = config.domain.signalService ∧
      p.slot = config.slotOf request.sourceChain request.app request.signal := by
  simp only [serviceAuthorize,authorize,Bool.and_eq_true,decide_eq_true_eq] at accepted
  have bound := proof_binding accepted.2.2
  exact ⟨accepted.1,bound.2.1.trans accepted.1.symm,bound.2.2.1,bound.2.2.2.1⟩

/-- Projection retains the actual derived-slot proof requests and root writes; the
installed provider and its immutable fork parameter supply the raw checker call. -/
private theorem service_run_cache {config : ServiceConfig} {l1 : Nat → Nat} {fork : Nat}
    {verify : HopProof → Bool} {s : RootState} {cache : Cache}
    (history : ServiceRun config l1 fork verify s cache) : CacheRun l1 fork config.domain verify s cache := by
  induction history with
  | initial flat => exact .initial flat
  | roots prior event ih => exact .roots ih event
  | prove prior installation migration time request p accepted ih =>
    simp only [serviceAuthorize,authorize,Bool.and_eq_true,decide_eq_true_eq] at accepted
    have checked := accepted.2.2
    rw [(migration_safety migration accepted.2.1).1,installation_fork migration] at checked
    exact .prove ih (requestSlot config request) p checked

/-- Service-level authorization proves the requested source chain/app/signal's derived
storage fact. Collision separation is not silently assumed for arbitrary finite hashes. -/
theorem service_authorization_sound {config : ServiceConfig} {installation : Installation}
    {l1 : Nat → Nat} {fork : Nat} {s : RootState} {cache : Cache} {verify : HopProof → Bool}
    {stored : Nat → Nat → Nat → Nat → Prop} {request : ServiceRequest} {proof : Option HopProof}
    (migration : InstallRun fork installation) (history : ServiceRun config l1 fork verify s cache)
    (sound : StorageSound l1 verify stored)
    (accepted : serviceAuthorize config installation s cache verify request proof = true) :
    request.sourceChain = config.domain.chain ∧ ∃ number,
      stored number request.sourceChain config.domain.signalService
        (config.slotOf request.sourceChain request.app request.signal) := by
  simp only [serviceAuthorize,Bool.and_eq_true,decide_eq_true_eq] at accepted
  obtain ⟨number,fact⟩ := authorization_sound migration (service_run_cache history) sound accepted.2
  refine ⟨accepted.1,number,?_⟩
  simpa only [requestSlot,accepted.1] using fact

/-- An old proof cannot be reused for another request when their fixed derived slots
are distinct. App/signal inequality alone is insufficient without encoding separation. -/
theorem service_proof_isolation (config : ServiceConfig) (installation : Installation) (s : RootState)
    (cache : Cache) (verify : HopProof → Bool) (old request : ServiceRequest) (p : HopProof)
    (binding : p.slot = config.slotOf old.sourceChain old.app old.signal)
    (separate : config.slotOf old.sourceChain old.app old.signal ≠
      config.slotOf request.sourceChain request.app request.signal) :
    serviceAuthorize config installation s cache verify request (some p) = false := by
  cases outcome : serviceAuthorize config installation s cache verify request (some p) with
  | false => rfl
  | true => exact False.elim (separate (binding.symm.trans (service_proof_binding outcome).2.2.2))

/-- Adding one request's receipt cannot authorize a previously uncached different slot.
An independently proven target receipt is deliberately excluded by `absent`. -/
theorem service_cache_isolation (config : ServiceConfig) (installation : Installation) (s : RootState)
    (cache : Cache) (verify : HopProof → Bool) (old request : ServiceRequest)
    (absent : cached cache (config.slotOf request.sourceChain request.app request.signal) = false)
    (separate : config.slotOf old.sourceChain old.app old.signal ≠
      config.slotOf request.sourceChain request.app request.signal) :
    serviceAuthorize config installation s
      { cache with current := requestSlot config old :: cache.current } verify request none = false := by
  have missing : config.slotOf request.sourceChain request.app request.signal ∉ cache.current := by
    simpa only [cached,decide_eq_false_iff_not] using absent
  simp [serviceAuthorize,authorize,cached,requestSlot,Ne.symm separate,missing]

end Etna.Design.Anchorless
