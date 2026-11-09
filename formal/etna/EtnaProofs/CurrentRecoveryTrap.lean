import EtnaModel.CurrentRecovery
import EtnaProofs.Current
import EtnaProofs.CurrentCoherentCustody

/-! The rollback-across-K-change trap (reports/recoverability.md): once a landed, started
state's frontier is off the current grid, nothing lands again until a structural recovery or a
rollback. `land` needs the frontier on the grid (6.1, BATCH-6.3-1), and a plain `recover` keeps K
and needs the same (RECOV-8.3-3a). A structural recovery that installs a K whose grid holds the
frontier exits, as SPEC 8.3 allows (`RollbackGridTrap.rollback_grid_escape`). H4's path takes
that exit off the grid: a structural recovery that installs K = 1, in a new ruleset, when ruleset
nextRules + 1 is live (`LiveRules`' second case). The reachable instance is
`RollbackGridTrap.rollback_grid_trap`, in a verifier-failure environment that meets no premise
record. Under H4's premises no rollback is authorized, so only an unauthorized rollback in a raw
`Trace` reaches an off-grid state. -/
namespace Etna.Design.Current.Protocol.Recovery

/-- Calls that never change K, the checkpoint or the rule schedule. -/
private def Plain : Call → Prop
  | .initializeInbox .. | .setOrigin .. | .correctStart .. | .scheduleRules .. | .scheduleStop ..
  | .recover .. | .rollback .. | .land .. => False
  | _ => True

private theorem execute_plain {env : Environment} {w t : World} {call : Call} (plain : Plain call)
    (ok : execute env w call = some t) :
    t.inbox.gridK = w.inbox.gridK ∧ t.inbox.checkpoint = w.inbox.checkpoint ∧ t.schedule = w.schedule := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
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
      next => cases Option.some.inj inner; exact ⟨rfl,rfl,rfl⟩
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact ⟨rfl,rfl,rfl⟩
    next => simp at inner
  | forcedETH amount => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
    next => simp at ok
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [execute] at ok
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
  | restart | openSigner _ | switchSigner _ => cases Option.some.inj ok; exact ⟨rfl,rfl,rfl⟩
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl,rfl⟩
  | initializeInbox | setOrigin | correctStart | scheduleRules | scheduleStop | recover | rollback
  | land => exact (plain : False).elim

/-- `land` needs the frontier on the grid, so an off-grid frontier rejects every batch. -/
private theorem land_off_grid {env : Environment} {u : World} {start : StartData}
    (started : u.start = some start)
    (offGrid : Start.onGrid start.height u.inbox.gridK u.inbox.checkpoint.height = false) (a : Landing) :
    land env u a = none := by
  unfold Protocol.land
  split
  next checks =>
    have frontier := checks.frontierGrid
    rw [started] at frontier
    change Start.onGrid start.height u.inbox.gridK u.inbox.checkpoint.height = true at frontier
    rw [offGrid] at frontier
    cases frontier
  next => rfl

/-- From a landed, started state whose frontier is off its grid, no call but `rollback` or a
structural recovery moves the frontier or changes K. -/
private theorem execute_trapped {env : Environment} {u t : World} {call : Call} {start : StartData}
    (initialized : u.initialized = true) (started : u.start = some start)
    (landed : u.everLanded = true)
    (offGrid : Start.onGrid start.height u.inbox.gridK u.inbox.checkpoint.height = false)
    (allowed : NoRollbackOrUpgrade u call) (ok : execute env u call = some t) :
    t.inbox.checkpoint.height = u.inbox.checkpoint.height ∧ t.inbox.gridK = u.inbox.gridK := by
  cases call with
  | initializeInbox caller =>
    change initializeInbox env u caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next guard => rw [initialized] at guard; exact Bool.noConfusion guard.2.1
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env u caller height hash root = some t at ok
    rw [Custody.set_origin_once started] at ok
    cases ok
  | correctStart caller height hash root =>
    change correctStart env u caller height hash root = some t at ok
    have unlanded := (Custody.correction_before_any_landing ok).1
    rw [landed] at unlanded
    cases unlanded
  | scheduleRules caller rule time =>
    change Protocol.scheduleRules env u caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl⟩
  | scheduleStop caller time grid =>
    change Protocol.scheduleStop env u caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl⟩
  | recover request =>
    change Protocol.recover env u request = some t at ok
    have plain : request.upgrade = none := allowed
    unfold Protocol.recover at ok
    obtain ⟨current,same,ok⟩ := Option.bind_eq_some_iff.mp ok
    rw [started] at same
    cases Option.some.inj same
    dsimp only at ok
    simp only [plain,Option.isSome_none,Option.getD_none,Bool.false_eq_true,↓reduceIte] at ok
    split at ok
    next guard =>
      obtain ⟨-,-,-,-,-,-,-,-,-,-,grid,-⟩ := guard
      rw [offGrid] at grid
      cases grid
    next => simp at ok
  | rollback caller trusted restored => exact allowed.elim
  | land a =>
    change Protocol.land env u a = some t at ok
    rw [land_off_grid started offGrid a] at ok
    cases ok
  | _ =>
    obtain ⟨grid,checkpoint,_⟩ := execute_plain (by exact trivial) ok
    exact ⟨congrArg Checkpoint.height checkpoint,grid⟩

/-- From an off-grid frontier, nothing lands until a structural recovery or a rollback: along
calls with neither, `land` (6.1, BATCH-6.3-1) and every plain recovery (RECOV-8.3-3a) stay
blocked. A structural recovery that installs a K whose grid holds the frontier exits, as SPEC 8.3
allows, so an off-grid state needs one. -/
theorem offgrid_no_landing {env : Environment} {registry : RegistryMachine.State} {w : World}
    {start : StartData} (trace : Trace env (empty env registry) w) (started : w.start = some start)
    (landed : w.everLanded = true)
    (offGrid : Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = false) :
    ∀ u, CallTrace env NoRollbackOrUpgrade w u → ∀ a, land env u a = none := by
  intro u path
  have kept : Trace env w u ∧ u.inbox.checkpoint.height = w.inbox.checkpoint.height ∧
      u.inbox.gridK = w.inbox.gridK := by
    induction path with
    | refl => exact ⟨.refl _,rfl,rfl⟩
    | @call current prior call allowed ih =>
      obtain ⟨later,height,grid⟩ := ih
      refine ⟨.step later (.call _ call),?_⟩
      have reach := Custody.trace_append trace later
      have frozen := Custody.trace_start_frozen trace landed later
      have currentStart : current.start = some start := frozen.1.trans started
      have initialized : current.initialized = true := by
        cases fresh : current.initialized with
        | true => rfl
        | false =>
          have unstarted := (Journal.trace_frontier_shape reach).uninitialized fresh
          rw [currentStart] at unstarted
          cases unstarted
      have currentOff : Start.onGrid start.height current.inbox.gridK current.inbox.checkpoint.height = false := by
        rw [height,grid]
        exact offGrid
      cases ok : execute env current call with
      | none =>
        simp only [transact,ok,Option.getD_none]
        exact ⟨height,grid⟩
      | some result =>
        simp only [transact,ok,Option.getD_some]
        have step := execute_trapped initialized currentStart frozen.2 currentOff allowed ok
        exact ⟨step.1.trans height,step.2.trans grid⟩
  intro a
  have frozen := Custody.trace_start_frozen trace landed kept.1
  apply land_off_grid (frozen.1.trans started)
  rw [kept.2.1,kept.2.2]
  exact offGrid

end Etna.Design.Current.Protocol.Recovery
