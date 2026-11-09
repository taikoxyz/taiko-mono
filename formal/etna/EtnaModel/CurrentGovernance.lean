import EtnaModel.CurrentCoherentCustody

/-! External DAO upgrades and their history obligations. `correctStart` and `rollback`
in the normative machine are admissible upgrade actions, not deployed public entry
points. The raw functions below erase the historical ghost guards. `everLanded`,
`activeRecords` and `activeSnapshots` instrument the actual transaction history; an owner
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

/-- RECOV-8-24 to 8-28 as an external duty of a verifier-failure rollback. A retained
record is trusted when some admissible history from `initial` certifies it (`Custody.Certified`)
or it is the current start record (`Custody.Pending`); otherwise it was written by a bad
landing. The duty holds when `trusted` is a retained record with the snapshot written with
it, every retained record at or below it is trusted, and the first retained record above it
is bad. So a verifier failure happened (RECOV-8-24), and `trusted` is the last trusted
landing, the last landing before the first bad one, or the start record if no landing is
trusted (RECOV-8-28). It cannot be a guard of `rollback` itself: `Certified` quantifies over
`Trace`, which `rollback` builds. -/
def RollbackAuthorized (env : Environment) (initial w : World) (trusted : Checkpoint)
    (snapshot : Nat) : Prop :=
  trusted ∈ w.activeRecords ∧ (trusted,snapshot) ∈ w.activeSnapshots ∧
  (∀ r ∈ w.activeRecords, r.height ≤ trusted.height →
    Custody.Certified env initial r ∨ Custody.Pending env w r) ∧
  ∃ bad ∈ w.activeRecords, trusted.height < bad.height ∧
    ¬ Custody.Certified env initial bad ∧ ¬ Custody.Pending env w bad ∧
    ∀ r ∈ w.activeRecords, r.height < bad.height → r.height ≤ trusted.height

/-- These are external authorization duties over instrumented history, not runtime
checks. A correction follows no successful landing; a rollback meets `RollbackAuthorized`
for the history's initial world. They state no custody outcome. -/
def UpgradeAuthorized (env : Environment) (initial w : World) : Call → Prop
  | .correctStart _ _ _ _ => w.everLanded = false
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
