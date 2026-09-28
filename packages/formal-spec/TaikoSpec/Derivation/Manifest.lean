import TaikoSpec.Zlib
import TaikoSpec.Tx
import TaikoSpec.Derivation.Params
import TaikoSpec.Derivation.Types

/-!
# Manifest extraction

From a source's blob payload (the decoded blobs, concatenated) to its manifest blocks. `none`
means the source is replaced by the default manifest. Every check is a plain condition, so the
order in which an implementation performs them does not change the result.
-/

namespace TaikoSpec.Derivation

open TaikoSpec.Rlp

/-- Decodes `[timestamp, coinbase, anchorBlockNumber, gasLimit, [tx, …]]`. -/
def decodeBlock : Item → Option BlockManifest
  | .list [timestamp, coinbase, anchorBlockNumber, gasLimit, .list txs] => do
    let timestamp ← timestamp.uint? 64
    let coinbase ← coinbase.bytesN? 20
    let anchorBlockNumber ← anchorBlockNumber.uint? 64
    let gasLimit ← gasLimit.uint? 64
    guard (txs.all Tx.wellFormed)
    pure { timestamp, coinbase, anchorBlockNumber, gasLimit, transactions := txs }
  | _ => none

/-- Decodes a `DerivationSourceManifest`, whose RLP is `[[block, …]]`, from the whole of `raw`. -/
def decodeManifest (raw : ByteArray) : Option (List BlockManifest) :=
  match Rlp.decode raw with
  | some (.list [.list blocks]) => blocks.mapM decodeBlock
  | _ => none

/-- The compressed manifest inside a payload. Bytes `[offset, offset + 32)` hold the version,
bytes `[offset + 32, offset + 64)` the size, and the compressed data follows. The version must
be below `2^64` with its low 32 bits equal to 1; the size is the low 64 bits of its word. -/
def compressedSlice (payload : ByteArray) (offset : Nat) : Option ByteArray :=
  if offset + 64 ≤ payload.size then
    let version := beNat (payload.extract offset (offset + 32))
    let size := beNat (payload.extract (offset + 32) (offset + 64)) % 2 ^ 64
    if version < 2 ^ 64 ∧ version % 2 ^ 32 = SHASTA_PAYLOAD_VERSION ∧
        size ≤ payload.size - (offset + 64) then
      some (payload.extract (offset + 64) (offset + 64 + size))
    else none
  else none

/-- The block-count rules: at most `maxBlocks`, and exactly one for a forced inclusion. -/
def checkLimits (c : ChainParams) (ctx : ProposalCtx) (src : Source)
    (blocks : List BlockManifest) : Option (List BlockManifest) :=
  if blocks.length ≤ maxBlocks c ctx.timestamp ∧
      (src.isForcedInclusion = true → blocks.length = 1) then
    some blocks
  else none

/-- The manifest blocks of a source, or `none` for the default manifest. `payload` is the
source's blobs decoded and concatenated, or `none` if a blob's encoding is invalid. -/
def extractManifest (c : ChainParams) (ctx : ProposalCtx) (src : Source)
    (payload : Option ByteArray) : Option (List BlockManifest) :=
  if src.hasBlobs ∧ src.offset ≤ BLOB_BYTES - 64 then
    payload.bind fun bytes =>
      (compressedSlice bytes src.offset).bind fun compressed =>
        (Zlib.decompress compressed).bind fun raw =>
          (decodeManifest raw).bind (checkLimits c ctx src)
  else none

/-- The RLP item of one manifest block. -/
def encodeBlock (b : BlockManifest) : Item :=
  .list [.bytes (natToMinimalBytes b.timestamp), .bytes b.coinbase,
    .bytes (natToMinimalBytes b.anchorBlockNumber), .bytes (natToMinimalBytes b.gasLimit),
    .list b.transactions]

/-- The RLP encoding of a `DerivationSourceManifest`. -/
def encodeManifest (blocks : List BlockManifest) : ByteArray :=
  Rlp.encode (.list [.list (blocks.map encodeBlock)])

end TaikoSpec.Derivation
