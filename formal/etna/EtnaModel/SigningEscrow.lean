import EtnaModel.ProtocolState
import EtnaModel.Signer

/-! Derived signing/exit predicates. No replacement transition machine or escrow assumption
is introduced. `SnapshotTrace` is an explicit extra fact about a particular existing
trace: ordinary snapshots grow; exceptional rollback rechecks confirmations. It does not
authenticate arbitrary archives, bind a local signing tip, or guarantee evidence delivery. -/
namespace Etna.Design.SigningEscrow
open ProtocolState

/-- Confirmation timestamps name L1 blocks already reached by the machine. -/
def Clocked (w : World) : Prop :=
  ∀ id c, (w.registry.slots id).confirmedAt = some c → c ≤ w.l1Block

/-- Every retained confirmation is covered by the current landed snapshot. -/
def Covered (w : World) : Prop :=
  ∀ id c, (w.registry.slots id).confirmedAt = some c → (w.registry.slots id).exitAt ≤ w.inbox.snapshot

/-- A snapshot grows, or this is the registry-rechecking exceptional rollback transformer.
This predicate says nothing about escrow, signatures, or whether the restored value is trusted. -/
def SnapshotUpdate (w t : World) : Prop :=
  w.inbox.snapshot ≤ t.inbox.snapshot ∨
    ∃ cp snapshot now, t = applyRollback w cp snapshot now

/-- A refinement requiring only snapshot discipline. Every edge is an original Step;
this is not an observer replacing or restricting the original machine. Unrestricted traces
still receive `trace_clocked`; coverage additionally needs this environmental/proof bridge. -/
inductive SnapshotTrace : World → World → Prop
  | refl (w : World) : SnapshotTrace w w
  | step {first w t : World} (prior : SnapshotTrace first w)
      (change : Step w t) (snapshots : SnapshotUpdate w t) : SnapshotTrace first t

/-- Structural lifetime identities, including nonzero keys in any released slot of an
arbitrary input state. Reachable empty-start states satisfy the stronger condition. -/
structure KeysWellFormed (r : RegistryHistory.State) : Prop where
  allocated : ∀ id, id < r.nextId → (r.slots id).key ≠ 0 → (r.slots id).key ∈ r.usedKeys
  unique : ∀ key, key ≠ 0 → ∀ i, i < r.nextId → ∀ j, j < r.nextId →
    (r.slots i).key = key → (r.slots j).key = key → i = j

/-- Exclusion of a lifetime key in every allocated current entry; works after slot reuse. -/
def Excluded (key cutoff : Nat) (r : RegistryHistory.State) : Prop :=
  ∀ id, id < r.nextId → (r.slots id).key = key → (r.slots id).exitAt ≤ cutoff

/-- Authenticated decoded history lookup excludes a key at every cutoff at or after floor. -/
def HistoryExcluded (key floor : Nat) (r : RegistryHistory.State) : Prop :=
  ∀ cutoff, floor ≤ cutoff → ∀ e ∈ HistoricalContext.registryAt r cutoff,
    e.key = key → e.exitAt ≤ cutoff

/-- Every finite exit is already visible to all typed registry lookups at or beyond its
effective block; historical election snapshots before that block remain unchanged. -/
def ExitVisible (r : RegistryHistory.State) : Prop :=
  ∀ id, id < r.nextId → (r.slots id).key ≠ 0 → (r.slots id).exitAt ≠ Staking.noExit →
    HistoryExcluded (r.slots id).key (r.slots id).exitAt r

/-- All existing signer operations, without resetting durable state or adding a trust bit. -/
inductive SignerStep : Signer.State → Signer.State → Prop
  | sign {s t : Signer.State} {r : Signer.Request} {signature out : Hash} {persisted : Bool}
      (ok : Signer.sign s r signature persisted = some (t,out)) : SignerStep s t
  | switch (s : Signer.State) (domain : Domain) (generation start : Nat) (authenticated persisted : Bool) :
      SignerStep s (Signer.switchDomain s domain generation start authenticated persisted)
  | session (s : Signer.State) (generation : Nat) (trusted authoritative : Bool) :
      SignerStep s (Signer.openSession s generation trusted authoritative)

inductive SignerTrace : Signer.State → Signer.State → Prop
  | refl (s : Signer.State) : SignerTrace s s
  | step {first s t : Signer.State} (prior : SignerTrace first s) (change : SignerStep s t) : SignerTrace first t

end Etna.Design.SigningEscrow
