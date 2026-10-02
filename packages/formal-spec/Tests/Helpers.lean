import TaikoSpec.Derivation.Manifest

/-!
# Test helpers

Builders for payloads and blocks. Payloads use stored (uncompressed) DEFLATE blocks, so tests can
build any manifest without a compressor.
-/

open TaikoSpec TaikoSpec.Derivation

namespace Tests

/-- A 32-byte big-endian word. -/
def word (n : Nat) : ByteArray :=
  ⟨((List.range 32).reverse.map fun i => (n / 256 ^ i % 256).toUInt8).toArray⟩

/-- A zlib stream holding `raw` in stored blocks of at most 65535 bytes. -/
def zlibStored (raw : ByteArray) : ByteArray := Id.run do
  let mut out : ByteArray := ⟨#[0x78, 0x01]⟩
  let mut pos := 0
  let mut first := true
  while first || pos < raw.size do
    first := false
    let len := min 65535 (raw.size - pos)
    let final := pos + len ≥ raw.size
    out := out.push (if final then 1 else 0)
    out := out.push (len % 256).toUInt8 |>.push (len / 256).toUInt8
    out := out.push ((65535 - len) % 256).toUInt8 |>.push ((65535 - len) / 256).toUInt8
    out := out ++ raw.extract pos (pos + len)
    pos := pos + len
  let a := Zlib.adler32 raw
  return out ++ ⟨#[(a / 2 ^ 24).toUInt8, (a / 2 ^ 16 % 256).toUInt8, (a / 256 % 256).toUInt8,
    (a % 256).toUInt8]⟩

/-- A source payload carrying `blocks`, preceded by `offset` filler bytes. -/
def payloadOf (blocks : List BlockManifest) (offset : Nat := 0) (version : Nat := 1) :
    ByteArray :=
  let compressed := zlibStored (encodeManifest blocks)
  ⟨Array.replicate offset 0xaa⟩ ++ word version ++ word compressed.size ++ compressed

/-- A 20-byte address filled with `b`. -/
def addr (b : UInt8) : ByteArray := ⟨Array.replicate 20 b⟩

/-- A block without transactions. -/
def blk (timestamp anchor gasLimit : Nat) (coinbase : UInt8 := 0) : BlockManifest where
  timestamp := timestamp
  coinbase := addr coinbase
  anchorBlockNumber := anchor
  gasLimit := gasLimit
  transactions := []

/-- A source with blobs, by default a proposer source at offset 0. -/
def src (forced : Bool := false) (offset : Nat := 0) : Source :=
  { isForcedInclusion := forced, hasBlobs := true, offset }

/-- The timestamp, anchor and gas limit of each block. -/
def fields (bs : List BlockManifest) : List (Nat × Nat × Nat) :=
  bs.map fun b => (b.timestamp, b.anchorBlockNumber, b.gasLimit)

end Tests
