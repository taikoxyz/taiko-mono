import TaikoSpec.Derivation.Derive
import TaikoSpec.Derivation.ExtraData

/-!
# Checked header plans

Header construction follows normalized manifest derivation. Candidate transactions are RLP
items: sender authentication and execution are outside this model.
-/
namespace TaikoSpec.Derivation

/-- A 256-bit word, with its canonical representation given by `encodeBE 32 root.val`. -/
abbrev Root := Fin (2 ^ 256)

/-- Event metadata and the available L1 state-root lookups. -/
structure HeaderContext where
  baseFeeSharing : UInt8
  proposalId : Nat
  l1StateRoot : Nat → Option Root

/-- A normalized parent and its header commitment. -/
structure HeaderParent where
  core : Parent
  beaconRoot : Option Root

/-- Explicit distinction between the pre-Etna system anchor and manifest candidates. -/
inductive TransactionPlanEntry where
  | systemAnchor
  | manifest (item : TaikoSpec.Rlp.Item)

/-- A header construction result; manifest gas stays in `block.gasLimit`. -/
structure HeaderPlan where
  block : DerivedBlock
  gasLimit : Nat
  beaconRoot : Option Root
  extraData : List UInt8
  transactions : List TransactionPlanEntry

/-- Header failures cannot default or discard a source. -/
inductive HeaderError where
  | missingParentRoot
  | zeroParentRoot
  | missingL1Root (anchor : Nat)
  | zeroL1Root (anchor : Nat)
  | extraData (error : ExtraDataError)
  deriving DecidableEq, BEq, Repr

/-- Reuse is restricted to non-genesis Etna parents with an unchanged anchor. -/
def reuseParentRoot (c : ChainParams) (p : HeaderParent) (b : DerivedBlock) : Bool :=
  isEtna c p.core.timestamp && p.core.number != 0 && b.anchorBlockNumber == p.core.anchorBlockNumber

/-- Require a present nonzero commitment, retaining the origin of any failure. -/
def requireRoot (value : Option Root) (missing zero : HeaderError) : Except HeaderError Root :=
  match value with
  | none => .error missing
  | some r => if r = 0 then .error zero else .ok r

/-- Select the child's commitment from its own fork and the rolling parent. -/
def selectHeaderRoot (c : ChainParams) (ctx : HeaderContext) (p : HeaderParent)
    (b : DerivedBlock) : Except HeaderError (Option Root) := do
  if isEtna c b.timestamp then
    let r ← if reuseParentRoot c p b then
      requireRoot p.beaconRoot .missingParentRoot .zeroParentRoot
    else
      requireRoot (ctx.l1StateRoot b.anchorBlockNumber)
        (.missingL1Root b.anchorBlockNumber) (.zeroL1Root b.anchorBlockNumber)
    return some r
  else if isUnzen c b.timestamp then return some 0
  else return none

/-- Checked extra data for the child's fork. -/
def headerExtraData (c : ChainParams) (ctx : HeaderContext) (b : DerivedBlock) :
    Except HeaderError (List UInt8) :=
  if isEtna c b.timestamp then
    (encodeEtnaExtraData ctx.baseFeeSharing ctx.proposalId b.anchorBlockNumber).mapError
      HeaderError.extraData
  else .ok (encodeLegacyExtraData ctx.baseFeeSharing ctx.proposalId)

/-- Manifest order is unchanged; only earlier forks prepend a system anchor. -/
def candidateTransactions (c : ChainParams) (b : DerivedBlock) : List TransactionPlanEntry :=
  let items := b.transactions.map TransactionPlanEntry.manifest
  if isEtna c b.timestamp then items else .systemAnchor :: items

/-- Construct one header from a finalized, numbered manifest. -/
def buildHeader (c : ChainParams) (ctx : HeaderContext) (p : HeaderParent) (b : DerivedBlock) :
    Except HeaderError HeaderPlan := do
  let root ← selectHeaderRoot c ctx p b
  let extra ← headerExtraData c ctx b
  return { block := b
           gasLimit := b.gasLimit + anchorGasReserve c b.timestamp
           beaconRoot := root
           extraData := extra
           transactions := candidateTransactions c b }

/-- The next normalized parent retains the block's anchor and constructed header gas. -/
def advanceHeader (h : HeaderPlan) : HeaderParent :=
  { core := { number := h.block.number
              timestamp := h.block.timestamp
              gasLimit := h.gasLimit
              anchorBlockNumber := h.block.anchorBlockNumber }
    beaconRoot := h.beaconRoot }

/-- Sequential checked construction; any failure rejects the entire result. -/
def buildHeaders (c : ChainParams) (ctx : HeaderContext) : HeaderParent → List DerivedBlock →
    Except HeaderError (List HeaderPlan)
  | _, [] => .ok []
  | p, b :: bs => do
    let h ← buildHeader c ctx p b
    let hs ← buildHeaders c ctx (advanceHeader h) bs
    return h :: hs

/-- Derive every source first, then build headers with one rolling commitment across sources. -/
def deriveHeaders (c : ChainParams) (proposal : ProposalCtx) (ctx : HeaderContext)
    (p : HeaderParent) (sources : List (Source × Option ByteArray)) :
    Except HeaderError (List HeaderPlan) :=
  buildHeaders c ctx p (deriveSources c proposal p.core sources)

end TaikoSpec.Derivation
