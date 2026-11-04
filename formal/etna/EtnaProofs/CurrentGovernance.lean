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

 theorem execute_refines {env : Environment} {w t : World} {call : Call}
    (authorized : UpgradeAuthorized w call) (ok : execute env w call = some t) :
    Protocol.execute env w call = some t := by
  cases call <;> first
    | exact raw_correct_refines authorized ok
    | exact raw_rollback_refines authorized ok
    | exact ok

/-- The only bridge from raw DAO histories to the admissible protocol machine uses
an explicit authorization argument. Owner identity alone does not supply it. -/
theorem authorized_trace_refines {env : Environment} {first last : World}
    (history : DeployedTrace env first last) (authorization : AuthorizedUpgrades history) :
    Trace env first last := by
  induction history with
  | refl => exact .refl _
  | @call w prior call ih =>
    have duties : AuthorizedUpgrades prior ∧ (∀ t, execute env w call = some t → UpgradeAuthorized w call) := by
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

/-- Ordinary governance recovery keeps the exact already-consumed FI head. -/
theorem recovery_preserves_head {env : Environment} {w t : World} {request : RecoveryRequest}
    (ok : recover env w request = some t) : t.inbox.head = w.inbox.head :=
  (recover_origin_exact ok).2.2.2.2.2

end Etna.Design.Current.Protocol.Governance
