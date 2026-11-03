import EtnaModel.CurrentCoherentCustody

/-! External DAO upgrades and their history obligations. `correctStart` and `rollback`
in the normative machine are admissible upgrade actions, not deployed public entry
points. The raw functions below erase the historical ghost guards. `everLanded` and
`activeSnapshots` remain instrumentation of the actual transaction history; an owner
must establish their obligations from that history, not read them from Inbox storage. -/
namespace Etna.Design.Current.Protocol.Governance

/-- Physical start-rewrite checks/effect without the external no-prior-landing duty. -/
def rawCorrectStart (env : Environment) (w : World) (caller height hash root : Nat) : Option World :=
  w.start.bind fun old =>
    if caller = env.core.owner ∧ env.core.unzenInbox ≠ 0 ∧
        w.inbox.checkpoint.height = old.height ∧ w.inbox.signals = [] ∧
        0 < height ∧ height < limit48 ∧ hash ≠ 0 ∧ root ≠ 0 ∧ w.inbox.generation+1 < limit48 then
      some (writeStart w height hash root w.number (env.time w.number) (w.inbox.generation+1))
    else none

/-- Physical rollback checks/effect without a nonexistent checkpoint/snapshot mapping. -/
def rawRollback (env : Environment) (w : World) (caller : Nat) (trusted : Checkpoint)
    (snapshot : Nat) : Option World :=
  if caller = env.core.owner ∧ w.initialized = true ∧ w.inbox.entered = false ∧
      trusted ∈ w.activeRecords ∧ trusted.height ≤ w.inbox.checkpoint.height ∧
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
      activeSnapshots := w.activeSnapshots.filter (fun x => x.1.height ≤ trusted.height) }
  else none

def execute (env : Environment) (w : World) : Call → Option World
  | .correctStart caller height hash root => rawCorrectStart env w caller height hash root
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

/-- These are external authorization duties over instrumented history, not runtime
checks. A correction follows no successful landing; a rollback restores the snapshot
recorded with its retained checkpoint. Neither condition states a custody outcome. -/
def UpgradeAuthorized (w : World) : Call → Prop
  | .correctStart _ _ _ _ => w.everLanded = false
  | .rollback _ trusted snapshot => (trusted,snapshot) ∈ w.activeSnapshots
  | _ => True

/-- Authorization is required only for successful raw upgrades in this actual history.
It does not quantify over all possible owner calls or all raw traces. -/
def AuthorizedUpgrades {env : Environment} : {first last : World} →
    DeployedTrace env first last → Prop
  | _,_,.refl _ => True
  | _,_,@DeployedTrace.call _ _ w prior call => AuthorizedUpgrades prior ∧
      ∀ t, execute env w call = some t → UpgradeAuthorized w call
  | _,_,.node prior _ _ => AuthorizedUpgrades prior

end Etna.Design.Current.Protocol.Governance
