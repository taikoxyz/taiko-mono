import EtnaModel.UpgradeBoundary
import EtnaProofs.Signer

/-! Conditional decoded-policy guarantees only; no production activation is constructed. -/
namespace Etna.Design.UpgradeBoundary
open SigningBridge

theorem disabled_prepare (s : System) (p : Plan) : prepare none s p = s := rfl

theorem disabled_activate (s : System) (persisted : Bool) : activate none s persisted = s := by
  simp [activate]

theorem failed_switch_atomic (authority : Option Authority) (s : System) : activate authority s false = s := by
  cases authority <;> cases h : s.staged <;> simp [activate,h]

theorem stopped_plan_fixed (authority : Option Authority) (s : System) (p old : Plan)
    (stopped : s.staged = some old) : prepare authority s p = s := by
  cases authority <;> simp [prepare,stopped]

theorem registration_inert (s : System) (v : Version) :
    (retainMaterial s v).world = s.world ∧ (retainMaterial s v).schedule = s.schedule ∧
    (retainMaterial s v).staged = s.staged ∧ (retainMaterial s v).node = s.node := ⟨rfl,rfl,rfl,rfl⟩

theorem prepare_checked (auth : Authority) (s : System) (p : Plan)
    (changed : prepare (some auth) s p ≠ s) :
    s.staged = none ∧ auth.plan p = true ∧ planFits s p = true ∧
    prepare (some auth) s p = { s with staged := some p } := by
  simp only [prepare] at changed ⊢
  split at changed
  · rename_i h
    simp only [Bool.and_eq_true, Option.isNone_iff_eq_none] at h
    exact ⟨h.1.1,h.1.2,h.2,ite_eq_left (by simpa using h)⟩
  · exact False.elim (changed rfl)

theorem activation_cases (authority : Option Authority) (s : System) (persisted : Bool) :
    activate authority s persisted = s ∨ ∃ auth p, authority = some auth ∧ s.staged = some p ∧
      readyToSwitch auth s p = true ∧ activate authority s persisted = applySwitch s p := by
  cases authority with
  | none => exact Or.inl (disabled_activate s persisted)
  | some auth =>
    cases h : s.staged with
    | none => simp [activate,h]
    | some p =>
      by_cases ok : (persisted && readyToSwitch auth s p) = true
      · exact Or.inr ⟨auth,p,rfl,rfl,by simpa only [Bool.and_eq_true] using (show persisted = true ∧ readyToSwitch auth s p = true by simpa using ok).2,by simp [activate,h,ok]⟩
      · exact Or.inl (by simp [activate,h,ok])

theorem switch_prerequisites (auth : Authority) (s : System) (p : Plan)
    (ready : readyToSwitch auth s p = true) :
    auth.plan p = true ∧ planFits s p = true ∧
    auth.checkpoint s.world.inbox.domain s.world.inbox.checkpoint = true ∧
    s.world.inbox.checkpoint.height = p.height ∧ ∀ w ∈ s.jobs, w.status ≠ .pending := by
  simpa [readyToSwitch,List.all_eq_true,and_assoc] using ready

theorem plan_coordinates (s : System) (p : Plan) (fits : planFits s p = true) :
    p.domain = s.world.inbox.domain ∧ p.generation = s.world.inbox.generation ∧
    s.node.signer.domain = p.domain ∧ s.node.signer.activeGeneration = p.generation ∧
    p.previous = s.schedule.versionAt (p.height+1) ∧ p.previous = s.schedule.versionAt p.height ∧ p.previous.grid = s.world.inbox.gridK ∧
    p.previous.config = s.world.inbox.committeeConfig ∧ p.next.config = s.world.inbox.committeeConfig ∧
    GridRange p.previous.grid ∧ GridRange p.next.grid ∧ p.next.images ≠ [] ∧
    p.height % p.previous.grid = 0 ∧ p.height % p.next.grid = 0 ∧
    p.next.grid ≤ s.world.inbox.configuration.unsettled ∧
    s.world.inbox.configuration.unsettled % p.next.grid = 0 ∧ p.next.grid ≤ s.world.inbox.maxBatchBlocks ∧
    s.world.inbox.checkpoint.height ≤ p.height ∧ s.produced ≤ p.height := by
  simp only [planFits,Bool.and_eq_true,decide_eq_true_eq] at fits
  exact fits.1.1

theorem plan_no_prior_production (s : System) (p : Plan) (fits : planFits s p = true) :
    s.produced ≤ p.height ∧ ∀ r ∈ s.node.signer.log,
      r.generation = s.world.inbox.generation → r.position.height ≤ p.height := by
  have coords := plan_coordinates s p fits
  simp only [planFits,Bool.and_eq_true,decide_eq_true_eq] at fits
  have logs := fits.2
  simp only [logBelow,List.all_eq_true,decide_eq_true_eq] at logs
  refine ⟨coords.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2,?_⟩
  intro r mem generation
  exact (logs r mem).resolve_left (by simp [generation])

theorem historical_rules (s : Schedule) (height h : Nat) (v : Version) (old : h ≤ height) :
    (extendSchedule s height v).versionAt h = s.versionAt h := by simp [extendSchedule,old]

theorem new_rules (s : Schedule) (height h : Nat) (v : Version) (fresh : height < h) :
    (extendSchedule s height v).versionAt h = v := by simp [extendSchedule,Nat.not_le.mpr fresh]

theorem boundary_retained (s : Schedule) (height : Nat) (v : Version) (b : Nat) :
    b ∈ (extendSchedule s height v).boundaries ↔ b ∈ s.boundaries ∨ b = height := by
  simp [extendSchedule]

theorem batch_respects_boundaries (s : System) (j : Job) (ok : batchAllowed s j = true)
    (b : Nat) (recorded : b ∈ s.schedule.boundaries) : j.last ≤ b ∨ b ≤ j.first := by
  simp only [batchAllowed,Bool.and_eq_true] at ok
  have h := ok.1.1.2
  simp only [noCrossing,List.all_eq_true,decide_eq_true_eq] at h
  exact h b recorded

theorem batch_image_and_rules (s : System) (j : Job) (ok : batchAllowed s j = true) :
    j.deployment = s.world.inbox.domain ∧ j.generation = s.world.inbox.generation ∧
    j.first < j.last ∧ j.version = s.schedule.versionAt (j.first+1) ∧
    j.version = s.schedule.versionAt j.last ∧ j.version.config = s.world.inbox.committeeConfig ∧
    j.image ∈ j.version.images ∧ j.first % j.version.grid = 0 ∧ j.last % j.version.grid = 0 := by
  simp only [batchAllowed,Bool.and_eq_true,decide_eq_true_eq] at ok
  exact ok.1.1.1

theorem batch_uniform_rules (s : System) (j : Job) (ok : batchAllowed s j = true)
    (h : Nat) (above : j.first < h) (below : h ≤ j.last) : s.schedule.versionAt h = j.version := by
  simp only [batchAllowed,Bool.and_eq_true,List.all_eq_true,decide_eq_true_eq] at ok
  apply ok.1.2 h
  exact List.mem_range'.mpr ⟨h-(j.first+1),by omega,by omega⟩

theorem old_only_image_rejected (s : System) (p : Plan) (j : Job)
    (above : p.height < j.last) (oldOnly : j.image ∉ p.next.images) :
    batchAllowed (applySwitch s p) j = false := by
  apply Bool.eq_false_iff.mpr
  intro ok
  have checks := batch_image_and_rules (applySwitch s p) j ok
  have version : j.version = p.next := checks.2.2.2.2.1.trans (new_rules s.schedule p.height j.last p.next above)
  exact oldOnly (version ▸ checks.2.2.2.2.2.2.1)

theorem switch_frame (s : System) (p : Plan) :
    (applySwitch s p).world = { s.world with inbox := { s.world.inbox with gridK := p.next.grid } } ∧
    (applySwitch s p).node = s.node ∧ (applySwitch s p).jobs = s.jobs ∧
    (applySwitch s p).material = p.next :: s.material := ⟨rfl,rfl,rfl,rfl⟩

private theorem modified_jobs (jobs : List Work) (index : Nat) (status : Status) :
    (jobs.modify index (fun w => { w with status := status })).map Work.job = jobs.map Work.job := by
  induction jobs generalizing index with
  | nil => simp
  | cons w ws ih => cases index <;> simp_all [List.modify]

theorem invalidate_identity (s : System) (index : Nat) :
    ((invalidate s index).jobs.map Work.job) = s.jobs.map Work.job := by
  exact modified_jobs s.jobs index .invalidated

theorem settle_checked (s t : System) (index : Nat) (i : LandInput) (leaves : List Leaf) (e : LandingEnv)
    (ok : settle s index i leaves e = some t) :
    ∃ w, s.jobs[index]? = some w ∧ w.status = .pending ∧ batchAllowed s w.job = true ∧
      w.job.first = i.parentHeight ∧ w.job.last = i.lastHeight ∧
      w.job.generation = e.certificate.generation ∧ w.job.version.config = e.certificate.config ∧
      w.job.statement = e.certificate ∧ s.world.l1Block ≤ e.blockNumber ∧
      ProtocolState.land s.world i leaves e = some t.world ∧
      land s.world.inbox i leaves e = some t.world.inbox ∧
      t.jobs.map Work.job = s.jobs.map Work.job := by
  unfold settle at ok
  split at ok
  · contradiction
  · rename_i w selected
    split at ok
    · rename_i checks
      cases landed : land s.world.inbox i leaves e with
      | none => simp [landed] at ok
      | some inbox =>
        simp only [landed,Option.map_some,Option.some.injEq] at ok
        subst t
        refine ⟨w,selected,checks.1,checks.2.1,checks.2.2.1,checks.2.2.2.1,
          checks.2.2.2.2.1,checks.2.2.2.2.2.1,checks.2.2.2.2.2.2.1,checks.2.2.2.2.2.2.2,by simp [ProtocolState.land,landed],rfl,?_⟩
        exact modified_jobs s.jobs index .settled
    · contradiction

theorem sign_uses_session (s : System) (encode : SignMessage → Hash) (m : SignMessage) (v : Version)
    (signature : Hash) (persisted : Bool) (t : Signer.State) (out : Hash)
    (ok : sign s encode m v signature persisted = some (t,out)) :
    signingAllowed s encode m v = true ∧ TrustState.sign s.node encode m signature persisted = some (t,out) := by
  unfold sign at ok
  split at ok
  · exact ⟨by assumption,ok⟩
  · contradiction

theorem fresh_stops_at_boundary (s : System) (encode : SignMessage → Hash) (m : SignMessage) (v : Version)
    (signature : Hash) (persisted : Bool) (t : Signer.State) (out : Hash) (p : Plan)
    (stopped : s.staged = some p) (fresh : cached s encode m = false)
    (ok : sign s encode m v signature persisted = some (t,out)) : m.height ≤ p.height := by
  have gate := (sign_uses_session s encode m v signature persisted t out ok).1
  simp only [signingAllowed,Bool.and_eq_true] at gate
  simpa [stopped,fresh] using gate.2

theorem signing_height_rules (s : System) (encode : SignMessage → Hash) (m : SignMessage) (v : Version)
    (signature : Hash) (persisted : Bool) (t : Signer.State) (out : Hash)
    (ok : sign s encode m v signature persisted = some (t,out)) :
    m.domain = s.world.inbox.domain ∧ m.generation = s.world.inbox.generation ∧
      v = s.schedule.versionAt m.height ∧ v ∈ s.material := by
  have gate := (sign_uses_session s encode m v signature persisted t out ok).1
  simp only [signingAllowed,Bool.and_eq_true,decide_eq_true_eq] at gate
  exact gate.1

theorem cached_session_retry (s : System) (encode : SignMessage → Hash) (m : SignMessage) (v : Version)
    (signature : Hash) (persisted : Bool)
    (coordinates : m.domain = s.world.inbox.domain ∧ m.generation = s.world.inbox.generation ∧
      v = s.schedule.versionAt m.height ∧ v ∈ s.material) (hit : cached s encode m = true) :
    sign s encode m v signature persisted = TrustState.sign s.node encode m signature persisted := by
  have gate : signingAllowed s encode m v = true := by
    simp only [signingAllowed,hit,Bool.true_or,Bool.and_true,decide_eq_true_eq]
    exact coordinates
  simp only [sign,gate,ite_true]

theorem signing_log_retained (s : System) (encode : SignMessage → Hash) (m : SignMessage) (v : Version)
    (signature : Hash) (persisted : Bool) (t : Signer.State) (out : Hash)
    (ok : sign s encode m v signature persisted = some (t,out)) : ∃ extra, t.log = extra ++ s.node.signer.log := by
  exact Signer.sign_never_drops_log (sign_uses_session s encode m v signature persisted t out ok).2

/-- The boundary gate supplies the original session event, with exactly its original
fresh-producer obligation. It neither manufactures trust nor opens a signer session. -/
theorem signing_session_step (s : System) (key : Hash) (encode : SignMessage → Hash)
    (m : SignMessage) (v : Version) (signature out : Hash) (persisted : Bool) (t : Signer.State)
    (ok : sign s encode m v signature persisted = some (t,out))
    (producer : t.log ≠ s.node.signer.log → TrustState.EngineRequest s.node key m) :
    TrustState.Step key encode s.node { s.node with signer := t } :=
  .signed m signature out persisted t (sign_uses_session s encode m v signature persisted t out ok).2 producer

theorem boundary_denial (s : System) (encode : SignMessage → Hash) (m : SignMessage) (v : Version)
    (signature : Hash) (persisted : Bool) (denied : signingAllowed s encode m v = false) :
    sign s encode m v signature persisted = none := by simp [sign,denied]

private theorem prepare_frame (authority : Option Authority) (s : System) (p : Plan) :
    (prepare authority s p).node = s.node ∧ (prepare authority s p).jobs = s.jobs ∧
    (prepare authority s p).world.inbox = s.world.inbox ∧
    (prepare authority s p).schedule = s.schedule ∧ (prepare authority s p).material = s.material := by
  cases authority with
  | none => exact ⟨rfl,rfl,rfl,rfl,rfl⟩
  | some auth => simp only [prepare]; split <;> exact ⟨rfl,rfl,rfl,rfl,rfl⟩

theorem trace_retains_history (authority : Option Authority) (s t : System) (trace : SwitchTrace authority s t) :
    t.node = s.node ∧ t.jobs = s.jobs ∧ t.world.inbox.records = s.world.inbox.records ∧
    t.world.inbox.checkpoint = s.world.inbox.checkpoint ∧
    (∀ v ∈ s.material, v ∈ t.material) ∧
    ∀ h, h ≤ s.world.inbox.checkpoint.height → t.schedule.versionAt h = s.schedule.versionAt h := by
  induction trace with
  | refl => exact ⟨rfl,rfl,rfl,rfl,fun _ mem => mem,fun _ _ => rfl⟩
  | stage prior p ih =>
    obtain ⟨node,jobs,inbox,schedule,material⟩ := prepare_frame authority _ p
    exact ⟨node.trans ih.1,jobs.trans ih.2.1,by rw [inbox]; exact ih.2.2.1,
      by rw [inbox]; exact ih.2.2.2.1,by rw [material]; exact ih.2.2.2.2.1,
      by rw [schedule]; exact ih.2.2.2.2.2⟩
  | switch prior persisted ih =>
    rcases activation_cases authority _ persisted with unchanged | ⟨auth,p,_,_,ready,result⟩
    · rw [unchanged]; exact ih
    · rw [result]
      have checkpoint := (switch_prerequisites auth _ p ready).2.2.2.1
      refine ⟨ih.1,ih.2.1,ih.2.2.1,ih.2.2.2.1,?_,?_⟩
      · intro v mem
        exact List.mem_cons_of_mem _ (ih.2.2.2.2.1 v mem)
      · intro h bound
        have below : h ≤ p.height := by rw [← checkpoint,ih.2.2.2.1]; exact bound
        exact (historical_rules _ p.height h p.next below).trans (ih.2.2.2.2.2 h bound)

/-- Registry and every Inbox field other than the code-version grid constant are exact.
In particular a conditional code upgrade cannot mutate deployment storage parameters. -/
theorem trace_deployment_immutables (authority : Option Authority) (s t : System)
    (trace : SwitchTrace authority s t) :
    t.world.registry = s.world.registry ∧
    { t.world.inbox with gridK := s.world.inbox.gridK } = s.world.inbox := by
  induction trace with
  | refl => exact ⟨rfl,rfl⟩
  | stage prior p ih =>
    cases authority with
    | none => exact ih
    | some auth => simp only [prepare]; split <;> exact ih
  | switch prior persisted ih =>
    rcases activation_cases authority _ persisted with unchanged | ⟨auth,p,_,_,_,result⟩
    · rw [unchanged]; exact ih
    · rw [result]; exact ih

end Etna.Design.UpgradeBoundary
