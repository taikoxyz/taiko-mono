import EtnaModel.CurrentProtocol

/-! Current funds authorization. A refused start is merely archival data until the
first landing's Unzen fence authenticates it. Paths retain actual accepted calls,
reachable source states, full headers and concrete per-block rules. -/
namespace Etna.Design.Current.Protocol.Custody

structure Primitives (env : Environment) : Prop where
  genesis : HashBound env env.genesisHeader
  /-- EL hash agreement binds EL fields. Comet hash and FI cursor are bound by cuts. -/
  separation : ∀ x y, HashBound env x → HashBound env y → x.elHash = y.elHash →
    x.height = y.height ∧ x.stateRoot = y.stateRoot ∧ x.timestamp = y.timestamp ∧ x.anchor = y.anchor
  /-- The pre-existing Unzen proof authenticates its actual decoded EL header. -/
  unzen : ∀ proposal h proof, env.unzenValid proposal h proof = true →
    env.unzenRoot h ∧ HashBound env h ∧ h.timestamp < env.core.forkTime

/-- Physical EL fields of a legacy header, with Etna's initial Comet/FI context and the start
record's zero validator-state hash (STOR-B-9). -/
def StartsAt (h legacy : Header) : Prop :=
  h.height = legacy.height ∧ h.elHash = legacy.elHash ∧ h.stateRoot = legacy.stateRoot ∧
  h.timestamp = legacy.timestamp ∧ h.anchor = legacy.anchor ∧ h.cometHash = 0 ∧ h.cursor = 0 ∧
  h.valStateHash = 0

/-- The actual contract fence at the accepting first landing. The timestamp is the
upstream Unzen/cutoff duty; implementation validation remains guest semantics. -/
def FirstFence (env : Environment) (w : World) (h : Header) : Prop :=
  ∃ start, w.start = some start ∧ w.inbox.checkpoint.height = start.height ∧
    env.core.unzenInbox ≠ 0 ∧ w.unzen.nextProposal = w.unzen.finalizedProposal+1 ∧
    w.unzen.finalizedHash = start.hash ∧ w.unzen.checkpointExists = true ∧
    w.unzen.checkpointHash = start.hash ∧ w.unzen.checkpointRoot = start.stateRoot ∧
    h.height = start.height ∧ h.elHash = start.hash ∧ h.stateRoot = start.stateRoot ∧
    env.startImplementation h.stateRoot = true ∧ h.timestamp < env.core.forkTime

inductive Path (env : Environment) (initial : World) : Header → Prop
  | genesis {w t : World} (caller : Nat)
      (prior : Trace env initial w) (accepted : initializeInbox env w caller = some t)
      (newNetwork : env.core.unzenInbox = 0) : Path env initial env.genesisHeader
  | unzen {w t : World} {a : Landing} {h legacy : Header}
      (prior : Trace env initial w) (accepted : land env w a = some t)
      (first : w.inbox.checkpoint.height = (w.start.map StartData.height).getD 0)
      (switching : env.core.unzenInbox ≠ 0)
      (retained : w.unzenHeader = some legacy)
      (authenticated : env.unzenRoot legacy) (starts : StartsAt h legacy)
      (bound : HashBound env h) (fence : FirstFence env w h) : Path env initial h
  | landing {w t : World} {a : Landing}
      (prior : Trace env initial w) (accepted : land env w a = some t)
      (segment : Suffix env w a) (parent : Path env initial segment.parent) :
      Path env initial (Blocks.terminal segment.parent segment.blocks)

def AuthenticRoot (env : Environment) (initial : World) (h : Header) : Prop :=
  (env.core.unzenInbox = 0 ∧ h = env.genesisHeader) ∨
  ∃ w t a legacy, Trace env initial w ∧ land env w a = some t ∧ FirstFence env w h ∧
    w.unzenHeader = some legacy ∧ env.unzenRoot legacy ∧ StartsAt h legacy

inductive Descends (env : Environment) (initial : World) (root : Header) : Header → Prop
  | refl : Descends env initial root root
  | landing {w t : World} {a : Landing}
      (prior : Trace env initial w) (accepted : land env w a = some t)
      (segment : Suffix env w a) (parent : Descends env initial root segment.parent) :
      Descends env initial root (Blocks.terminal segment.parent segment.blocks)

def HeaderOf (cp : Checkpoint) (h : Header) : Prop :=
  h.height = cp.height ∧ h.cut = ⟨cp.elHash,cp.cometHash,cp.cursor,cp.valStateHash⟩

def Certified (env : Environment) (initial : World) (cp : Checkpoint) : Prop :=
  ∃ h, HeaderOf cp h ∧ HashBound env h ∧ Path env initial h

/-- This branch asserts no header existence, hash binding, or authenticity. -/
def Pending (env : Environment) (w : World) (cp : Checkpoint) : Prop :=
  env.core.unzenInbox ≠ 0 ∧ ∃ start, w.start = some start ∧ cp.height = start.height ∧ cp.elHash = start.hash ∧
    cp.cometHash = 0 ∧ cp.cursor = 0 ∧ cp.valStateHash = 0

def SignalSafe (env : Environment) (initial : World) (s : Signal) : Prop :=
  ∃ h, Path env initial h ∧ HashBound env h ∧ h.height = s.height ∧
    h.elHash = s.hash ∧ h.stateRoot = s.stateRoot

structure Invariant (env : Environment) (initial w : World) : Prop where
  records : ∀ cp ∈ w.activeRecords, Certified env initial cp ∨ Pending env w cp
  signals : ∀ s ∈ w.inbox.signals, SignalSafe env initial s
  unzen : w.unzen.checkpointExists = true → ∃ h, w.unzenHeader = some h ∧ env.unzenRoot h ∧ HashBound env h ∧
    w.unzen.finalizedHash = h.elHash ∧ w.unzen.checkpointHash = h.elHash ∧
    w.unzen.checkpointRoot = h.stateRoot ∧ h.timestamp < env.core.forkTime

/-- Raw reachability facts, proved by the current journal rather than presumed by H1. -/
def Frontier (w : World) : Prop := w.start.isSome = true →
  w.inbox.checkpoint ∈ w.activeRecords ∧
  recordAt w.inbox w.inbox.checkpoint.height = some w.inbox.checkpoint ∧
  w.inbox.checkpoint.cursor = w.inbox.head

end Etna.Design.Current.Protocol.Custody
