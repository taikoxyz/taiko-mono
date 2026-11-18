import DerivationWitnesses.Tests.Helpers
import DerivationWitnesses.Examples

/-!
# Manifest extraction tests

Ported from the Rust `protocol` crate's `manifest.rs` tests.
-/

open TaikoSpec TaikoSpec.Derivation Tests

-- Candidate grammar uses executable byte-array operations; this guard is not a kernel proof.
#guard Witness.candidateTransactions.all Tx.wellFormed

/-- `extractManifest` for a payload, by default from a proposer source at offset 0. -/
def extract (payload : ByteArray) (s : Source := src) : Option (List BlockManifest) :=
  extractManifest s (some payload)

/-- `p` with its size word replaced by `f` of the current size. -/
def mapSizeWord (p : ByteArray) (f : Nat → Nat) : ByteArray :=
  p.extract 0 32 ++ word (f (beNat (p.extract 32 64))) ++ p.extract 64 p.size

-- A well-formed manifest is extracted as is, also at a non-zero offset.
#guard (extract (payloadOf [blk 5 6 7])).map fields == some [(5, 6, 7)]
#guard (extract (payloadOf [blk 5 6 7] (offset := 7)) (src (offset := 7))).map fields ==
  some [(5, 6, 7)]
-- The version word must be below 2^64 with its low 32 bits equal to 1.
#guard (extract (payloadOf [blk 5 6 7] (version := 2 ^ 32 + 1))).isSome
#guard (extract (payloadOf [blk 5 6 7] (version := 2))).isNone
#guard (extract (payloadOf [blk 5 6 7] (version := 2 ^ 64 + 1))).isNone
-- The size is the low 64 bits of its word, and must fit in the payload.
#guard (extract (mapSizeWord (payloadOf [blk 5 6 7]) (· + 2 ^ 100))).isSome
#guard (extract (mapSizeWord (payloadOf [blk 5 6 7]) (· + 1))).isNone
#guard (extract (mapSizeWord (payloadOf [blk 5 6 7]) (· - 1))).isNone
#guard (extract (mapSizeWord (payloadOf [blk 5 6 7]) fun _ => 2 ^ 64 - 1)).isNone
-- No blobs, an offset past BLOB_BYTES - 64, or undecodable blobs give the default manifest.
#guard (extractManifest { src with hasBlobs := false }
  (some (payloadOf [blk 5 6 7]))).isNone
#guard (extract (payloadOf [blk 5 6 7]) (src (offset := 131009))).isNone
#guard (extractManifest src none).isNone
#guard (extract ByteArray.empty).isNone
-- A forced inclusion must carry exactly one block.
#guard (extract (payloadOf [blk 5 6 7]) (src (forced := true))).isSome
#guard (extract (payloadOf [blk 5 6 7, blk 8 9 10]) (src (forced := true))).isNone
#guard (extract (payloadOf []) (src (forced := true))).isNone
-- A zero-block manifest is extracted; validation replaces it later.
#guard (extract (payloadOf [])).map List.length == some 0
-- At most 768 blocks per source.
#guard (extract (payloadOf (List.replicate 768 (blk 1 1 1)))).isSome
#guard (extract (payloadOf (List.replicate 769 (blk 1 1 1)))).isNone
