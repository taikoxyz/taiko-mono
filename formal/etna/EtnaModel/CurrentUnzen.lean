import EtnaModel.CurrentCoherentCustody

/-! Primitive Unzen proof/header progress and the legacy prefix retained by the
closed switching machine. The parent accessor decodes the contract's overlap-aware
`expectedParentHash` at the supplied finalized-proposal boundary; it receives no World. -/
namespace Etna.Design.Current.Protocol.Custody

/-- The existing Unzen guest authenticates a nonempty EL extension of its decoded
parent. This states only the strictly advancing endpoint-height consequence needed
here; Unzen EL execution/derivation is outside this Etna model. It is a primitive
per-proof semantic obligation, independent of successful Etna calls or outcomes. -/
def UnzenExtension (env : Environment)
    (parentHash : Nat → Nat → Header → Hash → Hash) : Prop :=
  ∀ boundary proposal h proof parent, boundary < proposal →
    env.unzenValid proposal h proof = true →
    HashBound env parent → parentHash boundary proposal h proof = parent.elHash →
    parent.height < h.height

/-- The retained legacy endpoint bounds every checkpoint emitted by the legacy lane.
An unfinished start never supplies a bound on its own. -/
def LegacyPrefix (env : Environment) (w : World) : Prop :=
  (w.unzenHeader = none ∧ w.unzen.checkpointExists = false ∧ w.legacySignals = []) ∨
  ∃ h, w.unzenHeader = some h ∧ w.unzen.checkpointExists = true ∧ HashBound env h ∧
    w.unzen.finalizedHash = h.elHash ∧ ∀ signal ∈ w.legacySignals, signal.height ≤ h.height

/-- Before the first landing a switching start is pending. Once a landing succeeds,
its fence closes Unzen and permanently separates all legacy/Etna signal heights. -/
def SwitchingFence (env : Environment) (w : World) : Prop :=
  (w.everLanded = false ∧ Waiting env w) ∨
  (w.everLanded = true ∧ ∃ start, w.start = some start ∧
    w.unzen.nextProposal = w.unzen.finalizedProposal+1 ∧
    (∀ legacy ∈ w.legacySignals, legacy.height ≤ start.height) ∧
    ∀ signal ∈ w.inbox.signals, start.height < signal.height)

/-- The two live SignalService lanes never write the same L2 checkpoint height. -/
def LegacyEtnaDisjoint (w : World) : Prop :=
  ∀ legacy ∈ w.legacySignals, ∀ etna ∈ w.inbox.signals, legacy.height < etna.height

/-- Ordinary nonlanding calls preserve the prelanding shape and emit no Etna signal. -/
def NonlandingEffect (env : Environment) (w t : World) : Prop :=
  t.everLanded = w.everLanded ∧
  (∀ signal ∈ t.inbox.signals, signal ∈ w.inbox.signals) ∧
  (Waiting env w → Waiting env t)

end Etna.Design.Current.Protocol.Custody
