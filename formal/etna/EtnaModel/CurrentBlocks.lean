import EtnaModel.Current
import EtnaModel.ActualQueue

/-! Current decoded §3–§7 rules. The catalogue fixes executable EL/payload/byte adapters;
all consensus, anchoring, schedule and FI checks remain below, outside the catalogue.
The authenticated context uses the generation origin floor for pre-origin lookbacks. -/
namespace Etna.Design.Current.Blocks

abbrev Header := BlockValidity.Header
abbrev Bytes := ActualQueue.Bytes

structure Block where
  body : BlockValidity.Block
  schedule : Rules.Schedule
  raw : Bytes
  first : Option Bytes
  /-- Complete decoded execution-body order; the fixed payload adapter authenticates it. -/
  transactions : List Bytes := first.toList
  deriving DecidableEq, Repr

def Block.header (b : Block) : Header := b.body.header

/-- Immutable decoded interpreter entry, never a supplied block-validity conclusion. -/
structure Definition where
  executionValid : Header → BlockValidity.Block → Bool
  /-- Authenticate the complete ordered execution-body transaction list and witness bytes. -/
  payloadValid : BlockValidity.Block → Bytes → List Bytes → Bool
  bytes : ActualQueue.Primitives

abbrev RulesetCatalogue := Nat → Option Definition

structure GenerationPolicy where
  consensus : Consensus.Context
  startHeight : Nat
  gridK : Nat
  committeeConfig : Hash
  maxAnchorAge : Nat
  forcedDelay : Nat
  unsettled : Nat
  referenceNumber : Nat
  referenceHash : Hash
  committeeHash : Committee.Record → Hash
  signature : Consensus.Vote → Prop
  anchorAuthenticated : BlockValidity.Anchor → Bool
  committeeAuthenticated : Hash → Committee.Record → Bool
  forcedAuthenticated : BlockValidity.Anchor → Forced.Witness → Bool
  /-- Decoding of slot 293 under this exact anchor root. -/
  scheduleAuthenticated : BlockValidity.Anchor → Rules.Schedule → Bool
  batchPayloadValid : List Hash → List Block → Bool
  configHash : List Encoding.Word → Hash
  historyAuthenticated : Consensus.Context → Nat → Bool
  catalogue : RulesetCatalogue

abbrev Policy := GenerationPolicy

def refusingDefinition : Definition :=
  ⟨fun _ _ => false,fun _ _ _ => false,⟨fun _ => 0,fun _ => false,fun _ _ _ => .unavailable⟩⟩

def selectedRules (b : Block) : Nat := Rules.select b.schedule b.header.timestamp

def definition (r : GenerationPolicy) (b : Block) : Definition :=
  (r.catalogue (selectedRules b)).getD refusingDefinition

/-- The entry is the canonical, hash-matching transaction at execution-body position zero.
The parser is the selected fixed interpreter; no raw EIP-2718 refinement is asserted here. -/
def Included (primitive : ActualQueue.Primitives) (entry : Forced.Entry) (first : Option Bytes) : Prop :=
  ∃ tx, first = some tx ∧ primitive.hashBytes tx = entry.txHash ∧
    primitive.canonical tx = true ∧ tx.length ≤ 8192

/-- A skip is bound to the submitted bytes and a completed selected-interpreter decision. -/
def Skipped (primitive : ActualQueue.Primitives) (parent : Header)
    (block : BlockValidity.Block) (entry : Forced.Entry) (raw : Bytes) : Prop :=
  primitive.hashBytes raw = entry.txHash ∧ raw.length ≤ 8192 ∧
    (primitive.canonical raw = false ∨ primitive.buildSingleton parent block.header raw = .completedEmpty)

/-- Inclusion is allowed before the deadline; skipping consumes an entry only once due. -/
def TimelyByteAction (primitive : ActualQueue.Primitives) (delay : Nat) (parent : Header)
    (block : BlockValidity.Block) (entry : Forced.Entry) (raw : Bytes) (first : Option Bytes) : Prop :=
  Included primitive entry first ∨
    (entry.timestamp+delay ≤ block.header.anchor.timestamp ∧ Skipped primitive parent block entry raw)

def HeaderValid (r : GenerationPolicy) (p : Header) (b : Block) : Prop :=
  b.header.height = p.height+1 ∧ b.body.parentHash = p.elHash ∧
  b.body.lastBlockId = (if p.height = r.consensus.originHeight then none else some p.cometHash) ∧
  b.body.domain = r.consensus.domain ∧ b.body.generation = r.consensus.generation ∧
  b.header.timestamp < limit256 ∧
  b.header.timestamp = max (max (p.timestamp+1) b.body.bftTime) b.header.anchor.timestamp ∧
  b.body.feeShare = 100 ∧ b.body.blockBytes ≤ 124000 ∧
  b.body.parentBeaconRoot = b.header.anchor.stateRoot ∧
  b.body.validatorsHash = r.committeeHash (Consensus.activeAt r.consensus b.header.height) ∧
  b.body.nextValidatorsHash = r.committeeHash (Consensus.activeAt r.consensus (b.header.height+1))

/-- First-generation blocks authenticate their own anchor; later blocks authenticate and
inherit the parent anchor when unchanged. Old generation parent fields impose no floor. -/
def ParentAnchorValid (r : GenerationPolicy) (p : Header) (b : Block) : Prop :=
  if p.height = r.consensus.originHeight then b.body.anchorWitness = true
  else p.anchor.number ≤ b.header.anchor.number ∧
    r.consensus.anchorAt p.height = p.anchor.number ∧
    b.body.anchorWitness = decide (p.anchor.number ≠ b.header.anchor.number) ∧
    (p.anchor.number = b.header.anchor.number → p.anchor = b.header.anchor)

structure AnchorValid (r : GenerationPolicy) (p : Header) (b : Block) : Prop where
  parent : ParentAnchorValid r p b
  origin : r.consensus.originBlock ≤ b.header.anchor.number
  reference : b.header.anchor.number ≤ r.referenceNumber
  numberRange : b.header.anchor.number < limit48
  generation : b.header.anchor.generation = r.consensus.generation
  timestamp : b.header.anchor.timestamp ≤ b.header.timestamp
  age : b.header.timestamp-b.header.anchor.timestamp ≤ r.maxAnchorAge
  pressure : b.header.height-b.header.anchor.checkpointHeight ≤ r.unsettled
  history : r.consensus.anchorAt b.header.height = b.header.anchor.number
  authenticated : r.anchorAuthenticated b.header.anchor = true

/-- Epochs remain absolute; the generation's landing grid is not the epoch origin. -/
def WitnessValid (r : GenerationPolicy) (b : Block) : Prop :=
  if (b.header.height+1) % r.consensus.epochLen = 0 then
    match b.body.committeeWitness with
    | none => False
    | some w => w.record = Consensus.normal r.consensus ((b.header.height+1)/r.consensus.epochLen) ∧
        w.root = b.header.anchor.stateRoot ∧ w.record.cutoff ≤ b.header.anchor.number ∧
        r.committeeAuthenticated w.root w.record = true ∧ Consensus.ElectionValid r.consensus w.record
  else b.body.committeeWitness = none

structure Valid (r : GenerationPolicy) (p : Header) (b : Block) : Prop where
  config : Committee.configOK r.gridK r.consensus.epochLen r.unsettled = true
  floor : r.consensus.originHeight ≤ p.height
  header : HeaderValid r p b
  anchor : AnchorValid r p b
  witness : WitnessValid r b
  commit : Consensus.CommitValid r.consensus r.signature b.header.height b.body.round b.header.cometHash b.body.votes
  forced : Forced.step p.cursor b.header.anchor.tail b.header.anchor.timestamp r.forcedDelay b.body.forced b.body.singleton = .accepted b.header.cursor
  selected : r.catalogue (selectedRules b) = some (definition r b)
  schedule : Rules.fits b.schedule
  scheduleOpening : r.scheduleAuthenticated b.header.anchor b.schedule = true
  notStopped : Rules.stopped b.schedule r.startHeight p.height p.timestamp = false
  execution : (definition r b).executionValid p b.body = true
  payload : (definition r b).payloadValid b.body b.raw b.transactions = true
  positionZero : b.first = b.transactions.head?
  fields : ∀ w, b.body.forced = some w → ActualQueue.PayloadFields (definition r b).bytes p b.body w b.raw b.first
  storage : ∀ w, b.body.forced = some w → r.forcedAuthenticated b.header.anchor w = true
  configuration : r.committeeConfig = r.configHash (Encoding.configWords r.consensus.domain.l2ChainId
    r.consensus.domain.registry r.consensus.unit r.consensus.minimum r.consensus.nMax r.unsettled)
  history : r.historyAuthenticated r.consensus r.referenceNumber = true

/-- Every block selects its own anchored timestamp definition; there is no batch-wide
no-crossing rule and no caller-supplied security conclusion in the interpreter. -/
def Chain (r : GenerationPolicy) : Header → List Block → Prop
  | _, [] => True
  | p, b :: rest => Valid r p b ∧ Chain r b.header rest

def terminal : Header → List Block → Header
  | p, [] => p
  | _, b :: rest => terminal b.header rest

def cuts (p : Header) (bs : List Block) : List Cut := p.cut :: bs.map (fun b => b.header.cut)

def headerAt (p : Header) (bs : List Block) (n : Nat) : Header := terminal p (bs.take n)

def pairs : Header → List Block → List (Header × Block)
  | _, [] => []
  | p, b :: rest => (p,b) :: pairs b.header rest

/-- Every edge, including a stationary cursor, retains its actual parent and bytes. -/
def cursorWalk (p : Header) (bs : List Block) : List (Nat × Nat) :=
  (pairs p bs).map fun pair => (pair.1.cursor,pair.2.header.cursor)

/-- Keep exactly the actual block edges which consume one queue entry. -/
def consumingPairs (p : Header) (bs : List Block) : List (Header × Block) :=
  (pairs p bs).filter fun x => decide (x.2.header.cursor = x.1.cursor+1)

def statement (r : GenerationPolicy) (p : Header) (bs : List Block) (blobs : List Hash) : StatementData :=
  let last := terminal p bs
  let input : LandInput := ⟨p.height,last.height,last.elHash,last.cometHash,last.stateRoot,
    r.referenceNumber,last.cursor,(Consensus.activeAt r.consensus last.height).cutoff⟩
  ⟨r.consensus.domain,r.consensus.generation,r.committeeConfig,p.elHash,p.cometHash,p.cursor,
    input,r.referenceHash,blobs,tableHash r.gridK r.consensus.generation p.height last.height (cuts p bs)⟩

def BatchValid (r : GenerationPolicy) (p : Header) (bs : List Block) (blobs : List Hash) : Prop :=
  Chain r p bs ∧ r.batchPayloadValid blobs bs = true

end Etna.Design.Current.Blocks
