import TaikoSpec.Derivation.Manifest
import TaikoSpec.Derivation.Validate

/-!
# Deriving a proposal's blocks

Sources are processed in order. Each source's blocks build on the last block of the source
before it, and block numbers continue from the parent.
-/

namespace TaikoSpec.Derivation

variable (c : ChainParams) (ctx : ProposalCtx)

/-- The parent for the block after `b`. -/
def advance (p : Parent) (b : BlockManifest) : Parent where
  number := p.number + 1
  timestamp := b.timestamp
  gasLimit := b.gasLimit + anchorGasReserve c b.timestamp
  anchorBlockNumber := b.anchorBlockNumber

/-- Numbers a source's blocks, starting after `p`. -/
def toDerived (c : ChainParams) (forced : Bool) : Parent → List BlockManifest → List DerivedBlock
  | _, [] => []
  | p, b :: bs =>
    { number := p.number + 1
      timestamp := b.timestamp
      coinbase := b.coinbase
      anchorBlockNumber := b.anchorBlockNumber
      gasLimit := b.gasLimit
      transactions := b.transactions
      isForcedInclusion := forced } :: toDerived c forced (advance c p b) bs

/-- The blocks one source contributes when it builds on `p`. -/
def sourceBlocks (p : Parent) (src : Source) (payload : Option ByteArray) : List BlockManifest :=
  (finalizeSource c ctx p src (extractManifest c ctx src payload)).blocks

/-- The parent after all of `sources` have been derived on top of `p`. -/
def parentAfter : Parent → List (Source × Option ByteArray) → Parent
  | p, [] => p
  | p, (src, payload) :: rest =>
    parentAfter ((sourceBlocks c ctx p src payload).foldl (advance c) p) rest

/-- All blocks derived from `sources`, in order, on top of `p`. Each source comes with its blob
payload (`none` if a blob's encoding is invalid). -/
def deriveSources : Parent → List (Source × Option ByteArray) → List DerivedBlock
  | _, [] => []
  | p, (src, payload) :: rest =>
    let bs := sourceBlocks c ctx p src payload
    toDerived c src.isForcedInclusion p bs ++ deriveSources (bs.foldl (advance c) p) rest

end TaikoSpec.Derivation
