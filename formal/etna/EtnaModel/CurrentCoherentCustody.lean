import EtnaModel.CurrentCustody

/-! A single retained checkpoint chain. The header map is shared by every retained
record and signal; pending starts have no authenticated header at all. -/
namespace Etna.Design.Current.Protocol.Custody

/-- A custody edge keeps its actual accepted call and complete certified suffix. -/
def Edge (env : Environment) (initial : World) (parent child : Header) : Prop :=
  ∃ (w t : World) (a : Landing) (segment : Suffix env w a), Trace env initial w ∧ land env w a = some t ∧
    segment.parent = parent ∧ Blocks.terminal segment.parent segment.blocks = child

def RootAt (env : Environment) (start : Option StartData) (h : Header) : Prop :=
  ∃ s, start = some s ∧ h.height = s.height ∧ h.elHash = s.hash ∧
    h.stateRoot = s.stateRoot ∧ AuthenticRoot env h

/-- Newest-first retained chain: every record's actual parent is the next retained
record, and the oldest record is this start's authenticated root. -/
inductive Linked (env : Environment) (initial : World) (start : Option StartData)
    (H : Checkpoint → Header) : List Checkpoint → Prop
  | root (cp : Checkpoint) (root : RootAt env start (H cp)) : Linked env initial start H [cp]
  | step (child parent : Checkpoint) (rest : List Checkpoint)
      (parentHeight : parent.height = child.parent) (lower : parent.height < child.height)
      (edge : Edge env initial (H parent) (H child))
      (prior : Linked env initial start H (parent :: rest)) :
      Linked env initial start H (child :: parent :: rest)

/-- Before any authenticated Etna signal, a switching start remains untrusted. -/
def Waiting (env : Environment) (w : World) : Prop :=
  w.inbox.signals = [] ∧ (w.activeRecords = [] ∨
    w.activeRecords = [w.inbox.checkpoint] ∧ Pending env w w.inbox.checkpoint)

/-- One map and one retained parent chain authorize every current Etna signal. -/
def Coherent (env : Environment) (initial w : World) : Prop :=
  Waiting env w ∨ ∃ H : Checkpoint → Header,
    w.activeRecords.head? = some w.inbox.checkpoint ∧
    (∀ cp ∈ w.activeRecords, HeaderOf cp (H cp) ∧ HashBound env (H cp)) ∧
    Linked env initial w.start H w.activeRecords ∧
    ∀ signal ∈ w.inbox.signals, ∃ cp ∈ w.activeRecords,
      cp.height = signal.height ∧ cp.elHash = signal.hash ∧ (H cp).stateRoot = signal.stateRoot

def LegacySignalSafe (env : Environment) (signal : Signal) : Prop :=
  ∃ h, env.unzenRoot h ∧ HashBound env h ∧ h.timestamp < env.core.forkTime ∧
    h.height = signal.height ∧ h.elHash = signal.hash ∧ h.stateRoot = signal.stateRoot

/-- Calls that can write a new checkpoint and its associated selection snapshot. -/
def writesCheckpoint : Call → Bool
  | .initializeInbox _ | .setOrigin _ _ _ _ | .correctStart _ _ _ _ | .land _ => true
  | _ => false

/-- Exact snapshot provenance is an actual accepted checkpoint-writing call. -/
def SnapshotSource (env : Environment) (initial : World) (cp : Checkpoint) (snap : Nat) : Prop :=
  ∃ w call t, Trace env initial w ∧ execute env w call = some t ∧
    writesCheckpoint call = true ∧ t.inbox.checkpoint = cp ∧ t.inbox.snapshot = snap

end Etna.Design.Current.Protocol.Custody
