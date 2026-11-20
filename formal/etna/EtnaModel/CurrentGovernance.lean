import EtnaModel.CurrentCoherentCustody

/-! External DAO rollback and its history obligations. The raw transition erases the historical guards of the normative rollback. `everLanded`,
`activeRecords` and `activeSnapshots` instrument the actual transaction history; an owner
must establish their obligations from that history, not read them from Inbox storage. -/
namespace Etna.Design.Current.Protocol.Governance

/-- Raw rollback checks/effect without retained-lineage or checkpoint/snapshot
authorization. `inbox.records` is the physical height-indexed mapping represented by
a list; `activeRecords` instruments which records belong to the retained history.
The latter still describes which physical records this chosen upgrade clears, but
is not a runtime authorization check. Thus this effect is instrumented rather than
a fully ghost-free implementation; `raw_rollback_refines` relates it to the normative
effect only under the separately stated history duties. -/
def rawRollback (env : Environment) (w : World) (caller : Nat) (trusted : Checkpoint)
    (snapshot : Nat) : Option World :=
  if caller = env.core.owner ∧ w.initialized = true ∧ w.inbox.entered = false ∧
      trusted.height ≤ w.inbox.checkpoint.height ∧
      w.inbox.recoveryNonce+1 < limit256 then
    (RegistryMachine.execute w.registry.registry (registryView env w) w.number
      (.recheck w.registry.registry.config.inbox snapshot)).map fun registry =>
    { w with
      registry := { w.registry with registry := registry }
      inbox := { w.inbox with
        checkpoint := trusted
        head := trusted.cursor
        snapshot := snapshot
        recoveryNonce := w.inbox.recoveryNonce+1
        records := w.inbox.records.filter (fun r => r ∉ w.activeRecords ∨ r.height ≤ trusted.height)
        signals := w.inbox.signals.filter (fun s => s.height ≤ trusted.height) }
      activeRecords := w.activeRecords.filter (fun r => r.height ≤ trusted.height)
      activeSnapshots := w.activeSnapshots.filter (fun x => x.1.height ≤ trusted.height)
      activeLandings := w.activeLandings.filter (fun event => event.landing.input.lastHeight ≤ trusted.height) }
  else none

def execute (env : Environment) (w : World) : Call → Option World
  | .rollback caller trusted snapshot => rawRollback env w caller trusted snapshot
  | call => Protocol.execute env w call

def transact (env : Environment) (w : World) (call : Call) : World :=
  (execute env w call).getD w

/-- Actual chosen event history, including raw upgrades that the specification forbids. -/
inductive DeployedTrace (env : Environment) : World → World → Type
  | refl (w : World) : DeployedTrace env w w
  | call {first w : World} (prior : DeployedTrace env first w) (call : Call) :
      DeployedTrace env first (transact env w call)
  | node {first w : World} (prior : DeployedTrace env first w) (after : Node)
      (event : NodeEvent env w after) : DeployedTrace env first { w with node := after }

/-- The current start record, created by the one-time start write. -/
def StartRecord (w : World) (cp : Checkpoint) : Prop :=
  ∃ start, w.start = some start ∧ cp.height = start.height ∧ cp.elHash = start.hash ∧
    cp.cometHash = 0 ∧ cp.cursor = 0

/-- A retained record is trusted only with actual landing provenance. Every matching retained
landing must certify its complete actual statement. In particular a certified header/cut
cannot hide a bad saved snapshot or SignalService state root. The start is the sole exception
to landing-event existence, as RECOV-8-28 requires. -/
def TrustedRecord (env : Environment) (initial w : World) (cp : Checkpoint) : Prop :=
  (Custody.Certified env initial cp ∨ Custody.Pending env w cp) ∧
  (StartRecord w cp ∨ ∃ event ∈ w.activeLandings,
    event.checkpoint = cp ∧ event.Certified env initial) ∧
  ∀ event ∈ w.activeLandings, event.checkpoint = cp → event.Certified env initial

/-- RECOV-8-24 to 8-28: the target is the last retained record before the first bad actual
landing, with its saved snapshot. Trust judges the actual landing's complete statement,
including the snapshot and emitted root, not merely whether its checkpoint can be certified.
This is a historical duty of the DAO upgrade, not a public runtime guard. -/
def RollbackAuthorized (env : Environment) (initial w : World) (trusted : Checkpoint)
    (snapshot : Nat) : Prop :=
  trusted ∈ w.activeRecords ∧ (trusted,snapshot) ∈ w.activeSnapshots ∧
  (∀ r ∈ w.activeRecords, r.height ≤ trusted.height → TrustedRecord env initial w r) ∧
  ∃ bad ∈ w.activeRecords, trusted.height < bad.height ∧
    ¬ TrustedRecord env initial w bad ∧
    ∀ r ∈ w.activeRecords, r.height < bad.height → r.height ≤ trusted.height

/-- These are external authorization duties over instrumented history, not runtime
checks. A rollback meets `RollbackAuthorized` for the history's initial world. They state no custody outcome. -/
def UpgradeAuthorized (env : Environment) (initial w : World) : Call → Prop
  | .rollback _ trusted snapshot => RollbackAuthorized env initial w trusted snapshot
  | _ => True

/-- Authorization is required only for successful raw upgrades in this actual history.
It does not quantify over all possible owner calls or all raw traces. -/
def AuthorizedUpgrades {env : Environment} : {first last : World} →
    DeployedTrace env first last → Prop
  | _,_,.refl _ => True
  | first,_,@DeployedTrace.call _ _ w prior call => AuthorizedUpgrades prior ∧
      ∀ t, execute env w call = some t → UpgradeAuthorized env first w call
  | _,_,.node prior _ _ => AuthorizedUpgrades prior

end Etna.Design.Current.Protocol.Governance
