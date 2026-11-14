import DerivationModel.Derivation.Derive
import DerivationModel.Derivation.ExtraData
import DerivationModel.Chain

/-!
# Pre-execution header plans

The payload fields the Go and Rust drivers derive for an Unzen block before execution: the header
gas limit, the extra data and the transaction list. Candidate transactions are RLP items: sender
authentication and execution are outside this model, and so are the base fee, `mixHash`, and the
anchor's L1 block hash and state root. The execution engine, not the drivers, sets the Unzen
header fields `parentBeaconBlockRoot` (zero), `blobGasUsed`, `excessBlobGas`, `requestsHash` and
`difficulty` (zk gas); they are outside this model too.
-/
namespace TaikoSpec.Derivation

/-- Proposal fields the header reads. -/
structure HeaderContext where
  /-- `Proposed.basefeeSharingPctg`. -/
  baseFeeSharing : UInt8
  /-- `Proposed.id`, a uint48. -/
  proposalId : Nat

/-- One planned transaction: the system anchor first, then the manifest's candidates. -/
inductive TransactionPlanEntry where
  /-- `Anchor.anchorV4` for the block's anchor block number. -/
  | anchor (anchorBlockNumber : Nat)
  | manifest (item : TaikoSpec.Rlp.Item)

/-- A planned header; manifest gas stays in `block.gasLimit`. -/
structure HeaderPlan where
  block : DerivedBlock
  gasLimit : Nat
  extraData : List UInt8
  transactions : List TransactionPlanEntry

/-- The header plan of one derived block. -/
def buildHeader (hc : HeaderContext) (b : DerivedBlock) : HeaderPlan where
  block := b
  gasLimit := b.gasLimit + ANCHOR_GAS_LIMIT
  extraData := encodeExtraData hc.baseFeeSharing hc.proposalId
  transactions := .anchor b.anchorBlockNumber :: b.transactions.map .manifest

/-- The parent fields one header plan carries: its number, timestamp and header gas limit, and the
anchor block number its anchor transaction passes to `anchorV4`. -/
def headerParent (h : HeaderPlan) : Parent where
  number := h.block.number
  timestamp := h.block.timestamp
  gasLimit := h.gasLimit
  anchorBlockNumber := h.block.anchorBlockNumber

/-- `Anchor.getBlockState().anchorBlockNumber` after each of a sequence of anchor transactions,
starting from the parent's recorded value: `anchorV4` stores the checkpoint's block number only
when it is greater than the recorded one. -/
def recordedAnchors : Nat → List Nat → List Nat
  | _, [] => []
  | prev, n :: ns => max prev n :: recordedAnchors (max prev n) ns

/-- The parent the drivers rebuild after the header plans `hs` on top of `p`: number, timestamp
and gas limit from the last header, and the anchor block number from
`Anchor.getBlockState()`, i.e. the value recorded after the last anchor transaction. With no
header plan, `p`. -/
def rebuiltParent (p : Parent) (hs : List HeaderPlan) : Parent :=
  { hs.foldl (fun _ h => headerParent h) p with
    anchorBlockNumber := lastOr p.anchorBlockNumber
      (recordedAnchors p.anchorBlockNumber (hs.map (·.block.anchorBlockNumber))) }

/-- Derive every source, then plan each block's header. -/
def deriveHeaders (c : ChainParams) (proposal : ProposalCtx) (hc : HeaderContext) (p : Parent)
    (sources : List (Source × Option ByteArray)) : List HeaderPlan :=
  (deriveSources c proposal p sources).map (buildHeader hc)

end TaikoSpec.Derivation
