import EtnaModel.CurrentGovernance

namespace Etna.Design.Current.Protocol.Governance

 theorem raw_correct_refines {env : Environment} {w t : World} {caller height hash root : Nat}
    (authorized : w.everLanded = false)
    (ok : rawCorrectStart env w caller height hash root = some t) :
    correctStart env w caller height hash root = some t := by
  simpa only [rawCorrectStart,correctStart,authorized, and_true,true_and] using ok

 theorem raw_rollback_refines {env : Environment} {w t : World} {caller snapshot : Nat}
    {trusted : Checkpoint}
    (authorized : trusted ∈ w.activeRecords ∧ (trusted,snapshot) ∈ w.activeSnapshots)
    (ok : rawRollback env w caller trusted snapshot = some t) :
    rollback env w caller trusted snapshot = some t := by
  simpa only [rawRollback,rollback,authorized.1,authorized.2,true_and,and_true] using ok

 theorem execute_refines {env : Environment} {initial w t : World} {call : Call}
    (authorized : UpgradeAuthorized env initial w call) (ok : execute env w call = some t) :
    Protocol.execute env w call = some t := by
  cases call <;> first
    | exact raw_correct_refines authorized ok
    | exact raw_rollback_refines ⟨authorized.1,authorized.2.1⟩ ok
    | exact ok

/-- RECOV-8-28: the rollback duty leaves the DAO no choice of target height. Two targets that
both meet it are at the same height: everything at or below a target is trusted, and nothing
lies between a target and the first bad record above it. -/
theorem rollback_target_unique {env : Environment} {initial w : World} {one other : Checkpoint}
    {oneSnapshot otherSnapshot : Nat}
    (first : RollbackAuthorized env initial w one oneSnapshot)
    (second : RollbackAuthorized env initial w other otherSnapshot) :
    one.height = other.height := by
  have never : ∀ {low high : Checkpoint} {lowSnapshot highSnapshot : Nat},
      RollbackAuthorized env initial w low lowSnapshot →
      RollbackAuthorized env initial w high highSnapshot → ¬ low.height < high.height := by
    intro low high lowSnapshot highSnapshot lowAuthorized highAuthorized lower
    obtain ⟨_,_,_,bad,retained,_,uncertified,unpending,gap⟩ := lowAuthorized
    obtain ⟨member,_,trusted,_⟩ := highAuthorized
    by_cases covered : bad.height ≤ high.height
    · rcases trusted bad retained covered with certified | pending
      · exact uncertified certified
      · exact unpending pending
    · have between := gap high member (Nat.lt_of_not_le covered)
      omega
  rcases Nat.lt_trichotomy one.height other.height with lower | same | higher
  · exact absurd lower (never first second)
  · exact same
  · exact absurd higher (never second first)

/-- An authorized verifier-failure rollback restores the checkpoint, FI head and snapshot
written with the last trusted landing (RECOV-8-27/8-28) and keeps exactly the retained
records at or below it, each of them trusted. -/
theorem authorized_rollback_restores {env : Environment} {initial w t : World}
    {caller snapshot : Nat} {trusted : Checkpoint}
    (authorized : RollbackAuthorized env initial w trusted snapshot)
    (ok : rawRollback env w caller trusted snapshot = some t) :
    t.inbox.checkpoint = trusted ∧ t.inbox.head = trusted.cursor ∧ t.inbox.snapshot = snapshot ∧
      t.activeRecords = w.activeRecords.filter (fun r => r.height ≤ trusted.height) ∧
      ∀ cp ∈ t.activeRecords, Custody.Certified env initial cp ∨ Custody.Pending env t cp := by
  have normative := raw_rollback_refines ⟨authorized.1,authorized.2.1⟩ ok
  unfold rollback at normative
  split at normative
  next =>
    obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp normative
    refine ⟨rfl,rfl,rfl,rfl,?_⟩
    intro cp kept
    obtain ⟨retained,below⟩ := List.mem_filter.mp kept
    exact authorized.2.2.1 cp retained (of_decide_eq_true below)
  next => simp at normative

/-- The only bridge from raw DAO histories to the admissible protocol machine uses
an explicit authorization argument. Owner identity alone does not supply it. -/
theorem authorized_trace_refines {env : Environment} {first last : World}
    (history : DeployedTrace env first last) (authorization : AuthorizedUpgrades history) :
    Trace env first last := by
  induction history with
  | refl => exact .refl _
  | @call w prior call ih =>
    have duties : AuthorizedUpgrades prior ∧
        (∀ t, execute env w call = some t → UpgradeAuthorized env first w call) := by
      simpa only [AuthorizedUpgrades] using authorization
    have before := ih duties.1
    cases ok : execute env w call with
    | none => simpa [transact,ok] using before
    | some t =>
      have refined := execute_refines (duties.2 t ok) ok
      have step := Protocol.Step.call (env := env) w call
      have actual : Protocol.transact env w call = t := by
        simp [Protocol.transact,refined]
      have raw : transact env w call = t := by simp [transact,ok]
      exact raw.symm ▸ .step before (actual ▸ step)
  | node prior after event ih =>
    have duties : AuthorizedUpgrades prior := by simpa only [AuthorizedUpgrades] using authorization
    exact .step (ih duties) (.node after event)

/-- A successful recovery constructs the new generation origin from the old
checkpoint and this exact L1 call. Retained records, checkpoint and FI head survive. -/
theorem recover_origin_exact {env : Environment} {w t : World} {request : RecoveryRequest}
    (ok : recover env w request = some t) :
    t.inbox.generation = w.inbox.generation+1 ∧
    t.inbox.origin = ⟨w.inbox.checkpoint.height,w.number,env.time w.number⟩ ∧
    t.inbox.origins = w.inbox.origins ++
      [(w.inbox.generation+1,⟨w.inbox.checkpoint.height,w.number,env.time w.number⟩)] ∧
    t.inbox.checkpoint = w.inbox.checkpoint ∧ t.inbox.records = w.inbox.records ∧
    t.inbox.head = w.inbox.head := by
  unfold recover at ok
  obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
  dsimp only at ok
  cases upgrade : request.upgrade <;>
    simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,
      Bool.false_eq_true,↓reduceIte] at ok
  all_goals
    split at ok
    next =>
      obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
    next => simp at ok

/-- A start correction (START-10-5c) starts the corrected start as the next generation, with
its origin at the corrected height and this exact L1 call, appended after every earlier origin. -/
theorem correct_start_origin_exact {env : Environment} {w t : World} {caller height hash root : Nat}
    (ok : correctStart env w caller height hash root = some t) :
    t.inbox.generation = w.inbox.generation+1 ∧
    t.inbox.origin = ⟨height,w.number,env.time w.number⟩ ∧
    t.inbox.origins = w.inbox.origins ++
      [(w.inbox.generation+1,⟨height,w.number,env.time w.number⟩)] ∧
    t.start = some ⟨height,hash,root⟩ := by
  unfold correctStart at ok
  obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
  split at ok
  next => cases ok; exact ⟨rfl,rfl,rfl,rfl⟩
  next => simp at ok

/-- Ordinary governance recovery keeps the exact already-consumed FI head. -/
theorem recovery_preserves_head {env : Environment} {w t : World} {request : RecoveryRequest}
    (ok : recover env w request = some t) : t.inbox.head = w.inbox.head :=
  (recover_origin_exact ok).2.2.2.2.2

end Etna.Design.Current.Protocol.Governance
