import EtnaModel.CurrentProtocol

/-! An executable injective encoding for nonvacuity witnesses. These unbounded Nat
labels model ideal commitments; they are not an implementation of fixed-width Keccak. -/
namespace Etna.Design.Current.Encoding

def pair (a b : Nat) : Nat := (a+b)*(a+b)+a

/-- Give finitely many concrete values compact labels, retaining injectivity globally
through the shifted general encoding. No equality or soundness premise is supplied. -/
def relabel [DecidableEq α] : List α → (α → Nat) → α → Nat
  | [],code,x => code x
  | a :: rest,code,x => if x=a then 0 else relabel rest code x+1

inductive Tree where
  | leaf (value : Nat)
  | node (left right : Tree)
  deriving DecidableEq, Repr

def Tree.code : Tree → Nat
  | .leaf n => 2*n
  | .node a b => 2*pair a.code b.code+1

def quad (a b c d : Tree) : Tree := .node (.node a b) (.node c d)

def list (f : α → Tree) : List α → Tree
  | [] => .leaf 0
  | x :: xs => .node (f x) (list f xs)

def domain (d : Domain) : Tree := quad (.leaf d.l1ChainId) (.leaf d.l2ChainId)
  (.leaf d.inbox) (.leaf d.registry)

def entry (e : Committee.Entry) : Tree := quad (.leaf e.key) (.leaf e.stake)
  (.leaf e.activeFrom) (.leaf e.exitAt)

def committee (c : Committee.Record) : Tree := .node
  (.node (.leaf c.targetEpoch) (.leaf c.cutoff)) (list entry c.members)

def origin (o : Origin) : Tree := .node (.leaf o.height) (.node (.leaf o.l1Block) (.leaf o.timestamp))

def namedOrigin (x : Nat × Origin) : Tree := .node (.leaf x.1) (origin x.2)

def checkpoint (c : Checkpoint) : Tree := quad (.node (.leaf c.height) (.leaf c.elHash))
  (.node (.leaf c.cometHash) (.leaf c.cursor)) (.leaf c.generation) (.leaf c.parent)

def signal (s : Signal) : Tree := .node (.leaf s.height) (.node (.leaf s.hash) (.leaf s.stateRoot))

def configuration (c : CommitteeConfig) : Tree := quad (.leaf c.unit) (.leaf c.minimum)
  (.leaf c.nMax) (.leaf c.unsettled)

def state (s : Etna.Design.State) : Tree := quad
  (quad (domain s.domain) (.leaf s.committeeConfig) (.leaf s.gridK) (.leaf s.entered.toNat))
  (quad (.leaf s.generation) (.leaf s.recoveryNonce) (origin s.origin)
    (list namedOrigin s.origins))
  (quad (checkpoint s.checkpoint) (list checkpoint s.records)
    (quad (.leaf s.head) (.leaf s.tail) (.leaf s.snapshot) (.leaf s.ethBalance))
    (quad (.leaf s.feeAdmissions) (.leaf s.forcedETH) (.leaf s.swept) (list signal s.signals)))
  (quad (quad (.leaf s.epochLen) (.leaf s.genesisCutoff) (.leaf s.committeeZero) (configuration s.configuration))
    (committee s.committeeZeroRecord) (.node (.leaf s.forcedDelay) (.leaf s.maxAnchorAge))
    (quad (.leaf s.maxBatchBlocks) (.leaf s.forcedFee) (.leaf s.forcedThreshold) (.leaf s.protocolFeeRecipient)))

def schedule (s : Rules.Schedule) : Tree := quad (.node (.leaf s.active) (.leaf s.next))
  (.leaf s.time) (.leaf s.stopTime) (.leaf s.stopGrid)

def start (s : Protocol.StartData) : Tree := .node (.leaf s.height) (.node (.leaf s.hash) (.leaf s.stateRoot))

def optional (f : α → Tree) : Option α → Tree
  | none => .leaf 0
  | some x => .node (.leaf 1) (f x)

def registrySnapshot (s : RegistryHistory.Snapshot) : Tree := .node (.leaf s.block) (list entry s.entries)

def forcedEntry (e : Forced.Entry) : Tree := .node (.leaf e.txHash) (.node (.leaf e.timestamp) (.leaf e.l1Block))

def queuedEntry (x : Nat × Forced.Entry) : Tree := .node (.leaf x.1) (forcedEntry x.2)

def snapshot (s : Protocol.Snapshot) : Tree := quad
  (.node (.leaf s.number) (.leaf s.timestamp)) (state s.inbox)
  (.node (schedule s.schedule) (optional start s.start))
  (.node (list registrySnapshot s.registryHistory)
    (list queuedEntry s.queue))

def snapshotHash (s : Protocol.Snapshot) : Hash := (snapshot s).code
def referenceHash (history : List Protocol.Snapshot) (number : Nat) : Hash :=
  pair (list snapshot history).code number

def anchor (a : BlockValidity.Anchor) : Tree := quad
  (.node (.leaf a.number) (.leaf a.timestamp)) (.node (.leaf a.stateRoot) (.leaf a.checkpointHeight))
  (.leaf a.checkpointHash) (.node (.leaf a.generation) (.leaf a.tail))

/-- Physical decoded EL fields; its own hash and independent Comet/FI metadata are excluded. -/
def header (h : Blocks.Header) : Tree := quad (.leaf h.height) (.leaf h.stateRoot)
  (.leaf h.timestamp) (anchor h.anchor)

def headerHash (h : Blocks.Header) : Hash := (header h).code

end Etna.Design.Current.Encoding
